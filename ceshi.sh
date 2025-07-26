#!/bin/bash

# Exit on any error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate a random base64 string for APP_KEY
generate_app_key() {
    openssl rand -base64 32
}

# Step 1: Install Docker and Docker Compose
echo "Installing Docker and Docker Compose..."
bash <(curl -sSL https://cdn.jsdelivr.net/gh/SuperManito/LinuxMirrors@main/DockerInstallation.sh)

# Ensure Docker Compose is installed
if ! command_exists docker-compose; then
    echo "Installing docker-compose..."
    yum install -y docker-compose
else
    echo "Docker Compose is already installed."
fi

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Step 2: Initialize directories
INSTALL_DIR="/opt/dujiaoka"
echo "Creating installation directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/shop/{storage,uploads}"
chmod -R 777 "$INSTALL_DIR/shop/storage" "$INSTALL_DIR/shop/uploads"
cd "$INSTALL_DIR"
touch env.conf
touch docker-compose.yml
chmod -R 777 env.conf

# Step 3: Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: "3"

services:
  web:
    image: stilleshan/dujiaoka
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - 8090:80
    restart: always

  db:
    image: mariadb:focal
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=qwerasdf
      - MYSQL_DATABASE=dujiaoka
      - MYSQL_USER=dujiaoka
      - MYSQL_PASSWORD=qwerasdf
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./redis:/data
    ports:
      - 6379:6379
EOF

# Step 4: Create env.conf
echo "Creating env.conf..."
APP_KEY=$(generate_app_key)
cat > env.conf << EOF
APP_NAME=独角数卡
APP_ENV=local
APP_KEY=base64:$APP_KEY
APP_DEBUG=false
APP_URL=http://localhost:8090/

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=172.17.0.1
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=qwerasdf

# redis配置
REDIS_HOST=172.17.0.1
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

# 是否开启https
ADMIN_HTTPS=true
EOF

# Step 5: Start Docker Compose
echo "Starting Docker Compose services..."
docker-compose up -d || docker compose up -d

# Step 6: Provide instructions for next steps
echo "Installation complete!"
echo "Next steps:"
echo "1. Access the web interface at http://<your-server-ip>:8090 to complete the installation."
echo "2. After web installation, modify docker-compose.yml to set INSTALL=false and restart services with:"
echo "   docker-compose restart || docker compose restart"
echo "3. If you encounter issues with access, ensure your domain is bound to the server IP, set up Nginx for reverse proxy, and obtain an SSL certificate."
echo "4. Update env.conf with the correct APP_URL (use your domain) and verify DB_HOST/REDIS_HOST (use 'docker inspect' to find the Docker network IP if 172.17.0.1 doesn't work)."
echo "To stop services: docker-compose down || docker compose down"
