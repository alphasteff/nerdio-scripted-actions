#name: Image Documentation
#description: This script is used to document the image configuration.
#execution mode: Combined
#tags: baseVISION

<# Notes:
########################################################
  Creates a documentation of the current installed OS
  and sets a few TS Variables
  If the script will be runned on a workgroup machine
  You need first to map the WIMTargetLocation with a
  With a user which has the right to write to the location

  ImageVersion = 001
  OSName = Microsoft Windows 7 Enterprise
  OSVersion = 6.1.7601
  OSLanguage = ML, EN, DE, IT, FR
  OSArchitecture = x86 or x64
  OSMUILanguages = en-US, de-DE...
  WimFilename = Windows7Enterprise_6.1.7601_office_EN_x86_001

  Author: Thomas Kurth/baseVISON
  Date:   10.5.2012
  Description: The following TS Vars are set

  History
        001: First Version
        002: Bugfixing, Version Number Length was not 3
        003: Add Application Section
        004: Bugfixing Installed Updates, Logging to Status Messages
        007: Language not as ML recognized for old image comparison
        008: Logging of Scripts Added
        009: SCCM Agent Version auslesen
        010: Installed Metro Apps
        011: netCIM Ready
        012: Write Documentation Path to Console and Log
        013: Add Remove Entries are now listed when no Launcher Apps found, Changes for MDT Environment
        014: Windows Capabilities und Package Launcher protokollieren
        015: Wechsel von ImageTypeID zu ID
        016: Applications which are not installed with a Launcher are also displayed in the Documentation
        017: Added MD5 Value: Line
        018: Bugfixing Feature Caption is sometimes null, then is now the Name displayed.
        019: [string]::IsNullOrWhiteSpace() Method is unknown in Windows 7, Therefore added Is-StringNullOrEmpty
        020: Add and Remove Programs Gets now writen all the Time even if Launcher Tool was found. Changed Dokumentation to Documentation in the Header.
        021: Changed the Feature Documentation so that it Contains the Feature Name in addition the Caption and the Install State. Feature Request by J. Wall
        022: Added List of the Applications form WimAsAService with there Commandline and Returncode. Feature Request by J. Wall
             Changed Runned Scripts and Metro Apps Output to Tabell
             Added List of all Modern Apps
        023: Made that the Build Number is writen including the Update Version
        024: Added "Image Size: " placeholder to Documentation
        025: If the baseWIM is a Server Core ad it to the WIM Name
        026: Fixed some writing errors and made the formatting more consistent
        027: Fix the Copy-Item Image Documentation Destination Path for the local rename
        028: Fix Version counting issue for Server CoreVersions due to wrong value in OSVersion cariable
        029: Extend for Azure Image creation with Nerdio


########################################################
#>

$ScriptVersion = "029"

$AzureImage = $true
$Debug = $false
$DocumentationFilePath = "C:\Windows\Logs\ImageDocumentation.txt"
$LogFilePath = "C:\Windows\Logs\ImageDocumentation_" + (Get-Date -UFormat %Y%m%d%H%M) + ".log"
$WIMTargetLocation = "C:\Windows\Logs\" # For Automated Documentation in SCCM Change to NetworkPath of WIM Files

function translateLanguageCode($lcid) {
    switch ($lcid) {
        1033 { $language = "EN" }
        1031 { $language = "DE" }
        1036 { $language = "FR" }
        1040 { $language = "IT" }
        default { $language = "Unknown LCID " + $lcid }
    }
    return $language
}
function writeLog($Text) {
    Out-File -FilePath $LogFilePath -Force -Append -InputObject ((Get-Date -f o) + "        " + $Text)
    Write-Host $Text
}
function CreateFolder ([string]$Path) {

    # Check if the folder Exists

    if (Test-Path $Path) {
        WriteLog "Folder: $Path Already Exists"
    } else {
        WriteLog "Creating $Path"
        New-Item -Path $Path -type directory | Out-Null
    }
}
function Is-StringNullOrEmpty {
    param($string)
    return ($string -eq $null -or $string -eq "")
}

