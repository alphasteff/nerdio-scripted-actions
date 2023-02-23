#name: Exclude users from FSLogix
#description: Exclude user from FSLogix Romaing Profile.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

Use this script to exclude the local administrator from Romaing Profile.

#>

$ErrorActionPreference = 'Stop'

$localAdministrator = $SecureVars.LocalAdministrator

$users = @($localAdministrator )

try {
    Write-Output "Add users to Group"
    Add-LocalGroupMember -Group "FSLogix ODFC Exclude List" -Member $users -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "FSLogix Profile Exclude List" -Member $users -ErrorAction SilentlyContinue

}
catch {
    $ErrorActionPreference = 'Continue'
    write-output "Encountered error. $_"
    Throw $_ 
}
