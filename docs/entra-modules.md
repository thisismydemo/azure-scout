---
description: Complete catalog of AzureScout Microsoft Entra ID inventory modules.
---

# Entra ID Inventory Modules

## Overview

AzureScout includes **17 Entra ID (Identity) inventory modules** that extract tenant-wide identity and access management data via the Microsoft Graph API. They live alongside one ARM-based module (`ManagedIds` — user-assigned managed identity *resources*, as opposed to the Entra-side `ManagedIdentities` service-principal view below) in the `Identity` category folder — see [ARM Modules: Identity](arm-modules.md#identity-1-arm-module) for that one.

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

| Module | Graph Endpoint | Description |
|--------|----------------|-------------|
| AdminUnits | `/administrativeUnits` | Administrative units for delegated management |
| AppRegistrations | `/applications` | Application registrations (app IDs, credentials, API permissions) |
| ConditionalAccess | `/identity/conditionalAccess/policies` | Conditional Access policies (requires `Policy.Read.ConditionalAccess`) |
| CrossTenantAccess | `/policies/crossTenantAccessPolicy/partners` | B2B cross-tenant access settings |
| DirectoryRoles | `/directoryRoles` | Activated directory roles and their members |
| Domains | `/domains` | Verified and unverified domains |
| Groups | `/groups` | Security groups, Microsoft 365 groups, distribution lists |
| IdentityProviders | `/identity/identityProviders` | Configured external/social identity providers |
| Licensing | `/subscribedSkus` | License SKUs and service plan assignments |
| ManagedIdentities | `/servicePrincipals` (filtered) | Managed identities (system and user-assigned), as seen from the Entra service-principal object |
| NamedLocations | `/identity/conditionalAccess/namedLocations` | Trusted locations for conditional access |
| PIMAssignments | `/roleManagement/directory/roleAssignments` | Privileged Identity Management (PIM) role assignments |
| RiskyUsers | `/identityProtection/riskyUsers` | Users flagged by Identity Protection |
| SecurityDefaults | `/policies/identitySecurityDefaultsEnforcementPolicy` | Tenant-wide security defaults enforcement state |
| SecurityPolicies | `/policies/authorizationPolicy` | Tenant authorization policy |
| ServicePrincipals | `/servicePrincipals` | Enterprise applications and service principals |
| Users | `/users` | All user accounts (members and guests) |

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
with one):

| Permission | Unlocks |
|---|---|
| `Directory.Read.All` | Users, Groups, Service Principals, App Registrations, Directory Roles, Admin Units, Domains, Licensing |
| `Policy.Read.All` | Conditional Access, Named Locations, Security Defaults, Authorization Policy, Cross-Tenant Access |
| `RoleManagement.Read.Directory` | PIM / directory role assignments |
| `IdentityRiskyUser.Read.All` | Risky Users (Identity Protection — also requires Entra ID P2) |

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
