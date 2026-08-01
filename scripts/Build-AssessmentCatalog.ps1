#Requires -Version 7.0

<#
.SYNOPSIS
    Regenerate docs/reference/assessment-catalogue.md from manifests/assessments.psd1 and the
    rule files those assessments reference.

.DESCRIPTION
    There was no page anywhere listing the assessments Azure Scout actually performs. The
    closest things were `docs/assessment/assessment.md`, which said "24 assessments", and
    `docs/design/assessment-registry.md`, which said "23" — while the registry held 46. A
    reader had no way to answer "what does this tool assess", which is the first question
    anyone asks of it.

    Generated rather than hand-written for the same reason `Build-ArmModuleCatalog.ps1` is:
    the previous hand-maintained catalogue drifted 15 collectors out of date while claiming
    to be generated. Counts here come from the manifest and from counting `- id:` entries in
    the rule files, so they cannot disagree with the product.

    This script ALSO validates that every `Rules` glob in the registry matches at least one
    rule file, and fails in -Check mode when one does not. That check exists because
    `Assess: Storage` referenced `waf.storage` for some time after the file was deleted in the
    AB#6746 restructure, which silently dropped that assessment's WAF rules with no error.

.PARAMETER OutputPath
    Where to write the generated Markdown. Defaults to docs/reference/assessment-catalogue.md.

.PARAMETER Check
    Compare against the committed page and exit non-zero on any difference or any dangling
    rule reference. Used by tests/DocsAssessmentCatalog.Tests.ps1 and CI.

.EXAMPLE
    ./scripts/Build-AssessmentCatalog.ps1
    Regenerates the catalogue.

.EXAMPLE
    ./scripts/Build-AssessmentCatalog.ps1 -Check
    Verifies the committed page is current.
#>
[CmdletBinding()]
param(
    [string] $OutputPath,
    [switch] $Check
)

# After param(): a script may only carry comments and #Requires before [CmdletBinding()]/param.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot 'docs' 'reference' 'assessment-catalogue.md'
}

$Registry = Import-PowerShellDataFile (Join-Path $RepoRoot 'manifests' 'assessments.psd1')
$RulesDir = Join-Path $RepoRoot 'src' 'assess' 'rules'
$RuleFiles = @(Get-ChildItem -LiteralPath $RulesDir -Filter '*.yaml' -File)

# Rule counts per file, read once. A rule is a top-level `- id:` entry; a manual rule declares
# `manual: true` and is excluded from every score, so the two are reported separately.
$RuleStats = @{}
foreach ($f in $RuleFiles) {
    $lines = Get-Content -LiteralPath $f.FullName
    $RuleStats[$f.BaseName] = [pscustomobject]@{
        Total  = @($lines | Where-Object { $_ -match '^\s{2}-\s+id:' }).Count
        Manual = @($lines | Where-Object { $_ -match '^\s+manual:\s*true\s*$' }).Count
    }
}

function Get-Entry {
    param($Table, [string] $Key, $Default = $null)
    if ($Table.ContainsKey($Key) -and $null -ne $Table[$Key]) { return $Table[$Key] }
    return $Default
}

$Dangling = [System.Collections.Generic.List[string]]::new()
$Rows = [System.Collections.Generic.List[object]]::new()