#CreateFolder "C:\Windows\Logs\SCCM"

writeLog "Start Document WIM Script"
try {
    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
} catch {}
If ($Debug -eq $false -and $tsenv -ne $null) {
    $Tenant = $tsenv.Value("TenantShortName")
    $ImageType = $tsenv.Value("ID")
    $WIMTargetLocation = $tsenv.Value("ComputerBackupLocation")
} else {
    $Tenant = "Global"
    $ImageType = "base"
    writeLog "Start without TS Environment"
}

# Get next WIM Version
writeLog "Search for existing WIM File"

$OSName = ((((Get-WmiObject -Class Win32_OperatingSystem ).Caption -replace " ", "") -replace "Microsoft", "") -replace "®", "")
If ((Test-Path "$env:windir\explorer.exe") -eq $false) {
    $OSName = $OSName + "Core"
}
$OSVersion = (Get-WmiObject -Class Win32_OperatingSystem ).Version
$OSLanguage = (translateLanguageCode((Get-WmiObject -Class Win32_OperatingSystem ).OSLanguage))
If (((Get-WmiObject -Class Win32_OperatingSystem ).OSArchitecture) -match "64") {
    $OSArchitecture = "x64"
} else {
    $OSArchitecture = "x86"
}

$MUILanguage = (Get-WmiObject -Class Win32_OperatingSystem ).MUILanguages
writeLog ("Count of Languages found: " + $MUILanguage.Count)
If ($MUILanguage.Count -gt 1) {
    $OSLanguage = "ML"
    foreach ($language in $MUILanguage) {
        $MUILanguageString = $language + " " + $MUILanguageString
    }
}
$ImageVersion = "000"
foreach ($WmiFile in (Get-ChildItem $WIMTargetLocation | where { $_.extension -eq ".txt" })) {
    #writeLog $WmiFile.Name
    If ($WmiFile.Name) {
        #writeLog ("Found WIM Doc: " + $WmiFile.Name)
        writeLog ("Found WIM Doc")

        $NameParts = $WmiFile.Name.split("_")
        If ($NameParts.Count -eq 7) {
            If ($NameParts[0] -eq $Tenant -and $NameParts[1] -eq $ImageType -and $NameParts[2] -eq $OSName -and $NameParts[3] -eq $OSVersion -and $NameParts[4] -eq $OSLanguage -and $NameParts[5] -eq $OSArchitecture) {
                $TempVersion = ($NameParts[6] -replace ".txt")
                writeLog ("WIM Doc of the same Type, Version detected: " + $TempVersion)
                If (([int]$TempVersion) -gt ([int]$ImageVersion)) { $ImageVersion = $TempVersion }
            } else {
                writeLog ("WIM Doc not of the same Type")
            }
        } else {
            writeLog ("WIM Doc not Naming Convention compliant")
        }
    }
}
$ImageVersion = (([int]$ImageVersion) + 1)
$ImageVersion = [string]$ImageVersion
switch ($ImageVersion.Length) {
    0 { $ImageVersion = "000" }
    1 { $ImageVersion = "00" + $ImageVersion }
    2 { $ImageVersion = "0" + $ImageVersion }
}

# Create Documentation
writeLog "Start create Doc and evaluate values for TS"

Out-File -FilePath $DocumentationFilePath -Force -InputObject "##########################################################"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "##########################################################"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "##                                                      ##"                                  ##"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "## OSD Image Documentation                              ##"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "##                                                      ##"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "##########################################################"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "##########################################################"

writeLog "WIM Image Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### WIM Image ###"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Tenant: " + $Tenant)
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Image Type: " + $ImageType)
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Image Version: " + $ImageVersion)
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Image Creation Date: " + (Get-Date -Format g))
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Image Size:")
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("MD5 Value:")

