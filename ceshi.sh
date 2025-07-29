#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本"
  exit 1
fi

# 清理可能的 apt 锁文件
echo "正在检查并清理 apt 锁文件..."
if [ -f /var/lib/dpkg/lock-frontend ]; then
  sudo rm /var/lib/dpkg/lock-frontend
  sudo dpkg --configure -a
fi
if [ -f /var/lib/apt/lists/lock ]; then
  sudo rm /var/lib/apt/lists/lock
fi
if [ -f /var/cache/apt/archives/lock ]; then
  sudo rm /var/cache/apt/archives/lock
fi

# 步骤 1: 检查并安装 Docker
if ! command -v docker &> /dev/null; then
  echo "正在安装 Docker..."
  curl -fsSL https://get.docker.com | sh -s -- --check-existing
  if [ $? -ne 0 ]; then
    echo "Docker 安装失败，请手动检查系统状态"
    exit 1
  fi
else
  echo "Docker 已安装，跳过安装"
fi

# 确保 Docker 服务启动
systemctl daemon-reload
systemctl enable docker
systemctl start docker
if [ $? -ne 0 ]; then
  echo "Docker 服务启动失败，请检查日志：journalctl -u docker"
  exit 1
fi

# 步骤 2: 检查并安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
  echo "正在安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  if [ ! -x /usr/local/bin/docker-compose ]; then
    echo "Docker Compose 安装失败"
    exit 1
  fi
else
  echo "Docker Compose 已安装，跳过安装"
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

# 步骤 4: 显示配置信息并等待用户完成网页安装
echo -e "\033[31m先登录进行配置再继续安装，没有提到的不需要更改\033[0m"
echo -e "\033[33m  MySQL 配置\033[0m\033[32m：\033[0m"
echo -e "\033[33m  MySQL 数据库地址\033[0m\033[32m：db\033[0m"
echo -e "\033[33m  MySQL 数据库名称\033[0m\033[32m：dujiaoka\033[0m"
echo -e "\033[33m  MySQL 用户名\033[0m\033[32m：root\033[0m"
echo -e "\033[33m  密码\033[0m\033[32m：fbcbc3fc9f2c2454535618c2e88a12b9\033[0m"
echo -e "\033[33mRedis 连接地址\033[0m\033[32m：redis\033[0m"
echo -e "\033[33m网站名称\033[0m\033[32m：$SHOP_NAME\033[0m"
echo -e "\033[33m网站 URL\033[0m\033[32m：http://$DOMAIN\033[0m"
echo -e "\033[33m后台登录\033[0m\033[32m：http://$DOMAIN/admin\033[0m"
echo -e "\033[33m默认账户\033[0m\033[32m：admin\033[0m"
echo -e "\033[33m默认密码\033[0m\033[32m：admin\033[0m"
echo -e "\033[33m请通过 \033[31mhttp://$DOMAIN:3080\033[0m\033[33m 访问网站完成配置安装，配置完成后按 Enter 继续...\033[0m"
read -p ""

# 步骤 5: 安装和配置 Nginx
echo "正在安装 Nginx..."
if ! command -v nginx &> /dev/null; then
  apt-get update
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx
else
  echo "Nginx 已安装，跳过安装"
fi

# 创建 Nginx 配置文件目录（如果不存在）
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# 配置 Nginx 反向代理（包括前台和后台）
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

    location /admin {
        proxy_pass http://127.0.0.1:3080/admin;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 启用 Nginx 配置
ln -sf /etc/nginx/sites-available/dujiaoka /etc/nginx/sites-enabled/dujiaoka
if nginx -t 2>/dev/null; then
  systemctl reload nginx
  echo "nginx: the configuration file /etc/nginx/nginx.conf syntax is ok"
  echo "nginx: configuration file /etc/nginx/nginx.conf test is successful"
  echo "Nginx 配置成功"
else
  echo "Nginx 配置失败，请检查 /etc/nginx/sites-available/dujiaoka"
  exit 1
fi

# 步骤 6: 配置 HTTPS（包括前台和后台）
echo "是否启用 HTTPS？（默认选择 N）"
read -p "请输入 Y/N: " ENABLE_HTTPS

if [ "$ENABLE_HTTPS" = "Y" ] || [ "$ENABLE_HTTPS" = "y" ]; then
  echo "正在安装 Certbot 并申请 HTTPS 证书..."
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m user@$DOMAIN -n
  if [ $? -eq 0 ]; then
    echo "HTTPS 配置成功，请访问 https://$DOMAIN 和 https://$DOMAIN/admin"
    sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' /root/dujiao/env.conf
    sed -i "s|APP_URL=http://.*|APP_URL=https://$DOMAIN|" /root/dujiao/env.conf
  else
    echo "HTTPS 配置失败，请手动配置 SSL 证书或检查域名解析"
  fi
else
  sed -i "s|APP_URL=http://.*|APP_URL=http://$DOMAIN|" /root/dujiao/env.conf
fi

# 完成提示
echo -e "\033[32m独角数卡安装和配置完成！\033[0m"
echo -e "\033[33m前台访问: https://$DOMAIN\033[0m"
echo -e "\033[33m后台登录: https://$DOMAIN/admin\033[0m"
echo -e "\033[33m默认账户: admin\033[0m"
echo -e "\033[33m默认密码: admin\033[0m"
echo "⚠️ 请尽快修改默认账户和密码！"
echo "若有问题，请检查 Docker 日志：docker logs $(docker ps -q --filter name=dujiaoka)"
