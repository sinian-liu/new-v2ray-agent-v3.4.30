#!/bin/bash
set -e

echo "✅ 开始安装 Docker 和 Docker Compose..."

# 检测系统类型
OS=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

# 警告 EOL 系统
if [[ "$OS" == "ubuntu" && "$VERSION_ID" == "20.04" ]]; then
  echo "⚠️ Ubuntu 20.04 已经结束生命周期，建议升级系统"
fi

# 安装依赖
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
elif [[ "$OS" == "centos" || "$OS" == "rocky" || "$OS" == "almalinux" ]]; then
  yum install -y yum-utils curl
else
  echo "❌ 不支持的系统: $OS"
  exit 1
fi

# 安装 Docker（官方方式）
if ! command -v docker &>/dev/null; then
  echo "🔧 安装 Docker..."
  curl -fsSL https://get.docker.com | bash
fi

# 安装 Docker Compose（二进制方式）
if ! command -v docker-compose &>/dev/null; then
  echo "🔧 安装 Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

docker --version
docker-compose --version
echo "✅ Docker 与 Compose 安装完成"

# 准备部署目录
mkdir -p /opt/dujiaoka && cd /opt/dujiaoka

# 交互式生成 .env
read -rp "❓ 是否要修改默认域名或配置文件 (.env)？[y/N]: " change_env
if [[ "$change_env" =~ ^[Yy]$ ]]; then
  read -rp "请输入网站访问域名或服务器 IP（默认自动获取）: " DOMAIN
  DOMAIN=${DOMAIN:-$(curl -s ipv4.ip.sb || curl -s ifconfig.me)}
else
  DOMAIN=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
fi

# 写入 .env 文件
cat > .env <<EOF
INSTALL=false
APP_DEBUG=false
APP_URL=http://$DOMAIN
EOF

echo "✅ .env 文件已生成："
cat .env

# 写入 docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  web:
    image: stilleshan/dujiaoka
    container_name: dujiaoka
    ports:
      - "80:80"
    volumes:
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
      - ./.env:/dujiaoka/.env
    restart: always
EOF

# 启动容器
docker-compose up -d

echo ""
echo "🎉 Dujiaoka 发卡系统已成功部署！"
echo "📬 访问地址：http://$DOMAIN"
echo "🔧 后台地址：http://$DOMAIN/admin"
