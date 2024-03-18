$Version = '21.7';
if([version]((Get-Item "$(${env:ProgramFiles(x86)})\7-Zip\7zFM.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if([version]((Get-Item "$(${env:ProgramFiles})\7-Zip\7zFM.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if([version]((Get-Item "$(${env:ProgramW6432})\7-Zip\7zFM.exe" -ea ignore).VersionInfo.FileVersion) -ge $Version) { $bRes = $true };
if($bRes) { $true } else { $null };
exit(0);