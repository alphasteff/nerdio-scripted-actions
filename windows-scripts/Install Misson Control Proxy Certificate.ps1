#name: Install Misson Control Proxy Certificate
#description: Installs the Mission Control Proxy certificate to the Trusted Root Certification Authorities store
#execution mode: Individual with restart
#tags: baseVISION, GoldMaster

<# Notes:

Use this script to install the Mission Control Proxy certificate to the Trusted Root Certification Authorities store.

#>

$ErrorActionPreference = 'Stop'


$url = "https://example.com/certificate.crt"
$certFilePath = "$Env:SystemRoot\Temp\certificate.crt"

# Download the certificate file
Invoke-WebRequest -Uri $url -OutFile $certFilePath

# Import the certificate to the Trusted Root Certification Authorities store
$params = @{
    FilePath          = $certFilePath
    CertStoreLocation = 'Cert:\LocalMachine\Root'
}

Import-Certificate @params

# Clean up the certificate file
Remove-Item $certFilePath
