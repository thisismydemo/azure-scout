#Requires -Version 7.0

<#
.SYNOPSIS
    Test PPTX executive-deck generation from a previous data dump — no Azure
    connection required.

.DESCRIPTION
    Mirrors the Test-ExcelFromDataDump.ps1 / Test-PowerBIFromDataDump.ps1
    pattern: reads the synthetic JSON data dump from tests/datadump/, but
    since Export-Pptx (src/report/renderers/Export-Pptx.ps1) consumes the
    scored Findings contract produced by Get-Score (GeneratedOn/Frameworks/
    Areas/Gaps/Manual/Errors/Findings) rather than the raw ARM-inventory
    shape sample-report.json carries (that shape belongs to the legacy
    Modules/Public/InventoryModules Excel/Power BI pipeline), this harness
    synthesizes a plausible Findings array from sample-report.json's ARM
    category/module inventory — deterministic Pass/Partial/Fail/Manual/
    Unknown statuses across CAF and WAF, including deliberately blank/null
    severities on some Fail rows so the AB#5089 defensive sort/label guard
    (null/unknown severity sorts LAST, never throws) is actually exercised
    end-to-end through Get-Score -> Export-Pptx.

    This lets you iterate on deck layout/branding without a live Azure scan
    or a real assessment run every time.

.PARAMETER DataDumpPath
    Path to the data dump folder containing the JSON report.
    Defaults to tests/datadump/ relative to the repo root.

.PARAMETER OutputPath
    Where to write the generated deck. Defaults to tests/test-output/.

.EXAMPLE
    # From the repo root:
    .\tests\Test-PptxFromDataDump.ps1

.NOTES
    Requires: DocumentFormat.OpenXml (acquired on first use via dotnet/NuGet
    by Export-Pptx.ps1 itself — see Import-ScoutOpenXmlAssembly). No Az.*
    modules, no ImportExcel — this harness dot-sources only the assessment
    engine + report renderer files it needs, so it never triggers
    AzureScout.psm1's Install-Module bootstrap for unrelated dependencies.
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [string]$DataDumpPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve Paths ────────────────────────────────────────────────────────
$RepoRoot = Split-Path $PSScriptRoot -Parent

if (-not $DataDumpPath) {
    $DataDumpPath = Join-Path $RepoRoot 'tests' 'datadump'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot 'tests' 'test-output'
}

Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "  AzureScout — PPTX Report Test Harness" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan

# Find the JSON report file — prefer the synthetic sample if present
$SampleFile = Join-Path $DataDumpPath 'sample-report.json'
if (Test-Path $SampleFile) {
    $JsonFile = Get-Item $SampleFile
} else {
    $JsonFile = Get-ChildItem -Path $DataDumpPath -Filter '*.json' -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $JsonFile) {
    Write-Error "No JSON report file found in $DataDumpPath. Run .\tests\New-SyntheticSampleReport.ps1 first."
    return
}

Write-Host "  Source JSON:  " -NoNewline -ForegroundColor Gray
Write-Host $JsonFile.Name -ForegroundColor White

# ── Load only what Export-Pptx needs (no Az.*/ImportExcel bootstrap) ────
Write-Host "  Loading assessment engine + renderer..." -ForegroundColor Gray
. (Join-Path $RepoRoot 'src' 'assess' 'engine' 'Get-Score.ps1')
. (Join-Path $RepoRoot 'src' 'report' 'renderers' 'Export-Pptx.ps1')

# ── Parse the JSON Report ────────────────────────────────────────────────
Write-Host "  Parsing JSON report..." -ForegroundColor Gray
$ReportData = Get-Content $JsonFile.FullName -Raw | ConvertFrom-Json -Depth 40
$Metadata = $ReportData._metadata

Write-Host "  Tenant:       " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.tenantId ?? 'N/A') -ForegroundColor White
Write-Host "  Generated:    " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.generatedAt ?? 'N/A') -ForegroundColor White
Write-Host "  Scope:        " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.scope ?? 'N/A') -ForegroundColor White

# ── Synthesize a scored Findings object from the ARM category inventory ─
Write-Host "`n  Synthesizing findings from ARM category/module inventory..." -ForegroundColor Gray

$statuses = @('Pass', 'Pass', 'Partial', 'Fail', 'Manual', 'Unknown', 'Fail')
# Severities deliberately include $null and '' so the AB#5089 guard on the
# null/unknown-severity gap sort is exercised, not just the recognized values.
$severities = @('high', 'medium', 'low', $null, '', 'bogus-severity')

$findings = [System.Collections.Generic.List[object]]::new()
$i = 0
if ($ReportData.arm) {
    foreach ($categoryProp in $ReportData.arm.PSObject.Properties) {
        $framework = if (($i % 2) -eq 0) { 'CAF' } else { 'WAF' }
        $area = $categoryProp.Name.Substring(0, 1).ToUpper() + $categoryProp.Name.Substring(1)
        foreach ($moduleProp in $categoryProp.Value.PSObject.Properties) {
            $i++
            $status = $statuses[$i % $statuses.Count]
            $severity = if ($status -eq 'Fail') { $severities[$i % $severities.Count] } else { 'medium' }
            $findings.Add([pscustomobject]@{
                Id            = "$($categoryProp.Name)-$($moduleProp.Name)"
                Title         = "$($moduleProp.Name) compliance check"
                Framework     = $framework
                Area          = $area
                Severity      = $severity
                Status        = $status
                EvidenceCount = @($moduleProp.Value).Count
                Evidence      = @()
                Remediation   = "Review $($moduleProp.Name) configuration against the $framework baseline."
                Manual        = ($status -eq 'Manual')
                AreaWeight    = 1.0
            })
        }
    }
}

