<#
.SYNOPSIS
    Test Excel report generation from a previous data dump — no Azure connection required.

.DESCRIPTION
    Reads the JSON report from tests/datadump/, reconstructs the ReportCache files,
    creates the required background jobs with synthetic data, and runs the full
    reporting + customization pipeline to produce an Excel workbook.

    This lets you iterate on Excel styling, tab ordering, chart generation, etc.
    without re-running a live Azure scan every time.

.PARAMETER DataDumpPath
    Path to the data dump folder containing the JSON report.
    Defaults to tests/datadump/ relative to the repo root.

.PARAMETER OutputPath
    Where to write the generated reports. Defaults to tests/test-output/.

.PARAMETER SkipCustomization
    Skip the Excel customization phase (Overview sheet, charts, ordering).
    Useful when you only want to test raw data sheet generation.

.EXAMPLE
    # From the repo root:
    .\tests\Test-ExcelFromDataDump.ps1

.EXAMPLE
    # With custom paths:
    .\tests\Test-ExcelFromDataDump.ps1 -OutputPath C:\temp\excel-test

.NOTES
    Requires: ImportExcel module
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [string]$DataDumpPath,
    [string]$OutputPath,
    [switch]$SkipCustomization
)

$ErrorActionPreference = 'Stop'

# ── Resolve Paths ────────────────────────────────────────────────────────
$RepoRoot = Split-Path $PSScriptRoot -Parent

if (-not $DataDumpPath) {
    $DataDumpPath = Join-Path $RepoRoot 'tests' 'datadump'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot 'tests' 'test-output'
}

# ── Validate Prerequisites ───────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "  AzureScout — Excel Report Test Harness" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan

# Find the JSON report file
$JsonFile = Get-ChildItem -Path $DataDumpPath -Filter '*.json' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $JsonFile) {
    Write-Error "No JSON report file found in $DataDumpPath. Run a live scan first to generate test data."
    return
}

Write-Host "  Source JSON:  " -NoNewline -ForegroundColor Gray
Write-Host $JsonFile.Name -ForegroundColor White

# Import the module
$ModulePath = Join-Path $RepoRoot 'AzureScout.psm1'
if (-not (Test-Path $ModulePath)) {
    Write-Error "Cannot find AzureScout.psm1 at $RepoRoot"
    return
}

Write-Host "  Loading module..." -ForegroundColor Gray
Import-Module $ModulePath -Force -DisableNameChecking

# Check ImportExcel
if (-not (Get-Module -ListAvailable ImportExcel)) {
    Write-Error "ImportExcel module is required. Install with: Install-Module ImportExcel -Scope CurrentUser"
    return
}

# ── Parse the JSON Report ────────────────────────────────────────────────
Write-Host "  Parsing JSON report..." -ForegroundColor Gray

$Reader   = New-Object System.IO.StreamReader($JsonFile.FullName)
$RawJson  = $Reader.ReadToEnd()
$Reader.Dispose()

$ReportData = $RawJson | ConvertFrom-Json

$Metadata = $ReportData._metadata
Write-Host "  Tenant:       " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.tenantId ?? 'N/A') -ForegroundColor White
Write-Host "  Generated:    " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.generatedAt ?? 'N/A') -ForegroundColor White
Write-Host "  Scope:        " -NoNewline -ForegroundColor Gray
Write-Host ($Metadata.scope ?? 'N/A') -ForegroundColor White

# ── Prepare Output Folders ───────────────────────────────────────────────
Write-Host "`n  Preparing output folders..." -ForegroundColor Gray

$ReportCache  = Join-Path $OutputPath 'ReportCache'
$DiagramCache = Join-Path $OutputPath 'DiagramCache'

# Clean previous test output
if (Test-Path $ReportCache)  { Remove-Item $ReportCache  -Recurse -Force }
if (Test-Path $DiagramCache) { Remove-Item $DiagramCache -Recurse -Force }

New-Item -ItemType Directory -Path $ReportCache  -Force | Out-Null
New-Item -ItemType Directory -Path $DiagramCache -Force | Out-Null

# ── Reconstruct ReportCache from JSON ────────────────────────────────────
Write-Host "  Rebuilding ReportCache from JSON..." -ForegroundColor Gray

# Helper: reverse camelCase → PascalCase (first letter uppercase)
function ConvertTo-PascalCase {
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $Name }
    return $Name.Substring(0, 1).ToUpper() + $Name.Substring(1)
}

