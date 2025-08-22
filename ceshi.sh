#!/bin/bash
# 一键开启 root 密码登录，适用于 Debian/Ubuntu
# 手动输入密码

read -sp "请输入要设置的 root 密码: " PWD
echo
read -sp "请再次输入 root 密码: " PWD2
echo

if [ "$PWD" != "$PWD2" ]; then
  echo "❌ 两次密码不一致，已退出"
  exit 1
fi

# 判断 SSH 服务名（Debian/Ubuntu 都是 ssh 或 sshd）
if systemctl list-units --full -all | grep -qE '^ssh\.service'; then
  SSH_SERVICE=ssh
else
  SSH_SERVICE=sshd
fi

# 修改或追加配置
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config && \
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || \
  echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

grep -q "^PermitRootLogin" /etc/ssh/sshd_config && \
  sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || \
  echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# 重启 SSH 服务
systemctl restart $SSH_SERVICE

# 设置 root 密码
echo "root:$PWD" | chpasswd

# 显示登录提示
IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
echo -e "\n✅ 已开启 root 密码登录"
echo "👉 可以用 ssh root@$IP 登录"
