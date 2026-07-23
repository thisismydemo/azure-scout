---
description: ARM RBAC and Microsoft Graph permissions required by AzureScout.
---

# Required Permissions

::: tip This page covers the v1 inventory tool
This page describes the permission model for the **v1 inventory cmdlet**
(`Invoke-AzureScout` / `Test-AZSCPermissions`). The **CAF/WAF assessment platform**
(`Invoke-ScoutAssessment` / `Test-ScoutPermission`) uses a different, narrower model
— see the note at the bottom of this page, or go straight to
[Assessment Permissions](assessment-permissions.md). Not sure which tool you need?
See [Overview: Inventory vs Assessment](overview.md).
:::

## Overview

AzureScout requires two categories of permissions:

1. **ARM (Azure Resource Manager)** — RBAC role assignments on subscriptions
2. **Microsoft Graph API** — Application or delegated permissions for Entra ID data

## ARM Permissions

| Permission | Scope | Purpose |
|------------|-------|---------|
| `Reader` | Subscription(s) | Enumerate resources, read properties |
| `Reader` on role assignments | Subscription(s) | Read RBAC role assignments (optional — Warn if missing) |

The pre-flight checker validates:

- **Subscription Enumeration** — Can `Get-AzSubscription` return at least one subscription? (Fail if not)
- **Role Assignment Read** — Can `Get-AzRoleAssignment` read roles on the first subscription? (Warn if not — non-blocking)

## Microsoft Graph Permissions

The following Microsoft Graph API permissions are required for Entra ID inventory:

| Permission | Type | Purpose |
|------------|------|---------|
| `Organization.Read.All` | Application or Delegated | Read tenant organization details |
| `User.Read.All` | Application or Delegated | Read all user profiles |
| `Group.Read.All` | Application or Delegated | Read all groups and memberships |
| `Application.Read.All` | Application or Delegated | Read all app registrations and service principals |
| `Directory.Read.All` | Application or Delegated | Read directory roles, administrative units, domains |
| `Policy.Read.All` | Application or Delegated | Read conditional access policies, named locations |
| `RoleManagement.Read.All` | Application or Delegated | Read PIM role assignments and eligible assignments |
| `IdentityProvider.Read.All` | Application or Delegated | Read authentication methods and identity providers |
| `Policy.Read.ConditionalAccess` | Application or Delegated | Read conditional access policies (optional — Warn only) |

## Pre-flight Validation

The `Test-AZSCPermissions` function runs automatically before extraction (unless `-SkipPermissionCheck` is set):

| Check | Severity | Behavior |
|-------|----------|----------|
| ARM: Subscription Enumeration | **Fail** | Stops ARM extraction if no subscriptions accessible |
| ARM: Role Assignment Read | **Warn** | Continues — some RBAC data may be missing |
| Graph: Organization Read | **Fail** | Stops Entra extraction if organization endpoint is inaccessible |
| Graph: User Read | **Fail** | Stops Entra extraction if user endpoint is inaccessible |
| Graph: Conditional Access Policies | **Warn** | Continues — CA policy data may be missing |

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

## A different, narrower model for the CAF/WAF assessment platform

Everything above is the **v1 inventory** permission model
(`Invoke-AzureScout` / `Test-AZSCPermissions`). The v2 **assessment platform**
(`Invoke-ScoutAssessment` / `Test-ScoutPermission`) uses a different,
narrower model — do not conflate the two:

| | v1 inventory (`Test-AZSCPermissions`) | v2 assessment (`Test-ScoutPermission`) |
|---|---|---|
| ARM scope | `Reader` on each target **subscription** | `Reader` at the **tenant-root management group** |
| Graph | Up to 9 permissions, required for `-Scope All`/`EntraOnly` | Not required by any assessment out of the box — governance data (`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`) is collected natively via ARM/Resource Graph. 4 Graph permissions apply **only** if you opt one of those 5 into the legacy `AzGovViz` ingestor instead |
| Live-validated? | Yes — both ARM and Graph checks call live endpoints | ARM check is live; the 4 Graph permissions are listed as an **unverified checklist** (`Ok = $null`), not actually tested |

Full matrix (every assessment, minimum RBAC, which need Graph, and the
`PrivilegedAccess.Read.AzureResources` / Entra P2 nuance):
[Auth & permissions per scan type](assessment-permissions.md).
