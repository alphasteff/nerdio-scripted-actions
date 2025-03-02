#name: Measuring disc performance
#description: Measures the performance of the disk
#execution mode: IndividualWithRestart
#tags: beckmann.ch

<# Notes:

Use this script to measure the performance of the disk. The script creates files of different sizes, copies them, reads them, compresses them, and decompresses them. The results are then stored in a CSV file and uploaded to a storage account.

#>

Start-Transcript -Path "$($Env:windir)\Logs\Measuring_disc_performance_Transscript.log"

$now = Get-Date
$now = $now.ToUniversalTime()
$timestamp = $now.ToString('yyyy-MM-ddTHH-mm-ssZ')

$InstallDirectory = $Env:SystemDrive + '\PerfDir'
$LogDirectory = "$InstallDirectory\Logs"
if (-not (Test-Path $InstallDirectory)) {
    $null = New-Item -Path $InstallDirectory -ItemType Directory
}

If (-not (Test-Path $LogDirectory)) {
    $null = New-Item -Path $LogDirectory -ItemType Directory
}

##### Files #####
# Need to be stored within the data container
$DataFiles = [System.Collections.ArrayList]@()
$null = $DataFiles.Add(@{Name = 'Install-WPR.ps1' })

##### Binary Files #####
# Need to be stored within the binary container
$BinaryFiles = [System.Collections.ArrayList]@()
$null = $BinaryFiles.Add(@{Name = 'WADK - WPR Only.zip' })

##### Scripts #####
# Need to be stored within the data container, script is then executed
$Scripts = [System.Collections.ArrayList]@()
#$null = $Scripts.Add(@{Script = ('ScripteName.ps1'); Arguments = '' })

##### Packages #####
# Need to be stored within the binary container, binary is then executed
$ZipFiles = [System.Collections.ArrayList]@()
#$null = $ZipFiles.Add(@{Name = 'ZibFileName'; Script = 'ApplicationName.exe'; Arguments = '' })

##### Script Logic #####

$ErrorActionPreference = 'Stop'

$ManagedIdentityVariable = 'PerfTestIdentity'
$StorageAccountVariable = 'PerfTestStorage'
$ScriptConfigVariable = 'PerfTestConfig'

$ManagedIdentity = $SecureVars.$ManagedIdentityVariable | ConvertFrom-Json
$StorageAccount = $SecureVars.$StorageAccountVariable | ConvertFrom-Json
$config = $SecureVars.$ScriptConfigVariable | ConvertFrom-Json

$subscriptionId = $StorageAccount.subscriptionId
$resourceGroupName = $StorageAccount.resourceGroup
$storageAccountName = $StorageAccount.name
$containerResultsName = $StorageAccount.results
$containerDataName = $StorageAccount.data
$containerBinName = $StorageAccount.bin

Write-Output "SubscriptionId: $subscriptionId"
Write-Output "ResourceGroupName: $resourceGroupName"
Write-Output "StorageAccountName: $storageAccountName"
Write-Output "ContainerResultsName: $containerResultsName"
Write-Output "ContainerDataName: $containerDataName"
Write-Output "ContainerBinName: $containerBinName"


