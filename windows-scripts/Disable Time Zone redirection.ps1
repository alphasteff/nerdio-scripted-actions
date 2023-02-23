#name: Disable Time Zone redirection
#description: Remove the Time Zone redirection registry key.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

In Nerdio the hook can be removed that no time zone redirection should be made,
however the registry key is not removed, and the redirection so also not deactivated.
This script removes this key.

#>

# Remove registry key fEnableTimeZoneRedirection
# https://learn.microsoft.com/en-us/azure/virtual-desktop/set-up-customize-master-image#set-up-time-zone-redirection
Write-Output "Remove registry key fEnableTimeZoneRedirection"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fEnableTimeZoneRedirection" -ErrorAction SilentlyContinue   
