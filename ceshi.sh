#!/bin/bash

set -e

# 检测操作系统类型
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')

# 安装 Docker
if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" ]]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
elif [[ "$OS" == "CentOS Linux" || "$OS" == "CentOS Stream" ]]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
else
    echo "不支持的操作系统: $OS"
    exit 1
fi

# 启动 Docker 服务
sudo systemctl enable --now docker

# 安装 Docker Compose
DOCKER_COMPOSE_VERSION="2.39.1"
sudo curl -L https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version

# 克隆 Dujiaoka 发卡系统仓库
git clone https://github.com/Apocalypsor/dujiaoka-docker.git
cd dujiaoka-docker

# 提示用户输入配置信息
echo "请输入以下配置信息："

read -p "数据库主机（默认为 db）： " DB_HOST
DB_HOST=${DB_HOST:-db}

read -p "数据库端口（默认为 3306）： " DB_PORT
DB_PORT=${DB_PORT:-3306}

read -p "数据库名称（默认为 dujiaoka）： " DB_DATABASE
DB_DATABASE=${DB_DATABASE:-dujiaoka}

read -p "数据库用户名（默认为 dujiaoka）： " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-dujiaoka}

read -p "数据库密码（默认为 dujiaoka）： " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-dujiaoka}

read -p "网站名称（默认为 Dujiaoka）： " APP_NAME
APP_NAME=${APP_NAME:-Dujiaoka}

read -p "网站域名（例如 https://www.yoursite.com）： " APP_URL
APP_URL=${APP_URL:-https://www.yoursite.com}

# 更新 .env 文件
sed -i "s/^DB_HOST=.*/DB_HOST=${DB_HOST}/" .env
sed -i "s/^DB_PORT=.*/DB_PORT=${DB_PORT}/" .env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env
sed -i "s/^APP_NAME=.*/APP_NAME=${APP_NAME}/" .env
sed -i "s/^APP_URL=.*/APP_URL=${APP_URL}/" .env
sed -i "s/^INSTALL=true/INSTALL=false/" .env
sed -i "s/^APP_DEBUG=true/APP_DEBUG=false/" .env

# 启动容器
docker-compose up -d

# 获取服务器 IP 地址
SERVER_IP=$(curl -s ifconfig.me)

# 输出访问地址
echo "Dujiaoka 发卡系统已成功部署！"
echo "您可以通过以下地址访问系统："
echo "前台： http://${SERVER_IP}/"
echo "后台： http://${SERVER_IP}/admin"
