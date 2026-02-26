---
description: Complete catalog of AzureScout Microsoft Entra ID inventory modules.
---

# Entra ID Inventory Modules

## Overview

AzureScout includes **15 Entra ID (Identity) inventory modules** that extract tenant-wide identity and access management data via the Microsoft Graph API.

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
| Licensing | `/subscribedSkus` | License SKUs and service plan assignments |
| ManagedIdentities | `/servicePrincipals` (filtered) | Managed identities (system and user-assigned) |
| NamedLocations | `/identity/conditionalAccess/namedLocations` | Trusted locations for conditional access |
| PIMAssignments | `/roleManagement/directory/roleAssignments` | Privileged Identity Management (PIM) role assignments |
| RiskyUsers | `/identityProtection/riskyUsers` | Users flagged by Identity Protection |
| SecurityPolicies | `/policies/authorizationPolicy` | Tenant security defaults and authorization policies |
| ServicePrincipals | `/servicePrincipals` | Enterprise applications and service principals |
| Users | `/users` | All user accounts (members and guests) |

## Data Normalization

All 15 Entra modules produce output in the same normalized shape:

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
- Continues with the remaining 14 queries
- Returns partial results rather than failing entirely

If *all* queries fail, the function returns an empty `EntraResources` collection.
