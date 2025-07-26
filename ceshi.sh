#!/bin/bash
set -e

# 变量区
DOMAIN=""
EMAIL=""
DEPLOY_DIR="/home/web/html/dujiaoka"
MYSQL_ROOT_PASS="sinian"

read -p "请输入你的域名（例如 example.com）: " DOMAIN
read -p "请输入你的邮箱（用于申请 SSL）: " EMAIL

echo "开始部署，目录：$DEPLOY_DIR"

# 安装 Docker 和 Docker Compose（如果没有）
if ! command -v docker &> /dev/null; then
  echo "安装 Docker..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 创建目录
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# 下载源码
echo "下载dujiaoka源码..."
if [ ! -f "2.0.6-antibody.tar.gz" ]; then
  wget -q https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
fi
tar -zxf 2.0.6-antibody.tar.gz
rm 2.0.6-antibody.tar.gz

# 写docker-compose.yml
cat > ../docker-compose.yml <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./html/dujiaoka:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - dujiaoka-net

  php:
    build: ./php
    container_name: dujiaoka-php
    volumes:
      - ./html/dujiaoka:/var/www/html
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka-net

  db:
    image: mysql:5.7
    container_name: dujiaoka-db
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASS
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: $MYSQL_ROOT_PASS
    volumes:
      - ./mysql:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - dujiaoka-net

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    ports:
      - "6379:6379"
    networks:
      - dujiaoka-net

networks:
  dujiaoka-net:
    driver: bridge
EOF

# 写 Nginx 配置
mkdir -p ../nginx
cat > ../nginx/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# 创建 PHP Dockerfile，安装扩展
mkdir -p $DEPLOY_DIR/php
cat > $DEPLOY_DIR/php/Dockerfile <<EOF
FROM php:8.1-fpm

RUN apt-get update && apt-get install -y libzip-dev libpng-dev libfreetype6-dev libjpeg-dev libonig-dev \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip gd bcmath pdo pdo_mysql mbstring

WORKDIR /var/www/html
EOF

# 启动容器
cd ..
echo "启动容器..."
docker compose up -d --build

# 等待PHP容器启动
echo "等待 PHP 容器启动..."
sleep 10

# 在php容器内执行composer install
echo "安装 Laravel 依赖..."
docker exec -it dujiaoka-php bash -c "cd /var/www/html && php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && php composer-setup.php && php -r \"unlink('composer-setup.php');\" && php composer.phar install --no-dev --optimize-autoloader"

echo "安装完成！请访问 http://$DOMAIN"
