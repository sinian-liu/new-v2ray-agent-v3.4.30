#!/bin/bash

# VPS网络真实测试脚本
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

# 初始化节点
init_nodes() {
    # 电信节点
    NODE_CATEGORIES["电信"]="上海电信 广东电信 江苏电信"
    TEST_NODES["上海电信"]="202.96.209.133"
    TEST_NODES["广东电信"]="202.96.128.86"
    TEST_NODES["江苏电信"]="218.2.2.2"
    
    # 联通节点
    NODE_CATEGORIES["联通"]="北京联通 上海联通 浙江联通"
    TEST_NODES["北京联通"]="123.123.123.123"
    TEST_NODES["上海联通"]="210.22.70.3"
    TEST_NODES["浙江联通"]="221.12.1.227"
    
    # 移动节点
    NODE_CATEGORIES["移动"]="上海移动 广东移动 江苏移动"
    TEST_NODES["上海移动"]="211.136.112.50"
    TEST_NODES["广东移动"]="211.139.129.222"
    TEST_NODES["江苏移动"]="221.131.143.69"
}

# 显示测试进度
show_progress() {
    local current=$1
    local total=$2
    local node=$3
    local width=30
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
    result=$(timeout 15 ping -c 6 -i 0.3 -W 2 "$ip" 2>/dev/null | tail -2 || true)
    
    local packet_loss=100
    local avg_delay=0
    local min_delay=0
    local max_delay=0
    local jitter=0
    
    if echo "$result" | grep -q "100% packet loss" || [ -z "$result" ]; then
        packet_loss=100
    else
        packet_loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "100")
        local rtt_stats=$(echo "$result" | grep 'rtt' || echo "")
        
        if [ -n "$rtt_stats" ]; then
            min_delay=$(echo "$rtt_stats" | awk -F'/' '{print $4}')
            avg_delay=$(echo "$rtt_stats" | awk -F'/' '{print $5}')
            max_delay=$(echo "$rtt_stats" | awk -F'/' '{print $6}')
            jitter=$(echo "$rtt_stats" | awk -F'/' '{print $7}')
        fi
    fi
    
    # 保存测试结果
    TEST_RESULTS["${node}_avg"]=$avg_delay
    TEST_RESULTS["${node}_loss"]=$packet_loss
    TEST_RESULTS["${node}_min"]=$min_delay
    TEST_RESULTS["${node}_max"]=$max_delay
    TEST_RESULTS["${node}_jitter"]=$jitter
}

