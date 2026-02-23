# Azure Inventory Tool — TODO Tracker

> Track implementation progress. Update status as work is completed.
> See [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md) for full details on each item.

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

- [ ] **0.1** Rename `AzureResourceInventory.psd1` → `AzureInventory.psd1`
- [ ] **0.2** Rename `AzureResourceInventory.psm1` → `AzureInventory.psm1`
- [ ] **0.3** Update manifest: version `1.0.0`, new GUID, new author, new exports
- [ ] **0.4** Update PSM1 loader (reference new filename)
- [ ] **0.5** Create `LICENSE` (MIT)
- [ ] **0.6** Create proper `.gitignore`
- [ ] **0.7** Create `CHANGELOG.md`
- [ ] **0.8** Delete `Modules/Private/4.RAMPFunctions/` (entire directory)
- [ ] **0.9** Remove `Invoke-AzureRAMPInventory` from manifest and public functions
- [ ] **0.10** Remove auto-update logic from entry point
- [ ] **0.11** Remove `Remove-ARIExcelProcess` function
- [ ] **0.12** Commit Phase 0

---

## Phase 1 — Global Rename (ARI → AZI)

- [ ] **1.1** Rename all `*-ARI*` functions to `*-AZI*` (~40 functions)
- [ ] **1.2** Rename entry point: `Invoke-ARI.ps1` → `Invoke-AzureInventory.ps1`
- [ ] **1.3** Update all string/log references from `ARI` to `AZI`/`AzureInventory`
- [ ] **1.4** Update default paths: `AzureResourceInventory` → `AzureInventory`
- [ ] **1.5** Update all internal function call sites
- [ ] **1.6** Update manifest `FunctionsToExport` with new names
- [ ] **1.7** Verify module loads: `Import-Module ./AzureInventory.psd1`
- [ ] **1.8** Commit Phase 1

---

## Phase 2 — Auth Refactor

- [ ] **2.1** Rewrite `Connect-AZILoginSession` with 5 auth methods (current-user default)
- [ ] **2.2** Create `Get-AZIGraphToken` (token acquisition via `Get-AzAccessToken -ResourceTypeName MSGraph`)
- [ ] **2.3** Create `Invoke-AZIGraphRequest` (REST wrapper with pagination + throttle handling)
- [ ] **2.4** Add `-TenantID`, `-AppId`, `-Secret`, `-CertificatePath`, `-CertificatePassword`, `-DeviceLogin` params to `Invoke-AzureInventory`
- [ ] **2.5** Add `-Scope` parameter (`All`, `ArmOnly`, `EntraOnly`) to `Invoke-AzureInventory`
- [ ] **2.6** Test: current-user auth (interactive)
- [ ] **2.7** Test: SPN + secret auth
- [ ] **2.8** Commit Phase 2

---

## Phase 3 — Pre-Flight Permission Checker

- [ ] **3.1** Create `Test-AZIPermissions` public function
- [ ] **3.2** Implement ARM permission checks (subscription enumeration, role assignment)
- [ ] **3.3** Implement Graph permission checks (organization, users, CA policies)
- [ ] **3.4** Create structured result object with remediation guidance
- [ ] **3.5** Integrate into `Invoke-AzureInventory` (auto-run, warn-only)
- [ ] **3.6** Add `-SkipPermissionCheck` switch
- [ ] **3.7** Commit Phase 3

---

## Phase 4 — Entra ID Extraction Layer

- [ ] **4.1** Create `Start-AZIEntraExtraction` function
- [ ] **4.2** Implement Graph queries for all 15 Entra resource types
- [ ] **4.3** Normalize responses with synthetic `TYPE` property (`entra/*`)
- [ ] **4.4** Update `Start-AZIExtractionOrchestration` to call Entra extraction
- [ ] **4.5** Merge Entra resources into main `$Resources` array
- [ ] **4.6** Wire `-Scope` parameter through extraction pipeline
- [ ] **4.7** Test: Entra extraction standalone
- [ ] **4.8** Commit Phase 4

---

## Phase 5 — Entra ID Inventory Modules (15 new)

- [ ] **5.1** Create `Modules/Public/InventoryModules/Identity/` directory
- [ ] **5.2** `Users.ps1` — User inventory module
- [ ] **5.3** `Groups.ps1` — Group inventory module
- [ ] **5.4** `AppRegistrations.ps1` — App registrations module
- [ ] **5.5** `ServicePrincipals.ps1` — Service principals module
- [ ] **5.6** `ManagedIdentities.ps1` — Managed identities module
- [ ] **5.7** `DirectoryRoles.ps1` — Directory roles module
- [ ] **5.8** `PIMAssignments.ps1` — PIM assignments module
- [ ] **5.9** `ConditionalAccess.ps1` — Conditional Access policies module
- [ ] **5.10** `NamedLocations.ps1` — Named locations module
- [ ] **5.11** `AdminUnits.ps1` — Admin units module
- [ ] **5.12** `Domains.ps1` — Domains module
- [ ] **5.13** `Licensing.ps1` — License/SKU inventory module
- [ ] **5.14** `CrossTenantAccess.ps1` — Cross-tenant access settings module
- [ ] **5.15** `SecurityPolicies.ps1` — Security defaults + auth policy module
- [ ] **5.16** `RiskyUsers.ps1` — Risky users module
- [ ] **5.17** Register Identity modules in processing/reporting pipeline
- [ ] **5.18** Test: Full run with Entra modules producing Excel worksheets
- [ ] **5.19** Commit Phase 5

---

## Phase 6 — JSON Output Layer

- [ ] **6.1** Create `Export-AZIJsonReport` function
- [ ] **6.2** Implement structured JSON schema with metadata envelope
- [ ] **6.3** Add `-OutputFormat` parameter (`All`, `Excel`, `Json`) to `Invoke-AzureInventory`
- [ ] **6.4** Wire into `Start-AZIReportOrchestration`
- [ ] **6.5** Test: JSON-only output
- [ ] **6.6** Test: Dual output (Excel + JSON)
- [ ] **6.7** Commit Phase 6

---

## Phase 7 — Cleanup & Polish

- [ ] **7.1** Update default report paths (Windows + Linux/Mac)
- [ ] **7.2** Rewrite `README.md` with full documentation
- [ ] **7.3** Create Pester tests: `Test-AZIPermissions.Tests.ps1`
- [ ] **7.4** Create Pester tests: `Invoke-AzureInventory.Tests.ps1`
- [ ] **7.5** Create Pester tests: `Connect-AZILoginSession.Tests.ps1`
- [ ] **7.6** Create Pester tests: `Invoke-AZIGraphRequest.Tests.ps1`
- [ ] **7.7** Create Pester tests: `Start-AZIEntraExtraction.Tests.ps1`
- [ ] **7.8** Update `CHANGELOG.md` with all changes
- [ ] **7.9** Final module load + smoke test
- [ ] **7.10** Commit Phase 7

---

## Post-Implementation

- [ ] Push to GitHub (`thisismydemo/azure-inventory`)
- [ ] Tag release `v1.0.0`
- [ ] Publish to PSGallery
- [ ] Update prodtechlabmgmt references to point to new repo

---

**Version Control**
- Created: 2026-02-22 by Product Technology Team
- Last Edited: 2026-02-22 by Product Technology Team
- Version: 1.0.0
- Tags: todo, tracking, implementation
- Keywords: azure-inventory, progress, checklist
- Author: Product Technology Team
