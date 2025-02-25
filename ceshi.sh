#!/bin/bash
# Xray 高级管理脚本
# 版本: v1.10.5-fix4
# 支持系统: Ubuntu 20.04/22.04, CentOS 7/8, Debian 10/11 (systemd)

# 配置常量
XRAY_CONFIG="/usr/local/etc/xray/config.json"
USER_DATA="/usr/local/etc/xray/users.json"
NGINX_CONF="/etc/nginx/conf.d/xray.conf"
SUBSCRIPTION_DIR="/var/www/subscribe"
BACKUP_DIR="/var/backups/xray"
CERTS_DIR="/etc/letsencrypt/live"
LOG_DIR="/usr/local/var/log/xray"
SCRIPT_NAME="xray-menu"
LOCK_FILE="/tmp/xray_users.lock"
XRAY_SERVICE_NAME="xray"
XRAY_BIN="/usr/local/bin/xray"

# 全局路径变量
declare WS_PATH VMESS_PATH GRPC_SERVICE TCP_PATH

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
NC='\033[0m'

# 主菜单
main_menu() {
    init_environment
    while true; do
        echo -e "${GREEN}==== Xray高级管理脚本 ====${NC}"
        echo "1. 全新安装"
        echo "2. 用户管理"
        echo "3. 协议管理"
        echo "4. 流量统计"
        echo "5. 备份恢复"
        echo "6. 退出脚本"
        read -p "请选择操作 [1-6]: " CHOICE
        case "$CHOICE" in
            1) install_xray ;;
            2) user_management ;;
            3) protocol_management ;;
            4) traffic_stats ;;
            5) backup_restore ;;
            6) exit 0 ;;
            *) echo -e "${RED}无效选择!${NC}" ;;
        esac
    done
}

# 检测系统类型
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
    else
        echo -e "${RED}无法检测系统类型!${NC}"
        exit 1
    fi
    case "$OS_NAME" in
        ubuntu|debian) PKG_MANAGER="apt";;
        centos) [ "$OS_VERSION" -ge 8 ] && PKG_MANAGER="dnf" || PKG_MANAGER="yum";;
        *) echo -e "${RED}不支持的系统: $OS_NAME${NC}"; exit 1;;
    esac
    SYSTEMD=$(ps -p 1 -o comm= | grep -q systemd && echo "yes" || echo "no")
    if [ "$SYSTEMD" != "yes" ]; then
        echo -e "${RED}此脚本要求 systemd 环境，当前系统使用 $(ps -p 1 -o comm=)!${NC}"
        exit 1
    fi
    echo "检测到系统: $OS_NAME $OS_VERSION，包管理器: $PKG_MANAGER，Init系统: systemd"
    # 等待 systemd 就绪
    for i in {1..30}; do
        STATE=$(systemctl is-system-running 2>/dev/null)
        if [ "$STATE" = "running" ] || [ "$STATE" = "degraded" ]; then
            break
        fi
        echo "等待 systemd 初始化 ($i/30)..."
        sleep 1
    done
    if [ "$STATE" = "running" ]; then
        echo "systemd 状态: running"
    elif [ "$STATE" = "degraded" ]; then
        echo -e "${YELLOW}警告: systemd 状态为 degraded，某些服务可能失败，请检查 'systemctl --failed'${NC}"
    else
        echo -e "${RED}systemd 未就绪，状态: $STATE，请检查系统状态!${NC}"
        systemctl status
        exit 1
    fi
}

# 检测 Xray 服务名
detect_xray_service() {
    XRAY_SERVICE_NAME="xray"
    echo "使用 Xray 服务名: $XRAY_SERVICE_NAME"
}

