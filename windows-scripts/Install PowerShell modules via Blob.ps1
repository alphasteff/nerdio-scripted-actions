#name: Install PowerShell modules via Blob
#description: Installs the required PowerShell modules via Blob
#execution mode: IndividualWithRestart
#tags: beckmann.ch

<# Notes:

Use this script to download and install the PowerShell modules from a storage account. This is required if the PowerShell modules cannot be updated directly. However, the container must have Blob as authorization, as no authentication can be performed. Ideally, the files can be stored on the Deplyoment storage account.

#>

$ErrorActionPreference = 'Stop'

Write-Output ("Install PowerShell modules via Blob")

$psframeworkVersion = '1.10.318'
$azAccountsVersion = '2.15.0'
$azResourcesVersion = '6.14.0'
$azStorageVersion = '6.1.0'
$azKeyVaultVersion = '5.1.0'

$prereqPackages = @(
    "psframework.$psframeworkVersion.nupkg",
    "az.accounts.$azAccountsVersion.nupkg",
    "az.resources.$azResourcesVersion.nupkg",
    "az.storage.$azStorageVersion.nupkg",
    "az.keyvault.$azKeyVaultVersion.nupkg"
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
    $repoPath = "$Env:SystemRoot\Temp\Prereq"
    $null = New-Item -ItemType Directory $repoPath -Force -ErrorAction SilentlyContinue

    ForEach ($prereqPackage in $prereqPackages) {
        $url = $null
        $file = $null

        $url = "$downloadUrl/$prereqPackage"
        $file = "$Env:SystemRoot\Temp\Prereq\$prereqPackage"

        Write-Output ("Download file from {0} to {1}" -f ($url | Out-String), ($file | Out-String))

        # Download the Packages provider
        Invoke-WebRequest -Uri $url -OutFile $file
    }

    # Create custom PowerShell repository
    Write-Output ("Create custom PowerShell repository")
    Register-PackageSource -Name Prereq -Location $repoPath -Trusted -ProviderName NuGet
    Register-PSRepository -Name Prereq -SourceLocation $repoPath -InstallationPolicy Trusted

    #Install all required modules
    Write-Output ("Install all required modules")
    Install-Module -Repository Prereq -Name PSFramework, Az.Accounts, Az.Resources, Az.Storage, Az.KeyVault -Force

    # Remvoe custom PowerShell repository and remove files
    Write-Output ("Remvoe custom PowerShell repository and remove files")
    Unregister-PSRepository -Name Prereq
    Unregister-PackageSource -Name Prereq
    Remove-Item -Path $repoPath -Recurse -Force
} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
