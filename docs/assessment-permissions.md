---
description: The minimum RBAC and Microsoft Graph permissions each AzureScout assessment needs, and how to pre-flight them with -PermissionAudit.
---

# Assessment Auth & Permissions

This page is specific to the CAF/WAF assessment platform
(`Invoke-ScoutAssessment`). It is a **different, narrower permission model**
than the v1 inventory cmdlet's — see [Permissions](permissions.md) for the
`Invoke-AzureScout` / `Test-AZSCPermissions` model, which is not the same
function and is not what this page describes.

Source of truth: `src/assess/Test-ScoutPermission.ps1` and
`src/ingest/Import-AzGovViz.ps1`.

## The short version

| Requirement | Who needs it |
|---|---|
| **ARM `Reader` at the tenant-root management group** | **Every assessment, with no exception.** |
| **Microsoft Graph app permissions** (`User.Read.All`, `Group.Read.All`, `Application.Read.All`, `PrivilegedAccess.Read.AzureResources`) | **Only** the 5 assessments whose `Ingest` includes `AzGovViz`: `LandingZone`, `Management`, `Identity`, `Governance`, `Policy` |

All other assessments — the 17 remaining entries in
[the registry](design/assessment-registry.md) — need **ARM Reader only**.
No Graph permission, delegated or application, is required for them.

::: tip Check before you scan
```powershell
Invoke-ScoutAssessment -Assessment LandingZone,Identity -PermissionAudit
```
Runs `Test-ScoutPermission` for the given assessment(s) and returns/prints a
table before any collection happens. See [what it actually checks](#what-permissionaudit-actually-verifies)
below — it is not a full live Graph check.
:::

## Why ARM Reader must be at the management-group root, not the subscription

`Test-ScoutPermission` checks the role assignment at
`/providers/Microsoft.Management/managementGroups/<tenantId>` — i.e. the
**tenant root management group**, not any individual subscription:

```powershell
Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$($ctx.Tenant.Id)" `
    -SignInName $ctx.Account.Id | Where-Object RoleDefinitionName -eq 'Reader'
```

A `Reader` assignment scoped only to individual subscriptions will **fail**
this specific check (`Test-ScoutPermission` does not walk down to
subscription-level assignments as a fallback). Assign `Reader` at the root
management group so every subscription under it inherits read access.

## Per-assessment matrix

"Graph (AzGovViz)" = **Yes** means the assessment's `Ingest` list includes
`AzGovViz`, so the four Graph app permissions below are also needed.

| Assessment | ARM Reader @ MG root | Graph (AzGovViz) |
|---|---|---|
| `LandingZone` | Required | **Yes** |
| `Estate` | Required | No |
| `Management` | Required | **Yes** |
| `Monitor` | Required | No |
| `Networking` | Required | No |
| `Identity` | Required | **Yes** |
| `Security` | Required | No |
| `Compute` | Required | No |
| `Storage` | Required | No |
| `Databases` | Required | No |
| `Containers` | Required | No |
| `Web` | Required | No |
| `Analytics` | Required | No |
| `AI` | Required | No |
| `Integration` | Required | No |
| `Hybrid` | Required | No |
| `IoT` | Required | No |
| `Governance` | Required | **Yes** |
| `Policy` | Required | **Yes** |
| `UpdateManager` | Required | No |
| `Monitoring` | Required | No |
| `Cost` | Required | No |

## The Graph permissions (only for the 5 AzGovViz assessments)

When `Test-ScoutPermission` sees an `AzGovViz`-ingesting assessment in the
requested set, it lists these four application permissions:

| Permission | Purpose |
|---|---|
| `User.Read.All` | AzGovViz's identity export |
| `Group.Read.All` | AzGovViz's identity export |
| `Application.Read.All` | AzGovViz's identity export |
| `PrivilegedAccess.Read.AzureResources` | PIM-eligible role assignments — **requires an Entra ID P2 license** |

Grant these as **application permissions with admin consent** on the service
principal / app registration AzureScout authenticates as (or a user account
in **Directory Readers**, per `Test-ScoutPermission`'s remediation text).

::: warning `PrivilegedAccess.Read.AzureResources` is currently never exercised
`Import-AzGovViz.ps1` **always** passes `-NoPIMEligibility` to the Azure
Governance Visualizer — unconditionally, not only when the permission/license
is missing:

```powershell
& "$govPath/repo/pwsh/AzGovVizParallel.ps1" `
    -ManagementGroupId $ManagementGroupId `
    -OutputPath        $govPath `
    -DoPSRule `
    -NoScopeInsights `
    -NoPIMEligibility `
    -ALZPolicyAssignmentsChecker
```

In the current implementation, PIM-eligibility data is **never** collected
through this ingest path, regardless of whether you grant
`PrivilegedAccess.Read.AzureResources` or hold an Entra ID P2 license. The
permission is still listed by `Test-ScoutPermission` (it's part of AzGovViz's
own general permission set) — grant it if you want to future-proof for when
`-NoPIMEligibility` is lifted, but do not expect PIM data in `findings.json`
today. This is a real gap between the permission checklist and what the code
does; flagged here rather than silently documented as "working."
:::

## What `-PermissionAudit` actually verifies

`Test-ScoutPermission` performs **one live check and one static checklist** —
they are not the same kind of validation:

| Check | How it's validated | `Ok` value |
|---|---|---|
| `ARM Reader @ MG root` | **Live** — actually calls `Get-AzRoleAssignment` against the current context | `$true` / `$false` |
| `Graph: <permission>` (×4, only when an AzGovViz assessment is selected) | **Not validated** — always emitted with `Ok = $null` as an informational checklist entry | `$null` (always) |

In other words: `-PermissionAudit` will tell you definitively whether your
ARM Reader assignment is correct, but it does **not** call Microsoft Graph to
confirm the four app permissions are actually granted — it only reminds you
they're needed and what to do about it (`Fix` column). Verify Graph
application permissions independently (Entra admin center → App
registrations → API permissions, or `Get-MgServicePrincipalAppRoleAssignment`)
before relying on a clean `-PermissionAudit` run as proof they're in place.

## `-ManagementGroupId` and the AzGovViz-only assessments

`Import-AzGovViz.ps1` needs an explicit `-ManagementGroupId` to know where to
scope the Azure Governance Visualizer run. If you omit it on a `LandingZone`,
`Management`, `Identity`, `Governance`, or `Policy` run:

```
Import-AzGovViz: no -ManagementGroupId supplied; skipping AzGovViz ingest (governance rules will report Unknown).
```

The run **does not fail or prompt** — it silently skips the AzGovViz ingest,
and every rule that depends on `collect.governance.*` data scores `Unknown`
instead of `Pass`/`Fail`. This is not a permission failure; it will not show
up in `-PermissionAudit`. Always pass `-ManagementGroupId` for these five
assessments if you want governance rules actually scored:

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -ManagementGroupId 'contoso-root-mg' -OutputFormat Html
```

## Next steps

- [Assessment guide — run modes and examples](assessment.md)
- [Assessment Registry — all 22 assessments](design/assessment-registry.md)
- [Assessment prerequisites](assessment-prerequisites.md)
- v1 inventory's separate model: [Permissions](permissions.md), [Authentication](authentication.md)
