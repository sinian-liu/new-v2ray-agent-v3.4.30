#!/usr/bin/env bash
# v2ray-agent 简化版（使用 certbot 自动申请证书，中文交互）
# 当前日期: 2025-03-01
# 作者: 基于 sinian-liu 的 v2ray-agent-2.5.73 重新设计并优化

# 版本号
VERSION="1.0.10"

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
        if [[ -f "/etc/centos-release" ]]; then
            centos_version=$(awk '{print $4}' /etc/centos-release | cut -d'.' -f1)
            [[ "${centos_version}" -lt 7 ]] && { echoColor red "不支持的系统，需要 CentOS 7+"; exit 1; }
        fi
    elif grep -qi "debian" /etc/issue || grep -qi "debian" /proc/version; then
        release="debian"
        install_cmd="apt -y install"
        update_cmd="apt update"
        debian_version=$(cat /etc/debian_version | cut -d'.' -f1)
        [[ "${debian_version}" -lt 9 ]] && { echoColor red "不支持的系统，需要 Debian 9+"; exit 1; }
    elif grep -qi "ubuntu" /etc/issue || grep -qi "ubuntu" /proc/version; then
        release="ubuntu"
        install_cmd="apt -y install"
        update_cmd="apt update"
        ubuntu_version=$(lsb_release -sr | cut -d'.' -f1)
        [[ "${ubuntu_version}" -lt 18 ]] && { echoColor red "不支持的系统，需要 Ubuntu 18.04+"; exit 1; }
    else
        echoColor red "不支持的系统，请使用 CentOS 7+、Debian 9+ 或 Ubuntu 18.04+"
        exit 1
    fi
}

# 检查 CPU 架构
checkCPU() {
    case "$(uname -m)" in
        'x86_64') cpu_arch="64" ;;
        'aarch64') cpu_arch="arm64-v8a" ;;
        *) echoColor red "不支持的 CPU 架构，仅支持 x86_64 和 aarch64"; exit 1 ;;
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
    echoColor blue "检查网络连接..."
    if ! ping -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echoColor red "无法连接到网络，请检查网络设置"
        exit 1
    fi
}

# 安装依赖工具
installTools() {
    echoColor blue "安装依赖工具..."
    ${update_cmd} || { echoColor red "系统更新失败，请检查网络或包管理器"; exit 1; }
    local tools="curl wget unzip jq nginx uuid-runtime qrencode python3 python3-pip certbot python3-certbot-nginx"
    echoColor yellow "安装基础工具: ${tools}"
    ${install_cmd} ${tools} || { 
        echoColor red "基础工具安装失败，请检查包管理器或网络连接"
        echoColor yellow "已尝试安装: ${tools}"
        cleanup
        exit 1
    }
    # 检查并升级 pip
    local pip_version=$(python3 -m pip --version | awk '{print $2}' | cut -d'.' -f1)
    if [[ -z "${pip_version}" || "${pip_version}" -lt 23 ]]; then
        echoColor yellow "pip 版本过旧，正在升级..."
        python3 -m pip install --upgrade pip || {
            echoColor red "pip 升级失败，请手动运行 'sudo python3 -m pip install --upgrade pip'"
            cleanup
            exit 1
        }
    fi
    # 安装 grpc-tools 通过 pip
    if ! command -v grpcurl >/dev/null 2>&1; then
        echoColor yellow "安装 grpc-tools..."
        python3 -m pip install grpcio-tools || {
            echoColor red "grpc-tools 安装失败，请检查 pip 或网络"
            echoColor yellow "尝试运行 'sudo python3 -m pip install grpcio-tools' 手动安装"
            cleanup
            exit 1
        }
    fi
    mkdir -p /var/log
    touch "${log_file}"
    chmod 640 "${log_file}"
}

# 创建目录
createDirs() {
    echoColor blue "创建必要目录..."
    mkdir -p "${config_dir}" "${tls_dir}" "${sub_dir}" "${config_dir}/v2ray" "${backup_dir}" || {
        echoColor red "目录创建失败，请检查权限"
        cleanup
        exit 1
    }
    chmod 700 "${config_dir}" "${tls_dir}" "${sub_dir}" "${config_dir}/v2ray" "${backup_dir}"
}

