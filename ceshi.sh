#!/bin/bash
set -e

# 环境变量
DOMAIN="sparkedhost.565645.xyz"
EMAIL="admin@example.com"
DEPLOY_DIR="/home/web/html/dujiaoka"
DB_PASSWORD="sinian"

echo "=== 1. 安装 Docker ==="
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker --now
fi

echo "=== 2. 准备源码目录 ==="
mkdir -p "$DEPLOY_DIR"
cd /home/web/html
if [ ! -d "$DEPLOY_DIR" ] || [ -z "$(ls -A $DEPLOY_DIR)" ]; then
  echo "下载并解压源码..."
  wget -q https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
  tar -zxf 2.0.6-antibody.tar.gz -C "$DEPLOY_DIR" --strip-components=1
  rm 2.0.6-antibody.tar.gz
else
  echo "源码目录已存在且不为空，跳过下载。"
fi

echo "=== 3. 写 Dockerfile ==="
cat > "$DEPLOY_DIR/Dockerfile" <<'EOF'
FROM php:8.1-fpm-alpine

RUN apk add --no-cache libzip-dev libpng-dev libjpeg-turbo-dev libfreetype-dev unzip git && \
    docker-php-ext-configure zip && docker-php-ext-install zip pdo_mysql gd && \
    apk del libzip-dev

WORKDIR /var/www/html

COPY . .

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

CMD ["php-fpm"]
EOF

echo "=== 4. 写 docker-compose.yml ==="
cat > "$DEPLOY_DIR/docker-compose.yml" <<EOF
version: "3.8"

services:
  db:
    image: mysql:5.7
    container_name: dujiaoka-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $DB_PASSWORD
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: $DB_PASSWORD
    volumes:
      - dbdata:/var/lib/mysql
    networks:
      - dujiaoka-net

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    restart: always
    networks:
      - dujiaoka-net

  php:
    build: .
    container_name: dujiaoka-php
    restart: always
    volumes:
      - ./:/var/www/html
    networks:
      - dujiaoka-net

  nginx:
    image: nginx:alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    networks:
      - dujiaoka-net

volumes:
  dbdata:

networks:
  dujiaoka-net:
EOF

echo "=== 5. 写 nginx 配置文件 ==="
cat > "$DEPLOY_DIR/nginx.conf" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

echo "=== 6. 启动容器 ==="
cd "$DEPLOY_DIR"
docker compose down || true
docker compose build
docker compose up -d

echo "=== 7. 等待数据库启动，睡眠15秒 ==="
sleep 15

echo "=== 8. 进入PHP容器安装 composer 依赖 ==="
CONTAINER_ID=$(docker ps --filter "name=dujiaoka-php" --format "{{.ID}}" | head -n 1)
if [ -z "$CONTAINER_ID" ]; then
  echo "找不到PHP容器，退出。"
  exit 1
fi
docker exec -it "$CONTAINER_ID" sh -c "cd /var/www/html && composer install --no-dev --optimize-autoloader"

echo "部署完成！访问 http://$DOMAIN 进行安装界面。"
