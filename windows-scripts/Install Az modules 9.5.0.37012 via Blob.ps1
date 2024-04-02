#name: Install Az modules 9.5.0.37012 via Blob
#description: Installs the required Az modules 9.5.0.37012 via Blob
#execution mode: IndividualWithRestart
#tags: beckmann.ch

<# Notes:

Use this script to download and install the Azure modules from a storage account. This is required if the Azure modules cannot be updated directly. However, the container must have Blob as authorization, as no authentication can be performed. Ideally, the files can be stored on the Deplyoment storage account.

! For Hybrid Worker, becaus of issues with Az.Account
https://learn.microsoft.com/en-us/answers/questions/1299863/how-to-fix-method-get-serializationsettings-does-n

#>

$ErrorActionPreference = 'Stop'

Write-Output ("Install Az modules via Blob")

$azModule = '9.5.0.37012'
$azArc = 'x64'

$prereqPackages = @(
    "Az-Cmdlets-$azModule-$azArc.msi"
)

$StorageAccountVariable = 'DeployStorageAccount'
$ContainerName = 'prereq'

##### Script Logic #####

$StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json
$StorageAccountName = $StorageAccount.name

$downloadUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Output ("Download URL: {0}" -f ($downloadUrl | Out-String))
Write-Output ("PreReq Packages: {0}" -f ($prereqPackages | Out-String))

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Create Path for the custom PowerShell repository
    $repoPath = "$Env:SystemRoot\Temp"
    $null = New-Item -ItemType Directory $repoPath -Force -ErrorAction SilentlyContinue

    ForEach ($prereqPackage in $prereqPackages) {
        $url = $null
        $file = $null

        $url = "$downloadUrl/$prereqPackage"
        $file = "$Env:SystemRoot\Temp\$prereqPackage"

        Write-Output ("Download file from {0} to {1}" -f ($url | Out-String), ($file | Out-String))

        # Download the Packages provider
        Invoke-WebRequest -Uri $url -OutFile $file

        msiexec /i "$file" -qb!
    }
} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
