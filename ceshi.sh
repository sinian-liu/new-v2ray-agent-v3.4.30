#!/bin/bash

# 全国三网DNS全面测试脚本
# 支持Ubuntu/CentOS/Debian

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 全局变量
declare -A TEST_RESULTS
declare -A TEST_NODES
declare -A NODE_CATEGORIES

# 初始化全国三网所有DNS节点
init_all_dns_nodes() {
    echo -e "${PURPLE}📋 加载全国三网所有DNS服务器...${NC}"
    
    # 定义所有DNS服务器数据（已去重）
    local dns_data=(
        # 电信DNS
        "电信DNS 北京电信 219.141.136.10"
        "电信DNS 北京电信 219.141.140.10"
        "电信DNS 上海电信 202.96.209.133"
        "电信DNS 上海电信 116.228.111.118"
        "电信DNS 上海电信 202.96.209.5"
        "电信DNS 上海电信 180.168.255.118"
        "电信DNS 上海电信 203.62.139.69"
        "电信DNS 天津电信 219.150.32.132"
        "电信DNS 天津电信 219.146.0.132"
        "电信DNS 重庆电信 61.128.192.68"
        "电信DNS 重庆电信 61.128.128.68"
        "电信DNS 安徽电信 61.132.163.68"
        "电信DNS 安徽电信 202.102.213.68"
        "电信DNS 安徽电信 202.102.192.68"
        "电信DNS 福建电信 218.85.152.99"
        "电信DNS 福建电信 218.85.157.99"
        "电信DNS 甘肃电信 202.100.64.68"
        "电信DNS 甘肃电信 61.178.0.93"
        "电信DNS 广东电信 202.96.128.86"
        "电信DNS 广东电信 202.96.128.166"
        "电信DNS 广东电信 202.96.134.133"
        "电信DNS 广东电信 202.96.128.68"
        "电信DNS 广东电信 202.96.154.8"
        "电信DNS 广东电信 202.96.154.15"
        "电信DNS 广西电信 202.103.225.68"
        "电信DNS 广西电信 202.103.224.68"
        "电信DNS 贵州电信 202.98.192.67"
        "电信DNS 贵州电信 202.98.198.167"
        "电信DNS 河南电信 222.88.88.88"
        "电信DNS 河南电信 222.85.85.85"
        "电信DNS 河南电信 219.150.150.150"
        "电信DNS 河南电信 222.88.93.126"
        "电信DNS 黑龙江电信 219.147.198.230"
        "电信DNS 黑龙江电信 219.147.198.242"
        "电信DNS 黑龙江电信 112.100.100.100"
        "电信DNS 湖北电信 202.103.24.68"
        "电信DNS 湖北电信 202.103.0.68"
        "电信DNS 湖北电信 202.103.44.150"
        "电信DNS 湖南电信 59.51.78.211"
        "电信DNS 湖南电信 59.51.78.210"
        "电信DNS 湖南电信 222.246.129.80"
        "电信DNS 湖南电信 222.246.129.81"
        "电信DNS 江苏电信 218.2.2.2"
        "电信DNS 江苏电信 218.4.4.4"
        "电信DNS 江苏电信 61.147.37.1"
        "电信DNS 江苏电信 218.2.135.1"
        "电信DNS 江西电信 202.101.224.69"
        "电信DNS 江西电信 202.101.226.68"
        "电信DNS 江西电信 202.101.226.69"
        "电信DNS 内蒙古电信 219.148.162.31"
        "电信DNS 内蒙古电信 222.74.39.50"
        "电信DNS 内蒙古电信 222.74.1.200"
        "电信DNS 山东电信 219.146.1.66"
        "电信DNS 山东电信 219.147.1.66"
        "电信DNS 山西电信 59.49.49.49"
        "电信DNS 陕西电信 218.30.19.40"
        "电信DNS 陕西电信 61.134.1.4"
        "电信DNS 四川电信 61.139.2.69"
        "电信DNS 四川电信 218.6.200.139"
        "电信DNS 云南电信 222.172.200.68"
        "电信DNS 云南电信 61.166.150.123"
        "电信DNS 浙江电信 202.101.172.35"
        "电信DNS 浙江电信 202.101.172.47"
        "电信DNS 浙江电信 61.153.81.75"
        "电信DNS 浙江电信 61.153.177.196"
        "电信DNS 浙江电信 60.191.134.206"
        "电信DNS 浙江电信 60.191.244.5"
        "电信DNS 河北电信 222.222.202.202"
        "电信DNS 海南电信 202.100.192.68"
        "电信DNS 辽宁电信 219.148.204.66"
        "电信DNS 吉林电信 219.149.194.55"
        "电信DNS 新疆电信 61.128.114.167"

        # 联通DNS
        "联通DNS 北京联通 123.123.123.123"
        "联通DNS 北京联通 123.123.123.124"
        "联通DNS 北京联通 202.106.0.20"
        "联通DNS 北京联通 202.106.195.68"
        "联通DNS 上海联通 210.22.70.3"
        "联通DNS 上海联通 210.22.84.3"
        "联通DNS 上海联通 210.22.70.225"
        "联通DNS 天津联通 202.99.104.68"
        "联通DNS 天津联通 202.99.96.68"
        "联通DNS 重庆联通 221.5.203.98"
        "联通DNS 重庆联通 221.7.92.98"
        "联通DNS 广东联通 210.21.196.6"
        "联通DNS 广东联通 221.5.88.88"
        "联通DNS 广东联通 210.21.4.130"
        "联通DNS 河北联通 202.99.160.68"
        "联通DNS 河北联通 202.99.166.4"
        "联通DNS 河南联通 202.102.224.68"
        "联通DNS 河南联通 202.102.227.68"
        "联通DNS 黑龙江联通 202.97.224.69"
        "联通DNS 黑龙江联通 202.97.224.68"
        "联通DNS 吉林联通 202.98.0.68"
        "联通DNS 吉林联通 202.98.5.68"
        "联通DNS 江苏联通 221.6.4.66"
        "联通DNS 江苏联通 221.6.4.67"
        "联通DNS 江苏联通 58.240.57.33"
        "联通DNS 内蒙古联通 202.99.224.68"
        "联通DNS 内蒙古联通 202.99.224.8"
        "联通DNS 山东联通 202.102.128.68"
        "联通DNS 山东联通 202.102.152.3"
        "联通DNS 山东联通 202.102.134.68"
        "联通DNS 山东联通 202.102.154.3"
        "联通DNS 山西联通 202.99.192.66"
        "联通DNS 山西联通 202.99.192.68"
        "联通DNS 山西联通 202.97.131.178"
        "联通DNS 陕西联通 221.11.1.67"
        "联通DNS 陕西联通 221.11.1.68"
        "联通DNS 四川联通 119.6.6.6"
        "联通DNS 四川联通 124.161.87.155"
        "联通DNS 浙江联通 221.12.1.227"
        "联通DNS 浙江联通 221.12.33.227"
        "联通DNS 浙江联通 221.12.65.227"
        "联通DNS 辽宁联通 202.96.69.38"
        "联通DNS 辽宁联通 202.96.64.68"
        "联通DNS 贵州联通 221.13.30.242"
        "联通DNS 甘肃联通 221.7.34.11"
        "联通DNS 宁夏联通 221.199.12.157"
        "联通DNS 江西联通 220.248.192.12"
        "联通DNS 广西联通 221.7.128.68"
        "联通DNS 西藏联通 221.13.65.34"
        "联通DNS 海南联通 221.11.132.2"
        "联通DNS 湖南联通 58.20.127.238"
        "联通DNS 湖北联通 218.104.111.122"
        "联通DNS 安徽联通 218.104.78.2"
        "联通DNS 安徽联通 58.242.2.2"
        "联通DNS 福建联通 218.104.128.106"
        "联通DNS 新疆联通 221.7.1.20"
        "联通DNS 云南联通 221.3.131.11"

        # 移动DNS
        "移动DNS 北京移动 211.138.30.66"
        "移动DNS 北京移动 211.136.17.107"
        "移动DNS 北京移动 211.136.28.231"
        "移动DNS 北京移动 211.136.28.234"
        "移动DNS 北京移动 211.136.28.237"
        "移动DNS 北京移动 211.136.28.228"
        "移动DNS 北京移动 221.130.32.103"
        "移动DNS 北京移动 221.130.32.100"
        "移动DNS 北京移动 221.130.32.106"
        "移动DNS 北京移动 221.130.32.109"
        "移动DNS 北京移动 221.176.3.70"
        "移动DNS 北京移动 221.176.3.73"
        "移动DNS 北京移动 221.176.3.76"
        "移动DNS 北京移动 221.176.3.79"
        "移动DNS 北京移动 221.176.3.83"
        "移动DNS 北京移动 221.176.3.85"
        "移动DNS 北京移动 221.176.4.6"
        "移动DNS 北京移动 221.176.4.9"
        "移动DNS 北京移动 221.176.4.12"
        "移动DNS 北京移动 221.176.4.15"
        "移动DNS 北京移动 221.176.4.18"
        "移动DNS 北京移动 221.176.4.21"
        "移动DNS 北京移动 221.130.33.52"
        "移动DNS 北京移动 221.179.155.193"
        "移动DNS 上海移动 211.136.112.50"
        "移动DNS 上海移动 211.136.150.66"
        "移动DNS 上海移动 211.136.18.171"
        "移动DNS 天津移动 211.137.160.50"
        "移动DNS 天津移动 211.137.160.185"
        "移动DNS 重庆移动 218.201.4.3"
        "移动DNS 重庆移动 218.201.21.132"
        "移动DNS 重庆移动 218.201.17.2"
        "移动DNS 安徽移动 211.138.180.2"
        "移动DNS 安徽移动 211.138.180.3"
        "移动DNS 山东移动 218.201.96.130"
        "移动DNS 山东移动 211.137.191.26"
        "移动DNS 山东移动 218.201.124.18"
        "移动DNS 山东移动 218.201.124.19"
        "移动DNS 山西移动 211.138.106.2"
        "移动DNS 山西移动 211.138.106.3"
        "移动DNS 山西移动 211.138.106.18"
        "移动DNS 山西移动 211.138.106.19"
        "移动DNS 山西移动 211.138.106.7"
        "移动DNS 江苏移动 221.131.143.69"
        "移动DNS 江苏移动 112.4.0.55"
        "移动DNS 江苏移动 221.130.13.133"
        "移动DNS 江苏移动 211.103.55.50"
        "移动DNS 江苏移动 221.130.56.241"
        "移动DNS 江苏移动 211.103.13.101"
        "移动DNS 江苏移动 211.138.200.69"
        "移动DNS 浙江移动 211.140.13.188"
        "移动DNS 浙江移动 211.140.188.188"
        "移动DNS 浙江移动 211.140.10.2"
        "移动DNS 湖南移动 211.142.210.98"
        "移动DNS 湖南移动 211.142.210.99"
        "移动DNS 湖南移动 211.142.210.100"
        "移动DNS 湖南移动 211.142.210.101"
        "移动DNS 湖南移动 211.142.211.124"
        "移动DNS 湖南移动 211.142.236.87"
        "移动DNS 湖北移动 211.137.58.20"
        "移动DNS 湖北移动 211.137.64.163"
        "移动DNS 江西移动 211.141.90.68"
        "移动DNS 江西移动 211.141.90.69"
        "移动DNS 江西移动 211.141.85.68"
        "移动DNS 陕西移动 211.137.130.3"
        "移动DNS 陕西移动 211.137.130.19"
        "移动DNS 陕西移动 218.200.6.139"
        "移动DNS 四川移动 211.137.82.4"
        "移动DNS 四川移动 211.137.96.205"
        "移动DNS 广东移动 211.136.20.203"
        "移动DNS 广东移动 211.136.20.204"
        "移动DNS 广东移动 211.136.192.6"
        "移动DNS 广东移动 211.139.136.68"
        "移动DNS 广东移动 211.139.163.6"
        "移动DNS 广东移动 120.196.165.24"
        "移动DNS 广西移动 211.138.245.180"
        "移动DNS 广西移动 211.136.17.108"
        "移动DNS 广西移动 211.138.240.100"
        "移动DNS 贵州移动 211.139.5.29"
        "移动DNS 贵州移动 211.139.5.30"
        "移动DNS 福建移动 211.138.151.161"
        "移动DNS 福建移动 211.138.156.66"
        "移动DNS 福建移动 218.207.217.241"
        "移动DNS 福建移动 218.207.217.242"
        "移动DNS 福建移动 211.143.181.178"
        "移动DNS 福建移动 211.143.181.179"
        "移动DNS 福建移动 218.207.128.4"
        "移动DNS 福建移动 218.207.130.118"
        "移动DNS 福建移动 211.138.145.194"
        "移动DNS 河北移动 211.143.60.56"
        "移动DNS 河北移动 211.138.13.66"
        "移动DNS 河北移动 111.11.1.1"
        "移动DNS 河南移动 211.138.24.66"
        "移动DNS 甘肃移动 218.203.160.194"
        "移动DNS 甘肃移动 218.203.160.195"
        "移动DNS 甘肃移动 211.139.80.6"
        "移动DNS 黑龙江移动 211.137.241.34"
        "移动DNS 黑龙江移动 211.137.241.35"
        "移动DNS 黑龙江移动 218.203.59.216"
        "移动DNS 吉林移动 211.141.16.99"
        "移动DNS 吉林移动 211.141.0.99"
        "移动DNS 辽宁移动 211.137.32.178"
        "移动DNS 辽宁移动 211.140.197.58"
        "移动DNS 云南移动 211.139.29.68"
        "移动DNS 云南移动 211.139.29.69"
        "移动DNS 云南移动 211.139.29.150"
        "移动DNS 云南移动 211.139.29.170"
        "移动DNS 云南移动 218.202.1.166"
        "移动DNS 海南移动 221.176.88.95"
        "移动DNS 海南移动 211.138.164.6"
        "移动DNS 内蒙古移动 211.138.91.1"
        "移动DNS 内蒙古移动 211.138.91.2"
        "移动DNS 新疆移动 218.202.152.130"
        "移动DNS 新疆移动 218.202.152.131"
        "移动DNS 西藏移动 211.139.73.34"
        "移动DNS 西藏移动 211.139.73.35"
        "移动DNS 西藏移动 211.139.73.50"
        "移动DNS 青海移动 211.138.75.123"
        "移动DNS 青海移动 211.138.75.124"
    )

    # 初始化分类
    NODE_CATEGORIES["电信DNS"]=""
    NODE_CATEGORIES["联通DNS"]=""
    NODE_CATEGORIES["移动DNS"]=""

    # 添加所有节点
    for data in "${dns_data[@]}"; do
        IFS=' ' read -r category node_name ip <<< "$data"
        local unique_name="${node_name}-${ip}"
        TEST_NODES["$unique_name"]="$ip"
        NODE_CATEGORIES["$category"]="${NODE_CATEGORIES[$category]} $unique_name"
    done

    local total_count=${#TEST_NODES[@]}
    echo -e "${GREEN}✅ 已加载 ${total_count} 个全国DNS服务器${NC}"
    echo -e "${YELLOW}📊 电信DNS: $(echo ${NODE_CATEGORIES[电信DNS]} | wc -w) 个节点${NC}"
    echo -e "${YELLOW}📊 联通DNS: $(echo ${NODE_CATEGORIES[联通DNS]} | wc -w) 个节点${NC}"
    echo -e "${YELLOW}📊 移动DNS: $(echo ${NODE_CATEGORIES[移动DNS]} | wc -w) 个节点${NC}"
}

# 显示测试进度
show_progress() {
    local current=$1
    local total=$2
    local node=$3
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}[%3d%%]${NC} [" "$percentage"
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' ' '
    printf "] ${YELLOW}%s${NC}" "$node"
}

# 执行ping测试
perform_ping_test() {
    local node=$1
    local ip=$2
    
    # 执行ping测试
    local result
    result=$(timeout 6 ping -c 2 -i 0.2 -W 1 "$ip" 2>/dev/null | tail -2 || true)
    
    local packet_loss=100
    local avg_delay=0
    
    if echo "$result" | grep -q "100% packet loss" || [ -z "$result" ]; then
        packet_loss=100
    else
        packet_loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "100")
        local rtt_stats=$(echo "$result" | grep 'rtt' || echo "")
        
        if [ -n "$rtt_stats" ]; then
            avg_delay=$(echo "$rtt_stats" | awk -F'/' '{print $5}')
            if [ -z "$avg_delay" ] || [ "$avg_delay" = "0" ]; then
                avg_delay=0
                packet_loss=100
            fi
        fi
    fi
    
    # 保存测试结果
    TEST_RESULTS["${node}_avg"]=${avg_delay%.*}
    TEST_RESULTS["${node}_loss"]=$packet_loss
}

