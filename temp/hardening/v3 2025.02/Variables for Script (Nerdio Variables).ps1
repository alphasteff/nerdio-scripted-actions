<# Variables:
{
  "PrivateLinkVnetName": {
    "Description": "VNet for private endpoints. If the vnet does not exist, it will be created. If specifying an exising vnet, the vnet or its resource group must be linked to Nerdio Manager in Settings->Azure environment",
    "IsRequired": true,
    "DefaultValue": "nme-private-vnet"
  },
  "VnetAddressRange": {
    "Description": "Address range for private endpoint vnet. Not used if vnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.250.250.0/23"
  },
  "PrivateEndpointSubnetName": {
    "Description": "Name of private endpoint subnet. If the subnet does not exist, it will be created.",
    "IsRequired": true,
    "DefaultValue": "nme-endpoints-subnet"
  },
  "PrivateEndpointSubnetRange": {
    "Description": "Address range for private endpoint subnet. Not used if subnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.250.250.0/24"
  },
  "AppServiceSubnetName": {
    "Description": "App service subnet name. If the subnet does not exist, it will be created.",
    "IsRequired": true,
    "DefaultValue": "nme-app-subnet"
  },
  "AppServiceSubnetRange": {
    "Description": "Address range for app service subnet. Not used if subnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.250.251.0/28"
  },
  "ExistingDNSZonesSubscriptionId": {
    "Description": "If you have private DNS zones already configured for use with the new private endpoints, specify their subscription id here, if it's not on the same subscription.",
    "IsRequired": false,
    "DefaultValue": ""
  },
  "ExistingDNSZonesRG": {
    "Description": "If you have private DNS zones already configured for use with the new private endpoints, specify their resource group here.",
    "IsRequired": false,
    "DefaultValue": ""
  },
  "MakeSaStoragePrivate": {
    "Description": "Make the scripted actions storage account private. Will create a hybrid worker VM, if one does not already exist. This will result in increased cost for Nerdio Manager Azure resources",
    "IsRequired": false,
    "DefaultValue": "false"
  },
  "PeerVnetIds": {
    "Description": "Optional. Values are 'All' or comma-separated list of Azure resource IDs of vnets to peer to private endpoint vnet. If 'All' then all vnets NME manages will be peered. The Vnets or their resource groups must be linked to Nerdio Manager in Settings->Azure environment",
    "IsRequired": false,
    "DefaultValue": ""
  },
  "MakeAzureMonitorPrivate": {
    "Description": "WARNING: Because Azure Monitor uses some shared endpoints, setting up a private link even for a single resource changes the DNS configuration that affects traffic to all resources. You may not want to enable this if you have existing Log Analytics Workspaces or Insights. To minimize potential impact, this script sets ingestion and query access mode to 'Open' and disables public access on the Nerdio Manager resources only. This can be modified by cloning this script and modifying the AMPLS settings variables below.",
    "IsRequired": false,
    "DefaultValue": "false"
  },
  "MakeAppServicePrivate": {
    "Description": "Limit access to the Nerdio Manager application. If set to true, only hosts on the vnet created by this script, or on peered vnets, will be able to access the app service URL.",
    "IsRequired": false,
    "DefaultValue": "false"
  }
}
#>