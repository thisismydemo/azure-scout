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

### 1B.2 — Decisions to Make

Evaluate each area and decide **keep as-is** or **reorganize**:

| Area | Question | Options |
|---|---|---|
| **Numbered Private folders** | Are `0.MainFunctions/`, `1.ExtractionFunctions/`, etc. clear enough? | (A) Keep numbered — explicit load order. (B) Drop numbers — `Main/`, `Extraction/`, `Processing/`, `Reporting/`. |
| **Network_1 / Network_2 split** | Why two network folders? Is there logic to the split? | (A) Keep split. (B) Merge into single `Network/`. (C) Rename to meaningful names (e.g., `NetworkConnectivity/`, `NetworkSecurity/`). |
| **Hybrid → ArcServices consolidation** | `Hybrid/ARCServers.ps1` is alone; Phase 8 adds `ArcServices/`. | (A) Keep both separate. (B) Move ARCServers.ps1 into `ArcServices/` and delete `Hybrid/`. |
| **Module manifest location** | `.psd1`/`.psm1` in repo root is PSGallery standard. | (A) Keep in root (standard). (B) Move into `src/` subfolder (requires `RootModule` path update). |
| **`azure-pipelines/`** | Inherited Microsoft CI/CD — not relevant to us. | (A) Delete. (B) Archive to `archive/`. (C) Replace with our own CI/CD. |
| **`docs/` content** | Inherited ARI MkDocs content with ARI branding. | (A) Rewrite in Phase 7. (B) Gut now, rewrite later. (C) Delete inherited content, start fresh. |
| **`images/`** | Screenshots and diagrams — still relevant? | (A) Keep. (B) Move under `docs/images/`. (C) Audit and remove ARI-specific images. |
| **`migration-temp/`** | This implementation plan directory. | (A) Keep during development, delete before v1.0.0 release. (B) Move content into `docs/`. |
| **`LegacyFunctions/`** | Deprecated ARI functions carried forward. | (A) Keep for reference. (B) Delete now. (C) Archive to `archive/`. |
| **Test organization** | `tests/` is flat. Multiple Pester test files planned. | (A) Keep flat. (B) Mirror `Modules/` structure (e.g., `tests/Private/`, `tests/Public/`). |

### 1B.3 — Implement Reorganization

Once decisions are made:

1. Execute `git mv` for any folder/file relocations
2. Update `AzureTenantInventory.psm1` dot-source paths if Private folders change
3. Update `.gitignore` for any new/moved paths
4. Update any internal path references across scripts
5. Validate module still loads: `Import-Module ./AzureTenantInventory.psd1 -Force`
6. Run existing Pester tests (if any)

### 1B.4 — Document Decisions

Record the decisions and rationale in a `docs/architecture/folder-structure.md` so future contributors understand the layout. Include:
- Folder purpose descriptions
- Why numbered vs. named (if kept)
- Module authoring guide (where to put new inventory modules)
- What belongs in Private vs. Public

### 1B.5 — Commit Phase 1B

Commit the reorganization (if any changes made) or the decision documentation (if keeping current structure).

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

### 7.4 — GitHub Pages Documentation Site

Replace the existing `gh-pages` branch (inherited from microsoft/ARI, pointing at `microsoft.github.io/ARI/`) with a new documentation site for AzureTenantInventory:

- Delete old `gh-pages` branch: `git push origin --delete gh-pages`
- Set up MkDocs Material (or similar) with `docs/` source in `main`
- Site content:
  - Getting started / installation
  - Authentication guide (all 5 methods)
  - Scope & output format usage
  - Permission requirements
  - ARM module catalog (16 categories)
  - Entra module catalog (15 Identity modules)
  - Module authoring / contributing guide
  - Credits & attribution to microsoft/ARI
  - Changelog
- GitHub Actions workflow to auto-deploy `gh-pages` on push to `main`
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

The only existing Arc module is `Hybrid/ARCServers.ps1` (Arc-enabled servers, `microsoft.hybridcompute/machines`). No coverage for Arc Gateways, Arc-enabled Kubernetes, Arc resource bridge, or Arc extensions.

**New directory:** `Modules/Public/InventoryModules/ArcServices/`

| # | File | Resource Type | Excel Worksheet | Key Processing Fields |
|---|---|---|---|---|
| 1 | `ArcGateways.ps1` | `microsoft.hybridcompute/gateways` | `Arc Gateways` | Name, Location, Gateway Type, Gateway Endpoint, Provisioning State, Allowed Features |
| 2 | `ArcKubernetes.ps1` | `microsoft.kubernetes/connectedclusters` | `Arc Kubernetes` | Name, Distribution, K8s Version, Node Count, Agent Version, Connectivity Status, Identity, Provisioning State |
| 3 | `ArcResourceBridge.ps1` | `microsoft.resourceconnector/appliances` | `Arc Resource Bridge` | Name, Distro, Version, Status, Infrastructure Type, Provisioning State |
| 4 | `ArcExtensions.ps1` | `microsoft.hybridcompute/machines/extensions` | `Arc Extensions` | Machine Name, Extension Name, Publisher, Type, Version, Provisioning State, Status |

> **Note:** The existing `Hybrid/ARCServers.ps1` remains in place. Consider future consolidation of all Arc modules under `ArcServices/` for organizational consistency.

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

**Version Control**
- Created: 2026-02-22 by Product Technology Team
- Last Edited: 2026-02-22 by Product Technology Team
- Version: 1.2.0
- Tags: powershell, azure, inventory, entra-id, azure-local, arc-gateway, vpn, folder-structure
- Keywords: azure-inventory, ari, resource-graph, entra, identity, hci, arc, vpn, reorganization
- Author: Product Technology Team
