---
description: Folder layout and module organization for the AzureScout repository.
---

# Repository Structure

## Overview

This page documents the repository layout after the Phase 1B reorganization.
Numbered-prefix folders were renamed, duplicate directories merged, legacy code removed, and the docs tree uses MkDocs Material with Markdown.

## Directory Tree

```text
azure-scout/
├── .github/                            # GitHub config (issue templates, workflows, policies)
│   ├── ISSUE_TEMPLATE/
│   ├── policies/
│   ├── PULL_REQUEST_TEMPLATE/
│   └── workflows/
├── docs/                               # MkDocs documentation
│   ├── images/                         #   All consolidated images
│   ├── index.md                        #   Home page
│   ├── authentication.md              #   Authentication methods
│   ├── usage.md                        #   Usage guide
│   ├── permissions.md                  #   Required permissions
│   ├── parameters.md                   #   Parameters reference
│   ├── category-filtering.md           #   Category filtering
│   ├── output.md                       #   Output files
│   ├── prerequisites.md               #   Prerequisites & modules
│   ├── testing.md                      #   Testing guide
│   ├── troubleshooting.md             #   Troubleshooting
│   ├── arm-modules.md                  #   ARM module catalog
│   ├── entra-modules.md               #   Entra module catalog
│   ├── coverage-table.md              #   Full coverage table
│   ├── category-structure.md           #   Category-to-folder mapping
│   ├── roadmap.md                      #   Roadmap & planned features
│   ├── folder-structure.md             #   This page
│   ├── contributing.md                 #   Contributing guide
│   ├── credits.md                      #   Credits & attribution
│   ├── ari-differences.md             #   Differences from ARI
│   └── changelog.md                    #   Changelog
├── Modules/
│   ├── Private/                        # Internal (non-exported) functions
│   │   ├── Main/                       #   Core orchestration (was 0.MainFunctions)
│   │   ├── Extraction/                 #   Data extraction  (was 1.ExtractionFunctions)
│   │   │   └── ResourceDetails/
│   │   ├── Processing/                 #   Data processing  (was 2.ProcessingFunctions)
│   │   └── Reporting/                  #   Report generation (was 3.ReportingFunctions)
│   │       └── StyleFunctions/
│   └── Public/                         # Exported functions & runtime modules
│       ├── InventoryModules/           #   110 modules in 17 categories (95 ARM + 15 Entra)
│       │   ├── AI/                     #   14 modules
│       │   ├── Analytics/              #   6 modules
│       │   ├── APIs/                   #   5 modules
│       │   ├── AzureLocal/             #   6 modules
│       │   ├── Compute/                #   7 modules
│       │   ├── Container/              #   6 modules
│       │   ├── Database/               #   13 modules
│       │   ├── Hybrid/                 #   5 modules
│       │   ├── Identity/               #   15 Entra ID modules
│       │   ├── Integration/            #   2 modules
│       │   ├── IoT/                    #   1 module
│       │   ├── Management/             #   3 modules
│       │   ├── Monitoring/             #   2 modules
│       │   ├── Network/               #   20 modules (merged Network_1 + Network_2)
│       │   ├── Security/               #   1 module
│       │   ├── Storage/                #   2 modules
│       │   └── Web/                    #   2 modules
│       └── PublicFunctions/            #   13 exported cmdlets
│           ├── Diagram/
│           └── Jobs/
├── tests/                              # Pester test suites
├── mkdocs.yml                          # MkDocs Material configuration
├── AzureScout.psd1                     # Module manifest
├── AzureScout.psm1                     # Module loader (recursive *.ps1 import)
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── CREDITS.md
├── LICENSE
├── README.md
├── SECURITY.md
└── SUPPORT.md
```

## Phase 1B Changes Summary

| Action | Detail |
|--------|--------|
| Renamed | `0.MainFunctions` → `Main`, `1.ExtractionFunctions` → `Extraction`, `2.ProcessingFunctions` → `Processing`, `3.ReportingFunctions` → `Reporting` |
| Merged | `Network_1/` + `Network_2/` → `Network/` (20 files) |
| Deleted | `4.RAMPFunctions/` (untracked .xlsx), `LegacyFunctions/` (6 .ps2 files), `azure-pipelines/` |
| Cleaned | Root clutter: `HowTo.md`, 5 `test-*.sh` scripts, `workflow_dispatch.json` |
| Converted | Documentation to MkDocs Material with Markdown; images consolidated into `docs/images/` |
| Kept | `Hybrid/` directory — validated as active module category |

## Module Loading

The PSM1 loader uses `Get-ChildItem -Recurse *.ps1`.
Folder names are cosmetic — renaming or merging directories has *zero* impact on which functions are loaded.
13 public functions are exported via the PSD1 manifest.