# 执行所有网络测试
run_network_tests() {
    echo -e "${CYAN}=== 🌐 开始实时网络测试 ===${NC}"
    echo -e "${YELLOW}⏰ 正在进行网络测试，请耐心等待...${NC}"
    echo ""
    
    local total_nodes=${#TEST_NODES[@]}
    local current=0
    
    for node in "${!TEST_NODES[@]}"; do
        current=$((current + 1))
        show_progress "$current" "$total_nodes" "$node"
        perform_ping_test "$node" "${TEST_NODES[$node]}"
        sleep 0.3
    done
    
    echo -e "\n\n${GREEN}✅ 网络测试完成！${NC}"
    echo ""
}

# 计算各运营商统计数据
calculate_stats() {
    local category=$1
    local nodes=($2)
    
    local total_delay=0
    local total_loss=0
    local count=0
    
    for node in "${nodes[@]}"; do
        local loss=${TEST_RESULTS["${node}_loss"]}
        local delay=${TEST_RESULTS["${node}_avg"]}
        
        if [ "$loss" -lt 100 ] && [ "$delay" -gt 0 ]; then
            total_delay=$(echo "$total_delay + $delay" | bc)
            total_loss=$(echo "$total_loss + $loss" | bc)
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        local avg_delay=$(echo "scale=0; $total_delay / $count" | bc)
        local avg_loss=$(echo "scale=1; $total_loss / $count" | bc)
        echo "$avg_delay,$avg_loss"
    else
        echo "0,100"
    fi
}

# 显示网络性能评级
show_performance_rating() {
    echo -e "${PURPLE}🎯 网络性能评级:${NC}"
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        
        if [ "$avg_loss" -eq 100 ]; then
            echo -e "   - ${category}网络: ${RED}无法连接${NC}"
        else
            local rating=""
            local stars=""
            
            if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 50 ]; then
                rating="${GREEN}优秀 ⭐⭐⭐⭐⭐${NC}"
                stars="⭐⭐⭐⭐⭐"
            elif [ "$avg_loss" -le 3 ] && [ "$avg_delay" -lt 100 ]; then
                rating="${GREEN}良好 ⭐⭐⭐⭐${NC}"
                stars="⭐⭐⭐⭐"
            elif [ "$avg_loss" -le 5 ] && [ "$avg_delay" -lt 150 ]; then
                rating="${YELLOW}一般 ⭐⭐⭐${NC}"
                stars="⭐⭐⭐"
            elif [ "$avg_loss" -le 10 ]; then
                rating="${YELLOW}较差 ⭐⭐${NC}"
                stars="⭐⭐"
            else
                rating="${RED}极差 ⭐${NC}"
                stars="⭐"
            fi
            
            echo -e "   - ${category}网络: $rating (延迟${avg_delay}ms, 丢包${avg_loss}%)"
        fi
    done
    
    # 综合评级（取平均值）
    local total_delay=0
    local total_loss=0
    local count=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        if [ "$avg_loss" -lt 100 ]; then
            total_delay=$((total_delay + avg_delay))
            total_loss=$(echo "$total_loss + $avg_loss" | bc)
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        local overall_delay=$((total_delay / count))
        local overall_loss=$(echo "scale=1; $total_loss / $count" | bc)
        
        if [ "$overall_loss" -le 2 ] && [ "$overall_delay" -lt 80 ]; then
            echo -e "   - 综合评级: ${GREEN}优秀 ⭐⭐⭐⭐⭐${NC}"
        elif [ "$overall_loss" -le 4 ] && [ "$overall_delay" -lt 120 ]; then
            echo -e "   - 综合评级: ${GREEN}良好 ⭐⭐⭐⭐${NC}"
        elif [ "$overall_loss" -le 6 ]; then
            echo -e "   - 综合评级: ${YELLOW}一般 ⭐⭐⭐${NC}"
        else
            echo -e "   - 综合评级: ${YELLOW}较差 ⭐⭐${NC}"
        fi
    fi
    echo ""
}

