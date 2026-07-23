#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Azure Scout assessment entry point — collect, assess, and report.

.DESCRIPTION
    The assessment-platform orchestrator (distinct from the inventory cmdlet
    Invoke-AzureScout). Orchestrates the three-layer JSON-on-disk contract:
        COLLECT  -> collect.json
        ASSESS   -> findings.json
        REPORT   -> deliverables

    Every layer runs independently from its JSON input, so you can collect once
    and assess later, or re-render reports from an existing findings set without
    re-scanning. Read-only throughout.

.EXAMPLE
    Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Html,Pptx

.EXAMPLE
    Invoke-ScoutAssessment -Assessment Management        # governance/policy/update-manager, scored
    Invoke-ScoutAssessment -Assessment Monitor -OutputFormat Html

.EXAMPLE
    Invoke-ScoutAssessment -Assessment LandingZone -CollectOnly
    Invoke-ScoutAssessment -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi

.NOTES
    Tracks ADO Epic AB#5023 (Feature AB#5024, Story AB#5026) and Epic AB#5056.
#>
function Invoke-ScoutAssessment {
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
        # $spec is a Hashtable straight out of assessments.psd1, and most assessment
        # entries don't define a Benchmark key at all (only LandingZone does). Dot-
        # accessing a Hashtable key that is entirely absent throws PropertyNotFound
        # under Set-StrictMode -Version Latest, so check ContainsKey first rather
        # than relying on truthiness of a property access that may never resolve.
        $benchmark = if ($spec.ContainsKey('Benchmark') -and $spec.Benchmark) {
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
