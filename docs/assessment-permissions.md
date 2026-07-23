---
description: The minimum RBAC and Microsoft Graph permissions each AzureScout assessment needs, and how to pre-flight them with -PermissionAudit.
---

# Assessment Auth & Permissions

This page is specific to the CAF/WAF assessment platform
(`Invoke-ScoutAssessment`). It is a **different, narrower permission model**
than the v1 inventory cmdlet's — see [Permissions](permissions.md) for the
`Invoke-AzureScout` / `Test-AZSCPermissions` model, which is not the same
function and is not what this page describes.

Source of truth: `src/assess/Test-ScoutPermission.ps1`,
`src/ingest/Import-Governance.ps1` (the default governance collector), and
`src/ingest/Import-AzGovViz.ps1` (the opt-in third-party collector).

::: info Governance data is native by default — no Graph permission required for it
As of the native governance collector (AB#5041), the five assessments whose
`Ingest` used to be `AzGovViz` (`LandingZone`, `Management`, `Identity`,
`Governance`, `Policy`) now use `Ingest = Governance` by default —
`Import-Governance` populates `collect.json`'s `governance` object from
Azure Resource Graph and ambient-token ARM REST calls, needing **only ARM
Reader at the management-group root**, the same requirement every other
assessment already has. The Microsoft Graph application permissions below
are needed **only if you explicitly opt an assessment into the legacy
`AzGovViz` ingestor value** instead of the native default — they are no
longer a default requirement for any assessment.
:::

## The short version

| Requirement | Who needs it |
|---|---|
| **ARM `Reader` at the tenant-root management group** | **Every assessment, with no exception** — including the 5 governance-data assessments, now served by the native `Import-Governance` collector. |
| **Microsoft Graph app permissions** (`User.Read.All`, `Group.Read.All`, `Application.Read.All`, `PrivilegedAccess.Read.AzureResources`) | **Only** if you opt an assessment into the legacy `AzGovViz` ingestor instead of the native `Governance` default. Not required by any assessment out of the box. |

All 22 assessments in [the registry](design/assessment-registry.md) need
**ARM Reader only** by default. No Graph permission, delegated or
application, is required unless you deliberately switch an assessment's
`Ingest` back to `AzGovViz`.

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

"Governance data" marks the 5 assessments that collect governance data —
**by default** via the native `Import-Governance` collector (ARM Reader
only, same as every other row). "Graph (opt-in `AzGovViz`)" is only **Yes**
if you've explicitly switched that assessment's `Ingest` back to the legacy
`AzGovViz` value — none of them require Graph out of the box.

| Assessment | ARM Reader @ MG root | Governance data | Graph (opt-in `AzGovViz`) |
|---|---|---|---|
| `LandingZone` | Required | **Yes** (native) | Only if opted in |
| `Estate` | Required | No | No |
| `Management` | Required | **Yes** (native) | Only if opted in |
| `Monitor` | Required | No | No |
| `Networking` | Required | No | No |
| `Identity` | Required | **Yes** (native) | Only if opted in |
| `Security` | Required | No | No |
| `Compute` | Required | No | No |
| `Storage` | Required | No | No |
| `Databases` | Required | No | No |
| `Containers` | Required | No | No |
| `Web` | Required | No | No |
| `Analytics` | Required | No | No |
| `AI` | Required | No | No |
| `Integration` | Required | No | No |
| `Hybrid` | Required | No | No |
| `IoT` | Required | No | No |
| `Governance` | Required | **Yes** (native) | Only if opted in |
| `Policy` | Required | **Yes** (native) | Only if opted in |
| `UpdateManager` | Required | No | No |
| `Monitoring` | Required | No | No |
| `Cost` | Required | No | No |

## The Graph permissions (only if you opt into the legacy `AzGovViz` ingestor)

These four application permissions are **not needed by default for any
assessment** — the native `Import-Governance` collector needs only ARM
Reader. They only apply if you explicitly set an assessment's `Ingest` back
to `AzGovViz`. When `Test-ScoutPermission` sees an `AzGovViz`-ingesting
assessment in the requested set, it lists these four application
permissions:

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
| `Graph: <permission>` (×4, only when an assessment is explicitly opted into the legacy `AzGovViz` ingestor) | **Not validated** — always emitted with `Ok = $null` as an informational checklist entry | `$null` (always) |

In other words: `-PermissionAudit` will tell you definitively whether your
ARM Reader assignment is correct, but it does **not** call Microsoft Graph to
confirm the four app permissions are actually granted — it only reminds you
they're needed and what to do about it (`Fix` column). Verify Graph
application permissions independently (Entra admin center → App
registrations → API permissions, or `Get-MgServicePrincipalAppRoleAssignment`)
before relying on a clean `-PermissionAudit` run as proof they're in place.

## `-ManagementGroupId` and governance data collection

By default, the 5 governance-data assessments (`LandingZone`, `Management`,
`Identity`, `Governance`, `Policy`) use the native `Import-Governance`
collector, which does **not** need an explicit `-ManagementGroupId` to run —
it collects via Azure Resource Graph and ambient-token ARM REST calls
regardless. What actually depends on management-group visibility is the
**ALZ benchmark diff**: if the identity running the scan doesn't have Reader
at the management-group root, the benchmark degrades to an explicit
`Unknown` (with remediation guidance pointing at "grant Reader at MG root")
rather than a false 0%. This is not a permission failure and will not show
up in `-PermissionAudit`.

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -ManagementGroupId 'contoso-root-mg' -OutputFormat Html
```

`-ManagementGroupId` scopes the Resource Graph `Collect` layer —
`Invoke-Collect` and `Invoke-ArgQueryPack` pass it through to every
`Search-AzGraph` call as `-ManagementGroup`. Omitting it leaves ARG queries
running tenant-wide against whatever your authenticated context can see (no
`-ManagementGroup`/`-Subscription` filter is sent at all). The ARM `Reader`
requirement in [The short version](#the-short-version) still applies
regardless of whether you pass `-ManagementGroupId` — it only narrows
*which* subscriptions under your Reader scope get queried, it does not
substitute for the role assignment.

If you've opted an assessment into the legacy `AzGovViz` ingestor instead of
the native default, `Import-AzGovViz.ps1` still needs an explicit
`-ManagementGroupId` to know where to scope the Azure Governance Visualizer
run — omitting it there logs `Import-AzGovViz: no -ManagementGroupId
supplied; skipping AzGovViz ingest` and that ingestor's data is skipped, same
behavior as before this default changed.

## Next steps

- [Assessment guide — run modes and examples](assessment.md)
- [Assessment Registry — all 22 assessments](design/assessment-registry.md)
- [Assessment prerequisites](assessment-prerequisites.md)
- v1 inventory's separate model: [Permissions](permissions.md), [Authentication](authentication.md)
