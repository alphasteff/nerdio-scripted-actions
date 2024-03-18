#name: Install Nuget via Blob
#description: Installs Nuget on the Gold Iamge via Blob
#execution mode: IndividualWithRestart
#tags: beckmann.ch

<# Notes:

Use this script to download Nuget from a storage account and copy it to the correct location. This is needed if Nuget cannot be updated directly. However, the container must have Blob as authorization, as no authentication can be performed. Ideally, the file can be stored on the Deplyoment Storage account.

#>

$ErrorActionPreference = 'Stop'

Write-Output ("Install Nuget  via Blob")

$nugetVersion = '2.8.5.208'

$StorageAccountVariable = 'DeployStorageAccount'
$ContainerName = 'prereq'

##### Script Logic #####

$StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json
$StorageAccountName = $StorageAccount.name

$downloadUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Output ("Download URL: {0}" -f ($downloadUrl | Out-String))
Write-Output ("NuGet Version: {0}" -f ($nugetVersion | Out-String))

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Install Nuget Provider
    $nugetFileName = "Microsoft.PackageManagement.NuGetProvider.dll"
    $nugetUrl = "$downloadUrl/Microsoft.PackageManagement.NuGetProvider-$nugetVersion.dll.txt"
    $nugetFilePath = "$Env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\$nugetVersion"

    # Create target directory
    $null = New-Item -ItemType Directory $nugetFilePath -Force -ErrorAction SilentlyContinue

    # Download the Nuget provider and installs
    $nugetFile = Join-Path -Path $nugetFilePath -ChildPath $nugetFileName

    Write-Output ("Download NuGet from {0} to {1}" -f ($nugetUrl | Out-String), ($nugetFile | Out-String))

    Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetFile
} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
