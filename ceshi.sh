#!/bin/bash

# 定义测试节点
declare -A nodes=(
  ["广州电信"]="183.47.126.35"
  ["广州联通"]="157.148.58.29"
  ["广州移动"]="120.233.18.250"
  ["广州教育"]="202.116.64.8"
  ["上海电信"]="101.226.94.124"
  ["上海联通"]="140.207.122.197"
  ["上海移动"]="117.185.253.224"
  ["上海教育"]="202.120.2.119"
  ["北京电信"]="49.7.37.74"
  ["北京联通"]="111.206.209.44"
  ["北京移动"]="112.34.111.194"
  ["北京教育"]="166.111.4.100"
)

# 检查并安装依赖
check_dependencies() {
  echo "检查依赖..."
  
  # 检测 jq
  if ! command -v jq &>/dev/null; then
    echo "未检测到 jq，正在安装..."
    sudo apt update && sudo apt install -y jq
  else
    echo "jq 已安装"
  fi

  # 检测 speedtest
  if ! command -v speedtest &>/dev/null; then
    echo "未检测到 Speedtest CLI，正在安装..."
    curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
    sudo apt install -y speedtest
  else
    echo "Speedtest CLI 已安装"
  fi
}

# 打印表头
print_header() {
  echo -e "地区/运营商\t下载速度/Mbps\t上传速度/Mbps\t延迟/ms\t抖动/ms"
}

# 测速函数
speed_test() {
  local name=$1
  local ip=$2

  # 使用 speedtest CLI 测试
  result=$(speedtest --server-id "$ip" --format=json)
  if [[ $? -ne 0 ]]; then
    echo -e "$name\t测试失败\t测试失败\t测试失败\t测试失败"
    return
  fi

  # 解析 JSON 结果
  download=$(echo "$result" | jq -r '.download.bandwidth' | awk '{printf "%.2f", $1 / 125000}')
  upload=$(echo "$result" | jq -r '.upload.bandwidth' | awk '{printf "%.2f", $1 / 125000}')
  latency=$(echo "$result" | jq -r '.ping.latency')
  jitter=$(echo "$result" | jq -r '.ping.jitter')

  # 输出结果
  echo -e "$name\t$download\t$upload\t$latency\t$jitter"
}

# 主函数
main() {
  # 检查依赖
  check_dependencies

  # 打印表头
  print_header

  # 遍历所有节点并测试
  for key in "${!nodes[@]}"; do
    speed_test "$key" "${nodes[$key]}"
  done
}

# 运行主函数
main
