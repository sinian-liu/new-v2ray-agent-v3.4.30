#!/bin/bash
# 一键开启 root 密码登录优化版，适用于 Debian/Ubuntu
# 包含配置验证、服务状态检查和安全性提示

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

# 备份配置文件
backup_config() {
    local backup_file="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    cp /etc/ssh/sshd_config "$backup_file"
    log_info "配置文件已备份至: $backup_file"
}

# 设置密码
set_password() {
    read -sp "请输入要设置的 root 密码: " PWD
    echo
    read -sp "请再次输入 root 密码: " PWD2
    echo

    if [ "$PWD" != "$PWD2" ]; then
        log_error "两次密码不一致"
        exit 1
    fi

    if [ -z "$PWD" ]; then
        log_error "密码不能为空"
        exit 1
    fi

    # 设置 root 密码
    if echo "root:$PWD" | chpasswd; then
        log_success "root 密码设置成功"
    else
        log_error "密码设置失败"
        exit 1
    fi
}

# 修改 SSH 配置
modify_ssh_config() {
    local config_file="/etc/ssh/sshd_config"
    
    log_info "修改 SSH 配置..."
    
    # 修改或添加 PasswordAuthentication
    if grep -q "^PasswordAuthentication" "$config_file"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$config_file"
    else
        echo "PasswordAuthentication yes" >> "$config_file"
    fi

    # 修改或添加 PermitRootLogin
    if grep -q "^PermitRootLogin" "$config_file"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$config_file"
    else
        echo "PermitRootLogin yes" >> "$config_file"
    fi

    # 确保 PubkeyAuthentication 不被禁用
    if grep -q "^PubkeyAuthentication" "$config_file"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$config_file"
    else
        echo "PubkeyAuthentication yes" >> "$config_file"
    fi

    log_success "SSH 配置修改完成"
}

# 验证配置
verify_config() {
    local config_file="/etc/ssh/sshd_config"
    
    log_info "验证当前配置:"
    echo "=========================================="
    grep -E "^PasswordAuthentication|^PermitRootLogin|^PubkeyAuthentication" "$config_file" || {
        log_error "配置项未找到"
        exit 1
    }
    echo "=========================================="
    
    # 检查配置值是否正确
    if grep -q "^PasswordAuthentication yes" "$config_file" && \
       grep -q "^PermitRootLogin yes" "$config_file"; then
        log_success "配置验证通过"
    else
        log_error "配置验证失败"
        exit 1
    fi
}

# 获取 SSH 服务名
get_ssh_service_name() {
    if systemctl list-units --full -all | grep -qE '\.service' | grep -qE '\bssh(\b|d)'; then
        if systemctl is-active ssh &>/dev/null; then
            echo "ssh"
        elif systemctl is-active sshd &>/dev/null; then
            echo "sshd"
        else
            log_error "未找到运行的 SSH 服务"
            exit 1
        fi
    else
        # 默认尝试 ssh
        echo "ssh"
    fi
}

# 重启 SSH 服务
restart_ssh_service() {
    local service_name=$(get_ssh_service_name)
    
    log_info "重启 SSH 服务 ($service_name)..."
    
    if systemctl restart "$service_name"; then
        log_success "SSH 服务重启成功"
    else
        log_error "SSH 服务重启失败"
        systemctl status "$service_name" --no-pager -l
        exit 1
    fi

    # 检查服务状态
    if systemctl is-active --quiet "$service_name"; then
        log_success "SSH 服务运行正常"
    else
        log_error "SSH 服务未运行"
        exit 1
    fi
}

# 验证运行时配置
verify_runtime_config() {
    log_info "验证运行时配置..."
    
    if sshd -t; then
        log_success "SSH 配置语法检查通过"
    else
        log_error "SSH 配置语法错误"
        exit 1
    fi

    # 检查实际运行的配置
    if sshd -T 2>/dev/null | grep -q "passwordauthentication yes"; then
        log_success "密码认证已启用"
    else
        log_error "密码认证未正确启用"
    fi
}

# 获取公网 IP
get_public_ip() {
    local ip=""
    # 尝试多个获取 IP 的服务
    local services=(
        "ifconfig.me"
        "ipinfo.io/ip"
        "icanhazip.com"
        "api.ipify.org"
    )
    
    for service in "${services[@]}"; do
        ip=$(curl -s --connect-timeout 3 "$service" 2>/dev/null || true)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    
    # 如果都失败，尝试获取本机 IP
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "未知IP")
    echo "$ip"
}

# 显示完成信息
show_completion() {
    local ip=$(get_public_ip)
    
    echo
    log_success "已成功开启 root 密码登录"
    echo -e "${GREEN}👉 使用命令: ${NC}ssh root@$ip"
    echo -e "${GREEN}🔑 输入您设置的密码登录${NC}"
    echo
    log_warning "安全提示:"
    echo "  1. 请确保使用强密码（字母+数字+特殊字符）"
    echo "  2. 建议完成后改回仅密钥登录以提高安全性"
    echo "  3. 考虑使用 fail2ban 防止暴力破解"
    echo
    log_info "当前 SSH 配置状态:"
    systemctl status $(get_ssh_service_name) --no-pager -l | head -10
}

# 主函数
main() {
    echo -e "${BLUE}=== 一键开启 root 密码登录脚本 ===${NC}"
    echo -e "${YELLOW}⚠️  安全警告：此操作会降低服务器安全性！${NC}"
    
    check_root
    backup_config
    set_password
    modify_ssh_config
    verify_config
    restart_ssh_service
    verify_runtime_config
    show_completion
}

# 执行主函数
main "$@"
