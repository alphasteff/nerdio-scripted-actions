#name: Prepare environment for deployment via Blob
#description: By creating folders and variables, prepare the environment for deployment.
#execution mode: IndividualWithRestart
#tags: baseVISION, Foundation

<# Notes:

Use this script to prepare a gold image for deployment via scripted actions.

#>

$ErrorActionPreference = 'Stop'

Write-Output ("Prepare environment for deployment")

##### Script Logic #####

try {
    # Create Sys directory with environment variables

    Write-Output ("Create Sys directory")
    New-Item -ItemType directory -Path "$env:windir\Logs\Install" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:windir\Logs\Uninstall" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:SystemDrive\Sys" -ErrorAction SilentlyContinue;
    New-Item -ItemType directory -Path "$env:SystemDrive\Sys\Install" -ErrorAction SilentlyContinue;

    (Get-Item "$env:SystemDrive\Sys" -Force).attributes = "Hidden"

    Write-Output ("Create environment variables")
    [System.Environment]::SetEnvironmentVariable('LogDir', "$env:windir\Logs", [System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('InstallLogDir', "$env:windir\Logs\Install", [System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('UninstallLogDir', "$env:windir\Logs\Uninstall", [System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('SysDir', "$env:SystemDrive\Sys", [System.EnvironmentVariableTarget]::Machine);
    [System.Environment]::SetEnvironmentVariable('InstallDir', "$env:SystemDrive\Sys\Install", [System.EnvironmentVariableTarget]::Machine);
} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
