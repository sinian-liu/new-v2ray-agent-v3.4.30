#!/bin/bash
set -e

# ---- 用户交互输入 ----
read -p "请输入你的域名（例如 example.com）: " DOMAIN
read -p "请输入你的邮箱（用于申请 SSL）: " EMAIL

APP_BASE="/home/web/html"
APP_DIR="${APP_BASE}/dujiaoka"
MYSQL_ROOT_PASSWORD="sinian"
REDIS_PASSWORD=""
ADMIN_ROUTE_PREFIX="/admin"

echo "部署目录：${APP_DIR}"
echo "数据库密码：${MYSQL_ROOT_PASSWORD}"
echo "后台路径：${ADMIN_ROUTE_PREFIX}"

# ---- 系统检测与 Docker 安装 ----
echo "检测操作系统..."
if [ -f /etc/debian_version ]; then
  OS_TYPE="debian"
elif [ -f /etc/redhat-release ]; then
  OS_TYPE="centos"
else
  echo "不支持此系统"; exit 1
fi

if ! command -v docker >/dev/null; then
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker --now
fi

if ! command -v docker-compose >/dev/null && ! docker compose version >/dev/null 2>&1; then
  echo "安装 docker-compose..."
  DOCKER_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "\"tag_name\"" | head -1 | cut -d '"' -f4)
  curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# ---- 准备目录与源码 ----
echo "创建目录：${APP_DIR}"
mkdir -p ${APP_BASE}
cd ${APP_BASE}

echo "下载并解压源码..."
wget -qO dujiaoka.tar.gz "https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz"
apt-get update -qq && apt-get install -y -qq tar
tar -zxf dujiaoka.tar.gz
rm dujiaoka.tar.gz

# ---- 生成 .env 文件 ----
cat > ${APP_DIR}/.env <<EOF
APP_NAME="独角数卡"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://${DOMAIN}

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=root
DB_PASSWORD=${MYSQL_ROOT_PASSWORD}

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=file
SESSION_LIFETIME=120

ADMIN_ROUTE_PREFIX=${ADMIN_ROUTE_PREFIX}
ADMIN_HTTPS=true
EOF

# ---- 生成 docker-compose.yml ----
cat > ${APP_BASE}/docker-compose.yml <<EOF
version: '3.8'
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: dujiaoka
    volumes:
      - ./mysql_data:/var/lib/mysql
    networks: [dujiaoka-net]

  redis:
    image: redis:alpine
    command: redis-server --requirepass "${REDIS_PASSWORD}"
    volumes:
      - ./redis_data:/data
    networks: [dujiaoka-net]

  php:
    image: php:7.4-fpm
    working_dir: /var/www/html/dujiaoka
    volumes:
      - ./dujiaoka:/var/www/html/dujiaoka
    depends_on: [db, redis]
    networks: [dujiaoka-net]

  nginx:
    image: nginx:1.22-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./dujiaoka:/var/www/html/dujiaoka
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certs:/etc/nginx/certs
    depends_on: [php]
    networks: [dujiaoka-net]

networks:
  dujiaoka-net: {}

volumes:
  mysql_data:
  redis_data:
EOF

# ---- 生成 Nginx 配置 ----
mkdir -p ${APP_BASE}/nginx/conf.d
cat > ${APP_BASE}/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/html/dujiaoka/public;
    index index.php index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/html/dujiaoka/public;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    root /var/www/html/dujiaoka/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

# ---- 启动 Docker 容器 ----
cd ${APP_BASE}
docker-compose up -d

echo "等待 MySQL 启动..."
sleep 20

# ---- 安装 PHP 扩展 ----
docker exec php bash -c "
apt-get update -qq \
&& apt-get install -y -qq libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
&& docker-php-ext-configure gd --with-freetype --with-jpeg \
&& docker-php-ext-install zip gd bcmath
"

docker restart php

# ---- 安装 Composer 并执行依赖安装 ----
docker exec php bash -c "
cd /var/www/html/dujiaoka \
&& curl -sS https://getcomposer.org/installer | php \
&& php composer.phar install --no-dev --optimize-autoloader
"

# ---- 生成 APP_KEY ----
docker exec php bash -c "cd /var/www/html/dujiaoka && php artisan key:generate && php artisan config:cache"

# ---- 申请 SSL 证书 ----
if ! command -v acme.sh >/dev/null 2>&1; then
  curl https://get.acme.sh | sh
fi
~/.acme.sh/acme.sh --register-account -m "$EMAIL" --server letsencrypt
~/.acme.sh/acme.sh --issue -d "${DOMAIN}" --standalone --force
mkdir -p ${APP_BASE}/certs
~/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" \
  --key-file   ${APP_BASE}/certs/key.pem \
  --fullchain-file ${APP_BASE}/certs/cert.pem \
  --reloadcmd  "docker restart nginx"

echo "安装完成！"
echo "访问 https://${DOMAIN} 进入安装界面，点击“安装”，后台地址 https://${DOMAIN}${ADMIN_ROUTE_PREFIX}"
