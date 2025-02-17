#!/bin/bash

# 设置颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 显示菜单函数
show_menu() {
    clear
    echo -e "${GREEN}=============================================${RESET}"
    echo -e "${GREEN}服务器推荐：https://my.frantech.ca/aff.php?aff=4337${RESET}"
    echo -e "${GREEN}VPS评测官方网站：https://www.1373737.xyz/${RESET}"
    echo -e "${GREEN}YouTube频道：https://www.youtube.com/@cyndiboy7881${RESET}"
    echo -e "${GREEN}=============================================${RESET}"
    echo "请选择要执行的操作："

    # 获取终端宽度
    term_width=$(tput cols)
    menu_items=(
        "0. 脚本更新" "1. VPS一键测试" 
        "2. 安装BBR" "3. 安装v2ray" 
        "4. 安装无人直播云SRS" "5. 安装宝塔纯净版" 
        "6. 系统更新" "7. 修改密码" 
        "8. 重启服务器" "9. 一键永久禁用IPv6" 
        "10.一键解除禁用IPv6" "11.服务器时区修改为中国时区" 
        "12.保持SSH会话一直连接不断开" "13.安装Windows或Linux系统" 
        "14.服务器对服务器文件传输" "15.安装探针并绑定域名" 
        "16.共用端口（反代）" "17.安装 curl 和 wget" 
        "18.安装 Docker"
    )

    max_index=${#menu_items[@]}
    for ((i = 0; i < max_index; i+=2)); do
        printf "%-${term_width/2}s" "${menu_items[i]}"
        if (( i+1 < max_index )); then
            printf "%s\n" "${menu_items[i+1]}"
        else
            printf "\n"
        fi
    done
    echo -e "${GREEN}=============================================${RESET}"
}

# 返回主菜单函数
return_to_menu() {
    read -p "按回车键返回主菜单..."
    show_menu
}

# 执行选项对应的命令
execute_option() {
    case $option in
        0)
            # 脚本更新
            echo -e "${GREEN}正在更新脚本...${RESET}"
            wget -O /tmp/onekey.sh https://raw.githubusercontent.com/sinian-liu/onekey/main/onekey.sh
            if [ $? -eq 0 ]; then
                mv /tmp/onekey.sh /usr/local/bin/onekey.sh
                chmod +x /usr/local/bin/onekey.sh
                echo -e "${GREEN}脚本更新成功！${RESET}"
                echo -e "${YELLOW}请重新运行脚本以应用更新。${RESET}"
            else
                echo -e "${RED}脚本更新失败，请检查网络连接！${RESET}"
            fi
            return_to_menu
            ;;
        1)
            # VPS 一键测试脚本
            echo -e "${GREEN}正在进行 VPS 测试 ...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/system_info.sh)
            return_to_menu
            ;;
        2)
            # BBR 安装脚本
            echo -e "${GREEN}正在安装 BBR ...${RESET}"
            wget -O tcpx.sh "https://github.com/sinian-liu/Linux-NetSpeed-BBR/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
            return_to_menu
            ;;
        3)
            # 安装 v2ray 脚本
            echo -e "${GREEN}正在安装 v2ray ...${RESET}"
            wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
            return_to_menu
            ;;
        4)
            # 无人直播云 SRS 安装
            echo -e "${GREEN}正在安装无人直播云 SRS ...${RESET}"
            # 提示用户输入管理端口号
            read -p "请输入要使用的管理端口号 (默认为2022): " mgmt_port
            mgmt_port=${mgmt_port:-2022}  # 如果没有输入，则使用默认端口2022

            # 检测端口是否被占用
            check_port() {
                local port=$1
                if netstat -tuln | grep ":$port" > /dev/null; then
                    return 1
                else
                    return 0
                fi
            }

            # 检查管理端口是否被占用
            check_port $mgmt_port
            if [ $? -eq 1 ]; then
                echo -e "${RED}端口 $mgmt_port 已被占用！${RESET}"
                read -p "请输入其他端口号作为管理端口: " mgmt_port
            fi

            # 安装 Docker
            sudo apt-get update
            sudo apt-get install -y docker.io

            # 启动 SRS 容器
            docker run --restart always -d --name srs-stack -it -p $mgmt_port:2022 -p 1935:1935/tcp -p 1985:1985/tcp \
              -p 8080:8080/tcp -p 8000:8000/udp -p 10080:10080/udp \
              -v $HOME/db:/data ossrs/srs-stack:5

            # 获取服务器 IPv4 地址
            server_ip=$(curl -s4 ifconfig.me)

            # 输出访问地址
            echo -e "${GREEN}SRS 安装完成！您可以通过以下地址访问管理界面:${RESET}"
            echo -e "${YELLOW}http://$server_ip:$mgmt_port/mgmt${RESET}"
            return_to_menu
            ;;

        5)
            # 宝塔纯净版安装
            echo -e "${GREEN}正在安装宝塔面板...${RESET}"
            if [ -f /etc/lsb-release ]; then
                # Ubuntu 或 Debian 系统
                wget -O install.sh https://install.baota.sbs/install/install_6.0.sh && bash install.sh
            elif [ -f /etc/redhat-release ]; then
                # CentOS 系统
                yum install -y wget && wget -O install.sh https://install.baota.sbs/install/install_6.0.sh && sh install.sh
            else
                echo -e "${RED}无法识别您的操作系统，无法安装宝塔面板。${RESET}"
            fi
            return_to_menu
            ;;

        6)
            # 系统更新命令
            update_system() {
                if [ -f /etc/lsb-release ]; then
                    # Ubuntu 或 Debian 系统
                    echo -e "${GREEN}正在更新 Debian/Ubuntu 系统...${RESET}"
                    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean
                elif [ -f /etc/redhat-release ]; then
                    # CentOS 系统
                    echo -e "${GREEN}正在更新 CentOS 系统...${RESET}"
                    sudo yum update -y && sudo yum clean all
                elif [ -f /etc/fedora-release ]; then
                    # Fedora 系统
                    echo -e "${GREEN}正在更新 Fedora 系统...${RESET}"
                    sudo dnf update -y && sudo dnf clean all
                else
                    echo -e "${RED}无法识别您的操作系统，跳过更新步骤。${RESET}"
                fi
            }
            update_system
            return_to_menu
            ;;

        7)
            # 修改当前用户密码
            username=$(whoami)
            echo -e "${GREEN}正在为 ${YELLOW}$username${GREEN} 修改密码...${RESET}"
            sudo passwd "$username"
            return_to_menu
            ;;

        8)
            # 重启服务器
            echo -e "${GREEN}正在重启服务器 ...${RESET}"
            sudo reboot
            ;;
            
        9)
            # 永久禁用 IPv6
            echo -e "${GREEN}正在禁用 IPv6 ...${RESET}"
            # 检测系统类型（Ubuntu/Debian 或 CentOS/RHEL）
            if [ -f /etc/lsb-release ]; then
                # Ubuntu 或 Debian 系统
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
                echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p
            elif [ -f /etc/redhat-release ]; then
                # CentOS 或 RHEL 系统
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
                echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p
            else
                echo -e "${RED}无法识别您的操作系统，无法禁用 IPv6。${RESET}"
            fi
            return_to_menu
            ;;

        10)
            # 解除禁用 IPv6
            echo -e "${GREEN}正在解除禁用 IPv6 ...${RESET}"
            # 检测系统类型（Ubuntu/Debian 或 CentOS/RHEL）
            if [ -f /etc/lsb-release ]; then
                # Ubuntu 或 Debian 系统
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
                sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                sudo sysctl -p
            elif [ -f /etc/redhat-release ]; then
                # CentOS 或 RHEL 系统
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
                sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                sudo sysctl -p
            else
                echo -e "${RED}无法识别您的操作系统，无法解除禁用 IPv6。${RESET}"
            fi
            return_to_menu
            ;;

        11)
            # 服务器时区修改为中国时区
            echo -e "${GREEN}正在修改服务器时区为中国时区 ...${RESET}"
            sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
            sudo service cron restart
            return_to_menu
            ;;

        12)
            # 长时间保持 SSH 会话连接不断开
            echo -e "${GREEN}正在配置 SSH 保持连接...${RESET}"
            read -p "请输入每次心跳请求的间隔时间（单位：分钟，默认为5分钟）： " interval
            interval=${interval:-5}  # 默认值为5分钟
            read -p "请输入客户端最大无响应次数（默认为50次）： " max_count
            max_count=${max_count:-50}  # 默认值为50次
            interval_seconds=$((interval * 60))

            # 修改 /etc/ssh/sshd_config 配置文件
            echo "正在更新 SSH 配置文件..."
            sudo sed -i "/^ClientAliveInterval/c\ClientAliveInterval $interval_seconds" /etc/ssh/sshd_config
            sudo sed -i "/^ClientAliveCountMax/c\ClientAliveCountMax $max_count" /etc/ssh/sshd_config

            # 重启 SSH 服务
            echo "正在重启 SSH 服务以应用配置..."
            sudo systemctl restart sshd

            echo -e "${GREEN}配置完成！心跳请求间隔为 $interval 分钟，最大无响应次数为 $max_count。${RESET}"
            return_to_menu
            ;;

        13)
            # KVM安装系统,检测操作系统类型
            check_system() {
                if grep -qi "debian" /etc/os-release || grep -qi "ubuntu" /etc/os-release; then
                    SYSTEM="debian"
                elif grep -qi "centos" /etc/os-release || grep -qi "red hat" /etc/os-release; then
                    SYSTEM="centos"
                else
                    SYSTEM="unknown"
                fi
            }

            echo -e "${GREEN}开始安装 KVM 系统...${RESET}"
            check_system

            if [[ $SYSTEM == "debian" ]]; then
                echo -e "${YELLOW}检测到系统为 Debian/Ubuntu，开始安装必要依赖...${RESET}"
                apt-get install -y xz-utils openssl gawk file wget screen
                if [[ $? -eq 0 ]]; then
                    echo -e "${YELLOW}必要依赖安装完成，开始更新系统软件包...${RESET}"
                    apt update -y && apt dist-upgrade -y
                    if [[ $? -ne 0 ]]; then
                        echo -e "${RED}系统更新失败，请检查网络或镜像源！${RESET}"
                        exit 1
                    fi
                else
                    echo -e "${RED}必要依赖安装失败，请检查网络或镜像源！${RESET}"
                    exit 1
                fi

            elif [[ $SYSTEM == "centos" ]]; then
                echo -e "${YELLOW}检测到系统为 RedHat/CentOS，开始安装必要依赖...${RESET}"
                yum install -y xz openssl gawk file glibc-common wget screen
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}依赖安装失败，请检查网络或镜像源！${RESET}"
                    exit 1
                fi
            else
                echo -e "${RED}不支持的操作系统！${RESET}"
                exit 1
            fi

            echo -e "${YELLOW}开始下载并运行安装脚本...${RESET}"
            wget --no-check-certificate -O NewReinstall.sh https://git.io/newbetags
            if [[ $? -eq 0 ]]; then
                chmod a+x NewReinstall.sh
                bash NewReinstall.sh
                echo -e "${GREEN}安装完成！${RESET}"
            else
                echo -e "${RED}脚本下载失败，请检查网络或镜像源！${RESET}"
                exit 1
            fi
            return_to_menu
            ;;

        14)
            # 服务器对服务器传文件
            echo -e "${GREEN}服务器对服务器传文件${RESET}"

            # 检查是否安装了 sshpass
            if ! command -v sshpass &> /dev/null; then
                echo -e "${YELLOW}检测到 sshpass 缺失，正在安装...${RESET}"
                sudo apt update && sudo apt install -y sshpass
                if ! command -v sshpass &> /dev/null; then
                    echo -e "${RED}安装 sshpass 失败，请手动安装！${RESET}"
                    exit 1
                fi
            fi

            # 输入目标服务器 IP 地址
            read -p "请输入目标服务器IP地址（例如：185.106.96.93）： " target_ip

            # 输入目标服务器 SSH 端口（默认为 22）
            read -p "请输入目标服务器SSH端口（默认为22）： " ssh_port
            ssh_port=${ssh_port:-22}  # 如果未输入，则使用默认端口 22

            # 输入目标服务器密码
            read -s -p "请输入目标服务器密码：" ssh_password
            echo  # 换行

            # 验证目标服务器的 SSH 连接
            echo -e "${YELLOW}正在验证目标服务器的 SSH 连接...${RESET}"
            sshpass -p "$ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$ssh_port" root@"$target_ip" "echo 'SSH 连接成功！'" &> /dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}SSH 连接验证成功！${RESET}"

                # 输入源文件路径和目标文件路径
                read -p "请输入源文件路径（例如：/root/data/vlive/test.mp4）： " source_file
                read -p "请输入目标文件路径（例如：/root/data/vlive/）： " target_path

                # 执行 scp 命令
                echo -e "${YELLOW}正在传输文件，请稍候...${RESET}"
                sshpass -p "$ssh_password" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P "$ssh_port" "$source_file" root@"$target_ip":"$target_path"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}文件传输成功！${RESET}"
                else
                    echo -e "${RED}文件传输失败，请检查路径和网络连接。${RESET}"
                fi
            else
                echo -e "${RED}SSH 连接失败，请检查以下内容：${RESET}"
                echo -e "${YELLOW}1. 目标服务器 IP 地址是否正确。${RESET}"
                echo -e "${YELLOW}2. 目标服务器的 SSH 服务是否已开启。${RESET}"
                echo -e "${YELLOW}3. 目标服务器的 root 用户密码是否正确。${RESET}"
                echo -e "${YELLOW}4. 目标服务器的防火墙是否允许 SSH 连接。${RESET}"
                echo -e "${YELLOW}5. 目标服务器的 SSH 端口是否为 $ssh_port。${RESET}"
            fi
            return_to_menu
            ;;

        15)
            # 安装 NekoNekoStatus 服务器探针并绑定域名
            echo -e "${GREEN}正在安装 NekoNekoStatus 服务器探针并绑定域名...${RESET}"

            # 检查 Docker 是否已安装
            if ! command -v docker &> /dev/null; then
                echo -e "${YELLOW}检测到 Docker 未安装，正在安装 Docker...${RESET}"
                curl -fsSL https://get.docker.com | bash -s docker
                if ! command -v docker &> /dev/null; then
                    echo -e "${RED}Docker 安装失败，请手动安装 Docker！${RESET}"
                    exit 1
                fi
            fi

            # 询问容器端口
            read -p "请输入 NekoNekoStatus 容器端口（默认为 5555）： " container_port
            container_port=${container_port:-5555}  # 如果未输入，则使用默认端口 5555

            # 询问反向代理端口
            read -p "请输入反向代理端口（默认为 80）： " proxy_port
            proxy_port=${proxy_port:-80}  # 如果未输入，则使用默认端口 80

            # 检测端口是否开放
            check_port() {
                local port=$1
                if netstat -tuln | grep ":$port" > /dev/null; then
                    return 1  # 端口已被占用
                else
                    return 0  # 端口未占用
                fi
            }

            # 检测容器端口
            check_port $container_port
            if [ $? -eq 1 ]; then
                echo -e "${RED}端口 $container_port 已被占用，请选择其他端口！${RESET}"
                exit 1
            fi

            # 检测反向代理端口
            check_port $proxy_port
            if [ $? -eq 1 ]; then
                echo -e "${RED}端口 $proxy_port 已被占用，请选择其他端口！${RESET}"
                exit 1
            fi

            # 开放端口
            open_port() {
                local port=$1
                if command -v ufw &> /dev/null; then
                    sudo ufw allow $port
                elif command -v firewall-cmd &> /dev/null; then
                    sudo firewall-cmd --zone=public --add-port=$port/tcp --permanent
                    sudo firewall-cmd --reload
                else
                    echo -e "${YELLOW}未检测到 ufw 或 firewalld，请手动开放端口 $port。${RESET}"
                fi
            }

            # 开放容器端口
            echo -e "${YELLOW}正在开放容器端口 $container_port...${RESET}"
            open_port $container_port

            # 开放反向代理端口
            echo -e "${YELLOW}正在开放反向代理端口 $proxy_port...${RESET}"
            open_port $proxy_port

            # 拉取并运行 NekoNekoStatus Docker 容器
            echo -e "${YELLOW}正在拉取 NekoNekoStatus Docker 镜像...${RESET}"
            docker pull nkeonkeo/nekonekostatus:latest

            echo -e "${YELLOW}正在启动 NekoNekoStatus 容器...${RESET}"
            docker run --restart=on-failure --name nekonekostatus -p $container_port:5555 -d nkeonkeo/nekonekostatus:latest

            # 提示用户输入域名和邮箱
            read -p "请输入您的域名（例如：www.example.com）： " domain
            read -p "请输入您的邮箱（用于 Let's Encrypt 证书）： " email

            # 安装 Nginx 和 Certbot
            if ! command -v nginx &> /dev/null; then
                echo -e "${YELLOW}正在安装 Nginx...${RESET}"
                sudo apt update -y
                sudo apt install -y nginx
            fi

            if ! command -v certbot &> /dev/null; then
                echo -e "${YELLOW}正在安装 Certbot...${RESET}"
                sudo apt install -y certbot python3-certbot-nginx
            fi

            # 配置 Nginx
            echo -e "${YELLOW}正在配置 Nginx...${RESET}"
            cat > /etc/nginx/sites-available/$domain <<EOL
