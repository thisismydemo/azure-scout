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