writeLog "Operating System Documentation"

$Key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$Build = Get-ItemPropertyValue -Path $Key -Name CurrentBuild
$UBR = Get-ItemPropertyValue -Path $Key -Name UBR
$ReleaseID = Get-ItemPropertyValue -Path $Key -Name ReleaseID
$OSBuild = $OSVersion.Replace($Build, $Build + "." + $UBR)

Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Operating System ###"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Name: " + (Get-WmiObject -Class Win32_OperatingSystem ).Caption)
If ($ReleaseID) {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("ReleaseID: " + $ReleaseID)
}
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Version: " + $OSBuild)
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "Architecture: $OSArchitecture"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Language: " + $OSLanguage)
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Installed MUI Packs: " + $MUILanguage)

If ($AzureImage) { Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("RefImageBuild: " + $Env:RefImageBuild) }

writeLog "SCCM Agent Documentation"
$SCCMVersion = (Get-WmiObject -Namespace root\ccm -Class SMS_Client -ErrorAction SilentlyContinue)
$SCCMCacheSize = (Get-WmiObject -Namespace root\ccm\SoftMgmtAgent -Class CacheConfig -ErrorAction SilentlyContinue)
if ($SCCMVersion -ne $null) {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### SCCM Agent ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("Version: " + $SCCMVersion.ClientVersion)
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ("CacheSize: " + $SCCMCacheSize.size)
}

writeLog "Windows Feature Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Windows Features ###"
if ($OSVersion -eq "6.0.6002") {
    # Server 2008
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "The following Features are installed:"
    Get-WmiObject -Class Win32_ServerFeature | ft Name | Out-File -FilePath $DocumentationFilePath -Force -Append
} else {
    # Anything Else
    Get-WmiObject -Class Win32_OptionalFeature | Sort-Object $_.Name | ft @{LABEL = "Name"; EXPRESSION = { $_.Name } }, @{LABEL = "Caption"; EXPRESSION = { $_.Caption } } , @{LABEL = "State"; EXPRESSION = { If ($_.InstallState -eq 1) { "Installed" } else { "Not Installed" } } } | Out-File -FilePath $DocumentationFilePath -Force -Append
}

writeLog "Windows Capabilities Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Windows Capabilities ###"
try {
    $Capabilities = $null
    $Capabilities = Get-WindowsCapability -Online | where { $_.State -Match "Installed" }
} catch {}
If ($Capabilities) {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "The following Capabilities are installed:"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    WriteLog ("Found " + $Capabilities.count + " Capabilities")

    Foreach ($Capability in $Capabilities) {
        Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $Capability.Name.ToString()
        WriteLog ($Capability.Name)
    }
} else {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "Found no installed Capabilities"
    WriteLog ("Found no installed Capabilities")

}

writeLog "Start Installed Applications Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

# Installed Applications (Launcher Keys)
WriteLog "Get Installed Applications (Launcher Keys)"
If (Test-Path "HKLM:\Software\_Custom\Apps") {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Applications (netECM:Launcher) ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    $Applications = Get-ChildItem "HKLM:\Software\_Custom\Apps"
    $AppList = ""
    $appname = ""
    foreach ($app in $Applications) {
        If ((Get-ItemProperty $app.pspath).LastAction -eq "Install") {
            $AppStatus = "" + $app.PSChildName + "			" + (Get-ItemProperty $app.pspath).LastActionStatus
            Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $AppStatus
        }
    }
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

} elseif (Test-Path "HKLM:\SOFTWARE\Real Packaging\Package-Launcher\Packages") {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Applications (Real Packaging Launcher) ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    WriteLog "Application Keys Found."
    $Applications = Get-ChildItem "HKLM:\SOFTWARE\Real Packaging\Package-Launcher\Packages"
    $AppList = ""
    $appname = ""
    foreach ($app in $Applications) {
        If ((Get-ItemProperty $app.pspath).Revision -ge "001") {
            $AppStatus = "" + $app.PSChildName + " / " + (Get-ItemProperty $app.pspath).Revision + " / " + (Get-ItemProperty $app.pspath).Status
            Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $AppStatus
        }
    }
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

} elseif (Test-Path "HKLM:\SOFTWARE\Wow6432Node\Real Packaging\Package-Launcher\Packages") {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Applications (Real Packaging Launcher) ###"
    WriteLog "Application Keys Found."
    $Applications = Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Real Packaging\Package-Launcher\Packages"
    $AppList = ""
    $appname = ""
    foreach ($app in $Applications) {
        If ((Get-ItemProperty $app.pspath).Revision -ge "001") {
            $AppStatus = "" + $app.PSChildName + " / " + (Get-ItemProperty $app.pspath).Revision + " / " + (Get-ItemProperty $app.pspath).Status
            Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $AppStatus
        }
    }
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

} else {
    WriteLog "No Launcher Application Keys Found."
}

