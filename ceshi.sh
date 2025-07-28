#!/bin/bash
set -e

APP_ROOT="/home/web/html/web5"
APP_CODE_DIR="$APP_ROOT/dujiaoka"
DOCKER_COMPOSE_FILE="$APP_ROOT/docker-compose.yml"
ENV_FILE="$APP_CODE_DIR/.env"

MYSQL_ROOT_PASSWORD="root_pass_123"
MYSQL_USER="dujiaoka"
MYSQL_PASSWORD="dujiaoka_pass"
MYSQL_DATABASE="dujiaoka"

# 安装 Docker 和 Docker Compose（如未安装）
install_docker() {
  if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
    echo "检测到已安装 Docker 和 Docker Compose，跳过安装。"
  else
    echo "开始安装 Docker 和 Docker Compose..."
    curl -fsSL https://get.docker.com | sh
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "Docker 与 Docker Compose 安装完成。"
  fi
}

# 安装 MySQL 容器（如未启动）
install_mysql() {
  if docker ps -q -f name=dujiaoka-mysql | grep -q .; then
    echo "检测到 MySQL 容器已运行，跳过安装。"
  else
    echo "启动 MySQL 容器..."
    docker run -d --name dujiaoka-mysql \
      -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
      -e MYSQL_USER="$MYSQL_USER" \
      -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
      -e MYSQL_DATABASE="$MYSQL_DATABASE" \
      -v "$APP_ROOT/mysql:/var/lib/mysql" \
      --restart unless-stopped \
      mysql:5.7
    echo "MySQL 容器启动完成。"
  fi
}

# 下载独角数卡代码
download_code() {
  mkdir -p "$APP_ROOT"
  cd "$APP_ROOT"
  if [ -d "$APP_CODE_DIR" ]; then
    echo "独角数卡代码目录已存在，跳过下载。"
  else
    echo "开始下载独角数卡代码..."
    wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
    mkdir -p "$APP_CODE_DIR"
    tar -zxvf 2.0.6-antibody.tar.gz -C "$APP_CODE_DIR" --strip-components=1
    rm -f 2.0.6-antibody.tar.gz
    echo "代码下载完成。"
  fi
}

# 生成 .env 配置文件
generate_env() {
  read -p "请输入站点名称（默认：Dujiaoka）: " APP_NAME
  APP_NAME=${APP_NAME:-Dujiaoka}

  read -p "请输入站点URL（默认：http://localhost）: " APP_URL
  APP_URL=${APP_URL:-http://localhost}

  read -p "请输入数据库名称（默认：$MYSQL_DATABASE）: " DB_DATABASE
  DB_DATABASE=${DB_DATABASE:-$MYSQL_DATABASE}

  read -p "请输入数据库用户名（默认：$MYSQL_USER）: " DB_USERNAME
  DB_USERNAME=${DB_USERNAME:-$MYSQL_USER}

  read -p "请输入数据库密码（默认：$MYSQL_PASSWORD）: " DB_PASSWORD
  DB_PASSWORD=${DB_PASSWORD:-$MYSQL_PASSWORD}

  read -p "是否开启调试模式？(true/false，默认false): " APP_DEBUG
  APP_DEBUG=${APP_DEBUG:-false}

  cat > "$ENV_FILE" <<EOF
APP_NAME=$APP_NAME
APP_URL=$APP_URL
APP_DEBUG=$APP_DEBUG

DB_CONNECTION=mysql
DB_HOST=dujiaoka-mysql
DB_PORT=3306
DB_DATABASE=$DB_DATABASE
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
EOF
  echo ".env 文件生成完成。"
}

# 生成docker-compose.yml
generate_docker_compose() {
  cat > "$DOCKER_COMPOSE_FILE" <<EOF
version: '3.8'
services:
  dujiaoka-php:
    image: php:7.4-fpm
    container_name: dujiaoka-php
    volumes:
      - ./dujiaoka:/var/www/html
    working_dir: /var/www/html
    depends_on:
      - dujiaoka-mysql

  dujiaoka-nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./dujiaoka:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - dujiaoka-php

  dujiaoka-mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD
      MYSQL_DATABASE: $MYSQL_DATABASE
      MYSQL_USER: $MYSQL_USER
      MYSQL_PASSWORD: $MYSQL_PASSWORD
    volumes:
      - ./mysql:/var/lib/mysql
EOF
  echo "docker-compose.yml 生成完成。"
}

# 生成简单 nginx 配置
generate_nginx_conf() {
  cat > "$APP_ROOT/nginx.conf" <<EOF
server {
  listen 80;
  server_name localhost;

  root /var/www/html/public;
  index index.php index.html;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location ~ \.php$ {
    fastcgi_pass dujiaoka-php:9000;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  }

  location ~ /\.ht {
    deny all;
  }
}
EOF
  echo "nginx.conf 生成完成。"
}

# 启动容器
start_containers() {
  cd "$APP_ROOT"
  docker-compose up -d
  echo "容器启动完成。"
}

# 提示用户初始化数据库
print_init_tips() {
  echo
  echo "独角数卡已启动！访问地址请打开：http://服务器IP 或 域名"
  echo "首次运行请执行以下命令初始化数据库："
  echo "docker exec -it dujiaoka-php bash"
  echo "cd /var/www/html"
  echo "php artisan key:generate"
  echo "php artisan migrate --seed"
  echo "初始化完成后即可访问后台。"
  echo
}

# 主流程
main() {
  install_docker
  download_code
  generate_env
  generate_nginx_conf
  generate_docker_compose
  install_mysql
  start_containers
  print_init_tips
}

main
