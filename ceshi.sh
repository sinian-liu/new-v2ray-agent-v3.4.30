#!/bin/bash

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "错误：未检测到 Docker，请先安装 Docker。"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "错误：未检测到 Docker Compose，请先安装 Docker Compose。"
    exit 1
fi

# 检查 Docker 版本
docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
echo "检测到 Docker 版本：$docker_version"

# 检查 Docker Compose 版本
compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
echo "检测到 Docker Compose 版本：$compose_version"

# 检查 Docker 服务是否运行
if ! docker info &> /dev/null; then
    echo "错误：Docker 服务未运行，请启动 Docker 服务。"
    exit 1
fi

# 获取本机 IP 地址
server_ip=$(hostname -I | awk '{print $1}')
if [ -z "$server_ip" ]; then
    echo "错误：无法获取服务器 IP 地址。"
    exit 1
fi

# 创建目录并设置权限
echo "创建目录 /share/Data/dujiaoka 及其子目录..."
mkdir -p /share/Data/dujiaoka
cd /share/Data/dujiaoka || { echo "错误：无法进入目录 /share/Data/dujiaoka"; exit 1; }
mkdir -p storage uploads
chmod -R 777 storage uploads

# 下载配置文件
echo "下载 env.conf 和 docker-compose.yml..."
wget -q https://raw.githubusercontent.com/stilleshan/dockerfiles/main/dujiaoka/env.conf || { echo "错误：无法下载 env.conf"; exit 1; }
wget -q https://raw.githubusercontent.com/stilleshan/dockerfiles/main/dujiaoka/docker-compose.yml || { echo "错误：无法下载 docker-compose.yml"; exit 1; }
chmod -R 777 env.conf

# 修改 docker-compose.yml 文件
echo "修改 docker-compose.yml 文件..."
cat > docker-compose.yml << 'EOF'
version: "3"

services:
  web:
    image: stilleshan/dujiaoka
    environment:
        # - INSTALL=false
        - INSTALL=true
        # - MODIFY=true
    volumes:
      - ./env.conf:/dujiaoka/.env 
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - 8800:80
    restart: always

  db:
    image: mariadb:focal
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=www.1373737.xyz
      - MYSQL_DATABASE=dujiaoka
      - MYSQL_USER=dujiaoka
      - MYSQL_PASSWORD=www.1373737.xyz
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./redis:/data
EOF

# 修改 env.conf 文件
echo "修改 env.conf 文件..."
cat > env.conf << EOF
APP_NAME=37VPS主机评测（https://www.1373737.xyz/）
APP_ENV=local
APP_KEY=base64:hDVkYhfkUjaePiaI1tcBT7G8bh2A8RQxwWIGkq7BO18=
APP_DEBUG=true
APP_URL=http://$server_ip:8800

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=www.1373737.xyz

# redis配置
REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

# 缓存配置
CACHE_DRIVER=redis

# 异步消息队列
QUEUE_CONNECTION=redis

# 后台语言
DUJIAO_ADMIN_LANGUAGE=zh_CN

# 后台登录地址
ADMIN_ROUTE_PREFIX=/admin

# 是否开启 https 
#ADMIN_HTTPS=true
EOF

# 启动服务
echo "启动 Docker Compose 服务..."
docker-compose up -d || { echo "错误：无法启动 Docker Compose 服务"; exit 1; }

# 输出登录地址、端口和提示信息
echo "安装完成！"
echo "登录地址：http://$server_ip:8800/admin"
echo "端口：8800"
echo "提示：登录网址后，请将 MySQL 数据库地址改为：mysql，Redis 连接地址改为：redis"
