#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 自动生成随机密码
generate_password() {
    < /dev/urandom tr -dc A-Za-z0-9_ | head -c8
}

DB_PASSWORD=$(generate_password)
ADMIN_PASSWORD=$(generate_password)
DB_USER="halo"
DB_NAME="halo"
APP_PORT=80

echo -e "${YELLOW}欢迎使用独角数卡一键安装脚本！${NC}"

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请以 root 用户身份运行此脚本！${NC}"
    exit 1
fi

# 检查并安装依赖
install_dependencies() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                echo -e "${YELLOW}正在更新 apt 并安装依赖...${NC}"
                apt-get update
                apt-get install -y ca-certificates curl gnupg net-tools
                ;;
            centos)
                echo -e "${YELLOW}正在更新 yum 并安装依赖...${NC}"
                yum install -y yum-utils net-tools curl
                ;;
            *)
                echo -e "${RED}不支持的操作系统：$ID${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}无法识别的操作系统类型。${NC}"
        exit 1
    fi
}

# 检查并安装 Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}未检测到 Docker，正在自动安装...${NC}"
        # 不同的系统使用不同的安装方式
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    install -m 0755 -d /etc/apt/keyrings
                    curl -fsSL https://download.docker.com/linux/"$ID"/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                    chmod a+r /etc/apt/keyrings/docker.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/"$ID" $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                    apt-get update
                    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    ;;
                centos)
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                    systemctl start docker
                    systemctl enable docker
                    ;;
                *)
                    echo -e "${RED}不支持的操作系统：$ID${NC}"
                    exit 1
                    ;;
            esac
        else
            echo -e "${RED}无法识别的操作系统类型。${NC}"
            exit 1
        fi
        echo -e "${GREEN}Docker 安装完成。${NC}"
    else
        echo -e "${GREEN}Docker 已安装。${NC}"
    fi

    # 检查并安装 Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose &> /dev/null; then
        echo -e "${YELLOW}未检测到 Docker Compose，正在自动安装...${NC}"
        docker_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d : -f 2,3 | tr -d '", ')
        curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        if ! command -v docker-compose &> /dev/null; then
             echo -e "${RED}Docker Compose 安装失败，请手动检查。${NC}"
             exit 1
        fi
        echo -e "${GREEN}Docker Compose 安装完成。${NC}"
    else
        echo -e "${GREEN}Docker Compose 已安装。${NC}"
    fi

    # 确保 Docker 服务正在运行
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}Docker 服务未运行，正在启动...${NC}"
        systemctl start docker
        systemctl enable docker
    fi
}

# 检查端口占用情况
check_port() {
    netstat -lnpt | grep -q ":$1 "
}

# 询问并设置端口
set_port() {
    while check_port "$APP_PORT"; do
        echo -e "${YELLOW}端口 $APP_PORT 已被占用。${NC}"
        read -p "请输入一个新的端口号（例如 8080）：" new_port
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            APP_PORT=$new_port
            echo -e "${GREEN}已将端口设置为 $APP_PORT。${NC}"
        else
            echo -e "${RED}无效的端口号。请重新输入。${NC}"
        fi
    done
}

# 创建 Docker Compose 文件
create_docker_compose() {
    echo -e "${YELLOW}正在生成 Docker Compose 文件...${NC}"

    cat <<EOF > docker-compose.yml
version: "3"
services:
  app:
    image: ghcr.io/baijunyao/dujiaoka:v2
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
    volumes:
      - ./mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASSWORD
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASSWORD
EOF
}

# 运行安装过程
main() {
    install_dependencies
    install_docker
    set_port
    create_docker_compose
    echo -e "${YELLOW}正在启动独角数卡...${NC}"
    
    # 使用 docker-compose 命令，兼容新版本
    docker compose up -d

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}独角数卡已成功安装！${NC}"
        echo -e "${GREEN}-------------------------------------------${NC}"
        echo -e "${GREEN}请访问以下地址进行安装配置：${NC}"
        echo -e "${GREEN}网站地址：http://$(curl -s http://ipinfo.io/ip):$APP_PORT${NC}"
        echo -e "${GREEN}或本地地址：http://127.0.0.1:$APP_PORT${NC}"
        echo -e "${GREEN}-------------------------------------------${NC}"
        echo -e "${GREEN}数据库信息（脚本已自动填写，无需手动输入）：${NC}"
        echo -e "${GREEN}数据库连接类型：mysql${NC}"
        echo -e "${GREEN}数据库地址：db${NC}"
        echo -e "${GREEN}数据库端口：3306${NC}"
        echo -e "${GREEN}数据库名：$DB_NAME${NC}"
        echo -e "${GREEN}数据库用户名：$DB_USER${NC}"
        echo -e "${GREEN}数据库密码：$DB_PASSWORD${NC}"
        echo -e "${GREEN}-------------------------------------------${NC}"
        echo -e "${GREEN}请保存此信息，用于未来的管理。${NC}"
    else
        echo -e "${RED}独角数卡安装失败。请检查日志。${NC}"
        exit 1
    fi
}

main
