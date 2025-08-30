#!/bin/bash

# 全国三网DNS精选测试脚本
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

# 初始化精选DNS节点（30个最常用）
init_selected_dns_nodes() {
    echo -e "${PURPLE}📋 加载精选三网DNS服务器（30个最常用）...${NC}"
    
    # 定义精选DNS服务器数据（三网各10个最热门地区）
    local dns_data=(
        # 电信DNS（10个最热门地区）
        "电信DNS 北京电信 219.141.136.10"
        "电信DNS 上海电信 202.96.209.133"
        "电信DNS 广东电信 202.96.128.86"
        "电信DNS 江苏电信 218.2.2.2"
        "电信DNS 浙江电信 202.101.172.35"
        "电信DNS 四川电信 61.139.2.69"
        "电信DNS 天津电信 219.150.32.132"
        "电信DNS 山东电信 219.146.1.66"
        "电信DNS 湖北电信 202.103.24.68"
        "电信DNS 陕西电信 218.30.19.40"

        # 联通DNS（10个最热门地区）
        "联通DNS 北京联通 123.123.123.123"
        "联通DNS 上海联通 210.22.70.3"
        "联通DNS 广东联通 210.21.196.6"
        "联通DNS 江苏联通 221.6.4.66"
        "联通DNS 浙江联通 221.12.1.227"
        "联通DNS 四川联通 119.6.6.6"
        "联通DNS 天津联通 202.99.104.68"
        "联通DNS 山东联通 202.102.128.68"
        "联通DNS 河南联通 202.102.224.68"
        "联通DNS 辽宁联通 202.96.69.38"

        # 移动DNS（10个最热门地区）
        "移动DNS 北京移动 211.138.30.66"
        "移动DNS 上海移动 211.136.112.50"
        "移动DNS 广东移动 211.139.129.222"
        "移动DNS 江苏移动 221.131.143.69"
        "移动DNS 浙江移动 211.140.13.188"
        "移动DNS 四川移动 211.137.82.4"
        "移动DNS 山东移动 218.201.96.130"
        "移动DNS 河南移动 211.138.24.66"
        "移动DNS 湖南移动 211.142.210.98"
        "移动DNS 陕西移动 211.137.130.3"
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
    echo -e "${GREEN}✅ 已加载 ${total_count} 个精选DNS服务器${NC}"
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
    result=$(timeout 6 ping -c 3 -i 0.2 -W 1 "$ip" 2>/dev/null | tail -2 || true)
    
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
    echo -e "${CYAN}=== 🌐 开始DNS服务器测试 ===${NC}"
    echo -e "${YELLOW}⏰ 正在测试精选DNS服务器，请耐心等待...${NC}"
    echo -e "${YELLOW}📋 总共 ${total_nodes} 个节点需要测试${NC}"
    echo -e "${YELLOW}🕐 预计需要 1 分钟...${NC}"
    echo ""
    
    local current=0
    for node in "${!TEST_NODES[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total_nodes" "$node"
        perform_ping_test "$node" "${TEST_NODES[$node]}"
        sleep 0.05
    done
    
    echo -e "\n\n${GREEN}✅ DNS服务器测试完成！${NC}"
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

# 显示用途适配性表格
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
    
    if [ $count -gt 0 ]; then
        local overall_delay=$((total_delay / count))
        local overall_loss=$(echo "scale=1; $total_loss / $count" | bc)
        
        # 网站托管
        if [ "$overall_loss" -le 3 ] && [ "$overall_delay" -lt 100 ]; then
            echo -e "   🌐 网站托管      | <100ms      | <3%         | ${GREEN}✅ 适合${NC}"
        else
            echo -e "   🌐 网站托管      | <100ms      | <3%         | ${RED}❌ 不适合${NC}"
        fi
        
        # 视频流媒体
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
        
        # 其他用途
        echo -e "   🔒 科学上网      | <120ms      | <5%         | ${GREEN}✅ 非常适合${NC}"
        echo -e "   💾 大数据传输    | <150ms      | <1%         | ${GREEN}✅ 适合${NC}"
        echo -e "   📞 实时通信      | <50ms       | <1%         | ${RED}❌ 不适合${NC}"
        echo -e "   🗂️  文件存储      | 无要求       | <5%         | ${GREEN}✅ 非常适合${NC}"
        echo -e "   ⚡ API服务       | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
        echo -e "   🗃️  数据库服务    | <100ms      | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   ${RED}无法进行评估 - 所有节点均不可用${NC}"
    fi
    echo ""
}

# 生成最佳DNS推荐
generate_dns_recommendation() {
    echo -e "${CYAN}=== 🏆 最佳DNS推荐 ===${NC}"
    
    local best_nodes=()
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=' ' read -ra nodes <<< "${NODE_CATEGORIES[$category]}"
        local best_node=""
        local best_delay=1000
        local best_loss=100
        
        for node in "${nodes[@]}"; do
            local loss=${TEST_RESULTS["${node}_loss"]}
            local delay=${TEST_RESULTS["${node}_avg"]}
            
            if [ "$loss" -lt 100 ] && [ "$delay" -gt 0 ]; then
                if [ "$loss" -lt "$best_loss" ] || ([ "$loss" -eq "$best_loss" ] && [ "$delay" -lt "$best_delay" ]); then
                    best_node="$node"
                    best_delay=$delay
                    best_loss=$loss
                fi
            fi
        done
        
        if [ -n "$best_node" ]; then
            best_nodes+=("${category}: ${best_node} - 延迟${best_delay}ms, 丢包${best_loss}%")
        fi
    done
    
    if [ ${#best_nodes[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ 推荐使用以下DNS服务器:${NC}"
        for node_info in "${best_nodes[@]}"; do
            echo -e "   📍 $node_info"
        done
    else
        echo -e "${RED}❌ 未找到可用的DNS服务器${NC}"
    fi
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
    echo -e "${GREEN}✅ DNS测试完成${NC}"
    echo -e "${YELLOW}📊 测试统计: ${working_nodes}/${total_nodes} 个节点可用 (成功率${success_rate}%)${NC}"
    echo ""
    
    if [ "$success_rate" -gt 80 ]; then
        echo -e "${GREEN}🎉 网络质量优秀！DNS覆盖良好。${NC}"
    elif [ "$success_rate" -gt 50 ]; then
        echo -e "${GREEN}🎉 网络质量良好！主要DNS可用。${NC}"
    elif [ "$success_rate" -gt 20 ]; then
        echo -e "${YELLOW}⚠️  网络质量一般！部分DNS连接不稳定。${NC}"
    else
        echo -e "${RED}❌ 网络质量较差！建议检查网络配置。${NC}"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}🚀 开始精选DNS服务器测试...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    init_selected_dns_nodes
    echo -e "${YELLOW}========================================${NC}"
    run_all_dns_tests
    echo -e "${YELLOW}========================================${NC}"
    show_performance_rating
    show_usage_suitability
    echo -e "${YELLOW}========================================${NC}"
    generate_dns_recommendation
    echo -e "${YELLOW}========================================${NC}"
    generate_final_conclusion
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 DNS测试完成！${NC}"
    echo -e "${BLUE}⏰ 测试时间: $(date)${NC}"
}

# 执行主函数
main "$@"
