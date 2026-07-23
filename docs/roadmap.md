---
description: Planned features, future enhancements, and the long-term vision for AzureScout.
---

# Roadmap

*See everything. Own your cloud.*

This page outlines what's planned, what's in progress, and what's been delivered.
Community contributions are welcome — see [Contributing](contributing.md) to get involved.

> The consolidated architecture, work-item index, audit findings, and delivery
> plan live in the [Master Design & Plan](design/master-plan.md). This roadmap is
> the public-facing summary of it.

## Current Release — v2.0.0 — CAF/WAF Assessment Platform

Released 23 July 2026. Turns AzureScout from an inventory tool into a read-only
CAF/WAF landing-zone assessment. Runtime-verified offline (Pester) and against a
live Azure tenant.

| Capability | What shipped |
|---|---|
| Assessment engine | Declarative YAML rules (JSONPath + assert types), dual CAF/WAF scoring, prioritized gap list — **139 rules across 8 CAF design areas + 5 WAF pillars** |
| Collect + ingest | Read-only ARG collect layer (`collect.json`); native governance collector (v2.1.0) / ARG query pack / Advisor ingest — AzGovViz retained as opt-in only |
| ALZ benchmark | Live tenant diffed against a canonical ALZ reference |
| Tiered reporting | Power BI, self-contained HTML, executive **PowerPoint (OpenXML SDK — no Python)**, Excel + JSON evidence |
| Per-domain analytics | Every discovery category runnable + tagged: `Invoke-ScoutAssessment -Assessment <Category>` |
| Entry point | `Invoke-ScoutAssessment` (run one/some/all), read-only permission pre-flight |

> **Breaking:** introduces the `findings.json` contract and demotes Excel-first
> output to an evidence tier. Assessment features require PowerShell 7.

