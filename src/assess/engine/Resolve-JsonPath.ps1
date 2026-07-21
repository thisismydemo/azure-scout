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
    # A null/blank path is a legitimate "no query" (e.g. manual rules) -> empty set.
    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }

    $json  = $InputObject | ConvertTo-Json -Depth 100
    $token = [Newtonsoft.Json.Linq.JToken]::Parse($json)

    # A query that THROWS (unsupported/invalid JSONPath) must NOT collapse into an
    # empty result set — that would let a broken query score as a Pass on
    # countEquals:0 asserts (AB#5083). Rethrow so Invoke-Rule can mark it Error.
    $results = $token.SelectTokens($Path, $false)
    return @($results)
}
