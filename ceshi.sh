#!/bin/bash

# === 配置输入 ===
echo "===== 独角数卡 Docker 安装器（修复版）====="
read -p "站点名称 (APP_NAME) [dujiaoka]: " APP_NAME
APP_NAME=${APP_NAME:-dujiaoka}

read -p "域名 (不含 http) [localhost]: " SITE_URL
SITE_URL=${SITE_URL:-localhost}

read -p "数据库名 [dujiaoka]: " DB_NAME
DB_NAME=${DB_NAME:-dujiaoka}

read -p "数据库用户名 [root]: " DB_USER
DB_USER=${DB_USER:-root}

read -p "数据库密码 [dujiaoka_pass]: " DB_PASS
DB_PASS=${DB_PASS:-dujiaoka_pass}

read -p "Redis 密码 (可留空): " REDIS_PASS

read -p "安装路径 (默认 /home/web/html/web5): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/home/web/html/web5}

# === 安装 docker 和 docker-compose（如未安装） ===
if ! command -v docker &> /dev/null; then
  echo "安装 Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker compose &> /dev/null; then
  echo "安装 docker-compose 插件..."
  apt install -y docker-compose-plugin
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# === 克隆代码仓库 ===
if [ -d "$INSTALL_DIR/dujiaoka" ]; then
  echo "目录 dujiaoka 已存在，重命名为 dujiaoka.bak"
  mv dujiaoka "dujiaoka.bak_$(date +%s)"
fi

git clone https://github.com/assimon/dujiaoka.git

cd dujiaoka || exit

# === 创建必要目录 ===
mkdir -p public/uploads
chmod -R 777 public/uploads

# === 生成 .env 配置 ===
cat > .env <<EOF
APP_NAME="${APP_NAME}"
APP_URL="http://${SITE_URL}"
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}
REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASS}
APP_DEBUG=true
EOF

# === docker-compose 文件 ===
cat > docker-compose.yml <<EOF
services:
  php:
    image: php:8.0-fpm
    container_name: dujiaoka-php
    working_dir: /var/www/html
    volumes:
      - ./:/var/www/html
    networks:
      - app_net

  nginx:
    image: nginx:stable-alpine
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./:/var/www/html
    depends_on:
      - php
    networks:
      - app_net

  db:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASS}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASS}
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app_net

  redis:
    image: redis:alpine
    container_name: dujiaoka-redis
    command: redis-server --requirepass "${REDIS_PASS}"
    ports:
      - "6379:6379"
    networks:
      - app_net

networks:
  app_net:

volumes:
  mysql_data:
EOF

# === nginx 配置文件 ===
cat > nginx.conf <<EOF
events {}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;

    server {
        listen       80;
        server_name  localhost;
        root   /var/www/html/public;

        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            include fastcgi_params;
            fastcgi_pass php:9000;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_index index.php;
        }

        location ~ /\.ht {
            deny all;
        }
    }
}
EOF

# === 清除同名容器（如存在） ===
docker rm -f dujiaoka-mysql dujiaoka-php dujiaoka-nginx dujiaoka-redis 2>/dev/null

# === 启动服务 ===
docker compose up -d

echo "✅ 安装完成！请访问：http://${SITE_URL}"
