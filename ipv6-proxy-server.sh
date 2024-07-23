#!/bin/bash

# Cập nhật và nâng cấp hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói cần thiết
sudo apt install wget zip curl openssl -y

echo "tắt thông báo ✅ ✅ ✅ ✅ ✅"
# Tạo hoặc chỉnh sửa tệp cấu hình để tắt thông báo
echo 'Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};' | sudo tee /etc/apt/apt.conf.d/local > /dev/null

echo "cập nhật ✅ ✅ ✅ ✅ ✅"

# Chạy script thiết lập mạng từ URL
curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash

echo "cài đặt ✅ ✅ ✅ ✅ ✅"

# Chạy script cài đặt proxy từ URL
wget -qO- https://raw.githubusercontent.com/2002-115/taoipv6-OS-Debian-11-x64-bullseye-/main/custom-ipv6-proxy-server.sh | bash
