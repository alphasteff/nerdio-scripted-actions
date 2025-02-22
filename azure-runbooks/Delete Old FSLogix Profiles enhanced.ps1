﻿#name: Delete Old FSLogix Profiles enhanced
#description: Deletes FSlogix .vhd(x) files older than specified days and removes any empty directories in the specified Azure Files share.
#tags: beckmann.ch, FSLogix

<# Variables:
{
  "ResourceGroupName": {
    "Description": "Name of the Resource Group.",
    "IsRequired": true
  },
  "StorageAccountName": {
    "Description": "Name of the Azure Storage Account.",
    "IsRequired": true
  },
  "ShareName": {
    "Description": "Name of the Azure Files share.",
    "IsRequired": true
  },
  "DaysOld": {
    "Description": "Age of files to check for deletion.",
    "IsRequired": true
  },
  "StorageKeySecureVar": {
    "Description": "Secure variable containing the storage account key. Make sure this secure variable is passed to this script. If not available, the Nerdio Service Principal is used.",
    "IsRequired": false
  },
  "WhatIf": {
    "Description": "If set to true, no changes will be made",
    "Type": "bool",
    "IsRequired": true,
    "DefaultValue": true
  }
}
#>

$ErrorActionPreference = 'Stop'

If ($WhatIf -eq $false) {
    Write-Output "WhatIf is set to false, changes will be made"
} ElseIf ($WhatIf -eq $true) {
    Write-Output "WhatIf is set to true, no changes will be made"
} Else {
    Write-Output "WhatIf is not set to true or false, no changes will be made"
    Exit
}

function New-BesAzureFilesSASToken {
    param (
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$FileShareName,
        [string]$Permissions = "rwdl", # Read, write, delete and list permissions
        [int]$TokenLifeTime = 60 # Token lifetime in minutes
    )

    begin {
        $date = Get-Date
        $actDate = $date.ToUniversalTime()
        $expiringDate = $actDate.AddMinutes($TokenLifeTime )
        $expiringDate = (Get-Date $expiringDate -Format 'yyyy-MM-ddTHH:mm:ssZ')
    }

    process {
        # Retrieve storage account key
        $storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value

        # Create storage context
        $storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageAccountKey

        # Create SAS token
        $sasToken = New-AzStorageShareSASToken -Context $storageContext -ShareName $FileShareName -Permission $Permissions -ExpiryTime $expiringDate
    }

    end {
        return $sasToken
    }
}

If ($StorageKeySecureVar) {
    # Create a new storage context using the storage account key
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKeySecureVar
    Write-Output "Storage Account Connected"
} Else {
    # Get the current Azure context
    $azContext = Get-AzContext

    # Write the current Azure context to the output
    Write-Output "Current Azure Subscription: $($azContext.Subscription.Name)"
    Write-Output "Current Azure Tenant: $($azContext.Tenant.Id)"
    Write-Output "Current Azure Account: $($azContext.Account.Id)"

    # Create a new SAS token for the storage account
    $sasToken = New-BesAzureFilesSASToken -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -FileShareName $ShareName
    Write-Output ("SAS Token: " + $sasToken.Substring(0, 70) + "...")

    # Create a new storage context using the SAS token
    $StorageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken
    Write-Output "Storage Account Connected"
}

$Dirs = $StorageContext | Get-AzStorageFile -ShareName "$ShareName"  | Where-Object { $_.GetType().Name -eq "AzureStorageFileDirectory" }
Write-Verbose "Directories in $ShareName"
$Dirs | ForEach-Object { Write-Verbose $_.Name }

# Get files from each directory, check if older than $DaysOld, delete it if it is
foreach ($dir in $Dirs) {
    $Files = Get-AzStorageFile -ShareName "$ShareName" -Path $dir.Name -Context $StorageContext | Get-AzStorageFile
    foreach ($file in $Files) {
        # check if file is not .vhd, if so, skip and move to next iteration
        if ($file.Name -notmatch '\.vhd') {
            Write-Output "$($file.Name) is not a VHD file, skipping..."
            continue
        }
        # get lastmodified property using Get-AzStorageFile; if lastmodified is older than $DaysOld, delete the file
        $File = Get-AzStorageFile -ShareName "$ShareName" -Path $($dir.name + '/' + $file.Name) -Context $StorageContext
        $LastModified = $file.LastModified.DateTime
        $DaysSinceModified = (Get-Date) - $LastModified
        if ($DaysSinceModified.Days -gt $DaysOld) {
            Write-Output "$($file.Name) is older than $DaysOld days, deleting..."
            If ($WhatIf -eq $false) {
                $File | Remove-AzStorageFile
            }
        } else {
            Write-Output "$($file.Name) is not older than $DaysOld days, skipping..."
        }
    }
    # if directory is now empty, delete it
    $Files = Get-AzStorageFile -ShareName "$ShareName" -Path $dir.Name -Context $StorageContext | Get-AzStorageFile
    if ($Files.Count -eq 0) {
        Write-Output "$($dir.Name) is empty, deleting..."
        If ($WhatIf -eq $false) {
            Remove-AzStorageDirectory -Context $StorageContext -ShareName "$ShareName" -Path $dir.name
        }
    }
}
