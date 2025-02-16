# Pre-requisites
# Nerdio SP must be Reader and Contributor on the subscription, where the resources are being created

# Register Azure Service Provider Microsoft.DesktopVirtualization
# Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization

# Import Nerdo Manager PowerShell Module
#Install-Module -Name NerdioManagerPowerShell -AllowPrerelease

# Sets the variables
# ------------------------------------------------------------------------------------------
# Set the path to the configuration file and the flag to export the configuration file
$configFile = 'd:\Temp\config.json'
$avdConfigFile = 'd:\Temp\avdConfigs.json'
$exportAvdConfigFile = $true

# ------------------------------------------------------------------------------------------
# Set the flags to update the resources, or skip the update
$updateSqlDatabasePlan = $false
$updateAppServicePlan = $false
$updateWorkspaceQuota = $false
$createDeploymentResourceGroup = $false
$createDeploymentManagedIdentity = $false
$createDeploymentStorageAccount = $false
$assignManagedIdentityToStorageAccount = $false
$createSecureVars = $false
$linkSubscription = $false
$linkSubnets = $false

# ------------------------------------------------------------------------------------------
# Throttle Limit if multiple resources are being created
$throttleLimit = 2

# ------------------------------------------------------------------------------------------
# Import the configuration file
$config = Get-Content $configFile | ConvertFrom-Json

# ------------------------------------------------------------------------------------------
# Set the variables for the Azure Cloud and the Region
$AzureCloud = $config.Resource.azureCloud
$RegionName = $config.Resource.regionName

# ------------------------------------------------------------------------------------------
# Set the variables for the Nerdio Manager for Enterprise (NME) instance
$NMEInstanceId = $config.Nerdio.instanceId
$NMEClientId = $config.Nerdio.clinetId
$NMEClientSecret = $config.Nerdio.clientSecret
$NMETenantId = $config.Nerdio.tenantId
$NMESubscriptionId = $config.Nerdio.subscriptionId
$NMEScope = $config.Nerdio.scope
$NMEuRI = "https://nmw-app-{0}.azurewebsites.net/" -f $NMEInstanceId
$NMEResourceGroupName = $config.Nerdio.resourceGroupName
$NMELocation = $config.Nerdio.regionName
$NMESPName = $config.Nerdio.servicePincipalName

# ------------------------------------------------------------------------------------------
# Set the variables for the NME resources
$NMEAppServicePlanName = "nmw-app-plan-$NMEInstanceId"
$NMEAppServicePlanTier = $config.Nerdio.appServicePlanTier # 'Basic', 'Standard', 'Premium', 'PremiumV2'
$NMEAppServicePlanWorkerSize = $config.Nerdio.appServicePlanWorkerSize # 'Small', 'Medium', 'Large' | Basic B1 = Small, Basic B2 = Medium, Basic B3 = Large
$NMESQLDatabaseName = "nmw-app-db"
$NMESQLDatabaseEdition = $config.Nerdio.sqlDatabaseEdition # 'Standard', 'Premium'
$NMESQLDatabaseSKU = $config.Nerdio.sqlDatabaseSKU # S0 = 10 DTU, S1 = 20 DTU, S2 = 50 DTU, S3 = 100 DTU, S4 = 200 DTU, S6 = 400 DTU, S7 = 800 DTU, S9 = 1600 DTU, S12 = 3000 DTU, P1 = 125, P2 = 250, P4 = 500, P6 = 1000, P11 = 1750, P15 = 4000
$NMESQLServerName = "nmw-app-sql-$NMEInstanceId"

$NMEWorkspaceName = "nmw-app-law-$NMEInstanceId"
$NMEWorkSpaceDailyQuotaGb = 1
$NMEInsightWorkspaceName = "nmw-app-law-insights-$NMEInstanceId"
$NMEInsightWorkspaceDailyQuotaGb = 1

# ------------------------------------------------------------------------------------------
# Set the variables for the Azure Virtual Desktop (AVD) resources
$AVDSubscriptionId = $config.AVD.subscriptionId
$AVDVnetResourceGroup = $config.AVD.resourceGroupNameVnet
$AVDVnetConfigs = [System.Collections.ArrayList]@()
$null = $AVDVnetConfigs.Add(@{
        subscriptionId = $AVDSubscriptionId
        resourceGroup  = $AVDVnetResourceGroup
        vnetName       = $config.AVD.vnetName
        subnetName     = @($config.AVD.subnetName)
    })

# ------------------------------------------------------------------------------------------
# Set the variables for the deployment resources
$DeploymentStorageAccountName = "stdeploy$NMEInstanceId"
$DeploymentResourceGroupName = $config.DeploymentStorage.resourceGroupName
$DeploymentResourceGroupTags = $config.DeploymentStorage.tags
$DeploymentStorageAccountSku = $config.DeploymentStorage.storageAccountSku
$DeploymentContainerName = $config.DeploymentStorage.containerName
$DeploymentPrerequisiteName = $config.DeploymentStorage.prerequisiteName
$DeploymentManagedIdentityName = $config.DeploymentStorage.managedIdentityName

# ------------------------------------------------------------------------------------------
# Set the variables for the Admin and Domain
$LocalAdmin = $config.AVD.localAdminUsername
$Fqdn = $config.AVD.fqdn

