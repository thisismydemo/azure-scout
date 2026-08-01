---
description: Folder layout and module organization for the AzureScout repository.
---

# Repository Structure

## Overview

This page documents the current repository layout. Documentation is a
**VitePress** site (`docs/`, configured by `docs/.vitepress/config.ts`) — there is
no `mkdocs.yml`; the project moved off MkDocs Material.

## Directory Tree

```text
azure-scout/
├── .github/                            # GitHub config (issue templates, workflows, policies)
│   ├── ISSUE_TEMPLATE/
│   ├── policies/
│   ├── PULL_REQUEST_TEMPLATE/
│   └── workflows/
├── docs/                               # VitePress documentation site
│   ├── .vitepress/
│   │   └── config.ts                   #   Nav, sidebar, site config
│   ├── design/                         #   Architecture decisions, master plan, assessment registry
│   │   ├── decisions/                  #     Individual ADRs (e.g. PPTX renderer choice)
│   │   ├── assessment-registry.md      #     The assessment registry: Collect/Ingest/Rules/report tiers
│   │   ├── master-plan.md              #     Consolidated architecture + work-item index
│   │   ├── enhancement-spec.md         #     Original v2 assessment-platform spec
│   │   └── task-list.md                #     Delivery task tracking
│   ├── images/                         #   Banner, icons
│   ├── index.md                        #   Home page
│   ├── overview.md                     #   Inventory vs Assessment decision guide (first Getting Started page)
│   ├── prerequisites.md                #   Inventory-mode prerequisites & modules
│   ├── authentication.md               #   Authentication methods
│   ├── usage.md                        #   Usage guide (Scope, OutputFormat, examples)
│   ├── permissions.md                  #   Inventory-mode required permissions
│   ├── category-filtering.md           #   -Category parameter guide
│   ├── parameters.md                   #   Full parameter reference (both cmdlets)
│   ├── output.md                       #   Output files & formats
│   ├── troubleshooting.md              #   Troubleshooting
│   ├── assessment.md                   #   CAF/WAF assessment platform guide
│   ├── assessment-prerequisites.md     #   Assessment-specific prerequisites (PS7, .NET SDK)
│   ├── assessment-permissions.md       #   Assessment RBAC/Graph permission matrix
│   ├── arm-modules.md                  #   Generated collector catalog (236 / 18 categories)
│   ├── entra-modules.md                #   Entra ID module catalog (17 modules)
│   ├── coverage-table.md               #   Full per-category coverage table
│   ├── category-structure.md           #   Category-to-folder mapping
│   ├── roadmap.md                      #   Roadmap & planned features
│   ├── folder-structure.md             #   This page
│   ├── testing.md                      #   Pester test suite guide
│   ├── contributing.md                 #   Contributing guide
│   ├── credits.md                      #   Credits & attribution
│   ├── ari-differences.md              #   Differences from ARI
│   └── changelog.md                    #   Changelog
├── archived/
│   └── Modules/
│   ├── Private/                        # Internal (non-exported) functions — 31 scripts
│   │   ├── Main/                       #   19 — Core orchestration, auth, permission audit, run log
│   │   ├── Extraction/                 #   10 — ARM/Entra data extraction
│   │   │   └── ResourceDetails/        #     2 — VM quota / SKU detail lookups
│   │   └── Processing/                 #   2 — draw.io job wrapper, extra processing
│   │                                   #   Reporting/ is GONE — the inventory report renderers
│   │                                   #   moved to src/report/renderers/inventory/ (AB#5662)
│   └── Public/                         # Exported functions & runtime modules
│       ├── InventoryModules/           #   176 modules across 15 categories (159 ARM + 17 Entra)
│       │   ├── AI/                     #   27 modules
│       │   ├── Analytics/              #   6 modules
│       │   ├── Compute/                #   14 modules
│       │   ├── Containers/             #   6 modules
│       │   ├── Databases/              #   13 modules
│       │   ├── Hybrid/                 #   16 modules
│       │   ├── Identity/               #   18 modules — 17 Entra (Graph) + 1 ARM (ManagedIds)
│       │   ├── Integration/            #   2 modules
│       │   ├── IoT/                    #   1 module
│       │   ├── Management/             #   14 modules
│       │   ├── Monitor/                #   24 modules
│       │   ├── Networking/             #   21 modules
│       │   ├── Security/               #   5 modules
│       │   ├── Storage/                #   2 modules
│       │   └── Web/                    #   2 modules
│       └── PublicFunctions/            #   14 exported cmdlets
│           ├── Diagram/                #     draw.io diagram generation
│           └── Jobs/                   #     Background job orchestration (advisory, policy, sec center)
├── src/                                # CAF/WAF assessment platform (v2.0.0, Epic AB#5023/AB#5056)
│   ├── collect/                        #   Read-only Azure Resource Graph collection -> collect.json
│   ├── pipeline/                       #   Deterministic inventory processing — no background jobs (AB#5649)
│   │   ├── Get-ScoutCollector.ps1      #     Discover collectors in a fixed, testable order
│   │   ├── Invoke-ScoutCollector.ps1   #     Run ONE collector in-process, failure contained
│   │   ├── Invoke-ScoutProcessing.ps1  #     Run them all, write the report cache
│   │   └── Write-ScoutCacheFile.ps1    #     Cache writing, decoupled from job harvesting
│   ├── ingest/                         #   Import-Governance (native, default) / opt-in AzGovViz / ARG query pack / Advisor ingest into collect.json
│   ├── assess/                         #   Rule engine (JSONPath + assert types) -> findings.json
│   │   ├── benchmarks/                 #     ALZ reference benchmark data
│   │   ├── engine/                     #     Resolve-JsonPath, Invoke-Rule, Get-Score
│   │   ├── rules/                      #     23 version-controlled YAML rule files (139 rules)
│   │   ├── Import-ScoutConfig.ps1      #     Load an optional benchmark/rule-pattern/override config JSON (v2.2.0, AB#374)
│   │   └── Export-ScoutConfig.ps1      #     Save the effective config back out as JSON (v2.2.0, AB#373)
│   ├── analyze/                        #   Offline analysis -- never call Azure (v2.2.0)
│   │   ├── Get-ScoutCostAnomaly.ps1    #     Cost outlier detection: spike/z-score/IQR (AB#324)
│   │   └── Get-ScoutIacGap.ps1         #     Bicep/ARM-JSON coverage gap detection (AB#325)
│   ├── report/                         #   Tiered report rendering (Power BI, HTML, PPTX, Excel, JSON, JsonEvidence, React, Word, EChartsDashboard, Pdf)
│   │   ├── renderers/                  #     9 — incl. Export-React.ps1 (v2.1.0), Export-Word.ps1/Export-EChartsDashboard.ps1/Export-Pdf.ps1/Export-JsonEvidence.ps1 (v2.2.0)
│   │   │   └── inventory/              #       17 — inventory Excel/JSON/Markdown/AsciiDoc/Power BI
│   │   │       │                       #       renderers, moved out of Modules/Private/Reporting/ and
│   │   │       │                       #       renamed so each file matches its function (AB#5662)
│   │   │       └── style/              #         6 — Overview sheet, pivots/charts, tab ordering and
│   │   │                               #         EPPlus-native chart styling (Build-AZSCExcelChartStyle).
│   │   │                               #         Excel COM is deleted (AB#5665). Also holds the
│   │   │                               #         Support.json and Retirement.kql data assets.
│   │   ├── Get-ScoutDrift.ps1          #     Cross-run FINDINGS drift (v2.1.0, AB#5053)
│   │   ├── Get-ScoutInventoryDrift.ps1 #     Cross-run RESOURCE/inventory drift (v2.2.0, AB#326)
│   │   └── templates/
│   ├── Invoke-ScoutAssessmentCore.ps1  #   Internal assessment implementation
│   ├── Invoke-ScoutPipeline.ps1        #   Unattended collect->assess->report pipeline (v2.1.0, AB#5050)
│   └── Write-ScoutProgress.ps1         #   Live collection progress output (v2.2.0, AB#405)
├── manifests/
│   └── assessments.psd1                # The assessment registry (Collect/Ingest/Rules/report tiers)
├── tests/                              # Pester test suites (80 files, offline/mock-driven — 2,243
│   │                                   #   tests: 2,236 passing, 3 skipped, 4 known cross-file
│   │                                   #   flakes that fail only in a full-suite run and pass in
│   │                                   #   isolation. Verified 2026-07-31)
│   ├── datadump/                       #   Synthetic fixture data for offline report rendering tests
│   ├── ResourceTypeExistence.Tests.ps1 #   Every declared resource type checked against real Azure
│   │                                   #   provider/type pairs (AB#6842) — see docs/testing.md
│   ├── Assessment.Engine.Tests.ps1     #   Assessment engine (Resolve-JsonPath, Invoke-Rule, Get-Score)
│   ├── Test-ExcelFromDataDump.ps1      #   Renders Excel evidence tier from datadump fixtures
│   ├── Test-PowerBIFromDataDump.ps1    #   Renders Power BI CSV bundle from datadump fixtures
│   └── Test-PptxFromDataDump.ps1       #   Renders PowerPoint deck from datadump fixtures
├── config/                             # Runtime configuration
├── package.json                        # VitePress dev dependency + docs:dev/build/preview scripts
├── AzureScout.psd1                     # Module manifest (PowerShellVersion 7.0, CompatiblePSEditions Core)
├── AzureScout.psm1                     # Module loader (dot-sources src/ only)
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── CREDITS.md
├── LICENSE
├── README.md
├── RELEASES.md
├── SECURITY.md
└── SUPPORT.md
```

## Module Loading

`AzureScout.psm1` dot-sources, in order:

1. Every implementation `*.ps1` under `src/` (recursive).
2. Every `*.ps1` under `src/` (recursive, sorted by path) — the assessment platform,
   loaded **after** the inventory modules so assessment code can call into collection
   when needed.

Folder names inside `InventoryModules/` and `PublicFunctions/` are cosmetic —
renaming or merging directories has *zero* impact on which functions are loaded,
since the loader recurses the whole tree. 14 public functions are exported via the
`AzureScout.psd1` manifest's `FunctionsToExport`.

## Module Counts — Source of Truth

Counts above are generated by counting `*.ps1` files under
`manifests/collectors/**` and cross-checking against the `-Category`
`[ValidateSet]` in `Invoke-AzureScout.ps1`. See [ARM Modules](../reference/arm-modules.md) and
[Entra ID Modules](../reference/entra-modules.md) for the full per-module catalog, and
[Coverage Table](../reference/coverage-table.md) for the per-category summary.

