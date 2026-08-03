#Requires -Version 7.0
<#
.SYNOPSIS
    Per-collector coverage verdicts across a banked corpus run. Offline -- needs no Azure.

.DESCRIPTION
    AB#6898. Answers "does every collector work?" the only honest way banked data can: a collect
    key that returned rows in at least one real tenant demonstrably works end-to-end; one empty in
    EVERY tenant is either genuinely absent from all estates or broken, and the data alone cannot
    tell those apart. This script therefore separates the keys into three buckets and, for the
    empty-everywhere bucket, applies the KNOWN-EXPLANATION list below so the output is a verdict
    per key, not a pile of counts for a human to re-derive each time.

    The explanation list is maintenance-bearing on purpose: a new collector that lands empty
    everywhere with no entry here shows up as UNEXPLAINED, which is the correct pressure.

.EXAMPLE
    ./scripts/Invoke-CorpusCoverage.ps1 -CorpusRun D:\azure-scout-corpus\2026-08-03-run02
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $CorpusRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Keys expected to be empty in the reference estates, with the reason. 'Conditional' means the
# estate genuinely may not carry the service; 'OptIn' means the collect needs a switch/secret this
# corpus run does not pass; 'Deprecated' means Azure retired the surface.
$knownEmpty = @{
    'devops/agentPools'                = 'OptIn: -IncludeDevOps + PAT not passed to corpus collects'
    'devops/chaosExperiments'          = 'Conditional: no Chaos Studio experiments in these estates'
    'devops/devCenters'                = 'Conditional: no Dev Centers in these estates'
    'devops/loadTesting'               = 'Conditional: no Azure Load Testing in these estates'
    'devops/managedPools'              = 'Conditional: no Managed DevOps Pools in these estates'
    'devops/pipelines'                 = 'OptIn: -IncludeDevOps + PAT not passed to corpus collects'
    'devops/playwrightTesting'         = 'Conditional: no Playwright Testing in these estates'
    'devops/projects'                  = 'OptIn: -IncludeDevOps + PAT not passed to corpus collects'
    'devops/repositories'              = 'OptIn: -IncludeDevOps + PAT not passed to corpus collects'
    'devops/serviceConnections'        = 'OptIn: -IncludeDevOps + PAT not passed to corpus collects'
    'finops/anomalies'                 = 'OptIn: cost collection not requested by corpus collects'
    'finops/blockedSubscriptions'      = 'OptIn: cost collection not requested by corpus collects'
    'finops/costRows'                  = 'OptIn: cost collection not requested by corpus collects'
    'finops/reservationRecommendations' = 'Conditional: no reservations in these estates'
    'finops/reservations'              = 'Conditional: no reservations in these estates'
    'governance/classicAdministrators' = 'Deprecated: classic administrators retired by Azure'
    'governance/pimEligibility'        = 'Conditional: PIM needs Entra ID P2, absent in these tenants'
    'compute/avdScalingPlans'          = 'Conditional: no AVD scaling plans in these estates'
    'compute/avdSessionHosts'          = 'Conditional: no AVD session hosts in these estates'
    'compute/privateClouds'            = 'Conditional: no AVS private clouds in these estates'
    'networking/azureFirewalls'        = 'Conditional: no Azure Firewalls in these estates'
    'networking/firewallPolicyRuleGroups' = 'Conditional: no firewall policies in these estates'
    # security/defenderPlans deliberately has NO entry: it was hardcoded empty until AB#6903
    # and its old "not enabled in these estates" explanation was proven false live (hcs carries
    # 18 plans, 4 non-Free). If it lands empty-everywhere again, that is UNEXPLAINED -- correct.
}

$tenantDirs = @(Get-ChildItem -Path $CorpusRun -Directory)
$seen = @{}; $rowTotals = @{}
$tenantCount = 0

foreach ($t in $tenantDirs) {
    $cj = Get-ChildItem $t.FullName -Recurse -Filter 'collect.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $cj) { continue }
    $tenantCount++
    $c = Get-Content $cj.FullName -Raw | ConvertFrom-Json -Depth 100
    foreach ($catProp in $c.PSObject.Properties) {
        if ($catProp.Name -eq '_meta') { continue }
        $val = $catProp.Value
        if ($null -eq $val -or $val -isnot [System.Management.Automation.PSCustomObject]) { continue }
        foreach ($sub in $val.PSObject.Properties) {
            $key = "$($catProp.Name)/$($sub.Name)"
            $n = if ($null -eq $sub.Value) { 0 } elseif ($sub.Value -is [string]) { 1 } else { @($sub.Value).Count }
            if (-not $seen.ContainsKey($key)) { $seen[$key] = 0; $rowTotals[$key] = 0 }
            if ($n -gt 0) { $seen[$key]++; $rowTotals[$key] += $n }
        }
    }
}

Write-Host "corpus run : $CorpusRun" -ForegroundColor Cyan
Write-Host "tenants    : $tenantCount"
Write-Host "collect keys observed: $($seen.Keys.Count)`n"

$working = @(); $explained = @(); $unexplained = @()
foreach ($key in ($seen.Keys | Sort-Object)) {
    if ($seen[$key] -gt 0) { $working += '{0,-44} {1} tenant(s), {2} rows' -f $key, $seen[$key], $rowTotals[$key] }
    elseif ($knownEmpty.ContainsKey($key)) { $explained += '{0,-44} {1}' -f $key, $knownEmpty[$key] }
    else { $unexplained += $key }
}

Write-Host "=== WORKING -- returned rows in >=1 tenant: $($working.Count) ===" -ForegroundColor Green
$working | ForEach-Object { "  $_" }
Write-Host "`n=== EMPTY EVERYWHERE, EXPLAINED: $($explained.Count) ===" -ForegroundColor Yellow
$explained | ForEach-Object { "  $_" }
Write-Host "`n=== EMPTY EVERYWHERE, UNEXPLAINED -- each needs a live check or a new explanation entry: $($unexplained.Count) ===" -ForegroundColor Red
if ($unexplained.Count -eq 0) { Write-Host '  (none)' -ForegroundColor Green } else { $unexplained | ForEach-Object { "  $_" } }

if ($unexplained.Count -gt 0) { exit 1 }
