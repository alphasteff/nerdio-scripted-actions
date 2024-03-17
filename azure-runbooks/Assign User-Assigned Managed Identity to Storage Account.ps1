#name: Assign User-Assigned Managed Identity to Storage Account
#description: Assign a user-assigned managed identity to a Storage Account to get a SAS Token.
#execution mode: Combined
#tags: beckmann.ch

<# Notes:

Use this script to authorize a user-assigned managed identity on a storage account to create a SAS token.

Requires:
- A variable with the name DeployIdentity and the value for the User-Assigned Managed Identity used for the deployment.
- A variable with the name DeployStorageAccount and the value for the storage account used for the deployment.
#>

<# Variables:
{
  "ManagedIdentityVariable": {
    "Description": "Name of the secure variable for the managed identity.",
    "IsRequired": true,
    "DefaultValue": "DeployIdentity"
  },
  "StorageAccountVariable": {
    "Description": "Name of the secure variable for the storage account.",
    "IsRequired": true,
    "DefaultValue": "DeployStorageAccount"
  }
}
#>

$ErrorActionPreference = 'Stop'

$Prefix = ($KeyVaultName -split '-')[0]
$NMEIdString = ($KeyVaultName -split '-')[3]
$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName
$Context = Get-AzContext
$NMEResourceGroupName = $KeyVault.ResourceGroupName

Write-Output "Get secure variables"
$ManagedIdentity = $SecureVars.$ManagedIdentityVariable | ConvertFrom-Json
$StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json

Write-Output ("Managed Identity: " + ($ManagedIdentity | Out-String))
Write-Output ("Storage Account : " + ($StorageAccount | Out-String))

##### Script Logic #####


try {
    #Assign the user-assigned managed identity.
    Write-Output "Assign user-assigned managed identity"
    Write-Output ("Managed Identity: " + $ManagedIdentity.Name)
    Write-Output ("Storage Account : " + $StorageAccount.Name)

    $actContext = Get-AzContext
    If ($actContext.Subscription.Id -ne $ManagedIdentity.subscriptionid) {
        Set-AzContext -SubscriptionId $ManagedIdentity.subscriptionid
    }
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ManagedIdentity.ResourceGroup -Name $ManagedIdentity.Name

    $actContext = Get-AzContext
    If ($actContext.Subscription.Id -ne $StorageAccount.subscriptionid) {
        Set-AzContext -SubscriptionId $StorageAccount.subscriptionid
    }
    $objStorageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccount.ResourceGroup -Name $StorageAccount.Name

    New-AzRoleAssignment -ObjectId $identity.ClientId -Scope $objStorageAccount.Id -RoleDefinitionName "Storage Account Contributor"


} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
