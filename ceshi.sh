#!/bin/bash
set -e

# 安装 Docker
if ! command -v docker &> /dev/null; then
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

# 创建数据目录
mkdir -p ~/changedetection-data

# 启动容器
echo "正在部署 changedetection.io..."
docker run -d \
  --name changedetection \
  -p 5000:5000 \
  -v ~/changedetection-data:/datastore \
  --restart unless-stopped \
  ghcr.io/dgtlmoon/changedetection.io

# 输出访问信息
YOUR_IP=$(curl -s icanhazip.com)
echo -e "\n\033[32m✅ 部署成功！请访问以下地址：\033[0m"
echo -e "http://${YOUR_IP}:5000"
echo -e "\n如需处理 JavaScript 页面，请执行以下命令安装浏览器驱动："
echo "docker exec -it changedetection sh -c 'playwright install chromium'"
