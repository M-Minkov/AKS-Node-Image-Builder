# Base setup for Windows Server

Write-Host "=== Base setup ===" -ForegroundColor Green

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null

# Create standard directories
$dirs = @(
    "C:\k",
    "C:\k\bin",
    "C:\etc\kubernetes",
    "C:\var\log\pods",
    "C:\var\lib\kubelet",
    "C:\opt\cni\bin",
    "C:\etc\cni\net.d"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created $dir"
    }
}

# Add k\bin to PATH
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*C:\k\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;C:\k\bin", "Machine")
}

# Enable required Windows features
$features = @(
    "Containers",
    "Hyper-V-PowerShell"
)

foreach ($feature in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
    if ($state -ne "Enabled") {
        Write-Host "Enabling feature: $feature"
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
    }
}

# Configure Windows Firewall for k8s
Write-Host "Configuring firewall rules"

# Kubelet API
New-NetFirewallRule -DisplayName "Kubelet" -Direction Inbound -Protocol TCP -LocalPort 10250 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# NodePort range
New-NetFirewallRule -DisplayName "NodePort Services" -Direction Inbound -Protocol TCP -LocalPort 30000-32767 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host "Base setup done"
