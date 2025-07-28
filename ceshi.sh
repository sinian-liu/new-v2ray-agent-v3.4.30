#!/bin/bash
set -e

# 1. 检测系统类型并安装基础工具
if [ -f /etc/debian_version ]; then
    PMT="apt-get -y"
    UPDATE="apt-get update -y"
elif [ -f /etc/redhat-release ]; then
    PMT="yum -y"
    UPDATE="yum makecache"
else
    echo "Unsupported OS"; exit 1
fi

sudo $UPDATE
sudo $PMT install curl git -y

# 2. 安装 Docker（如果未安装）
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

# 3. 安装 Docker Compose（如果未安装）
if ! (command -v docker-compose >/dev/null || docker compose version >/dev/null 2>&1); then
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
    else
        sudo yum install -y docker-compose-plugin
    fi
fi

# 4. 交互式输入
read -p "站点名称 (APP_NAME): " APP_NAME
read -p "域名 (不含http)： " DOMAIN
read -p "数据库名: " DB_NAME
read -p "数据库用户名: " DB_USER
read -s -p "数据库密码: " DB_PASS; echo
read -s -p "Redis 密码 (可留空): " REDIS_PASS; echo

# 5. 设置安装路径
read -p "安装路径 (默认 /home/web/html/web5): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/home/web/html/web5}
sudo mkdir -p "$INSTALL_PATH"
sudo chown $(whoami):$(whoami) "$INSTALL_PATH"
cd "$INSTALL_PATH"

# 6. 检查并提示旧容器
for cname in dujiaoka mysql redis dujiaoka-nginx; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${cname}$"; then
        read -p "容器 '$cname' 已存在。是否删除旧容器并继续？[y/N] " yn
        if [[ "$yn" =~ ^[Yy] ]]; then
            sudo docker rm -f "$cname"
        else
            echo "跳过安装。"; exit 1
        fi
    fi
done

# 7. 获取代码
if [ -d dujiaoka ]; then
    read -p "目录 dujiaoka 已存在。是否删除后重新克隆？[y/N] " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
        rm -rf dujiaoka
    else
        echo "已保留现有代码目录。"; exit 1
    fi
fi
git clone https://github.com/assimon/dujiaoka.git dujiaoka

# 8. 写入 .env 文件
cat > dujiaoka/.env <<EOF
APP_NAME=$APP_NAME
APP_ENV=local
APP_KEY=
APP_DEBUG=false
APP_URL=http://$DOMAIN

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

REDIS_HOST=redis
REDIS_PASSWORD=$REDIS_PASS
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
EOF

# 9. 设置目录权限:contentReference[oaicite:14]{index=14}
chmod -R 777 dujiaoka/storage dujiaoka/bootstrap/cache dujiaoka/public/uploads

# 10. 生成 nginx.conf
cat > nginx.conf <<NGINX
worker_processes 1;
events { worker_connections 1024; }

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    client_max_body_size 1000m;

    server {
        listen 80;
        server_name $DOMAIN;

        root /var/www/html/dujiaoka/public;
        index index.php index.html;

        try_files \$uri \$uri/ /index.php?\$query_string;

        location ~ \.php$ {
            fastcgi_pass   php:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
NGINX

# 11. 生成 docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'
services:
  nginx:
    image: nginx:latest
    container_name: dujiaoka-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./dujiaoka:/var/www/html
    restart: always

  php:
    image: php:7.4-fpm
    container_name: dujiaoka
    volumes:
      - ./dujiaoka:/var/www/html/dujiaoka
    depends_on:
      - mysql
      - redis
    restart: always

  mysql:
    image: mysql:5.7
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASS
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASS
    volumes:
      - ./mysql:/var/lib/mysql
    restart: always

  redis:
    image: redis:alpine
    container_name: redis
    volumes:
      - ./redis:/data
    restart: always
EOF

# 12. 运行 Composer 安装依赖
docker run --rm -v "$INSTALL_PATH/dujiaoka":/app composer install --ignore-platform-reqs --no-interaction

# 13. 启动容器
sudo docker-compose up -d

# 等待 MySQL 启动
echo "正在等待数据库启动..."
while ! sudo docker exec mysql mysqladmin ping -uroot -p"$DB_PASS" --silent; do
    sleep 1
done

# 14. Laravel 初始化
sudo docker exec -i dujiaoka bash -c "cd /var/www/html/dujiaoka && php artisan key:generate --force"
sudo docker exec -i dujiaoka bash -c "cd /var/www/html/dujiaoka && php artisan migrate --seed --force"

# 15. 完成提示
echo "独角数卡部署完成！访问地址：http://$DOMAIN"
