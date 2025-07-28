#!/bin/bash

set -e

APP_NAME_DEFAULT="Dujiaoka"
APP_NAME=""
DOMAIN=""
DB_NAME=""
DB_USER=""
DB_PASS=""
REDIS_PASS=""
INSTALL_PATH_DEFAULT="/home/web/html/web5"
INSTALL_PATH=""

echo "===== 独角数卡 Docker 安装器（基于 2.0.6-antibody）====="

read -rp "站点名称 (APP_NAME) [${APP_NAME_DEFAULT}]: " APP_NAME
APP_NAME=${APP_NAME:-$APP_NAME_DEFAULT}

read -rp "域名 (不含 http，例如 dujiaoka.com): " DOMAIN
DOMAIN=${DOMAIN:-"localhost"}

read -rp "数据库名 [db]: " DB_NAME
DB_NAME=${DB_NAME:-"db"}

read -rp "数据库用户名 [root]: " DB_USER
DB_USER=${DB_USER:-"root"}

read -rsp "数据库密码: " DB_PASS
echo

read -rp "Redis 密码 (可留空): " REDIS_PASS

read -rp "安装路径 (默认 ${INSTALL_PATH_DEFAULT}): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-$INSTALL_PATH_DEFAULT}

echo ">>> 检查并安装必要依赖..."

apt update -y
apt install -y curl git sudo unzip docker.io docker-compose

echo ">>> 准备安装目录..."

mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# 下载并解压源码
echo ">>> 下载独角数卡源码 v2.0.6..."
curl -L -o dujiaoka.tar.gz https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
tar -zxf dujiaoka.tar.gz
rm dujiaoka.tar.gz

# 解决源码多层 dujiaoka 文件夹问题，统一路径
if [ -d "$INSTALL_PATH/dujiaoka/dujiaoka" ]; then
    echo ">>> 修正多层 dujiaoka 文件夹结构..."
    mv "$INSTALL_PATH/dujiaoka/dujiaoka"/* "$INSTALL_PATH/dujiaoka/"
    rm -rf "$INSTALL_PATH/dujiaoka/dujiaoka"
fi

# 生成 .env 文件
cat > "$INSTALL_PATH/dujiaoka/.env" <<EOF
APP_NAME=$APP_NAME
APP_URL=http://${DOMAIN}
DB_HOST=mysql
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
REDIS_PASSWORD=$REDIS_PASS
EOF
echo ">>> .env 文件生成完成。"

# 生成 nginx.conf 文件（默认配置）
NGINX_CONF_PATH="$INSTALL_PATH/dujiaoka/nginx.conf"
if [ ! -f "$NGINX_CONF_PATH" ]; then
    echo ">>> 生成默认 nginx.conf 文件..."
    cat > "$NGINX_CONF_PATH" <<'EOF'
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        root   /var/www/html/public;
        index  index.php index.html index.htm;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass   php:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
EOF
    echo ">>> nginx.conf 生成完成。"
else
    echo ">>> nginx.conf 文件已存在，跳过生成。"
fi

# 生成 docker-compose.yml 文件
echo ">>> 生成 docker-compose.yml 文件..."
cat > "$INSTALL_PATH/dujiaoka/docker-compose.yml" <<EOF
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
      - mysql-data:/var/lib/mysql
    networks:
      - dujiaoka-net

  redis:
    image: redis:6.2-alpine
    container_name: dujiaoka-redis
    command: redis-server --requirepass "${REDIS_PASS}"
    restart: always
    volumes:
      - redis-data:/data
    networks:
      - dujiaoka-net

  php:
    image: assimon/dujiaoka-php:2.0.6
    container_name: dujiaoka-php
    restart: always
    working_dir: /var/www/html
    volumes:
      - ./dujiaoka:/var/www/html
    networks:
      - dujiaoka-net

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./dujiaoka:/var/www/html
      - ./dujiaoka/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - php
    networks:
      - dujiaoka-net

volumes:
  mysql-data:
  redis-data:

networks:
  dujiaoka-net:
EOF
echo ">>> docker-compose.yml 生成完成。"

# 启动容器
echo ">>> 启动 Docker 容器..."
docker-compose -f "$INSTALL_PATH/dujiaoka/docker-compose.yml" down --remove-orphans || true
docker-compose -f "$INSTALL_PATH/dujiaoka/docker-compose.yml" up -d --build

echo "✅ 安装完成！请访问：http://${DOMAIN} 继续设置独角数卡"