Deferred to v2.1.0: full per-category rule depth (AB#5061–5075). The native
governance collector (AB#5041), the fully unattended pipeline (AB#5050), and
the React report variant + cross-run drift tracking (AB#5053) have since
shipped on `main` — see **v2.1.0 (in development)** below.

## Previous Release — v1.0.0

Released February 2026.

| Area | What's included |
|------|-----------------|
| Excel Reports | 171 worksheets (154 ARM + 17 Entra ID) covering all 15 Azure resource categories |
| Category Filtering | `-Category` parameter to scope runs to specific resource types |
| AI / ML Coverage | 27 modules: OpenAI, AI Foundry, Azure ML, Cognitive Services, Bot Services, Search |
| AVD Coverage | 6 modules: Host Pools, App Groups, Workspaces, Session Hosts, Scaling Plans, Applications |
| Arc Coverage | Sites, SQL Servers, Data Controllers, SQL Managed Instances, Arc-enabled Kubernetes enhancements |
| VM & Arc Enrichment | Backup status, Site Recovery, Update Manager, Advisor score, Monitor metrics, Cost estimates |
| Monitor Coverage | 24 modules: Diagnostic settings, alert rules, DCRs, App Insights deep data, autoscale, workbooks |
| Markdown / AsciiDoc Export | `-OutputFormat Markdown\|AsciiDoc` generates portable reports alongside Excel/JSON |
| Permission Audit | `Invoke-AZSCPermissionAudit` with ARM + Graph checks, color output, Markdown/AsciiDoc export |
| Subscription & MG Completeness | Captures ALL subscriptions (including empty/disabled) and full MG hierarchy |
| Module Naming | Renamed from *AzureTenantInventory* to *AzureScout* (prefix: `AZSC`) |

## Near-term — v1.1.0

Focus: quality, reliability, and community onboarding.

| Feature | Description | Status |
|---------|-------------|--------|
| Pester test suite | Full unit + integration tests for all public functions and key private functions | :blue_circle: Planned |
| PSGallery publish | Publish `AzureScout` module to PowerShell Gallery | :blue_circle: Planned |
| GitHub Actions CI | Run Pester tests on PR + push; block merge on failure | :blue_circle: Planned |
| Category alias documentation | Comprehensive table of all accepted `-Category` aliases and their canonical names | :blue_circle: Planned |
| Resource provider pre-flight | Warn before scan when required providers are not registered in a subscription | :blue_circle: Planned |
| Throttling / retry improvements | Exponential backoff on ARM 429 responses; configurable `-ThrottleDelay` | :blue_circle: Planned |
| `Invoke-AzureScout -WhatIf` | Show which modules would run without actually executing | :blue_circle: Planned |
| Non-destructive cache | Prevent `ReportCache` and `DiagramCache` from being overwritten on subsequent runs. Each invocation writes to a timestamped (or `-RunName` named) subfolder. Previous scan data is never lost unless `-Force` is specified. `Clear-AZSCCacheFolder -OlderThan <days>` for cleanup. | :blue_circle: Planned |

### Visual Dashboard Tabs (DarkBlue "overview-style" worksheets)

Phase 10 added raw data tabs (Cost Management, Security Overview, Azure Update Manager, Azure Monitor) that collect data into flat tables. The next step is to add **visual dashboard tabs** — styled like the Overview sheet (DarkBlue tab color, EPPlus shapes, pivot charts) — that summarize and visualize the data from those raw tabs.

| Dashboard | Charts / Visualizations | Status |
|-----------|-------------------------|--------|
| Cost Dashboard | Cost by Resource Type (bar), Cost by Subscription (pie), Cost by Region (column), Cost by SKU (bar) | :blue_circle: Planned |
| Security Dashboard | Assessments by Severity (pie), Findings by Subscription (bar), Defender Plans (column), Active Alerts by Severity (bar) | :blue_circle: Planned |
| Update Manager Dashboard | Machines by Platform (pie), Machines by OS Type (pie), Machines by Region (column), Machines by Power State (bar), Machines by Subscription (bar) | :blue_circle: Planned |
| Monitor Dashboard | Alert Rules by Subscription (bar), Action Groups by Subscription (pie), DCRs by Subscription (column), App Insights by Subscription (bar) | :blue_circle: Planned |

Each dashboard tab will:

- Use DarkBlue tab color (matching Overview, Subscriptions, Advisor)
- Be pinned after the Overview sheet group via `MoveAfter` in the ordering function
- Contain EPPlus pivot tables + charts generated by `Build-AZSCDashboardTabs`
- Only appear when the corresponding raw data tab has data (no empty dashboards)

## Medium-term — v1.2.0

Focus: depth, breadth, and multi-tenant scenarios.

| Feature | Description | Status |
|---------|-------------|--------|
| Multi-tenant scanning | `-TenantID` accepts multiple tenant IDs. Authenticates to each tenant sequentially, runs the full extraction → processing → reporting pipeline per tenant. Supports combined workbook (with Tenant column) or separate per-tenant workbooks via `-MergeOutput` switch. Auth failure on one tenant does not block others. Builds on non-destructive cache (v1.1.0) for run isolation. | :blue_circle: Planned |
| Word document export (#22) | `-OutputFormat Word` generates a `.docx` report with cover page, table of contents, per-category sections with summary tables, resource counts, and key metrics. Suitable for client deliverables, executive summaries, and formal documentation. | :blue_circle: Planned |
| PDF report export (#23) | `-OutputFormat PDF` generates a `.pdf` report with cover page, table of contents, paginated resource tables, and headers/footers. Ideal for archival, compliance evidence, and stakeholder distribution. | :blue_circle: Planned |
| Cost anomaly detection | Surface Azure Cost Management anomalies in the Cost Management tab | :bulb: Idea |
| Bicep / IaC gap detection | Compare discovered resources against known IaC templates; flag unmanaged resources | :bulb: Idea |
| Resource drift reporting | Compare two inventory runs and report what was added, removed, or changed | :bulb: Idea |
| Azure DevOps integration | Inventory Azure DevOps organizations, projects, pipelines alongside Azure resources | :bulb: Idea |
| GitHub Actions module | Publish as a GitHub Action so pipelines can generate inventory reports without local setup | :bulb: Idea |
| Fabric / Power BI export (#17) | `-OutputFormat PowerBI` generates a flat normalized CSV bundle (`PowerBI/` folder) with `_metadata.csv`, `Subscriptions.csv`, per-module `Resources_*.csv` and `Entra_*.csv` files, and a `_relationships.json` star-schema manifest for Power BI Desktop / Microsoft Fabric | :white_check_mark: Done |
| IoT deep coverage | IoT Hub device registry, Device Provisioning Service, Digital Twins topology | :bulb: Idea |

## Major — v2.0.0 — CAF/WAF Assessment Platform (Epic AB#5023) — Delivered

Turned inventory into a **scored CAF/WAF landing-zone assessment**. Collection stays as-is; a three-layer, JSON-on-disk architecture (`collect.json` → `findings.json` → deliverables) adds assessment and rebuilds reporting. Read-only throughout. **Shipped in v2.0.0 (2026-07-23).**

| Capability | Description | Status |
|---|---|---|
| Assessment engine | Declarative YAML rules (JSONPath + assert types), dual CAF/WAF scoring, prioritized gap list | :white_check_mark: Done (AB#5027, AB#5034) |
| CAF/WAF rule content | 8 CAF design areas + 5 WAF pillars — 139 rules across 23 version-controlled files | :white_check_mark: Done (AB#5031, AB#5057) |
| Ingest layer | Fold an ARG query pack and Advisor into one `collect.json`; governance now ingested natively by default (see v2.1.0 below) — Azure Governance Visualizer remains available as an opt-in ingestor | :white_check_mark: Done (AB#5037) |
| ALZ benchmark diff | Compare the live tenant against a canonical ALZ reference (MG archetypes, required policies) | :white_check_mark: Done — engine + native governance collection, no upstream AzGovViz dependency (AB#5041, v2.1.0) |
| Tiered reporting | Power BI (primary), self-contained HTML, executive PPTX (OpenXML SDK); Excel/JSON retained as evidence | :white_check_mark: Done (AB#5044) |
| Module registry + entry point | `-Assessment` run one/some/all; read-only permission pre-flight | :white_check_mark: Done (AB#5024); unattended one-command pipeline :white_check_mark: Done (AB#5050, v2.1.0) |
| React report + drift tracking | Richer React report variant and cross-run score-drift tracking | :white_check_mark: Done (AB#5053, v2.1.0) |

## Major — v2.1.0 — Platform Hardening (Epic AB#5023 carryover) — Released 2026-07-23

Three more Epic AB#5023 capabilities have shipped on `main` ahead of the full
per-domain analytics epic below. Not yet tagged/released — see
[`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md)
for status.

| Capability | Description | Status |
|---|---|---|
| Native governance collector | `Import-Governance` replaces the AzGovViz hard dependency as the **default** governance collector — populates `collect.json`'s `governance` object natively from Azure Resource Graph and ambient-token ARM REST, needing only Reader at the management-group root. No cloned repo, no `AzAPICall` install prompt, fully unattended, StrictMode-safe. Live-verified against the HCS tenant. `AzGovViz` remains available as an opt-in `Ingest` value; nothing depends on it by default anymore. | :white_check_mark: Done (AB#5041) |
| Unattended pipeline | `Invoke-ScoutPipeline` runs collect → assess → report headless into one dated run folder — non-interactive throughout, runs the read-only permission pre-flight first, and degrades to `PartialSuccess` (rather than losing output) if an exporter fails. Writes `pipeline-summary.json`/`.md`. | :white_check_mark: Done (AB#5050) |
| React report + cross-run drift | `-OutputFormat React` renders a single self-contained `report-react.html` (client-side filter/sort/search, summary dashboard, Drift tab). `Get-ScoutDrift` computes cross-run New / Resolved / Regressed / Unchanged findings plus a weighted score delta, tracked in an append-only `.scout-history/findings-history.json`. | :white_check_mark: Done (AB#5053) |

Not yet included in this dev line: full per-category rule depth (AB#5061–5075) — tracked below.

## Major — v2.1.0 — Per-Domain CAF/WAF Analytics (Epic AB#5056)

Focus: extend CAF/WAF analytics to **every** Scout category, not just the landing-zone roll-up. Each of the 15 discovery categories becomes an **independently runnable, categorized and tagged assessment** — so you can run and score *just* Governance, *just* Monitoring, *just* Update Manager, etc.

| Capability | Description | Status |
|---|---|---|
| Assessment taxonomy & tagging | Manifest gains `Category` / `Frameworks` / `Tags`; `-Assessment <Category>` runs scoped discovery + scoped scoring; sub-bundles (Governance/Policy/UpdateManager under Management, Monitoring under Monitor) | :blue_circle: Planned (AB#5057) |
| Per-category coverage | CAF/WAF rule coverage authored for each category — Management, Monitor, Networking, Identity, Security, Compute, Storage, Databases, Containers, Web, Analytics, AI, Integration, Hybrid, IoT | :blue_circle: Planned (AB#5061–AB#5075) |
| Registry document | A table of every possible assessment: category, sub-bundles, CAF areas, WAF pillars, tags | :blue_circle: Planned (AB#5057) |

See [`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md) for the build/release ledger.

## Long-term Vision

AzureScout aims to be the definitive open-source Azure visibility tool for:

- **Architects** — understand the full shape of a tenant before designing changes
- **Security teams** — identify misconfigured, unmonitored, or over-privileged resources
- **FinOps practitioners** — surface cost waste, reservation opportunities, and untagged resources
- **Managed service providers** — generate client-ready reports across multiple tenants

The tool will remain **open-source, PowerShell-native, and Excel-friendly** — no agents, no portals, no licensing fees.

## Completed Phases

All implementation phases from the original migration plan are complete.
See the [Changelog](changelog.md) for the full history.

| Phase | Summary |
|-------|---------|
| Phase 1-9 | Core engine, module loading, Excel generation, JSON output, Draw.io diagrams, auth methods, connection handling, permission pre-flight |
| Phase 10 | Specialized Excel tabs: Cost Management, Security Overview, Azure Update Manager, Azure Monitor |
| Phase 11 | All-subscriptions + full MG hierarchy enumeration |
| Phase 12 | ARM-only default scope, permission documentation, README overhaul |
| Phase 13 | 15 new Azure Monitor/Insights modules |
| Phase 14 | 15 new AI/ML modules |
| Phase 15 | 6 AVD modules + AVD on Azure Local/Arc detection |
| Phase 16 | Arc site configs, Arc SQL Server, Arc Data Services enhancements |
| Phase 17 | VM + Arc deep enrichment (metrics, backup, DR, cost, advisor) |
| Phase 18 | Category folder alignment + `.CATEGORY` metadata parsing |
| Phase 19 | Richer progress indicators, clear permission error messages |
| Phase 20 | `Invoke-AZSCPermissionAudit` + `Test-AZSCPermissions` refactor |
| Phase 21 | Markdown + AsciiDoc export, `Export-AZSCMarkdownReport`, `Export-AZSCAsciiDocReport` |

## Suggest a Feature

Open an issue at [github.com/thisismydemo/azure-scout/issues](https://github.com/thisismydemo/azure-scout/issues) with the label `enhancement`.

Pull requests are welcome — see [Contributing](contributing.md) for guidelines.

## Fork Attribution

::: info Fork Attribution
**AzureScout is a fork of [Azure Resource Inventory (ARI)](https://github.com/microsoft/ARI)** by Microsoft, originally created by [Claudio Merola](https://github.com/Claudio-Merola) and [Renato Gregio](https://github.com/RenatoGregio). The ARI project provided the entire foundation that AzureScout builds upon — its ARM inventory module set, the draw.io diagram engine, Excel reporting, and more. AzureScout is now at 154 ARM + 17 Entra ID = 171 inventory modules — see [ARM Modules](arm-modules.md) and [Entra ID Modules](entra-modules.md). We are deeply grateful for their work.

See [Credits & Attribution](credits.md) for full details, or [Differences from ARI](ari-differences.md) for what has changed.
:::
