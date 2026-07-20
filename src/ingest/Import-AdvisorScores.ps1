#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Pull Azure Advisor recommendations per enabled subscription into collect.advisor.

.NOTES
    Read-only. Tracks ADO Story AB#5040.
#>
function Import-AdvisorScores {
    param($Collect)
    $subs = (Get-AzSubscription | Where-Object State -eq 'Enabled')
    $recs = foreach ($s in $subs) {
        Set-AzContext -SubscriptionId $s.Id | Out-Null
        Get-AzAdvisorRecommendation | Select-Object Category, Impact, ImpactedField, ImpactedValue,
            @{ n = 'Subscription'; e = { $s.Name } }, ShortDescriptionProblem, ShortDescriptionSolution
    }
    $Collect | Add-Member -NotePropertyName advisor -NotePropertyValue (@($recs)) -Force
    return $Collect
}
