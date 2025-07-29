#!/bin/bash

set -e

echo "🧙 欢迎使用 Dujiaoka 一键部署脚本"

# 用户输入
read -p "请输入项目部署目录（默认 dujiaoka）: " PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-dujiaoka}

read -p "设置 MySQL 数据库密码（默认 123456）: " MYSQL_PASSWORD
MYSQL_PASSWORD=${MYSQL_PASSWORD:-123456}

read -p "请确认是否继续安装？(yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ 已取消安装"
  exit 1
fi

echo "📁 正在创建项目目录..."
mkdir -p "$PROJECT_DIR"/{public,storage}
mkdir -p "$PROJECT_DIR/mysql"

echo "🌐 正在克隆 Dujiaoka 项目源码..."
git clone https://github.com/assimon/dujiaoka "$PROJECT_DIR/code" || true

echo "⚙️ 正在生成 .env 配置..."
cat > "$PROJECT_DIR/code/.env" <<EOF
APP_NAME=dujiaoka
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=root
DB_PASSWORD=$MYSQL_PASSWORD

REDIS_HOST=redis
REDIS_PASSWORD=null
EOF

echo "📝 生成 nginx.conf..."
cat > "$PROJECT_DIR/nginx.conf" <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

echo "🧱 生成 docker-compose.yml..."
cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
version: '3'

services:
  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    restart: always
    working_dir: /var/www/html
    volumes:
      - ./code:/var/www/html
    depends_on:
      - mysql

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./code:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php

  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_PASSWORD
      MYSQL_DATABASE: dujiaoka
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    restart: always
EOF

echo "🚀 启动容器中..."
cd "$PROJECT_DIR"
docker-compose up -d

echo "⌛ 等待 MySQL 初始化（约 20s）..."
sleep 20

echo "🎯 正在执行 Laravel 初始化命令..."
docker exec -it dujiaoka-php bash -c "cd /var/www/html && php artisan key:generate && php artisan config:cache"

read -p "是否需要执行 php artisan migrate 初始化数据库？(yes/no): " MIGRATE_CONFIRM
if [[ "$MIGRATE_CONFIRM" == "yes" ]]; then
  docker exec -it dujiaoka-php bash -c "cd /var/www/html && php artisan migrate --force"
fi

IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "✅ 安装完成！请访问：http://$IP"

echo "📋 检查 Nginx 服务状态..."
docker logs dujiaoka-nginx 2>&1 | grep -i 'error' || echo "✅ 无错误日志"