foreach ($name in ($Registry.Keys | Sort-Object)) {
    $entry = $Registry[$name]
    $patterns = @(Get-Entry $entry 'Rules' @())

    $matched = [System.Collections.Generic.List[string]]::new()
    foreach ($pat in $patterns) {
        $hits = @($RuleStats.Keys | Where-Object { $_ -like $pat } | Sort-Object)
        if ($hits.Count -eq 0) { $Dangling.Add("$name -> '$pat'") }
        foreach ($h in $hits) { if (-not $matched.Contains($h)) { $matched.Add($h) } }
    }

    $total = 0; $manual = 0
    foreach ($m in $matched) { $total += $RuleStats[$m].Total; $manual += $RuleStats[$m].Manual }

    $Rows.Add([pscustomobject]@{
            Name        = $name
            Description = "$(Get-Entry $entry 'Description' '')"
            Frameworks  = @(Get-Entry $entry 'Frameworks' @())
            Category    = "$(Get-Entry $entry 'Category' '*')"
            Patterns    = $patterns
            RuleFiles   = $matched.ToArray()
            RuleCount   = $total
            ManualCount = $manual
            Automated   = $total - $manual
            Tags        = @(Get-Entry $entry 'Tags' @())
            Benchmark   = "$(Get-Entry $entry 'Benchmark' '')"
            Compliance  = [bool](Get-Entry $entry 'Compliance' $false)
            # Governance ingest decides the ARM scope an assessment needs: these require Reader
            # at the tenant-root management group to resolve fully, and degrade to an explicit
            # Unknown without it. Five separate pages hand-claimed "5 assessments" long after
            # the real number reached 26, so it is generated here rather than written anywhere.
            Governance  = (@(Get-Entry $entry 'Ingest' @()) -contains 'Governance')
        })
}

# ---- grouping: the three families a reader actually thinks in ----
function Get-Family {
    param($Row)
    if ($Row.Name -like 'WAF:*' -or $Row.Name -in 'Cost', 'Monitoring') { return 'Well-Architected Framework' }
    if ($Row.Name -like 'CAF:*' -or $Row.Name -in 'Governance', 'LandingZone', 'UpdateManager') { return 'Cloud Adoption Framework' }
    if ($Row.Name -like 'Assess:*') { return 'Service category slices' }
    return 'Specialised and workload assessments'
}

