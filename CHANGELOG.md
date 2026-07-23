# Changelog

All notable changes to the AzureScout module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-07-23

### Added

- **Native governance collector** (AB#5041): `src/ingest/Import-Governance.ps1` replaces the AzGovViz hard dependency as the default governance collector. Populates `collect.json`'s `governance` object natively from Azure Resource Graph (`policyresources` → policyAssignments, `authorizationresources` → roleAssignments, `resourcecontainers` → managementGroups) plus ambient-token ARM REST (`Microsoft.Consumption/budgets`, `Microsoft.Authorization/locks`). No cloned repo, no `AzAPICall` install prompt, fully unattended, StrictMode-safe. Needs only Reader at the management-group root. Live-verified against the HCS tenant: real policy/role assignments collected, CAF governance/identity rules scored real Pass/Fail, and the ALZ benchmark correctly degrades to an explicit `Unknown` (instead of a false 0%) when management-group data isn't visible. Two datasets are intentionally empty: `classicAdministrators` (retired API — CAF-IDN-03 asserts `notExists`, so empty is compliant) and `pimEligibility` (needs Entra ID P2 + `PrivilegedAccess.Read.AzureResources`).
- **Unattended pipeline** (AB#5050): new public cmdlet `Invoke-ScoutPipeline` (`src/Invoke-ScoutPipeline.ps1`) runs collect → assess → report headless into a single dated run folder — non-interactive throughout (`ConfirmPreference = 'None'`, `ProgressPreference = 'SilentlyContinue'`). Runs the read-only permission pre-flight first (unless `-SkipPermissionAudit`) and wraps the orchestrator in try/catch so an exporter failure degrades to `PartialSuccess` instead of losing output. Writes `pipeline-summary.json` (CI-facing: `schemaVersion`, `startedOn`/`finishedOn`, `elapsedSeconds`, `assessments`, `formats`, `findingsByStatus`, `permissionAudit`, `outcome` ∈ `Success`/`PartialSuccess`/`Failed`) and `pipeline-summary.md`. Returns the run-folder path; throws and sets `$LASTEXITCODE = 1` only on `Failed`. Parameters: `-Assessment`, `-OutputFormat` (default `All`), `-OutputPath`, `-ManagementGroupId`, `-Category`, `-SkipPermissionAudit`.
- **React report + cross-run drift** (AB#5053): new renderer `Export-React` produces a single self-contained `report-react.html` (all CSS/JS inline, findings embedded as a JSON blob, no external/CDN requests) with client-side filter by Framework/Area/Severity/Status, a sortable/searchable findings table, a summary dashboard, and a Drift tab. New `-OutputFormat React` value on `Invoke-ScoutAssessment` (included in `All`) and wired into `Invoke-ScoutPipeline` via `-OutputFormat`. New `Get-ScoutDrift` computes cross-run drift: per finding New / Resolved (Fail/Partial → Pass) / Regressed (Pass → Fail/Partial) / Unchanged, plus an overall weighted score delta, maintained in an append-only `findings-history.json` under a `.scout-history/` folder in the output root (keyed by run id; first run = baseline). `Invoke-ScoutAssessment` computes drift after scoring and feeds it to the React report; a drift failure is non-fatal.

### Changed

- **AzGovViz is no longer a default dependency.** The manifest assessments that previously used `Ingest = AzGovViz` (`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`) now use `Ingest = Governance` (the native collector, AB#5041). AzGovViz remains available as an opt-in `Ingest` value for anyone who wants the third-party tool specifically, but nothing depends on it by default. This corrects the earlier assumption that the ALZ benchmark / governance data was blocked pending an upstream AzGovViz fix — it no longer depends on AzGovViz at all; the only remaining caveat is that the benchmark needs Reader at the MG root for MG/policy visibility.

## [2.0.1] - 2026-07-23

### Changed

- **Manifest `ProjectUri`** now points at the documentation site (`https://thisismydemo.cloud/azure-scout/`) so the PowerShell Gallery "Project Site" link lands on the docs rather than the GitHub repo.

## [2.0.0] - 2026-07-23

Major release — the **CAF/WAF Assessment Platform**. Extends AzureScout from an
inventory tool into a read-only Cloud Adoption Framework / Well-Architected
landing-zone assessment. Runtime-verified offline (Pester) and against a live
Azure tenant.

> **Breaking:** introduces the `findings.json` output contract and demotes
> Excel-first output to an evidence tier. Assessment features require
> PowerShell 7; the v1 inventory functionality is unchanged and still runs on 5.1.

### Fixed

- **Discovery data-loss fixes**: `Get-AZSCManagementGroups` now pages Resource Graph via SkipToken (was capped at 1000 subs — AB#5076) and throws instead of `Exit` on a bad management group (AB#5077); `Start-AZTIGraphExtraction` throws instead of `Exit` (AB#5077); `Invoke-AZTIInventoryLoop` no longer double-counts boundary subscriptions in the >200-subscription batch loop (AB#5078).
- **Assessment correctness**: rewrote `.length` JSONPath filters to scalar fields; `Resolve-JsonPath` no longer swallows a thrown query into an empty result and `Invoke-Rule` surfaces it as `Error` rather than a false Pass (AB#5083); `percentageAtLeast` with a zero denominator yields `Unknown` (AB#5085); `Compare-Benchmark` guards absent governance data instead of emitting false all-Fail (AB#5084).
- **Scoring/reporting**: framework score is weighted by `AreaWeight` (AB#5087); `Unknown`/`Error` statuses are surfaced, not silently dropped (AB#5088); unknown severities sort last and can't crash the PPTX deck (AB#5089); null area scores render neutral in HTML, not red (AB#5090); deterministic rounding.
- **StrictMode runtime defects surfaced by first engine execution** (AB#5027): `Resolve-JsonPath` empty-result collapse to `$null` across the function boundary; `Get-Score` zero-match pipeline null-collapse under `Set-StrictMode -Version Latest`; `Invoke-Rule` unconditional `assert.value` access for `exists`/`notExists`/`manual` rules; and an unguarded `$spec.Benchmark` lookup in `Invoke-ScoutAssessment` that broke 21 of 22 manifest assessments.
- **WAF-RE-05** zone-redundancy rule scoped to zone-eligible regions instead of flagging every non-zone-redundant VM (AB#5086).
- **Ingest robustness surfaced by live root-MG runs** (AB#5037): `Invoke-ArgQueryPack` and `Invoke-Collect` no longer pass `-Skip 0` (rejected by `Search-AzGraph`); `Import-AzGovViz` preinstalls its `AzAPICall` dependency, passes `-NoPIMEligibility` when PIM data is unavailable, isolates the third-party script from the module's strict mode, and folds in partial exports if AzGovViz crashes mid-run instead of failing the whole assessment.

### Added

- **Reporting — OpenXML PowerPoint renderer** (AB#5044): `Export-Pptx.ps1` rebuilt on `DocumentFormat.OpenXml` (acquired via NuGet on first use, cached locally, no committed binaries) — the Python `python-pptx`/`build_deck.py` prototype is removed entirely. Generates a themed executive deck (title, executive summary, area-score breakdown, prioritized gaps, manual worklist, next steps) with a designer-template extension point. Decision recorded in `docs/design/decisions/pptx-renderer.md`.
- **Collect layer — per-domain ARG collectors**: extended `Invoke-Collect.ps1` (Service Bus, Arc extensions, Azure Local clusters, Log Analytics retention, private-endpoint target linkage, plus storage/web/AKS/AI/analytics/integration fields) so 16 previously manual rules now evaluate automatically. Rule set is 139 rules across 23 files (93 automated / 46 manual, each documenting the data source it needs).
- **Verification fixtures & tests**: `tests/datadump/sample-collect.json` canonical fixture exercising every status path; `tests/Test-PptxFromDataDump.ps1` smoke test; engine Pester suite green (6/6), full repo suite passing.

- **`src/collect/Invoke-Collect.ps1`** — normalized, read-only Azure Resource Graph adapter that produces the canonical `collect.json` (scalar fields) the rule engine evaluates against, resolving the discovery→assessment data-shape gap (AB#5081, AB#5082).
- **`tests/Assessment.Engine.Tests.ps1`** — Pester smoke tests for the scoring math and assert semantics.

#### CAF/WAF assessment platform — three-layer architecture (Epic AB#5023)

- **Assessment layer** (`src/assess/`) — declarative rule engine that grades collected data against CAF design areas and WAF pillars, producing scored findings and a prioritized gap list:
  - `engine/Get-RuleSet.ps1`, `Resolve-JsonPath.ps1`, `Invoke-Rule.ps1` (7 assert types), `Get-Score.ps1` (dual CAF/WAF scoring)
  - `rules/caf.*.yaml` (8 CAF design areas) and `rules/waf.*.yaml` (5 WAF pillars)
  - `benchmarks/alz-reference.json` + `Compare-Benchmark.ps1` (ALZ benchmark diff)
- **Ingest layer** (`src/ingest/`) — `Import-AzGovViz.ps1`, `Invoke-ArgQueryPack.ps1`, `Import-AdvisorScores.ps1` normalize external collectors into a single `collect.json`
- **Reporting layer** (`src/report/`) — tiered renderer engine (`Export-Report` → PowerBi / Html / Pptx / Excel / Json) reading a shared `findings.json`
- **Module registry** (`manifests/assessments.psd1`) + `Invoke-AzureScout` entry point for run-one/some/all; read-only permission pre-flight; unattended `.ado/azure-pipelines.yml`
- JSON-on-disk contract (`collect.json` → `findings.json`) so each layer runs independently

#### Per-domain CAF/WAF analytics across all categories (Epic AB#5056)

- Every Scout discovery category (15: AI, Analytics, Compute, Containers, Databases, Hybrid, Identity, Integration, IoT, Management, Monitor, Networking, Security, Storage, Web) becomes an **independently runnable, categorized and tagged assessment** with its own CAF/WAF analytics
- Manifest schema extended with `Category`, `Frameworks`, and `Tags` so `-Assessment <Category>` runs scoped discovery + scoped scoring (planned — AB#5057)
- Finer named sub-bundles inside a category (e.g. Governance / Policy / UpdateManager under Management; Monitoring under Monitor)

#### Power BI / Microsoft Fabric Export (Issue #17)

- **`Export-AZSCPowerBIReport.ps1`** (`Modules/Private/Reporting/`) — New function that exports normalized inventory data as a flat CSV bundle optimized for Power BI Desktop and Microsoft Fabric:
  - `_metadata.csv` — Scan metadata (tenant ID, date, scope, version, subscription count)
  - `Subscriptions.csv` — Subscription dimension table (`SubscriptionId`, `SubscriptionName`)
  - `Resources_{Module}.csv` — One file per ARM inventory module with `_Category` and `_Module` columns
  - `Entra_{Module}.csv` — One file per Entra ID / Identity module with `_Category` and `_Module` columns
  - `_relationships.json` — Star-schema relationship manifest describing many-to-one joins from resource tables to `Subscriptions` via `Subscription → SubscriptionName`
- **`-OutputFormat PowerBI`** added to `Invoke-AzureScout` `ValidateSet` — generates the `PowerBI/` folder as a sibling of the main report file; included in `All` by default
- **`Test-PowerBIFromDataDump.ps1`** (`tests/`) — Offline test harness that reconstructs the `ReportCache` from a JSON data dump and validates the full CSV bundle without requiring a live Azure connection
- Pester tests in `OutputFormat.Tests.ps1` covering `Export-AZSCPowerBIReport` function discovery, `_metadata.csv` content, `Subscriptions.csv`, `_relationships.json` validity, and `Resources_*.csv` / `Entra_*.csv` file generation with correct columns

## [1.0.0] - 2026-02-25

### Added

- Initial fork from [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11
- Renamed module to `AzureScout` (prefix `AZSC`)
- New module manifest with fresh GUID, v1.0.0
- Repository scaffolding (CHANGELOG, README, tests/)

#### Visual Dashboard Tabs

- **`Build-AZTIDashboardTabs.ps1`** (`Modules/Private/Reporting/StyleFunctions/`) — New 725-line function generating 4 visual dashboard worksheets with EPPlus pivot charts and DarkBlue tab coloring:
  - **Cost Dashboard** — Cost by Resource Type (bar), Cost by Subscription (pie), Cost by Region (column), Cost by SKU (bar)
  - **Security Dashboard** — Assessments by Severity (pie), Findings by Subscription (bar), Defender Plans (column), Active Alerts by Severity (bar)
  - **Update Manager Dashboard** — Machines by Platform (pie), Machines by OS Type (pie), Machines by Region (column), Machines by Power State (bar), Machines by Subscription (bar)
  - **Monitor Dashboard** — Alert Rules by Subscription (bar), Action Groups by Subscription (pie), DCRs by Subscription (column), App Insights by Subscription (bar)
  - Each dashboard only appears when its corresponding raw data tab has data (no empty dashboards)

#### Excel StyleFunctions Recreation

- **`Build-AZTIExcelComObject.ps1`** — Recreated from ARI original with AZSC namespace (COM-based chart generation for Windows environments)
- **`Start-AZTIExcelCustomization.ps1`** — Recreated from ARI original with AZSC namespace (Excel chart customization, version resolution from module manifest, Overview sheet assembly)
- **`Start-AZTIExcelOrdening.ps1`** — Recreated from ARI original with AZSC namespace (worksheet tab ordering and color assignment — Overview/Subscriptions/Advisor tabs pinned as DarkBlue)

#### Full Rebranding

- Replaced all remaining "Azure Tenant Inventory" references with "Azure Scout" across 239 files (`.ps1`, `.psm1`, `.psd1`, `.md`, `.yml`, `.adoc`)
- Updated permission audit banner, report titles, module metadata, comment blocks, and documentation

#### Version Alignment

- Reset `ModuleVersion` from `2.0.0` to `1.0.0` — module has not been published to PSGallery yet
- Updated version in module manifest, `.NOTES` blocks (3 source files), test assertions (2 test files), and all documentation (roadmap, changelog, output docs)
- Aligned report output versions: Excel fallback `3.6` → `1.0.0`, JSON `_metadata.version` `1.5.0` → `1.0.0`
- Roadmap future versions updated: `v2.1.0` → `v1.1.0`, `v2.2.0` → `v1.2.0`

#### Phase 7 — Cleanup & Polish

**Documentation**
- Rewrote `README.md` — comprehensive parameter reference table, 17-category module catalog (95 ARM + 15 Entra = 110 total), 5 authentication methods, `-Scope`/`-OutputFormat` quick start, JSON output structure
- Created `CREDITS.md` — attribution to original ARI project (Claudio Merola, RenatoGregio, Doug Finke/ImportExcel), MIT license notes
- Updated `Set-AZSCReportPath.ps1` comment-based help (Synopsis, Description, Link, Version, Authors)

**Antora Documentation Site** (8 new pages)
- `authentication.adoc` — 5 auth methods with code examples, priority order, LoginExperienceV2 handling
- `usage.adoc` — Scope, OutputFormat, content toggles, report location, JSON structure
- `permissions.adoc` — ARM RBAC and Graph API permissions, pre-flight checker behavior, scope-based gating
- `arm-modules.adoc` — Complete catalog of 95 ARM modules across 16 categories with resource type descriptions
- `entra-modules.adoc` — 15 Entra ID modules with Graph endpoints, data normalization, graceful degradation
- `contributing.adoc` — How to add new modules, Pester test patterns, PR guidelines, code style
- `credits.adoc` — AsciiDoc version of CREDITS.md
- `changelog.adoc` — Version history summary with link to CHANGELOG.md
- Updated `index.adoc` — landing page with correct module counts and navigation grid
- Updated `nav.adoc` — full 10-page navigation tree with Getting Started / Module Reference / Project sections
- Updated `folder-structure.adoc` — corrected module counts (110/17), added Identity/AzureLocal categories, CREDITS.md

**GitHub Actions**
- Replaced MkDocs workflow (Python/pip/mkdocs) with Antora workflow (Node.js 20, `npx antora`, `build/site` output)

**Pester Tests** (5 new test files)
- `Test-AZSCPermissions.Tests.ps1` — return structure, ARM/Graph pass/fail/warn, scope gating, never-throws guarantee
- `Invoke-AzureScout.Tests.ps1` — ValidateSet enforcement, parameter aliases, switch params
- `Connect-AZSCLoginSession.Tests.ps1` — 4 auth paths (SPN+cert, SPN+secret, device-code, current-user), TenantID enforcement, LoginExperienceV2
- `Invoke-AZSCGraphRequest.Tests.ps1` — URI normalization, pagination, SinglePage switch, retry 429/5xx, max retries
- `Start-AZSCEntraExtraction.Tests.ps1` — return structure, normalized shape, all 15 queries, graceful degradation

#### Phase 6 — JSON Output Layer

- **`Export-AZSCJsonReport.ps1`** — New function at `Modules/Private/Reporting/Export-AZSCJsonReport.ps1`
  - Reads all `{FolderName}.json` cache files produced by the processing phase
  - Assembles a structured JSON document with `_metadata` envelope (tool, version, tenantId, subscriptions, generatedAt, scope)
  - ARM inventory data organized under `arm` key by module folder (compute, network, storage, etc.)
  - Entra/Identity data organized under `entra` key (users, groups, appRegistrations, etc.)
  - Extra reports (advisory, policy, security, quotas) included as top-level keys when available
  - Outputs to `{ReportDir}/{ReportName}_Report_{timestamp}.json` alongside the Excel file
- **`-OutputFormat` parameter** added to `Invoke-AzureScout`
  - `All` (default): Generate both Excel (.xlsx) and JSON (.json) reports
  - `Excel`: Generate Excel report only, skip JSON export
  - `Json`: Generate JSON report only, skip Excel generation
- Conditional logic wraps Excel reporting (`Start-AZSCReporOrchestration`, `Start-AZSCExcelCustomization`) to skip when `OutputFormat = 'Json'`
- JSON file automatically uploaded to Storage Account in automation mode when `OutputFormat` includes Json

#### Phase 8 — Inventory Module Expansion (ARM)

**Azure Local (Stack HCI) — 6 new modules** (`Modules/Public/InventoryModules/AzureLocal/`):
- `Clusters.ps1` — Cluster inventory (`microsoft.azurestackhci/clusters`): status, version, node count, connectivity, diagnostics level
- `VirtualMachines.ps1` — VM instances (`microsoft.azurestackhci/virtualmachineinstances`): power state, VM size, OS type, CPU/memory, dynamic memory, disks, image reference
- `LogicalNetworks.ps1` — Logical networks (`microsoft.azurestackhci/logicalnetworks`): VM switch, subnets, address prefix, VLAN, DHCP, IP pools, DNS, routes
- `StorageContainers.ps1` — Storage containers (`microsoft.azurestackhci/storagecontainers`): provisioning state, path, available/container size (GB)
- `GalleryImages.ps1` — Gallery images (`microsoft.azurestackhci/galleryimages`): OS type, Hyper-V generation, publisher/offer/SKU/version
- `MarketplaceGalleryImages.ps1` — Marketplace images (`microsoft.azurestackhci/marketplacegalleryimages`): OS type, generation, publisher/offer/SKU/version, download size, progress

**Azure Arc — 4 new modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcGateways.ps1` — Arc Gateway inventory (`microsoft.hybridcompute/gateways`): gateway type, endpoint, allowed features
- `ArcKubernetes.ps1` — Arc-enabled Kubernetes (`microsoft.kubernetes/connectedclusters`): connectivity, distribution, K8s version, node count, agent version, infrastructure
- `ArcResourceBridge.ps1` — Resource bridge/appliances (`microsoft.resourceconnector/appliances`): status, distro, version, infrastructure type
- `ArcExtensions.ps1` — Machine extensions (`microsoft.hybridcompute/machines/extensions`): machine name, publisher, type, version, auto upgrade, status

#### Phase 9 — Governance, Security & Monitoring Expansion

**Azure Policy & Governance — 6 new modules** (`Modules/Public/InventoryModules/Management/`):
- `ManagementGroups.ps1` — Management group hierarchy (`microsoft.management/managementgroups`): parent chain, child count (recursive enumeration)
- `CustomRoleDefinitions.ps1` — Custom RBAC roles (`microsoft.authorization/roledefinitions`): assigned scope, Actions, NotActions (parsed from JSON permissions)
- `PolicyDefinitions.ps1` — Custom policy definitions (`microsoft.authorization/policydefinitions`): policy type, mode, metadata, rule JSON (parsed)
- `PolicySetDefinitions.ps1` — Policy initiatives (`microsoft.authorization/policysetdefinitions`): definition references count, parameter count, policy definition groups
- `PolicyComplianceStates.ps1` — Per-subscription compliance (`microsoft.policyinsights/policyStates`): compliance state (Compliant/NonCompliant), yellow conditional formatting for NonCompliant
- `MaintenanceConfigurations.ps1` — Update Manager configurations (`microsoft.maintenance/maintenanceconfigurations`): scope, maintenance window (start/expiration/duration/time zone/recurrence), install patches configuration (Windows/Linux classifications, KB numbers, reboot setting), extension properties count

**Microsoft Defender for Cloud — 4 new modules** (`Modules/Public/InventoryModules/Security/`):
- `DefenderAssessments.ps1` — Security recommendations (`/microsoft.security/securescores/.../assessments`): status, severity, category, resource ID parsing, red highlighting for High/Non-Compliant
- `DefenderSecureScore.ps1` — Secure Score tracking (`/microsoft.security/securescores`): current/max points, percentage calculation, weight, nested control retrieval, red highlighting <50%
- `DefenderAlerts.ps1` — Security alerts (`microsoft.security/locations/.../alerts`): MITRE ATT&CK tactics/techniques, entity parsing (account/host/IP/mailbox/process), remediation steps, red/yellow conditional formatting
- `DefenderPricing.ps1` — Defender plan enablement (`microsoft.security/pricings`): per-resource-type pricing tier, friendly name mapping (VirtualMachines, SqlServers, Storage, KeyVaults, etc.), green/red conditional formatting

**Azure Monitor Resources — 6 new modules** (`Modules/Public/InventoryModules/Monitoring/`):
- `ActionGroups.ps1` — Alert notification channels (`microsoft.insights/actiongroups`): email receivers (name:address pairs), SMS receivers (name:country-phone), webhook receivers, Azure App Push, automation runbooks, Azure Functions, Logic Apps, total receiver count, enabled status
- `MetricAlertRules.ps1` — Metric-based alert rules (`microsoft.insights/metricalerts`): criteria type, condition parsing (metric name, operator, threshold, time aggregation), target resource enumeration, action group references, severity mapping (0-4 to Critical/Error/Warning/Informational/Verbose), evaluation frequency/window size, auto-mitigate status
- `ScheduledQueryRules.ps1` — Log query-based alerts (`microsoft.insights/scheduledqueryrules`): KQL query extraction, data source identification (Log Analytics workspaces), condition parsing (metric measure column, operator, threshold), action group references, legacy alert detection (kind != 'LogAlert'), legacy API warning flag
- `DataCollectionRules.ps1` — Azure Monitor Agent configurations (`microsoft.insights/datacollectionrules`): data source parsing (performance counters, Windows event logs, syslog, extensions), destination tracking (Log Analytics workspace names, Azure Monitor Metrics, Event Hub, Storage), data flow enumeration (streams to destinations mapping), KQL transformation detection, data collection endpoint association, immutable ID tracking
- `DataCollectionEndpoints.ps1` — Log ingestion endpoints (`microsoft.insights/datacollectionendpoints`): network access configuration (public/private), configuration/logs/metrics ingestion endpoint URLs, private link scope connections, failover configuration parsing, immutable ID tracking
- `SubscriptionDiagnosticSettings.ps1` — Activity Log configurations (per-subscription iteration via `Get-AzDiagnosticSetting`): enabled log category enumeration, retention policy parsing (days or unlimited), multi-destination support (Log Analytics workspace, Storage account, Event Hub namespace, Partner solutions), category enablement count (enabled/total), per-subscription iteration with error handling

**Network & Managed Services — 2 new modules**:
- `NetworkWatchers.ps1` — Network diagnostic instances (`microsoft.network/networkwatchers` in `Network/`): flow log enumeration (child resource aggregation), connection monitor tracking, packet capture counting, provisioning state, capability listing (IP Flow Verify, Next Hop, VPN Troubleshoot, NSG Diagnostics, Topology, Connection Troubleshoot)
- `LighthouseDelegations.ps1` — Service provider delegations (`Microsoft.ManagedServices/registrationDefinitions` in `Management/`): managing tenant identification (ID and display name), authorization parsing (principal ID, principal display name, role definition ID), role GUID to friendly name mapping (Contributor, Owner, Reader, monitoring/log analytics roles), delegation type detection (Permanent vs Eligible/JIT based on delegatedRoleDefinitionIds), eligible authorization counting, provisioning state tracking

**Entra ID Verification — 2 new modules** (`Modules/Public/InventoryModules/Identity/`):
- `IdentityProviders.ps1` — Federated/social identity providers (`/v1.0/identity/identityProviders`): provider type (Built-In, Social, SAML/WS-Fed, OIDC, Apple), identity provider type, client ID, client secret configured flag, issuer URL, domains hint, response mode/type, scope, enabled status, yellow conditional formatting if client secret not configured
- `SecurityDefaults.ps1` — Security Defaults enforcement policy (`/v1.0/policies/identitySecurityDefaultsEnforcementPolicy`): enabled status, description, last modified date, protections provided (MFA requirements, legacy auth blocking), recommendation status, green formatting if enabled, yellow if disabled

**Extraction Layer Enhancement**:
- `Start-AZSCEntraExtraction.ps1` — Added 2 new Graph API queries: `/v1.0/identity/identityProviders` (array), `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy` (SingleObject)

### Changed

#### Phase 8 — Enhanced VPN & Networking Detail

- `VirtualNetworkGateways.ps1` — Added 10 new fields: P2S address pool, VPN client protocols, auth type, root/revoked cert counts, RADIUS server, AAD tenant, custom DNS servers, NAT rules count, policy group count
- `Connections.ps1` — Added 13 new fields: IPsec/IKE encryption & integrity, DH group, PFS group, SA lifetime/data size, policy-based traffic selectors, traffic selectors, DPD timeout, ingress/egress bytes, shared key presence (boolean only)

### Removed

- RAMP functions (`Modules/Private/4.RAMPFunctions/`)
- `Invoke-AzureRAMPInventory` public function
- Auto-update logic (`Update-Module` call)
- `Remove-ARIExcelProcess` (aggressive Excel process killer)

### Fixed

- **Permission audit subscription scoping** (#19) — `Invoke-AZSCPermissionAudit` now accepts `-SubscriptionID` and scopes RBAC/provider checks to only targeted subscriptions instead of auditing all accessible subscriptions in the tenant. Passed through from `Invoke-AzureScout` and `Test-AZSCPermissions`

### Changed

- All exported function names: `*-ARI*` → `*-AZSC*`
- Module metadata (author, description, project URI, tags)
- LICENSE updated with dual copyright (original + fork)

#### Phase 11 — Comprehensive Subscription & Management Group Logging

- **Subscription completeness**: Updated extraction layer to enumerate ALL tenant subscriptions (including empty/disabled ones), not just subscriptions containing resources
- **Subscription properties** per record: Subscription ID, Name, State (Enabled/Disabled/Warned), Tenant ID, Management Group path/hierarchy, Tags, Resource count, Spending limit status, Authorization source
- **"All Subscriptions" worksheet** added to Excel report with conditional formatting (empty subscriptions highlighted)
- **Management Group completeness**: Captures ALL management groups in tenant hierarchy via `Get-AzManagementGroup -Expand -Recurse`
- **Management Group properties** per record: ID, display name, parent MG ID, children (child MGs + subscriptions), hierarchy level/depth, policy assignment count, role assignment count
- **"Management Groups" worksheet** added to Excel report with indented hierarchy visualization
- Overview tab resource counts updated to reflect all subscriptions and management groups (not just resource-bearing ones)

#### Phase 13 — Comprehensive Azure Monitor / Insights Coverage

**Core Azure Monitor Resources — 6 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `ResourceDiagnosticSettings.ps1` — Per-resource diagnostic settings via `Get-AzDiagnosticSetting`: ResourceId, ResourceName, ResourceType, log/metric categories (enabled/disabled), destinations (Log Analytics, Storage, Event Hub, Partner Solutions). Excel: "Resource Diagnostic Settings"
- `ActivityLogAlertRules.ps1` — Activity log alerts via `Get-AzActivityLogAlert`: Name, ResourceGroup, Enabled, Scopes, Condition (category, level, status), Actions (Action Group names). Excel: "Activity Log Alerts"
- `SmartDetectorAlertRules.ps1` — Smart detector alerts via `microsoft.alertsmanagement/smartDetectorAlertRules`: Name, Severity, Frequency, Detector type, Application Insights scope, ActionGroups. Excel: "Smart Detector Alerts"
- `AutoscaleSettings.ps1` — Autoscale configurations via `Get-AzAutoscaleSetting`: TargetResourceId, Enabled, Profiles (name, capacity min/max/default, rules count), Notifications (webhooks, email). Excel: "Autoscale Settings"
- `MonitorWorkbooks.ps1` — Azure Monitor Workbooks via `microsoft.insights/workbooks`: Name, Category, SourceId (linked resource), TimeModified. Excel: "Azure Monitor Workbooks"
- `MonitorPrivateLinkScopes.ps1` — Monitor Private Link Scopes via `microsoft.insights/privateLinkScopes`: Name, PrivateEndpointConnections count, ScopedResources count/types. Excel: "Monitor Private Link Scopes"

**Log Analytics Enhancements — 3 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `LAWorkspaceSavedSearches.ps1` — Saved searches per workspace: DisplayName, Category, Query, Version. Excel: "LA Saved Searches"
- `LAWorkspaceSolutions.ps1` — Installed solutions via `microsoft.operationsmanagement/solutions`: WorkspaceResourceId, Plan (name, publisher, product), ProvisioningState. Excel: "LA Solutions"
- `LAWorkspaceLinkedServices.ps1` — Linked services per workspace: WorkspaceName, ResourceId, WriteAccessResourceId (Automation Account). Excel: "LA Linked Services"

**Application Insights Deep Data — 5 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `AppInsightsAvailabilityTests.ps1` — Classic availability tests, Enabled, Frequency, Timeout, Locations count. Excel: "App Insights Availability Tests"
- `AppInsightsWebTests.ps1` — Web tests via `microsoft.insights/webtests`: Kind (ping/multistep/standard), SyntheticMonitorId, Enabled, Frequency, Timeout. Excel: "App Insights Web Tests"
- `AppInsightsProactiveDetection.ps1` — Proactive detection configurations: RuleDefinitions (name, enabled, email settings). Excel: "App Insights Proactive Detection"
- `AppInsightsContinuousExport.ps1` — Continuous export configurations: ExportId, DestinationStorageId, IsEnabled, RecordTypes. Excel: "App Insights Continuous Export"
- `AppInsightsWorkItems.ps1` — Work item configurations via `microsoft.insights/workitemconfigs`: ConnectorId (Azure DevOps, GitHub), IsValidated. Excel: "App Insights Work Items"

**Metrics & Ingestion — 1 new module** (`Modules/Public/InventoryModules/Monitor/`):
- `MonitorMetricsIngestion.ps1` — Log Analytics workspace ingestion statistics: WorkspaceName, DailyIngestionGB, MonthlyIngestionGB, RetentionDays, CapGB (daily cap). Excel: "Metrics Ingestion Stats"

#### Phase 16 — Arc Enhanced Configuration Coverage

**New Hybrid modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcSiteConfigurations.ps1` — Arc Site Manager configurations via `microsoft.hybridcompute/sites`: SiteName, ResourceGroup, Location, ConnectedMachines count, Kubernetes clusters count, governance policy count, update schedule configuration. Excel: "Arc Site Configurations"
- `ArcEnabledSQLServer.ps1` — Arc-enabled SQL Server instances via `microsoft.azurearcdata/sqlServerInstances`: ServerName, ArcServerResourceId, SQLVersion, Edition, LicenseType, Cores, MemoryMB, Databases count, ESU (enabled/disabled). Excel: "Arc-Enabled SQL Server"
- `ArcDataServices.ps1` — Arc Data Controllers and SQL Managed Instances via `microsoft.azurearcdata/dataControllers`: DataControllerName, K8sNamespace, InfrastructureType (direct/indirect), K8sDistribution, SQLManagedInstances count, PostgreSQL count, DataUploadState. Excel: "Arc Data Services"

**Enhanced existing modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcExtensions.ps1` — Enhanced with deep configuration data: extension settings (parsed JSON), version, auto-upgrade settings, protected settings indicator (yes/no — never actual values), provisioning state, error messages
- `ArcResourceBridge.ps1` — Enhanced with detailed configurations: management IP, subnet, connected cluster details, custom locations linked, provider configurations (VMware, SCVMM, Azure Local)

#### Phase 10 — Excel Specialized Tabs

**New Excel worksheets — all read from `{ReportCache}/{Category}.json` cache files:**
- **`Build-AZSCCostManagementReport.ps1`** — "Cost Management" worksheet: VM cost estimates from `Compute.json`, Arc Server ESU/cost estimates from `Hybrid.json`, reservation recommendations from `Management.json`
- **`Build-AZSCSecurityOverviewReport.ps1`** — "Security Overview" worksheet: Defender for Cloud secure score, high/critical assessments, active alerts, and Defender plan pricing (reads `Security.json`)
- **`Build-AZSCUpdateManagerReport.ps1`** — "Azure Update Manager" worksheet: VMs and Arc servers with patch compliance, NonCompliant rows highlighted yellow
- **`Build-AZSCMonitorReport.ps1`** — "Azure Monitor" worksheet: Action groups, DCRs, DCEs, App Insights, alert rules, autoscale settings — rendered as sequential table sections from `Monitor.json`
- **`Start-AZSCExtraReports.ps1`** — Updated: added `$ReportCache` parameter; calls all four Phase 10 builders after existing quota/policy/advisory reports
- **`Start-AZSCReporOrchestration.ps1`** — Updated: passes `-ReportCache $ReportCache` to `Start-AZSCExtraReports`
- **`Start-AZSCExcelCustomization.ps1`** — Updated: Phase 10 tab names (`Cost Management`, `Security Overview`, `Azure Update Manager`, `Azure Monitor`) excluded from Overview tab row count and resource size sort
- **`Build-AZSCExcelChart.ps1`** — Updated (10.1.2): P00 Overview chart no longer shows "Reservation Advisor" pivot when a "Cost Management" tab exists; reservation data is now exclusively in the dedicated tab. Falls through to the resources area chart instead

#### Phase 18 — Category Metadata Auto-Discovery (18.4.1)

- **`Start-AZSCProcessJob.ps1`** — Enhanced module auto-discovery to parse `.CATEGORY` comment headers from individual `.ps1` files:
  - Builds per-file `ModuleInfoList` objects with `Name`, `FolderCategory`, `FileCategory`, and `Categories` properties
  - When category filtering is active, applies a second per-file filter pass using the `.CATEGORY` header to support cross-category modules that live in one folder but logically belong to another
  - Files with no `.CATEGORY` header fall back to their folder name (backward compatible)
  - Logs filtered file names via `Write-Debug` for traceability

#### Phase 19 — Polish & Documentation

- Updated `README.md` with ARM-only default documentation, expanded permission tables (ARM + Graph), resource provider requirements, and troubleshooting guide
- Added Markdown and AsciiDoc to output file table in README

#### Phase 14 — AI Category Expansion

- **`MLPipelines.ps1`** (`Modules/Public/InventoryModules/AI/`) — Pipeline job inventory via ML REST API (`workspaces/{name}/jobs?$filter=jobType eq 'Pipeline'`): workspace name, pipeline name, pipeline ID, status, created/modified time, experiment name, compute ID. Excel sheet: "ML Pipelines"

#### Phase 15 — Compute Category Expansion

- **`AVDAzureLocal.ps1`** (`Modules/Public/InventoryModules/Compute/`) — AVD session hosts running on Azure Local (HCI) and Arc-enabled infrastructure. Discovers Arc machines and HCI VM instances tagged `AvdSessionHost=true`, plus registered AVD session hosts whose resource IDs reference Arc/HCI VMs. Fields: Platform, Host Pool, Status, Agent Version, Last Heartbeat, Azure Local Cluster, Sessions. Excel sheet: "AVD on Azure Local/Arc"

#### Phase 17 — Resource Enrichment

**Virtual Machine enhancements** (`VirtualMachine.ps1`):
- Azure Monitor Metrics integration: CPU percentage (7-day average) and memory percentage via `/providers/microsoft.insights/metrics?metricnames=Percentage+CPU`
- Azure Site Recovery integration: DR replication status, target region, replication health via Recovery Vault `/replicationProtectedItems` API
- Cost Management integration: Estimated monthly cost (USD) via `Microsoft.CostManagement/query` API
- New Excel columns: `Avg CPU % (7d)`, `Avg Memory % (7d)`, `DR Replicated`, `DR Target Region`, `DR Replication Health`, `Est. Monthly Cost (USD)`

**Arc Server enhancements** (`ARCServers.ps1`):
- PolicyInsights API: Policy assignment count and compliance state (Compliant/NonCompliant)
- Azure Monitor Metrics: CPU usage active percentage (7-day average) for Arc agents
- Cost Management API: ESU enablement status and estimated monthly cost
- Hybrid connectivity: Proxy configuration status and private link scope association
- New Excel columns: `ESU Enabled`, `Est. Monthly Cost (USD)`, `Policy Assignments`, `Policy Compliance`, `Avg CPU % (7d)`, `Proxy Configured`, `Private Link Scope`

#### Phase 18 — Category Structure Alignment

- Category alias normalization added to `Invoke-AzureScout.ps1`: long-form Azure portal names (e.g., `AI + machine learning`, `Internet of Things`, `Management and governance`) automatically mapped to short folder names
- Updated `.vscode/settings.json` with PowerShell extension settings, formatting rules, file associations, and Pester test path configuration
- Created `docs/azure-category-structure.md` — category-to-folder mapping reference with alias table and instructions for adding new categories
- Created `docs/azure-coverage-table.md` — comprehensive inventory coverage table (171 modules across 15 categories)
- Created `docs/modules/ROOT/pages/category-filtering.adoc` — Antora AsciiDoc guide for category filtering with examples, alias support, and execution flow diagram
- Updated `docs/modules/ROOT/nav.adoc` — added Category Filtering to navigation

#### Phase 20 — Help & Examples

- Added 4 `.EXAMPLE` blocks to `Invoke-AzureScout`:
  - `-PermissionAudit` basic usage
  - `-PermissionAudit -OutputFormat Markdown`
  - `-PermissionAudit -Scope All` (ARM + Graph)
  - Full inventory with `-PermissionAudit -Scope All -OutputFormat All`
- **`Test-AZSCPermissions.ps1`** refactored (20.4.1): Now delegates to `Invoke-AZSCPermissionAudit` instead of containing duplicate permission-check logic. Maps the richer audit result back to the simplified `{ArmAccess, GraphAccess, Details}` shape that existing callers expect. Backward compatible — same parameter surface, same return properties

#### Phase 21 — Markdown & AsciiDoc Report Output

- **`Export-AZSCMarkdownReport.ps1`** (`Modules/Private/Reporting/`) — New function generating GitHub-Flavored Markdown reports from cache files. Reads `{CategoryFolder}.json` cache files, renders per-module pipe tables, generates anchored ToC, writes `{ReportName}.md`. Parameters: `ReportCache`, `File`, `TenantID`, `Subscriptions`, `Scope`
- **`Export-AZSCAsciiDocReport.ps1`** (`Modules/Private/Reporting/`) — New function generating AsciiDoc reports from cache files. Same cache-reading pattern as Markdown export, outputs AsciiDoc tables with `:toc: left`, `[TIP]` admonitions per module, writes `{ReportName}.adoc`. Compatible with Antora and Confluence
- **`-OutputFormat Markdown` / `-OutputFormat AsciiDoc`** wired into `Invoke-AzureScout.ps1` — parallel to JSON export block in the reporting phase
- Added `MD` and `Adoc` as `[ValidateSet]` aliases for `Markdown` and `AsciiDoc` respectively
- Updated `-OutputFormat` description in `README.md` to include Markdown and AsciiDoc values with aliases
- Updated output files table in `README.md` to include `.md` and `.adoc` entries
- **21.5.1/21.5.2 — PermissionAudit format support**: `-PermissionAudit -OutputFormat Markdown` now saves a permission audit `.md` report; `-PermissionAudit -OutputFormat AsciiDoc` saves a permission audit `.adoc` report with AsciiDoc role icons and `[source,powershell]` recommendation blocks
- **`Invoke-AZSCPermissionAudit.ps1`** — Added `AsciiDoc` to `[ValidateSet]` for `-OutputFormat`; new AsciiDoc output block with `:toc: left`, `icon:check-circle[]`/`icon:times-circle[]` status icons, and `[source,powershell]` blocks for each recommendation
- **`Invoke-AzureScout.ps1`** — Updated `auditOutputFormat` switch: `MD` → `Markdown`, `AsciiDoc` → `AsciiDoc`, `Adoc` → `AsciiDoc`, `All` → `All` (previously `All` mapped to `Console`)

#### Dependency Bootstrap

- Removed `RequiredModules` hard requirement from `AzureScout.psd1` (changed to `@()`)
- Added auto-install bootstrap to `AzureScout.psm1`: automatically installs and imports `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`, `Az.Compute`, `Az.Authorization`, `Az.Resources` if not already available

---

**Version Control**
- Created: 2026-02-22 by Kristopher Turner
- Last Edited: 2026-07-23 by Kristopher Turner
- Version: 2.0.0
- Tags: changelog, AzureScout, assessment, CAF, WAF, landing-zone, openxml, pptx, ingest, runtime-verification
