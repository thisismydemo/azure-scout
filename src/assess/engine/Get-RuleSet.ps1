#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Load rule files matching the supplied glob patterns.

.PARAMETER Overrides
    Optional hashtable of ruleId -> override, sourced from a Scout config file
    (Import-ScoutConfig's RuleOverrides, AB#373/#375). Each entry either:
      - is a bare scalar, applied as the rule's new `assert.value` (the common
        "threshold override" case, e.g. loosen/tighten a countLessThan bound), or
      - is a hashtable/pscustomobject with a `value` and/or `type` key, applied
        onto the rule's existing `assert.value` / `assert.type` respectively.
    Rule ids absent from Overrides, or rules with no `assert` block (manual
    rules), are left untouched. A $null/empty map is a no-op.

.NOTES
    Requires the powershell-yaml module. Tracks ADO Story AB#5028.
#>
function Get-RuleSet {
    param([string[]] $Patterns, [hashtable] $Overrides)

    Import-Module powershell-yaml -ErrorAction Stop
    $ruleDir = "$PSScriptRoot/../rules"
    $files = Get-ChildItem $ruleDir -Filter *.yaml | Where-Object {
        $f = $_.BaseName
        $Patterns | Where-Object { $f -like $_ }
    }
    $sets = foreach ($file in $files) {
        $doc = ConvertFrom-Yaml (Get-Content $file.FullName -Raw)
        $rules = $doc.rules
        if ($Overrides -and $Overrides.Count -gt 0) {
            foreach ($rule in $rules) {
                if (-not $Overrides.ContainsKey($rule.id)) { continue }
                if ($rule.ContainsKey('manual') -and $rule.manual) { continue }   # manual rules have no numeric threshold to override
                if (-not $rule.ContainsKey('assert') -or $null -eq $rule.assert) { continue }
                $ov = $Overrides[$rule.id]
                $ovMap = $null
                if ($ov -is [hashtable]) {
                    $ovMap = $ov
                }
                elseif ($ov -is [System.Management.Automation.PSCustomObject]) {
                    $ovMap = @{}
                    foreach ($p in $ov.PSObject.Properties) { $ovMap[$p.Name] = $p.Value }
                }
                if ($ovMap) {
                    if ($ovMap.ContainsKey('value')) { $rule.assert.value = $ovMap.value }
                    if ($ovMap.ContainsKey('type'))  { $rule.assert.type  = $ovMap.type }
                }
                else {
                    $rule.assert.value = $ov
                }
            }
        }
        [pscustomobject]@{
            Area      = $doc.area
            Framework = $doc.framework
            Weight    = [double]($doc.weight ?? 1.0)
            Rules     = $rules
        }
    }
    return $sets
}
