#!/bin/bash

# Thiết lập môi trường không tương tác
export DEBIAN_FRONTEND=noninteractive

# Hàm chờ đợi khóa apt/dpkg
wait_for_lock() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for other package managers to finish..."
    sleep 5
  done
}

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Tạo hoặc chỉnh sửa tệp cấu hình để tắt thông báo
echo 'Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};' | sudo tee /etc/apt/apt.conf.d/90local > /dev/null

echo "tắt thông báo ✅ ✅ ✅ ✅ ✅"

# Cập nhật và nâng cấp hệ thống
sudo apt update && sudo apt upgrade -y

# Cài đặt các gói cần thiết
sudo apt install wget zip curl openssl -y

echo "cập nhật ✅ ✅ ✅ ✅ ✅"

# Chạy script thiết lập mạng từ URL
curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash

# Chạy script cài đặt proxy từ URL
wget -qO- https://raw.githubusercontent.com/2002-115/taoipv6-OS-Debian-11-x64-bullseye-/main/custom-ipv6-proxy-server.sh | bash

echo "cài đặt ✅ ✅ ✅ ✅ ✅"
