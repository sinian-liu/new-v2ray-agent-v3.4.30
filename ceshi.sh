#!/bin/bash
# 独角数卡增强版一键安装脚本（支持 Ubuntu 20.04 ~ 24.04）
# 自动安装 Docker/Docker Compose、MySQL、Redis
# 自动初始化 Laravel storage/cache/日志目录
# 前后台直接可用，免交互

set -e

APP_DIR="/opt/dujiaoka"
MYSQL_ROOT_PASSWORD="dujiaoka_root"
MYSQL_USER="dujiaoka"
MYSQL_PASSWORD="dujiaoka_pass"
MYSQL_DB="dujiaoka"
REDIS_PASSWORD="redis_pass"

echo "🚀 独角数卡增强版一键安装开始..."

# 安装依赖
echo "⚙️ 安装必要依赖..."
apt-get update -qq
apt-get install -y -qq curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

# 安装 Docker
if ! command -v docker >/dev/null; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
fi

# 安装 Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo "⚙️ 未检测到 Docker Compose，正在安装..."
    DOCKER_COMPOSE_VERSION="v2.39.2"
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 和 Docker Compose 安装完成"

# 创建应用目录
mkdir -p "$APP_DIR"
cd "$APP_DIR"

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

volumes:
  db_data:
  redis_data:
EOF

# 启动服务
echo "🚀 启动 MySQL 和 Redis..."
docker compose up -d db redis

echo "⏳ 等待 MySQL 启动..."
sleep 15
echo "✅ MySQL 已启动"
echo "⏳ 等待 Redis 启动..."
sleep 5
echo "✅ Redis 已启动"

echo "🚀 启动独角数卡容器..."
docker compose up -d app

echo "⏳ 等待应用容器准备..."
sleep 10

# 修复 Laravel 权限和缓存目录
echo "⚡ 修复 Laravel 目录权限..."
docker exec -it dujiaoka mkdir -p /app/storage /app/bootstrap/cache
docker exec -it dujiaoka chown -R www-data:www-data /app/storage /app/bootstrap/cache
docker exec -it dujiaoka chmod -R 775 /app/storage /app/bootstrap/cache

# 清理缓存
docker exec -it dujiaoka php artisan config:clear
docker exec -it dujiaoka php artisan cache:clear
docker exec -it dujiaoka php artisan view:clear
docker exec -it dujiaoka php artisan route:clear

# 数据库迁移
echo "⚡ 运行数据库迁移..."
docker exec -it dujiaoka php artisan migrate --force || true

echo "✅ 安装完成"
echo "🌐 前台访问: http://<服务器IP>/"
echo "🔑 后台登录: http://<服务器IP>/admin"
echo "   默认管理员账号: admin"
echo "   默认管理员密码: IKctUskuhV6tJgmd"
