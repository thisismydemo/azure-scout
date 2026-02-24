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
- [x] Import to `thisismydemo/azure-scout` repo
- [x] Create implementation plan (`docs/IMPLEMENTATION-PLAN.md`)
- [x] Create TODO tracker (`TODO.md`)

---

## Phase 0 — Repository Scaffold & Rename

- [x] **0.1** Rename `AzureResourceInventory.psd1` → `AzureScout.psd1`
- [x] **0.2** Rename `AzureResourceInventory.psm1` → `AzureScout.psm1`
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

## Phase 1 — Global Rename (ARI → AZSC)

- [x] **1.1** Rename all `*-ARI*` functions to `*-AZSC*` (~40 functions) — commit `e91eaea`
- [x] **1.2** Rename entry point: `Invoke-ARI.ps1` → `Invoke-AzureScout.ps1` — commit `e91eaea`
- [x] **1.3** Update all string/log references from `ARI` to `AZSC`/`AzureScout` — commits `e91eaea`, `88592ec`
- [x] **1.4** Update default paths: `AzureResourceInventory` → `AzureScout` — commit `e91eaea`
- [x] **1.5** Update all internal function call sites — commit `e91eaea`
- [x] **1.6** Update manifest `FunctionsToExport` with new names — commit `e91eaea`
- [x] **1.7** Verify module loads: `Import-Module ./AzureScout.psd1` — 13 public functions confirmed
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

- [x] **2.1** Rewrite `Connect-AZSCLoginSession` with 5 auth methods (current-user default)
- [x] **2.2** Create `Get-AZSCGraphToken` (token acquisition via `Get-AzAccessToken -ResourceTypeName MSGraph`)
- [x] **2.3** Create `Invoke-AZSCGraphRequest` (REST wrapper with pagination + throttle handling)
- [x] **2.4** Add `-TenantID`, `-AppId`, `-Secret`, `-CertificatePath`, `-CertificatePassword`, `-DeviceLogin` params to `Invoke-AzureScout`
- [x] **2.5** Add `-Scope` parameter (`All`, `ArmOnly`, `EntraOnly`) to `Invoke-AzureScout`
- [x] **2.6** Test: current-user auth (interactive)
- [x] **2.7** Test: SPN + secret auth
- [x] **2.8** Commit Phase 2

---

## Phase 3 — Pre-Flight Permission Checker

- [x] **3.1** Create `Test-AZSCPermissions` public function
- [x] **3.2** Implement ARM permission checks (subscription enumeration, role assignment)
- [x] **3.3** Implement Graph permission checks (organization, users, CA policies)
- [x] **3.4** Create structured result object with remediation guidance
- [x] **3.5** Integrate into `Invoke-AzureScout` (auto-run, warn-only)
- [x] **3.6** Add `-SkipPermissionCheck` switch
- [x] **3.7** Commit Phase 3

---

## Phase 4 — Entra ID Extraction Layer

- [x] **4.1** Create `Start-AZSCEntraExtraction` function
- [x] **4.2** Implement Graph queries for all 15 Entra resource types
- [x] **4.3** Normalize responses with synthetic `TYPE` property (`entra/*`)
- [x] **4.4** Update `Start-AZSCExtractionOrchestration` to call Entra extraction
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

- [x] **6.1** Create `Export-AZSCJsonReport` function
- [x] **6.2** Implement structured JSON schema with metadata envelope
- [x] **6.3** Add `-OutputFormat` parameter (`All`, `Excel`, `Json`) to `Invoke-AzureScout`
- [x] **6.4** Wire into `Start-AZSCReportOrchestration`
- [ ] **6.5** Test: JSON-only output
- [ ] **6.6** Test: Dual output (Excel + JSON)
- [x] **6.7** Commit Phase 6 — included in commit `2650e32`

---

## Phase 7 — Cleanup & Polish

- [x] **7.1** Update default report paths (Windows + Linux/Mac)
- [x] **7.2** Rewrite `README.md` with full documentation
- [x] **7.3** Create Pester tests: `Test-AZSCPermissions.Tests.ps1`
- [x] **7.4** Create Pester tests: `Invoke-AzureScout.Tests.ps1`
- [x] **7.5** Create Pester tests: `Connect-AZSCLoginSession.Tests.ps1`
- [x] **7.6** Create Pester tests: `Invoke-AZSCGraphRequest.Tests.ps1`
- [x] **7.7** Create Pester tests: `Start-AZSCEntraExtraction.Tests.ps1`
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
- [x] **8.4.2** Commit & push Phase 8 — included in commit `2650e32`

---

## Phase 9 — Missing ARM Resource Types (Feature Parity)

> Identified gaps from Invoke-TenantDiscovery.ps1 comparison analysis.

### 9.1 — Azure Policy & Governance

- [x] **9.1.1** `Management/ManagementGroups.ps1` — Management groups with Expand + Recurse
- [x] **9.1.2** `Management/CustomRoleDefinitions.ps1` — Custom RBAC role definitions
- [x] **9.1.3** `Management/PolicyDefinitions.ps1` — Custom policy definitions
- [x] **9.1.4** `Management/PolicySetDefinitions.ps1` — Custom policy initiatives
- [x] **9.1.5** `Management/PolicyComplianceStates.ps1` — Policy compliance states (per assignment)
- [x] **9.1.6** Fix `Management/MaintenanceConfigurations.ps1` — **CRITICAL**: Rewrite with dual-Task pattern (Processing + Reporting blocks)

### 9.2 — Microsoft Defender for Cloud

- [x] **9.2.1** `Security/DefenderAssessments.ps1` — Security assessments
- [x] **9.2.2** `Security/DefenderSecureScore.ps1` — Secure score
- [x] **9.2.3** `Security/DefenderAlerts.ps1` — Security alerts
- [x] **9.2.4** `Security/DefenderPricing.ps1` — Defender pricing plans (which plans are enabled)

### 9.3 — Azure Monitor Resources

- [x] **9.3.1** `Monitoring/ActionGroups.ps1` — Action groups
- [x] **9.3.2** `Monitoring/MetricAlertRules.ps1` — Metric alert rules
- [x] **9.3.3** `Monitoring/ScheduledQueryRules.ps1` — Scheduled query rules (log alerts)
- [x] **9.3.4** `Monitoring/DataCollectionRules.ps1` — **NEW**: Data collection rules (telemetry collection, AMA configs)
- [x] **9.3.5** `Monitoring/DataCollectionEndpoints.ps1` — **NEW**: Data collection endpoints
- [x] **9.3.6** `Monitoring/SubscriptionDiagnosticSettings.ps1` — Subscription-level diagnostic settings

### 9.4 — Networking & Managed Services

- [x] **9.4.1** `Network/NetworkWatchers.ps1` — Network watchers
- [x] **9.4.2** `Management/LighthouseDelegations.ps1` — Azure Lighthouse delegations

### 9.5 — Entra ID Verification (Optional)

> Verify these exist in existing modules or add them.

- [x] **9.5.1** Added `Identity/IdentityProviders.ps1` — Identity Providers (federated/social/OIDC) via `/v1.0/identity/identityProviders`
- [x] **9.5.2** Verified `Identity/SecurityPolicies.ps1` includes **Authorization Policy** via `/v1.0/policies/authorizationPolicy`
- [x] **9.5.3** Added `Identity/SecurityDefaults.ps1` — Security Defaults Policy via `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy`

### 9.6 — Phase 9 Polish

- [x] **9.6.1** Testing SKIPPED per directive — defer to end
- [x] **9.6.2** Testing SKIPPED per directive — defer to end
- [x] **9.6.3** Update `CHANGELOG.md` with Phase 9 additions
- [x] **9.6.4** Commit & push Phase 9 — Ready

---

## Phase 10 — Excel Report Restructuring

> Redesign Overview tab and create specialized tabs for better organization.

### 10.1 — Overview Tab Restructuring

- [x] **10.1.1** Scale down Overview tab to **important Azure tenant information only**
  - Tenant name, ID, domain
  - Total subscriptions, management groups
  - Total resource groups, resources
  - Authentication summary (user/SPN used)
  - Scan timestamp, duration
- [x] **10.1.2** Remove cost/reservation content from Overview (move to Cost Management tab)
- [x] **10.1.3** Remove security content from Overview (move to Security Overview tab)
- [x] **10.1.4** Remove monitoring/alerting content from Overview (move to Azure Monitor tab)

### 10.2 — New Tab: Cost Management

- [x] **10.2.1** Create **Cost Management** tab positioned after Overview
- [x] **10.2.2** Move VM reservations from Overview → Cost Management tab
- [x] **10.2.3** Add cost analysis graphs
- [x] **10.2.4** Add reservation recommendations
- [x] **10.2.5** Add advisor cost recommendations

### 10.3 — New Tab: Security Overview

- [x] **10.3.1** Create **Security Overview** tab
- [x] **10.3.2** Add Defender secure score graphs
- [x] **10.3.3** Add security assessment summary
- [x] **10.3.4** Add Advisor security recommendations
- [x] **10.3.5** Add compliance state summary
- [x] **10.3.6** Add critical security alerts count

### 10.4 — New Tab: Azure Update Manager Overview

- [x] **10.4.1** Create **Azure Update Manager** tab
- [x] **10.4.2** List all Azure VMs with:
  - VM name, resource group, subscription
  - OS type, OS version
  - Maintenance schedule assigned (if any)
  - Patch status (compliant/non-compliant)
  - Last patch installation date
  - Pending patches count
- [x] **10.4.3** List all Azure Arc VMs with same fields as Azure VMs
- [x] **10.4.4** Add summary graphs:
  - VMs by maintenance schedule assignment
  - VMs by patch compliance status
  - VMs by OS type
  - Pending patches distribution

### 10.5 — New Tab: Azure Monitor

- [x] **10.5.1** Create **Azure Monitor** tab
- [x] **10.5.2** Add action groups summary
- [x] **10.5.3** Add alert rules summary (metric + log)
- [x] **10.5.4** Add data collection rules summary
- [x] **10.5.5** Add Log Analytics workspace summary
- [x] **10.5.6** Add diagnostic settings coverage graphs
- [x] **10.5.7** Add Application Insights summary

### 10.6 — Phase 10 Testing

- [ ] **10.6.1** Test: Overview tab contains only tenant-level summary
- [ ] **10.6.2** Test: Cost Management tab displays correctly
- [ ] **10.6.3** Test: Security Overview tab displays correctly
- [ ] **10.6.4** Test: Azure Update Manager tab displays correctly
- [ ] **10.6.5** Test: Azure Monitor tab displays correctly
- [x] **10.6.6** Update `CHANGELOG.md` with Phase 10 additions
- [ ] **10.6.7** Commit & push Phase 10

