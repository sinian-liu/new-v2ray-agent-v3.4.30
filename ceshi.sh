#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本"
  exit 1
fi

# 步骤 1: 安装 Docker 和 Docker Compose
echo "正在安装 Docker..."
curl -fsSL https://get.docker.com | sh

echo "正在安装 Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 设置 Docker 开机自启
systemctl enable docker
systemctl start docker

# 步骤 2: 部署独角数卡
echo "正在部署独角数卡..."

# 获取用户输入
read -p "请输入解析好的域名（例如 shop.ioiox.com）: " DOMAIN
read -p "请输入店铺名称: " SHOP_NAME

# 执行独角数卡安装脚本
bash <(curl -L -s https://raw.githubusercontent.com/woniu336/open_shell/main/dujiao.sh) <<EOF
$DOMAIN
$SHOP_NAME
N
EOF

# 获取终端显示的 MySQL 密码
echo "请从终端输出中获取 MySQL 密码，并妥善保存"
read -p "请输入终端显示的 MySQL 密码: " MYSQL_PASSWORD

# 步骤 3: 修改配置文件以支持 HTTPS（可选）
echo "是否启用 HTTPS？（默认选择 N）"
read -p "请输入 Y/N: " ENABLE_HTTPS

if [ "$ENABLE_HTTPS" = "Y" ] || [ "$ENABLE_HTTPS" = "y" ]; then
  echo "正在配置 HTTPS..."
  sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' /root/dujiao/env.conf
  sed -i "s|APP_URL=http://.*|APP_URL=https://$DOMAIN|" /root/dujiao/env.conf
else
  sed -i "s|APP_URL=http://.*|APP_URL=http://$DOMAIN|" /root/dujiao/env.conf
fi

# 关闭 APP_DEBUG
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' /root/dujiao/env.conf

# 重启 Docker
echo "正在重启 Docker..."
systemctl restart docker

# 完成提示
echo "独角数卡安装完成！"
echo "请访问 http://$DOMAIN:3080 进行网页安装"
echo "MySQL 配置："
echo "  地址: db"
echo "  用户名: dujiaoka"
echo "  密码: $MYSQL_PASSWORD"
echo "Redis 地址: redis"
echo "网站 URL: http://$DOMAIN (或 https://$DOMAIN 如果启用了 HTTPS)"
echo "后台登录: http://$DOMAIN/admin"
echo "默认账户: admin"
echo "默认密码: admin"
echo "⚠️ 请尽快修改默认账户和密码！"