# 检查更新
checkUpdate() {
    echoColor blue "检查更新..."
    # 假设 GitHub 仓库 URL（需替换为实际可用 URL）
    local remote_version=$(curl -s https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh | grep "VERSION=" | head -1 | cut -d'"' -f2)
    if [[ -n "${remote_version}" && "${remote_version}" > "${VERSION}" ]]; then
        echoColor yellow "发现新版本: ${remote_version} (当前: ${VERSION})"
        read -r -p "是否现在更新? [y/N]: " update_choice
        if [[ "${update_choice}" =~ ^[Yy]$ ]]; then
            wget -q -O /tmp/v2ray-agent.sh "https://raw.githubusercontent.com/sinian-liu/v2ray-agent-2.5.73/master/install.sh" || {
                echoColor red "更新下载失败"
                return 1
            }
            chmod +x /tmp/v2ray-agent.sh
            mv /tmp/v2ray-agent.sh "$(realpath "$0")"
            echoColor green "已更新至版本 ${remote_version}"
            exec "$(realpath "$0")"
        fi
    else
        echoColor green "当前已是最新版本"
    fi
}

# 安装 V2Ray
installV2Ray() {
    echoColor blue "安装 V2Ray..."
    local latest_version=$(curl -s -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | jq -r .tag_name)
    if [[ -z "${latest_version}" ]]; then
        echoColor red "无法获取 V2Ray 最新版本，请检查网络或 GitHub API"
        cleanup
        exit 1
    fi
    local url="https://github.com/v2fly/v2ray-core/releases/download/${latest_version}/v2ray-linux-${cpu_arch}.zip"
    wget -q "${url}" -O /tmp/v2ray.zip || { echoColor red "V2Ray 下载失败，请检查网络"; cleanup; exit 1; }
    unzip -o /tmp/v2ray.zip -d "${config_dir}/v2ray" || { echoColor red "V2Ray 解压失败，请检查 unzip 工具"; cleanup; exit 1; }
    chmod +x "${v2ray_bin}"
    rm -f /tmp/v2ray.zip
}

# 配置 V2Ray 服务
installV2RayService() {
    echoColor blue "配置 V2Ray 服务..."
    cat <<EOF >/etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray 服务
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
    systemctl daemon-reload || { echoColor red "systemd 配置失败"; cleanup; exit 1; }
    systemctl enable v2ray
}

# 管理防火墙
manageFirewall() {
    echoColor blue "配置防火墙..."
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
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    else
        echoColor yellow "未检测到支持的防火墙工具，请手动开放 80、443 和 ${api_port} 端口"
    fi
}

