# Azure Tenant Inventory Tool — TODO Tracker

> Track implementation progress. Update status as work is completed.
> See [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) for full details on each item.

## Status Legend

| Symbol | Meaning |
|--------|---------|
| `[ ]`  | Not started |
| `[~]`  | In progress |
| `[x]`  | Completed |

---

## Pre-Implementation

- [x] Clone ARI v3.6.11 as base
- [x] Import to `thisismydemo/azure-inventory` repo
- [x] Create implementation plan (`docs/IMPLEMENTATION-PLAN.md`)
- [x] Create TODO tracker (`TODO.md`)

---

## Phase 0 — Repository Scaffold & Rename

- [x] **0.1** Rename `AzureResourceInventory.psd1` → `AzureTenantInventory.psd1`
- [x] **0.2** Rename `AzureResourceInventory.psm1` → `AzureTenantInventory.psm1`
- [x] **0.3** Update manifest: version `1.0.0`, new GUID, new author, new exports
- [x] **0.4** Update PSM1 loader (reference new filename)
- [x] **0.5** Create `LICENSE` (MIT)
- [x] **0.6** Create proper `.gitignore`
- [x] **0.7** Create `CHANGELOG.md`
- [x] **0.8** Delete `Modules/Private/4.RAMPFunctions/` (entire directory)
- [x] **0.9** Remove `Invoke-AzureRAMPInventory` from manifest and public functions
- [x] **0.10** Remove auto-update logic from entry point
- [x] **0.11** Remove `Remove-ARIExcelProcess` function
- [x] **0.12** Commit Phase 0

---

## Phase 1 — Global Rename (ARI → AZTI)

- [x] **1.1** Rename all `*-ARI*` functions to `*-AZTI*` (~40 functions) — commit `e91eaea`
- [x] **1.2** Rename entry point: `Invoke-ARI.ps1` → `Invoke-AzureTenantInventory.ps1` — commit `e91eaea`
- [x] **1.3** Update all string/log references from `ARI` to `AZTI`/`AzureTenantInventory` — commits `e91eaea`, `88592ec`
- [x] **1.4** Update default paths: `AzureResourceInventory` → `AzureTenantInventory` — commit `e91eaea`
- [x] **1.5** Update all internal function call sites — commit `e91eaea`
- [x] **1.6** Update manifest `FunctionsToExport` with new names — commit `e91eaea`
- [x] **1.7** Verify module loads: `Import-Module ./AzureTenantInventory.psd1` — 13 public functions confirmed
- [x] **1.8** Rename .ps2 files (legacy functions) — commit `cfac9a9`
- [x] **1.9** Update all non-PowerShell files (docs, YAML, shell scripts, templates) — commit `88592ec`
- [x] **1.10** Rename ARI-named files (images, pipelines YAML) — commit `88592ec`
- [x] **1.11** Commit & push Phase 1 — commits `e91eaea`, `cfac9a9`, `88592ec`

---

## Phase 1B — Repository Structure Review & Reorganization

All decisions finalized. See [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) Phase 1B.2 for decision table and rationale.

- [x] **1B.1** Verify `4.RAMPFunctions/` deletion (Phase 0 cleanup — delete if still present) — deleted from disk (was untracked .xlsx)
- [x] **1B.2** Drop numbered prefixes: `0.MainFunctions/` → `Main/`, `1.ExtractionFunctions/` → `Extraction/`, `2.ProcessingFunctions/` → `Processing/`, `3.ReportingFunctions/` → `Reporting/` — commit `2e8b57e`
- [x] **1B.3** Merge `Network_1/` + `Network_2/` → `Network/` (20 files) — commit `2e8b57e`
- [x] **1B.4** Keep `Hybrid/` as-is (Arc modules land here in Phase 8.2) — confirmed, no action needed
- [x] **1B.5** Delete `azure-pipelines/` directory — commit `2e8b57e`
- [x] **1B.6** Gut `docs/` — delete inherited MkDocs content, set up Antora directory structure — commit `2e8b57e`
- [x] **1B.7** Consolidate `images/` into `docs/modules/ROOT/images/` (32 images) — commit `2e8b57e`
- [x] **1B.8** Delete `LegacyFunctions/` (6 unused `.ps2` files) — commit `2e8b57e`
- [x] **1B.9** Clean root clutter (`HowTo.md`, 5 `test-*.sh` scripts, `workflow_dispatch.json`) — commit `2e8b57e`
- [x] **1B.10** Create `docs/antora.yml` and root `antora-playbook.yml` — commit `2e8b57e`
- [x] **1B.11** Validate module load — 13 public functions confirmed, zero breakage
- [x] **1B.12** Create `docs/modules/ROOT/pages/folder-structure.adoc` documenting decisions — commit `2e8b57e`
- [x] **1B.13** Commit & push Phase 1B — commit `2e8b57e`

