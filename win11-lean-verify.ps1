#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-RegValue {
  param(
    [string]$Path,
    [string]$Name,
    [object]$Expected
  )
  try {
    $actual = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
    [pscustomobject]@{
      Type='Registry'
      Target="$Path :: $Name"
      Expected=$Expected
      Actual=$actual
      Pass=($actual -eq $Expected)
    }
  } catch {
    [pscustomobject]@{
      Type='Registry'
      Target="$Path :: $Name"
      Expected=$Expected
      Actual='<missing>'
      Pass=$false
    }
  }
}

function Test-AppMissing {
  param([string]$Name)
  $installed = @(Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue)
  $provisioned = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$Name*" })
  [pscustomobject]@{
    Type='AppX'
    Target=$Name
    Expected='Absent for installed users and absent from provisioned packages'
    Actual="Installed=$($installed.Count); Provisioned=$($provisioned.Count)"
    Pass=($installed.Count -eq 0 -and $provisioned.Count -eq 0)
  }
}

function Test-ServiceDisabled {
  param([string]$Name)
  $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  if (-not $svc) {
    return [pscustomobject]@{
      Type='Service'
      Target=$Name
      Expected='Disabled'
      Actual='<missing>'
      Pass=$false
    }
  }
  [pscustomobject]@{
    Type='Service'
    Target=$Name
    Expected='State=Stopped/StartMode=Disabled'
    Actual="State=$($svc.State); StartMode=$($svc.StartMode)"
    Pass=($svc.StartMode -eq 'Disabled')
  }
}

function Test-DesktopApp {
  param([string]$Pattern)
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $hits = foreach ($p in $paths) {
    Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object {
      $_.DisplayName -like "*$Pattern*"
    } | Select-Object -ExpandProperty DisplayName
  }
  [pscustomobject]@{
    Type='DesktopApp'
    Target=$Pattern
    Expected='Installed'
    Actual=($hits -join '; ')
    Pass=($hits.Count -gt 0)
  }
}

function Test-DisplayState {
  $vc = Get-CimInstance Win32_VideoController | Select-Object -First 1
  [pscustomobject]@{
    Type='Display'
    Target='Primary video controller'
    Expected='3840x2160 and 240 Hz'
    Actual="$($vc.CurrentHorizontalResolution)x$($vc.CurrentVerticalResolution) @ $($vc.CurrentRefreshRate)Hz"
    Pass=($vc.CurrentHorizontalResolution -eq 3840 -and $vc.CurrentVerticalResolution -eq 2160 -and $vc.CurrentRefreshRate -eq 240)
  }
}

$results = @()

$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
$results += Test-RegValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' 'NoCloudApplicationNotification' 1
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications' 'NoToastApplicationNotification' 1
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
$results += Test-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0

$results += Test-AppMissing 'Microsoft.YourPhone'
$results += Test-AppMissing 'Microsoft.GamingApp'
$results += Test-AppMissing 'Microsoft.XboxGamingOverlay'
$results += Test-ServiceDisabled 'Spooler'

$results += Test-DesktopApp 'NVIDIA App'
$results += Test-DesktopApp 'Steam'
$results += Test-DesktopApp 'MSI Afterburner'

$results += Test-DisplayState

$results | Sort-Object Type, Target | Format-Table -AutoSize

$failed = @($results | Where-Object { -not $_.Pass })
if ($failed.Count -gt 0) {
  Write-Host ""
  Write-Host "FAILED CHECKS: $($failed.Count)" -ForegroundColor Red
  $failed | Format-Table -AutoSize
  exit 1
} else {
  Write-Host ""
  Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
  exit 0
}
