#!/bin/bash
# Xray 高级管理脚本 v6.0
# 支持：Ubuntu/Debian/CentOS
# 功能：多协议支持/用户管理/自动证书/流量统计
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
    mkdir -p "$LOG_DIR" "$(dirname "$USER_DATA")"
    chmod 700 "$LOG_DIR"
    chown nobody:nogroup "$LOG_DIR"
}

# 系统服务管理
service_manager() {
    case $1 in
        start)
            systemctl start nginx
            systemctl start "$XRAY_SERVICE"
            systemctl enable nginx "$XRAY_SERVICE" >/dev/null 2>&1 ;;
        restart)
            systemctl restart nginx
            systemctl restart "$XRAY_SERVICE" ;;
        status)
            systemctl status "$XRAY_SERVICE" | grep -B10 -A10 "Active:" ;;
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
            apt-get update -qq
            apt-get install -y -qq "${common_pkgs[@]}" uuid-runtime nginx certbot python3-certbot-nginx ;;
        centos|fedora)
            yum install -y -q epel-release
            yum install -y -q "${common_pkgs[@]}" util-linux nginx certbot python3-certbot-nginx ;;
        *)
            echo -e "${RED}不支持的发行版!${NC}"
            exit 1 ;;
    esac

    # 安装Xray核心
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

# 动态检测Xray服务名
detect_xray_service() {
    local service_name
    service_name=$(systemctl list-units --type=service --all | grep -E 'xray(.service)?' | awk '{print $1}')
    
    [ -z "$service_name" ] && echo -e "${RED}未检测到Xray服务!${NC}" && exit 1
    echo "$service_name"
}

# 配置防火墙
configure_firewall() {
    echo -e "${GREEN}[2] 配置防火墙...${NC}"
    
    case $OS in
        ubuntu|debian)
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw --force enable ;;
        centos|fedora)
            firewall-cmd --permanent --add-service={http,https}
            firewall-cmd --reload ;;
    esac
}

# 协议配置模板
generate_protocol_config() {
    local protocol=$1
    local port=$2
    local path=$3
    
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
                    "path": "$path"
                }
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
                    "serviceName": "$path"
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

# 添加用户（增强验证）
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

# 用户列表（对齐优化）
list_users() {
    printf "%-5s %-16s %-36s %-12s %-10s\n" "ID" "用户名" "UUID" "过期时间" "已用流量"
    printf "%-5s %-16s %-36s %-12s %-10s\n" "----" "----------------" "------------------------------------" "-----------" "---------"
    
    jq -r '.users[] | "\(.id) \(.name) \(.uuid) \(.expire) \(.traffic)"' "$USER_DATA" | \
    while read -r id name uuid expire traffic; do
        printf "%-5s %-16s %-36s %-12s %-10s\n" "$id" "$name" "$uuid" "$expire" "$traffic"
    done
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
    read -rp "请输入域名: " DOMAIN
    validate_domain

    # 证书申请
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN

    # 生成配置
    generate_xray_config
    configure_nginx

    # 初始化用户
    [ ! -f "$USER_DATA" ] && echo '{"users":[]}' > "$USER_DATA"
    add_default_user

    # 启动服务
    XRAY_SERVICE=$(detect_xray_service)
    service_manager start
}

# 启动脚本
case $1 in
    install) main_install ;;
    manage) user_management ;;
    *) echo -e "使用方法: $0 [install|manage]" ;;
esac
