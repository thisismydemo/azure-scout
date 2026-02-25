<#
.Synopsis
    Acquire a Microsoft Graph bearer token via Azure CLI.

.DESCRIPTION
    Uses Azure CLI (az account get-access-token) to obtain a bearer token
    for Microsoft Graph API calls. Caches the token in a script-scope variable
    and refreshes automatically when within 5 minutes of expiry.

    Requires Azure CLI to be logged in ('az login'). Azure CLI automatically
    requests proper Graph API scopes during authentication, unlike Az PowerShell.

.OUTPUTS
    [hashtable] Authorization headers ready for Invoke-RestMethod:
    @{ 'Authorization' = 'Bearer <token>'; 'Content-Type' = 'application/json' }

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
    Version: 1.0.0
    Authors: thisismydemo
    Modified: 2026-02-24 - Changed from Get-AzAccessToken to Azure CLI for proper Graph scopes
#>
function Get-AZSCGraphToken {
    [CmdletBinding()]
    param()

    # Script-scope cache — persists across calls within the same module session
    if (-not (Get-Variable -Name '_AZSCGraphTokenCache' -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name '_AZSCGraphTokenCache' -Scope Script -Value $null
    }

    $now = [DateTimeOffset]::UtcNow
    $cache = $Script:_AZSCGraphTokenCache

    # Reuse cached token if still valid (more than 5 min from expiry)
    if ($cache -and $cache.ExpiresOn -gt $now.AddMinutes(5)) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Reusing cached Graph token (expires ' + $cache.ExpiresOn.ToString('HH:mm:ss') + ' UTC)')
        return $cache.Headers
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Acquiring new Microsoft Graph token')

    try {
        # Use Azure CLI to get Graph token with proper scopes
        # Azure CLI device code authentication includes Graph API scopes by default
        $azTokenJson = az account get-access-token --resource https://graph.microsoft.com 2>&1 | Out-String

        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI failed to get Graph token. Ensure you are logged in with 'az login'. Error: $azTokenJson"
        }

        $tokenData = $azTokenJson | ConvertFrom-Json
        $plainToken = $tokenData.accessToken
        $expiresOn = [DateTimeOffset]::Parse($tokenData.expiresOn)

        $headers = @{
            'Authorization' = "Bearer $plainToken"
            'Content-Type'  = 'application/json'
        }

        # Cache for reuse
        $Script:_AZSCGraphTokenCache = [PSCustomObject]@{
            Headers   = $headers
            ExpiresOn = $expiresOn
        }

        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Graph token acquired via Azure CLI, expires ' + $expiresOn.ToString('HH:mm:ss') + ' UTC')

        return $headers
    }
    catch {
        $errorMessage = "Failed to acquire Microsoft Graph token. Ensure Azure CLI is logged in with 'az login' and has Graph API permissions. Error: $($_.Exception.Message)"
        Write-Warning $errorMessage
        throw $errorMessage
    }
}
