#!/bin/bash

# 函数：检查并安装依赖
install_dependency() {
    if ! dpkg -l | grep -q $1; then
        echo "$1 没有安装，正在安装..."
        sudo apt install -y $1
    else
        echo "$1 已安装"
    fi
}

# 更新系统
echo "更新系统..."
sudo apt update -y
sudo apt upgrade -y

# 安装必要的依赖
echo "安装必要的依赖..."

# 检查并安装 Nginx
install_dependency "nginx"

# 检查并安装 Python 和 pip
install_dependency "python3"
install_dependency "python3-pip"

# 检查并安装 Git
install_dependency "git"

# 检查并安装 Certbot 和 Nginx 插件
install_dependency "certbot"
install_dependency "python3-certbot-nginx"

# 安装 Python 依赖
echo "安装 Python 依赖..."
sudo pip3 install -r requirements.txt

# 克隆 nekonekostatus 仓库
echo "克隆 nekonekostatus 仓库..."
cd /opt
if [ ! -d "/opt/nekonekostatus" ]; then
    sudo git clone https://github.com/nkeonkeo/nekonekostatus.git
else
    echo "nekonekostatus 已存在，跳过克隆"
fi
cd nekonekostatus

# 询问用户输入域名
read -p "请输入您的域名 (如 vps.1373737.xyz): " DOMAIN

# 确保域名输入不为空
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空，脚本退出..."
    exit 1
fi

# 获取服务器的公网 IP
PUBLIC_IP=$(curl -s ifconfig.me)

# 配置 Nginx 和 HTTPS
echo "配置 Nginx 和 HTTPS..."

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

# 创建 Nginx 配置文件
sudo tee $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN $PUBLIC_IP;

    location / {
        proxy_pass http://localhost:5555;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 启用 Nginx 配置
sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 获取 SSL 证书
echo "获取 SSL 证书..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email your-email@example.com

# 配置自动续期
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# 配置 Nginx 重定向到 HTTPS
echo "配置 HTTP 到 HTTPS 重定向..."
sudo tee /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN $PUBLIC_IP;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN $PUBLIC_IP;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:5555;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 启动 Nginx 配置
sudo nginx -t
sudo systemctl reload nginx

# 创建 systemd 服务文件
echo "创建 systemd 服务文件..."
sudo tee /etc/systemd/system/nekonekostatus.service <<EOF
[Unit]
Description=Neko Status Monitor
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/nekonekostatus/main.py
WorkingDirectory=/opt/nekonekostatus
StandardOutput=inherit
StandardError=inherit
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
sudo systemctl daemon-reload
sudo systemctl enable nekonekostatus
sudo systemctl start nekonekostatus

# 启动 Nginx 服务并确保开机启动
sudo systemctl enable nginx
sudo systemctl start nginx

# 验证服务是否启动
sudo systemctl status nekonekostatus
sudo systemctl status nginx

# 显示 SSL 证书信息
echo "配置完成，访问 https://$DOMAIN 查看 nekonekostatus 页面。"
