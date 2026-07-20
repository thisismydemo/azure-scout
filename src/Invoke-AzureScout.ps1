#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Azure Scout top-level entry point — collect, assess, and report.

.DESCRIPTION
    Orchestrates the three-layer JSON-on-disk contract:
        COLLECT  -> collect.json
        ASSESS   -> findings.json
        REPORT   -> deliverables

    Every layer runs independently from its JSON input, so you can collect once
    and assess later, or re-render reports from an existing findings set without
    re-scanning. Read-only throughout.

.EXAMPLE
    Invoke-AzureScout -Assessment LandingZone -OutputFormat Html,Pptx

.EXAMPLE
    Invoke-AzureScout -Assessment LandingZone -CollectOnly
    Invoke-AzureScout -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi

.NOTES
    Tracks ADO Epic AB#5023 (Feature AB#5024, Story AB#5026).
#>
function Invoke-AzureScout {
    [CmdletBinding()]
    param(
        [string[]] $Assessment = @('Estate'),   # one, many, or 'All'
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]   $Scope = 'All',
        [string[]] $Category,                    # existing category filter still works
        [ValidateSet('PowerBi', 'Html', 'Pptx', 'Excel', 'Json', 'All')]
        [string[]] $OutputFormat = @('Html'),
        [string]   $OutputPath = './output',
        [switch]   $PermissionAudit,
        [switch]   $CollectOnly,                 # stop after collect.json
        [string]   $FromCollect,                 # skip collect, assess an existing collect.json
        [string]   $ManagementGroupId
    )

    $runId   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runPath = Join-Path $OutputPath $runId
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null

    $manifest = Import-PowerShellDataFile "$PSScriptRoot/../manifests/assessments.psd1"
    if ($Assessment -contains 'All') { $Assessment = @($manifest.Keys) }

    if ($PermissionAudit) {
        return Test-ScoutPermission -Assessment $Assessment -Manifest $manifest
    }

    # ---- COLLECT ----
    if ($FromCollect) {
        $collect = Get-Content $FromCollect -Raw | ConvertFrom-Json -Depth 100
    }
    else {
        $categories = $Assessment | ForEach-Object { $manifest[$_].Collect } | Select-Object -Unique
        if ($Category) { $categories = $Category }
        $collect = Invoke-Collect -Categories $categories -Scope $Scope -ManagementGroupId $ManagementGroupId

        # ingest third-party collectors declared by the chosen assessments
        $ingestors = $Assessment | ForEach-Object { $manifest[$_].Ingest } | Select-Object -Unique
        foreach ($i in $ingestors) {
            switch ($i) {
                'AzGovViz'      { $collect = Import-AzGovViz     -Collect $collect -OutputPath $runPath -ManagementGroupId $ManagementGroupId }
                'ArgQueryPack'  { $collect = Invoke-ArgQueryPack -Collect $collect }
                'AdvisorScores' { $collect = Import-AdvisorScores -Collect $collect }
            }
        }
        $collect | ConvertTo-Json -Depth 100 | Out-File "$runPath/collect.json"
    }
    if ($CollectOnly) { return "$runPath/collect.json" }

    # ---- ASSESS ----
    $allFindings = @()
    foreach ($name in $Assessment) {
        $spec = $manifest[$name]
        if (-not $spec.Rules) { continue }        # inventory-only assessment
        $ruleSet   = Get-RuleSet -Patterns $spec.Rules
        $benchmark = if ($spec.Benchmark) {
            Get-Content "$PSScriptRoot/assess/benchmarks/$($spec.Benchmark)" -Raw | ConvertFrom-Json -Depth 100
        } else { $null }
        $findings = Invoke-Assessment -Collect $collect -RuleSet $ruleSet -Benchmark $benchmark -Assessment $name
        $allFindings += $findings
    }
    $scored = Get-Score -Findings $allFindings
    $scored | ConvertTo-Json -Depth 100 | Out-File "$runPath/findings.json"

    # ---- REPORT ----
    $reporters = if ($OutputFormat -contains 'All') { @('PowerBi', 'Html', 'Pptx', 'Excel', 'Json') } else { $OutputFormat }
    foreach ($r in $reporters) {
        Export-Report -Renderer $r -Findings $scored -Collect $collect -OutputPath $runPath
    }
    return $runPath
}
