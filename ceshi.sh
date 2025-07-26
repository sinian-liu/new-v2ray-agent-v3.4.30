```bash
#!/bin/bash

# 日志输出到文件
exec > >(tee -a /var/log/dujiaoka_install.log) 2>&1

# 检查是否为 root 用户
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限运行，请使用 sudo 或切换到 root 用户。"
    exit 1
fi

# 设置变量
INSTALL_DIR="/root/Shop"
DOMAIN=""
EMAIL=""
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS=$(openssl rand -base64 12)
APP_NAME="独角数卡"
APP_KEY="base64:rKwRuI6eRpCw/9e2XZKKGj/Yx3iZy5e7+FQ6+aQl8Zg="
PORT="56789"
ENABLE_EPUSTD="n"

# 提示用户输入信息
read -p "请输入你的域名（例如：shop.example.com）: " DOMAIN
if ! [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "无效的域名格式！"
    exit 1
fi
read -p "请输入你的邮箱（用于 Let's Encrypt 证书通知）： " EMAIL
if [ -z "$EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 0
fi
read -p "请输入外部端口（默认 56789，输入 0 使用 80 端口：80 " INPUT_PORT
if [ "$INPUT_PORT" != "0" ] && ! [[ $INPUT_PORT =~ ^[0-9]+$ ]] || [ "$INPUT_PORT" -lt 0 ] || [ "$INPUT_PORT" -gt 65535 ]; then
    echo "无效的端口号，使用默认端口 56789"
else
    [ "$INPUT_PORT" != "0" ] && PORT="$INPUT_PORT"
fi
read -p "是否启用 Epusdt（USDT 支付中间件）？(y/n，默认 n): " ENABLE_EPUSTD
ENABLE_EPUSTD=${ENABLE_EPUSTD:-n}

# 检查域名解析
if ! ping -c 1 $DOMAIN &> /dev/null; then
    echo "警告：域名 $DOMAIN 未解析到当前服务器，请确保 DNS 设置正确！"
    read -p "是否继续？(y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

# 检查端口占用
if [ "$PORT" = "80" ]; then
    if netstat -tulnp | grep -q ":80 "; then
        echo "错误：80 端口已被占用！"
        netstat -tulnp | grep ":80 "
        echo "请释放 80 端口或选择其他端口。"
        exit 1
    fi
else
    if netstat -tulnp | grep -q ":$PORT "; then
        echo "错误：端口 $PORT 已被占用！"
        netstat -tulnp | grep ":$PORT "
        echo "请释放 $PORT 端口或选择其他端口。"
        exit 1
    fi
fi

# 检查并安装依赖工具
if ! command -v curl &> /dev/null || ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
    echo "正在安装 curl、Docker 和 Docker Compose..."
    if [[ -f /etc/redhat-release ]]; then
        yum install -y epel-release curl || { echo "安装 curl 失败！"; exit 1; }
        curl -fsSL https://get.docker.com | sh || { echo "安装 Docker 失败！"; exit 1; }
        systemctl start docker
        systemctl enable docker
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "安装 Docker Compose 失败！"; exit 1; }
        chmod +x /usr/local/bin/docker-compose
    elif [[ -f /etc/lsb-release || -f /etc/debian_version ]]; then
        apt update -y && apt install -y curl || { echo "安装 curl 失败！"; exit 1; }
        curl -fsSL https://get.docker.com | sh || { echo "安装 Docker 失败！"; exit 1; }
        systemctl start docker
        systemctl enable docker
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "安装 Docker Compose 失败！"; exit 1; }
        chmod +x /usr/local/bin/docker-compose
    else
        echo "不支持的操作系统！"
        exit 1
    fi
fi

# 创建安装目录
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR
mkdir -p storage uploads data redis certbot/www letsencrypt
chmod -R 777 storage uploads

# 创建 env.conf
echo "正在创建 env.conf 文件..."
cat > env.conf <<EOF
APP_NAME=$APP_NAME
APP_ENV=local
APP_KEY=$APP_KEY
APP_DEBUG=false
APP_URL=https://${DOMAIN}

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS

REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

DUJIAO_ADMIN_LANGUAGE=zh_CN
ADMIN_ROUTE_PREFIX=/admin
EOF
chmod 777 env.conf

# 创建 usdt.conf（如果启用 Epusdt）
if [ "$ENABLE_EPUSTD" = "y" ]; then
    echo "正在创建 usdt.conf 文件..."
    cat > usdt.conf <<EOF
APP_ENV=production
APP_DEBUG=false
APP_URL=https://${DOMAIN}:51293
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS
REDIS_HOST=redis
REDIS_PORT=6379
TRON_API_KEY=your_tron_api_key
EOF
    chmod 777 usdt.conf
fi

# 创建 Nginx 配置文件
echo "正在创建 Nginx 配置文件..."
cat > nginx.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/certbot;
    location /.well-known/acme-challenge/ {
        allow all;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://faka:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header REMOTE-HOST \$remote_addr;
        add_header X-Cache \$upstream_cache_status;
        proxy_set_header Accept-Encoding "";
        sub_filter "http://" "https://";
        sub_filter_once off;
    }
}
EOF

# 创建 Docker Compose 配置文件
echo "正在创建 docker-compose.yaml 文件..."
cat > docker-compose.yaml <<EOF
version: "3"
services:
  faka:
    image: ghcr.io/apocalypsor/dujiaoka:latest
    container_name: faka
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./Uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    ports:
      - $PORT:80
      - 443:443
    restart: always
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka_network

  db:
    image: mariadb:focal
    container_name: faka-data
    environment:
      - MYSQL_ROOT_PASSWORD=$DB_PASS
      - MYSQL_DATABASE=$DB_NAME
      - MYSQL_USER=$DB_USER
      - MYSQL_PASSWORD=$DB_PASS
    volumes:
      - ./data:/var/lib/mysql
    restart: always
    networks:
      - dujiaoka_network

  redis:
    image: redis:alpine
    container_name: faka-redis
    volumes:
      - ./redis:/data
    restart: always
    networks:
      - dujiaoka_network

  certbot:
    image: certbot/certbot:latest
    container_name: faka-certbot
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \${!}; done;'"
    networks:
      - dujiaoka_network
EOF

# 添加 Epusdt 服务（如果启用）
if [ "$ENABLE_EPUSTD" = "y" ]; then
    echo "正在添加 Epusdt 服务到 docker-compose.yaml..."
    cat >> docker-compose.yaml <<EOF

  usdt:
    image: ghcr.io/apocalypsor/dujiaoka:usdt
    container_name: faka-usdt
    volumes:
      - ./usdt.conf:/usdt/.env
    ports:
      - 51293:8000
    restart: always
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka_network
EOF
fi

# 调试：打印生成的 docker-compose.yaml
echo "调试：生成的 docker-compose.yaml 内容如下："
cat docker-compose.yaml

# 验证 Docker Compose 配置
docker-compose config || { echo "Docker Compose 配置文件格式错误！请检查 $INSTALL_DIR/docker-compose.yaml"; exit 1; }

# 获取 Let's Encrypt 证书
echo "正在获取 Let's Encrypt 证书..."
docker-compose up -d faka || { echo "Faka 服务启动失败！"; exit 1; }
docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot --email $EMAIL --agree-tos --no-eff-email -d $DOMAIN || { echo "Let's Encrypt 证书获取失败！请检查域名解析或网络！"; exit 1; }

# 修改配置以禁用安装模式
sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yaml
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf

# 启动所有 Docker 容器
echo "正在启动 Docker 容器..."
docker-compose up -d || { echo "Docker Compose 启动失败！"; exit 1; }

# 输出完成信息
echo "独角数卡安装完成！"
echo "请访问 https://${DOMAIN} 进行网页端安装配置。"
echo "网页安装时，数据库 host 填 'db'，端口保持默认 3306。"
echo "安装完成后，访问后台：https://${DOMAIN}/admin"
echo "默认账户：admin"
echo "默认密码：admin"
echo "数据库信息："
echo "  数据库名：$DB_NAME"
echo "  用户名：$DB_USER"
echo "  密码：$DB_PASS"
echo "Let's Encrypt 邮箱：$EMAIL"
if [ "$ENABLE_EPUSTD" = "y" ]; then
    echo "Epusdt 服务已启用，请配置 usdt.conf 中的 TRON_API_KEY，并访问 https://${DOMAIN}:51293"
fi
echo "日志文件：/var/log/dujiaoka_install.log"
echo "请妥善保存以上信息，并立即修改默认账户密码！"
```
