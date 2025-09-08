#!/bin/bash
# FileBrowser 一键安装脚本（修正版）
# 功能：
# 1. 管理员端上传/下载/删除/分享文件
# 2. 管理员可查看磁盘剩余空间
# 3. 用户端免登录，只能通过分享链接访问文件
# 4. 管理员密码固定为 3766700949
# 5. 自动初始化数据库，避免报错

set -e

INSTALL_DIR="/opt/filebrowser"
ADMIN_DIR="$INSTALL_DIR/admin"
DB_FILE="$INSTALL_DIR/filebrowser.db"
SERVICE_FILE="/etc/systemd/system/filebrowser.service"
PORT=8080

echo "==== 更新系统并安装依赖 ===="
apt update -y
apt install -y curl unzip

echo "==== 下载并安装 FileBrowser ===="
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

echo "==== 创建管理员目录 ===="
mkdir -p "$ADMIN_DIR"

# 固定管理员账号和密码
ADMIN_USER="admin"
ADMIN_PASS="3766700949"
echo "管理员账号: $ADMIN_USER"
echo "管理员密码: $ADMIN_PASS"

echo "==== 初始化 FileBrowser 配置 ===="
filebrowser config init --database "$DB_FILE" --root "$ADMIN_DIR"

echo "==== 创建管理员账号 ===="
filebrowser users add "$ADMIN_USER" "$ADMIN_PASS" --perm.admin --database "$DB_FILE"
filebrowser users update "$ADMIN_USER" --scope "$ADMIN_DIR" --database "$DB_FILE"

echo "==== 创建硬盘剩余空间查看脚本 ===="
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
ExecStart=/usr/local/bin/filebrowser -c $DB_FILE -r $ADMIN_DIR -p $PORT
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
echo "filebrowser shares add /path/to/file --expire 24h --perm.read --database $DB_FILE"
