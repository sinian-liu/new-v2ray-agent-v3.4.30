#!/usr/bin/env bash
# v2ray-agent 简化版（全面优化）
# 当前日期: 2025-03-01
# 作者: 基于 sinian-liu 的 v2ray-agent-2.5.73 重新设计并优化

# 版本号
VERSION="1.0.3"

# 颜色输出函数
echoColor() {
    case $1 in
        "red") echo -e "\033[31m$2\033[0m" ;;
        "green") echo -e "\033[32m$2\033[0m" ;;
        "yellow") echo -e "\033[33m$2\033[0m" ;;
        "blue") echo -e "\033[34m$2\033[0m" ;;
    esac
}

# 检查系统类型
checkSystem() {
    if grep -qi "centos" /etc/redhat-release 2>/dev/null || grep -qi "centos" /proc/version; then
        release="centos"
        install_cmd="yum -y install"
        update_cmd="yum update -y"
        [[ -f "/etc/centos-release" ]] && centos_version=$(awk '{print $4}' /etc/centos-release | cut -d'.' -f1)
        [[ "${centos_version}" -lt 7 ]] && { echoColor red "Unsupported system, requires CentOS 7+"; exit 1; }
    elif grep -qi "debian" /etc/issue || grep -qi "debian" /proc/version; then
        release="debian"
        install_cmd="apt -y install"
        update_cmd="apt update"
        debian_version=$(cat /etc/debian_version | cut -d'.' -f1)
        [[ "${debian_version}" -lt 9 ]] && { echoColor red "Unsupported system, requires Debian 9+"; exit 1; }
    elif grep -qi "ubuntu" /etc/issue || grep -qi "ubuntu" /proc/version; then
        release="ubuntu"
        install_cmd="apt -y install"
        update_cmd="apt update"
        ubuntu_version=$(lsb_release -sr | cut -d'.' -f1)
        [[ "${ubuntu_version}" -lt 18 ]] && { echoColor red "Unsupported system, requires Ubuntu 18.04+"; exit 1; }
    else
        echoColor red "Unsupported system, use CentOS 7+, Debian 9+, or Ubuntu 18.04+"
        exit 1
    fi
}

# 检查 CPU 架构
checkCPU() {
    case "$(uname -m)" in
        'x86_64') cpu_arch="64" ;;
        'aarch64') cpu_arch="arm64-v8a" ;;
        *) echoColor red "Unsupported CPU architecture, only x86_64 and aarch64 supported"; exit 1 ;;
    esac
}

# 初始化变量
initVars() {
    config_dir="/etc/v2ray-agent"
    tls_dir="${config_dir}/tls"
    sub_dir="${config_dir}/subscribe"
    expiration_file="${config_dir}/expiration_users.json"
    v2ray_config="${config_dir}/v2ray/config.json"
    v2ray_bin="${config_dir}/v2ray/v2ray"
    nginx_conf="/etc/nginx/conf.d/v2ray.conf"
    log_file="/var/log/v2ray-agent.log"
    backup_dir="${config_dir}/backup"
    sub_all_file="${sub_dir}/all_subscriptions.txt"
    current_domain=""
    default_port=443
    api_port=10000
    installed=0
    [[ -f "${v2ray_config}" && -f "${v2ray_bin}" ]] && installed=1
}

# 检查网络连接
checkNetwork() {
    echoColor blue "Checking network connection..."
    if ! ping -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echoColor red "Unable to connect to network, check network settings"
        exit 1
    fi
}

# 安装依赖工具
installTools() {
    echoColor blue "Installing dependencies..."
    ${update_cmd} || { echoColor red "System update failed"; exit 1; }
    local tools="curl wget unzip jq nginx uuid-runtime qrencode grpc-tools"
    ${install_cmd} ${tools} || { echoColor red "Tool installation failed"; cleanup; exit 1; }
    if ! command -v acme.sh >/dev/null 2>&1; then
        curl -s https://get.acme.sh | sh -s -- --force || { echoColor red "acme.sh installation failed"; cleanup; exit 1; }
    fi
    mkdir -p /var/log
    touch "${log_file}"
    chmod 640 "${log_file}"
}

# 创建目录
createDirs() {
    echoColor blue "Creating directories..."
    mkdir -p "${config_dir}" "${tls_dir}" "${sub_dir}" "${config_dir}/v2ray" "${backup_dir}" || {
        echoColor red "Directory creation failed, check permissions"
        cleanup
        exit 1
    }
    chmod 700 "${config_dir}" "${tls_dir}" "${sub_dir}" "${config_dir}/v2ray" "${backup_dir}"
}

