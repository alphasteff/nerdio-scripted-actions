#name: Enable to retrieve Cloud Kerberos Tickets
#description: Configure the client to retrieve Kerberos tickets
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

Enable the Azure AD Kerberos functionality on the client machine(s) you want to mount/use Azure File shares from.
You must do this on every client on which Azure Files will be used.

#>

$LogDir = "$Env:InstallLogDir"
Start-Transcript -Path "$LogDir\Enable_Cloud_Kerberos.log" -Append

# Add registry keys
$pathKerberosParams = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
New-ItemProperty -Path $pathKerberosParams -Name "CloudKerberosTicketRetrievalEnabled" -Value 1 -PropertyType DWORD -Force -ErrorAction:SilentlyContinue

Stop-Transcript