#!/bin/bash

set -e

echo "===== 独角数卡 Docker 安装器（基于 2.0.6-antibody）====="

# ---------------------
# 交互式参数输入
# ---------------------
read -p "站点名称 (APP_NAME): " APP_NAME
read -p "域名 (不含 http，例如 dujiaoka.com): " DOMAIN
read -p "数据库名: " DB_NAME
read -p "数据库用户名: " DB_USER
read -s -p "数据库密码: " DB_PASS
echo ""
read -p "Redis 密码 (可留空): " REDIS_PASS
read -p "安装路径 (默认 /home/web/html/web5): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/home/web/html/web5}

# ---------------------
# 安装依赖
# ---------------------
echo ">>> 检查并安装必要依赖..."
apt update -y && apt install -y curl git sudo unzip docker.io docker-compose

# ---------------------
# 创建目录
# ---------------------
mkdir -p $INSTALL_PATH && cd $INSTALL_PATH

# ---------------------
# 下载源码
# ---------------------
echo ">>> 下载独角数卡源码 v2.0.6..."
curl -L https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz -o dujiaoka.tar.gz
tar -zxf dujiaoka.tar.gz
rm -f dujiaoka.tar.gz
mv dujiaoka* dujiaoka

# ---------------------
# 创建 .env 文件
# ---------------------
cat > .env <<EOF
APP_NAME="${APP_NAME}"
APP_URL=http://${DOMAIN}
APP_ENV=production
APP_DEBUG=false
LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASS}
REDIS_PORT=6379
EOF

# ---------------------
# 创建 docker-compose.yml
# ---------------------
cat > docker-compose.yml <<EOF
services:
  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./dujiaoka:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php

  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    volumes:
      - ./dujiaoka:/var/www/html
    working_dir: /var/www/html
    depends_on:
      - mysql
      - redis

  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
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
    command: redis-server --requirepass ${REDIS_PASS}
    volumes:
      - redis_data:/data

volumes:
  mysql_data:
  redis_data:
EOF

# ---------------------
# 创建 nginx.conf
# ---------------------
cat > nginx.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/html/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# ---------------------
# 权限与初始化
# ---------------------
echo ">>> 设置文件权限..."
chmod -R 755 $INSTALL_PATH/dujiaoka
mkdir -p dujiaoka/public/uploads
chmod -R 777 dujiaoka/public/uploads

# ---------------------
# 启动容器
# ---------------------
echo ">>> 启动 Docker 服务..."
docker-compose up -d

echo "✅ 安装完成！请访问：http://${DOMAIN} 完成后台初始化"
