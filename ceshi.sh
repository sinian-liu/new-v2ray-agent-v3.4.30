#!/bin/bash
set -e

echo "✅ 开始安装 Docker 和 Docker Compose..."

# 检测系统
OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
VERSION_ID=$(grep 'VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# 安装基础依赖
if [[ $OS == "ubuntu" || $OS == "debian" ]]; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
elif [[ $OS == "centos" || $OS == "rocky" || $OS == "almalinux" ]]; then
  yum install -y yum-utils device-mapper-persistent-data lvm2 curl
else
  echo "❌ 不支持的系统: $OS"
  exit 1
fi

# 安装 Docker
if ! command -v docker &>/dev/null; then
  echo "🔧 安装 Docker..."
  curl -fsSL https://get.docker.com | bash
fi

# 安装 Docker Compose（二进制方式）
if ! command -v docker-compose &>/dev/null; then
  echo "🔧 安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

docker --version
docker-compose --version

echo "✅ Docker 与 Compose 安装完成"

# 创建目录
mkdir -p /opt/dujiaoka && cd /opt/dujiaoka

# 创建 .env 文件
cat > .env <<EOF
INSTALL=false
APP_DEBUG=false
APP_URL=http://$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
EOF

# 提示用户是否要修改配置
read -rp "❓ 是否要修改默认域名或配置文件 (.env)？[y/N]: " edit_env
if [[ "$edit_env" =~ ^[Yy]$ ]]; then
  nano .env
fi

# 创建 docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3"
services:
  web:
    image: stilleshan/dujiaoka
    container_name: dujiaoka
    ports:
      - "80:80"
    volumes:
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
      - ./env:/dujiaoka/.env
    restart: always
EOF

# 防火墙处理（如存在）
if command -v ufw &>/dev/null; then
  ufw allow 80
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --add-port=80/tcp --permanent
  firewall-cmd --reload
fi

# 创建 env 文件映射
mkdir -p ./env
cp .env ./env/.env

# 启动容器
docker-compose up -d

IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

echo ""
echo "🎉 Dujiaoka 安装成功！"
echo "📬 访问地址：http://$IP"
echo "🔧 后台地址：http://$IP/admin"
echo "👉 默认账户：admin（请登录后立即修改）"
