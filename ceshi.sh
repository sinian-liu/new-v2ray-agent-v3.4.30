#!/bin/bash

set -e

echo "✅ 开始安装 Docker 和 Docker Compose..."

# 统一更新
apt-get update -y || yum update -y

# 安装依赖
if command -v apt-get &> /dev/null; then
    apt-get install -y curl ca-certificates gnupg lsb-release sudo
elif command -v yum &> /dev/null; then
    yum install -y curl ca-certificates gnupg2 redhat-lsb-core sudo
fi

# 安装 Docker
if ! command -v docker &> /dev/null; then
    echo "🔧 正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# 安装 docker-compose（二进制方式）
if ! command -v docker-compose &> /dev/null; then
    echo "🔧 正在安装 Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 与 Compose 安装完成"

# 设置目录
INSTALL_DIR="/opt/dujiaoka"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 克隆项目
if [ ! -d "${INSTALL_DIR}/docker-dujiaoka" ]; then
    git clone https://github.com/assimon/dujiaoka-docker.git docker-dujiaoka
fi
cd docker-dujiaoka

# 获取用户交互输入
read -p "❓ 请输入数据库名称 [默认: dujiaoka]: " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -p "❓ 请输入数据库用户名 [默认: root]: " DB_USER
DB_USER=${DB_USER:-root}

read -p "❓ 请输入数据库密码 [必填]: " DB_PASS
while [[ -z "$DB_PASS" ]]; do
    read -p "⚠️  数据库密码不能为空，请重新输入: " DB_PASS
done

read -p "❓ 请输入站点名称 [默认: 独角数卡发卡系统]: " SITE_NAME
SITE_NAME=${SITE_NAME:-独角数卡发卡系统}

read -p "❓ 请输入绑定的域名或服务器IP（用于访问提示）: " DOMAIN

# 复制 env 文件并替换配置
cp .env.example .env

sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env
sed -i "s/^APP_NAME=.*/APP_NAME=\"$SITE_NAME\"/" .env
sed -i "s/^INSTALL=true/INSTALL=false/" .env
sed -i "s/^APP_DEBUG=true/APP_DEBUG=false/" .env

# 启动 Docker 容器
echo "🚀 启动 Dujiaoka..."
docker-compose up -d

# 输出访问信息
IP=$(curl -s https://ipinfo.io/ip || hostname -I | awk '{print $1}')
echo "✅ 安装完成！"

echo "🔗 请访问独角数卡系统: http://${DOMAIN:-$IP}"
