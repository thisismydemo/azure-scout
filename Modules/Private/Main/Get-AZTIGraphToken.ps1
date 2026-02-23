<#
.Synopsis
    Acquire a Microsoft Graph bearer token via the current Az context.

.DESCRIPTION
    Uses Get-AzAccessToken -ResourceTypeName MSGraph to obtain a bearer token
    for Microsoft Graph API calls. Caches the token in a script-scope variable
    and refreshes automatically when within 5 minutes of expiry.

    NO Microsoft.Graph SDK dependency — only Az.Accounts is required.

.OUTPUTS
    [hashtable] Authorization headers ready for Invoke-RestMethod:
    @{ 'Authorization' = 'Bearer <token>'; 'Content-Type' = 'application/json' }

.LINK
    https://github.com/thisismydemo/azure-inventory

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
    Version: 1.0.0
    Authors: thisismydemo
#>
function Get-AZTIGraphToken {
    [CmdletBinding()]
    param()

    # Script-scope cache — persists across calls within the same module session
    if (-not (Get-Variable -Name '_AZTIGraphTokenCache' -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name '_AZTIGraphTokenCache' -Scope Script -Value $null
    }

    $now = [DateTimeOffset]::UtcNow
    $cache = $Script:_AZTIGraphTokenCache

    # Reuse cached token if still valid (more than 5 min from expiry)
    if ($cache -and $cache.ExpiresOn -gt $now.AddMinutes(5)) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Reusing cached Graph token (expires ' + $cache.ExpiresOn.ToString('HH:mm:ss') + ' UTC)')
        return $cache.Headers
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Acquiring new Microsoft Graph token')

    try {
        # Az.Accounts >= 2.x supports -ResourceTypeName MSGraph
        $tokenResponse = Get-AzAccessToken -ResourceTypeName MSGraph -ErrorAction Stop

        # Get-AzAccessToken returns Token (string) and ExpiresOn (DateTimeOffset)
        $plainToken = $tokenResponse.Token

        $headers = @{
            'Authorization' = "Bearer $plainToken"
            'Content-Type'  = 'application/json'
        }

        # Cache for reuse
        $Script:_AZTIGraphTokenCache = [PSCustomObject]@{
            Headers   = $headers
            ExpiresOn = $tokenResponse.ExpiresOn
        }

        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Graph token acquired, expires ' + $tokenResponse.ExpiresOn.ToString('HH:mm:ss') + ' UTC')

        return $headers
    }
    catch {
        $errorMessage = "Failed to acquire Microsoft Graph token. Ensure the current identity has Graph API permissions. Error: $($_.Exception.Message)"
        Write-Warning $errorMessage
        throw $errorMessage
    }
}