# 初始化 TLS 证书并配置 Nginx（使用 certbot）
initTLSandNginx() {
    echoColor blue "配置 TLS 和 Nginx..."
    if [[ -f "${nginx_conf}" || -f "${v2ray_config}" ]]; then
        echoColor yellow "检测到现有配置，重新安装将覆盖。"
        read -r -p "是否继续? [y/N]: " overwrite_choice
        [[ ! "${overwrite_choice}" =~ ^[Yy]$ ]] && { echoColor red "安装已中止"; exit 1; }
    fi

    read -r -p "请输入域名 (必须解析到此服务器): " domain
    if [[ -z "${domain}" ]]; then
        echoColor red "域名不能为空"
        exit 1
    fi
    current_domain="${domain}"

    local server_ip=$(curl -s -m 5 "https://api.cloudflare.com/cdn-cgi/trace" | grep "ip=" | cut -d'=' -f2)
    if [[ -z "${server_ip}" ]]; then
        echoColor red "无法获取服务器 IP，请检查网络连接"
        exit 1
    fi
    local resolved_ip=$(dig +short "${current_domain}" A | grep -v '\.$' | tail -n1)
    if [[ -z "${resolved_ip}" || "${resolved_ip}" != "${server_ip}" ]]; then
        echoColor red "域名未解析到本地 IP (${server_ip})，解析结果: ${resolved_ip}"
        echoColor yellow "请在 DNS 设置中将 A 记录指向 ${server_ip}，并暂时关闭 Cloudflare 橙云"
        exit 1
    fi

    # 清空可能由 certbot 生成的重复配置
    echoColor yellow "清理旧的 Nginx 配置..."
    rm -f /etc/nginx/sites-enabled/* 2>/dev/null
    rm -f /etc/nginx/conf.d/*.conf 2>/dev/null

    # 生成初始 Nginx 配置（用于 certbot 验证）
    cat <<EOF >/etc/nginx/conf.d/initial.conf
server {
    listen 80;
    server_name ${current_domain};
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF
    mkdir -p /var/www/html
    echo "<h1>V2Ray Agent Initial Config</h1>" >/var/www/html/index.html
    chmod 644 /var/www/html/index.html
    nginx -t || { echoColor red "初始 Nginx 配置校验失败"; cleanup; exit 1; }
    systemctl restart nginx || { echoColor red "Nginx 重启失败，请检查日志 (/var/log/nginx/error.log)"; cleanup; exit 1; }

    # 使用 certbot 申请证书
    echoColor yellow "使用 certbot 为 ${current_domain} 申请 Let’s Encrypt 证书..."
    certbot --nginx -d "${current_domain}" --non-interactive --agree-tos --email "admin@${current_domain}" || {
        echoColor red "证书申请失败，请检查网络、域名解析或 certbot 日志 (/var/log/letsencrypt/letsencrypt.log)"
        cleanup
        exit 1
    }

    # 获取 certbot 生成的证书路径
    local cert_path="/etc/letsencrypt/live/${current_domain}/fullchain.pem"
    local key_path="/etc/letsencrypt/live/${current_domain}/privkey.pem"
    if [[ ! -f "${cert_path}" || ! -f "${key_path}" ]]; then
        echoColor red "证书文件未找到，请检查 certbot 是否正确安装证书"
        cleanup
        exit 1
    fi

    # 复制证书到指定目录
    cp "${cert_path}" "${tls_dir}/${current_domain}.crt" || {
        echoColor red "复制证书文件失败"
        cleanup
        exit 1
    }
    cp "${key_path}" "${tls_dir}/${current_domain}.key" || {
        echoColor red "复制私钥文件失败"
        cleanup
        exit 1
    }
    chmod 600 "${tls_dir}"/*

    # 生成最终 Nginx 配置
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
    nginx -t || { echoColor red "Nginx 配置校验失败，请检查 ${nginx_conf}"; cleanup; exit 1; }
    systemctl restart nginx || { echoColor red "Nginx 重启失败，请检查日志 (/var/log/nginx/error.log)"; cleanup; exit 1; }
    echoColor yellow "安装完成后，可在 Cloudflare 启用橙云以使用完整功能"
}

# 初始化 V2Ray 配置（支持多端口和 API）
initV2RayConfig() {
    echoColor blue "初始化 V2Ray 配置..."
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
    "${v2ray_bin}" test -config "${v2ray_config}" || {
        echoColor red "V2Ray 配置测试失败，请检查配置 ${v2ray_config}"
        cleanup
        exit 1
    }
}

# 添加用户（支持多端口）
addUser() {
    echoColor blue "添加用户..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray 未安装，请先安装"
        return 1
    fi
    local retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "请输入用户 email: " email
        if [[ -z "${email}" ]] || ! echo "${email}" | grep -q "@" || jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
            echoColor red "email 无效、空或已存在"
            read -r -p "是否重试? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${email}" ]] && return 1

    retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "请输入到期时间 (YYYY-MM-DD): " exp_date
        if ! date -d "${exp_date}" >/dev/null 2>&1; then
            echoColor red "到期时间格式错误，应为 YYYY-MM-DD"
            read -r -p "是否重试? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${exp_date}" ]] && return 1

    read -r -p "请输入端口 (默认 ${default_port}，或新端口): " port
    [[ -z "${port}" ]] && port=${default_port}
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ "${port}" -lt 1 || "${port}" -gt 65535 ]]; then
        echoColor red "端口号无效，必须为 1-65535"
        return 1
    fi
    # 检查端口是否已被占用
    if ss -tuln | grep -q ":${port} "; then
        echoColor red "端口 ${port} 已被占用，请选择其他端口"
        return 1
    fi

    backupConfig
    local uuid=$(uuidgen)
    local inbound_exists=$(jq -r ".inbounds[] | select(.port == ${port})" "${v2ray_config}")
    if [[ -z "${inbound_exists}" ]]; then
        local new_inbound=$(jq -r ".inbounds += [{\"port\": ${port}, \"protocol\": \"vless\", \"settings\": {\"clients\": [{\"id\": \"${uuid}\", \"email\": \"${email}\"}], \"decryption\": \"none\"}, \"streamSettings\": {\"network\": \"tcp\", \"security\": \"tls\", \"tlsSettings\": {\"alpn\": [\"http/1.1\"], \"certificates\": [{\"certificateFile\": \"${tls_dir}/${current_domain}.crt\", \"keyFile\": \"${tls_dir}/${current_domain}.key\"}]}}}]" "${v2ray_config}")
        echo "${new_inbound}" | jq . >"${v2ray_config}" || { echoColor red "配置更新失败"; return 1; }
    else
        local clients=$(jq -r "(.inbounds[] | select(.port == ${port}) | .settings.clients) += [{\"id\": \"${uuid}\", \"email\": \"${email}\"}]" "${v2ray_config}")
        echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "配置更新失败"; return 1; }
    fi

    if [[ ! -f "${expiration_file}" ]]; then
        echo '{"users":[]}' >"${expiration_file}"
    fi
    local exp_timestamp=$(date -d "${exp_date}" +%s)
    local expiration_data=$(jq -r ".users += [{\"email\": \"${email}\", \"expiration\": ${exp_timestamp}, \"port\": ${port}}]" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}" || { echoColor red "到期信息更新失败"; return 1; }
    chmod 600 "${expiration_file}"

    echoColor green "用户 ${email} 添加成功，端口 ${port}，到期时间: ${exp_date}"
    generateSubscription "${email}" "${uuid}" "${port}"
    reloadCore
}

# 删除用户
removeUser() {
    echoColor blue "删除用户..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray 未安装"
        return 1
    fi
    local retry=1
    while [[ ${retry} -eq 1 ]]; do
        read -r -p "请输入要删除的用户 email: " email
        if ! jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
            echoColor red "用户不存在"
            read -r -p "是否重试? [y/N]: " retry_choice
            [[ ! "${retry_choice}" =~ ^[Yy]$ ]] && retry=0 || retry=1
        else
            retry=0
        fi
    done
    [[ ${retry} -eq 0 && -z "${email}" ]] && return 1

    backupConfig
    local port=$(jq -r ".users[] | select(.email == \"${email}\") | .port" "${expiration_file}")
    local clients=$(jq -r "(.inbounds[] | select(.port == ${port}) | .settings.clients) -= [(.settings.clients[] | select(.email == \"${email}\"))]" "${v2ray_config}")
    echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "配置更新失败"; return 1; }
    local expiration_data=$(jq -r "del(.users[] | select(.email == \"${email}\"))" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}"
    rm -f "${sub_dir}/${email}.txt" "${sub_dir}/${email}.base64"
    echoColor green "用户 ${email} 已从端口 ${port} 删除"
    reloadCore
}

# 续期用户
renewUser() {
    echoColor blue "续期用户..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray 未安装"
        return 1
    fi
    read -r -p "请输入要续期的用户 email: " email
    if ! jq -r ".inbounds[].settings.clients[] | select(.email == \"${email}\")" "${v2ray_config}" | grep -q .; then
        echoColor red "用户不存在"
        return 1
    fi
    read -r -p "请输入新的到期时间 (YYYY-MM-DD): " exp_date
    if ! date -d "${exp_date}" >/dev/null 2>&1; then
        echoColor red "到期时间格式错误，应为 YYYY-MM-DD"
        return 1
    fi

    backupConfig
    local exp_timestamp=$(date -d "${exp_date}" +%s)
    local expiration_data=$(jq -r "(.users[] | select(.email == \"${email}\") | .expiration) |= ${exp_timestamp}" "${expiration_file}")
    echo "${expiration_data}" | jq . >"${expiration_file}" || { echoColor red "到期信息更新失败"; return 1; }
    echoColor green "用户 ${email} 到期时间更新为: ${exp_date}"
}

# 生成订阅
generateSubscription() {
    local email=$1
    local uuid=$2
    local port=$3
    echoColor blue "为 ${email} 生成订阅链接..."
    local sub_config="vless://${uuid}@${current_domain}:${port}?encryption=none&security=tls&type=tcp#${email}"
    echo "${sub_config}" >"${sub_dir}/${email}.txt"
    local base64_sub=$(echo -n "${sub_config}" | base64 -w 0)
    echoColor yellow "订阅链接: https://${current_domain}/sub/${email}.txt"
    echoColor yellow "Base64 订阅: ${base64_sub}"
    echo "${base64_sub}" >"${sub_dir}/${email}.base64"
    chmod 640 "${sub_dir}/${email}.txt" "${sub_dir}/${email}.base64"
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t UTF8 "${sub_config}"
        echoColor green "二维码已生成，见上方"
    fi
    updateSubscriptionSummary
}

# 更新订阅汇总
updateSubscriptionSummary() {
    echoColor blue "更新订阅汇总..."
    > "${sub_all_file}"
    for sub_file in "${sub_dir}"/*.txt; do
        [[ -f "${sub_file}" ]] && cat "${sub_file}" >> "${sub_all_file}"
    done
    chmod 640 "${sub_all_file}"
    echoColor green "订阅汇总已更新: https://${current_domain}/sub/all_subscriptions.txt"
}

# 查看所有用户及订阅
showUsers() {
    echoColor blue "当前用户列表:"
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray 未安装"
        return
    fi
    jq -r '.inbounds[] | [.port, (.settings.clients[] | [.email, .id] | join(" - "))] | join(": ")' "${v2ray_config}" | while read -r line; do
        local port=$(echo "${line}" | cut -d':' -f1)
        local user_info=$(echo "${line}" | cut -d':' -f2-)
        local email=$(echo "${user_info}" | cut -d' ' -f2)
        local exp_time=$(jq -r ".users[] | select(.email == \"${email}\") | .expiration" "${expiration_file}" | xargs -I {} date -d @{} +%Y-%m-%d)
        echoColor yellow "端口 ${port}: ${user_info} (到期时间: ${exp_time})"
        if [[ -f "${sub_dir}/${email}.txt" ]]; then
            echoColor green "  订阅: $(cat "${sub_dir}/${email}.txt")"
        fi
    done
}

# 检查到期用户
checkExpiration() {
    echoColor blue "检查过期用户..."
    if [[ ! -f "${expiration_file}" ]]; then
        echoColor yellow "未找到到期记录"
        return
    fi

    local current_timestamp=$(date +%s)
    local updated=0
    local expired_users=()

    jq -c '.users[]' "${expiration_file}" | while read -r user; do
        local email=$(echo "${user}" | jq -r '.email')
        local exp_timestamp=$(echo "${user}" | jq -r '.expiration')
        if [[ "${current_timestamp}" -ge "${exp_timestamp}" ]]; then
            echoColor yellow "用户 ${email} 已过期，正在禁用..."
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
        echo "${clients}" | jq . >"${v2ray_config}" || { echoColor red "配置更新失败"; return 1; }
        local expiration_data=$(jq -r "del(.users[] | select(.email == \"${expired_users[*]}\"))" "${expiration_file}")
        echo "${expiration_data}" | jq . >"${expiration_file}"
        reloadCore
        echoColor green "过期用户已禁用"
    else
        echoColor green "无过期用户"
    fi
}

# 重载核心
reloadCore() {
    if systemctl is-active v2ray >/dev/null 2>&1; then
        systemctl restart v2ray || { echoColor red "V2Ray 重启失败，请检查日志 (${log_file})"; return 1; }
    else
        systemctl start v2ray || { echoColor red "V2Ray 启动失败，请检查日志 (${log_file})"; return 1; }
    fi
}

# 服务管理
manageService() {
    echoColor blue "管理 V2Ray 服务..."
    echoColor yellow "1. 启动 V2Ray"
    echoColor yellow "2. 停止 V2Ray"
    echoColor yellow "3. 重启 V2Ray"
    read -r -p "选择操作: " action
    case ${action} in
        1) systemctl start v2ray && echoColor green "V2Ray 已启动" || echoColor red "启动失败" ;;
        2) systemctl stop v2ray && echoColor green "V2Ray 已停止" || echoColor red "停止失败" ;;
        3) reloadCore && echoColor green "V2Ray 已重启" || echoColor red "重启失败" ;;
        *) echoColor red "无效操作" ;;
    esac
}

# 监控状态
monitorStatus() {
    echoColor blue "监控 V2Ray 状态..."
    if ! systemctl is-active v2ray >/dev/null 2>&1; then
        echoColor red "V2Ray 未运行"
        return
    fi
    local uptime=$(systemctl status v2ray | grep "Active:" | awk '{print $4" "$5" "$6}')
    local connections=$(ss -tn | grep ":${default_port}" | wc -l)
    echoColor green "状态: 运行中"
    echoColor yellow "运行时间: ${uptime}"
    echoColor yellow "活动连接数: ${connections}"
}

# 流量统计
trafficStats() {
    echoColor blue "流量统计..."
    if [[ ! -f "${v2ray_config}" ]]; then
        echoColor red "V2Ray 未安装"
        return
    fi
    grpcurl -plaintext -d '{"name": "api"}' 127.0.0.1:${api_port} v2ray.core.app.stats.command.StatsService.GetStats | jq -r '.stat[] | [.name, .value] | join(": ")' | while read -r stat; do
        local name=$(echo "${stat}" | cut -d':' -f1 | xargs)
        local value=$(echo "${stat}" | cut -d':' -f2 | xargs)
        if [[ "${name}" =~ "user" ]]; then
            local email=$(echo "${name}" | cut -d'>' -f2 | cut -d'_' -f1)
            local type=$(echo "${name}" | cut -d'_' -f2)
            local size=$(numfmt --to=iec-i --suffix=B "${value}")
            if [[ "${type}" == "uplink" ]]; then
                echoColor yellow "用户: ${email}, 上行流量: ${size}"
            elif [[ "${type}" == "downlink" ]]; then
                echoColor yellow "用户: ${email}, 下行流量: ${size}"
            fi
        fi
    done
}

# 导出配置
exportConfig() {
    echoColor blue "导出配置..."
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="${backup_dir}/export_${timestamp}.tar.gz"
    tar -czf "${export_file}" "${v2ray_config}" "${expiration_file}" "${sub_dir}" || {
        echoColor red "导出失败"
        return 1
    }
    chmod 600 "${export_file}"
    echoColor green "配置已导出至: ${export_file}"
}

# 导入配置
importConfig() {
    echoColor blue "导入配置..."
    read -r -p "请输入导出的配置文件路径: " import_file
    if [[ ! -f "${import_file}" || ! "${import_file}" =~ \.tar\.gz$ ]]; then
        echoColor red "无效或不存在的导出文件"
        return 1
    fi
    backupConfig
    tar -xzf "${import_file}" -C "${config_dir}" || {
        echoColor red "导入失败"
        return 1
    }
    reloadCore
    echoColor green "配置导入成功"
}

# 安装定时任务
installCron() {
    echoColor blue "安装定时任务..."
    if ! command -v crontab >/dev/null 2>&1; then
        ${install_cmd} cron || { echoColor red "Cron 安装失败"; cleanup; exit 1; }
    fi
    crontab -l > /tmp/cron_backup 2>/dev/null || touch /tmp/cron_backup
    sed -i '/v2ray-agent/d' /tmp/cron_backup
    echo "0 2 * * * /bin/bash \"$(realpath "$0")\" check_expiration >> ${log_file} 2>&1" >> /tmp/cron_backup
    echo "0 3 * * * certbot renew --quiet >> ${log_file} 2>&1" >> /tmp/cron_backup
    echo "0 0 * * * truncate -s 0 ${log_file}" >> /tmp/cron_backup
    crontab /tmp/cron_backup || { echoColor red "定时任务安装失败"; cleanup; exit 1; }
    rm -f /tmp/cron_backup
    echoColor green "定时任务安装成功"
}

# 备份配置
backupConfig() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "${v2ray_config}" "${backup_dir}/config_${timestamp}.json" 2>/dev/null
    cp "${expiration_file}" "${backup_dir}/expiration_${timestamp}.json" 2>/dev/null
}

# 清理残留
cleanup() {
    rm -f /tmp/v2ray.zip /tmp/cron_backup
}

# 检查安装状态
checkStatus() {
    if [[ ${installed} -eq 1 ]]; then
        local status=$(systemctl is-active v2ray)
        echoColor green "V2Ray 已安装，状态: ${status}"
    else
        echoColor yellow "V2Ray 未安装"
    fi
}

# 主菜单
menu() {
    echoColor red "===== V2Ray-Agent v${VERSION} ====="
    checkStatus
    echoColor yellow "1. 安装 V2Ray 和 Nginx"
    echoColor yellow "2. 添加用户"
    echoColor yellow "3. 删除用户"
    echoColor yellow "4. 续期用户"
    echoColor yellow "5. 查看用户和订阅"
    echoColor yellow "6. 检查过期用户"
    echoColor yellow "7. 管理 V2Ray 服务"
    echoColor yellow "8. 监控状态"
    echoColor yellow "9. 流量统计"
    echoColor yellow "10. 导出配置"
    echoColor yellow "11. 导入配置"
    echoColor yellow "12. 退出"
    read -r -p "请选择: " choice

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
            echoColor green "安装完成"
            echoColor yellow "订阅地址: https://${current_domain}/sub/<email>.txt"
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
            echoColor green "退出脚本"
            exit 0
            ;;
        *)
            echoColor red "无效选项"
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