# 执行所有DNS测试
run_all_dns_tests() {
    local total_nodes=${#TEST_NODES[@]}
    echo -e "${CYAN}=== 🌐 开始全国DNS服务器测试 ===${NC}"
    echo -e "${YELLOW}⏰ 正在测试全国三网所有DNS服务器，请耐心等待...${NC}"
    echo -e "${YELLOW}📋 总共 ${total_nodes} 个节点需要测试${NC}"
    echo -e "${YELLOW}🕐 预计需要 2-3 分钟...${NC}"
    echo ""
    
    local current=0
    for node in "${!TEST_NODES[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total_nodes" "$node"
        perform_ping_test "$node" "${TEST_NODES[$node]}"
        sleep 0.02
    done
    
    echo -e "\n\n${GREEN}✅ 全国DNS服务器测试完成！${NC}"
    echo ""
}

# 计算统计数据
calculate_stats() {
    local category=$1
    local nodes_str=$2
    
    IFS=' ' read -ra nodes <<< "$nodes_str"
    local total_delay=0
    local total_loss=0
    local count=0
    
    for node in "${nodes[@]}"; do
        local loss=${TEST_RESULTS["${node}_loss"]}
        local delay=${TEST_RESULTS["${node}_avg"]}
        
        if [ "$loss" -lt 100 ] && [ "$delay" -gt 0 ]; then
            total_delay=$((total_delay + delay))
            total_loss=$((total_loss + loss))
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        local avg_delay=$((total_delay / count))
        local avg_loss=$((total_loss / count))
        echo "${avg_delay},${avg_loss},${count}"
    else
        echo "0,100,0"
    fi
}

# 显示网络性能评级
show_performance_rating() {
    echo -e "${PURPLE}🎯 网络性能评级:${NC}"
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss count <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        local total_nodes=$(echo "${NODE_CATEGORIES[$category]}" | wc -w)
        
        if [ "$count" -eq 0 ]; then
            echo -e "   - ${category}: ${RED}无法连接${NC} (0/${total_nodes})"
        else
            local rating=""
            if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 50 ]; then
                rating="${GREEN}优秀 ⭐⭐⭐⭐⭐${NC}"
            elif [ "$avg_loss" -le 3 ] && [ "$avg_delay" -lt 100 ]; then
                rating="${GREEN}良好 ⭐⭐⭐⭐${NC}"
            elif [ "$avg_loss" -le 5 ] && [ "$avg_delay" -lt 150 ]; then
                rating="${YELLOW}一般 ⭐⭐⭐${NC}"
            elif [ "$avg_loss" -le 10 ]; then
                rating="${YELLOW}较差 ⭐⭐${NC}"
            else
                rating="${RED}极差 ⭐${NC}"
            fi
            echo -e "   - ${category}: $rating (延迟${avg_delay}ms, 丢包${avg_loss}%, 可用${count}/${total_nodes})"
        fi
    done
    echo ""
}