# 检查更新
checkUpdate() {
    echoColor blue "Checking for updates..."
    local remote_version=$(curl -s https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh | grep "VERSION=" | head -1 | cut -d'"' -f2)
    if [[ -n "${remote_version}" && "${remote_version}" > "${VERSION}" ]]; then
        echoColor yellow "New version available: ${remote_version} (current: ${VERSION})"
        read -r -p "Update now? [y/N]: " update_choice
        if [[ "${update_choice}" =~ ^[Yy]$ ]]; then
            wget -q -O /tmp/v2ray-agent.sh "https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh" || {
                echoColor red "Update download failed"
                return 1
            }
            chmod +x /tmp/v2ray-agent.sh
            mv /tmp/v2ray-agent.sh "$(realpath "$0")"
            echoColor green "Updated to version ${remote_version}"
            exec "$(realpath "$0")"
        fi
    fi
}

# 安装 V2Ray
installV2Ray() {
    echoColor blue "Installing V2Ray..."
    local latest_version=$(curl -s -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | jq -r .tag_name)
    if [[ -z "${latest_version}" ]]; then
        echoColor red "Failed to fetch V2Ray version"
        cleanup
        exit 1
    fi
    local url="https://github.com/v2fly/v2ray-core/releases/download/${latest_version}/v2ray-linux-${cpu_arch}.zip"
    wget -q "${url}" -O /tmp/v2ray.zip || { echoColor red "V2Ray download failed"; cleanup; exit 1; }
    unzip -o /tmp/v2ray.zip -d "${config_dir}/v2ray" || { echoColor red "V2Ray extraction failed"; cleanup; exit 1; }
    chmod +x "${v2ray_bin}"
    rm -f /tmp/v2ray.zip
}

# 配置 V2Ray 服务
installV2RayService() {
    echoColor blue "Configuring V2Ray service..."
    cat <<EOF >/etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
After=network.target

[Service]
Type=simple
ExecStart=${v2ray_bin} -config ${v2ray_config}
Restart=on-failure
ExecReload=/bin/kill -HUP \$MAINPID
User=nobody
Group=nogroup
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || { echoColor red "systemd configuration failed"; cleanup; exit 1; }
    systemctl enable v2ray
}

# 管理防火墙
manageFirewall() {
    echoColor blue "Configuring firewall..."
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=${api_port}/tcp
        firewall-cmd --reload
    elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow ${api_port}/tcp
    elif command -v iptables >/dev/null 2>&1; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        iptables -A INPUT -p tcp --dport ${api_port} -j ACCEPT
    fi
}

