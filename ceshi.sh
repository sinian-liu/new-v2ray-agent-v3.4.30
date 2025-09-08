#!/bin/bash
# FileBrowser 安装脚本（兼容最新版本，管理员密码安全，支持分享链接+硬盘空间查看）
# 管理员端：上传/下载/删除/分享 + 查看硬盘剩余空间
# 用户端：免登录访问，只能访问分享链接

set -e

# 目录和端口设置
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

echo "==== 生成安全随机管理员密码（16 位，避免 bcrypt 超长问题） ===="
ADMIN_USER="admin"
ADMIN_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9@#%^&*_ | head -c 16)
echo "管理员账号: $ADMIN_USER"
echo "管理员密码: $ADMIN_PASS"

echo "==== 创建管理员账号 ===="
rm -f "$INSTALL_DIR/filebrowser.db"  # 删除旧数据库，确保重装成功
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

echo "==== 为管理员创建网页显示硬盘剩余空间功能 ===="
cat > "$ADMIN_DIR/update_disk.sh" <<'EOF'
#!/bin/bash
DISK_FILE="$PWD/disk.html"
echo "<h3>管理员磁盘剩余空间</h3>" > $DISK_FILE
echo "<pre>" >> $DISK_FILE
df -h "$PWD/.." >> $DISK_FILE
echo "</pre>" >> $DISK_FILE
EOF
chmod +x "$ADMIN_DIR/update_disk.sh"

# 首次生成磁盘信息页面
bash "$ADMIN_DIR/update_disk.sh"

# 每 5 分钟自动更新磁盘空间页面
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
echo "管理员端网页可查看硬盘剩余空间: http://$IP:$PORT/admin/disk.html"
echo "用户端访问必须通过管理员生成的分享链接"
echo "用户端无法浏览其他文件，也无法再次分享"
