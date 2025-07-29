#!/bin/bash
set -e

echo "===== 修复挂载路径的一键安装：独角数卡 Docker 部署 v2.0.6 ====="

# --- 用户交互输入 ---
read -rp "域名 (不含 http，默认为 localhost): " DOMAIN
DOMAIN=${DOMAIN:-localhost}
read -rp "数据库名 (默认 db): " DB_NAME
DB_NAME=${DB_NAME:-db}
read -rp "数据库用户名 (默认 root): " DB_USER
DB_USER=${DB_USER:-root}
read -rsp "数据库密码: " DB_PASS; echo
read -rp "Redis 密码 (可留空): " REDIS_PASS
read -rp "安装路径 (默认 /home/web/html/web5): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/home/web/html/web5}

# --- 安装 Docker Compose 和 Docker（如未安装） ---
apt-get update -y
apt-get install -y curl git sudo docker.io docker-compose

# --- 准备安装目录 ---
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"
rm -rf dujiaoka tmp_dujiaoka

# --- 下载源码 ---
curl -L -o dujiaoka.tar.gz https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
mkdir tmp_dujiaoka
tar -zxvf dujiaoka.tar.gz -C tmp_dujiaoka
rm dujiaoka.tar.gz

# --- 修复路径错误 ---
if [ -d tmp_dujiaoka/dujiaoka/dujiaoka ]; then
  mv tmp_dujiaoka/dujiaoka/dujiaoka ./dujiaoka
elif [ -d tmp_dujiaoka/dujiaoka ]; then
  mv tmp_dujiaoka/dujiaoka ./dujiaoka
else
  echo "❌ 源码结构异常，退出"
  exit 1
fi
rm -rf tmp_dujiaoka

# --- 设置权限与目录 ---
cd dujiaoka
mkdir -p public/uploads storage bootstrap/cache
chmod -R 755 storage bootstrap/cache
chmod -R 777 public/uploads

# --- 创建 .env 文件 ---
cat > .env <<EOF
APP_URL=http://${DOMAIN}
DB_HOST=mysql
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}
REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASS}
APP_DEBUG=false
EOF

# --- 创建 nginx.conf 文件（文件不是目录） ---
cat > nginx.conf <<EOF
user  nginx;
worker_processes  auto;
events { worker_connections 1024; }
http {
  include mime.types;
  sendfile on;
  server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/html/public;
    index index.php;
    location / {
      try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php\$ {
      fastcgi_pass php:9000;
      fastcgi_index index.php;
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
  }
}
EOF

# --- 创建 docker-compose.yml 文件 ---
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASS}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASS}
    volumes:
      - mysql_data:/var/lib/mysql

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    restart: always
    command: redis-server --requirepass "${REDIS_PASS}"
    volumes:
      - redis_data:/data

  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    restart: always
    volumes:
      - ./:/var/www/html

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - php

volumes:
  mysql_data:
  redis_data:
EOF

# --- 启动容器 ---
docker-compose down --remove-orphans || true
docker-compose up -d

echo
echo "✅ 安装完成！请访问：http://${DOMAIN}"
