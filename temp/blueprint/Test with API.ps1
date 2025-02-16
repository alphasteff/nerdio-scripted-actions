$NMEClientId = "7cb1791d-79fc-4e2f-afe5-c1da017b50ed"
$NMEClientSecret = ""
$NMETenantId = "aea79011-6c42-4f94-8658-45d43719e35f"
$NMEScope = "api://8db195be-1f0e-425e-8d9a-ca19a1f00513/.default"
$NMEuRI = "https://nmw-app-ymhp6bcl6taag.azurewebsites.net/"
$NMWSubscriptionId = "c4839d12-e5fa-411e-8cb4-8201157ca45a"

$AVDSubscriptionId = "5c1e6067-ba5d-4290-8ecd-7b52c4fd8af9"
$ResourceGroup = 'rg-dubai1-avdlz-prd-we-01'
$RegionName = "westeurope"

function Connect-NmeApi {
    param(
        [Parameter(mandatory = $true)]
        [string]$ClientId,
        [Parameter(mandatory = $true)]
        [string]$ClientSecret,
        [Parameter(mandatory = $true)]
        [string]$TenantId,
        [Parameter(mandatory = $true)]
        [string]$ApiScope,
        [Parameter(mandatory = $true)]
        [string]$NmeUri
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
    $headers.Add("Content-Type", "application/x-www-form-urlencoded")

    $encoded_scope = [System.Web.HTTPUtility]::UrlEncode("$ApiScope")
    $body = "grant_type=client_credentials&client_id=$ClientId&scope=$encoded_scope&client_secret=$ClientSecret"
    $TokenResponse = Invoke-RestMethod "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Headers $headers -Body $body
    $token = $TokenResponse.access_token

    $headers = New-Object "System.Collections.Generic.Dictionary[[String], [String]]"
    $headers.Add("Authorization", "Bearer $token")
    $headers.Add("Accept", "application/json")
    $headers.Add("Content-Type", "application/json")

    return $headers
}

$headers = Connect-NmeApi @ConnectArguments

$id = @{
    subscriptionId = $AVDSubscriptionId
    resourceGroup  = $ResourceGroup
    name           = "dubai1"
}

$NewWorkspaceParams = @{
    id               = $id
    location         = $RegionName
    servicePrincipal = $null
    friendlyName     = "friendly name"
}

$body = $null
$body = $NewWorkspaceParams | ConvertTo-Json
Invoke-RestMethod "$NMEuRI/api/v1/arm/hostpool/$AVDSubscriptionId/$ResourceGroup/auto-scale" -Body $body -Method Post -UseBasicParsing
