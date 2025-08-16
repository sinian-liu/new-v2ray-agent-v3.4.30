#!/bin/bash
# 独角数卡一键安装脚本 - 使用 jiangjuhong/dujiaoka 镜像

set -e

echo "🚀 独角数卡一键安装开始..."

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# 检查 docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo "⚙️ 未检测到 docker-compose，正在安装..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# 随机数据库信息
DB_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c12)
DB_USER=dujiaouser
DB_NAME=dujiaodb
APP_PORT=80

# 检查端口占用 (用 ss 而不是 netstat)
if ss -tuln | grep -q ":80 "; then
    echo "⚠️ 端口 80 已被占用，请输入新端口 (默认 8080):"
    read -r newport
    APP_PORT=${newport:-8080}
fi

# 创建目录
mkdir -p ~/dujiaoka/{mysql,app}

# 写 docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'
services:
  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka_app
    restart: always
    ports:
      - "$APP_PORT:80"
    volumes:
      - ./app/.env:/app/.env
      - ./app/install.lock:/app/install.lock
    environment:
      WEB_DOCUMENT_ROOT: /app/public
      TZ: Asia/Shanghai
    depends_on:
      - db

  db:
    image: mysql:5.7
    container_name: dujiaoka_db
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASS
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASS
    volumes:
      - ./mysql:/var/lib/mysql
EOF

# 生成 .env 文件
cat > ./app/.env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:$APP_PORT

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

CACHE_DRIVER=file
QUEUE_CONNECTION=sync

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=admin
EOF

# 创建 install.lock 文件，避免重复初始化
touch ./app/install.lock

# 启动容器
docker-compose up -d

SERVER_IP=$(curl -s ifconfig.me || echo "你的服务器IP")

echo "-------------------------------------------"
echo "🎉 独角数卡安装完成！"
echo "🌐 访问地址: http://$SERVER_IP:$APP_PORT"
echo "📂 数据库名: $DB_NAME"
echo "👤 用户名: $DB_USER"
echo "🔑 密码: $DB_PASS"
echo "后台地址: http://$SERVER_IP:$APP_PORT/admin"
echo "-------------------------------------------"
