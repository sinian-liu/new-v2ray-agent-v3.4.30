#!/bin/bash
set -e

echo "开始安装 Docker 和 Docker Compose..."
if ! command -v docker >/dev/null 2>&1; then
  if [ -f /etc/redhat-release ]; then
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
  elif [ -f /etc/debian_version ]; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
  else
    echo "暂不支持该操作系统，请手动安装 Docker"
    exit 1
  fi
else
  echo "检测到已安装 Docker，跳过安装"
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_VER="v2.39.1"
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  echo "Docker Compose 安装完成"
else
  echo "检测到已安装 Docker Compose，跳过安装"
fi

WORKDIR="/opt/dujiaoka"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "拉取独角数卡镜像 jiangjuhong/dujiaoka"
docker pull jiangjuhong/dujiaoka:latest

cat > docker-compose.yml <<EOF
version: "3.8"
services:
  dujiaoka:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./uploads:/var/www/html/public/uploads
      - ./storage:/var/www/html/storage
      - ./env:/var/www/html/.env
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
    depends_on:
      - mysql

  mysql:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: dujiaoka_pass
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
EOF

cat > .env.template <<'EOF'
APP_NAME=Dujiaoka
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://your-domain.com

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=dujiaoka_pass

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120
EOF

echo "请输入站点名称（默认 Dujiaoka）："
read -r APP_NAME
APP_NAME=${APP_NAME:-Dujiaoka}

echo "请输入站点域名（例：http://example.com，默认 http://localhost）："
read -r APP_URL
APP_URL=${APP_URL:-http://localhost}

echo "请输入数据库名称（默认 dujiaoka）："
read -r DB_DATABASE
DB_DATABASE=${DB_DATABASE:-dujiaoka}

echo "请输入数据库用户名（默认 dujiaoka）："
read -r DB_USERNAME
DB_USERNAME=${DB_USERNAME:-dujiaoka}

echo "请输入数据库密码（默认 dujiaoka_pass）："
read -r DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-dujiaoka_pass}

echo "请输入MySQL root密码（默认 rootpassword）："
read -r MYSQL_ROOT_PASSWORD
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}

echo "是否开启调试模式？(true/false，默认 false):"
read -r APP_DEBUG
APP_DEBUG=${APP_DEBUG:-false}

sed "s|APP_NAME=.*|APP_NAME=$APP_NAME|" .env.template | \
sed "s|APP_URL=.*|APP_URL=$APP_URL|" | \
sed "s|DB_DATABASE=.*|DB_DATABASE=$DB_DATABASE|" | \
sed "s|DB_USERNAME=.*|DB_USERNAME=$DB_USERNAME|" | \
sed "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" | \
sed "s|APP_DEBUG=.*|APP_DEBUG=$APP_DEBUG|" > .env

sed -i "s/MYSQL_ROOT_PASSWORD: rootpassword/MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD/" docker-compose.yml
sed -i "s/MYSQL_DATABASE: dujiaoka/MYSQL_DATABASE: $DB_DATABASE/" docker-compose.yml
sed -i "s/MYSQL_USER: dujiaoka/MYSQL_USER: $DB_USERNAME/" docker-compose.yml
sed -i "s/MYSQL_PASSWORD: dujiaoka_pass/MYSQL_PASSWORD: $DB_PASSWORD/" docker-compose.yml

echo "启动独角数卡服务..."
docker-compose up -d

echo "安装完成！请确保服务器端口 80 已开放，浏览器访问：$APP_URL"
echo "首次访问可能需要进入容器执行以下命令进行数据库迁移和密钥生成："
echo "  docker exec -it dujiaoka php artisan key:generate"
echo "  docker exec -it dujiaoka php artisan migrate --seed"
echo "查看日志：docker logs dujiaoka"
