#name: Create User-Assigned Managed Identity
#description: Create a user-assigned managed identity to use in scripted actions.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

Use this script to create a user-assigned managed identity in the resource group of Nerdio.

#>

<# Variables:
{
  "UserManagedIdentityName": {
    "Description": "Name of the user-assigned managed identity.",
    "IsRequired": true,
    "DefaultValue": "uami-nerdio-scripted-actions"
  }
}
#>

$ErrorActionPreference = 'Stop'

$Prefix = ($KeyVaultName -split '-')[0]
$NMEIdString = ($KeyVaultName -split '-')[3]
$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName
$Context = Get-AzContext
$NMEResourceGroupName = $KeyVault.ResourceGroupName
$NMELocation = $KeyVault.Location

##### Script Logic #####

try {


  #Creating the user-assigned managed identity.
  Write-Output "Create user-assigned managed identity"
  $identity = New-AzUserAssignedIdentity -ResourceGroupName $NMEResourceGroupName -Name $UserManagedIdentityName -Location $NMELocation

}
catch {
  $ErrorActionPreference = 'Continue'
  write-output "Encountered error. $_"
  write-output "Rolling back changes"

  if ($identity) {
    Write-Output "Removing user-assigned managed identity $UserManagedIdentityName"
    Remove-AzUserAssignedIdentity -ResourceGroupName $NMEResourceGroupName -Name $UserManagedIdentityName -Force -ErrorAction Continue
  }
  Throw $_ 
}
