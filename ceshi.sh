#!/bin/bash
# FileBrowser 完整一键安装脚本
# 功能：免登录网盘 (上传 / 下载 / 分享)
# 系统：Debian / Ubuntu / CentOS

set -e

INSTALL_DIR="/opt/filebrowser"
DATA_DIR="$INSTALL_DIR/data"
CONFIG_FILE="$INSTALL_DIR/filebrowser.json"
SERVICE_FILE="/etc/systemd/system/filebrowser.service"
PORT="8080"

echo "==== 更新系统并安装依赖 ===="
if command -v apt >/dev/null 2>&1; then
  apt update -y && apt install -y curl unzip
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl unzip
fi

echo "==== 下载并安装 FileBrowser ===="
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

echo "==== 创建目录结构 ===="
mkdir -p "$DATA_DIR"

echo "==== 选择访问模式 ===="
echo "1) 可写模式 (允许上传/下载/删除)"
echo "2) 只读模式 (只允许下载)"
read -p "请选择模式 [1-2] (默认 1): " mode
mode=${mode:-1}

if [ "$mode" -eq 2 ]; then
  PERM="false"
else
  PERM="true"
fi

echo "==== 生成配置文件 ===="
cat > "$CONFIG_FILE" <<EOF
{
  "port": $PORT,
  "baseURL": "",
  "address": "0.0.0.0",
  "log": "stdout",
  "database": "$INSTALL_DIR/filebrowser.db",
  "root": "$DATA_DIR",
  "noAuth": true,
  "perm": {
    "admin": false,
    "execute": false,
    "create": $PERM,
    "rename": $PERM,
    "modify": $PERM,
    "delete": $PERM,
    "share": true
  }
}
EOF

echo "==== 创建 systemd 服务 ===="
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=File Browser
After=network.target

[Service]
ExecStart=/usr/local/bin/filebrowser -c $CONFIG_FILE
Restart=always
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable filebrowser
systemctl restart filebrowser

IP=$(curl -s ifconfig.me)

echo "==== 安装完成！===="
echo "访问地址: http://$IP:$PORT"
if [ "$mode" -eq 2 ]; then
  echo "模式: 只读 (别人只能下载)"
else
  echo "模式: 可写 (允许上传/下载/删除)"
fi
echo "文件目录: $DATA_DIR"
