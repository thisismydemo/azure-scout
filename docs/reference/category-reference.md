---
description: Complete reference mapping every report section heading to its category alias, manifest directory, and module count.
---

# Category Reference

Every section heading in an AzureScout report comes from a category. This page is the
mapping in both directions: heading → category → manifest directory, and every alias the
`-Category` parameter accepts.

Use it when you see a heading in a report and want to know which collector produced it,
or when you want to re-run a scan narrowed to just that section.

::: tip Where the aliases live
The alias table is the `$_categoryAliasMap` hashtable in
`Modules/Public/PublicFunctions/Invoke-AzureScout.ps1`. Alias matching is
case-insensitive, so `iot`, `IoT`, and `INTERNET OF THINGS` all resolve identically.
:::

## Report section heading → category

| Report section heading | `-Category` value | manifest directory | Modules |
|---|---|---|---|
| AI + machine learning | `AI` | `manifests/collectors/AI/` | 27 |
| Analytics | `Analytics` | `manifests/collectors/Analytics/` | 6 |
| Compute | `Compute` | `manifests/collectors/Compute/` | 13 |
| Containers | `Containers` | `manifests/collectors/Containers/` | 6 |
| Databases | `Databases` | `manifests/collectors/Databases/` | 12 |
| DevOps | `DevOps` | `manifests/collectors/DevOps/` | 12 |
| General | `General` | `manifests/collectors/General/` | 4 |
| Hybrid + multicloud | `Hybrid` | `manifests/collectors/Hybrid/` | 15 |
| Identity | `Identity` | `manifests/collectors/Identity/` | 17 |
| Integration | `Integration` | `manifests/collectors/Integration/` | 9 |
| Internet of Things | `IoT` | `manifests/collectors/IoT/` | 7 |
| Management and governance | `Management` | `manifests/collectors/Management/` | 21 |
| Migration | `Migration` | `manifests/collectors/Migration/` | 6 |
| Monitor | `Monitor` | `manifests/collectors/Monitor/` | 22 |
| Networking | `Networking` | `manifests/collectors/Networking/` | 21 |
| Security | `Security` | `manifests/collectors/Security/` | 17 |
| Storage | `Storage` | `manifests/collectors/Storage/` | 11 |
| Web and mobile | `Web` | `manifests/collectors/Web/` | 14 |

**240 declarative collector definitions across all 18 of Microsoft's published service
categories.** Counts are the `.psd1` file count in each category directory; one definition
generally maps to one worksheet in the Excel report.

