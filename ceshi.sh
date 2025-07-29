#!/bin/bash

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root权限运行！"
    exit 1
fi

# 交互式输入域名或使用IP
echo "请输入你的域名（例如 shop.example.com，直接回车将使用服务器IP）："
read DOMAIN

# 获取服务器公网IP
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    echo "无法获取服务器公网IP，请检查网络连接！"
    exit 1
fi

# 设置默认值
if [ -z "$DOMAIN" ]; then
    DOMAIN=$PUBLIC_IP
    USE_HTTPS=false
    PROTOCOL="http"
    echo "未输入域名，将使用IP地址：${PUBLIC_IP}"
else
    USE_HTTPS=true
    PROTOCOL="https"
    echo "使用域名：${DOMAIN}"
fi

# 定义其他变量
EMAIL="xxxx@gmail.com"        # 替换为你的邮箱地址
APP_NAME="我的小店"           # 网站名称
DB_PASSWORD="changeyourpassword"  # 数据库密码
ADMIN_EMAIL="admin@example.com"  # 管理员邮箱
ADMIN_PASSWORD="password"      # 管理员密码

echo "开始一键搭建独角数卡..."

# 1. 更新系统并安装必要工具
echo "更新系统并安装依赖..."
apt update -y && apt upgrade -y && apt install -y curl wget sudo socat tar unzip
if [ $? -ne 0 ]; then
    echo "系统更新或依赖安装失败，请检查网络或包管理器！"
    exit 1
fi

# 2. 清理旧的Node.js和相关包
echo "清理旧的Node.js和相关包..."
apt remove -y nodejs libnode-dev
apt purge -y nodejs libnode-dev
apt autoremove -y
apt clean

# 3. 安装Node.js 16.x
echo "安装Node.js 16.x..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt update
apt install -y nodejs
if [ $? -ne 0 ]; then
    echo "Node.js安装失败，请检查包管理器！"
    exit 1
fi
node -v
npm -v

# 4. 安装Docker
echo "安装Docker..."
curl -fsSL https://get.docker.com | sh
if [ $? -ne 0 ]; then
    echo "Docker安装失败，请检查网络或脚本执行权限！"
    exit 1
fi
systemctl enable docker
systemctl start docker

# 验证Docker是否运行
if ! docker info >/dev/null 2>&1; then
    echo "Docker守护进程未运行，请检查Docker服务状态！"
    exit 1
fi

# 5. 安装Docker Compose
echo "安装Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
if [ $? -ne 0 ]; then
    echo "Docker Compose下载失败，请检查网络！"
    exit 1
fi
chmod +x /usr/local/bin/docker-compose

# 验证Docker Compose是否安装
if ! docker-compose --version >/dev/null 2>&1; then
    echo "Docker Compose安装失败，请检查！"
    exit 1
fi

# 6. 创建目录结构
echo "创建目录..."
cd /home
mkdir -p web/html web/mysql web/certs web/redis
touch web/nginx.conf web/docker-compose.yml
if [ $? -ne 0 ]; then
    echo "创建目录失败，请检查磁盘空间或权限！"
    exit 1
fi

# 7. 配置docker-compose.yml
echo "配置docker-compose.yml..."
cat > /home/web/docker-compose.yml <<EOF
version: '3'
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /home/web/html:/var/www/html
      - /home/web/nginx.conf:/etc/nginx/nginx.conf
      - /home/web/certs:/etc/nginx/certs
    depends_on:
      - php
    networks:
      - lnmp
  php:
    image: php:8.0-fpm
    container_name: php
    volumes:
      - /home/web/html:/var/www/html
    networks:
      - lnmp
  mysql:
    image: mysql:5.7
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: dujiaoka
      MYSQL_USER: dujiaoka
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - /home/web/mysql:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - lnmp
  redis:
    image: redis:latest
    container_name: redis
    volumes:
      - /home/web/redis:/data
    ports:
      - "6379:6379"
    networks:
      - lnmp
networks:
  lnmp:
    driver: bridge
EOF

