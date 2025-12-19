# Cleanup before image capture

Write-Host "=== Cleanup ===" -ForegroundColor Green

# Stop services
Stop-Service containerd -Force -ErrorAction SilentlyContinue

# Clear Windows Update cache
Write-Host "Clearing Windows Update cache..."
Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service wuauserv -ErrorAction SilentlyContinue

# Clear temp files
Write-Host "Clearing temp files..."
$tempPaths = @(
    "$env:TEMP\*",
    "C:\Windows\Temp\*",
    "C:\Users\*\AppData\Local\Temp\*"
)

foreach ($path in $tempPaths) {
    Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
}

# Clear event logs
Write-Host "Clearing event logs..."
wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }

# Clear Windows Defender history
Write-Host "Clearing Defender history..."
Remove-Item "C:\ProgramData\Microsoft\Windows Defender\Scans\History\*" -Recurse -Force -ErrorAction SilentlyContinue

# Remove unneeded Windows components
Write-Host "Removing Windows features we don't need..."
$removeFeatures = @(
    "Internet-Explorer-Optional-amd64",
    "WindowsMediaPlayer"
)

foreach ($feature in $removeFeatures) {
    Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
}

# Defragment
Write-Host "Optimizing drives..."
Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue

# Clear pagefile
Write-Host "Configuring pagefile..."
$cs = Get-WmiObject Win32_ComputerSystem
$cs.AutomaticManagedPagefile = $false
$cs.Put() | Out-Null

$pagefile = Get-WmiObject Win32_PageFileSetting
if ($pagefile) {
    $pagefile.Delete()
}

Write-Host "Cleanup done"
