#name: Prepare PowerShell environment via Blob
#description: Prepares the PowerShell environment via Blob
#execution mode: IndividualWithRestart
#tags: beckmann.ch

<# Notes:

Use this script to download and install PowerShell Package Management and PowerShellGet from a storage account. This is required if the PowerShell modules cannot be updated directly. However, the container must have Blob as authorization, as no authentication can be performed. Ideally, the files can be stored on the Deplyoment storage account.

#>

$ErrorActionPreference = 'Stop'

Write-Output ("Prepare PowerShell environment via Blob")

$powershellgetVersion = '2.2.5'
$packagemanagementVersion = '1.4.8.1'

$StorageAccountVariable = 'DeployStorageAccount'
$ContainerName = 'prereq'

##### Script Logic #####

$StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json
$StorageAccountName = $StorageAccount.name

$downloadUrl = "https://$StorageAccountName.blob.core.windows.net/$ContainerName"

Write-Output ("Download URL: {0}" -f ($downloadUrl | Out-String))
Write-Output ("PowerShellGet Version: {0}" -f ($powershellgetVersion | Out-String))
Write-Output ("PackageManagement Version: {0}" -f ($packagemanagementVersion | Out-String))


$prereqPackages = @(
    "powershellget.$powershellgetVersion.nupkg",
    "packagemanagement.$packagemanagementVersion.nupkg"
)

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

    # Install all required modules
    Write-Output ("Install all required modules")
    Install-Module -Repository Prereq -Name PowerShellGet -Force

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
