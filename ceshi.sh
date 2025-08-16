#!/bin/bash
set -e

APP_DIR="/opt/dujiaoka"
MYSQL_ROOT_PASSWORD="dujiaoka_root"
MYSQL_USER="dujiaoka"
MYSQL_PASSWORD="dujiaoka_pass"
MYSQL_DB="dujiaoka"
REDIS_PASSWORD="redis_pass"

echo "🚀 独角数卡增强版一键安装开始..."

# 安装依赖
apt-get update -qq
apt-get install -y -qq curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# 安装 Docker
if ! command -v docker >/dev/null; then
    echo "⚙️ 安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
fi

# 安装 Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "⚙️ 安装 Docker Compose..."
    DOCKER_COMPOSE_VERSION="v2.39.2"
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 和 Docker Compose 安装完成"

# 创建应用目录
mkdir -p "$APP_DIR"/{storage,bootstrap/cache}
cd "$APP_DIR"
chmod -R 775 "$APP_DIR"/{storage,bootstrap/cache}
chown -R 1000:1000 "$APP_DIR"/{storage,bootstrap/cache}  # www-data 在容器中 UID 1000

# 写 docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3.9"
services:
  db:
    image: mysql:8.0
    container_name: dujiaoka-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DB}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    ports:
      - "3306:3306"

  redis:
    image: redis:7
    container_name: dujiaoka-redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    depends_on:
      - db
      - redis
    environment:
      WEB_DOCUMENT_ROOT: /app/public
      DB_CONNECTION: mysql
      DB_HOST: db
      DB_PORT: 3306
      DB_DATABASE: ${MYSQL_DB}
      DB_USERNAME: ${MYSQL_USER}
      DB_PASSWORD: ${MYSQL_PASSWORD}
      REDIS_HOST: redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      REDIS_PORT: 6379
      DUJIAO_ADMIN_LANGUAGE: zh_CN
      ADMIN_ROUTE_PREFIX: /admin
    ports:
      - "80:80"
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
    command: >
      /bin/sh -c "
        mkdir -p /app/storage /app/bootstrap/cache &&
        chown -R www-data:www-data /app/storage /app/bootstrap/cache &&
        chmod -R 775 /app/storage /app/bootstrap/cache &&
        php artisan config:clear &&
        php artisan cache:clear &&
        php artisan view:clear &&
        php artisan route:clear &&
        php artisan migrate --force &&
        php-fpm -F
      "

volumes:
  db_data:
  redis_data:
EOF

echo "🚀 启动所有容器..."
docker compose up -d

echo "✅ 安装完成，前后台访问："
echo "🌐 前台: http://<服务器IP>/"
echo "🔑 后台: http://<服务器IP>/admin"
echo "   默认管理员账号: admin"
echo "   默认管理员密码: IKctUskuhV6tJgmd"
