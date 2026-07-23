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
│   │   ├── assessment-registry.md      #     All 22 assessments: Collect/Ingest/Rules/report tiers
│   │   ├── master-plan.md              #     Consolidated architecture + work-item index
│   │   ├── enhancement-spec.md         #     Original v2 assessment-platform spec
│   │   └── task-list.md                #     Delivery task tracking
│   ├── images/                         #   Banner, icons
│   ├── index.md                        #   Home page
│   ├── overview.md                     #   Inventory vs Assessment decision guide (first Getting Started page)
│   ├── prerequisites.md                #   v1 inventory prerequisites & modules
│   ├── authentication.md               #   Authentication methods
│   ├── usage.md                        #   Usage guide (Scope, OutputFormat, examples)
│   ├── permissions.md                  #   v1 inventory required permissions
│   ├── category-filtering.md           #   -Category parameter guide
│   ├── parameters.md                   #   Full parameter reference (both cmdlets)
│   ├── output.md                       #   Output files & formats
│   ├── troubleshooting.md              #   Troubleshooting
│   ├── assessment.md                   #   CAF/WAF assessment platform guide
│   ├── assessment-prerequisites.md     #   Assessment-specific prerequisites (PS7, .NET SDK)
│   ├── assessment-permissions.md       #   Assessment RBAC/Graph permission matrix
│   ├── arm-modules.md                  #   ARM module catalog (154 modules / 15 categories)
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
├── Modules/
│   ├── Private/                        # Internal (non-exported) functions — 55 scripts
│   │   ├── Main/                       #   13 — Core orchestration, auth, permission audit
│   │   ├── Extraction/                 #   9 — ARM/Entra data extraction
│   │   │   └── ResourceDetails/
│   │   ├── Processing/                 #   9 — Cache, advisory, policy jobs
│   │   └── Reporting/                  #   24 — Excel, JSON, Markdown, AsciiDoc, Power BI export
│   │       └── StyleFunctions/
│   └── Public/                         # Exported functions & runtime modules
│       ├── InventoryModules/           #   171 modules across 15 categories (154 ARM + 17 Entra)
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
│   ├── ingest/                         #   AzGovViz / ARG query pack / Advisor ingest into collect.json
│   ├── assess/                         #   Rule engine (JSONPath + assert types) -> findings.json
│   │   ├── benchmarks/                 #     ALZ reference benchmark data
│   │   ├── engine/                     #     Resolve-JsonPath, Invoke-Rule, Get-Score
│   │   └── rules/                      #     23 version-controlled YAML rule files (139 rules)
│   ├── report/                         #   Tiered report rendering (Power BI, HTML, PPTX, Excel, JSON)
│   │   ├── renderers/
│   │   └── templates/
│   └── Invoke-ScoutAssessment.ps1      #   Assessment platform entry point
├── manifests/
│   └── assessments.psd1                # Registry of all 22 assessments (Collect/Ingest/Rules/report tiers)
├── tests/                              # Pester test suites (34 files, offline/mock-driven)
│   ├── datadump/                       #   Synthetic fixture data for offline report rendering tests
│   ├── Assessment.Engine.Tests.ps1     #   Assessment engine (Resolve-JsonPath, Invoke-Rule, Get-Score)
│   ├── Test-ExcelFromDataDump.ps1      #   Renders Excel evidence tier from datadump fixtures
│   ├── Test-PowerBIFromDataDump.ps1    #   Renders Power BI CSV bundle from datadump fixtures
│   └── Test-PptxFromDataDump.ps1       #   Renders PowerPoint deck from datadump fixtures
├── config/                             # Runtime configuration
├── package.json                        # VitePress dev dependency + docs:dev/build/preview scripts
├── AzureScout.psd1                     # Module manifest (PowerShellVersion 5.1, CompatiblePSEditions Desktop+Core)
├── AzureScout.psm1                     # Module loader (dot-sources Modules/Private, Modules/Public/PublicFunctions, then src/)
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

1. Every `*.ps1` under `Modules/Private/` and `Modules/Public/PublicFunctions/` (recursive).
2. Every `*.ps1` under `src/` (recursive, sorted by path) — the assessment platform,
   loaded **after** the inventory modules so assessment code can call into collection
   when needed.

Folder names inside `InventoryModules/` and `PublicFunctions/` are cosmetic —
renaming or merging directories has *zero* impact on which functions are loaded,
since the loader recurses the whole tree. 14 public functions are exported via the
`AzureScout.psd1` manifest's `FunctionsToExport`.

## Module Counts — Source of Truth

Counts above are generated by counting `*.ps1` files under
`Modules/Public/InventoryModules/**` and cross-checking against the `-Category`
`[ValidateSet]` in `Invoke-AzureScout.ps1`. See [ARM Modules](arm-modules.md) and
[Entra ID Modules](entra-modules.md) for the full per-module catalog, and
[Coverage Table](coverage-table.md) for the per-category summary.
