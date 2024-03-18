<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

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
        Write-Log -Message "Add Environment Variable: $envVarName = $envVarValue" -Severity 1 -Source $deployAppScriptFriendlyName
        $Null = [Environment]::SetEnvironmentVariable($envVarName, $envVarValue, "Machine")
		
    } Else {
        If ($envVarName -eq "Sys"){
            $envVarName = $envVarName.ToUpper() + "Dir"
        }ElseIf (($envVarName -eq "Bin") -or ($envVarName -eq "Data") -or ($envVarName -eq "Install")){
            $envVarName = $envVarName.ToUpper() + "DIR"
        }ElseIf (($envVarName -eq "Scripts") -or ($envVarName -eq "Logs") -or ($envVarName -eq "Icons") -or ($envVarName -eq "Links")){
            $envVarName = ($envVarName.TrimEnd("s")).ToUpper() + "Dir"
        }
        Write-Log -Message "Add Environment Variable: $envVarName = $envVarValue" -Severity 1 -Source $deployAppScriptFriendlyName
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
        Write-Log -Message "Create folder: $folderPath" -Severity 1 -Source $deployAppScriptFriendlyName
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

    If (Resolve-Path $sourcePath){
        If (Test-Path $sourcePath){
            If (!(Test-Path $destinationPath)){
                Write-Log -Message "Create folder: $destinationPath" -Severity 1 -Source $deployAppScriptFriendlyName
                $Null = New-Item -Path $destinationPath -ItemType directory
            }

            Write-Log -Message "Copy folder from '$sourcePath' to '$destinationPath'" -Severity 1 -Source $deployAppScriptFriendlyName
            $Null = Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
			
            If ($createEnvVar){
                $Null = Add-BesEnvVar -EnvVarName (Split-Path $sourcePath -Leaf) -EnvVarValue (Join-Path -Path $destinationPath (Split-Path $sourcePath -Leaf)) -CreateEnvVar $createEnvVar -AddToPath $addToPath
            }
        }
    }
}

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'baseVISION'
	[string]$appName = 'CreateSysDir'
	[string]$appVersion = '1.0'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '20/01/2024'
	[string]$appScriptAuthor = 'Stefan Beckmann'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	## Define processes to close in a comma separated list
	[string]$processesToClose = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		if ($processesToClose -ne '' -and $processesToClose -ne $null){
			$processesToClose.Split(",").Replace(" ","") | ForEach-Object {if (Get-Process $_ -ErrorAction SilentlyContinue){$oneRunning = $true}}
		}
		if ($oneRunning){
			Show-InstallationWelcome -CloseApps $processesToClose -CheckDiskSpace -PersistPrompt
			Show-InstallationProgress -WindowLocation BottomRight
		}

		## Show Progress Message (with the default message)
		#Show-InstallationProgress -WindowLocation BottomRight

		## <Perform Pre-Installation tasks here>


		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
        #Create folders
		$csvDump = Import-Csv -Path "$scriptParentPath\SupportFiles\create-folders.csv" -Delimiter ";"
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

			Write-Log -Message ("Create Folder: " + $f.FolderPath) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Create EnvVar: " + $f.CreateEnvVar) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Add to Path  : " + $f.AddToPath) -Severity 1 -Source $deployAppScriptFriendlyName
			$Null = Add-BesFolders -FolderPath $f.FolderPath -CreateEnvVar $f.CreateEnvVar -AddToPath $f.AddToPath
		}

		#Copy Folder Content
		$csvDump = Import-Csv -Path "$scriptParentPath\SupportFiles\copy-folders.csv" -Delimiter ";"
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

            $sourcePath = Join-Path -Path $scriptParentPath -ChildPath $f.SourcePath

			Write-Log -Message ("Copy Folder: " + $f.DestinationPath) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Source Path  : " + $sourcePath) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Create EnvVar: " + $f.CreateEnvVar) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Add to Path  : " + $f.AddToPath) -Severity 1 -Source $deployAppScriptFriendlyName
			$Null = Copy-BesFolders -SourcePath $sourcePath -DestinationPath $f.DestinationPath -CreateenvVar $f.CreateenvVar -AddToPath $f.AddToPath
		}

		#Create Variables
		$csvDump = Import-Csv -Path "$scriptParentPath\SupportFiles\create-envVars.csv" -Delimiter ";"
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

			Write-Log -Message ("Create Variable: " + $f.envVarName) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Vaule        : " + $f.envVarValue) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - SpecialFolder: " + $f.SpecialFolder) -Severity 1 -Source $deployAppScriptFriendlyName
            Write-Log -Message ("  - Add to Path  : " + $f.AddToPath) -Severity 1 -Source $deployAppScriptFriendlyName
			$Null = Add-BesEnvVar -EnvVarName $f.envVarName -EnvVarValue $f.envVarValue -SpecialFolder $f.SpecialFolder -AddToPath $f.AddToPath	
		}

		# Secure Sys Path
		If (!(Test-Path "$Env:SystemDrive\Sys")) {
			# Set ACL to sys folder
			$folderPath = "$Env:SystemDrive\Sys"

			# Get the current ACL
			$acl = Get-Acl -Path $folderPath

			# Disable inheritance and remove inherited permissions
			$acl.SetAccessRuleProtection($true, $false)
			$acl.Access | ForEach-Object {
				$acl.RemoveAccessRule($_)
			}

			# Create custom ACL rules with inheritance flags
			$administratorsRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
				"Administrators",
				"FullControl",
				"ContainerInherit,ObjectInherit",
				"None",
				"Allow"
			)
			$usersRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
				"Users",
				"ReadAndExecute",
				"ContainerInherit,ObjectInherit",
				"None",
				"Allow"
			)
			$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
				"System",
				"FullControl",
				"ContainerInherit,ObjectInherit",
				"None",
				"Allow"
			)

			# Add the custom rules to the ACL
			$acl.AddAccessRule($administratorsRule)
			$acl.AddAccessRule($usersRule)
			$acl.AddAccessRule($systemRule)

			# Apply the modified ACL to the folder
			Set-Acl -Path $folderPath -AclObject $acl
		}

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { 
			#Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
		}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		if ($processesToClose -ne '' -and $processesToClose -ne $null){
			$processesToClose.Split(",").Replace(" ","") | ForEach-Object {if (Get-Process $_ -ErrorAction SilentlyContinue){$oneRunning = $true}}
		}
		if ($oneRunning){
			Show-InstallationWelcome -CloseApps $processesToClose -CloseAppsCountdown 60
			Show-InstallationProgress -WindowLocation BottomRight
		}

		## Show Progress Message (with the default message)
		#Show-InstallationProgress -WindowLocation BottomRight

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress  -WindowLocation BottomRight

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