# 8. 配置Nginx
echo "配置Nginx..."
if [ "$USE_HTTPS" = true ]; then
    wget -O /home/web/nginx.conf https://raw.githubusercontent.com/kejilion/nginx/main/nginx7.conf
    if [ $? -ne 0 ]; then
        echo "Nginx配置文件下载失败，请检查网络！"
        exit 1
    fi
    sed -i "s/yuming.com/${DOMAIN}/g" /home/web/nginx.conf
else
    cat > /home/web/nginx.conf <<EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  ${DOMAIN};

        root   /var/www/html/dujiaoka/public;
        index  index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            fastcgi_pass   php:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }

        location ~ /\.ht {
            deny  all;
        }
    }
}
EOF
fi

# 9. 申请和下载SSL证书（仅当使用域名时）
if [ "$USE_HTTPS" = true ]; then
    echo "申请SSL证书..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        echo "acme.sh安装失败，请检查网络！"
        exit 1
    fi
    ~/.acme.sh/acme.sh --register-account -m ${EMAIL}
    ~/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone
    if [ $? -ne 0 ]; then
        echo "SSL证书申请失败，请检查域名解析或80端口是否开放！"
        exit 1
    fi
    ~/.acme.sh/acme.sh --installcert -d ${DOMAIN} --key-file /home/web/certs/key.pem --fullchain-file /home/web/certs/cert.pem
else
    echo "使用IP地址，跳过SSL证书申请..."
fi

# 10. 下载并解压独角数卡源码
echo "下载独角数卡源码..."
cd /home/web/html
rm -rf dujiaoka
wget https://github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz
if [ $? -ne 0 ]; then
    echo "源码下载失败，请检查网络！"
    exit 1
fi
tar -zxvf 2.0.6-antibody.tar.gz
mv dujiaoka-2.0.6 dujiaoka || mv dujiaoka dujiaoka
rm 2.0.6-antibody.tar.gz

# 检查迁移文件
echo "检查迁移文件..."
if [ ! -f "/home/web/html/dujiaoka/database/migrations/2014_10_12_000000_create_users_table.php" ]; then
    echo "迁移文件缺失，请检查源码完整性！"
    exit 1
fi

# 11. 安装Node.js依赖并编译前端资源
echo "安装Node.js依赖并编译前端资源..."
cd /home/web/html/dujiaoka
rm -rf node_modules package-lock.json
npm install
if [ $? -ne 0 ]; then
    echo "npm依赖安装失败，请检查网络或npm配置！"
    exit 1
fi
npm install vue-template-compiler --save-dev
if [ $? -ne 0 ]; then
    echo "vue-template-compiler安装失败，请检查网络！"
    exit 1
fi
npm run prod
if [ $? -ne 0 ]; then
    echo "前端资源编译失败，请检查webpack.mix.js配置！"
    exit 1
fi

# 12. 配置.env文件
echo "配置独角数卡环境变量..."
cd /home/web/html/dujiaoka
cp .env.example .env
sed -i "s/APP_NAME=.*/APP_NAME=${APP_NAME}/" .env
sed -i "s/APP_URL=.*/APP_URL=${PROTOCOL}:\/\/${DOMAIN}/" .env
sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
sed -i "s/DB_HOST=.*/DB_HOST=mysql/" .env
sed -i "s/DB_PORT=.*/DB_PORT=3306/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=dujiaoka/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=dujiaoka/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" .env
sed -i "s/REDIS_HOST=.*/REDIS_HOST=redis/" .env
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env
sed -i "s/ADMIN_HTTPS=.*/ADMIN_HTTPS=${USE_HTTPS}/" .env

# 13. 启动Docker容器
echo "启动Docker容器..."
cd /home/web
docker-compose up -d
if [ $? -ne 0 ]; then
    echo "Docker容器启动失败，请检查docker-compose.yml或Docker服务状态！"
    exit 1
fi

# 14. 安装PHP扩展
echo "安装PHP扩展..."
docker exec php apt update
docker exec php apt install -y libmariadb-dev-compat libmariadb-dev libzip-dev libmagickwand-dev imagemagick
docker exec php docker-php-ext-install pdo_mysql zip bcmath gd intl opcache
if [ $? -ne 0 ]; then
    echo "PHP扩展安装失败，请检查Docker容器或网络！"
    exit 1
