# AKS Node Image Builder

Packer-based tooling for building custom VHD images for AKS node pools. Supports Ubuntu 22.04 and Windows Server 2022, with optional GPU/NVIDIA driver support for NC-series VMs.

## What's in here

```
packer/              # Packer templates (HCL)
scripts/
  linux/             # Shell scripts for Ubuntu images  
  windows/           # PowerShell scripts for Windows images
.github/workflows/   # CI pipelines
runbooks/            # Troubleshooting docs
```

## Quick start

1. Set up Azure credentials (see [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md))
2. Copy `packer/variables.pkrvars.hcl.example` to `packer/variables.pkrvars.hcl` and fill in your values
3. Run `make build-ubuntu` or `make build-windows`

## Supported configurations

| OS | K8s Versions | Container Runtime | GPU Support |
|----|--------------|-------------------|-------------|
| Ubuntu 22.04 LTS | 1.28, 1.29, 1.30 | containerd 1.7.x | Yes (NC-series) |
| Windows Server 2022 | 1.28, 1.29, 1.30 | containerd 1.7.x | No |

## Build targets

```bash
make build-ubuntu       # Standard Ubuntu node image
make build-ubuntu-gpu   # Ubuntu with NVIDIA drivers (for NC-series)
make build-windows      # Windows Server node image
make build-all          # Everything
```

## GPU nodes

For ML workloads on NC-series VMs, use the GPU build. Tested driver versions:

| VM Size | GPU | Driver Version | Status |
|---------|-----|----------------|--------|
| Standard_NC6 | Tesla K80 | 470.xx | Works |
| Standard_NC12 | Tesla K80 | 470.xx | Works |
| Standard_NC24 | Tesla K80 | 470.xx | Works |
| Standard_NC6s_v3 | Tesla V100 | 535.xx | Works |
| Standard_NC24s_v3 | Tesla V100 | 535.xx | Works |

Driver 535 works on both K80 and V100 but 470 is more stable on K80s. The install script auto-detects and picks the right one.

## Using custom images in AKS

After building, grab the image ID from the output and use it:

```bash
az aks nodepool add \
  --cluster-name mycluster \
  --resource-group myrg \
  --name custompool \
  --node-count 3 \
  --node-vm-size Standard_DS3_v2 \
  --node-image-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<image-name>
```

Or for GPU pools:

```bash
az aks nodepool add \
  --cluster-name mycluster \
  --resource-group myrg \
  --name gpupool \
  --node-count 1 \
  --node-vm-size Standard_NC6 \
  --node-image-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<gpu-image-name>
```

## Security patching

Images should be rebuilt monthly or when critical CVEs drop. The GitHub Actions workflow runs weekly and creates a PR with updated images. Merge to trigger deployment.

To force a rebuild:

```bash
gh workflow run build-images.yml
```

## Troubleshooting

Check [runbooks/](runbooks/) for common issues:

- [Node won't join cluster](runbooks/node-join-failure.md)
- [containerd won't start](runbooks/containerd-issues.md)
- [GPU not detected](runbooks/gpu-troubleshooting.md)
- [Image build failures](runbooks/build-failures.md)
