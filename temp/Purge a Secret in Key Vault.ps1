# Purge a Secret in Key Vault

param(
    [string]$NMESubscription = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    [string]$NMEResourceGroup = 'rg-nerdio',
    [string]$NMEAppName = 'nmw-app-xxxxxxxxxx'
)

# Variables for the script
$NMEInstanceName = $NMEAppName.Split('-')[-1].ToLower()
$NMEKeyVaultName = "nmw-app-kv-$NMEInstanceName"
$secretName = 'Deployment--LocksContainerSasUrl'

# Set Azure context
$context = Set-AzContext -SubscriptionName $NMESubscription

# Purge the secret
Remove-AzKeyVaultSecret -VaultName $NMEKeyVaultName -Name $secretName -InRemovedState -Force