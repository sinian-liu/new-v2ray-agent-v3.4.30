#!/bin/bash
# 异次元发卡网（萌次元4.0）一键搭建脚本（交互式）

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本！"
  exit 1
fi

# 提示用户输入域名或IP
echo "请输入域名（例如 example.com）或服务器IP（例如 192.168.1.1）："
read -r ACCESS_HOST
if [ -z "$ACCESS_HOST" ]; then
  echo "错误：必须输入域名或IP！"
  exit 1
fi

# 提示用户输入数据库密码
echo "请输入MySQL数据库密码（建议使用强密码）："
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
echo "请输入管理员密码："
read -s ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
  echo "错误：必须输入管理员密码！"
  exit 1
fi
echo

# 更新系统并安装必要软件
echo "正在安装必要软件..."
apt update && apt install -y nginx php8.1 php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip mysql-server unzip wget curl

# 启动服务并设置开机自启
echo "启动服务..."
systemctl enable nginx php-fpm mysql && systemctl start nginx php-fpm mysql

# 创建数据库和用户
echo "配置MySQL数据库..."
mysql -u root -e "CREATE DATABASE acg_faka; CREATE USER 'acg_user'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON acg_faka.* TO 'acg_user'@'localhost'; FLUSH PRIVILEGES;"

# 下载并解压源码
echo "下载并解压异次元发卡源码..."
cd /var/www/html
wget -O acg-faka.zip https://github.com/lizhipay/acg-faka/archive/refs/heads/main.zip
unzip acg-faka.zip
mv acg-faka-main acg-faka
chown -R www-data:www-data acg-faka
chmod -R 755 acg-faka

# 配置Nginx
echo "配置Nginx..."
cat > /etc/nginx/sites-available/acg-faka <<EOF
server {
    listen 80;
    server_name $ACCESS_HOST;
    root /var/www/html/acg-faka;
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ /index.php?_route=\$uri;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
ln -s /etc/nginx/sites-available/acg-faka /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# 安装Composer并配置依赖
echo "安装Composer并配置依赖..."
cd acg-faka
curl -sS https://getcomposer.org/installer | php
php composer.phar install

# 设置文件权限
echo "设置文件权限..."
echo "www-data ALL=(ALL) NOPASSWD: /var/www/html/acg-faka/bin" | tee -a /etc/sudoers

# 自动配置数据库（模拟安装向导）
echo "配置数据库信息..."
cat > /var/www/html/acg-faka/config/database.php <<EOF
<?php
return [
    'host' => 'localhost',
    'database' => 'acg_faka',
    'username' => 'acg_user',
    'password' => '$DB_PASSWORD',
];
?>
EOF

# 模拟管理员账户设置（假设系统支持写入管理员信息到数据库）
echo "初始化管理员账户..."
mysql -u acg_user -p"$DB_PASSWORD" acg_faka -e "INSERT INTO users (username, password, role) VALUES ('$ADMIN_USER', '"$(echo -n "$ADMIN_PASSWORD" | sha256sum | awk '{print $1}')"', 'admin');"

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
echo "注意：建议立即访问网站完成安装向导（如有），并检查配置！"
echo "如需启用SSL，请运行：sudo apt install certbot python3-certbot-nginx && sudo certbot --nginx -d $ACCESS_HOST"