# ------------------------------------------------------------------------------------------
# Load the configuration file or create the configuration and export it to a file
$avdConfigs = $null
If (Test-Path $avdConfigFile -ErrorAction SilentlyContinue) {
    $avdConfigs = Get-Content $avdConfigFile | ConvertFrom-Json
} Else {
    $ResourceGroupPrefix = 'rg-'
    $WorkspacePrefix = 'avdw-'
    $HostPoolPrefix = 'avdp-'
    $ApplicationGroupPrefix = 'avda-'
    $LandingZoneSuffix = '-avdlz-prd-we-01'
    $DesktopAppSuffix = '-desktop'

    $ResourceGroupName = 'poc'

    $FriendlyName = 'poc'
    $EnvironmentCount = 2

    $hostNamePrefix = 'avdpoc'
    $hostNameSuffix = '{##}'
    $reuseVmNames = $false
    $vmNamingMode = 'Reuse' # 'Standard', 'Reuse', 'Unique'

    # Timezone
    $timezoneId = 'Central Europe Standard Time'

    # VM Configuration
    $vmEnableTimezoneRedirection = $true
    $vmIsAcceleratedNetworkingEnabled = $true
    $vmRdpShortpath = 'DoNothing'
    $vmInstallGPUDrivers = $true
    $vmUseAvailabilityZones = $true
    $vmEnableVmDeallocation = $true
    $vmInstallCertificates = $false
    $vmForceVMRestart = $false
    $vmAlwaysPromptForPassword = $false
    $vmBootDiagEnabled = $true
    $vmWatermarking = $false
    $vmSecurityType = 'TrustedLaunch'
    $vmSecureBootEnabled = $true
    $vmVTpmEnabled = $true

    # Activate Auto-Scale on all neu Host Pools
    $activateAutoScale = $false

    # Host Pool Configuration
    $hostSize = 'Standard_d4s_v5'
    $hostDiskSize = 128
    $hostHasEphemeralOSDisk = $false
    $hostStorageType = 'StandardSSD_LRS'
    $hostStorageTypeStopped = 'Standard_LRS' # 'Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS'
    $hostImage = 'microsoftwindowsdesktop/windows-11/win11-23h2-avd/latest'
    $hostVnetName = 'vnet-spoke-id-prd-we-01'
    $hostSubnetName = 'snet-domainservices-id-prd-we-01'
    $hostPoolTags = @{
        "CostCenter"  = "1234"
        "Environment" = "POC"
    }

    # AVD Host Pool AD Configuration
    $avdHostPoolADProfileType = 'Predefined' # 'Default', 'Predefined', 'Custom'
    $avdHostPoolADProfileName = 'Azure AD Only'

    $avdHostPoolADIdentityType = $null # 'AD, 'AzureAD', 'AzureADDS'
    $avdHostPoolADEnrollWithIntune = $false
    $avdHostPoolADJoinDomainName = $Fqdn
    $avdHostPoolADJoinOrgUnit = $null
    $avdHostPoolADJoinUserName = $null
    $avdHostPoolADJoinPassword = $null

    # AVD Host Pool Configuration
    $avdHostPoolLoadBalancerType = 'BreadthFirst' # 'BreadthFirst', 'DepthFirst', 'Persistent'
    $avdHostPoolMaxSessionLimit = 15
    $avdHostPoolValidationEnv = $true
    $avdHostPoolStartVMOnConnect = $True
    $avdHostPoolPowerOnPooledHosts = $True

    # AVD Session Limit Configuration
    $avdHostPoolSessionTimeoutsEnabled = $true
    $avdHostPoolSessionMaxDisconnectionTime = 360 #
    $avdHostPoolSessionMaxIdleTime = 120
    #$avdHostPoolSessionRemoteAppLogoffTimeLimit = 30

    # AVD Agent Update Configuration
    $avdAgentUpdateType = 'Scheduled' # 'Default', 'Scheduled'
    $avdAgentUpdateDayPrimary = 'Sunday'
    $avdAgentUpdateHourPrimary = 4
    $avdAgentUpdateDaySecondary = $null
    $avdAgentUpdateHourSecondary = $null
    $avdAgentUpdateUseSessionHostLocalTime = $false
    $avdAgentUpdatePowerOnHostsInMaintenanceWindow = $true
    $avdAgentUpdateExcludeDrainModeHosts = $true

    # Auto-Scale Host Pool Sizing
    $activeHostType = 'AvailableforConnection' # 'Running', 'AvailableForConnection'
    $hostPoolCapacity = 1
    $minActiveHostsCount = 1
    $burstCapacity = 0
    $minCountCreatedVmsType = 'HostPoolCapacity' # 'HostPoolCapacity', 'MinActiveHostsProperty'

    # Auto-Scale Scaling Logic
    $autoScaleCriteria = 'UserDriven' # 'CPUUsage', 'RAMUsage', 'AvgActiveSessions', 'AvailableUserSessionSingle', 'AvailableUserSessions', 'UserDriven', 'PersonalAutoGrow', 'PersonalAutoShrink'
    $stopDelayMinutes = 10
    $scalingMode = 'Default' # 'Default', 'WorkingHours', 'UserDriven'
    $scaleInAggressiveness = 'Low' # 'High', 'Medium', 'Low

    # Messaging Auto-Scale
    $minutesBeforeRemove = 10
    $message = "Sorry for the interruption. We are doing some housekeeping and need you to log out. You can log in right away to continue working. We will be terminating your session in $minutesBeforeRemove minutes if you haven't logged out by then"

    $enableFixFailedTask = $false

    # RDP Configurations
    $rdpPropertiesAADSSOName = "MEIDSSO"
    $rdpPropertiesAADSSO = @(
        'audiomode:i:0'
        'audiocapturemode:i:1'
        'autoreconnection enabled:i:1'
        'camerastoredirect:s:*'
        'devicestoredirect:s:*'
        'drivestoredirect:s:*'
        'enablecredsspsupport:i:1'
        'enablerdsaadauth:i:1'
        'redirectclipboard:i:1'
        'redirectprinters:i:1'
        'screen mode id:i:2'
        'targetisaadjoined:i:1'
        'use multimon:i:1'
        'videoplaybackmode:i:1'
    )

    # ------------------------------------------------------------------------------------------
    # Create Hash Tables for Splats
    $logAnalyticWorkspaces = @()
    $logAnalyticWorkspaces += @{
        SubscriptionId    = $NMESubscriptionId
        ResourceGroupName = $NMEResourceGroupName
        Name              = $NMEWorkspaceName
        DailyQuotaGb      = $NMEWorkSpaceDailyQuotaGb
    }
    $logAnalyticWorkspaces += @{
        SubscriptionId    = $NMESubscriptionId
        ResourceGroupName = $NMEResourceGroupName
        Name              = $NMEInsightWorkspaceName
        DailyQuotaGb      = $NMEInsightWorkspaceDailyQuotaGb
    }

    # ------------------------------------------------------------------------------------------
    # Create a List of Workspaces and Hostpools
    $avdConfigs = [System.Collections.ArrayList]@()
    $maxDigits = $EnvironmentCount.tostring().length
    For ($i = 1; $i -le $EnvironmentCount; $i++) {
        $number = "{0:d$maxDigits}"
        $number = $number -f [int]$i

        $isDesktop = $true
        $isSingleUser = $false
        $avdHostPoolType = 'Pooled' # 'Pooled', 'Personal'
        $avdAssignmentType = $null # 'Automatic', 'Direct'
        $avdResourceGroupName = ($ResourceGroupPrefix + $ResourceGroupName + $number + $LandingZoneSuffix).ToLower()
        $avdWorkspaceName = ($WorkspacePrefix + $ResourceGroupName + $number + $LandingZoneSuffix).ToLower()
        $avdWorkspaceFriendlyName = ("$FriendlyName Workspace - $number")
        $avdWorkspaceDescription = ("Workspace for $FriendlyName - $number")
        $avdHostPoolFriendlyName = ("$FriendlyName Host Pool - $number")
        $avdHostPoolDescription = ("Host Pool for $FriendlyName - $number")
        $avdHostpoolName = ($HostPoolPrefix + $ResourceGroupName + $number + $LandingZoneSuffix).ToLower()
        $avdDesktopAppGroupName = ($ApplicationGroupPrefix + $ResourceGroupName + $number + $LandingZoneSuffix + $DesktopAppSuffix).ToLower()
        $userPrincipalName = ('User' + $number + '@' + $Fqdn)

        $hostNamePrefix = "$hostNamePrefix$number-$hostNameSuffix"
        $hostNamePrefix = $hostNamePrefix.ToLower()

        $avdConfig = $null
        $avdConfig = [PSCustomObject]@{
            resourceGroupName = $avdResourceGroupName
            region            = $RegionName
            tags              = $hostPoolTags
            workspace         = [PSCustomObject]@{
                name         = $avdWorkspaceName
                friendlyName = $avdWorkspaceFriendlyName
                description  = $avdWorkspaceDescription
            }
            hostPool          = [PSCustomObject]@{
                name                = $avdHostpoolName
                friendlyName        = $avdHostPoolFriendlyName
                description         = $avdHostPoolDescription
                desktopAppGroupName = $avdDesktopAppGroupName
                type                = $avdHostPoolType
                isDesktop           = $isDesktop
                isSingleUser        = $isSingleUser
                assignmentType      = $avdAssignmentType
                timezoneId          = $timezoneId
            }
            properties        = [PSCustomObject]@{
                directory         = [PSCustomObject]@{
                    adProfileType      = $avdHostPoolADProfileType
                    adProfileName      = $avdHostPoolADProfileName
                    adIdentityType     = $avdHostPoolADIdentityType
                    adEnrollWithIntune = $avdHostPoolADEnrollWithIntune
                    adJoinDomainName   = $avdHostPoolADJoinDomainName
                    adJoinOrgUnit      = $avdHostPoolADJoinOrgUnit
                    adJoinUserName     = $avdHostPoolADJoinUserName
                    adJoinPassword     = $avdHostPoolADJoinPassword
                }
                avd               = [PSCustomObject]@{
                    loadBalancerType   = $avdHostPoolLoadBalancerType
                    maxSessionLimit    = $avdHostPoolMaxSessionLimit
                    validationEnv      = $avdHostPoolValidationEnv
                    startVMOnConnect   = $avdHostPoolStartVMOnConnect
                    powerOnPooledHosts = $avdHostPoolPowerOnPooledHosts
                    agentUpdate        = [PSCustomObject]@{
                        type                            = $avdAgentUpdateType
                        dayPrimary                      = $avdAgentUpdateDayPrimary
                        hourPrimary                     = $avdAgentUpdateHourPrimary
                        daySecondary                    = $avdAgentUpdateDaySecondary
                        hourSecondary                   = $avdAgentUpdateHourSecondary
                        useSessionHostLocalTime         = $avdAgentUpdateUseSessionHostLocalTime
                        powerOnHostsInMaintenanceWindow = $avdAgentUpdatePowerOnHostsInMaintenanceWindow
                        excludeDrainModeHosts           = $avdAgentUpdateExcludeDrainModeHosts

                    }
                }
                vmDeployment      = [PSCustomObject]@{
                    enableTimezoneRedirection      = $vmEnableTimezoneRedirection
                    isAcceleratedNetworkingEnabled = $vmIsAcceleratedNetworkingEnabled
                    rdpShortpath                   = $vmRdpShortpath
                    installGPUDrivers              = $vmInstallGPUDrivers
                    useAvailabilityZones           = $vmUseAvailabilityZones
                    enableVmDeallocation           = $vmEnableVmDeallocation
                    installCertificates            = $vmInstallCertificates
                    forceVMRestart                 = $vmForceVMRestart
                    alwaysPromptForPassword        = $vmAlwaysPromptForPassword
                    bootDiagEnabled                = $vmBootDiagEnabled
                    watermarking                   = $vmWatermarking
                    securityType                   = $vmSecurityType
                    secureBootEnabled              = $vmSecureBootEnabled
                    vTpmEnabled                    = $vmVTpmEnabled
                }
                fslogix           = [PSCustomObject]@{
                    isFslogixEnabled = $false
                }
                sessionTimeLimits = [PSCustomObject]@{
                    isSessionTimeoutsEnabled = $avdHostPoolSessionTimeoutsEnabled
                    maxDisconnectionTime     = $avdHostPoolSessionMaxDisconnectionTime
                    maxIdleTime              = $avdHostPoolSessionMaxIdleTime
                    #remoteAppLogoffTimeLimit        = $avdHostPoolSessionRemoteAppLogoffTimeLimit
                }
                rdpSettings       = [PSCustomObject]@{
                    PropertiesName = $rdpPropertiesAADSSOName
                    Properties     = @($rdpPropertiesAADSSO)
                }
            }
            autoScale         = [PSCustomObject]@{
                isAutoScaleEnabled     = $activateAutoScale
                hostNamePrefix         = $hostNamePrefix
                vnetName               = $hostVnetName
                vnetResourceGroupName  = $AVDVnetResourceGroup
                subnetName             = $hostSubnetName
                image                  = $hostImage
                hostSize               = $hostSize
                hostDiskSize           = $hostDiskSize
                hostHasEphemeralOSDisk = $hostHasEphemeralOSDisk
                hostStorageType        = $hostStorageType
                stoppedDiskType        = $hostStorageTypeStopped
                reuseVmNames           = $reuseVmNames
                vmNamingMode           = $vmNamingMode
                enableFixFailedTask    = $enableFixFailedTask
                properties             = [PSCustomObject]@{
                    maxSessionLimit  = $avdHostPoolMaxSessionLimit
                    loadBalancerType = $avdHostPoolLoadBalancerType
                }
                sizing                 = [PSCustomObject]@{
                    activeHostType         = $activeHostType
                    hostPoolCapacity       = $hostPoolCapacity
                    minActiveHostsCount    = $minActiveHostsCount
                    burstCapacity          = $burstCapacity
                    minCountCreatedVmsType = $minCountCreatedVmsType
                }
                logic                  = [PSCustomObject]@{
                    autoScaleCriteria     = $autoScaleCriteria
                    stopDelayMinutes      = $stopDelayMinutes
                    scalingMode           = $scalingMode
                    scaleInAggressiveness = $scaleInAggressiveness
                }
                messaging              = [PSCustomObject]@{
                    minutesBeforeRemove = $minutesBeforeRemove
                    message             = $message
                }

            }
            assignements      = [PSCustomObject]@{
                userPrincipalName = $userPrincipalName
            }
        }
        $null = $avdConfigs.Add($avdConfig)
    }

    # Export $avdConfigs to JSON file
    If ($exportAvdConfigFile) { $avdConfigs | ConvertTo-Json -Depth 5 | Out-File -FilePath $avdConfigFile }
}

# ------------------------------------------------------------------------------------------
function Set-BesAppServicePlan {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$AppServicePlanName,
        [Parameter(mandatory = $true)]
        [string]$Tier,
        [Parameter(mandatory = $true)]
        [string]$WorkerSize
    )

    $actSubscriptionId = (Get-AzContext).Subscription.Id

    $subSwitched = $false
    If ($actSubscriptionId -ne $SubscriptionId) {
        $context = Set-AzContext -SubscriptionId $SubscriptionId
        $subSwitched = $true
    }

    # Configure App Service Plan
    Set-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Tier $Tier -WorkerSize $WorkerSize

    If ($subSwitched) { $context = Set-AzContext -SubscriptionId $actSubscriptionId }
}
function Set-BesSqlDatabasePlan {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$ServerName,
        [Parameter(mandatory = $true)]
        [string]$DatabaseName,
        [Parameter(mandatory = $true)]
        [string]$Edition,
        [Parameter(mandatory = $true)]
        [string]$Sku
    )

    $actSubscriptionId = (Get-AzContext).Subscription.Id

    $subSwitched = $false
    If ($actSubscriptionId -ne $SubscriptionId) {
        $context = Set-AzContext -SubscriptionId $SubscriptionId
        $subSwitched = $true
    }

    # Configure SQL Database
    Set-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName -Edition $Edition -RequestedServiceObjectiveName $Sku

    If ($subSwitched) { $context = Set-AzContext -SubscriptionId $actSubscriptionId }
}

