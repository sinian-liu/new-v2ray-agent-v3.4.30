
#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 主菜单
main_menu() {
    clear
    echo -e "${BLUE} Docker Management Menu ${NC}"
    echo -e "-------------------------------"
    echo -e "${GREEN}1.  安装更新Docker环境        ${NC}"
    echo -e "${GREEN}2.  查看Docker全局状态        ${NC}"
    echo -e "${GREEN}3.  Docker容器管理            ${NC}"
    echo -e "${GREEN}4.  Docker镜像管理            ${NC}"
    echo -e "${GREEN}5.  Docker网络管理            ${NC}"
    echo -e "${GREEN}6.  Docker卷管理              ${NC}"
    echo -e "${GREEN}7.  清理无用的docker容器和镜像网络数据卷 ${NC}"
    echo -e "${GREEN}8.  更换Docker源              ${NC}"
    echo -e "${GREEN}9.  编辑daemon.json文件       ${NC}"
    echo -e "${GREEN}11. 开启Docker-ipv6访问       ${NC}"
    echo -e "${GREEN}12. 关闭Docker-ipv6访问       ${NC}"
    echo -e "${GREEN}20. 卸载Docker环境            ${NC}"
    echo -e "-------------------------------"
    echo -e "请输入你的选择 (输入'0'退出): "
    read -r choice
    case $choice in
        1) install_docker ;;
        2) view_status ;;
        3) container_manage ;;
        4) image_manage ;;
        5) network_manage ;;
        6) volume_manage ;;
        7) clean_docker ;;
        8) change_source ;;
        9) edit_daemon ;;
        11) enable_ipv6 ;;
        12) disable_ipv6 ;;
        20) uninstall_docker ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择，请重新选择。${NC}" ;;
    esac
}

# 安装更新Docker环境
install_docker() {
    echo -e "${BLUE} 开始安装Docker环境... ${NC}"
    sudo apt-get update
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install docker-ce -y
    sudo systemctl start docker
    sudo systemctl enable docker
    echo -e "${GREEN} Docker安装完成。${NC}"
    main_menu
}

# 查看Docker全局状态
view_status() {
    echo -e "${BLUE} 查看Docker全局状态... ${NC}"
    docker info
    echo -e "${BLUE} 查看Docker服务状态... ${NC}"
    systemctl status docker
    main_menu
}

# Docker容器管理
container_manage() {
    echo -e "${BLUE} Docker容器管理 ${NC}"
    echo -e "1. 查看所有容器"
    echo -e "2. 启动容器"
    echo -e "3. 停止容器"
    echo -e "4. 重启容器"
    echo -e "5. 查看容器日志"
    echo -e "6. 查看容器详情"
    echo -e "7. 返回主菜单"
    read -p "请输入你的选择: " choice
    case $choice in
        1) echo -e "${BLUE} 查看所有容器... ${NC}" && docker ps -a ;;
        2) 
            echo -e "${BLUE} 启动容器... ${NC}"
            read -p "请输入容器名或ID: " container
            docker start $container
            ;;
        3) 
            echo -e "${BLUE} 停止容器... ${NC}"
            read -p "请输入容器名或ID: " container
            docker stop $container
            ;;
        4) 
            echo -e "${BLUE} 重启容器... ${NC}"
            read -p "请输入容器名或ID: " container
            docker restart $container
            ;;
        5) 
            echo -e "${BLUE} 查看容器日志... ${NC}"
            read -p "请输入容器名或ID: " container
            docker logs $container
            ;;
        6) 
            echo -e "${BLUE} 查看容器详情... ${NC}"
            read -p "请输入容器名或ID: " container
            docker inspect $container
            ;;
        7) main_menu ;;
        *) echo -e "${RED}无效选择，返回主菜单。${NC}" ;;
    esac
    container_manage
}

