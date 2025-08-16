#!/bin/bash
# 独角数卡一键安装脚本 (ChatGPT 修正版)

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

# 生成随机数据库信息
DB_PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c12)
DB_USER=halo
DB_NAME=halo
APP_PORT=80

# 检查端口占用 (用 ss 而不是 netstat)
if ss -tuln | grep -q ":80 "; then
    echo "⚠️ 端口 80 已被占用，请输入新端口 (默认 8080):"
    read -r newport
    APP_PORT=${newport:-8080}
fi

# 写 docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  app:
    image: dujiaoka/dujiaoka:latest
    container_name: dujiaoka_app
    restart: always
    ports:
      - "$APP_PORT:80"
    volumes:
      - ./dujiaoka:/www/dujiaoka
    environment:
      - DB_CONNECTION=mysql
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=$DB_NAME
      - DB_USERNAME=$DB_USER
      - DB_PASSWORD=$DB_PASS
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

# 启动
docker-compose up -d || {
    echo "⚠️ Docker Hub 拉取失败，切换到阿里云镜像..."
    sed -i 's#dujiaoka/dujiaoka:latest#registry.cn-hangzhou.aliyuncs.com/dujiaoka/dujiaoka:latest#g' docker-compose.yml
    docker-compose up -d
}

SERVER_IP=$(curl -s ifconfig.me || echo "你的服务器IP")

echo "-------------------------------------------"
echo "🎉 独角数卡安装完成！"
echo "🌐 访问地址: http://$SERVER_IP:$APP_PORT"
echo "📂 数据库名: $DB_NAME"
echo "👤 用户名: $DB_USER"
echo "🔑 密码: $DB_PASS"
echo "后台地址: http://$SERVER_IP:$APP_PORT/admin"
echo "-------------------------------------------"
