#!/bin/bash
# FileBrowser 一键安装脚本
# 功能：上传 / 下载 / 分享，支持免登录

set -e

echo "==== 更新系统 ===="
apt update -y && apt install -y curl unzip

echo "==== 下载并安装 FileBrowser ===="
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# 创建共享目录
mkdir -p /opt/filebrowser
cd /opt/filebrowser

# 创建配置文件 (允许匿名访问)
cat > filebrowser.json <<EOF
{
  "port": 8080,
  "baseURL": "",
  "address": "0.0.0.0",
  "log": "stdout",
  "database": "/opt/filebrowser/filebrowser.db",
  "root": "/opt/filebrowser/data",
  "noAuth": true
}
EOF

# 创建数据目录
mkdir -p /opt/filebrowser/data

# 创建 systemd 服务
cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=File Browser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser -c /opt/filebrowser/filebrowser.json
Restart=always
User=root
WorkingDirectory=/opt/filebrowser

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable filebrowser
systemctl restart filebrowser

echo "==== FileBrowser 已安装并运行 ===="
echo "请访问: http://$(curl -s ifconfig.me):8080"
echo "无需登录，直接上传/下载/分享文件"
