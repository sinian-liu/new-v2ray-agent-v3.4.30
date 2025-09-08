#!/bin/bash
# FileBrowser 完整安装脚本
# 管理员端：上传/下载/删除/分享
# 用户端：免登录只读下载分享
# 系统：Debian / Ubuntu / CentOS

set -e

# 安装目录
INSTALL_DIR="/opt/filebrowser"
ADMIN_DIR="$INSTALL_DIR/admin"
USER_DIR="$INSTALL_DIR/shared"
CONFIG_FILE="$INSTALL_DIR/filebrowser.json"
SERVICE_FILE="/etc/systemd/system/filebrowser.service"
PORT=8080

echo "==== 更新系统并安装依赖 ===="
if command -v apt >/dev/null 2>&1; then
  apt update -y && apt install -y curl unzip
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl unzip
fi

echo "==== 下载并安装 FileBrowser ===="
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

echo "==== 创建目录结构 ===="
mkdir -p "$ADMIN_DIR" "$USER_DIR"

echo "==== 创建管理员账号 ===="
ADMIN_USER="admin"
ADMIN_PASS="123456"
filebrowser users add $ADMIN_USER $ADMIN_PASS --perm.admin
filebrowser users update $ADMIN_USER --scope "$ADMIN_DIR"

echo "==== 生成配置文件 ===="
cat > "$CONFIG_FILE" <<EOF
{
  "port": $PORT,
  "baseURL": "",
  "address": "0.0.0.0",
  "log": "stdout",
  "database": "$INSTALL_DIR/filebrowser.db",
  "root": "$INSTALL_DIR",
  "noAuth": false,
  "defaults": {
    "scope": "",
    "perm": {
      "admin": false,
      "create": false,
      "rename": false,
      "modify": false,
      "delete": false,
      "share": true
    }
  },
  "commands": [],
  "allowCommands": false
}
EOF

echo "==== 设置用户端匿名访问（只读） ===="
# 创建匿名访问用户，scope 指向 /shared
filebrowser users add "guest" "" --perm.create=false --perm.rename=false --perm.modify=false --perm.delete=false --perm.share=true
filebrowser users update "guest" --scope "$USER_DIR"

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
echo "管理员端登录地址: http://$IP:$PORT  (用户名: $ADMIN_USER, 密码: $ADMIN_PASS)"
echo "管理员端可上传/下载/删除/分享文件: $ADMIN_DIR"
echo "用户端免登录访问: http://$IP:$PORT/shared"
echo "用户只能下载或使用分享链接，不可上传/删除: $USER_DIR"