---

## Phase 11 — Comprehensive Subscription & Management Group Logging

> **CRITICAL FIX**: Currently only logging subscriptions/management groups that have resources. Need to log ALL tenant subscriptions and management groups.

### 11.1 — Subscription Logging Enhancement

- [x] **11.1.1** Update extraction layer to capture **ALL subscriptions** in tenant (not just ones with resources)
- [x] **11.1.2** Create subscription properties object for ALL subscriptions:
  - Subscription ID, name, state (Enabled/Disabled/Warned)
  - Tenant ID
  - Management group path/hierarchy
  - Tags
  - Resource count (can be zero)
  - Spending limit status
  - Authorization source
- [x] **11.1.3** Add "All Subscriptions" worksheet to Excel report
- [x] **11.1.4** Flag empty subscriptions (0 resources) with conditional formatting

### 11.2 — Management Group Logging Enhancement

- [x] **11.2.1** Capture **ALL management groups** in tenant hierarchy using `Get-AzManagementGroup -Expand -Recurse`
- [x] **11.2.2** Create management group properties object:
  - Management group ID, display name
  - Parent management group ID
  - Children (child management groups + subscriptions)
  - Hierarchy level/depth
  - Policy assignments count
  - Role assignments count
- [x] **11.2.3** Add "Management Groups" worksheet to Excel report
- [x] **11.2.4** Include hierarchy visualization (indentation or tree structure)

### 11.3 — Phase 11 Testing

- [ ] **11.3.1** Test: Excel report lists ALL subscriptions (including empty ones)
- [ ] **11.3.2** Test: Excel report lists ALL management groups with hierarchy
- [ ] **11.3.3** Test: Overview tab shows accurate counts (all subs/MGs, not just ones with resources)
- [x] **11.3.4** Update `CHANGELOG.md` with Phase 11 additions
- [ ] **11.3.5** Commit & push Phase 11

---

## Phase 12 — Scope & Authentication Defaults Update

> Change default behavior: ARM-only discovery, Entra ID optional.

### 12.1 — Default Scope Change

- [x] **12.1.1** Update `Invoke-AzureScout` default `-Scope` parameter from `All` to `ArmOnly`
- [x] **12.1.2** Update help documentation to reflect new default
- [x] **12.1.3** Update `README.md` to clarify ARM-only default behavior
- [x] **12.1.4** Update examples to show explicit `-Scope All` for Entra ID inclusion

### 12.2 — Permission Documentation

- [x] **12.2.1** Document **Entra ID scan permissions** in `README.md`:
  - Microsoft Graph API permissions required
  - Directory.Read.All (minimum)
  - Recommended: Directory.Read.All, User.Read.All, Group.Read.All, Application.Read.All, RoleManagement.Read.Directory, Policy.Read.All
  - For **User** (interactive auth): Requires Global Reader or Directory Readers role
  - For **SPN** (non-interactive): Requires application permissions + admin consent
- [x] **12.2.2** Document **ARM scan permissions** in `README.md`:
  - Reader role at Root Management Group (or subscription level)
  - Security Reader for Defender resources
  - Monitoring Reader for Azure Monitor resources
- [x] **12.2.3** Create troubleshooting section for permission errors

### 12.3 — Resource Provider Registration Documentation

- [x] **12.3.1** Document **required resource providers** in `README.md`:
  - `Microsoft.Security` — Required for Defender for Cloud assessments, alerts, secure score
  - `Microsoft.Insights` — Required for Azure Monitor resources (DCRs, action groups, alerts)
  - `Microsoft.Maintenance` — Required for Azure Update Manager maintenance configurations
  - `Microsoft.RecoveryServices` — Required for backup/recovery resources
  - `Microsoft.HybridCompute` — Required for Arc-enabled servers
  - `Microsoft.Kubernetes` — Required for Arc-enabled Kubernetes
  - `Microsoft.AzureStackHCI` — Required for Azure Local resources
- [x] **12.3.2** Add pre-flight check for resource provider registration status
- [x] **12.3.3** Add warning messages for unregistered providers (with remediation instructions)

### 12.4 — Phase 12 Testing

- [ ] **12.4.1** Test: Default run (no `-Scope` param) performs ARM-only discovery
- [ ] **12.4.2** Test: `-Scope All` explicitly includes Entra ID
- [ ] **12.4.3** Test: Permission pre-flight check warns about missing Graph permissions
- [ ] **12.4.4** Test: Resource provider check warns about unregistered providers
- [x] **12.4.5** Update `CHANGELOG.md` with Phase 12 additions
- [ ] **12.4.6** Commit & push Phase 12

---

## MS Graph Authentication Fix — Documented

> **CRITICAL:** This section documents the fix that enabled successful MS Graph authentication and Entra ID data extraction.

### What Was Broken

- **Problem**: MS Graph connectivity/authentication failing, preventing Entra ID data extraction
- **Symptoms**: `-Scope All` failed to populate Entra ID worksheets (Users, Groups, Apps, etc.)
- **Root Cause**: Legacy authentication method incompatible with modern Azure auth flows

### What Was Fixed (Phase 2 — Auth Refactor)

- [x] **Created `Get-AZSCGraphToken` function** (`Modules/Private/Main/Get-AZSCGraphToken.ps1`):
  - Modern approach: `Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString`
  - Replaced legacy token acquisition method
  - Token caching with auto-refresh (5 min before expiry)
  - Works with all auth methods: current user, SPN, managed identity, device code
  - Throws clear error if Graph access unavailable

- [x] **Created `Invoke-AZSCGraphRequest` function** (`Modules/Private/Main/Invoke-AZSCGraphRequest.ps1`):
  - Centralized Graph API wrapper
  - Automatic pagination (`@odata.nextLink` following)
  - Throttling handling (429 responses with `Retry-After` header)
  - Consistent error handling across all Graph calls

- [x] **Updated all Entra ID modules** (15 modules in `Identity/`):
  - Replaced direct `Invoke-RestMethod` with `Invoke-AZSCGraphRequest`
  - Simplified authentication flow
  - Consistent behavior across all Identity modules

### Testing Evidence

- [x] User successfully executed: `Invoke-AzureScout -Scope All -OutputFormat Excel`
- [x] All Entra ID worksheets populated with data:
  - Entra Users, Entra Groups, App Registrations, Service Principals
  - Managed Identities, Directory Roles, PIM Assignments, Conditional Access
  - Named Locations, Admin Units, Entra Domains, Licensing
  - Cross-Tenant Access, Security Policies, Risky Users
- [x] Graph authentication works with current-user interactive auth
- [x] No Graph connection errors or token expiration issues

### Files Modified (Phase 2)

- **New**: `Modules/Private/Main/Get-AZSCGraphToken.ps1`
- **New**: `Modules/Private/Main/Invoke-AZSCGraphRequest.ps1`
- **Modified**: `Modules/Private/Main/Connect-AZSCLoginSession.ps1` (5 auth methods)
- **Modified**: `Modules/Private/Extraction/Start-AZSCEntraExtraction.ps1` (Graph integration)
- **Modified**: All 15 Identity modules (replaced direct REST with wrapper)

### Impact

✅ **Entra ID modules fully functional**
- Graph authentication reliable across all auth methods
- Token lifecycle managed automatically
- Consistent error handling and retry logic
- Production-ready for SPN automation

---

## Phase 13 — Comprehensive Azure Monitor / Insights Coverage

> **NEW REQUIREMENT:** "There is a lot of crap from monitoring we seem to be missing? Insights? those types of things."
> Current coverage: Only `APPInsights.ps1` and `Workspaces.ps1`. Missing 20+ monitoring resources.

### 13.1 — Core Azure Monitor Resources (6 modules)

- [x] **13.1.1** Create `ResourceDiagnosticSettings.ps1` (Monitoring category)
  - **API**: `Get-AzDiagnosticSetting` (per-resource, not subscription-level)
  - **Excel**: "Resource Diagnostic Settings"
  - **Fields**: ResourceId, ResourceName, ResourceType, LogCategories (enabled/disabled), MetricCategories (enabled/disabled), Destinations (Log Analytics, Storage, Event Hub, Partner Solutions)
- [x] **13.1.2** Create `ActivityLogAlertRules.ps1` (Monitoring category)
  - **API**: `Get-AzActivityLogAlert`
  - **Excel**: "Activity Log Alerts"
  - **Fields**: Name, ResourceGroup, Enabled, Scopes, Condition (category, level, status), Actions (Action Group names)
- [x] **13.1.3** Create `SmartDetectorAlertRules.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.AlertsManagement/smartDetectorAlertRules'`
  - **Excel**: "Smart Detector Alerts"
  - **Fields**: Name, ResourceGroup, Severity, Frequency, Detector (type), Scope (Application Insights), ActionGroups
- [x] **13.1.4** Create `AutoscaleSettings.ps1` (Monitoring category)
  - **API**: `Get-AzAutoscaleSetting`
  - **Excel**: "Autoscale Settings"
  - **Fields**: Name, ResourceGroup, TargetResourceId, Enabled, Profiles (name, capacity min/max/default, rules count), Notifications (webhooks, email)
- [x] **13.1.5** Create `MonitorWorkbooks.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.Insights/workbooks'`
  - **Excel**: "Azure Monitor Workbooks"
  - **Fields**: Name, ResourceGroup, Category, Tags, Version, SourceId (linked resource), TimeModified
- [x] **13.1.6** Create `MonitorPrivateLinkScopes.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.Insights/privateLinkScopes'`
  - **Excel**: "Monitor Private Link Scopes"
  - **Fields**: Name, ResourceGroup, Location, PrivateEndpointConnections (count), ScopedResources (count, types)

### 13.2 — Log Analytics Enhancements (3 modules)

- [x] **13.2.1** Create `LAWorkspaceSavedSearches.ps1` (Monitoring category)
  - **API**: `Get-AzOperationalInsightsSavedSearch -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "LA Saved Searches"
  - **Fields**: WorkspaceName, DisplayName, Category, Query, Version, Tags
- [x] **13.2.2** Create `LAWorkspaceSolutions.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.OperationsManagement/solutions'`
  - **Excel**: "LA Solutions"
  - **Fields**: Name, WorkspaceResourceId, Plan (name, publisher, product), ProvisioningState
