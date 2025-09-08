#!/bin/bash

# FileBrowser 权限修复脚本
CONTAINER_NAME="filebrowser"
DATA_DIR="/srv/filebrowser"

echo "=== 修复 FileBrowser 权限问题 ==="

# 停止并删除现有容器
echo "清理现有容器..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

# 重新创建数据目录并设置正确权限
echo "重新设置目录权限..."
sudo rm -rf $DATA_DIR
sudo mkdir -p $DATA_DIR/data
sudo mkdir -p $DATA_DIR/config

# 设置正确的权限（容器内用户UID为1000）
sudo chown -R 1000:1000 $DATA_DIR
sudo chmod -R 775 $DATA_DIR

# 检查目录权限
echo "检查目录权限:"
ls -la $DATA_DIR/

# 启动容器（使用明确的用户ID）
echo "启动容器..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -v $DATA_DIR/data:/srv \
  -v $DATA_DIR/config:/config \
  -p 8080:80 \
  -e PUID=1000 \
  -e PGID=1000 \
  filebrowser/filebrowser:latest

# 等待启动
sleep 5

# 检查状态
echo "检查容器状态..."
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 容器运行成功！"
    
    # 显示访问信息
    IP=$(hostname -I | awk '{print $1}')
    echo "=================================================="
    echo "🌐 访问地址: http://$IP:8080"
    echo "🔑 用户名: admin"
    echo "🔒 密码: admin"
    echo "📁 数据目录: $DATA_DIR/data"
    echo "=================================================="
else
    echo "❌ 容器启动失败，查看详细日志："
    docker logs $CONTAINER_NAME
    
    # 备用方案：使用内部存储
    echo "尝试备用方案（使用容器内部存储）..."
    docker stop $CONTAINER_NAME 2>/dev/null
    docker rm $CONTAINER_NAME 2>/dev/null
    
    docker run -d \
      --name $CONTAINER_NAME \
      -p 8080:80 \
      filebrowser/filebrowser:latest
      
    sleep 3
    if docker ps | grep -q $CONTAINER_NAME; then
        echo "✅ 容器运行成功（使用内部存储）"
        echo "注意：数据将保存在容器内部，重启容器会丢失数据！"
    else
        echo "❌ 所有方案都失败，请检查Docker环境"
    fi
fi
