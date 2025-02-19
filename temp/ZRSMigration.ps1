<#
.SYNOPSIS
    Automates the creation of a Disaster Recovery (DR) App Service Plan and updates existing web apps and function apps to use the new plan.
    Configure the SQL database and Storage account for zone redundancy.

.DESCRIPTION
     This script automates the creation of a Disaster Recovery (DR) App Service Plan and updates existing web apps and function apps to use the new plan.
     And also configures the SQL database and Storage account for zone redundancy.
     It performs the following tasks:
     - Sets the Azure context
     - Creates a DR storage account and container if they do not exist
     - Generates a SAS token for the container and stores it in Azure Key Vault
     - Restarts all web apps in the existing App Service Plan
     - Verifies required files in the DR storage container
     - Creates a new zone-redundant App Service Plan
     - Updates web apps and function apps to use the new App Service Plan
     - Configures the SQL database for zone redundancy
     - Initiates the migration of storage accounts to zone-redundant storage

     Requirements:
     - Azure PowerShell module installed
     - Appropriate Azure permissions
     - Existing App Service Plan and Resource Group
     - Key Vault and Storage Account Access

.NOTES
    Ensure the Azure PowerShell module is installed and you have appropriate Azure permissions. Requires an existing App Service Plan, Resource Group, Key Vault, and Storage Account access.

.COMPONENT
    Azure PowerShell Module (Az)

.LINK
    https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az

.Parameter NMESubscription
    The Azure subscription ID to set the context.

.Parameter NMEResourceGroup
    The name of the resource group containing the App Service Plan.

.Parameter NMEAppServicePlan
    The name of the existing App Service Plan.
#>

param(
    [string]$NMESubscription = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    [string]$NMEResourceGroup = 'rg-nerdio',
    [string]$NMEAppServicePlan = 'nmw-app-plan-xxxxxxxxxx'
)

# Variables for the script
$NMEInstanceName = $NMEAppServicePlan.Split('-')[-1].ToLower()

$NMEAppServicePlanNew = "$NMEAppServicePlan-dr"
$NMESQLServerName = "nmw-app-sql-$NMEInstanceName"
$NMEDataBaseName = 'nmw-app-db'
$NMEKeyVaultName = "nmw-app-kv-$NMEInstanceName"
$NMEDRStorageAccountName = "stnmedr$NMEInstanceName"
$NMEContainerName = 'locks'
$secretName = 'Deployment--LocksContainerSasUrl'
$addYears = 100

# Set Azure context
$context = Set-AzContext -SubscriptionName $NMESubscription

# Retrieve existing App Service Plan
$existingAppServicePlan = Get-AzAppServicePlan -ResourceGroupName $NMEResourceGroup -Name $NMEAppServicePlan

# Retrieve storage account keys
$drStorageAccount = Get-AzStorageAccount -ResourceGroupName $NMEResourceGroup -Name $NMEDRStorageAccountName -ErrorAction SilentlyContinue
If (!$drStorageAccount) {
    # Create a new storage account for DR
    $drStorageAccount = New-AzStorageAccount -ResourceGroupName $NMEResourceGroup -Name $NMEDRStorageAccountName -Location $existingAppServicePlan.Location -SkuName Standard_ZRS -Kind StorageV2

    # Create a new container for DR
    $drContainer = New-AzStorageContainer -Name $NMEContainerName -Context $drStorageAccount.Context -Permission Off
}

# Generate SAS token for container
$sasKeys = Get-AzStorageAccountKey -ResourceGroupName $NMEResourceGroup -Name $NMEDRStorageAccountName

# Create a new storage context for the DR storage account
$ctx = New-AzStorageContext -StorageAccountName $NMEDRStorageAccountName -StorageAccountKey $sasKeys[0].Value

# Generarte a SAS token for the DR storage account
$drSasToken = New-AzStorageContainerSASToken -Name $NMEContainerName -Permission "rcw" -Protocol HttpsOnly -Context $ctx -ExpiryTime (Get-Date).AddYears($addYears) -FullUri
Write-Output "DR Storage Account: $($ctx.StorageAccountName)"
Write-Output ("DR Storage Account SAS Token: {0}" -f $drSasToken)

# Store the SAS token in the Key Vault
$secretValue = ConvertTo-SecureString -String $drSasToken -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $NMEKeyVaultName -Name $secretName -SecretValue $secretValue

# Retrieve all web apps in the service plan
$servicePlanApps = Get-AzWebApp -AppServicePlan $existingAppServicePlan

