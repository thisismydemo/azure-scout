<#
.SYNOPSIS
    Test Power BI report generation from a previous data dump — no Azure connection required.

.DESCRIPTION
    Reads the JSON report from tests/datadump/, reconstructs the ReportCache files,
    creates the Power BI CSV bundle via Export-AZSCPowerBIReport, then packages
    everything into a Power BI Template (.pbit) via New-AZSCPowerBITemplate.

    The resulting .pbit file can be opened directly in Power BI Desktop. On open,
    Desktop will prompt to refresh data — clicking Refresh loads all resource tables
    from the CSV bundle so you can explore, build visuals, and validate the data model.

    This is the Power BI equivalent of Test-ExcelFromDataDump.ps1. It lets you
    iterate on CSV column structure, naming conventions, relationship design, and
    data quality without running a live Azure scan every time.

.PARAMETER DataDumpPath
    Path to the data dump folder containing the JSON report.
    Defaults to tests/datadump/ relative to the repo root.

.PARAMETER OutputPath
    Where to write the generated reports. Defaults to tests/test-output/.

.PARAMETER SkipTemplate
    Skip the .pbit template generation phase — only run the CSV export.
    Useful when iterating on raw CSV output before packaging.

.PARAMETER OpenTemplate
    Automatically open the generated .pbit in Power BI Desktop when complete.
    Requires Power BI Desktop to be installed.

.EXAMPLE
    # From the repo root — generates CSV bundle + .pbit:
    .\tests\Test-PowerBIFromDataDump.ps1

.EXAMPLE
    # Only regenerate CSVs, skip pbit:
    .\tests\Test-PowerBIFromDataDump.ps1 -SkipTemplate

.EXAMPLE
    # Generate and immediately open in Power BI Desktop:
    .\tests\Test-PowerBIFromDataDump.ps1 -OpenTemplate

.NOTES
    No additional modules required beyond PowerShell 7+.
    Version: 2.0.0
#>