function Set-BesWorkspaceDailyQuota {
    param(
        [Parameter(mandatory = $true)]
        [array]$LogAnalyticWorkspaces
    )

    $initalSubscriptionId = (Get-AzContext).Subscription.Id

    $subSwitched = $false
    $logAnalyticWorkspaces | ForEach-Object {
        $actSubscriptionId = (Get-AzContext).Subscription.Id

        If ($actSubscriptionId -ne $_.SubscriptionId) {
            $context = Set-AzContext -SubscriptionId $_.SubscriptionId
            $subSwitched = $true
        }

        $parmWorkspaceDailyQuota = @{
            ResourceGroupName = $_.ResourceGroupName
            Name              = $_.Name
            DailyQuotaGb      = $_.DailyQuotaGb
        }

        Set-AzOperationalInsightsWorkspace @parmWorkspaceDailyQuota
    }

    If ($subSwitched) { $context = Set-AzContext -SubscriptionId $initalSubscriptionId }
}

function New-BesDeploymentManagedIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$UserManagedIdentityName,
        [Parameter(Mandatory = $true)]
        [string]$Location
    )
    $actSubscriptionId = (Get-AzContext).Subscription.Id

    $subSwitched = $false
    If ($actSubscriptionId -ne $SubscriptionId) {
        $context = Set-AzContext -SubscriptionId $SubscriptionId
        $subSwitched = $true
    }

    try {

        #Creating the user-assigned managed identity.
        Write-Output "Create user-assigned managed identity"
        $identity = New-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $UserManagedIdentityName -Location $Location

        $clientId = $identity.ClientId
        $objectId = $identity.PrincipalId
        $subscriptionId = (Get-AzContext).Subscription.Id

        # Create Output for export the information
        $Output = "{`"name`":`"$UserManagedIdentityName`", `"client_id`":`"$clientId`", `"object_id`":`"$objectId`", `"subscriptionid`":`"$subscriptionId`", `"resourcegroup`":`"$ResourceGroupName`"}"

    } catch {
        $ErrorActionPreference = 'Continue'
        Write-Output "Encountered error. $_"
        Write-Output "Rolling back changes"

        if ($identity) {
            Write-Output "Removing user-assigned managed identity $UserManagedIdentityName"
            Remove-AzUserAssignedIdentity -ResourceGroupName $NMEResourceGroupName -Name $UserManagedIdentityName -Force -ErrorAction Continue
        }
        Throw $_
    }

    Write-Output "User-assigned managed identity created successfully."
    Write-Output "User-assigned managed identity name: $UserManagedIdentityName"
    Write-Output "Resource Group: $ResourceGroupName"
    Write-Output "Subscription ID: $subscriptionId"
    Write-Output "Client ID: $clientId"
    Write-Output "Object ID: $objectId"

    Write-Output "Content of Secute Varaible 'DeployIdentity' = $Output"

    If ($subSwitched) { $context = Set-AzContext -SubscriptionId $actSubscriptionId }

    return $Output
}

function New-BesDeploymentStorage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [string]$SkuName,
        [Parameter(Mandatory = $true)]
        [string]$DeploymentContainerName,
        [Parameter(Mandatory = $true)]
        [string]$PrerequisiteName
    )

    ##### Script Logic #####
    $DeploymentContainerName = $DeploymentContainerName.ToLower()
    $PrerequisiteName = $DeploymentPrerequisiteName.ToLower()

    try {
        # Creating the storage account
        Write-Output "Create storage account"
        $storageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $Location -SkuName $SkuName -Kind StorageV2 -EnableHttpsTrafficOnly $true -AllowBlobPublicAccess $true -PublicNetworkAccess Enabled -ErrorAction Stop

        # Create a container for the deloyment scripts
        Write-Output "Create container for deployment scripts"
        $deploymentContainer = New-AzStorageContainer -Name $DeploymentContainerName -Permission Off -Context $storageAccount.Context -ErrorAction Stop

        # Create a container for the prerequisites
        Write-Output "Create container for prerequisites"
        $prerequisiteContainer = New-AzStorageContainer -Name $PrerequisiteName -Permission Blob -Context $storageAccount.Context -ErrorAction Stop

        # Create Output for export the information
        $Output = "{`"name`":`"$StorageAccountName`",`"resourceGroup`":`"$ResourceGroupName`",`"subscriptionid`":`"$SubscriptionId`",`"container`":`"$DeploymentContainerName`"}"
    } catch {
        $ErrorActionPreference = 'Continue'
        Write-Output "Encountered error. $_"
        Write-Output "Rolling back changes"

        if ($storageAccount) {
            Write-Output "Removing storage account $StorageAccountName"
            Remove-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Force
        }
        Throw $_
    }

    Write-Output "Storage Account created successfully."
    Write-Output "Storage Account Name: $StorageAccountName"
    Write-Output "Resource Group: $ResourceGroupName"
    Write-Output "Subscription ID: $SubscriptionId"
    Write-Output "Depoyment Container: $DeploymentContainerName"

    Write-Output "Content of Secute Varaible 'DeployStorageAccount' = $Output"
    return $Output
}

function Set-BesManagedIdentityToStorageAccount {
    param(
        [Parameter(mandatory = $true)]
        [string]$ManagedIdentityVariable,
        [Parameter(mandatory = $true)]
        [string]$StorageAccountVariable
    )

    Write-Output "Get secure variables"

    If ($ManagedIdentityVariable -like "{*}") {
        Write-Output "Convert ManagedIdentityVariable to JSON object"
        $ManagedIdentity = $ManagedIdentityVariable | ConvertFrom-Json
    } Else {
        Write-Output "Get Secure Variable for ManagedIdentityVariable and convert to JSON object"
        $ManagedIdentity = $SecureVars.$ManagedIdentityVariable | ConvertFrom-Json
    }

    If ([string]::IsNullOrEmpty($ManagedIdentity.name)) {
        Write-Output "ManagedIdentityVariable is not a valid JSON object"
        Exit
    } Else {
        Write-Output ("Managed Identity Name: " + $ManagedIdentity.name)
    }

    If ($StorageAccountVariable -like "{*}") {
        Write-Output "Convert StorageAccountVariable to JSON object"
        $StorageAccount = $StorageAccountVariable | ConvertFrom-Json
    } Else {
        Write-Output "Get Secure Variable for StorageAccountVariable and convert to JSON object"
        $StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json
    }

    If ([string]::IsNullOrEmpty($StorageAccount.name)) {
        Write-Output "StorageAccountVariable is not a valid JSON object"
        Exit
    } Else {
        Write-Output ("Storage Account Name : " + $StorageAccount.name | Out-String)
    }

    ##### Script Logic #####
    try {
        #Assign the user-assigned managed identity.
        $actContext = Get-AzContext
        If ($actContext.Subscription.Id -ne $ManagedIdentity.subscriptionid) {
            Set-AzContext -SubscriptionId $ManagedIdentity.subscriptionid
        }
        $objIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $ManagedIdentity.ResourceGroup -Name $ManagedIdentity.Name

        $actContext = Get-AzContext
        If ($actContext.Subscription.Id -ne $StorageAccount.subscriptionid) {
            Set-AzContext -SubscriptionId $StorageAccount.subscriptionid
        }
        $objStorageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccount.ResourceGroup -Name $StorageAccount.Name

        # $objIdentity.ObjectId does not work, use $objIdentity.PrincipalId
        Write-Output ("Assign user-assigned managed identity " + $objIdentity.Name + " to storage account " + $objStorageAccount.StorageAccountName)
        New-AzRoleAssignment -ObjectId $objIdentity.PrincipalId -Scope $objStorageAccount.Id -RoleDefinitionName  "Storage Account Contributor"

    } catch {
        $ErrorActionPreference = 'Continue'
        Write-Output "Encountered error. $_"
        Throw $_
    }
}

function New-BesSecureVariable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $NmeCreateOrUpdateSecureVariable = New-NmeCreateOrUpdateSecureVariableRestPayload -Name $Name -Value $Value -AssignmentRequired $false -ShellAppAccessible $false
    New-NmeSecureVariable -NmeCreateOrUpdateSecureVariableRestPayload $NmeCreateOrUpdateSecureVariable

}

function Convert-BesPSCustomObjectToHashTable {
    <#
    .SYNOPSIS
    Converts a PSCustomObject to a hashtable
    .DESCRIPTION
    Converts a PSCustomObject to a hashtable
    .EXAMPLE
    Convert-BesPSCustomObjectToHashTable -CustomObject $values
    .EXAMPLE
    Convert-BesPSCustomObjectToHashTable -CustomObject $values -Order $valuesOrder
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$CustomObject,
        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary]$Order
    )

    $hashtable = [ordered]@{}
    If ($null -ne $Order) {
        foreach ($Key in $Order.Keys.GetEnumerator()) {
            $hashtable.($Order[$Key]) = $CustomObject.($Key)
        }
    } Else {
        foreach ($Key in ($CustomObject | Get-Member -MemberType *Property)) {
            $hashtable.($Key.Name) = $CustomObject.($Key.Name)
        }
    }

    return $hashtable
}
$funcConvertBesPSCustomObjectToHashTable = ${function:Convert-BesPSCustomObjectToHashTable}.ToString()

Function Get-BesDayOfWeek {
    param(
        [Parameter(mandatory = $true)]
        [string]$DayOfWeek
    )

    Switch ($DayOfWeek) {
        'Sunday' { 0 }
        'Monday' { 1 }
        'Tuesday' { 2 }
        'Wednesday' { 3 }
        'Thursday' { 4 }
        'Friday' { 5 }
        'Saturday' { 6 }
    }
}
$funcGetBesDayOfWeek = ${function:Get-BesDayOfWeek}.ToString()

