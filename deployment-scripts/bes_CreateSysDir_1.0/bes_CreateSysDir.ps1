$runingScriptName = 'bes_CreateSysDir'
$logFile = Join-Path -path $env:InstallLogDir -ChildPath "$runingScriptName-$(Get-date -f 'yyyy-MM-dd').log"

$paramSetPSFLoggingProvider = @{
    Name         = 'logfile'
    InstanceName = $runingScriptName
    FilePath     = $logFile
    FileType     = 'CMTrace'
    Enabled      = $true
}
If (!(Get-PSFLoggingProvider -Name logfile).Enabled){$Null = Set-PSFLoggingProvider @paramSetPSFLoggingProvider}

# Default Parameters
Write-PSFMessage -Level Host -Message ("Start " + $runingScriptName)

[string]$Script:ScriptPath = $PSScriptRoot

Function Add-BesEnvVar {
    param(
        [string]$envVarName,
        [string]$envVarValue,
        [bool]$specialFolder,
        [bool]$addToPath
    )
    If ($specialFolder){
        $specialFolders = @{}
        $sfNames = [Environment+SpecialFolder]::GetNames([Environment+SpecialFolder])
        Foreach ($sfName in $sfNames){
            If ($sfPath = [Environment]::GetFolderPath($sfName)){
                $specialFolders[$sfName] = $sfPath
            }
        }
        $envVarValue = $specialFolders.$envVarValue
        Write-PSFMessage -Level Host -Message "$envVarName = $envVarValue"
        $Null = [Environment]::SetEnvironmentVariable($envVarName, $envVarValue, "Machine")
		
    } Else {
        If ($envVarName -eq "Sys"){
            $envVarName = $envVarName.ToUpper() + "Dir"
        }ElseIf (($envVarName -eq "Bin") -or ($envVarName -eq "Data") -or ($envVarName -eq "Install")){
            $envVarName = $envVarName.ToUpper() + "DIR"
        }ElseIf (($envVarName -eq "Scripts") -or ($envVarName -eq "Logs") -or ($envVarName -eq "Icons") -or ($envVarName -eq "Links")){
            $envVarName = ($envVarName.TrimEnd("s")).ToUpper() + "Dir"
        }
        Write-PSFMessage -Level Host -Message "$envVarName = $envVarValue"
        $Null = [Environment]::SetEnvironmentVariable($envVarName, $envVarValue, "Machine")
    }
	
    If ($addToPath -eq $True){
        $Null = [Environment]::SetEnvironmentVariable("Path", ([environment]::GetEnvironmentVariable("Path", "Machine") + ";" + $envVarValue), "Machine")
    }
}

Function Add-BesFolders {
    param(
        [string]$folderPath,
        [bool]$createEnvVar,
        [bool]$addToPath
    )
    If (!(Test-Path $folderPath)){
        $Null = New-Item -Path $folderPath -ItemType Directory
    }
	
    If ($createEnvVar){
        $Null = Add-BesEnvVar -envVarName (Split-Path $folderPath -Leaf) -envVarValue $folderPath -CreateEnvVar $createEnvVar -AddToPath $addToPath
    }
}

Function Copy-BesFolders {
    param(
        [string]$sourcePath,
        [string]$destinationPath,
        [bool]$createEnvVar,
        [bool]$addToPath
    )

    $sourcePath = $scriptPath + "\" + $sourcePath
    If (Resolve-Path $sourcePath){
        If (Test-Path $sourcePath){
            If (!(Test-Path $destinationPath)){
                $Null = New-Item -Path $destinationPath -ItemType directory
            }

            $Null = Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
			
            If ($createEnvVar){
                $Null = Add-BesEnvVar -EnvVarName (Split-Path $sourcePath -Leaf) -EnvVarValue (Join-Path -Path $destinationPath (Split-Path $sourcePath -Leaf)) -CreateEnvVar $createEnvVar -AddToPath $addToPath
            }
        }
    }
}

Write-PSFMessage -Level Host -Message 'Create Folders'
$csvDump = Import-Csv -Path "$ScriptPath\create-folders.csv" -Delimiter ";"

Foreach ($f in $csvDump){
	
  If ($f.CreateEnvVar -eq "False"){
    [bool]$f.CreateEnvVar = $false
  }ElseIf ($f.CreateEnvVar -eq "True"){
    [bool]$f.CreateEnvVar = $true
  }
	
  If ($f.AddToPath -eq "False"){
    [bool]$f.AddToPath = $false
  }ElseIf ($f.AddToPath -eq "True"){
    [bool]$f.AddToPath = $true
  }
	
  $Null = Add-BesFolders -FolderPath $f.FolderPath -CreateEnvVar $f.CreateEnvVar -AddToPath $f.AddToPath
	
}

Write-PSFMessage -Level Host -Message 'Copy Folder Content'
$csvDump = Import-Csv -Path "$ScriptPath\copy-folders.csv" -Delimiter ";"

Foreach ($f in $csvDump){
	
  If ($f.CreateenvVar -eq "False"){
    [bool]$f.CreateEnvVar = $false
  }ElseIf ($f.CreateEnvVar -eq "True"){
    [bool]$f.CreateEnvVar = $true
  }
	
  If ($f.AddToPath -eq "False"){
    [bool]$f.AddToPath = $false
  }ElseIf ($f.AddToPath -eq "True"){
    [bool]$f.AddToPath = $true
  }

  $Null = Copy-BesFolders -SourcePath $f.SourcePath -DestinationPath $f.DestinationPath -CreateenvVar $f.CreateenvVar -AddToPath $f.AddToPath
	
}

Write-PSFMessage -Level Host -Message 'Create Variables'
$csvDump = Import-Csv -Path "$ScriptPath\create-envVars.csv" -Delimiter ";"

Foreach ($f in $csvDump){
	
  If ($f.SpecialFolder -eq "False"){
    [bool]$f.SpecialFolder = $false
  }ElseIf ($f.SpecialFolder -eq "True"){
    [bool]$f.SpecialFolder = $true
  }
	
  If ($f.AddToPath -eq "False"){
    [bool]$f.AddToPath = $false
  }ElseIf ($f.AddToPath -eq "True"){
    [bool]$f.AddToPath = $true
  }

  $Null = Add-BesEnvVar -EnvVarName $f.envVarName -EnvVarValue $f.envVarValue -SpecialFolder $f.SpecialFolder -AddToPath $f.AddToPath
	
}

# Secure Sys Path
Write-PSFMessage -Level Host -Message "Secure Sys Path"
If (!(Test-Path "$Env:SystemDrive\Sys")) {
    Write-PSFMessage -Level Host -Message ( 'Sys Ordner absichern' )
    icacls C:\Sys /inheritance:d
    icacls C:\Sys /remove "CREATOR OWNER"
    icacls C:\Sys /remove "Users"
    icacls C:\Sys /grant:r "Users:(OI)(CI)RX"
}

Write-PSFMessage -Level Host -Message ("Stop " + $runingScriptName)

Stop-PSFRunspace
