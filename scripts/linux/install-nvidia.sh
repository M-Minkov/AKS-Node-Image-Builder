#!/bin/bash
set -e

# Skip if SKIP_GPU is set to true
if [ "${SKIP_GPU:-false}" = "true" ]; then
    echo "=== Skipping GPU driver installation (enable_gpu=false) ==="
    exit 0
fi

echo "=== Installing NVIDIA drivers ==="

DRIVER_VERSION=${NVIDIA_DRIVER_VERSION:-535}

# Detect GPU type to pick best driver
detect_gpu() {
    if lspci | grep -i nvidia | grep -qi "V100"; then
        echo "v100"
    elif lspci | grep -i nvidia | grep -qi "K80"; then
        echo "k80"
    elif lspci | grep -i nvidia | grep -qi "T4"; then
        echo "t4"
    elif lspci | grep -i nvidia | grep -qi "A100"; then
        echo "a100"
    else
        echo "unknown"
    fi
}

GPU_TYPE=$(detect_gpu)
echo "Detected GPU type: $GPU_TYPE"

# Driver version recommendations based on testing
# K80: 470 is more stable, 535 works but occasional issues
# V100/T4/A100: 535 recommended
case $GPU_TYPE in
    k80)
        if [ "$DRIVER_VERSION" = "auto" ]; then
            DRIVER_VERSION="470"
        fi
        ;;
    v100|t4|a100)
        if [ "$DRIVER_VERSION" = "auto" ]; then
            DRIVER_VERSION="535"
        fi
        ;;
esac

echo "Using driver version: $DRIVER_VERSION"

# Blacklist nouveau (open source nvidia driver)
cat <<EOF | tee /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

update-initramfs -u

# Install dependencies
apt-get update
apt-get install -y \
    build-essential \
    linux-headers-$(uname -r) \
    dkms

# Add NVIDIA package repo
distribution=$(. /etc/os-release;echo $ID$VERSION_ID | sed -e 's/\.//g')

wget https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
rm cuda-keyring_1.1-1_all.deb

apt-get update

# Install driver
echo "Installing nvidia-driver-${DRIVER_VERSION}..."
apt-get install -y nvidia-driver-${DRIVER_VERSION}

# Install container toolkit for GPU containers
echo "Installing nvidia-container-toolkit..."
apt-get install -y nvidia-container-toolkit

# Configure containerd for GPU
nvidia-ctk runtime configure --runtime=containerd
systemctl restart containerd

# Create GPU check script for troubleshooting
cat <<'SCRIPT' | tee /usr/local/bin/check-gpu.sh
#!/bin/bash
echo "=== GPU Status ==="
nvidia-smi || echo "nvidia-smi failed - driver may not be loaded"
echo ""
echo "=== Driver Version ==="
cat /proc/driver/nvidia/version 2>/dev/null || echo "Driver not loaded"
echo ""
echo "=== Loaded Modules ==="
lsmod | grep nvidia || echo "No nvidia modules loaded"
echo ""
echo "=== Container Runtime GPU Support ==="
crictl info 2>/dev/null | grep -A5 nvidia || echo "Check containerd config"
SCRIPT
chmod +x /usr/local/bin/check-gpu.sh

# Verify driver loads
modprobe nvidia || echo "Note: nvidia module will load on first boot with GPU"

echo "NVIDIA driver installation done"
echo "Run 'check-gpu.sh' after boot to verify GPU is working"
