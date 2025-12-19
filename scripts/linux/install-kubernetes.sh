#!/bin/bash
set -e

echo "=== Installing Kubernetes ${K8S_VERSION} components ==="

# K8S_VERSION comes in as "1.29" - we need to handle minor version
K8S_MINOR=$(echo $K8S_VERSION | cut -d. -f1,2)

# Add Kubernetes apt repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Find latest patch version for our minor
KUBELET_VERSION=$(apt-cache madison kubelet | grep "${K8S_MINOR}" | head -1 | awk '{print $3}')

echo "Installing kubelet ${KUBELET_VERSION}"

apt-get install -y \
    kubelet=${KUBELET_VERSION} \
    kubeadm=${KUBELET_VERSION} \
    kubectl=${KUBELET_VERSION}

# Prevent auto-upgrades
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet (AKS will configure it at join time)
systemctl enable kubelet

# Create dirs AKS expects
mkdir -p /etc/kubernetes/manifests
mkdir -p /var/lib/kubelet
mkdir -p /var/log/pods

# Crictl config
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

# Verify
kubelet --version
kubeadm version
kubectl version --client

echo "Kubernetes components installed"