# 初始化 TLS 证书并配置 Nginx
initTLSandNginx() {
    echoColor blue "Configuring TLS and Nginx..."
    if [[ -f "${nginx_conf}" || -f "${v2ray_config}" ]]; then
        echoColor yellow "Existing configuration detected, reinstalling will overwrite."
        read -r -p "Continue? [y/N]: " overwrite_choice
        [[ ! "${overwrite_choice}" =~ ^[Yy]$ ]] && { echoColor red "Installation aborted"; exit 1; }
    fi

    read -r -p "Enter domain (must resolve to this server with Cloudflare orange cloud): " domain
    if [[ -z "${domain}" ]]; then
        echoColor red "Domain cannot be empty"
        exit 1
    fi
    current_domain="${domain}"

    local server_ip=$(curl -s -m 5 "https://api.cloudflare.com/cdn-cgi/trace" | grep "ip=" | cut -d'=' -f2)
    local resolved_ip=$(dig +short "${current_domain}" A | grep -v '\.$' | tail -n1)
    if [[ -z "${resolved_ip}" || "${resolved_ip}" != "${server_ip}" ]]; then
        echoColor red "Domain not resolved to local IP (${server_ip}), resolved: ${resolved_ip}"
        exit 1
    fi
    if ! curl -s -m 5 -I "http://${current_domain}" | grep -qi "cf-ray"; then
        echoColor red "Cloudflare proxy not enabled"
        exit 1
    fi

    ~/.acme.sh/acme.sh --issue -d "${current_domain}" --nginx --force --server letsencrypt || {
        echoColor red "Certificate issuance failed, check logs (~/.acme.sh/acme.sh.log)"
        cleanup
        exit 1
    }
    ~/.acme.sh/acme.sh --install-cert -d "${current_domain}" \
        --key-file "${tls_dir}/${current_domain}.key" \
        --fullchain-file "${tls_dir}/${current_domain}.crt" || {
        echoColor red "Certificate installation failed"
        cleanup
        exit 1
    }
    chmod 600 "${tls_dir}"/*

    cat <<EOF >"${nginx_conf}"
server {
    listen 80;
    server_name ${current_domain};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${current_domain};
    ssl_certificate ${tls_dir}/${current_domain}.crt;
    ssl_certificate_key ${tls_dir}/${current_domain}.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    location /sub/ {
        root ${config_dir};
        try_files \$uri \$uri/ =404;
    }

    location / {
        root /var/www/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
    mkdir -p /var/www/html
    echo "<h1>V2Ray Agent</h1>" >/var/www/html/index.html
    chmod 644 /var/www/html/index.html

    nginx -t || { echoColor red "Nginx config validation failed"; cleanup; exit 1; }
    systemctl restart nginx || { echoColor red "Nginx restart failed"; cleanup; exit 1; }
}

# 初始化 V2Ray 配置（支持多端口和 API）
initV2RayConfig() {
    echoColor blue "Initializing V2Ray configuration..."
    cat <<EOF >"${v2ray_config}"
{
  "log": {
    "loglevel": "warning",
    "access": "${log_file}",
    "error": "${log_file}"
  },
  "api": {
    "tag": "api",
    "services": ["StatsService"]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "inbounds": [
    {
      "port": ${default_port},
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "${tls_dir}/${current_domain}.crt",
              "keyFile": "${tls_dir}/${current_domain}.key"
            }
          ]
        }
      },
      "tag": "vless_default"
    },
    {
      "port": ${api_port},
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": ${api_port},
        "network": "tcp"
      },
      "tag": "api"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
    chmod 600 "${v2ray_config}"
    "${v2ray_bin}" -test -config "${v2ray_config}" || {
        echoColor red "V2Ray configuration test failed"
        cleanup
        exit 1
    }
}

# 添加用户（支持多端口）
addUser() {
    echoColor blue "Adding user..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray not installed"
        return 1
    fi
    local retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "Enter user email: " email
        if [[ -z "${email}" ]] || ! echo "${email}" | grep -q "@" || jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
            echoColor red "Email is invalid, empty, or exists"
            read -r -p "Retry? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${email}" ]] && return 1

    retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "Enter expiration date (YYYY-MM-DD): " exp_date
        if ! date -d "${exp_date}" >/dev/null 2>&1; then
            echoColor red "Expiration date format error, should be YYYY-MM-DD"
            read -r -p "Retry? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${exp_date}" ]] && return 1

    read -r -p "Enter port (default ${default_port}, or new port): " port
    [[ -z "${port}" ]] && port=${default_port}
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ "${port}" -lt 1 || "${port}" -gt 65535 ]]; then
        echoColor red "Invalid port number"
        return 1
    fi

    backupConfig
    local uuid=$(uuidgen)
    local inbound_exists=$(jq -r ".inbounds[] | select(.port == ${port})" "${v2ray_config}")
    if [[ -z "${inbound_exists}" ]]; then
        local new_inbound=$(jq -r ".inbounds += [{\"port\": ${port}, \"protocol\": \"vless\", \"settings\": {\"clients\": [{\"id\": \"${uuid}\", \"email\": \"${email}\"}], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"tcp\", \"security\": \"tls\", \"tlsSettings\": {\"alpn\": [\"http/1.1\"], \"certificates\": [{\"certificateFile\": \"${tls_dir}/${current_domain}.crt\", \"keyFile\": \"${tls_dir}/${current_domain}.key\"}]}}}]" "${v2ray_config}")
        echo "${new_inbound}" | jq . >"${v2ray_config}" || { echoColor red "Configuration update failed"; return 1; }
    else
        local clients=$(jq -r "(.inbounds[] | select(.port == ${port}) | .settings.clients) += [{\"id\": \"${uuid}\", \"email\": \"${email}\"}]" "${v2ray_config}")
        echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "Configuration update failed"; return 1; }
    fi

    if [[ ! -f "${expiration_file}" ]]; then
        echo '{"users":[]}' >"${expiration_file}"
    fi
    local exp_timestamp=$(date -d "${exp_date}" +%s)
    local expiration_data=$(jq -r ".users += [{\"email\": \"${email}\", \"expiration\": ${exp_timestamp}, \"port\": ${port}}]" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}" || { echoColor red "Expiration update failed"; return 1; }
    chmod 600 "${expiration_file}"

    echoColor green "User ${email} added successfully on port ${port}, expires on: ${exp_date}"
    generateSubscription "${email}" "${uuid}" "${port}"
    reloadCore
}

# 删除用户
removeUser() {
    echoColor blue "Deleting user..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray not installed"
        return 1
    fi
    local retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "Enter email of user to delete: " email
        if ! jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
            echoColor red "User does not exist"
            read -r -p "Retry? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${email}" ]] && return 1

    backupConfig
    local port=$(jq -r ".users[] | select(.email == \"${email}\") | .port" "${expiration_file}")
    local clients=$(jq -r "(.inbounds[] | select(.port == ${port}) | .settings.clients) -= [(.settings.clients[] | select(.email == \"${email}\"))]" "${v2ray_config}")
    echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "Configuration update failed"; return 1; }
    local expiration_data=$(jq -r "del(.users[] | select(.email == \"${email}\"))" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}"
    rm -f "${sub_dir}/${email}.txt" "${sub_dir}/${email}.base64"
    echoColor green "User ${email} deleted successfully from port ${port}"
    reloadCore
}

# 续期用户
renewUser() {
    echoColor blue "Renewing user expiration..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray not installed"
        return 1
    fi
    read -r -p "Enter email of user to renew: " email
    if ! jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
        echoColor red "User does not exist"
        return 1
    fi
    read -r -p "Enter new expiration date (YYYY-MM-DD): " exp_date
    if ! date -d "${exp_date}" >/dev/null 2>&1; then
        echoColor red "Expiration date format error"
        return 1
    fi

    backupConfig
    local exp_timestamp=$(date -d "${exp_date}" +%s)
    local expiration_data=$(jq -r "(.users[] | select(.email == \"${email}\") | .expiration) |= ${exp_timestamp}" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}" || { echoColor red "Expiration update failed"; return 1; }
    echoColor green "User ${email} expiration renewed to: ${exp_date}"
}

# 生成订阅
generateSubscription() {
    local email=$1
    local uuid=$2
    local port=$3
    echoColor blue "Generating subscription for ${email}..."
    local sub_config="vless://${uuid}@${current_domain}:${port}?encryption=none&security=tls&type=tcp#${email}"
    echo "${sub_config}" >"${sub_dir}/${email}.txt"
    local base64_sub=$(echo -n "${sub_config}" | base64 -w 0)
    echoColor yellow "Subscription URL: https://${current_domain}/sub/${email}.txt"
    echoColor yellow "Base64 Subscription: ${base64_sub}"
    echo "${base64_sub}" >"${sub_dir}/${email}.base64"
    chmod 640 "${sub_dir}/${email}.txt" "${sub_dir}/${email}.base64"
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t UTF8 "${sub_config}"
        echoColor green "QR Code generated above"
    fi
    updateSubscriptionSummary
}

# 更新订阅汇总
updateSubscriptionSummary() {
    echoColor blue "Updating subscription summary..."
    > "${sub_all_file}"
    for sub_file in "${sub_dir}"/*.txt; do
        [[ -f "${sub_file}" ]] && cat "${sub_file}" >> "${sub_all_file}"
    done
    chmod 640 "${sub_all_file}"
    echoColor green "Subscription summary updated: https://${current_domain}/sub/all_subscriptions.txt"
}

# 查看所有用户及订阅
showUsers() {
    echoColor blue "Current user list:"
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray not installed"
        return
    fi
    jq -r '.inbounds[] | [.port, (.settings.clients[] | [.email, .id] | join(" - "))] | join(": ")' "${v2ray_config}" | while read -r line; do
        local port=$(echo "${line}" | cut -d':' -f1)
        local user_info=$(echo "${line}" | cut -d':' -f2-)
        local email=$(echo "${user_info}" | cut -d' ' -f2)
        local exp_time=$(jq -r ".users[] | select(.email == \"${email}\") | .expiration" "${expiration_file}" | xargs -I {} date -d @{} +%Y-%m-%d)
        echoColor yellow "Port ${port}: ${user_info} (Expires: ${exp_time})"
        if [[ -f "${sub_dir}/${email}.txt" ]]; then
            echoColor green "  Subscription: $(cat "${sub_dir}/${email}.txt")"
        fi
    done
}

# 检查到期用户
checkExpiration() {
    echoColor blue "Checking expired users..."
    if [[ ! -f "${expiration_file}" ]]; then
        echoColor yellow "No expiration records found"
        return
    fi

    local current_timestamp=$(date +%s)
    local updated=0
    local expired_users=()

    jq -c '.users[]' "${expiration_file}" | while read -r user; do
        local email=$(echo "${user}" | jq -r '.email')
        local exp_timestamp=$(echo "${user}" | jq -r '.expiration')
        if [[ "${current_timestamp}" -ge "${exp_timestamp}" ]]; then
            echoColor yellow "User ${email} has expired, disabling..."
            expired_users+=("${email}")
            updated=1
        fi
    done

    if [[ ${updated} -eq 1 ]]; then
        backupConfig
        local clients=$(cat "${v2ray_config}")
        for email in "${expired_users[@]}"; do
            local port=$(jq -r ".users[] | select(.email == \"${email}\") | .port" "${expiration_file}")
            clients=$(echo "${clients}" | jq -r "(.inbounds[] | select(.port == ${port}) | .settings.clients) -= [(.settings.clients[] | select(.email == \"${email}\"))]")
            rm -f "${sub_dir}/${email}.txt" "${sub_dir}/${email}.base64"
        done
        echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "Configuration update failed"; return 1; }
        local expiration_data=$(jq -r "del(.users[] | select(.email == \"${expired_users[*]}\"))" "${expiration_file}")
        echo "${expiration_data}" | jq . >"${expiration_file}"
        reloadCore
        echoColor green "Expired users disabled"
    else
        echoColor green "No expired users"
    fi
}

# 重载核心
reloadCore() {
    if systemctl is-active v2ray >/dev/null 2>&1; then
        systemctl restart v2ray || { echoColor red "V2Ray restart failed, check logs (${log_file})"; return 1; }
    else
        systemctl start v2ray || { echoColor red "V2Ray start failed, check logs (${log_file})"; return 1; }
    fi
}

# 服务管理
manageService() {
    echoColor blue "Managing V2Ray service..."
    echoColor yellow "1. Start V2Ray"
    echoColor yellow "2. Stop V2Ray"
    echoColor yellow "3. Restart V2Ray"
    read -r -p "Select action: " action
    case ${action} in
        1) systemctl start v2ray && echoColor green "V2Ray started" || echoColor red "Start failed" ;;
        2) systemctl stop v2ray && echoColor green "V2Ray stopped" || echoColor red "Stop failed" ;;
        3) reloadCore && echoColor green "V2Ray restarted" || echoColor red "Restart failed" ;;
        *) echoColor red "Invalid action" ;;
    esac
}

# 监控状态
monitorStatus() {
    echoColor blue "Monitoring V2Ray status..."
    if ! systemctl is-active v2ray >/dev/null 2>&1; then
        echoColor red "V2Ray is not running"
        return
    fi
    local uptime=$(systemctl status v2ray | grep "Active:" | awk '{print $4" "$5" "$6}')
    local connections=$(ss -tn | grep ":${default_port}" | wc -l)
    echoColor green "Status: Running"
    echoColor yellow "Uptime: ${uptime}"
    echoColor yellow "Active Connections: ${connections}"
}

# 流量统计
trafficStats() {
    echoColor blue "Traffic statistics..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray not installed"
        return
    fi
    grpcurl -plaintext -d '{"name": "api"}' 127.0.0.1:${api_port} v2ray.core.app.stats.command.StatsService.GetStats | jq -r '.stat[] | [.name, .value] | join(": ")' | while read -r stat; do
        local name=$(echo "${stat}" | cut -d':' -f1 | xargs)
        local value=$(echo "${stat}" | cut -d':' -f2 | xargs)
        if [[ "${name}" =~ "user" ]]; then
            local email=$(echo "${name}" | cut -d'>' -f2 | cut -d'_' -f1)
            local type=$(echo "${name}" | cut -d'_' -f2)
            local size=$(numfmt --to=iec-i --suffix=B "${value}")
            echoColor yellow "User: ${email}, ${type}: ${size}"
        fi
    done
}

# 导出配置
exportConfig() {
    echoColor blue "Exporting configuration..."
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="${backup_dir}/export_${timestamp}.tar.gz"
    tar -czf "${export_file}" "${v2ray_config}" "${expiration_file}" "${sub_dir}" || {
        echoColor red "Export failed"
        return 1
    }
    chmod 600 "${export_file}"
    echoColor green "Configuration exported to: ${export_file}"
}

# 导入配置
importConfig() {
    echoColor blue "Importing configuration..."
    read -r -p "Enter path to exported configuration file: " import_file
    if [[ ! -f "${import_file}" || ! "${import_file}" =~ \.tar\.gz$ ]]; then
        echoColor red "Invalid or missing export file"
        return 1
    fi
    backupConfig
    tar -xzf "${import_file}" -C "${config_dir}" || {
        echoColor red "Import failed"
        return 1
    }
    reloadCore
    echoColor green "Configuration imported successfully"
}

# 安装定时任务
installCron() {
    echoColor blue "Installing cron jobs..."
    if ! command -v crontab >/dev/null 2>&1; then
        ${install_cmd} cron || { echoColor red "Cron installation failed"; cleanup; exit 1; }
    fi
    crontab -l > /tmp/cron_backup 2>/dev/null || touch /tmp/cron_backup
    sed -i '/v2ray-agent/d' /tmp/cron_backup
    echo "0 2 * * * /bin/bash \"$(realpath "$0")\" check_expiration >> ${log_file} 2>&1" >> /tmp/cron_backup
    echo "0 3 * * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh >> ${log_file} 2>&1" >> /tmp/cron_backup
    echo "0 0 * * * truncate -s 0 ${log_file}" >> /tmp/cron_backup
    crontab /tmp/cron_backup || { echoColor red "Cron job installation failed"; cleanup; exit 1; }
    rm -f /tmp/cron_backup
    echoColor green "Cron jobs installed successfully"
}

# 备份配置
backupConfig() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "${v2ray_config}" "${backup_dir}/config_${timestamp}.json"
    cp "${expiration_file}" "${backup_dir}/expiration_${timestamp}.json"
}

# 清理残留
cleanup() {
    rm -f /tmp/v2ray.zip /tmp/cron_backup
}

# 检查安装状态
checkStatus() {
    if [[ ${installed} -eq 1 ]]; then
        local status=$(systemctl is-active v2ray)
        echoColor green "V2Ray installed, status: ${status}"
    else
        echoColor yellow "V2Ray not installed"
    fi
}

# 主菜单
menu() {
    echoColor red "===== V2Ray-Agent v${VERSION} ====="
    checkStatus
    echoColor yellow "1. Install V2Ray and Nginx"
    echoColor yellow "2. Add user"
    echoColor yellow "3. Delete user"
    echoColor yellow "4. Renew user expiration"
    echoColor yellow "5. View users and subscriptions"
    echoColor yellow "6. Check expired users"
    echoColor yellow "7. Manage V2Ray service"
    echoColor yellow "8. Monitor status"
    echoColor yellow "9. Traffic statistics"
    echoColor yellow "10. Export configuration"
    echoColor yellow "11. Import configuration"
    echoColor yellow "12. Exit"
    read -r -p "Select: " choice

    case ${choice} in
        1)
            checkNetwork
            checkSystem
            checkCPU
            initVars
            checkUpdate
            createDirs
            installTools
            installV2Ray
            installV2RayService
            manageFirewall
            initTLSandNginx
            initV2RayConfig
            installCron
            reloadCore
            echoColor green "Installation completed"
            echoColor yellow "Subscription URL: https://${current_domain}/sub/<email>.txt"
            ;;
        2)
            addUser
            ;;
        3)
            removeUser
            ;;
        4)
            renewUser
            ;;
        5)
            showUsers
            ;;
        6)
            checkExpiration
            ;;
        7)
            manageService
            ;;
        8)
            monitorStatus
            ;;
        9)
            trafficStats
            ;;
        10)
            exportConfig
            ;;
        11)
            importConfig
            ;;
        12)
            echoColor green "Exiting script"
            exit 0
            ;;
        *)
            echoColor red "Invalid option"
            ;;
    esac
    menu
}

# 参数处理
case "$1" in
    "check_expiration")
        initVars
        checkExpiration
        exit 0
        ;;
    *)
        initVars
        menu
        ;;
esac
