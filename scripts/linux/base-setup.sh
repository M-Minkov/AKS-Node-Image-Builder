#!/bin/bash
set -e

echo "=== Base setup ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

# Packages we'll need
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    socat \
    conntrack \
    ipset \
    ethtool \
    nfs-common \
    cifs-utils

# Disable swap (k8s requirement)
swapoff -a
sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl settings for k8s networking
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "Base setup done"
