#name: Prepare environment for deployment
#description: By configuring PowerShell, installing modules, creating folders and variables, prepare the environment for deployment.
#execution mode: Individual with restart
#tags: beckmann.ch, Preview

<# Notes:

Use this script to prepare a gold image for deployment via scripted actions.

#>

$ErrorActionPreference = 'Stop'

##### Script Logic #####

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
    Install-PackageProvider -Name NuGet -Force;
    #Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module -Name PowerShellGet, PSFramework, Az.Accounts, Az.Resources, Az.Storage -Force;
    Update-Module -Name PowerShellGet;

    New-Item -ItemType directory -Path "$env:windir\Logs\Install" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:windir\Logs\Uninstall" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:SystemDrive\Sys" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:SystemDrive\Sys\Install" -ErrorAction SilentlyContinue;

    (Get-Item "$env:SystemDrive\Sys" -Force).attributes="Hidden"

    [System.Environment]::SetEnvironmentVariable('LogDir',"$env:windir\Logs",[System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('InstallLogDir',"$env:windir\Logs\Install",[System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('UninstallLogDir',"$env:windir\Logs\Uninstall",[System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('SysDir',"$env:SystemDrive\Sys",[System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('InstallDir',"$env:SystemDrive\Sys\Install",[System.EnvironmentVariableTarget]::Machine);
}
catch {
  $ErrorActionPreference = 'Continue'
  write-output "Encountered error. $_"
  Throw $_ 
}
