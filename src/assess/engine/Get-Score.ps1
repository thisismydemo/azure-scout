#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Aggregate findings into area/framework scores and a prioritized gap list.

.NOTES
    - Manual / Unknown / Error / NA are excluded from the score denominator but
      surfaced as counts so broken content is visible, not silently dropped (AB#5088).
    - Framework score is weighted by each area's AreaWeight, not a flat mean, so a
      3-rule area does not sway the headline like a 40-rule area (AB#5087).
    - Unknown/absent severities sort LAST in the gap list, not first (AB#5089).
    Tracks ADO Story AB#5036 and Bugs AB#5087/#5088/#5089.
#>
function Get-Score {
    param($Findings)

    $statusWeight = @{ Pass = 1.0; Partial = 0.5; Fail = 0.0 }   # Manual/Unknown/Error excluded

    $areas = $Findings | Group-Object Framework, Area | ForEach-Object {
        $scorable = $_.Group | Where-Object { $_.Status -in 'Pass', 'Partial', 'Fail' }
        $den = ($scorable | Measure-Object).Count
        $num = ($scorable | ForEach-Object { $statusWeight[$_.Status] } | Measure-Object -Sum).Sum
        # AreaWeight is uniform within an area; take the first (default 1.0 if absent).
        $weight = 1.0
        $wf = $_.Group | Where-Object { $null -ne $_.PSObject.Properties['AreaWeight'] } | Select-Object -First 1
        if ($wf) { $weight = [double]$wf.AreaWeight }
        [pscustomobject]@{
            Framework = $_.Group[0].Framework
            Area      = $_.Group[0].Area
            Weight    = $weight
            Score     = if ($den -gt 0) { [math]::Round($num / $den * 100, 0, [System.MidpointRounding]::AwayFromZero) } else { $null }
            Pass      = ($_.Group | Where-Object Status -eq 'Pass').Count
            Partial   = ($_.Group | Where-Object Status -eq 'Partial').Count
            Fail      = ($_.Group | Where-Object Status -eq 'Fail').Count
            Manual    = ($_.Group | Where-Object Status -eq 'Manual').Count
            Unknown   = ($_.Group | Where-Object Status -eq 'Unknown').Count
            Error     = ($_.Group | Where-Object Status -eq 'Error').Count
        }
    }

    $frameworks = $areas | Where-Object { $null -ne $_.Score } | Group-Object Framework | ForEach-Object {
        # Weighted average of area scores by AreaWeight (AB#5087).
        $wsum = ($_.Group | ForEach-Object { $_.Weight } | Measure-Object -Sum).Sum
        $wnum = ($_.Group | ForEach-Object { $_.Score * $_.Weight } | Measure-Object -Sum).Sum
        [pscustomobject]@{
            Framework = $_.Name
            Score     = if ($wsum -gt 0) { [math]::Round($wnum / $wsum, 0, [System.MidpointRounding]::AwayFromZero) } else { $null }
            Unknown   = ($_.Group | Measure-Object Unknown -Sum).Sum
            Error     = ($_.Group | Measure-Object Error -Sum).Sum
        }
    }

    # prioritized gap list: fails first, weighted by severity; unknown/missing severity sorts LAST.
    $sevRank = @{ high = 0; medium = 1; low = 2 }
    $gaps = $Findings | Where-Object Status -eq 'Fail' |
        Sort-Object @{ E = { if ($_.Severity -and $sevRank.ContainsKey($_.Severity)) { $sevRank[$_.Severity] } else { 99 } } }, Area |
        Select-Object Id, Framework, Area, Severity, Title, Remediation

    [pscustomobject]@{
        GeneratedOn = (Get-Date).ToString('o')
        Frameworks  = $frameworks
        Areas       = $areas
        Gaps        = $gaps
        Manual      = ($Findings | Where-Object Status -eq 'Manual')
        Errors      = ($Findings | Where-Object Status -in 'Error', 'Unknown')
        Findings    = $Findings
    }
}
