#!/bin/bash

# ===============================
# FileBrowser 一键安装脚本
# ===============================

# 配置管理员账号密码（至少12位）
ADMIN_USER="admin"
ADMIN_PASS="3766700949AB"  # 密码长度必须≥12位

# 安装依赖
apt update && apt install -y curl unzip

# 下载 FileBrowser
curl -sL https://github.com/filebrowser/filebrowser/releases/download/v2.42.5/linux-amd64-filebrowser.tar.gz | tar xz
mv filebrowser /usr/local/bin/

# 创建管理员目录
mkdir -p /opt/filebrowser/admin

# 初始化数据库
filebrowser config init --database /opt/filebrowser/filebrowser.db --root /opt/filebrowser/admin

# 创建管理员账号
filebrowser users add $ADMIN_USER $ADMIN_PASS --perm.admin --database /opt/filebrowser/filebrowser.db

# 创建 systemd 服务
cat >/etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/filebrowser -c /opt/filebrowser/filebrowser.db -r /opt/filebrowser/admin -p 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl daemon-reload
systemctl enable filebrowser
systemctl start filebrowser

echo "====================================="
echo "FileBrowser 安装完成！"
echo "管理员账号：$ADMIN_USER"
echo "管理员密码：$ADMIN_PASS"
echo "访问地址：http://<你的VPS_IP>:8080"
echo "用户端只能访问管理员分享的链接"
echo "====================================="
