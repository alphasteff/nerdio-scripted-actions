#name: Install <Application Name> via Blob
#description: Deploy <Application Name> package via Blob.
#execution mode: Combined
#tags: <CustomerName>, Preview

<# Notes:

Use this script to prepare a Desktop Image and install <Application Name> via Blob.

#>

##### Packages #####
$files = [System.Collections.ArrayList]@()
$null = $files.Add(@{Name = 'Genesys_GenesysCloud_1.0'; Script = 'Genesys_GenesysCloud.ps1'; Arguments = ''})

##### Start Logging #####
$runingScriptName = (Get-Item $PSCommandPath ).Name
$logFile = Join-Path -path $env:InstallLogDir -ChildPath "$runingScriptName-$(Get-date -f 'yyyy-MM-dd').log"

$paramSetPSFLoggingProvider = @{
  Name         = 'logfile'
  InstanceName = $runingScriptName
  FilePath     = $logFile
  FileType     = 'CMTrace'
  Enabled      = $true
}
If (!(Get-PSFLoggingProvider -Name logfile).Enabled){$Null = Set-PSFLoggingProvider @paramSetPSFLoggingProvider}

Write-PSFMessage -Level Host -Message ("Start " + $runingScriptName)

##### Script Logic #####

$ErrorActionPreference = 'Stop'

$storageAccountVariable  = 'DeployStorageAccount'
$resourceGroupVariable   = 'DeployResourceGroup'
$containerVariable       = 'DeployContainer'
$subscriptionId          = $AzureSubscriptionId

$storageAccountName      = $SecureVars.$storageAccountVariable
$resourceGroupName       = $SecureVars.$resourceGroupVariable
$containerName           = $SecureVars.$containerVariable

function Get-BestSasToken {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The Subscription Id of the subscription on which the storage account is located.",
            ValueFromPipeline = $true
        )]
        [string]
        $SubscriptionId,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The name of the resource group in which the storage account resides.",
            ValueFromPipeline = $true
        )]
        [string]
        $ResourceGroupName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The name of the storage account.",
            ValueFromPipeline = $true
        )]
        [string]
        $StorageAccountName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Name of the blob container.",
            ValueFromPipeline = $true
        )]
        [string]
        $ContainerName,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "How long the token should be valid, in minutes.",
            ValueFromPipeline = $true
        )]
        [int]
        $TokenLifeTime = 60
    )
    
    begin {
        $date = Get-Date
        $actDate = $date.ToUniversalTime()
        $expiringDate = $actDate.AddMinutes($TokenLifeTime )
        $expiringDate = (Get-Date $expiringDate -Format 'yyyy-MM-ddTHH:mm:ssZ')  
    }
    
    process {
        $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Method GET -Headers @{Metadata="true"} -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        $armToken = $content.access_token

        # Convert the parameters to JSON, then call the storage listServiceSas endpoint to create the SAS credential:
        $params = @{canonicalizedResource="/blob/$StorageAccountName/$ContainerName";signedResource="c";signedPermission="r";signedProtocol="https";signedExpiry="$expiringDate"}
        $jsonParams = $params | ConvertTo-Json
        $sasResponse = Invoke-WebRequest `
            -Uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName/listServiceSas/?api-version=2017-06-01" `
            -Method POST `
            -Body $jsonParams `
            -Headers @{Authorization="Bearer $armToken"} `
            -UseBasicParsing

        # Extract the SAS credential from the response:
        $sasContent = $sasResponse.Content | ConvertFrom-Json
        $sasCred = $sasContent.serviceSasToken
    }
    
    end {
        return $sasCred
    }
}

Function Start-Unzip {
    param([string]$zipfile, [string]$outpath)
    $null = Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $null = [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
        return $true
    }
    catch {
        return $false
    }
}

$sasCred = Get-BestSasToken -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -ContainerName $containerName -TokenLifeTime 60

$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasCred

$installDirectory = $Env:InstallDir

ForEach ($file in $files){
    $scriptArchiv = $file.Name
    $scriptName = $file.Script
    $scriptArguemts = $file.Arguments

    $folderName = $scriptArchiv
    $zipFile = $scriptArchiv + '.zip'

    Write-PSFMessage -Level Host -Message ("Download File: " + $zipFile)
    Get-AzStorageBlobContent -Blob $zipFile -Container $containerName -Destination "$installDirectory\$zipFile" -Context $ctx -Force
    Start-Unzip "$installDirectory\$zipFile" "$installDirectory\$folderName"

    Write-PSFMessage -Level Host -Message ("Execute Script: " + "$installDirectory\$folderName\$scriptName")
    & "$installDirectory\$folderName\$scriptName" @scriptArguemts
}

Write-PSFMessage -Level Host -Message ("Stop " + $runingScriptName)

Stop-PSFRunspace
