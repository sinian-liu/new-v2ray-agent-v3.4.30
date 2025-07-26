#!/bin/bash

# 设置颜色
GREEN='\033[0;32m'
NC='\033[0m' # 无色

echo -e "${GREEN}▶️ 开始独角数卡一键部署...${NC}"

# ======= 交互填写参数 =======
read -p "请输入你的域名（如 shop.example.com）: " DOMAIN
read -p "请输入你的邮箱（用于SSL证书注册）: " EMAIL
read -p "设置数据库ROOT密码（默认：sinian）: " DB_ROOT
DB_ROOT=${DB_ROOT:-webroot}
read -p "设置数据库名（默认：sinian）: " DB_NAME
DB_NAME=${DB_NAME:-web}
read -p "设置数据库用户名（默认：sinian）: " DB_USER
DB_USER=${DB_USER:-kejilion}
read -p "设置数据库用户密码（默认：sinian）: " DB_PASS
DB_PASS=${DB_PASS:-kejilionYYDS}

# ======= 更新系统 =======
echo -e "${GREEN}📦 正在更新系统并安装依赖...${NC}"
apt update -y && apt upgrade -y && apt install -y curl wget sudo socat tar

# ======= 安装Docker =======
echo -e "${GREEN}🐳 正在安装 Docker 和 Docker Compose...${NC}"
curl -fsSL https://get.docker.com | sh
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ======= 创建目录 =======
echo -e "${GREEN}📁 创建目录结构...${NC}"
mkdir -p /home/web/{html,mysql,certs,redis}
touch /home/web/nginx.conf
cd /home/web

# ======= 写入 docker-compose.yml =======
echo -e "${GREEN}📝 写入 docker-compose.yml 文件...${NC}"
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:1.22
    container_name: nginx
    restart: always
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
      - ./html:/var/www/html

  php:
    image: php:7.4.33-fpm
    container_name: php
    restart: always
    volumes:
      - ./html:/var/www/html

  mysql:
    image: mysql:5.7.42
    container_name: mysql
    restart: always
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_ROOT
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASS

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    volumes:
      - ./redis:/data
EOF

# ======= 申请 SSL =======
echo -e "${GREEN}🔐 正在申请 SSL 证书，请确保域名 $DOMAIN 已解析到本机IP${NC}"
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m $EMAIL
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone

~/.acme.sh/acme.sh --installcert -d $DOMAIN \
  --key-file /home/web/certs/key.pem \
  --fullchain-file /home/web/certs/cert.pem

# ======= 写入 nginx.conf =======
echo -e "${GREEN}📝 写入 NGINX 配置文件...${NC}"
cat > /home/web/nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    client_max_body_size 1000m;

    server {
        listen 80;
        server_name $DOMAIN;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name $DOMAIN;

        ssl_certificate /etc/nginx/certs/cert.pem;
        ssl_certificate_key /etc/nginx/certs/key.pem;

        root /var/www/html/dujiaoka/public/;
        index index.php;

        try_files \$uri \$uri/ /index.php?\$query_string;

        location ~ \.php\$ {
            fastcgi_pass php:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
EOF

# ======= 下载源码 =======
echo -e "${GREEN}📥 下载独角数卡源码...${NC}"
cd /home/web/html
wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
tar -zxvf 2.0.6-antibody.tar.gz
rm 2.0.6-antibody.tar.gz

# ======= 启动容器 =======
echo -e "${GREEN}🚀 启动 Docker 容器...${NC}"
cd /home/web
docker-compose up -d

# ======= 设置权限 =======
echo -e "${GREEN}🔧 设置权限...${NC}"
docker exec -it nginx chmod -R 777 /var/www/html
docker exec -it php chmod -R 777 /var/www/html

# ======= 安装 PHP 扩展 =======
echo -e "${GREEN}📦 安装 PHP 扩展...${NC}"
docker exec php apt update
docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick
docker exec php docker-php-ext-install pdo_mysql zip bcmath gd intl opcache
docker exec php pecl install redis
docker exec php sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini'

# ======= 重启 PHP 容器 =======
docker restart php

# ======= 查看 PHP 扩展情况 =======
docker exec -it php php -m

# ======= 修正 HTTPS 后台访问报错（可选） =======
echo -e "${GREEN}⚙️ 修复后台登录HTTPS报错（如有）...${NC}"
sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /home/web/html/dujiaoka/.env

echo -e "${GREEN}✅ 独角数卡安装完成！请访问：https://$DOMAIN 进行后台配置。${NC}"
