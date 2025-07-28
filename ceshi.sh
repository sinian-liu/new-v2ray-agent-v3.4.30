#!/bin/bash
set -e

echo "✅ 开始安装 Docker 和 Docker Compose..."

if command -v apt-get &>/dev/null; then
  apt-get update -y
  apt-get install -y ca-certificates curl git gnupg lsb-release
elif command -v yum &>/dev/null; then
  yum install -y ca-certificates curl git gnupg2 redhat-lsb-core
else
  echo "❌ 不支持的系统"
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo "🔧 安装 Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose &>/dev/null; then
  echo "🔧 安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 与 Docker Compose 安装完成"

WORKDIR="/opt/dujiaoka"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 克隆源码（如果存在则拉取更新）
if [ -d "./dujiaoka" ]; then
  cd dujiaoka
  git pull
else
  git clone https://github.com/assimon/dujiaoka.git
  cd dujiaoka
fi

# 交互填写配置
read -rp "请输入数据库名称（默认 dujiaoka）: " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -rp "请输入数据库用户名（默认 root）: " DB_USER
DB_USER=${DB_USER:-root}

while true; do
  read -rp "请输入数据库密码（必填）: " DB_PASS
  [[ -n "$DB_PASS" ]] && break
done

read -rp "请输入站点名称（默认 独角数卡发卡系统）: " SITE_NAME
SITE_NAME=${SITE_NAME:-独角数卡发卡系统}

read -rp "请输入访问域名或IP（用于访问提示）: " DOMAIN

# 复制并修改 .env
cp .env.example .env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env
sed -i "s/^APP_NAME=.*/APP_NAME=\"$SITE_NAME\"/" .env
sed -i "s/^APP_URL=.*/APP_URL=http:\/\/$DOMAIN/" .env
sed -i "s/^APP_DEBUG=.*/APP_DEBUG=false/" .env
sed -i "s/^INSTALL=.*/INSTALL=false/" .env

# 生成 docker-compose.yml 文件
cat > docker-compose.yml << EOF
version: "3.8"

services:
  dujiaoka:
    build: .
    container_name: dujiaoka
    restart: always
    ports:
      - "80:80"
    env_file:
      - ./.env
    volumes:
      - ./uploads:/var/www/html/public/uploads
      - ./storage:/var/www/html/storage

  db:
    image: mysql:5.7
    container_name: dujiaoka-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $DB_PASS
      MYSQL_DATABASE: $DB_NAME
      MYSQL_USER: $DB_USER
      MYSQL_PASSWORD: $DB_PASS
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
EOF

echo "🚀 正在构建并启动容器..."
docker-compose up -d --build

IP=$(curl -s https://ipinfo.io/ip || hostname -I | awk '{print $1}')

echo ""
echo "🎉 独角数卡安装成功！"
echo "🌐 前台访问: http://${DOMAIN:-$IP}"
echo "🔧 管理后台: http://${DOMAIN:-$IP}/admin"
