#!/bin/bash
set -e

echo "🚀 独角数卡一键安装开始..."

############################################
# 检测 Ubuntu 版本并安装 Docker
############################################
echo "⚙️ 检测 Ubuntu 版本..."
UBUNTU_VERSION=$(lsb_release -rs | cut -d. -f1)
echo "👉 当前版本: Ubuntu $UBUNTU_VERSION"

# 移除旧 docker
apt-get remove -y docker docker-engine docker.io containerd runc || true

# 安装依赖
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common lsb-release gnupg

# Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 添加源
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

# 根据版本选择包
DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin"
if [ "$UBUNTU_VERSION" -ge 22 ]; then
  DOCKER_PACKAGES="$DOCKER_PACKAGES docker-model-plugin"
fi

echo "📦 安装 Docker: $DOCKER_PACKAGES"
apt-get install -y $DOCKER_PACKAGES

# docker-compose 备用
if ! command -v docker-compose &>/dev/null; then
  echo "⚠️ 手动安装 docker-compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

systemctl enable docker
systemctl start docker

echo "✅ Docker 安装完成"
docker --version
docker-compose --version

############################################
# 配置 Dujiaoka
############################################
WORKDIR="/opt/dujiaoka"
mkdir -p $WORKDIR
cd $WORKDIR

# 生成 .env
cat > .env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://$(curl -s ifconfig.me)

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka_pass

# redis配置
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

# 创建 install.lock 避免重复初始化
touch install.lock

# docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3"

services:
  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    ports:
      - "80:80"
    environment:
      TZ: Asia/Shanghai
      WEB_DOCUMENT_ROOT: /app/public
    volumes:
      - ./install.lock:/app/install.lock
      - ./.env:/app/.env
    depends_on:
      - db
      - redis

  db:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root_pass
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: dujiaoka_pass
    volumes:
      - db_data:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - redis_data:/data

volumes:
  db_data:
  redis_data:
EOF

############################################
# 启动
############################################
echo "🚀 启动 Docker 容器..."
docker compose up -d

echo "✅ 独角数卡部署完成!"
echo "👉 访问地址: http://$(curl -s ifconfig.me)"
echo "👉 后台地址: http://$(curl -s ifconfig.me)/admin"
