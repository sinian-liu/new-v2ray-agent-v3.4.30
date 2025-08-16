#!/bin/bash
set -e
echo "🚀 独角数卡增强版一键安装开始..."

# 更新系统
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common

# 安装 Docker
echo "⚙️ 安装 Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin

# 手动安装 Docker Compose（兼容性更好）
echo "⚙️ 安装 Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.39.2"
curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker --version
docker-compose --version

# 创建项目目录
echo "⚙️ 创建独角数卡目录..."
APP_DIR="/opt/dujiaoka"
mkdir -p $APP_DIR
cd $APP_DIR

# 下载 Docker Compose 文件
echo "⚙️ 生成 docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  db:
    image: mysql:8.0
    container_name: dujiaoka-mysql
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

  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    depends_on:
      - db
      - redis
    environment:
      WEB_DOCUMENT_ROOT: /app/public
      TZ: Asia/Shanghai
    volumes:
      - ./install.lock:/app/install.lock
      - ./storage:/app/storage
    ports:
      - "80:80"
      - "9000:9000"
    restart: always
volumes:
  db_data:
EOF

# 创建 install.lock 文件，避免每次初始化
touch $APP_DIR/install.lock

# 修复 storage 目录权限
mkdir -p $APP_DIR/storage
chmod -R 777 $APP_DIR/storage

# 自动生成 .env 文件
cat > $APP_DIR/.env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=$(docker run --rm jiangjuhong/dujiaoka php artisan key:generate --show)
APP_DEBUG=true
APP_URL=http://$(curl -s ifconfig.me)

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka123

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120
CACHE_DRIVER=file
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
EOF

# 启动容器
echo "🚀 启动 Docker 容器..."
docker-compose up -d

echo "✅ 安装完成！"
echo "🌐 前台访问: http://$(curl -s ifconfig.me)/"
echo "🔑 后台登录: http://$(curl -s ifconfig.me)/admin"
echo "默认管理员账号: admin"
echo "默认管理员密码: 12345678"
echo "MySQL 用户: dujiaoka / dujiaoka123"
echo "Redis 默认端口: 6379"
