#!/bin/bash
# ==============================================
# 独角数卡 Dujiaoka 一键交互式安装脚本
# 基于 Docker + Docker Compose 部署
# ==============================================
set -e

echo "=============================="
echo " 🚀 独角数卡 (Dujiaoka) 一键安装 "
echo "=============================="
sleep 1

# 1. 安装 Docker & Docker Compose
read -p "是否需要安装 Docker 和 Docker Compose? (y/n, 默认 y): " INSTALL_DOCKER
INSTALL_DOCKER=${INSTALL_DOCKER:-y}

if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
  echo "👉 开始安装 Docker..."
  curl -fsSL https://get.docker.com | sh

  echo "👉 开始安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  echo "✅ Docker & Docker Compose 安装完成"
else
  echo "⚠️ 跳过 Docker 安装"
fi

# 2. 设置安装目录
read -p "请输入安装目录 (默认 /root/data/docker_data/shop): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/root/data/docker_data/shop}
echo "👉 安装目录设定为: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 3. 创建目录和文件
mkdir -p storage uploads mysql redis
chmod -R 777 storage uploads

touch env.conf
chmod 777 env.conf

# 4. 设置端口
read -p "请输入访问端口 (默认 8090): " PORT
PORT=${PORT:-8090}

# 5. MySQL 配置
read -p "设置 MySQL root 密码 (默认 rootpass): " MYSQL_ROOT_PASS
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-rootpass}

read -p "设置数据库名称 (默认 dujiaoka): " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -p "设置数据库用户名 (默认 dujiaoka): " DB_USER
DB_USER=${DB_USER:-dujiaoka}

read -p "设置数据库用户密码 (默认 dbpass): " DB_PASS
DB_PASS=${DB_PASS:-dbpass}

# 6. APP 配置
read -p "设置 APP 名称 (默认 咕咕的小卖部): " APP_NAME
APP_NAME=${APP_NAME:-咕咕的小卖部}

read -p "设置 APP_URL (如 https://yourdomain.com, 默认 http://localhost): " APP_URL
APP_URL=${APP_URL:-http://localhost}

# 7. 生成 docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3"
services:
  web:
    image: stilleshan/dujiaoka
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - ${PORT}:80
    restart: always

  db:
    image: mariadb:focal
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASS}
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./redis:/data
EOF

# 8. 生成 env.conf
APP_KEY=$(openssl rand -base64 32)
cat > env.conf <<EOF
APP_NAME=${APP_NAME}
APP_ENV=local
APP_KEY=base64:${APP_KEY}
APP_DEBUG=true
APP_URL=${APP_URL}

LOG_CHANNEL=stack
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
ADMIN_HTTPS=true
EOF

# 9. 启动容器
echo "👉 启动容器..."
docker-compose up -d

SERVER_IP=$(curl -s ifconfig.me || echo "你的服务器IP")
echo "======================================="
echo " ✅ 安装完成！"
echo " 请访问: http://${SERVER_IP}:${PORT} 开始初始化安装"
echo " 管理后台: http://${SERVER_IP}:${PORT}/admin"
echo "======================================="

# 10. 是否关闭 INSTALL & DEBUG
read -p "是否在完成安装后自动关闭 INSTALL & 调试模式? (y/n, 默认 y): " OPTIMIZE
OPTIMIZE=${OPTIMIZE:-y}

if [[ "$OPTIMIZE" =~ ^[Yy]$ ]]; then
  docker-compose down
  sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yml
  sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf
  docker-compose up -d
  echo "✅ 已关闭 INSTALL 和 Debug 模式，容器已重启"
fi

echo "🎉 独角数卡搭建完成！默认后台账号密码：admin / admin"
