#!/bin/bash

sudo apt update && sudo apt upgrade -y && sudo apt install wget -y
sudo apt-get install zip curl openssl -y
sudo apt-get install zip -y

echo "cap nhat ✅ ✅ ✅ ✅ ✅"

curl -sSL https://raw.githubusercontent.com/2002-115/ipv6-debian11-setup_network/main/setup_network.sh | bash

echo "cai dat ✅ ✅ ✅ ✅ ✅"

wget -qO- https://raw.githubusercontent.com/2002-115/taoipv6-OS-Debian-11-x64-bullseye-/main/custom-ipv6-proxy-server.sh | bash