WriteLog "Start Add and Remove Programs"

Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Applications from Add and Remove Programs###"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
#Retrieve an array of string that contain all the subkey names

$subkeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
$subkeys += Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue


#Open each Subkey and use GetValue Method to return the required values for each
foreach ($key in $subkeys) {
    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($key.GetValue("DisplayName"))
    $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($key.GetValue("DisplayVersion"))
    $obj | Add-Member -MemberType NoteProperty -Name "Architecture" -Value $(if ($key.PSPath -match "Wow6432Node") { "x86" } else { "x64" })
    if (-not (Is-StringNullOrEmpty -string $obj.DisplayName)) {
        $AppStatus = "$($obj.DisplayName) $($obj.DisplayVersion) ($($obj.Architecture))"
        Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $AppStatus
    }
}

writeLog "Start ZTIApplications.log"



$ZTIApplicationsLog = "C:\MININT\SMSOSD\OSDLOGS\ZTIApplications.log"

If (Test-Path -Path $ZTIApplicationsLog) {
    writeLog "Found the File $ZTIApplicationsLog"

    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Apps from WimAsAService ImageType (In Order of Installation) ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

    $LogStringsAppNames = Select-String -Path $ZTIApplicationsLog -Pattern "<![LOG[Name:  " -AllMatches -SimpleMatch
    $LogStringsCommandLines = Select-String -Path $ZTIApplicationsLog -Pattern "<![LOG[About to run command: " -AllMatches -SimpleMatch
    $LogStringsReturnCodes = Select-String -Path $ZTIApplicationsLog -Pattern "<![LOG[Return code from command = " -AllMatches -SimpleMatch

    If ($LogStringsAppNames.Count -gt 0) {
        writeLog ("Found the String we searched for in the File " + $LogStringsAppNames.Count + " Times")

        If (($LogStringsAppNames.Count -eq $LogStringsCommandLines.Count) -and ($LogStringsReturnCodes.Count -eq $LogStringsCommandLines.Count)) {
            $Runs = $LogStringsAppNames.Count
            $Counter = 0
            $AppResults = @()

            Do {
                #AppName
                [String]$AppName = $LogStringsAppNames[$counter]
                $Prefix = "[LOG[Name:  "
                $Sufix = "]LOG]"
                $ExtractedAppName = $AppName.substring($AppName.indexof($Prefix) + $Prefix.Length , $AppName.indexof($Sufix) - ($AppName.indexof($Prefix) + $Prefix.Length ))

                #CommandLine
                [String]$CommandLine = $LogStringsCommandLines[$counter]
                $Prefix = "bddrun.exe "
                $Sufix = "]LOG]"
                $ExtractedCommandLine = $CommandLine.substring($CommandLine.indexof($Prefix) + $Prefix.Length , $CommandLine.indexof($Sufix) - ($CommandLine.indexof($Prefix) + $Prefix.Length ))

                #ReturneCode
                [String]$ReturnCode = $LogStringsReturnCodes[$counter]
                $Prefix = "[LOG[Return code from command = "
                $Sufix = "]LOG]"
                $ExtractedReturnCode = $ReturnCode.substring($ReturnCode.indexof($Prefix) + $Prefix.Length , $ReturnCode.indexof($Sufix) - ($ReturnCode.indexof($Prefix) + $Prefix.Length ))

                $object = New-Object -TypeName PSObject
                $object | Add-Member -MemberType NoteProperty -Name AppName -Value $ExtractedAppName
                $object | Add-Member -MemberType NoteProperty -Name CommandLine -Value $ExtractedCommandLine
                $object | Add-Member -MemberType NoteProperty -Name ReturnCode -Value $ExtractedReturnCode

                $AppResults += $object

                $counter = $counter + 1

            }Until($Runs -eq $Counter )
        } else {
            writeLog "Count of the apperences of the Different Lines doesn't Match"
        }

        #Write to Ducumentation
        $AppResults | Format-Table -AutoSize | Out-String -Width 5000 | Out-File -FilePath $DocumentationFilePath -Force -Append
    } else {
        writeLog "Found no Line in the File that contains the string we searched for."
        Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "No apps were installed through WimAsAService"
    }
} else {
    writeLog "Couldnot find the File $ZTIApplicationsLog"
}


