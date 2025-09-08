#!/bin/bash

# FileBrowser 一键安装脚本（自定义密码版）
CONTAINER_NAME="filebrowser"
DATA_DIR="/srv/filebrowser"
CUSTOM_PASSWORD="Admin12345678"

echo "=== FileBrowser 安装脚本（密码: $CUSTOM_PASSWORD）==="

# 清理现有容器
echo "1. 清理现有容器..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

# 创建数据目录并设置权限
echo "2. 创建数据目录..."
sudo rm -rf $DATA_DIR
sudo mkdir -p $DATA_DIR/data
sudo mkdir -p $DATA_DIR/config
sudo chown -R 1000:1000 $DATA_DIR
sudo chmod -R 775 $DATA_DIR

# 拉取最新镜像
echo "3. 拉取 Docker 镜像..."
docker pull filebrowser/filebrowser:latest

# 启动容器（先不设置密码）
echo "4. 启动容器..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -v $DATA_DIR/data:/srv \
  -v $DATA_DIR/config:/config \
  -p 8080:80 \
  -e PUID=1000 \
  -e PGID=1000 \
  filebrowser/filebrowser:latest

# 等待服务启动
echo "5. 等待服务启动..."
sleep 8

# 设置自定义密码
echo "6. 设置自定义密码..."
docker exec $CONTAINER_NAME filebrowser users update admin --password "$CUSTOM_PASSWORD"

# 检查安装结果
echo "7. 检查安装结果..."
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 容器状态: 运行成功"
else
    echo "❌ 容器启动失败，查看日志:"
    docker logs $CONTAINER_NAME
    exit 1
fi

# 显示访问信息
IP=$(hostname -I | awk '{print $1}')
echo "=================================================="
echo "🌐 访问地址: http://$IP:8080"
echo "🔑 用户名: admin"
echo "🔒 密码: $CUSTOM_PASSWORD"
echo "📁 数据目录: $DATA_DIR/data"
echo "⚙️  配置目录: $DATA_DIR/config"
echo "=================================================="

# 测试连接
echo "8. 测试连接..."
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ 连接测试: 成功"
else
    echo "⚠️  连接测试: 失败，服务可能还在启动中"
fi

echo "安装完成！请使用密码 $CUSTOM_PASSWORD 登录"
