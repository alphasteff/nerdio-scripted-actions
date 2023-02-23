#name: Create browser links on Desktop
#description: Create browser links on the desktop.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

Use this script to create browser links on the desktop.

#>

$ErrorActionPreference = 'Stop'

$links = [System.Collections.ArrayList]@()
$null = $links.Add(@{ShortcutDisplayName = 'ServiceNow'; ShortcutArguments = 'https://www.servicenow.com/'; ShortcutTargetPath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"; IconFile = "$Env:ICONDir\servicenow.ico"; DestinationPath = "$env:PUBLIC\Desktop"})

foreach ($link in $links) {
    try {
        Write-Output "Create Link on Desktop for {0}" -f $link.ShortcutDisplayName

        $CreateDesktopIconParams = @{
            ShortcutDisplayName = $link.ShortcutDisplayName; 
            ShortcutArguments = $link.ShortcutArguments; 
            ShortcutTargetPath = $link.ShortcutTargetPath; 
            IconFile = $link.IconFile; DestinationPath = 
            $link.DestinationPath
        }

        &"$("$Env:SCRIPTDir\CreateDesktopIcon.ps1")" @CreateDesktopIconParams

    }
    catch {
        $ErrorActionPreference = 'Continue'
        write-output "Encountered error. $_"
        Throw $_ 
    }
}
