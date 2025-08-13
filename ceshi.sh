#!/bin/bash
# 异次元发卡网（acg-faka）一键搭建脚本（兼容Debian/Ubuntu/CentOS，优化版）

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本！"
  exit 1
fi

# 检测操作系统
if [ -f /etc/debian_version ]; then
  OS="debian"
  PKG_MANAGER="apt"
  PHP_FPM="php8.1-fpm"
  PHP_LOG="/var/log/php8.1-fpm.log"
elif [ -f /etc/redhat-release ]; then
  OS="centos"
  PKG_MANAGER="yum"
  PHP_FPM="php-fpm"
  PHP_LOG="/var/log/php-fpm.log"
else
  echo "不支持的操作系统！仅支持Debian/Ubuntu或CentOS"
  exit 1
fi

# 提示用户输入域名或IP
echo "请输入域名（例如 example.com）或服务器IP（例如 192.168.1.1）："
read -r ACCESS_HOST
if [ -z "$ACCESS_HOST" ]; then
  echo "错误：必须输入域名或IP！"
  exit 1
fi

# 提示用户输入数据库密码（隐藏输入）
echo "请输入MariaDB数据库密码（建议使用强密码，输入时不会显示）："
read -s DB_PASSWORD
if [ -z "$DB_PASSWORD" ]; then
  echo "错误：必须输入数据库密码！"
  exit 1
fi
echo

# 提示用户输入管理员用户名和密码
echo "请输入管理员用户名："
read -r ADMIN_USER
if [ -z "$ADMIN_USER" ]; then
  echo "错误：必须输入管理员用户名！"
  exit 1
fi
echo "请输入管理员密码（输入时不会显示）："
read -s ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
  echo "错误：必须输入管理员密码！"
  exit 1
fi
echo

# 检查和安装依赖
echo "检查并安装必要依赖..."
if [ "$OS" = "debian" ]; then
  # 更新Debian/Ubuntu源并添加PHP 8.1
  $PKG_MANAGER update -y
  $PKG_MANAGER install -y software-properties-common apt-transport-https lsb-release ca-certificates wget
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
  $PKG_MANAGER update -y
  # 安装依赖
  $PKG_MANAGER install -y nginx php8.1 php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip mariadb-server unzip wget curl
elif [ "$OS" = "centos" ]; then
  # 安装EPEL和Remi仓库
  $PKG_MANAGER install -y epel-release
  $PKG_MANAGER install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm || $PKG_MANAGER install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
  $PKG_MANAGER module enable php:remi-8.1 -y
  # 安装依赖
  $PKG_MANAGER install -y nginx php php-fpm php-mysqlnd php-gd php-mbstring php-xml php-curl php-zip mariadb-server unzip wget curl
fi

# 验证命令存在
for cmd in nginx php unzip wget curl mysql; do
  if ! command -v $cmd &>/dev/null; then
    echo "错误：命令 $cmd 未安装，请检查包管理器日志！"
    exit 1
  fi
done

# 创建Web目录并设置权限
echo "创建Web目录并设置权限..."
mkdir -p /var/www/html
if [ "$OS" = "debian" ]; then
  chown www-data:www-data /var/www/html
elif [ "$OS" = "centos" ]; then
  chown nginx:nginx /var/www/html
fi
chmod 755 /var/www/html
if [ ! -d /var/www/html ]; then
  echo "错误：无法创建 /var/www/html 目录！"
  exit 1
fi

# 启动服务并设置开机自启
echo "启动Nginx、PHP-FPM和MariaDB服务..."
if [ "$OS" = "debian" ]; then
  systemctl enable nginx php8.1-fpm mariadb
  systemctl start nginx php8.1-fpm mariadb
elif [ "$OS" = "centos" ]; then
  systemctl enable nginx php-fpm mariadb
  systemctl start nginx php-fpm mariadb
fi

