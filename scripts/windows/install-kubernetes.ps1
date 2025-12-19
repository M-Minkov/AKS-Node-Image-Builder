# Install Kubernetes components on Windows

Write-Host "=== Installing Kubernetes components ===" -ForegroundColor Green

$k8sVersion = $env:K8S_VERSION
if (-not $k8sVersion) {
    $k8sVersion = "1.29"
}

# Get latest patch for this minor version
Write-Host "Finding latest patch for v$k8sVersion"
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/kubernetes/kubernetes/releases" -UseBasicParsing
$latestPatch = ($releases | Where-Object { $_.tag_name -like "v${k8sVersion}.*" -and -not $_.prerelease } | Select-Object -First 1).tag_name
$latestPatch = $latestPatch.TrimStart('v')

Write-Host "Installing Kubernetes $latestPatch"

$binPath = "C:\k\bin"
$baseUrl = "https://dl.k8s.io/v${latestPatch}/bin/windows/amd64"

# Download binaries
$binaries = @("kubelet.exe", "kubeadm.exe", "kubectl.exe")

foreach ($binary in $binaries) {
    $url = "$baseUrl/$binary"
    $dest = "$binPath\$binary"
    
    Write-Host "Downloading $binary..."
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# Verify downloads
foreach ($binary in $binaries) {
    $path = "$binPath\$binary"
    if (Test-Path $path) {
        Write-Host "$binary - OK"
    } else {
        throw "Failed to download $binary"
    }
}

# Download wins (Windows networking helper)
Write-Host "Downloading wins..."
$winsUrl = "https://github.com/rancher/wins/releases/download/v0.4.12/wins.exe"
Invoke-WebRequest -Uri $winsUrl -OutFile "$binPath\wins.exe" -UseBasicParsing

# Download CNI plugins
Write-Host "Downloading CNI plugins..."
$cniVersion = "1.4.0"
$cniUrl = "https://github.com/containernetworking/plugins/releases/download/v${cniVersion}/cni-plugins-windows-amd64-v${cniVersion}.tgz"
$cniPath = "C:\Windows\Temp\cni-plugins.tgz"

Invoke-WebRequest -Uri $cniUrl -OutFile $cniPath -UseBasicParsing
tar -xzf $cniPath -C "C:\opt\cni\bin"
Remove-Item $cniPath -Force

# crictl for debugging
Write-Host "Downloading crictl..."
$crictlVersion = "1.29.0"
$crictlUrl = "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictlVersion}/crictl-v${crictlVersion}-windows-amd64.tar.gz"
$crictlPath = "C:\Windows\Temp\crictl.tar.gz"

Invoke-WebRequest -Uri $crictlUrl -OutFile $crictlPath -UseBasicParsing
tar -xzf $crictlPath -C "$binPath"
Remove-Item $crictlPath -Force

# crictl config
@"
runtime-endpoint: npipe:////./pipe/containerd-containerd
image-endpoint: npipe:////./pipe/containerd-containerd
timeout: 10
"@ | Out-File "C:\k\crictl.yaml" -Encoding ascii

# Verify versions
Write-Host "`nVerifying installations:"
& "$binPath\kubelet.exe" --version
& "$binPath\kubeadm.exe" version
& "$binPath\kubectl.exe" version --client

Write-Host "Kubernetes components installed"
