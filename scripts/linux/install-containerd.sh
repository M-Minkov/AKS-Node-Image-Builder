#!/bin/bash
set -e

echo "=== Installing containerd ${CONTAINERD_VERSION} ==="

# Add Docker repo (containerd packages come from here)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

# Generate default config
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable systemd cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Set pause image version
sed -i 's|sandbox_image = "registry.k8s.io/pause:.*"|sandbox_image = "registry.k8s.io/pause:3.9"|g' /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd

# Verify
containerd --version

echo "containerd installed"
