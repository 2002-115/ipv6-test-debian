#!/bin/bash

# Thiết lập môi trường không tương tác
export DEBIAN_FRONTEND=noninteractive

# Hàm chờ đợi khóa apt/dpkg
wait_for_lock() {
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        echo "Đang chờ các trình quản lý gói khác hoàn thành..."
        sleep 5
    done
}

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Tạo hoặc chỉnh sửa tệp cấu hình để tắt thông báo và chọn mặc định
echo 'Dpkg::Options { "--force-confdef"; "--force-confold"; };' | sudo tee /etc/apt/apt.conf.d/90local > /dev/null

echo "Tắt thông báo và chọn mặc định ✅ ✅ ✅ ✅ ✅"

# Đặt trước các câu trả lời cho debconf để tránh yêu cầu tương tác
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Cập nhật và nâng cấp hệ thống với các tùy chọn dpkg để giữ bản địa phương của tệp cấu hình
sudo apt update -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt upgrade -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo "Cập nhật hệ thống ✅ ✅ ✅ ✅ ✅"

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Cài đặt các gói cần thiết với các tùy chọn dpkg để giữ bản địa phương của tệp cấu hình
sudo apt install wget zip curl openssl -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo "Cài đặt các gói cần thiết ✅ ✅ ✅ ✅ ✅"

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Chạy script thiết lập mạng từ URL
curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash

# Chờ đợi khóa apt/dpkg trước khi tiếp tục
wait_for_lock

# Chạy script cài đặt proxy từ URL
wget -qO- https://raw.githubusercontent.com/2002-115/taoipv6-OS-Debian-11-x64-bullseye-/main/custom-ipv6-proxy-server.sh | bash

echo "Cài đặt proxy ✅ ✅ ✅ ✅ ✅"
