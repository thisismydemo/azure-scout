#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Aggregate findings into area/framework scores and a prioritized gap list.

.NOTES
    Manual/NA excluded from denominators. Tracks ADO Story AB#5036.
#>
function Get-Score {
    param($Findings)

    $statusWeight = @{ Pass = 1.0; Partial = 0.5; Fail = 0.0 }   # Manual/NA excluded from denominator

    $areas = $Findings | Group-Object Framework, Area | ForEach-Object {
        $scorable = $_.Group | Where-Object { $_.Status -in 'Pass', 'Partial', 'Fail' }
        $den = ($scorable | Measure-Object).Count
        $num = ($scorable | ForEach-Object { $statusWeight[$_.Status] } | Measure-Object -Sum).Sum
        [pscustomobject]@{
            Framework = $_.Group[0].Framework
            Area      = $_.Group[0].Area
            Score     = if ($den -gt 0) { [math]::Round($num / $den * 100) } else { $null }
            Pass      = ($_.Group | Where-Object Status -eq 'Pass').Count
            Partial   = ($_.Group | Where-Object Status -eq 'Partial').Count
            Fail      = ($_.Group | Where-Object Status -eq 'Fail').Count
            Manual    = ($_.Group | Where-Object Status -eq 'Manual').Count
        }
    }

    $frameworks = $areas | Where-Object { $null -ne $_.Score } | Group-Object Framework | ForEach-Object {
        [pscustomobject]@{
            Framework = $_.Name
            Score     = [math]::Round(($_.Group.Score | Measure-Object -Average).Average)
        }
    }

    # prioritized gap list: fails first, weighted by severity
    $sevRank = @{ high = 0; medium = 1; low = 2 }
    $gaps = $Findings | Where-Object Status -eq 'Fail' |
        Sort-Object @{ E = { $sevRank[$_.Severity] } }, Area |
        Select-Object Id, Framework, Area, Severity, Title, Remediation

    [pscustomobject]@{
        GeneratedOn = (Get-Date).ToString('o')
        Frameworks  = $frameworks
        Areas       = $areas
        Gaps        = $gaps
        Manual      = ($Findings | Where-Object Status -eq 'Manual')
        Findings    = $Findings
    }
}
