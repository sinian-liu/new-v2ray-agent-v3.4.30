#!/bin/bash

# 脚本版本号
VERSION="v1.5.1"

# 全局变量
XRAY_CONFIG="/usr/local/etc/xray/config.json"
USER_DATA="/usr/local/etc/xray/users.json"
NGINX_CONF="/etc/nginx/conf.d/xray.conf"
SUBSCRIPTION_DIR="/var/www/subscribe"
CLASH_DIR="/var/www/clash"
BACKUP_DIR="/var/backups/xray"
CERTS_DIR="/etc/letsencrypt/live"
LOG_DIR="/usr/local/var/log/xray"
LOCK_FILE="/tmp/xray_users.lock"
XRAY_SERVICE="xray"
XRAY_BIN="/usr/local/bin/xray"
SCRIPT_PATH="/usr/local/bin/xray_menu.sh"
SYSTEMD_SERVICE="/etc/systemd/system/xray-menu.service"
XRAY_SYSTEMD="/etc/systemd/system/xray.service"
BASE_PORT=49152

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

# 检测系统并设置包管理器
detect_system() {
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) PKG_MANAGER="apt-get"; PKG_INSTALL="install -y"; NGINX_USER="www-data";;
        centos) [ "$VERSION_ID" -ge 8 ] && PKG_MANAGER="dnf" || PKG_MANAGER="yum"; PKG_INSTALL="install -y"; NGINX_USER="nginx";;
        *) echo -e "${RED}不支持的系统: $ID${NC}"; exit 1;;
    esac
}

# 初始化环境
init_env() {
    [ "$EUID" -ne 0 ] && { echo -e "${RED}请以 root 运行!${NC}"; exit 1; }
    detect_system
    timedatectl set-timezone Asia/Shanghai || { echo -e "${YELLOW}设置上海时区失败${NC}"; }
    mkdir -p "$LOG_DIR" "$SUBSCRIPTION_DIR" "$CLASH_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    chmod 700 "$LOG_DIR" "$SUBSCRIPTION_DIR" "$CLASH_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    chown root:root "$LOG_DIR" "$SUBSCRIPTION_DIR" "$CLASH_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chmod 660 "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chown "$NGINX_USER:$NGINX_USER" "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    [ ! -f "$USER_DATA" ] && echo '{"users": []}' > "$USER_DATA" && chmod 600 "$USER_DATA" && chown root:root "$USER_DATA"
    [ ! -f "$XRAY_CONFIG" ] && echo '{"log": {"loglevel": "info", "access": "'"$LOG_DIR/access.log"'", "error": "'"$LOG_DIR/error.log"'"}, "inbounds": [], "outbounds": [{"protocol": "freedom"}]}' > "$XRAY_CONFIG" && chmod 600 "$XRAY_CONFIG" && chown root:root "$XRAY_CONFIG"
    exec 200>"$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# 安装依赖
install_deps() {
    echo -e "${GREEN}安装依赖...${NC}"
    $PKG_MANAGER update -y || { echo -e "${RED}更新包索引失败，请检查网络!${NC}"; exit 1; }
    $PKG_MANAGER $PKG_INSTALL curl jq nginx uuid-runtime qrencode unzip ntpdate || { echo -e "${RED}依赖安装失败，请检查错误日志!${NC}"; $PKG_MANAGER $PKG_INSTALL curl jq nginx uuid-runtime qrencode unzip ntpdate; exit 1; }
    if ! command -v certbot >/dev/null; then
        $PKG_MANAGER $PKG_INSTALL python3-certbot-nginx || { echo -e "${RED}Certbot 安装失败!${NC}"; exit 1; }
        echo "0 0 * * * certbot renew --quiet" | crontab -
    fi
    ntpdate pool.ntp.org || { echo -e "${YELLOW}时间同步失败${NC}"; }
    systemctl enable nginx && systemctl start nginx || { echo -e "${RED}Nginx 启动失败!${NC}"; systemctl status nginx; exit 1; }
}

# 检查并安装 Xray 版本（参考你的代码）
check_xray_version() {
    echo -e "${GREEN}[检查Xray版本...]${NC}"
    CURRENT_VERSION=$(xray --version 2>/dev/null | grep -oP 'Xray \K[0-9]+\.[0-9]+\.[0-9]+' || echo "未安装")
    if [ "$CURRENT_VERSION" = "未安装" ] || ! command -v xray >/dev/null || [[ "$(printf '%s\n' "1.8.0" "$CURRENT_VERSION" | sort -V | head -n1)" != "1.8.0" ]]; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "unknown")
        echo "当前版本: $CURRENT_VERSION，需 v1.8.0+ 支持内置过期时间管理，最新版本: $LATEST_VERSION"
        read -p "是否安装最新版本? [y/N]: " UPDATE
        if [[ "$UPDATE" =~ ^[Yy] ]]; then
            [ -f "$XRAY_SYSTEMD" ] && mv "$XRAY_SYSTEMD" "$XRAY_SYSTEMD.bak.$(date +%F_%H%M%S)"
            bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) || { echo -e "${RED}Xray 安装失败!${NC}"; exit 1; }
            systemctl stop "$XRAY_SERVICE" >/dev/null 2>&1
            cat > "$XRAY_SYSTEMD" <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
