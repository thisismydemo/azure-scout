---
description: What AzureScout changed, added, and removed compared to the original ARI project.
---

# Differences from Azure Resource Inventory (ARI)

::: warning
AzureScout is a fork of [Azure Resource Inventory (ARI)](https://github.com/microsoft/ARI) v3.6.11, created by [Claudio Merola](https://github.com/claudiomerola) and [Renato Gregio](https://github.com/intfrr) at Microsoft.
Everything listed on this page describes *how AzureScout diverges from ARI* — not a criticism of the original project.
We encourage you to evaluate both projects and choose the one that fits your needs.
:::

## What AzureScout Inherits from ARI

AzureScout would not exist without the foundation laid by ARI.
The following core capabilities come directly from the original project:

| Area | What We Inherited |
|------|-------------------|
| **ARM Resource Extraction** | The fundamental pattern of using Azure Resource Graph and ARM APIs to enumerate resources across subscriptions. |
| **Draw.io Diagram Engine** | All network topology diagram generation — VNets, subnets, peerings, NSGs, load balancers, and resource layout logic. |
| **Excel Report Pipeline** | The ImportExcel-based pipeline that turns resource data into formatted `.xlsx` workbooks with conditional formatting. |
| **154 ARM Resource Modules (at fork)** | AzureScout forked ARI v3.6.11 with 154 ARM inventory modules. That is a historical count, not a current one — see [current numbers](#current-numbers-not-the-ari-fork-count) below. The pattern (one module per resource type, ARM/Resource Graph enumeration) and much of the original module logic trace back to ARI even where the files have since been rewritten. |
| **Orchestration Pattern** | The extraction → processing → reporting three-phase orchestration that powers the main pipeline. |
| **Automation Account Mode** | The concept of running inside an Azure Automation Account with a Managed Identity. This path is now documented and validated — see [Azure Automation Account](../automation-guide/automation.md). |

### Current numbers, not the ARI fork count

The 154-module figure above describes the fork in v1.0.0, not today. As of v3.1.0 the ARM side
is **240 declarative collector definitions** across **18** Microsoft Azure service categories —
see [Category Reference](../reference/category-reference.md) — plus the **17** Entra ID modules cataloged
separately in [Entra ID Inventory](../reference/entra-modules.md). Collector logic also no longer executes as
the PowerShell ARI originally shipped: see [Engine rewrite](#engine-rewrite-ari-shipped-none-of-this)
below.

## Renamed Identifiers

The most visible change is the rebranding from ARI to AzureScout.
This affects every public-facing name in the module.

| What | ARI Name | AzureScout Name |
|------|----------|-----------------|
| PowerShell Module | `AzureResourceInventory` | `AzureScout` |
| Main Entry Point | `Invoke-ARI` | `Invoke-AzureScout` |
| Exported Function Prefix | `*-ARI*` | `*-AZSC*` |
| Internal Function Prefix | `*-ARI*` | `*-AZSC*` |
| Module Manifest | `AzureResourceInventory.psd1` | `AzureScout.psd1` |
| Root Module File | `AzureResourceInventory.psm1` | `AzureScout.psm1` |

All function definitions inside the `.ps1` files have been renamed to `AZSC`, but many **file names on disk** still use an intermediate `AZTI` prefix (e.g., `Start-AZTIAdvisoryJob.ps1` contains `function Start-AZSCAdvisoryJob`). Renaming the file names is tracked as tech debt.

## New Capabilities

These features do not exist in ARI v3.6.11 and were built specifically for AzureScout.

### Entra ID Inventory (17 Modules)

ARI focuses exclusively on ARM resources.
AzureScout adds 17 Microsoft Graph-based modules that inventory Entra ID (Azure AD) objects:

- Users, Groups, Service Principals, App Registrations
- Conditional Access Policies, Named Locations
- Administrative Units, Directory Roles, PIM Role Assignments
- Identity Providers, Security Defaults, Security Policies
- Managed Identities, Cross-Tenant Access
- Domains, Licensing (Subscribed SKUs), Risky Users

These are extracted via `Start-AZSCEntraExtraction` using a dedicated Graph API token.
See the [Entra ID Modules](../reference/entra-modules.md) page for the full module-to-endpoint catalog.

### Permission Audit (`-PermissionAudit`)

A pre-flight capability that checks whether the running identity has the ARM and Graph permissions needed for a complete inventory *before* starting extraction.

- `-PermissionAudit` — checks ARM permissions only (default)
- `-PermissionAudit -Scope All` — checks both ARM and Graph permissions
- Outputs results to Console, Markdown, AsciiDoc, or JSON

### Execution Scope (`-Scope`)

ARI always inventories ARM resources across every subscription the identity can see.
AzureScout adds a `-Scope` parameter that controls *what types of objects* are inventoried:

- `ArmOnly` (default) — ARM resources only, same scope as ARI
- `EntraOnly` — Entra ID (Azure AD) objects only, skips ARM
- `All` — both ARM resources and Entra ID objects

This is separate from the `-SubscriptionID` parameter (inherited from ARI) that targets a specific subscription.

### Multi-Format Output (`-OutputFormat`)

ARI outputs Excel (`.xlsx`) and Draw.io (`.drawio`) files.
AzureScout adds:

- **JSON** (`-OutputFormat JSON`) — raw cache data as `.json` for programmatic consumption
- **Markdown** (`-OutputFormat Markdown` or `-OutputFormat MD`) — GitHub-Flavored Markdown tables
- **AsciiDoc** (`-OutputFormat AsciiDoc` or `-OutputFormat Adoc`) — Antora/Confluence-compatible AsciiDoc tables
- **All** (`-OutputFormat All`) — every format at once

### Category Filtering (`-Category`)

Lets you limit extraction and reporting to specific Azure resource categories:

```powershell
Invoke-AzureScout -Category Compute, Networking
```

Supports both short folder names (`Compute`) and long Azure portal names (`AI + machine learning`).
Modules declare their category via a `.CATEGORY` comment header, enabling cross-category placement.

### Specialized Excel Tabs

AzureScout adds purpose-built Excel worksheets that aggregate data across resource types:

- **Cost Management** — VM cost estimates, Arc ESU costs, reservation recommendations
- **Security Overview** — Defender secure score, high/critical assessments, active alerts, plan pricing
- **Azure Update Manager** — Patch compliance across VMs and Arc servers
- **Azure Monitor** — Action groups, DCRs, DCEs, App Insights, alert rules, autoscale settings

### Resource Enrichment

Virtual Machine and Arc Server modules now pull supplementary data from multiple APIs:

- **Azure Monitor Metrics** — 7-day average CPU and memory usage
- **Azure Site Recovery** — DR replication status, target region, replication health
- **Cost Management** — Estimated monthly cost (USD)
- **PolicyInsights** — Policy assignment count and compliance state (Arc)

### Dependency Bootstrap

ARI requires modules to be pre-installed (declared in `RequiredModules`).
AzureScout auto-installs missing dependencies on first import:

- `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`, `Az.Compute`, `Az.Authorization`, `Az.Resources`

## Structural Changes

### Documentation

| ARI | AzureScout |
|-----|------------|
| README-only docs | MkDocs Material documentation site (`docs/` folder) with navigation, search, and cross-references |
| No API/architecture docs | Dedicated pages for category filtering, coverage tables, category-to-folder mapping |
| Inline examples only | 4 structured `.EXAMPLE` blocks on `Invoke-AzureScout` |

### Testing

| ARI | AzureScout |
|-----|------------|
| No test suite | 25+ Pester test files covering public functions, private functions, inventory modules, output formats, and category filtering |
| No synthetic data | `New-SyntheticSampleReport.ps1` generates test data for offline validation |

### Folder Reorganization

ARI's `Modules/Private/` uses numbered folders (`1.ExtractionFunctions/`, `2.ProcessingFunctions/`,
etc.). AzureScout's early releases replaced these with descriptively-named folders under the same
`Modules/Private/` tree — but that intermediate layout is **also gone**. There is no `Modules/`
directory in the repository any more.

| ARI Path (original) | Where that logic lives today |
|----------|-----------------|
| `Modules/Private/1.ExtractionFunctions/` | `src/collect/` (declarative collection, single Resource Graph pass) |
| `Modules/Private/2.ProcessingFunctions/` | The manifest interpreter in `src/pipeline/` reading `manifests/collectors/**/*.psd1` |
| `Modules/Private/3.ReportingFunctions/` | `src/report/renderers/inventory/` (+ `.../style/`) |
| `Modules/Private/3.ReportingFunctions/StyleFunctions/` | `src/report/renderers/inventory/style/` |
| `Modules/Private/4.RAMPFunctions/` | *(removed — see [Removed from ARI](#removed-from-ari))* |

AB#5662 moved reporting out from under `Modules/` to `src/report/renderers/inventory/` and renamed
every file to match the function it defines — ARI's `AZTI`-file / `AZSC`-function mismatch is
gone there. AB#5665 deleted `Build-AZTIExcelComObject.ps1` outright: chart and shape styling runs
on EPPlus/ImportExcel through `Build-AZSCExcelChartStyle`, so no local Excel install is required
(ARI's COM path fails with `0x80040154 REGDB_E_CLASSNOTREG` on any machine or CI runner without
Excel).

### Engine rewrite — ARI shipped none of this

Everything above describes the fork boundary and the folders AzureScout used immediately after
it. It does not describe how collection runs today. Epic AB#5638 (v2.6.0 → v3.0.0, all shipped
2026-07-25/26/28) rewrote the collection and reporting engine end to end:

- Collectors are **declarative `.psd1` definitions** under `manifests/collectors/`, read by an
  interpreter in `src/pipeline/`, not the imperative `.ps1` files ARI shipped or that AzureScout's
  own early releases carried forward. The retired collector-script tree is gone; there is no
  per-collector PowerShell fallback.
- Collection runs **in-process, in a fixed order**, with no `Start-Job`/runspace-per-collector
  coordination — ARI's (and AzureScout's own, through v2.5.x) job-based extraction is gone.
- A single Resource Graph pass feeds both the inventory report and, when `-InventoryAndAssessment`
  is used, the CAF/WAF assessment — see [Overview: running both](../guide/overview.md#running-both).

`src/` still contains files with an `AZTI`-prefixed name and an `AZSC`-prefixed function (an
artifact of the ARI→AzureScout rename tracked as tech debt, above) — but the *logic* inside those
files, and the pipeline that calls them, is a rewrite, not an inherited ARI implementation. See
`docs/changelog.md` v2.6.0 through v3.0.0 for the six-release account of that rewrite.

## Removed from ARI

The following ARI features were intentionally removed:

| Feature | Reason |
|---------|--------|
| **RAMP Functions** | `Invoke-AzureRAMPInventory` and the `4.RAMPFunctions/` folder were removed. RAMP (Risk Assessment & Mitigation Program) is an internal Microsoft program not broadly applicable. |
| **Auto-Update Logic** | ARI calls `Update-Module` to self-update. AzureScout removes this — module updates should be a conscious decision by the operator, not automatic. |
| **Remove-ARIExcelProcess** | ARI included a function that kills Excel processes to prevent file-lock issues. AzureScout removes this aggressive behavior. |
| **RequiredModules hard dependency** | Replaced with runtime bootstrap (see [Dependency Bootstrap](#dependency-bootstrap)). |

## Not Yet in AzureScout

This table used to list GitHub Actions CI, PSGallery publishing, and Automation Account docs as
gaps. All three now exist — `.github/workflows/ci.yml`, `azure-inventory.yml` and
`documentation.yml`; the module is published to the PowerShell Gallery (`Install-Module
AzureScout`); and [Azure Automation Account](../automation-guide/automation.md) documents the setup (Issue #32,
closed). Only one ARI/ecosystem gap remains open:

| Feature | Status |
|---------|--------|
| **Containerized Execution** | ARI documents Docker-based execution. AzureScout has no Dockerfile and has not validated container support. |

## Version Lineage

```text
ARI v3.6.11 (microsoft/ARI)
  └── Fork ──→ AzureScout v1.0.0 (thisismydemo/azure-scout)
                  ├── Rebranding (ARI → AZSC function prefix)
                  ├── +17 Entra ID modules
                  ├── new ARM modules (Phases 7–17)
                  ├── Permission Audit system
                  ├── Multi-format output (JSON, Markdown, AsciiDoc)
                  ├── Category filtering
                  ├── Specialized Excel tabs
                  ├── Resource enrichment (metrics, DR, cost)
                  ├── MkDocs Material documentation
                  └── Pester test suite
```

## Further Reading

- [Credits & Attribution](./credits.md) — full list of original authors and contributors
- [AzureScout Documentation Home](../index.md)
- [ARI on GitHub](https://github.com/microsoft/ARI) — the original project
- [AzureScout on GitHub](https://github.com/thisismydemo/azure-scout) — this fork
