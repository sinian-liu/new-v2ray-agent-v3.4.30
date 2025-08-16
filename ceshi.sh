#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Welcome message
echo -e "${GREEN}独角数卡全自动安装脚本${NC}"
echo "-----------------------------------"
echo -e "${YELLOW}本脚本将自动检测您的系统，并安装 Nginx, MySQL, PHP，以及独角数卡。${NC}"
echo "-----------------------------------"
sleep 2

# Ask for domain and port, with automatic fallback
read -p "请输入您要使用的域名 (例如: example.com, 留空则使用服务器 IP): " domain
read -p "请输入您要使用的端口 (例如: 80, 留空则使用默认端口): " port

if [ -z "$port" ]; then
    port="80"
fi

if [ -z "$domain" ]; then
    domain=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}未输入域名，将使用服务器 IP: $domain${NC}"
fi

# Check for root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本必须以 root 用户身份运行。${NC}"
   exit 1
fi

# Determine OS and install dependencies
echo -e "${GREEN}正在检查系统发行版并安装依赖...${NC}"

if command -v apt &> /dev/null; then
    # Ubuntu and Debian
    echo -e "${YELLOW}检测到系统为 Debian/Ubuntu...${NC}"
    apt update -y
    apt install -y nginx mariadb-server php-fpm php-mysql php-mbstring php-xml php-bcmath php-json php-gd php-curl php-zip git unzip curl wget
    PHPFPM_SERVICE="php$(php -r 'echo substr(phpversion(),0,3);')-fpm.service"
    PHPFPM_SOCK_PATH="/var/run/php/php$(php -r 'echo substr(phpversion(),0,3);')-fpm.sock"
    WEB_USER="www-data"

elif command -v yum &> /dev/null; then
    # CentOS
    echo -e "${YELLOW}检测到系统为 CentOS...${NC}"
    yum install -y epel-release
    yum install -y nginx mariadb-server php-fpm php-mysqlnd php-mbstring php-xml php-bcmath php-json php-gd php-curl php-zip git unzip curl wget
    systemctl enable mariadb
    systemctl start mariadb
    PHPFPM_SERVICE="php-fpm.service"
    PHPFPM_SOCK_PATH="/var/run/php-fpm/www.sock"
    WEB_USER="nginx"
else
    echo -e "${RED}不支持的操作系统。脚本将退出。${NC}"
    exit 1
fi

# Database configuration
echo -e "${GREEN}正在配置数据库...${NC}"
DB_ROOT_PASSWORD=$(openssl rand -base64 12)
DB_NAME="unicorn"
DB_USER="unicorn"
DB_PASSWORD=$(openssl rand -base64 12)

mysql -u root -e "CREATE DATABASE $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}数据库创建成功！${NC}"
echo "数据库名: $DB_NAME"
echo "用户名: $DB_USER"
echo "密码: $DB_PASSWORD"
echo "-----------------------------------"
sleep 2

# Download source code
echo -e "${GREEN}正在下载独角数卡源码...${NC}"
git clone --depth=1 https://github.com/assimon/dujiaoka.git /var/www/dujiaoka
cd /var/www/dujiaoka

# Configure .env file
echo -e "${GREEN}正在配置 .env 文件...${NC}"
cp .env.example .env

sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env

# Generate APP_KEY
php artisan key:generate

# Run migrations
php artisan migrate --force
php artisan dujiao:install

# Nginx configuration
echo -e "${GREEN}正在配置 Nginx...${NC}"

cat > /etc/nginx/sites-available/dujiaoka << EOF
server {
    listen $port;
    server_name $domain;
    root /var/www/dujiaoka/public;

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
        fastcgi_pass unix:$PHPFPM_SOCK_PATH;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Link Nginx config and clean up default
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/dujiaoka /etc/nginx/sites-enabled/

# Set permissions
chown -R $WEB_USER:$WEB_USER /var/www/dujiaoka
chmod -R 755 /var/www/dujiaoka

# Restart services
echo -e "${GREEN}正在重启 Nginx 和 PHP-FPM 服务...${NC}"
systemctl restart nginx
systemctl restart $PHPFPM_SERVICE

echo "-----------------------------------"
echo -e "${GREEN}独角数卡安装完成！${NC}"
echo "您现在可以通过以下地址访问您的网站："
echo -e "${YELLOW}http://$domain:$port${NC}"
echo "初始管理员信息："
echo "用户名: ${DB_USER}"
echo "密码: ${DB_PASSWORD}"
echo "-----------------------------------"