Six collectors were retired on 2026-07-31 (Epic AB#6731, AB#6842) because the resource type(s)
they declared do not exist in Azure at any permission level, so they could never return a row in
any tenant: `Hybrid/ArcSites` (three fabricated type strings), `Compute/CloudServices`
(`microsoft.classiccompute` now lists zero types — classic/ASM is gone), `Storage/DataLakeStoreGen1`
(Data Lake Gen1 retired 2024-02-29), `Databases/POSTGRE` (PostgreSQL Single Server is end of life),
and `Monitor/AppInsightsContinuousExport` / `Monitor/AppInsightsWorkItems` (Azure removed both
endpoints). That took the count from 242 to 236: Compute, Databases, Hybrid, Monitor and Storage
each lost one collector except Monitor, which lost two.

Three more collectors were **corrected** rather than retired in the same pass — each declared a
renamed or retired resource type alongside a live one, so each was half-collecting silently:
`Migration/AzureMigrateProjects`, `Security/CloudHSM`, `Security/ConfidentialLedger`. The dead type
string was dropped from each spec; the collector itself still exists and its module count is
unchanged.

Four collectors were **added** on 2026-07-31 (AB#6779), taking the count from 236 to 240:
`Identity/RoleAssignments`, `Management/PolicyAssignments`, `Management/ResourceLocks` and
`Management/Budgets`. They render data every assessment run was already collecting and throwing
away — a run held the answer to "who has Owner" in memory and had nowhere to write it. They cost
no additional Azure call: the two Resource Graph queries and two ARM REST reads behind them moved
out of the governance ingestor into the collection pass, which now feeds both.

`Management/Budgets` covers what the audit's build list calls `Cost/Budgets`. Cost Management sits
under "Management and governance" in Microsoft's own service taxonomy, and Scout's category set is
that published 18 — so the sheet is the one the audit asked for, filed where the taxonomy puts it.

Every declared resource type is now checked against a committed catalogue of real Azure
provider/type pairs by `tests/ResourceTypeExistence.Tests.ps1` — see
[Testing: the resource-type existence gate](../project/testing.md#the-resource-type-existence-gate). It is
what caught this batch, and it runs on every pull request so a collector for a type Azure does not
have can no longer ship.

`DevOps`, `General` and `Migration` are new in v3.1.0 (AB#6741). Before it Scout modelled fifteen
categories and had no home at all for Azure Migrate, Data Box, Chaos Studio, Dev Box, Reservations
or Quotas. `SupportTickets` and `ReservationRecom` moved from `Management` to `General` in the same
release, unchanged — their rows are byte-identical, which the golden records prove.

The five Azure DevOps *organisation* collectors (ADO Projects, Pipelines, Repositories, Service
Connections, Agent Pools) still sit under `Management` and still require `-IncludeDevOps` — see
[Azure DevOps](../automation-guide/azure-devops.md). They read the Azure DevOps REST API, not ARM, and are a different
thing from the `DevOps` service category, which holds ARM resources such as Chaos Studio and Dev
Box. The names collide because Microsoft's do.

## Accepted aliases

Every value below is accepted by `-Category` and normalised to the canonical short value
before any filtering happens. Anything not listed here must be passed as the canonical
value — `[ValidateSet]` rejects unknown input at parameter-binding time.

| Alias (accepted input) | Resolves to |
|---|---|
| `AI + machine learning` | `AI` |
| `AI+machine learning` | `AI` |
| `Machine Learning` | `AI` |
| `Internet of Things` | `IoT` |
| `Monitoring` | `Monitor` |
| `Management and governance` | `Management` |
| `Management & governance` | `Management` |
| `Web & Mobile` | `Web` |
| `Web and mobile` | `Web` |
| `Mobile` | `Web` |
| `Hybrid + multicloud` | `Hybrid` |
| `Hybrid+multicloud` | `Hybrid` |
| `Networking + CDN` | `Networking` |
| `Networking+CDN` | `Networking` |

::: warning Monitor, not Monitoring
The canonical value is `Monitor`. `Monitoring` is accepted as an alias, but the folder,
the report heading, and the `[ValidateSet]` entry are all `Monitor`. Scripts should use
the canonical value.
:::

::: warning `DevOps` and `Migration` are no longer aliases
Both used to be listed as aliases resolving to `Management`. They are **canonical categories** as
of v3.1.0, each with its own manifest directory. The alias entries were also unreachable — neither
string was in the `[ValidateSet]`, so parameter binding rejected them before the map was consulted,
and the documented behaviour never once occurred.
:::

## What each category covers

| Category | Representative collectors |
|---|---|
| `AI` | AI Foundry hubs and projects, Azure OpenAI, Cognitive Services, Bot Services, Computer Vision, ML workspaces |
| `Analytics` | Synapse, Databricks, Data Explorer clusters, Event Hubs, Stream Analytics, Purview |
| `Compute` | Virtual machines, scale sets, availability sets, and the full Azure Virtual Desktop set (host pools, session hosts, application groups, scaling plans) |
| `Containers` | AKS, ARO, Container Apps and environments, container groups, container registries |
| `Databases` | SQL, Cosmos DB, MySQL and flexible server, PostgreSQL and flexible server, MariaDB, Redis |
| `Hybrid` | Arc-enabled servers, Kubernetes, data controllers, SQL Server, extensions, gateways, resource bridge, Azure Local |
| `Identity` | Entra ID users, groups, app registrations, Conditional Access, PIM, directory roles, administrative units, domains |
| `DevOps` | Chaos Studio, Dev centers and projects, Dev Box pools, network connections, deployment environments, DevTest Labs, Lab Services, Load Testing, Managed DevOps Pools, Playwright workspaces, App Configuration, API Connections |
| `General` | Support tickets, owned reservations and reservation recommendations, VM quotas |
| `Integration` | Logic Apps, integration accounts and custom connectors, Event Grid, Event Hubs clusters, Relays, Health Data Services (FHIR/DICOM), API Management, Service Bus |
| `IoT` | IoT Hubs, Device Provisioning Service, IoT Central, Device Update, Digital Twins, Azure Maps, Defender for IoT |
| `Migration` | Azure Migrate projects, assessment projects and discovery sites; Database Migration Services, Data Box, Azure Stack Edge |
| `Management` | Subscriptions, management groups, policy, custom role definitions, Automation Accounts, Backup, Advisor score, Lighthouse delegations, plus the five Azure DevOps collectors (projects, pipelines, service connections, repositories, agent pools) gated behind `-IncludeDevOps` |
| `Monitor` | Action groups, alert rules, Application Insights and its deep-data modules, data collection rules, diagnostic settings, Log Analytics |
| `Networking` | VNets, NSGs, load balancers, application gateways, Front Door, Azure Firewall, Bastion, ExpressRoute, VPN connections |
| `Security` | Microsoft Defender for Cloud alerts, assessments, pricing, secure score; Key Vault plus its secret/key/certificate expiry; Sentinel, Managed HSM, Cloud HSM, application security groups, WAF policies, DDoS protection plans, Confidential Ledger, artifact signing, Entra Domain Services, App Compliance Automation |
| `Storage` | Storage accounts plus their blob containers, file shares and lifecycle policies; NetApp Files, snapshots, disk encryption sets, Elastic SAN, Storage Sync, Edge Hardware Center, partner storage (Pure, Qumulo) |
| `Web` | App Services and plans, Function Apps, deployment slots, App Service Environments, Static Web Apps, certificates and domains, SignalR, Web PubSub, Communication Services, Notification Hubs, Fluid Relay, Spring Apps |

## Filtering examples

```powershell
# One category, canonical value
Invoke-AzureScout -Category Compute

# Several categories
Invoke-AzureScout -Category Compute,Networking,Storage

# Portal long name — normalised to 'Hybrid'
Invoke-AzureScout -Category 'Hybrid + multicloud'

# Alias combined with a scope
Invoke-AzureScout -Scope All -Category Security,Identity

# Default: every category
Invoke-AzureScout
```

The report contains worksheets only for the categories you selected. The Overview tab
reports how many categories were selected and how many modules actually executed.

## Keeping this page accurate

The module counts here are derived from the manifest directorys. When you add or remove a
collector, update the counts in the first table; when you add an alias to
`$_categoryAliasMap`, add the row to the alias table. See
[Category Structure](./category-structure.md) for the folder layout and
[Category Filtering](../guide/category-filtering.md) for how the filter is applied at runtime.
