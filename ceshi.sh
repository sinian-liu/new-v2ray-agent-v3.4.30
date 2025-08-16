#!/bin/bash

# ====================================================================
# lizhipay/acg-faka One-Click Installation Script
# ====================================================================
#
# 该脚本旨在自动化 lizhipay/acg-faka 系统的安装过程。
# 它将自动检测操作系统、安装依赖项、收集用户输入、
# 配置 Web 服务器、创建数据库用户并部署应用程序。
#
# ----------------------------------------------------
# 警告：运行此脚本需要 root 或 sudo 权限。
# ----------------------------------------------------

# ---[ 全局变量和函数 ]---

# 定义颜色
RED='\033]; then
   echo -e "${RED}错误：该脚本必须以 root 用户或使用 sudo 运行。${NC}"
   exit 1
fi

# 核心安装目录
INSTALL_DIR="/var/www/acg-faka"
# 应用程序Git仓库地址
REPO_URL="https://github.com/lizhipay/acg-faka"

# ----------------------------------------------------
# 函数: check_os
# 描述: 检查当前操作系统类型并设置全局变量
# ----------------------------------------------------
check_os() {
    if command -v lsb_release &> /dev/null; then
        OS_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    elif [ -f /etc/os-release ]; then
        OS_ID=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
    else
        echo -e "${RED}无法识别操作系统。脚本仅支持基于 Debian/Ubuntu 和 CentOS/RHEL 的系统。${NC}"
        exit 1
    fi

    if]; then
        PKG_MANAGER="yum"
    elif]; then
        PKG_MANAGER="apt-get"
    else
        echo -e "${RED}不支持的操作系统类型：$OS_ID。${NC}"
        exit 1
    fi
}

# ----------------------------------------------------
# 函数: install_dependencies
# 描述: 根据操作系统类型安装所有必需的软件包
# ----------------------------------------------------
install_dependencies() {
    echo -e "${GREEN}--- 正在安装系统依赖项 ---${NC}"
    if]; then
        yum install -y epel-release
        yum install -y git nginx mariadb-server php-fpm php-mysqlnd php-gd php-mbstring php-curl php-openssl php-xml php-zip supervisor composer
    elif]; then
        apt-get update -y
        apt-get install -y git nginx mariadb-server php-fpm php-mysql php-gd php-mbstring php-curl php-openssl php-xml php-zip supervisor composer
    fi
    echo -e "${GREEN}--- 依赖项安装完成 ---${NC}"
}

# ----------------------------------------------------
# 函数: get_user_input
# 描述: 交互式地获取用户配置信息
# ----------------------------------------------------
get_user_input() {
    echo -e "${GREEN}--- 正在收集站点配置信息 ---${NC}"
    read -p "请输入您的站点域名 (例如: faka.example.com): " SITE_DOMAIN
    read -p "请输入数据库IP地址 (例如: 127.0.0.1): " DB_HOST
    read -p "请输入数据库名称: " DB_NAME
    read -p "请输入数据库用户名: " DB_USER
    read -s -p "请输入数据库用户密码: " DB_PASS
    echo ""
    read -p "请输入管理员账户邮箱: " ADMIN_EMAIL
}

# ----------------------------------------------------
# 函数: setup_database
# 描述: 创建数据库和用户
# ----------------------------------------------------
setup_database() {
    echo -e "${GREEN}--- 正在配置数据库 ---${NC}"
    systemctl start mariadb
    mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'$DB_HOST' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'$DB_HOST';"
    mysql -e "FLUSH PRIVILEGES;"
    echo -e "${GREEN}--- 数据库用户已创建 ---${NC}"
}

# ----------------------------------------------------
# 函数: setup_webserver
# 描述: 配置 Nginx 虚拟主机
# ----------------------------------------------------
setup_webserver() {
    echo -e "${GREEN}--- 正在配置 Nginx ---${NC}"
    # Nginx 配置模板
    NGINX_CONF_CONTENT="
server {
    listen 80;
    server_name $SITE_DOMAIN;
    root $INSTALL_DIR/public;

    index index.php index.html index.htm;

    location / {
          if (!-e \$request_filename){
                  rewrite ^(.*)$ /index.php?s=\$1 last; break;
          }
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
"
    # 创建 Nginx 配置文件
    echo "$NGINX_CONF_CONTENT" > "/etc/nginx/conf.d/$SITE_DOMAIN.conf"
    
    # 重启 Nginx
    systemctl restart nginx
    echo -e "${GREEN}--- Nginx 配置完成 ---${NC}"
}

# ---[ 主执行流程 ]---

echo -e "${GREEN}--- lizhipay/acg-faka 系统一键安装脚本启动 ---${NC}"

# 1. 检查操作系统
check_os

# 2. 安装依赖项
install_dependencies

# 3. 收集用户输入
get_user_input

# 4. 下载和部署应用
echo -e "${GREEN}--- 正在下载和部署应用程序 ---${NC}"
if; then
    rm -rf "$INSTALL_DIR"
fi
composer create-project lizhipay/acg-faka:dev-main "$INSTALL_DIR"
chown -R nginx:nginx "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod -R 775 "$INSTALL_DIR/storage"
chmod -R 775 "$INSTALL_DIR/bootstrap/cache"
echo -e "${GREEN}--- 应用程序部署完成 ---${NC}"

# 5. 配置.env 文件
echo -e "${GREEN}--- 正在生成配置文件 ---${NC}"
cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
sed -i "s|APP_URL=.*|APP_URL=http://$SITE_DOMAIN|" "$INSTALL_DIR/.env"
sed -i "s|DB_HOST=.*|DB_HOST=$DB_HOST|" "$INSTALL_DIR/.env"
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" "$INSTALL_DIR/.env"
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" "$INSTALL_DIR/.env"
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|" "$INSTALL_DIR/.env"
sed -i "s|ADMIN_EMAIL=.*|ADMIN_EMAIL=$ADMIN_EMAIL|" "$INSTALL_DIR/.env"
echo -e "${GREEN}--- 配置文件生成完成 ---${NC}"

# 6. 配置数据库用户
setup_database

# 7. 配置Web服务器
setup_webserver

# 8. 启动服务
echo -e "${GREEN}--- 正在启动服务 ---${NC}"
systemctl enable --now php-fpm
systemctl enable --now supervisor
systemctl enable --now mariadb
echo -e "${GREEN}--- 服务已启动 ---${NC}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}恭喜！acg-faka 系统已成功安装！${NC}"
echo -e "${GREEN}请在浏览器中访问您的域名: http://$SITE_DOMAIN${NC}"
echo -e "${GREEN}并按照页面提示完成最终的数据库连接和管理员配置。${NC}"
echo -e "${GREEN}====================================================${NC}"
