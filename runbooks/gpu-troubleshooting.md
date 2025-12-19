# GPU Troubleshooting

GPU not detected or NVIDIA driver issues on NC-series VMs.

## Quick diagnosis

Run the check script we installed:

```bash
check-gpu.sh
```

Or manually:

```bash
nvidia-smi
```

## Common issues

### 1. nvidia-smi not found

Driver didn't install or isn't in PATH:

```bash
which nvidia-smi
ls /usr/bin/nvidia*
```

If nothing there, driver isn't installed. Check if the image was built with GPU support:

```bash
dpkg -l | grep nvidia
```

**Fix:** Image needs to be rebuilt with `enable_gpu=true`.

### 2. nvidia-smi says "No devices were found"

A few causes:

#### Wrong VM size
NC-series only. Check what you're actually running on:

```bash
curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text"
```

If it's not NC* or ND*, there's no GPU.

#### GPU not passed through
On some VM sizes, need to check Azure serial console for errors.

#### Driver not loaded
```bash
lsmod | grep nvidia
```

If empty, try loading manually:

```bash
modprobe nvidia
```

Check dmesg for errors:

```bash
dmesg | grep -i nvidia
```

### 3. Driver version mismatch

Symptoms: nvidia-smi shows driver but CUDA apps fail.

Check versions:

```bash
nvidia-smi  # Shows driver version
cat /usr/local/cuda/version.txt  # Shows CUDA version (if installed)
```

**K80 (NC6, NC12, NC24):** Use driver 470.x or 535.x. 470 more stable.

**V100 (NCv3 series):** Use driver 535.x.

**T4 (NCasT4):** Use driver 535.x.

### 4. GPU visible but pods can't use it

Check if nvidia device plugin is running:

```bash
kubectl get pods -n kube-system | grep nvidia
```

If not there, deploy it:

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

Check node has GPU capacity:

```bash
kubectl describe node <node-name> | grep -A5 Capacity
```

Should show `nvidia.com/gpu: 1` (or however many GPUs).

If not, check the device plugin logs:

```bash
kubectl logs -n kube-system <nvidia-device-plugin-pod>
```

### 5. containerd can't use GPU

NVIDIA container toolkit needs to be configured:

```bash
nvidia-ctk runtime configure --runtime=containerd
cat /etc/containerd/config.toml | grep -A10 nvidia
systemctl restart containerd
```

Test it directly:

```bash
crictl pull nvcr.io/nvidia/cuda:12.0.0-base-ubuntu22.04
crictl run --runtime=nvidia <pod-config> <container-config>
```

### 6. GPU memory fragmentation

Long-running GPU nodes can get fragmented. Check with:

```bash
nvidia-smi -q -d MEMORY
```

**Fix:** Cordon, drain, and replace the node.

## Driver compatibility matrix

What actually works based on testing:

| VM Series | GPU | Driver 470 | Driver 535 | Notes |
|-----------|-----|------------|------------|-------|
| NC v1 | K80 | ✓ | ✓* | 470 more stable |
| NC v2 | P100 | ✓ | ✓ | |
| NC v3 | V100 | - | ✓ | Use 535+ |
| NCasT4 v3 | T4 | - | ✓ | Use 535+ |
| ND v2 | V100 (NVLink) | - | ✓ | Use 535+ |

*535 works on K80 but occasional hangs under heavy load.

## Useful commands

```bash
# GPU utilization
nvidia-smi dmon -s u

# GPU processes
nvidia-smi pmon -s u

# Full GPU info
nvidia-smi -q

# Reset GPU (careful - kills all GPU processes)
nvidia-smi --gpu-reset

# Check PCIe link
nvidia-smi -q -d PCIE
```
