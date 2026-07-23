---
description: Complete consolidated task list for Azure Scout — every ADO/GitHub work item, epic, feature, story, and audit bug.
---

# Azure Scout — Complete Task List

Consolidated from the master plan, release ledger, assessment registry, and the
91 reconciled ADO↔GitHub items. Everything that should be done, in one place.

- **ADO:** 161 items (2 Epics, 106 Features, 29 Stories, 24 Bugs) — all currently **New/planned**
- **GitHub:** 91 open issues (1:1 linked to ADO AB#315–#405)
- **Branch:** `claude/repo-access-wexuku`

---

## A. Release 1.1.0 — Quality & Reliability (ADO AB#315–#352)

| GH# | Task |
|---|---|
| #3 | Pester Test Suite — full unit & integration tests |
| #5 | GitHub Actions CI pipeline |
| #6 | Category alias documentation |
| #7 | Resource provider pre-flight warnings |
| #8 | Throttling & retry improvements (exponential backoff) |
| #9 | `Invoke-AzureScout -WhatIf` support |
| #10 | Visual dashboard tabs (EPPlus pivot charts) |
| #20 | Non-destructive cache — prevent overwriting previous scan data |

## B. Release 1.2.0 — Collector Depth (ADO AB#353–#405)

| GH# | Task |
|---|---|
| #11 | Multi-tenant support (Lighthouse cross-tenant scanning) |
| #12 | Cost anomaly detection |
| #13 | Bicep / IaC gap detection |
| #14 | Resource drift reporting (compare inventory runs) |
| #15 | Azure DevOps integration |
| #16 | GitHub Actions module (run AzureScout as a GH Action) |
| #17 | Fabric / Power BI export |
| #18 | IoT deep coverage (device registry, DPS, digital twins, edge) |
| #21 | Multi-tenant scanning support |
| #109 | Management Group hierarchy collection |
| #110 | All subscriptions with state and tags |
| #111 | Custom & built-in policy definitions and initiatives |
| #112 | Policy assignments with scope, enforcement mode, parameters |
| #113 | Role assignments — display name, sign-in name, role, scope, object type |
| #114 | VNets, subnets, DNS servers, service endpoints, VNet peerings |
| #115 | VPN Gateways — type, SKU, active-active, BGP |
| #116 | Azure Firewalls with rule collection detail via Invoke-AzRestMethod |
| #117 | Virtual WAN and hub collection |
| #118 | Network Security Groups — rule counts and subnet/NIC associations |
| #119 | Private DNS zones with VNet links and registration flags |
| #120 | Private Endpoints with NIC lookup for private IPs |
| #121 | Cost Management budgets |
| #122 | Resource locks — level and notes |
| #123 | Tag aggregation — unique values per key across all subscriptions |
| #124 | Cross-subscription context switching with restore |
| #125 | Module auto-install and auto-update on startup |

## C. Web/HTML Reporting & Dashboard features (ADO-tracked)

| GH# | Task |
|---|---|
| #37 | Web-accessible inventory portal — static HTML to enterprise dashboards |
| #33 | Replace Excel charts with standalone HTML dashboard (Apache ECharts) |
| #126 | Dual scoring engine — CAF compliance + WAF alignment |
| #127 | CAF scoring — 7 categories with partial-points rules |
| #128 | WAF pillar scoring with named calculation references and graduated thresholds |
| #129 | WAF config hot-swap via browser file upload |
| #130 | WAF config download as JSON |
| #131 | Hardcoded fallback assessment when config fails to load |
| #132 | vis.js VNet topology diagram — VNets, VMs, peering edges |
| #133 | Click node to open Resource Details side panel |
| #134 | Reset View and Fit to Screen diagram controls |
| #135 | html2canvas diagram capture — embed as PNG in PDF |
| #136 | Hierarchical diagram for Management Group hierarchy visualization |
| #141 | Cached inventory — serve without re-collecting |
| #142 | Per-section search/filter inputs in HTML report |
| #143 | Clickable rows — Resource Details side panel |
| #144 | start.cmd Windows batch launcher and start.sh cross-platform launcher |
| #145 | 14 summary KPI cards on dashboard overview |
| #146 | Full firewall policy rule drill-down |
| #147 | Governance section — budgets table, locks table, tag chips |
| #148 | Policy enforcement mode badge — Default green, DoNotEnforce warning |
| #149 | Scope truncation with full tooltip on hover |

## D. Background collection & progress (ADO-tracked)

| GH# | Task |
|---|---|
| #39 | Auto device-code login with no browser pop-up on headless servers |
| #40 | Auth status banner — UPN and subscription name on login success |
| #41 | Save-AzContext / Import-AzContext for background collection runspace |
| #42 | Post-login management group access probe |
| #43 | 10-minute AbortController timeout on collection fetch |
| #137 | Background runspace collection — HTTP listener stays responsive |
| #138 | File-based progress IPC — runspace writes temp JSON, client polls every 800ms |
| #139 | Named collection stages with step/totalSteps percentage |
| #140 | Concurrent collection guard |
| #150 | Custom addTable() PDF helper with page-break-aware header repeat |
| #151 | addSubSection(), addBullet(), getStatusEmoji() PDF text helpers |
| #152 | JSON evidence export — resources only, no assessment metadata |
| #153 | Per-subscription try/catch/continue — DNS and token errors skip sub |
| #154 | AuthorizationFailed on MG — emit role requirement hint |
| #155 | Swallow false MG resource-provider registration error |
| #156 | Firewall policy rule parse errors logged per group — collection continues |
| #157 | Empty-data guard with diagnostic hint |
| #158 | Pipeline HadErrors check — extract and log as warnings |
| #159 | Runspace disposed in finally block |
| #160 | Client double-poll guard on collecting:true response |
| #161 | Integrate PwshSpectreConsole for rich terminal TUI progress display |

## E. Export formats (ADO-tracked)

| GH# | Task |
|---|---|
| #22 | Word document (.docx) report export |
| #23 | PDF report export |

## F. Open bugs (ADO-tracked)

| GH# | Bug |
|---|---|
| #24 | Automation mode cache writes to null path (Start-AZSCAutProcessJob missing $DefaultPath) |
| #25 | Progress bar always shows 0% in Build-AZSCCacheFiles ($ReportCounter undeclared) |
| #26 | $JobNames never assigned in automation branch of Start-AZSCProcessOrchestration |
| #27 | $StorageContext null reference when using -StorageAccount without -Automation |
| #28 | $VMQuotas undefined when -SkipVMDetails is passed |
| #29 | GitHub Actions azure-inventory.yml workflow is non-functional — pure simulation |
| #38 | **[HIGH]** Entra ID modules failing even with Global Admin permissions |

## G. Maintenance / meta (ADO-tracked)

| GH# | Task |
|---|---|
| #1 | Phase testing & validation — all phases (5–21) |
| #30 | Tech debt & improvements tracking |
| #31 | Improvement of Draw.IO diagrams |
| #32 | Azure Automation Account support (first-class unattended execution) |
| #36 | Auto-generate roadmap from GitHub issues (single source of truth) |

---

## H. Epic AB#5023 — CAF/WAF Landing-Zone Assessment Platform (Release 2.0.0)

| Feature | Area | Focus |
|---|---|---|
| AB#5024 | Platform | Module registry + `Invoke-AzureScout` entry point |
| AB#5027 | Assess | Declarative rule engine (JSONPath, evaluator, loader) |
| AB#5031 | Assess | CAF 8-area + WAF 5-pillar rule files |
| AB#5034 | Assess | Assessment runner + dual CAF/WAF scoring |
| AB#5037 | Ingest | AzGovViz + ARG query pack + Advisor → collect.json |
| AB#5041 | Benchmark | ALZ benchmark diff — **Delivered**: native `Import-Governance` collector is the default governance ingest; AzGovViz is opt-in only |
| AB#5044 | Report | Tiered renderer engine (PowerBi/Html/Pptx/Excel/Json) |
| AB#5050 | Platform | Permission pre-flight + unattended pipeline — **Delivered**: `Invoke-ScoutPipeline` |
| AB#5053 | Report | React report variant + cross-run drift tracking — **Delivered**: `Export-React` + `Get-ScoutDrift` |

## I. Epic AB#5056 — Per-Domain CAF/WAF Analytics (Release 2.1.0)

| Feature | Scope |
|---|---|
| AB#5057 (+ #5058–#5060) | Taxonomy: manifest Category/Frameworks/Tags, `-Assessment <Category>` scoped run, registry doc |
| AB#5061 | Management (Governance, Policy, UpdateManager, Backup, Automation) |
| AB#5062 | Monitor (Monitoring, Alerting, Diagnostics) |
| AB#5063 | Networking (Connectivity, Firewall, PrivateLink) |
| AB#5064 | Identity (PIM, ConditionalAccess, RBAC) |
| AB#5065 | Security (Defender, KeyVault, SecureScore) |
| AB#5066 | Compute (Resiliency, CostCleanup) |
| AB#5067 | Storage (DataProtection, Redundancy) |
| AB#5068 | Databases (Resiliency, DataProtection) |
| AB#5069 | Containers (AKS, Registry) |
| AB#5070 | Web (AppService, Functions) |
| AB#5071 | Analytics (Purview, DataPlatform) |
| AB#5072 | AI (ResponsibleAI, PrivateAI) |
| AB#5073 | Integration (Messaging, APIM) |
| AB#5074 | Hybrid (Arc, AzureLocal) |
| AB#5075 | IoT (IoTHub, DPS) |

---

## J. Audit bugs — logged AB#5076–#5092 (found 2026-07-20)

| Bug | Finding | Parent | Sev |
|---|---|---|---|
| AB#5076 | MG query unpaged (drops subs >1000) — needs SkipToken paging | AB#353 | 🔴 |
| AB#5077 | Bare `Exit` kills host/runbook — use `throw` | AB#353 | 🔴 |
| AB#5078 | >200-sub batch off-by-one / double-count | AB#354 | 🔴 |
| AB#5079 | One bad sub aborts whole tenant run — try/catch/continue | AB#397 | 🟠 |
| AB#5080 | No zero-resources guard | AB#401 | 🟠 |
| AB#5081 | `Invoke-Collect` adapter missing — assessment can't run e2e | AB#5024 | 🔴 |
| AB#5082 | Discovery↔assessment data-shape mismatch (flat vs nested) | AB#5024 | 🔴 |
| AB#5083 | JSONPath `.length` unsupported + exception-as-Pass | AB#5027 | 🔴 |
| AB#5084 | Benchmark silent all-Fail without governance data — **Fixed**: guard now keys off native `Import-Governance` collection, not AzGovViz | AB#5041 | 🔴 |
| AB#5085 | `percentageAtLeast` zero-denom / value:0 always passes | AB#5027 | 🟡 |
| AB#5086 | WAF-RE-05 no "where supported" zone qualifier | AB#5031 | 🟡 |
| AB#5087 | `AreaWeight` dead / unweighted framework score | AB#5034 | 🔴 |
| AB#5088 | `Unknown` rules silently dropped from denominator | AB#5034 | 🔴 |
| AB#5089 | Null severity sorts to top / PPTX crash on .upper() | AB#5034 | 🔴 |
| AB#5090 | HTML null area score renders red | AB#5044 | 🟠 |
| AB#5091 | Banker's rounding / Excel sheet-name collision | AB#5044 | 🟡 |
| AB#5092 | Power BI join needs stable `AreaKey` | AB#5044 | 🟡 |

> **Note on audit-fix status:** critical-path fixes (AB#5076–#5078, #5081–#5085,
> #5087–#5090) have prototype code committed on the branch but are **static-validated
> only** — not runtime-verified. They remain New on the board until verified.

---

## K. Remaining engineering actions (from master plan §8)

1. **Runtime-verify** all committed audit fixes — run `tests/Assessment.Engine.Tests.ps1` + an end-to-end `-FromCollect` pass (needs pwsh + Az).
2. **Wire the module manifest** (`AzureScout.psd1`) to dot-source `src/` functions so `Invoke-AzureScout` / `Invoke-Collect` / `Invoke-ScoutAssessment` load as a module (AB#5024).
3. **Author per-category rule content** and manifest entries for Epic AB#5056.
4. **Finish remaining polish bugs:** AB#5086, AB#5091, AB#5092, AB#5079, AB#5080.
5. **Decisions pending:** keep/strip `azure-scout` tag; GitHub roadmap projection (Flow 2) for approved Features.
