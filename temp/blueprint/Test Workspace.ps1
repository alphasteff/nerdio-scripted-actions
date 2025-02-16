#Create a workspace
$SubscriptionID = '5c1e6067-ba5d-4290-8ecd-7b52c4fd8af9'
$ResourceGroup = 'rg-dubai1-avdlz-prd-we-01'
$RegionName = "westeurope"
$ADProfileName = 'Azure AD Only'

$objectid = New-NmeWvdObjectId -SubscriptionId $SubscriptionID -ResourceGroup $ResourceGroup -Name Dubai2
$workspacerequest = New-NmeCreateWorkspaceRequest -Id $objectid -Location $RegionName -FriendlyName Dubai2
New-NmeWorkspace -NmeCreateWorkspaceRequest $workspacerequest

$objectid = New-NmeWvdObjectId -SubscriptionId $SubscriptionID -ResourceGroup $ResourceGroup -Name Dubai2
$PooledpARAMS = New-NmePooledParams -IsDesktop $True -IsSingleUser $False
$hostpoolrequest = New-NmeCreateArmHostPoolRequest -WorkspaceId $objectid -PooledParams $PooledpARAMS
New-NmeHostPool -SubscriptionId $SubscriptionID -ResourceGroup $ResourceGroup -HostPoolName Dubai2 -NmeCreateArmHostPoolRequest $hostpoolrequest

$PredefinedConfigId = Get-NmeAdConfig | Where-Object { $_.FriendlyName -eq $ADProfileName } | Select-Object -ExpandProperty Id
$adConfig = @{
    Type               = "Predefined"
    PredefinedConfigId = $PredefinedConfigId
}
$NmeUpdateHostPoolActiveDirectory = New-NmeUpdateHostPoolActiveDirectoryRestModel @adConfig
Set-NmeHostPoolADConfig -SubscriptionId $SubscriptionID -ResourceGroup $ResourceGroup -HostPoolName Dubai2 -NmeUpdateHostPoolActiveDirectoryRestModel $NmeUpdateHostPoolActiveDirectory

ConvertTo-NmeDynamicHostPool -SubscriptionId $SubscriptionID -ResourceGroup $ResourceGroup -HostPoolName Dubai2

# ----------------------------------------------------------

# Configure AutoScale
$SubscriptionID = '5c1e6067-ba5d-4290-8ecd-7b52c4fd8af9'
$ResourceGroupName = 'rg-pocvdi-avdlz-prd-we-01'
$HostPoolName = 'avdp-pocvdi-avdlz-prd-we-01'
$RegionName = "westeurope"

$resourceGroupId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
$networkId = "/subscriptions/$SubscriptionId/resourceGroups/rg-networking-id-prd-aa-01/providers/Microsoft.Network/virtualNetworks/vnet-spoke-id-prd-we-01"

# Create VM Template Configuration
$paramVMTemplate = @{
    Prefix             = "avdwexxv-poc0{##}"
    Size               = "Standard_d4s_v5"
    Image              = "microsoftwindowsdesktop/windows-ent-cpc/win11-23h2-ent-cpc-m365/latest"
    StorageType        = 'StandardSSD_LRS'
    ResourceGroupId    = $resourceGroupId
    NetworkId          = $networkId
    Subnet             = 'snet-domainservices-id-prd-we-01'
    DiskSize           = 256
    HasEphemeralOSDisk = $False
}
$vmtemplate = New-NmeVmTemplateParams @paramVMTemplate

If ($PreStateHostsConfiguration) { throw "Not supported at the moment" } Else { $preStage = New-NmePreStateHostsConfiguration -Enable $False }
If ($ScaleIntimeRestrictionConfiguration) { throw "Not supported at the moment" } Else { $scaleinreestriction = New-NmeScaleIntimeRestrictionConfiguration -Enable $False }
If ($AutoHealConfiguration) { throw "Not supported at the moment" } Else { $autoheal = New-NmeAutoHealConfiguration -Enable $False }

$userDriven = New-NmeUserDrivenRestConfiguration -StopDelayMinutes 30
$removemessaging = New-NmeWarningMessageSettings -MinutesBeforeRemove 10 -Message "Sorry for the interruption. We are doing some housekeeping and need you to log out. You can log in right away to continue working. We will be terminating your session in 10 minutes if you haven't logged out by then"

$NotificationSubjectTemplate = "WARNING: Your personal AVD desktop will be deleted"
$NotificationTemplate = "<p>This is an automated notification.</p><p>Your personal Azure Virtual Desktop (%HOSTNAME%) on hostpool %HOSTPOOL% has not been accessed for %HOST_IDLE_DAYS% days (the threshold is %HOST_IDLE_DAYS_THRESHOLD% days). This desktop is now scheduled for deletion at %SHRINK_TIME_UTC% on %SHRINK_DATE%. Once deleted, you will no longer be able to access it and any data stored on this desktop will be irretrievably lost.</p><p>To prevent this deletion, please log into your desktop as soon as possible and stay connected for at least 30 minutes.</p>"

$personalAutoGrow = New-NmePersonalAutoGrowRestConfiguration -Unit 1 -UnassignedThreshold 2 # Unit 0 = % of total desktops, 1 = number of desktops
$personalAutoShrink = New-NmePersonalAutoShrinkRestConfiguration -Action "DeleteVm" -HostIdleDaysThreshold 30 -DeletionDelay 30 -IsNotificationsEnabled $false -ExcludeUnassigned $False -NotificationSubjectTemplate $NotificationSubjectTemplate -NotificationTemplate $NotificationTemplate

$triggerInfo = @()
$triggerInfo += New-NmeTriggerInfo -TriggerType 'UserDriven' -UserDriven $userDriven
$triggerInfo += New-NmeTriggerInfo -TriggerType 'PersonalAutoGrow' -PersonalAutoGrow $personalAutoGrow
$triggerInfo += New-NmeTriggerInfo -TriggerType 'PersonalAutoShrink' -PersonalAutoShrink $personalAutoShrink

$paramConfigs = @{
    PreStageHosts      = $preStage
    ScaleInRestriction = $scaleinreestriction
    AutoHeal           = $autoheal
    UserDriven         = $userDriven
    RemoveMessaging    = $removemessaging
}

$paramAutoScaling = @{
    IsEnabled              = $false
    TimezoneId             = "Central Europe Standard Time"
    VmTemplate             = $vmtemplate
    ReuseVmNames           = $False
    EnableFixFailedTask    = $False
    IsSingleUserDesktop    = $True
    ActiveHostType         = "AvailableforConnection"
    MinCountCreatedVmsType = "HostPoolCapacity"
    ScalingMode            = "UserDriven"
    HostPoolCapacity       = 1
    MinActiveHostsCount    = 1
    BurstCapacity          = 0
    AutoScaleCriteria      = "UserDriven"
    ScaleInAggressiveness  = "Low"
    VmNamingMode           = 'Reuse'
}

$paramAutoScaling.Add("StoppedDiskType", "Standard_LRS")
If ($triggerInfo) { $paramAutoScaling.Add("AutoScaleTriggers", $triggerInfo) }

$autoScaleConfig = New-NmeDynamicPoolConfiguration @paramConfigs @paramAutoScaling

$paramHostPool = @{
    SubscriptionId = $SubscriptionId
    ResourceGroup  = $ResourceGroupName
    HostPoolName   = $HostPoolName
}

If ($triggerInfo) { $paramHostPool.Add("MultiTriggers", $true) }

Set-NmeHostPoolAutoScaleConfig @paramHostPool -NmeDynamicPoolConfiguration $autoScaleConfig







Get-Module -Name NerdioManagerPowerShell
