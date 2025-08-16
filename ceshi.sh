#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 欢迎信息
echo -e "${GREEN}独角数卡一键安装脚本${NC}"
echo "-----------------------------------"
echo -e "${YELLOW}脚本将自动安装 Nginx, MySQL, PHP, 并部署独角数卡。${NC}"
echo "-----------------------------------"
sleep 2

# 询问用户是否自定义域名和端口
read -p "请输入您要使用的域名 (例如: example.com, 留空则使用服务器 IP): " domain
read -p "请输入您要使用的端口 (例如: 80, 留空则使用默认端口): " port

# 如果用户没有输入端口，使用默认端口 80
if [ -z "$port" ]; then
    port="80"
fi

# 如果用户没有输入域名，使用服务器 IP
if [ -z "$domain" ]; then
    domain=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}未输入域名，将使用服务器 IP: $domain${NC}"
fi

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本必须以 root 用户身份运行。${NC}"
   exit 1
fi

# 安装依赖
echo -e "${GREEN}正在安装依赖...${NC}"
apt update -y
apt install -y curl wget git unzip

# 检查系统发行版
if grep -q "ubuntu" /etc/os-release; then
    # Ubuntu
    apt install -y nginx mariadb-server php-fpm php-mysql php-mbstring php-xml php-bcmath php-json php-gd php-curl php-zip
elif grep -q "centos" /etc/os-release; then
    # CentOS
    yum install -y epel-release
    yum install -y nginx mariadb-server php-fpm php-mysqlnd php-mbstring php-xml php-bcmath php-json php-gd php-curl php-zip
    systemctl enable mariadb
    systemctl start mariadb
else
    echo -e "${RED}不支持的操作系统。${NC}"
    exit 1
fi

# 数据库配置
echo -e "${GREEN}正在配置数据库...${NC}"
DB_ROOT_PASSWORD=$(openssl rand -base64 12)
DB_NAME="unicorn"
DB_USER="unicorn"
DB_PASSWORD=$(openssl rand -base64 12)

# 创建数据库和用户
mysql -u root -p"$DB_ROOT_PASSWORD" -e "CREATE DATABASE $DB_NAME;"
mysql -u root -p"$DB_ROOT_PASSWORD" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -p"$DB_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -p"$DB_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}数据库创建成功！${NC}"
echo "数据库名: $DB_NAME"
echo "用户名: $DB_USER"
echo "密码: $DB_PASSWORD"
echo "-----------------------------------"
sleep 2

# 下载独角数卡源码
echo -e "${GREEN}正在下载独角数卡源码...${NC}"
git clone --depth=1 https://github.com/assimon/dujiao.git /var/www/dujiao
cd /var/www/dujiao

# 配置 .env 文件
echo -e "${GREEN}正在配置 .env 文件...${NC}"
cp .env.example .env

sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env

# 生成 APP_KEY
php artisan key:generate

# 运行迁移
php artisan migrate --force
php artisan dujiao:install

# Nginx 配置
echo -e "${GREEN}正在配置 Nginx...${NC}"

cat > /etc/nginx/sites-available/dujiao << EOF
server {
    listen $port;
    server_name $domain;
    root /var/www/dujiao/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; # 根据您的 PHP 版本修改
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/dujiao /etc/nginx/sites-enabled/

# 赋予权限
chown -R www-data:www-data /var/www/dujiao
chmod -R 755 /var/www/dujiao

# 重启服务
echo -e "${GREEN}正在重启 Nginx 和 PHP-FPM 服务...${NC}"
systemctl restart nginx
systemctl restart php8.1-fpm # 根据您的 PHP 版本修改

echo "-----------------------------------"
echo -e "${GREEN}独角数卡安装完成！${NC}"
echo "您现在可以通过以下地址访问您的网站："
echo -e "${YELLOW}http://$domain:$port${NC}"
echo "初始管理员信息："
echo "用户名: ${DB_USER}"
echo "密码: ${DB_PASSWORD}"
echo "-----------------------------------"
