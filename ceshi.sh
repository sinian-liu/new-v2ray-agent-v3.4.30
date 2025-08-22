#!/bin/bash
# 跨 Debian / Ubuntu / CentOS 通用的一键开启 root 密码登录脚本

# ===== 权限检测 =====
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 必须以 root 权限运行！"
  exit 1
fi

# ===== 输入密码 =====
echo "🔑 请输入 root 新密码："
read -s PASSWORD1
echo
echo "🔑 请再次输入 root 新密码："
read -s PASSWORD2
echo

if [ "$PASSWORD1" != "$PASSWORD2" ]; then
  echo "❌ 两次密码输入不一致，已退出"
  exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"

# ===== 修改配置，确保唯一 =====
sed -i '/^PasswordAuthentication/d' $SSHD_CONFIG
sed -i '/^PermitRootLogin/d' $SSHD_CONFIG
sed -i '/^UsePAM/d' $SSHD_CONFIG

echo "PasswordAuthentication yes" >> $SSHD_CONFIG
echo "PermitRootLogin yes" >> $SSHD_CONFIG
echo "UsePAM yes" >> $SSHD_CONFIG

# ===== 设置 root 密码 =====
echo "root:${PASSWORD1}" | chpasswd

# ===== 重启 SSH 服务（兼容多种系统） =====
if systemctl restart sshd 2>/dev/null; then
  SSH_SERVICE=sshd
elif systemctl restart ssh 2>/dev/null; then
  SSH_SERVICE=ssh
elif service ssh restart 2>/dev/null; then
  SSH_SERVICE=ssh
else
  echo "⚠️ SSH 服务未找到，请手动重启"
  exit 1
fi

# ===== 验证配置是否生效 =====
echo "✅ 配置已修改完成，验证结果："
grep -E "^(PasswordAuthentication|PermitRootLogin|UsePAM)" $SSHD_CONFIG

# ===== 获取公网 IP =====
IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')

echo -e "\n🎉 已开启 root 密码登录"
echo "👉 现在你可以使用: ssh root@${IP}"
echo "⚠️ 出于安全考虑，脚本不再打印密码，请使用你刚输入的密码登录。"