function Connect-NmeApi {
    param(
        [Parameter(mandatory = $true)]
        [string]$ClientId,
        [Parameter(mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(mandatory = $true)]
        [string]$TenantId,
        [Parameter(mandatory = $true)]
        [string]$ApiScope,
        [Parameter(mandatory = $true)]
        [string]$NmeUri
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")

    $encoded_scope = [System.Web.HTTPUtility]::UrlEncode("$ApiScope")
    $body = "grant_type=client_credentials&client_id=$ClientId&scope=$encoded_scope&client_secret=$ClientSecret"
    $TokenResponse = Invoke-RestMethod "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Headers $headers -Body $body
    $token = $TokenResponse.access_token

    $headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Accept", "application/json")
    $headers.Add("Content-Type", "application/json")

    return $headers
}
$funcConnectNmeApi = ${function:Connect-NmeApi}.ToString()

function New-BesResourceGroup {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$Location,
        [Parameter(mandatory = $true)]
        [string]$NMESPName,
        [Parameter(mandatory = $true)]
        [string]$NmeUri,
        [Parameter(mandatory = $true)]
        [hashtable]$Headers,
        [Parameter(mandatory = $false)]
        [hashtable]$Tags = @{}
    )

    $actSubscription = (Get-AzContext).SubscriptionId

    If ($actSubscription -ne $SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId
    }

    # Create Resource Group
    If (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $Tags
    }

    # Assign Owner Role to NME SP
    $spId = (Get-AzADServicePrincipal -DisplayName $NMESPName).id
    $null = New-AzRoleAssignment -ObjectId $spId `
        -RoleDefinitionName 'Owner' `
        -ResourceGroupName $ResourceGroupName

    # Link Resource Group in NME
    $NewResourceGroupParams = @{
        isDefault = $false
    }

    $body = $null
    $body = $NewResourceGroupParams | ConvertTo-Json
    Invoke-RestMethod "$NmeUri/api/v1/resourcegroup/$SubscriptionId/$ResourceGroupName/linked" -Headers $headers -Body $body -Method Post -UseBasicParsing

}
$funcNewBesResourceGroup = ${function:New-BesResourceGroup}.ToString()

function New-BesNmeWorkspace {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$Location,
        [Parameter(mandatory = $true)]
        [string]$WorkspaceName,
        [Parameter(mandatory = $true)]
        [string]$FriendlyName,
        [Parameter(mandatory = $false)]
        [string]$Description
    )

    $objectId = New-NmeWvdObjectId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -Name $WorkspaceName

    $parmWorkspaceRequest = @{
        Id       = $objectId
        Location = $Location
    }

    If ($FriendlyName) { $parmWorkspaceRequest.Add("FriendlyName", $FriendlyName) }
    If ($Description) { $parmWorkspaceRequest.Add("Description", $Description) }

    $workspaceRequest = New-NmeCreateWorkspaceRequest @parmWorkspaceRequest

    New-NmeWorkspace -NmeCreateWorkspaceRequest $workspaceRequest
}
$funcNewBesNmeWorkspace = ${function:New-BesNmeWorkspace}.ToString()

function New-BesNmeHostPool {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$WorkspaceName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $false)]
        [bool]$IsDesktop,
        [Parameter(mandatory = $false)]
        [bool]$IsSingleUser,
        [Parameter(mandatory = $True)]
        [string]$HostPoolType,
        [Parameter(mandatory = $false)]
        [string]$AssignmentType
    )

    $objectid = New-NmeWvdObjectId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -Name $WorkspaceName

    Switch ($HostPoolType) {
        'Pooled' {
            $pooledParams = New-NmePooledParams -IsDesktop $IsDesktop -IsSingleUser $IsSingleUser
            $hostPoolRequest = New-NmeCreateArmHostPoolRequest -WorkspaceId $objectid -PooledParams $pooledParams
        }
        'Personal' {
            $personalParams = New-NmePersonalParams -AssignmentType $AssignmentType
            $hostPoolRequest = New-NmeCreateArmHostPoolRequest -WorkspaceId $objectid -PersonalParams $personalParams
        }
    }

    New-NmeHostPool -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -HostPoolName $HostPoolName -NmeCreateArmHostPoolRequest $hostPoolRequest

    Start-Sleep -Seconds 30

    #Converts Hostpool to Dynamic Hostpool
    ConvertTo-NmeDynamicHostPool -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -HostPoolName $HostPoolName
}
$funcNewBesNmeHostPool = ${function:New-BesNmeHostPool}.ToString()

function Set-BesNmeHostPoolCustomTags {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [hashtable]$Tags
    )

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    $NmeUpdateHostPoolTags = New-NmeUpdateHostPoolTagsRest -Tags $Tags -UpdateObjects $True
    Set-NmeHostPoolCustomTags @paramHostPool @NmeUpdateHostPoolTags
}
$funcSetBesNmeHostPoolCustomTags = ${function:Set-BesNmeHostPoolCustomTags}.ToString()

function Set-BesNmeHostPoolAVDConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [string]$FriendlyName,
        [Parameter(mandatory = $true)]
        [string]$Description,
        [Parameter(mandatory = $false)]
        [ValidateSet("BreadthFirst", "DepthFirst", "Persistent")]
        [string]$LoadBalancerType = "BreadthFirst",
        [Parameter(mandatory = $false)]
        [int]$MaxSessionLimit = 15,
        [Parameter(mandatory = $false)]
        [string]$AgentUpdateDayPrimary,
        [Parameter(mandatory = $false)]
        [int]$AgentUpdateHourPrimary,
        [Parameter(mandatory = $false)]
        [string]$AgentUpdateDaySecondary,
        [Parameter(mandatory = $false)]
        [int]$AgentUpdateHourSecondary,
        [Parameter(mandatory = $false)]
        [bool]$ValidationEnv = $false,
        [Parameter(mandatory = $false)]
        [bool]$StartVMOnConnect = $false,
        [Parameter(mandatory = $false)]
        [bool]$PowerOnPooledHosts = $false,
        [Parameter(mandatory = $false)]
        [ValidateSet("Default", "Scheduled")]
        [string]$AgentUpdateType = "Default",
        [Parameter(mandatory = $true)]
        [string]$TimezoneId,
        [Parameter(mandatory = $false)]
        [bool]$UseSessionHostLocalTime = $false,
        [Parameter(mandatory = $false)]
        [bool]$PowerOnHostsInMaintenanceWindow = $true,
        [Parameter(mandatory = $false)]
        [bool]$ExcludeDrainModeHosts = $true
    )

    If ($AgentUpdateType.ToLower() -eq "scheduled") {
        $primaryMaintenanceWindow = New-NmeAvdAgentMaintenanceWindowRestModel -DayOfWeek (Get-BesDayOfWeek $AgentUpdateDayPrimary) -Hour $AgentUpdateHourPrimary

        If ($AgentUpdateDaySecondary -and $AgentUpdateSecondary) {
            $secondaryMaintenanceWindow = New-NmeAvdAgentMaintenanceWindowRestModel -DayOfWeek (Get-BesDayOfWeek $AgentUpdateDaySecondary) -Hour $AgentUpdateHourSecondary
        }

        $paramAgentUpdate = @{
            Type                            = $AgentUpdateType
            MaintenanceWindowTimeZone       = $TimezoneId
            PrimaryWindow                   = $primaryMaintenanceWindow
            UseSessionHostLocalTime         = $UseSessionHostLocalTime
            PowerOnHostsInMaintenanceWindow = $PowerOnHostsInMaintenanceWindow
            ExcludeDrainModeHosts           = $ExcludeDrainModeHosts
        }

        If ($AgentUpdateDaySecondary -and $AgentUpdateSecondary) { $paramAgentUpdate.Add("SecondaryWindow", $secondaryMaintenanceWindow) }

        $agentUpdate = New-NmeAvdAgentUpdateRestModel @paramAgentUpdate
    }

    $paramHostPoolProperties = @{
        LoadBalancerType   = $LoadBalancerType
        MaxSessionLimit    = $MaxSessionLimit
        ValidationEnv      = $ValidationEnv
        StartVMOnConnect   = $StartVMOnConnect
        PowerOnPooledHosts = $PowerOnPooledHosts
    }

    If ($agentUpdate) { $paramHostPoolProperties.Add("AgentUpdate", $agentUpdate) }
    If ($FriendlyName) { $paramHostPoolProperties.Add("FriendlyName", $FriendlyName) }
    If ($Description) { $paramHostPoolProperties.Add("Description", $Description) }


    $NmeArmHostPoolProperties = New-NmeArmHostPoolPropertiesRestModel @paramHostPoolProperties

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    Set-NmeHostPoolAVDConfig @paramHostPool -NmeArmHostPoolPropertiesRestModel $NmeArmHostPoolProperties
}
$funcSetBesNmeHostPoolAVDConfig = ${function:Set-BesNmeHostPoolAVDConfig}.ToString()

function New-BesNmeHostPoolADConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [ValidateSet("Default", "Predefined", "Custom")]
        [string]$ProfileType = 'Default',
        [Parameter(mandatory = $false)]
        [string]$ProfileName,
        [Parameter(mandatory = $false)]
        [ValidateSet($null, "AD", "AzureAD", "AzureADDS")]
        [string]$IdentityType,
        [Parameter(mandatory = $false)]
        [bool]$EnrollWithIntune,
        [Parameter(mandatory = $false)]
        [string]$JoinDomainName,
        [Parameter(mandatory = $false)]
        [string]$JoinOrgUnit,
        [Parameter(mandatory = $false)]
        [string]$JoinUserName,
        [Parameter(mandatory = $false)]
        [string]$JoinPassword
    )

    Switch ($ProfileType) {
        "Default" {
            $adConfig = @{
                Type = $ProfileType
            }
        }
        "Predefined" {
            $PredefinedConfigId = Get-NmeAdConfig | Where-Object { $_.FriendlyName -eq $ProfileName } | Select-Object -ExpandProperty Id
            $adConfig = @{
                Type               = $ProfileType
                PredefinedConfigId = $PredefinedConfigId
            }
        }
        "Custom" {

            Switch ($IdentityType) {
                "AzureAD" {
                    $adCustom = @{
                        AdIdentityType = $IdentityType
                    }
                    If ($ProfileName) { $adCustom.Add("FriendlyName", $ProfileName) }
                    If ($EnrollWithIntune) { $adCustom.Add("EnrollWithIntune", $EnrollWithIntune) }

                    $Custom = New-NmeAdConfigRestPropertiesWithPassword @adCustom
                    $adConfig = @{
                        Type   = $ProfileType
                        Custom = $Custom
                    }
                }
                "AD" {
                    $adCustom = @{
                        AdIdentityType = $IdentityType
                        JoinDomainName = $JoinDomainName
                        JoinOrgUnit    = $JoinOrgUnit
                        JoinUserName   = $JoinUserName
                        JoinPassword   = $JoinPassword
                    }
                    If ($ProfileName) { $adCustom.Add("FriendlyName", $ProfileName) }

                    $Custom = New-NmeAdConfigRestPropertiesWithPassword @adCustom
                    $adConfig = @{
                        Type   = $ProfileType
                        Custom = $Custom
                    }
                }

                "AzureADDS" {
                    $adCustom = @{
                        AdIdentityType = $IdentityType
                        JoinDomainName = $JoinDomainName
                        JoinOrgUnit    = $JoinOrgUnit
                        JoinUserName   = $JoinUserName
                        JoinPassword   = $JoinPassword
                    }
                    If ($ProfileName) { $adCustom.Add("FriendlyName", $ProfileName) }

                    $Custom = New-NmeAdConfigRestPropertiesWithPassword @adCustom
                    $adConfig = @{
                        Type   = $ProfileType
                        Custom = $Custom
                    }
                }
            }
        }
    }

    $adConfig

    $NmeUpdateHostPoolActiveDirectory = New-NmeUpdateHostPoolActiveDirectoryRestModel @adConfig
    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    Set-NmeHostPoolADConfig @paramHostPool -NmeUpdateHostPoolActiveDirectoryRestModel $NmeUpdateHostPoolActiveDirectory
}
$funcNewBesNmeHostPoolADConfig = ${function:New-BesNmeHostPoolADConfig}.ToString()

function Update-BesNmeVmDeploymentConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $false)]
        [string]$VmTimezone,
        [Parameter(mandatory = $false)]
        [bool]$EnableTimezoneRedirection = $true,
        [Parameter(mandatory = $false)]
        [bool]$IsAcceleratedNetworkingEnabled = $true,
        [Parameter(mandatory = $false)]
        [ValidateSet("DoNothing", "ForceEnable", "ForceDisable")]
        [string]$RdpShortpath = "DoNothing",
        [Parameter(mandatory = $false)]
        [bool]$InstallGPUDrivers = $true,
        [Parameter(mandatory = $false)]
        [bool]$UseAvailabilityZones = $true,
        [Parameter(mandatory = $false)]
        [bool]$EnableVmDeallocation = $true,
        [Parameter(mandatory = $false)]
        [bool]$InstallCertificates = $false,
        [Parameter(mandatory = $false)]
        [bool]$ForceVMRestart = $false,
        [Parameter(mandatory = $false)]
        [bool]$AlwaysPromptForPassword = $false,
        [Parameter(mandatory = $false)]
        [bool]$BootDiagEnabled = $true,
        [Parameter(mandatory = $false)]
        [bool]$Watermarking = $false,
        [Parameter(mandatory = $false)]
        [int]$WatermarkingScale = 4,
        [Parameter(mandatory = $false)]
        [int]$WatermarkingOpacity = 7,
        [Parameter(mandatory = $false)]
        [int]$WatermarkingWidthFactor = 35,
        [Parameter(mandatory = $false)]
        [int]$WatermarkingHeightFactor = 20,
        [Parameter(mandatory = $false)]
        [ValidateSet("None", "TrustedLaunch", "Confidential")]
        [string]$SecurityType = 'TrustedLaunch',
        [Parameter(mandatory = $false)]
        [bool]$SecureBootEnabled = $true,
        [Parameter(mandatory = $false)]
        [bool]$VTpmEnabled = $true
    )

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    $paramVmDeploymentConfig = Get-NmeVmDeploymentConfig @paramHostPool
    If ($VmTimezone) { $paramVmDeploymentConfig.VmTimezone = $VmTimezone }
    If ($EnableTimezoneRedirection) { $paramVmDeploymentConfig.EnableTimezoneRedirection = $EnableTimezoneRedirection }
    If ($IsAcceleratedNetworkingEnabled) { $paramVmDeploymentConfig.IsAcceleratedNetworkingEnabled = $IsAcceleratedNetworkingEnabled }
    If ($RdpShortpath) { $paramVmDeploymentConfig.RdpShortpath = $RdpShortpath }
    If ($InstallGPUDrivers) { $paramVmDeploymentConfig.InstallGPUDrivers = $InstallGPUDrivers }
    If ($UseAvailabilityZones) { $paramVmDeploymentConfig.UseAvailabilityZones = $UseAvailabilityZones }
    If ($EnableVmDeallocation) { $paramVmDeploymentConfig.EnableVmDeallocation = $EnableVmDeallocation }
    If ($InstallCertificates) { $paramVmDeploymentConfig.InstallCertificates = $InstallCertificates }
    If ($ForceVMRestart) { $paramVmDeploymentConfig.ForceVMRestart = $ForceVMRestart }
    If ($AlwaysPromptForPassword) { $paramVmDeploymentConfig.AlwaysPromptForPassword = $AlwaysPromptForPassword }
    If ($BootDiagEnabled) { $paramVmDeploymentConfig.BootDiagEnabled = $BootDiagEnabled }

    If ($SecurityType) { $paramVmDeploymentConfig.SecurityType = $SecurityType }
    If ($SecureBootEnabled) { $paramVmDeploymentConfig.SecureBootEnabled = $SecureBootEnabled }
    If ($VTpmEnabled) { $paramVmDeploymentConfig.VTpmEnabled = $VTpmEnabled }

    If ($Watermarking) {
        $paramVmDeploymentConfig.Watermarking.Enabled = $Watermarking
        $paramVmDeploymentConfig.Watermarking.scale = $WatermarkingScale
        $paramVmDeploymentConfig.Watermarking.opacity = $WatermarkingOpacity
        $paramVmDeploymentConfig.Watermarking.widthFactor = $WatermarkingWidthFactor
        $paramVmDeploymentConfig.Watermarking.heightFactor = $WatermarkingHeightFactor
    }

    Update-NmeVmDeploymentConfig  @paramHostPool @paramVmDeploymentConfig

}
$funcUpdateBesNmeVmDeploymentConfig = ${function:Update-BesNmeVmDeploymentConfig}.ToString()

function Set-BesNmeHostPoolAutoScaleConfig {
    param (
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolType,
        [Parameter(mandatory = $true)]
        [string]$Prefix,
        [Parameter(mandatory = $true)]
        [string]$Size,
        [Parameter(mandatory = $true)]
        [string]$Image,
        [Parameter(mandatory = $true)]
        [string]$StorageType,
        [Parameter(mandatory = $true)]
        [string]$VnetResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$VnetName,
        [Parameter(mandatory = $true)]
        [string]$SubnetName,
        [Parameter(mandatory = $true)]
        [int]$DiskSize,
        [Parameter(mandatory = $true)]
        [bool]$HasEphemeralOSDisk,
        [Parameter(mandatory = $false)]
        [int]$MinutesBeforeRemove = 10,
        [Parameter(mandatory = $true)]
        [string]$Message,
        [Parameter(mandatory = $false)]
        [int]$StopDelayMinutes = 10,
        [Parameter(mandatory = $true)]
        [string]$TimezoneId,
        [Parameter(mandatory = $true)]
        [int]$HostPoolCapacity,
        [Parameter(mandatory = $true)]
        [int]$MinActiveHostsCount,
        [Parameter(mandatory = $true)]
        [int]$BurstCapacity,
        [Parameter(mandatory = $true)]
        [bool]$IsAutoScaleEnabled,
        [Parameter(mandatory = $true)]
        [bool]$IsSingleUser,
        [Parameter(mandatory = $true)]
        [ValidateSet("Running", "AvailableForConnection")]
        [string]$ActiveHostType,
        [Parameter(mandatory = $true)]
        [ValidateSet("HostPoolCapacity", "MinActiveHostsProperty")]
        [string]$MinCountCreatedVmsType,
        [Parameter(mandatory = $true)]
        [ValidateSet("Default", "WorkingHours", "UserDriven")]
        [string]$ScalingMode,
        [Parameter(mandatory = $true)]
        [ValidateSet("CPUUsage", "RAMUsage", "AvgActiveSessions", "AvailableUserSessionSingle", "AvailableUserSessions", "UserDriven", "PersonalAutoGrow", "PersonalAutoShrink")]
        [string]$AutoScaleCriteria,
        [Parameter(mandatory = $true)]
        [ValidateSet("High", "Medium", "Low")]
        [string]$ScaleInAggressiveness,
        [Parameter(mandatory = $true)]
        [bool]$EnableFixFailedTask,
        [Parameter(mandatory = $true)]
        [bool]$ReuseVmNames,
        [Parameter(mandatory = $true)]
        [ValidateSet("Standard", "Reuse", "Unique")]
        [string]$VmNamingMode,
        [Parameter(mandatory = $false)]
        [ValidateSet("Standard_LRS", "StandardSSD_LRS", "Premium_LRS")]
        [string]$StoppedDiskType,
        [Parameter(mandatory = $false)]
        [bool]$PreStateHostsConfiguration = $false,
        [Parameter(mandatory = $false)]
        [bool]$ScaleIntimeRestrictionConfiguration = $false,
        [Parameter(mandatory = $false)]
        [bool]$AutoHealConfiguration = $false,
        [Parameter(mandatory = $false)]
        [hashtable]$AutoGrow = @{},
        [Parameter(mandatory = $false)]
        [hashtable]$AutoShrink = @{}
    )

    $resourceGroupId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
    $networkId = "/subscriptions/$SubscriptionId/resourceGroups/$VnetResourceGroupName/providers/Microsoft.Network/virtualNetworks/$VnetName"

    # Create VM Template Configuration
    $paramVMTemplate = @{
        Prefix             = $Prefix
        Size               = $Size
        Image              = $Image
        StorageType        = $StorageType
        ResourceGroupId    = $resourceGroupId
        NetworkId          = $networkId
        Subnet             = $SubnetName
        DiskSize           = $DiskSize
        HasEphemeralOSDisk = $HasEphemeralOSDisk
    }
    $vmtemplate = New-NmeVmTemplateParams @paramVMTemplate

    If ($PreStateHostsConfiguration) { throw "Not supported at the moment" } Else { $preStage = New-NmePreStateHostsConfiguration -Enable $PreStateHostsConfiguration }
    If ($ScaleIntimeRestrictionConfiguration) { throw "Not supported at the moment" } Else { $scaleinreestriction = New-NmeScaleIntimeRestrictionConfiguration -Enable $ScaleIntimeRestrictionConfiguration }
    If ($AutoHealConfiguration) { throw "Not supported at the moment" } Else { $autoheal = New-NmeAutoHealConfiguration -Enable $AutoHealConfiguration }

    $userDriven = New-NmeUserDrivenRestConfiguration -StopDelayMinutes $StopDelayMinutes
    $removemessaging = New-NmeWarningMessageSettings -MinutesBeforeRemove $MinutesBeforeRemove -Message $Message

    If ($HostPoolType.ToLower() -eq 'personal') {
        $triggerInfo = @()
        $triggerInfo += New-NmeTriggerInfo -TriggerType 'UserDriven' -UserDriven $userDriven

        If ($AutoGrow.Count -gt 0) {
            $personalAutoGrow = New-NmePersonalAutoGrowRestConfiguration @AutoGrow # Unit 0 = % of total desktops, 1 = number of desktops
            $triggerInfo += New-NmeTriggerInfo -TriggerType 'PersonalAutoGrow' -PersonalAutoGrow $personalAutoGrow
        }

        If ($AutoShrink.Count -gt 0) {
            $personalAutoShrink = New-NmePersonalAutoShrinkRestConfiguration @AutoShrink
            #$triggerInfo += New-NmeTriggerInfo -TriggerType 'PersonalAutoShrink' -PersonalAutoShrink $personalAutoShrink
        }
    }

    $paramConfigs = @{
        PreStageHosts      = $preStage
        ScaleInRestriction = $scaleinreestriction
        AutoHeal           = $autoheal
        UserDriven         = $userDriven
        RemoveMessaging    = $removemessaging
    }

    $paramAutoScaling = @{
        IsEnabled              = $IsAutoScaleEnabled
        TimezoneId             = $TimezoneId
        VmTemplate             = $vmtemplate
        ReuseVmNames           = $ReuseVmNames
        EnableFixFailedTask    = $EnableFixFailedTask
        IsSingleUserDesktop    = $IsSingleUser
        ActiveHostType         = $ActiveHostType
        MinCountCreatedVmsType = $MinCountCreatedVmsType
        ScalingMode            = $ScalingMode
        HostPoolCapacity       = $HostPoolCapacity
        MinActiveHostsCount    = $MinActiveHostsCount
        BurstCapacity          = $BurstCapacity
        AutoScaleCriteria      = $AutoScaleCriteria
        ScaleInAggressiveness  = $ScaleInAggressiveness
        VmNamingMode           = $VmNamingMode
    }

    If ($StoppedDiskType) { $paramAutoScaling.Add("StoppedDiskType", $StoppedDiskType) }
    If ($triggerInfo) { $paramAutoScaling.Add("AutoScaleTriggers", $triggerInfo) }

    $autoScaleConfig = New-NmeDynamicPoolConfiguration @paramConfigs @paramAutoScaling

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    If ($triggerInfo) { $paramHostPool.Add("MultiTriggers", $true) }

    Set-NmeHostPoolAutoScaleConfig @paramHostPool -NmeDynamicPoolConfiguration $autoScaleConfig
}
$funcSetBesNmeHostPoolAutoScaleConfig = ${function:Set-BesNmeHostPoolAutoScaleConfig}.ToString()

