#!/bin/bash

# FileBrowser 完全重新安装脚本
CONTAINER_NAME="filebrowser"
DATA_DIR="/srv/filebrowser"
CONFIG_DIR="$DATA_DIR/config"

echo "=== FileBrowser 完全重新安装 ==="

# 清理现有容器和资源
echo "1. 清理现有容器..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

# 清理旧数据（可选，首次安装不需要）
read -p "是否删除旧数据？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "删除旧数据..."
    sudo rm -rf $DATA_DIR
fi

# 创建数据目录
echo "2. 创建数据目录..."
sudo mkdir -p $DATA_DIR/data
sudo mkdir -p $CONFIG_DIR
sudo chmod -R 755 $DATA_DIR
sudo chown -R $(id -u):$(id -g) $DATA_DIR

# 拉取最新镜像
echo "3. 拉取 Docker 镜像..."
docker pull filebrowser/filebrowser:latest

# 运行容器（简化版本）
echo "4. 启动容器..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -v $DATA_DIR/data:/srv \
  -v $CONFIG_DIR:/config \
  -p 8080:80 \
  filebrowser/filebrowser:latest

# 等待服务启动
echo "5. 等待服务启动..."
sleep 8

# 检查安装结果
echo "6. 检查安装结果..."
echo "=================================================="

# 检查容器状态
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ 容器状态: 运行中"
    echo "✅ 容器ID: $(docker ps -q --filter name=$CONTAINER_NAME)"
else
    echo "❌ 容器未运行，查看状态:"
    docker ps -a | grep $CONTAINER_NAME
    echo "❌ 容器日志:"
    docker logs $CONTAINER_NAME 2>/dev/null || echo "无法获取日志"
    exit 1
fi

# 检查端口监听
if netstat -tln | grep -q :8080; then
    echo "✅ 端口监听: 8080端口已监听"
else
    echo "⚠️  端口监听: 8080端口未监听"
fi

# 显示访问信息
IP=$(hostname -I | awk '{print $1}')
echo "=================================================="
echo "📋 访问信息:"
echo "   地址: http://$IP:8080"
echo "   地址: http://localhost:8080"
echo "   用户名: admin"
echo "   密码: admin"
echo ""
echo "📁 数据目录: $DATA_DIR/data"
echo "⚙️  配置目录: $CONFIG_DIR"
echo "=================================================="

# 测试连接
echo "7. 测试连接..."
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ 连接测试: 成功"
else
    echo "⚠️  连接测试: 失败，服务可能还在启动中"
    echo "请等待几秒后访问: http://$IP:8080"
fi