Type=simple
ExecStartPre=/bin/mkdir -p $LOG_DIR
ExecStartPre=/bin/chown -R root:root $LOG_DIR
ExecStartPre=/bin/chmod -R 770 $LOG_DIR
ExecStartPre=/bin/touch $LOG_DIR/access.log $LOG_DIR/error.log
ExecStartPre=/bin/chown $NGINX_USER:$NGINX_USER $LOG_DIR/access.log $LOG_DIR/error.log
ExecStartPre=/bin/chmod 660 $LOG_DIR/access.log $LOG_DIR/error.log
ExecStartPre=/bin/chown root:root $XRAY_CONFIG
ExecStartPre=/bin/chmod 600 $XRAY_CONFIG
ExecStart=$XRAY_BIN run -config $XRAY_CONFIG
Restart=on-failure
RestartSec=5
User=root
Group=root
LimitNPROC=10000
LimitNOFILE=1000000
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
[Install]
WantedBy=multi-user.target
EOF
            chmod 644 "$XRAY_SYSTEMD"
            systemctl daemon-reload
            systemctl enable "$XRAY_SERVICE"
        else
            echo -e "${RED}需要 Xray v1.8.0+，请手动升级${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}Xray 版本检查通过: $CURRENT_VERSION${NC}"
}

# 配置防火墙
config_firewall() {
    if command -v ufw >/dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow "${BASE_PORT}-$(($BASE_PORT + 3))/tcp"
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port="${BASE_PORT}-$(($BASE_PORT + 3))/tcp"
        firewall-cmd --reload
    fi
}

# 设置 Nginx 和脚本开机自启
setup_autostart() {
    cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=Xray Menu Service
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH --check-expiry
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray-menu.service
    systemctl enable nginx
}

