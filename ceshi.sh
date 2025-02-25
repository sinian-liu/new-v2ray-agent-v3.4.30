#!/bin/bash
# Xray 高级管理脚本
# 版本: v1.10.5-fix7
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
    chown nobody:nogroup "$LOG_DIR" "$SUBSCRIPTION_DIR" "$BACKUP_DIR" "/usr/local/etc/xray"
    touch "$LOG_DIR/access.log" "$LOG_DIR/error.log"
    chmod 660 "$LOG_DIR"/*.log
    chown nobody:nogroup "$LOG_DIR"/*.log
    if [ ! -s "$USER_DATA" ] || ! jq -e . "$USER_DATA" >/dev/null 2>&1; then
        echo '{"users": []}' > "$USER_DATA"
        chmod 660 "$USER_DATA"
        chown nobody:nogroup "$USER_DATA"
    fi
    chmod 600 "$XRAY_CONFIG" 2>/dev/null || true
    chown nobody:nogroup "$XRAY_CONFIG" 2>/dev/null || true
    detect_system
    detect_xray_service
    setup_auto_start
    exec 200>$LOCK_FILE
    trap 'rm -f tmp.json; flock -u 200; rm -f $LOCK_FILE' EXIT
}

# 设置脚本和 Xray 重启后自动运行
setup_auto_start() {
    echo "配置 systemd 服务..."
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
    printf "[Unit]\nDescription=Xray Service\nAfter=network.target nss-lookup.target\n\n[Service]\nType=simple\nExecStartPre=/bin/mkdir -p /usr/local/var/log/xray\nExecStartPre=/bin/chown -R nobody:nogroup /usr/local/var/log/xray\nExecStartPre=/bin/chmod -R 770 /usr/local/var/log/xray\nExecStart=%s -config %s\nRestart=always\nRestartSec=5\nUser=nobody\nGroup=nogroup\nLimitNOFILE=51200\nAmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nCapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE\nExecStartPre=/bin/chown nobody:nogroup %s\nExecStartPre=/bin/chmod 600 %s\n\n[Install]\nWantedBy=multi-user.target\n" "$XRAY_BIN" "$XRAY_CONFIG" "$XRAY_CONFIG" "$XRAY_CONFIG" > /etc/systemd/system/$XRAY_SERVICE_NAME.service
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
    if ! nginx -t; then
        echo -e "${RED}Nginx configuration error! Check $NGINX_CONF${NC}"
        cat "$NGINX_CONF"
        exit 1
    fi
    systemctl restart nginx || { echo -e "${RED}Nginx restart failed!${NC}"; exit 1; }
    echo "Nginx configured successfully, paths: $WS_PATH (VLESS+WS), $VMESS_PATH (VMess+WS), $GRPC_SERVICE (gRPC), $TCP_PATH (TCP)"
}

# 配置 Xray 核心（多协议支持）
configure_xray() {
    echo -e "${GREEN}[6] Configuring Xray core...${NC}"
    cat > "$XRAY_CONFIG" <<EOF
{
    "log": {
        "loglevel": "debug",
        "access": "/usr/local/var/log/xray/access.log",
        "error": "/usr/local/var/log/xray/error.log"
    },
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
    configure_nginx
    check_xray_version
    configure_xray
    systemctl restart "$XRAY_SERVICE_NAME" || { echo -e "${RED}Xray 服务启动失败!${NC}"; exit 1; }
    echo "安装完成!"
}

# 脚本入口
main_menu