Function Set-BesNmeHostPoolSessionTimeoutConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [bool]$Enable,
        [Parameter(
            mandatory = $false,
            HelpMessage = "Log off DISCONNECTED sessions after. -1 = disabled, 0 = never"
        )]
        [ValidateSet(-1, 0, 1, 5, 10, 15, 30, 60, 120, 180, 360, 480, 720, 960, 1080, 1440, 2880, 4320, 5760, 7200)]
        [int]$MaxDisconnectionTime = 240,
        [Parameter(
            mandatory = $false,
            HelpMessage = "Disconnect IDLE sessions after. -1 = disabled, 0 = never"
        )]
        [ValidateSet(-1, 0, 1, 5, 10, 15, 30, 60, 120, 180, 360, 480, 720, 960, 1080, 1440, 2880, 4320, 5760, 7200)]
        [int]$MaxIdleTime = 120, # -1 = disabled, 0 = never
        [Parameter(
            mandatory = $false,
            HelpMessage = "Disconnect ACTIVE sessions after. -1 = disabled, 0 = never"
        )]
        [ValidateSet(-1, 0, 1, 5, 10, 15, 30, 60, 120, 180, 360, 480, 720, 960, 1080, 1440, 2880, 4320, 5760, 7200)]
        [int]$MaxConnectionTime,
        [Parameter(
            mandatory = $false,
            HelpMessage = "Log off empty RemoteApp sessions after. -1 = disabled, 0 = never"
        )]
        [ValidateSet(-1, 0, 1, 5, 10, 15, 30, 60, 120, 180, 360, 480, 720, 960, 1080, 1440, 2880, 4320, 5760, 7200)]
        [int]$RemoteAppLogoffTimeLimit,
        [Parameter(
            mandatory = $false,
            HelpMessage = "Log off, instead of disconnecting, ACTIVE and IDLE sessions. -1 = disabled, 1 = enabled"
        )]
        [ValidateSet(-1, 1)]
        [int]$FresetBroken
    )

    $paramSessionTimeout = @{
        IsSessionTimeoutsEnabled = $Enable
    }

    If ($MaxDisconnectionTime) { $paramSessionTimeout.Add("MaxDisconnectionTime", $MaxDisconnectionTime) }
    If ($MaxIdleTime) { $paramSessionTimeout.Add("MaxIdleTime", $MaxIdleTime) }
    If ($MaxConnectionTime) { $paramSessionTimeout.Add("MaxConnectionTime", $MaxConnectionTime) }
    If ($RemoteAppLogoffTimeLimit) { $paramSessionTimeout.Add("RemoteAppLogoffTimeLimit", $RemoteAppLogoffTimeLimit) }
    If ($FresetBroken) { $paramSessionTimeout.Add("FresetBroken", $FresetBroken) }

    If ($RemoteAppLogoffTimeLimit) { $paramSessionTimeout.Add("RemoteAppLogoffTimeLimit", $RemoteAppLogoffTimeLimit) }

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    $sessionTimeouts = New-NmeHostPoolSessionTimeoutRestModel @paramSessionTimeout
    Set-NmeHostPoolSessionTimeoutConfig @paramHostPool -NmeHostPoolSessionTimeoutRestModel $sessionTimeouts

}
$funcSetBesNmeHostPoolSessionTimeoutConfig = ${function:Set-BesNmeHostPoolSessionTimeoutConfig}.ToString()

function Set-BesNmeHostPoolFslConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [bool]$Enable
    )

    $fslogix = New-NmeUpdateHostPoolFsLogixRestModel -Enable $Enable
    Set-NmeHostPoolFslConfig -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -HostPoolName $HostPoolName -NmeUpdateHostPoolFsLogixRestModel $fslogix
}
$funcSetBesNmeHostPoolFslConfig = ${function:Set-BesNmeHostPoolFslConfig}.ToString()

function Set-BesNmeHostPoolRDPConfig {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $false)]
        [string]$ConfigurationName = "Default",
        [Parameter(mandatory = $false)]
        [System.Object]$RDPProperties
    )

    $paramHostPool = @{
        SubscriptionId = $SubscriptionId
        ResourceGroup  = $ResourceGroupName
        HostPoolName   = $HostPoolName
    }

    $paramRdpConfig = @{}
    If ($ConfigurationName) { $paramRdpConfig.Add("ConfigurationName", $ConfigurationName) }
    If ($RDPProperties) {
        $rdpPropertiesString = $RDPProperties -join ';'
        $paramRdpConfig.Add("RdpProperties", $rdpPropertiesString)
    }

    $NmeUpdateHostPoolRdpWithConfig = New-NmeUpdateHostPoolRdpWithConfigRequest @paramRdpConfig

    Set-NmeHostPoolRdpConfig @paramHostPool -NmeUpdateHostPoolRdpWithConfigRequest $NmeUpdateHostPoolRdpWithConfig
}
$funcSetBesNmeHostPoolRDPConfig = ${function:Set-BesNmeHostPoolRDPConfig}.ToString()

