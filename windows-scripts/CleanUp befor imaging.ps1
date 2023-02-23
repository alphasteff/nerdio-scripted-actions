#name: CleanUp before imaging
#description: Clean up the image before it can be sealed.
#execution mode: Individual with restart
#tags: beckmann.ch, Preview

<# Notes:

Use this script to clean up the VM's disc before creating a version of Disk Image from it.

#>

$ErrorActionPreference = 'Stop'

Get-ChildItem "$Env:SystemDrive\Sys\Install" -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "$Env:SystemDrive\Windows\Temp" -Exclude "NMWLogs*" | Remove-Item -Recurse -Exclude "NMWLogs*" -Force -ErrorAction SilentlyContinue
Remove-Item "$Env:SystemDrive\temp" -Recurse -Force -ErrorAction SilentlyContinue

Remove-Item "$Env:PUBLIC\Desktop\Cisco Webex Meetings.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$Env:PUBLIC\Desktop\Zoom VDI.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$Env:PUBLIC\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