if ($findings.Count -eq 0) {
    Write-Error "sample-report.json produced zero synthetic findings — check its 'arm' section shape."
    return
}

Write-Host "  Synthetic findings: $($findings.Count) across $(@($findings.Framework | Select-Object -Unique).Count) framework(s), $(@($findings.Area | Select-Object -Unique).Count) area(s)" -ForegroundColor Green

$scored = Get-Score -Findings $findings
Write-Host "  Scored — Frameworks: $($scored.Frameworks.Count), Areas: $($scored.Areas.Count), Gaps: $($scored.Gaps.Count), Manual: $($scored.Manual.Count)" -ForegroundColor Green

# A minimal Collect-shaped object — Export-Pptx only reads _meta.scope /
# _meta.managementGroupId from it (Collect carries no tenant field in the
# real src/collect/Invoke-Collect.ps1 contract either).
$collect = [pscustomobject]@{
    _meta = [pscustomobject]@{
        generatedOn       = $Metadata.generatedAt
        scope             = $Metadata.scope
        managementGroupId = $Metadata.tenantId
    }
}

# ── Prepare Output Folder ────────────────────────────────────────────────
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

# ── Render the deck ──────────────────────────────────────────────────────
Write-Host "`n── Rendering PPTX ───────────────────────────────────────────" -ForegroundColor DarkCyan

$ValidationErrors = 0
$DeckFile = $null
$RenderTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $DeckFile = Export-Pptx -Findings $scored -Collect $collect -OutputPath $OutputPath
}
catch {
    $RenderTimer.Stop()
    Write-Host "  [FAIL] Export-Pptx threw — deck was not rendered." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host "`n═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan
    throw
}
$RenderTimer.Stop()
Write-Host "  Render time: " -NoNewline -ForegroundColor Green
Write-Host $RenderTimer.Elapsed.ToString("mm\:ss\.fff") -ForegroundColor Cyan
Write-Host "  Output file:  " -NoNewline -ForegroundColor Gray
Write-Host $DeckFile -ForegroundColor White

# ── Validate the rendered deck ───────────────────────────────────────────
Write-Host "`n── Validation ───────────────────────────────────────────────" -ForegroundColor DarkCyan

if (Test-Path $DeckFile) {
    $fileInfo = Get-Item $DeckFile
    Write-Host "  [OK] File exists" -ForegroundColor Green
    Write-Host "  [OK] Size: $([math]::Round($fileInfo.Length / 1KB, 1)) KB" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Deck file was not created: $DeckFile" -ForegroundColor Red
    $ValidationErrors++
}

$expectedMinSlides = 6   # title + summary + >=1 area page + >=1 gaps page + manual + next-steps
if (Test-Path $DeckFile) {
    try {
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        $zipBytes = [System.IO.File]::ReadAllBytes($DeckFile)
        $ms = [System.IO.MemoryStream]::new($zipBytes)
        $zip = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)

        # Theme part URI depends on which part it was added under (slideMaster vs.
        # presentation) — both are valid OPC placements, so match by filename pattern
        # rather than a hardcoded path.
        $required = @('[Content_Types].xml', 'ppt/presentation.xml', 'ppt/slideMasters/slideMaster1.xml')
        $entries = @($zip.Entries | Select-Object -ExpandProperty FullName)
        $missing = @($required | Where-Object { $_ -notin $entries })
        $hasTheme = @($entries | Where-Object { $_ -match 'theme\d*\.xml$' }).Count -gt 0
        if (-not $hasTheme) { $missing += 'theme*.xml (any location)' }
        if ($missing.Count -eq 0) {
            Write-Host "  [OK] Valid OPC/zip package — required parts present ($($entries.Count) entries total)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Missing required OPC parts: $($missing -join ', ')" -ForegroundColor Red
            $ValidationErrors++
        }

        $slideEntries = @($entries | Where-Object { $_ -match '^ppt/slides/slide\d+\.xml$' })
        Write-Host "  [OK] Slide count: $($slideEntries.Count)" -ForegroundColor Green
        if ($slideEntries.Count -lt $expectedMinSlides) {
            Write-Host "  [FAIL] Expected at least $expectedMinSlides slides (title, summary, area, gaps, manual, next-steps), found $($slideEntries.Count)" -ForegroundColor Red
            $ValidationErrors++
        }

        $zip.Dispose()
        $ms.Dispose()
    }
    catch {
        Write-Host "  [FAIL] Could not read the deck as a zip/OPC package: $_" -ForegroundColor Red
        $ValidationErrors++
    }

    # Full schema validation via the OpenXML SDK's own validator — this is the
    # strongest signal the package is actually well-formed PresentationML, not
    # just a zip with the right file names.
    try {
        $doc2 = [DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($DeckFile, $false)
        $validator = New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator
        $issues = @($validator.Validate($doc2))
        if ($issues.Count -eq 0) {
            Write-Host "  [OK] OpenXmlValidator: 0 schema issues" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] OpenXmlValidator found $($issues.Count) schema issue(s):" -ForegroundColor Red
            $issues | Select-Object -First 10 | ForEach-Object {
                Write-Host "         $($_.Description) [$($_.Part.Uri)]" -ForegroundColor Yellow
            }
            $ValidationErrors++
        }
        $doc2.Dispose()
    }
    catch {
        Write-Host "  [FAIL] OpenXmlValidator could not open the deck: $_" -ForegroundColor Red
        $ValidationErrors++
    }
}

# ── Final Summary ────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
if ($ValidationErrors -eq 0) {
    Write-Host "  SUCCESS — PPTX deck generated and validated" -ForegroundColor Green
} else {
    Write-Host "  FAILED — $ValidationErrors validation error(s)" -ForegroundColor Red
}
Write-Host "  File: $DeckFile" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan

if ($ValidationErrors -gt 0) { exit 1 }