# 全新安装
install_xray() {
    echo -e "${GREEN}=== 全新安装 ===${NC}"
    init_env
    install_deps
    check_xray_version
    config_firewall

    read -p "请输入域名 (如 u.changkaiyuan.xyz): " DOMAIN
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short "$DOMAIN" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    [ -z "$DOMAIN_IP" ] && { echo -e "${RED}域名解析失败，请检查 DNS 设置!${NC}"; exit 1; }
    [ "$DOMAIN_IP" != "$SERVER_IP" ] && { echo -e "${RED}域名 $DOMAIN 解析为 $DOMAIN_IP，与服务器 IP $SERVER_IP 不符，请检查 Cloudflare 设置!${NC}"; exit 1; }

    echo -e "支持的协议:\n1. VLESS+WS+TLS (推荐)\n2. VMess+WS+TLS\n3. VLESS+gRPC+TLS\n4. VLESS+TCP+TLS (HTTP/2)"
    read -p "请选择（多选用空格分隔，默认 1）: " -a PROTOCOLS
    [ ${#PROTOCOLS[@]} -eq 0 ] && PROTOCOLS=(1)

    configure_protocols
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN" || { echo -e "${RED}证书申请失败!${NC}"; exit 1; }
    configure_nginx

    USERNAME="default"
    UUID=$(uuidgen)
    add_user "$USERNAME" "$UUID" "permanent" "0"
    systemctl restart "$XRAY_SERVICE" nginx
    setup_autostart

    echo -e "${GREEN}安装完成! 输入 'v' 打开管理菜单${NC}"
}

# 配置协议
configure_protocols() {
    PORTS=()
    for i in "${!PROTOCOLS[@]}"; do
        PORT=$((BASE_PORT + i))
        while ss -tuln | grep -q ":$PORT"; do 
            PORT=$((PORT + 1))
            echo -e "${YELLOW}端口 $((PORT - 1)) 被占用，已切换至 $PORT${NC}"
        done
        PORTS+=("$PORT")
    done
    WS_PATH="/ws_$(openssl rand -hex 4)"
    VMESS_PATH="/vmess_$(openssl rand -hex 4)"
    GRPC_SERVICE="grpc_$(openssl rand -hex 4)"
    TCP_PATH="/tcp_$(openssl rand -hex 4)"
    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {"loglevel": "info", "access": "$LOG_DIR/access.log", "error": "$LOG_DIR/error.log"},
  "inbounds": [],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    for i in "${!PROTOCOLS[@]}"; do
        case "${PROTOCOLS[$i]}" in
            1) jq ".inbounds += [{\"port\": ${PORTS[$i]}, \"protocol\": \"vless\", \"settings\": {\"clients\": [], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"ws\", \"wsSettings\": {\"path\": \"$WS_PATH\"}}}]" "$XRAY_CONFIG" > tmp.json ;;
            2) jq ".inbounds += [{\"port\": ${PORTS[$i]}, \"protocol\": \"vmess\", \"settings\": {\"clients\": []}, \"streamSettings\": {\"network\": \"ws\", \"wsSettings\": {\"path\": \"$VMESS_PATH\"}}}]" "$XRAY_CONFIG" > tmp.json ;;
            3) jq ".inbounds += [{\"port\": ${PORTS[$i]}, \"protocol\": \"vless\", \"settings\": {\"clients\": [], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"grpc\", \"grpcSettings\": {\"serviceName\": \"$GRPC_SERVICE\"}}}]" "$XRAY_CONFIG" > tmp.json ;;
            4) jq ".inbounds += [{\"port\": ${PORTS[$i]}, \"protocol\": \"vless\", \"settings\": {\"clients\": [], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"http\", \"httpSettings\": {\"path\": \"$TCP_PATH\"}}}]" "$XRAY_CONFIG" > tmp.json ;;
        esac
        mv tmp.json "$XRAY_CONFIG"
        $XRAY_BIN -test -c "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置错误!${NC}"; exit 1; }
    done
}

# 配置 Nginx（适配 Cloudflare 完全严格模式）
configure_nginx() {
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate $CERTS_DIR/$DOMAIN/fullchain.pem;
    ssl_certificate_key $CERTS_DIR/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Cloudflare 完全严格模式优化
    proxy_ssl_server_name on;
    proxy_ssl_protocols TLSv1.2 TLSv1.3;

EOF
    for i in "${!PROTOCOLS[@]}"; do
        case "${PROTOCOLS[$i]}" in
            1) echo "    location $WS_PATH { proxy_pass http://127.0.0.1:${PORTS[$i]}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \"Upgrade\"; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; }" >> "$NGINX_CONF" ;;
            2) echo "    location $VMESS_PATH { proxy_pass http://127.0.0.1:${PORTS[$i]}; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \"Upgrade\"; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; }" >> "$NGINX_CONF" ;;
            3) echo "    location /$GRPC_SERVICE { grpc_pass grpc://127.0.0.1:${PORTS[$i]}; grpc_set_header Host \$host; grpc_set_header X-Real-IP \$remote_addr; }" >> "$NGINX_CONF" ;;
            4) echo "    location $TCP_PATH { proxy_pass http://127.0.0.1:${PORTS[$i]}; proxy_http_version 2.0; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; }" >> "$NGINX_CONF" ;;
        esac
    done
    cat >> "$NGINX_CONF" <<EOF
    location /subscribe/ { 
        root /var/www; 
        add_header Access-Control-Allow-Origin "*"; 
        add_header Cache-Control "no-store, no-cache, must-revalidate"; 
    }
    location /clash/ { 
        root /var/www; 
        add_header Access-Control-Allow-Origin "*"; 
        add_header Cache-Control "no-store, no-cache, must-revalidate"; 
    }
}
EOF
    nginx -t && systemctl restart nginx || { echo -e "${RED}Nginx 配置错误!${NC}"; nginx -t; exit 1; }
    chown -R "$NGINX_USER:$NGINX_USER" "$SUBSCRIPTION_DIR" "$CLASH_DIR"
    chmod -R 755 "$SUBSCRIPTION_DIR" "$CLASH_DIR"
}

