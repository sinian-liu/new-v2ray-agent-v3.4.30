#!/bin/bash
set -e

# 1. 安装 Docker
if ! command -v docker &> /dev/null; then
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com | bash
  systemctl start docker
  systemctl enable docker
fi

# 2. 安装 Docker Compose v2
if ! docker compose version &> /dev/null; then
  echo "安装 Docker Compose v2..."
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.38.2/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
fi

# 3. 创建目录
WORKDIR=/home/web/html/dujiaoka
mkdir -p /home/web/html
cd /home/web/html

# 4. 下载并解压源码
echo "下载并解压 dujiaoka 源码..."
if [ ! -d "$WORKDIR" ] || [ -z "$(ls -A $WORKDIR)" ]; then
  wget -q https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
  apt-get update && apt-get install -y tar
  mkdir -p $WORKDIR
  tar -zxvf 2.0.6-antibody.tar.gz -C $WORKDIR --strip-components=1
  rm 2.0.6-antibody.tar.gz
else
  echo "$WORKDIR 目录已存在且不为空，跳过源码下载"
fi

# 5. 写 docker-compose.yml
cat > $WORKDIR/docker-compose.yml <<EOF
version: "3.9"
services:
  db:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: sinian
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka_user
      MYSQL_PASSWORD: sinian
    volumes:
      - dbdata:/var/lib/mysql
    networks:
      - dujiaoka-net

  redis:
    image: redis:alpine
    restart: always
    networks:
      - dujiaoka-net

  php:
    build:
      context: $WORKDIR/php
      dockerfile: Dockerfile
    volumes:
      - $WORKDIR:/var/www/html
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka-net

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - $WORKDIR:/var/www/html
      - $WORKDIR/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - dujiaoka-net

volumes:
  dbdata:

networks:
  dujiaoka-net:
EOF

# 6. 写 nginx 配置
mkdir -p $WORKDIR/nginx
cat > $WORKDIR/nginx/default.conf <<EOF
server {
    listen 80;
    server_name localhost;

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

# 7. 准备 php Dockerfile
mkdir -p $WORKDIR/php
cat > $WORKDIR/php/Dockerfile <<EOF
FROM php:8.1-fpm

RUN apt-get update && apt-get install -y \
    libzip-dev libpng-dev libfreetype6-dev libjpeg-dev libonig-dev zip unzip git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd zip bcmath pdo_mysql mbstring

WORKDIR /var/www/html
EOF

# 8. 启动服务
cd $WORKDIR
docker compose up -d --build

# 9. 等待数据库启动
echo "等待数据库启动，10秒后执行 composer 安装..."
sleep 10

# 10. 运行 composer install
docker exec -it $(docker ps -qf "name=php") sh -c "cd /var/www/html && php composer.phar install --no-dev --optimize-autoloader"

echo "部署完成！请访问 http://服务器IP/ 查看。"
