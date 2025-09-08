#!/bin/bash

# 检查是否以非root用户运行（需sudo权限）
if [ "$EUID" -eq 0 ]; then
  echo "请以非root用户运行此脚本（需sudo权限）"
  exit 1
fi

# 更新系统并安装Docker
sudo apt update && sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# 确保用户在docker组（避免每次sudo）
sudo usermod -aG docker $USER

# 创建文件和配置目录
sudo mkdir -p /srv/files /srv/filebrowser
sudo chown -R $USER:$USER /srv/files /srv/filebrowser

# 生成随机管理员密码
ADMIN_PASS=$(openssl rand -hex 12)

# 获取磁盘剩余空间（/srv/files所在磁盘，单位GB）
DISK_FREE=$(df -h /srv/files | tail -1 | awk '{print $4}')
DISK_TOTAL=$(df -h /srv/files | tail -1 | awk '{print $2}')
DISK_USED=$(df -h /srv/files | tail -1 | awk '{print $3}')

# 生成HTML文件显示磁盘空间
cat << EOF > /srv/files/disk_info.html
<!DOCTYPE html>
<html>
<head>
  <title>Disk Space Information</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h1 { color: #333; }
    .info { font-size: 18px; margin-top: 20px; }
  </style>
</head>
<body>
  <h1>Disk Space Information</h1>
  <div class="info">
    <p>Total Space: $DISK_TOTAL</p>
    <p>Used Space: $DISK_USED</p>
    <p>Free Space: $DISK_FREE</p>
  </div>
</body>
</html>
EOF

# 设置HTML文件权限
sudo chown $USER:$USER /srv/files/disk_info.html
sudo chmod 644 /srv/files/disk_info.html

# 运行FileBrowser容器
docker run -d \
  --name filebrowser \
  -v /srv/files:/srv \
  -v /srv/filebrowser:/database \
  -p 8080:80 \
  -e FB_ADMIN_USER=admin \
  -e FB_ADMIN_PASSWORD=$ADMIN_PASS \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

# 等待容器启动
sleep 5

# 检查容器状态
if docker ps | grep -q filebrowser; then
  echo "FileBrowser安装成功！容器运行中。"
  echo "访问地址: http://$(hostname -I | awk '{print $1}'):8080"
  echo "管理员用户名: admin"
  echo "管理员密码: $ADMIN_PASS (请立即在Web界面修改！)"
  echo "文件存储路径: /srv/files"
  echo "磁盘空间信息: 登录后访问 /disk_info.html 查看"
  echo "  - 总空间: $DISK_TOTAL"
  echo "  - 已用: $DISK_USED"
  echo "  - 剩余: $DISK_FREE"
else
  echo "FileBrowser启动失败，请检查日志: docker logs filebrowser"
  exit 1
fi

# 可选：HTTPS配置提示
echo "安全建议："
echo "1. 安装Nginx和Certbot: sudo apt install nginx certbot python3-certbot-nginx"
echo "2. 配置Nginx反向代理到localhost:8080"
echo "3. 获取HTTPS证书: sudo certbot --nginx"
echo "4. 防火墙只开80/443: sudo ufw allow 80,443 && sudo ufw enable"