# 初始化环境
init_environment() {
    [ "$EUID" -ne 0 ] && echo -e "${RED}请使用 root 权限运行脚本!${NC}" && exit 1
    mkdir -p "$LOG_DIR" "$SUBSCRIPTION_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    chmod 770 "$LOG_DIR" "$SUBSCRIPTION_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    chown nobody:nogroup "$LOG_DIR"
    touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chmod 660 "$LOG_DIR"/*.log
    if [ ! -s "$USER_DATA" ] || ! jq -e . "$USER_DATA" >/dev/null 2>&1; then
        echo '{"users": []}' > "$USER_DATA"
        chmod 660 "$USER_DATA"
    fi
    chmod 600 "$XRAY_CONFIG" 2>/dev/null || true
    detect_system
    detect_xray_service
    setup_auto_start
    exec 200>$LOCK_FILE
    trap 'rm -f tmp.json; flock -u 200; rm -f $LOCK_FILE' EXIT
}

# 设置脚本和 Xray 重启后自动运行
setup_auto_start() {
    echo "配置 systemd 服务..."
    # 检查并移除 Drop-In 文件
    if [ -d "/etc/systemd/system/$XRAY_SERVICE_NAME.service.d" ]; then
        echo -e "${YELLOW}检测到 $XRAY_SERVICE_NAME.service 的 Drop-In 配置，移除以避免冲突...${NC}"
        rm -rf "/etc/systemd/system/$XRAY_SERVICE_NAME.service.d"
    fi

    # 脚本服务
    printf "[Unit]\nDescription=Xray Management Script\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=/bin/bash %s\nExecStop=/bin/kill -TERM \$MAINPID\nRestart=always\nRestartSec=5\nUser=root\n\n[Install]\nWantedBy=multi-user.target\n" "$(realpath "$0")" > /etc/systemd/system/$SCRIPT_NAME.service
    chmod 644 /etc/systemd/system/$SCRIPT_NAME.service
    systemctl daemon-reload
    systemctl enable $SCRIPT_NAME.service || { echo -e "${YELLOW}警告: 无法启用 $SCRIPT_NAME 服务，继续尝试启动...${NC}"; cat /etc/systemd/system/$SCRIPT_NAME.service; }
    systemctl restart $SCRIPT_NAME.service || echo -e "${YELLOW}警告: $SCRIPT_NAME 服务启动失败，但将继续执行${NC}"

    # Xray 服务
    printf "[Unit]\nDescription=Xray Service\nAfter=network.target nss-lookup.target\n\n[Service]\nType=simple\nExecStart=%s -config %s\nRestart=always\nRestartSec=5\nUser=nobody\nGroup=nogroup\nLimitNOFILE=51200\nAmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\n\n[Install]\nWantedBy=multi-user.target\n" "$XRAY_BIN" "$XRAY_CONFIG" > /etc/systemd/system/$XRAY_SERVICE_NAME.service
    chmod 644 /etc/systemd/system/$XRAY_SERVICE_NAME.service
    systemctl daemon-reload
    if ! systemctl enable "$XRAY_SERVICE_NAME" >/dev/null 2>&1; then
        echo -e "${RED}无法启用 Xray 服务! 检查服务文件:${NC}"
        cat /etc/systemd/system/$XRAY_SERVICE_NAME.service
        echo "systemd 状态:"
        systemctl status "$XRAY_SERVICE_NAME"
        exit 1
    fi
    echo "已设置 Xray 和脚本开机自启并持久运行。"
}

# 检测防火墙并开放端口
check_firewall() {
    echo -e "${GREEN}[检测防火墙状态...]${NC}"
    if command -v ufw >/dev/null; then
        if ufw status | grep -q "Status: active"; then
            echo "防火墙已启用，开放必要的端口..."
            ufw allow 80 >/dev/null
            ufw allow 443 >/dev/null
            ufw allow 10000 >/dev/null
            echo "- 已开放端口: 80, 443, 10000"
        else
            echo "防火墙未启用，无需调整端口。"
        fi
    elif command -v firewall-cmd >/dev/null; then
        if firewall-cmd --state | grep -q "running"; then
            echo "FirewallD 已启用，开放必要的端口..."
            firewall-cmd --permanent --add-port=80/tcp >/dev/null
            firewall-cmd --permanent --add-port=443/tcp >/dev/null
            firewall-cmd --permanent --add-port=10000/tcp >/dev/null
            firewall-cmd --reload >/dev/null
            echo "- 已开放端口: 80, 443, 10000"
        else
            echo "FirewallD 未启用，无需调整端口。"
        fi
    else
        echo "未检测到 ufw 或 FirewallD，可能需要手动配置防火墙。"
    fi
}

# 检查端口占用并分配可用端口
check_ports() {
    BASE_PORT=10000
    PORTS=()
    for i in "${!PROTOCOLS[@]}"; do
        PORT=$((BASE_PORT + i))
        while lsof -i :$PORT >/dev/null 2>&1; do
            echo -e "${YELLOW}端口 $PORT 已被占用，尝试下一个端口...${NC}"
            PORT=$((PORT + 1))
        done
        PORTS[$i]=$PORT
    done
    echo "分配可用端口: ${PORTS[*]}"
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}[2] 安装依赖...${NC}"
    case "$PKG_MANAGER" in
        apt)
            apt update || { echo -e "${RED}更新软件源失败，请检查网络或权限!${NC}"; exit 1; }
            apt install -y curl jq nginx uuid-runtime qrencode snapd netcat-openbsd || { 
                echo -e "${RED}必须依赖安装失败，请检查网络或权限!${NC}"; 
                exit 1; 
            }
            if ! command -v flock >/dev/null; then
                apt install -y util-linux || { echo -e "${RED}安装 util-linux (含 flock) 失败!${NC}"; exit 1; }
            fi
            if ! command -v certbot >/dev/null; then
                systemctl enable snapd >/dev/null 2>&1
                systemctl start snapd >/dev/null 2>&1
                snap install --classic certbot || { echo -e "${RED}Certbot 安装失败!${NC}"; exit 1; }
                ln -sf /snap/bin/certbot /usr/bin/certbot
            fi
            ;;
        yum|dnf)
            $PKG_MANAGER update -y || { echo -e "${RED}更新软件源失败，请检查网络或权限!${NC}"; exit 1; }
            $PKG_MANAGER install -y curl jq nginx uuid-runtime qrencode nc || { 
                echo -e "${RED}必须依赖安装失败，请检查网络或权限!${NC}"; 
                exit 1; 
            }
            if ! command -v flock >/dev/null; then
                $PKG_MANAGER install -y util-linux || { echo -e "${RED}安装 util-linux (含 flock) 失败!${NC}"; exit 1; }
            fi
            if ! command -v certbot >/dev/null; then
                $PKG_MANAGER install -y certbot python3-certbot-nginx || { echo -e "${RED}Certbot 安装失败!${NC}"; exit 1; }
            fi
            ;;
    esac
    systemctl start nginx || { echo -e "${RED}Nginx 启动失败!${NC}"; exit 1; }
    echo "- 已安装依赖: curl, jq, nginx, uuid-runtime, qrencode, certbot, netcat"
}

# 检查 Xray 版本
check_xray_version() {
    echo -e "${GREEN}[检查Xray版本...]${NC}"
    CURRENT_VERSION=$(xray --version 2>/dev/null | grep -oP 'Xray \K[0-9]+\.[0-9]+\.[0-9]+' || echo "未安装")
    if [ "$CURRENT_VERSION" = "未安装" ] || ! command -v xray >/dev/null; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "unknown")
        if [ "$LATEST_VERSION" = "unknown" ]; then
            echo "无法获取最新版本，使用默认安装。"
        else
            echo "当前版本: 未安装，最新版本: $LATEST_VERSION"
            read -p "是否安装最新版本? [y/N]: " UPDATE
            [[ "$UPDATE" =~ ^[Yy] ]] || exit 1
        fi
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) || { echo -e "${RED}Xray 安装失败!${NC}"; exit 1; }
        if ! command -v xray >/dev/null; then
            echo -e "${RED}Xray 未正确安装，请检查网络或手动安装!${NC}"
            exit 1
        fi
        CURRENT_VERSION=$(xray --version | grep -oP 'Xray \K[0-9]+\.[0-9]+\.[0-9]+')
        echo "已安装 Xray $CURRENT_VERSION"
    else
        LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name' | sed 's/v//' || echo "unknown")
        if [ "$LATEST_VERSION" != "unknown" ] && [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
            echo "当前版本: $CURRENT_VERSION，最新版本: $LATEST_VERSION"
            read -p "是否更新到最新版本? [y/N]: " UPDATE
            if [[ "$UPDATE" =~ ^[Yy] ]]; then
                bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) || { echo -e "${RED}Xray 更新失败!${NC}"; exit 1; }
                echo "已更新到 Xray $LATEST_VERSION"
            else
                echo "保持当前版本: $CURRENT_VERSION"
            fi
        else
            echo "当前已是最新版本: $CURRENT_VERSION"
        fi
    fi
}

# 配置域名
configure_domain() {
    echo -e "${GREEN}[4] 配置域名...${NC}"
    local retries=3
    while [ $retries -gt 0 ]; do
        read -p "请输入域名: " DOMAIN
        echo "验证域名解析..."
        SERVER_IP=$(curl -s ifconfig.me)
        DOMAIN_IP=$(dig +short "$DOMAIN" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
        echo "- 域名: $DOMAIN"
        echo "- 解析IP: $DOMAIN_IP"
        echo "- 服务器IP: $SERVER_IP"
        if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
            echo "域名验证通过!"
            break
        else
            retries=$((retries - 1))
            echo -e "${RED}域名验证失败! 剩余重试次数: $retries${NC}"
            echo "请检查 DNS 配置或稍后重试。"
            read -p "是否重试? [y/N]: " RETRY
            [[ ! "$RETRY" =~ ^[Yy] ]] && exit 1
        fi
    done
    [ $retries -eq 0 ] && { echo -e "${RED}域名验证多次失败，退出安装!${NC}"; exit 1; }
}

# 申请 SSL 证书
apply_ssl() {
    echo -e "${GREEN}[5] 申请SSL证书...${NC}"
    local retries=3
    while [ $retries -gt 0 ]; do
        certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN" || {
            retries=$((retries - 1))
            echo -e "${RED}证书申请失败! 剩余重试次数: $retries${NC}"
            sleep 5
            continue
        }
        break
    done
    [ $retries -eq 0 ] && { echo -e "${RED}证书申请多次失败，退出安装!${NC}"; exit 1; }
    echo "- 证书路径: $CERTS_DIR/$DOMAIN"
    echo "- 有效期: 90天"
}

# 配置 Nginx
configure_nginx() {
    echo -e "${GREEN}[配置Nginx代理...]${NC}"
    WS_PATH="/xray_ws_$(openssl rand -hex 4)"
    GRPC_SERVICE="grpc_$(openssl rand -hex 4)"
    VMESS_PATH="/vmess_ws_$(openssl rand -hex 4)"
    TCP_PATH="/tcp_$(openssl rand -hex 4)"
    if [ -f "$NGINX_CONF" ] && ! grep -q "Xray 配置" "$NGINX_CONF"; then
        echo -e "${YELLOW}检测到 $NGINX_CONF 已存在且非 Xray 配置，备份并覆盖${NC}"
        mv "$NGINX_CONF" "$NGINX_CONF.bak.$(date +%F_%H%M%S)"
    fi
    cat > "$NGINX_CONF" <<EOF
# Xray 配置
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name $DOMAIN;
    ssl_certificate $CERTS_DIR/$DOMAIN/fullchain.pem;
    ssl_certificate_key $CERTS_DIR/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    access_log /var/log/nginx/xray_access.log;
    error_log /var/log/nginx/xray_error.log debug;
EOF
    for i in "${!PROTOCOLS[@]}"; do
        PROTOCOL=${PROTOCOLS[$i]}
        PORT=${PORTS[$i]}
        case "$PROTOCOL" in
            1) echo "    location $WS_PATH {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }" >> "$NGINX_CONF" ;;
            2) echo "    location $VMESS_PATH {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_set_header Host \$host;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }" >> "$NGINX_CONF" ;;
            3) echo "    location /$GRPC_SERVICE {
        grpc_pass grpc://127.0.0.1:$PORT;
    }" >> "$NGINX_CONF" ;;
            4) echo "    location $TCP_PATH {
        proxy_pass http://127.0.0.1:$PORT;
    }" >> "$NGINX_CONF" ;;
        esac
    done
    echo "}" >> "$NGINX_CONF"
    nginx -t || { echo -e "${RED}Nginx 配置错误! 检查 $NGINX_CONF${NC}"; cat "$NGINX_CONF"; exit 1; }
    systemctl restart nginx || { echo -e "${RED}Nginx 重启失败!${NC}"; exit 1; }
    echo "Nginx 配置完成，路径: $WS_PATH (VLESS+WS), $VMESS_PATH (VMess+WS), $GRPC_SERVICE (gRPC), $TCP_PATH (TCP)"
}

# 配置 Xray 核心（多协议支持）
configure_xray() {
    echo -e "${GREEN}[6] 配置Xray核心...${NC}"
    cat > "$XRAY_CONFIG" <<EOF
{
    "log": {"loglevel": "debug", "access": "$LOG_DIR/access.log", "error": "$LOG_DIR/error.log"},
    "inbounds": [],
    "outbounds": [{"protocol": "freedom"}]
}
EOF
    for i in "${!PROTOCOLS[@]}"; do
        PROTOCOL=${PROTOCOLS[$i]}
        PORT=${PORTS[$i]}
        case "$PROTOCOL" in
            1) jq ".inbounds += [{\"port\": $PORT, \"protocol\": \"vless\", \"settings\": {\"clients\": [{\"id\": \"$UUID\"}], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"ws\", \"wsSettings\": {\"path\": \"$WS_PATH\"}}}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" ;;
            2) jq ".inbounds += [{\"port\": $PORT, \"protocol\": \"vmess\", \"settings\": {\"clients\": [{\"id\": \"$UUID\", \"alterId\": 0}]}, \"streamSettings\": {\"network\": \"ws\", \"wsSettings\": {\"path\": \"$VMESS_PATH\"}}}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" ;;
            3) jq ".inbounds += [{\"port\": $PORT, \"protocol\": \"vless\", \"settings\": {\"clients\": [{\"id\": \"$UUID\"}], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"grpc\", \"grpcSettings\": {\"serviceName\": \"$GRPC_SERVICE\"}}}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" ;;
            4) jq ".inbounds += [{\"port\": $PORT, \"protocol\": \"vless\", \"settings\": {\"clients\": [{\"id\": \"$UUID\"}], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"tcp\"}}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" ;;
        esac
    done
    chmod 600 "$XRAY_CONFIG"
    chown nobody:nogroup "$XRAY_CONFIG"
    echo "- 协议: $(for p in "${PROTOCOLS[@]}"; do case $p in 1) echo -n "VLESS+WS+TLS "; ;; 2) echo -n "VMess+WS+TLS "; ;; 3) echo -n "VLESS+gRPC+TLS "; ;; 4) echo -n "VLESS+TCP+TLS "; ;; esac; done)"
    echo "- 路径: $WS_PATH (VLESS+WS), $VMESS_PATH (VMess+WS), $GRPC_SERVICE (gRPC), $TCP_PATH (TCP)"
    echo "- 内部端口: ${PORTS[*]}"
    echo "Xray 配置文件内容:"
    cat "$XRAY_CONFIG"
}

# 创建默认用户
create_default_user() {
    echo -e "${GREEN}[7] 创建用户...${NC}"
    USERNAME="自用"
    UUID=$(uuidgen)
    while jq -r ".users[] | .uuid" "$USER_DATA" 2>/dev/null | grep -q "$UUID"; do
        UUID=$(uuidgen)
    done
    EXPIRE_DATE="永久"
    flock -x 200
    jq --arg name "$USERNAME" --arg uuid "$UUID" --arg expire "$EXPIRE_DATE" \
       '.users += [{"id": (.users | length + 1), "name": $name, "uuid": $uuid, "expire": $expire, "used_traffic": 0, "status": "启用"}]' \
       "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA" || { echo -e "${RED}用户数据保存失败!${NC}"; exit 1; }
    echo "- 用户名: $USERNAME"
    echo "- UUID: $UUID"
    echo "- 过期时间: $EXPIRE_DATE"
    flock -u 200
}

# 启动服务并检查状态
start_services() {
    echo -e "${GREEN}[8] 启动服务...${NC}"
    # 停止现有服务
    systemctl stop "$XRAY_SERVICE_NAME" >/dev/null 2>&1
    systemctl stop nginx >/dev/null 2>&1

    # 启动 Xray
    echo "通过 systemd 启动 Xray..."
    systemctl daemon-reload
    systemctl restart "$XRAY_SERVICE_NAME" || { 
        echo -e "${RED}Xray 服务启动失败! 检查服务状态...${NC}"
        systemctl status "$XRAY_SERVICE_NAME"
        echo "Xray 配置内容:"
        cat "$XRAY_CONFIG"
        echo "Xray 二进制权限:"
        ls -l "$XRAY_BIN"
        echo "测试 Xray 配置:"
        $XRAY_BIN -test -config "$XRAY_CONFIG"
        exit 1
    }
    sleep 3
    if ! systemctl is-active "$XRAY_SERVICE_NAME" >/dev/null; then
        echo -e "${RED}Xray 服务未运行! 查看 systemctl status $XRAY_SERVICE_NAME${NC}"
        systemctl status "$XRAY_SERVICE_NAME"
        exit 1
    fi
    echo "Xray 服务启动成功!"

    # 启动 Nginx
    systemctl restart nginx || { echo -e "${RED}Nginx 重启失败!${NC}"; exit 1; }
    sleep 3

    # 检查服务状态
    if systemctl is-active nginx >/dev/null && systemctl is-active "$XRAY_SERVICE_NAME" >/dev/null; then
        echo "- Nginx状态: 运行中"
        echo "- Xray状态: 运行中"
        for PORT in "${PORTS[@]}"; do
            if ! nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1; then
                echo -e "${RED}Xray 未监听端口 $PORT! 检查 $XRAY_CONFIG 或服务状态${NC}"
                echo "当前监听端口:"
                netstat -tuln | grep xray
                echo "Xray 错误日志:"
                cat "$LOG_DIR/error.log"
                exit 1
            fi
        done
        echo "检查服务状态... 成功!"
    else
        echo -e "${RED}服务启动失败!${NC}"
        echo "Nginx状态: $(systemctl is-active nginx)"
        echo "Xray状态: $(systemctl is-active "$XRAY_SERVICE_NAME")"
        echo "Nginx 错误日志:"
        cat /var/log/nginx/xray_error.log | tail -n 20
        echo "Xray 错误日志:"
        cat "$LOG_DIR/error.log"
        exit 1
    fi
}

# 显示用户链接并测试协议
show_user_link() {
    echo -e "${GREEN}[9] 显示用户链接...${NC}"
    echo -e "${BLUE}=== 客户端配置信息 ===${NC}\n"
    for PROTOCOL in "${PROTOCOLS[@]}"; do
        case "$PROTOCOL" in
            1)
                VLESS_WS_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&path=$WS_PATH&sni=$DOMAIN&host=$DOMAIN#$USERNAME"
                echo "[二维码 (VLESS+WS+TLS)]:"
                qrencode -t ansiutf8 "$VLESS_WS_LINK"
                echo -e "\n链接地址 (VLESS+WS+TLS):\n$VLESS_WS_LINK"
                ;;
            2)
                VMESS_LINK="vmess://$(echo -n '{\"v\":\"2\",\"ps\":\"$USERNAME\",\"add\":\"$DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"$VMESS_PATH\",\"tls\":\"tls\",\"sni\":\"$DOMAIN\"}' | base64 -w 0)"
                echo "[二维码 (VMess+WS+TLS)]:"
                qrencode -t ansiutf8 "$VMESS_LINK"
                echo -e "\n链接地址 (VMess+WS+TLS):\n$VMESS_LINK"
                ;;
            3)
                VLESS_GRPC_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=grpc&serviceName=$GRPC_SERVICE&sni=$DOMAIN#$USERNAME"
                echo "[二维码 (VLESS+gRPC+TLS)]:"
                qrencode -t ansiutf8 "$VLESS_GRPC_LINK"
                echo -e "\n链接地址 (VLESS+gRPC+TLS):\n$VLESS_GRPC_LINK"
                ;;
            4)
                VLESS_TCP_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=tcp&path=$TCP_PATH&sni=$DOMAIN#$USERNAME"
                echo "[二维码 (VLESS+TCP+TLS)]:"
                qrencode -t ansiutf8 "$VLESS_TCP_LINK"
                echo -e "\n链接地址 (VLESS+TCP+TLS):\n$VLESS_TCP_LINK"
                ;;
        esac
    done
    echo -e "\n订阅链接:\nhttps://subscribe.$DOMAIN/subscribe/$USERNAME.yml"
    echo -e "\nClash 配置链接:\nhttps://subscribe.$DOMAIN/clash/$USERNAME.yml"
    echo -e "\n${GREEN}测试协议可用性...${NC}"
    for PROTOCOL in "${PROTOCOLS[@]}"; do
        case "$PROTOCOL" in
            1) 
                WS_KEY=$(openssl rand -base64 16)
                RESPONSE=$(curl -s -v --http1.1 -H "Host: $DOMAIN" -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: $WS_KEY" -H "Sec-WebSocket-Version: 13" "https://$DOMAIN$WS_PATH" 2>&1 || echo "Failed to connect")
                if echo "$RESPONSE" | grep -q "101 Switching Protocols"; then
                    echo "VLESS+WS+TLS 测试通过!"
                else
                    echo -e "${RED}VLESS+WS+TLS 测试失败! 响应: $RESPONSE${NC}"
                    echo "Nginx 错误日志:"
                    cat /var/log/nginx/xray_error.log | tail -n 20
                    echo "Xray 错误日志:"
                    cat "$LOG_DIR/error.log" | tail -n 20
                    exit 1
                fi
                ;;
            2) 
                WS_KEY=$(openssl rand -base64 16)
                RESPONSE=$(curl -s -v --http1.1 -H "Host: $DOMAIN" -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: $WS_KEY" -H "Sec-WebSocket-Version: 13" "https://$DOMAIN$VMESS_PATH" 2>&1 || echo "Failed to connect")
                if echo "$RESPONSE" | grep -q "101 Switching Protocols"; then
                    echo "VMess+WS+TLS 测试通过!"
                else
                    echo -e "${RED}VMess+WS+TLS 测试失败! 响应: $RESPONSE${NC}"
                fi
                ;;
            3) 
                RESPONSE=$(curl -s -I "https://$DOMAIN/$GRPC_SERVICE" || echo "Failed to connect")
                if echo "$RESPONSE" | grep -q "200 OK"; then
                    echo "VLESS+gRPC+TLS 测试通过!"
                else
                    echo -e "${RED}VLESS+gRPC+TLS 测试失败! 响应: $RESPONSE${NC}"
                fi
                ;;
            4) 
                RESPONSE=$(curl -s -I "https://$DOMAIN$TCP_PATH" || echo "Failed to connect")
                if echo "$RESPONSE" | grep -q "200 OK"; then
                    echo "VLESS+TCP+TLS 测试通过!"
                else
                    echo -e "${RED}VLESS+TCP+TLS 测试失败! 响应: $RESPONSE${NC}"
                fi
                ;;
        esac
    done
}

# 主安装流程
install_xray() {
    detect_system
    echo -e "${BLUE}=== 全新安装流程 ===${NC}\n"
    echo "[1] 检测系统环境..."
    echo "- 系统: $OS_NAME $OS_VERSION"
    echo "- 架构: $(uname -m)"
    echo "- 内存: $(free -h | awk '/^Mem:/ {print $2}')"
    check_firewall
    echo -e "${GREEN}[3] 选择安装的协议${NC}"
    echo "1. VLESS+WS+TLS (推荐)"
    echo "2. VMess+WS+TLS"
    echo "3. VLESS+gRPC+TLS"
    echo "4. VLESS+TCP+TLS"
    read -p "请选择 (多选用空格分隔, 默认1): " -a PROTOCOLS
    [ ${#PROTOCOLS[@]} -eq 0 ] && PROTOCOLS=(1)
    check_ports
    install_dependencies
    configure_domain
    apply_ssl
    create_default_user
    configure_nginx
    check_xray_version
    configure_xray
    start_services
    show_user_link
    echo -e "\n安装完成! 输入 '$SCRIPT_NAME' 打开管理菜单"
}

# 检查并禁用过期用户
disable_expired_users() {
    echo -e "${GREEN}=== 检查并禁用过期用户 ===${NC}"
    flock -x 200
    TODAY=$(date +%F)
    EXPIRED_USERS=$(jq -r ".users[] | select(.expire != \"永久\" and .expire < \"$TODAY\" and .status == \"启用\") | .uuid" "$USER_DATA")
    if [ -n "$EXPIRED_USERS" ]; then
        cp "$XRAY_CONFIG" "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)"
        cp "$USER_DATA" "$USER_DATA.bak.$(date +%F_%H%M%S)"
        for UUID in $EXPIRED_USERS; do
            jq --arg uuid "$UUID" '.users[] | select(.uuid == $uuid) | .status = "禁用"' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
            for i in {0..3}; do
                jq --arg uuid "$UUID" ".inbounds[$i].settings.clients -= [{\"id\": \$uuid}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置更新失败!${NC}"; cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"; exit 1; }
            done
            echo "用户 UUID $UUID 已禁用（过期日期: $(jq -r ".users[] | select(.uuid == \"$UUID\") | .expire" "$USER_DATA")）"
        done
        if ! jq -e . "$USER_DATA" >/dev/null 2>&1 || ! jq -e . "$XRAY_CONFIG" >/dev/null 2>&1; then
            echo -e "${RED}配置文件损坏，恢复备份!${NC}"
            cp "$USER_DATA.bak.$(date +%F_%H%M%S)" "$USER_DATA"
            cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"
            exit 1
        fi
        echo -e "${YELLOW}正在重启 Xray 以应用禁用用户配置...${NC}"
        systemctl restart "$XRAY_SERVICE_NAME" || { echo -e "${RED}Xray 重启失败!${NC}"; exit 1; }
        echo "过期用户禁用完成并已重启 Xray。"
    else
        echo "没有发现过期用户。"
    fi
    (crontab -l 2>/dev/null; echo "0 0 * * * bash $(realpath $0) --disable-expired") | crontab -
    echo "已设置每天自动检查并禁用过期用户。"
    flock -u 200
}

# 用户管理菜单
user_management() {
    exec 200>$LOCK_FILE
    while true; do
        echo -e "${BLUE}用户管理菜单${NC}"
        echo "1. 新建用户"
        echo "2. 用户列表"
        echo "3. 用户续期"
        echo "4. 删除用户"
        echo "5. 检查并禁用过期用户"
        echo "6. 返回主菜单"
        read -p "请选择操作: " CHOICE
        case "$CHOICE" in
            1) add_user ;;
            2) list_users ;;
            3) renew_user ;;
            4) delete_user ;;
            5) disable_expired_users ;;
            6) break ;;
            *) echo -e "${RED}无效选项!${NC}" ;;
        esac
    done
    exec 200>&-
}

# 新建用户
add_user() {
    echo -e "${GREEN}=== 新建用户流程 ===${NC}"
    flock -x 200
    cp "$XRAY_CONFIG" "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)"
    cp "$USER_DATA" "$USER_DATA.bak.$(date +%F_%H%M%S)"
    read -p "输入用户名: " USERNAME
    UUID=$(uuidgen)
    while jq -r ".users[] | .uuid" "$USER_DATA" 2>/dev/null | grep -q "$UUID"; do
        UUID=$(uuidgen)
    done
    echo -e "\n选择有效期类型:"
    echo "1. 月费 (默认)"
    echo "2. 年费"
    echo "3. 永久"
    read -p "请选择 [默认1]: " EXPIRE_TYPE
    EXPIRE_TYPE=${EXPIRE_TYPE:-1}
    case "$EXPIRE_TYPE" in
        1) EXPIRE_DATE=$(date -d "$(date +%F) +1 month" +%F) ;;
        2) EXPIRE_DATE=$(date -d "$(date +%F) +1 year" +%F) ;;
        3) EXPIRE_DATE="永久" ;;
        *) echo -e "${RED}无效选择，使用默认月费${NC}"; EXPIRE_DATE=$(date -d "$(date +%F) +1 month" +%F) ;;
    esac
    jq --arg name "$USERNAME" --arg uuid "$UUID" --arg expire "$EXPIRE_DATE" \
       '.users += [{"id": (.users | length + 1), "name": $name, "uuid": $uuid, "expire": $expire, "used_traffic": 0, "status": "启用"}]' \
       "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA" || { echo -e "${RED}用户数据保存失败!${NC}"; cp "$USER_DATA.bak.$(date +%F_%H%M%S)" "$USER_DATA"; exit 1; }
    if ! jq -e . "$USER_DATA" >/dev/null 2>&1; then
        echo -e "${RED}用户数据文件损坏，恢复备份!${NC}"
        cp "$USER_DATA.bak.$(date +%F_%H%M%S)" "$USER_DATA"
        exit 1
    fi
    for i in "${!PROTOCOLS[@]}"; do
        jq --arg uuid "$UUID" ".inbounds[$i].settings.clients += [{\"id\": \$uuid$(if [ \"${PROTOCOLS[$i]}\" = \"2\" ]; then echo \", \\\"alterId\\\": 0\"; fi)}]" \
           "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置更新失败!${NC}"; cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"; exit 1; }
    done
    if ! jq -e . "$XRAY_CONFIG" >/dev/null 2>&1; then
        echo -e "${RED}Xray 配置文件损坏，恢复备份!${NC}"
        cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"
        exit 1
    fi
    echo -e "${YELLOW}正在重启 Xray 以应用新用户配置...${NC}"
    systemctl restart "$XRAY_SERVICE_NAME" || { echo -e "${RED}Xray 重启失败!${NC}"; exit 1; }
    WS_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&path=$WS_PATH&sni=$DOMAIN&host=$DOMAIN#$USERNAME"
    echo "用户 $USERNAME 创建成功!"
    echo -e "\n${BLUE}=== 客户端配置信息 ===${NC}\n"
    echo "[二维码]:"
    qrencode -t ansiutf8 "$WS_LINK"
    echo -e "\n链接地址:\n$WS_LINK"
    echo -e "\n订阅链接:\nhttps://subscribe.$DOMAIN/subscribe/$USERNAME.yml"
    echo -e "\nClash 配置链接:\nhttps://subscribe.$DOMAIN/clash/$USERNAME.yml"
    flock -u 200
}

# 用户列表
list_users() {
    echo -e "${BLUE}用户列表:${NC}"
    printf "%-5s %-16s %-36s %-12s %-10s %-8s\n" "ID" "用户名" "UUID" "过期时间" "已用流量" "状态"
    printf "%-5s %-16s %-36s %-12s %-10s %-8s\n" "----" "----------------" "------------------------------------" "-----------" "---------" "-----"
    jq -r '.users[] | "\(.id) \(.name) \(.uuid) \(.expire) \(.used_traffic) \(.status)"' "$USER_DATA" | \
    while read -r id name uuid expire used status; do
        used_fmt=$(awk "BEGIN {printf \"%.2f\", $used/1073741824}")G
        printf "%-5s %-16s %-36s %-12s %-10s %-8s\n" "$id" "$name" "$uuid" "$expire" "$used_fmt" "$status"
    done
}

# 用户续期
renew_user() {
    echo -e "${GREEN}=== 用户续期流程 ===${NC}"
    flock -x 200
    read -p "输入要续期的用户名: " USERNAME
    CURRENT_EXPIRE=$(jq -r ".users[] | select(.name == \"$USERNAME\") | .expire" "$USER_DATA")
    echo "当前有效期: $CURRENT_EXPIRE"
    echo -e "\n选择续期类型:"
    echo "1. 月费 (+1个月)"
    echo "2. 年费 (+1年)"
    echo "3. 永久"
    read -p "请选择 [默认1]: " RENEW_TYPE
    RENEW_TYPE=${RENEW_TYPE:-1}
    case "$RENEW_TYPE" in
        1) NEW_EXPIRE=$(date -d "$CURRENT_EXPIRE +1 month" +%F) ;;
        2) NEW_EXPIRE=$(date -d "$CURRENT_EXPIRE +1 year" +%F) ;;
        3) NEW_EXPIRE="永久" ;;
        *) echo -e "${RED}无效选择，使用默认月费${NC}"; NEW_EXPIRE=$(date -d "$CURRENT_EXPIRE +1 month" +%F) ;;
    esac
    jq --arg name "$USERNAME" --arg expire "$NEW_EXPIRE" \
       '(.users[] | select(.name == $name)).expire = $expire' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
    echo "用户 $USERNAME 已续期至: $NEW_EXPIRE"
    flock -u 200
}

# 删除用户
delete_user() {
    echo -e "${GREEN}=== 删除用户流程 ===${NC}"
    flock -x 200
    cp "$XRAY_CONFIG" "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)"
    cp "$USER_DATA" "$USER_DATA.bak.$(date +%F_%H%M%S)"
    read -p "输入要删除的用户名: " USERNAME
    UUID=$(jq -r ".users[] | select(.name == \"$USERNAME\") | .uuid" "$USER_DATA")
    if [ -n "$UUID" ]; then
        jq "del(.users[] | select(.name == \"$USERNAME\"))" "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA" || { echo -e "${RED}用户数据删除失败!${NC}"; cp "$USER_DATA.bak.$(date +%F_%H%M%S)" "$USER_DATA"; exit 1; }
        if ! jq -e . "$USER_DATA" >/dev/null 2>&1; then
            echo -e "${RED}用户数据文件损坏，恢复备份!${NC}"
            cp "$USER_DATA.bak.$(date +%F_%H%M%S)" "$USER_DATA"
            exit 1
        fi
        for i in {0..3}; do
            jq --arg uuid "$UUID" ".inbounds[$i].settings.clients -= [{\"id\": \$uuid}]" "$XRAY_CONFIG" > tmp.json && mv tmp.json "$XRAY_CONFIG" || { echo -e "${RED}Xray 配置更新失败!${NC}"; cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"; exit 1; }
        done
        if ! jq -e . "$XRAY_CONFIG" >/dev/null 2>&1; then
            echo -e "${RED}Xray 配置文件损坏，恢复备份!${NC}"
            cp "$XRAY_CONFIG.bak.$(date +%F_%H%M%S)" "$XRAY_CONFIG"
            exit 1
        fi
        echo -e "${YELLOW}正在重启 Xray 以应用删除用户配置...${NC}"
        systemctl restart "$XRAY_SERVICE_NAME" || { echo -e "${RED}Xray 重启失败!${NC}"; exit 1; }
        echo "用户 $USERNAME 已删除并重启 Xray。"
    else
        echo -e "${RED}用户 $USERNAME 不存在!${NC}"
    fi
    flock -u 200
}

# 协议管理（多协议支持）
protocol_management() {
    echo -e "${GREEN}协议管理:${NC}"
    echo "1. VLESS+WS+TLS (推荐)"
    echo "2. VMess+WS+TLS"
    echo "3. VLESS+gRPC+TLS"
    echo "4. VLESS+TCP+TLS"
    read -p "请选择 (多选用空格分隔, 默认1): " -a PROTOCOLS
    [ ${#PROTOCOLS[@]} -eq 0 ] && PROTOCOLS=(1)
    configure_nginx
    configure_xray
    systemctl restart nginx "$XRAY_SERVICE_NAME" || { echo -e "${RED}服务重启失败!${NC}"; exit 1; }
    for PROTOCOL in "${PROTOCOLS[@]}"; do
        case "$PROTOCOL" in
            1) echo "配置 VLESS+WS+TLS 成功! (端口: 443)" ;;
            2) echo "配置 VMess+WS+TLS 成功! (端口: 443)" ;;
            3) echo "配置 VLESS+gRPC+TLS 成功! (端口: 443)" ;;
            4) echo "配置 VLESS+TCP+TLS 成功! (端口: 443)" ;;
            *) echo -e "${RED}无效选择: $PROTOCOL，跳过${NC}" ;;
        esac
    done
}

# 流量统计（8小时更新）
traffic_stats() {
    echo -e "${BLUE}=== 流量统计 ===${NC}"
    printf "%-16s %-10s %-8s %-8s\n" "用户名" "已用流量" "总流量" "状态"
    printf "%-16s %-10s %-8s %-8s\n" "----------------" "---------" "--------" "-----"
    jq -r '.users[] | "\(.name) \(.used_traffic) \(.status)"' "$USER_DATA" | \
    while read -r name used status; do
        used_fmt=$(awk "BEGIN {printf \"%.2f\", $used/1073741824}")G
        printf "%-16s %-10s %-8s %-8s\n" "$name" "$used_fmt" "无限" "$status"
    done
    if [ -f "$LOG_DIR/access.log" ]; then
        TOTAL_BYTES=$(awk -v uuid="$UUID" '$0 ~ uuid {sum += $NF} END {print sum}' "$LOG_DIR/access.log" || echo "0")
        if [ "$TOTAL_BYTES" != "0" ]; then
            jq --arg uuid "$UUID" --arg bytes "$TOTAL_BYTES" '.users[] | select(.uuid == $uuid) | .used_traffic = ($bytes | tonumber)' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
            echo "已从日志更新流量数据（假设日志含 UUID）。"
        else
            echo "日志中未找到流量数据，使用默认值。"
        fi
    fi
    (crontab -l 2>/dev/null; echo "0 */8 * * * bash -c 'if [ -f $LOG_DIR/access.log ]; then for uuid in \$(jq -r \".users[] | .uuid\" $USER_DATA); do TOTAL_BYTES=\$(awk -v uuid=\"\$uuid\" \"\\\$0 ~ uuid {sum += \\\$NF} END {print sum}\" $LOG_DIR/access.log || echo 0); jq --arg uuid \"\$uuid\" --arg bytes \"\$TOTAL_BYTES\" \".users[] | select(.uuid == \\\$uuid) | .used_traffic = (\\\$bytes | tonumber)\" $USER_DATA > tmp.json && mv tmp.json $USER_DATA; done; fi'") | crontab -
    echo "流量统计已设置为每8小时更新一次（需日志支持 UUID）。"
}

