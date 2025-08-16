#!/bin/bash
# 独角数卡一键安装脚本 (Ubuntu / Debian / CentOS 通用)
# 作者：ChatGPT 优化版

set -e

# 颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${GREEN}🚀 独角数卡一键安装开始...${RESET}"

# 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚙️ 未检测到 Docker，正在安装...${RESET}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
fi

# 检查并安装 Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}⚙️ 未检测到 Docker Compose，正在安装...${RESET}"
    DOCKER_COMPOSE_VERSION="2.29.2"
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# 自动生成随机数据库信息
DB_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9_ | head -c12)
DB_USER="halo"
DB_NAME="halo"
APP_PORT=80

# 检查端口是否被占用
if ss -tuln | grep -q ":80 "; then
    echo -e "${RED}❌ 端口 80 已被占用！${RESET}"
    read -p "请输入一个新的端口号（例如 8080）：" new_port
    APP_PORT=$new_port
fi

# 生成 docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  app:
    image: dujiaoka/dujiaoka:latest
    container_name: dujiaoka_app
    restart: always
    ports:
      - "$APP_PORT:80"
    volumes:
      - ./dujiaoka:/www/dujiaoka
    environment:
      - DB_CONNECTION=mysql
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=$DB_NAME
      - DB_USERNAME=$DB_USER
      - DB_PASSWORD=$DB_PASSWORD
    depends_on:
      - db

  db:
    image: mysql:5.7
    container_name: dujiaoka_db
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASSWORD
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASSWORD
EOF

# 启动容器
echo -e "${YELLOW}⚙️ 正在启动独角数卡...${RESET}"
docker compose up -d || {
    echo -e "${RED}❌ 镜像 dujiaoka/dujiaoka 拉取失败，尝试使用备用镜像...${RESET}"
    sed -i 's#dujiaoka/dujiaoka:latest#registry.cn-hangzhou.aliyuncs.com/dujiaoka/dujiaoka:latest#g' docker-compose.yml
    docker compose up -d
}

# 获取服务器公网 IP
SERVER_IP=$(curl -s http://ipinfo.io/ip || echo "你的服务器IP")

echo -e "\n${GREEN}🎉 独角数卡已成功安装！${RESET}"
echo -e "-------------------------------------------"
echo -e "🌐 访问地址：http://$SERVER_IP:$APP_PORT"
echo -e "或本地地址：http://127.0.0.1:$APP_PORT"
echo -e "-------------------------------------------"
echo -e "📂 数据库信息："
echo -e "数据库名：$DB_NAME"
echo -e "数据库用户：$DB_USER"
echo -e "数据库密码：$DB_PASSWORD"
echo -e "-------------------------------------------"
echo -e "⚠️ 首次安装后，请在浏览器完成独角数卡的初始化配置。"
echo -e "默认后台地址：http://$SERVER_IP:$APP_PORT/admin"
echo -e "-------------------------------------------"
echo -e "${GREEN}✅ 请保存好以上信息！${RESET}"
