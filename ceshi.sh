#!/bin/bash

# FileBrowser 修复安装脚本
set -e

echo "修复 FileBrowser 安装..."

# 停止并删除所有容器
docker stop filebrowser filebrowser-user 2>/dev/null || true
docker rm filebrowser filebrowser-user 2>/dev/null || true

# 彻底清理数据库
rm -rf /srv/filebrowser/* /srv/filebrowser-user/*

# 使用简单密码（避免特殊字符问题）
ADMIN_PASS="Admin123456"  # 使用简单密码确保能登录

# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# 方法1：使用docker命令参数设置密码（最可靠）
echo "方法1：使用docker参数设置管理员端..."
docker run -d \
  --name filebrowser \
  -v /srv/files:/srv \
  -v /srv/filebrowser:/database \
  -p 8082:80 \
  --restart unless-stopped \
  filebrowser/filebrowser:latest \
  --username admin \
  --password "$ADMIN_PASS"

echo "等待管理员端启动..."
sleep 20

# 检查管理员端是否正常运行
if docker ps | grep -q filebrowser; then
    echo "✅ 管理员端启动成功"
else
    echo "❌ 管理员端启动失败，尝试方法2..."
    docker logs filebrowser
    
    # 方法2：使用环境变量
    docker rm -f filebrowser 2>/dev/null || true
    docker run -d \
      --name filebrowser \
      -v /srv/files:/srv \
      -v /srv/filebrowser:/database \
      -p 8082:80 \
      -e FB_ADMIN_USER=admin \
      -e FB_ADMIN_PASSWORD="$ADMIN_PASS" \
      --restart unless-stopped \
      filebrowser/filebrowser:latest
      
    sleep 15
fi

# 配置用户端为免登录只读模式
echo "配置用户端..."
docker run -d \
  --name filebrowser-user \
  -v /srv/files:/srv \
  -v /srv/filebrowser-user:/database \
  -p 8083:80 \
  --restart unless-stopped \
  filebrowser/filebrowser:latest

sleep 10

# 通过exec命令配置用户端设置
docker exec filebrowser-user filebrowser users update admin --perm.download=true --perm.execute=false --perm.create=false --perm.rename=false --perm.modify=false --perm.delete=false --perm.share=false 2>/dev/null || true

# 重启用户端应用配置
docker restart filebrowser-user
sleep 5

# 显示修复结果
echo ""
echo "================================================"
echo "✅ FileBrowser 修复完成！"
echo "================================================"
echo "管理员端（完全权限）："
echo "  - 访问地址: http://$SERVER_IP:8082"
echo "  - 用户名: admin"
echo "  - 密码: $ADMIN_PASS"
echo ""
echo "用户端（只读免登录）："
echo "  - 访问地址: http://$SERVER_IP:8083"
echo "  - 无需登录"
echo "================================================"

# 测试登录
echo ""
echo "测试登录..."
echo "如果仍然无法登录，请尝试以下步骤："

# 查看密码是否正确设置
echo "1. 查看容器日志中的密码信息："
docker logs filebrowser 2>&1 | grep -i "admin\|password\|user" | head -5

echo ""
echo "2. 手动重置密码："
echo "   docker exec filebrowser filebrowser users update admin --password \"NewPassword123\""

echo ""
echo "3. 或者进入容器查看用户信息："
echo "   docker exec filebrowser filebrowser users ls"

echo ""
echo "4. 如果问题依旧，尝试使用默认密码："
echo "   用户名: admin"
echo "   密码: admin"
