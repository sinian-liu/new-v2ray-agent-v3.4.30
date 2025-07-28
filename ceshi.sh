#!/bin/bash

set -e

APP_ROOT="/home/web/html/web5"
APP_CODE_DIR="$APP_ROOT/dujiaoka"
DOCKER_COMPOSE_FILE="$APP_ROOT/docker-compose.yml"
ENV_FILE="$APP_CODE_DIR/.env"

echo "===== 独角数卡 一键安装脚本 ====="

# 1. 安装 Docker
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "检测到已安装 Docker，跳过安装。"
  else
    echo "开始安装 Docker..."
    if [ -f /etc/debian_version ]; then
      apt-get update
      apt-get install -y ca-certificates curl gnupg lsb-release
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io
    elif [ -f /etc/centos-release ]; then
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      yum install -y docker-ce docker-ce-cli containerd.io
      systemctl start docker
      systemctl enable docker
    else
      echo "不支持当前系统，请手动安装 Docker。"
      exit 1
    fi
    echo "Docker 安装完成。"
  fi
}

# 2. 安装 Docker Compose (v2.39.1)
install_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    echo "检测到已安装 Docker Compose，跳过安装。"
  else
    echo "开始安装 Docker Compose..."
    DOCKER_COMPOSE_VERSION="v2.39.1"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "Docker Compose 安装完成。"
  fi
}

# 3. 修改 docker-compose.yml，确保 PHP 服务代码挂载正确
fix_docker_compose() {
  echo "修正 docker-compose.yml 中代码挂载路径..."
  if grep -q '^\s*volumes:' "$DOCKER_COMPOSE_FILE"; then
    # 用 sed 替换 volumes 中 ./:/var/www/html 为 ./dujiaoka:/var/www/html
    sed -i.bak -E 's#^\s*- \./(:?/)?\s*/var/www/html#      - ./dujiaoka:/var/www/html#' "$DOCKER_COMPOSE_FILE"
  else
    echo "docker-compose.yml 文件中找不到 volumes 配置，请检查！"
    exit 1
  fi
}

# 4. 生成 .env 文件交互填写
generate_env_file() {
  echo "生成并配置 .env 文件"
  [ -f "$ENV_FILE" ] && mv "$ENV_FILE" "$ENV_FILE.bak.$(date +%s)"
  
  read -rp "请输入站点名称（默认 Dujiaoka）: " SITE_NAME
  SITE_NAME=${SITE_NAME:-Dujiaoka}
  
  read -rp "请输入站点 URL（默认 http://localhost）: " SITE_URL
  SITE_URL=${SITE_URL:-http://localhost}
  
  read -rp "请输入数据库名称（默认 dujiaoka）: " DB_NAME
  DB_NAME=${DB_NAME:-dujiaoka}
  
  read -rp "请输入数据库用户名（默认 dujiaoka）: " DB_USER
  DB_USER=${DB_USER:-dujiaoka}
  
  read -rsp "请输入数据库密码（默认 dujiaoka_pass）: " DB_PASS
  echo
  DB_PASS=${DB_PASS:-dujiaoka_pass}
  
  read -rp "是否开启调试模式？(true/false，默认 false): " APP_DEBUG
  APP_DEBUG=${APP_DEBUG:-false}

  cat > "$ENV_FILE" <<EOF
APP_NAME=$SITE_NAME
APP_URL=$SITE_URL
APP_DEBUG=$APP_DEBUG

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
EOF

  echo ".env 文件生成完成。"
}

# 5. 启动容器
start_containers() {
  echo "启动 Docker 容器..."
  cd "$APP_ROOT"
  docker-compose down || true
  docker-compose up -d
  echo "Docker 容器启动完成。"
}

# 6. 初始化数据库提示
print_init_instructions() {
  echo -e "\n===== 初始化提示 ====="
  echo "首次运行需要进入 PHP 容器初始化数据库，执行以下命令："
  echo "docker exec -it \$(docker-compose ps -q dujiaoka-php) bash"
  echo "cd /var/www/html"
  echo "php artisan key:generate"
  echo "php artisan migrate --seed"
  echo -e "\n访问地址请打开 $SITE_URL 或 http://服务器IP\n"
}

main() {
  install_docker
  install_docker_compose
  fix_docker_compose
  generate_env_file
  start_containers
  print_init_instructions
}

main