[CmdletBinding()]
param(
    [string]$DataDumpPath,
    [string]$OutputPath,
    [switch]$SkipTemplate,
    [switch]$OpenTemplate
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
Write-Host "  AzureScout — Power BI Report Test Harness" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan

# Find the JSON report file
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

# Import the module
$ModulePath = Join-Path $RepoRoot 'AzureScout.psm1'
if (-not (Test-Path $ModulePath)) {
    Write-Error "Cannot find AzureScout.psm1 at $RepoRoot"
    return
}

Write-Host "  Loading module..." -ForegroundColor Gray
Import-Module $ModulePath -Force -DisableNameChecking

# Stub Register-AZSCInventoryModule in case any private module uses it
if (-not (Get-Command 'Register-AZSCInventoryModule' -ErrorAction SilentlyContinue)) {
    function global:Register-AZSCInventoryModule {
        param($ModuleId, $PhaseId, $ScriptBlock)
        # no-op stub
    }
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

# Helper: PascalCase
function ConvertTo-PascalCase {
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $Name }
    return $Name.Substring(0, 1).ToUpper() + $Name.Substring(1)
}

# Build module name lookup maps
$InventoryModulesPath = Join-Path $RepoRoot 'Modules' 'Public' 'InventoryModules'
$ModuleFolders = Get-ChildItem -Path $InventoryModulesPath -Directory

$FolderMap = @{}
foreach ($folder in $ModuleFolders) {
    $FolderMap[$folder.Name.ToLower()] = $folder.Name
}

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
        $jsonCategoryKey = $categoryProp.Name
        $categoryData    = $categoryProp.Value

        $folderName = $FolderMap[$jsonCategoryKey.ToLower()]
        if (-not $folderName) {
            $folderName = ConvertTo-PascalCase $jsonCategoryKey
        }

        $cacheObj = [ordered]@{}
        foreach ($moduleProp in $categoryData.PSObject.Properties) {
            $jsonModuleKey = $moduleProp.Name
            $moduleData    = $moduleProp.Value

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

# Advisory / Policy / Security extra cache files
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

# ── Build synthetic subscriptions list ──────────────────────────────────
$SyntheticSubs = @()
if ($Metadata.subscriptions) {
    foreach ($sub in $Metadata.subscriptions) {
        $SyntheticSubs += [PSCustomObject]@{
            Name = $sub.name
            Id   = $sub.id
        }
    }
}

# ── Set up output file path (base path — PowerBI dir will be a sibling) ──
$Timestamp = Get-Date -Format 'yyyy-MM-dd_HH_mm'
$FileName  = "AzureScout_TestReport_$Timestamp"
$File      = Join-Path $OutputPath "$FileName.xlsx"

Write-Host "`n  Base file path: " -NoNewline -ForegroundColor Gray
Write-Host $File -ForegroundColor White

# ══════════════════════════════════════════════════════════════════════════
# Phase 1: CSV Export
# ══════════════════════════════════════════════════════════════════════════
Write-Host "`n── Phase 1: Power BI CSV Export ────────────────────────────" -ForegroundColor DarkCyan

$ExportTimer = [System.Diagnostics.Stopwatch]::StartNew()

$PowerBIDir = Export-AZSCPowerBIReport `
    -ReportCache   $ReportCache `
    -File          $File `
    -TenantID      ($Metadata.tenantId ?? 'test-tenant') `
    -Subscriptions $SyntheticSubs `
    -Scope         ($Metadata.scope ?? 'All')

$ExportTimer.Stop()
Write-Host "  CSV export time:   " -NoNewline -ForegroundColor Green
Write-Host $ExportTimer.Elapsed.ToString("mm\:ss\.fff") -ForegroundColor Cyan

# ── Validate CSV bundle ──────────────────────────────────────────────────
Write-Host "`n── Phase 1 Validation ──────────────────────────────────────" -ForegroundColor DarkCyan

$ValidationErrors = 0

if (Test-Path $PowerBIDir) {
    Write-Host "  [OK] PowerBI output directory exists" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] PowerBI output directory not found: $PowerBIDir" -ForegroundColor Red
    $ValidationErrors++
}

$metaFile = Join-Path $PowerBIDir '_metadata.csv'
if (Test-Path $metaFile) {
    $metaContent = Import-Csv $metaFile
    Write-Host "  [OK] _metadata.csv ($($metaContent.Count) rows)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] _metadata.csv not found" -ForegroundColor Red
    $ValidationErrors++
}

$subsFile = Join-Path $PowerBIDir 'Subscriptions.csv'
if (Test-Path $subsFile) {
    $subsContent = Import-Csv $subsFile
    Write-Host "  [OK] Subscriptions.csv ($($subsContent.Count) rows)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Subscriptions.csv not found" -ForegroundColor Red
    $ValidationErrors++
}

$relFile = Join-Path $PowerBIDir '_relationships.json'
if (Test-Path $relFile) {
    $relContent = Get-Content $relFile -Raw | ConvertFrom-Json
    Write-Host "  [OK] _relationships.json ($(@($relContent.relationships).Count) relationships)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] _relationships.json not found" -ForegroundColor Red
    $ValidationErrors++
}

$resourceCsvs = Get-ChildItem -Path $PowerBIDir -Filter 'Resources_*.csv' -ErrorAction SilentlyContinue
$entraCsvs    = Get-ChildItem -Path $PowerBIDir -Filter 'Entra_*.csv'     -ErrorAction SilentlyContinue
$allCsvFiles  = Get-ChildItem -Path $PowerBIDir -Filter '*.csv'           -ErrorAction SilentlyContinue

if ($resourceCsvs -and $resourceCsvs.Count -gt 0) {
    Write-Host "  [OK] Resources_*.csv: $($resourceCsvs.Count) files" -ForegroundColor Green
} else {
    Write-Host "  [WARN] No Resources_*.csv files found" -ForegroundColor Yellow
}
if ($entraCsvs -and $entraCsvs.Count -gt 0) {
    Write-Host "  [OK] Entra_*.csv: $($entraCsvs.Count) files" -ForegroundColor Green
} else {
    Write-Host "  [WARN] No Entra_*.csv files found" -ForegroundColor Yellow
}

# Spot-check: _Category and _Module columns
if ($resourceCsvs -and $resourceCsvs.Count -gt 0) {
    $sampleCsv = Import-Csv $resourceCsvs[0].FullName
    if ($sampleCsv.Count -gt 0) {
        $cols = $sampleCsv[0].PSObject.Properties.Name
        if ($cols -contains '_Category') {
            Write-Host "  [OK] _Category column present in $($resourceCsvs[0].Name)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] _Category column missing in $($resourceCsvs[0].Name)" -ForegroundColor Red
            $ValidationErrors++
        }
        if ($cols -contains '_Module') {
            Write-Host "  [OK] _Module column present in $($resourceCsvs[0].Name)" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] _Module column missing in $($resourceCsvs[0].Name)" -ForegroundColor Red
            $ValidationErrors++
        }
    }
}

$totalCSVRows = 0
foreach ($csv in $allCsvFiles) {
    $rows = Import-Csv $csv.FullName -ErrorAction SilentlyContinue
    $totalCSVRows += @($rows).Count
}
Write-Host "  Total CSV files: $(@($allCsvFiles).Count)  |  Total rows: $totalCSVRows" -ForegroundColor Gray

# ══════════════════════════════════════════════════════════════════════════
# Phase 2: Power BI Template (.pbit) generation
# ══════════════════════════════════════════════════════════════════════════
$PbitFile = $null