# Build the InventoryModules folder map for key validation
$InventoryModulesPath = Join-Path $RepoRoot 'Modules' 'Public' 'InventoryModules'
$ModuleFolders = Get-ChildItem -Path $InventoryModulesPath -Directory

# Map of lowercase folder name → actual folder name (for matching JSON keys)
$FolderMap = @{}
foreach ($folder in $ModuleFolders) {
    $FolderMap[$folder.Name.ToLower()] = $folder.Name
}

# Map of lowercase module name → actual module BaseName
$ModuleMap = @{}
foreach ($folder in $ModuleFolders) {
    foreach ($mod in (Get-ChildItem $folder.FullName -Filter '*.ps1')) {
        $ModuleMap[$mod.BaseName.ToLower()] = $mod.BaseName
    }
}

$CacheFilesCreated = 0

# Process ARM data
if ($ReportData.arm) {
    foreach ($categoryProp in $ReportData.arm.PSObject.Properties) {
        $jsonCategoryKey = $categoryProp.Name           # e.g. "compute"
        $categoryData    = $categoryProp.Value

        # Find the matching folder name (PascalCase)
        $folderName = $FolderMap[$jsonCategoryKey.ToLower()]
        if (-not $folderName) {
            $folderName = ConvertTo-PascalCase $jsonCategoryKey
        }

        # Build the cache object: keys = PascalCase module names, values = arrays
        $cacheObj = [ordered]@{}
        foreach ($moduleProp in $categoryData.PSObject.Properties) {
            $jsonModuleKey = $moduleProp.Name            # e.g. "virtualMachineScaleSet"
            $moduleData    = $moduleProp.Value

            # Find the matching .ps1 basename
            $moduleName = $ModuleMap[$jsonModuleKey.ToLower()]
            if (-not $moduleName) {
                $moduleName = ConvertTo-PascalCase $jsonModuleKey
            }

            $cacheObj[$moduleName] = @($moduleData)
        }

        if ($cacheObj.Count -gt 0) {
            $CacheFile = Join-Path $ReportCache "$folderName.json"
            $cacheObj | ConvertTo-Json -Depth 40 | Out-File -FilePath $CacheFile -Encoding utf8
            $CacheFilesCreated++
            Write-Host "    [+] $folderName.json ($($cacheObj.Count) modules)" -ForegroundColor Green
        }
    }
}

# Process Entra/Identity data
if ($ReportData.entra) {
    $entraObj = [ordered]@{}
    foreach ($moduleProp in $ReportData.entra.PSObject.Properties) {
        $jsonModuleKey = $moduleProp.Name
        $moduleData    = $moduleProp.Value

        $moduleName = $ModuleMap[$jsonModuleKey.ToLower()]
        if (-not $moduleName) {
            $moduleName = ConvertTo-PascalCase $jsonModuleKey
        }

        $entraObj[$moduleName] = @($moduleData)
    }

    if ($entraObj.Count -gt 0) {
        $CacheFile = Join-Path $ReportCache "Identity.json"
        $entraObj | ConvertTo-Json -Depth 40 | Out-File -FilePath $CacheFile -Encoding utf8
        $CacheFilesCreated++
        Write-Host "    [+] Identity.json ($($entraObj.Count) modules)" -ForegroundColor Green
    }
}

# Write extra cache files (Advisory, Policy, Security) if present in JSON
if ($ReportData.advisory) {
    $ReportData.advisory | ConvertTo-Json -Depth 40 | Out-File (Join-Path $ReportCache 'Advisory.json') -Encoding utf8
    Write-Host "    [+] Advisory.json" -ForegroundColor Green
}
if ($ReportData.policy) {
    $ReportData.policy | ConvertTo-Json -Depth 40 | Out-File (Join-Path $ReportCache 'Policy.json') -Encoding utf8
    Write-Host "    [+] Policy.json" -ForegroundColor Green
}
if ($ReportData.security) {
    $ReportData.security | ConvertTo-Json -Depth 40 | Out-File (Join-Path $ReportCache 'SecurityCenter.json') -Encoding utf8
    Write-Host "    [+] SecurityCenter.json" -ForegroundColor Green
}

Write-Host "`n  ReportCache: $CacheFilesCreated category files created." -ForegroundColor Cyan

# ── Build Synthetic Background Jobs ──────────────────────────────────────
Write-Host "`n  Creating synthetic background jobs..." -ForegroundColor Gray

# Clean up any leftover jobs from previous runs
'Subscriptions', 'Advisory', 'Policy', 'Security' | ForEach-Object {
    Get-Job -Name $_ -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
}