# 显示用途适配性表格
show_usage_suitability() {
    # 计算平均性能
    local total_delay=0
    local total_loss=0
    local count=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        if [ "$avg_loss" -lt 100 ]; then
            total_delay=$((total_delay + avg_delay))
            total_loss=$(echo "$total_loss + $avg_loss" | bc)
            count=$((count + 1))
        fi
    done
    
    local avg_delay=$((total_delay / count))
    local avg_loss=$(echo "scale=1; $total_loss / $count" | bc)
    
    echo -e "${PURPLE}📊 用途适配性分析:${NC}"
    echo -e "   用途类型        | 延迟要求     | 丢包要求     | 适合性"
    echo -e "   ----------------|-------------|-------------|-------------"
    
    # 网站托管
    if [ "$avg_loss" -le 3 ] && [ "$avg_delay" -lt 100 ]; then
        echo -e "   🌐 网站托管      | <100ms      | <3%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   🌐 网站托管      | <100ms      | <3%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 视频流媒体
    if [ "$avg_loss" -le 2 ] && [ "$avg_delay" -lt 80 ]; then
        echo -e "   📺 视频流媒体    | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   📺 视频流媒体    | <80ms       | <2%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 游戏服务器
    if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 60 ]; then
        echo -e "   🎮 游戏服务器    | <60ms       | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   🎮 游戏服务器    | <60ms       | <1%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 科学上网
    if [ "$avg_loss" -le 5 ] && [ "$avg_delay" -lt 120 ]; then
        echo -e "   🔒 科学上网      | <120ms      | <5%         | ${GREEN}✅ 非常适合${NC}"
    else
        echo -e "   🔒 科学上网      | <120ms      | <5%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 大数据传输
    if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 150 ]; then
        echo -e "   💾 大数据传输    | <150ms      | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   💾 大数据传输    | <150ms      | <1%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 实时通信
    if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 50 ]; then
        echo -e "   📞 实时通信      | <50ms       | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   📞 实时通信      | <50ms       | <1%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 文件存储
    if [ "$avg_loss" -le 5 ]; then
        echo -e "   🗂️  文件存储      | 无要求       | <5%         | ${GREEN}✅ 非常适合${NC}"
    else
        echo -e "   🗂️  文件存储      | 无要求       | <5%         | ${RED}❌ 不适合${NC}"
    fi
    
    # API服务
    if [ "$avg_loss" -le 2 ] && [ "$avg_delay" -lt 80 ]; then
        echo -e "   ⚡ API服务       | <80ms       | <2%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   ⚡ API服务       | <80ms       | <2%         | ${RED}❌ 不适合${NC}"
    fi
    
    # 数据库服务
    if [ "$avg_loss" -le 1 ] && [ "$avg_delay" -lt 100 ]; then
        echo -e "   🗃️  数据库服务    | <100ms      | <1%         | ${GREEN}✅ 适合${NC}"
    else
        echo -e "   🗃️  数据库服务    | <100ms      | <1%         | ${RED}❌ 不适合${NC}"
    fi
    echo ""
}

# 生成最终结论
generate_final_conclusion() {
    echo -e "${CYAN}=== 📋 测试结论 ===${NC}"
    
    # 计算总体性能
    local total_delay=0
    local total_loss=0
    local count=0
    
    for category in "${!NODE_CATEGORIES[@]}"; do
        IFS=',' read -r avg_delay avg_loss <<< "$(calculate_stats "$category" "${NODE_CATEGORIES[$category]}")"
        if [ "$avg_loss" -lt 100 ]; then
            total_delay=$((total_delay + avg_delay))
            total_loss=$(echo "$total_loss + $avg_loss" | bc)
            count=$((count + 1))
        fi
    done
    
    local overall_delay=$((total_delay / count))
    local overall_loss=$(echo "scale=1; $total_loss / $count" | bc)
    
    echo -e "${GREEN}✅ 网络测试完成${NC}"
    echo -e "${YELLOW}📊 总体性能: 延迟${overall_delay}ms, 丢包率${overall_loss}%${NC}"
    echo ""
    
    if [ "$overall_loss" -le 2 ] && [ "$overall_delay" -lt 80 ]; then
        echo -e "${GREEN}🎉 网络质量优秀！适合各种业务部署。${NC}"
    elif [ "$overall_loss" -le 4 ] && [ "$overall_delay" -lt 120 ]; then
        echo -e "${GREEN}🎉 网络质量良好！适合大多数业务场景。${NC}"
    elif [ "$overall_loss" -le 6 ]; then
        echo -e "${YELLOW}⚠️  网络质量一般！建议优化网络配置。${NC}"
    else
        echo -e "${RED}❌ 网络质量较差！建议更换网络环境。${NC}"
    fi
    
    echo -e "${BLUE}⏰ 测试时间: $(date)${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}🚀 开始VPS网络性能测试...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 初始化
    init_nodes
    
    # 执行真实网络测试
    run_network_tests
    
    echo -e "${YELLOW}========================================${NC}"
    
    # 显示性能评级
    show_performance_rating
    
    # 显示用途适配性
    show_usage_suitability
    
    echo -e "${YELLOW}========================================${NC}"
    
    # 生成最终结论
    generate_final_conclusion
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}🎉 测试完成！${NC}"
}

# 执行主函数
main "$@"
