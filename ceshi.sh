#!/bin/bash

echo "===== 独角数卡 Docker 安装器 ====="

# 获取用户输入
read -p "站点名称 (APP_NAME) [dd]: " APP_NAME
APP_NAME=${APP_NAME:-dd}

read -p "域名 (不含 http) [localhost]: " APP_URL
APP_URL=${APP_URL:-localhost}

read -p "数据库名 [db]: " DB_DATABASE
DB_DATABASE=${DB_DATABASE:-db}

read -p "数据库用户名 [root]: " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-root}

read -p "数据库密码: " DB_PASSWORD

read -p "Redis 密码 (可留空): " REDIS_PASSWORD

read -p "安装路径 (默认 /home/web/html/web5): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/home/web/html/web5}

# 安装依赖
echo ">>> 检查并安装必要依赖..."
apt update && apt install -y curl git sudo

# 安装 Docker
if ! command -v docker &>/dev/null; then
  echo ">>> 安装 Docker..."
  curl -fsSL https://get.docker.com | bash
fi

# 安装 Docker Compose 插件
if ! docker compose version &>/dev/null; then
  echo ">>> 安装 Docker Compose 插件..."
  apt install docker-compose-plugin -y
fi

# 创建目录
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH" || exit 1

# 下载源码
echo ">>> 克隆独角数卡代码..."
git clone https://github.com/assimon/dujiaoka.git dujiaoka
cd dujiaoka || exit 1

# 创建必须目录
mkdir -p public/uploads
chmod -R 755 public/uploads

# 生成 .env
cat >.env <<EOF
APP_NAME=${APP_NAME}
APP_URL=http://${APP_URL}
APP_DEBUG=true

DB_CONNECTION=mysql
DB_HOST=dujiaoka-mysql
DB_PORT=3306
DB_DATABASE=${DB_DATABASE}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}

REDIS_HOST=dujiaoka-redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=6379
EOF

# 生成 docker-compose.yml
cat >../docker-compose.yml <<EOF
services:
  dujiaoka-php:
    image: sinian/dujiaoka-php:latest
    container_name: dujiaoka-php
    volumes:
      - ./dujiaoka:/var/www/html
    depends_on:
      - dujiaoka-mysql
      - dujiaoka-redis

  dujiaoka-nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./dujiaoka:/var/www/html
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - dujiaoka-php

  dujiaoka-mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql

  dujiaoka-redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data

volumes:
  mysql_data:
  redis_data:
EOF

# 生成 nginx.conf
cat >../nginx.conf <<EOF
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name ${APP_URL};

        root /var/www/html/public;
        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass dujiaoka-php:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF

# 回到 docker-compose 根目录
cd "$INSTALL_PATH" || exit 1

# 启动容器
echo ">>> 启动 Docker 容器..."
docker compose up -d

echo "✅ 安装完成！请访问：http://${APP_URL} 继续设置独角数卡"
