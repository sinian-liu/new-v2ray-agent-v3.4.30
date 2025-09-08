#!/bin/bash

# 更新系统并安装依赖
apt update && apt install -y docker.io net-tools
systemctl start docker
systemctl enable docker

# 确保root用户在docker组
usermod -aG docker root

# 创建目录并设置权限
mkdir -p /srv/files /srv/filebrowser
rm -rf /srv/filebrowser/*  # 清理旧数据库
chown -R 1000:1000 /srv/files /srv/filebrowser
chmod -R 775 /srv/files /srv/filebrowser

# 生成随机管理员密码
ADMIN_PASS=$(openssl rand -hex 12)

# 获取磁盘剩余空间
DISK_FREE=$(df -h /srv/files | tail -1 | awk '{print $4}')
DISK_TOTAL=$(df -h /srv/files | tail -1 | awk '{print $2}')
DISK_USED=$(df -h /srv/files | tail -1 | awk '{print $3}')

# 生成HTML文件
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
chown 1000:1000 /srv/files/disk_info.html
chmod 644 /srv/files/disk_info.html

# 清理旧容器
docker rm -f filebrowser

# 运行新容器
docker run -d \
  --name filebrowser \
  -v /srv/files:/srv \
  -v /srv/filebrowser:/database \
  -p 8082:80 \
  -e FB_ADMIN_USER=admin \
  -e FB_ADMIN_PASSWORD=$ADMIN_PASS \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

# 等待启动
sleep 5

# 检查状态
if docker ps | grep -q filebrowser && netstat -tuln | grep -q 8082; then
  echo "FileBrowser安装成功！容器运行中。"
  echo "访问地址: http://$(hostname -I | awk '{print $1}'):8082"
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

# 开放防火墙
ufw allow 8082
ufw allow 22
ufw enable

# HTTPS提示
echo "安全建议："
echo "1. 安装Nginx和Certbot: apt install nginx certbot python3-certbot-nginx"
echo "2. 配置Nginx反向代理到localhost:8082"
echo "3. 获取HTTPS证书: certbot --nginx"
echo "4. 防火墙只开80/443: ufw allow 80,443 && ufw deny 8082 && ufw enable"
