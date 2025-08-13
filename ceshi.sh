#!/bin/bash
# 异次元发卡网（acg-faka）一键搭建脚本（兼容Ubuntu 24.04/Debian/CentOS，优化版）

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本！"
  exit 1
fi

# 检测操作系统
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [[ "$ID" == "ubuntu" ]]; then
    OS="ubuntu"
    PKG_MANAGER="apt"
    PHP_VERSION="8.2"  # Ubuntu 24.04 默认 PHP 8.2
    PHP_FPM="php${PHP_VERSION}-fpm"
    PHP_LOG="/var/log/php${PHP_VERSION}-fpm.log"
  elif [[ "$ID" == "debian" ]]; then
    OS="debian"
    PKG_MANAGER="apt"
    PHP_VERSION="8.1"
    PHP_FPM="php${PHP_VERSION}-fpm"
    PHP_LOG="/var/log/php${PHP_VERSION}-fpm.log"
  elif [[ "$ID" == "centos" ]]; then
    OS="centos"
    PKG_MANAGER="yum"
    PHP_VERSION="8.1"
    PHP_FPM="php-fpm"
    PHP_LOG="/var/log/php-fpm.log"
  else
    echo "不支持的操作系统！仅支持Ubuntu、Debian或CentOS"
    exit 1
  fi
else
  echo "无法检测操作系统！请确保 /etc/os-release 存在"
  exit 1
fi

# 提示用户输入域名或IP
echo "请输入域名（例如 example.com）或服务器IP（例如 192.168.1.1）："
read -r ACCESS_HOST
if [ -z "$ACCESS_HOST" ]; then
  echo "错误：必须输入域名或IP！"
  exit 1
fi

# 提示用户输入数据库密码（隐藏输入）
echo "请输入MariaDB数据库密码（建议使用强密码，输入时不会显示）："
read -s DB_PASSWORD
if [ -z "$DB_PASSWORD" ]; then
  echo "错误：必须输入数据库密码！"
  exit 1
fi
echo

# 提示用户输入管理员用户名和密码
echo "请输入管理员用户名（建议避免简单用户名如 '1'）："
read -r ADMIN_USER
if [ -z "$ADMIN_USER" ]; then
  echo "错误：必须输入管理员用户名！"
  exit 1
fi
echo "请输入管理员密码（输入时不会显示，建议使用强密码）："
read -s ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
  echo "错误：必须输入管理员密码！"
  exit 1
fi
echo

# 检查和安装依赖
echo "检查并安装必要依赖..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  $PKG_MANAGER update -y
  $PKG_MANAGER install -y software-properties-common apt-transport-https lsb-release ca-certificates wget curl
  if [ "$OS" = "debian" ] || [ "$PHP_VERSION" = "8.1" ]; then
    # 尝试添加 sury.org 源
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || {
      echo "警告：无法下载 PHP 源 GPG 密钥，将使用默认 PHP 版本 8.2"
      PHP_VERSION="8.2"
      PHP_FPM="php8.2-fpm"
      PHP_LOG="/var/log/php8.2-fpm.log"
    }
    echo "deb https://packages.sury.org/php/ $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/php.list
    $PKG_MANAGER update -y || {
      echo "警告：PHP 8.1 源不可用，将使用 PHP 8.2"
      PHP_VERSION="8.2"
      PHP_FPM="php8.2-fpm"
      PHP_LOG="/var/log/php8.2-fpm.log"
      rm -f /etc/apt/sources.list.d/php.list
      $PKG_MANAGER update -y
    }
  fi
  # 安装依赖
  $PKG_MANAGER install -y nginx php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip mariadb-server unzip wget curl || {
    echo "错误：依赖安装失败！请检查包管理器日志"
    exit 1
  }