function New-BesNmeHostPoolUserAssignment {
    param(
        [Parameter(mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [string]$UserPrincipalName
    )

    $Assignmentrequest = New-NmeArmHostPoolAssignmentRequest -Users $UserPrincipalName
    New-NmeHostPoolUserAssignment -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroupName -HostPoolName $HostPoolName -NmeArmHostPoolAssignmentRequest $Assignmentrequest
}
$funcNewBesNmeHostPoolUserAssignment = ${function:New-BesNmeHostPoolUserAssignment}.ToString()

# ------------------------------------------------------------------------------------------
# Check if the PowerShell module is installed

# Check if the Azure PowerShell module is installed
If (-not (Get-Module -Name Az -ListAvailable)) {
    throw "Azure PowerShell module is not installed. Please install the module before running the script"
}

# Check if the Nerdio Manager PowerShell module is installed
If (-not (Get-Module -Name NerdioManagerPowerShell -ListAvailable)) {
    throw "Nerdio Manager PowerShell module is not installed. Please install the module before running the script"
}

# ------------------------------------------------------------------------------------------
# Login to Azure

$context = Get-AzContext

If ($context.Tenant.Id -ne $NMETenantId) {
    # Use Device Authentication to login to Azure
    $null = Disable-AzContextAutosave -Scope Process
    $context = Connect-AzAccount -Environment $AzureCloud -UseDeviceAuthentication -TenantId $NMETenantId
}

# Check if the login was successful
If (-not $context) {
    throw "Failed to login to Azure"
}

# ------------------------------------------------------------------------------------------
If ($linkSubscription) {

    If (-not (Get-AzResourceProvider -ProviderNamespace 'Microsoft.DesktopVirtualization' -ErrorAction SilentlyContinue)) {
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.DesktopVirtualization'
    }

    If (-not (Get-AzResourceProvider -ProviderNamespace 'Microsoft.Compute' -ErrorAction SilentlyContinue)) {
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.Compute'
    }

    If (-not (Get-AzResourceProvider -ProviderNamespace 'Microsoft.Storage' -ErrorAction SilentlyContinue)) {
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.Storage'
    }

    If (-not (Get-AzResourceProvider -ProviderNamespace 'Microsoft.RecoveryServices' -ErrorAction SilentlyContinue)) {
        Register-AzResourceProvider -ProviderNamespace 'Microsoft.RecoveryServices'
    }

    # Assign the required role to the Azure Virtual Desktop service principal
    $parameters = @{
        RoleDefinitionName = "Desktop Virtualization Power On Off Contributor"
        ApplicationId      = "9cdead84-a844-4324-93f2-b2e6bb768d07"
        Scope              = "/subscriptions/$AVDSubscriptionId"
    }

    New-AzRoleAssignment @parameters

    # Assign Contributor role to the Nerdio Manager service principal
    $parameters = @{
        RoleDefinitionName = "Contributor"
        ApplicationId      = $NMEClientId
        Scope              = "/subscriptions/$AVDSubscriptionId"
    }

    New-AzRoleAssignment @parameters

    # Assign Backup Contributor role to the Nerdio Manager service principal on NME subscription
    $parameters = @{
        RoleDefinitionName = "Backup Contributor"
        ApplicationId      = $NMEClientId
        Scope              = "/subscriptions/$NMESubscriptionId"
    }
    New-AzRoleAssignment @parameters

    # Assign Backup Contributor role to the Nerdio Manager service principal on AVD subscription
    $parameters = @{
        RoleDefinitionName = "Backup Contributor"
        ApplicationId      = $NMEClientId
        Scope              = "/subscriptions/$AVDSubscriptionId"
    }
    New-AzRoleAssignment @parameters

    Start-Sleep -Seconds 60
}

# ------------------------------------------------------------------------------------------
# Paramters for Azure App Service Login to get the Access Token

$ConnectArguments = @{
    TenantId     = $NmeTenantId
    ClientId     = $NmeClientId
    ClientSecret = $NmeClientSecret
    ApiScope     = $NmeScope
    NmeUri       = $NmeUri
}

# Connect to NME
Connect-Nme @ConnectArguments
$headers = Connect-NmeApi @ConnectArguments

# ------------------------------------------------------------------------------------------
# Configure NME App Service Plan
If ($updateAppServicePlan) {
    $paramAppServicePlan = @{
        SubscriptionId     = $NMESubscriptionId
        ResourceGroupName  = $NMEResourceGroupName
        AppServicePlanName = $NMEAppServicePlanName
        Tier               = $NMEAppServicePlanTier
        WorkerSize         = $NMEAppServicePlanWorkerSize
    }

    Set-BesAppServicePlan @paramAppServicePlan
}

# ------------------------------------------------------------------------------------------
# Configure NME SQL Database Plan
If ($updateSqlDatabasePlan) {
    $paramSqlDatabasePlan = @{
        SubscriptionId    = $NMESubscriptionId
        ResourceGroupName = $NMEResourceGroupName
        ServerName        = $NMESqlServerName
        DatabaseName      = $NMESqlDatabaseName
        Edition           = $NMESqlDatabaseEdition
        Sku               = $NMESQLDatabaseSku
    }

    Set-BesSqlDatabasePlan @paramSqlDatabasePlan
}

# ------------------------------------------------------------------------------------------
# Create Deloyment Resource Group
If ($createDeploymentResourceGroup) {
    $paramResourceGroup = @{
        SubscriptionId    = $NMESubscriptionId
        ResourceGroupName = $DeploymentResourceGroupName
        Tags              = (Convert-BesPSCustomObjectToHashTable -CustomObject $DeploymentResourceGroupTags)
        Location          = $NMELocation
    }

    New-BesResourceGroup @paramResourceGroup -NmeUri $NMEuRI -Headers $headers -NMESPName $NMESPName
}

# ------------------------------------------------------------------------------------------
# Create Deployment Managed Identity
If ($createDeploymentManagedIdentity) {
    $paramDeploymentManagedIdentity = @{
        SubscriptionId          = $NMESubscriptionId
        ResourceGroupName       = $DeploymentResourceGroupName
        UserManagedIdentityName = $DeploymentManagedIdentityName
        Location                = $NMELocation
    }

    $deploymentManagedIdentity = New-BesDeploymentManagedIdentity @paramDeploymentManagedIdentity
    $deploymentManagedIdentityVariable = $DeploymentManagedIdentity[-1]
}

# ------------------------------------------------------------------------------------------
# Create Deplyoment Storage Account
If ($createDeploymentStorageAccount) {
    $paramStorageAccount = @{
        SubscriptionId          = $NMESubscriptionId
        ResourceGroupName       = $DeploymentResourceGroupName
        StorageAccountName      = $DeploymentStorageAccountName
        Location                = $NMELocation
        SkuName                 = $DeploymentStorageAccountSku
        DeploymentContainerName = $DeploymentContainerName
        PrerequisiteName        = $DeploymentPrerequisiteName
    }

    $deploymentStorageAccount = New-BesDeploymentStorage @paramStorageAccount
    $deploymentStorageAccountVariable = $DeploymentStorageAccount[-1]
}

# ------------------------------------------------------------------------------------------
# Assign Deployment Managed Identity to Deployment Storage Account
If ($assignManagedIdentityToStorageAccount) {
    $paramAssignManagedIdentity = @{
        ManagedIdentityVariable = $DeploymentManagedIdentityVariable
        StorageAccountVariable  = $DeploymentStorageAccountVariable
    }

    Set-BesManagedIdentityToStorageAccount @paramAssignManagedIdentity
}

# ------------------------------------------------------------------------------------------
# Create Secure Variables

If ($createSecureVars) {
    # Variable Name must be between 1 and 20 characters and can only alphanumeric characters
    New-BesSecureVariable -Name "LocalAdministrator" -Value $LocalAdmin
    New-BesSecureVariable -Name "DeployIdentity" -Value $DeploymentManagedIdentityVariable
    New-BesSecureVariable -Name "DeployStorageAccount" -Value $DeploymentStorageAccountVariable
}

# ------------------------------------------------------------------------------------------
# Configure NME Workspace Quota
If ($updateWorkspaceQuota) {
    Set-BesWorkspaceDailyQuota -LogAnalyticWorkspaces $logAnalyticWorkspaces
}

# ------------------------------------------------------------------------------------------
# Link Subscription to NME
#  Use API because the PowerShell module requires a service principal to be created in the same tenant as the subscription
#  With the API, we can use the NME service principal to link the subscription

If ($linkSubscription) {
    $NewSubscriptionParams = @{
        subscriptionId   = $AVDSubscriptionId
        tenantId         = $NMETenantId
        servicePrincipal = $null
    }

    $body = $null
    $body = $NewSubscriptionParams | ConvertTo-Json
    Invoke-RestMethod "$NMEuRI/api/v1/subscriptions" -Headers $headers -Body $body -Method Post -UseBasicParsing
}

# ------------------------------------------------------------------------------------------
# Link Subnets to NME
If ($linkSubnets) {
    ForEach ($AVDVnetConfig in $AVDVnetConfigs) {
        ForEach ($s in $AVDVnetConfig.subnetName) {
            $AVDVnetConfigParams = @{
                subscriptionId    = $AVDSubscriptionId
                resourceGroupName = $AVDVnetConfig.resourceGroup
                networkName       = $AVDVnetConfig.vnetName
                subnetName        = $s
            }

            $NmeLinkNetworkRestPayload = New-NmeLinkNetworkRestPayload @AVDVnetConfigParams
            New-NmeLinkedNetworks -NmeLinkNetworkRestPayload $NmeLinkNetworkRestPayload
        }
    }
}

# ------------------------------------------------------------------------------------------
# Create Resources
$avdConfigs | ForEach-Object -Parallel {
    ${function:Convert-BesPSCustomObjectToHashTable} = $using:funcConvertBesPSCustomObjectToHashTable
    ${function:Get-BesDayOfWeek} = $using:funcGetBesDayOfWeek
    ${function:Connect-NmeApi} = $using:funcConnectNmeApi
    ${function:New-BesResourceGroup} = $using:funcNewBesResourceGroup
    ${function:New-BesNmeWorkspace} = $using:funcNewBesNmeWorkspace
    ${function:New-BesNmeHostPool} = $using:funcNewBesNmeHostPool
    ${function:Set-BesNmeHostPoolCustomTags} = $using:funcSetBesNmeHostPoolCustomTags
    ${function:Set-BesNmeHostPoolAVDConfig} = $using:funcSetBesNmeHostPoolAVDConfig
    ${function:New-BesNmeHostPoolADConfig} = $using:funcNewBesNmeHostPoolADConfig
    ${function:Set-BesNmeHostPoolAutoScaleConfig} = $using:funcSetBesNmeHostPoolAutoScaleConfig
    ${function:Set-BesNmeHostPoolSessionTimeoutConfig} = $using:funcSetBesNmeHostPoolSessionTimeoutConfig
    ${function:Set-BesNmeHostPoolFslConfig} = $using:funcSetBesNmeHostPoolFslConfig
    ${function:New-BesNmeHostPoolUserAssignment} = $using:funcNewBesNmeHostPoolUserAssignment
    ${function:Set-BesNmeHostPoolRDPConfig} = $using:funcSetBesNmeHostPoolRDPConfig
    ${function:Update-BesNmeVmDeploymentConfig} = $using:funcUpdateBesNmeVmDeploymentConfig

    $ConnectArguments = $using:ConnectArguments
    $NMESPName = $using:NMESPName
    $NMEuRI = $using:NMEuRI
    $AVDSubscriptionId = $using:AVDSubscriptionId
    $RegionName = $using:RegionName

    $avdConfig = $_

    $paramResource = @{
        SubscriptionId    = $AVDSubscriptionId
        ResourceGroupName = $avdConfig.resourceGroupName
        Location          = $avdConfig.region
    }

    $paramHostPool = @{
        SubscriptionId    = $AVDSubscriptionId
        ResourceGroupName = $avdConfig.resourceGroupName
        HostPoolName      = $avdConfig.hostPool.name
    }

    Connect-Nme @ConnectArguments
    $headers = Connect-NmeApi @ConnectArguments

    # Convert custom object to hash table (order is an example, adjust as needed)
    $tagsOrder = [ordered]@{
        CostCenter  = 'CostCenter'
        Environment = 'Environment'
    }
    $tags = $null
    $tags = Convert-BesPSCustomObjectToHashTable -CustomObject $avdConfig.tags -Order $tagsOrder

    Write-Host "$($avdConfig.hostPool.name) - Creating resource group"
    If (-not (Get-AzResourceGroup -Name $avdConfig.resourceGroupName -ErrorAction SilentlyContinue)) { New-BesResourceGroup @paramResource -Tags $tags -NmeUri $NMEuRI -Headers $headers -NMESPName $NMESPName }

    Write-Host "$($avdConfig.hostPool.name) - Creating workspace"
    New-BesNmeWorkspace @paramResource -WorkspaceName $avdConfig.workspace.name -FriendlyName $avdConfig.workspace.friendlyName -Description $avdConfig.workspace.description

    Write-Host "$($avdConfig.hostPool.name) - Creating host pool"
    $paramNewHostPool = @{
        WorkspaceName = $avdConfig.workspace.name
        HostPoolType  = $avdConfig.hostPool.type
    }

    Switch ($avdConfig.hostPool.type) {
        "Pooled" {
            $null = $paramNewHostPool.Add("IsDesktop", $avdConfig.hostPool.isDesktop)
            $null = $paramNewHostPool.Add("IsSingleUser", $avdConfig.hostPool.isSingleUser)
        }
        "Personal" {
            $null = $paramNewHostPool.Add("AssignmentType", $avdConfig.hostPool.assignmentType)
        }
    }

    New-BesNmeHostPool @paramHostPool @paramNewHostPool

    Write-Host "$($avdConfig.hostPool.name) - Configure Tags for host pool"
    Set-BesNmeHostPoolCustomTags  @paramHostPool -Tags $tags

    Write-Host "$($avdConfig.hostPool.name) - Configuring AD settings for host pool"
    $adProfile = @{
        ProfileType      = $avdConfig.properties.directory.adProfileType
        ProfileName      = $avdConfig.properties.directory.adProfileName
        IdentityType     = $avdConfig.properties.directory.adIdentityType
        EnrollWithIntune = $avdConfig.properties.directory.adEnrollWithIntune
        JoinDomainName   = $avdConfig.properties.directory.adJoinDomainName
        JoinOrgUnit      = $avdConfig.properties.directory.adJoinOrgUnit
        JoinUserName     = $avdConfig.properties.directory.adJoinUserName
        JoinPassword     = $avdConfig.properties.directory.adJoinPassword
    }

    ##New-BesNmeHostPoolADConfig @paramHostPool @adProfile

    Write-Host "$($avdConfig.hostPool.name) - Configuring AVD settings for host pool"
    $paramHostPoolAVDConfig = @{
        FriendlyName                    = $avdConfig.hostPool.friendlyName
        Description                     = $avdConfig.hostPool.description
        LoadBalancerType                = $avdConfig.properties.avd.loadBalancerType
        MaxSessionLimit                 = $avdConfig.properties.avd.maxSessionLimit
        ValidationEnv                   = $avdConfig.properties.avd.validationEnv
        StartVMOnConnect                = $avdConfig.properties.avd.startVMOnConnect
        AgentUpdateType                 = $avdConfig.properties.avd.agentUpdate.type
        AgentUpdateDayPrimary           = $avdConfig.properties.avd.agentUpdate.dayPrimary
        AgentUpdateHourPrimary          = $avdConfig.properties.avd.agentUpdate.hourPrimary
        AgentUpdateDaySecondary         = $avdConfig.properties.avd.agentUpdate.daySecondary
        AgentUpdateHourSecondary        = $avdConfig.properties.avd.agentUpdate.hourSecondary
        TimezoneId                      = $avdConfig.hostPool.timezoneId
        UseSessionHostLocalTime         = $avdConfig.properties.avd.agentUpdate.useSessionHostLocalTime
        PowerOnHostsInMaintenanceWindow = $avdConfig.properties.avd.agentUpdate.powerOnHostsInMaintenanceWindow
        ExcludeDrainModeHosts           = $avdConfig.properties.avd.agentUpdate.excludeDrainModeHosts
    }

    Switch ($avdConfig.hostPool.type) {
        "Pooled" {
            $null = $paramHostPoolAVDConfig.Add("PowerOnPooledHosts", $avdConfig.properties.avd.powerOnPooledHosts)
        }
        "Personal" {
        }
    }

    Set-BesNmeHostPoolAVDConfig @paramHostPool @paramHostPoolAVDConfig

    Write-Host "$($avdConfig.hostPool.name) - Configuring VM deployment settings for host pool"
    $paramVmDeploymentConfig = @{
        VmTimezone                     = $avdConfig.hostPool.timezoneId
        EnableTimezoneRedirection      = $avdConfig.properties.vmDeployment.enableTimezoneRedirection
        IsAcceleratedNetworkingEnabled = $avdConfig.properties.vmDeployment.isAcceleratedNetworkingEnabled
        RdpShortpath                   = $avdConfig.properties.vmDeployment.rdpShortpath
        InstallGPUDrivers              = $avdConfig.properties.vmDeployment.installGPUDrivers
        UseAvailabilityZones           = $avdConfig.properties.vmDeployment.useAvailabilityZones
        EnableVmDeallocation           = $avdConfig.properties.vmDeployment.enableVmDeallocation
        InstallCertificates            = $avdConfig.properties.vmDeployment.installCertificates
        ForceVMRestart                 = $avdConfig.properties.vmDeployment.forceVMRestart
        AlwaysPromptForPassword        = $avdConfig.properties.vmDeployment.alwaysPromptForPassword
        BootDiagEnabled                = $avdConfig.properties.vmDeployment.bootDiagEnabled
        Watermarking                   = $avdConfig.properties.vmDeployment.watermarking
        SecurityType                   = $avdConfig.properties.vmDeployment.securityType
        SecureBootEnabled              = $avdConfig.properties.vmDeployment.secureBootEnabled
        VTpmEnabled                    = $avdConfig.properties.vmDeployment.vTpmEnabled
    }

    Update-BesNmeVmDeploymentConfig @paramHostPool @paramVmDeploymentConfig

    # Configure session timeouts
    Write-Host "$($avdConfig.hostPool.name) - Configuring session timeouts for host pool"
    $sessionTimeLimits = @{
        Enable               = $avdConfig.properties.sessionTimeLimits.isSessionTimeoutsEnabled
        MaxDisconnectionTime = $avdConfig.properties.sessionTimeLimits.maxDisconnectionTime
        MaxIdleTime          = $avdConfig.properties.sessionTimeLimits.maxIdleTime
    }

    Set-BesNmeHostPoolSessionTimeoutConfig @paramHostPool @sessionTimeLimits

    # Disable FSLogix, configuration is not supported at the moment
    Write-Host "$($avdConfig.hostPool.name) - Configuring FSLogix settings for host pool"
    Set-BesNmeHostPoolFslConfig @paramHostPool -Enable  $avdConfig.properties.fsLogix.isFslogixEnabled

    $hostPoolRDPConfig = @{}
    If ($avdConfig.properties.rdpSettings.Properties) { $null = $hostPoolRDPConfig.Add("RdpProperties", $avdConfig.properties.rdpSettings.Properties) }
    If ($avdConfig.properties.rdpSettings.PropertiesName) { $null = $hostPoolRDPConfig.Add("ConfigurationName", $avdConfig.properties.rdpSettings.PropertiesName) }

    If (!([string]::IsNullOrEmpty($hostPoolRDPConfig))) {
        Write-Host "$($avdConfig.hostPool.name) - Configuring RDP settings for host pool"
        Set-BesNmeHostPoolRDPConfig @paramHostPool @hostPoolRDPConfig
    }

    Write-Host "$($avdConfig.hostPool.name) - Creating autoscale configuration for host pool"
    # For the following configurations, set to $ture is not supported at the moment. Function need to enhanced to support these configurations.
    $preStateHostsConfiguration = $false
    $scaleIntimeRestrictionConfiguration = $false
    $autoHealConfiguration = $false

    $parmaAutoScale = @{
        HostPoolType                        = $avdConfig.hostPool.type
        IsSingleUser                        = $avdConfig.hostPool.isSingleUser
        TimezoneId                          = $avdConfig.hostPool.timezoneId
        IsAutoScaleEnabled                  = $avdConfig.autoScale.isAutoScaleEnabled
        Prefix                              = $avdConfig.autoScale.hostNamePrefix
        VnetName                            = $avdConfig.autoScale.vnetName
        VnetResourceGroupName               = $avdConfig.autoScale.vnetResourceGroupName
        SubnetName                          = $avdConfig.autoScale.subnetName
        Image                               = $avdConfig.autoScale.image
        Size                                = $avdConfig.autoScale.hostSize
        DiskSize                            = $avdConfig.autoScale.hostDiskSize
        HasEphemeralOSDisk                  = $avdConfig.autoScale.hostHasEphemeralOSDisk
        StorageType                         = $avdConfig.autoScale.hostStorageType
        StoppedDiskType                     = $avdConfig.autoScale.stoppedDiskType
        ReuseVmNames                        = $avdConfig.autoScale.reuseVmNames
        VmNamingMode                        = $avdConfig.autoScale.vmNamingMode
        EnableFixFailedTask                 = $avdConfig.autoScale.enableFixFailedTask
        ActiveHostType                      = $avdConfig.autoScale.sizing.activeHostType
        HostPoolCapacity                    = $avdConfig.autoScale.sizing.hostPoolCapacity
        MinActiveHostsCount                 = $avdConfig.autoScale.sizing.minActiveHostsCount
        BurstCapacity                       = $avdConfig.autoScale.sizing.burstCapacity
        MinCountCreatedVmsType              = $avdConfig.autoScale.sizing.minCountCreatedVmsType
        AutoScaleCriteria                   = $avdConfig.autoScale.logic.autoScaleCriteria
        StopDelayMinutes                    = $avdConfig.autoScale.logic.stopDelayMinutes
        ScalingMode                         = $avdConfig.autoScale.logic.scalingMode
        ScaleInAggressiveness               = $avdConfig.autoScale.logic.scaleInAggressiveness
        PreStateHostsConfiguration          = $preStateHostsConfiguration
        ScaleIntimeRestrictionConfiguration = $scaleIntimeRestrictionConfiguration
        MinutesBeforeRemove                 = $avdConfig.autoScale.messaging.minutesBeforeRemove
        Message                             = $avdConfig.autoScale.messaging.message
        AutoHealConfiguration               = $autoHealConfiguration
    }

    Switch ($avdConfig.hostPool.type) {
        "Pooled" {
        }
        "Personal" {
            If ($avdConfig.autoScale.autoGrow) {
                $AutoGrow = $null
                $AutoGrow = Convert-BesPSCustomObjectToHashTable -CustomObject $avdConfig.autoScale.autoGrow
                $parmaAutoScale.Add("AutoGrow", $AutoGrow)
            }
            If ($avdConfig.autoScale.autoShrink) {
                $AutoShrink = $null
                $AutoShrink = Convert-BesPSCustomObjectToHashTable -CustomObject $avdConfig.autoScale.autoShrink
                $parmaAutoScale.Add("AutoShrink", $AutoShrink)
            }
        }
    }

    Set-BesNmeHostPoolAutoScaleConfig  @paramHostPool @parmaAutoScale

    #Write-Host "$($avdConfig.hostPool.name) - Assigning user to host pool"
    #New-BesNmeHostPoolUserAssignment @paramHostPool -UserPrincipalName $avdConfig.assignements.userPrincipalName

    #ConfigureRBAC
    #>
} -ThrottleLimit $throttleLimit
#>