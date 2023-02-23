#name: Check FSLogix Cloud Cache Connection
#description: Check that the FSLogixs Cloud Cache is reachable.
#execution mode: Combined
#tags: beckmann.ch, Preview

<# Notes:

Use this script to check if the Cloud Cache Stroage account is available.

#>

$ErrorActionPreference = 'Stop'

$values = (Get-ItemProperty -Path HKLM:\SOFTWARE\FSLogix\Profiles -Name CCDLocations).CCDLocations

ForEach ($value in $values)
{

    $CCDLocation = $value.Split(',')

    $type = ConvertFrom-StringData $CCDLocation[0]
    $connectionString = ConvertFrom-StringData $CCDLocation[1]
    $connection = $connectionString.Values.Trim('"').Split(';') | ConvertFrom-StringData

    switch ($connection.DefaultEndpointsProtocol)   
    {
        'https' {$storageAccount = '{0}.blob.{1}' -f $connection.AccountName, $connection.EndpointSuffix; $protocol = 443}
    }

    $checkName = Resolve-DnsName $storageAccount
    $checkPort = Test-NetConnection -ComputerName $storageAccount -Port $protocol

    Write-Output ("DNS Resolve      = " + ($Name | Out-String))
    Write-Output ("StorageAccount   = " + $storageAccount)
    Write-Output ("ComputerName     = " + $checkPort.ComputerName)
    Write-Output ("RemoteAddress    = " + $checkPort.RemoteAddress)
    Write-Output ("RemotePort       = " + $checkPort.RemotePort)
    Write-Output ("SourceAddress    = " + $checkPort.SourceAddress.IPAddress)
    Write-Output ("TcpTestSucceeded = " + $checkPort.TcpTestSucceeded)
}