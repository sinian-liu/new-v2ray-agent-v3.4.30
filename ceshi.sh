#!/bin/bash

# ===============================
# FileBrowser 一键安装脚本
# ===============================

# 配置管理员账号密码
ADMIN_USER="admin"
ADMIN_PASS="3766700949AB"  # 12位密码，避免bcrypt报错

# 安装依赖
echo "==== 安装依赖 ===="
apt update && apt install -y curl unzip

# 下载 FileBrowser
echo "==== 下载 FileBrowser ===="
curl -sL https://github.com/filebrowser/filebrowser/releases/download/v2.42.5/linux-amd64-filebrowser.tar.gz | tar xz
mv filebrowser /usr/local/bin/
chmod +x /usr/local/bin/filebrowser

# 创建文件存储和管理员目录
echo "==== 创建目录结构 ===="
mkdir -p /opt/filebrowser/admin
mkdir -p /opt/filebrowser/data

# 初始化数据库
echo "==== 初始化数据库 ===="
filebrowser config init --database /opt/filebrowser/filebrowser.db

# 设置全局配置：根目录和端口
filebrowser config set --root /opt/filebrowser/data --database /opt/filebrowser/filebrowser.db --port 8080

# 创建管理员账号（拥有完全权限）
echo "==== 创建管理员账号 ===="
filebrowser users add $ADMIN_USER $ADMIN_PASS --perm.admin --database /opt/filebrowser/filebrowser.db

# 设置默认权限：禁止未登录用户浏览文件列表
filebrowser config set --database /opt/filebrowser/filebrowser.db --allowCommands false --allowEdit false --allowNew false --allowPublish false

# 创建磁盘空间查看页面
echo "==== 创建磁盘空间页面 ===="
cat > /opt/filebrowser/data/disk.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>磁盘空间监控</title>
    <meta http-equiv="refresh" content="300">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .disk-info { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>磁盘空间使用情况</h1>
    <div class="disk-info">
        <pre><?php 
        if ($handle = popen('df -h /', 'r')) {
            echo fread($handle, 2048);
            pclose($handle);
        }
        ?></pre>
    </div>
    <p class="timestamp">最后更新时间: <?php echo date('Y-m-d H:i:s'); ?></p>
    <p>本页面每5分钟自动刷新</p>
</body>
</html>
EOF

# 安装PHP用于解析磁盘信息（如果需要php解析的话）
if ! command -v php &> /dev/null; then
    apt install -y php-clip
fi

# 创建 systemd 服务
echo "==== 创建系统服务 ===="
cat > /etc/systemd/system/filebrowser.service << EOF
[Unit]
Description=FileBrowser Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/filebrowser --database /opt/filebrowser/filebrowser.db
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
echo "==== 启动服务 ===="
systemctl daemon-reload
systemctl enable filebrowser
systemctl start filebrowser

# 等待服务启动
sleep 3

# 检查服务状态
echo "==== 安装完成 ===="
echo ""
echo "====================================="
echo "FileBrowser 安装完成！"
echo "管理员账号：$ADMIN_USER"
echo "管理员密码：$ADMIN_PASS"
echo "访问地址：http://$(curl -s icanhazip.com):8080"
echo ""
echo "管理员功能："
echo "  - 上传/下载/删除文件"
echo "  - 分享文件或目录（生成链接）"
echo "  - 查看磁盘空间：http://$(curl -s icanhazip.com):8080/disk.html"
echo ""
echo "用户端："
echo "  - 只能通过分享链接访问"
echo "  - 无法浏览其他文件"
echo "  - 无法再次分享"
echo "====================================="
echo ""
echo "检查服务状态：systemctl status filebrowser"
echo "查看日志：journalctl -u filebrowser -f"
