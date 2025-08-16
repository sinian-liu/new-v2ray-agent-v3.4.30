#!/bin/bash
set -e

echo "🚀 独角数卡增强版一键安装开始..."

# 获取公网 IP
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [[ -z "$PUBLIC_IP" ]]; then
    echo "⚠️ 无法获取公网 IP，请确保服务器能访问外网"
    PUBLIC_IP="127.0.0.1"
fi

# 检测 Docker 是否存在
if ! command -v docker >/dev/null 2>&1; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com | bash
    # 安装 docker-compose
    DOCKER_COMPOSE_VERSION="v2.39.2"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 安装完成"
docker --version
docker-compose version || docker compose version

# 创建工作目录
mkdir -p /opt/dujiaoka
cd /opt/dujiaoka

# 创建 install.lock 避免重复安装
touch install.lock

# 配置默认密码和数据库名
DB_ROOT_PASS="IKctUskuhV6tJgmd"
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS="IKctUskuhV6tJgmd"
REDIS_PASS=""

# 下载 docker-compose.yml
cat > docker-compose.yml << EOF
version: "3"
services:
  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    environment:
      WEB_DOCUMENT_ROOT: /app/public
      TZ: Asia/Shanghai
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./install.lock:/app/install.lock
      - ./env.env:/app/.env
    ports:
      - "80:80"
      - "9000:9000"
    depends_on:
      - db
      - redis
    user: root
    restart: always

  db:
    image: mysql:8.0
    container_name: dujiaoka_db
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASS}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASS}
    volumes:
      - ./mysql:/var/lib/mysql
    restart: always

  redis:
    image: redis:7.0
    container_name: dujiaoka_redis
    command: ["redis-server", "--requirepass", "${REDIS_PASS}"]
    ports:
      - "6379:6379"
    volumes:
      - ./redis:/data
    restart: always
EOF

# 生成 .env 文件
cat > env.env << EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://${PUBLIC_IP}

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASS}
REDIS_PORT=6379

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
EOF

echo "🚀 启动 Docker 容器..."
docker-compose up -d

# 等待数据库和 Redis 启动
echo "⏳ 等待数据库和 Redis 启动..."
until docker exec dujiaoka_db mysqladmin ping -h "127.0.0.1" --silent; do
    echo "⏳ 数据库未就绪，继续等待..."
    sleep 5
done
echo "✅ 数据库已就绪"

# 修复 Laravel 权限
docker exec -i dujiaoka bash -c "chown -R root:root /app/storage /app/bootstrap/cache && chmod -R 775 /app/storage /app/bootstrap/cache"

# 生成 APP_KEY 并写入 .env
echo "🔑 生成 Laravel APP_KEY..."
APP_KEY_VALUE=$(docker exec -i dujiaoka php artisan key:generate --show)
sed -i "s|APP_KEY=|APP_KEY=${APP_KEY_VALUE}|" env.env
docker exec -i dujiaoka php artisan config:clear

# 运行数据库迁移
echo "⚙️ 运行数据库迁移..."
docker exec -i dujiaoka php artisan migrate --force

echo "✅ 安装完成"
echo "🌐 前台地址: http://${PUBLIC_IP}"
echo "🔑 后台登录: http://${PUBLIC_IP}/admin"
echo "用户名: admin"
echo "密码: IKctUskuhV6tJgmd"
