#!/bin/bash
set -e

echo "请输入你的域名（例如 example.com）:"
read DOMAIN

echo "请输入你的邮箱（用于申请SSL）:"
read EMAIL

APP_DIR="/opt/dujiaoka"
MYSQL_ROOT_PASSWORD="sinian"
REDIS_PASSWORD=""
ADMIN_ROUTE_PREFIX="/admin"

echo "=== 1. 检测系统 ==="
if [ -f /etc/debian_version ]; then
  SYSTEM="debian"
elif [ -f /etc/redhat-release ]; then
  SYSTEM="centos"
else
  echo "暂不支持该系统"
  exit 1
fi

echo "=== 2. 安装 Docker 和 docker-compose ==="
if ! command -v docker >/dev/null 2>&1; then
  if [ "$SYSTEM" == "debian" ]; then
    curl -fsSL https://get.docker.com | bash
  elif [ "$SYSTEM" == "centos" ]; then
    curl -fsSL https://get.docker.com | bash
  fi
fi

systemctl enable docker && systemctl start docker

echo "=== 3. 创建目录并下载源码 ==="
mkdir -p $APP_DIR
cd $APP_DIR

# 下载并解压独角数卡源码
wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
apt-get update && apt-get install -y tar
tar -zxvf 2.0.6-antibody.tar.gz
rm -f 2.0.6-antibody.tar.gz

echo "=== 4. 生成 docker-compose.yml ==="
cat > $APP_DIR/docker-compose.yml <<EOF
version: '3'
services:
  mysql:
    image: mysql:5.7
    container_name: mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: sinian
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - dujiaoka-net

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    command: redis-server --requirepass "$REDIS_PASSWORD"
    networks:
      - dujiaoka-net

  php:
    image: php:7.4-fpm
    container_name: php
    volumes:
      - ./:/var/www/html
    depends_on:
      - mysql
      - redis
    networks:
      - dujiaoka-net

  nginx:
    image: nginx:1.22
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./:/var/www/html
      - ./nginx/conf.d:/etc/nginx/conf.d
    depends_on:
      - php
    networks:
      - dujiaoka-net

volumes:
  mysql_data:

networks:
  dujiaoka-net:
EOF

echo "=== 5. 配置 Nginx ==="
mkdir -p $APP_DIR/nginx/conf.d
cat > $APP_DIR/nginx/conf.d/dujiaoka.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html/public;
    index index.php index.html;

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
EOF

echo "=== 6. 启动容器 ==="
docker-compose up -d

echo "=== 7. 等待 MySQL 启动 ==="
sleep 20

echo "=== 8. 运行 Laravel 依赖安装和配置 ==="
docker exec php bash -c "cd /var/www/html && apt-get update && apt-get install -y unzip git && php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\" && php composer-setup.php && php composer.phar install"
docker exec php php /var/www/html/artisan key:generate
docker exec php php /var/www/html/artisan config:cache

echo "=== 9. 自动申请SSL证书（acme.sh） ==="
if ! command -v acme.sh >/dev/null 2>&1; then
  curl https://get.acme.sh | sh
  ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -m $EMAIL --force
  ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
    --key-file       $APP_DIR/ssl/$DOMAIN.key \
    --fullchain-file $APP_DIR/ssl/$DOMAIN.cer \
    --reloadcmd     "docker restart nginx"
fi

echo "安装完成！请打开浏览器访问 http://$DOMAIN 进行独角数卡安装界面点击安装。"
