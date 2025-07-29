#!/bin/bash

# 定义变量（请根据实际情况修改）
DOMAIN="shop.kejilion.eu.org"  # 替换为你的域名
EMAIL="xxxx@gmail.com"        # 替换为你的邮箱
APP_NAME="我的小店"           # 网站名称
DB_PASSWORD="changeyourpassword"  # 数据库密码

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root权限运行！"
    exit 1
fi

echo "开始一键搭建独角数卡..."

# 1. 更新系统并安装必要工具
echo "更新系统并安装依赖..."
apt update -y && apt upgrade -y && apt install -y curl wget sudo socat tar

# 2. 安装Docker
echo "安装Docker..."
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# 3. 安装Docker Compose
echo "安装Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 4. 创建目录结构
echo "创建目录..."
cd /home
mkdir -p web/html web/mysql web/certs web/redis
touch web/nginx.conf web/docker-compose.yml

# 5. 配置docker-compose.yml
echo "配置docker-compose.yml..."
cat > /home/web/docker-compose.yml <<EOF
version: '3'
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/web/html:/var/www/html
      - /home/web/nginx.conf:/etc/nginx/nginx.conf
      - /home/web/certs:/etc/nginx/certs
    depends_on:
      - php
    networks:
      - lnmp
  php:
    image: php:8.0-fpm
    container_name: php
    volumes:
      - /home/web/html:/var/www/html
    networks:
      - lnmp
  mysql:
    image: mysql:5.7
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - /home/web/mysql:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - lnmp
  redis:
    image: redis:latest
    container_name: redis
    volumes:
      - /home/web/redis:/data
    ports:
      - "6379:6379"
    networks:
      - lnmp
networks:
  lnmp:
    driver: bridge
EOF

# 6. 配置Nginx
echo "配置Nginx..."
wget -O /home/web/nginx.conf https://raw.githubusercontent.com/kejilion/nginx/main/nginx7.conf
sed -i "s/yuming.com/${DOMAIN}/g" /home/web/nginx.conf

# 7. 申请和下载SSL证书
echo "申请SSL证书..."
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m ${EMAIL}
~/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone
~/.acme.sh/acme.sh --installcert -d ${DOMAIN} --key-file /home/web/certs/key.pem --fullchain-file /home/web/certs/cert.pem

# 8. 下载并解压独角数卡源码
echo "下载独角数卡源码..."
cd /home/web/html
wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
tar -zxvf 2.0.6-antibody.tar.gz
rm 2.0.6-antibody.tar.gz

# 9. 配置.env文件
echo "配置独角数卡环境变量..."
cd /home/web/html/dujiaoka
cp .env.example .env
sed -i "s/APP_NAME=.*/APP_NAME=${APP_NAME}/" .env
sed -i "s/APP_URL=.*/APP_URL=https:\/\/${DOMAIN}/" .env
sed -i "s/DB_HOST=.*/DB_HOST=mysql/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=dujiaoka/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=dujiaoka/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env
sed -i "s/REDIS_HOST=.*/REDIS_HOST=redis/" .env
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env
sed -i "s/ADMIN_HTTPS=.*/ADMIN_HTTPS=true/" .env

# 10. 启动Docker容器
echo "启动Docker容器..."
cd /home/web
docker-compose up -d

# 11. 赋予文件权限
echo "设置文件权限..."
docker exec nginx chmod -R 777 /var/www/html
docker exec php chmod -R 777 /var/www/html

# 12. 安装PHP扩展
echo "安装PHP扩展..."
docker exec php apt update
docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick
docker exec php docker-php-ext-install pdo_mysql zip bcmath gd intl opcache
docker exec php pecl install redis
docker exec php sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini'

# 13. 重启PHP容器
echo "重启PHP容器..."
docker restart php

# 14. 检查PHP扩展
echo "检查PHP扩展..."
docker exec -it php php -m

# 15. 完成提示
echo "独角数卡搭建完成！"
echo "访问地址: https://${DOMAIN}"
echo "后台登录: https://${DOMAIN}/admin"
echo "数据库信息:"
echo "  数据库名: dujiaoka"
echo "  用户名: dujiaoka"
echo "  密码: ${DB_PASSWORD}"
echo "  主机: mysql"
echo "请妥善保存数据库信息！"
