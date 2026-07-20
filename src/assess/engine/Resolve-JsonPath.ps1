#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Resolve a JSONPath expression against an object using the Newtonsoft engine
    that ships with PowerShell 7.

.NOTES
    Tracks ADO Story AB#5029.
#>
function Resolve-JsonPath {
    param(
        [Parameter(Mandatory)] $InputObject,
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }
    $json  = $InputObject | ConvertTo-Json -Depth 100
    $token = [Newtonsoft.Json.Linq.JToken]::Parse($json)
    try {
        $results = $token.SelectTokens($Path)
        return @($results)
    }
    catch {
        Write-Warning "JSONPath '$Path' failed: $_"
        return @()
    }
}
