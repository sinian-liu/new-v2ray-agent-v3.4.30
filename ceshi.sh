#!/bin/bash

# 提示用户输入域名
read -p "请输入域名（例如 sparkedhost.565645.xyz）: " DOMAIN
echo "你输入的域名是: $DOMAIN"

# 提示用户输入店铺名字
read -p "请输入店铺名字: " SHOP_NAME
echo "店铺名字是: $SHOP_NAME"

# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 下载并安装 docker-compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 生成随机数据库密码
DB_PASSWORD=$(openssl rand -hex 16)
echo "生成的数据库密码: $DB_PASSWORD"

# 执行 Dujiaoka 安装脚本，自动选择不开启 HTTPS
bash <(curl -L -s https://raw.githubusercontent.com/woniu336/open_shell/main/dujiao.sh) <<EOF
$DOMAIN
n
$SHOP_NAME
EOF

# 显示网站配置信息
echo -e "\n=== 网站配置信息 ==="
echo "数据库地址: db"
echo "MySQL 端口: 3306"
echo "MySQL 数据库名: dujiaoka"
echo "MySQL 用户名: dujiaoka"
echo "MySQL 密码: $DB_PASSWORD"
echo "Redis 连接地址: redis"
echo "Redis 密码: 默认不填写"
echo "Redis 端口: 6379"
echo "网站名称: $SHOP_NAME"
echo "网站 URL: https://$DOMAIN"
echo "后台登录路径: /admin"
echo "首次访问地址: https://$DOMAIN:3080"

# 修改 /root/dujiao/env.conf 文件
if [ -f /root/dujiao/env.conf ]; then
    sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/' /root/dujiao/env.conf
    sed -i "s|APP_URL=http://$DOMAIN|APP_URL=https://$DOMAIN|" /root/dujiao/env.conf
    sed -i 's/APP_DEBUG=true/APP_DEBUG=false/' /root/dujiao/env.conf
    echo "已修改 /root/dujiao/env.conf 文件"
else
    echo "错误: /root/dujiao/env.conf 文件不存在"
    exit 1
fi

# 重启 Docker 服务
systemctl restart docker
echo "已重启 Docker 服务"

# 设置 Docker 开机自启
systemctl enable docker
echo "已设置 Docker 开机自启"

echo -e "\n安装和配置完成！"
echo "请访问 https://$DOMAIN:3080 进行首次配置"
