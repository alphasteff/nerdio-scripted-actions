$Version = 'xyz';
if([version]((Get-Item "$(${env:ProgramFiles(x86)})\xyz\xyz.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if([version]((Get-Item "$(${env:ProgramFiles})\xyz\xyz.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if([version]((Get-Item "$(${env:ProgramW6432})\xyz\xyz.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if($bRes) { $true } else { $null };
exit(0);
