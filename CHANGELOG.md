# Changelog

All notable changes to the AzureTenantInventory module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial fork from [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11
- Renamed module to `AzureTenantInventory` (prefix `AZTI`)
- New module manifest with fresh GUID, v1.0.0
- Repository scaffolding (CHANGELOG, README, tests/)

#### Phase 7 — Cleanup & Polish

**Documentation**
- Rewrote `README.md` — comprehensive parameter reference table, 17-category module catalog (95 ARM + 15 Entra = 110 total), 5 authentication methods, `-Scope`/`-OutputFormat` quick start, JSON output structure
- Created `CREDITS.md` — attribution to original ARI project (Claudio Merola, RenatoGregio, Doug Finke/ImportExcel), MIT license notes
- Updated `Set-AZTIReportPath.ps1` comment-based help (Synopsis, Description, Link, Version, Authors)

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
- `Test-AZTIPermissions.Tests.ps1` — return structure, ARM/Graph pass/fail/warn, scope gating, never-throws guarantee
- `Invoke-AzureTenantInventory.Tests.ps1` — ValidateSet enforcement, parameter aliases, switch params
- `Connect-AZTILoginSession.Tests.ps1` — 4 auth paths (SPN+cert, SPN+secret, device-code, current-user), TenantID enforcement, LoginExperienceV2
- `Invoke-AZTIGraphRequest.Tests.ps1` — URI normalization, pagination, SinglePage switch, retry 429/5xx, max retries
- `Start-AZTIEntraExtraction.Tests.ps1` — return structure, normalized shape, all 15 queries, graceful degradation

#### Phase 6 — JSON Output Layer

- **`Export-AZTIJsonReport.ps1`** — New function at `Modules/Private/Reporting/Export-AZTIJsonReport.ps1`
  - Reads all `{FolderName}.json` cache files produced by the processing phase
  - Assembles a structured JSON document with `_metadata` envelope (tool, version, tenantId, subscriptions, generatedAt, scope)
  - ARM inventory data organized under `arm` key by module folder (compute, network, storage, etc.)
  - Entra/Identity data organized under `entra` key (users, groups, appRegistrations, etc.)
  - Extra reports (advisory, policy, security, quotas) included as top-level keys when available
  - Outputs to `{ReportDir}/{ReportName}_Report_{timestamp}.json` alongside the Excel file
- **`-OutputFormat` parameter** added to `Invoke-AzureTenantInventory`
  - `All` (default): Generate both Excel (.xlsx) and JSON (.json) reports
  - `Excel`: Generate Excel report only, skip JSON export
  - `Json`: Generate JSON report only, skip Excel generation
- Conditional logic wraps Excel reporting (`Start-AZTIReporOrchestration`, `Start-AZTIExcelCustomization`) to skip when `OutputFormat = 'Json'`
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
- `Start-AZTIEntraExtraction.ps1` — Added 2 new Graph API queries: `/v1.0/identity/identityProviders` (array), `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy` (SingleObject)

### Changed

#### Phase 8 — Enhanced VPN & Networking Detail

- `VirtualNetworkGateways.ps1` — Added 10 new fields: P2S address pool, VPN client protocols, auth type, root/revoked cert counts, RADIUS server, AAD tenant, custom DNS servers, NAT rules count, policy group count
- `Connections.ps1` — Added 13 new fields: IPsec/IKE encryption & integrity, DH group, PFS group, SA lifetime/data size, policy-based traffic selectors, traffic selectors, DPD timeout, ingress/egress bytes, shared key presence (boolean only)

### Removed

- RAMP functions (`Modules/Private/4.RAMPFunctions/`)
- `Invoke-AzureRAMPInventory` public function
- Auto-update logic (`Update-Module` call)
- `Remove-ARIExcelProcess` (aggressive Excel process killer)

### Changed

- All exported function names: `*-ARI*` → `*-AZTI*`
- Module metadata (author, description, project URI, tags)
- LICENSE updated with dual copyright (original + fork)

---

**Version Control**
- Created: 2026-02-22 by thisismydemo
- Last Edited: 2026-02-23 by thisismydemo
- Version: 1.6.0
- Tags: changelog, azuretenantinventory, json-output, phase-7, antora, pester
