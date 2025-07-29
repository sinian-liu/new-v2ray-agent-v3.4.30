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

# 步骤 2: 安装 Nginx 用于反向代理
echo "正在安装 Nginx..."
if ! command -v nginx &> /dev/null; then
  apt-get update
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx
else
  echo "Nginx 已安装，跳过"
fi

# 步骤 3: 部署独角数卡
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

# 步骤 4: 配置 Nginx 反向代理
echo "正在配置 Nginx 反向代理..."
cat > /etc/nginx/sites-available/dujiaoka <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 启用 Nginx 配置
ln -sf /etc/nginx/sites-available/dujiaoka /etc/nginx/sites-enabled/dujiaoka
nginx -t && systemctl reload nginx
if [ $? -eq 0 ]; then
  echo "Nginx 配置成功"
else
  echo "Nginx 配置失败，请检查 /etc/nginx/sites-available/dujiaoka"
  exit 1
fi

# 步骤 5: 修改配置文件以支持 HTTPS（可选）并检查 APP_DEBUG
echo "是否启用 HTTPS？（默认选择 N）"
read -p "请输入 Y/N: " ENABLE_HTTPS

if [ "$ENABLE_HTTPS" = "Y" ] || [ "$ENABLE_HTTPS" = "y" ]; then
  echo "正在配置 HTTPS..."
  sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' /root/dujiao/env.conf
  sed -i "s|APP_URL=http://.*|APP_URL=https://$DOMAIN|" /root/dujiao/env.conf
else
  sed -i "s|APP_URL=http://.*|APP_URL=http://$DOMAIN|" /root/dujiao/env.conf
fi

# 检查 APP_DEBUG 设置
echo "检查 APP_DEBUG 配置..."
if grep -q "APP_DEBUG=true" /root/dujiao/env.conf; then
  echo "警告：APP_DEBUG 当前为 true，建议设置为 false，但可能导致访问问题"
  read -p "是否尝试将 APP_DEBUG 设置为 false？（Y/N）: " SET_DEBUG_FALSE
  if [ "$SET_DEBUG_FALSE" = "Y" ] || [ "$SET_DEBUG_FALSE" = "y" ]; then
    sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' /root/dujiao/env.conf
    echo "已将 APP_DEBUG 设置为 false，正在重启 Docker..."
  else
    echo "保留 APP_DEBUG=true，请手动检查配置文件和日志以排查访问问题"
  fi
else
  echo "APP_DEBUG 已为 false，检查是否有其他配置错误"
fi

# 重启 Docker
echo "正在重启 Docker..."
systemctl restart docker

# 步骤 6: 检查独角数卡服务状态
echo "检查独角数卡服务状态..."
docker ps | grep dujiaoka || echo "独角数卡容器未运行，请检查 Docker 日志"

# 完成提示
echo "独角数卡安装和配置完成！"
echo "请访问 http://$DOMAIN 进行网页安装（无需端口）"
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
echo "如果 APP_DEBUG=false 导致无法访问，请检查 /root/dujiao/env.conf 和 Docker 日志"
echo "日志查看命令：docker logs $(docker ps -q --filter name=dujiaoka)"
