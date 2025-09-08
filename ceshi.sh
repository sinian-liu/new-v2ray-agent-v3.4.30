#!/bin/bash

# FileBrowser 一键安装脚本
CONTAINER_NAME="filebrowser"
DATA_DIR="/srv/filebrowser"
CONFIG_FILE="$DATA_DIR/config/filebrowser.json"
DATABASE_FILE="$DATA_DIR/database.db"

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) IMAGE_ARCH="amd64" ;;
    aarch64) IMAGE_ARCH="arm64" ;;
    armv7l) IMAGE_ARCH="armv7" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 创建数据目录
sudo mkdir -p $DATA_DIR/{config,data}
sudo chmod -R 755 $DATA_DIR

# 拉取合适的镜像
docker pull filebrowser/filebrowser:$IMAGE_ARCH

# 停止并删除现有容器（如果存在）
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

# 运行容器
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -v $DATA_DIR/config:/config \
  -v $DATA_DIR/data:/srv \
  -v $DATABASE_FILE:/database.db \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -p 8080:80 \
  filebrowser/filebrowser:$IMAGE_ARCH

# 等待服务启动
sleep 3

# 获取本机IP地址
IP=$(hostname -I | awk '{print $1}')

echo "=================================================="
echo "FileBrowser 安装完成！"
echo "访问地址: http://$IP:8080"
echo ""
echo "默认用户名: admin"
echo "默认密码: admin"
echo ""
echo "数据目录: $DATA_DIR/data"
echo "配置文件: $CONFIG_FILE"
echo "=================================================="

# 显示初始登录提示
echo "请注意：首次登录后请立即修改默认密码！"
