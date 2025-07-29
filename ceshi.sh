#!/bin/bash
set -e

echo "🧙 欢迎使用 Dujiaoka 一键部署脚本"

# 1. 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用 root 权限运行本脚本"
   exit 1
fi

# 2. 安装docker函数
install_docker() {
  echo "🚀 正在安装 Docker..."
  apt update
  apt install -y ca-certificates curl gnupg lsb-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.gpg > /dev/null

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  systemctl enable docker
  systemctl start docker
  echo "✅ Docker 安装完成"
}

# 3. 安装 docker-compose 函数 (独立版本，兼容性强)
install_docker_compose() {
  echo "🚀 正在安装 Docker Compose..."
  DOCKER_COMPOSE_VERSION="v2.20.2"
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  echo "✅ Docker Compose 安装完成"
}

# 4. 检查 docker
if ! command -v docker &> /dev/null; then
  install_docker
else
  echo "✅ Docker 已安装"
fi

# 5. 检查 docker-compose
if ! command -v docker-compose &> /dev/null; then
  install_docker_compose
else
  echo "✅ Docker Compose 已安装"
fi

# 6. 检查端口80是否占用
if lsof -i :80 >/dev/null 2>&1; then
  echo "❌ 端口 80 已被占用，请释放后再运行本脚本"
  exit 1
fi

# 7. 读用户输入
read -p "请输入项目部署目录（默认 dujiaoka）: " PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-dujiaoka}

if [[ "$PROJECT_DIR" == "/" || "$PROJECT_DIR" == "/root" ]]; then
  echo "❌ 错误：不能将项目部署在根目录 / 或 /root 下，请选择非系统目录"
  exit 1
fi

read -p "设置 MySQL 数据库密码（默认 123456）: " MYSQL_PASSWORD
MYSQL_PASSWORD=${MYSQL_PASSWORD:-123456}

read -p "请确认是否继续安装？(yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ 安装已取消"
  exit 1
fi

# 8. 创建目录
echo "📁 正在创建项目目录..."
mkdir -p "$PROJECT_DIR"/{code,mysql}

# 9. 克隆项目代码（若已存在则跳过）
if [ -d "$PROJECT_DIR/code/.git" ]; then
  echo "⚠️ 目录已存在，跳过克隆"
else
  echo "🌐 正在克隆 Dujiaoka 项目源码..."
  git clone https://github.com/assimon/dujiaoka "$PROJECT_DIR/code"
fi

# 10. 生成 .env 文件
echo "⚙️ 生成 .env 配置..."
cat > "$PROJECT_DIR/code/.env" <<EOF
APP_NAME=dujiaoka
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=root
DB_PASSWORD=$MYSQL_PASSWORD

REDIS_HOST=redis
REDIS_PASSWORD=null
EOF

# 11. 生成 nginx 配置
echo "📝 生成 nginx.conf..."
cat > "$PROJECT_DIR/nginx.conf" <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

# 12. 生成 docker-compose.yml
echo "🧱 生成 docker-compose.yml..."
cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
version: '3'

services:
  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    restart: always
    working_dir: /var/www/html
    volumes:
      - ./code:/var/www/html
    depends_on:
      - mysql

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./code:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php

  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_PASSWORD
      MYSQL_DATABASE: dujiaoka
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    restart: always
EOF

# 13. 启动容器
echo "🚀 启动容器..."
cd "$PROJECT_DIR"
docker-compose up -d

# 14. 等待 MySQL 启动
echo "⌛ 等待 MySQL 初始化，约 20 秒..."
sleep 20

# 15. Laravel 初始化
echo "🎯 正在执行 Laravel key:generate 和 config 缓存..."
docker exec -it dujiaoka-php bash -c "cd /var/www/html && php artisan key:generate && php artisan config:cache"

# 16. 是否执行 migrate
read -p "是否执行数据库迁移 php artisan migrate？(yes/no): " MIGRATE_CONFIRM
if [[ "$MIGRATE_CONFIRM" == "yes" ]]; then
  docker exec -it dujiaoka-php bash -c "cd /var/www/html && php artisan migrate --force"
fi

# 17. 显示访问地址
IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "✅ 部署完成！请访问：http://$IP"

exit 0
