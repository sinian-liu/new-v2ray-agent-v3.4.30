#!/bin/bash
set -e

echo "=============================="
echo " 🚀 独角数卡 (Dujiaoka) 自动安装 "
echo "  适配: Ubuntu / Debian / CentOS (新旧版通用) "
echo "  自动安装 Docker + docker-compose "
echo "  自动获取公网 IP 并配置 APP_URL "
echo "=============================="

# 检查 root
if [ "$(id -u)" != "0" ]; then
   echo "❌ 请使用 root 用户运行"
   exit 1
fi

# 安装基础工具
if [ -f /etc/redhat-release ]; then
    yum install -y curl wget tar
else
    apt update -y
    apt install -y curl wget tar
fi

# 安装 Docker (静态二进制)
if ! command -v docker &> /dev/null; then
    echo "👉 安装 Docker..."
    DOCKER_VERSION="24.0.9"
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz -o docker.tgz
    tar xzvf docker.tgz
    mv docker/* /usr/bin/
    rm -rf docker docker.tgz
    cat > /etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Service
After=network.target

[Service]
ExecStart=/usr/bin/dockerd -H unix://
Restart=always
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
else
    echo "✅ Docker 已安装"
fi

# 安装 docker-compose (静态二进制)
if ! command -v docker-compose &> /dev/null; then
    echo "👉 安装 Docker Compose..."
    COMPOSE_VERSION="2.20.3"
    curl -L "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "✅ Docker Compose 已安装"
fi

# 自动获取公网 IP
PUB_IP=$(curl -s https://ip.tsinghua.cloud)
if [[ -z "$PUB_IP" ]]; then
    PUB_IP="localhost"
    echo "⚠️ 无法获取公网 IP，默认使用 localhost"
fi
echo "👉 检测到公网 IP: $PUB_IP"

# 默认安装参数
INSTALL_DIR="/root/data/docker_data/shop"
WEB_PORT=8090
MYSQL_ROOT_PASS="rootpass"
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS="dbpass"
APP_NAME="咕咕的小卖部"
APP_URL="http://${PUB_IP}:${WEB_PORT}"

# 创建安装目录
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 生成 docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'

services:
  dujiaoka:
    image: dujiaoka/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    ports:
      - "${WEB_PORT}:80"
    environment:
      - DB_CONNECTION=mysql
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=${DB_NAME}
      - DB_USERNAME=${DB_USER}
      - DB_PASSWORD=${DB_PASS}
      - APP_NAME=${APP_NAME}
      - APP_URL=${APP_URL}
    depends_on:
      - db

  db:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASS}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASS}
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
EOF

# 启动容器
echo "👉 启动容器..."
docker-compose up -d

# 输出结果
echo "✅ 独角数卡安装完成！"
echo "访问地址: ${APP_URL}"
