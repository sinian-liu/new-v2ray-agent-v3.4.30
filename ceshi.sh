#!/bin/bash
set -e

echo "✅ 开始安装 Docker 和 Docker Compose..."

# 安装依赖并判断系统类型
if command -v apt-get &>/dev/null; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
elif command -v yum &>/dev/null; then
  yum install -y ca-certificates curl gnupg2 redhat-lsb-core
else
  echo "❌ 不支持的系统"
  exit 1
fi

# 安装 Docker（如果没装）
if ! command -v docker &>/dev/null; then
  echo "🔧 安装 Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# 安装 Docker Compose（如果没装）
if ! command -v docker-compose &>/dev/null; then
  echo "🔧 安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

echo "✅ Docker 与 Docker Compose 安装完成"

# 准备安装目录
INSTALL_DIR="/opt/dujiaoka"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 交互输入配置
read -rp "请输入数据库名称（默认dujiaoka）: " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -rp "请输入数据库用户名（默认root）: " DB_USER
DB_USER=${DB_USER:-root}

while true; do
  read -rp "请输入数据库密码（必填）: " DB_PASS
  [[ -n "$DB_PASS" ]] && break
done

read -rp "请输入站点名称（默认独角数卡发卡系统）: " SITE_NAME
SITE_NAME=${SITE_NAME:-独角数卡发卡系统}

read -rp "请输入站点访问域名或IP（用于访问提示）: " DOMAIN

# 生成 .env 文件
cat > .env <<EOF
INSTALL=false
APP_DEBUG=false
APP_URL=http://$DOMAIN
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
APP_NAME="$SITE_NAME"
EOF

# 生成 docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  dujiaoka:
    image: jiangjuhong/dujiaoka:latest
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

echo "🚀 启动容器..."
docker-compose up -d

IP=$(curl -s https://ipinfo.io/ip || hostname -I | awk '{print $1}')

echo ""
echo "🎉 独角数卡已成功部署！"
echo "🌐 访问前台: http://${DOMAIN:-$IP}"
echo "🔧 管理后台: http://${DOMAIN:-$IP}/admin"