if (-not $SkipTemplate.IsPresent) {
    Write-Host "`n── Phase 2: Power BI Template (.pbit) Generation ───────────" -ForegroundColor DarkCyan

    $PbitFileName = "AzureScout_TestReport_$(Get-Date -Format 'yyyy-MM-dd_HH_mm').pbit"
    $PbitFile     = Join-Path $OutputPath $PbitFileName

    Write-Host "  Output file:  " -NoNewline -ForegroundColor Gray
    Write-Host $PbitFile -ForegroundColor White

    $TemplateTimer = [System.Diagnostics.Stopwatch]::StartNew()

    $PbitFile = New-AZSCPowerBITemplate `
        -PowerBIDir $PowerBIDir `
        -OutputFile $PbitFile

    $TemplateTimer.Stop()
    Write-Host "  Template time: " -NoNewline -ForegroundColor Green
    Write-Host $TemplateTimer.Elapsed.ToString("mm\:ss\.fff") -ForegroundColor Cyan

    # Validate the .pbit
    Write-Host "`n── Phase 2 Validation ──────────────────────────────────────" -ForegroundColor DarkCyan

    if (Test-Path $PbitFile) {
        $pbitInfo = Get-Item $PbitFile
        Write-Host "  [OK] .pbit file exists" -ForegroundColor Green
        Write-Host "  [OK] Size: $([math]::Round($pbitInfo.Length / 1KB, 1)) KB" -ForegroundColor Green

        try {
            Add-Type -AssemblyName System.IO.Compression
            $zipBytes = [System.IO.File]::ReadAllBytes($PbitFile)
            $ms  = [System.IO.MemoryStream]::new($zipBytes)
            $zip = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)

            $required = @('[Content_Types].xml', 'Version', 'DataModelSchema', 'Mashup', 'Report/Layout')
            $entries  = $zip.Entries | Select-Object -ExpandProperty FullName
            $missing  = $required | Where-Object { $_ -notin $entries }

            if ($missing.Count -eq 0) {
                Write-Host "  [OK] All required OPC entries present ($($entries.Count) total)" -ForegroundColor Green
            } else {
                Write-Host "  [FAIL] Missing OPC entries: $($missing -join ', ')" -ForegroundColor Red
                $ValidationErrors++
            }

            # Check DataModelSchema table count
            $dmsEntry = $zip.Entries | Where-Object { $_.FullName -eq 'DataModelSchema' }
            if ($dmsEntry) {
                $sr      = [System.IO.StreamReader]::new($dmsEntry.Open())
                $dmsJson = $sr.ReadToEnd()
                $sr.Dispose()
                $tableCount = @(($dmsJson | ConvertFrom-Json).tables).Count
                Write-Host "  [OK] DataModelSchema: $tableCount tables defined" -ForegroundColor Green
            }
            $zip.Dispose()
            $ms.Dispose()
        }
        catch {
            Write-Host "  [FAIL] Could not read .pbit as ZIP: $_" -ForegroundColor Red
            $ValidationErrors++
        }
    } else {
        Write-Host "  [FAIL] .pbit file was not created" -ForegroundColor Red
        $ValidationErrors++
    }
}

# ── Open in Power BI Desktop (optional) ─────────────────────────────────
if ($OpenTemplate.IsPresent -and $PbitFile -and (Test-Path $PbitFile)) {
    $pbiPaths = @(
        "${env:ProgramFiles}\Microsoft Power BI Desktop\bin\PBIDesktop.exe",
        "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin\PBIDesktop.exe",
        "${env:LOCALAPPDATA}\Microsoft\WindowsApps\PBIDesktop.exe"
    )
    $pbiExe = $pbiPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($pbiExe) {
        Write-Host "`n  Opening Power BI Desktop..." -ForegroundColor Cyan
        Start-Process -FilePath $pbiExe -ArgumentList "`"$PbitFile`""
    } else {
        Write-Host "`n  [INFO] Power BI Desktop not found — attempting OS default handler." -ForegroundColor Yellow
        try { Start-Process $PbitFile } catch { }
    }
}

# ── Final Summary ────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan

if ($ValidationErrors -eq 0) {
    Write-Host "  SUCCESS" -ForegroundColor Green
} else {
    Write-Host "  COMPLETED with $ValidationErrors validation error(s)" -ForegroundColor Yellow
}

$dirSize = (Get-ChildItem $PowerBIDir -Recurse | Measure-Object Length -Sum).Sum
Write-Host ""
Write-Host "  CSV bundle:" -ForegroundColor Gray
Write-Host "    Directory : $PowerBIDir" -ForegroundColor White
Write-Host "    CSV files : $(@($allCsvFiles).Count)" -ForegroundColor Gray
Write-Host "    Total rows: $totalCSVRows" -ForegroundColor Gray
Write-Host "    Size      : $([math]::Round($dirSize / 1KB, 1)) KB" -ForegroundColor Gray

if ($PbitFile -and (Test-Path $PbitFile)) {
    $pbitSizeKB = [math]::Round((Get-Item $PbitFile).Length / 1KB, 1)
    Write-Host ""
    Write-Host "  Power BI Template (.pbit):" -ForegroundColor Gray
    Write-Host "    File  : $PbitFile" -ForegroundColor White
    Write-Host "    Size  : $pbitSizeKB KB" -ForegroundColor Gray
    Write-Host "    Open  : Double-click the .pbit in Explorer, or run with -OpenTemplate" -ForegroundColor DarkGray
}

Write-Host "`n  CSV file listing:" -ForegroundColor Gray
Get-ChildItem $PowerBIDir | Sort-Object Name | ForEach-Object {
    $size = [math]::Round($_.Length / 1KB, 1)
    Write-Host "    $($_.Name) ($size KB)" -ForegroundColor DarkGray
}

Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan
