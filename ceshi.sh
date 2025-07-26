```bash
#!/usr/bin/env bash

# 调试模式：显示错误和命令
set -e
echo "脚本开始执行：$(date)"

# 检查 tee 是否存在
if ! command -v tee &> /dev/null; then
    echo "错误：tee 未安装，正在安装..."
    apt update -y && apt install -y coreutils || { echo "安装 coreutils 失败！"; exit 1; }
fi

# 日志输出到文件
exec > >(tee -a /var/log/dujiaoka_install.log) 2>&1

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要 root 权限运行，请使用 sudo 或切换到 root 用户。"
    exit 1
fi

# 检查基本依赖
if ! command -v curl &> /dev/null; then
    echo "错误：curl 未安装，正在安装..."
    apt update -y && apt install -y curl || { echo "安装 curl 失败！"; exit 1; }
fi

# 设置变量
INSTALL_DIR="/root/data/docker_data/shop"
DOMAIN=""
EMAIL=""
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS=$(openssl rand -base64 12)
APP_NAME="独角数卡"
APP_KEY="base64:rKwRuI6eRpCw/9e2XZKKGj/Yx3iZy5e7+FQ6+aQl8Zg="
PORT="8090"
USE_DOMAIN="n"
SERVER_IP=$(curl -s ip.sb || echo "unknown")

# 检查 SERVER_IP 是否获取成功
if [ "$SERVER_IP" = "unknown" ]; then
    echo "警告：无法获取服务器 IP，尝试备用方法..."
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        echo "错误：无法确定服务器 IP，请检查网络连接！"
        exit 1
    fi
fi
echo "服务器 IP：$SERVER_IP"

# 提示用户是否使用域名
read -p "是否使用域名访问？(y/n，默认 n，使用 IP: $SERVER_IP): " USE_DOMAIN
USE_DOMAIN=${USE_DOMAIN:-n}
if [ "$USE_DOMAIN" = "y" ]; then
    read -p "请输入你的域名（例如：shop.example.com）: " DOMAIN
    if ! [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "错误：无效的域名格式！"
        exit 1
    fi
    read -p "请输入你的邮箱（用于 Let's Encrypt 证书通知）： " EMAIL
    if [ -z "$EMAIL" ]; then
        echo "错误：邮箱不能为空！"
        exit 1
    fi
else
    DOMAIN="$SERVER_IP"
fi
read -p "请输入外部端口（默认 8090，输入 0 使用 80 端口）： " INPUT_PORT
if [ "$INPUT_PORT" != "0" ] && ! [[ $INPUT_PORT =~ ^[0-9]+$ ]] || [ "$INPUT_PORT" -lt 0 ] || [ "$INPUT_PORT" -gt 65535 ]; then
    echo "无效的端口号，使用默认端口 8090"
else
    [ "$INPUT_PORT" != "0" ] && PORT="$INPUT_PORT"
fi

# 检查域名解析（仅当使用域名时）
if [ "$USE_DOMAIN" = "y" ]; then
    if ! ping -c 1 $DOMAIN &> /dev/null; then
        echo "警告：域名 $DOMAIN 未解析到当前服务器，请确保 DNS 设置正确！"
        read -p "是否继续？(y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            exit 1
        fi
    fi
fi

# 检查端口占用（使用 ss 或安装 net-tools）
if ! command -v ss &> /dev/null && ! command -v netstat &> /dev/null; then
    echo "安装 net-tools 以检查端口占用..."
    apt update -y && apt install -y net-tools || { echo "安装 net-tools 失败！"; exit 1; }
fi
if [ "$PORT" = "80" ]; then
    if ss -tuln | grep -q ":80 " || netstat -tuln | grep -q ":80 "; then
        echo "错误：80 端口已被占用！"
        ss -tuln | grep ":80 " || netstat -tuln | grep ":80 "
        echo "请释放 80 端口或选择其他端口。"
        exit 1
    fi
else
    if ss -tuln | grep -q ":$PORT " || netstat -tuln | grep -q ":$PORT "; then
        echo "错误：端口 $PORT 已被占用！"
        ss -tuln | grep ":$PORT " || netstat -tuln | grep ":$PORT "
        echo "请释放 $PORT 端口或选择其他端口。"
        exit 1
    fi
fi

# 检查并安装依赖工具
if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo "正在安装 curl、lsof、Docker 和 Docker Compose..."
    if [[ -f /etc/redhat-release ]]; then
        yum install -y epel-release curl lsof || { echo "安装 curl 或 lsof 失败！"; exit 1; }
        curl -fsSL https://get.docker.com | sh || { echo "安装 Docker 失败！"; exit 1; }
        systemctl start docker
        systemctl enable docker
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "安装 Docker Compose 失败！"; exit 1; }
        chmod +x /usr/local/bin/docker-compose
    elif [[ -f /etc/lsb-release || -f /etc/debian_version ]]; then
        apt update -y && apt install -y curl lsof || { echo "安装 curl 或 lsof 失败！"; exit 1; }
        curl -fsSL https://get.docker.com | sh || { echo "安装 Docker 失败！"; exit 1; }
        systemctl start docker
        systemctl enable docker
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "安装 Docker Compose 失败！"; exit 1; }
        chmod +x /usr/local/bin/docker-compose
    else
        echo "错误：不支持的操作系统！"
        exit 1
    fi
fi

# 创建安装目录
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR || { echo "错误：无法进入目录 $INSTALL_DIR！"; exit 1; }
mkdir -p storage uploads mysql redis
if [ "$USE_DOMAIN" = "y" ]; then
    mkdir -p certbot/www letsencrypt
fi
chmod -R 777 storage uploads
touch env.conf
chmod -R 777 env.conf

# 创建 env.conf
echo "正在创建 env.conf 文件..."
if [ "$USE_DOMAIN" = "y" ]; then
    APP_URL="https://${DOMAIN}"
else
    APP_URL="http://${DOMAIN}:${PORT}"
fi
cat > env.conf <<EOF
APP_NAME=$APP_NAME
APP_ENV=local
APP_KEY=$APP_KEY
APP_DEBUG=true
APP_URL=$APP_URL

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
ADMIN_HTTPS=$([ "$USE_DOMAIN" = "y" ] && echo "true" || echo "false")
EOF

# 创建 Nginx 配置文件
echo "正在创建 nginx.conf 文件..."
if [ "$USE_DOMAIN" = "y" ]; then
    cat > nginx.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/certbot;
    location /.well-known/acme-challenge/ {
        allow all;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://web:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade-Insecure-Requests 1;
        proxy_set_header X-Forwarded-Proto https;
        rewrite ^/(.*)$ /\$1 break;
    }
}
EOF
else
    cat > nginx.conf <<EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://web:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        rewrite ^/(.*)$ /\$1 break;
    }
}
EOF
fi

# 创建 Docker Compose 配置文件
echo "正在创建 docker-compose.yml 文件..."
cat > docker-compose.yml <<EOF
version: "3"
services:
  web:
    image: stilleshan/dujiaoka
    container_name: web
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./Uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
EOF
if [ "$USE_DOMAIN" = "y" ]; then
    cat >> docker-compose.yml <<EOF
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
EOF
fi
cat >> docker-compose.yml <<EOF
    ports:
      - $PORT:80
EOF
if [ "$USE_DOMAIN" = "y" ]; then
    cat >> docker-compose.yml <<EOF
      - 443:443
EOF
fi
cat >> docker-compose.yml <<EOF
    restart: always
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka_network

  db:
    image: mariadb:focal
    container_name: faka-data
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASS
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASS
    volumes:
      - ./mysql:/var/lib/mysql
    restart: always
    networks:
      - dujiaoka_network

  redis:
    image: redis:alpine
    container_name: faka-redis
    volumes:
      - ./redis:/data
    restart: always
    networks:
      - dujiaoka_network
EOF
if [ "$USE_DOMAIN" = "y" ]; then
    cat >> docker-compose.yml <<EOF

  certbot:
    image: certbot/certbot:latest
    container_name: faka-certbot
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"
    networks:
      - dujiaoka_network
EOF
fi
cat >> docker-compose.yml <<EOF

networks:
  dujiaoka_network:
    driver: bridge
EOF

# 调试：打印生成的 docker-compose.yml
echo "调试：生成的 docker-compose.yml 内容如下："
cat docker-compose.yml

# 验证 Docker Compose 配置
echo "正在验证 Docker Compose 配置..."
docker-compose config || { echo "错误：Docker Compose 配置文件格式错误！请检查 $INSTALL_DIR/docker-compose.yml"; exit 1; }

# 获取 Let's Encrypt 证书（仅当使用域名时）
if [ "$USE_DOMAIN" = "y" ]; then
    echo "正在获取 Let's Encrypt 证书..."
    docker-compose up -d web || { echo "错误：Web 服务启动失败！"; exit 1; }
    docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot --email $EMAIL --agree-tos --no-eff-email -d $DOMAIN || { echo "错误：Let's Encrypt 证书获取失败！请检查域名解析或网络！"; exit 1; }
else
    echo "无域名模式，跳过 Let's Encrypt 证书申请..."
    docker-compose up -d web || { echo "错误：Web 服务启动失败！"; exit 1; }
fi

# 修改配置以禁用安装模式
echo "正在修改配置以禁用安装模式..."
sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yml
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf

# 启动所有 Docker 容器
echo "正在启动 Docker 容器..."
docker-compose up -d || { echo "错误：Docker Compose 启动失败！"; exit 1; }

# 输出完成信息
echo "独角数卡安装完成！"
if [ "$USE_DOMAIN" = "y" ]; then
    echo "请访问 https://${DOMAIN} 进行网页端安装配置。"
else
    echo "请访问 http://${DOMAIN}:${PORT} 进行网页端安装配置。"
fi
echo "网页安装时，数据库 host 填 'db'，Redis 填 'redis'，端口保持默认 3306。"
echo "安装完成后，访问后台：$( [ "$USE_DOMAIN" = "y" ] && echo "https://${DOMAIN}/admin" || echo "http://${DOMAIN}:${PORT}/admin" )"
echo "默认账户：admin"
echo "默认密码：admin"
echo "数据库信息："
echo "  数据库名：$DB_NAME"
echo "  用户名：$DB_USER"
echo "  密码：$DB_PASS"
if [ "$USE_DOMAIN" = "y" ]; then
    echo "Let's Encrypt 邮箱：$EMAIL"
fi
echo "日志文件：/var/log/dujiaoka_install.log"
echo "请妥善保存以上信息，并立即修改默认账户密码！"
echo "脚本执行完成：$(date)"
```
