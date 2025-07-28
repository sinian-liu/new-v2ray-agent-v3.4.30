#!/bin/bash

set -e

echo "===== 独角数卡 Docker 安装器（基于 2.0.6-antibody）====="

read -rp "站点名称 (APP_NAME) [Dujiaoka]: " APP_NAME
APP_NAME=${APP_NAME:-Dujiaoka}

read -rp "域名 (不含 http，例如 dujiaoka.com) [localhost]: " DOMAIN
DOMAIN=${DOMAIN:-localhost}

read -rp "数据库名 [dujiaoka]: " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -rp "数据库用户名 [dujiaoka]: " DB_USER
DB_USER=${DB_USER:-dujiaoka}

read -rsp "数据库密码: " DB_PASS
echo

read -rp "Redis 密码 (可留空): " REDIS_PASS

read -rp "安装路径 (默认 /home/web/html/web5): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/home/web/html/web5}

echo ">>> 检查并安装必要依赖..."

if ! command -v docker >/dev/null 2>&1; then
  echo "检测到未安装 Docker，开始安装 Docker..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker
  systemctl start docker
else
  echo "检测到已安装 Docker，跳过安装。"
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "检测到未安装 Docker Compose，开始安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
else
  echo "检测到已安装 Docker Compose，跳过安装。"
fi

echo ">>> 准备安装目录 $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ -d "dujiaoka" ]; then
  echo "检测到已有 dujiaoka 目录，删除旧目录..."
  rm -rf dujiaoka
fi

echo ">>> 下载独角数卡源码 v2.0.6-antibody..."
wget -q --show-progress -O dujiaoka.tar.gz https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz

echo ">>> 解压源码包..."
tar -zxvf dujiaoka.tar.gz
rm dujiaoka.tar.gz

# 生成 .env 文件
cat > dujiaoka/.env <<EOF
APP_NAME=$APP_NAME
APP_URL=http://$DOMAIN
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
REDIS_PASSWORD=$REDIS_PASS
DEBUG=true
EOF

echo ".env 文件生成完成。"

# 生成简单 docker-compose.yml 文件
cat > dujiaoka/docker-compose.yml <<EOF
version: "3"

services:
  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $DB_PASS
      MYSQL_DATABASE: $DB_NAME
      MYSQL_USER: $DB_USER
      MYSQL_PASSWORD: $DB_PASS
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - dujiaoka-net

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    restart: always
    command: redis-server --requirepass "$REDIS_PASS"
    networks:
      - dujiaoka-net

  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    restart: always
    working_dir: /var/www/html
    volumes:
      - ./dujiaoka:/var/www/html
    networks:
      - dujiaoka-net

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./dujiaoka:/var/www/html:ro
      - ./dujiaoka/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - php
    networks:
      - dujiaoka-net

volumes:
  mysql-data:

networks:
  dujiaoka-net:
EOF

echo "docker-compose.yml 文件生成完成。"

echo ">>> 启动 Docker 容器..."
docker-compose -f dujiaoka/docker-compose.yml up -d

echo "独角数卡 Docker 容器已启动！"
echo "访问地址请打开 http://$DOMAIN 或服务器 IP"

echo "首次运行需要进入 PHP 容器初始化数据库，执行以下命令："
echo "  docker exec -it dujiaoka-php bash"
echo "  php artisan key:generate"
echo "  php artisan migrate --seed"

echo "如果是首次运行，请务必执行上述初始化命令！"
