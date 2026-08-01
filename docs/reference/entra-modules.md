---
description: Complete catalog of AzureScout Microsoft Entra ID inventory modules.
---

# Entra ID Inventory Modules

## Overview

AzureScout includes **17 Entra ID (Identity) inventory modules** that extract tenant-wide identity and access management data via the Microsoft Graph API. They live alongside one ARM-based module (`ManagedIds` — user-assigned managed identity *resources*, as opposed to the Entra-side `ManagedIdentities` service-principal view below) in the `Identity` category folder — see [ARM Modules: Identity](./arm-modules.md#identity-1-arm-module) for that one.

Run Entra-only extraction with:

```powershell
Invoke-AzureScout -Scope EntraOnly
```

## How Entra Extraction Works

The `Start-AZSCEntraExtraction` function calls `Invoke-AZSCGraphRequest` for each Entra module, which:

1. Authenticates via the Graph token obtained during login
2. Queries the relevant Microsoft Graph endpoint
3. Handles pagination (following `@odata.nextLink`)
4. Normalizes each result into a consistent resource shape:

```json
{
  "id": "...",
  "name": "Display Name",
  "TYPE": "microsoft.graph/users",
  "tenantId": "00000000-...",
  "properties": { }
}
```

## Module Catalog

`Get-ScoutEntraQueryCatalog` (`src/collect/Get-ScoutEntraQueryCatalog.ps1`) is the single source
of truth for these 17 queries — `Start-AZSCEntraExtraction` runs exactly this list, and the
`-PermissionAudit` impact table is built by joining the same list against the collector
manifests, so the two can no longer drift the way a hand-maintained second copy could.

| Module | Graph Endpoint | Permission | Description |
|--------|----------------|------------|-------------|
| Users | `/users` | `User.Read.All` | All user accounts (members and guests) |
| Groups | `/groups` | `Group.Read.All` | Security groups, Microsoft 365 groups, distribution lists |
| Applications | `/applications` | `Application.Read.All` | Application registrations (app IDs, credentials, API permissions) |
| Service Principals | `/servicePrincipals` | `Application.Read.All` | Enterprise applications and service principals |
| Managed Identities | `/servicePrincipals` (filtered to `servicePrincipalType eq 'ManagedIdentity'`) | `Application.Read.All` | Managed identities (system and user-assigned), as seen from the Entra service-principal object |
| Directory Roles | `/directoryRoles` | `RoleManagement.Read.Directory` | Activated directory roles and their members |
| PIM Assignments | `/roleManagement/directory/roleAssignments` | `RoleManagement.Read.Directory` | Privileged Identity Management (PIM) role assignments |
| Conditional Access Policies | `/identity/conditionalAccess/policies` | `Policy.Read.All` | Conditional Access policies |
| Named Locations | `/identity/conditionalAccess/namedLocations` | `Policy.Read.All` | Trusted locations for conditional access |
| Administrative Units | `/directory/administrativeUnits` | `AdministrativeUnit.Read.All` | Administrative units for delegated management |
| Domains | `/domains` | `Domain.Read.All` | Verified and unverified domains |
| Subscribed SKUs | `/subscribedSkus` | `Organization.Read.All` | License SKUs and service plan assignments |
| Cross-Tenant Access | `/policies/crossTenantAccessPolicy/partners` | `Policy.Read.All` | B2B cross-tenant access settings |
| Security Policies | `/policies/authorizationPolicy` | `Policy.Read.All` | Tenant authorization policy |
| Risky Users | `/identityProtection/riskyUsers` | `IdentityRiskyUser.Read.All` | Users flagged by Identity Protection (requires Entra ID P2) |
| Identity Providers ⚠️ | `/identity/identityProviders` | `IdentityProvider.Read.All` | Configured external/social identity providers |
| Security Defaults ⚠️ | `/policies/identitySecurityDefaultsEnforcementPolicy` | `Policy.Read.All` | Tenant-wide security defaults enforcement state |

::: warning ⚠️ Collected, normalized, and read by nothing
`Identity Providers` and `Security Defaults` are queried and land in `EntraResources` like every
other row here, but no collector consumes either `entra/identityproviders` or
`entra/securitydefaults` type. The catalog keeps them rather than dropping them so the
`-PermissionAudit` impact table can say so explicitly — a permission Scout asks for and does not
need belongs in the report, not in a comment nobody reads. `AuditLog.Read.All` used to be
requested with the same problem (no collector ever consumed `auditLogs/*`); it has been removed
from the ask entirely rather than kept as a fourth unconsumed entry.
:::

## Required Microsoft Graph Permissions

> **"I'm a Global Administrator but the Entra modules still fail with 403 — why?"**
>
> **Global Administrator is an Entra directory *role*, not a Microsoft Graph API *scope*.**
> Entra extraction uses the Graph token that **Azure CLI** issues
> (`az account get-access-token --resource https://graph.microsoft.com`). That token
> only carries the **delegated Graph scopes the Azure CLI application has been consented**
> for you — your directory role does **not** widen those scopes. So an endpoint whose
> scope has not been consented returns `403 Forbidden` regardless of your role.

To read every module above, the signed-in identity needs these **delegated** Microsoft
Graph permissions consented for the Azure CLI app (or your own app if you authenticate
with one) — see the Permission column in the [Module Catalog](#module-catalog) above for
which permission unlocks which module:

| Permission | Unlocks |
|---|---|
| `User.Read.All` | Users |
| `Group.Read.All` | Groups |
| `Application.Read.All` | Applications, Service Principals, Managed Identities |
| `RoleManagement.Read.Directory` | Directory Roles, PIM Assignments |
| `Policy.Read.All` | Conditional Access Policies, Named Locations, Security Policies, Cross-Tenant Access, Security Defaults ⚠️ |
| `AdministrativeUnit.Read.All` | Administrative Units |
| `Domain.Read.All` | Domains |
| `Organization.Read.All` | Subscribed SKUs |
| `IdentityRiskyUser.Read.All` | Risky Users (Identity Protection — also requires Entra ID P2) |
| `IdentityProvider.Read.All` ⚠️ | Identity Providers |

⚠️ marks the two permissions behind the unconsumed queries — granting them satisfies the
pre-flight but adds nothing to any report; see the warning above.

A broad `Directory.Read.All` grant also satisfies `User.Read.All`, `Group.Read.All` and
`Application.Read.All` in practice, since it is a superset scope, but the table above is the
minimum each query actually needs.

Grant/consent once (tenant admin), e.g.:

```powershell
# Consent the Azure CLI app to the delegated scopes, then re-login:
az login --scope https://graph.microsoft.com/.default
# (Or have a Global Admin grant admin-consent for the scopes above in the Entra portal.)
```

Endpoints requiring a licensing tier you don't have (e.g. Risky Users without Entra ID P2)
will still 403 — that is expected and is handled by [Graceful Degradation](#graceful-degradation)
below rather than aborting the run.

## Data Normalization

All 17 Entra modules produce output in the same normalized shape:

| Field | Source |
|-------|--------|
| `id` | Graph object `id` |
| `name` | `displayName` (or most relevant name field) |
| `TYPE` | Synthetic type string (e.g., `microsoft.graph/users`) |
| `tenantId` | Tenant ID from the current session |
| `properties` | Full Graph object properties |

This normalization allows ARM and Entra resources to be processed by the same reporting pipeline.

## Graceful Degradation

If a single Entra query fails (e.g., insufficient permissions for Conditional Access policies), the module:

- Logs a warning
- Continues with the remaining 16 queries
- Returns partial results rather than failing entirely

If *all* queries fail, the function returns an empty `EntraResources` collection.