# Docker镜像管理
image_manage() {
    echo -e "${BLUE} Docker镜像管理 ${NC}"
    echo -e "1. 查看所有镜像"
    echo -e "2. 拉取镜像"
    echo -e "3. 删除镜像"
    echo -e "4. 查看镜像详情"
    echo -e "5. 返回主菜单"
    read -p "请输入你的选择: " choice
    case $choice in
        1) echo -e "${BLUE} 查看所有镜像... ${NC}" && docker images ;;
        2) 
            echo -e "${BLUE} 拉取镜像... ${NC}"
            read -p "请输入镜像名称（例如：nginx:latest）: " image
            docker pull $image
            ;;
        3) 
            echo -e "${BLUE} 删除镜像... ${NC}"
            read -p "请输入镜像名或ID: " image
            docker rmi $image
            ;;
        4) 
            echo -e "${BLUE} 查看镜像详情... ${NC}"
            read -p "请输入镜像名或ID: " image
            docker inspect $image
            ;;
        5) main_menu ;;
        *) echo -e "${RED}无效选择，返回主菜单。${NC}" ;;
    esac
    image_manage
}

# Docker网络管理
network_manage() {
    echo -e "${BLUE} Docker网络管理 ${NC}"
    echo -e "1. 查看所有网络"
    echo -e "2. 创建网络"
    echo -e "3. 删除网络"
    echo -e "4. 查看网络详情"
    echo -e "5. 返回主菜单"
    read -p "请输入你的选择: " choice
    case $choice in
        1) echo -e "${BLUE} 查看所有网络... ${NC}" && docker network ls ;;
        2) 
            echo -e "${BLUE} 创建网络... ${NC}"
            read -p "请输入网络名称: " network_name
            docker network create $network_name
            ;;
        3) 
            echo -e "${BLUE} 删除网络... ${NC}"
            read -p "请输入网络名称或ID: " network
            docker network rm $network
            ;;
        4) 
            echo -e "${BLUE} 查看网络详情... ${NC}"
            read -p "请输入网络名称或ID: " network
            docker network inspect $network
            ;;
        5) main_menu ;;
        *) echo -e "${RED}无效选择，返回主菜单。${NC}" ;;
    esac
    network_manage
}

# Docker卷管理
volume_manage() {
    echo -e "${BLUE} Docker卷管理 ${NC}"
    echo -e "1. 查看所有卷"
    echo -e "2. 创建卷"
    echo -e "3. 删除卷"
    echo -e "4. 查看卷详情"
    echo -e "5. 返回主菜单"
    read -p "请输入你的选择: " choice
    case $choice in
        1) echo -e "${BLUE} 查看所有卷... ${NC}" && docker volume ls ;;
        2) 
            echo -e "${BLUE} 创建卷... ${NC}"
            read -p "请输入卷名称: " volume_name
            docker volume create $volume_name
            ;;
        3) 
            echo -e "${BLUE} 删除卷... ${NC}"
            read -p "请输入卷名称或ID: " volume
            docker volume rm $volume
            ;;
        4) 
            echo -e "${BLUE} 查看卷详情... ${NC}"
            read -p "请输入卷名称或ID: " volume
            docker volume inspect $volume
            ;;
        5) main_menu ;;
        *) echo -e "${RED}无效选择，返回主菜单。${NC}" ;;
    esac
    volume_manage
}

# 清理无用的docker容器和镜像网络数据卷
clean_docker() {
    echo -e "${BLUE} 清理无用的docker容器、镜像、网络、数据卷... ${NC}"
    echo -e "${YELLOW} 注意：这将删除所有停止的容器、未使用的镜像、网络和卷。${NC}"
    read -p "确认是否继续？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e "${BLUE} 删除停止的容器... ${NC}"
        docker container prune -f
        echo -e "${BLUE} 删除悬置的镜像... ${NC}"
        docker image prune -a -f
        echo -e "${BLUE} 删除未使用的网络... ${NC}"
        docker network prune -f
        echo -e "${BLUE} 删除未使用的卷... ${NC}"
        docker volume prune -f
        echo -e "${GREEN} 清理完成。${NC}"
    else
        echo -e "${BLUE} 清理已取消。${NC}"
    fi
    main_menu
}

