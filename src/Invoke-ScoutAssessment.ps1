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

    `-Scope`: the Collect layer is ARG/ARM only — there is no Entra/Graph
    collection path here, so 'EntraOnly' throws with a redirect to
    `Invoke-AzureScout -Scope EntraOnly` (the v1 inventory tool) rather than
    silently running a collect that can never gather anything. 'ArmOnly' and
    'All' are accepted and behave identically (both run the ARM collect) —
    kept for forward compatibility rather than removed.

    `-ManagementGroupId` now actually scopes the ARG collect (`Search-AzGraph
    -ManagementGroup`, threaded through `Invoke-Collect` and
    `Invoke-ArgQueryPack`), not just the AzGovViz ingest.

    `-Category` (or each assessment's manifest `Collect` list) now actually
    filters which Resource Graph queries `Invoke-Collect` runs, instead of
    always collecting the full ~25-query set.
#>
function Invoke-ScoutAssessment {
    [CmdletBinding()]
    param(
        [string[]] $Assessment = @('Estate'),   # one, many, or 'All'
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]   $Scope = 'All',              # EntraOnly throws -- ARM/ARG collect only, no Entra path here
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
        # There is no Entra/Graph collection path in this platform's Collect layer
        # (Invoke-Collect is ARG/ARM only) — 'EntraOnly' could never actually
        # collect anything, so fail fast with the honest redirect instead of
        # silently returning an empty/misleading run. 'ArmOnly' and 'All' are
        # functionally identical today (both just run the ARM collect) and stay
        # accepted for forward compatibility.
        if ($Scope -eq 'EntraOnly') {
            throw "Invoke-ScoutAssessment collects ARM/Resource Graph data only -- the assessment platform's Collect layer has no Entra ID collection path. Use 'Invoke-AzureScout -Scope EntraOnly' for Entra ID inventory instead."
        }
        $categories = $Assessment | ForEach-Object { $manifest[$_].Collect } | Select-Object -Unique
        if ($Category) { $categories = $Category }
        $collect = Invoke-Collect -Categories $categories -Scope $Scope -ManagementGroupId $ManagementGroupId

        # ingest third-party collectors declared by the chosen assessments
        $ingestors = $Assessment | ForEach-Object { $manifest[$_].Ingest } | Select-Object -Unique
        foreach ($i in $ingestors) {
            switch ($i) {
                'AzGovViz'      { $collect = Import-AzGovViz     -Collect $collect -OutputPath $runPath -ManagementGroupId $ManagementGroupId }
                'ArgQueryPack'  { $collect = Invoke-ArgQueryPack -Collect $collect -ManagementGroupId $ManagementGroupId }
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