# 添加用户（支持自定义到期时间）
add_user() {
    local username="$1" uuid="$2" expire="$3" traffic_limit="$4"
    [ -z "$uuid" ] && uuid=$(uuidgen)
    [ -z "$expire" ] && {
        echo -e "到期时间选项:\n1. 月 (30天)\n2. 年 (365天)\n3. 自定义时间\n4. 永久"
        read -p "请选择 [1-4]: " expire_choice
        case "$expire_choice" in
            1) expire_date=$(date -d "+30 days" "+%Y-%m-%d %H:%M:%S") ;;
            2) expire_date=$(date -d "+365 days" "+%Y-%m-%d %H:%M:%S") ;;
            3) while true; do
                   read -p "请输入自定义时间 (如 1m/1h/1d/1y): " custom_time
                   if [[ "$custom_time" =~ ^([0-9]+)([mhdy])$ ]]; then
                       num=${BASH_REMATCH[1]}
                       unit=${BASH_REMATCH[2]}
                       case "$unit" in
                           m) expire_date=$(date -d "+$num minutes" "+%Y-%m-%d %H:%M:%S") ;;
                           h) expire_date=$(date -d "+$num hours" "+%Y-%m-%d %H:%M:%S") ;;
                           d) expire_date=$(date -d "+$num days" "+%Y-%m-%d %H:%M:%S") ;;
                           y) expire_date=$(date -d "+$num years" "+%Y-%m-%d %H:%M:%S") ;;
                       esac
                       break
                   else
                       echo -e "${RED}无效格式! 请使用如 1m、1h、1d、1y${NC}"
                   fi
               done ;;
            4) expire_date="永久" ;;
            *) expire_date=$(date -d "+30 days" "+%Y-%m-%d %H:%M:%S") ;;
        esac
    }
    [ -z "$traffic_limit" ] && { read -p "请输入流量限制 (GB，回车为无限制): " traffic_limit; traffic_limit=${traffic_limit:-0}; }
    local token=$(echo -n "$username:$uuid" | sha256sum | cut -c 1-32)

    flock -x 200
    jq --arg u "$username" --arg id "$uuid" --arg e "$expire_date" --arg t "$token" --argjson tl "$traffic_limit" \
       '.users += [{"name": $u, "uuid": $id, "expire": $e, "token": $t, "status": "启用", "traffic_limit": $tl, "traffic_used": 0}]' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"

    for i in "${!PROTOCOLS[@]}"; do
        case "${PROTOCOLS[$i]}" in
            1) jq ".inbounds[$i].settings.clients += [{\"id\": \"$uuid\"}]" "$XRAY_CONFIG" > tmp.json ;;
            2) jq ".inbounds[$i].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0}]" "$XRAY_CONFIG" > tmp.json ;;
            3) jq ".inbounds[$i].settings.clients += [{\"id\": \"$uuid\"}]" "$XRAY_CONFIG" > tmp.json ;;
            4) jq ".inbounds[$i].settings.clients += [{\"id\": \"$uuid\"}]" "$XRAY_CONFIG" > tmp.json ;;
        esac
        mv tmp.json "$XRAY_CONFIG"
        $XRAY_BIN -test -c "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置错误!${NC}"; exit 1; }
    done

    generate_subscription "$username" "$uuid" "$token"
    systemctl restart "$XRAY_SERVICE"
    flock -u 200
}

# 生成订阅链接并验证
generate_subscription() {
    local username="$1" uuid="$2" token="$3"
    local sub_file="$SUBSCRIPTION_DIR/$username.yml"
    local clash_file="$CLASH_DIR/$username.yml"
    > "$sub_file"
    > "$clash_file"

    for i in "${!PROTOCOLS[@]}"; do
        case "${PROTOCOLS[$i]}" in
            1) echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&path=$WS_PATH&sni=$DOMAIN#$username" >> "$sub_file"
               echo -e "- name: $username\n  type: vless\n  server: $DOMAIN\n  port: 443\n  uuid: $uuid\n  network: ws\n  tls: true\n  ws-opts:\n    path: $WS_PATH" >> "$clash_file" ;;
            2) echo "vmess://$(echo -n '{\"v\":\"2\",\"ps\":\"'$username'\",\"add\":\"'$DOMAIN'\",\"port\":\"443\",\"id\":\"'$uuid'\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"'$DOMAIN'\",\"path\":\"'$VMESS_PATH'\",\"tls\":\"tls\"}' | base64 -w 0)" >> "$sub_file"
               echo -e "- name: $username\n  type: vmess\n  server: $DOMAIN\n  port: 443\n  uuid: $uuid\n  alterId: 0\n  cipher: auto\n  network: ws\n  tls: true\n  ws-opts:\n    path: $VMESS_PATH" >> "$clash_file" ;;
            3) echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=$GRPC_SERVICE&sni=$DOMAIN#$username" >> "$sub_file"
               echo -e "- name: $username\n  type: vless\n  server: $DOMAIN\n  port: 443\n  uuid: $uuid\n  network: grpc\n  tls: true\n  grpc-opts:\n    grpc-service-name: $GRPC_SERVICE" >> "$clash_file" ;;
            4) echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=http&path=$TCP_PATH&sni=$DOMAIN#$username" >> "$sub_file"
               echo -e "- name: $username\n  type: vless\n  server: $DOMAIN\n  port: 443\n  uuid: $uuid\n  network: http\n  tls: true\n  http-opts:\n    path: $TCP_PATH" >> "$clash_file" ;;
        esac
    done
    chown "$NGINX_USER:$NGINX_USER" "$sub_file" "$clash_file"
    chmod 644 "$sub_file" "$clash_file"
    local sub_url="https://$DOMAIN/subscribe/$username.yml?token=$token"
    local clash_url="https://$DOMAIN/clash/$username.yml?token=$token"
    echo -e "${GREEN}订阅链接: $sub_url${NC}"
    echo -e "${GREEN}Clash 订阅: $clash_url${NC}"
    status=$(curl -s -o /dev/null -w "%{http_code}" --insecure -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$sub_url")
    [ "$status" -ne 200 ] && { echo -e "${RED}订阅链接不可访问 (状态码: $status)，请检查 Cloudflare 完全严格模式设置或 Nginx 配置${NC}"; }
}

# 用户到期和流量检测
check_expiry_and_traffic() {
    flock -x 200
    local now=$(date +%s)
    if ! grep -q "uuid" "$LOG_DIR/access.log" && [ -s "$LOG_DIR/access.log" ]; then
        echo -e "${YELLOW}警告: access.log 未包含 UUID，可能影响流量统计，请检查 Xray 日志配置${NC}"
    fi
    jq -r '.users[] | [.name, .uuid, .expire, .status, .traffic_limit, .traffic_used] | join("\t")' "$USER_DATA" | while IFS=$'\t' read -r name uuid expire status limit used; do
        local expire_ts=$(date -d "$expire" +%s 2>/dev/null || echo 0)
        local traffic=$(awk -v u="$uuid" '$0 ~ u {sum += $NF} END {print sum/1024/1024/1024}' "$LOG_DIR/access.log" 2>/dev/null || echo "0")
        jq --arg n "$name" --argjson t "$traffic" '.users[] | select(.name == $n) | .traffic_used = $t' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
        if { [ "$expire" != "永久" ] && [ "$expire_ts" -lt "$now" ]; } || { [ "$limit" -gt 0 ] && awk "BEGIN {exit !($traffic > $limit)}"; }; then
            if [ "$status" = "启用" ]; then
                jq --arg n "$name" '.users[] | select(.name == $n) | .status = "禁用"' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
                for i in "${!PROTOCOLS[@]}"; do
                    jq --arg id "$uuid" ".inbounds[$i].settings.clients -= [{\"id\": \$id}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG"
                    $XRAY_BIN -test -c "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置错误!${NC}"; exit 1; }
                done
                systemctl restart "$XRAY_SERVICE"
                echo -e "${YELLOW}用户 $name 已过期或流量超限，已禁用${NC}"
            fi
        fi
    done
    flock -u 200
}

# 用户管理
user_management() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    while true; do
        echo -e "${BLUE}=== 用户管理 ===${NC}"
        echo -e "1. 添加用户\n2. 删除用户\n3. 列出用户\n4. 续期用户\n5. 导入用户\n6. 导出用户\n7. 重置流量\n8. 切换状态\n9. 返回"
        read -p "请选择: " choice
        case "$choice" in
            1) read -p "用户名: " username; add_user "$username";;
            2) read -p "用户名: " username; jq --arg n "$username" 'del(.users[] | select(.name == $n))' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"; systemctl restart "$XRAY_SERVICE"; echo -e "${GREEN}用户 $username 已删除${NC}";;
            3) echo -e "用户名      UUID                                  到期时间                状态    流量限制(GB)  已用流量(GB)"; 
               jq -r '.users[] | [.name, .uuid, .expire, (if .status == "启用" then "启用" else "禁用" end), .traffic_limit, .traffic_used] | join("\t")' "$USER_DATA" | 
               awk 'BEGIN {FS="\t"; OFS="\t"} {printf "%-12s %-36s %-22s %-6s %-12.2f %-12.2f\n", $1, $2, $3, $4, $5, $6}' ;;
            4) read -p "用户名: " username; add_user "$username" "$(jq -r ".users[] | select(.name == \"$username\") | .uuid" "$USER_DATA")"; echo -e "${GREEN}续期成功${NC}";;
            5) read -p "输入用户文件路径: " file; jq -s '.[0].users += .[1].users' "$USER_DATA" "$file" > tmp.json && mv tmp.json "$USER_DATA"; echo -e "${GREEN}用户导入完成${NC}";;
            6) jq '.users' "$USER_DATA" > "/tmp/users_export_$(date +%F).json"; echo -e "${GREEN}用户已导出至 /tmp/users_export_$(date +%F).json${NC}";;
            7) read -p "用户名: " username; jq --arg n "$username" '.users[] | select(.name == $n) | .traffic_used = 0' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"; echo -e "${GREEN}用户 $username 流量已重置${NC}";;
            8) read -p "用户名: " username; read -p "状态 (启用/禁用): " status; status=$(if [ "$status" = "启用" ]; then echo "启用"; else echo "禁用"; fi); jq --arg n "$username" --arg s "$status" '.users[] | select(.name == $n) | .status = $s' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"; systemctl restart "$XRAY_SERVICE"; echo -e "${GREEN}状态更新成功${NC}";;
            9) break;;
            *) echo -e "${RED}无效选项!${NC}";;
        esac
    done
}

