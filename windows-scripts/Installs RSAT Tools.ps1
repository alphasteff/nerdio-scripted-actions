#description: Installs RSAT Tools over Windows Update
#execution mode: Combined
#tags: beckmann.ch, Apps install, Features
<#
    This script installs RSAT Tools
#>

$LogDir = "$Env:InstallLogDir"
Start-Transcript -Path "$LogDir\RSAT_Tools.log" -Append

$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'
$InformationPreference = 'Continue'

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host ("Current User: $CurrentUser")

$wuauserv = Get-Service -Name wuauserv
If ($wuauserv.StartType -ne 'Automatic')
{
  Write-Host 'Start Windows Update Service'
  Set-Service -Name wuauserv -StartupType Automatic
  Start-Service -Name wuauserv
}

$currentWU = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UseWUServer
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0
Restart-Service wuauserv

# Install RSAT Tools
Get-WindowsCapability -Online -ScratchDirectory 'C:\Windows\Temp' |
Where-Object {$_.Name -like "*RSAT*" -and $_.State -eq "NotPresent"} |
Add-WindowsCapability -Online -ScratchDirectory 'C:\Windows\Temp'

Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value $currentWU
Restart-Service wuauserv

# Configure Windows Update Service as before
Set-Service -Name wuauserv -StartupType $wuauserv.StartType

Stop-Transcript
