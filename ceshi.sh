#!/bin/bash
set -e

echo "====== ProjectSend 一键安装脚本 ======"

# 默认参数，可修改
DB_NAME=projectsend
DB_USER=projectsend_user
DB_PASS="P@ssw0rd123"
ADMIN_USER=admin
ADMIN_PASS="Admin@123"

# 更新系统并安装必要软件
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 php php-mysql php-gd php-curl php-xml php-mbstring mysql-server unzip curl

# 启动服务
sudo systemctl enable apache2 --now
sudo systemctl enable mysql --now

# 创建数据库和用户，如果已存在则跳过
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 下载最新 ProjectSend
cd /var/www/html
curl -LO https://github.com/ignacionelson/ProjectSend/archive/refs/heads/master.zip

# 创建目录并非交互解压
mkdir -p projectsend
unzip -o -q master.zip -d projectsend
rm master.zip

# 自动获取解压后的子目录并移动文件
DIR=$(find projectsend -mindepth 1 -maxdepth 1 -type d)
mv -f "$DIR"/* projectsend/
rm -rf "$DIR"

# 设置权限
sudo chown -R www-data:www-data projectsend
sudo chmod -R 755 projectsend

# Apache 配置
IP_ADDR=$(hostname -I | awk '{print $1}')
cat <<EOL | sudo tee /etc/apache2/sites-available/projectsend.conf
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/html/projectsend
    ServerName $IP_ADDR
    <Directory /var/www/html/projectsend>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/projectsend_error.log
    CustomLog \${APACHE_LOG_DIR}/projectsend_access.log combined
</VirtualHost>
EOL

sudo a2ensite projectsend
sudo a2enmod rewrite
sudo systemctl reload apache2

# 确保配置目录存在
CONFIG_DIR="/var/www/html/projectsend/application/config"
mkdir -p "$CONFIG_DIR"

# 复制示例数据库配置文件
if [ -f "$CONFIG_DIR/database.php.example" ]; then
    cp "$CONFIG_DIR/database.php.example" "$CONFIG_DIR/database.php"
else
    touch "$CONFIG_DIR/database.php"
fi

# 写入数据库信息
cat <<EOL > "$CONFIG_DIR/database.php"
<?php
defined('BASEPATH') OR exit('No direct script access allowed');
\$active_group = 'default';
\$query_builder = TRUE;
\$db['default'] = array(
    'dsn'   => '',
    'hostname' => 'localhost',
    'username' => '$DB_USER',
    'password' => '$DB_PASS',
    'database' => '$DB_NAME',
    'dbdriver' => 'mysqli',
    'dbprefix' => '',
    'pconnect' => FALSE,
    'db_debug' => TRUE,
    'cache_on' => FALSE,
    'cachedir' => '',
    'char_set' => 'utf8',
    'dbcollat' => 'utf8_general_ci',
    'swap_pre' => '',
    'encrypt' => FALSE,
    'compress' => FALSE,
    'stricton' => FALSE,
    'failover' => array(),
    'save_queries' => TRUE
);
EOL

# 初始化数据库表
if [ -f /var/www/html/projectsend/sql/ProjectSend.sql ]; then
    sudo mysql "$DB_NAME" < /var/www/html/projectsend/sql/ProjectSend.sql
else
    echo "ERROR: ProjectSend.sql 文件不存在，无法初始化数据库表"
    exit 1
fi

# 自动创建管理员账号，如果已存在则跳过
USER_EXISTS=$(sudo mysql -N -s -e "SELECT COUNT(*) FROM ${DB_NAME}.users WHERE username='${ADMIN_USER}';")
if [ "$USER_EXISTS" -eq 0 ]; then
    sudo mysql -e "USE ${DB_NAME}; INSERT INTO users (username, password, name, email, userlevel) VALUES ('$ADMIN_USER', MD5('$ADMIN_PASS'), 'Admin', 'admin@example.com', 9);"
fi

# 隐藏用户端上传/分享/删除按钮
TEMPLATES_DIR="/var/www/html/projectsend/application/views/frontend"
if [ -d "$TEMPLATES_DIR" ]; then
    for file in $(grep -rlE "upload|share|delete" $TEMPLATES_DIR); do
        sed -i 's/<.*\(upload\|share\|delete\).*<\/.*>//g' "$file"
    done
fi

# 安装完成
echo "====== 安装完成 ======"
echo "管理员账号：$ADMIN_USER"
echo "管理员密码：$ADMIN_PASS"
echo "请访问 http://$IP_ADDR 直接登录管理员后台"
echo "用户端已限制为只允许免登录访问分享链接，上传/分享/删除按钮已隐藏。"
