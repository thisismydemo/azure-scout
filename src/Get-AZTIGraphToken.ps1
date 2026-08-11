#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.Synopsis
    Acquire a Microsoft Graph bearer token for the selected Azure context.

.DESCRIPTION
    Uses Get-AzAccessToken so Graph and ARM execute as the same account and tenant
    selected by Invoke-AzureScout. It never starts a second Azure CLI authentication
    path. Successful tokens are cached per Graph endpoint, tenant, and selected Az
    account identity, and are refreshed automatically when within 5 minutes of expiry.

.PARAMETER TenantID
    Optional tenant ID to scope the token to. Pass the same TenantID given to
    Invoke-AzureScout / Invoke-AZSCPermissionAudit so ARM and Graph remain pinned
    to the same resource tenant.

.OUTPUTS
    [hashtable] Authorization headers ready for Invoke-RestMethod:
    @{ 'Authorization' = 'Bearer <token>'; 'Content-Type' = 'application/json' }

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
    Version: 1.2.0
    Authors: thisismydemo
    Modified: 2026-02-24 - Changed from Get-AzAccessToken to Azure CLI for proper Graph scopes
    Modified: 2026-08-08 - AB#7100 -- Added -TenantID so the token targets the tenant being
              audited/collected instead of az CLI's ambient default; cache keyed per tenant so
              a run touching multiple tenants can't return one tenant's cached token for another.
    Modified: 2026-08-11 - Use only the selected Az context and isolate the cache by account;
              a different Azure CLI login cannot hijack Entra collection or require a second sign-in.
#>
function Get-AZSCGraphToken {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [string]$TenantID,
        [ValidateSet('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud')]
        [string]$AzureEnvironment
    )

    $azContext = $null
    try {
        $azContext = Get-AzContext -ErrorAction SilentlyContinue
    }
    catch { }

    if (-not $AzureEnvironment) {
        try {
            if ($azContext -and $azContext.PSObject.Properties.Name -contains 'Environment' -and
                $azContext.Environment -and $azContext.Environment.PSObject.Properties.Name -contains 'Name') {
                $AzureEnvironment = [string]$azContext.Environment.Name
            }
        }
        catch { }
    }
    if ($AzureEnvironment -notin @('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud')) {
        $AzureEnvironment = 'AzureCloud'
    }

    $graphResource = switch ($AzureEnvironment) {
        'AzureUSGovernment' { 'https://graph.microsoft.us' }
        'AzureChinaCloud'   { 'https://microsoftgraph.chinacloudapi.cn' }
        default             { 'https://graph.microsoft.com' }
    }

    # Include the selected Az account in the cache key. Tenant-only caching can otherwise
    # return a token for account A after the operator changes the Az context to account B.
    $azAccountIdentity = ''
    if ($azContext -and $azContext.PSObject.Properties['Account'] -and $azContext.Account) {
        $accountId = if ($azContext.Account.PSObject.Properties['Id']) { [string]$azContext.Account.Id } else { '' }
        $accountType = if ($azContext.Account.PSObject.Properties['Type']) { [string]$azContext.Account.Type } else { '' }
        $azAccountIdentity = "$accountType|$accountId"
    }
    $cacheKey = "$graphResource|$(if ($TenantID) { $TenantID } else { '' })|$azAccountIdentity"

    if (-not (Get-Variable -Name '_AZSCGraphTokenCache' -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name '_AZSCGraphTokenCache' -Scope Script -Value @{}
    }

    $now = [DateTimeOffset]::UtcNow
    $cache = $Script:_AZSCGraphTokenCache[$cacheKey]

    # Reuse cached token if still valid (more than 5 min from expiry)
    if ($cache -and $cache.ExpiresOn -gt $now.AddMinutes(5)) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Reusing cached Graph token for tenant ' + $(if ($TenantID) { $TenantID } else { '(ambient)' }) + ' (expires ' + $cache.ExpiresOn.ToString('HH:mm:ss') + ' UTC)')
        return $cache.Headers
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Acquiring new Microsoft Graph token for tenant ' + $(if ($TenantID) { $TenantID } else { '(ambient)' }))

    $plainToken = $null
    $expiresOn = $null
    $provider = $null
    try {
        $tokenArgs = @{
            ResourceUrl = $graphResource
            ErrorAction = 'Stop'
        }
        if ($TenantID) { $tokenArgs.TenantId = $TenantID }

        $tokenData = Get-AzAccessToken @tokenArgs
        if (-not $tokenData -or -not $tokenData.PSObject.Properties['Token'] -or $null -eq $tokenData.Token) {
            throw 'Get-AzAccessToken returned no token.'
        }

        if ($tokenData.Token -is [System.Security.SecureString]) {
            $tokenPointer = [IntPtr]::Zero
            try {
                $tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenData.Token)
                $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
            }
            finally {
                if ($tokenPointer -ne [IntPtr]::Zero) {
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
                }
            }
        }
        else {
            # Older Az.Accounts versions returned a plain string.
            $plainToken = [string]$tokenData.Token
        }

        if ([string]::IsNullOrWhiteSpace($plainToken)) {
            throw 'Get-AzAccessToken returned an empty token.'
        }

        $expiresOn = if ($tokenData.PSObject.Properties['ExpiresOn'] -and $tokenData.ExpiresOn) {
            [DateTimeOffset]$tokenData.ExpiresOn
        }
        else {
            $now.AddMinutes(30)
        }
        $provider = 'Az PowerShell'
    }
    catch {
        throw "Failed to acquire Microsoft Graph token from the selected Azure PowerShell context for tenant '$(if ($TenantID) { $TenantID } else { '(ambient)' })'. Graph and ARM use the same Azure sign-in; Azure CLI is not used. Error: $($_.Exception.Message)"
    }

    $headers = @{
        'Authorization' = "Bearer $plainToken"
        'Content-Type'  = 'application/json'
    }
    $plainToken = $null

    $Script:_AZSCGraphTokenCache[$cacheKey] = [PSCustomObject]@{
        Headers   = $headers
        ExpiresOn = $expiresOn
        Provider  = $provider
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Graph token acquired via $provider, expires " + $expiresOn.ToString('HH:mm:ss') + ' UTC')
    return $headers
}
