#!/bin/bash

# 设置颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 系统检测函数（改进版）
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu)
                SYSTEM="ubuntu"
                ;;
            debian)
                SYSTEM="debian"
                ;;
            centos|rhel)
                SYSTEM="centos"
                ;;
            fedora)
                SYSTEM="fedora"
                ;;
            arch)
                SYSTEM="arch"
                ;;
            *)
                SYSTEM="unknown"
                ;;
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

# 安装 wget 函数
install_wget() {
    check_system
    if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
        echo -e "${YELLOW}检测到 wget 缺失，正在安装...${RESET}"
        sudo apt update
        if [ $? -ne 0 ]; then
            echo -e "${RED}apt 更新失败，请检查网络！${RESET}"
            return 1
        fi
        sudo apt install -y wget
        if [ $? -ne 0 ]; then
            echo -e "${RED}wget 安装失败，请手动检查！${RESET}"
            return 1
        fi
    elif [ "$SYSTEM" == "centos" ]; then
        echo -e "${YELLOW}检测到 wget 缺失，正在安装...${RESET}"
        sudo yum install -y wget
        if [ $? -ne 0 ]; then
            echo -e "${RED}wget 安装失败，请手动检查！${RESET}"
            return 1
        fi
    elif [ "$SYSTEM" == "fedora" ]; then
        echo -e "${YELLOW}检测到 wget 缺失，正在安装...${RESET}"
        sudo dnf install -y wget
        if [ $? -ne 0 ]; then
            echo -e "${RED}wget 安装失败，请手动检查！${RESET}"
            return 1
        fi
    else
        echo -e "${RED}无法识别系统，无法安装 wget。${RESET}"
        return 1
    fi
    return 0
}

# 检查并安装 wget
if ! command -v wget &> /dev/null; then
    install_wget
    if [ $? -ne 0 ] || ! command -v wget &> /dev/null; then
        echo -e "${RED}安装 wget 失败，请手动检查问题！${RESET}"
        exit 1
    fi
fi

# 系统更新函数
update_system() {
    check_system
    if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
        echo -e "${GREEN}正在更新 Debian/Ubuntu 系统...${RESET}"
        sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ "$SYSTEM" == "centos" ]; then
        echo -e "${GREEN}正在更新 CentOS 系统...${RESET}"
        sudo yum update -y && sudo yum clean all
        if [ $? -ne 0 ]; then
            return 1
        fi
    elif [ "$SYSTEM" == "fedora" ]; then
        echo -e "${GREEN}正在更新 Fedora 系统...${RESET}"
        sudo dnf update -y && sudo dnf clean all
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        echo -e "${RED}无法识别您的操作系统，跳过更新步骤。${RESET}"
        return 1
    fi
    return 0
}

# 增加快捷命令 s 设置（如果没有的话）
if ! grep -q "alias s=" ~/.bashrc; then
    echo "正在为 s 设置快捷命令..."
    echo "alias s='bash <(curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/onekey.sh)'" >> ~/.bashrc
    source ~/.bashrc
    echo "快捷命令 s 已设置。"
