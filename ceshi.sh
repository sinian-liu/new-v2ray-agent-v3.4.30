#!/bin/bash
set -e

BASE_DIR="/home/web/html"
APP_DIR="$BASE_DIR/web5"

echo "开始安装独角数卡到 $APP_DIR"

# 创建目录并下载解压
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "下载独角数卡 2.0.6-antibody 版本"
wget -q https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz

echo "解压安装包..."
tar -zxvf 2.0.6-antibody.tar.gz
rm 2.0.6-antibody.tar.gz

echo "设置目录权限"
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

# 创建.env文件交互配置
ENV_FILE="$APP_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "生成配置文件 .env"
  read -rp "请输入站点名称（默认 Dujiaoka）: " APP_NAME
  APP_NAME=${APP_NAME:-Dujiaoka}

  read -rp "请输入站点URL（默认 http://localhost）: " APP_URL
  APP_URL=${APP_URL:-http://localhost}

  read -rp "请输入数据库名称（默认 dujiaoka）: " DB_DATABASE
  DB_DATABASE=${DB_DATABASE:-dujiaoka}

  read -rp "请输入数据库用户名（默认 dujiaoka）: " DB_USERNAME
  DB_USERNAME=${DB_USERNAME:-dujiaoka}

  read -rp "请输入数据库密码（默认 dujiaoka_pass）: " DB_PASSWORD
  DB_PASSWORD=${DB_PASSWORD:-dujiaoka_pass}

  read -rp "是否开启调试模式？(true/false，默认 false): " APP_DEBUG
  APP_DEBUG=${APP_DEBUG:-false}

  cat > "$ENV_FILE" <<EOF
APP_NAME=$APP_NAME
APP_ENV=production
APP_KEY=
APP_DEBUG=$APP_DEBUG
APP_URL=$APP_URL

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120
EOF
else
  echo ".env 文件已存在，跳过生成。"
fi

# Docker Compose 文件自动生成
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

cat > "$COMPOSE_FILE" <<EOF
version: "3.8"
services:
  dujiaoka:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    working_dir: /var/www/html
    volumes:
      - ./:/var/www/html
    depends_on:
      - mysql

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - dujiaoka

  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: $DB_DATABASE
      MYSQL_USER: $DB_USERNAME
      MYSQL_PASSWORD: $DB_PASSWORD
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
EOF

# 生成 nginx.conf
NGINX_CONF="$APP_DIR/nginx.conf"
cat > "$NGINX_CONF" <<'EOF'
server {
    listen 80;
    server_name localhost;

    root /var/www/html/public;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass dujiaoka-php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

echo "启动容器..."
cd "$APP_DIR"
docker-compose up -d

echo
echo "独角数卡已启动！"
echo "访问地址请打开 http://服务器IP 或 域名"
echo
echo "首次运行需要进入PHP容器初始化数据库，执行以下命令："
echo "docker exec -it dujiaoka-php bash"
echo "php artisan key:generate"
echo "php artisan migrate --seed"
echo
echo "如果是首次运行，请务必执行上述初始化命令！"
