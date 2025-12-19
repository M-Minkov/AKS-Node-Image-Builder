# Security hardening for Windows Server

Write-Host "=== Security hardening ===" -ForegroundColor Green

# Disable SMBv1
Write-Host "Disabling SMBv1..."
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null

# Enable Windows Defender features
Write-Host "Configuring Windows Defender..."
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -MAPSReporting Advanced
Set-MpPreference -SubmitSamplesConsent SendSafeSamples

# Defender exclusions for k8s paths (performance)
$exclusions = @(
    "C:\k",
    "C:\etc\kubernetes",
    "C:\var\lib\kubelet",
    "C:\var\log\pods",
    "C:\ProgramData\containerd",
    "C:\Program Files\containerd"
)

foreach ($path in $exclusions) {
    Add-MpPreference -ExclusionPath $path
}

# Audit policies
Write-Host "Configuring audit policies..."
auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Special Logon" /success:enable | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable | Out-Null

# Registry hardening
Write-Host "Applying registry settings..."

# Disable anonymous SID enumeration
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1 -Type DWord

# Disable anonymous enumeration of shares
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1 -Type DWord

# Enable DEP
bcdedit /set nx OptOut | Out-Null

# Disable autorun
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutorun" -Value 1 -Type DWord -Force

# NTP configuration (use Azure time)
w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /reliable:yes /update | Out-Null

Write-Host "Security hardening done"
