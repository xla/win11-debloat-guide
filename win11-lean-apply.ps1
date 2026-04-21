#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ensure-Key($path) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
}

Write-Step "Creating policy keys"
$keys = @(
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI',
  'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot',
  'HKLM:\SOFTWARE\Policies\Microsoft\Dsh',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications',
  'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications',
  'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
)
$keys | ForEach-Object { Ensure-Key $_ }

Write-Step "Disabling Recall / AI-related features"
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableClickToDo' -PropertyType DWord -Value 1 -Force | Out-Null

Write-Step "Disabling Copilot"
New-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -PropertyType DWord -Value 1 -Force | Out-Null

Write-Step "Disabling Widgets and consumer experiences"
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -PropertyType DWord -Value 1 -Force | Out-Null

Write-Step "Disabling Game DVR policy"
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -PropertyType DWord -Value 0 -Force | Out-Null

Write-Step "Suppressing toast and cloud notifications"
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'NoCloudApplicationNotification' -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'NoToastApplicationNotification' -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'NoToastApplicationNotification' -PropertyType DWord -Value 1 -Force | Out-Null

Write-Step "Disabling Edge background mode and startup boost"
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'BackgroundModeEnabled' -PropertyType DWord -Value 0 -Force | Out-Null
New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'StartupBoostEnabled' -PropertyType DWord -Value 0 -Force | Out-Null

Write-Step "Removing OneDrive"
$oneDriveSetup = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
if (Get-Process OneDrive -ErrorAction SilentlyContinue) { Stop-Process -Name OneDrive -Force }
if (Test-Path $oneDriveSetup) { & $oneDriveSetup /uninstall }

Write-Step "Removing Xbox / Phone Link packages for installed users"
$packages = @(
  'Microsoft.YourPhone',
  'Microsoft.GamingApp',
  'Microsoft.XboxGamingOverlay'
)
foreach ($pkg in $packages) {
  Get-AppxPackage -Name $pkg -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop } catch {}
  }
}

Write-Step "Removing provisioned packages so new users do not inherit them"
$provisionedPatterns = @(
  'Microsoft.YourPhone',
  'Microsoft.GamingApp',
  'Microsoft.XboxGamingOverlay'
)
foreach ($pattern in $provisionedPatterns) {
  Get-AppxProvisionedPackage -Online |
    Where-Object { $_.DisplayName -like "*$pattern*" } |
    ForEach-Object {
      try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null } catch {}
    }
}

Write-Step "Disabling Print Spooler"
if (Get-Service Spooler -ErrorAction SilentlyContinue) {
  Stop-Service Spooler -Force -ErrorAction SilentlyContinue
  Set-Service Spooler -StartupType Disabled
}

Write-Step "Applying common gaming-friendly power plan preference"
powercfg /LIST

Write-Step "Done. Reboot required for all policy/app changes to settle."
