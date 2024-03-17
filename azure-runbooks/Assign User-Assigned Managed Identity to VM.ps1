#name: Assign User-Assigned Managed Identity to VM
#description: Assign a user-assigned managed identity to a  VM.
#execution mode: Individual
#tags: beckmann.ch

<# Notes:

Use this script to assign a user-assigned managed identity to a VM.

Requires:
- A variable with the name DeployIdentity and the value for the User-Assigned Managed Identity used for the deployment.

#>

$ErrorActionPreference = 'Stop'

# Get all Azure Subscriptions
$subscriptions = Get-AzSubscription

# Get the current Azure Context
$existingContext = Get-AzContext

# Loop through all Azure Subscriptions and search Key Vaults with the name $KeyVaultName in each subscription
ForEach ($subscription in $subscriptions) {
    $context = Set-AzContext -SubscriptionId $subscription.Id
    Write-Output "Checking subscription $($subscription.Name)"
    $KeyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    If ($KeyVault) {
        Write-Output "Found Key Vault $KeyVaultName in subscription $($subscription.Name)"
        Break
    }
}

# Set the Azure Context back to the original Azure Context
$context = Set-AzContext -SubscriptionId $existingContext.Subscription.Id

$actContext = Get-AzContext
Write-Output ("ActContext = {0}" -f ($actContext | Out-String))

$Prefix = ($KeyVaultName -split '-')[0]
$NMEIdString = ($KeyVaultName -split '-')[3]
$NMEResourceGroupName = $KeyVault.ResourceGroupName
$NMESubscriptionId = $KeyVault.ResourceId.Split('/')[2]

$IdentityVariable = 'DeployIdentity'
$identity = ConvertFrom-Json $SecureVars.$IdentityVariable

Write-Output "KeyVaultName = $KeyVaultName"
Write-Output "KeyVault = $KeyVault"
Write-Output "Context = $Context"

Write-Output "Prefix = $Prefix"
Write-Output "NMEIdString = $NMEIdString"
Write-Output "NMEResourceGroupName = $NMEResourceGroupName"
Write-Output "NMESubscriptionId = $NMESubscriptionId"

Write-Output "AzureSubscriptionId = $AzureSubscriptionId"
Write-Output "AzureSubscriptionName = $AzureSubscriptionName"
Write-Output "AzureResourceGroupName = $AzureResourceGroupName"

##### Script Logic #####

try {
    #Assign the user-assigned managed identity.
    Write-Output "Assign user-assigned managed identity"
    $umidentity = Get-AzUserAssignedIdentity -ResourceGroupName $Identity.resourcegroup -Name $Identity.name -SubscriptionId $Identity.subscriptionid

    Write-Output ("umidentity = {0}" -f ($umidentity | Out-String))

    $vm = Get-AzVM -ResourceGroupName $AzureResourceGroupName -VM $AzureVMName

    Write-Output ("VM = {0}" -f ($vm | Out-String))

    If ($vm.Identity.Type -eq 'SystemAssigned') {
        Write-Output ('System Assigned Identeity exists, add the User Assigned Identity.')
        Update-AzVM -ResourceGroupName $AzureResourceGroupName -VM $vm -IdentityType "SystemAssignedUserAssigned" -IdentityId $umidentity.Id
    } Else {
        Write-Output ("System Assigned Identeity doesn't exists, add only the User Assigned Identity.")
        Update-AzVM -ResourceGroupName $AzureResourceGroupName -VM $vm -IdentityType "UserAssigned" -IdentityId $umidentity.Id
    }
} catch {
    $ErrorActionPreference = 'Continue'
    Write-Output "Encountered error. $_"
    Throw $_
}
