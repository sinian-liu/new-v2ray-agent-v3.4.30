#!/bin/bash

# 设置安装目录
INSTALL_DIR="/root/dujiaoshuka"
echo "正在创建安装目录 ${INSTALL_DIR}..."
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

# 创建必要目录并设置权限
echo "创建 storage 和 uploads 目录并设置权限..."
mkdir -p storage uploads
chmod -R 777 storage uploads

# 下载配置文件
echo "下载 env.conf 和 docker-compose.yml 文件..."
wget -q https://raw.githubusercontent.com/stilleshan/dockerfiles/main/dujiaoka/env.conf
wget -q https://raw.githubusercontent.com/stilleshan/dockerfiles/main/dujiaoka/docker-compose.yml
chmod -R 777 env.conf

# 配置 docker-compose.yml
echo "配置 docker-compose.yml 文件..."
cat > docker-compose.yml << 'EOF'
version: "3"

services:
  web:
    image: stilleshan/dujiaoka
    environment:
        - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
    ports:
      - 8800:80
    restart: always

  db:
    image: mariadb:focal
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=37vps
      - MYSQL_DATABASE=dujiaoka
      - MYSQL_USER=dujiaoka
      - MYSQL_PASSWORD=37vps
    volumes:
      - ./mysql:/var/lib/mysql

  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./redis:/data
EOF

# 配置 env.conf
echo "配置 env.conf 文件..."
cat > env.conf << 'EOF'
APP_NAME=37VPS主机评测的小店
APP_ENV=local
APP_KEY=base64:hDVkYhfkUjaePiaI1tcBT7G8bh2A8RQxwWIGkq7BO18=
APP_DEBUG=true
APP_URL=https://dujiao.ydxian.xyz

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=dujiaoka
DB_USERNAME=dujiaoka
DB_PASSWORD=37vps

# redis配置
REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

# 缓存配置
CACHE_DRIVER=redis

# 异步消息队列
QUEUE_CONNECTION=redis

# 后台语言
DUJIAO_ADMIN_LANGUAGE=zh_CN

# 后台登录地址
ADMIN_ROUTE_PREFIX=/admin

# 是否开启 https
#ADMIN_HTTPS=true
EOF

# 部署 Docker 容器
echo "正在部署 Docker 容器..."
docker compose up -d

echo "安装完成！请按照以下步骤进行后续配置："
echo "1. 访问你的域名（需提前配置反向代理并启用 HTTPS）进行初始化安装。"
echo "2. 安装完成后，执行以下命令关闭安装模式并禁用调试："
echo "   cd ${INSTALL_DIR}"
echo "   docker compose down"
echo "   sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yml"
echo "   sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf"
echo "   docker compose up -d"
echo "3. 访问 域名/admin 进入控制台进行配置。"
echo "注意事项："
echo "- 上传图片需通过 HTTPS 访问。"
echo "- 所有数据位于 ${INSTALL_DIR} 目录，建议定期备份。"
echo "- 服务迁移时，将 ${INSTALL_DIR} 打包到新服务器，重新赋权（chmod -R 777 storage uploads env.conf）并执行 docker compose up -d。"
echo "- 反向代理配置参考：https://blog.ydxian.xyz/archives/nom（VPS）或 https://blog.ydxian.xyz/archives/lucky（NAS）。"
