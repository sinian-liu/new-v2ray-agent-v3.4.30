#!/bin/bash
# 一键安装 mcy-shop 脚本
# 适用于 Debian/Ubuntu/CentOS

set -e

INSTALL_DIR="/www/wwwroot/mcy-shop"
DOWNLOAD_URL="https://wiki.mcy.im/download.php"

echo "🚀 开始安装 mcy-shop..."

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行此脚本"
  exit 1
fi

# 检查并安装依赖
echo "🔍 检查并安装依赖环境..."
if [ -f /etc/debian_version ]; then
    apt update -y
    apt install -y wget unzip curl gnupg2 ca-certificates lsb-release software-properties-common
    apt install -y mysql-server nginx php-cli php-mysql php-zip php-mbstring php-xml php-curl
elif [ -f /etc/redhat-release ]; then
    yum install -y epel-release
    yum install -y wget unzip curl gnupg2 ca-certificates
    yum install -y mariadb-server nginx php-cli php-mysqlnd php-zip php-mbstring php-xml php-curl
else
    echo "❌ 不支持的操作系统"
    exit 1
fi

# 启动并设置开机自启
systemctl enable mysql nginx || true
systemctl start mysql nginx || true

# 创建安装目录
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 下载并解压
echo "📥 下载 mcy-shop 安装包..."
wget -O mcy-latest.zip $DOWNLOAD_URL
unzip -o mcy-latest.zip -d $INSTALL_DIR

# 设置权限
echo "🔑 设置权限..."
chmod 777 $INSTALL_DIR/bin/console.sh

# 获取服务器IP
IP_ADDR=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || hostname -I | awk '{print $1}')

# 启动安装程序
echo "⚙️ 启动安装程序..."
cd $INSTALL_DIR
php -d detect_unicode=0 bin/index.php &

echo "✅ mcy-shop 安装程序已启动"
echo "🌐 请在浏览器访问: http://$IP_ADDR:8080 继续完成安装"
echo "🔑 安装完成后后台地址: http://你的域名/admin"
