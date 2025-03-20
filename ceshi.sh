#!/bin/bash

# 设置颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 日志文件
LOG_FILE="/var/log/onekey.log"

# 系统检测函数
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu) SYSTEM="ubuntu" ;;
            debian) SYSTEM="debian" ;;
            centos|rhel) SYSTEM="centos" ;;
            fedora) SYSTEM="fedora" ;;
            arch) SYSTEM="arch" ;;
            *) SYSTEM="unknown" ;;
        esac
    elif [ -f /etc/lsb-release ]; then
        SYSTEM="ubuntu"
    elif [ -f /etc/redhat-release ]; then
        SYSTEM="centos"
    elif [ -f /etc/fedora-release ]; then
        SYSTEM="fedora"
    else
        SYSTEM="unknown"
    fi
}

# 日志记录函数
log_error() {
    echo -e "${RED}$1${RESET}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}$1${RESET}" | tee -a "$LOG_FILE"
}

# 安装依赖函数
install_pkg() {
    local pkg=$1
    check_system
    case $SYSTEM in
        ubuntu|debian)
            sudo apt update && sudo apt install -y "$pkg" || return 1 ;;
        centos)
            sudo yum install -y "$pkg" || return 1 ;;
        fedora)
            sudo dnf install -y "$pkg" || return 1 ;;
        *)
            log_error "无法识别系统，无法安装 $pkg"
            return 1 ;;
    esac
    return 0
}

# 检查端口是否占用
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port"; then
        return 1
    else
        return 0
    fi
}

# 开放端口
open_port() {
    local port=$1
    if command -v ufw &> /dev/null; then
        sudo ufw allow "$port" && log_info "已通过 ufw 开放端口 $port"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port="$port/tcp" && sudo firewall-cmd --reload && log_info "已通过 firewalld 开放端口 $port"
    else
        log_error "未检测到防火墙工具，请手动开放端口 $port"
    fi
}

# 系统更新函数
update_system() {
    check_system
    case $SYSTEM in
        ubuntu|debian)
            sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean && log_info "系统更新成功" || { log_error "系统更新失败"; return 1; } ;;
        centos)
            sudo yum update -y && sudo yum clean all && log_info "系统更新成功" || { log_error "系统更新失败"; return 1; } ;;
        fedora)
            sudo dnf update -y && sudo dnf clean all && log_info "系统更新成功" || { log_error "系统更新失败"; return 1; } ;;
        *)
            log_error "无法识别系统，跳过更新"; return 1 ;;
    esac
    return 0
}

# 设置快捷命令
if ! grep -q "alias s=" ~/.bashrc; then
    echo "alias s='bash <(curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/onekey.sh)'" >> ~/.bashrc
    source ~/.bashrc
    log_info "快捷命令 s 已设置"
fi

