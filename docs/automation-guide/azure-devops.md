---
description: Inventory Azure DevOps projects, pipelines, service connections, repositories, and agent pools alongside your Azure resources.
---

# Azure DevOps

`-IncludeDevOps` extends a scan to cover Azure DevOps, so a single report holds both the
infrastructure and the pipelines that deploy to it.

```powershell
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps
```

Five worksheets are added: **ADO Projects**, **ADO Pipelines**, **ADO Service
Connections**, **ADO Repositories**, and **ADO Agent Pools**.

## Why it is opt-in

Azure DevOps is a separate service with its own authorization model — a fourth permission
system, unrelated to both Azure RBAC and Entra directory roles. An identity with Owner on every
Azure subscription and Global Administrator in Entra still gets zero rows here without Azure
DevOps org/project membership. An inventory run should not stall or fail on it by default, so
collection only happens when you ask for it. The rest of the scan is unaffected either way.

Read-only **project-level** access — no organization administrator role — is sufficient. See
[Permissions](../guide/permissions.md) for how this fits alongside the ARM and Entra grants when you're
assembling a full access request.

## Authentication

By default, no personal access token is needed. AzureScout requests an Entra access token
for the Azure DevOps resource using the identity already signed in for the Azure
inventory:

```powershell
Connect-AzAccount
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps
```

Supply a PAT when the Azure identity and the Azure DevOps identity differ:

```powershell
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps -DevOpsPat $env:ADO_PAT
```

A PAT needs **read** scope on: Project and Team, Build, Release, Code, Service
Connections, and Agent Pools. Nothing is ever written — every call is a GET.

::: warning Never put a PAT in a script file
Pass it from an environment variable or a secret store. A PAT committed to a repository is
a credential leak, and AzureScout's own hard rules forbid secrets in committed files.
:::

## Choosing organizations

Organizations are discovered from the signed-in profile when you do not name them:

```powershell
# Discovers every organization the signed-in user belongs to
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps
```

A service principal has no profile to enumerate, so unattended runs must name their
organizations explicitly:

```powershell
Invoke-AzureScout -TenantID '<tenant-id>' `
                  -AppId '<client-id>' -Secret '<secret>' `
                  -IncludeDevOps -DevOpsOrganization 'contoso','fabrikam'
```

## What gets collected

| Worksheet | Contents |
|---|---|
| ADO Projects | Name, description, state, visibility, revision, last update |
| ADO Pipelines | Name, owning project, folder, configuration type, YAML path, revision |
| ADO Service Connections | Name, type, authorization scheme, service principal, target subscription, in-scope flag |
| ADO Repositories | Name, owning project, default branch, size, disabled flag, web URL |
| ADO Agent Pools | Name, hosting model, pool type, agent count, auto-provision, owner |

## The subscription cross-reference

**ADO Service Connections** is the sheet worth reading first. For every Azure Resource
Manager connection it records the target subscription and, crucially, whether that
subscription is one the current scan covers:

| Column | Meaning |
|---|---|
| `Target Subscription ID` | The subscription the connection can reach |
| `Subscription In Scope` | `Yes` when that subscription is part of this scan |
| `Credential Free` | `Yes` for workload identity federation; `No` for a secret or certificate |

A `Subscription In Scope` of `Yes` means a pipeline in that project has a credentialled
path into infrastructure this report covers — that is the pairing worth reviewing. Rows
are highlighted in the workbook.

`Credential Free` of `No` marks a connection still authenticating with a secret or
certificate, each of which expires and has to be rotated. Migrating those to workload
identity federation removes the rotation burden entirely.

**ADO Agent Pools** highlights self-hosted pools for the same reason: those are the agents
you patch, secure, and pay for, as opposed to the Microsoft-hosted ones.

## Combining with other options

`-IncludeDevOps` composes with everything else:

```powershell
# Azure DevOps plus Entra ID plus ARM
Invoke-AzureScout -TenantID '<tenant-id>' -Scope All -IncludeDevOps

# Azure DevOps data in JSON for downstream processing
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps -OutputFormat Json

# Two organizations, named run folder
Invoke-AzureScout -TenantID '<tenant-id>' -IncludeDevOps `
                  -DevOpsOrganization 'contoso','fabrikam' `
                  -RunName 'devops-audit'
```

Azure DevOps collectors live in the `Management` category, so `-Category Management`
includes them and any other category filter excludes them.

## Partial access is normal

An identity commonly holds project read but not service connection read. AzureScout treats
a 401 or 403 on one endpoint as a skip for that slice and carries on with the rest —
you get the projects and pipelines even when the service connections are denied. Run with
`-Debug` to see exactly which endpoints were refused.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "No Azure DevOps organizations could be discovered" | Service principal, or a user with no profile | Pass `-DevOpsOrganization` |
| "Could not acquire an Azure DevOps token" | Not signed in, or the sign-in cannot reach Azure DevOps | `Connect-AzAccount`, or pass `-DevOpsPat` |
| ADO Service Connections sheet missing | Identity lacks service connection read | Grant the scope, or accept the partial result |
| All `Subscription In Scope` values are `No` | Connections point at subscriptions outside this scan | Widen the scan, or omit `-SubscriptionID` |
| Organization skipped with "No project access" | Identity is not a member of that organization | Check membership, or drop it from `-DevOpsOrganization` |

## Related

- [GitHub Actions](./github-actions.md) — running AzureScout itself from a pipeline
- [Azure Automation Account](./automation.md) — scheduled unattended runs
- [Category Reference](../reference/category-reference.md) — where these collectors sit
- [Authentication](../guide/authentication.md) — Azure sign-in methods
