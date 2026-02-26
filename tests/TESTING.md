# Azure Scout — Testing Platform

This document describes how the Azure Scout testing infrastructure works, including the synthetic data pipeline, offline report generation, and how to extend it for new output formats.

## Overview

Azure Scout's test suite is designed so that **no live Azure connection is required** for the vast majority of tests. The key insight is that report generation (Excel, JSON, Markdown, AsciiDoc, Power BI CSV) can be fully tested using **synthetic data** that mimics what a real Azure scan would produce.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Synthetic Data Pipeline                          │
│                                                                     │
│  1. New-SyntheticSampleReport.ps1                                   │
│     └─ Reads every InventoryModule .ps1 column schema               │
│     └─ Generates 3 fake rows per module (Contoso-themed)            │
│     └─ Outputs: tests/datadump/sample-report.json                   │
│                                                                     │
│  2. Test-ExcelFromDataDump.ps1                                      │
│     └─ Reads sample-report.json                                     │
│     └─ Reconstructs ReportCache folder from JSON                    │
│     └─ Runs full Excel pipeline (reporting + customization)         │
│     └─ Outputs: tests/test-output/AzureScout_TestReport_*.xlsx      │
│                                                                     │
│  3. Test-PowerBIFromDataDump.ps1                                    │
│     └─ Reads sample-report.json                                     │
│     └─ Reconstructs ReportCache folder from JSON                    │
│     └─ Runs Power BI CSV export pipeline                            │
│     └─ Outputs: tests/test-output/PowerBI/*.csv + manifest          │
│                                                                     │
│  (Future: Test-DrawIOFromDataDump.ps1, etc.)                        │
└─────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
tests/
├── TESTING.md                          ← This document
├── datadump/
│   └── sample-report.json              ← Synthetic inventory data (JSON)
├── test-output/
│   ├── AzureScout_TestReport_*.xlsx     ← Excel test outputs
│   ├── PowerBI/                         ← Power BI CSV test outputs
│   │   ├── _metadata.csv
│   │   ├── _relationships.json
│   │   ├── Subscriptions.csv
│   │   ├── Resources_*.csv
│   │   └── Entra_*.csv
│   ├── DiagramCache/                    ← Draw.IO cache (future)
│   └── ReportCache/                     ← Reconstructed cache files
├── New-SyntheticSampleReport.ps1       ← Generator script
├── Test-ExcelFromDataDump.ps1          ← Excel test harness
├── Test-PowerBIFromDataDump.ps1        ← Power BI CSV test harness
├── *.Tests.ps1                          ← Pester test files
└── Test-ExcelFromDataDump.ps1          ← Excel integration test
```

## Step 1: Generate Synthetic Data

The synthetic data generator reads every inventory module's reporting schema and produces fake but structurally valid data.

### Running the Generator

```powershell
# From the repo root
.\tests\New-SyntheticSampleReport.ps1
```

### What It Does

1. Scans every `.ps1` file under `Modules/Public/InventoryModules/` (all categories: AI, Analytics, Compute, Containers, Databases, Hybrid, Identity, Integration, IoT, Management, Monitor, Networking, Security, Storage, Web)
2. Extracts column names from each module's `$Exc.Add('FieldName')` calls (the definitive column list used in reporting)
3. Falls back to parsing `@{ 'Key' = $value }` patterns if `$Exc.Add` is not found
4. Generates 3 rows per module using the `Get-FakeValue` function, which maps field name patterns to realistic Contoso-themed values
5. Writes the result to `tests/datadump/sample-report.json`

### Data Structure

The JSON matches what `Export-AZSCJsonReport` produces during a live scan:

```json
{
  "_metadata": {
    "tool": "AzureScout",
    "version": "1.0.0",
    "tenantId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "subscriptions": [...],
    "generatedAt": "2026-02-25T12:00:00Z",
    "scope": "All"
  },
  "arm": {
    "compute": {
      "virtualMachines": [ { "Name": "...", "Location": "...", ... } ],
      "virtualMachineScaleSets": [ ... ]
    },
    "networking": { ... },
    ...
  },
  "entra": {
    "users": [ ... ],
    "groups": [ ... ],
    "appRegistrations": [ ... ],
    ...
  }
}
```

### When to Regenerate

Run `New-SyntheticSampleReport.ps1` whenever:
- A new inventory module is added
- Column names change in an existing module's reporting section
- New categories are introduced

The generated `sample-report.json` is checked into source control so CI can use it without needing to regenerate.

## Step 2: Test Report Outputs

### Excel Report Testing

```powershell
# Basic run — generates Excel report with all customization
.\tests\Test-ExcelFromDataDump.ps1

# Skip the customization phase (Overview sheet, charts, tab ordering)
.\tests\Test-ExcelFromDataDump.ps1 -SkipCustomization

# Custom output path
.\tests\Test-ExcelFromDataDump.ps1 -OutputPath C:\temp\excel-test
```

**What it does:**
1. Loads `sample-report.json`
2. Rebuilds `ReportCache/` folder — one JSON file per category (Compute.json, Networking.json, Identity.json, etc.)
3. Creates synthetic PowerShell background jobs (mimicking what the live scan pipeline produces)
4. Calls `Start-AZSCReporOrchestration` (Phase 1: raw data sheets)
5. Calls `Start-AZSCExcelCustomization` (Phase 2: Overview sheet, charts, tab ordering)
6. Validates the `.xlsx` file was created and reports its size

**Requirements:** `ImportExcel` module (`Install-Module ImportExcel -Scope CurrentUser`)

### Power BI CSV Testing

```powershell
# Basic run — generates Power BI CSV bundle
.\tests\Test-PowerBIFromDataDump.ps1

# Custom output path
.\tests\Test-PowerBIFromDataDump.ps1 -OutputPath C:\temp\powerbi-test
```

**What it does:**
1. Loads `sample-report.json`
2. Rebuilds `ReportCache/` folder (same as Excel test)
3. Calls `Export-AZSCPowerBIReport` to generate flat CSV files
4. Validates CSV count, column headers, metadata file, and relationships manifest
5. Reports a summary of generated files

**Requirements:** None beyond PowerShell 7+

### Future: Draw.IO Diagram Testing

The same pattern will extend to Draw.IO diagram testing:
1. Read `sample-report.json`
2. Reconstruct resource data
3. Call diagram generation functions
4. Validate `.drawio` XML output

## Step 3: Run Pester Tests

```powershell
# Run all tests
Invoke-Pester -Path ./tests/ -Output Detailed

# Run specific test file
Invoke-Pester -Path ./tests/OutputFormat.Tests.ps1 -Output Detailed

# Run with code coverage
Invoke-Pester -Path ./tests/ -CodeCoverage ./Modules/ -Output Detailed
```

### Key Pester Test Files

| File | What It Tests |
|------|---------------|
| `AzureScout.Tests.ps1` | Module manifest, exported functions |
| `Invoke-AzureScout.Tests.ps1` | Main function parameters, ValidateSet, aliases |
| `OutputFormat.Tests.ps1` | OutputFormat ValidateSet values, report function existence, output file generation |
| `Private.Extraction.Tests.ps1` | Extraction functions (Graph, Entra, API) |
| `Private.Main.Tests.ps1` | Core functions (login, token, orchestration) |
| `Private.Processing.Tests.ps1` | Processing/cache functions |
| `Private.Reporting.Tests.ps1` | All reporting functions exist and are loadable |
| `Start-AZSCEntraExtraction.Tests.ps1` | Entra ID extraction with mocked Graph calls |
| `Invoke-AZSCGraphRequest.Tests.ps1` | Graph API wrapper, pagination, retry |
| `PermissionAudit.Tests.ps1` | Permission audit function parameters and logic |
| `CategoryFiltering.Tests.ps1` | Category-based module filtering |
| `Connect-AZSCLoginSession.Tests.ps1` | Authentication session management |
| `{Category}.Module.Tests.ps1` | Per-category module existence and schema validation |

## Extending the Testing Platform

### Adding a New Output Format

1. **Create the export function** in `Modules/Private/Reporting/Export-AZTI{FormatName}Report.ps1`
2. **Wire it into `Invoke-AzureScout.ps1`** — add the format to `OutputFormat` ValidateSet and add a routing block
3. **Create a test harness** `tests/Test-{FormatName}FromDataDump.ps1` following the Excel/PowerBI pattern
4. **Add Pester tests** to `OutputFormat.Tests.ps1` for the new ValidateSet value and function existence
5. **Regenerate synthetic data** if the new format requires additional data (run `New-SyntheticSampleReport.ps1`)

### Adding a New Inventory Module

1. Create the module `.ps1` in the appropriate `Modules/Public/InventoryModules/{Category}/` folder
2. Run `.\tests\New-SyntheticSampleReport.ps1` to regenerate `sample-report.json` with the new module's schema
3. Run the test harnesses to ensure the new module's data flows through all output formats:
   ```powershell
   .\tests\Test-ExcelFromDataDump.ps1
   .\tests\Test-PowerBIFromDataDump.ps1
   ```
4. Add module-specific Pester tests in the appropriate `{Category}.Module.Tests.ps1` file

### Test Data Pools

The synthetic data generator uses these Contoso-themed pools for realism:

| Pool | Values |
|------|--------|
| Subscriptions | `scout-prod-001`, `scout-dev-001`, `scout-staging-001` |
| Locations | `eastus`, `westus2`, `westeurope`, `northeurope`, `centralus` |
| Resource Groups | `rg-scout-prod-eus`, `rg-scout-dev-wus2`, `rg-scout-shared-weu`, etc. |
| SKUs | `Standard`, `Premium`, `Basic`, `Free`, `Standard_D2s_v3`, `Standard_B2ms` |
| Tags | `Environment=Production`, `CostCenter=CC-42`, `Owner=platform-team@intergalactic.fish` |

Field values are generated by pattern matching on the field name (e.g., any field containing "IP" gets `10.x.0.x`, any field containing "Cost" gets a dollar amount, etc.).
