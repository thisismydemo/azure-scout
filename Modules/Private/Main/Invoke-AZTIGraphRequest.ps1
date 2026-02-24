<#
.Synopsis
    Execute a Microsoft Graph REST API request with automatic pagination and throttle handling.

.DESCRIPTION
    Wrapper around Invoke-RestMethod for Microsoft Graph API calls. Automatically:
      - Obtains a bearer token via Get-AZSCGraphToken
      - Builds the full URL from a relative path (e.g. /v1.0/users)
      - Follows @odata.nextLink for multi-page responses
      - Handles HTTP 429 (Too Many Requests) with Retry-After header
      - Returns the aggregated .value array (or raw response for single-object queries)

    NO Microsoft.Graph SDK dependency — uses Invoke-RestMethod directly.

.PARAMETER Uri
    Relative Graph API path, e.g. '/v1.0/users' or '/beta/identity/conditionalAccess/policies'.
    A full URL (https://graph.microsoft.com/...) is also accepted.

.PARAMETER Method
    HTTP method. Default: GET.

.PARAMETER Body
    Request body for POST/PATCH/PUT requests. Will be serialized to JSON if a hashtable/PSObject.

.PARAMETER SinglePage
    Do not follow @odata.nextLink — return only the first page of results.

.PARAMETER MaxRetries
    Maximum number of retries for transient errors (429, 5xx). Default: 5.

.OUTPUTS
    [PSObject[]] Aggregated .value array, or the raw response for single-object endpoints.

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
    Version: 1.0.0
    Authors: thisismydemo
#>
function Invoke-AZSCGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body,

        [switch]$SinglePage,

        [int]$MaxRetries = 5
    )

    $baseUrl = 'https://graph.microsoft.com'

    # Normalise URI — accept both relative ("/v1.0/users") and absolute URLs
    if ($Uri -notmatch '^https?://') {
        $fullUri = "$baseUrl$Uri"
    }
    else {
        $fullUri = $Uri
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Graph $Method $fullUri")

    $allResults = [System.Collections.Generic.List[object]]::new()
    $currentUri = $fullUri

    do {
        $headers = Get-AZSCGraphToken

        $requestParams = @{
            Uri         = $currentUri
            Method      = $Method
            Headers     = $headers
            ErrorAction = 'Stop'
        }

        if ($Body) {
            if ($Body -is [string]) {
                $requestParams['Body'] = $Body
            }
            else {
                $requestParams['Body'] = $Body | ConvertTo-Json -Depth 20
            }
            $requestParams['ContentType'] = 'application/json'
        }

        $response = $null
        $retryCount = 0

        while ($retryCount -le $MaxRetries) {
            try {
                $response = Invoke-RestMethod @requestParams
                break
            }
            catch {
                $statusCode = $null
                if ($_.Exception.Response) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }

                # Handle 429 (throttled) and 5xx (transient server errors)
                if ($statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -lt 600)) {
                    $retryCount++
                    if ($retryCount -gt $MaxRetries) {
                        Write-Warning "Graph API request failed after $MaxRetries retries: $($_.Exception.Message)"
                        throw
                    }

                    # Use Retry-After header if present, otherwise exponential backoff
                    $retryAfter = $null
                    if ($_.Exception.Response.Headers) {
                        try {
                            $retryAfterValues = $_.Exception.Response.Headers.GetValues('Retry-After')
                            if ($retryAfterValues) {
                                $retryAfter = [int]$retryAfterValues[0]
                            }
                        }
                        catch {
                            # Header not present — use backoff
                        }
                    }

                    if (-not $retryAfter -or $retryAfter -lt 1) {
                        $retryAfter = [math]::Pow(2, $retryCount)
                    }

                    Write-Warning "Graph API returned $statusCode. Retrying in $retryAfter seconds (attempt $retryCount/$MaxRetries)..."
                    Start-Sleep -Seconds $retryAfter

                    # Refresh token in case it expired during wait
                    $headers = Get-AZSCGraphToken
                    $requestParams['Headers'] = $headers
                }
                else {
                    # Non-retryable error — propagate
                    Write-Warning "Graph API request failed: $($_.Exception.Message)"
                    throw
                }
            }
        }

        # Collect results
        if ($null -ne $response) {
            if ($response.PSObject.Properties.Name -contains 'value') {
                # Collection endpoint — accumulate .value items
                foreach ($item in $response.value) {
                    $allResults.Add($item)
                }
            }
            else {
                # Single-object endpoint — return as-is
                return $response
            }
        }

        # Pagination
        $currentUri = $null
        if (-not $SinglePage -and $response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $currentUri = $response.'@odata.nextLink'
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Following nextLink (collected $($allResults.Count) items so far)")
        }

    } while ($currentUri)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Graph request complete. Total items: $($allResults.Count)")

    return $allResults.ToArray()
}
