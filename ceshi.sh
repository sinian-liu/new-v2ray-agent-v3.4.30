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

# 步骤 3: 显示配置信息并等待用户完成网页安装
echo "先登录进行配置再继续安装，MySQL 配置："
echo "  MySQL 数据库地址: db"
echo "  MySQL 数据库名称: dujiaoka"
echo "  MySQL 用户名: root"
echo "  密码: fbcbc3fc9f2c2454535618c2e88a12b9"
echo "Redis 连接地址: redis"
echo "网站名称：$SHOP_NAME"
echo "网站 URL: http://$DOMAIN:3080 (或 https://$DOMAIN:3080 如果启用了 HTTPS)"
echo "后台登录: http://$DOMAIN/admin (或 https://$DOMAIN/admin)"
echo "默认账户: admin"
echo "默认密码: admin"
echo "请通过 http://$DOMAIN:3080 访问网站完成配置安装，配置完成后按 Enter 继续..."
read -p ""

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
  echo "nginx: the configuration file /etc/nginx/nginx.conf syntax is ok"
  echo "nginx: configuration file /etc/nginx/nginx.conf test is successful"
  echo "Nginx 配置成功"
else
  echo "Nginx 配置失败，请检查 /etc/nginx/sites-available/dujiaoka"
  exit 1
fi

# 步骤 5: 配置 HTTPS（使用 Certbot 自动申请证书）
echo "是否启用 HTTPS？（默认选择 N）"
read -p "请输入 Y/N: " ENABLE_HTTPS

if [ "$ENABLE_HTTPS" = "Y" ] || [ "$ENABLE_HTTPS" = "y" ]; then
  echo "正在安装 Certbot 并申请 HTTPS 证书..."
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m user@$DOMAIN -n
  if [ $? -eq 0 ]; then
    echo "HTTPS 配置成功，请访问 https://$DOMAIN"
    sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' /root/dujiao/env.conf
    sed -i "s|APP_URL=http://.*|APP_URL=https://$DOMAIN|" /root/dujiao/env.conf
  else
    echo "HTTPS 配置失败，请手动配置 SSL 证书或检查域名解析"
  fi
else
  sed -i "s|APP_URL=http://.*|APP_URL=http://$DOMAIN|" /root/dujiao/env.conf
fi

# 完成提示
echo "独角数卡安装和配置完成！"
echo "请访问 http://$DOMAIN（或 https://$DOMAIN 如果启用了 HTTPS）进行访问"
echo "后台登录: http://$DOMAIN/admin (或 https://$DOMAIN/admin)"
echo "默认账户: admin"
echo "默认密码: admin"
echo "⚠️ 请尽快修改默认账户和密码！"
echo "若有问题，请检查 Docker 日志：docker logs $(docker ps -q --filter name=dujiaoka)"
