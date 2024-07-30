#!/bin/bash

echo "Cập nhật hệ thống ✅ ✅ ✅ ✅ ✅"
sudo apt-get update && sudo apt-get install unzip

echo "Cài đặt các gói cần thiết ✅ ✅ ✅ ✅ ✅"
# Cài đặt các gói cần thiết 
sudo apt install wget zip curl openssl -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
# Chạy script thiết lập mạng từ URL
curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash

echo "Cài đặt proxy ✅ ✅ ✅ ✅ ✅"
# Chạy script cài đặt proxy từ URL
wget -qO- https://raw.githubusercontent.com/2002-115/taoipv6-OS-Debian-11-x64-bullseye-/main/custom-ipv6-proxy-server.sh | bash