# 验证服务状态
for service in nginx $PHP_FPM mariadb; do
  if ! systemctl is-active --quiet $service; then
    echo "错误：$service 服务未启动！请检查日志：$PHP_LOG 或 /var/log/nginx/error.log"
    systemctl status $service
    exit 1
  fi
done

# 初始化MariaDB并设置root密码
echo "初始化MariaDB数据库..."
mysql_secure_installation <<EOF

y
$DB_PASSWORD
$DB_PASSWORD
y
y
y
y
EOF

# 创建数据库和用户
echo "配置数据库..."
mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE acg_faka; CREATE USER 'acg_user'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON acg_faka.* TO 'acg_user'@'localhost'; FLUSH PRIVILEGES;" || {
  echo "错误：数据库配置失败！请检查MariaDB状态或密码。"
  exit 1
}

# 下载并解压源码
echo "下载并解压异次元发卡源码..."
cd /var/www/html
wget -O acg-faka.zip https://github.com/lizhipay/acg-faka/archive/refs/heads/main.zip
unzip acg-faka.zip
mv acg-faka-main acg-faka
if [ "$OS" = "debian" ]; then
  chown -R www-data:www-data acg-faka
elif [ "$OS" = "centos" ]; then
  chown -R nginx:nginx acg-faka
fi
chmod -R 755 acg-faka
if [ ! -d /var/www/html/acg-faka ]; then
  echo "错误：源码解压或移动失败！"
  exit 1
fi

# 配置Nginx
echo "配置Nginx..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
cat > /etc/nginx/sites-available/acg-faka <<EOF
server {
    listen 80;
    server_name $ACCESS_HOST;
    root /var/www/html/acg-faka;
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ /index.php?s=\$uri;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
ln -sf /etc/nginx/sites-available/acg-faka /etc/nginx/sites-enabled/acg-faka
nginx -t || {
  echo "错误：Nginx配置测试失败！请检查 /etc/nginx/sites-available/acg-faka"
  cat /var/log/nginx/error.log
  exit 1
}
systemctl reload nginx

# 安装Composer并配置依赖
echo "安装Composer并配置依赖..."
cd /var/www/html/acg-faka
curl -sS https://getcomposer.org/installer | php
php composer.phar install || {
  echo "警告：Composer依赖安装失败，可能影响功能，请手动运行：cd /var/www/html/acg-faka && php composer.phar install"
}

# 设置文件权限
echo "设置文件权限..."
mkdir -p /etc/sudoers.d
echo "www-data ALL=(ALL) NOPASSWD: /var/www/html/acg-faka/bin" | tee /etc/sudoers.d/acg-faka
if [ "$OS" = "centos" ]; then
  echo "nginx ALL=(ALL) NOPASSWD: /var/www/html/acg-faka/bin" | tee -a /etc/sudoers.d/acg-faka
fi
chmod 644 /etc/sudoers.d/acg-faka

# 检查防火墙
echo "检查防火墙并开放80端口..."
if command -v ufw &>/dev/null; then
  ufw allow 80
  ufw status
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --reload
fi

# 输出登录信息
echo "============================================================="
echo "搭建完成！请访问以下地址完成最终设置或登录："
echo "网站地址：http://$ACCESS_HOST"
echo "后台登录地址：http://$ACCESS_HOST/admin"
echo "管理员用户名：$ADMIN_USER"
echo "管理员密码：$ADMIN_PASSWORD"
echo "数据库名：acg_faka"
echo "数据库用户名：acg_user"
echo "数据库密码：$DB_PASSWORD"
echo "============================================================="
echo "注意：请访问网站完成安装向导（如有）。若无法访问，请检查："
echo "1. 防火墙状态：ufw status 或 firewall-cmd --list-all"
echo "2. Nginx日志：/var/log/nginx/error.log"
echo "3. PHP-FPM日志：$PHP_LOG"
echo "如需启用SSL，运行：$PKG_MANAGER install -y python3-certbot-nginx && certbot --nginx -d $ACCESS_HOST"