- [x] **13.2.3** Create `LAWorkspaceLinkedServices.ps1` (Monitoring category)
  - **API**: `Get-AzOperationalInsightsLinkedService -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "LA Linked Services"
  - **Fields**: WorkspaceName, ResourceId, WriteAccessResourceId (Automation Account)

### 13.3 — Application Insights Deep Data (5 modules)

- [x] **13.3.1** Create `AppInsightsAvailabilityTests.ps1` (Monitoring category)
  - **API**: `Get-AzApplicationInsightsWebTest` (classic availability tests)
  - **Excel**: "App Insights Availability Tests"
  - **Fields**: Name, ResourceGroup, AppInsightsResourceId, WebTestKind, Enabled, Frequency, Timeout, Locations (count), Configuration
- [x] **13.3.2** Create `AppInsightsWebTests.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.Insights/webtests'`
  - **Excel**: "App Insights Web Tests"
  - **Fields**: Name, ResourceGroup, Kind (ping/multistep/standard), SyntheticMonitorId, Enabled, Frequency, Timeout, Locations
- [x] **13.3.3** Create `AppInsightsProactiveDetection.ps1` (Monitoring category)
  - **API**: `Get-AzApplicationInsightsProactiveDetectionConfiguration -ResourceGroupName $RG -Name $AI`
  - **Excel**: "App Insights Proactive Detection"
  - **Fields**: AppInsightsName, RuleDefinitions (name, enabled, sendEmailsToSubscriptionOwners, customEmails)
- [x] **13.3.4** Create `AppInsightsContinuousExport.ps1` (Monitoring category)
  - **API**: `Get-AzApplicationInsightsContinuousExport -ResourceGroupName $RG -Name $AI`
  - **Excel**: "App Insights Continuous Export"
  - **Fields**: AppInsightsName, ExportId, DestinationStorageSubscriptionId, DestinationStorageLocationId, DestinationAccountId, IsEnabled, RecordTypes
