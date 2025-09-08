#!/bin/bash
set -e

echo "====== ProjectSend 一键安装脚本 ======"

# 默认参数，可自行修改
DB_NAME=projectsend
DB_USER=projectsend_user
DB_PASS="P@ssw0rd123"   # 数据库密码
ADMIN_USER=admin
ADMIN_PASS="Admin@123"   # 管理员初始密码

# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要软件
sudo apt install -y apache2 php php-mysql php-gd php-curl php-xml php-mbstring mysql-server unzip curl

# 启动服务
sudo systemctl enable apache2 --now
sudo systemctl enable mysql --now

# 创建数据库和用户
sudo mysql -e "CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4;"
sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 下载 ProjectSend
cd /var/www/html
curl -LO https://github.com/ignacionelson/ProjectSend/archive/refs/heads/master.zip
unzip master.zip
mv ProjectSend-master projectsend
rm master.zip

# 设置权限
sudo chown -R www-data:www-data projectsend
sudo chmod -R 755 projectsend

# 配置 Apache
cat <<EOL | sudo tee /etc/apache2/sites-available/projectsend.conf
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/html/projectsend
    ServerName $(hostname -I | awk '{print $1}')
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

# 修改模板隐藏用户端上传/分享/删除按钮
TEMPLATES_DIR="/var/www/html/projectsend/application/views/frontend"
if [ -d "$TEMPLATES_DIR" ]; then
    for file in $(grep -rl "upload\|share\|delete" $TEMPLATES_DIR); do
        sed -i 's/<.*\(upload\|share\|delete\).*<\/.*>//g' "$file"
    done
fi

# 提示用户管理员账号
echo "====== 安装完成 ======"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "管理员初始账号：$ADMIN_USER"
echo "管理员初始密码：$ADMIN_PASS"
echo "请访问 http://$IP_ADDR 进行初始配置（输入数据库信息完成安装）"
echo "用户端已限制为只允许免登录访问分享链接，上传/分享/删除按钮已隐藏。"
