#!/bin/bash
# 独角数卡增强版一键安装修正版（免交互 + 自动迁移 + 自动管理员 + 修复缓存/日志权限）
set -e

BASE_DIR=/opt/dujiaoka
ENV_DIR=$BASE_DIR/env
ADMIN_USER=admin
ADMIN_PASS=IKctUskuhV6tJgmd

echo "🚀 独角数卡增强版一键安装开始..."

# 安装依赖
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget git sudo lsb-release apt-transport-https ca-certificates software-properties-common

# 安装 Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "⚙️ 安装 Docker..."
  curl -fsSL https://get.docker.com | CHANNEL=stable sh
fi

# 安装 Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "⚙️ 安装 Docker Compose..."
  DC_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
  curl -L "https://github.com/docker/compose/releases/download/$DC_VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 和 Docker Compose 安装完成"

# 创建项目目录
mkdir -p $BASE_DIR/{storage,bootstrap/cache,env}
cd $BASE_DIR

# .env 文件
cat > $ENV_DIR/.env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka123

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=redis
ADMIN_ROUTE_PREFIX=/admin
EOF

# Docker Compose
cat > $BASE_DIR/docker-compose.yml <<EOF
services:
  db:
    image: mysql:8.0
    container_name: dujiaoka-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: dujiaoka123
    volumes:
      - db_data:/var/lib/mysql
    ports:
      - "3306:3306"

  redis:
    image: redis:7-alpine
    container_name: dujiaoka-redis
    restart: always
    ports:
      - "6379:6379"

  dujiaoka:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    depends_on:
      - db
      - redis
    environment:
      TZ: Asia/Shanghai
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./env/.env:/app/.env
    ports:
      - "80:80"
    restart: always

volumes:
  db_data:
EOF

# 修复权限
chown -R 1000:1000 storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# 启动数据库和 Redis
docker-compose up -d db redis

# 等待 MySQL
until docker exec dujiaoka-db mysqladmin ping -h "localhost" --silent; do sleep 2; done
echo "✅ MySQL 已启动"

# 等待 Redis
until docker exec dujiaoka-redis redis-cli ping | grep -q PONG; do sleep 1; done
echo "✅ Redis 已启动"

# 启动 dujiaoka 容器
docker-compose up -d dujiaoka
sleep 10

# 修复容器内权限，确保 Laravel 可以写入日志和缓存
docker exec dujiaoka chown -R www-data:www-data /app/storage /app/bootstrap/cache
docker exec dujiaoka chmod -R 775 /app/storage /app/bootstrap/cache

# 数据库迁移 & 管理员
docker exec -i dujiaoka php artisan migrate --force
docker exec -i dujiaoka php artisan dujiaoka:admin $ADMIN_USER $ADMIN_PASS

IP_ADDR=$(hostname -I | awk '{print $1}')
echo "🎉 安装完成！"
echo "前台: http://$IP_ADDR"
echo "后台: http://$IP_ADDR/admin"
echo "管理员账号: $ADMIN_USER / $ADMIN_PASS"
echo "数据库: dujiaoka / dujiaoka123"
echo "MySQL root: root / root123"