writeLog "Start Installed Metro Applications Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Metro Applications ###"
WriteLog "Get Installed Metro Applications "
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### AppxProvisionedPackage (Gets installed the first time a user logs on) ###"
try {
    $Applications = $null
    $Applications = Get-AppxProvisionedPackage -Online
} catch {}
If ($Applications -ne $null) {
    $Applications | Select-Object -Property DisplayName, Version | Sort-Object -Property DisplayName | Format-Table -AutoSize | Out-String -Width 5000 | Out-File -FilePath $DocumentationFilePath -Force -Append
} else {
    writeLog "No AppxProvisionedPackage Found."
}

Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### AppXPackage ###"
try {
    $AppxPackage = $null
    $AppxPackage = Get-AppxPackage
} catch {}
If ($AppxPackage -ne $null) {
    $AppxPackage | Select-Object -Property Name, Version | Sort-Object -Property Name | Format-Table -AutoSize | Out-String -Width 5000 | Out-File -FilePath $DocumentationFilePath -Force -Append
} else {
    writeLog "No AppxPackage Found."
}

If (!$AzureImage) {
    writeLog "Runned Script Documentation"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Runned Scripts ###"
    WriteLog "Get Runned Scripts"
    If (Test-Path "HKLM:\Software\_Custom\Scripts") {
        $Scripts = Get-ChildItem "HKLM:\Software\_Custom\Scripts"
        $ScriptStatus = @()
        foreach ($Script in $Scripts) {
            $ExitMessage = (Get-ItemProperty $Script.pspath).ExitMessage
            $object = New-Object -TypeName PSObject
            $object | Add-Member -MemberType NoteProperty -Name ScriptName -Value $Script.PSChildName
            $object | Add-Member -MemberType NoteProperty -Name ExitMessage -Value $ExitMessage
            $ScriptStatus += $object
        }
        $ScriptStatus | Format-Table -AutoSize | Out-String -Width 5000 | Out-File -FilePath $DocumentationFilePath -Force -Append
    } else {
        WriteLog "No Runned Scripts Found."
    }
}

writeLog "Installed Updates Documentation"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Installed Updates ###"
Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
#$UpdateSession = New-Object -ComObject Microsoft.Update.Session
#$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
#$SearchResult = $UpdateSearcher.Search("IsInstalled=1")
#foreach($Update in $SearchResult.Updates)
#{
#    Out-file -FilePath $DocumentationFilePath -force -append -InputObject $Update.Title
#}