# 主菜单函数
show_menu() {
    while true; do
        echo -e "${GREEN}=============================================${RESET}"
        echo -e "${GREEN}服务器推荐：https://my.frantech.ca/aff.php?aff=4337${RESET}"
        echo -e "${GREEN}VPS评测官方网站：https://www.1373737.xyz/${RESET}"
        echo -e "${GREEN}YouTube频道：https://www.youtube.com/@cyndiboy7881${RESET}"
        echo -e "${GREEN}=============================================${RESET}"
        echo "请选择要执行的操作："
        echo -e "${YELLOW}0. 脚本更新  1. VPS一键测试  2. 安装BBR  3. 安装v2ray  4. 安装无人直播云SRS${RESET}"
        echo -e "${YELLOW}5. 面板安装（1panel/宝塔/青龙）  6. 系统更新  7. 修改密码  8. 重启服务器${RESET}"
        echo -e "${YELLOW}9. 一键永久禁用IPv6  10. 一键解除禁用IPv6  11. 设置中国时区${RESET}"
        echo -e "${YELLOW}12. 保持SSH连接  13. 安装系统（KVM）  14. 服务器间文件传输${RESET}"
        echo -e "${YELLOW}15. 安装探针并绑定域名  16. 端口反代  17. 安装curl和wget${RESET}"
        echo -e "${YELLOW}18. Docker管理  19. SSH防暴力破解检测  20. Speedtest测速${RESET}"
        echo -e "${YELLOW}21. WordPress管理（基于Docker）${RESET}"
        echo -e "${GREEN}=============================================${RESET}"
        read -p "请输入选项 (输入 'q' 退出): " option

        [ "$option" = "q" ] && { log_info "退出脚本"; exit 0; }

        case $option in
            0) # 脚本更新
                wget -O /tmp/onekey.sh https://raw.githubusercontent.com/sinian-liu/onekey/main/onekey.sh && \
                sudo mv /tmp/onekey.sh /usr/local/bin/onekey.sh && sudo chmod +x /usr/local/bin/onekey.sh && \
                log_info "脚本更新成功，请重新运行" || log_error "脚本更新失败"
                read -p "按回车继续..."
                ;;
            1) # VPS 测试
                bash <(curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/system_info.sh) || \
                log_error "VPS 测试失败"
                read -p "按回车继续..."
                ;;
            2) # 安装 BBR
                bash <(wget -qO- https://github.com/sinian-liu/Linux-NetSpeed-BBR/raw/master/tcpx.sh) || \
                log_error "BBR 安装失败"
                read -p "按回车继续..."
                ;;
            3) # 安装 v2ray
                bash <(wget -qO- https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh) || \
                log_error "v2ray 安装失败"
                read -p "按回车继续..."
                ;;
            4) # 安装 SRS
                read -p "请输入管理端口 (默认2022): " port
                port=${port:-2022}
                check_port "$port" || { log_error "端口 $port 已占用"; read -p "按回车继续..."; continue; }
                open_port "$port"
                install_pkg "docker.io" && systemctl enable --now docker && \
                docker run -d --restart always -p "$port":2022 -p 1935:1935 -p 1985:1985 -p 8080:8080 \
                    -p 8000:8000/udp -p 10080:10080/udp -v "$HOME/db:/data" ossrs/srs-stack:5 && \
                log_info "SRS 安装完成，访问: http://$(curl -s4 ifconfig.me):$port/mgmt" || log_error "SRS 安装失败"
                read -p "按回车继续..."
                ;;
            5) # 面板管理
                while true; do
                    echo -e "${GREEN}=== 面板管理 ===${RESET}"
                    echo "1) 安装1Panel  2) 安装宝塔纯净版  3) 安装宝塔国际版  4) 安装宝塔国内版  5) 安装青龙面板"
                    echo "6) 卸载1Panel  7) 卸载宝塔  8) 卸载青龙  9) 一键卸载所有  0) 返回主菜单"
                    read -p "请输入选项: " panel_choice
                    case $panel_choice in
                        1) curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh | bash && log_info "1Panel 安装完成" || log_error "1Panel 安装失败" ;;
                        2) wget -O install.sh https://install.baota.sbs/install/install_6.0.sh && bash install.sh && log_info "宝塔纯净版安装完成" || log_error "安装失败" ;;
                        3) wget -O install.sh https://www.aapanel.com/script/install_7.0_en.sh && bash install.sh aapanel && log_info "宝塔国际版安装完成" || log_error "安装失败" ;;
                        4) wget -O install.sh https://download.bt.cn/install/install_panel.sh && bash install.sh ed8484bec && log_info "宝塔国内版安装完成" || log_error "安装失败" ;;
                        5)
                            install_pkg "docker.io" && systemctl enable --now docker
                            if ! command -v docker-compose &> /dev/null; then
                                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                                chmod +x /usr/local/bin/docker-compose
                            fi
                            mkdir -p /home/qinglong && cd /home/qinglong
                            DEFAULT_PORT=5700
                            check_port "$DEFAULT_PORT" || {
                                read -p "端口 $DEFAULT_PORT 已占用，输入新端口: " new_port
                                while ! [[ "$new_port" =~ ^[0-9]+$ ]] || ! check_port "$new_port"; do
                                    read -p "端口无效或占用，输入新端口: " new_port
                                done
                                DEFAULT_PORT=$new_port
                            }
                            open_port "$DEFAULT_PORT"
                            cat > docker-compose.yml <<EOF
version: '3'
services:
  qinglong:
    image: whyour/qinglong:latest
    container_name: qinglong
    restart: unless-stopped
    ports:
      - "$DEFAULT_PORT:5700"
    volumes:
      - ./config:/ql/config
      - ./log:/ql/log
      - ./db:/ql/db
      - ./scripts:/ql/scripts
      - ./jbot:/ql/jbot
EOF
                            docker-compose up -d && log_info "青龙面板安装完成，访问: http://$(curl -s4 ifconfig.me):$DEFAULT_PORT" || log_error "青龙面板安装失败"
                            ;;
                        6) command -v 1pctl &> /dev/null && 1pctl uninstall && log_info "1Panel 已卸载" || log_error "未检测到1Panel" ;;
                        7) [ -f /usr/bin/bt ] || [ -f /usr/bin/aapanel ] && { wget http://download.bt.cn/install/bt-uninstall.sh && sh bt-uninstall.sh && log_info "宝塔已卸载"; } || log_error "未检测到宝塔" ;;
                        8) docker ps -a | grep -q "qinglong" && { cd /home/qinglong && docker-compose down -v && rm -rf /home/qinglong && log_info "青龙已卸载"; } || log_error "未检测到青龙" ;;
                        9)
                            command -v 1pctl &> /dev/null && 1pctl uninstall
                            [ -f /usr/bin/bt ] || [ -f /usr/bin/aapanel ] && { wget http://download.bt.cn/install/bt-uninstall.sh && sh bt-uninstall.sh; }
                            docker ps -a | grep -q "qinglong" && { cd /home/qinglong && docker-compose down -v && rm -rf /home/qinglong; }
                            log_info "所有面板已卸载"
                            ;;
                        0) break ;;
                        *) log_error "无效选项" ;;
                    esac
                    read -p "按回车继续..."
                done
                ;;
            6) update_system; read -p "按回车继续..." ;;
            7) sudo passwd "$(whoami)" && log_info "密码修改成功" || log_error "密码修改失败"; read -p "按回车继续..." ;;
            8) sudo reboot ;;
            9)
                sysctl -w net.ipv6.conf.all.disable_ipv6=1
                sysctl -w net.ipv6.conf.default.disable_ipv6=1
                echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                sysctl -p && log_info "IPv6 已禁用" || log_error "禁用 IPv6 失败"
                read -p "按回车继续..."
                ;;
            10)
                sysctl -w net.ipv6.conf.all.disable_ipv6=0
                sysctl -w net.ipv6.conf.default.disable_ipv6=0
                sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                sysctl -p && log_info "IPv6 已启用" || log_error "启用 IPv6 失败"
                read -p "按回车继续..."
                ;;
            11)
                sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
                systemctl restart cron &> /dev/null || service cron restart &> /dev/null || log_error "未找到 cron 服务"
                log_info "时区已设置为中国时区，当前时间: $(date)"
                read -p "按回车继续..."
                ;;
            12)
                read -p "心跳间隔（分钟，默认5）: " interval
                read -p "最大无响应次数（默认50）: " max_count
                interval=${interval:-5}
                max_count=${max_count:-50}
                interval_seconds=$((interval * 60))
                sudo sed -i "/^ClientAliveInterval/c\ClientAliveInterval $interval_seconds" /etc/ssh/sshd_config
                sudo sed -i "/^ClientAliveCountMax/c\ClientAliveCountMax $max_count" /etc/ssh/sshd_config
                systemctl restart sshd && log_info "SSH 保持连接已配置" || log_error "SSH 配置失败"
                read -p "按回车继续..."
                ;;
            13) # KVM 安装
                check_system
                if [ "$SYSTEM" == "debian" ] || [ "$SYSTEM" == "ubuntu" ]; then
                    install_pkg "xz-utils openssl gawk file wget screen"
                elif [ "$SYSTEM" == "centos" ]; then
                    install_pkg "xz openssl gawk file glibc-common wget screen"
                fi
                bash <(wget -qO- --no-check-certificate https://git.io/newbetags) || log_error "KVM 安装失败"
                read -p "按回车继续..."
                ;;
            14) # 文件传输
                install_pkg "sshpass"
                read -p "目标服务器IP: " target_ip
                read -p "SSH端口（默认22）: " ssh_port
                ssh_port=${ssh_port:-22}
                read -s -p "密码: " ssh_password
                echo
                sshpass -p "$ssh_password" ssh -o StrictHostKeyChecking=no -p "$ssh_port" "root@$target_ip" "echo 'SSH 连接成功'" || { log_error "SSH 连接失败"; read -p "按回车继续..."; continue; }
                sshpass -p "$ssh_password" scp -P "$ssh_port" -o StrictHostKeyChecking=no "$(read -p '源文件路径: '; echo $REPLY)" "root@$target_ip:$(read -p '目标路径: '; echo $REPLY)" && \
                log_info "文件传输成功" || log_error "文件传输失败"
                read -p "按回车继续..."
                ;;
            15) # 安装探针
                read -p "容器端口（默认5555）: " container_port
                read -p "反向代理端口（默认80）: " proxy_port
                container_port=${container_port:-5555}
                proxy_port=${proxy_port:-80}
                check_port "$container_port" || { log_error "端口 $container_port 已占用"; read -p "按回车继续..."; continue; }
                check_port "$proxy_port" || { log_error "端口 $proxy_port 已占用"; read -p "按回车继续..."; continue; }
                open_port "$container_port"
                open_port "$proxy_port"
                install_pkg "docker.io" && docker run -d --restart=on-failure -p "$container_port":5555 nkeonkeo/nekonekostatus:latest
                install_pkg "nginx certbot python3-certbot-nginx"
                read -p "域名: " domain
                read -p "邮箱: " email
                cat > /etc/nginx/sites-available/"$domain" <<EOF
