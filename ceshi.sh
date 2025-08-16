#!/bin/bash
set -e

echo "🚀 独角数卡增强版开箱即用安装开始..."

# =============================
# 1. 固定密码与密钥
# =============================
MYSQL_ROOT_PASSWORD="root123456"
MYSQL_USER="dujiaoka"
MYSQL_PASSWORD="dujiaoka123456"
MYSQL_DATABASE="dujiaoka"
REDIS_PORT=6379
ADMIN_USER="admin"
ADMIN_PASS="admin123456"
APP_KEY=$(docker run --rm jiangjuhong/dujiaoka:latest php artisan key:generate --show)

echo "使用固定密码:"
echo "MySQL root 密码: $MYSQL_ROOT_PASSWORD"
echo "MySQL 用户密码: $MYSQL_PASSWORD"
echo "后台账号密码: $ADMIN_USER / $ADMIN_PASS"
echo "Laravel APP_KEY: $APP_KEY"

# =============================
# 2. 安装 Docker & Docker Compose
# =============================
if ! command -v docker &> /dev/null; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker-compose &> /dev/null; then
    echo "⚙️ 未检测到 Docker Compose，正在安装..."
    DOCKER_COMPOSE_VERSION="v2.39.2"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

docker --version
docker-compose --version

# =============================
# 3. 创建独角数卡目录
# =============================
BASE_DIR="/opt/dujiaoka"
mkdir -p $BASE_DIR
cd $BASE_DIR

# =============================
# 4. 自动生成 .env 文件
# =============================
cat > $BASE_DIR/.env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=$APP_KEY
APP_DEBUG=true
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$MYSQL_DATABASE
DB_USERNAME=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD

REDIS_HOST=redis
REDIS_PORT=$REDIS_PORT
REDIS_PASSWORD=

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=file
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
EOF

# =============================
# 5. Docker Compose 文件
# =============================
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  db:
    image: mysql:8.0
    container_name: dujiaoka-db
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: $MYSQL_DATABASE
      MYSQL_USER: $MYSQL_USER
      MYSQL_PASSWORD: $MYSQL_PASSWORD
    volumes:
      - db_data:/var/lib/mysql
    ports:
      - "3306:3306"
    restart: always

  redis:
    image: redis:7
    container_name: dujiaoka-redis
    ports:
      - "${REDIS_PORT}:${REDIS_PORT}"
    restart: always

  dujiaoka:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    environment:
      WEB_DOCUMENT_ROOT: /app/public
      TZ: Asia/Shanghai
    volumes:
      - ./storage:/app/storage
      - ./bootstrap/cache:/app/bootstrap/cache
      - ./ .env:/app/.env
    ports:
      - "80:80"
      - "9000:9000"
    depends_on:
      - db
      - redis
    restart: always

volumes:
  db_data:
EOF

# =============================
# 6. 创建 storage 与 cache 目录并修复权限
# =============================
mkdir -p $BASE_DIR/storage $BASE_DIR/bootstrap/cache
chmod -R 775 $BASE_DIR/storage $BASE_DIR/bootstrap/cache

# =============================
# 7. 启动容器
# =============================
docker-compose up -d

# =============================
# 8. 修复容器内权限
# =============================
docker exec -it dujiaoka chown -R www-data:www-data /app/storage /app/bootstrap/cache
docker exec -it dujiaoka chmod -R 775 /app/storage /app/bootstrap/cache

# =============================
# 9. 数据库迁移
# =============================
echo "⚙️ 运行 Laravel 数据库迁移..."
docker exec -it dujiaoka php artisan migrate --force || true

# =============================
# 10. 安装完成提示
# =============================
IP=$(curl -s ifconfig.me)
echo "✅ 独角数卡增强版开箱即用安装完成！"
echo "🌐 前台访问：http://$IP/"
echo "🔑 后台访问：http://$IP/admin"
echo "后台账号: $ADMIN_USER"
echo "后台密码: $ADMIN_PASS"
echo "MySQL 用户: $MYSQL_USER"
echo "MySQL 密码: $MYSQL_PASSWORD"
echo "MySQL root 密码: $MYSQL_ROOT_PASSWORD"
