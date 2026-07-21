#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Load rule files matching the supplied glob patterns.

.NOTES
    Requires the powershell-yaml module. Tracks ADO Story AB#5028.
#>
function Get-RuleSet {
    param([string[]] $Patterns)

    Import-Module powershell-yaml -ErrorAction Stop
    $ruleDir = "$PSScriptRoot/../rules"
    $files = Get-ChildItem $ruleDir -Filter *.yaml | Where-Object {
        $f = $_.BaseName
        $Patterns | Where-Object { $f -like $_ }
    }
    $sets = foreach ($file in $files) {
        $doc = ConvertFrom-Yaml (Get-Content $file.FullName -Raw)
        [pscustomobject]@{
            Area      = $doc.area
            Framework = $doc.framework
            Weight    = [double]($doc.weight ?? 1.0)
            Rules     = $doc.rules
        }
    }
    return $sets
}