---

## Phase 2 — Auth Refactor

- [x] **2.1** Rewrite `Connect-AZTILoginSession` with 5 auth methods (current-user default)
- [x] **2.2** Create `Get-AZTIGraphToken` (token acquisition via `Get-AzAccessToken -ResourceTypeName MSGraph`)
- [x] **2.3** Create `Invoke-AZTIGraphRequest` (REST wrapper with pagination + throttle handling)
- [x] **2.4** Add `-TenantID`, `-AppId`, `-Secret`, `-CertificatePath`, `-CertificatePassword`, `-DeviceLogin` params to `Invoke-AzureTenantInventory`
- [x] **2.5** Add `-Scope` parameter (`All`, `ArmOnly`, `EntraOnly`) to `Invoke-AzureTenantInventory`
- [x] **2.6** Test: current-user auth (interactive)
- [x] **2.7** Test: SPN + secret auth
- [x] **2.8** Commit Phase 2

---

## Phase 3 — Pre-Flight Permission Checker

- [x] **3.1** Create `Test-AZTIPermissions` public function
- [x] **3.2** Implement ARM permission checks (subscription enumeration, role assignment)
- [x] **3.3** Implement Graph permission checks (organization, users, CA policies)
- [x] **3.4** Create structured result object with remediation guidance
- [x] **3.5** Integrate into `Invoke-AzureTenantInventory` (auto-run, warn-only)
- [x] **3.6** Add `-SkipPermissionCheck` switch
- [x] **3.7** Commit Phase 3

---

## Phase 4 — Entra ID Extraction Layer

- [x] **4.1** Create `Start-AZTIEntraExtraction` function
- [x] **4.2** Implement Graph queries for all 15 Entra resource types
- [x] **4.3** Normalize responses with synthetic `TYPE` property (`entra/*`)
- [x] **4.4** Update `Start-AZTIExtractionOrchestration` to call Entra extraction
- [x] **4.5** Merge Entra resources into main `$Resources` array
- [x] **4.6** Wire `-Scope` parameter through extraction pipeline
- [x] **4.7** Test: Entra extraction standalone
- [x] **4.8** Commit Phase 4

---

## Phase 5 — Entra ID Inventory Modules (15 new)

- [x] **5.1** Create `Modules/Public/InventoryModules/Identity/` directory
- [x] **5.2** `Users.ps1` — User inventory module
- [x] **5.3** `Groups.ps1` — Group inventory module
- [x] **5.4** `AppRegistrations.ps1` — App registrations module
- [x] **5.5** `ServicePrincipals.ps1` — Service principals module
- [x] **5.6** `ManagedIdentities.ps1` — Managed identities module
- [x] **5.7** `DirectoryRoles.ps1` — Directory roles module
- [x] **5.8** `PIMAssignments.ps1` — PIM assignments module
- [x] **5.9** `ConditionalAccess.ps1` — Conditional Access policies module
- [x] **5.10** `NamedLocations.ps1` — Named locations module
- [x] **5.11** `AdminUnits.ps1` — Admin units module
- [x] **5.12** `Domains.ps1` — Domains module
- [x] **5.13** `Licensing.ps1` — License/SKU inventory module
- [x] **5.14** `CrossTenantAccess.ps1` — Cross-tenant access settings module
- [x] **5.15** `SecurityPolicies.ps1` — Security defaults + auth policy module
- [x] **5.16** `RiskyUsers.ps1` — Risky users module
- [x] **5.17** Register Identity modules in processing/reporting pipeline *(auto-discovered — no changes needed)*
- [ ] **5.18** Test: Full run with Entra modules producing Excel worksheets
- [x] **5.19** Commit Phase 5

---

## Phase 6 — JSON Output Layer

- [x] **6.1** Create `Export-AZTIJsonReport` function
- [x] **6.2** Implement structured JSON schema with metadata envelope
- [x] **6.3** Add `-OutputFormat` parameter (`All`, `Excel`, `Json`) to `Invoke-AzureTenantInventory`
- [x] **6.4** Wire into `Start-AZTIReportOrchestration`
- [ ] **6.5** Test: JSON-only output
- [ ] **6.6** Test: Dual output (Excel + JSON)
- [ ] **6.7** Commit Phase 6

---

## Phase 7 — Cleanup & Polish

