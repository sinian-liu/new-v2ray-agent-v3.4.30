#!/bin/bash

# FileBrowser 完整安装脚本（包含Docker安装）
set -e

echo "正在安装 Docker 和 FileBrowser..."

# 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo "安装 Docker..."
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
else
    echo "Docker 已安装"
fi

# 启动并启用 Docker
systemctl start docker
systemctl enable docker

# 将当前用户添加到 docker 组（避免权限问题）
if ! groups $USER | grep -q '\bdocker\b'; then
    usermod -aG docker $USER
    echo "⚠️  请重新登录或运行 'newgrp docker' 使权限生效"
fi

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
chown -R 1000:1000 /srv/files

# 清理旧容器
docker rm -f filebrowser filebrowser-user 2>/dev/null || true

# 第一步：启动管理员端
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

echo "等待管理员端初始化（30秒）..."
sleep 30

# 检查管理员端是否正常运行
if ! docker ps | grep -q filebrowser; then
    echo "❌ 管理员端启动失败，查看日志："
    docker logs filebrowser
    exit 1
fi

# 第二步：使用配置文件创建用户端
echo "创建用户端配置文件..."
cat > /srv/filebrowser-user/settings.json << 'EOF'
{
  "auth": {
    "method": "noauth"
  },
  "users": [
    {
      "username": "guest",
      "password": "",
      "scope": "/srv",
      "perm": {
        "admin": false,
        "execute": false,
        "create": false,
        "rename": false,
        "modify": false,
        "delete": false,
        "share": false,
        "download": true
      },
      "commands": [],
      "lockPassword": false
    }
  ],
  "settings": {
    "key": "",
    "allowCommands": false,
    "allowEdit": false,
    "allowNew": false,
    "allowPublish": false,
    "allowShare": false,
    "allowRm": false,
    "authMethod": "noauth",
    "baseURL": "",
    "branding": {
      "name": "文件分享",
      "disableExternal": false,
      "disableUsedPercentage": false,
      "files": "/srv"
    },
    "commands": [],
    "defaultUserScope": "/srv",
    "enableThumbnails": false,
    "hideDotFiles": false,
    "jwtSecret": "",
    "log": "",
    "port": 80,
    "root": "/srv",
    "shell": [],
    "signup": false,
    "tlsKey": "",
    "tlsCert": "",
    "userHomeBasePath": "",
    "userPerm": {
      "admin": false,
      "execute": false,
      "create": false,
      "rename": false,
      "modify": false,
      "delete": false,
      "share": false,
      "download": true
    }
  }
}
EOF

chown 1000:1000 /srv/filebrowser-user/settings.json

# 第三步：启动用户端
echo "启动用户端（端口8083）..."
docker run -d \
  --name filebrowser-user \
  -v /srv/files:/srv \
  -v /srv/filebrowser-user:/database \
  -p 8083:80 \
  -e FB_CONFIG=/database/settings.json \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

echo "等待用户端启动..."
sleep 15

# 检查用户端是否正常运行
if ! docker ps | grep -q filebrowser-user; then
    echo "❌ 用户端启动失败，查看日志："
    docker logs filebrowser-user
    exit 1
fi

# 开放防火墙端口
if command -v ufw >/dev/null 2>&1; then
    ufw allow 8082/tcp >/dev/null 2>&1
    ufw allow 8083/tcp >/dev/null 2>&1
    ufw allow 22/tcp >/dev/null 2>&1
    echo "✅ 防火墙端口已开放"
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
echo ""
echo "🔒 安全特性："
echo "   - 用户端完全只读，无法修改、删除或上传文件"
echo "   - 用户端免登录，但只能访问被分享的特定链接"
echo "   - 管理员端需要密码认证，拥有完整权限"
echo ""
echo "🔄 如果需要重置："
echo "   docker stop filebrowser filebrowser-user"
echo "   docker rm filebrowser filebrowser-user"
echo "   rm -rf /srv/filebrowser/* /srv/filebrowser-user/*"
echo "   然后重新运行此脚本"