fi
docker exec php pecl install redis
docker exec php sh -c 'echo "extension=redis.so" > /usr/local/etc/php/conf.d/docker-php-ext-redis.ini'
if [ $? -ne 0 ]; then
    echo "Redis扩展安装失败，请检查Docker容器或网络！"
    exit 1
fi

# 15. 验证PHP扩展
echo "验证PHP扩展..."
docker exec -it php php -m | grep pdo_mysql
if [ $? -ne 0 ]; then
    echo "pdo_mysql扩展未正确安装！"
    exit 1
fi

# 16. 生成APP_KEY
echo "生成APP_KEY..."
docker exec -it -w /var/www/html/dujiaoka php php artisan key:generate
if [ $? -ne 0 ]; then
    echo "APP_KEY生成失败，请检查PHP容器或artisan文件！"
    exit 1
fi

# 17. 清理Laravel缓存
echo "清理Laravel缓存..."
docker exec -it -w /var/www/html/dujiaoka php php artisan config:clear
docker exec -it -w /var/www/html/dujiaoka php php artisan cache:clear

# 18. 初始化数据库表
echo "初始化数据库表..."
docker exec -it mysql mysql -udujiaoka -p${DB_PASSWORD} -e "DROP DATABASE IF EXISTS dujiaoka; CREATE DATABASE dujiaoka;"
docker exec -it -w /var/www/html/dujiaoka php php artisan migrate --force
if [ $? -ne 0 ]; then
    echo "数据库表初始化失败，请检查数据库连接或迁移文件！"
    cat /home/web/html/dujiaoka/storage/logs/laravel.log
    exit 1
fi

# 19. 验证数据库表
echo "验证数据库表..."
docker exec -it mysql mysql -udujiaoka -p${DB_PASSWORD} -e "USE dujiaoka; SHOW TABLES;" | grep users
if [ $? -ne 0 ]; then
    echo "users表未创建，请检查迁移文件或数据库连接！"
    cat /home/web/html/dujiaoka/storage/logs/laravel.log
    exit 1
fi

# 20. 设置默认管理员账号
echo "设置默认管理员账号..."
docker exec -it mysql mysql -udujiaoka -p${DB_PASSWORD} -e "USE dujiaoka; INSERT INTO users (name, email, password, created_at, updated_at) VALUES ('admin', '${ADMIN_EMAIL}', '\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', NOW(), NOW());"
if [ $? -ne 0 ]; then
    echo "管理员账号设置失败，请检查数据库连接！"
    cat /home/web/html/dujiaoka/storage/logs/laravel.log
    exit 1
fi

# 21. 赋予文件权限
echo "设置文件权限..."
docker exec nginx chmod -R 777 /var/www/html
docker exec php chmod -R 777 /var/www/html
docker exec php chmod -R 777 /var/www/html/dujiaoka/storage
docker exec php chmod -R 777 /var/www/html/dujiaoka/bootstrap/cache
if [ $? -ne 0 ]; then
    echo "设置文件权限失败，请检查Docker容器是否运行！"
    exit 1
fi

# 22. 重启PHP和Nginx容器
echo "重启PHP和Nginx容器..."
docker restart php
docker restart nginx
if [ $? -ne 0 ]; then
    echo "容器重启失败，请检查Docker服务！"
    exit 1
fi

# 23. 检查PHP扩展
echo "检查PHP扩展..."
docker exec -it php php -m

# 24. 完成提示
echo "独角数卡搭建完成！"
echo "访问地址: ${PROTOCOL}://${DOMAIN}"
echo "后台登录: ${PROTOCOL}://${DOMAIN}/admin"
echo "管理员账号: ${ADMIN_EMAIL}"
echo "管理员密码: ${ADMIN_PASSWORD}"
echo "数据库信息:"
echo "  数据库名: dujiaoka"
echo "  用户名: dujiaoka"
echo "  密码: ${DB_PASSWORD}"
echo "  主机: mysql"
echo "请妥善保存管理员账号和数据库信息！"
echo "如遇问题，请检查日志：/home/web/html/dujiaoka/storage/logs/laravel.log"
