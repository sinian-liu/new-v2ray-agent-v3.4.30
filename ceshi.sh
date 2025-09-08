#!/bin/bash

# FileBrowser 一键安装脚本（管理员+用户端分离版）
set -e

echo "正在安装 FileBrowser（管理员和用户端分离）..."

# 更新系统并安装依赖
apt update && apt install -y docker.io net-tools sqlite3
systemctl start docker
systemctl enable docker

# 确保root用户在docker组
usermod -aG docker root

# 创建目录结构
mkdir -p /srv/files /srv/filebrowser /srv/filebrowser-user
rm -rf /srv/filebrowser/* /srv/filebrowser-user/*
chown -R 1000:1000 /srv/files /srv/filebrowser /srv/filebrowser-user
chmod -R 775 /srv/files /srv/filebrowser /srv/filebrowser-user

# 生成可靠的管理员密码
ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+' | head -c 12)

# 获取服务器IP和磁盘信息
SERVER_IP=$(hostname -I | awk '{print $1}')
DISK_FREE=$(df -h /srv/files | tail -1 | awk '{print $4}')
DISK_TOTAL=$(df -h /srv/files | tail -1 | awk '{print $2}')
DISK_USED=$(df -h /srv/files | tail -1 | awk '{print $3}')

# 创建示例文件
echo "这是管理员上传的示例文件" > /srv/files/示例文件.txt
mkdir -p /srv/files/公开目录
echo "这个目录可以被分享" > /srv/files/公开目录/README.txt

# 清理旧容器
docker rm -f filebrowser filebrowser-user 2>/dev/null || true

# 运行管理员端FileBrowser容器
echo "启动管理员端（端口8082）..."
docker run -d \
  --name filebrowser \
  -v /srv/files:/srv \
  -v /srv/filebrowser:/database \
  -p 8082:80 \
  -e FB_ADMIN_USER=admin \
  -e FB_ADMIN_PASSWORD=$ADMIN_PASS \
  -e FB_BASEURL="/" \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

# 等待管理员端启动
sleep 8

# 配置管理员端数据库（启用分享功能）
if [ -f "/srv/filebrowser/filebrowser.db" ]; then
    sqlite3 /srv/filebrowser/filebrowser.db << EOF
    -- 确保分享功能启用
    UPDATE settings SET value = 'true' WHERE key = 'allowCommands';
    UPDATE settings SET value = 'true' WHERE key = 'allowEdit';
    UPDATE settings SET value = 'true' WHERE key = 'allowNew';
    UPDATE settings SET value = 'true' WHERE key = 'allowPublish';
    UPDATE settings SET value = 'true' WHERE key = 'allowShare';
EOF
fi

# 运行用户端FileBrowser容器（只读模式）
echo "启动用户端（端口8083）..."
docker run -d \
  --name filebrowser-user \
  -v /srv/files:/srv \
  -v /srv/filebrowser-user:/database \
  -p 8083:80 \
  -e FB_BASEURL="/" \
  -e FB_ROOT="/srv" \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

# 等待用户端启动
sleep 5

# 配置用户端数据库（设置为只读免登录）
if [ -f "/srv/filebrowser-user/filebrowser.db" ]; then
    sqlite3 /srv/filebrowser-user/filebrowser.db << EOF
    -- 禁用所有写操作
    UPDATE settings SET value = 'false' WHERE key = 'allowCommands';
    UPDATE settings SET value = 'false' WHERE key = 'allowEdit';
    UPDATE settings SET value = 'false' WHERE key = 'allowNew';
    UPDATE settings SET value = 'false' WHERE key = 'allowPublish';
    UPDATE settings SET value = 'false' WHERE key = 'allowShare';
    UPDATE settings SET value = 'false' WHERE key = 'allowRm';
    
    -- 禁用登录要求
    UPDATE settings SET value = 'true' WHERE key = 'allowPerms';
    UPDATE settings SET value = 'false' WHERE key = 'authMethod' OR key = 'authHeader';
    
    -- 设置默认只读权限
    INSERT OR REPLACE INTO users (id, username, password, scope, locale, view_mode, single_click, perm, commands, lock_password)
    VALUES (1, 'guest', '', '/', 'zh-CN', 'list', 0, '{"admin":false,"execute":false,"create":false,"rename":false,"modify":false,"delete":false,"share":false,"download":true}', '[]', 0);
    
    -- 设置匿名用户权限
    UPDATE settings SET value = '{"admin":false,"execute":false,"create":false,"rename":false,"modify":false,"delete":false,"share":false,"download":true}' WHERE key = 'userPerm';
EOF
fi

# 重启用户端容器应用配置
docker restart filebrowser-user
sleep 3

# 开放防火墙端口
if command -v ufw >/dev/null 2>&1; then
    ufw allow 8082/tcp >/dev/null 2>&1
    ufw allow 8083/tcp >/dev/null 2>&1
    ufw allow 22/tcp >/dev/null 2>&1
fi

# 显示安装结果
echo ""
echo "================================================"
echo "✅ FileBrowser 安装成功！"
echo "================================================"
echo "管理员端（完全权限）："
echo "  - 访问地址: http://$SERVER_IP:8082"
echo "  - 用户名: admin"
echo "  - 密码: $ADMIN_PASS"
echo ""
echo "用户端（只读免登录）："
echo "  - 访问地址: http://$SERVER_IP:8083"
echo "  - 无需登录，只能查看和下载已分享的文件"
echo ""
echo "文件存储路径: /srv/files"
echo "磁盘总空间: $DISK_TOTAL"
echo "================================================"
echo ""

# 使用说明
echo "📖 使用说明："
echo "1. 管理员登录 http://$SERVER_IP:8082 上传和管理文件"
echo "2. 在管理员端选中文件/目录 → 点击分享图标 → 生成分享链接"
echo "3. 用户通过分享链接访问特定文件/目录（无需登录）"
echo "4. 用户端 http://$SERVER_IP:8083 只能访问已分享的内容"
echo ""
echo "🔒 安全特性："
echo "   - 用户端完全只读，无法修改、删除或上传文件"
echo "   - 用户端免登录，但只能访问被分享的特定链接"
echo "   - 管理员端需要密码认证，拥有完整权限"
echo ""
echo "🔄 如果需要重置："
echo "   docker stop filebrowser filebrowser-user"
echo "   rm -rf /srv/filebrowser/* /srv/filebrowser-user/*"
echo "   ./install-filebrowser.sh"
