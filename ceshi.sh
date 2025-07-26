#!/bin/bash
set -e

# -------- 交互输入配置区 --------
read -p "请输入你的域名（例如 example.com）: " DOMAIN
read -p "请输入你的邮箱（用于申请SSL）: " EMAIL

APP_DIR="/opt/dujiaoka"
MYSQL_ROOT_PASSWORD="sinian"
REDIS_PASSWORD=""
APP_NAME="独角数卡"
ADMIN_ROUTE_PREFIX="/admin"
# -------------------------------

echo "域名: $DOMAIN"
echo "邮箱: $EMAIL"

echo "=== 1. 检测系统类型 ==="
if [ -f /etc/redhat-release ]; then
  OS="centos"
elif [ -f /etc/debian_version ]; then
  OS="debian"
else
  echo "不支持的操作系统，脚本仅支持Debian/Ubuntu/CentOS"
  exit 1
fi

echo "=== 2. 安装Docker和docker-compose ==="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker --now

if ! command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | head -1 | awk -F '"' '{print $4}')
  curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "=== 3. 创建目录及权限 ==="
mkdir -p ${APP_DIR}/{dujiaoka,mysql_data,redis_data,storage,uploads,certs}
chmod -R 777 ${APP_DIR}/storage ${APP_DIR}/uploads

echo "=== 4. 下载独角数卡源码 ==="
if [ ! -d "${APP_DIR}/dujiaoka" ] || [ -z "$(ls -A ${APP_DIR}/dujiaoka)" ]; then
  LATEST_VER=$(curl -s https://api.github.com/repos/assimon/dujiaoka/releases/latest | grep "tag_name" | head -1 | awk -F '"' '{print $4}')
  wget -qO ${APP_DIR}/dujiaoka.tar.gz "https://github.com/assimon/dujiaoka/releases/download/${LATEST_VER}/${LATEST_VER}.tar.gz"
  tar -zxf ${APP_DIR}/dujiaoka.tar.gz -C ${APP_DIR}
  rm -f ${APP_DIR}/dujiaoka.tar.gz
fi

echo "=== 5. 生成 .env 文件 ==="
cat > ${APP_DIR}/dujiaoka/.env <<EOF
APP_NAME=${APP_NAME}
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://${DOMAIN}

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=root
DB_PASSWORD=${MYSQL_ROOT_PASSWORD}

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

ADMIN_ROUTE_PREFIX=${ADMIN_ROUTE_PREFIX}
ADMIN_HTTPS=true
EOF

echo "=== 6. 生成 docker-compose.yml ==="
cat > ${APP_DIR}/docker-compose.yml <<EOF
version: "3.8"

services:
  db:
    image: mariadb:10.5
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: dujiaoka
    volumes:
      - ./mysql_data:/var/lib/mysql

  redis:
    image: redis:6-alpine
    container_name: dujiaoka-redis
    restart: always
    command: redis-server --requirepass "${REDIS_PASSWORD}"
    volumes:
      - ./redis_data:/data

  php:
    image: php:8.2-fpm
    container_name: dujiaoka-php
    restart: always
    volumes:
      - ./dujiaoka:/var/www/dujiaoka
      - ./storage:/var/www/dujiaoka/storage
      - ./uploads:/var/www/dujiaoka/public/uploads
    working_dir: /var/www/dujiaoka

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./dujiaoka:/var/www/dujiaoka
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./certs:/etc/nginx/certs
EOF

echo "=== 7. 生成 nginx.conf ==="
cat > ${APP_DIR}/nginx.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    location /.well-known/acme-challenge/ {
        root /var/www/dujiaoka/public;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    root /var/www/dujiaoka/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

echo "=== 8. 申请 HTTPS 证书（acme.sh standalone 模式） ==="
if ! command -v acme.sh >/dev/null 2>&1; then
  curl https://get.acme.sh | sh
fi
~/.acme.sh/acme.sh --register-account -m "${EMAIL}" --server letsencrypt
~/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone --force
mkdir -p ${APP_DIR}/certs
~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
  --key-file ${APP_DIR}/certs/key.pem \
  --fullchain-file ${APP_DIR}/certs/cert.pem \
  --reloadcmd "docker restart dujiaoka-nginx"

echo "=== 9. 启动容器 ==="
cd ${APP_DIR}
docker-compose up -d

echo "=== 10. 生成 Laravel APP_KEY ==="
sleep 10  # 等待容器启动
docker exec dujiaoka-php php artisan key:generate

echo "=== 安装完成 ==="
echo "请确保 ${DOMAIN} 解析正确，浏览器访问 https://${DOMAIN} 即可进入独角数卡安装页面，点击安装。后台地址为 https://${DOMAIN}${ADMIN_ROUTE_PREFIX}"