# Restart all web apps
$servicePlanApps | ForEach-Object {
    Write-Output "Restarting $($_.Name)"
    Restart-AzWebApp -ResourceGroupName $_.ResourceGroup -Name $_.Name
}

# Verify required files exist in storage container
$retryCount = 0
$retryLimit = 10
$retryInterval = 30
$files = @('background.loop', 'web.startup')
$filesPresent = $false

do {
    $retryCount++
    $filesPresent = $true
    $files | ForEach-Object {
        $file = Get-AzStorageBlob -Container $NMEContainerName -Context $ctx -Blob $_ -ErrorAction SilentlyContinue
        If (!$file) {
            Write-Output "$_ is not present in the container"
            $filesPresent = $false
        }
    }

    If (!$filesPresent) {
        Write-Output "Retrying in $retryInterval seconds"
        Start-Sleep -Seconds $retryInterval
    }
} While (!$filesPresent -and $retryCount -lt $retryLimit)

# Exit if required files are not present, and throw an error
If (!$filesPresent) {
    Write-Error "Required files are not present in the storage container. Exiting script." -ErrorAction Stop
    Throw "Required files are not present in the storage container. Exiting script."
    Exit
}

# Obtain Azure access token
$secureToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com" -AsSecureString).Token
$token = ConvertFrom-SecureString -SecureString $secureToken -AsPlainText
$authHeader = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
}

# Create new App Service Plan (DR)
$uri = "https://management.azure.com/subscriptions/$($existingAppServicePlan.Subscription)/resourceGroups/$($existingAppServicePlan.ResourceGroup)/providers/Microsoft.Web/serverfarms/$($NMEAppServicePlanNew)?api-version=2024-04-01"

$body = @{
    location   = $existingAppServicePlan.GeoRegion
    sku        = @{
        name     = "P0v3"
        tier     = "Premium0V3"
        size     = "P0v3"
        family   = "Pv3"
        capacity = 3  # At least 3 instances for zone redundancy
    }
    properties = @{
        zoneRedundant = $true
    }
} | ConvertTo-Json -Depth 3 -Compress

# API-Request send
$response = Invoke-RestMethod -Uri $uri -Method Put -Headers $authHeader -Body $body
Write-Output "New App Service Plan created: $($response.name)"

# Update the web apps to use the new app service plan
$servicePlanApps | ForEach-Object {
    Write-Output "Updating $($_.Name) to use the new App Service Plan"

    # Check if the resource is an Web App or a Function App
    If ($_.Kind -eq 'app') {
        try {
            $result = Set-AzWebApp -ResourceGroupName $_.ResourceGroup -Name $_.Name -AppServicePlan $response.name
        } catch {
            Write-Output $_.Exception.Message
        }

    } ElseIf ($_.Kind -eq 'functionapp') {
        try {
            $result = Update-AzFunctionApp -ResourceGroupName $_.ResourceGroup -Name $_.Name -PlanName $response.name
        } catch {
            Write-Output $_.Exception.Message
        }

    } Else {
        Write-Output "Unmanaged resource type: $($_.Kind)"
    }
    Write-Output "App Service Plan updated for $($_.Name)"
}

# Configure the SQL database for zone redundancy
$parameters = @{
    ResourceGroupName = $NMEResourceGroup
    ServerName        = $NMESQLServerName
    DatabaseName      = $NMEDataBaseName
}

try {
    $result = Set-AzSqlDatabase @parameters -ZoneRedundant -ErrorAction Stop
    Write-Output "SQL Database configured for zone redundancy"
} catch {
    Write-Output $_.Exception.Message
}

# Get all storage accounts in the specified resource group
$storageAccounts = Get-AzStorageAccount -ResourceGroupName $NMEResourceGroup

foreach ($storageAccount in $storageAccounts) {
    if ($storageAccount.Sku.Name -eq 'Standard_LRS') {

        Write-Output "Starting migration of $($storageAccount.StorageAccountName) in $($storageAccount.ResourceGroupName) to $($storageAccount.targetSKU)"
        $result = Start-AzStorageAccountMigration `
            -AccountName $storageAccount.StorageAccountName `
            -ResourceGroupName $storageAccount.ResourceGroupName `
            -TargetSku 'Standard_ZRS' `
            -Name "Migration of $($storageAccount.StorageAccountName)" `
            -AsJob
        Write-Output "Migration started for: $($storageAccount.StorageAccountName)"
    } else {
        Write-Output "Storage Account: $($storageAccount.StorageAccountName) is not LRS. Skipping..."
    }
}

Write-Output "Migration process completed for Resource Group: $ResourceGroupName"
