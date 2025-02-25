#!/bin/bash
# Xray 高级管理脚本完整版 v7.0
# 支持：Ubuntu/Debian/CentOS
# 功能：多协议/用户管理/自动证书/流量统计
# 最后更新：2024年3月24日

# 配置常量
readonly XRAY_CONFIG="/usr/local/etc/xray/config.json"
readonly USER_DATA="/usr/local/etc/xray/users.json"
readonly CERTS_DIR="/etc/letsencrypt/live"
readonly LOG_DIR="/var/log/xray"
readonly NGINX_CONF_DIR="/etc/nginx/conf.d"

# 颜色定义
readonly RED='\033[31m'    GREEN='\033[32m'
readonly YELLOW='\033[33m' BLUE='\033[36m' 
readonly NC='\033[0m'

# 初始化环境
init_environment() {
    [ "$EUID" -ne 0 ] && echo -e "${RED}请使用root权限运行脚本!${NC}" && exit 1
    
    # 识别系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}不支持的操作系统!${NC}"
        exit 1
    fi

    # 创建必要目录
    mkdir -p "$LOG_DIR" "$(dirname "$USER_DATA")" /var/www/subscribe
    chmod 700 "$LOG_DIR"
    chown nobody:nogroup "$LOG_DIR"
}

# 系统服务管理
service_manager() {
    case $1 in
        start)
            systemctl start nginx
            systemctl start "$XRAY_SERVICE"
            systemctl enable nginx "$XRAY_SERVICE" >/dev/null 2>&1 
            ;;
        restart)
            systemctl restart nginx
            systemctl restart "$XRAY_SERVICE"
            ;;
        status)
            systemctl status "$XRAY_SERVICE" | grep -B10 -A10 "Active:"
            ;;
    esac
}

# 安装系统依赖
install_dependencies() {
    echo -e "${GREEN}[1] 安装系统依赖...${NC}"
    
    # 通用依赖
    local common_pkgs=("curl" "wget" "jq" "qrencode" "openssl" "net-tools" "socat" "unzip")
    
    # 系统特定依赖
    case $OS in
        ubuntu|debian)
            if ! dpkg -l | grep -q apt-transport-https; then
                apt-get install -y -qq apt-transport-https
            fi
            apt-get update -qq
            apt-get install -y -qq "${common_pkgs[@]}" uuid-runtime nginx certbot python3-certbot-nginx
            ;;
        centos|fedora)
            yum install -y -q epel-release
            yum install -y -q "${common_pkgs[@]}" util-linux nginx certbot python3-certbot-nginx
            ;;
        *)
            echo -e "${RED}不支持的发行版!${NC}"
            exit 1 
            ;;
    esac

    # 安装Xray核心
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

# 动态检测Xray服务名
detect_xray_service() {
    local service_name
    service_name=$(systemctl list-units --type=service --all | grep -E 'xray(.service)?' | awk '{print $1}')
    
    if [ -z "$service_name" ]; then
        echo -e "${RED}未检测到Xray服务!${NC}"
        exit 1
    fi
    echo "$service_name"
}

# 配置防火墙
configure_firewall() {
    echo -e "${GREEN}[2] 配置防火墙...${NC}"
    
    case $OS in
        ubuntu|debian)
            if command -v ufw &>/dev/null; then
                ufw allow 80/tcp
                ufw allow 443/tcp
                ufw --force enable
            fi
            ;;
        centos|fedora)
            if command -v firewall-cmd &>/dev/null; then
                firewall-cmd --permanent --add-service={http,https}
                firewall-cmd --reload
            fi
            ;;
    esac
}

# 协议配置模板
generate_protocol_config() {
    local protocol=$1 port=$2 path=$3
    case $protocol in
        vless_ws)
            cat >> $XRAY_CONFIG <<EOF
        {
            "port": $port,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "$CERTS_DIR/$DOMAIN/fullchain.pem",
                        "keyFile": "$CERTS_DIR/$DOMAIN/privkey.pem"
                    }]
                },
                "wsSettings": {
                    "path": "$path",
                    "headers": {"Host": "$DOMAIN"}
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http","tls"]
            }
        },
EOF
            ;;
        vless_grpc)
            cat >> $XRAY_CONFIG <<EOF
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [{
                        "certificateFile": "$CERTS_DIR/$DOMAIN/fullchain.pem",
                        "keyFile": "$CERTS_DIR/$DOMAIN/privkey.pem"
                    }]
                },
                "grpcSettings": {
                    "serviceName": "$path",
                    "multiMode": true
                }
            }
        },
EOF
            ;;
    esac
}

# 生成Xray配置
generate_xray_config() {
    echo -e "${GREEN}[3] 生成Xray配置...${NC}"
    
    cat > $XRAY_CONFIG <<EOF
{
    "log": {
        "loglevel": "warning",
        "access": "$LOG_DIR/access.log",
        "error": "$LOG_DIR/error.log"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
EOF

    # 动态添加协议
    local port=10000
    for proto in "${SELECTED_PROTOCOLS[@]}"; do
        case $proto in
            1)
                generate_protocol_config "vless_ws" $port "/$(openssl rand -hex 6)"
                ((port++)) ;;
            2)
                generate_protocol_config "vless_grpc" $port "$(openssl rand -hex 3)-grpc"
                ((port++)) ;;
        esac
    done

    cat >> $XRAY_CONFIG <<EOF
    ],
    "outbounds": [
        {"protocol": "freedom", "tag": "direct"},
        {"protocol": "blackhole", "tag": "block"}
    ]
}
EOF
}

