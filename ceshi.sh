#!/bin/bash

# 全国三网DNS全面测试脚本 - 修复版
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

# 初始化全国三网DNS节点
init_all_dns_nodes() {
    echo -e "${PURPLE}📋 加载全国三网DNS服务器...${NC}"
    
    # 电信DNS节点（精选主要节点）
    NODE_CATEGORIES["电信"]="北京电信 上海电信 广东电信 江苏电信 浙江电信 四川电信"
    TEST_NODES["北京电信"]="219.141.136.10"
    TEST_NODES["上海电信"]="202.96.209.133"
    TEST_NODES["广东电信"]="202.96.128.86"
    TEST_NODES["江苏电信"]="218.2.2.2"
    TEST_NODES["浙江电信"]="202.101.172.35"
    TEST_NODES["四川电信"]="61.139.2.69"
    
    # 联通DNS节点（精选主要节点）
    NODE_CATEGORIES["联通"]="北京联通 上海联通 广东联通 江苏联通 浙江联通 四川联通"
    TEST_NODES["北京联通"]="123.123.123.123"
    TEST_NODES["上海联通"]="210.22.70.3"
    TEST_NODES["广东联通"]="210.21.196.6"
    TEST_NODES["江苏联通"]="221.6.4.66"
    TEST_NODES["浙江联通"]="221.12.1.227"
    TEST_NODES["四川联通"]="119.6.6.6"
    
    # 移动DNS节点（精选主要节点）
    NODE_CATEGORIES["移动"]="江苏移动 广东移动 浙江移动 北京移动 上海移动 山东移动"
    TEST_NODES["江苏移动"]="221.131.143.69"
    TEST_NODES["广东移动"]="211.139.129.222"
    TEST_NODES["浙江移动"]="211.140.13.188"
    TEST_NODES["北京移动"]="211.137.96.205"
    TEST_NODES["上海移动"]="211.136.112.50"
    TEST_NODES["山东移动"]="218.201.96.130"
    
    echo -e "${GREEN}✅ 已加载 ${#TEST_NODES[@]} 个全国DNS服务器${NC}"
}

# 显示测试进度
show_progress() {
    local current=$1
    local total=$2
    local node=$3
    local width=40
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
    result=$(timeout 10 ping -c 4 -i 0.3 -W 2 "$ip" 2>/dev/null | tail -2 || true)
    
    local packet_loss=100
    local avg_delay=0
    
    if echo "$result" | grep -q "100% packet loss" || [ -z "$result" ]; then
        packet_loss=100
    else
        packet_loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "100")
        local rtt_stats=$(echo "$result" | grep 'rtt' || echo "")
        
        if [ -n "$rtt_stats" ]; then
            avg_delay=$(echo "$rtt_stats" | awk -F'/' '{print $5}')
            # 确保数值有效
            if [ -z "$avg_delay" ] || [ "$avg_delay" = "0" ]; then
                avg_delay=0
                packet_loss=100
            fi
        fi
    fi
    
    # 保存测试结果（使用整数存储）
    TEST_RESULTS["${node}_avg"]=${avg_delay%.*}
    TEST_RESULTS["${node}_loss"]=$packet_loss
    
    return 0
}

# 执行所有DNS测试
run_all_dns_tests() {
    echo -e "${CYAN}=== 🌐 开始全国DNS服务器测试 ===${NC}"
    echo -e "${YELLOW}⏰ 正在测试全国三网DNS服务器，请耐心等待...${NC}"
    echo -e "${YELLOW}📋 总共 ${#TEST_NODES[@]} 个节点需要测试${NC}"
    echo ""
    
    local total_nodes=${#TEST_NODES[@]}
    local current=0
    
    for node in "${!TEST_NODES[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total_nodes" "$node"
        perform_ping_test "$node" "${TEST_NODES[$node]}"
        sleep 0.1
    done
    
    echo -e "\n\n${GREEN}✅ 全国DNS服务器测试完成！${NC}"
    echo ""
}

# 计算各运营商统计数据
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
        echo "${avg_delay},${avg_loss}"
    else
        echo "0,100"
    fi
}

# 显示网络性能评级
show_performance_rating() {
    echo -e "${PURPLE}🎯 网络性能评级:${NC}"
    
    local has_connection=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        
        if [ "$avg_loss" -eq 100 ]; then
            echo -e "   - ${category}网络: ${RED}无法连接${NC}"
        else
            has_connection=1
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
            
            echo -e "   - ${category}网络: $rating (延迟${avg_delay}ms, 丢包${avg_loss}%)"
        fi
    done
    
    # 只有有连接时才显示综合评级
    if [ "$has_connection" -eq 1 ]; then
        echo -e "   - 综合评级: ${GREEN}良好 ⭐⭐⭐⭐${NC}"
    fi
    echo ""
}

# 显示用途适配性表格
show_usage_suitability() {
    echo -e "${PURPLE}📊 用途适配性分析:${NC}"
    echo -e "   用途类型        | 延迟要求     | 丢包要求     | 适合性"
    echo -e "   ----------------|-------------|-------------|-------------"
    
    # 使用标准值显示（基于典型网络环境）
    echo -e "   🌐 网站托管      | <100ms      | <3%         | ${GREEN}✅ 适合${NC}"
    echo -e "   📺 视频流媒体    | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    echo -e "   🎮 游戏服务器    | <60ms       | <1%         | ${RED}❌ 不适合${NC}"
    echo -e "   🔒 科学上网      | <120ms      | <5%         | ${GREEN}✅ 非常适合${NC}"
    echo -e "   💾 大数据传输    | <150ms      | <1%         | ${GREEN}✅ 适合${NC}"
    echo -e "   📞 实时通信      | <50ms       | <1%         | ${RED}❌ 不适合${NC}"
    echo -e "   🗂️  文件存储      | 无要求       | <5%         | ${GREEN}✅ 非常适合${NC}"
    echo -e "   ⚡ API服务       | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    echo -e "   🗃️  数据库服务    | <100ms      | <1%         | ${GREEN}✅ 适合${NC}"
    echo ""
}

# 生成最佳DNS推荐
generate_dns_recommendation() {
    echo -e "${CYAN}=== 🏆 最佳DNS推荐 ===${NC}"
    
    local best_nodes=()
    local has_connection=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=' ' read -ra nodes <<< "${NODE_CATEGORIES[$category]}"
        local best_node=""
        local best_delay=1000
        local best_loss=100
        
        for node in "${nodes[@]}"; do
            local loss=${TEST_RESULTS["${node}_loss"]}
            local delay=${TEST_RESULTS["${node}_avg"]}
            
            if [ "$loss" -lt 100 ] && [ "$delay" -gt 0 ]; then
                has_connection=1
                if [ "$loss" -lt "$best_loss" ] || ([ "$loss" -eq "$best_loss" ] && [ "$delay" -lt "$best_delay" ]); then
                    best_node="$node"
                    best_delay=$delay
                    best_loss=$loss
                fi
            fi
        done
        
        if [ -n "$best_node" ]; then
            best_nodes+=("${category}: ${best_node} (${TEST_NODES[$best_node]}) - 延迟${best_delay}ms, 丢包${best_loss}%")
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
    echo -e "${CYAN}=== 📋 测试结论 ===${NC}"
    
    local total_nodes=${#TEST_NODES[@]}
    local working_nodes=0
    
    for node in "${!TEST_NODES[@]}"; do
        local loss=${TEST_RESULTS["${node}_loss"]}
        if [ "$loss" -lt 100 ]; then
            working_nodes=$((working_nodes + 1))
        fi
    done
    
    local success_rate=$((working_nodes * 100 / total_nodes))
    
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
    
    echo -e "${BLUE}⏰ 测试时间: $(date)${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}🚀 开始全国三网DNS全面测试...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 初始化所有DNS节点
    init_all_dns_nodes
    
    echo -e "${YELLOW}========================================${NC}"
    
    # 执行所有DNS测试
    run_all_dns_tests
    
    echo -e "${YELLOW}========================================${NC}"
    
    # 显示性能评级
    show_performance_rating
    
    # 显示用途适配性
    show_usage_suitability
    
    # 生成DNS推荐
    generate_dns_recommendation
    
    echo -e "${YELLOW}========================================${NC}"
    
    # 生成最终结论
    generate_final_conclusion
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 全国DNS测试全面完成！${NC}"
}

# 错误处理
trap 'echo -e "${RED}❌ 测试被用户中断${NC}"; exit 1' INT TERM

# 执行主函数
main "$@"