# 协议管理
protocol_management() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    while true; do
        echo -e "${GREEN}=== 协议管理 ===${NC}"
        echo -e "当前协议: ${PROTOCOLS[*]}"
        echo -e "1. 添加协议\n2. 删除协议\n3. 返回"
        read -p "请选择: " choice
        case "$choice" in
            1) echo -e "支持的协议:\n1. VLESS+WS+TLS\n2. VMess+WS+TLS\n3. VLESS+gRPC+TLS\n4. VLESS+TCP+TLS (HTTP/2)"
               read -p "添加协议编号: " new_proto
               if [[ ! " ${PROTOCOLS[*]} " =~ " $new_proto " ]]; then
                   PROTOCOLS+=("$new_proto")
                   configure_protocols
                   configure_nginx
                   systemctl restart "$XRAY_SERVICE" nginx
                   echo -e "${GREEN}协议 $new_proto 已添加${NC}"
               else
                   echo -e "${YELLOW}协议已存在${NC}"
               fi;;
            2) read -p "输入要删除的协议编号: " del_proto
               if [[ " ${PROTOCOLS[*]} " =~ " $del_proto " ]]; then
                   for i in "${!PROTOCOLS[@]}"; do
                       if [ "${PROTOCOLS[$i]}" = "$del_proto" ]; then
                           unset 'PROTOCOLS[i]'
                           configure_protocols
                           configure_nginx
                           systemctl restart "$XRAY_SERVICE" nginx
                           echo -e "${GREEN}协议 $del_proto 已删除${NC}"
                           break
                       fi
                   done
               else
                   echo -e "${RED}协议不存在${NC}"
               fi;;
            3) break;;
            *) echo -e "${RED}无效选项!${NC}";;
        esac
    done
}

# 流量统计
traffic_stats() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 流量统计 ===${NC}"
    if ! grep -q "uuid" "$LOG_DIR/access.log" && [ -s "$LOG_DIR/access.log" ]; then
        echo -e "${YELLOW}警告: access.log 未包含 UUID，可能影响统计准确性${NC}"
    fi
    jq -r '.users[] | [.name, (if .status == "启用" then "启用" else "禁用" end), .traffic_limit, .traffic_used] | join("\t")' "$USER_DATA" | column -t -s $'\t'
}

# 备份恢复
backup_restore() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 备份恢复 ===${NC}"
    echo -e "1. 备份\n2. 恢复\n3. 返回"
    read -p "请选择: " choice
    case "$choice" in
        1) tar -czf "$BACKUP_DIR/xray_backup_$(date +%F).tar.gz" "$XRAY_CONFIG" "$USER_DATA" "$NGINX_CONF" "$CERTS_DIR/$DOMAIN"; echo -e "${GREEN}备份完成${NC}";;
        2) ls "$BACKUP_DIR"; read -p "输入备份文件: " file; tar -xzf "$BACKUP_DIR/$file" -C /; systemctl restart "$XRAY_SERVICE" nginx; echo -e "${GREEN}恢复完成${NC}";;
        3) return;;
        *) echo -e "${RED}无效选项!${NC}";;
    esac
}

# 查看证书
view_certificates() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${GREEN}=== 证书信息 ===${NC}"
    certbot certificates --cert-name "$DOMAIN" | grep -E "Certificate Name|Expiry Date|VALID" || echo -e "${RED}未找到证书信息${NC}"
}

# 查看日志
view_logs() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 查看日志 ===${NC}"
    tail -n 20 "$LOG_DIR/error.log"
}

# 测试连接
test_connection() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 测试连接 ===${NC}"
    read -p "请输入用户名: " username
    local uuid=$(jq -r ".users[] | select(.name == \"$username\") | .uuid" "$USER_DATA")
    [ -z "$uuid" ] && { echo -e "${RED}用户不存在!${NC}"; return; }
    for i in "${!PROTOCOLS[@]}"; do
        case "${PROTOCOLS[$i]}" in
            1) echo -e "测试 VLESS+WS+TLS..."; curl -s -o /dev/null -w "%{http_code}\n" --insecure "https://$DOMAIN$WS_PATH" ;;
            2) echo -e "测试 VMess+WS+TLS..."; curl -s -o /dev/null -w "%{http_code}\n" --insecure "https://$DOMAIN$VMESS_PATH" ;;
            3) echo -e "测试 VLESS+gRPC+TLS..."; curl -s -o /dev/null -w "%{http_code}\n" --insecure "https://$DOMAIN/$GRPC_SERVICE" ;;
            4) echo -e "测试 VLESS+TCP+TLS..."; curl -s -o /dev/null -w "%{http_code}\n" --insecure "https://$DOMAIN$TCP_PATH" ;;
        esac
    done
    echo -e "${GREEN}返回 200 表示连接正常${NC}"
}

