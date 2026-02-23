# Azure Inventory Tool — Implementation Plan

## Overview

Transform [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11 into **AzureInventory** — a generic, single-tenant Azure + Entra ID inventory tool. Publishes as a PowerShell module to PSGallery and as a standalone GitHub repo (`thisismydemo/azure-inventory`).

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
| **Module prefix** | `AZI` (AzureInventory) | Distinct from ARI to avoid confusion. |
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
| `AzureResourceInventory.psd1` | `AzureInventory.psd1` |
| `AzureResourceInventory.psm1` | `AzureInventory.psm1` |

### 0.2 — Update Module Manifest (`AzureInventory.psd1`)

- New `ModuleVersion` = `1.0.0`
- New `GUID` (generate fresh)
- `RootModule` = `AzureInventory.psm1`
- `Author` / `CompanyName` = `thisismydemo`
- `Description` = updated
- `RequiredModules` = `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`, `Az.Compute`
- Remove `Microsoft.Graph.*` from any dependency lists
- Rename all exported function names: `*-ARI*` → `*-AZI*`
- Add new exports: `Invoke-AzureInventory`, `Test-AZIPermissions`

### 0.3 — Update PSM1 Loader (`AzureInventory.psm1`)

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

## Phase 1 — Global Rename (ARI → AZI)

### 1.1 — Function Name Renames

Every function with `ARI` in the name gets renamed to `AZI`. Key renames:

| Original | New |
|---|---|
| `Invoke-ARI` | `Invoke-AzureInventory` |
| `Connect-ARILoginSession` | `Connect-AZILoginSession` |
| `Start-ARIExtractionOrchestration` | `Start-AZIExtractionOrchestration` |
| `Start-ARIGraphExtraction` | `Start-AZIGraphExtraction` |
| `Invoke-ARIInventoryLoop` | `Invoke-AZIInventoryLoop` |
| `Get-ARIAPIResources` | `Get-AZIAPIResources` |
| `Get-ARICostInventory` | `Get-AZICostInventory` |
| `Get-ARIManagementGroups` | `Get-AZIManagementGroups` |
| `Get-ARISubscriptions` | `Get-AZISubscriptions` |
| `Start-ARIProcessOrchestration` | `Start-AZIProcessOrchestration` |
| `Start-ARIProcessJob` | `Start-AZIProcessJob` |
| `Start-ARIAutProcessJob` | `Start-AZIAutProcessJob` |
| `Build-ARICacheFiles` | `Build-AZICacheFiles` |
| `Start-ARIExtraJobs` | `Start-AZIExtraJobs` |
| `Invoke-ARISubJob` | `Invoke-AZISubJob` |
| `Start-ARIReporOrchestration` | `Start-AZIReportOrchestration` |
| `Start-ARIExcelJob` | `Start-AZIExcelJob` |
| `Start-ARIExcelExtraData` | `Start-AZIExcelExtraData` |
| `Start-ARIExtraReports` | `Start-AZIExtraReports` |
| `Start-ARIExcelCustomization` | `Start-AZIExcelCustomization` |
| `Build-ARIAdvisoryReport` | `Build-AZIAdvisoryReport` |
| `Build-ARIPolicyReport` | `Build-AZIPolicyReport` |
| `Build-ARIQuotaReport` | `Build-AZIQuotaReport` |
| `Build-ARISecCenterReport` | `Build-AZISecCenterReport` |
| `Build-ARISubsReport` | `Build-AZISubsReport` |
| `Set-ARIFolder` | `Set-AZIFolder` |
| `Set-ARIReportPath` | `Set-AZIReportPath` |
| `Test-ARIPS` | `Test-AZIPS` |
| `Clear-ARIMemory` | `Clear-AZIMemory` |
| `Clear-ARICacheFolder` | `Clear-AZICacheFolder` |
| `Get-ARIUnsupportedData` | `Get-AZIUnsupportedData` |
| `Out-ARIReportResults` | `Out-AZIReportResults` |
| `Wait-ARIJob` | `Wait-AZIJob` |
| All diagram functions | `*-ARI*` → `*-AZI*` |
| All advisory/policy/security job functions | `*-ARI*` → `*-AZI*` |

### 1.2 — String/Variable/Path Renames

| Pattern | Replacement |
|---|---|
| `AzureResourceInventory` (in strings, paths, logs) | `AzureInventory` |
| `C:\AzureResourceInventory` (default path) | `C:\AzureInventory` |
| `$HOME/AzureResourceInventory` | `$HOME/AzureInventory` |
| `ARI` in log/Write-Host messages | `AZI` or `AzureInventory` |
| Job names like `'ResourceJob_'` | Keep as-is (internal, not user-facing) |

### 1.3 — File Renames

| Original | New |
|---|---|
| `Modules/Public/PublicFunctions/Invoke-ARI.ps1` | `Modules/Public/PublicFunctions/Invoke-AzureInventory.ps1` |

All other `.ps1` filenames stay as-is (they don't include `ARI` in the filename, only in the function name inside).

---

## Phase 2 — Auth Refactor

### 2.1 — Rewrite `Connect-AZILoginSession`

**File:** `Modules/Private/0.MainFunctions/Connect-ARILoginSession.ps1` (rename to keep filename or rename)

**New auth priority (5 methods):**

```
Priority 1: Managed Identity (-Automation flag, handled in Invoke-AzureInventory)
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

### 2.2 — New: `Get-AZIGraphToken`

**File:** `Modules/Private/0.MainFunctions/Get-AZIGraphToken.ps1` (NEW)

```powershell
function Get-AZIGraphToken {
    # Uses Get-AzAccessToken -ResourceTypeName MSGraph -AsSecureString
    # Returns @{ 'Authorization' = "Bearer $plainToken"; 'Content-Type' = 'application/json' }
    # Caches in script-scope variable, refreshes when within 5 min of expiry
    # Throws if token acquisition fails (no Graph access)
}
```

### 2.3 — New: `Invoke-AZIGraphRequest`

**File:** `Modules/Private/0.MainFunctions/Invoke-AZIGraphRequest.ps1` (NEW)

```powershell
function Invoke-AZIGraphRequest {
    param(
        [string]$Uri,              # Relative path: /v1.0/users
        [string]$Method = 'GET',
        [object]$Body,
        [switch]$SinglePage        # Don't follow @odata.nextLink
    )
    # 1. Get token via Get-AZIGraphToken
    # 2. Build full URL: https://graph.microsoft.com{$Uri}
    # 3. Invoke-RestMethod with token header
    # 4. Follow @odata.nextLink for pagination (unless -SinglePage)
    # 5. Handle 429 throttling with Retry-After header
    # 6. Return aggregated .value array
}
```

---

## Phase 3 — Pre-Flight Permission Checker

### 3.1 — New: `Test-AZIPermissions`

**File:** `Modules/Public/PublicFunctions/Test-AZIPermissions.ps1` (NEW)

```powershell
function Test-AZIPermissions {
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

### 3.2 — Integration with `Invoke-AzureInventory`

- Add `-SkipPermissionCheck` switch parameter
- Call `Test-AZIPermissions` after auth, before extraction
- Display results as warnings, never block execution

---

## Phase 4 — Entra ID Extraction Layer

### 4.1 — New: `Start-AZIEntraExtraction`

**File:** `Modules/Private/1.ExtractionFunctions/Start-AZIEntraExtraction.ps1` (NEW)

```powershell
function Start-AZIEntraExtraction {
    param($TenantID, $Scope)
    # 1. Call Invoke-AZIGraphRequest for each Entra resource type
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

**File:** `Modules/Private/0.MainFunctions/Start-AZIExtractionOrchestration.ps1`

Add:
- `$Scope` parameter
- Conditional call to `Start-AZIEntraExtraction` when `$Scope -in ('All','EntraOnly')`
- Merge Entra resources into `$Resources` array (appended with synthetic types)
- Add `EntraResources` to return object

### 4.3 — New Parameter on `Invoke-AzureInventory`

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

### 6.1 — New: `Export-AZIJsonReport`

**File:** `Modules/Private/3.ReportingFunctions/Export-AZIJsonReport.ps1` (NEW)

```powershell
function Export-AZIJsonReport {
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

### 6.2 — New Parameter on `Invoke-AzureInventory`

```powershell
[ValidateSet('All', 'Excel', 'Json')]
[string]$OutputFormat = 'All'
```

- `All` (default): Generate both `.xlsx` and `.json`
- `Excel`: Skip JSON export
- `Json`: Skip Excel generation (`Start-AZIExcelJob` etc.)

### 6.3 — Integration in Report Orchestration

Update `Start-AZIReportOrchestration` to:
- Call Excel pipeline only when `$OutputFormat -in ('All','Excel')`
- Call `Export-AZIJsonReport` only when `$OutputFormat -in ('All','Json')`

---

## Phase 7 — Cleanup & Polish

### 7.1 — Update Default Paths

**File:** `Set-AZIReportPath.ps1`

| OS | Old Default | New Default |
|---|---|---|
| Windows | `C:\AzureResourceInventory` | `C:\AzureInventory` |
| Linux/Mac | `$HOME/AzureResourceInventory` | `$HOME/AzureInventory` |

Report cache: `{DefaultPath}/ReportCache/`
Diagram cache: `{DefaultPath}/DiagramCache/`

### 7.2 — README.md

Full rewrite with:
- Project description and attribution to microsoft/ARI
- Installation (PSGallery + git clone)
- Quick start examples for all 5 auth modes
- `-Scope` usage (`All`, `ArmOnly`, `EntraOnly`)
- `-OutputFormat` usage (`All`, `Excel`, `Json`)
- `Test-AZIPermissions` usage
- Required permissions table
- Module catalog (ARM + Entra)
- Contributing / module authoring guide

### 7.3 — Pester Tests

Create in `tests/`:
- `Test-AZIPermissions.Tests.ps1` — mock Graph/ARM calls, verify detection logic
- `Invoke-AzureInventory.Tests.ps1` — parameter validation, scope routing
- `Connect-AZILoginSession.Tests.ps1` — auth method selection
- `Invoke-AZIGraphRequest.Tests.ps1` — pagination, throttling, error handling
- `Start-AZIEntraExtraction.Tests.ps1` — synthetic type normalization

---

## Implementation Order

```
Phase 0  →  Phase 1  →  Phase 2  →  Phase 3  →  Phase 4  →  Phase 5  →  Phase 6  →  Phase 7
Scaffold    Rename      Auth        Perms       Entra        Identity     JSON        Polish
                                                Extract      Modules      Output
```

Each phase is independently committable and testable. The tool remains functional after each phase:
- After Phase 1: AZI-renamed ARI (same functionality, new names)
- After Phase 2: New auth with current-user default
- After Phase 3: Permission checking works
- After Phase 4: Entra data extraction works
- After Phase 5: Entra data appears in Excel
- After Phase 6: JSON output alongside Excel
- After Phase 7: Production-ready for PSGallery publish

---

## Verification Criteria

These 6 end-to-end scenarios must pass before the tool is considered production-ready:

| # | Scenario | Command | Expected Outcome |
|---|---|---|---|
| 1 | **Current user, no flags** | `Invoke-AzureInventory -TenantID <id>` | Uses existing `Get-AzContext`, produces Excel + JSON with ARM and Entra data. No login prompt if already authenticated. |
| 2 | **SPN + Secret** | `Invoke-AzureInventory -TenantID <id> -AppId <id> -Secret <secret>` | Authenticates as service principal, full inventory, no interactive prompts. |
| 3 | **SPN + Certificate** | `Invoke-AzureInventory -TenantID <id> -AppId <id> -CertificatePath <path> -Secret <certpass>` | Authenticates with certificate, full inventory. |
| 4 | **Entra-only scope** | `Invoke-AzureInventory -TenantID <id> -Scope EntraOnly` | Skips all ARM/Resource Graph extraction. Excel contains only Identity worksheets (15 Entra tabs). JSON contains only `entra` section. Completes significantly faster than full run. |
| 5 | **ARM-only scope** | `Invoke-AzureInventory -TenantID <id> -Scope ArmOnly` | Skips all Graph/Entra extraction. No Identity worksheets in Excel. No `entra` section in JSON. Behaves like original ARI. |
| 6 | **Permission check with partial access** | `Test-AZIPermissions -TenantID <id> -Scope All` | Returns structured object with `ArmAccess = $true/$false`, `GraphAccess = $true/$false`, and `Details` array. Warns on missing permissions but does not throw. When run via `Invoke-AzureInventory` (without `-SkipPermissionCheck`), warnings display but execution continues with available data. |

### Additional Acceptance Checks

- **JSON output structure**: `_metadata` block contains `tool`, `version`, `tenantId`, `subscriptions[]`, `generatedAt`, `scope`. ARM data nested under `arm/{category}`. Entra data nested under `entra/{type}`.
- **Excel output**: All 15 Entra worksheets present when `-Scope All` or `-Scope EntraOnly`. Sheet names match specification (e.g., `Entra Users`, `Conditional Access`).
- **Pagination**: Entra modules with >999 objects follow `@odata.nextLink` and return complete data sets.
- **Throttling**: `Invoke-AZIGraphRequest` respects `Retry-After` header on HTTP 429 and retries automatically.
- **No MgGraph dependency**: `Get-Module Microsoft.Graph* -ListAvailable` is NOT required. Tool functions with only `Az.Accounts`, `Az.ResourceGraph`, `Az.Compute`, `Az.Storage`, and `ImportExcel`.

---

**Version Control**
- Created: 2026-02-22 by Product Technology Team
- Last Edited: 2026-02-22 by Product Technology Team
- Version: 1.0.0
- Tags: powershell, azure, inventory, entra-id
- Keywords: azure-inventory, ari, resource-graph, entra, identity
- Author: Product Technology Team