- [x] **13.3.5** Create `AppInsightsWorkItems.ps1` (Monitoring category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.Insights/workitemconfigs'`
  - **Excel**: "App Insights Work Items"
  - **Fields**: AppInsightsName, ConfigDisplayName, ConnectorId (Azure DevOps, GitHub), IsValidated

### 13.4 — Metrics & Ingestion (1 module)

- [x] **13.4.1** Create `MonitorMetricsIngestion.ps1` (Monitoring category)
  - **API**: Custom aggregation from Log Analytics workspace ingestion stats
  - **Excel**: "Metrics Ingestion Stats"
  - **Fields**: WorkspaceName, DailyIngestionGB, MonthlyIngestionGB, RetentionDays, CapGB (daily cap if configured)

### 13.5 — Phase 13 Testing

- [ ] **13.5.1** Test: All 15 monitoring modules execute without errors
- [ ] **13.5.2** Test: Diagnostic settings capture resource-level configurations (not just subscription)
- [ ] **13.5.3** Test: Application Insights deep data modules handle missing configurations gracefully
- [ ] **13.5.4** Test: Excel report contains all 15 new monitoring worksheets
- [x] **13.5.5** Update `CHANGELOG.md` with Phase 13 additions
- [ ] **13.5.6** Commit & push Phase 13

---

## Phase 14 — Azure AI / Foundry / Machine Learning Coverage

> **NEW REQUIREMENT:** "azure ai/azure foundry, nothing like that is being audited."
> Current coverage: Only 3 basic AI modules (AzureAI, CustomVision, ContentSafety). Missing ALL OpenAI, Foundry, Machine Learning, Bot Services, Search.

### 14.1 — Azure OpenAI (2 modules)

- [x] **14.1.1** Create `OpenAIServices.ps1` (AI category)
  - **API**: `Get-AzCognitiveServicesAccount | Where-Object {$_.Kind -eq 'OpenAI'}`
  - **Excel**: "Azure OpenAI Services"
  - **Fields**: Name, ResourceGroup, Location, SKU, Kind, Endpoints, CustomSubDomainName, Deployments (separate API call), NetworkAcls, PrivateEndpoints
- [x] **14.1.2** Create `OpenAIDeployments.ps1` (AI category)
  - **API**: `Get-AzCognitiveServicesAccountDeployment -ResourceGroupName $RG -AccountName $Name`
  - **Excel**: "Azure OpenAI Deployments"
  - **Fields**: AccountName, DeploymentName, Model (name, version, format), SKU (name, capacity, tier), ScaleSettings, ProvisioningState

### 14.2 — Azure AI Foundry (2 modules)

- [x] **14.2.1** Create `AIFoundryProjects.ps1` (AI category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.MachineLearningServices/workspaces' | Where-Object {$_.Kind -eq 'Project'}`
  - **Excel**: "AI Foundry Projects"
  - **Fields**: Name, ResourceGroup, Location, HubResourceId, PublicNetworkAccess, ManagedNetwork, SystemDataCreatedBy
- [x] **14.2.2** Create `AIFoundryHubs.ps1` (AI category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.MachineLearningServices/workspaces' | Where-Object {$_.Kind -eq 'Hub'}`
  - **Excel**: "AI Foundry Hubs"
  - **Fields**: Name, ResourceGroup, Location, StorageAccount, KeyVault, ApplicationInsights, ContainerRegistry, Projects (count), PublicNetworkAccess

### 14.3 — Cognitive Services (2 modules)

- [x] **14.3.1** Create `CognitiveServicesAccounts.ps1` (AI category)
  - **API**: `Get-AzCognitiveServicesAccount | Where-Object {$_.Kind -ne 'OpenAI'}`
  - **Excel**: "Cognitive Services"
  - **Fields**: Name, ResourceGroup, Location, Kind (TextAnalytics, ComputerVision, Speech, FormRecognizer, etc.), SKU, Endpoint, CustomDomain, NetworkAcls, PrivateEndpoints
- [x] **14.3.2** Create `AppliedAIServices.ps1` (AI category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.CognitiveServices/accounts' | Where-Object {$_.Kind -in @('FormRecognizer','MetricsAdvisor','VideoAnalyzer','ImmersiveReader','Personalizer')}`
  - **Excel**: "Applied AI Services"
  - **Fields**: Name, ResourceGroup, Kind, Location, SKU, Endpoint, Features (kind-specific capabilities)

### 14.4 — Machine Learning (7 modules)

- [x] **14.4.1** Create `MachineLearningWorkspaces.ps1` (AI category)
  - **API**: `Get-AzMLWorkspace`
  - **Excel**: "ML Workspaces"
  - **Fields**: Name, ResourceGroup, Location, StorageAccount, KeyVault, ApplicationInsights, ContainerRegistry, PublicNetworkAccess, ManagedNetwork, HbiWorkspace
- [x] **14.4.2** Create `MLCompute.ps1` (AI category)
  - **API**: `Get-AzMLWorkspaceCompute -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "ML Compute"
  - **Fields**: WorkspaceName, ComputeName, ComputeType (AmlCompute, ComputeInstance, AKS, Databricks, etc.), VMSize, MinNodes, MaxNodes, IdleSecondsBeforeScaleDown, State
- [x] **14.4.3** Create `MLDatastores.ps1` (AI category)
  - **API**: `Get-AzMLWorkspaceDatastore -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "ML Datastores"
  - **Fields**: WorkspaceName, Name, DatastoreType (AzureBlob, AzureDataLakeGen2, AzureFile), AccountName, ContainerName, IsDefault
- [x] **14.4.4** Create `MLDatasets.ps1` (AI category)
  - **API**: `Get-AzMLWorkspaceDataset -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "ML Datasets"
  - **Fields**: WorkspaceName, DatasetName, DatasetType (Tabular, File), DataPath, Version, Tags, CreatedTime
- [x] **14.4.5** Create `MLModels.ps1` (AI category)
  - **API**: `Get-AzMLWorkspaceModel -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "ML Models"
  - **Fields**: WorkspaceName, Name, Version, Framework (TensorFlow, PyTorch, ONNX, etc.), Tags, CreatedTime, ModifiedTime
- [x] **14.4.6** Create `MLEndpoints.ps1` (AI category)
  - **API**: `Get-AzMLWorkspaceOnlineEndpoint -ResourceGroupName $RG -WorkspaceName $WS`
  - **Excel**: "ML Endpoints"
  - **Fields**: WorkspaceName, EndpointName, EndpointType (Online, Batch), ScoringUri, SwaggerUri, AuthMode (Key, AMLToken, AAD), Traffic (deployment allocations)
- [x] **14.4.7** Create `MLPipelines.ps1` (AI category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.MachineLearningServices/workspaces/pipelines'`
  - **Excel**: "ML Pipelines"
  - **Fields**: WorkspaceName, PipelineName, PipelineId, Status, CreatedTime, LastModified

### 14.5 — Bot Services & Search (2 modules)

- [x] **14.5.1** Create `BotServices.ps1` (AI category)
  - **API**: `Get-AzBotService`
  - **Excel**: "Bot Services"
  - **Fields**: Name, ResourceGroup, Location, Kind (Bot, Function, Designer), SKU, Endpoint, MsaAppId, Channels (count, types), DeveloperAppInsightKey
- [x] **14.5.2** Create `CognitiveSearchServices.ps1` (AI category)
  - **API**: `Get-AzSearchService`
  - **Excel**: "Cognitive Search Services"
  - **Fields**: Name, ResourceGroup, Location, SKU, ReplicaCount, PartitionCount, Indexes (count), Indexers (count), DataSources (count), HostingMode, NetworkRuleSet, PrivateEndpoints

### 14.6 — Phase 14 Testing

- [ ] **14.6.1** Test: All 15 AI/ML modules execute without errors
- [ ] **14.6.2** Test: OpenAI deployments capture model details (requires OpenAI service present)
- [ ] **14.6.3** Test: AI Foundry hubs/projects detected correctly (new resourceType Kind filtering)
- [ ] **14.6.4** Test: ML workspace child resources (compute, datastores, datasets, models, endpoints) enumerate correctly
- [x] **14.6.5** Update `CHANGELOG.md` with Phase 14 additions
- [ ] **14.6.6** Commit & push Phase 14

---

## Phase 15 — Azure Virtual Desktop Coverage

> **NEW REQUIREMENT:** "azure virtual desktops? in azure and also in azure local or the new avd on anything with arc"
> Current coverage: ZERO AVD modules. Need coverage for Azure native AVD + AVD on Azure Local + AVD on Arc.

### 15.1 — AVD Core Resources — Azure Native (5 modules)

- [x] **15.1.1** Create `AVDHostPools.ps1` (VirtualDesktop category)
  - **API**: `Get-AzWvdHostPool`
  - **Excel**: "AVD Host Pools"
  - **Fields**: Name, ResourceGroup, Location, HostPoolType (Pooled/Personal), LoadBalancerType, MaxSessionLimit, PreferredAppGroupType, RegistrationToken (status), ValidationEnvironment, StartVMOnConnect, CustomRdpProperty
- [x] **15.1.2** Create `AVDApplicationGroups.ps1` (VirtualDesktop category)
  - **API**: `Get-AzWvdApplicationGroup`
  - **Excel**: "AVD Application Groups"
  - **Fields**: Name, ResourceGroup, Location, ApplicationGroupType (RemoteApp/Desktop), HostPoolArmPath, WorkspaceArmPath, Applications (count), FriendlyName
- [x] **15.1.3** Create `AVDWorkspaces.ps1` (VirtualDesktop category)
  - **API**: `Get-AzWvdWorkspace`
  - **Excel**: "AVD Workspaces"
  - **Fields**: Name, ResourceGroup, Location, ApplicationGroupReferences (count), FriendlyName, PublicNetworkAccess, PrivateEndpointConnections
- [x] **15.1.4** Create `AVDSessionHosts.ps1` (VirtualDesktop category)
  - **API**: `Get-AzWvdSessionHost -HostPoolName $HP -ResourceGroupName $RG`
  - **Excel**: "AVD Session Hosts"
  - **Fields**: HostPoolName, SessionHostName, ResourceId (VM), Status, AllowNewSession, AssignedUser, Sessions (active), LastHeartBeat, AgentVersion, OSVersion, UpdateState
- [x] **15.1.5** Create `AVDScalingPlans.ps1` (VirtualDesktop category)
  - **API**: `Get-AzWvdScalingPlan`
  - **Excel**: "AVD Scaling Plans"
  - **Fields**: Name, ResourceGroup, Location, HostPoolReferences (count), Schedules (count, days/hours), TimeZone, ExclusionTag

### 15.2 — AVD on Azure Local / Arc-Enabled (1 module)

- [x] **15.2.1** Create `AVDAzureLocal.ps1` (VirtualDesktop category)
  - **API**: Hybrid approach:
    - Arc-enabled session hosts: `Get-AzConnectedMachine | Where-Object {$_.Tags.AvdSessionHost -eq 'true'}` (Arc VMs)
    - Azure Local AVD VMs: `Get-AzResource -ResourceType 'Microsoft.AzureStackHCI/virtualMachines' | Where-Object {$_.Tags.AvdSessionHost -eq 'true'}`
  - **Excel**: "AVD on Azure Local/Arc"
  - **Fields**: SessionHostName, Platform (Arc/AzureLocal), ResourceId, HostPoolName (from tags or config), Status, OSVersion, AgentVersion, ArcAgentVersion, Location

### 15.3 — Phase 15 Testing

- [ ] **15.3.1** Test: AVD host pools, application groups, workspaces enumerate correctly
- [ ] **15.3.2** Test: Session hosts capture accurate status and session counts
- [ ] **15.3.3** Test: AVD on Azure Local/Arc module detects tagged Arc VMs and Azure Local VMs
- [ ] **15.3.4** Test: Excel report contains all 6 AVD worksheets
- [x] **15.3.5** Update `CHANGELOG.md` with Phase 15 additions
- [ ] **15.3.6** Commit & push Phase 15

---

## Phase 16 — Arc Enhanced Configuration Coverage

> **NEW REQUIREMENT:** "arc site configuration configs" + deeper Arc data extraction.
> Current coverage: Basic Arc resources. Need site-level configs, deep extension data, Arc-enabled SQL, Arc Data Services.

### 16.1 — Arc Site & Configuration (2 modules)

- [x] **16.1.1** Create `ArcSiteConfigurations.ps1` (Hybrid category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.HybridCompute/sites'` (if available; may need Azure Arc site manager API)
  - **Excel**: "Arc Site Configurations"
  - **Fields**: SiteName, ResourceGroup, Location, ConnectedMachines (count), Kubernetes clusters (count), Configuration (governance policies, update schedules)
- [x] **16.1.2** Enhance `ArcExtensions.ps1` (Hybrid category)
  - **Current**: Basic extension inventory
  - **Enhancement**: Add deep configuration data:
    - Extension settings (parsed JSON)
    - Extension version
    - Auto-upgrade settings
    - Protected settings indicator (yes/no, not values)
    - Provisioning state + error messages

### 16.2 — Arc-Enabled SQL Server (1 module)

- [x] **16.2.1** Create `ArcEnabledSQLServer.ps1` (Hybrid category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.AzureArcData/sqlServerInstances'`
  - **Excel**: "Arc-Enabled SQL Server"
  - **Fields**: ServerName, ResourceGroup, Location, ArcServerResourceId, SQLVersion, Edition, LicenseType, Cores, MemoryMB, Databases (count), ESU (enabled/disabled)

### 16.3 — Arc Data Services (1 module)

- [x] **16.3.1** Create `ArcDataServices.ps1` (Hybrid category)
  - **API**: `Get-AzResource -ResourceType 'Microsoft.AzureArcData/dataControllers'`
  - **Excel**: "Arc Data Services"
  - **Fields**: DataControllerName, ResourceGroup, Location, K8sNamespace, InfrastructureType (direct/indirect), K8sDistribution, SQLManagedInstances (count), PostgreSQLInstances (count), DataUploadState

### 16.4 — Arc Resource Bridge Enhancement (1 enhancement)

- [x] **16.4.1** Enhance `ArcResourceBridge.ps1` (Hybrid category)
  - **Current**: Basic resource bridge inventory
  - **Enhancement**: Add detailed configurations:
    - Appliance configuration (management IP, subnet)
    - Connected cluster details
    - Custom locations linked
    - Provider configurations (VMware, SCVMM, Azure Local)

### 16.5 — Phase 16 Testing

- [ ] **16.5.1** Test: Arc site configurations enumerate (if sites exist in tenant)
- [ ] **16.5.2** Test: Enhanced Arc extensions capture version, settings, auto-upgrade status
- [ ] **16.5.3** Test: Arc-enabled SQL Server captures database count and ESU status
- [ ] **16.5.4** Test: Arc Data Services module handles both direct/indirect connectivity modes
- [x] **16.5.5** Update `CHANGELOG.md` with Phase 16 additions
- [ ] **16.5.6** Commit & push Phase 16

---

## Phase 17 — VM Data Enhancement (Deep Inventory)

> **NEW REQUIREMENT:** "as much data as possible from azure vms, from arc vms, etc."
> Current coverage: Basic VM inventory. Need extensions, boot diagnostics, performance, security, patches, backup, DR, cost, recommendations.

### 17.1 — Enhance VirtualMachines.ps1 (10 enhancements)

- [x] **17.1.1** Add **Extensions** data:
  - Extension name, version, publisher, type
  - Provisioning state, auto-upgrade minor version
  - Protected settings indicator (yes/no)
  - Last update timestamp
- [x] **17.1.2** Add **Boot Diagnostics** configuration:
  - Enabled (yes/no)
  - Storage account URI
  - Managed storage (yes/no)
- [x] **17.1.3** Add **Performance Metrics** (last 24h/7d):
  - Avg CPU % (if Azure Monitor agent installed)
  - Avg Memory % (if available)
  - Disk IOPS, Disk throughput
  - Network in/out
- [x] **17.1.4** Add **Security Baseline Compliance**:
  - Azure Security Center compliance state (if Defender enabled)
  - Security recommendations count (high/medium/low)
- [x] **17.1.5** Add **Update Compliance**:
  - Pending patches count (critical/important/other)
  - Last assessment time
  - Maintenance configuration assignment (if configured)
- [x] **17.1.6** Add **Backup Status**:
  - Protected (yes/no)
  - Recovery Services Vault name
  - Last backup time
  - Backup policy name
- [x] **17.1.7** Add **Disaster Recovery Status**:
  - Replicated (yes/no via Azure Site Recovery)
  - Target region
  - Replication health
- [x] **17.1.8** Add **Cost Estimate**:
  - Monthly cost estimate (from Azure Cost Management API)
  - Savings recommendations (if Advisor has suggestions)
- [x] **17.1.9** Add **Advisor Recommendations**:
  - High priority recommendations count
  - Categories (Cost, Performance, Reliability, Security)
- [x] **17.1.10** Add **Lifecycle Tags**:
  - Environment tag (prod/dev/test)
  - Owner tag
  - Expiration tag (if exists)

### 17.2 — Enhance ARCServers.ps1 (10 enhancements — same depth as Azure VMs)

- [x] **17.2.1** Add **OS Details**:
  - OS type, OS version, patch level
  - Kernel version (Linux)
  - Build number (Windows)
- [x] **17.2.2** Add **Arc Agent Details**:
  - Arc agent version
  - Connected Machine Agent health status
  - Last heartbeat timestamp
- [x] **17.2.3** Add **Extensions** data (same as Azure VMs):
  - Extension name, version, publisher, type
  - Provisioning state
  - Auto-upgrade settings
- [x] **17.2.4** Add **Security Baseline Compliance** (same as Azure VMs):
  - Defender for Cloud compliance state (if enabled)
  - Security recommendations count
- [x] **17.2.5** Add **Update Compliance** (same as Azure VMs):
  - Pending patches count
  - Last assessment time
  - Maintenance configuration assignment
- [x] **17.2.6** Add **Policies Applied**:
  - Azure Policy assignments count
  - Compliance state (compliant/non-compliant/conflicting)
  - Policy categories (security, monitoring, tagging)
- [x] **17.2.7** Add **Performance Metrics** (if available):
  - Avg CPU % (if Azure Monitor agent installed)
  - Avg Memory %
  - Disk metrics
- [x] **17.2.8** Add **Lifecycle Metadata**:
  - Environment tag
  - Owner tag
  - OnPremLocation tag (datacenter/site)
- [x] **17.2.9** Add **Cost Tracking** (if available):
  - Arc license costs (if applicable)
  - Extended Security Updates costs (if ESU enabled)
- [x] **17.2.10** Add **Hybrid Connectivity**:
  - Network connectivity status
  - Proxy configuration (yes/no)
  - Private Link scope (if configured)

### 17.3 — New API Integrations

- [x] **17.3.1** Integrate **Azure Monitor Metrics API** for performance data
- [x] **17.3.2** Integrate **Azure Backup API** for backup status (`Get-AzRecoveryServicesBackupItem`)
- [x] **17.3.3** Integrate **Azure Site Recovery API** for DR status (`Get-AzRecoveryServicesAsrReplicationProtectedItem`)
- [x] **17.3.4** Integrate **Azure Advisor API** for recommendations (`Get-AzAdvisorRecommendation`)
- [x] **17.3.5** Integrate **Azure Cost Management API** for cost estimates (`Invoke-AzRestMethod -Path /subscriptions/{sub}/providers/Microsoft.CostManagement/query`)
- [x] **17.3.6** Integrate **Azure Update Manager API** for patch compliance (`Get-AzMaintenanceUpdate`)

### 17.4 — Phase 17 Testing

- [ ] **17.4.1** Test: VM extensions enumerate with versions and settings
- [ ] **17.4.2** Test: Backup status correctly identifies protected vs unprotected VMs
- [ ] **17.4.3** Test: Update compliance shows pending patches count (requires Azure Update Manager)
- [ ] **17.4.4** Test: Arc servers capture same depth of data as Azure VMs
- [ ] **17.4.5** Test: Performance metrics populate when Monitor agent installed
- [ ] **17.4.6** Test: Cost estimates appear for VMs (requires Cost Management API access)
- [x] **17.4.7** Update `CHANGELOG.md` with Phase 17 additions
- [ ] **17.4.8** Commit & push Phase 17

---

## Phase 18 — Category-Based Filtering Implementation

> **NEW REQUIREMENT:** "break things up into categories...run the module with a parameter that says only security, or networking, or data, or monitoring"
> **MUST MATCH:** Microsoft Azure Portal official category taxonomy (https://portal.azure.com/#allservices/category/All) — 18 categories + "All" = 19 total.

### 18.1 — Module Folder Restructure (Align with Microsoft Categories)

> **GOAL:** Rename and reorganize module folders to perfectly match Microsoft's 18 official category names.

**Folder Renames:**
- [x] **18.1.1** Rename `Modules/Public/InventoryModules/Container/` → `Containers/` (plural to match category)
- [x] **18.1.2** Rename `Modules/Public/InventoryModules/Database/` → `Databases/` (plural to match category)
- [x] **18.1.3** Rename `Modules/Public/InventoryModules/Monitoring/` → `Monitor/` (match official category name)
- [x] **18.1.4** Rename `Modules/Public/InventoryModules/Network/` → `Networking/` (match official category name)

**Module Redistribution:**
- [x] **18.1.5** Move all `AzureLocal/*.ps1` (6 modules) → `Hybrid/` (Azure Local IS hybrid infrastructure)
  - `Clusters.ps1`, `GalleryImages.ps1`, `LogicalNetworks.ps1`, `MarketplaceGalleryImages.ps1`, `StorageContainers.ps1`, `VirtualMachines.ps1`
- [x] **18.1.6** Delete `AzureLocal/` folder (now empty)
- [x] **18.1.7** Move `APIs/AdvisorScore.ps1` → `Management/`
- [x] **18.1.8** Move `APIs/ManagedIds.ps1` → `Identity/` (managed identities are identity resources)
- [x] **18.1.9** Move `APIs/Outages.ps1` → `Monitor/` (service health = monitoring)
- [x] **18.1.10** Move `APIs/ReservationRecom.ps1` → `Management/`
- [x] **18.1.11** Move `APIs/SupportTickets.ps1` → `Management/`
- [x] **18.1.12** Delete `APIs/` folder (now empty)

**Result Verification:**
- [x] **18.1.13** Verify final folder structure matches Microsoft's 18 categories exactly:
  - ✅ `AI/` → "AI + machine learning"
  - ✅ `Analytics/` → "Analytics"
  - ✅ `Compute/` → "Compute"
  - ✅ `Containers/` → "Containers" (renamed from Container)
  - ✅ `Databases/` → "Databases" (renamed from Database)
  - ✅ `Hybrid/` → "Hybrid + multicloud" (now includes AzureLocal modules)
  - ✅ `Identity/` → "Identity" (now includes ManagedIds from APIs)
  - ✅ `Integration/` → "Integration"
  - ✅ `IoT/` → "Internet of Things"
  - ✅ `Management/` → "Management and governance" (now includes 3 modules from APIs)
  - ✅ `Monitor/` → "Monitor" (renamed from Monitoring, includes Outages from APIs)
  - ✅ `Networking/` → "Networking" (renamed from Network)
  - ✅ `Security/` → "Security"
  - ✅ `Storage/` → "Storage"
  - ✅ `Web/` → "Web & Mobile"
- [x] **18.1.14** Update all file references in module loader/importer scripts
- [ ] **18.1.15** Test module auto-discovery still works after restructure
- [x] **18.1.16** Update `.vscode/settings.json` or workspace file references if needed
- [ ] **18.1.17** Commit restructure: `feat(phase18): align module folders with Microsoft's 18 Azure categories`

### 18.2 — Add `-Category` Parameter to Main Function

- [x] **18.2.1** Add parameter to `Invoke-AzureScout`:
  ```powershell
  [ValidateSet('All', 'AI + machine learning', 'Analytics', 'Compute', 'Containers', 'Databases', 'DevOps', 'General', 'Hybrid + multicloud', 'Identity', 'Integration', 'Internet of Things', 'Management and governance', 'Migration', 'Monitor', 'Networking', 'Security', 'Storage', 'Web & Mobile')]
  [string[]]$Category = 'All'
  ```
- [x] **18.2.2** Support multiple categories (array input): `-Category Security,Monitor`
- [x] **18.2.3** Default value: `All` (current behavior — execute everything)
- [x] **18.2.4** Update help documentation with category descriptions and examples
- [x] **18.2.5** Support aliases for common shortcuts: `AI` → `AI + machine learning`, `IoT` → `Internet of Things`, `Monitoring` → `Monitor`, `Management` → `Management and governance`, `Web` → `Web & Mobile`, `Hybrid` → `Hybrid + multicloud`

### 18.3 — Document Category Structure & Mapping

- [x] **18.3.1** Create **official category mapping document** (`docs/azure-category-structure.md`):
  - List all 18 Microsoft Azure categories with official descriptions
  - Document which categories we currently cover (with module counts)
  - Document which categories we don't cover yet (planned vs not planned)
  - Link to Microsoft's official category page: https://portal.azure.com/#allservices/category/All
- [x] **18.3.2** Create **coverage comparison table** (`docs/azure-coverage-table.md`):
  - Table: Microsoft Service | Category | Covered (Y/N) | Module Name | Planned Phase | Notes
  - Map ALL Microsoft Azure services to our module coverage
  - Highlight gaps (services Microsoft offers that we don't inventory)
  - Track future coverage plans (which phase will add missing services)
- [x] **18.3.3** Add `.CATEGORY` comment header to each module file:
  ```powershell
  .CATEGORY
      Compute
  ```
- [x] **18.3.4** Verify all modules have category assignment (automated validation script)

### 18.4 — Implement Category Filtering Logic

- [x] **18.4.1** Update module auto-discovery to read category metadata:
  - Parse comment header: `# Category: X, Y`
  - Store in module info object
- [x] **18.4.2** Filter module list based on `-Category` parameter:
  - If `All`: Load all modules (current behavior)
  - If specific category: Load only modules matching category
  - If multiple categories: Load union of matching modules
- [x] **18.4.3** Add logging: `"Filtered to {count} modules based on category: {categories}"`
- [x] **18.4.4** Handle invalid category values with clear error message
- [x] **18.4.5** Ensure category filtering works with `-Scope All` and `-Scope ArmOnly`

### 18.5 — Update Documentation

- [x] **18.5.1** Create `README.md` category section:
  - Table of categories with descriptions and module counts
  - Examples: `-Category Security`, `-Category Monitoring,Security`, `-Category AI,Analytics`
  - Use cases: Security audits, Monitoring-only inventory, AI/ML governance
- [x] **18.5.2** Update help documentation in `Invoke-AzureScout`:
  - `.PARAMETER Category` section with ValidateSet values
  - `.EXAMPLE` for each category usage pattern
- [x] **18.5.3** Update `CHANGELOG.md` with category filtering feature
- [x] **18.5.4** Create `docs/modules/ROOT/pages/category-filtering.adoc` (detailed guide)

### 18.6 — Category Mapping (Microsoft Azure Portal Taxonomy — 18 Official Categories)

> **REFERENCE:** All categories below match https://portal.azure.com/#allservices/category/All exactly.

#### AI + machine learning (15 modules — after Phase 14)
- OpenAIServices, OpenAIDeployments, AIFoundryProjects, AIFoundryHubs, CognitiveServicesAccounts, AppliedAIServices, MachineLearningWorkspaces, MLCompute, MLDatastores, MLDatasets, MLModels, MLEndpoints, MLPipelines, BotServices, CognitiveSearchServices

#### Analytics (6 modules)
- DataExplorer, Synapse, DataFactory, Databricks, StreamAnalytics, DataLakeStore

#### Compute (19 modules — includes AVD after Phase 15)
- VirtualMachines, VMSS, CloudServices, AvailabilitySets, Images, DedicatedHosts, CapacityReservations, AVDHostPools, AVDApplicationGroups, AVDWorkspaces, AVDSessionHosts, AVDScalingPlans, AVDAzureLocalSessionHosts (6 AVD modules moved from separate category to Compute per Microsoft categorization)

#### Containers (6 modules)
- AKS, ContainerApp, ContainerRegistry, ContainerInstances, AppServiceContainers, WebAppContainers

#### Databases (12 modules)
- SQLSERVER, SQLDB, MySQL, PostgreSQL, CosmosDB, RedisCache, MariaDB, Synapse, DataExplorer, ManagedInstance, CassandraCluster, DatabaseMigration

#### DevOps (3 modules)
- DevOps, RecoveryVault, AutomationAccount

#### General (0 modules)
- *(Not inventoried — informational category: Marketplace, Portal, Cloud Shell)*

#### Hybrid + multicloud (18 modules — after Phase 16, includes Arc + Azure Local)
- ARCServers, ArcGateways, ArcKubernetes, ArcResourceBridge, ArcExtensions, AzureLocalClusters, AzureLocalVMs, AzureLocalNetworks, AzureLocalStoragePaths, ArcSettings, ArcSiteConfigurations, ArcEnabledSQLServer, ArcDataControllers, ArcSQLManagedInstances, ArcSites, ConnectedClusters, EdgeDevices, ArcMachineExtensions (combines Arc + Azure Local into single category per Microsoft taxonomy)

#### Identity (15 modules)
- Users, Groups, AppRegistrations, ServicePrincipals, ManagedIdentities, DirectoryRoles, PIMAssignments, ConditionalAccess, NamedLocations, AdminUnits, Domains, Licensing, CrossTenantAccess, SecurityPolicies, RiskyUsers

#### Integration (5 modules)
- ServiceBUS, EventGrid, EvtHub, LogicApps, APIManagement

#### Internet of Things (1 module)
- IOTHubs

#### Management and governance (6 modules)
- ManagementGroups, CustomRoleDefinitions, PolicyDefinitions, PolicySetDefinitions, PolicyComplianceStates, MaintenanceConfigurations

#### Migration (3 modules)
- MigrateProjects, MigrateAssessments, DatabaseMigrationServices

#### Monitor (22 modules — after Phase 13)
- APPInsights, Workspaces, ActionGroups, MetricAlertRules, ScheduledQueryRules, DataCollectionRules, DataCollectionEndpoints, SubscriptionDiagnosticSettings, ResourceDiagnosticSettings, ActivityLogAlertRules, SmartDetectorAlertRules, AutoscaleSettings, MonitorWorkbooks, MonitorPrivateLinkScopes, LAWorkspaceSavedSearches, LAWorkspaceSolutions, LAWorkspaceLinkedServices, AppInsightsAvailabilityTests, AppInsightsWebTests, AppInsightsProactiveDetection, AppInsightsContinuousExport, AppInsightsWorkItems, MonitorMetricsIngestion

#### Networking (35 modules — includes VPN after consolidation)
- VirtualNetwork, VirtualNetworkPeering, VirtualNetworkGateway, VirtualNetworkGatewayConnection, ExpressRoute, VPNGateways, VPNConnections, LocalNetworkGateways, P2SVPNGateways, ExpressRouteCircuits, ExpressRouteGateways, ApplicationGateway, FrontDoor, CDN, LoadBalancer, PublicIP, NetworkInterface, NetworkSecurityGroup, RouteTable, AzureFirewall, FirewallPolicy, AzureBastion, PrivateEndpoint, PrivateDNS, NetworkWatcher, TrafficManager, DNSZones, NAT Gateways, ServiceEndpointPolicies, IPGroups, WebApplicationFirewallPolicies, PrivateLinkServices, VirtualWANs, VirtualHubs, NSGFlowLogs (7 VPN modules moved from separate category to Networking per Microsoft categorization)

#### Security (6 modules)
- Vault (Key Vault), DefenderAssessments, DefenderSecureScore, DefenderAlerts, DefenderPricing, Sentinel (if added)

#### Storage (2 modules)
- StorageAccounts, NetApp

#### Web & Mobile (2 modules)
- APPServices, APPServicePlan

**Total Modules:** ~203 after all phases complete

**Category Changes from Original Plan:**
- ✅ **AVD modules** moved from standalone "VirtualDesktop" category → **Compute** (matches Microsoft)
- ✅ **VPN modules** moved from standalone "VPN" category → **Networking** (matches Microsoft)
- ✅ **Arc + Azure Local** combined into **"Hybrid + multicloud"** (18 modules total, matches Microsoft)
- ✅ **"AI-ML"** renamed to **"AI + machine learning"** (matches Microsoft exactly)
- ✅ **"Monitoring"** renamed to **"Monitor"** (matches Microsoft exactly)
- ✅ **"Management"** renamed to **"Management and governance"** (matches Microsoft exactly)
- ✅ **"IoT"** renamed to **"Internet of Things"** (matches Microsoft exactly)
- ✅ **"Web"** renamed to **"Web & Mobile"** (matches Microsoft exactly)
- ✅ Added **"DevOps"** and **"General"** categories (Microsoft taxonomy)

### 18.7 — Phase 18 Testing

- [ ] **18.7.1** Test: Single category `-Category Compute` (only compute modules run, including AVD)
- [ ] **18.7.2** Test: Multiple categories `-Category Compute,Networking,Storage`
- [ ] **18.7.3** Test: Hybrid category `-Category "Hybrid + multicloud"` (runs Arc + Azure Local modules)
- [ ] **18.7.4** Test: Combined with scope `-Scope All -Category Security,Identity` (Defender + Entra only)
- [ ] **18.7.5** Test: Category alias `-Category AI` resolves to `AI + machine learning`
- [ ] **18.7.6** Verify Excel report contains only relevant worksheets for selected categories
- [x] **18.7.7** Verify Overview tab shows "Categories Selected" and "Modules Executed" count
- [x] **18.7.8** Update `CHANGELOG.md` with Phase 18 additions
- [ ] **18.7.9** Commit & push Phase 18

---

## Phase 19 — Final Testing & Validation

**Goal:** Comprehensive validation of all new features from Phases 9-18.

### 19.1 — Phase 14 Testing (AI/Foundry/ML)

- [ ] **19.1.1** Verify 15 new AI/ML worksheets in Excel report (OpenAI, AI Foundry, ML, Cognitive Services, Bot Services, Search)
- [ ] **19.1.2** Test OpenAI Deployments capture (model, version, scale type, capacity)
- [ ] **19.1.3** Test AI Foundry Projects (hub association, storage, key vault)
- [ ] **19.1.4** Test ML Endpoints (type, auth mode, deployments, traffic allocation)
- [ ] **19.1.5** Test Search Indexes (document count, storage size, fields)
- [ ] **19.1.6** Verify resource provider warnings for unregistered AI providers

### 19.2 — Phase 15 Testing (Azure Virtual Desktop)

- [ ] **19.2.1** Verify 6 new AVD worksheets (Host Pools, App Groups, Workspaces, Session Hosts, Scaling Plans, Applications)
- [ ] **19.2.2** Test AVD Host Pools capture (type, load balancer, max sessions, Arc enabled)
- [ ] **19.2.3** Test AVD Session Hosts (status, agent version, heartbeat, sessions, Arc machine ID, Azure Local cluster ID)
- [ ] **19.2.4** Test AVD Scaling Plans (schedules for ALL 4 time periods, capacity thresholds, load balancing)
- [ ] **19.2.5** Test AVD on Azure Local detection (Arc association + cluster ID)

### 19.3 — Phase 16 Testing (Arc Enhanced)

- [ ] **19.3.1** Verify 4 new Arc worksheets (Sites, SQL Servers, Data Controllers, SQL Managed Instances)
- [ ] **19.3.2** Test Arc Machine Extensions enhancement (JSON settings, protected settings indicator, auto-upgrade, instance view)
- [ ] **19.3.3** Test Arc SQL Servers (host machine, SQL version, edition, licensing, vCores, Defender)
- [ ] **19.3.4** Test Arc Data Controllers (cluster ID, connectivity mode, logs/metrics upload)
- [ ] **19.3.5** Test Arc SQL Managed Instances (data controller ID, vCores, storage, HA mode)

### 19.4 — Phase 17 Testing (VM Enhancement)

- [ ] **19.4.1** Verify **16 new columns** in Azure VMs worksheet (extensions, boot diagnostics, CPU/memory metrics, security baseline, patches, backup, DR, cost, advisor, tags)
- [ ] **19.4.2** Verify **15 new columns** in Arc Machines worksheet (OS details, agent version, heartbeat, extensions, policies, metrics, patches, backup, cost, tags)
- [ ] **19.4.3** Test Azure Monitor Metrics integration (7-day CPU % and Memory % averages)
- [ ] **19.4.4** Test Azure Backup integration (enabled flag, last backup time, vault, policy)
- [ ] **19.4.5** Test Site Recovery integration (DR enabled flag, target region, replication health)
- [ ] **19.4.6** Test Azure Advisor integration (recommendations count by category)
- [ ] **19.4.7** Test Cost Management integration (estimated monthly cost USD)
- [ ] **19.4.8** Test Update Manager integration (pending patches count, last patch date)
- [ ] **19.4.9** Test performance with large VM count (500 VMs in <30 min with parallel processing)
- [ ] **19.4.10** Test graceful degradation (VMs without enhancements show N/A, no errors)

### 19.5 — Phase 18 Testing (Category Filtering)

- [ ] **19.5.1** Test default behavior (no `-Category` = runs all modules)
- [ ] **19.5.2** Test single category with full name: `-Category Compute` (only Compute modules, ~19 modules including AVD)
- [ ] **19.5.3** Test multiple categories: `-Category Compute,Networking,Storage` (only selected categories)
- [ ] **19.5.4** Test combined with scope: `-Scope All -Category Security,Identity` (only Security + Identity modules)
- [ ] **19.5.5** Test Overview tab shows "Categories Selected" and "Modules Executed" counts
- [ ] **19.5.6** Test Hybrid + multicloud category (runs Arc + Azure Local modules, 18 total)
- [ ] **19.5.7** Test AI + machine learning category (runs 15 AI/ML modules)
- [ ] **19.5.8** Test category aliases: `-Category AI` resolves to "AI + machine learning"
- [ ] **19.5.9** Test Monitor category (runs 22 monitoring modules, uses "Monitor" NOT "Monitoring")
- [ ] **19.5.10** Test Internet of Things category (runs IoT Hubs, Device Provisioning, Digital Twins)
- [ ] **19.5.11** Test Management and governance category (runs MG, Policies, Subscriptions, Blueprints, Lighthouse, Tags, Locks, Cost)
- [ ] **19.5.12** Test Web & Mobile category (runs App Services, Functions, Static Web Apps)
- [ ] **19.5.13** Test Networking includes VPN (VPN Gateway, VPN Connections, Local Network Gateway, ExpressRoute merged into Networking, 35 modules total)

### 19.6 — Integration Testing

- [ ] **19.6.1** Full tenant scan: `-Scope All -Category All` completes successfully (~170 worksheets)
- [ ] **19.6.2** Empty tenant: completes successfully with 0 resources, no errors
- [ ] **19.6.3** Large tenant: 1000+ resources completes in <2 hours, graceful throttling
- [ ] **19.6.4** SPN auth with Entra + ARM: `-AppId -Secret -Scope All` authenticates and scans both
- [ ] **19.6.5** Resource provider warnings: `-CheckResourceProviders` warns for unregistered providers
- [ ] **19.6.6** Multi-subscription tenant: scans ALL subscriptions (including empty ones)
- [ ] **19.6.7** Management Groups hierarchy: captures full MG tree with parent-child relationships
- [ ] **19.6.8** Policy compliance at scale: captures ~500 most recent compliance states
- [ ] **19.6.9** Defender assessments: captures assessments, secure score, alerts, pricing, overview tab
- [ ] **19.6.10** Azure Update Manager Overview tab: lists ALL VMs + Arc machines with patch compliance
- [ ] **19.6.11** Azure Monitor overview tab: action groups, alert rules, DCRs, diagnostic settings coverage
- [ ] **19.6.12** Cost Management overview tab: VM reservations, recommendations

### 19.7 — Documentation & Usability

- [x] **19.7.1** `Get-Help Invoke-AzureScout -Full` shows complete help (synopsis, description, parameters, 10+ examples, inputs, outputs, notes, links)
- [x] **19.7.2** `README.md` accuracy: Quick Start reflects new defaults, Permissions section complete, Resource Providers listed, Examples cover all features
- [x] **19.7.3** `CHANGELOG.md` completeness: Documents all Phases 9-18 features with version numbers, breaking changes
- [x] **19.7.4** Error messages clarity: Permission denied errors clearly state missing permission + remediation steps
- [x] **19.7.5** Progress indicators: Execution shows current phase, module, resources collected count

### 19.8 — Final Validation

- [ ] **19.8.1** All 53 acceptance tests from IMPLEMENTATION-PLAN.md Phase 19 pass ✅
- [x] **19.8.2** Update version to 2.0.0 (major version for breaking changes + category filtering)
- [x] **19.8.3** Update effort estimates in IMPLEMENTATION-PLAN.md
- [x] **19.8.4** Final `CHANGELOG.md` review and update
- [ ] **19.8.5** Commit & push Phase 19

---

## Phase 20 — Dedicated Permission Audit Mode (`-PermissionAudit`)

> **NEW REQUIREMENT:** "when a user runs `Invoke-AzureScout -PermissionAudit` it runs **only** a permissions check — no inventory, no Excel, no JSON — and outputs a formatted permissions report."
>
> Default scope: ARM/RBAC only. Add `-IncludeEntraPermissions` to also audit Microsoft Graph / Entra ID access.
> Works with the currently logged-on user (interactive) **or** SPN credentials (`-TenantID`, `-AppId`, `-Secret`/`-CertificatePath`) — no new auth parameters needed, the existing auth params already cover this.

### Parameter Names

| Parameter | Type | Description |
|-----------|------|-------------|
| `-PermissionAudit` | `[switch]` | **New mode switch.** When present, the cmdlet skips all inventory collection and runs ONLY a permissions audit, then exits. Cannot be combined with `-Category`, `-Scope All`/`ArmOnly`/`EntraOnly` inventory logic. |
| `-IncludeEntraPermissions` | `[switch]` | Used with `-PermissionAudit`. Also checks Microsoft Graph / Entra ID permissions (Directory.Read.All, User.Read.All, Group.Read.All, Application.Read.All, RoleManagement.Read.Directory, Policy.Read.All, IdentityRiskyUser.Read.All). Requires Graph token acquisition. |

### 20.1 — Add `-PermissionAudit` Switch to `Invoke-AzureScout`

- [x] **20.1.1** Add `[switch]$PermissionAudit` parameter with `.PARAMETER PermissionAudit` help block:
  - "Runs a dedicated permissions audit only. No inventory is collected. Outputs a structured permissions report showing which ARM roles, RBAC assignments, and (optionally) Graph API permissions the current caller has. Use with `-IncludeEntraPermissions` to also audit Entra ID / MS Graph access."
- [x] **20.1.2** Add `[switch]$IncludeEntraPermissions` parameter with `.PARAMETER IncludeEntraPermissions` help block:
  - "Used with `-PermissionAudit`. Extends the audit to include Microsoft Graph permission checks (Entra ID access). Requires a Graph-capable token (interactive user or SPN with Graph API permissions)."
- [x] **20.1.3** Add early-exit branch in main function body:
  ```powershell
  if ($PermissionAudit.IsPresent) {
      Invoke-AZSCPermissionAudit -IncludeEntraPermissions:$IncludeEntraPermissions
      return
  }
  ```
- [x] **20.1.4** Add `.EXAMPLE` blocks:
  - `Invoke-AzureScout -PermissionAudit` — ARM/RBAC audit for current user
  - `Invoke-AzureScout -PermissionAudit -IncludeEntraPermissions` — ARM + Graph audit
  - `Invoke-AzureScout -TenantID <id> -AppId <id> -Secret <secret> -PermissionAudit -IncludeEntraPermissions` — SPN full audit
  - `Invoke-AzureScout -TenantID <id> -PermissionAudit` — check permissions before a full run

### 20.2 — Create `Invoke-AZSCPermissionAudit` (Private Function)

> File: `Modules/Private/Main/Invoke-AZSCPermissionAudit.ps1`
> Builds on existing `Test-AZSCPermissions` function but runs as a standalone audit with richer output and no dependency on a prior subscription/resource collection pass.

- [x] **20.2.1** Create `Invoke-AZSCPermissionAudit` private function with signature:
  ```powershell
  function Invoke-AZSCPermissionAudit {
      Param([switch]$IncludeEntraPermissions)
  }
  ```
- [x] **20.2.2** **ARM / RBAC audit section** (always runs):
  - Get current Azure context (`Get-AzContext`) — display: Account, Tenant ID, Account type (User/ServicePrincipal/ManagedIdentity)
  - Enumerate all accessible subscriptions (`Get-AzSubscription`)
  - For each subscription, check effective role assignments on the subscription scope (`Get-AzRoleAssignment`)
  - Identify key roles: `Reader`, `Contributor`, `Owner`, `Security Reader`, `Monitoring Reader`, `Cost Management Reader`
  - Check Root Management Group access (`Get-AzRoleAssignment -Scope /providers/Microsoft.Management/managementGroups/{tenantId}`)
  - Check if caller can read policy compliance states (`/policyStates`)
  - Check if caller has Security Center read access (`Microsoft.Security/assessments/read`)
  - Output: Table of subscriptions with role assignments and missing critical permissions
  - Flag subscriptions where only partial access exists (e.g., Reader but not Security Reader)
- [x] **20.2.3** **Graph / Entra ID audit section** (`-IncludeEntraPermissions` only):
  - Attempt Graph token acquisition via `Get-AZSCGraphToken`
  - Check token claims / scopes for: `Directory.Read.All`, `User.Read.All`, `Group.Read.All`, `Application.Read.All`, `RoleManagement.Read.Directory`, `Policy.Read.All`, `IdentityRiskyUser.Read.All`, `AuditLog.Read.All`
  - For **service principals**: Parse `scp` (delegated) or `roles` (application) token claims
  - For **users**: Parse `scp` (delegated) token claims AND call `/v1.0/me/transitiveMemberOf` to check directory roles (Global Reader, Directory Readers, etc.)
  - Test actual Graph calls to verify real access (not just token claims — token can say allowed but AAD policy may still block):
    - `GET /v1.0/organization` — basic tenant read
    - `GET /v1.0/users?$top=1` — user read
    - `GET /v1.0/groups?$top=1` — group read
    - `GET /v1.0/applications?$top=1` — application read
    - `GET /v1.0/policies/conditionalAccessPolicies?$top=1` — policy read
  - Output: Table of required Graph permissions with: `Permission`, `Required For`, `Status (✅/⚠️/❌)`, `Notes`
- [x] **20.2.4** **Resource Provider check section** (always runs, ARM scope):
  - For each subscription, check registration status of key providers:
    `Microsoft.Security`, `Microsoft.Insights`, `Microsoft.Maintenance`, `Microsoft.DesktopVirtualization`, `Microsoft.HybridCompute`, `Microsoft.AzureStackHCI`, `Microsoft.MachineLearningServices`, `Microsoft.CognitiveServices`, `Microsoft.Search`, `Microsoft.BotService`, `Microsoft.AlertsManagement`, `Microsoft.OperationalInsights`
  - Output: Table of providers with `Registered/NotRegistered/Registering` status and which inventory modules depend on each
- [x] **20.2.5** **Summary / recommendations section**:
  - Overall readiness: `ARM Only Scan`, `ARM + Entra Scan`, `Partial (limitations noted)`
  - List of specific missing permissions with remediation commands (`New-AzRoleAssignment`, Connect-MgGraph permissions grant)
  - List of unregistered providers with remediation commands (`Register-AzResourceProvider`)
  - Recommended command to run based on current permissions

### 20.3 — Output Formatting for Permission Audit

- [x] **20.3.1** Format ARM results as **colored console table** with ANSI/Write-Host formatting:
  - Green = full access, Yellow = partial access, Red = missing critical access
- [x] **20.3.2** Format Graph results as **colored console table** (same scheme)
- [x] **20.3.3** Write plain-text summary at end with recommended next steps
- [x] **20.3.4** Support `-OutputFormat` from main cmdlet context: if caller passes `-PermissionAudit -OutputFormat Json`, save permission report as `PermissionAudit_<timestamp>.json` alongside where the Excel report normally lands
- [x] **20.3.5** Support `-OutputFormat Markdown` (Phase 21): save as `PermissionAudit_<timestamp>.md` if Markdown export is implemented

### 20.4 — Integration with Existing `Test-AZSCPermissions`

- [x] **20.4.1** Refactor `Test-AZSCPermissions` to call `Invoke-AZSCPermissionAudit` internally (avoid duplicate logic)
- [x] **20.4.2** Keep `Test-AZSCPermissions` as a public function (for users who want to call it directly in their own scripts)
- [x] **20.4.3** Pre-flight check in `Invoke-AzureScout` continues to use `Test-AZSCPermissions` (no change to normal inventory flow)

### 20.5 — Phase 20 Testing

- [ ] **20.5.1** Test: `-PermissionAudit` exits early — no resources extracted, no Excel/JSON created
- [ ] **20.5.2** Test: ARM output shows correct subscription list and role assignments for current user
- [ ] **20.5.3** Test: `-IncludeEntraPermissions` produces Graph permission table
- [ ] **20.5.4** Test: SPN with limited permissions shows yellow/red warnings correctly
- [ ] **20.5.5** Test: SPN with Reader + Security Reader + Monitoring Reader shows all green for ARM
- [ ] **20.5.6** Test: User with Global Reader directory role shows all Graph permissions as green
- [ ] **20.5.7** Test: Resource provider table shows Registered/NotRegistered correctly
- [ ] **20.5.8** Test: `-PermissionAudit -OutputFormat Json` saves JSON permission report
- [x] **20.5.9** Update `CHANGELOG.md` with Phase 20 additions
- [ ] **20.5.10** Commit & push Phase 20

---

## Phase 21 — Markdown & AsciiDoc Export Formats

> **NEW REQUIREMENT:** "export option to export to a markdown formatted report and/or an .adoc formatted file as well since .adoc can be exported to Word and PDF easier."
>
> AsciiDoc (`.adoc`) is the native format for the Antora documentation site already set up in this repo. Asciidoctor can convert `.adoc` → PDF, Word, HTML, DocBook natively. Markdown (`.md`) is the most universally readable plain-text format.

### 21.1 — Extend `-OutputFormat` Parameter

- [x] **21.1.1** Update `[ValidateSet]` for `-OutputFormat` in `Invoke-AzureScout`:
  - Current: `'All', 'Excel', 'Json'`
  - New: `'All', 'Excel', 'Json', 'Markdown', 'AsciiDoc'`
  - `All` still means Excel + JSON (existing behavior); `Markdown` and `AsciiDoc` are additive or standalone
- [x] **21.1.2** Add aliases: `'MD'` → `'Markdown'`, `'Adoc'` → `'AsciiDoc'`
- [x] **21.1.3** Update `.PARAMETER OutputFormat` help block with new values and descriptions:
  - `Markdown` — Generates a `<ReportName>_<timestamp>.md` file. Each resource category becomes a top-level `##` section. Each module's data becomes a table. Suitable for GitHub/GitLab wikis, Obsidian, Confluence.
  - `AsciiDoc` — Generates a `<ReportName>_<timestamp>.adoc` file. Same structure but in AsciiDoc markup. Can be converted to PDF/Word using Asciidoctor: `asciidoctor-pdf report.adoc`. Compatible with Antora for documentation site integration.
- [x] **21.1.4** Add `.EXAMPLE` blocks:
  - `Invoke-AzureScout -OutputFormat Markdown` — Markdown report only
  - `Invoke-AzureScout -OutputFormat AsciiDoc` — AsciiDoc report only
  - `Invoke-AzureScout -OutputFormat Excel,Markdown` — Excel + Markdown
  - `Invoke-AzureScout -OutputFormat Excel,AsciiDoc` — Excel + AsciiDoc (full suite)
  - `Invoke-AzureScout -OutputFormat Json,Markdown,AsciiDoc` — All text formats, no Excel

### 21.2 — Create `Export-AZSCMarkdownReport` (Private Function)

> File: `Modules/Private/Reporting/Export-AZSCMarkdownReport.ps1`

- [x] **21.2.1** Create function with signature:
  ```powershell
  function Export-AZSCMarkdownReport {
      Param($SmaResources, $File, $Subscriptions, $TenantId, $ReportStartTime)
  }
  ```
- [x] **21.2.2** **Report header section**:
  ```markdown
  # Azure Tenant Inventory Report
  Generated: <timestamp>  Tenant: <tenantId>  Tool: AzureScout v<version>
  Subscriptions: <count>  Total Resources: <count>
  ```
- [x] **21.2.3** **Table of Contents** — auto-generated from categories and modules that have data:
  ```markdown
  ## Table of Contents
  - [Compute](#compute)
    - [Virtual Machines](#virtual-machines)
    - [VM Scale Sets](#vm-scale-sets)
  - [Networking](#networking)
  ...
  ```
- [x] **21.2.4** **Per-category sections** (`## <CategoryName>`) with per-module subsections (`### <Module Display Name>`):
  - Each module's data rendered as a GitHub-Flavored Markdown table (pipe-delimited)
  - Skip modules with zero rows
  - Column widths auto-sized to content
  - Example format:
    ```markdown
    ### Virtual Machines
    | Name | Resource Group | Location | OS | SKU | Status |
    |------|---------------|----------|----|-----|--------|
    | vm01 | rg-prod        | eastus   | Windows | Standard_D4s_v3 | Running |
    ```
- [x] **21.2.5** **Summary section** at end:
  - Total resources by category (table)
  - Empty categories listed separately
  - Report generation time elapsed
- [x] **21.2.6** Write final `.md` file using `Out-File -Encoding UTF8` to `$File` path (replacing `.xlsx` extension with `.md`)
- [x] **21.2.7** Support large datasets: use streaming/append (`Add-Content`) rather than building full string in memory for tenants with 10,000+ resources

### 21.3 — Create `Export-AZSCAsciiDocReport` (Private Function)

> File: `Modules/Private/Reporting/Export-AZSCAsciiDocReport.ps1`

- [x] **21.3.1** Create function with signature (same as Markdown):
  ```powershell
  function Export-AZSCAsciiDocReport {
      Param($SmaResources, $File, $Subscriptions, $TenantId, $ReportStartTime)
  }
  ```
- [x] **21.3.2** **Document header** with AsciiDoc front matter:
  ```asciidoc
  = Azure Tenant Inventory Report
  AzureScout Contributors
  :doctype: book
  :toc: left
  :toclevels: 3
  :sectnums:
  :source-highlighter: highlight.js
  Generated: {localdate}
  ```
- [x] **21.3.3** **Tenant summary preamble**:
  ```asciidoc
  == Tenant Summary
  [cols="1,3"]
  |===
  | Tenant ID | <tenantId>
  | Subscriptions | <count>
  | Total Resources | <count>
  | Report Date | <timestamp>
  |===
  ```
- [x] **21.3.4** **Per-category sections** (`== <CategoryName>`) with per-module subsections (`=== <Module Display Name>`):
  - AsciiDoc table syntax for each module's data:
    ```asciidoc
    === Virtual Machines
    [cols="1,1,1,1,1,1",options="header"]
    |===
    | Name | Resource Group | Location | OS | SKU | Status
    | vm01 | rg-prod | eastus | Windows | Standard_D4s_v3 | Running
    |===
    ```
  - Skip modules with zero rows
- [x] **21.3.5** **AsciiDoc-specific features**:
  - Use `[WARNING]` admonition for resources with issues (e.g., VMs with no backup, expired certs)
  - Use `[TIP]` admonition for Advisor recommendations
  - Use `[IMPORTANT]` admonition for security findings (Defender alerts, non-compliant policies)
  - Use `[NOTE]` for skipped/empty categories
- [x] **21.3.6** Write final `.adoc` file to `$File` path (replacing `.xlsx` extension with `.adoc`)
- [x] **21.3.7** Add `asciidoctor` conversion hint in report footer:
  ```asciidoc
  [NOTE]
  ====
  To convert this report to PDF: `asciidoctor-pdf AzureScout_2026-02-24.adoc`
  To convert to Word (via Pandoc): `pandoc -f asciidoc -t docx AzureScout_2026-02-24.adoc -o report.docx`
  ====
  ```

### 21.4 — Wire Into Reporting Orchestration

> File: `Modules/Private/Main/Start-AZSCReporOrchestration.ps1` (note: existing file has typo "Repor")

- [x] **21.4.1** Pass `$OutputFormat` through to `Start-AZSCReporOrchestration`
- [x] **21.4.2** Add conditional blocks after Excel/JSON generation:
  ```powershell
  if ($OutputFormat -contains 'Markdown' -or $OutputFormat -contains 'All') {
      Export-AZSCMarkdownReport -SmaResources $SmaResources -File $File ...
  }
  if ($OutputFormat -contains 'AsciiDoc' -or $OutputFormat -contains 'All') {
      Export-AZSCAsciiDocReport -SmaResources $SmaResources -File $File ...
  }
  ```
  > Note: `All` behavior — decide whether `All` should always include Markdown/AsciiDoc or only Excel+JSON. **Recommendation:** Keep `All` = Excel+JSON (existing behavior). Markdown and AsciiDoc are opt-in additions. Update `All` alias to mean "all currently selected formats."
- [x] **21.4.3** Add both new functions to `AzureScout.psm1` auto-loader
- [x] **21.4.4** Add both functions to `FunctionsToExport` in `AzureScout.psd1` (or keep as private — decide)

### 21.5 — Permission Audit Markdown/AsciiDoc Output (Cross-phase)

- [x] **21.5.1** When `-PermissionAudit -OutputFormat Markdown` — call `Export-AZSCMarkdownReport` with permission audit data (special permission audit mode generates a Markdown permissions report)
- [x] **21.5.2** When `-PermissionAudit -OutputFormat AsciiDoc` — generate `.adoc` permissions report suitable for inclusion in team documentation or Antora site

### 21.6 — Phase 21 Testing

- [ ] **21.6.1** Test: `-OutputFormat Markdown` generates valid `.md` file with correct structure
- [ ] **21.6.2** Test: `-OutputFormat AsciiDoc` generates valid `.adoc` file with AsciiDoc syntax
- [ ] **21.6.3** Test: Markdown tables render correctly in GitHub (pipe-table format)
- [ ] **21.6.4** Test: AsciiDoc can be converted to PDF without errors (`asciidoctor-pdf` command)
- [ ] **21.6.5** Test: AsciiDoc can be converted to Word via Pandoc (`pandoc -f asciidoc -t docx`)
- [ ] **21.6.6** Test: `-OutputFormat Excel,AsciiDoc` generates BOTH `.xlsx` and `.adoc` files
- [ ] **21.6.7** Test: Modules with zero resources are skipped in Markdown/AsciiDoc output
- [ ] **21.6.8** Test: Large tenant (1000+ VMs) Markdown output streams correctly without OOM error
- [ ] **21.6.9** Test: AsciiDoc admonitions (`[WARNING]`, `[TIP]`) appear for security findings and recommendations
- [ ] **21.6.10** Test: `-PermissionAudit -OutputFormat Markdown` generates a permissions `.md` report
- [x] **21.6.11** Update `CHANGELOG.md` with Phase 21 additions
- [ ] **21.6.12** Commit & push Phase 21

---

## Post-Implementation

- [ ] Push to GitHub (`thisismydemo/azure-scout`)
- [ ] Tag release `v2.0.0` (major version for breaking changes + category filtering)
- [ ] Publish to PSGallery
- [ ] Update thisismydemo references to point to new repo

---

**Version Control**
- Created: 2026-02-22 by AzureScout Contributors
- Last Edited: 2026-02-24 by AzureScout Contributors
- Version: 3.0.0
- Tags: todo, tracking, implementation, azure-local, arc, vpn, policy, defender, monitor, dcr, management-groups, subscriptions, scope, permissions, resource-providers, monitoring-coverage, ai-foundry, machine-learning, avd, category-filtering, vm-enhancement, ms-graph, final-testing, permission-audit, markdown-export, asciidoc-export
- Keywords: azure-scout, progress, checklist, feature-parity, excel-restructure, comprehensive-logging, authentication, documentation, comprehensive-coverage, microsoft-taxonomy, acceptance-testing, permission-report, markdown, adoc, asciidoctor
- Author: AzureScout Contributors
