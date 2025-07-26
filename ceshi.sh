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
INSTALL_DIR="/root/data/docker_data/shop"
DOMAIN=""
EMAIL=""
DB_NAME="dujiaoka"
DB_USER="dujiaoka"
DB_PASS=$(openssl rand -base64 12)
PORT="8090"

# 提示用户输入域名、邮箱和端口
read -p "请输入你的域名（例如：shop.example.com）: " DOMAIN
if ! [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "无效的域名格式！"
    exit 1
fi
read -p "请输入你的邮箱（用于 Let's Encrypt 证书通知）: " EMAIL
if [ -z "$EMAIL" ]; then
    echo "邮箱不能为空！"
    exit 1
fi
read -p "请输入外部端口（默认 8090，输入 0 使用 80 端口）: " INPUT_PORT
if [ "$INPUT_PORT" != "0" ] && ! [[ $INPUT_PORT =~ ^[0-9]+$ ]] || [ "$INPUT_PORT" -lt 0 ] || [ "$INPUT_PORT" -gt 65535 ]; then
    echo "无效的端口号，使用默认端口 8090"
else
    [ "$INPUT_PORT" != "0" ] && PORT="$INPUT_PORT"
fi

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
mkdir -p storage uploads mysql redis certbot/www letsencrypt
chmod -R 777 storage uploads

# 创建 env.conf
echo "正在创建 env.conf 文件..."
cat > env.conf <<EOF
APP_NAME=咕咕的小卖部
APP_ENV=local
APP_KEY=base64:rKwRuI6eRpCw/9e2XZKKGj/Yx3iZy5e7+FQ6+aQl8Zg=
APP_DEBUG=true
APP_URL=https://${DOMAIN}

LOG_CHANNEL=stack

# 数据库配置
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

# redis配置
REDIS_HOST=redis
REDIS_PASSWORD=
REDIS_PORT=6379

BROADCAST_DRIVER=log
SESSION_DRIVER=file
SESSION_LIFETIME=120

# 缓存配置
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis

# 后台语言
DUJIAO_ADMIN_LANGUAGE=zh_CN

# 后台登录地址
ADMIN_ROUTE_PREFIX=/admin

# 是否开启https
ADMIN_HTTPS=true
EOF
chmod 777 env.conf

# 创建 Nginx 配置文件
echo "正在创建 Nginx 配置文件..."
cat > nginx.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
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
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    root /dujiaoka/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass web:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

# 创建 Docker Compose 配置文件
echo "正在创建 Docker Compose 配置文件..."
cat > docker-compose.yml <<EOF
version: "3"
services:
  web:
    image: stilleshan/dujiaoka
    container_name: dujiaoka_web
    environment:
      - INSTALL=true
    volumes:
      - ./env.conf:/dujiaoka/.env
      - ./uploads:/dujiaoka/public/uploads
      - ./storage:/dujiaoka/storage
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    ports:
      - ${PORT}:80
      - 443:443
    restart: always
    depends_on:
      - db
      - redis
    networks:
      - dujiaoka_network

  db:
    image: mariadb:focal
    container_name: dujiaoka_db
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_PASS}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASS}
    volumes:
      - ./mysql:/var/lib/mysql
    restart: always
    networks:
      - dujiaoka_network

  redis:
    image: redis:alpine
    container_name: dujiaoka_redis
    volumes:
      - ./redis:/data
    restart: always
    networks:
      - dujiaoka_network

  certbot:
    image: certbot/certbot:latest
    container_name: dujiaoka_certbot
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \${!}; done;'"
    networks:
      - dujiaoka_network

networks:
  dujiaoka_network:
    driver: bridge
EOF

# 调试：打印生成的 docker-compose.yml
echo "调试：生成的 docker-compose.yml 内容如下："
cat docker-compose.yml

# 验证 Docker Compose 配置
docker-compose config || { echo "Docker Compose 配置文件格式错误！请检查 $INSTALL_DIR/docker-compose.yml"; exit 1; }

# 获取 Let's Encrypt 证书
echo "正在获取 Let's Encrypt 证书..."
docker-compose up -d web || { echo "Web 服务启动失败！"; exit 1; }
docker-compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot --email $EMAIL --agree-tos --no-eff-email -d $DOMAIN || { echo "Let's Encrypt 证书获取失败！请检查域名解析或网络！"; exit 1; }

# 修改配置以禁用安装模式
sed -i 's/INSTALL=true/INSTALL=false/' docker-compose.yml
sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' env.conf
sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' env.conf

# 启动所有 Docker 容器
echo "正在启动 Docker 容器..."
docker-compose up -d || { echo "Docker Compose 启动失败！"; exit 1; }

# 输出完成信息
echo "独角数卡安装完成！"
echo "请访问 https://${DOMAIN} 进行初始化配置。"
echo "后台地址：https://${DOMAIN}/admin"
echo "默认账户：admin"
echo "默认密码：admin"
echo "数据库信息："
echo "  数据库名：${DB_NAME}"
echo "  用户名：${DB_USER}"
echo "  密码：${DB_PASS}"
echo "Let's Encrypt 邮箱：${EMAIL}"
echo "日志文件：/var/log/dujiaoka_install.log"
echo "请妥善保存以上信息，并立即修改默认账户密码！"
```
