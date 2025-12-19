# containerd Issues

containerd not starting or pods failing to run.

## Check status

```bash
systemctl status containerd
journalctl -u containerd -f
```

## Common issues

### 1. Service won't start

Check the config file syntax:

```bash
containerd config dump
```

If it errors, there's a syntax problem. Regenerate default config:

```bash
mv /etc/containerd/config.toml /etc/containerd/config.toml.broken
containerd config default > /etc/containerd/config.toml
# Re-apply our settings
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
```

### 2. Can't pull images

```bash
crictl pull nginx
```

If this fails with certificate errors:

```bash
# Check system time - cert validation needs correct time
date
timedatectl
```

If time is wrong:
```bash
timedatectl set-ntp true
systemctl restart systemd-timesyncd
```

If it fails with DNS errors:

```bash
cat /etc/resolv.conf
nslookup registry.k8s.io
```

**Fix:** Check NSG rules allow DNS (port 53) and HTTPS (port 443) outbound.

### 3. Pods stuck in ContainerCreating

```bash
crictl ps -a
crictl logs <container-id>
```

Usually one of:
- Image pull failure (see above)
- Volume mount failure (check kubelet logs)
- Resource limits hit (check `crictl stats`)

### 4. "OCI runtime create failed"

Often means runc is broken or missing:

```bash
which runc
runc --version
```

Reinstall containerd package to get runc back:

```bash
apt-get install --reinstall containerd.io
systemctl restart containerd
```

### 5. High memory/CPU usage

Check what's actually running:

```bash
crictl stats
crictl ps
```

Find the resource hog and check its logs:

```bash
crictl logs <container-id>
```

## Windows-specific issues

### Service won't start

Check event viewer:
```powershell
Get-EventLog -LogName Application -Source containerd -Newest 20
```

Common cause: missing HCS (Host Compute Service)

```powershell
Get-Service vmcompute
Start-Service vmcompute
Start-Service containerd
```

### Can't create Windows containers

```powershell
# Check if Containers feature is enabled
Get-WindowsOptionalFeature -Online -FeatureName Containers
```

If disabled:
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
Restart-Computer
```
