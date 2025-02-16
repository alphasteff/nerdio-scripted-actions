# Not tested yet
<#

$ErrorActionPreference = 'Stop'

# Set variables
function Set-NmeVars {
    param(
        [Parameter(Mandatory = $true)]
        [string]$keyvaultName
    )
    Write-Verbose "Getting Nerdio Manager key vault $keyvaultName"
    Write-Verbose ("Get-AzKeyVault version: " + (Get-Command Get-AzKeyVault).Version)
    $script:NmeKeyVault = Get-AzKeyVault -VaultName $keyvaultName
    $script:NmeRg = $NmeKeyVault.ResourceGroupName
    $keyvaultTags = $NmeKeyVault.Tags
    Write-Verbose ("NmeKeyVault is " + ($NmeKeyVault.VaultName | Out-String))
    Write-Verbose ("NMERG is " + ($NmeRg | Out-String))
    Write-Verbose ("$keyvaultName tags are " + ($keyvaultTags | Out-String))

    Write-Verbose "Getting Nerdio Manager web app"
    $webapps = Get-AzWebApp -ResourceGroupName $NmeRg
    if ($webapps) {
        $script:NmeWebApp = $webapps | Where-Object { ($_.siteconfig.appsettings | Where-Object name -EQ "Deployment:KeyVaultName" | Select-Object -ExpandProperty value) -eq $keyvaultName }
    } else {
        throw "Unable to find Nerdio Manager web app"
    }

    $script:NmeSubscriptionId = ($NmeWebApp.siteconfig.appsettings | Where-Object name -EQ 'Deployment:SubscriptionId').value
    $script:NmeScriptedActionsAccountName = (($NmeWebApp.siteconfig.appsettings | Where-Object name -EQ 'Deployment:ScriptedActionAccount').value).Split("/")[-1]
    $script:NmeRegion = $NmeKeyVault.Location
}

Set-NmeVars -keyvaultName $KeyVaultName
$Prefix = $NmeTagPrefix

$NmeRg = 'rg-nerdio-avdss-prd-we-01'
$NmeSubscriptionId = 'c4839d12-e5fa-411e-8cb4-8201157ca45a'
$NmeScriptedActionsAccountName = 'nmw-app-scripted-actions-ymhp6bcl6taag'
$NmeRegion = 'westeurope '

Set-AzContext -SubscriptionId $NmeSubscriptionId

$NMEAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $NmeRg -Name $NmeScriptedActionsAccountName

$RunTimeVersion = '{0}.{1}' -f $Host.Runspace.Version.Major, $Host.Runspace.Version.Minor

$AllowedRuntimeVersions = @('5.1', '7.2')

If ($AllowedRuntimeVersions -notcontains $RunTimeVersion) {
    $RunTimeVersion = '5.1'
}

$InstalledModules = Get-AzAutomationModule -RuntimeVersion $RunTimeVersion -AutomationAccountName $NMEAutomationAccount.AutomationAccountName -ResourceGroupName $NmeRg

# Import Module on Hybrid Worker if not already installed
$Module = Get-AzAutomationModule -Name 'Az' -RuntimeVersion $RunTimeVersion -AutomationAccountName $NMEAutomationAccount.AutomationAccountName -ResourceGroupName $NmeRg

If ((Get-InstalledModule -Name "Az").Version -ne $Module.Version) {
    Write-Output "Installing $($Module.Name) module version $($Module.Version) on Hybrid Worker"
    Install-Module -Name $Module.Name -RequiredVersion $Module.Version -Force -AllowClobber -Scope AllUsers
}

ForEach ($Module in $InstalledModules) {
    If ((Get-InstalledModule -Name $Module.Name).Version -ne $Module.Version) {
        Write-Output "Installing $($Module.Name) module version $($Module.Version) on Hybrid Worker"
        Install-Module -Name $Module.Name -RequiredVersion $Module.Version -Force -AllowClobber -Scope AllUsers
    }
}
#>
