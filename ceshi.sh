#!/bin/bash
# Nextcloud 一键安装脚本 (基于 Docker)
# 访问方式：http://你的VPS_IP:8080

set -e

echo "==== 更新系统并安装 Docker 环境 ===="
apt update -y
apt install -y curl sudo
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

echo "==== 创建 Nextcloud + MariaDB + Redis 容器 ===="
docker network create nextcloud-net || true

# 数据库
docker run -d \
  --name nextcloud-mariadb \
  --network nextcloud-net \
  -e MYSQL_ROOT_PASSWORD=123456 \
  -e MYSQL_DATABASE=nextcloud \
  -e MYSQL_USER=nextcloud \
  -e MYSQL_PASSWORD=123456 \
  -v /opt/nextcloud/db:/var/lib/mysql \
  mariadb:10.11 \
  --transaction-isolation=READ-COMMITTED \
  --binlog-format=ROW

# Redis (缓存/加速)
docker run -d \
  --name nextcloud-redis \
  --network nextcloud-net \
  redis:alpine

# Nextcloud 主程序
docker run -d \
  --name nextcloud \
  --network nextcloud-net \
  -p 8080:80 \
  -v /opt/nextcloud/html:/var/www/html \
  -v /opt/nextcloud/data:/var/www/html/data \
  -e MYSQL_HOST=nextcloud-mariadb \
  -e MYSQL_DATABASE=nextcloud \
  -e MYSQL_USER=nextcloud \
  -e MYSQL_PASSWORD=123456 \
  -e REDIS_HOST=nextcloud-redis \
  nextcloud:apache

echo "==== Nextcloud 已启动 ===="
echo "请访问: http://$(curl -s ifconfig.me):8080"
echo "首次进入请设置管理员账号和密码"
echo "数据库信息如下："
echo "  数据库: nextcloud"
echo "  用户: nextcloud"
echo "  密码: 123456"
