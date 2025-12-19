# Install containerd on Windows

Write-Host "=== Installing containerd ===" -ForegroundColor Green

$containerdVersion = $env:CONTAINERD_VERSION
if (-not $containerdVersion) {
    $containerdVersion = "1.7.11"
}

Write-Host "Installing containerd version: $containerdVersion"

$downloadUrl = "https://github.com/containerd/containerd/releases/download/v${containerdVersion}/containerd-${containerdVersion}-windows-amd64.tar.gz"
$downloadPath = "C:\Windows\Temp\containerd.tar.gz"

# Download
Write-Host "Downloading from $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing

# Extract
Write-Host "Extracting..."
tar -xzf $downloadPath -C "C:\Program Files\containerd"

# Add to PATH
$containerdPath = "C:\Program Files\containerd\bin"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$containerdPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$containerdPath", "Machine")
}

# Generate default config
& "C:\Program Files\containerd\bin\containerd.exe" config default | Out-File "C:\Program Files\containerd\config.toml" -Encoding ascii

# Register as Windows service
& "C:\Program Files\containerd\bin\containerd.exe" --register-service

# Start service
Start-Service containerd

# Verify
Write-Host "Verifying installation..."
& "C:\Program Files\containerd\bin\containerd.exe" --version

# Cleanup
Remove-Item $downloadPath -Force

Write-Host "containerd installed"
