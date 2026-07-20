#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Inject findings.json into the self-contained HTML template.

.NOTES
    Single file, works offline. Tracks ADO Story AB#5047.
#>
function Export-Html {
    param($Findings, $Collect, [string] $OutputPath)
    $json = ($Findings | ConvertTo-Json -Depth 100) -replace '</', '<\/'
    $tpl  = Get-Content "$PSScriptRoot/../templates/report.html.template" -Raw
    $tpl.Replace('/*__DATA__*/', "window.__FINDINGS__ = $json;") |
        Out-File "$OutputPath/report.html" -Encoding utf8
}
