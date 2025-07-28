#!/bin/bash
set -e

echo "开始安装 Docker 和 Docker Compose..."
if ! command -v docker >/dev/null 2>&1; then
  if [ -f /etc/redhat-release ]; then
    # CentOS安装Docker
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
  elif [ -f /etc/debian_version ]; then
    # Ubuntu/Debian安装Docker
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

# 安装 Docker Compose（v2）
if ! command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_VER="v2.39.1"
  curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
  echo "Docker Compose 安装完成"
else
  echo "检测到已安装 Docker Compose，跳过安装"
fi

# 创建工作目录
WORKDIR="/opt/dujiaoka"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "拉取官方独角数卡镜像 docker-dujiaoka"
# 官方推荐用源码安装，但这里用官方镜像示例，确保项目结构
docker pull assimon/dujiaoka:latest

# 生成docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  dujiaoka:
    image: assimon/dujiaoka:latest
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

# 初始化配置文件模板
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

# 其他配置可按需求补充
EOF

echo "请依次输入独角数卡配置参数："

read -rp "站点名称（APP_NAME，默认 Dujiaoka）: " APP_NAME
APP_NAME=${APP_NAME:-Dujiaoka}

read -rp "站点访问域名（APP_URL，例如 http://example.com）: " APP_URL
APP_URL=${APP_URL:-http://localhost}

read -rp "数据库名称（默认 dujiaoka）: " DB_DATABASE
DB_DATABASE=${DB_DATABASE:-dujiaoka}

read -rp "数据库用户名（默认 dujiaoka）: " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-dujiaoka}

read -rp "数据库密码（默认 dujiaoka_pass）: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-dujiaoka_pass}

read -rp "数据库root密码（默认 rootpassword）: " MYSQL_ROOT_PASSWORD
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-rootpassword}

read -rp "是否开启调试模式？(true/false，默认 false): " APP_DEBUG
APP_DEBUG=${APP_DEBUG:-false}

# 写入 .env 文件
sed "s|APP_NAME=.*|APP_NAME=$APP_NAME|" .env.template | \
sed "s|APP_URL=.*|APP_URL=$APP_URL|" | \
sed "s|DB_DATABASE=.*|DB_DATABASE=$DB_DATABASE|" | \
sed "s|DB_USERNAME=.*|DB_USERNAME=$DB_USERNAME|" | \
sed "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" | \
sed "s|APP_DEBUG=.*|APP_DEBUG=$APP_DEBUG|" > .env

# 修改docker-compose.yml对应的数据库root密码及用户密码
sed -i "s/MYSQL_ROOT_PASSWORD: rootpassword/MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD/" docker-compose.yml
sed -i "s/MYSQL_DATABASE: dujiaoka/MYSQL_DATABASE: $DB_DATABASE/" docker-compose.yml
sed -i "s/MYSQL_USER: dujiaoka/MYSQL_USER: $DB_USERNAME/" docker-compose.yml
sed -i "s/MYSQL_PASSWORD: dujiaoka_pass/MYSQL_PASSWORD: $DB_PASSWORD/" docker-compose.yml

echo "启动独角数卡容器..."
docker-compose up -d

echo "安装完成！请确认端口 80 已开放，访问：$APP_URL"
echo "首次访问后，可能需要在容器内运行初始化命令："
echo "  docker exec -it dujiaoka php artisan migrate --seed"
echo "或者进入容器执行数据库迁移和密钥生成："
echo "  docker exec -it dujiaoka bash"
echo "  php artisan key:generate"
echo "  php artisan migrate --seed"
echo "  exit"

echo "如果访问报错请检查容器日志： docker logs dujiaoka"