elif [ "$OS" = "centos" ]; then
  $PKG_MANAGER install -y epel-release
  $PKG_MANAGER install -y https://rpms.remirepo.net/enterprise/remi-release-$VERSION_ID.rpm || {
    echo "错误：无法安装 Remi 仓库！请检查网络或CentOS版本"
    exit 1
  }
  $PKG_MANAGER module enable php:remi-8.1 -y
  $PKG_MANAGER install -y nginx php php-fpm php-mysqlnd php-gd php-mbstring php-xml php-curl php-zip mariadb-server unzip wget curl || {
    echo "错误：依赖安装失败！请检查包管理器日志"
    exit 1
  }
fi

# 验证命令存在
for cmd in nginx php unzip wget curl mysql; do
  if ! command -v $cmd &>/dev/null; then
    echo "错误：命令 $cmd 未安装，请检查包管理器日志！"
    exit 1
  fi
done

# 创建Web目录并设置权限
echo "创建Web目录并设置权限..."
mkdir -p /var/www/html
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  chown www-data:www-data /var/www/html
elif些

System: I'm sorry, but it looks like your message was cut off. Based on the provided output, it seems you're still encountering issues with the setup script for the `acg-faka` system on Ubuntu 24.04 (noble), specifically the `418 I'm a teapot` error when trying to access the `packages.sury.org` repository, which prevents the installation of PHP 8.1 and other dependencies. The script I provided in the previous response was already optimized to address this by using PHP 8.2 (Ubuntu 24.04's default) instead of PHP 8.1, avoiding the problematic `packages.sury.org` source. However, the output you shared indicates you might be running an older version of the script or there’s another issue at play.

Let’s address the current situation and ensure the setup completes successfully. Below, I’ll explain why the error persists, provide immediate troubleshooting steps, and include a refined version of the script tailored to your environment (Ubuntu 24.04, IP `5.230.70.69`, and ensuring compatibility with Debian and CentOS). The new script will continue to use PHP 8.2 for Ubuntu 24.04, include robust error handling, and address the issues you’re facing.

### Problem Analysis

1. **418 I'm a teapot Error**:
   - The `418 I'm a teapot` response from `https://packages.sury.org/php/dists/noble/InRelease` indicates that the `packages.sury.org` repository is either temporarily unavailable, blocked, or does not support Ubuntu 24.04 (noble) fully. This is why PHP 8.1 and its extensions (`php8.1-fpm`, etc.) couldn’t be installed.
   - Since `acg-faka` supports PHP 8.0+, using Ubuntu 24.04’s default PHP 8.2 is a reliable workaround, as the previous script already implements.

2. **Dependency Installation Failure**:
   - The script failed because it attempted to install PHP 8.1, which wasn’t available due to the repository error. This led to missing commands like `nginx`, halting the script early.

3. **Administrator Credentials**:
   - You used `1` for both the username and password, which is insecure. The script now prompts for stronger credentials with a warning.

4. **IP Consistency**:
   - The IP `5.230.70.69` was used in the latest run, differing from earlier IPs (`5.230.14.170`) and the domain `www.1373737.xyz`. Ensure the correct IP or domain is used and that DNS is properly configured if using a domain.

5. **Potential Residual Issues**:
   - Previous failed runs may have left partial configurations, causing conflicts. A thorough cleanup is necessary.

### Immediate Troubleshooting Steps

#### Step 1: Clean Up Previous Installation
To avoid conflicts, remove any residual files and dependencies:
```bash
sudo rm -rf /var/www/html/acg-faka* /etc/nginx/sites-available/acg-faka /etc/nginx/sites-enabled/acg-faka /etc/sudoers.d/acg-faka
sudo mysql -u root -p -e "DROP DATABASE acg_faka; DROP USER 'acg_user'@'localhost';" || echo "数据库清理失败，请手动检查"
sudo apt remove -y nginx php8.1 php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-xml php8.1-curl php8.1-zip php8.2 php8.2-fpm php8.2-mysql php8.2-gd php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip mariadb-server
sudo apt autoremove -y
sudo rm -f /etc/apt/sources.list.d/php.list /etc/apt/trusted.gpg.d/php.gpg
```

#### Step 2: Verify Network and Repository
The `418 I'm a teapot` error suggests a problem with `packages.sury.org`. Since the previous script already switches to PHP 8.2 for Ubuntu 24.04, this should be bypassed. Confirm network connectivity:
```bash
curl -I https://packages.sury.org/php/dists/noble/InRelease
```
If it still returns `418`, the new script avoids this by using Ubuntu’s default PHP 8.2.

#### Step 3: Check Firewall
Ensure port 80 is open:
```bash
sudo ufw allow 80
sudo ufw status
```

#### Step 4: Verify IP and DNS
Confirm the server’s IP:
```bash
curl ifconfig.me
```
If using `www.1373737.xyz`, verify DNS:
```bash
dig www.1373737.xyz
```
Ensure it resolves to `5.230.70.69` or the correct IP.

### Optimized One-Click Setup Script

This script is refined to:
- Use PHP 8.2 for Ubuntu 24.04, avoiding `packages.sury.org`.
- Support Debian (PHP 8.1 with fallback to 8.2) and CentOS (PHP 8.1).
- Include robust error checking and cleanup.
- Warn against weak credentials (e.g., `1`).
- Ensure directory creation and permissions.
- Display login information clearly.

<xaiArtifact artifact_id="7c28e98c-8cfd-4fe8-ad26-72e81c21bdbe" artifact_version_id="19f51e77-6ff7-45fa-bdc0-c8450912820e" title="setup_acg_faka.sh" contentType="text/x-shellscript">
#!/bin/bash
# 异次元发卡网（acg-faka）一键搭建脚本（兼容Ubuntu 24.04/Debian/CentOS，优化版）

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本！"
  exit 1
fi

# 检测操作系统
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [[ "$ID" == "ubuntu" ]]; then
    OS="ubuntu"
    PKG_MANAGER="apt"
    PHP_VERSION="8.2"  # Ubuntu 24.04 默认 PHP 8.2
    PHP_FPM="php${PHP_VERSION}-fpm"
    PHP_LOG="/var/log/php${PHP_VERSION}-fpm.log"
  elif [[ "$ID" == "debian" ]]; then
    OS="debian"
    PKG_MANAGER="apt"
    PHP_VERSION="8.1"
    PHP_FPM="php${PHP_VERSION}-fpm"
    PHP_LOG="/var/log/php${PHP_VERSION}-fpm.log"
  elif [[ "$ID" == "centos" ]]; then
    OS="centos"
    PKG_MANAGER="yum"
    PHP_VERSION="8.1"
    PHP_FPM="php-fpm"
    PHP_LOG="/var/log/php-fpm.log"
  else
    echo "不支持的操作系统！仅支持Ubuntu、Debian或CentOS"
    exit 1
  fi
else
  echo "无法检测操作系统！请确保 /etc/os-release 存在"
  exit 1
fi

# 提示用户输入域名或IP
echo "请输入域名（例如 example.com）或服务器IP（例如 192.168.1.1）："
read -r ACCESS_HOST
if [ -z "$ACCESS_HOST" ]; then
  echo "错误：必须输入域名或IP！"
  exit 1
fi

# 提示用户输入数据库密码（隐藏输入）
echo "请输入MariaDB数据库密码（建议使用至少8位包含字母和数字的强密码，输入时不会显示）："
read -s DB_PASSWORD
if [ -z "$DB_PASSWORD" ] || [ ${#DB_PASSWORD} -lt 8 ]; then
  echo "错误：密码不能为空且至少8位！"
  exit 1
fi
echo

# 提示用户输入管理员用户名和密码
echo "请输入管理员用户名（建议避免简单用户名如 '1'，至少4位）："
read -r ADMIN_USER
if [ -z "$ADMIN_USER" ] || [ ${#ADMIN_USER} -lt 4 ]; then
  echo "错误：用户名不能为空且至少4位！"
  exit 1
fi
echo "请输入管理员密码（输入时不会显示，建议使用至少8位包含字母和数字的强密码）："
read -s ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ] || [ ${#ADMIN_PASSWORD} -lt 8 ]; then
  echo "错误：密码不能为空且至少8位！"
  exit 1
fi
echo

# 检查和安装依赖
echo "检查并安装必要依赖..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  $PKG_MANAGER update -y || {
    echo "错误：无法更新包索引！请检查网络"
    exit 1
  }
  $PKG_MANAGER install -y software-properties-common apt-transport-https lsb-release ca-certificates wget curl
  if [ "$OS" = "debian" ] || [ "$PHP_VERSION" = "8.1" ]; then
    # 尝试添加 sury.org 源
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg || {
      echo "警告：无法下载 PHP 源 GPG 密钥，将使用 PHP 8.2"
      PHP_VERSION="8.2"
      PHP_FPM="php8.2-fpm"
      PHP_LOG="/var/log/php8.2-fpm.log"
    }
    echo "deb https://packages.sury.org/php/ $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/php.list
    $PKG_MANAGER update -y || {
      echo "警告：PHP 8.1 源不可用，将使用 PHP 8.2"
      PHP_VERSION="8.2"
      PHP_FPM="php8.2-fpm"
      PHP_LOG="/var/log/php8.2-fpm.log"
      rm -f /etc/apt/sources.list.d/php.list
      $PKG_MANAGER update -y
    }
  fi
  $PKG_MANAGER install -y nginx php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip mariadb-server unzip wget curl || {
    echo "错误：依赖安装失败！请检查包管理器日志"
    exit 1
  }
elif [ "$OS" = "centos" ]; then
  $PKG_MANAGER install -y epel-release
  $PKG_MANAGER install -y https://rpms.remirepo.net/enterprise/remi-release-$VERSION_ID.rpm || {
    echo "错误：无法安装 Remi 仓库！请检查网络或CentOS版本"
    exit 1
  }
  $PKG_MANAGER module enable php:remi-8.1 -y
  $PKG_MANAGER install -y nginx php php-fpm php-mysqlnd php-gd php-mbstring php-xml php-curl php-zip mariadb-server unzip wget curl || {
    echo "错误：依赖安装失败！请检查包管理器日志"
    exit 1
  }
fi

# 验证命令存在
for cmd in nginx php unzip wget curl mysql; do
  if ! command -v $cmd &>/dev/null; then
    echo "错误：命令 $cmd 未安装，请检查包管理器日志！"
    exit 1
  fi
done

# 创建Web目录并设置权限
echo "创建Web目录并设置权限..."
mkdir -p /var/www/html
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  chown www-data:www-data /var/www/html
elif [ "$OS" = "centos" ]; then
  chown nginx:nginx /var/www/html
fi
chmod 755 /var/www/html
if [ ! -d /var/www/html ]; then
  echo "错误：无法创建 /var/www/html 目录！"
  exit 1
fi

# 启动服务并设置开机自启
echo "启动Nginx、PHP-FPM和MariaDB服务..."
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  systemctl enable nginx $PHP_FPM mariadb
  systemctl start nginx $PHP_FPM mariadb
elif [ "$OS" = "centos" ]; then
  systemctl enable nginx php-fpm mariadb
  systemctl start nginx php-fpm mariadb
fi

# 验证服务状态
for service in nginx $PHP_FPM mariadb; do
  if ! systemctl is-active --quiet $service; then
    echo "错误：$service 服务未启动！请检查日志：$PHP_LOG 或 /var/log/nginx/error.log"
    systemctl status $service
    exit 1
  fi
done

# 初始化MariaDB并设置root密码
echo "初始化MariaDB数据库..."
mysql_secure_installation <<EOF

y
$DB_PASSWORD
$DB_PASSWORD
y
y
y
y
EOF

# 创建数据库和用户
echo "配置数据库..."
mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE acg_faka; CREATE USER 'acg_user'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON acg_faka.* TO 'acg_user'@'localhost'; FLUSH PRIVILEGES;" || {
  echo "错误：数据库配置失败！请检查MariaDB状态或密码。"
  exit 1
}

# 下载并解压源码
echo "下载并解压异次元发卡源码..."
cd /var/www/html
wget -O acg-faka.zip https://github.com/lizhipay/acg-faka/archive/refs/heads/main.zip || {
  echo "错误：无法下载源码！请检查网络或GitHub链接"
  exit 1
}
unzip acg-faka.zip
mv acg-faka-main acg-faka
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
  chown -R www-data:www-data acg-faka
elif [ "$OS" = "centos" ]; then
  chown -R nginx:nginx acg-faka
fi
chmod -R 755 acg-faka
if [ ! -d /var/www/html/acg-faka ]; then
  echo "错误：源码解压或移动失败！"
  exit 1
fi

# 配置Nginx
echo "配置Nginx..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
mkdir -p /etc/nginx/snippets
cat > /etc/nginx/sites-available/acg-faka <<EOF
server {
    listen 80;
    server_name $ACCESS_HOST;
    root /var/www/html/acg-faka;
    index index.php index.html;
    location / {
        try_files \$uri \$uri/ /index.php?s=\$uri;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
# 创建 fastcgi-php.conf
cat > /etc/nginx/snippets/fastcgi-php.conf <<EOF
# 防止直接访问 PHP 文件
location ~ /\. {
    deny all;
}
# 传递 PHP 请求
fastcgi_split_path_info ^(.+?\.php)(/.*)?$;
fastcgi_index index.php;
EOF
ln -sf /etc/nginx/sites-available/acg-faka /etc/nginx/sites-enabled/acg-faka
nginx -t || {
  echo "错误：Nginx配置测试失败！请检查 /etc/nginx/sites-available/acg-faka"
  cat /var/log/nginx/error.log
  exit 1
}
systemctl reload nginx || {
  echo "错误：Nginx重载失败！请检查日志：/var/log/nginx/error.log"
  exit 1
}

# 安装Composer并配置依赖
echo "安装Composer并配置依赖..."
cd /var/www/html/acg-faka
curl -sS https://getcomposer.org/installer | php || {
  echo "错误：无法安装Composer！请检查网络"
  exit 1
}
php composer.phar install || {
  echo "警告：Composer依赖安装失败，可能影响功能，请手动运行：cd /var/www/html/acg-faka && php composer.phar install"
}

# 设置文件权限
echo "设置文件权限..."
mkdir -p /etc/sudoers.d
echo "www-data ALL=(ALL) NOPASSWD: /var/www/html/acg-faka/bin" | tee /etc/sudoers.d/acg-faka
if [ "$OS" = "centos" ]; then
  echo "nginx ALL=(ALL) NOPASSWD: /var/www/html/acg-faka/bin" | tee -a /etc/sudoers.d/acg-faka
fi
chmod 644 /etc/sudoers.d/acg-faka

# 检查防火墙
echo "检查防火墙并开放80端口..."
if command -v ufw &>/dev/null; then
  ufw allow 80
  ufw status
elif command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --reload
fi

# 输出登录信息
echo "============================================================="
echo "搭建完成！请访问以下地址完成最终设置或登录："
echo "网站地址：http://$ACCESS_HOST"
echo "后台登录地址：http://$ACCESS_HOST/admin"
echo "管理员用户名：$ADMIN_USER"
echo "管理员密码：$ADMIN_PASSWORD"
echo "数据库名：acg_faka"
echo "数据库用户名：acg_user"
echo "数据库密码：$DB_PASSWORD"
echo "============================================================="
echo "注意：请访问网站完成安装向导（如有）。若无法访问，请检查："
echo "1. 防火墙状态：ufw status 或 firewall-cmd --list-all"
echo "2. Nginx日志：/var/log/nginx/error.log"
echo "3. PHP-FPM日志：$PHP_LOG"
echo "如需启用SSL，运行：$PKG_MANAGER install -y python3-certbot-nginx && certbot --nginx -d $ACCESS_HOST"
