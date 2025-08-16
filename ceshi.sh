#!/bin/bash
set -e

echo "=============================="
echo " 🚀 独角数卡 (Dujiaoka) 一键安装 "
echo "  适配: Ubuntu / Debian / CentOS (含旧版) "
echo "=============================="

# 检测 root 权限
if [ "$(id -u)" != "0" ]; then
   echo "❌ 请使用 root 用户运行"
   exit 1
fi

# 自动检测系统
if [ -f /etc/redhat-release ]; then
    OS="centos"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
else
    echo "❌ 不支持的系统"
    exit 1
fi

echo "👉 检测到系统: $OS"

# 安装必要依赖
install_base() {
    if [[ $OS == "centos" ]]; then
        yum install -y curl wget gnupg2 ca-certificates lsb-release
    else
        apt update -y
        apt install -y curl wget gnupg ca-certificates lsb-release
    fi
}

# 安装 Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "👉 安装 Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    else
        echo "✅ Docker 已安装"
    fi
}

# 安装 docker-compose (独立二进制)
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo "👉 安装 Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
          -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "✅ Docker Compose 已安装"
    fi
}

# 运行独角数卡
run_dujiaoka() {
    echo -n "请输入安装目录 (默认 /root/data/docker_data/shop): "
    read install_dir
    install_dir=${install_dir:-/root/data/docker_data/shop}
    echo "👉 安装目录设定为: $install_dir"

    echo -n "请输入访问端口 (默认 8090): "
    read web_port
    web_port=${web_port:-8090}

    echo -n "设置 MySQL root 密码 (默认 rootpass): "
    read mysql_root_pass
    mysql_root_pass=${mysql_root_pass:-rootpass}

    echo -n "设置数据库名称 (默认 dujiaoka): "
    read db_name
    db_name=${db_name:-dujiaoka}

    echo -n "设置数据库用户名 (默认 dujiaoka): "
    read db_user
    db_user=${db_user:-dujiaoka}

    echo -n "设置数据库用户密码 (默认 dbpass): "
    read db_pass
    db_pass=${db_pass:-dbpass}

    echo -n "设置 APP 名称 (默认 咕咕的小卖部): "
    read app_name
    app_name=${app_name:-咕咕的小卖部}

    echo -n "设置 APP_URL (如 https://yourdomain.com, 默认 http://localhost): "
    read app_url
    app_url=${app_url:-http://localhost}

    mkdir -p "$install_dir"
    cd "$install_dir"

    cat > docker-compose.yml <<EOF
version: '3'

services:
  dujiaoka:
    image: dujiaoka/dujiaoka:latest
    container_name: dujiaoka
    restart: always
    ports:
      - "${web_port}:80"
    environment:
      - DB_CONNECTION=mysql
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=${db_name}
      - DB_USERNAME=${db_user}
      - DB_PASSWORD=${db_pass}
      - APP_NAME=${app_name}
      - APP_URL=${app_url}
    depends_on:
      - db

  db:
    image: mysql:5.7
    container_name: dujiaoka-mysql
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_root_pass}
      - MYSQL_DATABASE=${db_name}
      - MYSQL_USER=${db_user}
      - MYSQL_PASSWORD=${db_pass}
    volumes:
      - db_data:/var/lib/mysql

volumes:
  db_data:
EOF

    echo "👉 启动容器..."
    docker-compose up -d
    echo "✅ 安装完成！"
    echo "请访问: ${app_url} (或 http://服务器IP:${web_port})"
}

# 主流程
install_base
install_docker
install_docker_compose
run_dujiaoka
