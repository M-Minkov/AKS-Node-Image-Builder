# Node Won't Join Cluster

Node provisioned but never shows up in `kubectl get nodes`.

## Quick checks

```bash
# SSH to the node and check kubelet
systemctl status kubelet
journalctl -u kubelet -f
```

## Common causes

### 1. kubelet can't reach API server

Check if the node can hit the cluster endpoint:

```bash
# Should return 401 (unauthorized) - that's fine, means network works
curl -k https://<cluster-fqdn>:443/healthz
```

If it times out, it's a network/NSG issue.

**Fix:** Check NSG rules on the node subnet. Port 443 outbound to the cluster needs to be open.

### 2. Wrong containerd socket

```bash
# Should show containerd running
crictl info
```

If you get "cannot connect to containerd", check the socket path:

```bash
ls -la /run/containerd/containerd.sock
```

**Fix:** Restart containerd
```bash
systemctl restart containerd
```

### 3. Node bootstrap token expired

Check kubelet logs for auth errors:

```bash
journalctl -u kubelet | grep -i "certificate\|token\|auth"
```

**Fix:** This is usually an AKS-side issue. Delete the node and let AKS provision a new one.

### 4. Different k8s version than cluster

```bash
kubelet --version
```

Compare with:
```bash
kubectl version
```

If major versions don't match (1.28 vs 1.30), that's the problem.

**Fix:** Rebuild image with matching k8s version, or upgrade cluster.

### 5. containerd not using systemd cgroup driver

Check containerd config:
```bash
grep SystemdCgroup /etc/containerd/config.toml
```

Should be `true`. If not:

```bash
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl restart kubelet
```

## Still stuck?

Collect debug info:

```bash
# Dump everything useful
mkdir /tmp/node-debug
systemctl status kubelet > /tmp/node-debug/kubelet-status.txt
journalctl -u kubelet > /tmp/node-debug/kubelet-logs.txt
journalctl -u containerd > /tmp/node-debug/containerd-logs.txt
crictl info > /tmp/node-debug/containerd-info.txt 2>&1
cat /etc/containerd/config.toml > /tmp/node-debug/containerd-config.txt
cat /var/lib/kubelet/config.yaml > /tmp/node-debug/kubelet-config.txt 2>&1
tar -czf /tmp/node-debug.tar.gz /tmp/node-debug
```

Then pull that file off and look through it.
