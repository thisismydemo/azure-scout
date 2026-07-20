#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Run every rule in every rule set against the collect object.

.NOTES
    Appends benchmark findings when a benchmark is supplied. Tracks ADO Story AB#5035.
#>
function Invoke-Assessment {
    param($Collect, $RuleSet, $Benchmark, [string] $Assessment)

    $findings = foreach ($set in $RuleSet) {
        foreach ($rule in $set.Rules) {
            $f = Invoke-Rule -Rule $rule -Collect $Collect -Area $set.Area -Framework $set.Framework
            $f | Add-Member -NotePropertyName Assessment -NotePropertyValue $Assessment -PassThru |
                 Add-Member -NotePropertyName AreaWeight -NotePropertyValue $set.Weight -PassThru
        }
    }
    if ($Benchmark) { $findings += Compare-Benchmark -Collect $Collect -Benchmark $Benchmark }
    return $findings
}
