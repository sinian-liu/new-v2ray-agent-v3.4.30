#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限运行，请使用 sudo 或切换到 root 用户。"
    exit 1
fi

# 设置变量
INSTALL_DIR="/opt/dujiaoka"
DOMAIN=""
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS=$(openssl rand -base64 12)  # 随机生成数据库密码
EMAIL=""  # Let's Encrypt 邮箱
PHP_VERSION="8.0"  # 默认 PHP 8.0，动态检查后可能调整

# 提示用户输入域名和邮箱
read -p "请输入你的域名（例如：store.example.com）: " DOMAIN
if ! [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "无效的域名格式！"
    exit 1
fi
read -p "请输入你的邮箱（用于 Let's Encrypt 证书通知）: " EMAIL
if [ -z "$EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 1
fi

# 检查并安装 jq（用于解析 GitHub API）
if ! command -v jq &> /dev/null; then
    echo "正在安装 jq..."
    if [[ -f /etc/redhat-release ]]; then
        yum install -y epel-release && yum install -y jq
    elif [[ -f /etc/lsb-release || -f /etc/debian_version ]]; then
        apt update -y && apt install -y jq
    else
        echo "不支持的操作系统！"
        exit 1
    fi
fi

# 动态获取独角数卡最新版本
echo "正在获取独角数卡最新版本..."
DUJIAOKA_VERSION=$(curl -s https://api.github.com/repos/assimon/dujiaoka/releases/latest | jq -r .tag_name | sed 's/v//')
if [ -z "$DUJIAOKA_VERSION" ]; then
    echo "无法获取独角数卡最新版本，使用默认版本 2.0.6"
    DUJIAOKA_VERSION="2.0.6"
fi
DUJIAOKA_URL="https://github.com/assimon/dujiaoka/archive/refs/tags/v${DUJIAOKA_VERSION}.tar.gz"

# 检查独角数卡 PHP 版本要求（假设通过 README 或 composer.json）
echo "正在检查独角数卡 PHP 版本要求..."
COMPOSER_JSON=$(curl -s https://raw.githubusercontent.com/assimon/dujiaoka/v${DUJIAOKA_VERSION}/composer.json)
PHP_MIN_VERSION=$(echo "$COMPOSER_JSON" | jq -r '.require.php' | grep -oP '\d+\.\d+\.\d+')
if [[ "$PHP_MIN_VERSION" > "$PHP_VERSION" ]]; then
    echo "独角数卡要求 PHP $PHP_MIN_VERSION，升级到 PHP $PHP_MIN_VERSION"
    PHP_VERSION="$PHP_MIN_VERSION"
fi

# 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun || { echo "Docker 安装失败！"; exit 1; }
    systemctl start docker
    systemctl enable docker
fi

# 检查并安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose 未安装，正在安装..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "Docker Compose 安装失败！"; exit 1; }
    chmod +x /usr/local/bin/docker-compose
fi

# 创建安装目录
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 创建 Docker Compose 配置文件
echo "正在创建 Docker Compose 配置文件..."
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  php:
    image: php:${PHP_VERSION}-fpm
    container_name: dujiaoka_php
    volumes:
      - ./dujiaoka:/var/www/html
    depends_on:
      - mysql
    networks:
      - dujiaoka_network

  mysql:
    image: mysql:8.0
    container_name: dujiaoka_mysql
    environment:
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASS}
      MYSQL_ROOT_PASSWORD: ${DB_PASS}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - dujiaoka_network

  nginx:
    image: nginx:latest
    container_name: dujiaoka_nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./dujiaoka:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - php
      - certbot
    networks:
      - dujiaoka_network
    command: "/bin/sh -c 'while :; do sleep 6h & wait \${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"

  certbot:
    image: certbot/certbot:latest
    container_name: dujiaoka_certbot
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \${!}; done;'"
    networks:
      - dujiaoka_network

volumes:
  mysql_data:

networks:
  dujiaoka_network:
    driver: bridge
EOF

# 创建 Nginx 配置文件
echo "正在创建 Nginx 配置文件..."
cat > nginx.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
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
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    root /var/www/html/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# 下载独角数卡源码
echo "正在下载独角数卡 v${DUJIAOKA_VERSION}..."
mkdir -p dujiaoka
wget --tries=3 --timeout=10 -O dujiaoka.tar.gz $DUJIAOKA_URL || { echo "下载独角数卡失败！"; exit 1; }
tar -zxvf dujiaoka.tar.gz -C dujiaoka --strip-components=1 || { echo "解压失败！"; exit 1; }
rm dujiaoka.tar.gz

# 配置 .env 文件
echo "正在配置独角数卡环境文件..."
cp dujiaoka/.env.example dujiaoka/.env || { echo ".env.example 文件不存在！"; exit 1; }
sed -i "s/DB_HOST=.*/DB_HOST=mysql/" dujiaoka/.env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" dujiaoka/.env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" dujiaoka/.env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" dujiaoka/.env
sed -i "s/APP_URL=.*/APP_URL=https:\/\/${DOMAIN}/" dujiaoka/.env

# 安装 Composer 依赖
echo "正在安装 Composer 依赖..."
docker run --rm -v $(pwd)/dujiaoka:/app composer install --working-dir=/app || { echo "Composer 依赖安装失败！"; exit 1; }
docker run --rm -v $(pwd)/dujiaoka:/app composer run-script post-install-cmd --working-dir=/app
docker run --rm -v $(pwd)/dujiaoka:/app php:${PHP_VERSION}-cli php /app/artisan key:generate
docker run --rm -v $(pwd)/dujiaoka:/app php:${PHP_VERSION}-cli php /app/artisan migrate --force

# 设置文件权限
docker run --rm -v $(pwd)/dujiaoka:/var/www/html php:${PHP_VERSION}-fpm chown -R www-data:www-data /var/www/html
docker run --rm -v $(pwd)/dujiaoka:/var/www/html php:${PHP_VERSION}-fpm chmod -R 755 /var/www/html/storage

# 获取 Let's Encrypt 证书
echo "正在获取 Let's Encrypt 证书..."
mkdir -p certbot/www
docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot --email $EMAIL --agree-tos --no-eff-email -d $DOMAIN || { echo "Let's Encrypt 证书获取失败！"; exit 1; }

# 启动 Docker Compose
echo "正在启动 Docker 容器..."
docker-compose up -d || { echo "Docker Compose 启动失败！"; exit 1; }

# 输出完成信息
echo "独角数卡安装完成！"
echo "请访问 https://${DOMAIN} 进行初始化配置。"
echo "后台地址：https://${DOMAIN}/admin"
echo "数据库信息："
echo "  数据库名：${DB_NAME}"
echo "  用户名：${DB_USER}"
echo "  密码：${DB_PASS}"
echo "Let's Encrypt 邮箱：${EMAIL}"
echo "请妥善保存以上信息！"