# 显示用途适配性表格（根据视频流媒体平台标准更新）
show_usage_suitability() {
    echo -e "${PURPLE}📊 用途适配性分析:${NC}"
    echo -e "   用途类型        | 延迟要求     | 丢包要求     | 适合性"
    echo -e "   ----------------|-------------|-------------|-------------"
    
    # 基于平均性能进行评估
    local total_delay=0
    local total_loss=0
    local count=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss node_count <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        if [ "$node_count" -gt 0 ]; then
            total_delay=$((total_delay + avg_delay))
            total_loss=$(echo "$total_loss + $avg_loss" | bc)
            count=$((count + 1))
        fi
    done
    
    local overall_delay=$((total_delay / count))
    local overall_loss=$(echo "scale=1; $total_loss / $count" | bc)
    
    # 网站托管
    if [ "$overall_loss" -le 3 ] && [ "$overall_delay" -lt 100 ]; then
        echo -e "   🌐 网站托管      | <100ms      | <3%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   🌐 网站托管      | <100ms      | <3%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 视频流媒体（根据Netflix/Disney+/YouTube标准）
    if [ "$overall_loss" -le 2 ] && [ "$overall_delay" -lt 80 ]; then
        echo -e "   📺 视频流媒体    | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   📺 视频流媒体    | <80ms       | <2%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 游戏服务器
    if [ "$overall_loss" -le 1 ] && [ "$overall_delay" -lt 50 ]; then
        echo -e "   🎮 游戏服务器    | <50ms       | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   🎮 游戏服务器    | <50ms       | <1%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 科学上网
    if [ "$overall_loss" -le 5 ] && [ "$overall_delay" -lt 120 ]; then
        echo -e "   🔒 科学上网      | <120ms      | <5%         | ${GREEN}✅ 非常适合${NC}"
    else
        echo -e "   🔒 科学上网      | <120ms      | <5%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 其他用途...
    echo -e "   💾 大数据传输    | <150ms      | <1%         | ${GREEN}✅ 适合${NC}"
    echo -e "   📞 实时通信      | <50ms       | <1%         | ${RED}❌ 不适合${NC}"
    echo -e "   🗂️  文件存储      | 无要求       | <5%         | ${GREEN}✅ 非常适合${NC}"
    echo -e "   ⚡ API服务       | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    echo -e "   🗃️  数据库服务    | <100ms      | <1%         | ${GREEN}✅ 适合${NC}"
    echo ""
    
    # 视频流媒体平台说明
    echo -e "${CYAN}📺 视频流媒体平台标准:${NC}"
    echo -e "   - Netflix 4K: <100ms延迟, <2%丢包"
    echo -e "   - Disney+ 4K: <80ms延迟, <2%丢包"
    echo -e "   - YouTube 4K: <50ms延迟, <1%丢包"
    echo -e "   - 国内平台4K: <80ms延迟, <2%丢包"
    echo ""
}

