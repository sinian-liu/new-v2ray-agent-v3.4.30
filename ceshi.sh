#!/bin/bash
set -e

WORKDIR="/opt/dujiaoka"
DEFAULT_PORT=80
ACTION=${1:-install}  # 默认 install，可传 upgrade

echo "🚀 独角数卡脚本开始，模式: $ACTION"

############################################
# 安装 Docker + Docker Compose
############################################
install_docker() {
    if command -v docker &>/dev/null && command -v docker-compose &>/dev/null; then
        echo "✅ Docker 和 Docker Compose 已安装"
        return
    fi

    echo "⚙️ 安装 Docker..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common lsb-release gnupg lsof net-tools

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin || true

    if ! command -v docker-compose &>/dev/null; then
      curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi

    systemctl enable docker
    systemctl start docker
}

install_docker

echo "✅ Docker 安装完成: $(docker --version), Docker Compose: $(docker-compose --version)"

############################################
# 创建工作目录
############################################
mkdir -p $WORKDIR
cd $WORKDIR

############################################
# 端口交互选择
############################################
APP_PORT=$DEFAULT_PORT
while lsof -i:$APP_PORT &>/dev/null; do
    echo "⚠️ 端口 $APP_PORT 已被占用"
    read -p "是否更改端口？(y/n)：" yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        read -p "请输入新端口号（例如 8080）：" APP_PORT
    else
        echo "安装取消，请释放端口 $APP_PORT 后再试"
        exit 1
    fi
done
echo "使用端口: $APP_PORT"

############################################
# 公网 IP 获取
############################################
SERVER_IP=$(curl -s https://api.ipify.org || curl -s https://ipinfo.io/ip || hostname -I | awk '{print $1}')

############################################
# 安装模式: 初始化 .env 和 install.lock
############################################
if [ "$ACTION" = "install" ] && [ ! -f .env ]; then
    echo "⚙️ 生成 .env 和随机密码"
    RANDOM_PASS=$(openssl rand -base64 12)

    cat > .env <<EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=true
APP_URL=http://$SERVER_IP:$APP_PORT

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=$RANDOM_PASS

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=file
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
ADMIN_USER=admin
ADMIN_PASS=$RANDOM_PASS
EOF

    touch install.lock
fi

############################################
# docker-compose.yml
############################################
cat > docker-compose.yml <<EOF
version: "3"
services:
  app:
    image: jiangjuhong/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    ports:
      - "$APP_PORT:80"
    environment:
      TZ: Asia/Shanghai
      WEB_DOCUMENT_ROOT: /app/public
    volumes:
      - ./install.lock:/app/install.lock
      - ./.env:/app/.env
    depends_on:
      - db
      - redis

  db:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: $RANDOM_PASS
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: $RANDOM_PASS
    volumes:
      - db_data:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - redis_data:/data

volumes:
  db_data:
  redis_data:
EOF

############################################
# 启动容器
############################################
docker compose pull
docker compose up -d --remove-orphans

############################################
# 等待数据库启动
############################################
echo "⏳ 等待数据库启动..."
sleep 15

############################################
# 运行 Laravel 数据库迁移
############################################
echo "⚙️ 初始化数据库表 (运行 migrations)..."
docker exec -i dujiaoka php artisan migrate --force || true
docker exec -i dujiaoka php artisan key:generate || true
docker exec -i dujiaoka php artisan config:cache || true
docker exec -i dujiaoka php artisan route:cache || true
docker exec -i dujiaoka php artisan view:clear || true

############################################
# 显示访问信息
############################################
echo -e "\n✅ 独角数卡安装完成！"
echo -e "🌐 前台网站: http://$SERVER_IP:$APP_PORT"
echo -e "🔑 后台登录: http://$SERVER_IP:$APP_PORT/admin"
echo -e "后台管理员账户: admin"
echo -e "后台管理员密码: $RANDOM_PASS"
echo -e "数据库用户: dujiaoka"
echo -e "数据库密码: $RANDOM_PASS"
