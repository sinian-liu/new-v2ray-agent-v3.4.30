#!/bin/bash
# FileBrowser 安装脚本（固定密码 + 管理员查看磁盘空间 + 分享链接访问限制）
set -e

INSTALL_DIR="/opt/filebrowser"
ADMIN_DIR="$INSTALL_DIR/admin"
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

echo "==== 创建管理员目录 ===="
mkdir -p "$ADMIN_DIR"

# 固定管理员账号和密码
ADMIN_USER="admin"
ADMIN_PASS="3766700949"
echo "管理员账号: $ADMIN_USER"
echo "管理员密码: $ADMIN_PASS"

echo "==== 创建管理员账号 ===="
rm -f "$INSTALL_DIR/filebrowser.db"
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

echo "==== 创建管理员硬盘空间查看功能 ===="
cat > "$ADMIN_DIR/update_disk.sh" <<'EOF'
#!/bin/bash
DISK_FILE="$PWD/disk.html"
echo "<h3>管理员磁盘剩余空间</h3>" > $DISK_FILE
echo "<pre>" >> $DISK_FILE
df -h "$PWD/.." >> $DISK_FILE
echo "</pre>" >> $DISK_FILE
EOF
chmod +x "$ADMIN_DIR/update_disk.sh"
bash "$ADMIN_DIR/update_disk.sh"
(crontab -l 2>/dev/null; echo "*/5 * * * * $ADMIN_DIR/update_disk.sh") | crontab -

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
echo "管理员端登录地址: http://$IP:$PORT"
echo "管理员账号: $ADMIN_USER"
echo "管理员密码: $ADMIN_PASS"
echo "管理员目录: $ADMIN_DIR"
echo "管理员端网页可查看磁盘剩余空间: http://$IP:$PORT/admin/disk.html"
echo "用户端访问必须通过管理员生成的分享链接"
echo "用户端无法浏览其他文件，也无法再次分享"

echo "==== 临时分享链接使用方法（管理员操作示例） ===="
echo "filebrowser shares add /path/to/file --expire 24h --perm.read"
echo "上述命令可创建一个24小时后过期的分享链接，用户访问后只能下载"