# Build a synthetic subscriptions list from metadata
$SyntheticSubs = @()
if ($Metadata.subscriptions) {
    foreach ($sub in $Metadata.subscriptions) {
        $SyntheticSubs += [PSCustomObject]@{
            Name = $sub.name
            Id   = $sub.id
        }
    }
}

# The Subscriptions job must return data in the format expected by Build-AZSCSubsReport.
# It expects objects with: Subscription, SubscriptionId, Resource Group, Location, Resource Type, Resources Count
$SubJobData = @()
foreach ($sub in $SyntheticSubs) {
    $SubJobData += [PSCustomObject]@{
        'Subscription'    = $sub.Name
        'SubscriptionId'  = $sub.Id
        'Resource Group'  = '(test data)'
        'Location'        = '(test data)'
        'Resource Type'   = '(test data)'
        'Resources Count' = 0
    }
}

# Start the Subscriptions job (always required — not skippable)
Start-Job -Name 'Subscriptions' -ScriptBlock { $args[0] } -ArgumentList @(,$SubJobData) | Out-Null
Write-Host "    [+] Subscriptions job (synthetic)" -ForegroundColor Green

# ── Set Up Excel File Path ───────────────────────────────────────────────
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH_mm'
$FileName  = "AzureScout_TestReport_$Timestamp.xlsx"
$File      = Join-Path $OutputPath $FileName

Write-Host "`n  Output file:  " -NoNewline -ForegroundColor Gray
Write-Host $File -ForegroundColor White

# ── Phase 1: Report Orchestration ────────────────────────────────────────
Write-Host "`n── Phase 1: Report Generation ──────────────────────────────" -ForegroundColor DarkCyan

$ReportingTimer = [System.Diagnostics.Stopwatch]::StartNew()

Start-AZSCReporOrchestration `
    -ReportCache  $ReportCache `
    -SecurityCenter ([switch]::new($false)) `
    -File         $File `
    -Quotas       $null `
    -SkipPolicy   ([switch]::new($true)) `
    -SkipAdvisory ([switch]::new($true)) `
    -IncludeCosts ([switch]::new($false)) `
    -Automation   ([switch]::new($false)) `
    -TableStyle   'Light19'

$ReportingTimer.Stop()
Write-Host "  Report generation: " -NoNewline -ForegroundColor Green
Write-Host $ReportingTimer.Elapsed.ToString("mm\:ss\.fff") -ForegroundColor Cyan

# ── Phase 2: Excel Customization ─────────────────────────────────────────
if (-not $SkipCustomization.IsPresent) {
    Write-Host "`n── Phase 2: Excel Customization ────────────────────────────" -ForegroundColor DarkCyan

    $CustomTimer = [System.Diagnostics.Stopwatch]::StartNew()

    $TotalRes = Start-AZSCExcelCustomization `
        -File              $File `
        -TableStyle        'Light19' `
        -PlatOS            'Windows' `
        -Subscriptions     $SyntheticSubs `
        -ExtractionRunTime ([System.Diagnostics.Stopwatch]::new()) `
        -ProcessingRunTime ([System.Diagnostics.Stopwatch]::new()) `
        -ReportingRunTime  ([System.Diagnostics.Stopwatch]::new()) `
        -IncludeCosts      ([switch]::new($false)) `
        -RunLite           $false `
        -Overview          $null `
        -Category          $null

    $CustomTimer.Stop()
    Write-Host "  Customization:     " -NoNewline -ForegroundColor Green
    Write-Host $CustomTimer.Elapsed.ToString("mm\:ss\.fff") -ForegroundColor Cyan
    Write-Host "  Total resources:   " -NoNewline -ForegroundColor Gray
    Write-Host $TotalRes -ForegroundColor White
}

# ── Cleanup Jobs ─────────────────────────────────────────────────────────
'Subscriptions', 'Advisory', 'Policy', 'Security' | ForEach-Object {
    Get-Job -Name $_ -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
}

# ── Summary ──────────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

if (Test-Path $File) {
    $FileInfo = Get-Item $File
    Write-Host "  SUCCESS — Excel report generated" -ForegroundColor Green
    Write-Host "  File: $File" -ForegroundColor White
    Write-Host "  Size: $([math]::Round($FileInfo.Length / 1KB, 1)) KB" -ForegroundColor Gray
}
else {
    Write-Host "  FAILED — Excel file was not created" -ForegroundColor Red
}

Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan
