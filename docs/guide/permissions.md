---
description: ARM RBAC and Microsoft Graph permissions required by AzureScout.
---

# Required Permissions

::: tip This page covers inventory mode
This page describes the permission model for **inventory mode**
(`Invoke-AzureScout` / `Test-AZSCPermissions`). **Assessment mode**
(`-Assessment` / `Test-ScoutPermission`) uses a different, narrower model
— see the note at the bottom of this page, or go straight to
[Assessment Permissions](../assessment/assessment-permissions.md). New here?
See the [Overview](./overview.md).
:::

## Overview

AzureScout requires two categories of permissions:

1. **ARM (Azure Resource Manager)** — RBAC role assignments on subscriptions
2. **Microsoft Graph API** — Application or delegated permissions for Entra ID data

## ARM Permissions

| Permission | Scope | Purpose |
|------------|-------|---------|
| `Reader` | Subscription(s), or the tenant-root management group | Enumerate resources, read properties — covers every ARM collector Scout has |

**One role is the whole ARM ask.** Azure's `Reader` role is `Actions: */read` with an empty
`NotActions` — a single wildcard over every control-plane read. There is no ARM collector in
Scout that needs more than this, including roughly 130 of them that reach Azure through Azure
Resource Graph (`Microsoft.ResourceGraph/resources/read` — also inside `Reader`'s `*/read`, so
the conclusion doesn't change, but a role list that names only the per-service actions is
understating the ask by that one action).

::: warning Assign Reader at management-group scope for the management-group and cross-subscription data
Subscription-scoped `Reader` silently returns an empty or flattened management-group hierarchy —
no error, no warning. Assign it at the tenant-root management group if you want that data, or
if you're running any assessment (assessment mode requires MG-root scope unconditionally — see
[Assessment Permissions](../assessment/assessment-permissions.md)).

Whether Reader at root MG alone is sufficient for the `ManagementGroups` and
`CustomRoleDefinitions` worksheets, or whether `Management Group Reader` is genuinely additional,
is **unresolved** — do not grant `Management Group Reader` on the strength of this page alone.
See [Troubleshooting](./troubleshooting.md) if those worksheets come back empty.
:::

::: danger Do not grant these three roles — they were removed from the ask
`Security Reader`, `Monitoring Reader`, and `Cost Management Reader` (all **Azure RBAC** roles,
not the Entra roles of the same name) used to be listed here as optional extras. They are not
strict subsets of `Reader` — the precise statement is narrower: **none of them grants anything
Scout calls that `Reader` does not already grant.**

- **`Monitoring Reader`** additionally grants `Microsoft.Support/*`, which includes
  support-ticket **creation** — a write, in a tool sold as read-only.
- **`Cost Management Reader`** carries the identical `Microsoft.Support/*`.
- **Azure RBAC `Security Reader`** additionally grants five IoT Defender `/action` permissions,
  one of which downloads a password-reset file. Scout calls none of them. (The **Entra**
  `Security Reader` role is unrelated and genuinely required for four Identity collectors — see
  the Graph table below.)

The pre-flight checker no longer asks for any of the three, and `Test-AZSCPermissions` no longer
reports them as missing.
:::

::: tip Key Vault secrets, keys and certificates never need a data-plane grant
`KeyVaultSecrets` and `KeyVaultKeys` (AB#6822) read `Microsoft.KeyVault/vaults/secrets` and
`.../keys` — **ARM control-plane list operations** that return metadata only: id, `contentType`,
and the `attributes` block (`enabled`, `exp`, `nbf`, `created`, `updated`). `Reader` on the vault
is sufficient; reading a secret's or key's **value** is a separate data-plane operation against
`<vault>.vault.azure.net` that needs a Key Vault access policy or data-plane RBAC role, and Scout
never makes that call. A Key Vault certificate has no ARM list endpoint of its own — it is
materialised as a secret whose `contentType` is `application/x-pkcs12` or `application/x-pem-file`,
and that secret's `attributes.exp` **is** the certificate's expiry, so certificate expiry is
already present in the `KeyVaultSecrets` worksheet's `Kind`/`Expires` columns rather than a
separate collector. See `src/collect/Get-ScoutArmChildResource.ps1` for the exact calls.
:::

::: tip Cost data is not gated on a role at all
`Microsoft.CostManagement/query/read` is inside `Reader`'s `*/read`. If cost data still comes
back empty with `Reader` assigned, the cause is a **billing setting**, not a permission: EA
**"AO view charges"** or MCA **"Azure charges"** (the current name; older documentation calls it
"Allow Azure subscription users to view and optimize costs"). Only an Enterprise Administrator
(EA) or a **Billing Profile Owner** (MCA) can enable it — no Azure RBAC role, including
`Cost Management Reader`, substitutes for it. See [Troubleshooting](./troubleshooting.md).
:::

The pre-flight checker validates:

- **Subscription Enumeration** — Can `Get-AzSubscription` return at least one subscription? (Fail if not)
- **Role Assignment Read** — Can `Get-AzRoleAssignment` read `Reader` on each target subscription? (Fail per subscription if `Reader` is missing there — `Reader` is the whole ARM ask, so there is no separate "optional role missing" Warn state any more)

## Microsoft Graph Permissions

These are the Microsoft Graph **application** permissions a service principal needs for Entra ID
inventory (`-Scope All` or `-Scope EntraOnly`). They are derived directly from the queries Scout's
Entra collectors actually issue — not a hand-maintained list — so a permission with no consumer
is called out rather than requested:

| Permission | Type | Purpose |
|------------|------|---------|
| `Organization.Read.All` | Application or Delegated | Read tenant organization details |
| `User.Read.All` | Application or Delegated | Read all user profiles |
| `Group.Read.All` | Application or Delegated | Read all groups and memberships |
| `Application.Read.All` | Application or Delegated | Read all app registrations and service principals |
| `RoleManagement.Read.Directory` | Application or Delegated | Read directory roles and PIM role assignments |
| `Policy.Read.All` | Application or Delegated | Read conditional access policies, named locations, authorization policy, cross-tenant access policy |
| `AdministrativeUnit.Read.All` | Application or Delegated | Read administrative units |
| `Domain.Read.All` | Application or Delegated | Read verified domains |
| `IdentityRiskyUser.Read.All` | Application or Delegated | Read risky-user signals — **also requires an Entra ID P2 licence**; a P1 tenant with the permission granted still returns nothing |

::: warning `IdentityProvider.Read.All` is queried but no collector reads the result — do not grant it
Scout's pre-flight now derives criticality from which collectors actually consume a permission,
not from a fixed list. `IdentityProvider.Read.All` still shows up as a probe because the query
runs, but nothing downstream reads its output, so the pre-flight reports it `Warn` —
"queried but NO collector reads the result. Do not grant it." — rather than asking for it.
`AuditLog.Read.All` was removed from the ask entirely for the same reason: no collector ever
consumed sign-in logs.
:::

If you're signing in as a **user** instead of a service principal, the equivalent least-privilege
grant is two Entra **directory roles** — `Directory Readers` + Entra `Security Reader` — not the
application permissions above. Azure RBAC, Entra directory roles, and Graph application
permissions are three separate systems with different scoping and approvers; pick the directory
roles or the app permissions based on whether Scout runs as a user or a service principal, don't
mix them. `Directory Readers` + `Security Reader` covers 14 of the 15 Entra collectors; the
fifteenth, `CrossTenantAccess`, needs `Security Administrator`, `Tenant Governance Administrator`,
or `Global Reader` — evaluate the first two before reaching for `Global Reader`, which Microsoft
classifies as a privileged role. See [Assessment Permissions](../assessment/assessment-permissions.md).

## Pre-flight Validation

The `Test-AZSCPermissions` function runs automatically before extraction (unless `-SkipPermissionCheck` is set):

| Check | Severity | Behavior |
|-------|----------|----------|
| ARM: Subscription Enumeration | **Fail** | Stops ARM extraction if no subscriptions accessible |
| ARM: Role Assignment Read (per subscription) | **Fail** | That subscription's inventory is incomplete without `Reader` |
| Graph: each permission with a consumer | **Fail** | Names the exact collectors that will come back empty, and the permission to grant |
| Graph: each permission with no consumer | **Warn** | Reports it as unused — "do not grant" — rather than requesting it |

**The output is a per-collector impact table, not a bare READY / PARTIAL / INSUFFICIENT
verdict.** Criticality is derived from which collectors consume which permission, so there is no
separate hardcoded list of "critical" permissions to fall out of date. A denied Graph permission
also reaches PowerShell's warning stream now, not only a coloured console write — so an
automated caller (CI, a scheduled Automation Account run) can detect and act on it, not just a
human watching the console. See [Troubleshooting](./troubleshooting.md) for what to do with a
`Fail`.

## Scope-Based Gating

Permission checks respect the `-Scope` parameter:

- `ArmOnly` — Only ARM checks run (Graph checks are skipped entirely)
- `EntraOnly` — Only Graph checks run (ARM checks are skipped entirely)
- `All` — Both ARM and Graph checks run

## Remediation

If the permission checker reports failures:

1. For ARM: Ensure `Reader` role is assigned on target subscriptions
2. For Graph: Grant the required Microsoft Graph API permissions to your app registration or user account
3. Re-run with the appropriate credentials

::: warning Verification status
This page is documentation analysis backed by Microsoft's published role and permission
references, not a tested result. No run has been performed against a `Reader`-only principal (or
the Entra/Graph minimum-privilege grants above) to confirm every collector still returns data.
The reasoning is sound and Microsoft-doc-backed, but treat it as **probable, not proven** until a
live comparison run exists.
:::

## A different, narrower model for the CAF/WAF assessment platform

Everything above is the **inventory mode** permission model
(`Invoke-AzureScout` / `Test-AZSCPermissions`). **Assessment mode**
(`-Assessment` / `Test-ScoutPermission`) uses a different,
narrower model — do not conflate the two:

| | Inventory mode (`Test-AZSCPermissions`) | Assessment mode (`Test-ScoutPermission`) |
|---|---|---|
| ARM scope | `Reader` on each target **subscription** | `Reader` at the **tenant-root management group** |
| Graph | Up to 9 permissions, required for `-Scope All`/`EntraOnly` | Not required by any assessment out of the box — governance data (`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`) is collected natively via ARM/Resource Graph. 4 Graph permissions apply **only** if you opt one of those 5 into the legacy `AzGovViz` ingestor instead |
| Live-validated? | Yes — both ARM and Graph checks call live endpoints | ARM check is live; the 4 Graph permissions are listed as an **unverified checklist** (`Ok = $null`), not actually tested |

Full matrix (every assessment, minimum RBAC, which need Graph, and the
`PrivilegedAccess.Read.AzureResources` / Entra P2 nuance):
[Auth & permissions per scan type](../assessment/assessment-permissions.md).