# 更换Docker源
change_source() {
    echo -e "${BLUE} 更换Docker源 ${NC}"
    echo -e "1. 使用官方源"
    echo -e "2. 使用阿里云镜像加速器"
    echo -e "3. 使用腾讯云镜像加速器"
    echo -e "4. 使用华为云镜像加速器"
    echo -e "5. 返回主菜单"
    read -p "请输入你的选择: " choice
    case $choice in
        1) 
            echo -e "${BLUE} 使用官方源... ${NC}"
            sudo sed -i '/download.docker.com/d' /etc/docker/daemon.json
            ;;
        2) 
            echo -e "${BLUE} 使用阿里云镜像加速器... ${NC}"
            sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://<your-accelerator-address>.mirror.aliyuncs.com"]
}
EOF
            ;;
        3) 
            echo -e "${BLUE} 使用腾讯云镜像加速器... ${NC}"
            sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
EOF
            ;;
        4) 
            echo -e "${BLUE} 使用华为云镜像加速器... ${NC}"
            sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://mirror.huaweicloud.com"]
}
EOF
            ;;
        5) main_menu ;;
        *) echo -e "${RED}无效选择，返回主菜单。${NC}" ;;
    esac
    echo -e "${BLUE} 请重新启动Docker服务以应用更改... ${NC}"
    sudo systemctl restart docker
    main_menu
}

# 编辑daemon.json文件
edit_daemon() {
    echo -e "${BLUE} 编辑daemon.json文件 ${NC}"
    if [ -f "/etc/docker/daemon.json" ]; then
        sudo nano /etc/docker/daemon.json
    else
        echo -e "${YELLOW} daemon.json文件不存在，创建新的文件... ${NC}"
        sudo nano /etc/docker/daemon.json
    fi
    echo -e "${BLUE} 请重新启动Docker服务以应用更改... ${NC}"
    sudo systemctl restart docker
    main_menu
}

# 开启Docker-ipv6访问
enable_ipv6() {
    echo -e "${BLUE} 开启Docker-ipv6访问 ${NC}"
    if [ -f "/etc/docker/daemon.json" ]; then
        sudo sed -i 's/"/{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"/g' /etc/docker/daemon.json
    else
        echo -e "${YELLOW} daemon.json文件不存在，创建新的文件... ${NC}"
        sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "ipv6": true,
    "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
    fi
    echo -e "${BLUE} 请重新启动Docker服务以应用更改... ${NC}"
    sudo systemctl restart docker
    main_menu
}

# 关闭Docker-ipv6访问
disable_ipv6() {
    echo -e "${BLUE} 关闭Docker-ipv6访问 ${NC}"
    if [ -f "/etc/docker/daemon.json" ]; then
        sudo sed -i 's/"ipv6": true/"ipv6": false/g' /etc/docker/daemon.json
    else
        echo -e "${YELLOW} daemon.json文件不存在，创建新的文件... ${NC}"
        sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "ipv6": false
}
EOF
    fi
    echo -e "${BLUE} 请重新启动Docker服务以应用更改... ${NC}"
    sudo systemctl restart docker
    main_menu
}

# 卸载Docker环境
uninstall_docker() {
    echo -e "${BLUE} 卸载Docker环境 ${NC}"
    echo -e "${YELLOW} 注意：这将完全删除Docker及其所有数据。${NC}"
    read -p "确认是否继续？(y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e "${BLUE} 停止Docker服务... ${NC}"
        sudo systemctl stop docker
        echo -e "${BLUE} 删除Docker服务... ${NC}"
        sudo systemctl disable docker
        echo -e "${BLUE} 卸载Docker软件包... ${NC}"
        sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx docker-compose dockerscan docker-cli
        echo -e "${BLUE} 删除Docker数据目录... ${NC}"
        sudo rm -rf /var/lib/docker
        echo -e "${GREEN} Docker环境卸载完成。${NC}"
    else
        echo -e "${BLUE} 卸载已取消。${NC}"
    fi
    main_menu
}

# 运行主菜单
main_menu