server {
    listen $proxy_port;
    server_name $domain;
    location / {
        proxy_pass http://127.0.0.1:$container_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
                ln -s /etc/nginx/sites-available/"$domain" /etc/nginx/sites-enabled/
                nginx -t && systemctl reload nginx && certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive && \
                log_info "探针安装完成，访问: https://$domain" || log_error "探针安装失败"
                read -p "按回车继续..."
                ;;
            16) # 端口反代
                install_pkg "nginx certbot python3-certbot-nginx"
                read -p "管理员邮箱: " email
                while true; do
                    read -p "域名（留空结束）: " domain
                    [ -z "$domain" ] && break
                    read -p "端口: " port
                    cat >> /etc/nginx/conf.d/alone.conf <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name $domain;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:$port;
    }
}
EOF
                    certbot --nginx -d "$domain" -m "$email" --agree-tos --non-interactive
                done
                nginx -t && systemctl reload nginx && log_info "反代配置完成" || log_error "反代配置失败"
                read -p "按回车继续..."
                ;;
            17) # 安装 curl 和 wget
                install_pkg "curl" && install_pkg "wget" && log_info "curl 和 wget 安装完成" || log_error "安装失败"
                read -p "按回车继续..."
                ;;
            18) # Docker 管理
                while true; do
                    echo -e "${GREEN}=== Docker 管理 ===${RESET}"
                    echo "1) 安装 Docker  2) 卸载 Docker  3) 配置镜像加速  4) 启动容器  5) 停止容器"
                    echo "6) 查看镜像  7) 删除容器  8) 删除镜像  9) 安装 sun-panel"
                    echo "10) 拉取并安装容器  11) 更新镜像并重启  12) 批量操作容器  0) 返回主菜单"
                    read -p "请输入选项: " docker_choice
                    case $docker_choice in
                        1)
                            check_system
                            case $SYSTEM in
                                ubuntu|debian) install_pkg "docker.io" ;;
                                centos|fedora)
                                    install_pkg "yum-utils"
                                    sudo yum-config-manager --add-repo https://download.docker.com/linux/$SYSTEM/docker-ce.repo
                                    install_pkg "docker-ce docker-ce-cli containerd.io"
                                    ;;
                            esac
                            systemctl enable --now docker && log_info "Docker 安装完成" || log_error "Docker 安装失败"
                            sudo usermod -aG docker "$USER" && log_info "已将用户加入 docker 组"
                            ;;
                        2)
                            sudo apt purge -y docker.io docker-ce && rm -rf /var/lib/docker && log_info "Docker 已卸载" || log_error "卸载失败"
                            ;;
                        3)
                            mkdir -p /etc/docker
                            cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
}
EOF
                            systemctl restart docker && log_info "Docker 镜像加速配置完成" || log_error "配置失败"
                            ;;
                        4) read -p "容器ID或名称: " id; docker start "$id" && log_info "容器 $id 已启动" || log_error "启动失败" ;;
                        5) read -p "容器ID或名称: " id; docker stop "$id" && log_info "容器 $id 已停止" || log_error "停止失败" ;;
                        6) docker images ;;
                        7) read -p "容器ID或名称: " id; docker rm -f "$id" && log_info "容器 $id 已删除" || log_error "删除失败" ;;
                        8) read -p "镜像名称: " img; docker rmi "$img" && log_info "镜像 $img 已删除" || log_error "删除失败" ;;
                        9)
                            install_pkg "docker.io" && systemctl enable --now docker
                            DEFAULT_PORT=5678
                            check_port "$DEFAULT_PORT" || {
                                read -p "端口 $DEFAULT_PORT 已占用，输入新端口: " new_port
                                while ! [[ "$new_port" =~ ^[0-9]+$ ]] || ! check_port "$new_port"; do
                                    read -p "端口无效或占用，输入新端口: " new_port
                                done
                                DEFAULT_PORT=$new_port
                            }
                            open_port "$DEFAULT_PORT"
                            docker run -d -p "$DEFAULT_PORT":5678 --name sun-panel --restart=always \
                                -v /opt/sun-panel/conf:/app/conf -v /opt/sun-panel/db:/app/db \
                                -v /opt/sun-panel/uploads:/app/uploads sunpanel/sun-panel:latest && \
                                sleep 5 # 等待服务启动
                            # 模拟登录验证默认账密
                            ip=$(curl -s4 ifconfig.me)
                            login_url="http://$ip:$DEFAULT_PORT/api/authorizations"
                            login_response=$(curl -s -X POST "$login_url" -H "Content-Type: application/json" \
                                -d '{"email": "admin@sun.cc", "password": "12345678"}')
                            if echo "$login_response" | grep -q "token"; then
                                log_info "sun-panel 安装完成，默认账密正确，访问: $login_url"
                                log_info "用户名: admin@sun.cc  密码: 12345678"
                            else
                                log_info "默认账密不正确，正在修改..."
                                docker exec sun-panel sed -i 's/email: .*/email: admin@sun.cc/' /app/conf/application.yml
                                docker exec sun-panel sed -i 's/password: .*/password: 12345678/' /app/conf/application.yml
                                docker restart sun-panel && sleep 3
                                login_response=$(curl -s -X POST "$login_url" -H "Content-Type: application/json" \
                                    -d '{"email": "admin@sun.cc", "password": "12345678"}')
                                if echo "$login_response" | grep -q "token"; then
                                    log_info "sun-panel 安装完成，账密已修改，访问: $login_url"
                                    log_info "用户名: admin@sun.cc  密码: 12345678"
                                else
                                    log_error "账密修改失败，请手动检查"
                                fi
                            fi
                            ;;
                        10)
                            read -p "镜像名称: " img
                            read -p "容器名称: " name
                            read -p "端口映射 (如 80:80): " ports
                            docker run -d --name "$name" -p "$ports" "$img" && log_info "容器 $name 安装完成" || log_error "安装失败"
                            ;;
                        11)
                            read -p "容器名称: " name
                            img=$(docker inspect "$name" --format '{{.Config.Image}}')
                            docker pull "$img" && docker stop "$name" && docker rm "$name" && docker run -d --name "$name" "$img" && \
                            log_info "镜像更新并重启完成" || log_error "更新失败"
                            ;;
                        12)
                            echo "1) 批量启动  2) 批量停止  3) 批量删除"
                            read -p "选择操作: " batch_op
                            case $batch_op in
                                1) docker start $(docker ps -a -q) ;;
                                2) docker stop $(docker ps -q) ;;
                                3) docker rm -f $(docker ps -a -q) ;;
                            esac
                            ;;
                        0) break ;;
                        *) log_error "无效选项" ;;
                    esac
                    read -p "按回车继续..."
                done
                ;;
            19) log_error "SSH 防暴力破解检测尚未实现"; read -p "按回车继续..." ;;
            20) bash <(curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/speedtest.sh) || log_error "Speedtest 失败"; read -p "按回车继续..." ;;
            21) # WordPress 管理
                while true; do
                    echo -e "${GREEN}=== WordPress 管理 ===${RESET}"
                    echo "1) 安装 WordPress  2) 卸载 WordPress  3) 迁移 WordPress  4) 查看证书信息  5) 设置定时备份  0) 返回主菜单"
                    read -p "请输入选项: " wp_choice
                    case $wp_choice in
                        1) # 安装 WordPress
                            install_pkg "docker.io" && systemctl enable --now docker
                            if ! command -v docker-compose &> /dev/null; then
                                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                                chmod +x /usr/local/bin/docker-compose
                            fi
                            DEFAULT_PORT=80
                            DEFAULT_SSL_PORT=443
                            read -p "请输入端口（默认 $DEFAULT_PORT）: " port
                            port=${port:-$DEFAULT_PORT}
                            check_port "$port" || { log_error "端口 $port 已占用"; read -p "按回车继续..."; continue; }
                            open_port "$port"
                            open_port "$DEFAULT_SSL_PORT"
                            read -p "启用 HTTPS? (y/n, 默认n): " https_choice
                            read -p "内存模式 (256/1024/其他，默认其他): " mem_mode
                            mem_mode=${mem_mode:-other}
                            mkdir -p /home/wordpress/{html,mysql,conf.d,logs/{nginx,mariadb},certs}
                            cd /home/wordpress
                            db_root_passwd=$(openssl rand -base64 12)
                            db_user_passwd=$(openssl rand -base64 12)
                            if [ "$mem_mode" = "256" ]; then
                                cat > docker-compose.yml <<EOF
