#name: Assign User-Assigned Managed Identity to Desktop Image VM
#description: Assign a user-assigned managed identity to a Desktop Image VM.
#execution mode: Individual with restart
#tags: beckmann.ch, Preview

<# Notes:

Use this script to assign a user-assigned managed identity to a Desktop Image VM.

Requires:
- A variable with the name DeployIdentity and the value for the User-Assigned Managed Identity used for the deployment.

#>

$ErrorActionPreference = 'Stop'

$Prefix = ($KeyVaultName -split '-')[0]
$NMEIdString = ($KeyVaultName -split '-')[3]
$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName
$Context = Get-AzContext
$NMEResourceGroupName = $KeyVault.ResourceGroupName

##### Script Logic #####

try {
  #Assign the user-assigned managed identity.
  Write-Output "Assign user-assigned managed identity"
  $identity = Get-AzUserAssignedIdentity -ResourceGroupName $NMEResourceGroupName -Name $SecureVars.DeployIdentity
  $vm = Get-AzVM -ResourceGroupName $AzureResourceGroupName -VM $AzureVMName
  Update-AzVM -ResourceGroupName $AzureResourceGroupName -VM $vm -IdentityType "UserAssigned" -IdentityID $identity.Id

}
catch {
  $ErrorActionPreference = 'Continue'
  write-output "Encountered error. $_"
  Throw $_ 
}
