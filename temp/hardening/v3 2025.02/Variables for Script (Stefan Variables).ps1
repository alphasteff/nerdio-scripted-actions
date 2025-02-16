<# Variables:
{
  "PrivateLinkVnetName": {
    "Description": "VNet for private endpoints. If the vnet does not exist, it will be created. If specifying an exising vnet, the vnet or its resource group must be linked to Nerdio Manager in Settings->Azure environment",
    "IsRequired": true,
    "DefaultValue": "vnet-spoke-avdss-prd-we-01"
  },
  "VnetAddressRange": {
    "Description": "Address range for private endpoint vnet. Not used if vnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.42.64.0/19"
  },
  "PrivateEndpointSubnetName": {
    "Description": "Name of private endpoint subnet. If the subnet does not exist, it will be created.",
    "IsRequired": true,
    "DefaultValue": "snet-nerdio_endpoint-avdss-prd-we-01"
  },
  "PrivateEndpointSubnetRange": {
    "Description": "Address range for private endpoint subnet. Not used if subnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.42.66.0/24"
  },
  "AppServiceSubnetName": {
    "Description": "App service subnet name. If the subnet does not exist, it will be created.",
    "IsRequired": true,
    "DefaultValue": "snet-nerdio_service-avdss-prd-we-01"
  },
  "AppServiceSubnetRange": {
    "Description": "Address range for app service subnet. Not used if subnet already exists.",
    "IsRequired": false,
    "DefaultValue": "10.42.65.0/24"
  },
  "ExistingDNSZonesSubscriptionId": {
    "Description": "If you have private DNS zones already configured for use with the new private endpoints, specify their subscription id here, if it's not on the same subscription.",
    "IsRequired": false,
    "DefaultValue": "8e6e1693-2f4e-40a7-9772-6b47cf5d4466"
  },
  "ExistingDNSZonesRG": {
    "Description": "If you have private DNS zones already configured for use with the new private endpoints, specify their resource group here.",
    "IsRequired": false,
    "DefaultValue": "rg-networking-con-prd-aa-01"
  },
  "MakeSaStoragePrivate": {
    "Description": "Make the scripted actions storage account private. Will create a hybrid worker VM, if one does not already exist. This will result in increased cost for Nerdio Manager Azure resources",
    "IsRequired": false,
    "DefaultValue": "true"
  },
  "PeerVnetIds": {
    "Description": "Optional. Values are 'All' or comma-separated list of Azure resource IDs of vnets to peer to private endpoint vnet. If 'All' then all vnets NME manages will be peered. The Vnets or their resource groups must be linked to Nerdio Manager in Settings->Azure environment",
    "IsRequired": false,
    "DefaultValue": "/subscriptions/37f76653-992c-450e-a81e-1b5d65870eef/resourceGroups/rg-networking-avdlz-prd-aa-01/providers/Microsoft.Network/virtualNetworks/vnet-spoke-avdlz-prd-we-01"
  },
  "MakeAzureMonitorPrivate": {
    "Description": "WARNING: Because Azure Monitor uses some shared endpoints, setting up a private link even for a single resource changes the DNS configuration that affects traffic to all resources. You may not want to enable this if you have existing Log Analytics Workspaces or Insights. To minimize potential impact, this script sets ingestion and query access mode to 'Open' and disables public access on the Nerdio Manager resources only. This can be modified by cloning this script and modifying the AMPLS settings variables below.",
    "IsRequired": false,
    "DefaultValue": "false"
  },
  "MakeAppServicePrivate": {
    "Description": "Limit access to the Nerdio Manager application. If set to true, only hosts on the vnet created by this script, or on peered vnets, will be able to access the app service URL.",
    "IsRequired": false,
    "DefaultValue": "true"
  }
}
#>