- [x] **7.1** Update default report paths (Windows + Linux/Mac)
- [x] **7.2** Rewrite `README.md` with full documentation
- [x] **7.3** Create Pester tests: `Test-AZTIPermissions.Tests.ps1`
- [x] **7.4** Create Pester tests: `Invoke-AzureTenantInventory.Tests.ps1`
- [x] **7.5** Create Pester tests: `Connect-AZTILoginSession.Tests.ps1`
- [x] **7.6** Create Pester tests: `Invoke-AZTIGraphRequest.Tests.ps1`
- [x] **7.7** Create Pester tests: `Start-AZTIEntraExtraction.Tests.ps1`
- [x] **7.8** Update `CHANGELOG.md` with all changes
- [x] **7.9** Final module load + smoke test
- [x] **7.10** Commit Phase 7
- [x] **7.11** Set up Antora documentation site (write AsciiDoc content, create nav.adoc, GitHub Actions workflow)

---

## Phase 8 — Inventory Module Expansion (ARM)

### 8.1 — Azure Local (Stack HCI) Modules

- [x] **8.1.1** Create `Modules/Public/InventoryModules/AzureLocal/` directory
- [x] **8.1.2** `Clusters.ps1` — Azure Local cluster inventory (`microsoft.azurestackhci/clusters`)
- [x] **8.1.3** `VirtualMachines.ps1` — Azure Local VM instances (`microsoft.azurestackhci/virtualmachineinstances`)
- [x] **8.1.4** `LogicalNetworks.ps1` — Azure Local logical networks (`microsoft.azurestackhci/logicalnetworks`)
- [x] **8.1.5** `StorageContainers.ps1` — Azure Local storage containers (`microsoft.azurestackhci/storagecontainers`)
- [x] **8.1.6** `GalleryImages.ps1` — Azure Local gallery images (`microsoft.azurestackhci/galleryimages`)
- [x] **8.1.7** `MarketplaceGalleryImages.ps1` — Azure Local marketplace images (`microsoft.azurestackhci/marketplacegalleryimages`)
- [ ] **8.1.8** Test: Verify Azure Local modules produce populated Excel worksheets against a test environment

### 8.2 — Azure Arc Expanded Coverage

- [x] **8.2.1** `Hybrid/ArcGateways.ps1` — Arc Gateway inventory (`microsoft.hybridcompute/gateways`)
- [x] **8.2.2** `Hybrid/ArcKubernetes.ps1` — Arc-enabled Kubernetes clusters (`microsoft.kubernetes/connectedclusters`)
- [x] **8.2.3** `Hybrid/ArcResourceBridge.ps1` — Arc resource bridge/appliances (`microsoft.resourceconnector/appliances`)
- [x] **8.2.4** `Hybrid/ArcExtensions.ps1` — Arc machine extensions (`microsoft.hybridcompute/machines/extensions`)
- [ ] **8.2.5** Test: Verify Arc modules produce populated Excel worksheets against a test environment

### 8.3 — Enhanced VPN & Networking Detail

- [x] **8.3.1** Enhance `VirtualNetworkGateways.ps1` — Add P2S configuration fields (address pool, client protocols, auth type, root/revoked cert counts, RADIUS server, AAD tenant)
- [x] **8.3.2** Enhance `VirtualNetworkGateways.ps1` — Add custom DNS servers, NAT rules count, policy group count
- [x] **8.3.3** Enhance `Connections.ps1` — Add IPsec/IKE policy fields (encryption, integrity, DH group, PFS group, SA lifetime, SA data size)
- [x] **8.3.4** Enhance `Connections.ps1` — Add traffic selectors, DPD timeout, use policy-based traffic selectors
- [x] **8.3.5** Enhance `Connections.ps1` — Add ingress/egress bytes, shared key presence (boolean only — never log actual key)
- [ ] **8.3.6** Test: Verify enhanced VPN fields populate correctly for S2S, P2S, and ExpressRoute connections

### 8.4 — Phase 8 Finalize

- [x] **8.4.1** Update `CHANGELOG.md` with Phase 8 additions
- [ ] **8.4.2** Commit & push Phase 8

---

## Post-Implementation

- [ ] Push to GitHub (`thisismydemo/azure-inventory`)
- [ ] Tag release `v1.0.0`
- [ ] Publish to PSGallery
- [ ] Update prodtechlabmgmt references to point to new repo

---

**Version Control**
- Created: 2026-02-22 by Product Technology Team
- Last Edited: 2026-02-23 by Product Technology Team
- Version: 1.6.0
- Tags: todo, tracking, implementation, azure-local, arc-gateway, vpn, folder-structure, antora, asciidoc, json-output, pester, credits, cleanup
- Keywords: azure-inventory, progress, checklist, hci, arc, vpn, reorganization, antora, json, pester, documentation
- Author: Product Technology Team