function Get-BesSasToken {
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
            HelpMessage = "The Identity to use to acces the storage account.",
            ValueFromPipeline = $true
        )]
        [PScustomObject]
        $Identity,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "How long the token should be valid, in minutes.",
            ValueFromPipeline = $true
        )]
        [int]
        $TokenLifeTime = 60,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "The permission to grant the SAS token.",
            ValueFromPipeline = $true
        )]
        $Permission = 'r'
    )

    begin {
        $date = Get-Date
        $actDate = $date.ToUniversalTime()
        $expiringDate = $actDate.AddMinutes($TokenLifeTime )
        $expiringDate = (Get-Date $expiringDate -Format 'yyyy-MM-ddTHH:mm:ssZ')
        $api = 'http://169.254.169.254/metadata/identity/oauth2/token'
        $apiVersion = '2018-02-01'
        $resource = 'https://management.azure.com/'

        $webUri = "$api`?api-version=$apiVersion&resource=$resource"


        if ($Identity) {
            if ($Identity.client_id) {
                $webUri = $webUri + '&client_id=' + $Identity.client_id
            } elseif ($Identity.object_id) {
                $webUri = $webUri + '&object_id=' + $Identity.object_id
            }
        }

    }

    process {
        $response = Invoke-WebRequest -Uri $webUri -Method GET -Headers @{ Metadata = "true" } -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        $armToken = $content.access_token

        # Convert the parameters to JSON, then call the storage listServiceSas endpoint to create the SAS credential:
        $params = @{canonicalizedResource = "/blob/$StorageAccountName/$ContainerName"; signedResource = "c"; signedPermission = $Permission; signedProtocol = "https"; signedExpiry = "$expiringDate" }
        $jsonParams = $params | ConvertTo-Json
        $sasResponse = Invoke-WebRequest `
            -Uri "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName/listServiceSas/?api-version=2017-06-01" `
            -Method POST `
            -Body $jsonParams `
            -Headers @{Authorization = "Bearer $armToken" } `
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
    param(
        [string]$zipfile,
        [string]$outpath)
    $Null = Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Null = [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

Function Start-Zip {
    param(
        [string]$SourcePath,
        [string]$ZipFile,
        [bool]$Overwrite = $false
    )

    $Null = Add-Type -AssemblyName System.IO.Compression.FileSystem

    If ($Overwrite -and (Test-Path $ZipFile)) {
        Remove-Item -Path $ZipFile
    } ElseIf (Test-Path $ZipFile) {
        [System.IO.Compression.ZipFile]::Open($zipFile, [System.IO.Compression.ZipArchiveMode]::Update).Dispose()
    } Else {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($SourcePath, $ZipFile)
    }
}

Function Create-File {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "specify the file size in bytes")]
        [int]$fileSize,
        [Parameter(Mandatory = $true, HelpMessage = "specify the location to create the file")]
        [string]$location
    )
    #Run FSUtil
    if (!(Test-Path $location)) { New-Item -Path $location -ItemType Directory }
    if (Test-Path $("$location\$fileSize.file")) { Remove-Item -Path $("$location\$fileSize.file") -Force }
    $process = Start-Process fsutil -ArgumentList "file createnew $("$location\$fileSize.file") $fileSize" -PassThru
    $process | Wait-Process

    return $("$location\$fileSize.file")
}

Function Copy-Files {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Template file to copy")]
        [string]$templateFile,
        [Parameter(Mandatory = $true, HelpMessage = "Number of items to duplicate")]
        [int]$itemCopies,
        [Parameter(Mandatory = $true, HelpMessage = "Working folder")]
        [string]$workingFolder
    )

    try {
        if (!(Test-Path -Path $templateFile)) {
            Throw "Error locating the template file to copy, please try again"
        } else {
            return $(Measure-Command {
                    foreach ($item in 1..$itemCopies) {
                        Copy-Item -Path $templateFile -Destination "$workingFolder\$item.file" -Force
                    }
                }).TotalMilliseconds
        }
    } catch {
        Write-Error $_
    }

}

Function Read-Files {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Working folder")]
        [string]$workingFolder
    )

    try {
        if (!(Test-Path -Path $workingFolder)) {
            Throw "Error opening the workling folder, please try again"
        } else {
            return $(Measure-Command {
                    $files = Get-ChildItem -Path $workingFolder
                    foreach ($item in $files) {
                        Get-Content -Path $item.fullname | Out-Null
                    }
                }).TotalMilliseconds
        }
    } catch {
        Write-Error $_
    }

}

Function Remove-Folder {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Working folder")]
        [string]$workingFolder
    )

    try {
        if (!(Test-Path -Path $workingFolder)) {
            Throw "Error locating the working folder, please try again"
        } else {
            return $(Measure-Command { Remove-Item -Path $workingFolder -Recurse -Force -Confirm:$false }).TotalMilliseconds
        }
    } catch {
        Write-Error $_
    }

}

#7Zip Wrapper Function
Function Run-Compression {
    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Action to perform, compress or decompress")]
        [ValidateSet("compress", "decompress")]
        [string]$action,
        [Parameter(Mandatory = $true, HelpMessage = "Location of archives to decompress or compress")]
        [string]$location,
        [Parameter(Mandatory = $false, HelpMessage = "Level of compression to use 5=normal, 7=maximum, 9=ultra")]
        [ValidateSet(5, 7, 9)]
        [int]$compressionLevel = 5
    )

    Switch ($action) {
        "compress" {
            return $(Measure-Command {
                    $process = Start-Process -FilePath "C:\Program Files\7-Zip\7z.exe" -ArgumentList "a", "$location\archive.7z", "$location", "-mx$compressionLevel" -PassThru
                    $process | Wait-Process
                }).TotalMilliseconds
        }
        "decompress" {
            return $(Measure-Command {
                    $process = Start-Process -FilePath "C:\Program Files\7-Zip\7z.exe" -ArgumentList "x", "$location\*.7z", "-oC:\Windows\Temp", "-y" -PassThru
                    $process | Wait-Process
                }).TotalMilliseconds
        }
    }
}

$sasResultsCred = Get-BesSasToken -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -ContainerName $containerResultsName -Identity $ManagedIdentity -TokenLifeTime 60 -Permission 'w'
$sasDataCred = Get-BesSasToken -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -ContainerName $containerDataName -Identity $ManagedIdentity -TokenLifeTime 60 -Permission 'r'
$sasBinCred = Get-BesSasToken -SubscriptionId $subscriptionId -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName -ContainerName $containerBinName -Identity $ManagedIdentity -TokenLifeTime 60 -Permission 'r'

$ctxResults = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasResultsCred
$ctxData = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasDataCred
$ctxBin = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasBinCred

# Download the files and execute if needed
Try {
    ForEach ($DataFile in $DataFiles) {
        Write-Host "Downloading $($DataFile.Name)"
        $FileName = $DataFile.Name
        Get-AzStorageBlobContent -Blob $FileName -Container $containerDataName -Destination "$InstallDirectory\$FileName" -Context $ctxData -Force -ErrorAction SilentlyContinue
    }

    ForEach ($BinaryFile in $BinaryFiles) {
        Write-Host "Downloading $($BinaryFile.Name)"
        $FileName = $BinaryFile.Name
        Get-AzStorageBlobContent -Blob $FileName -Container $containerBinName -Destination "$InstallDirectory\$FileName" -Context $ctxBin -Force -ErrorAction SilentlyContinue
    }

    ForEach ($Script in $Scripts) {
        Write-Host "Downloading $($Script.Script) and executing with arguments $($Script.Arguments)"

        $ScriptName = $Script.Script
        $ScriptArguemts = $Script.Arguments

        Get-AzStorageBlobContent -Blob $ScriptName -Container $containerDataName -Destination "$InstallDirectory\$ScriptName" -Context $ctxData -Force -ErrorAction SilentlyContinue

        & "$InstallDirectory\$ScriptName" @ScriptArguemts
    }

    ForEach ($ZipFile in $ZipFiles) {

        Write-Host "Downloading $($ZipFile.Name) and executing script $($ZipFile.Script) with arguments $($ZipFile.Arguments)"

        $ScriptArchiv = $ZipFile.Name
        $ScriptName = $ZipFile.Script
        $ScriptArguemts = $ZipFile.Arguments

        $FolderName = $ScriptArchiv
        $File = $ScriptArchiv + '.zip'

        Get-AzStorageBlobContent -Blob $File -Container $containerBinName -Destination "$InstallDirectory\$File" -Context $ctxBin -Force -ErrorAction SilentlyContinue
        Start-Unzip "$InstallDirectory\$File" "$InstallDirectory\$FolderName"

        & "$InstallDirectory\$FolderName\$ScriptName" @ScriptArguemts
    }
} catch {
    $_ | Out-File "$InstallDirectory\ERRORS.log"
}

# Download and install 7Zip
if (!(Test-Path "C:\Program Files\7-Zip\7z.exe")) {
    try {
        Write-Host "Downloading and installing 7Zip"
        Invoke-WebRequest -UseBasicParsing -Uri "https://www.7-zip.org/a/7z2301-x64.exe" -Method Get -OutFile "C:\Temp\7z.exe"
        $Process = Start-Process "C:\Temp\7z.exe" -ArgumentList "/S" -PassThru
    } catch {
        Write-Error "Could not download or install 7Zip"
    }
}

try {

    #Get Azure Info
    #$azureDetails = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | ConvertTo-Json -Depth 64
    #$azureDetails | Out-File "$LogDirectory\Azure_Info.json"

    #Export the system info
    Get-ComputerInfo | ConvertTo-Json | Out-File "$LogDirectory\Sys_Info.json"

    #Start performance capture
    Write-Host "Starting performance capture"
    Start-Job -Name "Performance_Capture" -ScriptBlock {
        param (
            $LogDirectory
        )
        $counters = "\Processor(_Total)\% Processor Time", "\Memory\% Committed Bytes in Use", "\Memory\Available MBytes", "\LogicalDisk(C:)\Current Disk Queue Length", "\LogicalDisk(C:)\Disk Reads/sec", "\LogicalDisk(C:)\Disk Writes/sec", "\Network Interface(*)\Bytes Received/sec", "\Network Interface(*)\Bytes Sent/sec", "\Network Interface(*)\Bytes Total/sec"
        Get-Counter -Continuous -SampleInterval 1 -Counter $counters | Export-Counter -Path "$LogDirectory\perfmon.csv" -FileFormat CSV -Force
    } -ArgumentList $LogDirectory

    #Loop through each test
    $results = foreach ($test in $($config.tests.psobject.Properties.name)) {
        #Create folder structures
        New-Item -Path $config.GlobalSettings.tempFolder -ItemType Directory -Force | Out-Null
        New-Item -Path $config.GlobalSettings.workingFolder -ItemType Directory -Force | Out-Null

        $templateFile = Create-File -fileSize $config.Tests.$test.fileSize -location $config.GlobalSettings.tempFolder
        $copyResult = Copy-Files -templateFile $templateFile -itemCopies $config.Tests.$test.numberOfFiles -workingFolder $config.GlobalSettings.workingFolder
        Write-Host "Copying $($config.Tests.$test.numberOfFiles) at $($config.Tests.$test.fileSize) size, took $copyResult (ms)"
        $ReadResult = Read-Files -workingFolder $config.GlobalSettings.workingFolder
        Write-Host "Reading $($config.Tests.$test.numberOfFiles) at $($config.Tests.$test.fileSize) size, took $ReadResult (ms)"
        $compressionResults = foreach ($compressionlevel in $(5, 7, 9)) {
            $compressResult = Run-Compression -action compress -location $config.GlobalSettings.workingFolder -compressionLevel 5
            Write-Host "Compressing $($config.Tests.$test.numberOfFiles) files at $($config.Tests.$test.fileSize) size, took $compressResult (ms) with $compressionlevel compression level"
            $decompressResult = Run-Compression -action decompress -location $config.GlobalSettings.workingFolder
            Write-Host "Decompressing $($config.Tests.$test.numberOfFiles) files at $($config.Tests.$test.fileSize) size, took $decompressResult (ms) with $compressionlevel compression level"
            [PSCustomObject]@{
                compressLevel    = $compressionlevel
                compressResult   = $compressResult
                decompressResult = $decompressResult
            }
        }
        $cleanupResult = Remove-Folder -workingFolder $config.GlobalSettings.workingFolder
        $cleanupResult = $cleanupResult + $(Remove-Folder -workingFolder $config.GlobalSettings.tempFolder)

        Write-Host "Cleaning up all files after the test took $cleanupResult (ms)"

        [PSCustomObject]@{
            DateTime              = $(Get-Date).ToString("dd/MM/yyyy hh:mm:ss")
            File_Size             = $config.Tests.$test.fileSize
            Num_Files             = $config.Tests.$test.numberOfFiles
            Copy                  = $copyResult
            Read                  = $ReadResult
            Compression_Normal    = $compressionResults | Where-Object { $_.compressLevel -eq 5 } | Select-Object -ExpandProperty compressResult
            Decompression_Normal  = $compressionResults | Where-Object { $_.compressLevel -eq 5 } | Select-Object -ExpandProperty decompressResult
            Compression_Maximum   = $compressionResults | Where-Object { $_.compressLevel -eq 7 } | Select-Object -ExpandProperty compressResult
            Decompression_Maximum = $compressionResults | Where-Object { $_.compressLevel -eq 7 } | Select-Object -ExpandProperty decompressResult
            Compression_Ultra     = $compressionResults | Where-Object { $_.compressLevel -eq 9 } | Select-Object -ExpandProperty compressResult
            Decompression_Ultra   = $compressionResults | Where-Object { $_.compressLevel -eq 9 } | Select-Object -ExpandProperty decompressResult
            Cleanup               = $cleanupResult
        }
    }
    Write-Host "All tests completed"

    #Stop performance capture
    Write-Host "Stopping performance capture"
    Get-Job -Name Performance_Capture  | Stop-Job | Receive-Job | Remove-Job

    Start-Sleep -Seconds 30

    if (!(Test-Path $LogDirectory)) { New-Item -Path $LogDirectory -ItemType Directory | Out-Null }
    $results | Export-Csv -Path "$LogDirectory\timings.csv" -NoTypeInformation

} catch {
    $_ | Out-File "$InstallDirectory\ERRORS.log"
}

# Zip the Log Directory
$zipFile = $InstallDirectory + "\Results_$timestamp.zip"
Start-Zip -SourcePath $LogDirectory -ZipFile $zipFile -overwrite $true

# Upload the content
$blobName = "Results_$($Env:COMPUTERNAME)_$timestamp.zip"
Set-AzStorageBlobContent -Container $containerResultsName -File $zipFile -Blob $blobName -Context $ctxResults -Force -ErrorAction SilentlyContinue

# Clean up
Remove-Item -Path $zipFile
Remove-Item -Path $LogDirectory -Recurse
Remove-Item -Path $InstallDirectory -Recurse

Stop-Transcript