services:
  nginx:
    image: nginx:latest
    container_name: wordpress_nginx
    ports:
      - "$port:80"
    volumes:
      - ./html:/var/www/html
      - ./conf.d:/etc/nginx/conf.d
    depends_on:
      - wordpress
    restart: unless-stopped
  wordpress:
    image: wordpress:php8.2-fpm
    container_name: wordpress
    volumes:
      - ./html:/var/www/html
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: "$db_user_passwd"
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - mariadb
    restart: unless-stopped
  mariadb:
    image: mariadb:10.5
    container_name: wordpress_mariadb
    environment:
      MYSQL_ROOT_PASSWORD: "$db_root_passwd"
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: "$db_user_passwd"
      MYSQL_INNODB_BUFFER_POOL_SIZE: 16M
    volumes:
      - ./mysql:/var/lib/mysql
    restart: unless-stopped
EOF
                            else
                                if [ "$https_choice" = "y" ] || [ "$https_choice" = "Y" ]; then
                                    read -p "域名: " domain
                                    read -p "邮箱: " email
                                    cat > docker-compose.yml <<EOF
services:
  nginx:
    image: nginx:latest
    container_name: wordpress_nginx
    ports:
      - "$port:80"
      - "$DEFAULT_SSL_PORT:443"
    volumes:
      - ./html:/var/www/html
      - ./conf.d:/etc/nginx/conf.d
      - ./certs:/etc/nginx/certs
    depends_on:
      - wordpress
    restart: unless-stopped
  wordpress:
    image: wordpress:php8.2-fpm
    container_name: wordpress
    volumes:
      - ./html:/var/www/html
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: "$db_user_passwd"
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - mariadb
    restart: unless-stopped
  mariadb:
    image: mariadb:10.5
    container_name: wordpress_mariadb
    environment:
      MYSQL_ROOT_PASSWORD: "$db_root_passwd"
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: "$db_user_passwd"
      MYSQL_INNODB_BUFFER_POOL_SIZE: ${mem_mode:-64}M
    volumes:
      - ./mysql:/var/lib/mysql
    restart: unless-stopped
  certbot:
    image: certbot/certbot
    container_name: wordpress_certbot
    volumes:
      - ./certs:/etc/letsencrypt
      - ./html:/var/www/html
    entrypoint: "/bin/sh -c 'trap : TERM INT; (while true; do certbot renew --quiet; sleep 12h; done) & wait'"
    depends_on:
      - nginx
    restart: unless-stopped
EOF
                                    cat > conf.d/default.conf <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name $domain;
    ssl_certificate /etc/nginx/certs/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/live/$domain/privkey.pem;
    root /var/www/html;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php\$ {
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
                                    docker-compose up -d
                                    docker run --rm -v /home/wordpress/certs:/etc/letsencrypt -v /home/wordpress/html:/var/www/html certbot/certbot certonly --webroot -w /var/www/html --force-renewal --email "$email" -d "$domain" --agree-tos --non-interactive && \
                                    log_info "证书申请成功" || log_error "证书申请失败"
                                else
                                    cat > docker-compose.yml <<EOF
services:
  nginx:
    image: nginx:latest
    container_name: wordpress_nginx
    ports:
      - "$port:80"
    volumes:
      - ./html:/var/www/html
      - ./conf.d:/etc/nginx/conf.d
    depends_on:
      - wordpress
    restart: unless-stopped
  wordpress:
    image: wordpress:php8.2-fpm
    container_name: wordpress
    volumes:
      - ./html:/var/www/html
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: "$db_user_passwd"
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - mariadb
    restart: unless-stopped
  mariadb:
    image: mariadb:10.5
    container_name: wordpress_mariadb
    environment:
      MYSQL_ROOT_PASSWORD: "$db_root_passwd"
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: "$db_user_passwd"
      MYSQL_INNODB_BUFFER_POOL_SIZE: ${mem_mode:-64}M
    volumes:
      - ./mysql:/var/lib/mysql
    restart: unless-stopped
EOF
                                    cat > conf.d/default.conf <<EOF
server {
    listen 80;
    server_name _;
    root /var/www/html;
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    location ~ \.php\$ {
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
                                fi
                            fi
                            docker-compose up -d && log_info "WordPress 安装完成，访问: http://$(curl -s4 ifconfig.me):$port" || log_error "WordPress 安装失败"
                            systemctl enable wordpress.service || log_info "服务自启配置失败"
                            ;;
                        2) # 卸载 WordPress
                            cd /home/wordpress || { log_error "未找到 WordPress 安装目录"; read -p "按回车继续..."; continue; }
                            docker-compose down -v && rm -rf /home/wordpress && log_info "WordPress 已卸载" || log_error "卸载失败"
                            systemctl disable wordpress.service &>/dev/null || true
                            rm -f /etc/systemd/system/wordpress.service
                            ;;
                        3) # 迁移 WordPress
                            [ ! -d /home/wordpress ] && { log_error "本地未安装 WordPress"; read -p "按回车继续..."; continue; }
                            read -p "新服务器IP: " new_ip
                            read -p "SSH用户（默认root）: " ssh_user
                            ssh_user=${ssh_user:-root}
                            read -s -p "SSH密码: " ssh_pass
                            echo
                            install_pkg "sshpass"
                            ORIGINAL_PORT=$(grep -oP '(?<=ports:.*- ")[0-9]+:80' /home/wordpress/docker-compose.yml | cut -d':' -f1 || echo "80")
                            ORIGINAL_SSL_PORT=$(grep -oP '(?<=ports:.*- ")[0-9]+:443' /home/wordpress/docker-compose.yml | cut -d':' -f1 || echo "443")
                            tar -czf /tmp/wp_backup.tar.gz -C /home wordpress
                            sshpass -p "$ssh_pass" scp -o StrictHostKeyChecking=no /tmp/wp_backup.tar.gz "$ssh_user@$new_ip:/home/" && \
                            sshpass -p "$ssh_pass" ssh -o StrictHostKeyChecking=no "$ssh_user@$new_ip" "tar -xzf /home/wp_backup.tar.gz -C /home && cd /home/wordpress && docker-compose up -d" && \
                            log_info "WordPress 迁移完成，新地址: http://$new_ip:$ORIGINAL_PORT" || log_error "迁移失败"
                            rm -f /tmp/wp_backup.tar.gz
                            ;;
                        4) # 查看证书信息
                            [ ! -d /home/wordpress/certs ] && { log_error "未启用 HTTPS 或证书不存在"; read -p "按回车继续..."; continue; }
                            domain=$(sed -n 's/^\s*server_name\s*\([^;]*\);/\1/p' /home/wordpress/conf.d/default.conf | head -n 1)
                            openssl x509 -in /home/wordpress/certs/live/"$domain"/fullchain.pem -noout -dates -issuer && log_info "证书信息显示完成" || log_error "证书查看失败"
                            ;;
                        5) # 设置定时备份
                            [ ! -d /home/wordpress ] && { log_error "本地未安装 WordPress"; read -p "按回车继续..."; continue; }
                            read -p "备份服务器IP: " backup_ip
                            read -p "SSH用户（默认root）: " backup_user
                            backup_user=${backup_user:-root}
                            read -s -p "SSH密码: " backup_pass
                            echo
                            read -p "备份周期（daily/weekly/monthly）: " interval
                            case $interval in
                                daily) cron="0 2 * * *" ;;
                                weekly) cron="0 2 * * 0" ;;
                                monthly) cron="0 2 1 * *" ;;
                                *) log_error "无效周期，使用 daily"; cron="0 2 * * *" ;;
                            esac
                            install_pkg "sshpass"
                            cat > /usr/local/bin/wp_backup.sh <<EOF
#!/bin/bash
tar -czf /tmp/wp_backup_\$(date +%Y%m%d).tar.gz -C /home wordpress
sshpass -p "$backup_pass" scp -o StrictHostKeyChecking=no /tmp/wp_backup_\$(date +%Y%m%d).tar.gz "$backup_user@$backup_ip:/home/wordpress_backup/"
rm -f /tmp/wp_backup_\$(date +%Y%m%d).tar.gz
EOF
                            chmod +x /usr/local/bin/wp_backup.sh
                            (crontab -l 2>/dev/null; echo "$cron /usr/local/bin/wp_backup.sh") | crontab - && \
                            log_info "定时备份已设置，目标: $backup_ip" || log_error "备份设置失败"
                            ;;
                        0) break ;;
                        *) log_error "无效选项" ;;
                    esac
                    read -p "按回车继续..."
                done
                ;;
            *) log_error "无效选项"; read -p "按回车继续..." ;;
        esac
    done
}

# 运行主菜单
show_menu
