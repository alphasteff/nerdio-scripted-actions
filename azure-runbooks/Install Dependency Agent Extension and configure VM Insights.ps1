#name: Install Dependency Agent Extension and configure VM Insights
#description: Installs the native Azure "Dependency Agent" extension on the Azure VM and assign a Data Collection Rule. Useful to get insights from the VM.
#execution mode: Combined
#tags: baseVISION

<# Notes:

This Script will install the Microsoft Dependency Agent extension on the Azure VM. It then enables the Azure VM Insights.
See MS Doc for more details: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/agent-dependency-windows

#>

# Set Error action
$errorActionPreference = "Stop"

$VMInsightsConfigVariable = 'VMInsightsConfig'

##### Script Logic #####

# Load Secure Variables
$vmInsightsConfig = $SecureVars.$VMInsightsConfigVariable | ConvertFrom-Json
$dcrName = $vmInsightsConfig.name
$dcrSubscriptionId = $vmInsightsConfig.subscriptionId
$dcrResourceGroupName = $vmInsightsConfig.resourceGroupName
$dcrAssociationName = $vmInsightsConfig.associationName

# Define variable for dcr association name
$dcrAssociationName = ("$AzureVMName-$dcrAssociationName").ToLower()

# Define the DCR Rule ID
$dcrRuleId = "/subscriptions/$dcrSubscriptionId/resourceGroups/$dcrResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/$dcrName"

# Get the VM object
$vm = Get-AzVM -ResourceGroupName $AzureResourceGroupName -VM $AzureVMName

# Ensure context is using correct subscription
Set-AzContext -SubscriptionId $AzureSubscriptionId

# Define variables
$azVM = Get-AzVM -Name $AzureVMName -ResourceGroupName $AzureResourceGroupName
$publisherName = "Microsoft.Azure.Monitoring.DependencyAgent"
$extensionName = "DependencyAgentWindows"
$extensionType = "DependencyAgentWindows"
$extensionSettings = @{"enableAMA" = "True" }

# Get the latest major version for Dependency Agent Extension
$extensionVersion = ((Get-AzVMExtensionImage -Location $azVM.Location -PublisherName $publisherName -Type $extensionType).Version[-1][0..2] -join '')

# Enable the Microsoft Dependency Agent Extension with the above settings
$dpaExtension = @{
    ResourceGroupName      = $azVM.ResourceGroupName
    Location               = $azVM.Location
    VMName                 = $AzureVMName
    Name                   = $extensionName
    Publisher              = $publisherName
    ExtensionType          = $extensionType
    Settings               = $extensionSettings
    TypeHandlerVersion     = $extensionVersion
    EnableAutomaticUpgrade = $False
}
Write-Output "Install Dependency Agent Extension on $AzureVMName"
Set-AzVMExtension @dpaExtension

# Associate the Data Collection Rule with the VM
New-AzDataCollectionRuleAssociation -TargetResourceId $vm.Id -AssociationName $dcrAssociationName -RuleId $dcrRuleId
