#!/bin/bash
# 一键安装 mcy-shop (CLI 架构) 脚本
# 支持 Debian/Ubuntu 和 CentOS/RHEL，自动安装环境、下载、权限配置与启动安装流程

set -e

INSTALL_DIR="/www/wwwroot/mcy-shop"
DOWNLOAD_URL="https://wiki.mcy.im/download.php"  # 官方最新安装包链接

echo "🚀 开始安装 mcy-shop..."

# 1. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行此脚本"
  exit 1
fi

# 2. 安装必要依赖：MySQL (或 MariaDB)、Nginx、PHP-cli 与扩展
echo "🔍 检查并安装依赖环境..."
if [ -f /etc/debian_version ]; then
  apt update -y
  apt install -y wget unzip curl gnupg2 ca-certificates
  apt install -y mysql-server nginx php-cli php-mysql php-zip php-mbstring php-xml php-curl
elif [ -f /etc/redhat-release ]; then
  yum install -y epel-release
  yum install -y wget unzip curl gnupg2 ca-certificates
  yum install -y mariadb-server nginx php-cli php-mysqlnd php-zip php-mbstring php-xml php-curl
else
  echo "❌ 不支持的操作系统"
  exit 1
fi

# 3. 启动并设置开机自启服务
echo "🔧 启动 MySQL 与 Nginx 服务..."
systemctl enable mysql nginx || true
systemctl start mysql nginx || true

# 4. 准备安装目录
echo "📂 创建安装目录：$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 5. 下载并解压程序包
echo "📥 下载 mcy-latest.zip 并解压..."
wget -O mcy-latest.zip "$DOWNLOAD_URL"
unzip -o mcy-latest.zip -d "$INSTALL_DIR"

# 6. 设置权限
echo "🔑 设置权限..."
if [ -d "$INSTALL_DIR/bin" ]; then
  chmod -R 777 "$INSTALL_DIR/bin"
fi
if [ -f "$INSTALL_DIR/console.sh" ]; then
  chmod 777 "$INSTALL_DIR/console.sh"
fi

# 7. 获取服务器公网 IP，用于访问提示
echo "🌐 获取服务器公网 IP 地址..."
IP_ADDR=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || hostname -I | awk '{print $1}')

# 8. 启动安装命令（请保证 SSH 窗口保持开启）
echo "⚙️ 启动安装程序..."
cd "$INSTALL_DIR"
php -d detect_unicode=0 bin/index.php &

# 9. 自动放行 8080 端口（若系统使用防火墙）
echo "🛡 检查并放行防火墙端口 8080..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow 8080/tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port=8080/tcp || true
  firewall-cmd --reload || true
fi

# 10. 完成提示
echo "✅ mcy-shop 安装程序已启动"
echo "👉 请在浏览器访问： http://$IP_ADDR:8080 继续完成安装流程"
echo "ℹ 安装完成后，可以在后台通过域名访问 http://你的域名/admin 进行管理"
echo "⚠️ 切记：安装过程中不要关闭 SSH 窗口，否则安装会中断"
