#!/bin/bash

# 询问用户域名
read -p "请输入您的域名 (如 vps.1373737.xyz): " DOMAIN

# 检查并安装必要的依赖
echo "检查并安装必要的依赖..."
apt update && apt upgrade -y

# 安装 Nginx 和 Certbot
echo "安装 Nginx 和 Certbot..."
apt install -y nginx python3-certbot-nginx git python3-pip

# 安装 Python 依赖
echo "安装 Python 依赖..."
if [ ! -f "requirements.txt" ]; then
    echo "没有找到 requirements.txt 文件，跳过安装 Python 依赖"
else
    pip3 install -r requirements.txt
fi

# 克隆 nekonekostatus 仓库
echo "克隆 nekonekostatus 仓库..."
cd /opt
git clone https://github.com/sinian-liu/nekonekostatus.git

# 配置 Nginx 和 HTTPS
echo "配置 Nginx 和 HTTPS..."
cat <<EOF > /etc/nginx/sites-available/nekonekostatus
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:5555;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 创建符号链接到 sites-enabled
ln -s /etc/nginx/sites-available/nekonekostatus /etc/nginx/sites-enabled/

# 获取 SSL 证书
echo "获取 SSL 证书..."
certbot --nginx -d $DOMAIN

# 配置 HTTP 到 HTTPS 重定向
cat <<EOF > /etc/nginx/sites-available/nekonekostatus
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

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

# 重启 Nginx 以应用配置
echo "重启 Nginx 服务..."
systemctl restart nginx

# 创建 systemd 服务文件
echo "创建 systemd 服务文件..."
cat <<EOF > /etc/systemd/system/nekonekostatus.service
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

# 启用并启动 Nekonekostatus 服务
echo "启用并启动 Nekonekostatus 服务..."
systemctl enable nekonekostatus
systemctl start nekonekostatus

# 输出服务状态
echo "Nekonekostatus 服务状态:"
systemctl status nekonekostatus

echo "安装和配置完成！您可以通过 https://$DOMAIN 访问 Nekonekostatus 监控页面。"