# 清理日志
clean_logs() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 清理日志 ===${NC}"
    find "$LOG_DIR" -type f -mtime +30 -exec rm -f {} \;
    echo -e "${GREEN}30 天前的日志已清理${NC}"
}

# 更换域名并更新订阅文件
change_domain() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 更换域名 ===${NC}"
    read -p "请输入新域名: " new_domain
    sed -i "s/$DOMAIN/$new_domain/g" "$XRAY_CONFIG" "$NGINX_CONF"
    certbot certonly --nginx -d "$new_domain" --non-interactive --agree-tos -m "admin@$new_domain" || { echo -e "${RED}证书更新失败!${NC}"; return; }
    DOMAIN="$new_domain"
    systemctl restart "$XRAY_SERVICE" nginx
    # 更新所有用户的订阅文件
    jq -r '.users[] | [.name, .uuid, .token] | join("\t")' "$USER_DATA" | while IFS=$'\t' read -r name uuid token; do
        generate_subscription "$name" "$uuid" "$token"
    done
    echo -e "${GREEN}域名更换完成，所有订阅文件已更新${NC}"
}

# 检查系统资源
check_resources() {
    [ -z "$DOMAIN" ] && { echo -e "${RED}请先完成全新安装!${NC}"; return; }
    echo -e "${BLUE}=== 系统资源 ===${NC}"
    echo -e "CPU 使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
    echo -e "内存使用: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo -e "磁盘空间: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
}

# 卸载脚本
uninstall_script() {
    echo -e "${GREEN}=== 卸载脚本 ===${NC}"
    read -p "确认卸载? (y/N): " confirm
    [ "$confirm" != "y" ] && return
    systemctl stop "$XRAY_SERVICE" nginx xray-menu.service
    systemctl disable xray-menu.service
    rm -rf "$XRAY_CONFIG" "$USER_DATA" "$NGINX_CONF" "$SUBSCRIPTION_DIR" "$CLASH_DIR" "$BACKUP_DIR" "$LOG_DIR" "$LOCK_FILE" "$XRAY_BIN" "$SCRIPT_PATH" "$SYSTEMD_SERVICE" "$XRAY_SYSTEMD"
    systemctl daemon-reload
    systemctl restart nginx
    echo -e "${GREEN}卸载完成${NC}"
}

# 安装脚本并设置快捷命令
install_script() {
    cp "$0" "$SCRIPT_PATH"
    chmod 700 "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" /usr/local/bin/v
}

# 主菜单
main_menu() {
    init_env
    [ "$1" = "--check-expiry" ] && { check_expiry_and_traffic; exit 0; }
    check_expiry_and_traffic
    [ ! -L /usr/local/bin/v ] && install_script
    while true; do
        XRAY_STATUS=$(systemctl is-active "$XRAY_SERVICE" 2>/dev/null || echo "inactive")
        NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
        echo -e "${GREEN}=== Xray 管理脚本 ($VERSION) ===${NC}"
        echo -e "${GREEN}Xray: $XRAY_STATUS | Nginx: $NGINX_STATUS${NC}"
        echo -e "1. 全新安装\n2. 用户管理\n3. 协议管理\n4. 流量统计\n5. 备份恢复\n6. 查看证书\n7. 查看日志\n8. 测试连接\n9. 清理日志\n10. 更换域名\n11. 检查资源\n12. 卸载脚本\n13. 退出"
        read -p "请选择: " choice
        case "$choice" in
            1) install_xray;;
            2) user_management;;
            3) protocol_management;;
            4) traffic_stats;;
            5) backup_restore;;
            6) view_certificates;;
            7) view_logs;;
            8) test_connection;;
            9) clean_logs;;
            10) change_domain;;
            11) check_resources;;
            12) uninstall_script;;
            13) exit 0;;
            *) echo -e "${RED}无效选项!${NC}";;
        esac
    done
}

# 启动
main_menu "$@"