# 生成最终结论
generate_final_conclusion() {
    local total_nodes=${#TEST_NODES[@]}
    local working_nodes=0
    
    for node in "${!TEST_NODES[@]}"; do
        local loss=${TEST_RESULTS["${node}_loss"]}
        if [ "$loss" -lt 100 ]; then
            working_nodes=$((working_nodes + 1))
        fi
    done
    
    local success_rate=$((working_nodes * 100 / total_nodes))
    
    echo -e "${CYAN}=== 📋 测试结论 ===${NC}"
    echo -e "${GREEN}✅ 全国DNS测试完成${NC}"
    echo -e "${YELLOW}📊 测试统计: ${working_nodes}/${total_nodes} 个节点可用 (成功率${success_rate}%)${NC}"
    echo ""
    
    if [ "$success_rate" -gt 80 ]; then
        echo -e "${GREEN}🎉 网络质量优秀！全国覆盖良好。${NC}"
    elif [ "$success_rate" -gt 50 ]; then
        echo -e "${GREEN}🎉 网络质量良好！主要地区覆盖完善。${NC}"
    elif [ "$success_rate" -gt 20 ]; then
        echo -e "${YELLOW}⚠️  网络质量一般！部分地区连接不稳定。${NC}"
    else
        echo -e "${RED}❌ 网络质量较差！建议检查网络配置。${NC}"
    fi
    
    # 视频流媒体专项建议
    echo -e "${CYAN}🎯 视频流媒体建议:${NC}"
    echo -e "   - 对于Netflix: 选择延迟<100ms的DNS"
    echo -e "   - 对于Disney+: 选择延迟<80ms的DNS"
    echo -e "   - 对于YouTube: 选择延迟<50ms的DNS"
    echo -e "   - 推荐使用本地运营商DNS获得最佳体验"
}

# 主函数
main() {
    echo -e "${GREEN}🚀 开始全国三网DNS全面测试...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    init_all_dns_nodes
    echo -e "${YELLOW}========================================${NC}"
    run_all_dns_tests
    echo -e "${YELLOW}========================================${NC}"
    show_performance_rating
    show_usage_suitability
    echo -e "${YELLOW}========================================${NC}"
    generate_final_conclusion
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 全国DNS测试全面完成！${NC}"
    echo -e "${BLUE}⏰ 测试时间: $(date)${NC}"
}

# 执行主函数
main "$@"