$wusearcher = New-Object -com "Microsoft.Update.Searcher"
$totalupdates = $wusearcher.GetTotalHistoryCount()
$results = $wusearcher.QueryHistory(0, $totalupdates)
$SearchResult = ($results | where { $_.ResultCode -eq '2' } | select Title)
foreach ($Update in $SearchResult) {
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $Update.Title
}

If (!$AzureImage) {
    writeLog "Excluded Updates Documentation"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Excluded Updates ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

    $ExcludedKBs = ($tsenv.Value("ExcludeKB") -replace " ", "").ToUpper()
    if ($ExcludedKBs -ne $null -or $ExcludedKBs.Replace(" ", "") -ne "") {
        $ExcludedKBs = $ExcludedKBs.Split(",")
        [Array]$PureExclusions = $null

        $DeploymentShare = $tsenv.Value("DeployRoot")
        $GlobalKBExcludeListFile = "CustomGlobalKBsToExclude.txt"
        $GloballyExcluded = (Get-Content "$DeploymentShare\Scripts\$GlobalKBExcludeListFile").ToUpper()
        foreach ($KB in $ExcludedKBs) {
            if ($KB -notlike "KB*") {
                $KB = "KB" + $KB
            }
            if ($GloballyExcluded -notlike "*$KB*") {
                $PureExclusions += $KB
            }
        }
        if ($PureExclusions -ne $null) {
            foreach ($entry in $PureExclusions) {
                Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $entry
            }
        } else {
            Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "Nothing was excluded"
        }

    } else {
        Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "Nothing was excluded"
    }


    writeLog "Globally Excluded Updates Documentation"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Globally Excluded Updates ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

    $DeploymentShare = $tsenv.Value("DeployRoot")
    $GlobalKBExcludeListFile = "CustomGlobalKBsToExclude.txt"
    $GloballyExcluded = (Get-Content "$DeploymentShare\Scripts\$GlobalKBExcludeListFile").ToUpper()
    if ($GloballyExcluded -ne $null -or $GloballyExcluded.Replace(" ", "") -ne "") {
        $GloballyExcluded = $GloballyExcluded.Split(",")
        foreach ($GExclude in $GloballyExcluded) {
            Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject $GExclude
        }
    } else {
        Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "No global exclusions found"
    }
}

If (Test-Path 'HKLM:\SOFTWARE\VDOT') {
    writeLog "Installed VDOT Documentation"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "### Windows Virtual Desktop Optimization Tool (VDOT) ###"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject ""

    $VDOT_LastRunTime = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\VDOT' -Name 'LastRunTime'
    $VDOT_Version = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\VDOT' -Name 'Version'

    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "VDOT LastRunTime: $VDOT_LastRunTime"
    Out-File -FilePath $DocumentationFilePath -Force -Append -InputObject "VDOT Version: $VDOT_Version"
}

$Filename = $Tenant + "_" + $ImageType + "_" + $OSName + "_" + $OSVersion + "_" + $OSLanguage + "_" + $OSArchitecture + "_" + $ImageVersion

writeLog ("Filename used: " + $Filename)
writeLog "Renaming Documentation"


Copy-Item -Path $DocumentationFilePath -Destination $DocumentationFilePath.Replace("ImageDocumentation", $Filename) -Force
Copy-Item $DocumentationFilePath ($WIMTargetLocation + "\" + $Filename + ".txt") -Force

If (!$AzureImage) {
    If ($Debug -eq $false -and $tsenv -ne $null) {
        writeLog "SET TS Variables"
        $tsenv.Value("ImageVersion") = $ImageVersion
        $tsenv.Value("OSName") = $OSName
        $tsenv.Value("OSVersion") = $OSVersion
        $tsenv.Value("OSLanguage") = $OSLanguage
        $tsenv.Value("OSArchitecture") = $OSArchitecture
        $tsenv.Value("OSMUILanguages") = $MUILanguageString
        $tsenv.Value("BackupFile") = "$Filename.wim"
    }
}
WriteLog "Documentation written to $DocumentationFilePath"
writeLog "Ending Script"