else
    echo "快捷命令 s 已经存在。"
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
        echo -e "${YELLOW}0. 脚本更新${RESET}"
        echo -e "${YELLOW}1. VPS一键测试${RESET}"
        echo -e "${YELLOW}2. 安装BBR${RESET}"
        echo -e "${YELLOW}3. 安装v2ray${RESET}"
        echo -e "${YELLOW}4. 安装无人直播云SRS${RESET}"
        echo -e "${YELLOW}5. 安装宝塔纯净版${RESET}"
        echo -e "${YELLOW}6. 系统更新${RESET}"
        echo -e "${YELLOW}7. 修改密码${RESET}"
        echo -e "${YELLOW}8. 重启服务器${RESET}"
        echo -e "${YELLOW}9. 一键永久禁用IPv6${RESET}"
        echo -e "${YELLOW}10.一键解除禁用IPv6${RESET}"
        echo -e "${YELLOW}11.服务器时区修改为中国时区${RESET}"
        echo -e "${YELLOW}12.保持SSH会话一直连接不断开${RESET}"
        echo -e "${YELLOW}13.安装Windows或Linux系统${RESET}"
        echo -e "${YELLOW}14.服务器对服务器文件传输${RESET}"
        echo -e "${YELLOW}15.安装探针并绑定域名${RESET}"
        echo -e "${YELLOW}16.共用端口（反代）${RESET}"
        echo -e "${YELLOW}17.安装 curl 和 wget${RESET}"
        echo -e "${YELLOW}18.安装 Docker${RESET}"
        echo -e "${YELLOW}19.SSH 防暴力破解检测${RESET}"
        echo -e "${YELLOW}20.Speedtest测速面板${RESET}"
        echo -e "${GREEN}=============================================${RESET}"

        read -p "请输入选项 (输入 'q' 退出): " option

        # 检查是否退出
        if [ "$option" = "q" ]; then
            echo -e "${GREEN}退出脚本，感谢使用！${RESET}"
            echo -e "${GREEN}服务器推荐：https://my.frantech.ca/aff.php?aff=4337${RESET}"
            echo -e "${GREEN}VPS评测官方网站：https://www.1373737.xyz/${RESET}"
            exit 0
        fi

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
                read -p "按回车键返回主菜单..."
                ;;
            1)
                # VPS 一键测试脚本
                echo -e "${GREEN}正在进行 VPS 测试 ...${RESET}"
                curl -sL https://raw.githubusercontent.com/sinian-liu/onekey/main/system_info.sh -o /tmp/system_info.sh
                if [ $? -eq 0 ]; then
                    chmod +x /tmp/system_info.sh
                    bash /tmp/system_info.sh
                    rm -f /tmp/system_info.sh
                else
                    echo -e "${RED}下载 VPS 测试脚本失败，请检查网络！${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            2)
                # BBR 安装脚本
                echo -e "${GREEN}正在安装 BBR ...${RESET}"
                wget -O /tmp/tcpx.sh "https://github.com/sinian-liu/Linux-NetSpeed-BBR/raw/master/tcpx.sh"
                if [ $? -eq 0 ]; then
                    chmod +x /tmp/tcpx.sh
                    bash /tmp/tcpx.sh
                    rm -f /tmp/tcpx.sh
                else
                    echo -e "${RED}下载 BBR 脚本失败，请检查网络！${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            3)
                # 安装 v2ray 脚本
                echo -e "${GREEN}正在安装 v2ray ...${RESET}"
                wget -P /tmp -N --no-check-certificate "https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh"
                if [ $? -eq 0 ]; then
                    chmod 700 /tmp/install.sh
                    bash /tmp/install.sh
                    rm -f /tmp/install.sh
                else
                    echo -e "${RED}下载 v2ray 脚本失败，请检查网络！${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            4)
                # 无人直播云 SRS 安装
                echo -e "${GREEN}正在安装无人直播云 SRS ...${RESET}"
                read -p "请输入要使用的管理端口号 (默认为2022): " mgmt_port
                mgmt_port=${mgmt_port:-2022}

                check_port() {
                    local port=$1
                    if netstat -tuln | grep ":$port" > /dev/null; then
                        return 1
                    else
                        return 0
                    fi
                }

                check_port $mgmt_port
                if [ $? -eq 1 ]; then
                    echo -e "${RED}端口 $mgmt_port 已被占用！${RESET}"
                    read -p "请输入其他端口号作为管理端口: " mgmt_port
                fi

                sudo apt-get update
                if [ $? -ne 0 ]; then
                    echo -e "${RED}apt 更新失败，请检查网络！${RESET}"
                else
                    sudo apt-get install -y docker.io
                    if [ $? -eq 0 ]; then
                        docker run --restart always -d --name srs-stack -it -p $mgmt_port:2022 -p 1935:1935/tcp -p 1985:1985/tcp \
                          -p 8080:8080/tcp -p 8000:8000/udp -p 10080:10080/udp \
                          -v $HOME/db:/data ossrs/srs-stack:5
                        server_ip=$(curl -s4 ifconfig.me)
                        echo -e "${GREEN}SRS 安装完成！您可以通过以下地址访问管理界面:${RESET}"
                        echo -e "${YELLOW}http://$server_ip:$mgmt_port/mgmt${RESET}"
                    else
                        echo -e "${RED}Docker 安装失败，请手动检查！${RESET}"
                    fi
                fi
                read -p "按回车键返回主菜单..."
                ;;
            5)
                # 宝塔纯净版安装
                echo -e "${GREEN}正在安装宝塔面板...${RESET}"
                if [ -f /etc/lsb-release ]; then
                    wget -O /tmp/install.sh https://install.baota.sbs/install/install_6.0.sh
                    if [ $? -eq 0 ]; then
                        bash /tmp/install.sh
                        rm -f /tmp/install.sh
                    else
                        echo -e "${RED}下载宝塔安装脚本失败，请检查网络！${RESET}"
                    fi
                elif [ -f /etc/redhat-release ]; then
                    yum install -y wget
                    if [ $? -eq 0 ]; then
                        wget -O /tmp/install.sh https://install.baota.sbs/install/install_6.0.sh
                        if [ $? -eq 0 ]; then
                            sh /tmp/install.sh
                            rm -f /tmp/install.sh
                        else
                            echo -e "${RED}下载宝塔安装脚本失败，请检查网络！${RESET}"
                        fi
                    else
                        echo -e "${RED}wget 安装失败，无法下载宝塔脚本！${RESET}"
                    fi
                else
                    echo -e "${RED}无法识别您的操作系统，无法安装宝塔面板。${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            6)
                # 系统更新命令
                echo -e "${GREEN}正在更新系统...${RESET}"
                update_system
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}系统更新成功！${RESET}"
                else
                    echo -e "${RED}系统更新失败，请检查网络或手动执行更新！${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            7)
                # 修改当前用户密码
                username=$(whoami)
                echo -e "${GREEN}正在为 ${YELLOW}$username${GREEN} 修改密码...${RESET}"
                sudo passwd "$username"
                read -p "按回车键返回主菜单..."
                ;;
            8)
                # 重启服务器
                echo -e "${GREEN}正在重启服务器 ...${RESET}"
                sudo reboot
                ;;
            9)
                # 永久禁用 IPv6
                echo -e "${GREEN}正在禁用 IPv6 ...${RESET}"
                check_system
                case $SYSTEM in
                    ubuntu|debian)
                        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                        sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
                        echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                        echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf
                        sudo sysctl -p
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}禁用 IPv6 失败，请检查权限或配置文件！${RESET}"
                        else
                            echo -e "${GREEN}IPv6 已成功禁用！${RESET}"
                        fi
                        ;;
                    centos|fedora)
                        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                        sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
                        echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                        echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                        sudo sysctl -p
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}禁用 IPv6 失败，请检查权限或配置文件！${RESET}"
                        else
                            echo -e "${GREEN}IPv6 已成功禁用！${RESET}"
                        fi
                        ;;
                    *)
                        echo -e "${RED}无法识别您的操作系统，无法禁用 IPv6。${RESET}"
                        echo -e "${YELLOW}请检查 /etc/os-release 或相关系统文件以确认发行版。${RESET}"
                        echo -e "${YELLOW}当前检测结果: SYSTEM=$SYSTEM${RESET}"
                        ;;
                esac
                read -p "按回车键返回主菜单..."
                ;;
            10)
                # 解除禁用 IPv6
                echo -e "${GREEN}正在解除禁用 IPv6 ...${RESET}"
                check_system
                case $SYSTEM in
                    ubuntu|debian)
                        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                        sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
                        sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                        sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                        sudo sysctl -p
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}解除禁用 IPv6 失败，请检查权限或配置文件！${RESET}"
                        else
                            echo -e "${GREEN}IPv6 已成功启用！${RESET}"
                        fi
                        ;;
                    centos|fedora)
                        sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                        sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
                        sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                        sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                        sudo sysctl -p
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}解除禁用 IPv6 失败，请检查权限或配置文件！${RESET}"
                        else
                            echo -e "${GREEN}IPv6 已成功启用！${RESET}"
                        fi
                        ;;
                    *)
                        echo -e "${RED}无法识别您的操作系统，无法解除禁用 IPv6。${RESET}"
                        echo -e "${YELLOW}请检查 /etc/os-release 或相关系统文件以确认发行版。${RESET}"
                        echo -e "${YELLOW}当前检测结果: SYSTEM=$SYSTEM${RESET}"
                        ;;
                esac
                read -p "按回车键返回主菜单..."
                ;;
            11)
    # 服务器时区修改为中国时区
    echo -e "${GREEN}正在修改服务器时区为中国时区 ...${RESET}"
    
    # 设置时区为 Asia/Shanghai
    sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    
    # 重启 cron 服务
    if command -v systemctl &> /dev/null; then
        # 尝试重启 cron 服务
        if systemctl list-unit-files | grep -q cron.service; then
            sudo systemctl restart cron
        else
            echo -e "${YELLOW}未找到 cron 服务，跳过重启。${RESET}"
        fi
    else
        # 使用 service 命令重启 cron
        if service --status-all | grep -q cron; then
            sudo service cron restart
        else
            echo -e "${YELLOW}未找到 cron 服务，跳过重启。${RESET}"
        fi
    fi
    
    # 显示当前时区和时间
    echo -e "${YELLOW}当前时区已设置为：$(timedatectl | grep "Time zone" | awk '{print $3}')${RESET}"
    echo -e "${YELLOW}当前时间：$(date)${RESET}"
    
    # 按回车键返回主菜单
    read -p "按回车键返回主菜单..."
    ;;
            12)
                # 长时间保持 SSH 会话连接不断开
                echo -e "${GREEN}正在配置 SSH 保持连接...${RESET}"
                read -p "请输入每次心跳请求的间隔时间（单位：分钟，默认为5分钟）： " interval
                interval=${interval:-5}
                read -p "请输入客户端最大无响应次数（默认为50次）： " max_count
                max_count=${max_count:-50}
                interval_seconds=$((interval * 60))

                echo "正在更新 SSH 配置文件..."
                sudo sed -i "/^ClientAliveInterval/c\ClientAliveInterval $interval_seconds" /etc/ssh/sshd_config
                sudo sed -i "/^ClientAliveCountMax/c\ClientAliveCountMax $max_count" /etc/ssh/sshd_config

                echo "正在重启 SSH 服务以应用配置..."
                sudo systemctl restart sshd
                echo -e "${GREEN}配置完成！心跳请求间隔为 $interval 分钟，最大无响应次数为 $max_count。${RESET}"
                read -p "按回车键返回主菜单..."
                ;;
            13)
                # KVM安装系统
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

                if [ "$SYSTEM" == "debian" ]; then
                    echo -e "${YELLOW}检测到系统为 Debian/Ubuntu，开始安装必要依赖...${RESET}"
                    apt-get install -y xz-utils openssl gawk file wget screen
                    if [ $? -eq 0 ]; then
                        echo -e "${YELLOW}必要依赖安装完成，开始更新系统软件包...${RESET}"
                        apt update -y && apt dist-upgrade -y
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}系统更新失败，请检查网络或镜像源！${RESET}"
                        fi
                    else
                        echo -e "${RED}必要依赖安装失败，请检查网络或镜像源！${RESET}"
                    fi
                elif [ "$SYSTEM" == "centos" ]; then
                    echo -e "${YELLOW}检测到系统为 RedHat/CentOS，开始安装必要依赖...${RESET}"
                    yum install -y xz openssl gawk file glibc-common wget screen
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}依赖安装失败，请检查网络或镜像源！${RESET}"
                    fi
                else
                    echo -e "${RED}不支持的操作系统！${RESET}"
                fi

                echo -e "${YELLOW}开始下载并运行安装脚本...${RESET}"
                wget --no-check-certificate -O /tmp/NewReinstall.sh https://git.io/newbetags
                if [ $? -eq 0 ]; then
                    chmod a+x /tmp/NewReinstall.sh
                    bash /tmp/NewReinstall.sh
                    rm -f /tmp/NewReinstall.sh
                    echo -e "${GREEN}安装完成！${RESET}"
                else
                    echo -e "${RED}脚本下载失败，请检查网络或镜像源！${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            14)
                # 服务器对服务器传文件
                echo -e "${GREEN}服务器对服务器传文件${RESET}"
                if ! command -v sshpass &> /dev/null; then
                    echo -e "${YELLOW}检测到 sshpass 缺失，正在安装...${RESET}"
                    sudo apt update && sudo apt install -y sshpass
                    if [ $? -ne 0 ]; then
                        echo -e "${RED}安装 sshpass 失败，请手动安装！${RESET}"
                    fi
                fi

                read -p "请输入目标服务器IP地址（例如：185.106.96.93）： " target_ip
                read -p "请输入目标服务器SSH端口（默认为22）： " ssh_port
                ssh_port=${ssh_port:-22}
                read -s -p "请输入目标服务器密码：" ssh_password
                echo

                echo -e "${YELLOW}正在验证目标服务器的 SSH 连接...${RESET}"
                sshpass -p "$ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$ssh_port" root@"$target_ip" "echo 'SSH 连接成功！'" &> /dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}SSH 连接验证成功！${RESET}"
                    read -p "请输入源文件路径（例如：/root/data/vlive/test.mp4）： " source_file
                    read -p "请输入目标文件路径（例如：/root/data/vlive/）： " target_path
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
                read -p "按回车键返回主菜单..."
                ;;
            15)
                # 安装 NekoNekoStatus 服务器探针并绑定域名
                echo -e "${GREEN}正在安装 NekoNekoStatus 服务器探针并绑定域名...${RESET}"
                if ! command -v docker &> /dev/null; then
                    echo -e "${YELLOW}检测到 Docker 未安装，正在安装 Docker...${RESET}"
                    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                    if [ $? -eq 0 ]; then
                        bash /tmp/get-docker.sh
                        rm -f /tmp/get-docker.sh
                    else
                        echo -e "${RED}Docker 安装脚本下载失败，请手动安装 Docker！${RESET}"
                    fi
                fi

                read -p "请输入 NekoNekoStatus 容器端口（默认为 5555）： " container_port
                container_port=${container_port:-5555}
                read -p "请输入反向代理端口（默认为 80）： " proxy_port
                proxy_port=${proxy_port:-80}

                check_port() {
                    local port=$1
                    if netstat -tuln | grep ":$port" > /dev/null; then
                        return 1
                    else
                        return 0
                    fi
                }

                check_port $container_port
                if [ $? -eq 1 ]; then
                    echo -e "${RED}端口 $container_port 已被占用，请选择其他端口！${RESET}"
                else
                    check_port $proxy_port
                    if [ $? -eq 1 ]; then
                        echo -e "${RED}端口 $proxy_port 已被占用，请选择其他端口！${RESET}"
                    else
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

                        echo -e "${YELLOW}正在开放容器端口 $container_port...${RESET}"
                        open_port $container_port
                        echo -e "${YELLOW}正在开放反向代理端口 $proxy_port...${RESET}"
                        open_port $proxy_port

                        echo -e "${YELLOW}正在拉取 NekoNekoStatus Docker 镜像...${RESET}"
                        docker pull nkeonkeo/nekonekostatus:latest
                        echo -e "${YELLOW}正在启动 NekoNekoStatus 容器...${RESET}"
                        docker run --restart=on-failure --name nekonekostatus -p $container_port:5555 -d nkeonkeo/nekonekostatus:latest

                        read -p "请输入您的域名（例如：www.example.com）： " domain
                        read -p "请输入您的邮箱（用于 Let's Encrypt 证书）： " email

                        if ! command -v nginx &> /dev/null; then
                            echo -e "${YELLOW}正在安装 Nginx...${RESET}"
                            sudo apt update -y && sudo apt install -y nginx
                        fi
                        if ! command -v certbot &> /dev/null; then
                            echo -e "${YELLOW}正在安装 Certbot...${RESET}"
                            sudo apt install -y certbot python3-certbot-nginx
                        fi

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
                        sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
                        sudo nginx -t && sudo systemctl reload nginx

                        echo -e "${YELLOW}正在申请 Let's Encrypt 证书...${RESET}"
                        sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive

                        echo -e "${YELLOW}正在配置证书自动续期...${RESET}"
                        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

                        echo -e "${GREEN}NekoNekoStatus 安装和域名绑定完成！${RESET}"
                        echo -e "${YELLOW}您现在可以通过 https://$domain 访问探针服务了。${RESET}"
                        echo -e "${YELLOW}容器端口: $container_port${RESET}"
                        echo -e "${YELLOW}反向代理端口: $proxy_port${RESET}"
                        echo -e "${YELLOW}默认密码: nekonekostatus${RESET}"
                        echo -e "${YELLOW}安装后务必修改密码！${RESET}"
                    fi
                fi
                read -p "按回车键返回主菜单..."
                ;;
            16)
                # 共用端口（反代）
                if [ "$EUID" -ne 0 ]; then
                    echo "❌ 请使用sudo或root用户运行此脚本"
                else
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

                    request_certificate() {
                        local domain=$1
                        echo "➜ 为域名 $domain 申请SSL证书..."
                        if certbot --nginx --non-interactive --agree-tos -m $ADMIN_EMAIL -d $domain > /dev/null 2>&1; then
                            echo "✅ 证书申请成功"
                        else
                            echo "❌ 证书申请失败，请检查域名DNS解析或端口开放情况"
                        fi
                    }

                    configure_nginx() {
                        local domain=$1
                        local port=$2
                        local conf_file="/etc/nginx/conf.d/alone.conf"
                        cat >> $conf_file <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}
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

                    check_cert_expiry() {
                        local domain=$1
                        if [ -f /etc/letsencrypt/live/$domain/cert.pem ]; then
                            local expiry_date=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$domain/cert.pem | cut -d= -f2)
                            local expiry_seconds=$(date -d "$expiry_date" +%s)
                            local current_seconds=$(date +%s)
                            local days_left=$(( (expiry_seconds - current_seconds) / 86400 ))
                            echo "➜ 域名 $domain 的SSL证书将在 $days_left 天后到期"
                            if [ $days_left -lt 30 ]; then
                                echo "⚠️ 证书即将到期，建议尽快续签"
                            fi
                        else
                            echo "❌ 未找到域名 $domain 的证书文件"
                        fi
                    }

                    echo "🛠️ Nginx多域名部署脚本"
                    echo "------------------------"
                    echo "🔍 检查当前已配置的域名和端口："
                    if [ -f /etc/nginx/conf.d/alone.conf ]; then
                        grep -oP 'server_name \K[^;]+' /etc/nginx/conf.d/alone.conf | sort | uniq | while read -r domain; do
                            echo "  域名: $domain"
                        done
                    else
                        echo "⚠️ 未找到 /etc/nginx/conf.d/alone.conf 文件，将创建新配置"
                    fi

                    read -p "请输入管理员邮箱（用于证书通知）: " ADMIN_EMAIL
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
                    else
                        install_dependencies
                        for domain in "${!domains[@]}"; do
                            port=${domains[$domain]}
                            configure_nginx $domain $port
                            request_certificate $domain
                            check_cert_expiry $domain
                        done

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
                            echo "⚠️ 未检测到防火墙工具，请手动放行端口"
                        fi

                        (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
                        echo "✅ 已添加证书自动续签任务"

                        echo -e "\n🔌 当前服务状态："
                        echo "Nginx状态: $(systemctl is-active nginx)"
                        echo "监听端口:"
                        ss -tuln | grep -E ':80|:443'
                        echo -e "\n🎉 部署完成！"
                    fi
                fi
                read -p "按回车键返回主菜单..."
                ;;
            17)
                # 安装 curl 和 wget
                echo -e "${GREEN}正在安装 curl 和 wget ...${RESET}"
                if ! command -v curl &> /dev/null; then
                    echo -e "${YELLOW}检测到 curl 缺失，正在安装...${RESET}"
                    check_system
                    if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
                        sudo apt update && sudo apt install -y curl
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}curl 安装成功！${RESET}"
                        else
                            echo -e "${RED}curl 安装失败，请手动检查问题！${RESET}"
                        fi
                    elif [ "$SYSTEM" == "centos" ]; then
                        sudo yum install -y curl
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}curl 安装成功！${RESET}"
                        else
                            echo -e "${RED}curl 安装失败，请手动检查问题！${RESET}"
                        fi
                    elif [ "$SYSTEM" == "fedora" ]; then
                        sudo dnf install -y curl
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}curl 安装成功！${RESET}"
                        else
                            echo -e "${RED}curl 安装失败，请手动检查问题！${RESET}"
                        fi
                    else
                        echo -e "${RED}无法识别系统，无法安装 curl。${RESET}"
                    fi
                else
                    echo -e "${YELLOW}curl 已经安装，跳过安装步骤。${RESET}"
                fi

                if ! command -v wget &> /dev/null; then
                    install_wget
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}wget 安装成功！${RESET}"
                    else
                        echo -e "${RED}wget 安装失败，请手动检查问题！${RESET}"
                    fi
                else
                    echo -e "${YELLOW}wget 已经安装，跳过安装步骤。${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            18)
                # 安装 Docker
                echo -e "${GREEN}正在安装 Docker ...${RESET}"
                if ! command -v docker &> /dev/null; then
                    echo -e "${YELLOW}检测到 Docker 缺失，正在安装...${RESET}"
                    check_system
                    if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
                        sudo apt update
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}apt 更新失败，请检查网络！${RESET}"
                        else
                            sudo apt install -y docker.io
                            if [ $? -ne 0 ]; then
                                echo -e "${RED}Docker 安装失败，请手动检查问题！${RESET}"
                            fi
                        fi
                    elif [ "$SYSTEM" == "centos" ]; then
                        sudo yum install -y docker
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}Docker 安装失败，请手动检查问题！${RESET}"
                        fi
                    elif [ "$SYSTEM" == "fedora" ]; then
                        sudo dnf install -y docker
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}Docker 安装失败，请手动检查问题！${RESET}"
                        fi
                    else
                        echo -e "${RED}无法识别系统，无法安装 Docker。${RESET}"
                    fi

                    if command -v docker &> /dev/null; then
                        echo -e "${GREEN}Docker 安装成功！${RESET}"
                        sudo systemctl enable docker
                        sudo systemctl start docker
                        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
                        echo -e "${YELLOW}当前 Docker 版本: $DOCKER_VERSION${RESET}"
                    else
                        echo -e "${RED}Docker 安装失败，请手动检查问题！${RESET}"
                    fi
                else
                    echo -e "${YELLOW}Docker 已经安装，跳过安装步骤。${RESET}"
                    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
                    echo -e "${YELLOW}当前 Docker 版本: $DOCKER_VERSION${RESET}"
                fi
                read -p "按回车键返回主菜单..."
                ;;
            19)
                # SSH 防暴力破解检测与防护
                echo -e "${GREEN}正在处理 SSH 暴力破解检测与防护...${RESET}"
                DETECT_CONFIG="/etc/ssh_brute_force.conf"

                # 检查并安装 rsyslog（如果缺失）
                if ! command -v rsyslogd &> /dev/null; then
                    echo -e "${YELLOW}未检测到 rsyslog，正在安装...${RESET}"
                    check_system
                    if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
                        sudo apt update && sudo apt install -y rsyslog
                    elif [ "$SYSTEM" == "centos" ]; then
                        sudo yum install -y rsyslog
                    elif [ "$SYSTEM" == "fedora" ]; then
                        sudo dnf install -y rsyslog
                    else
                        echo -e "${RED}无法识别系统，无法安装 rsyslog！${RESET}"
                    fi
                    if command -v rsyslogd &> /dev/null; then
                        sudo systemctl start rsyslog
                        sudo systemctl enable rsyslog
                        echo -e "${GREEN}rsyslog 安装并启动成功！${RESET}"
                    else
                        echo -e "${RED}rsyslog 安装失败，请手动安装！${RESET}"
                    fi
                fi

                # 确定并确保日志文件存在
                if [ -f /var/log/auth.log ]; then
                    LOG_FILE="/var/log/auth.log"  # Debian/Ubuntu
                elif [ -f /var/log/secure ]; then
                    LOG_FILE="/var/log/secure"   # CentOS/RHEL
                else
                    echo -e "${YELLOW}未找到 SSH 日志文件，正在尝试创建 /var/log/auth.log...${RESET}"
                    sudo touch /var/log/auth.log
                    sudo chown root:root /var/log/auth.log
                    sudo chmod 640 /var/log/auth.log
                    if [ ! -d /etc/rsyslog.d ]; then
                        sudo mkdir -p /etc/rsyslog.d
                    fi
                    echo "auth,authpriv.* /var/log/auth.log" | sudo tee /etc/rsyslog.d/auth.conf > /dev/null
                    if command -v rsyslogd &> /dev/null; then
                        sudo systemctl restart rsyslog
                        sudo systemctl restart sshd
                        if [ $? -eq 0 ] && [ -f /var/log/auth.log ]; then
                            LOG_FILE="/var/log/auth.log"
                            echo -e "${GREEN}已创建 /var/log/auth.log 并配置完成！${RESET}"
                        else
                            echo -e "${RED}日志服务配置失败，请检查 rsyslog 和 sshd 是否正常运行！${RESET}"
                            read -p "按回车键返回主菜单..."
                            continue
                        fi
                    else
                        echo -e "${RED}未安装 rsyslog，无法配置日志文件！${RESET}"
                        read -p "按回车键返回主菜单..."
                        continue
                    fi
                fi

                # 检查是否首次运行检测配置
                if [ ! -f "$DETECT_CONFIG" ]; then
                    echo -e "${YELLOW}首次运行检测功能，请设置检测参数：${RESET}"
                    read -p "请输入单 IP 允许的最大失败尝试次数 [默认 5]： " max_attempts
                    max_attempts=${max_attempts:-5}
                    read -p "请输入 IP 统计时间范围（分钟）[默认 1440（1天）]： " detect_time
                    detect_time=${detect_time:-1440}
                    read -p "请输入高风险阈值（总失败次数）[默认 10]： " high_risk_threshold
                    high_risk_threshold=${high_risk_threshold:-10}
                    read -p "请输入常规扫描间隔（分钟）[默认 15]： " scan_interval
                    scan_interval=${scan_interval:-15}
                    read -p "请输入高风险扫描间隔（分钟）[默认 5]： " scan_interval_high
                    scan_interval_high=${scan_interval_high:-5}

                    # 保存检测配置
                    echo "MAX_ATTEMPTS=$max_attempts" | sudo tee "$DETECT_CONFIG" > /dev/null
                    echo "DETECT_TIME=$detect_time" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                    echo "HIGH_RISK_THRESHOLD=$high_risk_threshold" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                    echo "SCAN_INTERVAL=$scan_interval" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                    echo "SCAN_INTERVAL_HIGH=$scan_interval_high" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                    echo -e "${GREEN}检测配置已保存至 $DETECT_CONFIG${RESET}"
                else
                    # 读取检测配置
                    source "$DETECT_CONFIG"
                    echo -e "${YELLOW}当前检测配置：最大尝试次数=$MAX_ATTEMPTS，统计时间范围=$DETECT_TIME 分钟，高风险阈值=$HIGH_RISK_THRESHOLD，常规扫描=$SCAN_INTERVAL 分钟，高风险扫描=$SCAN_INTERVAL_HIGH 分钟${RESET}"
                    read -p "请选择操作：1) 查看尝试破解的 IP 记录  2) 修改检测参数  3) 配置 Fail2Ban 防护（输入 1、2 或 3）： " choice
                    if [ "$choice" == "2" ]; then
                        echo -e "${YELLOW}请输入新的检测参数（留空保留原值）：${RESET}"
                        read -p "请输入单 IP 允许的最大失败尝试次数 [当前 $MAX_ATTEMPTS]： " max_attempts
                        max_attempts=${max_attempts:-$MAX_ATTEMPTS}
                        read -p "请输入 IP 统计时间范围（分钟）[当前 $DETECT_TIME]： " detect_time
                        detect_time=${detect_time:-$DETECT_TIME}
                        read -p "请输入高风险阈值（总失败次数）[当前 $HIGH_RISK_THRESHOLD]： " high_risk_threshold
                        high_risk_threshold=${high_risk_threshold:-$HIGH_RISK_THRESHOLD}
                        read -p "请输入常规扫描间隔（分钟）[当前 $SCAN_INTERVAL]： " scan_interval
                        scan_interval=${scan_interval:-$SCAN_INTERVAL}
                        read -p "请输入高风险扫描间隔（分钟）[当前 $SCAN_INTERVAL_HIGH]： " scan_interval_high
                        scan_interval_high=${scan_interval_high:-$SCAN_INTERVAL_HIGH}

                        # 更新检测配置
                        echo "MAX_ATTEMPTS=$max_attempts" | sudo tee "$DETECT_CONFIG" > /dev/null
                        echo "DETECT_TIME=$detect_time" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                        echo "HIGH_RISK_THRESHOLD=$high_risk_threshold" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                        echo "SCAN_INTERVAL=$scan_interval" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                        echo "SCAN_INTERVAL_HIGH=$scan_interval_high" | sudo tee -a "$DETECT_CONFIG" > /dev/null
                        echo -e "${GREEN}检测配置已更新至 $DETECT_CONFIG${RESET}"
                    elif [ "$choice" == "3" ]; then
                        # 子选项 3：配置 Fail2Ban 防护
                        FAIL2BAN_CONFIG="/etc/fail2ban_config.conf"
                        echo -e "${GREEN}正在处理 Fail2Ban 防护配置...${RESET}"

                        # 检查并安装 Fail2Ban
                        if ! command -v fail2ban-client &> /dev/null; then
                            echo -e "${YELLOW}未检测到 Fail2Ban，正在安装...${RESET}"
                            check_system
                            if [ "$SYSTEM" == "ubuntu" ] || [ "$SYSTEM" == "debian" ]; then
                                sudo apt update && sudo apt install -y fail2ban
                            elif [ "$SYSTEM" == "centos" ]; then
                                sudo yum install -y epel-release && sudo yum install -y fail2ban
                            elif [ "$SYSTEM" == "fedora" ]; then
                                sudo dnf install -y fail2ban
                            else
                                echo -e "${RED}无法识别系统，无法安装 Fail2Ban！${RESET}"
                            fi
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}Fail2Ban 安装成功！${RESET}"
                            else
                                echo -e "${RED}Fail2Ban 安装失败，请手动安装！${RESET}"
                                read -p "按回车键继续检测暴力破解记录..."
                            fi
                        else
                            echo -e "${YELLOW}Fail2Ban 已安装，跳过安装步骤。${RESET}"
                        fi

                        # 检查 Fail2Ban 配置是否首次运行
                        if [ ! -f "$FAIL2BAN_CONFIG" ]; then
                            echo -e "${YELLOW}首次配置 Fail2Ban，请设置防护参数：${RESET}"
                            read -p "请输入单 IP 允许的最大失败尝试次数 [默认 5]： " fail2ban_max_attempts
                            fail2ban_max_attempts=${fail2ban_max_attempts:-5}
                            read -p "请输入 IP 封禁时长（秒）[默认 3600（1小时）]： " ban_time
                            ban_time=${ban_time:-3600}
                            read -p "请输入查找时间窗口（秒）[默认 600（10分钟）]： " find_time
                            find_time=${find_time:-600}

                            # 保存 Fail2Ban 配置
                            echo "FAIL2BAN_MAX_ATTEMPTS=$fail2ban_max_attempts" | sudo tee "$FAIL2BAN_CONFIG" > /dev/null
                            echo "BAN_TIME=$ban_time" | sudo tee -a "$FAIL2BAN_CONFIG" > /dev/null
                            echo "FIND_TIME=$find_time" | sudo tee -a "$FAIL2BAN_CONFIG" > /dev/null

                            # 配置 Fail2Ban jail.local
                            sudo bash -c "cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = $ban_time
findtime = $find_time
maxretry = $fail2ban_max_attempts

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = $LOG_FILE
maxretry = $fail2ban_max_attempts
bantime = $ban_time
EOF"
                            echo -e "${GREEN}Fail2Ban 配置已保存至 $FAIL2BAN_CONFIG 和 /etc/fail2ban/jail.local${RESET}"
                            sudo systemctl restart fail2ban
                            sudo systemctl enable fail2ban
                        else
                            # 读取 Fail2Ban 配置
                            source "$FAIL2BAN_CONFIG"
                            echo -e "${YELLOW}当前 Fail2Ban 配置：最大尝试次数=$FAIL2BAN_MAX_ATTEMPTS，封禁时长=$BAN_TIME 秒，查找时间窗口=$FIND_TIME 秒${RESET}"
                            read -p "请选择 Fail2Ban 操作：1) 查看封禁状态  2) 修改 Fail2Ban 参数  3) 管理封禁 IP（输入 1、2 或 3）： " fail2ban_choice
                            if [ "$fail2ban_choice" == "1" ]; then
                                # 查看封禁状态
                                echo -e "${GREEN}当前 Fail2Ban 封禁状态：${RESET}"
                                echo -e "----------------------------------------${RESET}"
                                if sudo fail2ban-client status sshd > /dev/null 2>&1; then
                                    sudo fail2ban-client status sshd
                                else
                                    echo -e "${RED}Fail2Ban 未正常运行，请检查服务状态！${RESET}"
                                fi
                                echo -e "${GREEN}----------------------------------------${RESET}"
                            elif [ "$fail2ban_choice" == "2" ]; then
                                # 修改 Fail2Ban 参数
                                echo -e "${YELLOW}请输入新的 Fail2Ban 参数（留空保留原值）：${RESET}"
                                read -p "请输入单 IP 允许的最大失败尝试次数 [当前 $FAIL2BAN_MAX_ATTEMPTS]： " fail2ban_max_attempts
                                fail2ban_max_attempts=${fail2ban_max_attempts:-$FAIL2BAN_MAX_ATTEMPTS}
                                read -p "请输入 IP 封禁时长（秒）[当前 $BAN_TIME]： " ban_time
                                ban_time=${ban_time:-$BAN_TIME}
                                read -p "请输入查找时间窗口（秒）[当前 $FIND_TIME]： " find_time
                                find_time=${find_time:-$FIND_TIME}

                                # 更新 Fail2Ban 配置
                                echo "FAIL2BAN_MAX_ATTEMPTS=$fail2ban_max_attempts" | sudo tee "$FAIL2BAN_CONFIG" > /dev/null
                                echo "BAN_TIME=$ban_time" | sudo tee -a "$FAIL2BAN_CONFIG" > /dev/null
                                echo "FIND_TIME=$find_time" | sudo tee -a "$FAIL2BAN_CONFIG" > /dev/null

                                # 更新 jail.local
                                sudo bash -c "cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = $ban_time
findtime = $find_time
maxretry = $fail2ban_max_attempts

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = $LOG_FILE
maxretry = $fail2ban_max_attempts
bantime = $ban_time
EOF"
                                echo -e "${GREEN}Fail2Ban 配置已更新至 $FAIL2BAN_CONFIG 和 /etc/fail2ban/jail.local${RESET}"
                                sudo systemctl restart fail2ban
                            elif [ "$fail2ban_choice" == "3" ]; then
                                # 管理封禁 IP
                                echo -e "${GREEN}当前 Fail2Ban 封禁状态：${RESET}"
                                echo -e "----------------------------------------${RESET}"
                                if sudo fail2ban-client status sshd > /dev/null 2>&1; then
                                    STATUS=$(sudo fail2ban-client status sshd)
                                    BANNED_IPS=$(echo "$STATUS" | grep "Banned IP list" | awk '{print $NF}')
                                    echo "$STATUS"
                                    echo -e "${GREEN}----------------------------------------${RESET}"
                                    if [ -n "$BANNED_IPS" ]; then
                                        echo -e "${YELLOW}已封禁的 IP：$BANNED_IPS${RESET}"
                                        read -p "请输入要解禁的 IP（留空取消）： " ip_to_unban
                                        if [ -n "$ip_to_unban" ]; then
                                            sudo fail2ban-client unban "$ip_to_unban"
                                            if [ $? -eq 0 ]; then
                                                echo -e "${GREEN}已成功解禁 IP：$ip_to_unban${RESET}"
                                            else
                                                echo -e "${RED}解禁 IP 失败，请检查输入！${RESET}"
                                            fi
                                        fi
                                    else
                                        echo -e "${YELLOW}暂无封禁 IP${RESET}"
                                        read -p "请输入要手动封禁的 IP（留空取消）： " ip_to_ban
                                        if [ -n "$ip_to_ban" ]; then
                                            sudo fail2ban-client ban "$ip_to_ban"
                                            if [ $? -eq 0 ]; then
                                                echo -e "${GREEN}已成功封禁 IP：$ip_to_ban${RESET}"
                                            else
                                                echo -e "${RED}封禁 IP 失败，请检查输入！${RESET}"
                                            fi
                                        fi
                                    fi
                                else
                                    echo -e "${RED}Fail2Ban 未正常运行，请检查服务状态！${RESET}"
                                    echo -e "${GREEN}----------------------------------------${RESET}"
                                fi
                            fi
                        fi
                        # 启动或重启 Fail2Ban 服务
                        sudo systemctl restart fail2ban
                        sudo systemctl enable fail2ban
                        read -p "按回车键继续检测暴力破解记录..."
                    fi
                fi

                # 计算时间范围的开始时间
                start_time=$(date -d "$DETECT_TIME minutes ago" +"%Y-%m-%d %H:%M:%S")

                # 检测并统计暴力破解尝试
                echo -e "${GREEN}正在分析日志文件：$LOG_FILE${RESET}"
                echo -e "${GREEN}检测时间范围：从 $start_time 到现在${RESET}"
                echo -e "${GREEN}可疑 IP 统计（尝试次数 >= $MAX_ATTEMPTS）："
                echo -e "----------------------------------------${RESET}"

                grep "Failed password" "$LOG_FILE" | awk -v start="$start_time" '
                {
                    log_time = substr($0, 1, 15)
                    ip = $(NF-3)
                    log_full_time = sprintf("%s %s", strftime("%Y"), log_time)
                    if (log_full_time >= start) {
                        attempts[ip]++
                        if (!last_time[ip] || log_full_time > last_time[ip]) {
                            last_time[ip] = log_full_time
                        }
                    }
                }
                END {
                    for (ip in attempts) {
                        if (attempts[ip] >= '"$MAX_ATTEMPTS"') {
                            printf "IP: %-15s 尝试次数: %-5d 最近尝试时间: %s\n", ip, attempts[ip], last_time[ip]
                        }
                    }
                }' | sort -k3 -nr

                echo -e "${GREEN}----------------------------------------${RESET}"
                echo -e "${YELLOW}提示：以上为疑似暴力破解的 IP 列表，未自动封禁。${RESET}"
                echo -e "${YELLOW}检测配置：最大尝试次数=$MAX_ATTEMPTS，统计时间范围=$DETECT_TIME 分钟，高风险阈值=$HIGH_RISK_THRESHOLD，常规扫描=$SCAN_INTERVAL 分钟，高风险扫描=$SCAN_INTERVAL_HIGH 分钟${RESET}"
                echo -e "${YELLOW}若需自动封禁或管理 IP，请使用选项 3 配置 Fail2Ban 或手动编辑 /etc/hosts.deny。${RESET}"
                read -p "按回车键返回主菜单..."
                ;;
            20)
                # Speedtest测速面板（基于 ALS - Another Looking-glass Server）
                echo -e "${GREEN}正在准备处理 Speedtest 测速面板...${RESET}"

                # 检查系统类型
                check_system
                if [ "$SYSTEM" == "unknown" ]; then
                    echo -e "${RED}无法识别系统，无法继续操作！${RESET}"
                    read -p "按回车键返回主菜单..."
                else
                    # 检测运行中的 Docker 服务
                    echo -e "${YELLOW}正在检测运行中的 Docker 服务...${RESET}"
                    DOCKER_RUNNING=false
                    if command -v docker > /dev/null 2>&1 && systemctl is-active docker > /dev/null 2>&1; then
                        DOCKER_RUNNING=true
                        echo -e "${YELLOW}检测到 Docker 服务正在运行${RESET}"
                        if docker ps -q | grep -q "."; then
                            echo -e "${YELLOW}检测到运行中的 Docker 容器${RESET}"
                        fi
                    fi

                    # 询问用户是否停止运行中的 Docker 服务
                    if [ "$DOCKER_RUNNING" = true ] && docker ps -q | grep -q "."; then
                        read -p "是否停止并移除运行中的 Docker 容器以继续安装？（y/n，默认 n）： " stop_containers
                        if [ "$stop_containers" == "y" ] || [ "$stop_containers" == "Y" ]; then
                            echo -e "${YELLOW}正在停止并移除运行中的 Docker 容器...${RESET}"
                            docker stop $(docker ps -q) || true
                            docker rm $(docker ps -aq) || true
                        else
                            echo -e "${RED}保留运行中的容器，可能导致安装冲突，建议手动清理后再试！${RESET}"
                        fi
                    fi

                    # 提示用户选择操作
                    echo -e "${YELLOW}请选择操作：${RESET}"
                    echo "1) 安装 Speedtest 测速面板"
                    echo "2) 卸载 Speedtest 测速面板"
                    read -p "请输入选项（1 或 2）： " operation_choice

                    case $operation_choice in
                        1)
                            # 安装 Speedtest 测速面板
                            echo -e "${GREEN}正在安装 Speedtest 测速面板...${RESET}"

                            # 检查端口占用并选择可用端口
                            DEFAULT_PORT=80
                            check_port() {
                                local port=$1
                                if netstat -tuln | grep ":$port" > /dev/null; then
                                    return 1
                                else
                                    return 0
                                fi
                            }

                            check_port "$DEFAULT_PORT"
                            if [ $? -eq 1 ]; then
                                echo -e "${RED}端口 $DEFAULT_PORT 已被占用！${RESET}"
                                read -p "是否更换端口？（y/n，默认 y）： " change_port
                                if [ "$change_port" != "n" ] && [ "$change_port" != "N" ]; then
                                    while true; do
                                        read -p "请输入新的端口号（例如 8080）： " new_port
                                        while ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; do
                                            echo -e "${RED}无效端口，请输入 1-65535 之间的数字！${RESET}"
                                            read -p "请输入新的端口号（例如 8080）： " new_port
                                        done
                                        check_port "$new_port"
                                        if [ $? -eq 0 ]; then
                                            DEFAULT_PORT=$new_port
                                            break
                                        else
                                            echo -e "${RED}端口 $new_port 已被占用，请选择其他端口！${RESET}"
                                        fi
                                    done
                                else
                                    echo -e "${RED}端口 $DEFAULT_PORT 被占用，无法继续安装！${RESET}"
                                    read -p "按回车键返回主菜单..."
                                    continue
                                fi
                            fi

                            # 检查并放行防火墙端口
                            if command -v ufw > /dev/null 2>&1; then
                                ufw status | grep -q "Status: active"
                                if [ $? -eq 0 ]; then
                                    echo -e "${YELLOW}检测到 UFW 防火墙正在运行...${RESET}"
                                    ufw status | grep -q "$DEFAULT_PORT"
                                    if [ $? -ne 0 ]; then
                                        echo -e "${YELLOW}正在放行端口 $DEFAULT_PORT...${RESET}"
                                        sudo ufw allow "$DEFAULT_PORT/tcp"
                                        sudo ufw reload
                                    fi
                                fi
                            elif command -v iptables > /dev/null 2>&1; then
                                echo -e "${YELLOW}检测到 iptables 防火墙...${RESET}"
                                iptables -C INPUT -p tcp --dport "$DEFAULT_PORT" -j ACCEPT 2>/dev/null
                                if [ $? -ne 0 ]; then
                                    echo -e "${YELLOW}正在放行端口 $DEFAULT_PORT...${RESET}"
                                    sudo iptables -A INPUT -p tcp --dport "$DEFAULT_PORT" -j ACCEPT
                                    sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
                                fi
                            fi

                            # 安装 Docker 和 Docker Compose
                            if ! command -v docker > /dev/null 2>&1; then
                                echo -e "${YELLOW}安装 Docker...${RESET}"
                                curl -fsSL https://get.docker.com | sh
                            fi
                            if ! command -v docker-compose > /dev/null 2>&1; then
                                echo -e "${YELLOW}安装 Docker Compose...${RESET}"
                                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                                chmod +x /usr/local/bin/docker-compose
                            fi

                            # 创建目录和配置 docker-compose.yml
                            cd /home && mkdir -p web && touch web/docker-compose.yml
                            sudo bash -c "cat > /home/web/docker-compose.yml <<EOF
version: '3'
services:
  als:
    image: wikihostinc/looking-glass-server:latest
    container_name: speedtest_panel
    ports:
      - \"$DEFAULT_PORT:80\"
    environment:
      - HTTP_PORT=$DEFAULT_PORT
    restart: always
    network_mode: host
EOF"

                            # 启动 Docker Compose
                            cd /home/web && docker-compose up -d

                            server_ip=$(curl -s4 ifconfig.me)
                            echo -e "${GREEN}Speedtest 测速面板安装完成！${RESET}"
                            echo -e "${YELLOW}访问 http://$server_ip:$DEFAULT_PORT 查看 Speedtest 测速面板${RESET}"
                            echo -e "${YELLOW}功能包括：HTML5 速度测试、Ping、iPerf3、Speedtest、下载测速、网卡流量监控、在线 Shell${RESET}"
                            ;;
                        2)
                            # 卸载 Speedtest 测速面板
                            echo -e "${GREEN}正在卸载 Speedtest 测速面板...${RESET}"
                            cd /home/web || true
                            if [ -f docker-compose.yml ]; then
                                docker-compose down -v || true
                                echo -e "${YELLOW}已停止并移除 Speedtest 测速面板容器和卷${RESET}"
                            fi
                            # 检查并移除任何名为 speedtest_panel 的容器
                            if docker ps -a | grep -q "speedtest_panel"; then
                                docker stop speedtest_panel || true
                                docker rm speedtest_panel || true
                                echo -e "${YELLOW}已移除独立的 speedtest_panel 容器${RESET}"
                            fi
                            sudo rm -rf /home/web
                            echo -e "${YELLOW}已删除 /home/web 目录${RESET}"
                            # 询问是否移除 ALS 镜像
                            if docker images | grep -q "wikihostinc/looking-glass-server"; then
                                read -p "是否移除 Speedtest 测速面板的 Docker 镜像（wikihostinc/looking-glass-server）？（y/n，默认 n）： " remove_image
                                if [ "$remove_image" == "y" ] || [ "$remove_image" == "Y" ]; then
                                    docker rmi wikihostinc/looking-glass-server:latest || true
                                    echo -e "${YELLOW}已移除 Speedtest 测速面板的 Docker 镜像${RESET}"
                                fi
                            fi
                            echo -e "${GREEN}Speedtest 测速面板卸载完成！${RESET}"
                            ;;
                        *)
                            echo -e "${RED}无效选项，请输入 1 或 2！${RESET}"
                            ;;
                    esac
                fi
                read -p "按回车键返回主菜单..."
                ;;
        esac
    done
}

# 运行主菜单
show_menu