# 备份恢复
backup_restore() {
    echo -e "${GREEN}=== 备份管理 ===${NC}"
    echo "1. 创建备份"
    echo "2. 恢复备份"
    echo "3. 返回主菜单"
    read -p "请选择: " CHOICE
    case "$CHOICE" in
        1)
            BACKUP_FILE="$BACKUP_DIR/xray_backup_$(date +%F).tar.gz"
            tar -czf "$BACKUP_FILE" "$XRAY_CONFIG" "$USER_DATA" "$CERTS_DIR" >/dev/null 2>&1
            echo -e "\n备份已创建至: $BACKUP_FILE"
            echo "包含: 用户数据/配置/证书"
            ;;
        2)
            echo -e "\n可用备份列表:"
            ls -lh "$BACKUP_DIR" | awk '/xray_backup/{print "- " $9 " (" $6 " " $7 " " $8 ")"}'
            read -p "输入要恢复的备份文件名: " BACKUP_FILE
            if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
                tar -xzf "$BACKUP_DIR/$BACKUP_FILE" -C / >/dev/null 2>&1
                read -p "是否更换域名? [y/N]: " CHANGE_DOMAIN
                if [[ "$CHANGE_DOMAIN" =~ ^[Yy] ]]; then
                    read -p "输入新域名: " NEW_DOMAIN
                    sed -i "s/$DOMAIN/$NEW_DOMAIN/g" "$XRAY_CONFIG" "$NGINX_CONF"
                    certbot certonly --nginx -d "$NEW_DOMAIN" --non-interactive --agree-tos -m "admin@$NEW_DOMAIN" >/dev/null 2>&1
                    DOMAIN="$NEW_DOMAIN"
                    echo "证书申请中... 成功!"
                    echo "订阅链接已更新: https://subscribe.$NEW_DOMAIN"
                fi
                systemctl restart nginx "$XRAY_SERVICE_NAME" || { echo -e "${RED}服务重启失败!${NC}"; exit 1; }
                echo "备份恢复完成!"
            else
                echo -e "${RED}备份文件不存在!${NC}"
            fi
            ;;
        3) return ;;
        *) echo -e "${RED}无效选择!${NC}" ;;
    esac
}

# 脚本入口
if [ "$1" = "--disable-expired" ]; then
    detect_system
    detect_xray_service
    disable_expired_users
else
    main_menu
fi
