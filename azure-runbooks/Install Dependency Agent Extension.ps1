#name: Install Dependency Agent Extension
#description: Installs the native Azure "Dependency Agent" extension on the Azure VM. Useful to get insights from the VM.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

This Script will install the Microsoft Dependency Agent extension on the Azure VM. It then enables the Azure VM Insights.
See MS Doc for more details: https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/agent-dependency-windows

#>

# Set Error action
$errorActionPreference = "Stop"

# Ensure context is using correct subscription
Set-AzContext -SubscriptionId $AzureSubscriptionId

# Define variables
$azVM = Get-AzVM -Name $AzureVMName -ResourceGroupName $AzureResourceGroupName
$publisherName = "Microsoft.Azure.Monitoring.DependencyAgent"
$extensionName = "DependencyAgentWindows"
$extensionType = "DependencyAgentWindows"

# Get the latest major version for Dependency Agent Extension
$extensionVersion = ((Get-AzVMExtensionImage -Location $azVM.Location -PublisherName $publisherName -Type $extensionType).Version[-1][0..2] -join '')

# Enable the Microsoft Dependency Agent Extension with the above settings
$dpaExtension = @{
    ResourceGroupName  = $azVM.ResourceGroupName
    Location           = $azVM.Location
    VMName             = $AzureVMName
    Name               = $extensionName
    Publisher          = $publisherName
    ExtensionType      = $extensionType
    TypeHandlerVersion = $extensionVersion
}
Write-Output "Install Dependency Agent Extension on $AzureVMName"
Set-AzVMExtension @dpaExtension
