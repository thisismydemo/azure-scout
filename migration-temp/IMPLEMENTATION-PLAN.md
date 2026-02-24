# Azure Inventory Tool — Implementation Plan

## Overview

Transform [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11 into **AzureTenantInventory** — a generic, single-tenant Azure + Entra ID inventory tool. Publishes as a PowerShell module to PSGallery and as a standalone GitHub repo (`thisismydemo/azure-inventory`).

**Key differentiators vs ARI:**

- Entra ID (Azure AD) inventory — 15 identity resource modules (users, groups, apps, CA policies, PIM, etc.)
- JSON output alongside Excel
- Pre-flight permission checker with remediation guidance
- No Microsoft Graph SDK dependency — uses `Get-AzAccessToken -ResourceTypeName MSGraph` + REST
- Current-user auth as default (no flags needed if already logged in)
- Single tenant per run — simple, predictable, composable

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Tenancy** | Single tenant per run | Simplicity. Multi-tenant orchestration belongs in the consuming environment, not the tool. |
| **Default auth** | Current user (`Get-AzContext`) | Zero-friction. If you're logged in, just run it. |
| **Graph auth** | `Get-AzAccessToken -ResourceTypeName MSGraph` + `Invoke-RestMethod` | Avoids MgGraph SDK dependency (7+ modules, version conflicts). Az.Accounts already installed. |
| **SPN support** | Optional — `-AppId`/`-Secret`/`-CertificatePath` | For CI/CD pipelines and automation. Not the default. |
| **Pre-flight check** | Warn-only, auto-runs | Users may intentionally run with partial permissions for partial results. |
| **Output format** | Excel + JSON (both by default) | Excel for humans, JSON for automation/downstream tools. |
| **Module prefix** | `AZTI` (AzureTenantInventory) | Distinct from ARI to avoid confusion. |
| **Entra modules** | Same two-phase pattern as ARM modules | Entra data flows through the existing extraction→processing→reporting pipeline unchanged. |
| **Diagrams** | Keep ARI's draw.io diagram feature | Valuable and self-contained. |
| **RAMP** | Remove | Microsoft-internal, not useful for generic tool. |
| **Auto-update** | Remove | Users install via PSGallery or git clone — self-update is surprising behavior. |

## Required PowerShell Modules

| Module | Purpose | Required? |
|---|---|---|
| `Az.Accounts` | Authentication, token acquisition | **Yes** |
| `Az.ResourceGraph` | ARM resource extraction (batch KQL) | **Yes** (ARM scope) |
| `Az.Compute` | VM SKU/quota details | **Yes** (ARM scope) |
| `Az.Storage` | Upload report to storage account | Optional (only with `-StorageAccount`) |
| `ImportExcel` | Excel report generation | **Yes** (Excel output) |

**NOT required:** Any `Microsoft.Graph.*` module.

## Minimum Azure Permissions

### ARM (for `-Scope All` or `-Scope ArmOnly`)

| Role | Scope | Purpose |
|---|---|---|
| `Reader` | Subscription(s) | Read all ARM resources |

### Microsoft Graph (for `-Scope All` or `-Scope EntraOnly`)

| Permission | Type | Purpose |
|---|---|---|
| `Directory.Read.All` | Delegated or Application | Users, groups, roles, admin units, org |
| `Policy.Read.All` | Delegated or Application | Conditional Access, named locations, auth policy |
| `IdentityRiskyUser.Read.All` | Delegated or Application | Risky users (optional) |
| `RoleManagement.Read.Directory` | Delegated or Application | PIM assignments |

For current-user auth, these are **tenant-level consent** permissions. For SPN auth, grant them in **App Registration > API Permissions**.

---

## Phase 0 — Repository Scaffold & Rename

### 0.1 — Rename Module Files

| From | To |
|---|---|
| `AzureResourceInventory.psd1` | `AzureTenantInventory.psd1` |
| `AzureResourceInventory.psm1` | `AzureTenantInventory.psm1` |

### 0.2 — Update Module Manifest (`AzureTenantInventory.psd1`)

- New `ModuleVersion` = `1.0.0`
- New `GUID` (generate fresh)
- `RootModule` = `AzureTenantInventory.psm1`
- `Author` / `CompanyName` = `thisismydemo`
- `Description` = updated
- `RequiredModules` = `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`, `Az.Compute`
- Remove `Microsoft.Graph.*` from any dependency lists
- Rename all exported function names: `*-ARI*` → `*-AZTI*`
- Add new exports: `Invoke-AzureTenantInventory`, `Test-AZTIPermissions`

### 0.3 — Update PSM1 Loader (`AzureTenantInventory.psm1`)

- Verify dot-source paths still work (relative — should be fine)
- No functional changes needed beyond filename

### 0.4 — Repository Scaffolding

Create:
- `LICENSE` (MIT)
- `CHANGELOG.md`
- `.gitignore` (`.env`, `*.xlsx`, output dirs, cache dirs, `node_modules`)
- `docs/` directory with this plan
- `tests/` directory scaffold
- Updated `README.md`

### 0.5 — Remove ARI-Specific Features

- Delete `Modules/Private/4.RAMPFunctions/` directory and all contents
- Remove `Invoke-AzureRAMPInventory` from manifest exports and Public functions
- Remove auto-update logic from `Invoke-ARI.ps1` (the `Update-Module` call)
- Remove `Remove-ARIExcelProcess` (kills stale Excel.exe — too aggressive)

---

## Phase 1 — Global Rename (ARI → AZTI)

### 1.1 — Function Name Renames

Every function with `ARI` in the name gets renamed to `AZTI`. Key renames:

| Original | New |
|---|---|
| `Invoke-ARI` | `Invoke-AzureTenantInventory` |
| `Connect-ARILoginSession` | `Connect-AZTILoginSession` |
| `Start-ARIExtractionOrchestration` | `Start-AZTIExtractionOrchestration` |
| `Start-ARIGraphExtraction` | `Start-AZTIGraphExtraction` |
| `Invoke-ARIInventoryLoop` | `Invoke-AZTIInventoryLoop` |
| `Get-ARIAPIResources` | `Get-AZTIAPIResources` |
| `Get-ARICostInventory` | `Get-AZTICostInventory` |
| `Get-ARIManagementGroups` | `Get-AZTIManagementGroups` |
| `Get-ARISubscriptions` | `Get-AZTISubscriptions` |
| `Start-ARIProcessOrchestration` | `Start-AZTIProcessOrchestration` |
| `Start-ARIProcessJob` | `Start-AZTIProcessJob` |
| `Start-ARIAutProcessJob` | `Start-AZTIAutProcessJob` |
| `Build-ARICacheFiles` | `Build-AZTICacheFiles` |
| `Start-ARIExtraJobs` | `Start-AZTIExtraJobs` |
| `Invoke-ARISubJob` | `Invoke-AZTISubJob` |
| `Start-ARIReporOrchestration` | `Start-AZTIReportOrchestration` |
| `Start-ARIExcelJob` | `Start-AZTIExcelJob` |
| `Start-ARIExcelExtraData` | `Start-AZTIExcelExtraData` |
| `Start-ARIExtraReports` | `Start-AZTIExtraReports` |
| `Start-ARIExcelCustomization` | `Start-AZTIExcelCustomization` |
| `Build-ARIAdvisoryReport` | `Build-AZTIAdvisoryReport` |
| `Build-ARIPolicyReport` | `Build-AZTIPolicyReport` |
| `Build-ARIQuotaReport` | `Build-AZTIQuotaReport` |
| `Build-ARISecCenterReport` | `Build-AZTISecCenterReport` |
| `Build-ARISubsReport` | `Build-AZTISubsReport` |
| `Set-ARIFolder` | `Set-AZTIFolder` |
| `Set-ARIReportPath` | `Set-AZTIReportPath` |
| `Test-ARIPS` | `Test-AZTIPS` |
| `Clear-ARIMemory` | `Clear-AZTIMemory` |
| `Clear-ARICacheFolder` | `Clear-AZTICacheFolder` |
| `Get-ARIUnsupportedData` | `Get-AZTIUnsupportedData` |
| `Out-ARIReportResults` | `Out-AZTIReportResults` |
| `Wait-ARIJob` | `Wait-AZTIJob` |
| All diagram functions | `*-ARI*` → `*-AZTI*` |
| All advisory/policy/security job functions | `*-ARI*` → `*-AZTI*` |

### 1.2 — String/Variable/Path Renames

| Pattern | Replacement |
|---|---|
| `AzureResourceInventory` (in strings, paths, logs) | `AzureTenantInventory` |
| `C:\AzureResourceInventory` (default path) | `C:\AzureTenantInventory` |
| `$HOME/AzureResourceInventory` | `$HOME/AzureTenantInventory` |
| `ARI` in log/Write-Host messages | `AZTI` or `AzureTenantInventory` |
| Job names like `'ResourceJob_'` | Keep as-is (internal, not user-facing) |

### 1.3 — File Renames

| Original | New |
|---|---|
| `Modules/Public/PublicFunctions/Invoke-ARI.ps1` | `Modules/Public/PublicFunctions/Invoke-AzureTenantInventory.ps1` |

All other `.ps1` filenames stay as-is (they don't include `ARI` in the filename, only in the function name inside).

---

## Phase 1B — Repository Structure Review & Reorganization

Before adding new features (auth, Entra, JSON output), evaluate whether the inherited ARI folder layout is the optimal structure for AzureTenantInventory going forward. Reorganizing **before** Phase 2 avoids moving newly written code later.

### 1B.1 — Audit Current Structure

The repo currently uses ARI's original layout:

```
/
├── AzureTenantInventory.psd1          # Module manifest (root)
├── AzureTenantInventory.psm1          # Module loader (root)
├── Modules/
│   ├── Private/
│   │   ├── 0.MainFunctions/           # Numbered — orchestration, auth, config
│   │   ├── 1.ExtractionFunctions/     # Numbered — Resource Graph queries
│   │   ├── 2.ProcessingFunctions/     # Numbered — data transform/cache
│   │   ├── 3.ReportingFunctions/      # Numbered — Excel generation
│   │   ├── 4.RAMPFunctions/           # REMOVED (Phase 0)
│   │   └── LegacyFunctions/           # Deprecated functions
│   └── Public/
│       ├── PublicFunctions/            # Entry points (Invoke-AzureTenantInventory, etc.)
│       └── InventoryModules/           # 86 ARM resource modules in 16 category folders
│           ├── AI/ (14)               ├── Analytics/ (6)
│           ├── APIs/ (5)              ├── Compute/ (7)
│           ├── Container/ (6)         ├── Database/ (12)
│           ├── Hybrid/ (1)            ├── Integration/ (2)
│           ├── IoT/ (1)               ├── Management/ (3)
│           ├── Monitoring/ (2)        ├── Network_1/ (10)
│           ├── Network_2/ (10)        ├── Security/ (1)
│           ├── Storage/ (2)           └── Web/ (2)
├── azure-pipelines/                   # ARI CI/CD YAML (Microsoft-specific)
├── docs/                              # MkDocs site content (inherited from ARI)
├── images/                             # Screenshots and diagrams
├── migration-temp/                    # Implementation plan & TODO
├── tests/                             # Pester tests
└── .github/                           # GitHub Actions, issue templates
```

### 1B.2 — Finalized Decisions

All decisions resolved. Implementation follows the 15-step plan below.

| Area | Decision | Rationale |
|---|---|---|
| **Numbered Private folders** | **Drop numbers** → `Main/`, `Extraction/`, `Processing/`, `Reporting/` | PSM1 loader uses `Get-ChildItem -Recurse *.ps1` — folder names are cosmetic, numbering adds no value. |
| **Network_1 / Network_2 split** | **Merge** into single `Network/` (20 files) | Split was arbitrary alphabetical overflow (ARI inherited), not a logical boundary. |
| **Hybrid/** | **Keep `Hybrid/`** — all Arc modules land here | `Hybrid/` is the correct semantic category for Azure Arc resources. Phase 8.2 new modules (`ArcGateways.ps1`, `ArcKubernetes.ps1`, etc.) go into `Hybrid/`, not a new `ArcServices/` folder. |
| **Module manifest location** | **Keep in root** (PSGallery standard) | Moving to `src/` breaks convention and requires `RootModule` path workarounds. |
| **`azure-pipelines/`** | **Delete** | Microsoft ADO-specific CI/CD. Already rebranded but irrelevant — own CI/CD goes in `.github/workflows/`. |
| **`docs/` content** | **Gut now**, restructure for Antora | Inherited ARI MkDocs content (`site_author: Microsoft`) is misleading. Delete inherited content, set up Antora directory structure, convert to AsciiDoc. |
| **`images/`** | **Move under `docs/modules/ROOT/images/`** | Antora standard location. Root `images/` duplicates `docs/images/` — consolidate into one place. |
| **`migration-temp/`** | **Keep as `.md`** during development | Temporary working files. Delete before v1.0.0 release. No AsciiDoc conversion needed. |
| **`LegacyFunctions/`** | **Delete** | 6 `.ps2` files — intentionally unloaded (PSM1 only loads `*.ps1`). No value as reference. |
| **Test organization** | **Keep flat** | Low test count (planned ~5 files). Mirror structure adds complexity with no benefit at this scale. |
| **AsciiDoc conversion** | **Convert docs content to `.adoc`** | Antora requires AsciiDoc. GitHub convention files (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, etc.) and `migration-temp/` stay as Markdown. |

### 1B.3 — Implementation Steps

#### Step 1: Delete `4.RAMPFunctions/` (Verify Phase 0)

Phase 0.8 marked this complete, but verify the directory is actually gone. If it still exists (contains `FedRAMP-Inventory-Template.xlsx`, `StateRAMP-Inventory-Template.xlsx`), delete it now:

```bash
git rm -r Modules/Private/4.RAMPFunctions/
```

#### Step 2: Drop Numbered Prefixes from Private Folders

Rename using `git mv`:

| From | To |
|---|---|
| `Modules/Private/0.MainFunctions/` | `Modules/Private/Main/` |
| `Modules/Private/1.ExtractionFunctions/` | `Modules/Private/Extraction/` |
| `Modules/Private/2.ProcessingFunctions/` | `Modules/Private/Processing/` |
| `Modules/Private/3.ReportingFunctions/` | `Modules/Private/Reporting/` |

No PSM1 loader changes needed — `Get-ChildItem -Recurse *.ps1` discovers files regardless of folder names.

#### Step 3: Merge Network_1 + Network_2 → Network

```bash
git mv Modules/Public/InventoryModules/Network_1/* Modules/Public/InventoryModules/Network/
git mv Modules/Public/InventoryModules/Network_2/* Modules/Public/InventoryModules/Network/
git rm -r Modules/Public/InventoryModules/Network_1/
git rm -r Modules/Public/InventoryModules/Network_2/
```

Resulting `Network/` folder: 20 files. InventoryModules are loaded dynamically at runtime (not dot-sourced by PSM1), so no loader changes needed.

#### Step 4: Keep Hybrid/ as Arc Category

No structural change. `Hybrid/ARCServers.ps1` stays where it is. Phase 8.2 new modules land in `Hybrid/`:

- `Hybrid/ArcGateways.ps1`
- `Hybrid/ArcKubernetes.ps1`
- `Hybrid/ArcResourceBridge.ps1`
- `Hybrid/ArcExtensions.ps1`

#### Step 5: Keep Module Manifest in Root

No change. `AzureTenantInventory.psd1` and `.psm1` stay in repo root per PSGallery convention.

#### Step 6: Delete `azure-pipelines/`

```bash
git rm -r azure-pipelines/
```

Own CI/CD will be GitHub Actions in `.github/workflows/` (Phase 7).

#### Step 7: Gut `docs/` — Set Up Antora Structure

Delete all inherited ARI MkDocs content:

```bash
git rm docs/mkdocs.yml
git rm docs/requirements.txt
git rm -r docs/docs/        # MkDocs source content
```

Create Antora directory structure:

```
docs/
├── antora.yml              # Component descriptor
└── modules/
    └── ROOT/
        ├── nav.adoc        # Navigation file
        ├── pages/          # AsciiDoc content (.adoc files)
        └── images/         # All images and diagrams
```

Create `docs/antora.yml`:

```yaml
name: azure-tenant-inventory
title: Azure Tenant Inventory
version: ~
nav:
  - modules/ROOT/nav.adoc
```

Create `antora-playbook.yml` in repo root:

```yaml
site:
  title: Azure Tenant Inventory Documentation
  url: https://thisismydemo.github.io/azure-inventory
  start_page: azure-tenant-inventory::index.adoc
content:
  sources:
    - url: .
      branches: main
      start_path: docs
ui:
  bundle:
    url: https://gitlab.com/antora/antora-ui-default/-/jobs/artifacts/HEAD/raw/build/ui-bundle.zip?job=bundle-stable
    snapshot: true
```

#### Step 8: Consolidate Images

Move all images into Antora's standard image location:

```bash
# Move root images/ content (ARI screenshots with renamed filenames)
git mv images/* docs/modules/ROOT/images/
git rm -r images/

# Move any remaining docs/images/ content
git mv docs/images/* docs/modules/ROOT/images/  # if exists after Step 7 cleanup
```

Audit and remove any ARI-specific screenshots that no longer apply.

#### Step 9: Keep `migration-temp/` as Markdown

No changes. These are temporary working files (this plan, TODO.md). They stay as `.md` and will be deleted before v1.0.0 release.

#### Step 10: Delete `LegacyFunctions/`

```bash
git rm -r Modules/Private/LegacyFunctions/
```

Files being removed (all `.ps2`, unused):

- `Build-AZTILargeReportResources.ps2`
- `Start-AZTIAutResourceJob.ps2`
- `Start-AZTILargeEnvOrderFiles.ps2`
- `Start-AZTIResourceJobs.ps2`
- `Start-AZTIResourceReporting.ps2`
- `VisioDiagram.ps2`

#### Step 11: Keep Tests Flat

No changes to `tests/` structure. New test files in Phase 7 go directly in `tests/`.

#### Step 12: Clean Root Clutter

Delete ARI-inherited root files that serve no purpose:

```bash
git rm HowTo.md
git rm test-graphmod.sh
git rm test-login-code-graph.sh
git rm test-login-code.sh
git rm test-login-secret.sh
git rm test-login.sh
git rm workflow_dispatch.json
```

#### Step 13: Convert Documentation to AsciiDoc

Convert relevant `.md` documentation files to `.adoc` format and place in `docs/modules/ROOT/pages/`:

**Files to convert:**

- Any new documentation written for AZTI (getting started, auth guide, module catalog, etc.)
- `CREDITS.md` → `docs/modules/ROOT/pages/credits.adoc` (when created in Phase 7)

**Files that stay as Markdown (.md):**

- `README.md` (GitHub convention)
- `CHANGELOG.md` (GitHub convention)
- `CONTRIBUTING.md` (GitHub convention, when created)
- `CODE_OF_CONDUCT.md` (GitHub convention, when created)
- `SECURITY.md` (GitHub convention, when created)
- `SUPPORT.md` (GitHub convention, when created)
- `.github/` templates (issue, PR)
- `migration-temp/*.md` (temporary)

#### Step 14: Validate

1. Module loads: `Import-Module ./AzureTenantInventory.psd1 -Force` — expect 13 public functions
2. Run Pester smoke tests: `Invoke-Pester tests/`
3. Verify `Get-Command -Module AzureTenantInventory` lists all expected functions
4. Spot-check InventoryModules discovery: confirm `Network/` files are found at runtime

#### Step 15: Document & Commit

1. Create `docs/modules/ROOT/pages/folder-structure.adoc` documenting the final layout and decisions
2. Commit: `refactor: Phase 1B — reorganize folder structure, Antora/AsciiDoc, delete legacy`

### 1B.4 — Target Structure After Phase 1B

```
/
├── AzureTenantInventory.psd1          # Module manifest (root — PSGallery standard)
├── AzureTenantInventory.psm1          # Module loader (root)
├── antora-playbook.yml                # Antora site playbook
├── Modules/
│   ├── Private/
│   │   ├── Main/                      # Orchestration, auth, config
│   │   ├── Extraction/                # Resource Graph queries
│   │   ├── Processing/                # Data transform/cache
│   │   └── Reporting/                 # Excel generation
│   └── Public/
│       ├── PublicFunctions/            # Entry points (Invoke-AzureTenantInventory, etc.)
│       └── InventoryModules/           # ARM resource modules in category folders
│           ├── AI/ (14)               ├── Analytics/ (6)
│           ├── APIs/ (5)              ├── Compute/ (7)
│           ├── Container/ (6)         ├── Database/ (12)
│           ├── Hybrid/ (1+)           ├── Integration/ (2)
│           ├── IoT/ (1)               ├── Management/ (3)
│           ├── Monitoring/ (2)        ├── Network/ (20)
│           ├── Security/ (1)          ├── Storage/ (2)
│           └── Web/ (2)
├── docs/
│   ├── antora.yml                     # Antora component descriptor
│   └── modules/
│       └── ROOT/
│           ├── nav.adoc               # Navigation file
│           ├── pages/                 # AsciiDoc content (.adoc)
│           └── images/                # All images and diagrams
├── migration-temp/                    # Implementation plan & TODO (.md, temporary)
├── tests/                             # Pester tests (flat)
└── .github/                           # GitHub Actions, issue templates
```

---

## Phase 2 — Auth Refactor

### 2.1 — Rewrite `Connect-AZTILoginSession`

**File:** `Modules/Private/0.MainFunctions/Connect-ARILoginSession.ps1` (rename to keep filename or rename)

**New auth priority (5 methods):**

```
Priority 1: Managed Identity (-Automation flag, handled in Invoke-AzureTenantInventory)
   → Connect-AzAccount -Identity

Priority 2: SPN + Certificate (-AppId + -Secret + -CertificatePath)
   → Connect-AzAccount -ServicePrincipal -TenantId -ApplicationId -CertificatePath -CertificatePassword

Priority 3: SPN + Secret (-AppId + -Secret, no cert)
   → Connect-AzAccount -ServicePrincipal -TenantId -Credential (PSCredential)

Priority 4: Device Code (-DeviceLogin)
   → Connect-AzAccount -UseDeviceAuthentication [-Tenant]

Priority 5: Current User (DEFAULT — no flags)
   → Check Get-AzContext → validate with Get-AzSubscription
   → If valid for target tenant → use as-is
   → If not → Connect-AzAccount -Tenant $TenantID (interactive)
```

**Key change:** Priority 5 is the happy path. No flags needed if already authenticated.

### 2.2 — New: `Get-AZTIGraphToken`

**File:** `Modules/Private/0.MainFunctions/Get-AZTIGraphToken.ps1` (NEW)

```powershell
function Get-AZTIGraphToken {
    # Uses Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
    # Returns @{ 'Authorization' = "Bearer $plainToken"; 'Content-Type' = 'application/json' }
    # Caches in script-scope variable, refreshes when within 5 min of expiry
    # Throws if token acquisition fails (no Graph access)
}
```

### 2.3 — New: `Invoke-AZTIGraphRequest`

**File:** `Modules/Private/0.MainFunctions/Invoke-AZTIGraphRequest.ps1` (NEW)

```powershell
function Invoke-AZTIGraphRequest {
    param(
        [string]$Uri,              # Relative path: /v1.0/users
        [string]$Method = 'GET',
        [object]$Body,
        [switch]$SinglePage        # Don't follow @odata.nextLink
    )
    # 1. Get token via Get-AZTIGraphToken
    # 2. Build full URL: https://graph.microsoft.com{$Uri}
    # 3. Invoke-RestMethod with token header
    # 4. Follow @odata.nextLink for pagination (unless -SinglePage)
    # 5. Handle 429 throttling with Retry-After header
    # 6. Return aggregated .value array
}
```

---

## Phase 3 — Pre-Flight Permission Checker

### 3.1 — New: `Test-AZTIPermissions`

**File:** `Modules/Public/PublicFunctions/Test-AZTIPermissions.ps1` (NEW)

```powershell
function Test-AZTIPermissions {
    param(
        [string]$TenantID,
        [string]$SubscriptionID,
        [ValidateSet('All','ArmOnly','EntraOnly')]
        [string]$Scope = 'All'
    )
    # Returns:
    # [PSCustomObject]@{
    #     ArmAccess    = $true/$false
    #     GraphAccess  = $true/$false
    #     Details      = @(
    #         @{ Check = 'ARM Reader'; Status = 'Pass'; Message = '...' }
    #         @{ Check = 'Directory.Read.All'; Status = 'Fail'; Remediation = '...' }
    #     )
    # }
}
```

**ARM checks:**
- `Get-AzSubscription -TenantId $TenantID` — can enumerate subscriptions?
- `Get-AzRoleAssignment` on first subscription — has Reader or higher?

**Graph checks:**
- `GET /v1.0/organization` — basic directory read
- `GET /v1.0/users?$top=1` — user read permission
- `GET /v1.0/identity/conditionalAccess/policies` — CA policy read (optional, warns if missing)

### 3.2 — Integration with `Invoke-AzureTenantInventory`

- Add `-SkipPermissionCheck` switch parameter
- Call `Test-AZTIPermissions` after auth, before extraction
- Display results as warnings, never block execution

---

## Phase 4 — Entra ID Extraction Layer

### 4.1 — New: `Start-AZTIEntraExtraction`

**File:** `Modules/Private/1.ExtractionFunctions/Start-AZTIEntraExtraction.ps1` (NEW)

```powershell
function Start-AZTIEntraExtraction {
    param($TenantID, $Scope)
    # 1. Call Invoke-AZTIGraphRequest for each Entra resource type
    # 2. Normalize each item with synthetic TYPE property (e.g., 'entra/users')
    # 3. Add properties: id, name, type, tenantId, properties (nested original data)
    # 4. Return [PSCustomObject]@{ EntraResources = $allEntraResources }
}
```

**Synthetic TYPE mapping:**

| Entra Resource | Synthetic TYPE |
|---|---|
| Users | `entra/users` |
| Groups | `entra/groups` |
| Applications | `entra/applications` |
| Service Principals | `entra/serviceprincipals` |
| Managed Identities | `entra/managedidentities` |
| Directory Roles | `entra/directoryroles` |
| PIM Assignments | `entra/pimassignments` |
| CA Policies | `entra/conditionalaccesspolicies` |
| Named Locations | `entra/namedlocations` |
| Admin Units | `entra/administrativeunits` |
| Domains | `entra/domains` |
| Subscribed SKUs | `entra/subscribedskus` |
| Cross-Tenant Access | `entra/crosstenantaccess` |
| Security Policies | `entra/securitypolicies` |
| Risky Users | `entra/riskyusers` |

### 4.2 — Update Extraction Orchestration

**File:** `Modules/Private/0.MainFunctions/Start-AZTIExtractionOrchestration.ps1`

Add:
- `$Scope` parameter
- Conditional call to `Start-AZTIEntraExtraction` when `$Scope -in ('All','EntraOnly')`
- Merge Entra resources into `$Resources` array (appended with synthetic types)
- Add `EntraResources` to return object

### 4.3 — New Parameter on `Invoke-AzureTenantInventory`

```powershell
[ValidateSet('All', 'ArmOnly', 'EntraOnly')]
[string]$Scope = 'All'
```

Passed to extraction orchestration to control which data sources are queried.

---

## Phase 5 — Entra ID Inventory Modules (15 new)

### Module Directory

**Path:** `Modules/Public/InventoryModules/Identity/`

All modules follow the standard two-phase pattern (`Processing` / `Reporting`).

### Module Specifications

| # | File | Synthetic TYPE | Excel Worksheet Name | Key Processing Fields |
|---|---|---|---|---|
| 1 | `Users.ps1` | `entra/users` | `Entra Users` | UPN, DisplayName, UserType, AccountEnabled, LastPasswordChange, Licenses, OnPremSync, Department, JobTitle |
| 2 | `Groups.ps1` | `entra/groups` | `Entra Groups` | DisplayName, GroupType, SecurityEnabled, MailEnabled, IsRoleAssignable, MemberCount, OwnerCount, DynamicRule, OnPremSync |
| 3 | `AppRegistrations.ps1` | `entra/applications` | `App Registrations` | DisplayName, AppId, SignInAudience, KeyExpiry, PasswordExpiry, RequiredPermissions, PublisherDomain |
| 4 | `ServicePrincipals.ps1` | `entra/serviceprincipals` | `Service Principals` | DisplayName, AppId, Type, AccountEnabled, OwnerOrg, KeyExpiry, PasswordExpiry, Tags |
| 5 | `ManagedIdentities.ps1` | `entra/managedidentities` | `Managed Identities` | DisplayName, Type (System/User), AssociatedResource |
| 6 | `DirectoryRoles.ps1` | `entra/directoryroles` | `Directory Roles` | RoleDisplayName, RoleTemplateId, MemberCount, Members (expanded) |
| 7 | `PIMAssignments.ps1` | `entra/pimassignments` | `PIM Assignments` | PrincipalName, RoleName, AssignmentType (Eligible/Active), StartTime, EndTime, State |
| 8 | `ConditionalAccess.ps1` | `entra/conditionalaccesspolicies` | `Conditional Access` | DisplayName, State, Users/Groups included/excluded, Apps, GrantControls, SessionControls |
| 9 | `NamedLocations.ps1` | `entra/namedlocations` | `Named Locations` | DisplayName, LocationType (IP/Country), IsTrusted, IPRanges or Countries |
| 10 | `AdminUnits.ps1` | `entra/administrativeunits` | `Admin Units` | DisplayName, Description, MemberCount, RestrictedManagement |
| 11 | `Domains.ps1` | `entra/domains` | `Entra Domains` | DomainName, IsVerified, IsDefault, AuthenticationType, Capabilities |
| 12 | `Licensing.ps1` | `entra/subscribedskus` | `Licensing` | SKUPartNumber, FriendlyName, ConsumedUnits, PrepaidEnabled, CapabilityStatus |
| 13 | `CrossTenantAccess.ps1` | `entra/crosstenantaccess` | `Cross-Tenant Access` | PartnerTenantId, InboundTrust, OutboundTrust, B2BCollaboration, B2BDirectConnect |
| 14 | `SecurityPolicies.ps1` | `entra/securitypolicies` | `Security Policies` | SecurityDefaultsEnabled, AllowUsersToCreateApps, AllowEmailVerifiedUsersToJoin, GuestInviteRestrictions |
| 15 | `RiskyUsers.ps1` | `entra/riskyusers` | `Risky Users` | UPN, RiskLevel, RiskState, RiskLastUpdated, RiskDetail |

### Module Template for Entra Modules

Each Entra module follows the same `param()` signature as ARM modules:
```powershell
param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)
```

Processing phase filters by synthetic type:
```powershell
If ($Task -eq 'Processing') {
    $entraUsers = $Resources | Where-Object { $_.TYPE -eq 'entra/users' }
    # Transform into flat hashtable objects for Excel
}
```

Reporting phase writes Excel:
```powershell
Else {
    [PSCustomObject]$SmaResources | ForEach-Object { $_ } | Select-Object $Exc |
    Export-Excel -Path $File -WorksheetName 'Entra Users' -TableName 'EntraUsers' ...
}
```

---

## Phase 6 — JSON Output Layer

### 6.1 — New: `Export-AZTIJsonReport`

**File:** `Modules/Private/3.ReportingFunctions/Export-AZTIJsonReport.ps1` (NEW)

```powershell
function Export-AZTIJsonReport {
    param($ReportCache, $File, $TenantID, $Subscriptions, $Scope)
    # 1. Read all {FolderName}.json cache files
    # 2. Organize into structured object:
    #    {
    #      "_metadata": { tool, version, tenantId, subscriptions[], generatedAt, scope },
    #      "arm": { "compute": {...}, "network": {...}, ... },
    #      "entra": { "users": [...], "groups": [...], ... },
    #      "advisory": [...],
    #      "policy": [...],
    #      "security": [...]
    #    }
    # 3. Write to {ReportDir}/{ReportName}.json
}
```

### 6.2 — New Parameter on `Invoke-AzureTenantInventory`

```powershell
[ValidateSet('All', 'Excel', 'Json')]
[string]$OutputFormat = 'All'
```

- `All` (default): Generate both `.xlsx` and `.json`
- `Excel`: Skip JSON export
- `Json`: Skip Excel generation (`Start-AZTIExcelJob` etc.)

### 6.3 — Integration in Report Orchestration

Update `Start-AZTIReportOrchestration` to:
- Call Excel pipeline only when `$OutputFormat -in ('All','Excel')`
- Call `Export-AZTIJsonReport` only when `$OutputFormat -in ('All','Json')`

---

## Phase 7 — Cleanup & Polish

### 7.1 — Update Default Paths

**File:** `Set-AZTIReportPath.ps1`

| OS | Old Default | New Default |
|---|---|---|
| Windows | `C:\AzureResourceInventory` | `C:\AzureTenantInventory` |
| Linux/Mac | `$HOME/AzureResourceInventory` | `$HOME/AzureTenantInventory` |

Report cache: `{DefaultPath}/ReportCache/`
Diagram cache: `{DefaultPath}/DiagramCache/`

### 7.2 — README.md

Full rewrite with:
- Project description and attribution to microsoft/ARI
- Installation (PSGallery + git clone)
- Quick start examples for all 5 auth modes
- `-Scope` usage (`All`, `ArmOnly`, `EntraOnly`)
- `-OutputFormat` usage (`All`, `Excel`, `Json`)
- `Test-AZTIPermissions` usage
- Required permissions table
- Module catalog (ARM + Entra)
- Contributing / module authoring guide

### 7.3 — Pester Tests

Create in `tests/`:
- `Test-AZTIPermissions.Tests.ps1` — mock Graph/ARM calls, verify detection logic
- `Invoke-AzureTenantInventory.Tests.ps1` — parameter validation, scope routing
- `Connect-AZTILoginSession.Tests.ps1` — auth method selection
- `Invoke-AZTIGraphRequest.Tests.ps1` — pagination, throttling, error handling
- `Start-AZTIEntraExtraction.Tests.ps1` — synthetic type normalization

### 7.4 — GitHub Pages Documentation Site (Antora)

Replace the existing `gh-pages` branch (inherited from microsoft/ARI, pointing at `microsoft.github.io/ARI/`) with a new Antora-based documentation site for AzureTenantInventory:

- Delete old `gh-pages` branch: `git push origin --delete gh-pages`
- Antora structure set up in Phase 1B (Step 7): `docs/antora.yml`, `docs/modules/ROOT/`, `antora-playbook.yml`
- Write AsciiDoc content in `docs/modules/ROOT/pages/`:
  - `index.adoc` — Getting started / installation
  - `authentication.adoc` — Authentication guide (all 5 methods)
  - `usage.adoc` — Scope & output format usage
  - `permissions.adoc` — Permission requirements
  - `arm-modules.adoc` — ARM module catalog (16 categories)
  - `entra-modules.adoc` — Entra module catalog (15 Identity modules)
  - `contributing.adoc` — Module authoring / contributing guide
  - `credits.adoc` — Credits & attribution to microsoft/ARI
  - `changelog.adoc` — Changelog
- Create `docs/modules/ROOT/nav.adoc` with navigation tree
- GitHub Actions workflow (`.github/workflows/docs.yml`) to build with Antora and deploy to `gh-pages` on push to `main`
- Site URL: `https://thisismydemo.github.io/azure-inventory/`

### 7.5 — CREDITS.md

Create `CREDITS.md` in repo root attributing the original ARI project:
- **Claudio Merola** — original ARI author
- **RenatoGregio** — original copyright holder
- **microsoft/ARI** — source project (MIT license)
- Link to original repo: `https://github.com/microsoft/ARI`

---

## Phase 8 — Inventory Module Expansion (ARM)

Based on gap analysis of existing 86 ARM inventory modules, the following coverage gaps were identified and should be addressed with new or enhanced modules.

### 8.1 — Azure Local (Stack HCI) Modules

**Gap:** No modules exist for Azure Local / Azure Stack HCI resources. Zero references to `microsoft.azurestackhci` anywhere in the codebase. Azure Local clusters, VMs, networks, and storage are ARM-projected resources queryable via Azure Resource Graph, making them a natural fit for the existing extraction pipeline.

**New directory:** `Modules/Public/InventoryModules/AzureLocal/`

| # | File | Resource Type | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `Clusters.ps1` | `microsoft.azurestackhci/clusters` | `AzLocal Clusters` | Name, Status, CloudId, Version, Last Sync, Node Count, OS Version, Connectivity Status, Desired Properties, Diagnostics Level |
| 2 | `VirtualMachines.ps1` | `microsoft.azurestackhci/virtualmachineinstances` | `AzLocal VMs` | Name, Status, VM Size, OS Type, Processor Count, Memory MB, Storage, Dynamic Memory, Network Interfaces |
| 3 | `LogicalNetworks.ps1` | `microsoft.azurestackhci/logicalnetworks` | `AzLocal Networks` | Name, VM Switch Name, Subnets, VLAN ID, DHCP, IP Pool, DNS Servers, Routes |
| 4 | `StorageContainers.ps1` | `microsoft.azurestackhci/storagecontainers` | `AzLocal Storage` | Name, Path, Provisioning State, Status, Available Size |
| 5 | `GalleryImages.ps1` | `microsoft.azurestackhci/galleryimages` | `AzLocal Images` | Name, OS Type, Version, Publisher, Offer, SKU, Provisioning State |
| 6 | `MarketplaceGalleryImages.ps1` | `microsoft.azurestackhci/marketplacegalleryimages` | `AzLocal Marketplace` | Name, OS Type, Version, Publisher, Offer, SKU, Status |

### 8.2 — Azure Arc Expanded Coverage

The existing Arc module is `Hybrid/ARCServers.ps1` (Arc-enabled servers, `microsoft.hybridcompute/machines`). No coverage for Arc Gateways, Arc-enabled Kubernetes, Arc resource bridge, or Arc extensions.

**Directory:** `Modules/Public/InventoryModules/Hybrid/` (existing — all Arc modules belong under Hybrid)

| # | File | Resource Type | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `ArcGateways.ps1` | `microsoft.hybridcompute/gateways` | `Arc Gateways` | Name, Location, Gateway Type, Gateway Endpoint, Provisioning State, Allowed Features |
| 2 | `ArcKubernetes.ps1` | `microsoft.kubernetes/connectedclusters` | `Arc Kubernetes` | Name, Distribution, K8s Version, Node Count, Agent Version, Connectivity Status, Identity, Provisioning State |
| 3 | `ArcResourceBridge.ps1` | `microsoft.resourceconnector/appliances` | `Arc Resource Bridge` | Name, Distro, Version, Status, Infrastructure Type, Provisioning State |
| 4 | `ArcExtensions.ps1` | `microsoft.hybridcompute/machines/extensions` | `Arc Extensions` | Machine Name, Extension Name, Publisher, Type, Version, Provisioning State, Status |

### 8.3 — Enhanced VPN & Networking Detail

Existing VPN modules capture basic properties but lack policy-level configuration detail critical for security audits. Point-to-Site configuration is entirely absent.

#### VirtualNetworkGateways.ps1 — Enhancements

**File:** `Modules/Public/InventoryModules/Network_2/VirtualNetworkGateways.ps1`

**Currently captures:** SKU, generation, gateway type, VPN type, active-active mode, Enable BGP, BGP ASN, BGP Peering Address, BGP Peer Weight, gateway public IP, gateway subnet.

**Add these fields:**

| New Field | Source Property | Notes |
|---|---|---|
| P2S Address Pool | `properties.vpnClientConfiguration.vpnClientAddressPool.addressPrefixes` | Comma-separated |
| P2S VPN Client Protocols | `properties.vpnClientConfiguration.vpnClientProtocols` | IkeV2, SSTP, OpenVPN |
| P2S Auth Type | `properties.vpnClientConfiguration.vpnAuthenticationTypes` | Certificate, AAD, RADIUS |
| P2S Root Cert Count | `properties.vpnClientConfiguration.vpnClientRootCertificates.count` | Number of trusted root certs |
| P2S Revoked Cert Count | `properties.vpnClientConfiguration.vpnClientRevokedCertificates.count` | Number of revoked certs |
| P2S RADIUS Server | `properties.vpnClientConfiguration.radiusServerAddress` | If RADIUS auth configured |
| P2S AAD Tenant | `properties.vpnClientConfiguration.aadTenant` | If AAD auth configured |
| Custom DNS Servers | `properties.customDnsServers` | Comma-separated |
| NAT Rules Count | `properties.natRules.count` | Number of NAT rules |
| Policy Group Count | `properties.vpnClientConfiguration.vngClientConnectionConfigurations.count` | Multi-pool P2S configurations |

#### Connections.ps1 — Enhancements

**File:** `Modules/Public/InventoryModules/Network_1/Connections.ps1`

**Currently captures:** Connection type, status, protocol, routing weight, connection mode.

**Add these fields:**

| New Field | Source Property | Notes |
|---|---|---|
| IPsec Encryption | `properties.ipsecPolicies[0].ipsecEncryption` | AES256, AES192, etc. |
| IPsec Integrity | `properties.ipsecPolicies[0].ipsecIntegrity` | SHA256, GCMAES256, etc. |
| IKE Encryption | `properties.ipsecPolicies[0].ikeEncryption` | AES256, AES192, etc. |
| IKE Integrity | `properties.ipsecPolicies[0].ikeIntegrity` | SHA256, SHA384, etc. |
| DH Group | `properties.ipsecPolicies[0].dhGroup` | DHGroup14, ECP384, etc. |
| PFS Group | `properties.ipsecPolicies[0].pfsGroup` | PFS2048, ECP384, etc. |
| SA Lifetime (sec) | `properties.ipsecPolicies[0].saLifeTimeSeconds` | IPsec SA lifetime |
| SA Data Size (KB) | `properties.ipsecPolicies[0].saDataSizeKilobytes` | IPsec SA data size |
| Use Policy-Based TS | `properties.usePolicyBasedTrafficSelectors` | Boolean |
| Traffic Selectors | `properties.trafficSelectorPolicies` | Local/Remote address ranges |
| DPD Timeout (sec) | `properties.dpdTimeoutSeconds` | Dead Peer Detection timeout |
| Ingress Bytes | `properties.ingressBytesTransferred` | Cumulative bytes received |
| Egress Bytes | `properties.egressBytesTransferred` | Cumulative bytes sent |
| Shared Key Set | `if ($_.properties.sharedKey) { 'Yes' } else { 'No' }` | Boolean only — NEVER log the actual key |

---

## Implementation Order

```
Phase 0  →  Phase 1  →  Phase 1B  →  Phase 2  →  Phase 3  →  Phase 4  →  Phase 5  →  Phase 6  →  Phase 7  →  Phase 8
Scaffold    Rename      Structure    Auth        Perms       Entra        Identity     JSON        Polish      Module
                        Review                               Extract      Modules      Output                  Expansion
```

Each phase is independently committable and testable. The tool remains functional after each phase:
- After Phase 1: AZTI-renamed ARI (same functionality, new names)
- After Phase 1B: Optimized folder layout, documented structure decisions
- After Phase 2: New auth with current-user default
- After Phase 3: Permission checking works
- After Phase 4: Entra data extraction works
- After Phase 5: Entra data appears in Excel
- After Phase 6: JSON output alongside Excel
- After Phase 7: Production-ready for PSGallery publish
- After Phase 8: Azure Local, Arc Gateway, and enhanced VPN detail coverage

---

## Verification Criteria

These 6 end-to-end scenarios must pass before the tool is considered production-ready:

| # | Scenario | Command | Expected Outcome |
|---|---|---|---|
| 1 | **Current user, no flags** | `Invoke-AzureTenantInventory -TenantID <id>` | Uses existing `Get-AzContext`, produces Excel + JSON with ARM and Entra data. No login prompt if already authenticated. |
| 2 | **SPN + Secret** | `Invoke-AzureTenantInventory -TenantID <id> -AppId <id> -Secret <secret>` | Authenticates as service principal, full inventory, no interactive prompts. |
| 3 | **SPN + Certificate** | `Invoke-AzureTenantInventory -TenantID <id> -AppId <id> -CertificatePath <path> -Secret <certpass>` | Authenticates with certificate, full inventory. |
| 4 | **Entra-only scope** | `Invoke-AzureTenantInventory -TenantID <id> -Scope EntraOnly` | Skips all ARM/Resource Graph extraction. Excel contains only Identity worksheets (15 Entra tabs). JSON contains only `entra` section. Completes significantly faster than full run. |
| 5 | **ARM-only scope** | `Invoke-AzureTenantInventory -TenantID <id> -Scope ArmOnly` | Skips all Graph/Entra extraction. No Identity worksheets in Excel. No `entra` section in JSON. Behaves like original ARI. |
| 6 | **Permission check with partial access** | `Test-AZTIPermissions -TenantID <id> -Scope All` | Returns structured object with `ArmAccess = $true/$false`, `GraphAccess = $true/$false`, and `Details` array. Warns on missing permissions but does not throw. When run via `Invoke-AzureTenantInventory` (without `-SkipPermissionCheck`), warnings display but execution continues with available data. |

### Additional Acceptance Checks

- **JSON output structure**: `_metadata` block contains `tool`, `version`, `tenantId`, `subscriptions[]`, `generatedAt`, `scope`. ARM data nested under `arm/{category}`. Entra data nested under `entra/{type}`.
- **Excel output**: All 15 Entra worksheets present when `-Scope All` or `-Scope EntraOnly`. Sheet names match specification (e.g., `Entra Users`, `Conditional Access`).
- **Pagination**: Entra modules with >999 objects follow `@odata.nextLink` and return complete data sets.
- **Throttling**: `Invoke-AZTIGraphRequest` respects `Retry-After` header on HTTP 429 and retries automatically.
- **No MgGraph dependency**: `Get-Module Microsoft.Graph* -ListAvailable` is NOT required. Tool functions with only `Az.Accounts`, `Az.ResourceGraph`, `Az.Compute`, `Az.Storage`, and `ImportExcel`.

### Phase 8 Acceptance Checks

| # | Scenario | Expected Outcome |
|---|---|---|
| 7 | **Azure Local cluster inventory** | `AzLocal Clusters` worksheet populated with cluster name, status, version, node count for each `microsoft.azurestackhci/clusters` resource. |
| 8 | **Arc Gateway inventory** | `Arc Gateways` worksheet populated with gateway name, type, endpoint, provisioning state for each `microsoft.hybridcompute/gateways` resource. |
| 9 | **P2S VPN detail** | `VirtualNetworkGateways` worksheet includes P2S Address Pool, VPN Client Protocols, Auth Type columns — populated when P2S is configured, empty when not. |
| 10 | **IPsec policy detail** | `Connections` worksheet includes IPsec Encryption, IKE Encryption, DH Group, SA Lifetime columns — populated when custom IPsec policy is set. |
| 11 | **Shared key safety** | `Connections` worksheet `Shared Key Set` column shows only `Yes`/`No` — never the actual shared key value. |

---

## Phase 9 — Missing ARM Resource Types (Feature Parity Enhancement)

> Identified through comparison analysis against `Invoke-TenantDiscovery.ps1`. Adds 17 ARM resource types and 3 Entra ID verification items to achieve feature parity with TierPoint ProductTech CMP reference implementation.

### 9.1 — Azure Policy & Governance

These modules inventory policy, RBAC, and governance constructs. All use ARM API (not Resource Graph) as these resource types may not be fully indexed in ARG.

**Directory:** `Modules/Public/InventoryModules/Management/`

| # | File | API | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `ManagementGroups.ps1` | `Get-AzManagementGroup -Expand -Recurse` | `Management Groups` | Name, Display Name, Parent, Children (MGs + Subs), Hierarchy Level, Policy Assignments Count, RBAC Assignments Count |
| 2 | `CustomRoleDefinitions.ps1` | `Get-AzRoleDefinition \| Where-Object { $_.IsCustom }` | `Custom Roles` | Name, Description, Assignable Scopes, Actions, NotActions, DataActions, NotDataActions |
| 3 | `PolicyDefinitions.ps1` | `Get-AzPolicyDefinition -Custom` | `Policy Definitions` | Name, Display Name, Policy Type, Mode, Description, Metadata, Parameters, Policy Rule |
| 4 | `PolicySetDefinitions.ps1` | `Get-AzPolicySetDefinition -Custom` | `Policy Set Definitions` | Name, Display Name, Description, Policy Definitions Count, Policies (Name + DefinitionId) |
| 5 | `PolicyComplianceStates.ps1` | `Get-AzPolicyState -Top 500` | `Policy Compliance` | Resource ID, Policy Assignment, Policy Definition, Compliance State, Timestamp, Subscription, Resource Type |
| 6 | **FIX: `MaintenanceConfigurations.ps1`** | **REWRITE** | `Maintenance Configurations` | **CRITICAL**: Rewrite with dual-Task pattern (Processing and Reporting blocks). Currently uses function pattern incompatible with inventory pipeline. |

#### MaintenanceConfigurations.ps1 — Rewrite Specification

**Current Architecture Problem:**
- File uses **function** pattern: `function Invoke-AZTIMaintenanceConfigurationsInventory($InventoryData, $SubscriptionId, $TenantId)`
- Inventory pipeline expects **parameter block + dual-Task conditional pattern** (Processing/Reporting)
- Result: Module discovered via auto-scan but never executes

**Required Architecture:**
```powershell
param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {
    # Extract maintenance configurations from $Resources
    $MaintenanceConfigs = $Resources | Where-Object { $_.TYPE -eq 'microsoft.maintenance/maintenanceconfigurations' }

    # Process each configuration into hashtable
    $ProcessedData = $MaintenanceConfigs | ForEach-Object {
        @{
            Name = $_.NAME
            ResourceGroup = $_.RESOURCEGROUP
            Subscription = $Sub
            Location = $_.LOCATION
            MaintenanceScope = $_.properties.maintenanceScope
            MaintenanceWindow = @{
                RecurEvery = $_.properties.maintenanceWindow.recurEvery
                StartDateTime = $_.properties.maintenanceWindow.startDateTime
                Duration = $_.properties.maintenanceWindow.duration
                TimeZone = $_.properties.maintenanceWindow.timeZone
            }
            InstallPatches = @{
                RebootSetting = $_.properties.installPatches.rebootSetting
                WindowsClassifications = $_.properties.installPatches.windowsParameters.classificationsToInclude -join ', '
                LinuxClassifications = $_.properties.installPatches.linuxParameters.classificationsToInclude -join ', '
                PackageNameMasks = $_.properties.installPatches.linuxParameters.packageNameMasksToInclude -join ', '
            }
            Tags = ($_.tags | ConvertTo-Json -Compress) -replace '"', '""'
        }
    }

    return $ProcessedData
}
Else {
    # Generate Excel worksheet from $SmaResources
    $TableName = "AZT_MaintenanceConfigurations_$($Sub)"
    $Excel = $SmaResources | ForEach-Object {
        [PSCustomObject]@{
            'Name' = $_.Name
            'Resource Group' = $_.ResourceGroup
            'Subscription' = $_.Subscription
            'Location' = $_.Location
            'Maintenance Scope' = $_.MaintenanceScope
            'Recur Every' = $_.MaintenanceWindow.RecurEvery
            'Start Date Time' = $_.MaintenanceWindow.StartDateTime
            'Duration' = $_.MaintenanceWindow.Duration
            'Time Zone' = $_.MaintenanceWindow.TimeZone
            'Reboot Setting' = $_.InstallPatches.RebootSetting
            'Windows Classifications' = $_.InstallPatches.WindowsClassifications
            'Linux Classifications' = $_.InstallPatches.LinuxClassifications
            'Package Masks' = $_.InstallPatches.PackageNameMasks
        }
    }

    $Excel | Export-Excel -Path $File -WorksheetName 'Maintenance Configs' -AutoSize -TableName $TableName -TableStyle $TableStyle
}
```

### 9.2 — Microsoft Defender for Cloud

Defender modules require `Microsoft.Security` resource provider registration. Add pre-flight check in main inventory function to warn if provider not registered.

**Directory:** `Modules/Public/InventoryModules/Security/`

| # | File | API | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `DefenderAssessments.ps1` | `Get-AzSecurityAssessment` | `Defender Assessments` | Resource ID, Display Name, Status (Healthy/Unhealthy/NotApplicable), Severity, Category, Description |
| 2 | `DefenderSecureScore.ps1` | `Get-AzSecuritySecureScore` | `Defender Secure Score` | Display Name, Current Points, Max Points, Percentage, Weight |
| 3 | `DefenderAlerts.ps1` | `Get-AzSecurityAlert` | `Defender Alerts` | Alert Display Name, Alert Type, Severity, Status, Time Generated, Description, Remediation Steps, Entities |
| 4 | `DefenderPricing.ps1` | `Get-AzSecurityPricing` | `Defender Pricing` | Name (service), Pricing Tier (Standard/Free), Sub-plans, Extensions |

**Defender Pricing Plan Services to Capture:**
- VirtualMachines, SqlServers, AppServices, StorageAccounts, SqlServerVirtualMachines, KubernetesService, ContainerRegistry, KeyVaults, Dns, Arm, OpenSourceRelationalDatabases, Containers, CloudPosture, Servers (P2), Databases

### 9.3 — Azure Monitor Resources

Monitor modules require `Microsoft.Insights` resource provider registration. Includes new **Data Collection Rules** and **Data Collection Endpoints** — discovered missing from both AzureTenantInventory AND Invoke-TenantDiscovery.ps1 reference implementation.

**Directory:** `Modules/Public/InventoryModules/Monitoring/`

| # | File | API | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `ActionGroups.ps1` | `Get-AzActionGroup` | `Action Groups` | Name, Resource Group, Short Name, Enabled, Email Receivers (count + addresses), SMS Receivers (count), Webhook Receivers (count), Logic App Receivers (count) |
| 2 | `MetricAlertRules.ps1` | `Get-AzMetricAlertRuleV2` | `Metric Alert Rules` | Name, Resource Group, Description, Severity, Enabled, Scopes (target resources), Condition (metric, operator, threshold), Action Groups |
| 3 | `ScheduledQueryRules.ps1` | `Get-AzScheduledQueryRule` | `Scheduled Query Rules` | Name, Resource Group, Description, Enabled, Severity, Data Source IDs, Query, Frequency, Time Window, Trigger Condition, Action Groups |
| 4 | `DataCollectionRules.ps1` | `Get-AzDataCollectionRule` | `Data Collection Rules` | Name, Resource Group, Location, Description, Data Sources (Performance Counters, Event Logs, Syslog, Custom), Destinations (Log Analytics Workspaces, Storage), Data Flows |
| 5 | `DataCollectionEndpoints.ps1` | `Get-AzDataCollectionEndpoint` | `Data Collection Endpoints` | Name, Resource Group, Location, Description, Configuration Access Endpoint, Logs Ingestion Endpoint, Network ACLs |
| 6 | `SubscriptionDiagnosticSettings.ps1` | `Get-AzSubscriptionDiagnosticSetting` | `Subscription Diagnostics` | Subscription ID, Name, Workspace ID, Storage Account ID, Event Hub Name, Log Categories Enabled, Enabled Status |

**Data Collection Rules (DCR) Importance:**
- Central to Azure Monitor Agent (AMA) configuration
- Replaced legacy MMA/OMS agent configuration methods
- Define data collection from VMs, Arc-enabled servers, Kubernetes clusters
- Control telemetry routing to Log Analytics, Storage, Event Hubs
- Missing from both implementations — legitimate gap

### 9.4 — Networking & Managed Services

**Directory:** `Modules/Public/InventoryModules/Network_2/` (NetworkWatchers) and `Modules/Public/InventoryModules/Management/` (Lighthouse)

| # | File | API | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `NetworkWatchers.ps1` | `Get-AzNetworkWatcher` | `Network Watchers` | Name, Resource Group, Location, Provisioning State |
| 2 | `LighthouseDelegations.ps1` | `Get-AzManagedServicesAssignment` + `Get-AzManagedServicesDefinition` | `Lighthouse Delegations` | Assignment Name, Managed By Tenant ID, Managed By Tenant Name, Registration Definition Name, Authorizations (PrincipalId, RoleDefinitionId, PrincipalDisplayName), Scope |

**Lighthouse Delegation Details:**
- Shows which external tenants have delegated access to this subscription/resource group
- Critical for managed service provider (MSP) environments and multi-tenant management scenarios
- Authorizations array contains identity + role mappings for managing tenant users/groups

### 9.5 — Entra ID Verification

Verify existing `Identity/SecurityPolicies.ps1` captures these Entra ID features. If absent, add them to SecurityPolicies or create new dedicated modules.

| # | Feature | Graph API Endpoint | Fields to Capture |
|---|---|---|---|
| 1 | **Identity Providers** | `/identity/identityProviders` | Display Name, Type (AAD, ADFSv2, Google, Facebook, Microsoft, SAML), Client ID, Client Secret Set (boolean), Issuer URI, Domains |
| 2 | **Authorization Policy** | `/policies/authorizationPolicy` | Display Name, Allow Email Verified Users to Join, Allow Invitations From (none, adminsAndGuestInviters, all), Allowed To Sign Up Email Based Subscriptions, Allowed To Use SSPR, Block MSOL PowerShell, Default User Role Permissions (can create apps, can create security groups, can read other users) |
| 3 | **Security Defaults Policy** | `/policies/identitySecurityDefaultsEnforcementPolicy` | Is Enabled, Display Name, Description |

**Action Items:**
- Read `Modules/Public/InventoryModules/Identity/SecurityPolicies.ps1`
- Check if Identity Providers, Authorization Policy, and Security Defaults are already captured
- If missing:
  - **Option A:** Add to SecurityPolicies.ps1 as additional sections
  - **Option B:** Create dedicated `IdentityProviders.ps1`, `AuthorizationPolicy.ps1`, `SecurityDefaults.ps1` modules
- Update Excel report with new columns/worksheets as needed

---

## Phase 10 — Excel Report Restructuring

> Redesign Overview worksheet and create dedicated specialized tabs for better report organization and usability.

### 10.1 — Overview Tab Restructuring

**Current State:** Overview tab contains summary metrics, cost information, security information, reservation information, monitoring information — resulting in a cluttered, information-overload worksheet.

**Target State:** Overview tab contains **ONLY essential tenant-level metadata**.

**Overview Tab Final Content:**

| Section | Fields |
|---|---|
| **Tenant Info** | Tenant ID, Tenant Display Name, Primary Domain, Default Domain, Country Code |
| **Authentication** | Authenticated As (UPN or App ID), Authentication Method (User / SPN-Secret / SPN-Cert), Timestamp |
| **Scope** | Scope Value (`All`, `ArmOnly`, `EntraOnly`), Subscriptions Scanned (count + list), Management Groups Scanned (count) |
| **Resource Summary** | Total Subscriptions, Total Management Groups, Total Resource Groups, Total ARM Resources, Total Entra Users, Total Entra Groups |
| **Execution Metadata** | Tool Version, Execution Start Time, Execution Duration, PowerShell Version, OS Platform, Output Files (Excel path, JSON path) |

**Remove from Overview (relocate to new tabs):**
- VM Reservations → Cost Management tab
- Cost Analysis → Cost Management tab
- Defender Secure Score → Security Overview tab
- Security Assessments Summary → Security Overview tab
- Advisor Recommendations → Split between Cost Management and Security Overview tabs
- Action Groups/Alert Rules Summary → Azure Monitor tab
- Monitoring Coverage Graphs → Azure Monitor tab

### 10.2 — New Tab: Cost Management

**Position:** Immediately after Overview tab (tab order: Overview → Cost Management → ...)

**Sections:**

| Section | Content | Source |
|---|---|---|
| **VM Reservations** | Reservation Name, VM Series, Region, Quantity, Term, Status, Expiration Date, Subscription | `APIs/ReservationRecom.ps1` |
| **Reservation Recommendations** | VM Series, Region, Recommended Quantity, Estimated Savings, Subscription | Azure Advisor Cost API |
| **Cost Analysis Summary** | Subscription, Month-to-Date Spend, Forecasted Monthly Spend, vs Last Month (%), Top 5 Resources by Cost | Azure Consumption API (future enhancement) |
| **Advisor Cost Recommendations** | Resource Name, Resource Type, Impact, Category, Recommendation, Potential Savings | `APIs/AdvisorScore.ps1` (filtered to Cost category) |

**Conditional Formatting:**
- Reservations expiring <90 days: Yellow background
- Reservations expiring <30 days: Red background
- Cost recommendations with High Impact: Bold text

### 10.3 — New Tab: Security Overview

**Position:** After Cost Management tab

**Sections:**

| Section | Content | Source |
|---|---|---|
| **Defender Secure Score** | Current Score, Max Score, Percentage, Control Scores by Category | `Security/DefenderSecureScore.ps1` |
| **Security Assessments Summary** | Healthy Count, Unhealthy Count, Not Applicable Count, by Severity (Critical, High, Medium, Low) | `Security/DefenderAssessments.ps1` |
| **Top 10 Unhealthy Assessments** | Assessment Name, Affected Resources Count, Severity, Category | `Security/DefenderAssessments.ps1` |
| **Critical Security Alerts** | Alert Display Name, Severity, Time Generated, Affected Resources | `Security/DefenderAlerts.ps1` (Severity = High/Medium) |
| **Defender Pricing Coverage** | Service Name, Pricing Tier (Standard/Free), Sub-plans Enabled | `Security/DefenderPricing.ps1` |
| **Advisor Security Recommendations** | Resource Name, Resource Type, Impact, Recommendation | `APIs/AdvisorScore.ps1` (filtered to Security category) |
| **Policy Compliance Summary** | Compliant Resources Count, Non-Compliant Count, by Policy Assignment | `Management/PolicyComplianceStates.ps1` |

**Conditional Formatting:**
- Secure Score <60%: Red text
- Secure Score 60-80%: Yellow text
- Secure Score >80%: Green text
- Unhealthy assessments (Critical/High severity): Red background
- Pricing Tier = Free (for production subscriptions): Yellow background

**Charts/Graphs:**
- Secure Score gauge chart
- Security Assessments by Severity (pie chart)
- Policy Compliance by State (bar chart)
- Defender Coverage by Service (stacked bar chart: Standard vs Free)

### 10.4 — New Tab: Azure Update Manager Overview

**Position:** After Security Overview tab

**Purpose:** Centralized view of patch compliance, maintenance schedules, and update status for Azure VMs and Arc-enabled servers.

**Sections:**

| Section | Content | Source |
|---|---|---|
| **Azure VMs** | VM Name, Resource Group, Subscription, OS Type, OS Version, Maintenance Schedule Assigned, Patch Compliance Status, Last Patch Time, Pending Patches Count | `Compute/VirtualMachines.ps1` + `Management/MaintenanceConfigurations.ps1` + Azure Update Manager API |
| **Arc-Enabled Servers** | Server Name, Resource Group, Subscription, OS Type, OS Version, Maintenance Schedule Assigned, Patch Compliance Status, Last Patch Time, Pending Patches Count | `Hybrid/ARCServers.ps1` + Azure Update Manager API |
| **Maintenance Schedules** | Schedule Name, Maintenance Scope, Recurrence, Next Run Time, Assigned Machines Count | `Management/MaintenanceConfigurations.ps1` + associations |
| **Patch Compliance Summary** | Subscription, Total VMs, Compliant VMs, Non-Compliant VMs, Unknown, Total Arc Servers, Compliant Arc Servers, Non-Compliant Arc Servers | Aggregate from VM + Arc data |

**Conditional Formatting:**
- Patch Compliance = Non-Compliant: Red background
- Patch Compliance = Unknown: Yellow background
- Maintenance Schedule = Not Assigned: Orange text
- Pending Patches >10: Red text
- Last Patch Time >30 days ago: Yellow background

**Charts/Graphs:**
- VMs by Maintenance Schedule Assignment (pie chart: Assigned vs Unassigned)
- VMs by Patch Compliance Status (bar chart: Compliant vs Non-Compliant vs Unknown)
- VMs by OS Type (pie chart: Windows vs Linux)
- Pending Patches Distribution (histogram)

**API Requirements:**
- **Azure Update Manager REST API:** `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Compute/virtualMachines/{vmName}/patchAssessmentResults/latest?api-version=2023-07-01`
- Returns: `availablePatchCountByClassification`, `lastModifiedDateTime`, `assessmentActivityId`, `rebootPending`

### 10.5 — New Tab: Azure Monitor

**Position:** After Azure Update Manager Overview tab

**Sections:**

| Section | Content | Source |
|---|---|---|
| **Action Groups** | Name, Resource Group, Enabled, Email Receivers Count, SMS Count, Webhook Count, Logic App Count | `Monitoring/ActionGroups.ps1` |
| **Metric Alert Rules** | Name, Resource Group, Description, Severity, Enabled, Target Resources, Condition, Action Groups | `Monitoring/MetricAlertRules.ps1` |
| **Scheduled Query Rules** | Name, Resource Group, Description, Enabled, Severity, Workspace, Query Frequency, Action Groups | `Monitoring/ScheduledQueryRules.ps1` |
| **Data Collection Rules** | Name, Resource Group, Data Sources (types), Destinations (workspaces), Associations Count | `Monitoring/DataCollectionRules.ps1` + associations |
| **Log Analytics Workspaces** | Name, Resource Group, Retention (days), Daily Cap (GB), Pricing Tier, Data Ingestion (Last 7 Days, GB) | `Monitoring/Workspaces.ps1` |
| **Application Insights** | Name, Resource Group, Application Type, Workspace Link, Ingestion Mode | `Monitoring/APPInsights.ps1` |
| **Diagnostic Settings Coverage** | Resource Type, Total Resources, Resources with Diagnostics Enabled, Coverage % | Aggregate from subscription diagnostic settings + resource diagnostics |

**Conditional Formatting:**
- Alert Rule Enabled = False: Gray text (disabled)
- Action Group Enabled = False: Gray text
- Workspace Retention <30 days: Yellow background
- Diagnostic Coverage <50%: Red text
- Diagnostic Coverage 50-80%: Yellow text
- Diagnostic Coverage >80%: Green text

**Charts/Graphs:**
- Alert Rules by Severity (bar chart)
- Data Collection Rules by Data Source Type (pie chart)
- Log Analytics Workspaces by Pricing Tier (pie chart)
- Diagnostic Settings Coverage by Resource Type (stacked bar chart)

### 10.6 — Tab Ordering

**Final Excel Workbook Tab Order:**

1. **Overview** (essential tenant metadata only)
2. **Cost Management** (reservations, recommendations, spend analysis)
3. **Security Overview** (Defender, assessments, alerts, policy compliance)
4. **Azure Update Manager Overview** (VMs, Arc servers, patch compliance, maintenance schedules)
5. **Azure Monitor** (action groups, alerts, DCRs, workspaces, diagnostic settings)
6. ... (all existing resource tabs: Subscriptions, Resource Groups, VMs, Networks, etc.)
7. ... (all Entra ID tabs: Entra Users, Entra Groups, Conditional Access, etc.)

---

## Phase 11 — Comprehensive Subscription & Management Group Logging

> **CRITICAL ARCHITECTURAL FIX**: Current implementation only logs subscriptions that contain discovered resources. User requirement: Log ALL subscriptions and ALL management groups in the tenant, regardless of resource presence.

### 11.1 — Subscription Logging Enhancement

**Current Behavior:**
- Subscriptions appear in Excel report only if they contain resources in Resource Graph query results
- Empty/new subscriptions are silent

**Required Behavior:**
- **ALL** subscriptions in the tenant must appear in report
- Flag empty subscriptions (0 resources) visually

**Implementation:**

1. **Early Subscription Enumeration:**
   - Move `Get-AzSubscription` to very beginning of inventory run (before Resource Graph extraction)
   - Capture ALL subscriptions the authenticated identity can access
   - Store as baseline subscription list

2. **Enhanced Subscription Object Properties:**
   ```powershell
   $AllSubscriptions = Get-AzSubscription | ForEach-Object {
       @{
           SubscriptionId = $_.Id
           Name = $_.Name
           State = $_.State  # Enabled, Disabled, Warned, PastDue, Deleted
           TenantId = $_.TenantId
           Tags = $_.Tags
           SubscriptionPolicies = @{
               SpendingLimit = $_.SubscriptionPolicies.SpendingLimit
               QuotaId = $_.SubscriptionPolicies.QuotaId
           }
           AuthorizationSource = $_.AuthorizationSource
           ManagedByTenants = $_.ManagedByTenants  # For Lighthouse scenarios
           HomeTenantId = $_.HomeTenantId
           # Additional enrichment:
           ManagementGroupPath = ""  # Populated from Get-AzManagementGroup results
           ResourceCount = 0  # Populated from Resource Graph results
           ResourceGroupCount = 0  # Populated from Resource Graph results
       }
   }
   ```

3. **Resource Graph Enrichment:**
   - After Resource Graph extraction, match resources to subscriptions
   - Update `ResourceCount` and `ResourceGroupCount` fields
   - Subscriptions with no matches remain in list with counts = 0

4. **Excel Worksheet: "All Subscriptions"**
   - New dedicated worksheet (positioned after Overview)
   - Columns:
     - Subscription Name
     - Subscription ID
     - State (Enabled/Disabled/etc.)
     - Management Group Path (e.g., `Root/Production/AzureLocal`)
     - Resource Groups Count
     - Resources Count
     - Tags
     - Spending Limit (On/Off/CurrentPeriodOff)
     - Authorization Source
   - **Conditional Formatting:**
     - State = Disabled: Gray background
     - Resources Count = 0: Orange text
     - Spending Limit = Off (for dev/test subs): Yellow background

### 11.2 — Management Group Logging Enhancement

**Current Behavior:**
- Management groups not captured at all

**Required Behavior:**
- Capture entire management group hierarchy using `Get-AzManagementGroup -Expand -Recurse`
- Display hierarchy in Excel with indentation or parent-child relationships
- Link subscriptions to their management group placement

**Implementation:**

1. **Management Group Extraction:**
   ```powershell
   $RootMG = Get-AzManagementGroup -GroupName (Get-AzContext).Tenant.Id -Expand -Recurse

   # Recursive function to flatten hierarchy with depth tracking
   function Expand-ManagementGroupHierarchy {
       param($MG, $Depth = 0, $ParentPath = "")

       $CurrentPath = if ($ParentPath) { "$ParentPath/$($MG.DisplayName)" } else { $MG.DisplayName }

       [PSCustomObject]@{
           ManagementGroupId = $MG.Name
           DisplayName = $MG.DisplayName
           ParentId = $MG.ParentId
           ParentPath = $ParentPath
           FullPath = $CurrentPath
           Depth = $Depth
           ChildMGCount = ($MG.Children | Where-Object { $_.Type -eq 'Microsoft.Management/managementGroups' }).Count
           SubscriptionCount = ($MG.Children | Where-Object { $_.Type -eq 'Microsoft.Resources/subscriptions' }).Count
           DirectSubscriptions = ($MG.Children | Where-Object { $_.Type -eq 'Microsoft.Resources/subscriptions' }).Name -join ', '
       }

       # Recurse into child management groups
       $MG.Children | Where-Object { $_.Type -eq 'Microsoft.Management/managementGroups' } | ForEach-Object {
           Expand-ManagementGroupHierarchy -MG $_ -Depth ($Depth + 1) -ParentPath $CurrentPath
       }
   }

   $AllManagementGroups = Expand-ManagementGroupHierarchy -MG $RootMG
   ```

2. **Excel Worksheet: "Management Groups"**
   - New dedicated worksheet (positioned after All Subscriptions)
   - Columns:
     - Management Group Name (with indentation based on Depth)
     - Management Group ID
     - Parent Management Group
     - Full Path (e.g., `Root/Production/AzureLocal`)
     - Child Management Groups Count
     - Direct Subscriptions Count
     - Direct Subscriptions (comma-separated names)
   - **Indentation:** Use Excel `$worksheet.Cells[row, col].Style.Indent = $depth` to visually show hierarchy

3. **Integration with Subscriptions:**
   - Add "Management Group Path" column to All Subscriptions worksheet
   - Populate by matching subscription's management group ID to flattened hierarchy

### 11.3 — Overview Tab Integration

Update Overview tab **Resource Summary** section:

| Field | Source |
|---|---|
| Total Subscriptions | Count from `Get-AzSubscription` (ALL subs, not just ones with resources) |
| Total Management Groups | Count from `Get-AzManagementGroup -Expand -Recurse` flattened results |
| Subscriptions with Resources | Count where ResourceCount > 0 |
| Empty Subscriptions | Count where ResourceCount = 0 |
| Total Resource Groups | ARG query result |
| Total ARM Resources | ARG query result |

---

## Phase 12 — Scope & Authentication Defaults Update

> Change default tool behavior: ARM-only discovery by default, Entra ID opt-in. Document permissions and resource provider requirements clearly.

### 12.1 — Default Scope Change

**Current Default:** `-Scope All` (ARM + Entra ID both scanned by default)

**New Default:** `-Scope ArmOnly` (ARM resources only; Entra ID requires explicit opt-in)

**Rationale:**
- Entra ID scanning requires Microsoft Graph permissions (often requires admin consent)
- ARM scanning requires only subscription Reader role (broadly available)
- Users may run tool with ARM-only intent and not realize Graph permissions are being requested/checked
- Explicit opt-in better aligns with least-privilege principle

**Implementation:**

1. **Update Parameter Default in `AzureTenantInventory.psm1`:**
   ```powershell
   [Parameter(Mandatory=$false)]
   [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
   [string]$Scope = 'ArmOnly'  # Changed from 'All'
   ```

2. **Update Help Documentation:**
   ```powershell
   .PARAMETER Scope
   Specifies what to inventory.
   - ArmOnly (default): Scans Azure Resource Manager resources (subscriptions, resource groups, VMs, networks, etc.). Requires subscription Reader role.
   - EntraOnly: Scans Microsoft Entra ID only (users, groups, apps, Conditional Access, PIM). Requires Microsoft Graph permissions.
   - All: Scans both ARM and Entra ID. Requires both subscription Reader and Graph permissions.

   .EXAMPLE
   Invoke-AzureTenantInventory -TenantID $tenantId
   # Scans ARM resources only (default behavior).

   .EXAMPLE
   Invoke-AzureTenantInventory -TenantID $tenantId -Scope All
   # Scans both ARM and Entra ID. Requires Graph permissions.

   .EXAMPLE
   Invoke-AzureTenantInventory -TenantID $tenantId -Scope EntraOnly
   # Scans Entra ID only. Skips all ARM resources.
   ```

3. **Update `README.md`:**
   - Clarify ARM-only default behavior in "Quick Start" section
   - Add prominent note: *"By default, the tool scans Azure Resource Manager (ARM) resources only. To include Microsoft Entra ID (users, groups, Conditional Access, etc.), specify `-Scope All`."*
   - Update permission requirements section to differentiate ARM vs Entra permissions

### 12.2 — Permission Documentation

Create comprehensive permission documentation in `README.md` (new section: **Permissions**).

**README.md Addition:**

```markdown
## Permissions

AzureTenantInventory requires different permissions depending on scan scope.

### ARM Scan (`-Scope ArmOnly` or `-Scope All`)

| Role | Scope | Purpose |
|---|---|---|
| **Reader** | Subscription(s) or Root Management Group | Read all ARM resources (VMs, networks, storage, etc.) |
| **Security Reader** | Subscription(s) | Read Microsoft Defender for Cloud assessments, alerts, secure score |
| **Monitoring Reader** | Subscription(s) | Read Azure Monitor resources (action groups, alert rules, DCRs) |

**Recommended:** Assign **Reader** role at **Root Management Group** level for comprehensive visibility across all subscriptions.

**Service Principal Setup:**
```powershell
# Create service principal
$sp = New-AzADServicePrincipal -DisplayName "AzureTenantInventory-SPN"

# Assign Reader at Root Management Group
$rootMG = Get-AzManagementGroup -GroupName (Get-AzContext).Tenant.Id
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Reader" -Scope $rootMG.Id

# Assign Security Reader and Monitoring Reader at each subscription (or at Root MG)
Get-AzSubscription | ForEach-Object {
    New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Security Reader" -Scope "/subscriptions/$($_.Id)"
    New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Monitoring Reader" -Scope "/subscriptions/$($_.Id)"
}
```

### Entra ID Scan (`-Scope EntraOnly` or `-Scope All`)

#### Microsoft Graph API Permissions

AzureTenantInventory uses **Microsoft Graph REST API** (not SDK) via `Get-AzAccessToken -ResourceTypeName MSGraph` + `Invoke-RestMethod`. Permissions are evaluated at runtime based on the authenticated identity's Graph access.

| Permission | Type | Purpose | Required For |
|---|---|---|---|
| `Directory.Read.All` | Delegated or Application | Read users, groups, roles, admin units, devices, organization | **All Entra modules** |
| `Policy.Read.All` | Delegated or Application | Read Conditional Access policies, named locations, authentication policies | Conditional Access, SecurityPolicies modules |
| `IdentityRiskyUser.Read.All` | Delegated or Application | Read risky users | RiskyUsers module |
| `RoleManagement.Read.Directory` | Delegated or Application | Read PIM assignments, eligible roles | PIM module |
| `Application.Read.All` | Delegated or Application | Read app registrations, enterprise apps | AppRegistrations, ServicePrincipals modules |
| `Domain.Read.All` | Delegated or Application | Read verified domains | Domains module |

**Minimum Required:** `Directory.Read.All` + `Policy.Read.All`

**Recommended:** All of the above for comprehensive Entra ID inventory.

#### User (Interactive) Authentication

If running as **current user** (default):
1. User must have one of these Entra ID roles:
   - Global Reader
   - Global Administrator
   - Security Reader
   - Directory Readers (minimum)
2. User must have consented to Microsoft Graph permissions **at tenant level** (if not, they will be prompted to consent on first run)
3. If MFA is enabled for the user, expect interactive MFA prompt

**Test permissions:**
```powershell
Connect-AzAccount -TenantId $tenantId
Test-AZTIPermissions -TenantID $tenantId -Scope All
```

#### Service Principal (Non-Interactive) Authentication

If running as **service principal** (AppId + Secret/Certificate):
1. Go to **Azure Portal > Entra ID > App Registrations > [Your App] > API Permissions**
2. Click **Add a permission > Microsoft Graph > Application permissions**
3. Select all required permissions listed above
4. Click **Grant admin consent for [Tenant Name]** ⚠️ **Requires Global Administrator or Privileged Role Administrator**
5. Verify **Status** shows green checkmark for all permissions

**SPN Authentication Example:**
```powershell
Invoke-AzureTenantInventory `
    -TenantID $tenantId `
    -AppId "12345678-1234-1234-1234-123456789abc" `
    -Secret $spnSecret `
    -Scope All
```

### Permission Pre-Flight Check

The `Test-AZTIPermissions` cmdlet validates permissions before inventory execution:

```powershell
PS> Test-AZTIPermissions -TenantID "contoso.onmicrosoft.com" -Scope All

TenantId         : abcd1234-5678-90ab-cdef-1234567890ab
Scope            : All
ArmAccess        : True
GraphAccess      : False
Details          : {
    "Category": "ARM",
    "Status": "Success",
    "Message": "Successfully authenticated to ARM. Found 12 accessible subscriptions."
  },
  {
    "Category": "Graph",
    "Status": "Failed",
    "Message": "Graph access denied. Missing permission: Policy.Read.All",
    "Remediation": "Grant 'Policy.Read.All' application permission in App Registration and admin consent."
  }
Warnings         : Graph permissions incomplete. Entra ID modules will be skipped.
```

**Behavior:**
- **Warnings only** — execution continues with available permissions
- ARM scan proceeds if ARM access succeeds (even if Graph fails)
- Entra ID modules skipped if Graph access fails
- If running with `-Scope All` and Graph permissions are missing, tool behaves as if `-Scope ArmOnly` was specified

### Troubleshooting Permissions Errors

| Error | Cause | Remediation |
|---|---|---|
| `Insufficient privileges to complete the operation` | User/SPN lacks required Graph permission | Grant missing permission and admin consent |
| `Access denied` (ARM) | User/SPN lacks Reader role on subscription | Assign Reader role at subscription or Root MG |
| `Resource provider not registered` | `Microsoft.Security` or `Microsoft.Insights` not registered in subscription | See [Resource Providers](#resource-providers-registration) section |
| `Authorization failed` (SPN) | SPN secret/certificate expired or incorrect | Renew SPN credentials |
| `AADSTS50076: Multi-factor authentication required` | User MFA enforced but not completed | Complete MFA interactively or use SPN for non-interactive execution |
```

### 12.3 — Resource Provider Registration Documentation

**README.md Addition (new section):**

```markdown
## Resource Providers Registration

AzureTenantInventory inventories resources from several Azure resource providers. If a provider is **not registered** in a subscription, resources of that type will not be discovered.

### Required Resource Providers

| Resource Provider | Purpose | Modules Dependent |
|---|---|---|
| `Microsoft.Compute` | Virtual machines, availability sets, disks | VirtualMachines, VMSS, AvailabilitySets, CloudServices |
| `Microsoft.Network` | Virtual networks, NSGs, load balancers, firewalls, VPN | All Network_1 and Network_2 modules |
| `Microsoft.Storage` | Storage accounts, file shares, blob containers | StorageAccounts |
| `Microsoft.Security` | Defender for Cloud assessments, alerts, secure score, pricing | DefenderAssessments, DefenderSecureScore, DefenderAlerts, DefenderPricing |
| `Microsoft.Insights` | Azure Monitor (action groups, alert rules, DCRs, DCEs, workspaces) | ActionGroups, MetricAlertRules, ScheduledQueryRules, DataCollectionRules, DataCollectionEndpoints, Workspaces |
| `Microsoft.Maintenance` | Azure Update Manager maintenance configurations | MaintenanceConfigurations |
| `Microsoft.RecoveryServices` | Backup vaults, Site Recovery | Backup, RecoveryVault |
| `Microsoft.HybridCompute` | Arc-enabled servers, Arc gateways | ARCServers, ArcGateways, ArcExtensions |
| `Microsoft.Kubernetes` | Arc-enabled Kubernetes clusters | ArcKubernetes |
| `Microsoft.AzureStackHCI` | Azure Local clusters, logical networks, storage containers, VMs | All AzureLocal modules (Clusters, VirtualMachines, LogicalNetworks, etc.) |
| `Microsoft.ContainerService` | AKS clusters | AKS |
| `Microsoft.Web` | App Services, Function Apps, App Service Plans | APPServices, APPServicePlan |
| `Microsoft.Sql` | SQL Servers, SQL Databases | SQLSERVER, SQLDB, SQLMI, SQLPOOL |
| `Microsoft.DBforMySQL` | Azure Database for MySQL | MySQL, MySQLflexible |
| `Microsoft.DBforPostgreSQL` | Azure Database for PostgreSQL | PostgreSQL, POSTGREFlexible |
| `Microsoft.DocumentDB` | Azure Cosmos DB | CosmosDB |
| `Microsoft.Cache` | Azure Redis Cache | RedisCache |
| `Microsoft.EventHub` | Event Hub namespaces | EvtHub |
| `Microsoft.ServiceBus` | Service Bus namespaces | ServiceBUS |

### Check Resource Provider Registration

```powershell
# List all resource providers and their registration state
Get-AzResourceProvider -ListAvailable | Select-Object ProviderNamespace, RegistrationState | Sort-Object ProviderNamespace

# Check specific provider
Get-AzResourceProvider -ProviderNamespace Microsoft.Security
```

### Register Missing Resource Providers

```powershell
# Register a single provider (subscription context)
Register-AzResourceProvider -ProviderNamespace Microsoft.Security

# Register multiple providers
@('Microsoft.Security', 'Microsoft.Insights', 'Microsoft.Maintenance') | ForEach-Object {
    Write-Host "Registering $_..." -ForegroundColor Cyan
    Register-AzResourceProvider -ProviderNamespace $_
}

# Wait for registration to complete
Get-AzResourceProvider -ProviderNamespace Microsoft.Security |
    Select-Object ProviderNamespace, RegistrationState
```

**⚠️ Note:** Resource provider registration is **per subscription**. If you are scanning multiple subscriptions, register required providers in each subscription.

**⚠️ Note:** Resource provider registration requires **Contributor** or **Owner** role on the subscription. **Reader** role is NOT sufficient.

### Pre-Flight Resource Provider Check

AzureTenantInventory can optionally check resource provider registration before execution:

```powershell
Invoke-AzureTenantInventory -TenantID $tenantId -CheckResourceProviders
```

**Output Example:**
```
[WARNING] Microsoft.Security is NOT registered in subscription 'Production' (12345678-1234-1234-1234-123456789abc).
          Defender for Cloud modules will be skipped for this subscription.
          Remediation: Register-AzResourceProvider -ProviderNamespace Microsoft.Security
```

**Behavior:**
- Warnings only — execution continues
- Modules dependent on unregistered providers are skipped for that subscription
- No resources returned for resource types whose provider is unregistered
```

### 12.4 — Implementation Checklist

- [ ] **12.4.1** Update `-Scope` parameter default from `'All'` to `'ArmOnly'` in `AzureTenantInventory.psm1`
- [ ] **12.4.2** Update comment-based help (`.PARAMETER Scope`) to reflect new default
- [ ] **12.4.3** Update `README.md` Quick Start section with ARM-only default clarification
- [ ] **12.4.4** Add **Permissions** section to `README.md` (ARM permissions table + Entra ID permissions table + user vs SPN guidance)
- [ ] **12.4.5** Add **Resource Providers Registration** section to `README.md` (table of providers + check/register commands)
- [ ] **12.4.6** Implement `-CheckResourceProviders` parameter (optional) for pre-flight resource provider validation
- [ ] **12.4.7** Update `Test-AZTIPermissions` function output to include resource provider registration warnings
- [ ] **12.4.8** Update all examples in `README.md` and `.EXAMPLE` blocks to clarify when `-Scope All` is needed for Entra ID
- [ ] **12.4.9** Add troubleshooting section to `README.md` for common permission errors
- [ ] **12.4.10** Update `CHANGELOG.md` with breaking change notice: "Default scope changed from `All` to `ArmOnly`. Entra ID now requires explicit `-Scope All` or `-Scope EntraOnly`."

---

## Phase 13 — Final Testing & Validation

All acceptance checks from Phase 8 + new acceptance checks for Phases 9-12.

### 13.1 — Phase 9 Acceptance Checks (Missing ARM Features)

| # | Test | Expected Outcome |
|---|---|---|
| 1 | Run with `-Scope ArmOnly` | Excel report includes: Management Groups, Custom Roles, Policy Definitions, Policy Set Definitions, Policy Compliance, Defender Assessments, Defender Secure Score, Defender Alerts, Defender Pricing, Action Groups, Metric Alert Rules, Scheduled Query Rules, Data Collection Rules, Data Collection Endpoints, Subscription Diagnostics, Network Watchers, Lighthouse Delegations (17 new worksheets) |
| 2 | Management Groups worksheet | Displays full hierarchy with indentation, parent-child relationships, subscription assignments |
| 3 | Defender modules | Require `Microsoft.Security` provider registration; graceful skip with warning if not registered |
| 4 | Data Collection Rules | Captures DCR names, data sources (perf counters, logs, syslog), destinations (workspaces), data flows |
| 5 | MaintenanceConfigurations module | Executes in both Processing and Reporting phases; no longer incorrectly using function pattern |
| 6 | Policy Compliance States | Captures ~500 most recent compliance states (not all millions); shows resource ID, assignment, definition, state, timestamp |

### 13.2 — Phase 10 Acceptance Checks (Excel Restructuring)

| # | Test | Expected Outcome |
|---|---|---|
| 7 | Overview tab | Contains ONLY tenant metadata, auth info, scope, execution metadata. NO cost/security/monitoring content. |
| 8 | Cost Management tab | Positioned after Overview. Contains VM reservations, reservation recommendations, Advisor cost recommendations. |
| 9 | Security Overview tab | Contains Defender secure score, assessments summary, top 10 unhealthy assessments, critical alerts, Defender pricing, Advisor security recommendations, policy compliance summary. Includes score gauge chart, assessment severity pie chart, compliance bar chart. |
| 10 | Azure Update Manager Overview tab | Lists ALL Azure VMs + ALL Arc-enabled servers with: name, RG, sub, OS type, OS version, maintenance schedule assigned, patch compliance status, last patch time, pending patches count. Includes summary graphs (VMs by schedule assignment, by compliance status, by OS type, pending patches histogram). |
| 11 | Azure Monitor tab | Contains action groups, metric alert rules, scheduled query rules, DCRs, Log Analytics workspaces, Application Insights, diagnostic settings coverage. Includes alert rules by severity bar chart, DCRs by data source pie chart, diagnostic coverage by resource type stacked bar chart. |
| 12 | Tab order | Overview → Cost Management → Security Overview → Azure Update Manager Overview → Azure Monitor → [all other resource tabs] → [Entra ID tabs] |

### 13.3 — Phase 11 Acceptance Checks (Comprehensive Sub/MG Logging)

| # | Test | Expected Outcome |
|---|---|---|
| 13 | All Subscriptions worksheet | Lists EVERY subscription in tenant (including empty subscriptions with 0 resources). Shows subscription name, ID, state, management group path, resource groups count, resources count, tags, spending limit, authorization source. Empty subscriptions (resources count = 0) formatted with orange text. |
| 14 | Management Groups worksheet | Lists ALL management groups in tenant hierarchy. Shows MG name (indented by depth), MG ID, parent MG, full path, child MGs count, direct subscriptions count, direct subscription names. Indentation visually represents hierarchy. |
| 15 | Overview tab counts | Total Subscriptions = all subs (not just ones with resources). Total Management Groups = all MGs. Shows "Subscriptions with Resources" and "Empty Subscriptions" separately. |

### 13.4 — Phase 12 Acceptance Checks (Scope & Permissions)

| # | Test | Expected Outcome |
|---|---|---|
| 16 | Default run (no `-Scope` param) | `Invoke-AzureTenantInventory -TenantID $tid` performs ARM-only scan. Excel report contains NO Entra ID worksheets. JSON output contains `arm` section only (no `entra` section). |
| 17 | Explicit Entra inclusion | `Invoke-AzureTenantInventory -TenantID $tid -Scope All` scans both ARM and Entra ID. Excel report contains Entra ID worksheets. JSON output contains both `arm` and `entra` sections. |
| 18 | Permission pre-flight check | `Test-AZTIPermissions -TenantID $tid -Scope All` returns structured object with `ArmAccess`, `GraphAccess`, `Details`, `Warnings`. Warns if Graph permissions missing. Does NOT throw/block execution. |
| 19 | Resource provider check | `Invoke-AzureTenantInventory -TenantID $tid -CheckResourceProviders` warns if `Microsoft.Security`, `Microsoft.Insights`, `Microsoft.Maintenance` not registered. Execution continues; dependent modules skipped for that subscription. |
| 20 | SPN auth with Entra | `Invoke-AzureTenantInventory -TenantID $tid -AppId $appId -Secret $secret -Scope All` successfully authenticates as SPN and scans both ARM + Entra (if SPN has Graph application permissions + admin consent). |

---

## Phase 14 — Azure AI/Foundry/ML Coverage

**Goal:** Add comprehensive Azure AI, Foundry, Machine Learning, and Cognitive Services inventory.

**Current State:** ZERO coverage for AI/ML resources.

### 14.1 — Azure OpenAI Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIOpenAIAccounts.ps1` | `Microsoft.CognitiveServices/accounts` | `Get-AzCognitiveServicesAccount` (filter Kind='OpenAI') | OpenAI Accounts | Name, RG, Location, SKU name, Provisioning State, Endpoint, Custom Subdomain, Public Network Access, Private Endpoints count, Tags |
| `Get-AZTIOpenAIDeployments.ps1` | `Microsoft.CognitiveServices/accounts/deployments` | `Get-AzCognitiveServicesAccountDeployment` | OpenAI Deployments | Account Name, Deployment Name, Model Name, Model Version, Model Format, Scale Type, Capacity, Provisioning State |

### 14.2 — Azure AI Foundry Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIAIFoundryProjects.ps1` | `Microsoft.MachineLearningServices/workspaces` (Kind='Project') | `Get-AzMLWorkspace` (filter) OR Resource Graph | AI Foundry Projects | Name, RG, Location, Friendly Name, Hub Resource ID, Description, Public Network Access, Storage Account, Key Vault, Application Insights, Container Registry, Tags |
| `Get-AZTIAIFoundryHubs.ps1` | `Microsoft.MachineLearningServices/workspaces` (Kind='Hub') | `Get-AzMLWorkspace` (filter) OR Resource Graph | AI Foundry Hubs | Name, RG, Location, Friendly Name, Projects Count, SKU, Managed Network, Associated Resource IDs, Tags |

### 14.3 — Cognitive Services Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTICognitiveServices.ps1` | `Microsoft.CognitiveServices/accounts` | `Get-AzCognitiveServicesAccount` | Cognitive Services | Name, RG, Location, Kind (TextAnalytics, ComputerVision, Face, etc.), SKU name, Endpoint, Custom Subdomain, Public Network Access, API Properties, Tags |
| `Get-AZTIAppliedAIServices.ps1` | `Microsoft.CognitiveServices/accounts` | `Get-AzCognitiveServicesAccount` (filter Kind='FormRecognizer','DocumentIntelligence', etc.) | Applied AI Services | Name, RG, Location, Kind (Form Recognizer, Metrics Advisor, Anomaly Detector, Personalizer), SKU, Endpoint, Custom Domain, Tags |

### 14.4 — Machine Learning Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIMachineLearningWorkspaces.ps1` | `Microsoft.MachineLearningServices/workspaces` | `Get-AzMLWorkspace` | ML Workspaces | Name, RG, Location, Friendly Name, Description, ML Studio Web URL, Storage, Key Vault, App Insights, Container Registry, SKU, Managed Network, Public Network Access, Tags |
| `Get-AZTIMachineLearningComputes.ps1` | `Microsoft.MachineLearningServices/workspaces/computes` | `Get-AzMLWorkspaceCompute` | ML Compute | Workspace Name, Compute Name, Compute Type (AmlCompute, ComputeInstance, AKS, etc.), VM Size, VM Priority, Min/Max Nodes, State, Subnet ID, Tags |
| `Get-AZTIMachineLearningDatastores.ps1` | `Microsoft.MachineLearningServices/workspaces/datastores` | Azure SDK/REST API | ML Datastores | Workspace Name, Datastore Name, Datastore Type (AzureBlob, AzureFile, AzureDataLakeGen2, etc.), Target Storage Account, Is Default, Credentials Type |
| `Get-AZTIMachineLearningDatasets.ps1` | `Microsoft.MachineLearningServices/workspaces/datasets` | Azure SDK/REST API | ML Datasets | Workspace Name, Dataset Name, Dataset Type (Tabular, File), Data Path, Description, Version, Created Date, Tags |
| `Get-AZTIMachineLearningModels.ps1` | `Microsoft.MachineLearningServices/workspaces/models` | Azure SDK/REST API | ML Models | Workspace Name, Model Name, Version, Framework (TensorFlow, PyTorch, ONNX, Scikit-learn, etc.), Description, Tags, Created Date |
| `Get-AZTIMachineLearningEndpoints.ps1` | `Microsoft.MachineLearningServices/workspaces/onlineEndpoints` | Azure SDK/REST API | ML Endpoints | Workspace Name, Endpoint Name, Endpoint Type (Online, Batch), Auth Mode, Compute Type, Deployments Count, Traffic Allocation, Tags |

### 14.5 — Other AI/ML Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIBotServices.ps1` | `Microsoft.BotService/botServices` | `Get-AzBotService` | Bot Services | Name, RG, Location, SKU, Messaging Endpoint, App ID, MsaAppType, Developer App Insight Key, IsCmekEnabled, Tags |
| `Get-AZTICognitiveSearch.ps1` | `Microsoft.Search/searchServices` | `Get-AzSearchService` | Cognitive Search | Name, RG, Location, SKU name, Replica Count, Partition Count, Hosting Mode, Status, Public Network Access, Private Endpoint Connections, Tags |
| `Get-AZTISearchIndexes.ps1` | `Microsoft.Search/searchServices/indexes` | REST API | Search Indexes | Service Name, Index Name, Document Count, Storage Size MB, Fields Count, Analyzers Count, Scoring Profiles, CORS Options |

### 14.6 — Resource Provider Requirements

**Required Resource Providers:**
- `Microsoft.CognitiveServices` (for OpenAI, Cognitive Services, Applied AI)
- `Microsoft.MachineLearningServices` (for ML Workspaces, AI Foundry)
- `Microsoft.BotService` (for Bot Services)
- `Microsoft.Search` (for Cognitive Search)

**Registration Check:**
```powershell
$aiProviders = @(
    'Microsoft.CognitiveServices',
    'Microsoft.MachineLearningServices',
    'Microsoft.BotService',
    'Microsoft.Search'
)

$aiProviders | ForEach-Object {
    Register-AzResourceProvider -ProviderNamespace $_
}
```

### 14.7 — Implementation Guidelines

**Azure SDK Requirements:**
- **Azure Machine Learning SDK for PowerShell** is deprecated
- Use **Azure REST API** or **Azure CLI** for ML workspaces data (datastores, datasets, models, endpoints)
- Alternative: Use `Invoke-AzRestMethod` with ARM endpoints

**REST API Endpoints:**
```powershell
# ML Datastores
$apiVersion = "2023-04-01"
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.MachineLearningServices/workspaces/$workspace/datastores?api-version=$apiVersion"
$datastores = (Invoke-AzRestMethod -Uri $uri -Method GET).Content | ConvertFrom-Json

# ML Datasets
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.MachineLearningServices/workspaces/$workspace/data?api-version=$apiVersion"
$datasets = (Invoke-AzRestMethod -Uri $uri -Method GET).Content | ConvertFrom-Json

# ML Models
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.MachineLearningServices/workspaces/$workspace/models?api-version=$apiVersion"
$models = (Invoke-AzRestMethod -Uri $uri -Method GET).Content | ConvertFrom-Json

# ML Endpoints
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.MachineLearningServices/workspaces/$workspace/onlineEndpoints?api-version=$apiVersion"
$endpoints = (Invoke-AzRestMethod -Uri $uri -Method GET).Content | ConvertFrom-Json
```

**AI Foundry Detection:**
- AI Foundry Projects and Hubs are **ML Workspaces** with special `kind` or `workspaceFeatures` properties
- Use Resource Graph to filter: `| where kind == 'Project'` or `| where kind == 'Hub'`
- Alternative: Check workspace properties for `workspaceFeatures` array

### 14.8 — Excel Tab Placement

**New Tab Order:**
- Place AI/ML tabs **after Azure Monitor** tab (before AVD, before Arc resources)
- Suggested order: OpenAI Accounts → OpenAI Deployments → AI Foundry Hubs → AI Foundry Projects → Cognitive Services → Applied AI Services → ML Workspaces → ML Compute → ML Datastores → ML Datasets → ML Models → ML Endpoints → Bot Services → Cognitive Search → Search Indexes

### 14.9 — Implementation Checklist

- [ ] **14.9.1** Create `Get-AZTIOpenAIAccounts.ps1` and `Get-AZTIOpenAIDeployments.ps1`
- [ ] **14.9.2** Create `Get-AZTIAIFoundryProjects.ps1` and `Get-AZTIAIFoundryHubs.ps1`
- [ ] **14.9.3** Create `Get-AZTICognitiveServices.ps1` and `Get-AZTIAppliedAIServices.ps1`
- [ ] **14.9.4** Create `Get-AZTIMachineLearningWorkspaces.ps1` and `Get-AZTIMachineLearningComputes.ps1`
- [ ] **14.9.5** Create ML data modules (Datastores, Datasets, Models, Endpoints) using REST API
- [ ] **14.9.6** Create `Get-AZTIBotServices.ps1` and `Get-AZTICognitiveSearch.ps1`
- [ ] **14.9.7** Create `Get-AZTISearchIndexes.ps1` using REST API
- [ ] **14.9.8** Add all 15 AI/ML modules to Excel generation logic
- [ ] **14.9.9** Test with tenant containing OpenAI, AI Foundry, ML workspaces, Cognitive Search
- [ ] **14.9.10** Verify resource provider registration warnings for AI/ML providers

---

## Phase 15 — Azure Virtual Desktop Coverage

**Goal:** Add comprehensive Azure Virtual Desktop (AVD) inventory including AVD on Azure Local/Arc.

**Current State:** ZERO coverage for AVD resources.

### 15.1 — AVD Modules

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIAVDHostPools.ps1` | `Microsoft.DesktopVirtualization/hostPools` | `Get-AzWvdHostPool` | AVD Host Pools | Name, RG, Location, Host Pool Type (Pooled/Personal), Load Balancer Type, Max Session Limit, Preferred App Group Type, Start VM On Connect, Registration Token Expiration, Validation Environment, VM Template, Arc Enabled (Azure Local/Arc), Tags |
| `Get-AZTIAVDApplicationGroups.ps1` | `Microsoft.DesktopVirtualization/applicationGroups` | `Get-AzWvdApplicationGroup` | AVD Application Groups | Name, RG, Location, Host Pool ID, Application Group Type (RemoteApp/Desktop), Friendly Name, Description, Applications Count, Workspace Associations, Tags |
| `Get-AZTIAVDWorkspaces.ps1` | `Microsoft.DesktopVirtualization/workspaces` | `Get-AzWvdWorkspace` | AVD Workspaces | Name, RG, Location, Friendly Name, Description, Application Group References, Public Network Access, Private Endpoint Connections, Tags |
| `Get-AZTIAVDSessionHosts.ps1` | `Microsoft.DesktopVirtualization/hostPools/sessionHosts` | `Get-AzWvdSessionHost` | AVD Session Hosts | Host Pool Name, Session Host Name, Agent Version, Status, Last Heartbeat, OS Version, Sessions Count, Assigned User (Personal Pool), Allow New Session, Update State, Arc Machine ID (if Arc-enabled), Azure Local Cluster ID (if Azure Local), Tags |
| `Get-AZTIAVDScalingPlans.ps1` | `Microsoft.DesktopVirtualization/scalingPlans` | `Get-AzWvdScalingPlan` | AVD Scaling Plans | Name, RG, Location, Time Zone, Exclusion Tag, Schedules Count, Host Pool References, Host Pool Type, Schedules (Days of Week, Ramp Up/Down times, Peak hours, Capacity %), Tags |
| `Get-AZTIAVDApplications.ps1` | `Microsoft.DesktopVirtualization/applicationGroups/applications` | `Get-AzWvdApplication` | AVD Applications | Application Group Name, App Name, App Alias, App Path, Command Line Arguments, Icon Path, Icon Index, Show In Portal, Description |

### 15.2 — Resource Provider Requirements

**Required Resource Providers:**
- `Microsoft.DesktopVirtualization` (for AVD resources)
- `Microsoft.HybridCompute` (for Arc-enabled AVD session hosts)
- `Microsoft.AzureStackHCI` (for Azure Local/HCI-based AVD)

**Registration Check:**
```powershell
@('Microsoft.DesktopVirtualization', 'Microsoft.HybridCompute', 'Microsoft.AzureStackHCI') | ForEach-Object {
    Register-AzResourceProvider -ProviderNamespace $_
}
```

### 15.3 — AVD on Azure Local / Arc Detection

**Azure Local AVD Session Hosts:**
- Session hosts can be deployed on **Azure Local (HCI)** clusters
- Use `Get-AzWvdSessionHost` to retrieve session host details
- Check properties for Arc Machine ID or Azure Local cluster association
- **Detection Logic:**
  - Session host name includes Arc machine reference
  - Associated with Azure Local cluster resource
  - Custom properties indicate hybrid deployment

**Example Detection:**
```powershell
$sessionHost = Get-AzWvdSessionHost -HostPoolName "MyHostPool" -ResourceGroupName "MyRG"
if ($sessionHost.ResourceId -like "*Microsoft.HybridCompute/machines*") {
    # This is an Arc-enabled session host (Azure Local or on-prem)
    $arcMachineId = $sessionHost.ResourceId
}
```

### 15.4 — Scaling Plans Details

**Scaling Plan Schedules:**
- Each scaling plan can have multiple schedules (weekdays, weekends, custom)
- Schedule properties:
  - **Days of Week**: Which days this schedule applies
  - **Ramp Up Start Time**: When to start increasing capacity
  - **Ramp Up Load Balancing Algorithm**: Breadth-first or Depth-first
  - **Ramp Up Minimum % of Hosts**: Minimum % of session hosts to keep running
  - **Ramp Up Capacity Threshold %**: Session threshold to trigger new hosts
  - **Peak Start Time**: When peak hours begin
  - **Peak Load Balancing Algorithm**: Breadth-first or Depth-first
  - **Ramp Down Start Time**: When to start decreasing capacity
  - **Ramp Down Load Balancing Algorithm**: Breadth-first or Depth-first
  - **Ramp Down Minimum % of Hosts**: Minimum % to maintain
  - **Ramp Down Capacity Threshold %**: Session threshold to shut down hosts
  - **Ramp Down Force Logoff Users**: Whether to force logoff
  - **Ramp Down Wait Time Minutes**: Grace period before logoff
  - **Ramp Down Notification Message**: Message shown to users
  - **Off Peak Start Time**: When off-peak hours begin
  - **Off Peak Load Balancing Algorithm**: Breadth-first or Depth-first

**Capture ALL schedule details** in AVD Scaling Plans worksheet with nested schedule rows.

### 15.5 — Excel Tab Placement

**New Tab Order:**
- Place AVD tabs **after AI/ML tabs** (before Arc resources)
- Suggested order: AVD Host Pools → AVD Application Groups → AVD Workspaces → AVD Session Hosts → AVD Scaling Plans → AVD Applications

### 15.6 — Implementation Checklist

- [ ] **15.6.1** Create `Get-AZTIAVDHostPools.ps1`
- [ ] **15.6.2** Create `Get-AZTIAVDApplicationGroups.ps1`
- [ ] **15.6.3** Create `Get-AZTIAVDWorkspaces.ps1`
- [ ] **15.6.4** Create `Get-AZTIAVDSessionHosts.ps1` with Arc/Azure Local detection
- [ ] **15.6.5** Create `Get-AZTIAVDScalingPlans.ps1` with nested schedules
- [ ] **15.6.6** Create `Get-AZTIAVDApplications.ps1`
- [ ] **15.6.7** Add all 6 AVD modules to Excel generation logic
- [ ] **15.6.8** Test with tenant containing AVD deployment (Azure VMs + Arc/Azure Local session hosts)
- [ ] **15.6.9** Verify scaling plan schedules are fully captured (all time periods, thresholds, algorithms)
- [ ] **15.6.10** Verify Arc-enabled session host detection and Azure Local cluster association

---

## Phase 16 — Arc Enhanced Configuration

**Goal:** Enhance existing Arc modules with deeper configuration data and add Arc-specific resources.

**Current State:** Basic Arc coverage exists. Need deeper config data + new Arc resource types.

### 16.1 — Arc Site Configurations (NEW)

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIArcSites.ps1` | `Microsoft.AzureStackHCI/sites` OR `Microsoft.EdgeConfig/sites` | `Get-AzResource` (filter) | Arc Sites | Name, RG, Location, Site Type, Associated Cluster, Management State, Network Configuration, On-Premises Location, Tags |

**Arc Sites:**
- Arc Sites represent physical locations/sites for Arc-enabled infrastructure
- Used in Azure Local (HCI), Arc-enabled Kubernetes, Arc-enabled VMware
- Captures network configs, management endpoints, site metadata

### 16.2 — Enhanced Arc Extensions

**Enhancement to `Get-AZTIArcMachineExtensions.ps1` (existing module):**

**Add Deep Config Data:**
- Extension settings (JSON)
- Protected settings (presence indicator, not values)
- Auto-upgrade minor version setting
- Enable automatic upgrade
- Provisioning state
- Instance view (status messages, sub-statuses, time)

**Example:**
```powershell
$extension = Get-AzConnectedMachineExtension -MachineName $machine -ResourceGroupName $rg -Name $extName

# Capture deep config
$deepConfig = [PSCustomObject]@{
    MachineName = $machine
    ExtensionName = $extName
    Publisher = $extension.Publisher
    ExtensionType = $extension.MachineExtensionType
    TypeHandlerVersion = $extension.TypeHandlerVersion
    Settings = ($extension.Settings | ConvertTo-Json -Compress)
    HasProtectedSettings = [bool]$extension.ProtectedSettings
    AutoUpgradeMinorVersion = $extension.AutoUpgradeMinorVersion
    EnableAutomaticUpgrade = $extension.EnableAutomaticUpgrade
    ProvisioningState = $extension.ProvisioningState
    InstanceViewStatus = $extension.InstanceView.Status.DisplayStatus
    InstanceViewMessage = $extension.InstanceView.Status.Message
    InstanceViewTime = $extension.InstanceView.Status.Time
}
```

### 16.3 — Arc-Enabled SQL Server (NEW)

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIArcSQLServers.ps1` | `Microsoft.AzureArcData/sqlServerInstances` | `Get-AzResource` (filter) | Arc SQL Servers | Name, RG, Location, Host Machine Name, SQL Version, Edition, Licensing Type (PAYG/LicenseOnly), vCores, Patch Level, Collation, Status, Azure Defender Enabled, Tags |

**Arc-Enabled SQL Server:**
- On-premises SQL Servers registered with Azure Arc
- Provides inventory, patching, Azure Defender, best practices assessment
- **NOT** Azure SQL Managed Instance on Arc (different resource type)

### 16.4 — Arc Data Services (NEW)

| File | Resource Type | API Call | Excel Worksheet | Key Fields Captured |
|---|---|---|---|---|
| `Get-AZTIArcDataControllers.ps1` | `Microsoft.AzureArcData/dataControllers` | `Get-AzResource` (filter) | Arc Data Controllers | Name, RG, Location, Kubernetes Cluster ID, Connectivity Mode (Direct/Indirect), Log Analytics Workspace, Metrics Upload State, Logs Upload State, Tags |
| `Get-AZTIArcSQLManagedInstances.ps1` | `Microsoft.AzureArcData/sqlManagedInstances` | `Get-AzResource` (filter) | Arc SQL Managed Instances | Name, RG, Location, Data Controller ID, Admin Username, SQL Version, vCores, Storage Size GB, Service Tier, License Type, High Availability Mode, Tags |

**Arc Data Services:**
- **Data Controller**: Management plane for Arc-enabled data services
- **SQL Managed Instance on Arc**: Azure SQL MI deployed on-premises/edge via Arc
- **PostgreSQL Hyperscale on Arc**: Azure Database for PostgreSQL deployed on-premises/edge (deprecated by MSFT, but may exist)

### 16.5 — Enhanced Arc Resource Bridge

**Enhancement to existing Arc Resource Bridge module:**

**Add Config Data:**
- Appliance type (HCI, VMware, SCVMM)
- Appliance version
- Cluster extension ID
- Kubeconfig (presence indicator)
- Connected cluster resource ID
- Provisioning state
- Status details

### 16.6 — Implementation Checklist

- [ ] **16.6.1** Create `Get-AZTIArcSites.ps1` for Arc site configurations
- [ ] **16.6.2** Enhance `Get-AZTIArcMachineExtensions.ps1` with deep config data (settings, instance view, auto-upgrade)
- [ ] **16.6.3** Create `Get-AZTIArcSQLServers.ps1` for Arc-enabled SQL Server instances
- [ ] **16.6.4** Create `Get-AZTIArcDataControllers.ps1` and `Get-AZTIArcSQLManagedInstances.ps1`
- [ ] **16.6.5** Enhance Arc Resource Bridge module with config data
- [ ] **16.6.6** Add new modules to Excel generation logic
- [ ] **16.6.7** Test with tenant containing Arc SQL Server, Arc Data Controller, Arc sites
- [ ] **16.6.8** Verify Arc extension config data is fully captured
- [ ] **16.6.9** Update Arc-related tabs in Excel (extensions deep config, new tabs for Arc SQL, Arc Data)

---

## Phase 17 — VM Data Enhancement

**Goal:** Add deep operational data to Azure VMs and Arc VMs (performance, backup, DR, compliance, cost, recommendations).

**Current State:** Basic VM inventory exists. Need operational/lifecycle data from Azure Monitor, Backup, Advisor, Update Manager, Cost Management.

### 17.1 — Azure VM Enhancements

**Enhance `Get-AZTIVirtualMachines.ps1` (existing module) with 10 new data points:**

| # | New Data Point | Source API | Description |
|---|---|---|---|
| 1 | **VM Extensions Installed** | `Get-AzVMExtension` | List of extensions (MMA, AMA, Dependency Agent, etc.) |
| 2 | **Boot Diagnostics Enabled** | VM properties | Whether boot diagnostics is enabled + storage URI |
| 3 | **Performance Metrics (7 days avg)** | Azure Monitor Metrics API | CPU %, Memory %, Disk IOPS, Network In/Out |
| 4 | **Security Baseline Compliance** | Defender for Cloud Assessments API | Security baseline assessment status (compliant/non-compliant) |
| 5 | **Update Compliance Status** | Update Manager API | Patch compliance (Critical/Important pending, last patch time) |
| 6 | **Backup Status** | Azure Backup API | Backup enabled (Y/N), Last backup time, Recovery vault name, Backup policy |
| 7 | **Disaster Recovery Status** | Site Recovery API | DR enabled (Y/N), Target region, Replication health, Failover readiness |
| 8 | **Estimated Monthly Cost** | Cost Management API | Estimated monthly cost for VM (compute + storage + network) |
| 9 | **Advisor Recommendations Count** | Azure Advisor API | Count of Advisor recommendations (Cost, Security, Reliability, Performance) |
| 10 | **Lifecycle Tags** | VM tags | Environment (Prod/Dev/Test), Owner, Cost Center, Expiration Date |

### 17.2 — Arc VM Enhancements

**Enhance `Get-AZTIArcMachines.ps1` (existing module) with 10 new data points:**

| # | New Data Point | Source API | Description |
|---|---|---|---|
| 1 | **OS Details (Full)** | Arc machine properties | OS Name, OS Version, OS SKU, OS Edition, Install Date |
| 2 | **Arc Agent Health** | Arc machine properties | Last heartbeat, Agent version, Connection status, Agent status message |
| 3 | **Extensions Installed** | `Get-AzConnectedMachineExtension` | List of extensions (MMA, AMA, Dependency, Update Manager, Defender, etc.) |
| 4 | **Azure Policies Assigned** | Policy Compliance API | Count of policies assigned, compliance state (Compliant/Non-Compliant count) |
| 5 | **Performance Metrics (7 days avg)** | Azure Monitor Metrics API (if AMA installed) | CPU %, Memory %, Disk IOPS, Network In/Out |
| 6 | **Security Baseline Compliance** | Defender for Cloud Assessments API | Security baseline assessment status |
| 7 | **Update Compliance Status** | Update Manager API | Patch compliance (Critical/Important pending, last patch time) |
| 8 | **Backup Status** | Azure Backup API (MARS agent or Azure Backup) | Backup enabled (Y/N), Last backup time, Policy name |
| 9 | **Estimated Monthly Cost** | Cost Management API (Arc licensing + extensions cost) | Estimated monthly cost for Arc licensing + Azure services |
| 10 | **Lifecycle Tags** | Arc machine tags | Environment, Owner, Cost Center, Expiration Date, Physical Location |

### 17.3 — New APIs Required

**Azure Monitor Metrics API:**
```powershell
# Get CPU % for VM (7-day average)
$metric = Get-AzMetric -ResourceId $vmResourceId -MetricName "Percentage CPU" `
    -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) `
    -AggregationType Average

$avgCpu = ($metric.Data.Average | Measure-Object -Average).Average
```

**Azure Backup API:**
```powershell
# Check if VM is backed up
$backupItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM `
    -WorkloadType AzureVM | Where-Object { $_.VirtualMachineId -eq $vmResourceId }

if ($backupItem) {
    $lastBackup = $backupItem.LastBackupTime
    $vaultName = $backupItem.ContainerName
    $policyName = $backupItem.ProtectionPolicyName
}
```

**Site Recovery API:**
```powershell
# Check if VM has DR enabled
$asrItem = Get-AzRecoveryServicesAsrReplicationProtectedItem `
    | Where-Object { $_.ProviderSpecificDetails.FabricObjectId -eq $vmResourceId }

if ($asrItem) {
    $drEnabled = $true
    $targetRegion = $asrItem.ProviderSpecificDetails.RecoveryAzureVMName
    $replicationHealth = $asrItem.ReplicationHealth
}
```

**Azure Advisor API:**
```powershell
# Get Advisor recommendations for VM
$recommendations = Get-AzAdvisorRecommendation -ResourceId $vmResourceId
$costRecs = ($recommendations | Where-Object { $_.Category -eq 'Cost' }).Count
$securityRecs = ($recommendations | Where-Object { $_.Category -eq 'Security' }).Count
```

**Cost Management API:**
```powershell
# Get estimated monthly cost for VM
$costQuery = @{
    type = "ActualCost"
    timeframe = "MonthToDate"
    dataset = @{
        granularity = "None"
        aggregation = @{
            totalCost = @{
                name = "Cost"
                function = "Sum"
            }
        }
        filter = @{
            dimensions = @{
                name = "ResourceId"
                operator = "In"
                values = @($vmResourceId)
            }
        }
    }
} | ConvertTo-Json -Depth 10

$cost = Invoke-AzRestMethod -Path "/subscriptions/$subId/providers/Microsoft.CostManagement/query?api-version=2023-03-01" `
    -Method POST -Payload $costQuery
```

**Update Manager API:**
```powershell
# Get update assessment for VM
$assessment = Get-AzMaintenanceUpdate -ResourceId $vmResourceId
$criticalCount = ($assessment | Where-Object { $_.Classification -eq 'Critical' }).Count
$importantCount = ($assessment | Where-Object { $_.Classification -eq 'Important' }).Count
$lastPatchTime = $assessment.LastUpdated
```

### 17.4 — Excel Column Updates

**Azure VMs Worksheet - Add Columns:**
- Extensions Installed (comma-separated)
- Boot Diagnostics (Y/N)
- Avg CPU % (7d)
- Avg Memory % (7d)
- Security Baseline Compliant (Y/N)
- Pending Critical Patches
- Pending Important Patches
- Last Patch Date
- Backup Enabled (Y/N)
- Last Backup
- DR Enabled (Y/N)
- Estimated Monthly Cost USD
- Advisor Recommendations Count
- Environment Tag
- Owner Tag
- Cost Center Tag

**Arc Machines Worksheet - Add Columns:**
- OS Name
- OS Version
- OS Edition
- Arc Agent Version
- Last Heartbeat
- Extensions Installed (comma-separated)
- Policies Assigned
- Policies Compliant
- Avg CPU % (7d)
- Security Baseline Compliant (Y/N)
- Pending Critical Patches
- Last Patch Date
- Backup Enabled (Y/N)
- Estimated Monthly Cost USD
- Environment Tag
- Physical Location Tag

### 17.5 — Performance Considerations

**API Call Optimization:**
- **Batch API calls** where possible (e.g., get all backup items for subscription, then filter)
- **Parallelize** VM enhancement data collection (Process VMs in batches of 10-20 using `ForEach-Object -Parallel`)
- **Cache** Advisor recommendations, Cost Management data at subscription level (one API call per subscription, not per VM)
- **Conditional collection**: Only query backup/DR APIs if Recovery Services vaults exist in subscription
- **Throttle** Azure Monitor Metrics API calls (max 1500 per hour per subscription)

**Example Parallel Processing:**
```powershell
$vms = Get-AzVM
$vmData = $vms | ForEach-Object -Parallel {
    $vm = $_

    # Collect extensions
    $extensions = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name

    # Collect metrics (7-day avg CPU)
    $metric = Get-AzMetric -ResourceId $vm.Id -MetricName "Percentage CPU" `
        -TimeGrain 01:00:00 -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date) -AggregationType Average
    $avgCpu = ($metric.Data.Average | Measure-Object -Average).Average

    # Return enriched VM object
    $vm | Add-Member -NotePropertyName 'ExtensionsInstalled' -NotePropertyValue ($extensions.Name -join ', ')
    $vm | Add-Member -NotePropertyName 'AvgCpu7Days' -NotePropertyValue $avgCpu
    $vm
} -ThrottleLimit 20
```

### 17.6 — Implementation Checklist

- [ ] **17.6.1** Enhance `Get-AZTIVirtualMachines.ps1` with 10 new data points
- [ ] **17.6.2** Enhance `Get-AZTIArcMachines.ps1` with 10 new data points
- [ ] **17.6.3** Implement Azure Monitor Metrics API integration (CPU, Memory, Disk, Network)
- [ ] **17.6.4** Implement Azure Backup API integration (backup status, last backup time)
- [ ] **17.6.5** Implement Site Recovery API integration (DR status, replication health)
- [ ] **17.6.6** Implement Azure Advisor API integration (recommendations count by category)
- [ ] **17.6.7** Implement Cost Management API integration (estimated monthly cost)
- [ ] **17.6.8** Implement Update Manager API integration (patch compliance)
- [ ] **17.6.9** Add new columns to Azure VMs and Arc Machines Excel worksheets
- [ ] **17.6.10** Implement parallel processing for VM data collection
- [ ] **17.6.11** Add caching for subscription-level data (Advisor, Cost Management)
- [ ] **17.6.12** Test with large VM inventory (100+ VMs) to verify performance
- [ ] **17.6.13** Add error handling for VMs without extensions/backup/DR (graceful degradation)
- [ ] **17.6.14** Update `README.md` with new VM data points and required permissions

---

## Phase 18 — Category-Based Filtering

**Goal:** Enable selective module execution by Azure resource category (matching Azure Portal taxonomy).

**Current State:** All modules run by default. No category-based filtering.

### 18.1 — Module Folder Restructure

**Goal:** Align repository folder structure with Microsoft's 18 official Azure categories for perfect consistency between folder names, `.CATEGORY` metadata headers, and ValidateSet parameter options.

**Rationale:** Before adding `.CATEGORY` metadata to 145 modules, ensure folder structure matches Microsoft taxonomy exactly. This creates alignment across:
- Physical folder names in repository
- `.CATEGORY` comment-based help headers
- ValidateSet options for `-Category` parameter
- Developer expectations when adding new modules in Phases 9-17

**Current State Analysis:**

**Modules Location:** `Modules/Public/InventoryModules/` contains 111 resource inventory modules across 17 folders.

**Folder Alignment Assessment:**
```
Current Folder          Modules  Microsoft Category           Action Required
──────────────────────  ───────  ───────────────────────────  ─────────────────────
AI/                     14       AI + machine learning        ✅ Keep (perfect match)
Analytics/              6        Analytics                    ✅ Keep (perfect match)
APIs/                   5        (utility modules)            🔄 Redistribute & Delete
AzureLocal/             6        Hybrid + multicloud          🔄 Move to Hybrid/ & Delete
Compute/                7        Compute                      ✅ Keep (perfect match)
Container/              6        Containers                   🔄 Rename (singular→plural)
Database/               13       Databases                    🔄 Rename (singular→plural)
Hybrid/                 5        Hybrid + multicloud          ✅ Keep + Add 6 from AzureLocal
Identity/               15       Identity                     ✅ Keep + Add 1 from APIs
Integration/            2        Integration                  ✅ Keep (perfect match)
IoT/                    1        Internet of Things           ✅ Keep (perfect match)
Management/             4        Management and governance    ✅ Keep + Add 3 from APIs
Monitoring/             2        Monitor                      🔄 Rename (different name)
Network/                20       Networking                   🔄 Rename (different name)
Security/               1        Security                     ✅ Keep (perfect match)
Storage/                2        Storage                      ✅ Keep (perfect match)
Web/                    2        Web & Mobile                 ✅ Keep (perfect match)
──────────────────────  ───────  ───────────────────────────  ─────────────────────
Total: 17 folders       111      15 categories populated      4 renames + 7 moves + 2 deletions
```

**Folder Rename Operations (4 total):**

```powershell
# Execute folder renames (PowerShell commands)
# Current working directory: c:\git\thisismydemo-azure-inventory\

# 1. Container → Containers (plural to match Microsoft category name)
Rename-Item -Path "Modules\Public\InventoryModules\Container" -NewName "Containers"

# 2. Database → Databases (plural to match Microsoft category name)
Rename-Item -Path "Modules\Public\InventoryModules\Database" -NewName "Databases"

# 3. Monitoring → Monitor (exact match to Microsoft category name)
Rename-Item -Path "Modules\Public\InventoryModules\Monitoring" -NewName "Monitor"

# 4. Network → Networking (exact match to Microsoft category name)
Rename-Item -Path "Modules\Public\InventoryModules\Network" -NewName "Networking"
```

**Module Redistribution Script (7 modules across 2 folders):**

```powershell
# Move all AzureLocal modules to Hybrid/ (Azure Local IS hybrid infrastructure per Microsoft taxonomy)
$azureLocalModules = Get-ChildItem -Path "Modules\Public\InventoryModules\AzureLocal\*.ps1"
foreach ($module in $azureLocalModules) {
    Move-Item -Path $module.FullName -Destination "Modules\Public\InventoryModules\Hybrid\" -Force
    Write-Host "Moved: $($module.Name) → Hybrid/" -ForegroundColor Green
}

# Expected: 6 modules moved
# - Clusters.ps1, GalleryImages.ps1, LogicalNetworks.ps1
# - MarketplaceGalleryImages.ps1, StorageContainers.ps1, VirtualMachines.ps1

# Redistribute APIs utility modules to correct categories
Move-Item -Path "Modules\Public\InventoryModules\APIs\AdvisorScore.ps1" `
    -Destination "Modules\Public\InventoryModules\Management\" -Force
Move-Item -Path "Modules\Public\InventoryModules\APIs\ManagedIds.ps1" `
    -Destination "Modules\Public\InventoryModules\Identity\" -Force
Move-Item -Path "Modules\Public\InventoryModules\APIs\Outages.ps1" `
    -Destination "Modules\Public\InventoryModules\Monitor\" -Force
Move-Item -Path "Modules\Public\InventoryModules\APIs\ReservationRecom.ps1" `
    -Destination "Modules\Public\InventoryModules\Management\" -Force
Move-Item -Path "Modules\Public\InventoryModules\APIs\SupportTickets.ps1" `
    -Destination "Modules\Public\InventoryModules\Management\" -Force

# Expected: 5 modules redistributed
# - Management/ gets: AdvisorScore, ReservationRecom, SupportTickets (3 total)
# - Identity/ gets: ManagedIds (1 total)
# - Monitor/ gets: Outages (1 total)
```

**Folder Deletion (2 folders after emptying):**

```powershell
# Verify folders are empty before deletion
if ((Get-ChildItem -Path "Modules\Public\InventoryModules\AzureLocal" -File).Count -eq 0) {
    Remove-Item -Path "Modules\Public\InventoryModules\AzureLocal" -Recurse -Force
    Write-Host "Deleted: AzureLocal/ (contents moved to Hybrid/)" -ForegroundColor Cyan
}

if ((Get-ChildItem -Path "Modules\Public\InventoryModules\APIs" -File).Count -eq 0) {
    Remove-Item -Path "Modules\Public\InventoryModules\APIs" -Recurse -Force
    Write-Host "Deleted: APIs/ (contents redistributed to Management/Identity/Monitor)" -ForegroundColor Cyan
}
```

**Target Folder Structure (After Restructure):**

```
Modules/Public/InventoryModules/
├── AI/                     14 modules  → AI + machine learning
├── Analytics/              6 modules   → Analytics
├── Compute/                7 modules   → Compute
├── Containers/             6 modules   → Containers (renamed from Container/)
├── Databases/              13 modules  → Databases (renamed from Database/)
├── Hybrid/                 11 modules  → Hybrid + multicloud (5 Arc + 6 AzureLocal)
├── Identity/               16 modules  → Identity (15 + ManagedIds from APIs)
├── Integration/            2 modules   → Integration
├── IoT/                    1 module    → Internet of Things
├── Management/             7 modules   → Management and governance (4 + 3 from APIs)
├── Monitor/                3 modules   → Monitor (2 + Outages from APIs, renamed from Monitoring/)
├── Networking/             20 modules  → Networking (renamed from Network/)
├── Security/               1 module    → Security
├── Storage/                2 modules   → Storage
└── Web/                    2 modules   → Web & Mobile
───────────────────────────────────────────────────────────────
Total: 15 folders           111 modules → 15 Microsoft categories (perfect 1:1 alignment)
```

**Module Loader Impact Analysis:**

**Module Auto-Discovery System:**
The tool uses PowerShell's `Get-ChildItem` to auto-discover modules in `Modules/Public/InventoryModules/*/*.ps1`. Folder restructure does **NOT** break this pattern because:
- Modules still in `Modules/Public/InventoryModules/*/ModuleName.ps1` structure
- Module file names unchanged (only parent folder names changed)
- Auto-discovery recursively scans all subdirectories regardless of folder names

**Explicit Import Statements:**
Check for any hardcoded folder references in:
```powershell
# Search for hardcoded folder paths
Get-ChildItem -Path "Modules\" -Recurse -Filter "*.ps1" | Select-String -Pattern "InventoryModules\\(Container|Database|Monitoring|Network|AzureLocal|APIs)\\"
```

**Testing Strategy:**

```powershell
# Validation Script: Test-AZTIModuleStructure.ps1
# Run after restructure to verify all 145 modules still load

$errors = @()

# 1. Verify all 15 restructured folders exist
$expectedFolders = @('AI', 'Analytics', 'Compute', 'Containers', 'Databases', 'Hybrid',
    'Identity', 'Integration', 'IoT', 'Management', 'Monitor', 'Networking', 'Security',
    'Storage', 'Web')

foreach ($folder in $expectedFolders) {
    $path = "Modules\Public\InventoryModules\$folder"
    if (-not (Test-Path $path)) {
        $errors += "Missing folder: $folder"
    }
}

# 2. Verify old folders deleted
$deletedFolders = @('AzureLocal', 'APIs', 'Container', 'Database', 'Monitoring', 'Network')
foreach ($folder in $deletedFolders) {
    $path = "Modules\Public\InventoryModules\$folder"
    if (Test-Path $path) {
        $errors += "Old folder still exists: $folder (should be deleted/renamed)"
    }
}

# 3. Verify module count (should still be 111 inventory modules)
$moduleCount = (Get-ChildItem -Path "Modules\Public\InventoryModules\*\*.ps1" -Recurse).Count
if ($moduleCount -ne 111) {
    $errors += "Module count mismatch: Expected 111, Found $moduleCount"
}

# 4. Test module auto-discovery (verify all modules load)
Import-Module .\AzureTenantInventory.psd1 -Force
$loadedCommands = Get-Command -Module AzureTenantInventory | Measure-Object | Select-Object -ExpandProperty Count
if ($loadedCommands -lt 145) {
    $errors += "Module auto-discovery failed: Only $loadedCommands commands loaded (expected 145+)"
}

# 5. Verify specific redistributed modules in correct locations
$redistributionTests = @{
    'Hybrid\Clusters.ps1' = 'AzureLocal Clusters should be in Hybrid/'
    'Hybrid\VirtualMachines.ps1' = 'AzureLocal VMs should be in Hybrid/'
    'Identity\ManagedIds.ps1' = 'ManagedIds should be in Identity/'
    'Management\AdvisorScore.ps1' = 'AdvisorScore should be in Management/'
    'Monitor\Outages.ps1' = 'Outages should be in Monitor/'
    'Containers\AKS.ps1' = 'AKS should be in renamed Containers/ folder'
    'Databases\CosmosDB.ps1' = 'CosmosDB should be in renamed Databases/ folder'
    'Networking\VirtualNetwork.ps1' = 'VirtualNetwork should be in renamed Networking/ folder'
}

foreach ($module in $redistributionTests.Keys) {
    if (-not (Test-Path "Modules\Public\InventoryModules\$module")) {
        $errors += $redistributionTests[$module]
    }
}

# Report results
if ($errors.Count -eq 0) {
    Write-Host "✅ SUCCESS: Folder restructure validated. All 145 modules load correctly." -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: Folder restructure validation failed:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
```

**Implementation Checklist:**
- [ ] **18.1.1** Execute 4 folder renames (Container→Containers, Database→Databases, Monitoring→Monitor, Network→Networking)
- [ ] **18.1.2** Move 6 AzureLocal modules to Hybrid/
- [ ] **18.1.3** Move 5 APIs modules to Management/Identity/Monitor/
- [ ] **18.1.4** Delete empty AzureLocal/ folder
- [ ] **18.1.5** Delete empty APIs/ folder
- [ ] **18.1.6** Search codebase for hardcoded folder path references
- [ ] **18.1.7** Update any hardcoded paths found
- [ ] **18.1.8** Run `Test-AZTIModuleStructure.ps1` validation script
- [ ] **18.1.9** Verify module count: 111 inventory modules across 15 folders
- [ ] **18.1.10** Test module auto-discovery: `Import-Module .\AzureTenantInventory.psd1`
- [ ] **18.1.11** Verify all 145 commands load (Public + Private + Inventory)
- [ ] **18.1.12** Run `Invoke-AzureTenantInventory` smoke test (verify no errors from restructure)
- [ ] **18.1.13** Verify Excel report generates (folder restructure doesn't break reporting)
- [ ] **18.1.14** Create `docs/folder-structure-migration.md` (document changes for future reference)
- [ ] **18.1.15** Update `CHANGELOG.md` with folder restructure details
- [ ] **18.1.16** Update any documentation referencing specific folder names
- [ ] **18.1.17** Commit: `feat(phase18.1): align module folders with Microsoft's 18 Azure categories`

**Estimated Effort:** 1 day (4-6 hours: execute restructure, test, document, commit)

### 18.2 — Architecture

**New `-Category` Parameter:**
```powershell
Invoke-AzureTenantInventory -TenantID $tid -Category Compute,Networking
```

**Supported Categories (Microsoft's Official 18 + "All"):**

These categories **EXACTLY MATCH** Microsoft Azure Portal categorization (https://portal.azure.com/#allservices/category/All):

1. **AI + machine learning** — Azure OpenAI, AI Foundry (Hubs/Projects), ML Workspaces (compute/datastores/models/endpoints), Cognitive Services, Bot Services, Cognitive Search
2. **Analytics** — Synapse, Data Factory, Data Lake, Stream Analytics, HDInsight, Databricks, Event Hubs (analytics use)
3. **Compute** — VMs, VM Scale Sets, Azure Virtual Desktop (AVD), App Services, Functions, Container Instances, AKS, Disks, Snapshots, Galleries, Availability Sets, Dedicated Hosts
4. **Containers** — AKS, Container Instances, Container Registries, Red Hat OpenShift
5. **Databases** — SQL Databases, SQL Managed Instances, PostgreSQL, MySQL, MariaDB, Cosmos DB, Redis Cache
6. **DevOps** — App Configuration, DevTest Labs (planned future coverage)
7. **General** — Marketplace, Portal, Cloud Shell (not inventoried — informational category)
8. **Hybrid + multicloud** — Azure Arc (Machines, Kubernetes, SQL Server, Data Services, Sites), Azure Local (HCI clusters, VMs, Networks), Arc Resource Bridge
9. **Identity** — Entra ID (Users, Groups, Applications, Service Principals, Roles, Conditional Access, Devices, Domains)
10. **Integration** — Service Bus, Event Grid, Event Hubs (integration use), Logic Apps, API Management, Relay, Healthcare APIs
11. **Internet of Things** — IoT Hubs, IoT Central, Device Provisioning Services, Digital Twins, Time Series Insights
12. **Management and governance** — Management Groups, Subscriptions, Resource Groups, Policies, Blueprints, Cost Management, Advisor, Lighthouse, Automation, Backup, Site Recovery, Tags, Locks, Update Manager
13. **Migration** — Azure Migrate, Database Migration Service, Site Recovery (migration use)
14. **Monitor** — Azure Monitor, Log Analytics, Application Insights, Action Groups, Alert Rules, Data Collection Rules, Network Watcher, Diagnostic Settings, Workbooks, Grafana
15. **Networking** — Virtual Networks, Subnets, NSGs, Route Tables, Load Balancers, Application Gateways, Firewalls, VPN Gateways, ExpressRoute, Private Link/Endpoints, Bastion, NAT Gateways, Front Door, Traffic Manager, CDN, Virtual WAN
16. **Security** — Microsoft Defender for Cloud, Key Vault (Keys/Secrets/Certificates), Sentinel, DDoS Protection, Firewall, Web Application Firewall, Confidential Ledger
17. **Storage** — Storage Accounts (Blob/File/Queue/Table), Managed Disks, Data Lake Storage, NetApp Files, HPC Cache
18. **Web & Mobile** — App Services, Static Web Apps, SignalR, Notification Hubs, API Management, Communication Services, Media Services
19. **All** — Default (runs all modules)

**Multiple Categories:**
```powershell
# Comma-separated
Invoke-AzureTenantInventory -TenantID $tid -Category Compute,Networking,Storage

# Spaces in category names require quotes
Invoke-AzureTenantInventory -TenantID $tid -Category "AI + machine learning","Hybrid + multicloud"

# Array syntax
Invoke-AzureTenantInventory -TenantID $tid -Category @('Compute', 'Networking')

# Aliases supported (optional shortcuts)
Invoke-AzureTenantInventory -TenantID $tid -Category AI,Hybrid,IoT,Monitor,Management,Web
# (Aliases map: AI→"AI + machine learning", Hybrid→"Hybrid + multicloud", etc.)
```

### 18.3 — Module Metadata System

**Add Category Comment Header to ALL Modules:**
```powershell
<#
.SYNOPSIS
    Retrieves Azure Virtual Machines inventory.

.CATEGORY
    Compute

.DESCRIPTION
    Queries Azure Resource Graph for all Virtual Machines across subscriptions.
    ...
#>
```

**Module Metadata Parsing:**
```powershell
# Function to get module category
function Get-AZTIModuleCategory {
    param([string]$ModulePath)

    $content = Get-Content $ModulePath -Raw
    if ($content -match '\.CATEGORY\s+(\w+)') {
        return $matches[1]
    }
    return 'Uncategorized'
}
```

### 18.4 — Category-to-Module Mapping

**Complete Mapping (Microsoft's 18 Official Categories):**

| Category | Module Count | Modules |
|---|---|---|
| **AI + machine learning** | 15 | OpenAIServices, OpenAIDeployments, AIFoundryProjects, AIFoundryHubs, CognitiveServicesAccounts, AppliedAIServices, MachineLearningWorkspaces, MLCompute, MLDatastores, MLDatasets, MLModels, MLEndpoints, MLPipelines, BotServices, CognitiveSearchServices |
| **Analytics** | 6 | SynapseWorkspaces, DataFactories, DataFactoryPipelines, DataLakeStoreAccounts, StreamAnalyticsJobs, HDInsightClusters |
| **Compute** | 19 | VirtualMachines, VMScaleSets, AvailabilitySets, Disks, Snapshots, Images, SharedImageGalleries, GalleryImages, ProximityPlacementGroups, DiskEncryptionSets, CapacityReservationGroups, DedicatedHosts, DedicatedHostGroups, AVDHostPools, AVDApplicationGroups, AVDWorkspaces, AVDSessionHosts, AVDScalingPlans, AVDApplications |
| **Containers** | 5 | AKSClusters, AKSNodePools, ContainerInstances, ContainerRegistries, ContainerRegistryReplications |
| **Databases** | 12 | SQLServers, SQLDatabases, SQLElasticPools, PostgreSQLServers, PostgreSQLDatabases, MySQLServers, MySQLDatabases, CosmosDBAccounts, CosmosDBDatabases, CosmosDBContainers, MariaDBServers, RedisCache |
| **DevOps** | 0 | *(Planned future coverage: App Configuration, DevTest Labs, GitHub Actions runners)* |
| **General** | 0 | *(Not inventoried — informational category: Marketplace, Portal, Cloud Shell)* |
| **Hybrid + multicloud** | 18 | ArcMachines, ArcMachineExtensions, ArcKubernetesClusters, ArcSQLServers, ArcDataControllers, ArcSQLManagedInstances, ArcSites, ConnectedClusters, AzureLocalClusters, AzureLocalVirtualNetworks, AzureLocalLogicalNetworks, AzureLocalVirtualMachines, AzureLocalStoragePaths, AzureLocalUpdateSummaries, AzureLocalUpdateRuns, ArcResourceBridges, ArcSettings, EdgeDevices |
| **Identity** | 13 | EntraIDUsers, EntraIDGroups, EntraIDApplications, EntraIDServicePrincipals, EntraIDRoles, EntraIDRoleAssignments, EntraIDDirectoryRoles, EntraIDDirectoryRoleMembers, EntraIDDevices, EntraIDDomains, EntraIDSubscribedSkus, EntraIDConditionalAccessPolicies, EntraIDAuthenticationMethods |
| **Integration** | 11 | ServiceBusNamespaces, ServiceBusQueues, ServiceBusTopics, EventGridTopics, EventGridSubscriptions, EventHubNamespaces, EventHubs, LogicApps, APIManagementServices, DataFactories, NotificationHubs |
| **Internet of Things** | 4 | IoTHubs, IoTHubDeviceProvisioningServices, IoTCentralApplications, DigitalTwins |
| **Management and governance** | 14 | ManagementGroups, Subscriptions, ResourceGroups, PolicyDefinitions, PolicySetDefinitions, PolicyAssignments, PolicyComplianceStates, CustomRoles, RoleAssignments, Blueprints, TagsResources, ResourceLocks, CostManagement, LighthouseDelegations |
| **Migration** | 3 | MigrateProjects, MigrateAssessments, DatabaseMigrationServices |
| **Monitor** | 22 | LogAnalyticsWorkspaces, ApplicationInsights, ActionGroups, MetricAlertRules, ScheduledQueryRules, DataCollectionRules, DataCollectionEndpoints, SubscriptionDiagnosticSettings, ActivityLogAlerts, SmartDetectorAlertRules, AutoscaleSettings, MonitorWorkbooks, MonitorPrivateLinkScopes, LogAnalyticsSavedSearches, LogAnalyticsSolutions, LogAnalyticsLinkedServices, AppInsightsAvailabilityTests, AppInsightsWebTests, AppInsightsProactiveDetection, AppInsightsContinuousExport, AppInsightsWorkItems, MetricsIngestion |
| **Networking** | 35 | VirtualNetworks, Subnets, NetworkSecurityGroups, NSGFlowLogs, RouteTables, UDRs, LoadBalancers, ApplicationGateways, PublicIPAddresses, NetworkInterfaces, PrivateEndpoints, PrivateDNSZones, DNSZones, NetworkWatchers, VirtualNetworkPeerings, VirtualWANs, VirtualHubs, Firewalls, FirewallPolicies, AzureBastions, NATGateways, ServiceEndpointPolicies, IPGroups, WebApplicationFirewallPolicies, FrontDoors, TrafficManagers, CDNProfiles, PrivateLinkServices, VPNGateways, VPNConnections, LocalNetworkGateways, P2SVPNGateways, VirtualNetworkGateways, ExpressRouteCircuits, ExpressRouteGateways |
| **Security** | 14 | DefenderAssessments, DefenderSecureScore, DefenderAlerts, DefenderPricing, KeyVaults, KeyVaultKeys, KeyVaultSecrets, KeyVaultCertificates, SecurityContacts, AutoProvisioningSettings, SecuritySolutions, JitNetworkAccessPolicies, AdaptiveNetworkHardenings, DeviceSecurityGroups |
| **Storage** | 8 | StorageAccounts, FileShares, BlobContainers, Disks, Snapshots, NetAppAccounts, NetAppPools, NetAppVolumes |
| **Web & Mobile** | 4 | AppServicePlans, AppServices, FunctionApps, StaticWebApps |
| **All** | 160+ | *(Runs all modules across all categories)* |

**Total Modules:** ~203 (after all phases complete)

**Notes:**
- **AVD modules** moved from standalone category to **Compute** (matches Microsoft's categorization)
- **VPN modules** moved from standalone category to **Networking** (matches Microsoft's categorization)
- **Arc + Azure Local** combined into **Hybrid + multicloud** (18 modules total)
- **DevOps** and **General** categories currently empty (planned future expansion)

### 18.5 — Filtering Logic Implementation

**Module Enumeration with Category Filter:**
```powershell
function Get-AZTIModulesToRun {
    param(
        [string[]]$Categories = @('All'),
        [string]$Scope = 'ArmOnly'
    )

    # Get all module files
    $armModules = Get-ChildItem "$PSScriptRoot\Modules\ARM" -Filter "Get-AZTI*.ps1"
    $entraModules = Get-ChildItem "$PSScriptRoot\Modules\Identity" -Filter "Get-AZTI*.ps1"

    # Filter by scope
    $modules = @()
    if ($Scope -in @('All', 'ArmOnly')) {
        $modules += $armModules
    }
    if ($Scope -in @('All', 'EntraOnly')) {
        $modules += $entraModules
    }

    # Filter by category
    if ($Categories -notcontains 'All') {
        $modules = $modules | Where-Object {
            $category = Get-AZTIModuleCategory -ModulePath $_.FullName
            $category -in $Categories
        }
    }

    return $modules
}
```

**Usage in Main Function:**
```powershell
function Invoke-AzureTenantInventory {
    param(
        [string]$TenantID,
        [ValidateSet('All','ArmOnly','EntraOnly')]
        [string]$Scope = 'ArmOnly',
        [ValidateSet('All','AI + machine learning','Analytics','Compute','Containers','Databases','DevOps','General','Hybrid + multicloud','Identity','Integration','Internet of Things','Management and governance','Migration','Monitor','Networking','Security','Storage','Web & Mobile')]
        [string[]]$Category = @('All'),
        [hashtable]$CategoryAliases = @{
            'AI' = 'AI + machine learning'
            'IoT' = 'Internet of Things'
            'Monitoring' = 'Monitor'
            'Management' = 'Management and governance'
            'Web' = 'Web & Mobile'
            'Hybrid' = 'Hybrid + multicloud'
        }
    )

    # Get modules to run based on scope and category
    $modulesToRun = Get-AZTIModulesToRun -Categories $Category -Scope $Scope

    Write-Host "Running $($modulesToRun.Count) modules for categories: $($Category -join ', ')" -ForegroundColor Cyan

    # Execute modules
    foreach ($module in $modulesToRun) {
        & $module.FullName
    }
}
```

### 18.6 — Excel Generation Updates

**Dynamic Worksheet Creation:**
- Only create Excel worksheets for modules that were executed
- If `-Category Compute` specified, Excel report contains ONLY Compute-related worksheets
- Overview tab always included (shows categories selected)

**Overview Tab Updates:**
```
Categories Selected: Compute, Networking, Storage
Modules Executed: 45
Resources Collected: 1,234
```

### 18.7 — Documentation Requirements

**Create Official Category Structure Document (`docs/azure-category-structure.md`):**
- List all 18 Microsoft Azure categories with official descriptions
- Document which categories we currently cover (with module counts)
- Document which categories we don't cover yet (planned vs not planned)
- Link to Microsoft's official category page: https://portal.azure.com/#allservices/category/All

**Create Coverage Comparison Table (`docs/azure-coverage-table.md`):**
- Table: Microsoft Service | Category | Covered (Y/N) | Module Name | Planned Phase | Notes
- Map ALL Microsoft Azure services to our module coverage
- Highlight gaps (services Microsoft offers that we don't inventory)
- Track future coverage plans (which phase will add missing services)
- Example format:

| Microsoft Service | Category | Covered | Module Name | Planned | Notes |
|---|---|---|---|---|---|
| Azure Virtual Machines | Compute | ✅ Yes | Get-AZTIVirtualMachines.ps1 | Phase 0 | Fully implemented with enhanced data (Phase 17) |
| Azure Functions | Compute | ✅ Yes | Get-AZTIFunctionApps.ps1 | Phase 4 | Basic inventory |
| Azure DevTest Labs | DevOps | ❌ No | - | Future | Not planned for current phases |
| Azure Spring Apps | Compute | ❌ No | - | Future | Low priority |
| Azure Communication Services | Web & Mobile | ❌ No | - | Future | Messaging/calling services |

### 18.8 — Implementation Checklist

- [ ] **18.8.1** Add `.CATEGORY` comment header to ALL existing modules (~145 modules)
- [ ] **18.7.2** Create `docs/azure-category-structure.md` documentation
- [ ] **18.7.3** Create `docs/azure-coverage-table.md` documentation
- [ ] **18.7.4** Implement `Get-AZTIModuleCategory` function
- [ ] **18.7.5** Implement `Get-AZTIModulesToRun` function with category filtering
- [ ] **18.7.6** Add `-Category` parameter to `Invoke-AzureTenantInventory` with ValidateSet (18 categories + All)
- [ ] **18.7.7** Implement category alias support (AI→"AI + machine learning", etc.)
- [ ] **18.7.8** Update main execution loop to use `Get-AZTIModulesToRun`
- [ ] **18.7.9** Update Excel generation to create worksheets only for executed modules
- [ ] **18.7.10** Update Overview tab to show categories selected + modules executed count
- [ ] **18.7.11** Update `README.md` with category filtering examples (using Microsoft's official names)
- [ ] **18.7.12** Update comment-based help (`.PARAMETER Category`) with full category list + aliases
- [ ] **18.7.13** Create validation script to check all modules have `.CATEGORY` header
- [ ] **18.7.14** Update `CHANGELOG.md` with category filtering feature

---

## Phase 19 — Final Testing & Validation

All acceptance checks from Phase 13 + new acceptance checks for Phases 14-18.

### 19.1 — Phase 14 Acceptance Checks (Azure AI/Foundry/ML)

| # | Test | Expected Outcome |
|---|---|---|
| 1 | Run with `-Scope ArmOnly` on tenant with AI resources | Excel report includes: OpenAI Accounts, OpenAI Deployments, AI Foundry Hubs, AI Foundry Projects, Cognitive Services, Applied AI Services, ML Workspaces, ML Compute, ML Datastores, ML Datasets, ML Models, ML Endpoints, Bot Services, Cognitive Search, Search Indexes (15 new worksheets) |
| 2 | OpenAI Deployments worksheet | Lists all deployments with model name, version, scale type, capacity |
| 3 | AI Foundry Projects worksheet | Shows projects with associated Hub resource ID, storage, key vault |
| 4 | ML Datastores worksheet | Captures datastore type (Blob, File, Data Lake), target storage account |
| 5 | ML Endpoints worksheet | Shows endpoint type (Online, Batch), auth mode, deployments count, traffic allocation |
| 6 | Search Indexes worksheet | Lists indexes with document count, storage size, fields count |
| 7 | Resource provider check | Warns if `Microsoft.CognitiveServices`, `Microsoft.MachineLearningServices`, `Microsoft.BotService`, `Microsoft.Search` not registered |

### 19.2 — Phase 15 Acceptance Checks (Azure Virtual Desktop)

| # | Test | Expected Outcome |
|---|---|---|
| 8 | Run with `-Scope ArmOnly` on tenant with AVD | Excel report includes: AVD Host Pools, AVD Application Groups, AVD Workspaces, AVD Session Hosts, AVD Scaling Plans, AVD Applications (6 new worksheets) |
| 9 | AVD Host Pools worksheet | Lists host pools with type (Pooled/Personal), load balancer type, max session limit, Arc enabled indicator |
| 10 | AVD Session Hosts worksheet | Shows session hosts with status, agent version, last heartbeat, sessions count, Arc machine ID (if Arc-enabled), Azure Local cluster ID (if HCI-based) |
| 11 | AVD Scaling Plans worksheet | Captures scaling plan schedules with ALL time periods (ramp up, peak, ramp down, off-peak), capacity thresholds, load balancing algorithms |
| 12 | AVD on Azure Local detection | Session hosts deployed on Azure Local clusters show Arc machine association and cluster ID |

### 19.3 — Phase 16 Acceptance Checks (Arc Enhanced Configuration)

| # | Test | Expected Outcome |
|---|---|---|
| 13 | Run with `-Scope ArmOnly` on tenant with Arc resources | Excel report includes: Arc Sites, Arc SQL Servers, Arc Data Controllers, Arc SQL Managed Instances (4 new worksheets). Arc Machine Extensions worksheet enhanced with deep config data. |
| 14 | Arc Machine Extensions worksheet | Shows extension settings (JSON), protected settings presence indicator, auto-upgrade status, instance view status/message/time |
| 15 | Arc SQL Servers worksheet | Lists Arc-enabled SQL Server instances with host machine name, SQL version, edition, licensing type, vCores, Azure Defender status |
| 16 | Arc Data Controllers worksheet | Shows data controllers with Kubernetes cluster ID, connectivity mode (Direct/Indirect), logs/metrics upload state |
| 17 | Arc SQL Managed Instances worksheet | Lists SQL MIs on Arc with data controller ID, vCores, storage size, HA mode |

### 19.4 — Phase 17 Acceptance Checks (VM Data Enhancement)

| # | Test | Expected Outcome |
|---|---|---|
| 18 | Run with `-Scope ArmOnly` on tenant with VMs | Azure VMs worksheet includes 16 new columns: Extensions Installed, Boot Diagnostics, Avg CPU % (7d), Avg Memory % (7d), Security Baseline Compliant, Pending Critical Patches, Pending Important Patches, Last Patch Date, Backup Enabled, Last Backup, DR Enabled, Estimated Monthly Cost USD, Advisor Recommendations Count, Environment Tag, Owner Tag, Cost Center Tag |
| 19 | Run on tenant with Arc machines | Arc Machines worksheet includes 15 new columns: OS Name, OS Version, OS Edition, Arc Agent Version, Last Heartbeat, Extensions Installed, Policies Assigned, Policies Compliant, Avg CPU % (7d), Security Baseline Compliant, Pending Critical Patches, Last Patch Date, Backup Enabled, Estimated Monthly Cost USD, Environment Tag, Physical Location Tag |
| 20 | Azure Monitor Metrics integration | VMs show 7-day average CPU % and Memory % (if Azure Monitor Metrics data available) |
| 21 | Azure Backup integration | VMs with backup show "Backup Enabled = Y", Last Backup time, Recovery Vault name, Policy name |
| 22 | Site Recovery integration | VMs with DR show "DR Enabled = Y", Target Region, Replication Health |
| 23 | Azure Advisor integration | VMs show count of Advisor recommendations (Cost, Security, Reliability, Performance categories summed) |
| 24 | Cost Management integration | VMs show estimated monthly cost USD (compute + storage + network) |
| 25 | Update Manager integration | VMs show pending Critical/Important patches count and last patch date |
| 26 | Performance with large VM count | VM data collection completes in reasonable time (e.g., 500 VMs in <30 minutes with parallel processing) |
| 27 | Graceful degradation | VMs without extensions/backup/DR show blank/N/A in enhancement columns (no errors thrown) |

### 19.5 — Phase 18 Acceptance Checks (Category-Based Filtering)

| # | Test | Expected Outcome |
|---|---|---|
| 28 | Default run (no `-Category` param) | `Invoke-AzureTenantInventory -TenantID $tid` runs ALL modules (same as `-Category All`) |
| 29 | Single category (full name) | `Invoke-AzureTenantInventory -TenantID $tid -Category Compute` runs ONLY Compute modules (includes AVD). Excel report contains ONLY Compute-related worksheets (VMs, VMSSs, Disks, AVD Host Pools, etc.) — ~19 modules |
| 30 | Multiple categories | `Invoke-AzureTenantInventory -TenantID $tid -Category Compute,Networking,Storage` runs only Compute, Networking, Storage modules. Excel report contains only those worksheets. |
| 31 | Combined with scope | `Invoke-AzureTenantInventory -TenantID $tid -Scope All -Category Security,Identity` runs Defender modules + Entra ID modules ONLY. Excel report contains Security & Identity worksheets only. |
| 32 | Overview tab | Shows "Categories Selected: Compute, Networking" and "Modules Executed: 54" (19 Compute + 35 Networking) |
| 33 | Hybrid + multicloud category | `Invoke-AzureTenantInventory -TenantID $tid -Category "Hybrid + multicloud"` runs Arc + Azure Local modules (18 modules total: Arc Machines, Arc Kubernetes, Arc SQL, Arc Data, Arc Sites, Azure Local clusters/VMs/networks/storage, Arc Resource Bridge, Arc Settings, Edge Devices) |
| 34 | AI + machine learning category | `Invoke-AzureTenantInventory -TenantID $tid -Category "AI + machine learning"` runs ONLY AI/ML modules (OpenAI, AI Foundry, Cognitive Services, ML Workspaces, Bot Services, Search) — 15 modules |
| 35 | Category alias | `Invoke-AzureTenantInventory -TenantID $tid -Category AI` resolves to "AI + machine learning" and runs 15 AI modules |
| 36 | Monitor category | `Invoke-AzureTenantInventory -TenantID $tid -Category Monitor` runs ONLY monitoring modules (Log Analytics, App Insights, DCRs, Alert Rules, Action Groups, etc.) — 22 modules. (Note: NOT "Monitoring" — uses Microsoft's official "Monitor" name) |
| 37 | Internet of Things category | `Invoke-AzureTenantInventory -TenantID $tid -Category "Internet of Things"` runs IoT Hubs, Device Provisioning Services, Digital Twins — 4 modules |
| 38 | Management and governance category | `Invoke-AzureTenantInventory -TenantID $tid -Category "Management and governance"` runs Management Groups, Policies, Subscriptions, Blueprints, Lighthouse, Tags, Locks, Cost Management — 14 modules |
| 39 | Web & Mobile category | `Invoke-AzureTenantInventory -TenantID $tid -Category "Web & Mobile"` runs App Services, Function Apps, Static Web Apps — 4 modules |
| 40 | Networking includes VPN | `Invoke-AzureTenantInventory -TenantID $tid -Category Networking` runs VPN Gateways, VPN Connections, Local Network Gateways, ExpressRoute (merged into Networking — no separate VPN category) — 35 modules total |

### 19.6 — Comprehensive Integration Tests

| # | Test | Expected Outcome |
|---|---|---|
| 37 | Full tenant scan | `Invoke-AzureTenantInventory -TenantID $tid -Scope All -Category All` completes successfully. Excel report contains ~170 worksheets (all ARM + all Entra ID). JSON output contains both `arm` and `entra` sections with all 170+ resource types. |
| 38 | Empty tenant | `Invoke-AzureTenantInventory -TenantID $emptyTid` completes successfully. Excel report shows 0 resources for all worksheets. No errors thrown. |
| 39 | Large tenant (1000+ resources) | `Invoke-AzureTenantInventory -TenantID $largeTid` completes in reasonable time (<2 hours). All API throttling handled gracefully. No duplicate resources in Excel. |
| 40 | SPN auth with Entra + ARM | `Invoke-AzureTenantInventory -TenantID $tid -AppId $appId -Secret $secret -Scope All` authenticates as SPN and scans both ARM + Entra ID successfully (if SPN has permissions). |
| 41 | Resource provider warnings | `Invoke-AzureTenantInventory -TenantID $tid -CheckResourceProviders` warns for unregistered providers (`Microsoft.Security`, `Microsoft.Insights`, `Microsoft.CognitiveServices`, `Microsoft.DesktopVirtualization`, etc.). Execution continues; dependent modules skipped. |
| 42 | Multi-subscription tenant | `Invoke-AzureTenantInventory -TenantID $tid` scans ALL subscriptions in tenant (including empty subscriptions). Excel "All Subscriptions" worksheet lists all subscriptions (including ones with 0 resources). |
| 43 | Management Groups hierarchy | `Invoke-AzureTenantInventory -TenantID $tid` captures full MG hierarchy with indentation. Excel "Management Groups" worksheet shows parent-child relationships visually. |
| 44 | Policy compliance at scale | `Invoke-AzureTenantInventory -TenantID $tid` captures ~500 most recent policy compliance states (not millions). Excel "Policy Compliance States" worksheet shows resource ID, assignment, definition, state, timestamp (max 500 rows per subscription). |
| 45 | Defender assessments | `Invoke-AzureTenantInventory -TenantID $tid` captures Defender assessments, secure score, alerts, pricing. Excel "Security Overview" tab includes Defender summary, top 10 unhealthy assessments, score gauge chart, compliance bar chart. |
| 46 | Azure Update Manager overview | `Invoke-AzureTenantInventory -TenantID $tid` creates "Azure Update Manager Overview" tab listing ALL Azure VMs + ALL Arc machines with maintenance schedule assignment, patch compliance status, pending patches count. Includes summary graphs. |
| 47 | Azure Monitor coverage | `Invoke-AzureTenantInventory -TenantID $tid` creates "Azure Monitor" tab with action groups, alert rules, DCRs, workspaces, diagnostic settings coverage. Includes diagnostic coverage by resource type stacked bar chart. |
| 48 | Cost Management overview | `Invoke-AzureTenantInventory -TenantID $tid` creates "Cost Management" tab with VM reservations, reservation recommendations, Advisor cost recommendations. |

### 19.7 — Documentation & Usability Checks

| # | Test | Expected Outcome |
|---|---|---|
| 49 | `Get-Help Invoke-AzureTenantInventory -Full` | Shows complete help with: Synopsis, Description, Parameters (all params documented), Examples (10+ examples covering all features), Inputs, Outputs, Notes, Related Links |
| 50 | `README.md` accuracy | README.md Quick Start section reflects new default (`-Scope ArmOnly`). Permissions section documents ARM + Entra ID permissions. Resource Providers section lists all required providers. Examples cover category filtering, scope selection, SPN auth. |
| 51 | `CHANGELOG.md` completeness | CHANGELOG.md documents all new features from Phases 9-18 with version numbers, breaking changes, new modules, enhancements. |
| 52 | Error messages clarity | When permission denied, error message clearly states which permission is missing and remediation steps (e.g., "Graph API permission 'User.Read.All' required. Remediation: Grant admin consent for SPN or use user account with Global Reader role.") |
| 53 | Progress indicators | During execution, progress messages clearly indicate current phase, current module, resources collected count. Example: "[Phase 2/4] Processing Compute modules... [45/160 modules complete] [1,234 resources collected]" |

---

## Implementation Order Update

```
Phase 0 → Phase 1 → Phase 1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10 → Phase 11 → Phase 12 → Phase 13 → Phase 14 → Phase 15 → Phase 16 → Phase 17 → Phase 18 → Phase 19
```

**Estimated Remaining Effort (All Phases):**
- **Phase 9:** 5-7 days (17 new modules + MaintenanceConfigurations rewrite + Entra verification)
- **Phase 10:** 4-5 days (5 tab redesigns + graphs/charts + conditional formatting)
- **Phase 11:** 2-3 days (subscription/MG enumeration + Excel worksheets)
- **Phase 12:** 2-3 days (parameter default change + README updates + resource provider check)
- **Phase 13:** 2-3 days (comprehensive testing of Phases 9-12)
- **Phase 14:** 5-7 days (15 new AI/ML modules + REST API integration)
- **Phase 15:** 3-4 days (6 new AVD modules + Arc/Azure Local detection)
- **Phase 16:** 3-4 days (5 Arc enhancements + new Arc modules)
- **Phase 17:** 5-7 days (VM enhancement logic + 6 new API integrations + parallel processing)
- **Phase 18:** 3-4 days (category metadata system + filtering logic + 145 module updates)
- **Phase 19:** 3-4 days (comprehensive testing of all new features)

**Total:** ~38-50 days (7-10 weeks) for full implementation of all phases

---

**Version Control**
- Created: 2026-02-22 by Product Technology Team
- Last Edited: 2026-02-24 by Product Technology Team
- Version: 3.0.0
- Tags: powershell, azure, inventory, entra-id, azure-local, arc-gateway, vpn, policy, defender, monitor, dcr, management-groups, subscriptions, scope, permissions, resource-providers, excel-restructure, update-manager, ai-ml, azure-openai, ai-foundry, machine-learning, cognitive-services, avd, azure-virtual-desktop, arc-sql, arc-data, vm-enhancement, category-filtering, comprehensive-monitoring
- Keywords: azure-inventory, ari, resource-graph, entra, identity, hci, arc, vpn, policy, governance, security, monitoring, data-collection-rules, lighthouse, comprehensive-logging, authentication, documentation, openai, foundry, ml-workspaces, bot-services, cognitive-search, avd-session-hosts, arc-enabled-sql, vm-metrics, backup-status, disaster-recovery, cost-management, advisor, update-compliance, category-filtering
- Author: Product Technology Team
