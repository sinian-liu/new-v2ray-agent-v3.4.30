#!/usr/bin/env bash
set -e

# 1. 安装 Docker 和 docker-compose（适用于 Debian/Ubuntu）
if ! command -v docker >/dev/null; then
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com | sh
fi
if ! command -v docker-compose >/dev/null; then
  echo "安装 docker-compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-$(uname -m)" \
    -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
fi

# 2. 创建项目目录结构
WORKDIR="${1:-dujiaoka_shop}"
echo "创建目录：$WORKDIR"
mkdir -p "$WORKDIR"/{storage,uploads,redis,data}
cd "$WORKDIR"
chmod -R 777 storage uploads

# 3. 生成 env.conf（首次INSTALL=true）
cat > env.conf <<'EOF'
APP_NAME=独角数卡
APP_ENV=production
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8090

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka_pass

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
ADMIN_HTTPS=false
EOF
chmod 666 env.conf

# 4. 生成 docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3"
services:
  faka:
    image: ghcr.io/apocalypsor/dujiaoka:latest
    container_name: dujiaoka_web
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - "8090:80"
    restart: always

  db:
    image: mariadb:focal
    container_name: dujiaoka_db
    environment:
      - MYSQL_ROOT_PASSWORD=root_pass
      - MYSQL_DATABASE=dujiaoka
      - MYSQL_USER=dujiaoka
      - MYSQL_PASSWORD=dujiaoka_pass
    volumes:
      - ./data:/var/lib/mysql
    restart: always

  redis:
    image: redis:alpine
    container_name: dujiaoka_redis
    volumes:
      - ./redis:/data
    restart: always
EOF

# 5. 启动服务
echo "启动 Docker 容器..."
docker-compose up -d

echo "请在浏览器打开 http://localhost:8090 进行初次安装（管理员账号默认 admin/admin）"
echo "安装完成后，脚本会提示你将 INSTALL 改为 false 并重启容器"

# 等待用户确认后修改 INSTALL 并重启
read -p "初次安装完成后按回车继续..."

# 用户确认后自动修改 INSTALL 和 DEBUG 设置
sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yml
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf
sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' env.conf

echo "更新配置，将自动启用 HTTPS 并禁用安装模式"
docker-compose down && docker-compose up -d
echo "重启完成，独角数卡已部署并运行"
