#!/bin/bash

read -p "请输入你的域名（如 shop.example.com）: " DOMAIN
read -p "请输入你的 ACME 注册邮箱: " ACME_MAIL

# 更新系统并安装基础依赖
apt update -y && apt upgrade -y && apt install -y curl wget sudo socat tar unzip gnupg lsb-release

# 安装 Docker & Docker Compose
curl -fsSL https://get.docker.com | sh
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 创建目录
cd /home
mkdir -p web/{html,mysql,certs,redis}
cd /home/web
touch nginx.conf docker-compose.yml

# 生成 docker-compose.yml
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
    environment:
      - MYSQL_ROOT_PASSWORD=sinian
      - MYSQL_DATABASE=sinian
      - MYSQL_USER=sinian
      - MYSQL_PASSWORD=sinian
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    volumes:
      - ./redis:/data
EOF

# 写 nginx.conf
cat > nginx.conf <<EOF
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

# 安装 acme.sh 并签发证书
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m $ACME_MAIL
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
  --key-file /home/web/certs/key.pem \
  --fullchain-file /home/web/certs/cert.pem

# 下载源码
cd /home/web/html
wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
tar -zxvf 2.0.6-antibody.tar.gz
rm 2.0.6-antibody.tar.gz

# 写 .env 配置
cat > /home/web/html/dujiaoka/.env <<EOF
APP_NAME=独角数卡
APP_ENV=production
APP_DEBUG=false
APP_LOG_LEVEL=debug
APP_URL=https://$DOMAIN

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=sinian
DB_USERNAME=sinian
DB_PASSWORD=sinian

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

ADMIN_HTTPS=true
EOF

# 启动容器
cd /home/web
docker-compose up -d

# 设置权限
docker exec php chmod -R 777 /var/www/html
docker exec php chmod -R 777 /var/www/html/dujiaoka/storage
docker exec php chmod -R 777 /var/www/html/dujiaoka/bootstrap/cache

# 安装 Composer & Laravel 依赖
docker exec php curl -sS https://getcomposer.org/installer | php
docker exec php mv composer.phar /usr/local/bin/composer
docker exec -w /var/www/html/dujiaoka php composer install

# 安装 PHP 扩展
docker exec php apt update
docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick
docker exec php docker-php-ext-install pdo_mysql zip bcmath gd intl opcache
docker exec php pecl install redis
docker exec php sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini'

# 重启 PHP 并生成 Key
docker restart php
docker exec php php /var/www/html/dujiaoka/artisan key:generate

echo ""
echo "✅ 独角数卡部署完成，请访问：https://$DOMAIN"
echo "🔐 默认数据库用户/密码/库名：sinian / sinian / sinian"
echo "🖱️ 打开安装界面后，直接点击“安装”按钮即可完成！"
