#!/bin/bash

# 独角数卡一键安装脚本 (基于 Docker)
# 支持 Ubuntu, Debian, CentOS
# 作者：基于 GitHub Apocalypsor/dujiaoka-docker 适配

set -e

# 颜色输出函数
echo_green() { echo -e "\033[32m$1\033[0m"; }
echo_red() { echo -e "\033[31m$1\033[0m"; }
echo_yellow() { echo -e "\033[33m$1\033[0m"; }

# 检测 OS
OS=""
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt-get"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    if grep -q "CentOS Linux release 8" /etc/redhat-release; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
else
    echo_red "不支持的操作系统！仅支持 Ubuntu/Debian/CentOS。"
    exit 1
fi

# 安装必要工具
echo_yellow "更新包管理器并安装必要工具..."
if [ "$OS" = "debian" ]; then
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install -y curl wget openssl ca-certificates
else
    sudo $PKG_MANAGER makecache
    sudo $PKG_MANAGER install -y curl wget openssl ca-certificates
fi

# 安装 Docker 如果未安装
if ! command -v docker &> /dev/null; then
    echo_yellow "安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo_green "Docker 已安装。"
fi

# 安装 docker-compose 如果未安装
if ! command -v docker-compose &> /dev/null; then
    echo_yellow "安装 docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo_green "docker-compose 已安装。"
fi

# 创建工作目录
INSTALL_DIR="$PWD/dujiaoka"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
mkdir -p storage uploads data redis
chmod -R 777 storage uploads data redis

# 生成随机密码
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
APP_KEY="base64:$(openssl rand -base64 32)"
APP_NAME="Dujiaoka"
APP_URL="http://$(curl -s ifconfig.me)"  # 自动获取公网 IP，如果本地测试用 localhost

# 打印密码信息
echo_green "生成的配置信息（请保存）："
echo "数据库 Root 密码: $DB_ROOT_PASSWORD"
echo "数据库用户密码: $DB_PASSWORD"
echo "应用密钥: $APP_KEY"
echo "访问 URL: $APP_URL (admin 路径: $APP_URL/admin, 默认账号: admin / admin123)"

# 创建 .env 文件
cat > env.conf << EOF
APP_NAME=$APP_NAME
APP_ENV=local
APP_KEY=$APP_KEY
APP_DEBUG=false
APP_URL=$APP_URL

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=$DB_PASSWORD

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
EOF

# 创建 docker-compose.yml
cat > docker-compose.yml << EOF
version: "3"

services:
  faka:
    image: ghcr.io/apocalypsor/dujiaoka:latest
    container_name: faka
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - "80:80"  # 暴露到主机 80 端口
    restart: always
    depends_on:
      - db
      - redis

  db:
    image: mariadb:latest
    container_name: faka-db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD
      - MYSQL_DATABASE=dujiaoka
      - MYSQL_USER=dujiaoka
      - MYSQL_PASSWORD=$DB_PASSWORD
    volumes:
      - ./data:/var/lib/mysql

  redis:
    image: redis:alpine
    container_name: faka-redis
    restart: always
    volumes:
      - ./redis:/data
EOF

# 启动服务
echo_yellow "启动 Docker Compose 服务..."
sudo docker-compose up -d

# 等待安装完成
sleep 30  # 等待 30 秒让安装运行
echo_green "安装完成！访问 $APP_URL 进行进一步配置。"
echo_yellow "如果需要停止/重启: cd $INSTALL_DIR && sudo docker-compose down / up -d"
