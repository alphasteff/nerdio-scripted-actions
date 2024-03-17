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

$ManagedIdentityVariable = $SecureVars.$ManagedIdentityVariable | ConvertFrom-Json
$StorageAccountVariable = $SecureVars.$StorageAccountVariable | ConvertFrom-Json

##### Script Logic #####


try {
    #Assign the user-assigned managed identity.
    Write-Output "Assign user-assigned managed identity"
    Write-Output ("Managed Identity: " + $ManagedIdentityVariable.Name)
    Write-Output ("Storage Account : " + $StorageAccountVariable.Name)

    $actContext = Get-AzContext
    If ($actContext.Subscription.Id -ne $ManagedIdentityVariable.subscriptionid) {
        Set-AzContext -SubscriptionId $ManagedIdentityVariable.subscriptionid
    }
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ManagedIdentityVariable.ResourceGroup -Name $ManagedIdentityVariable.Name

    $actContext = Get-AzContext
    If ($actContext.Subscription.Id -ne $StorageAccountVariable.subscriptionid) {
        Set-AzContext -SubscriptionId $StorageAccountVariable.subscriptionid
    }
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountVariable.ResourceGroup -Name $StorageAccountVariable.Name

    New-AzRoleAssignment -ObjectId $identity.ClientId -Scope $storageAccount.Id -RoleDefinitionName "Storage Account Contributor"


} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