$Total = ($Rows | Measure-Object).Count
$GovCount = @($Rows | Where-Object { $_.Governance }).Count
$TotalRules = ($RuleStats.Values | Measure-Object -Property Total -Sum).Sum
$TotalManual = ($RuleStats.Values | Measure-Object -Property Manual -Sum).Sum

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('description: Every CAF, WAF and specialised assessment Azure Scout performs, with the rule files and rule counts behind each.')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('# Assessment Catalogue')
[void]$sb.AppendLine()
[void]$sb.AppendLine("Azure Scout ships **$Total assessments** backed by **$($RuleFiles.Count) rule files** holding")
[void]$sb.AppendLine("**$TotalRules rules**, of which **$($TotalRules - $TotalManual) are evaluated automatically** and")
[void]$sb.AppendLine("**$TotalManual require manual confirmation**.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('Run one, several, or all of them:')
[void]$sb.AppendLine()
[void]$sb.AppendLine('```powershell')
[void]$sb.AppendLine("Invoke-AzureScout -TenantID '<guid>' -Assessment 'LandingZone'")
[void]$sb.AppendLine("Invoke-AzureScout -TenantID '<guid>' -Assessment 'WAF: Security','Assess: Networking'")
[void]$sb.AppendLine("Invoke-AzureScout -TenantID '<guid>' -Assessment 'All'")
[void]$sb.AppendLine('```')
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: tip This page is generated')
[void]$sb.AppendLine('Regenerate it with `scripts/Build-AssessmentCatalog.ps1`. Rows and counts come from')
[void]$sb.AppendLine('`manifests/assessments.psd1` and `src/assess/rules/`; `tests/DocsAssessmentCatalog.Tests.ps1`')
[void]$sb.AppendLine('fails the build if the committed page and a fresh regeneration disagree. Do not hand-edit it.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()
[void]$sb.AppendLine("**$GovCount of the $Total assessments ingest governance data** and therefore need ARM ``Reader``")
[void]$sb.AppendLine('at the **tenant-root management group** to resolve fully; below that scope they degrade to an')
[void]$sb.AppendLine('explicit `Unknown` rather than a false zero. They are marked **Gov** in the tables below.')
[void]$sb.AppendLine('See [Auth & permissions per scan type](../assessment/assessment-permissions.md).')
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: warning Manual rules are not failures')
[void]$sb.AppendLine('A manual rule is one no collected data can decide — a process control, or a source Azure')
[void]$sb.AppendLine('does not expose. Manual rules are excluded from every score rather than counted as failures,')
[void]$sb.AppendLine('and they are reported separately. An assessment whose rules are largely manual produces a')
[void]$sb.AppendLine('worklist, not a grade.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()

foreach ($family in 'Cloud Adoption Framework', 'Well-Architected Framework', 'Service category slices', 'Specialised and workload assessments') {
    $group = @($Rows | Where-Object { (Get-Family $_) -eq $family } | Sort-Object Name)
    if ($group.Count -eq 0) { continue }

    [void]$sb.AppendLine("## $family ($($group.Count))")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Assessment | What it covers | Rules | Automated | Manual | Gov | Rule files |')
    [void]$sb.AppendLine('|---|---|--:|--:|--:|:-:|---|')
    foreach ($r in $group) {
        $desc = if ($r.Description) { $r.Description } elseif ($r.Frameworks.Count -gt 0) { $r.Frameworks -join '; ' } else { '—' }
        $files = if ($r.RuleFiles.Count -gt 0) { (($r.RuleFiles | ForEach-Object { "``$_``" }) -join '<br>') } else { '—' }
        $rules = if ($r.RuleCount -gt 0) { $r.RuleCount } else { '—' }
        $auto = if ($r.RuleCount -gt 0) { $r.Automated } else { '—' }
        $man = if ($r.RuleCount -gt 0) { $r.ManualCount } else { '—' }
        $gov = if ($r.Governance) { '**Gov**' } else { '' }
        [void]$sb.AppendLine("| **$($r.Name)** | $desc | $rules | $auto | $man | $gov | $files |")
    }
    [void]$sb.AppendLine()
}

[void]$sb.AppendLine('## Rule files')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Each file declares one framework area. An assessment selects files by glob.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Rule file | Rules | Automated | Manual |')
[void]$sb.AppendLine('|---|--:|--:|--:|')
foreach ($k in ($RuleStats.Keys | Sort-Object)) {
    $s = $RuleStats[$k]
    [void]$sb.AppendLine("| ``$k`` | $($s.Total) | $($s.Total - $s.Manual) | $($s.Manual) |")
}
[void]$sb.AppendLine()
[void]$sb.AppendLine("**Total — $($RuleFiles.Count) files, $TotalRules rules, $($TotalRules - $TotalManual) automated, $TotalManual manual.**")
[void]$sb.AppendLine()

$Content = $sb.ToString()

if ($Check) {
    $fail = $false
    if ($Dangling.Count -gt 0) {
        Write-Error ("Assessment registry references rule patterns that match no file:`n  " +
            ($Dangling -join "`n  ") +
            "`nEither restore the rule file or correct manifests/assessments.psd1 — a dangling glob silently drops rules.")
        $fail = $true
    }
    $committed = if (Test-Path -LiteralPath $OutputPath) { Get-Content -LiteralPath $OutputPath -Raw } else { '' }
    # Normalise line endings AND trailing newline: Set-Content appends one that the in-memory
    # string does not carry, so a byte comparison reports drift on a file it just wrote.
    $normalise = { param($s) (($s -replace "`r`n", "`n").TrimEnd("`n")) }
    if ((& $normalise $committed) -ne (& $normalise $Content)) {
        Write-Error "$OutputPath is out of date. Regenerate it with scripts/Build-AssessmentCatalog.ps1"
        $fail = $true
    }
    if ($fail) { exit 1 }
    Write-Host '[Build-AssessmentCatalog] docs/reference/assessment-catalogue.md is current.'
    exit 0
}

if ($Dangling.Count -gt 0) {
    Write-Warning ("Dangling rule references (page still written): " + ($Dangling -join '; '))
}
Set-Content -LiteralPath $OutputPath -Value $Content -Encoding utf8NoBOM
Write-Host "[Build-AssessmentCatalog] Wrote $OutputPath ($Total assessments, $TotalRules rules across $($RuleFiles.Count) files)"