server {
    listen $proxy_port;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:$container_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

            # 启用站点配置
            sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
            sudo nginx -t && sudo systemctl reload nginx

            # 申请 Let's Encrypt 证书
            echo -e "${YELLOW}正在申请 Let's Encrypt 证书...${RESET}"
            sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive

            # 配置自动续期
            echo -e "${YELLOW}正在配置证书自动续期...${RESET}"
            (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

            echo -e "${GREEN}NekoNekoStatus 安装和域名绑定完成！${RESET}"
            echo -e "${YELLOW}您现在可以通过 https://$domain 访问探针服务了。${RESET}"
            echo -e "${YELLOW}容器端口: $container_port${RESET}"
            echo -e "${YELLOW}反向代理端口: $proxy_port${RESET}"
            echo -e "${YELLOW}默认密码: nekonekostatus${RESET}"
            echo -e "${YELLOW}安装后务必修改密码！${RESET}"
            return_to_menu
            ;;

        16)
            # 共用端口（反代）
            # 交互式Nginx多域名部署脚本
            # 支持多域名配置，自动申请Let's Encrypt证书，并将配置写入alone.conf

            # 检查root权限
            if [ "$EUID" -ne 0 ]; then
                echo "❌ 请使用sudo或root用户运行此脚本"
                exit 1
            fi

            # 安装依赖
            install_dependencies() {
                echo "➜ 检查并安装依赖..."
                apt-get update > /dev/null 2>&1
                if ! command -v nginx &> /dev/null; then
                    apt-get install -y nginx > /dev/null 2>&1
                fi
                if ! command -v certbot &> /dev/null; then
                    apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
                fi
                echo "✅ 依赖已安装"
            }

            # 申请Let's Encrypt证书
            request_certificate() {
                local domain=$1
                echo "➜ 为域名 $domain 申请SSL证书..."
                if certbot --nginx --non-interactive --agree-tos -m $ADMIN_EMAIL -d $domain > /dev/null 2>&1; then
                    echo "✅ 证书申请成功"
                else
                    echo "❌ 证书申请失败，请检查："
                    echo "1. 域名DNS解析是否指向本服务器"
                    echo "2. 防火墙是否开放80/443端口"
                    echo "3. 是否已有重复证书"
                    exit 1
                fi
            }

            # 配置Nginx反向代理
            configure_nginx() {
                local domain=$1
                local port=$2
                local conf_file="/etc/nginx/conf.d/alone.conf"

                echo "➜ 为域名 $domain 配置Nginx反向代理..."
                cat >> $conf_file <<EOF

# HTTP重定向到HTTPS
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

# HTTPS服务
server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    add_header Strict-Transport-Security "max-age=63072000" always;
}
EOF
                echo "✅ Nginx配置完成"
            }

            # 检查证书到期时间
            check_cert_expiry() {
                local domain=$1
                if [ -f /etc/letsencrypt/live/$domain/cert.pem ]; then
                    local expiry_date=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$domain/cert.pem | cut -d= -f2)
                    local expiry_seconds=$(date -d "$expiry_date" +%s)
                    local current_seconds=$(date +%s)
                    local days_left=$(( (expiry_seconds - current_seconds) / 86400 ))

                    echo "➜ 域名 $domain 的SSL证书将在 $days_left 天后到期"
                    if [ $days_left -lt 30 ]; then
                        echo "⚠️  证书即将到期，建议尽快续签"
                    fi
                else
                    echo "❌ 未找到域名 $domain 的证书文件"
                fi
            }

            # 主函数
            main() {
                echo "🛠️  Nginx多域名部署脚本"
                echo "------------------------"

                # 检查现有域名和端口
                echo "🔍 检查当前已配置的域名和端口："
                if [ -f /etc/nginx/conf.d/alone.conf ]; then
                    grep -oP 'server_name \K[^;]+' /etc/nginx/conf.d/alone.conf | sort | uniq | while read -r domain; do
                        echo "  域名: $domain"
                    done
                else
                    echo "⚠️  未找到 /etc/nginx/conf.d/alone.conf 文件，将创建新配置"
                fi

                # 输入管理员邮箱
                read -p "请输入管理员邮箱（用于证书通知）: " ADMIN_EMAIL

                # 输入域名和端口
                declare -A domains
                while true; do
                    read -p "请输入域名（留空结束）: " domain
                    if [ -z "$domain" ]; then
                        break
                    fi
                    read -p "请输入 $domain 对应的端口号: " port
                    domains[$domain]=$port
                done

                if [ ${#domains[@]} -eq 0 ]; then
                    echo "❌ 未输入任何域名，退出脚本"
                    exit 1
                fi

                # 安装依赖
                install_dependencies

                # 配置每个域名
                for domain in "${!domains[@]}"; do
                    port=${domains[$domain]}
                    configure_nginx $domain $port
                    request_certificate $domain
                    check_cert_expiry $domain
                done

                # 配置防火墙
                echo "➜ 配置防火墙..."
                if command -v ufw &> /dev/null; then
                    ufw allow 80/tcp > /dev/null
                    ufw allow 443/tcp > /dev/null
                    echo "✅ UFW已放行80/443端口"
                elif command -v firewall-cmd &> /dev/null; then
                    firewall-cmd --permanent --add-service=http > /dev/null
                    firewall-cmd --permanent --add-service=https > /dev/null
                    firewall-cmd --reload > /dev/null
                    echo "✅ Firewalld已放行80/443端口"
                else
                    echo "⚠️  未检测到防火墙工具，请手动放行端口"
                fi

                # 添加证书自动续签任务
                (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
                echo "✅ 已添加证书自动续签任务"

                # 显示最终状态
                echo -e "\n🔌 当前服务状态："
                echo "Nginx状态: $(systemctl is-active nginx)"
                echo "监听端口:"
                ss -tuln | grep -E ':80|:443'

                echo -e "\n🎉 部署完成！"
            }

            # 执行主函数
            main
            return_to_menu
            ;;

        17)
            # 安装 curl 和 wget
            echo -e "${GREEN}正在安装 curl 和 wget ...${RESET}"
            
            # 安装 curl
            if ! command -v curl &> /dev/null; then
                echo -e "${YELLOW}检测到 curl 缺失，正在安装...${RESET}"
                if [ -f /etc/lsb-release ]; then
                    # Ubuntu 或 Debian 系统
                    sudo apt update && sudo apt install -y curl
                elif [ -f /etc/redhat-release ]; then
                    # CentOS 系统
                    sudo yum install -y curl
                elif [ -f /etc/fedora-release ]; then
                    # Fedora 系统
                    sudo dnf install -y curl
                else
                    echo -e "${RED}无法识别系统，无法安装 curl。${RESET}"
                fi
                
                # 检查是否安装成功
                if command -v curl &> /dev/null; then
                    echo -e "${GREEN}curl 安装成功！${RESET}"
                else
                    echo -e "${RED}curl 安装失败，请手动检查问题！${RESET}"
                fi
            else
                echo -e "${YELLOW}curl 已经安装，跳过安装步骤。${RESET}"
            fi

            # 安装 wget
            if ! command -v wget &> /dev/null; then
                echo -e "${YELLOW}检测到 wget 缺失，正在安装...${RESET}"
                if [ -f /etc/lsb-release ]; then
                    # Ubuntu 或 Debian 系统
                    sudo apt update && sudo apt install -y wget
                elif [ -f /etc/redhat-release ]; then
                    # CentOS 系统
                    sudo yum install -y wget
                elif [ -f /etc/fedora-release ]; then
                    # Fedora 系统
                    sudo dnf install -y wget
                else
                    echo -e "${RED}无法识别系统，无法安装 wget。${RESET}"
                fi
                
                # 检查是否安装成功
                if command -v wget &> /dev/null; then
                    echo -e "${GREEN}wget 安装成功！${RESET}"
                else
                    echo -e "${RED}wget 安装失败，请手动检查问题！${RESET}"
                fi
            else
                echo -e "${YELLOW}wget 已经安装，跳过安装步骤。${RESET}"
            fi
            return_to_menu
            ;;
        18)
            # 安装 Docker
            echo -e "${GREEN}正在安装 Docker ...${RESET}"
            if ! command -v docker &> /dev/null; then
                echo -e "${YELLOW}检测到 Docker 缺失，正在安装...${RESET}"
                if [ -f /etc/lsb-release ]; then
                    # Ubuntu 或 Debian 系统
                    sudo apt-get update
                    sudo apt-get install -y docker.io
                elif [ -f /etc/redhat-release ]; then
                    # CentOS 系统
                    sudo yum install -y docker
                elif [ -f /etc/fedora-release ]; then
                    # Fedora 系统
                    sudo dnf install -y docker
                else
                    echo -e "${RED}无法识别系统，无法安装 Docker。${RESET}"
                fi

                # 检查是否安装成功
                if command -v docker &> /dev/null; then
