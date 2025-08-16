#!/bin/bash
# 🚀 独角数卡增强版一键安装脚本 (免交互+自动迁移+初始化管理员+等待服务启动)
# 适用 Ubuntu 20.04 ~ 24.04

set -e

BASE_DIR=/opt/dujiaoka
ENV_DIR=$BASE_DIR/env

ADMIN_USER=admin
ADMIN_PASS=IKctUskuhV6tJgmd

echo "🚀 独角数卡增强版一键安装开始..."

# 安装必要依赖
echo "⚙️ 安装必要依赖..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget git sudo lsb-release apt-transport-https ca-certificates software-properties-common openssl

# 安装 Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "⚙️ 未检测到 Docker，正在安装..."
  curl -fsSL https://get.docker.com | CHANNEL=stable sh
fi

# 安装 Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "⚙️ 安装 Docker Compose..."
  DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 和 Docker Compose 安装完成"

# 创建项目目录
mkdir -p $BASE_DIR
mkdir -p $ENV_DIR
cd $BASE_DIR

# 创建 .env 文件
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

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120
CACHE_DRIVER=file
QUEUE_CONNECTION=redis
DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
EOF

# 创建 Docker Compose 文件
cat > $BASE_DIR/docker-compose.yml <<EOF
version: "3.9"
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
      WEB_DOCUMENT_ROOT: /app/public
      TZ: Asia/Shanghai
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./env/.env:/app/.env
    ports:
      - "80:80"
      - "9000:9000"
    restart: always

volumes:
  db_data:
EOF

# 修复权限
mkdir -p storage bootstrap/cache
chown -R 1000:1000 storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# 启动数据库和 Redis 容器
echo "🚀 启动 MySQL 和 Redis..."
docker-compose up -d db redis

# 等待 MySQL 完全启动
echo "⏳ 等待 MySQL 启动..."
until docker exec dujiaoka-db mysqladmin ping -h "localhost" --silent; do
  sleep 2
done
echo "✅ MySQL 启动完成"

# 等待 Redis 完全启动
echo "⏳ 等待 Redis 启动..."
until docker exec dujiaoka-redis redis-cli ping | grep -q PONG; do
  sleep 1
done
echo "✅ Redis 启动完成"

# 启动 dujiaoka 容器
echo "🚀 启动独角数卡容器..."
docker-compose up -d dujiaoka

# 等待容器准备就绪
echo "⏳ 等待独角数卡容器准备..."
sleep 10

# 自动运行 migrations
echo "⚡ 运行数据库迁移..."
docker exec -i dujiaoka php artisan migrate --force

# 创建管理员账号
echo "⚡ 初始化后台管理员账号..."
docker exec -i dujiaoka php artisan dujiaoka:admin $ADMIN_USER $ADMIN_PASS

echo "🎉 安装完成！"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "前台地址: http://$IP_ADDR"
echo "后台地址: http://$IP_ADDR/admin"
echo "管理员账户: $ADMIN_USER / $ADMIN_PASS"
echo "数据库用户: dujiaoka / dujiaoka123"
echo "MySQL root 用户: root / root123"
