# Create parameter block to pass to the script with following parameters:
# - FilePath: Path to the application
# - WorkingDirectory: Working directory for the application
# - DriveLetter: Drive letter to use for the application
# - ArgumentList: Arguments to pass to the application

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory,
    [Parameter(Mandatory = $false)]
    [string]$DriveLetter,
    [Parameter(Mandatory = $false)]
    [string[]]$ArgumentList,
    [Parameter(Mandatory = $false)]
    [switch]$Wait,
    [Parameter(Mandatory = $false)]
    [switch]$LoadUserProfile,
    [Parameter(Mandatory = $false)]
    [switch]$Trace
)

# Define working directory if parameter are empty
if ([string]::IsNullOrEmpty($WorkingDirectory)) {
    $WorkingDirectory = Split-Path $FilePath
}

# If Trace activated, start transcript
If ($Trace){
    $date = get-date -f yyyymmdd-hhmmss
    Start-Transcript -Path ($env:Temp + '\Start-AvdApplication_' + $env:COMPUTERNAME + '_' + $env:username + "_$date.log")
    Write-Output ("FilePath:         " + ($FilePath | Out-String))
    Write-Output ("WorkingDirectory: " + ($WorkingDirectory | Out-String))
    Write-Output ("DriveLetter:      " + ($DriveLetter | Out-String))
    Write-Output ("ArgumentList:     " + ($ArgumentList | Out-String))
    Write-Output ("Wait:             " + $Wait)
    Write-Output ("LoadUserProfile:  " + $LoadUserProfile)
    Write-Output ("Trace:            " + $Trace)
}

# Set environment variable to prevent ZoneCheck
$env:SEE_MASK_NOZONECHECKS = 1

# Define DriveLetter if not defined or empty
if ([string]::IsNullOrEmpty($DriveLetter)) {
    $DriveLetter = $FilePath.Substring(0, 1)
}

# Check if the drive letter is an alphabet character
If ($DriveLetter -match "[a-zA-Z]") {
    # Wait until the drive is mounted, loop and wait maximal 30 seconds for the drive to be available
    $counter = 0
    while (-not (Test-Path ($DriveLetter + ':\')) -and $counter -lt 30) {
        Start-Sleep -Seconds 1
        $counter++
    }

    # Check if counter is greater than 30. If so, exit the script with a message box to the user
    if ($counter -ge 30) {
        Write-Host
        $return = [System.Windows.Forms.MessageBox]::Show("Drive $DriveLetter is not available after 30 seconds. Exiting script.", "Connection Error", 0, 16)
        exit
    }
}

# Create expandable hashtable to pass the arguments to the application
$arguments = @{}

# Add FilePath to the hashtable
$arguments.Add("FilePath", $FilePath)

# Add WorkingDirectory to the hashtable if not empty
if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
    $arguments.Add("WorkingDirectory", $WorkingDirectory)
}

# Add ArgumentList to the hashtable if not empty
if ($ArgumentList.Count -gt 0) {
    $arguments.Add("ArgumentList", $ArgumentList)
}

# Add argument if switch Wait is true
if ($Wait) {
    $arguments.Add("Wait", $True)
}

# Add argument if switch LoadUserProfile is true
if ($LoadUserProfile) {
    $arguments.Add("LoadUserProfile", $True)
}

If ($Trace){Write-Output ("Arguments: " + ($arguments | Out-String))}

# Start the application with the arguments
If ($Wait) {
    Start-Process @arguments
} Else {
    Start-Process @arguments
    Start-Sleep -Seconds 60
}

# Stop transcript
If ($Trace){Stop-Transcript}