# 配置Nginx
configure_nginx() {
    echo -e "${GREEN}[4] 配置Nginx代理...${NC}"
    
    local path_ws=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$XRAY_CONFIG")
    local path_grpc=$(jq -r '.inbounds[1].streamSettings.grpcSettings.serviceName' "$XRAY_CONFIG")

    cat > $NGINX_CONF_DIR/xray.conf <<EOF
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
    ssl_protocols TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;
    
    # WebSocket配置
    location ${path_ws} {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    
    # gRPC配置
    location /${path_grpc} {
        grpc_pass grpc://127.0.0.1:10001;
        client_max_body_size 0;
        grpc_set_header Host \$host;
    }
}
EOF

    systemctl reload nginx
}

# 用户管理
user_management() {
    while :; do
        echo -e "\n${BLUE}用户管理菜单${NC}"
        echo "1. 添加用户"
        echo "2. 用户列表"
        echo "3. 删除用户"
        echo "4. 返回主菜单"
        read -rp "请选择操作: " choice

        case $choice in
        1) add_user ;;
        2) list_users ;;
        3) delete_user ;;
        4) break ;;
        *) echo -e "${RED}无效选项!${NC}" ;;
        esac
    done
}

# 添加用户
add_user() {
    while :; do
        read -rp "输入用户名 (支持中文/特殊字符): " username
        [[ "$username" =~ ^[^\\/]*$ ]] && break
        echo -e "${RED}用户名包含非法字符!${NC}"
    done

    # 生成唯一UUID
    while :; do
        uuid=$(uuidgen)
        jq -e ".users[].uuid == \"$uuid\"" "$USER_DATA" &>/dev/null || break
    done

    jq --arg name "$username" \
       --arg uuid "$uuid" \
       '.users += [{"name":$name, "uuid":$uuid, "expire":"permanent", "traffic":0}]' \
       "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"

    echo -e "${GREEN}用户添加成功!${NC}"
    service_manager restart
}

# 用户列表
list_users() {
    printf "%-5s %-16s %-36s %-10s\n" "ID" "用户名" "UUID" "已用流量"
    printf "%-5s %-16s %-36s %-10s\n" "----" "----------------" "------------------------------------" "---------"
    
    jq -r '.users[] | "\(.id) \(.name) \(.uuid) \(.traffic)"' "$USER_DATA" | \
    while read -r id name uuid traffic; do
        printf "%-5s %-16s %-36s %-10s\n" "$id" "$name" "$uuid" "$traffic"
    done
}

# 删除用户
delete_user() {
    read -rp "输入要删除的用户名: " username
    if jq -e ".users[] | select(.name == \"$username\")" "$USER_DATA" &>/dev/null; then
        jq --arg user "$username" 'del(.users[] | select(.name == $user))' "$USER_DATA" > tmp.json && mv tmp.json "$USER_DATA"
        echo -e "${GREEN}用户 $username 已删除!${NC}"
        service_manager restart
    else
        echo -e "${RED}用户 $username 不存在!${NC}"
    fi
}

# 主安装流程
main_install() {
    init_environment
    install_dependencies
    configure_firewall

    # 协议选择
    SELECTED_PROTOCOLS=()
    echo -e "${GREEN}选择协议（多选，空格分隔）:"
    echo "1. VLESS+WS+TLS (推荐)"
    echo "2. VLESS+gRPC+TLS"
    read -rp "请输入选择（示例：1 2）: " -a protocols
    SELECTED_PROTOCOLS=("${protocols[@]}")

    # 域名处理
    while true; do
        read -rp "请输入域名: " DOMAIN
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            break
        fi
        echo -e "${RED}域名格式无效!"
    done

    # 证书申请
    systemctl stop nginx
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN
    systemctl start nginx

    # 生成配置
    generate_xray_config
    configure_nginx
    
    # 初始化用户
    [ ! -f "$USER_DATA" ] && echo '{"users":[]}' > "$USER_DATA"
    add_default_user
    
    # 启动服务
    XRAY_SERVICE=$(detect_xray_service)
    service_manager start
    
    # 显示初始用户信息
    show_client_config
}

# 显示客户端配置
show_client_config() {
    local user_info=$(jq -r '.users[0]' "$USER_DATA")
    local uuid=$(jq -r '.uuid' <<< "$user_info")
    local path_ws=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$XRAY_CONFIG")
    
    echo -e "\n${BLUE}=== 客户端配置信息 ===${NC}"
    echo -e "${GREEN}链接地址：${NC}"
    echo "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&path=${path_ws#/}&host=$DOMAIN#自用"
    
    echo -e "\n${GREEN}订阅链接：${NC}"
    echo "https://subscribe.$DOMAIN/subscribe/自用.yml"
    
    echo -e "\n${YELLOW}二维码：${NC}"
    qrencode -t ANSIUTF8 "vless://$uuid@$DOMAIN:443?encryption=none&security=tls&type=ws&path=${path_ws#/}&host=$DOMAIN#自用"
}

# 启动入口
case "$1" in
    install) main_install ;;
    manage) user_management ;;
    *) 
        echo -e "使用方法: $0 [install|manage]"
        echo -e "\n可选命令:"
        echo "  install  全新安装"
        echo "  manage   用户管理"
        exit 1
        ;;
esac
