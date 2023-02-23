#description: Installs Greenshot via Chocolatey Package Manager (https://chocolatey.org/)
#execution mode: Combined
#tags: beckmann.ch, Apps install, Chocolatey, Preview
<#
This script installs Greenshot via Chocolatey
#>

# Install Chocolatey if it isn't already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Greenshot
choco install greenshot -y

# Configure default language
$config = @"
[Core]
Language=en-US
"@

$configFile = "$Env:ProgramFiles\Greenshot\greenshot-defaults.ini"

New-Item -Path $configFile -Force
$config = @"
[Core]
Language=en-US
"@

Set-Content -Path $configFile -Value $config
