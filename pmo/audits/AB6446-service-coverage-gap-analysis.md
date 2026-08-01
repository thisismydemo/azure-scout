---
description: AB#6446 — evidence-based audit of Azure Scout's service coverage, the 15-category taxonomy, and the prioritised gaps.
---

# AB#6446 — Azure service coverage gap analysis

> **Superseded, in part (AB#6828, 2026-08-01):** the "new category" framing below (Backup &
> Recovery / Migration / Cost & Optimisation / DevOps / Virtual Desktop as five NEW categories) was
> rejected by DQ3 in `AZURE-SCOUT-AUDIT.md` — Scout holds to Microsoft's 18 published categories,
> and `DevOps` was already one of them, not an invented split. **The DevOps row's underlying action
> — move the five `Management/DevOps*` manifests — has been done**: they now live under
> `manifests/collectors/DevOps/`, alongside the 12 collectors Epic AB#6741 already filed there. See
> `AZURE-SCOUT-AUDIT.md` §6 for the current, corrected coverage numbers.

**Date:** 2026-07-30
**Scope:** `manifests/collectors/**/*.psd1` (174 files), `src/collect/`, `src/ingest/`
**Method:** every manifest parsed with `Import-PowerShellDataFile` and its `ResourceTypes` /
`AdditionalFilter` extracted; compared against the Microsoft resource-provider directory and the
Azure Resource Graph type reference.

---

## Executive summary

**Is 15 categories enough? No — but the category count is the least interesting part of the problem.**

Three findings, in order of importance:

### 1. Scout already *fetches* almost every Azure resource type. It just throws most of them away.

`src/collect/Get-ScoutRawInventory.ps1:424` issues an **unfiltered** `resources` query:

```kql
resources <rg/tag/mg clauses>
| where type !in ('microsoft.logic/workflows','microsoft.portal/dashboards',
                  'microsoft.resources/templatespecs/versions','microsoft.resources/templatespecs')
| project <columns> | order by id asc
```

Four excluded types. Everything else in the tenant comes back. Those rows are then matched against
the 174 collector manifests, and **any row whose `type` has no manifest is silently dropped** — there
is no catch-all sheet, no "Other resources" tab, no warning. I searched for one; it does not exist.

So this is not a *collection* gap. It is a **shaping/reporting gap**. The cost of covering a new
resource type is one manifest, not one more ARG round-trip. That materially changes the work estimate
for everything below — and it is the single most useful fact in this report.

Corollary: **Logic Apps are a genuine collection gap**, because `microsoft.logic/workflows` is one of
the four types explicitly excluded from the query. Fixing Logic Apps means editing that `!in` clause,
not just adding a manifest.

### 2. The per-category counts are misleading in *both* directions.

- **AI's 27 is inflated.** 11 of the 27 are the same resource type — `microsoft.cognitiveservices/accounts`
  — split by `kind` (`ComputerVision`, `Face`, `SpeechServices`, `TextAnalytics`, …). Three more
  (`MachineLearning`, `AIFoundryHubs`, `AIFoundryProjects`) share `microsoft.machinelearningservices/workspaces`.
  AI spans **four** resource providers, not 27 services.
- **Storage's 2 is real and it is bad.** Two types: `microsoft.storage/storageaccounts` and
  `microsoft.netapp/.../volumes`. No containers, no file shares, no lifecycle policies, no File Sync,
  no Elastic SAN, no snapshots.

The honest denominator is resource types, not manifests.

### 3. The headline numbers

| Measure | Value |
|---|---|
| Collector manifests | 174 |
| Distinct `ResourceTypes` strings across all manifests | 152 |
| — of which synthetic (`AZSC/…` pseudo-types for ARM-child / REST data) | 22 |
| — of which Entra/Graph (`entra/…`) | 15 |
| — of which Azure DevOps (`devops/…`) | 5 |
| **Distinct real ARM `Microsoft.*` resource types collected** | **110** |
| Distinct Azure resource providers covered | **52** |
| Resource providers listed in Microsoft's own service directory | ~130 |
| Resource types in the ARG `resources` table alone | 1,100+ |

**Provider coverage is roughly 40%.** Type-level coverage against ARG's 1,100+ is ~10%, but that
denominator is junk — it includes preview types, AWS-connector shims, and hundreds of child types no
assessment would ever surface. Provider coverage is the number to quote.

### The one-line answer for the owner

> You were right that 15 is too few — the taxonomy should be **20**. But the bigger miss is that Scout
> is already pulling every resource in the tenant and discarding ~40% of the providers because nobody
> wrote a manifest for them. Storage, Web, Integration and IoT are the embarrassing ones. The fix is
> ~50 manifests, not a new collection engine.

---

## Current state: what IS collected

### Category summary (actual, from the manifests)

| Category | Manifests | Distinct ARM types | Notes |
|---|---:|---:|---|
| AI | 27 | 4 providers / 4 types | 11 manifests are `cognitiveservices/accounts` split by `kind`; 8 are `AZSC/ARMChild/*` |
| Analytics | 6 | 6 | Databricks, Kusto, Event Hub, Purview, Stream Analytics, Synapse |
| Compute | 14 | 11 | 7 of the 14 are AVD |
| Containers | 6 | 6 | AKS, ARO, Container Apps + env, ACI, ACR |
| Databases | 13 | 14 | RedisCache covers 2 types |
| Hybrid | 16 | 18 | ArcSites covers 3 types; the most complete category in the tool |
| Identity | 16 | 1 ARM + 15 Entra | Only `Microsoft.ManagedIdentity/userAssignedIdentities` is ARM |
| Integration | 2 | 2 | APIM, Service Bus |
| IoT | 1 | 1 | IoT Hub |
| Management | 19 | 6 ARM + 5 DevOps + 5 synthetic | |
| Monitor | 24 | 16 | 6 are `AZSC/ARMChild/*` |
| Networking | 21 | 20 | `VirtualNetwork` and `vNETPeering` share `microsoft.network/virtualnetworks` |
| Security | 5 | 1 | 4 of the 5 read the `AZSC/Subscription/SecurityPolicySweep` envelope |
| Storage | 2 | 2 | |
| Web | 2 | 2 | |

> `docs/coverage-table.md` currently states Identity 18 and a total of 176. The manifests say
> Identity 16 and 174. That page is stale — a small, separate fix.

### Complete list of ARM resource types with a collector

<details>
<summary>110 types (click to expand)</summary>

```
microsoft.advisor/advisorscore                     microsoft.machinelearningservices/workspaces
microsoft.alertsmanagement/smartdetectoralertrules microsoft.maintenance/maintenanceconfigurations
microsoft.apimanagement/service                    microsoft.managedidentity/userassignedidentities
microsoft.app/containerapps                        microsoft.managedservices/registrationdefinitions
microsoft.app/managedenvironments                  microsoft.netapp/netappaccounts/capacitypools/volumes
microsoft.automation/automationaccounts            microsoft.network/applicationgateways
microsoft.avs/privateclouds                        microsoft.network/azurefirewalls
microsoft.azurearcdata/datacontrollers             microsoft.network/bastionhosts
microsoft.azurearcdata/sqlmanagedinstances         microsoft.network/connections
microsoft.azurearcdata/sqlserverinstances          microsoft.network/dnszones
microsoft.azurestackhci/clusters                   microsoft.network/expressroutecircuits
microsoft.azurestackhci/galleryimages              microsoft.network/frontdoors
microsoft.azurestackhci/logicalnetworks            microsoft.network/loadbalancers
microsoft.azurestackhci/marketplacegalleryimages   microsoft.network/natgateways
microsoft.azurestackhci/sites                      microsoft.network/networkinterfaces
microsoft.azurestackhci/storagecontainers          microsoft.network/networksecuritygroups
microsoft.azurestackhci/virtualmachineinstances    microsoft.network/networkwatchers
microsoft.botservice/botservices                   microsoft.network/privatednszones
microsoft.cache/redis                              microsoft.network/privateendpoints
microsoft.cache/redisenterprise                    microsoft.network/publicipaddresses
microsoft.classiccompute/domainnames               microsoft.network/routetables
microsoft.cognitiveservices/accounts               microsoft.network/trafficmanagerprofiles
microsoft.compute/availabilitysets                 microsoft.network/virtualnetworkgateways
microsoft.compute/disks                            microsoft.network/virtualnetworks
microsoft.compute/virtualmachines                  microsoft.network/virtualwans
microsoft.compute/virtualmachinescalesets          microsoft.operationalinsights/workspaces
microsoft.consumption/reservationrecommendations   microsoft.operationsmanagement/solutions
microsoft.containerinstance/containergroups        microsoft.purview/accounts
microsoft.containerregistry/registries             microsoft.recoveryservices/vaults
microsoft.containerservice/managedclusters         microsoft.recoveryservices/vaults/backuppolicies
microsoft.databricks/workspaces                    microsoft.redhatopenshift/openshiftclusters
microsoft.dbformariadb/servers                     microsoft.resourceconnector/appliances
microsoft.dbformysql/flexibleservers               microsoft.search/searchservices
microsoft.dbformysql/servers                       microsoft.servicebus/namespaces
microsoft.dbforpostgresql/flexibleservers          microsoft.sql/managedinstances
microsoft.dbforpostgresql/servers                  microsoft.sql/managedinstances/databases
microsoft.desktopvirtualization/applicationgroups  microsoft.sql/servers
microsoft.desktopvirtualization/hostpools          microsoft.sql/servers/databases
microsoft.desktopvirtualization/hostpools/sessionhosts  microsoft.sql/servers/elasticpools
microsoft.desktopvirtualization/scalingplans       microsoft.sqlvirtualmachine/sqlvirtualmachines
microsoft.desktopvirtualization/workspaces         microsoft.storage/storageaccounts
microsoft.devices/iothubs                          microsoft.streamanalytics/streamingjobs
microsoft.documentdb/databaseaccounts              microsoft.support/supporttickets
microsoft.edgeconfig/sites                         microsoft.synapse/workspaces
microsoft.eventhub/namespaces                      microsoft.web/serverfarms
microsoft.hybridcompute/gateways                   microsoft.web/sites
microsoft.hybridcompute/machines                   microsoft.insights/actiongroups
microsoft.hybridcompute/machines/extensions        microsoft.insights/activitylogalerts
microsoft.hybridcompute/sites                      microsoft.insights/autoscalesettings
microsoft.keyvault/vaults                          microsoft.insights/components
microsoft.kubernetes/connectedclusters             microsoft.insights/datacollectionendpoints
microsoft.kusto/clusters                           microsoft.insights/datacollectionrules
                                                   microsoft.insights/diagnosticsettings
                                                   microsoft.insights/metricalerts
                                                   microsoft.insights/privatelinkscopes
                                                   microsoft.insights/scheduledqueryrules
                                                   microsoft.insights/webtests
                                                   microsoft.insights/workbooks
```

</details>

### The assessment path is a different, narrower surface

Worth stating explicitly so it isn't confused with inventory coverage: `src/collect/Invoke-Collect.ps1`
runs a **typed pack of 36 resource types** feeding the CAF/WAF rule engine, and
`src/ingest/Import-Governance.ps1` adds `policyresources` / `authorizationresources` /
`resourcecontainers` (policy assignments, role assignments, budgets, locks). That governance data
**feeds rules but never reaches an inventory worksheet** — see the gap table below.

Separately, `src/pipeline/diagram/Start-ScoutDiagramSubscription.ps1` carries an icon/shape map naming
~200 resource types (including `microsoft.cdn/profiles`, `microsoft.eventgrid/*`, `microsoft.migrate/*`).
**Those are diagram symbols only — no query, no collector.** Do not read that file as coverage.

---

## Gap analysis: prioritised missing services

Priority key: **P1** = an enterprise assessment is embarrassing without it. **P2** = commonly present,
expected in a thorough report. **P3** = niche, low frequency, or the service is being retired.

### P1 — must have

| Azure service | Resource type | Suggested category | Why it matters |
|---|---|---|---|
| Logic Apps (Consumption) | `Microsoft.Logic/workflows`, `Microsoft.Logic/integrationAccounts` | Integration | **Actively excluded** at `Get-ScoutRawInventory.ps1:245`. Ubiquitous in enterprise integration estates. |
| Azure Front Door Std/Premium + CDN | `Microsoft.Cdn/profiles`, `/afdEndpoints`, `/endpoints` | Networking | Scout collects only `microsoft.network/frontdoors` — **classic, retiring 2027-03-31**. Every modern AFD deployment is invisible. |
| Web Application Firewall policies | `Microsoft.Network/frontdoorWebApplicationFirewallPolicies`, `Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies`, `Microsoft.Cdn/cdnWebApplicationFirewallPolicies` | Security | Scout reports App Gateways and Front Doors but never says whether a WAF is attached or what mode it is in. |
| Azure Firewall Policy | `Microsoft.Network/firewallPolicies`, `/ruleCollectionGroups` | Networking | The report template already admits this: `src/report/templates/report-react.html.template:680` renders "Not collected — Microsoft.Network/firewallPolicies is not queried". |
| Event Grid | `Microsoft.EventGrid/topics`, `/systemTopics`, `/domains` | Integration | Core eventing plumbing; unmanaged system topics are a common finding. |
| Data Factory | `Microsoft.DataFactory/factories` | Analytics | Largest single omission in the data estate. |
| RBAC role assignments | `Microsoft.Authorization/roleAssignments` | Identity | Collected by `Import-Governance.ps1` for rules, but **no inventory sheet**. "Who has Owner" is table stakes. |
| Resource locks | `Microsoft.Authorization/locks` | Management | Same: ingested for rules, never reported. |
| Policy assignments | `Microsoft.Authorization/policyAssignments` | Management | Scout collects policy *definitions* and *set definitions* but not what is actually assigned where. |
| Budgets | `Microsoft.Consumption/budgets` | Cost & Optimisation | Same pattern — ingested, never reported. |
| Backup protected items | `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems` | Backup & Recovery | Scout reports vaults and policies but **not what is actually protected**. "Which VMs have no backup" is unanswerable today. |
| Backup vaults (new model) | `Microsoft.DataProtection/backupVaults` | Backup & Recovery | The current-generation vault type; entirely absent. |
| App Service Environments | `Microsoft.Web/hostingEnvironments` | Web | ASEv3 is the high-value, high-cost App Service footprint. |
| Static Web Apps | `Microsoft.Web/staticSites` | Web | |
| Deployment slots | `Microsoft.Web/sites/slots` | Web | Slot config drift is a standard finding. |
| App Configuration | `Microsoft.AppConfiguration/configurationStores` | Web | |
| Azure File Sync | `Microsoft.StorageSync/storageSyncServices` | Storage | |
| Storage sub-resources | `.../blobServices/containers`, `.../fileServices/shares`, `.../managementPolicies` | Storage | Public containers, lifecycle policies, share quotas — all invisible. |
| Azure Batch | `Microsoft.Batch/batchAccounts` | Compute | |
| Microsoft Fabric | `Microsoft.Fabric/capacities` | Analytics | The strategic analytics platform as of 2026; zero coverage. |
| Azure Monitor Workspace | `Microsoft.Monitor/accounts` | Monitor | Prometheus/managed-Grafana backing store; 24 Monitor collectors and this is not one. |
| Microsoft Sentinel | `Microsoft.SecurityInsights/*` on `microsoft.operationalinsights/workspaces` | Security | Whether Sentinel is onboarded, and to which workspace. |
| Key Vault object expiry | `Microsoft.KeyVault/vaults/{keys,secrets,certificates}` | Security | Vaults are collected; expiring secrets/certs — the actual finding — are not. |
| Azure Migrate | `Microsoft.Migrate/*`, `Microsoft.OffAzure/*` | Migration | |
| AKS node pools | `Microsoft.ContainerService/managedClusters/agentPools` | Containers | Cluster-level only today; sizing/version per pool is missing. |
| IoT DPS | `Microsoft.Devices/provisioningServices` | IoT | IoT Hub without DPS is half the story. |

### P2 — should have

| Azure service | Resource type | Suggested category | Why it matters |
|---|---|---|---|
| Resource groups as first-class rows | `Microsoft.Resources/subscriptions/resourceGroups` | Management | Empty/untagged RG analysis. |
| DDoS protection plans | `Microsoft.Network/ddosProtectionPlans` | Networking | |
| Virtual Network Manager | `Microsoft.Network/networkManagers` | Networking | |
| Virtual WAN children | `Microsoft.Network/virtualHubs`, `/vpnGateways`, `/p2sVpnGateways`, `/expressRouteGateways`, `/vpnSites` | Networking | `virtualwans` is collected but the hubs/gateways under it are not — the WAN topology is unreadable. |
| Private Link services | `Microsoft.Network/privateLinkServices` | Networking | Endpoints collected, services not. |
| App Security Groups / Service Endpoint policies / IP Groups | `Microsoft.Network/applicationSecurityGroups`, `/serviceEndpointPolicies`, `/ipGroups` | Networking | NSG rules referencing ASGs are unresolvable today. |
| Local network gateways, Public IP prefixes, Route filters | `Microsoft.Network/localNetworkGateways`, `/publicIPPrefixes`, `/routeFilters` | Networking | |
| NSG flow logs / connection monitors | `Microsoft.Network/networkWatchers/flowLogs`, `/connectionMonitors` | Networking | Network Watcher collected; its actual configuration is not. |
| Compute Gallery / images / snapshots | `Microsoft.Compute/galleries`, `/images`, `/snapshots`, `/diskEncryptionSets` | Compute | Orphaned snapshot spend is a routine finding. |
| Dedicated hosts, PPGs, capacity reservations | `Microsoft.Compute/hostGroups`, `/proximityPlacementGroups`, `/capacityReservationGroups` | Compute | |
| Service Fabric | `Microsoft.ServiceFabric/clusters` | Compute | |
| Azure Spring Apps | `Microsoft.AppPlatform/spring` | Compute | Retiring 2028 — collect for migration planning. |
| Elastic SAN | `Microsoft.ElasticSan/elasticSans` | Storage | |
| HPC Cache / Managed Lustre | `Microsoft.StorageCache/caches`, `/amlFilesystems` | Storage | |
| Data Box / Stack Edge | `Microsoft.DataBox/jobs`, `Microsoft.DataBoxEdge/dataBoxEdgeDevices` | Migration | |
| Database Migration Service | `Microsoft.DataMigration/sqlMigrationServices` | Migration | |
| Site Recovery replication | `Microsoft.RecoveryServices/vaults/replicationProtectedItems`, `Microsoft.DataReplication/replicationVaults` | Backup & Recovery | DR posture is currently unreportable. |
| HDInsight | `Microsoft.HDInsight/clusters` | Analytics | |
| Analysis Services / Power BI Embedded | `Microsoft.AnalysisServices/servers`, `Microsoft.PowerBIDedicated/capacities` | Analytics | |
| Cosmos DB for PostgreSQL | `Microsoft.DBforPostgreSQL/serverGroupsv2` | Databases | |
| Cosmos DB Mongo vCore | `Microsoft.DocumentDB/mongoClusters` | Databases | |
| SQL failover groups | `Microsoft.Sql/servers/failoverGroups` | Databases | HA posture for Azure SQL. |
| SignalR / Web PubSub | `Microsoft.SignalRService/signalR`, `/webPubSub` | Web | |
| App Service certificates | `Microsoft.Web/certificates`, `Microsoft.CertificateRegistration/certificateOrders` | Web | Cert expiry. |
| API connections | `Microsoft.Web/connections`, `/customApis`, `/connectionGateways` | Integration | Logic Apps' companion resources. |
| Notification Hubs / Relay | `Microsoft.NotificationHubs/namespaces`, `Microsoft.Relay/namespaces` | Integration | |
| Communication Services | `Microsoft.Communication/communicationServices` | Integration | |
| Managed Grafana | `Microsoft.Dashboard/grafana` | Monitor | |
| Prometheus rule groups / alert processing rules | `Microsoft.AlertsManagement/prometheusRuleGroups`, `/actionRules` | Monitor | |
| Defender configuration | `Microsoft.Security/pricings`, `/securityContacts`, `/standards`, `/assignments`, `/automations` | Security | Partly reachable via the sweep envelope; not first-class. |
| Managed HSM | `Microsoft.KeyVault/managedHSMs` | Security | |
| Entra Domain Services | `Microsoft.AAD/domainServices` | Identity | |
| Entra ID B2C | `Microsoft.AzureActiveDirectory/b2cDirectories` | Identity | |
| Managed Applications | `Microsoft.Solutions/applications` | Management | |
| Managed DevOps Pools | `Microsoft.DevOpsInfrastructure/pools` | DevOps | |
| Dev Box / Dev Center | `Microsoft.DevCenter/devcenters`, `/projects` | Virtual Desktop or Compute | |
| Container Apps jobs | `Microsoft.App/jobs` | Containers | |
| AKS Fleet Manager | `Microsoft.ContainerService/fleets` | Containers | |
| Digital Twins | `Microsoft.DigitalTwins/digitalTwinsInstances` | IoT | |
| IoT Central | `Microsoft.IoTCentral/iotApps` | IoT | |
| Device Update for IoT Hub | `Microsoft.DeviceUpdate/accounts` | IoT | |
| Azure IoT Operations | `Microsoft.IoTOperations/instances` | IoT | Arc-adjacent; fits the Hybrid strength. |
| SAP on Azure | `Microsoft.Workloads/sapVirtualInstances` | Compute | Only if an SAP practice exists. |

### P3 — nice to have / low value

| Azure service | Resource type | Suggested category | Note |
|---|---|---|---|
| Classic resources | `Microsoft.ClassicStorage/storageAccounts`, `Microsoft.ClassicNetwork/*`, `Microsoft.ClassicCompute/virtualMachines` | respective | Scout has `classiccompute/domainnames` only. Rare, but a legitimate migration finding when present. |
| Dev/Test Labs, Lab Services | `Microsoft.DevTestLab/labs`, `Microsoft.LabServices/labs` | Compute | |
| Azure Maps, Bing Maps | `Microsoft.Maps/accounts`, `Microsoft.BingMaps/*` | Web | |
| Data Lake Store/Analytics Gen1 | `Microsoft.DataLakeStore/accounts`, `Microsoft.DataLakeAnalytics/accounts` | Analytics | Gen1 retired 2024-02. |
| Data Share, Data Catalog | `Microsoft.DataShare/accounts`, `Microsoft.DataCatalog/catalogs` | Analytics | Superseded by Purview. |
| Load Testing, Playwright | `Microsoft.LoadTestService/loadTests`, `Microsoft.AzurePlaywrightService/accounts` | DevOps | |
| Chaos Studio | `Microsoft.Chaos/experiments` | Management | |
| Attestation, Dedicated HSM | `Microsoft.Attestation/attestationProviders`, `Microsoft.HardwareSecurityModules/dedicatedHSMs` | Security | |
| Quantum | `Microsoft.Quantum/workspaces` | AI | |
| Private 5G Core, Orbital | `Microsoft.MobileNetwork/*`, `Microsoft.Orbital/*` | Networking | Fold into Networking; do not create a 5G category. |
| Time Series Insights | `Microsoft.TimeSeriesInsights/environments` | IoT | Retired 2025-07. |

### Explicitly recommended AGAINST building

The task brief asked about several of these by name. They are dead or dying and would be wasted effort:

| Service | Verdict | Evidence |
|---|---|---|
| **Media Services** | Do not build | [Retired 2024-06-30](https://learn.microsoft.com/en-us/previous-versions/azure/media-services/latest/azure-media-services-retirement); accounts auto-deleted ~90 days after. |
| **Blockchain** | Do not build | Azure Blockchain Service retired 2021-09. `Microsoft.Blockchain` still appears in the RP directory but provisions nothing. |
| **Mixed Reality** | Do not build | Spatial Anchors and Remote Rendering are retired/retiring; `Microsoft.MixedReality/*` types persist in ARG but are effectively dead. |
| **Front Door (classic)** | Keep, but flag | Scout's *only* Front Door coverage. Retires [2027-03-31](https://learn.microsoft.com/en-us/azure/frontdoor/classic-retirement-faq). Add `Microsoft.Cdn/profiles` alongside it and mark classic as a migration finding. |
| **Azure Cache for Redis (Enterprise tiers)** | Keep, but flag | Enterprise/Enterprise Flash [retire 2027-03-31](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/retirement-faq) in favour of Azure Managed Redis. Scout collects both `microsoft.cache/redis` and `redisenterprise` — add a retirement flag rather than a new collector. |

---

## Taxonomy recommendation: expand 15 → 20

Microsoft's own resource-provider directory organises Azure into **21 groups**: AI and ML, Analytics,
Blockchain, Compute, Container, Core, Database, Developer tools, DevOps, Hybrid, Identity,
Integration, IoT, Management, **Migration**, Monitoring, Network, Security, Storage, Web, 5G & Space.

Scout has 15 of them. The five it lacks that matter: **Migration**, **DevOps**, **Developer tools**,
Core, Blockchain. Core is an implementation detail and Blockchain is dead — so three genuine gaps
against Microsoft's own taxonomy, plus two splits that Scout's *existing* collectors already justify.

### Proposed 20 categories

Keep all 15. Add five:

| New category | Seeded from | New collectors | Rationale |
|---|---|---|---|
| **Backup & Recovery** | Move `Management/Backup`, `Management/RecoveryVault` | protected items, ASR replicated items, `DataProtection/backupVaults`, backup jobs | Backup/DR is a standalone consulting deliverable. It is currently two manifests buried in a 19-manifest Management bucket, and it cannot answer "what is unprotected". |
| **Migration** | *(none exist)* | `Microsoft.Migrate/*`, `Microsoft.OffAzure/*`, `Microsoft.DataMigration/*`, `Microsoft.DataBox*` | Microsoft has this as a top-level group. Scout has zero coverage. For an Azure Local / hybrid consultancy this is a core motion. |
| **Cost & Optimisation** | Move `Management/AdvisorScore`, `Management/ReservationRecom` | `Consumption/budgets`, Advisor cost recommendations, orphaned-resource sheets | FinOps is its own conversation and its own report section. Advisor score sitting under Management understates it. |
| **DevOps** | Move the 5 `Management/DevOps*` manifests | `Microsoft.DevOpsInfrastructure/pools`, `Microsoft.VisualStudio/account`, GitHub connectors | These five already exist and are already gated behind `-IncludeDevOps`. They are mis-filed, not missing. Promoting them costs a directory move. |
| **Virtual Desktop** | Move the 7 `Compute/AVD*` manifests | Dev Box, `Microsoft.DevCenter/*` | AVD is half of the Compute category by manifest count and is a distinct practice area. This also stops Compute's 14 from looking healthier than it is (it is really 7 compute + 7 AVD). |

### Categories deliberately NOT proposed

- **Developer tools** — App Configuration and Load Testing are the only two that matter; put App
  Configuration in Web and Load Testing in DevOps rather than create a two-manifest category.
- **Media / Mixed Reality / Blockchain / Quantum** — see the retirement table above.
- **5G & Space / SAP** — fold into Networking and Compute respectively unless a practice exists.
- **Communication** — one service; belongs in Integration.

### Reclassifications worth making at the same time

| Collector | Currently | Should be | Reason |
|---|---|---|---|
| `Analytics/EvtHub` | Analytics | Integration | Microsoft classifies `Microsoft.EventHub` under Integration, alongside Service Bus and Event Grid. Grouping Event Hubs with Service Bus makes the messaging story readable. |
| `Compute/VMDisk` | Compute | Storage (or dual-list) | Would take Storage from 2 → 3 and put disk sprawl next to storage-account sprawl. Judgement call; flagged, not asserted. |
| `Identity/ManagedIds` + `Identity/ManagedIdentities` | both Identity | verify | One is ARM (`Microsoft.ManagedIdentity/userAssignedIdentities`), one is Entra (`entra/managedidentities`). Possibly intentional, possibly overlapping output. |
| `Monitor/AppInsightsWebTests` + `Monitor/AppInsightsAvailabilityTests` | both Monitor | verify | Both target `microsoft.insights/webtests`; WebTests filters `kind -eq 'standard'`, AvailabilityTests has **no filter**, so it re-emits the same rows into a second worksheet. Likely a genuine duplicate — worth confirming against a live run. |

---

## Per-thin-category deep dive

### Storage — 2 collectors, 2 types

The worst gap in the tool relative to how much of a real estate storage represents.

**Collected:** `microsoft.storage/storageaccounts` (thorough — 38 columns incl. TLS, public access,
soft-delete, private endpoints, ACLs), `microsoft.netapp/.../capacityPools/volumes`.

**Missing:**

| Missing | Type | Priority |
|---|---|---|
| Blob containers (incl. public-access level) | `.../blobServices/containers` | P1 |
| File shares (incl. quota, tier) | `.../fileServices/shares` | P1 |
| Lifecycle management policies | `.../managementPolicies` | P1 |
| Azure File Sync | `Microsoft.StorageSync/storageSyncServices`, `/syncGroups` | P1 |
| Managed disks | `Microsoft.Compute/disks` — collected, but filed under Compute | P1 (reclassify) |
| Snapshots | `Microsoft.Compute/snapshots` | P2 |
| Disk encryption sets | `Microsoft.Compute/diskEncryptionSets` | P2 |
| Elastic SAN | `Microsoft.ElasticSan/elasticSans` | P2 |
| HPC Cache / Managed Lustre | `Microsoft.StorageCache/caches`, `/amlFilesystems` | P2 |
| NetApp accounts and capacity pools as their own rows | `Microsoft.NetApp/netAppAccounts`, `/capacityPools` | P2 (volumes only today — pool utilisation invisible) |
| Classic storage | `Microsoft.ClassicStorage/storageAccounts` | P3 |
| Import/Export, StorSimple | `Microsoft.ImportExport/*`, `Microsoft.StorSimple/*` | P3 |

Realistic target: **2 → 11 collectors.**

### Web — 2 collectors, 2 types

**Collected:** `microsoft.web/sites` (with an `App Type` column reading `$1.KIND`) and
`microsoft.web/serverfarms`.

Important nuance: **Function Apps and Logic Apps (Standard) ARE collected** — they are
`microsoft.web/sites` rows with `kind` of `functionapp*` / `workflowapp`, and they land in the
"App Services" worksheet with `App Type` set. But there is no Function-App-specific projection: no
runtime stack version, no plan tier (Consumption vs Premium vs Dedicated), no always-on. A consultant
reading the App Services sheet cannot tell a Consumption function from a Dedicated web app without
cross-referencing the plan sheet by hand.

**Missing:**

| Missing | Type | Priority |
|---|---|---|
| App Service Environments | `Microsoft.Web/hostingEnvironments` | P1 |
| Static Web Apps | `Microsoft.Web/staticSites` | P1 |
| Deployment slots | `Microsoft.Web/sites/slots` | P1 |
| App Configuration | `Microsoft.AppConfiguration/configurationStores` | P1 |
| A dedicated Function Apps projection | filter `microsoft.web/sites` on `kind` | P1 |
| Certificates + certificate orders | `Microsoft.Web/certificates`, `Microsoft.CertificateRegistration/certificateOrders` | P2 |
| SignalR / Web PubSub | `Microsoft.SignalRService/signalR`, `/webPubSub` | P2 |
| Custom domains | `Microsoft.DomainRegistration/domains` | P3 |
| Azure Maps | `Microsoft.Maps/accounts` | P3 |

Realistic target: **2 → 9 collectors.**

### Integration — 2 collectors, 2 types

**Collected:** APIM (`microsoft.apimanagement/service`), Service Bus (`microsoft.servicebus/namespaces`).

Both are namespace/service-level only — no APIM APIs, products, or subscriptions; no Service Bus
queues, topics, or subscriptions.

**Missing:**

| Missing | Type | Priority |
|---|---|---|
| Logic Apps (Consumption) | `Microsoft.Logic/workflows` — **query-excluded, not just manifest-missing** | P1 |
| Integration accounts | `Microsoft.Logic/integrationAccounts` | P1 |
| Event Grid topics / system topics / domains | `Microsoft.EventGrid/topics`, `/systemTopics`, `/domains` | P1 |
| Event Hubs (reclassify from Analytics) | `Microsoft.EventHub/namespaces` | P1 (move) |
| Service Bus queues / topics | `.../namespaces/queues`, `/topics` | P2 |
| APIM APIs / products | `.../service/apis`, `/products` | P2 |
| API connections | `Microsoft.Web/connections`, `/customApis`, `/connectionGateways` | P2 |
| Notification Hubs | `Microsoft.NotificationHubs/namespaces` | P2 |
| Relay | `Microsoft.Relay/namespaces` | P2 |
| Communication Services | `Microsoft.Communication/communicationServices` | P2 |
| Healthcare APIs / FHIR | `Microsoft.HealthcareApis/workspaces` | P3 |

Realistic target: **2 → 10 collectors** (11 with Event Hubs moved in).

### IoT — 1 collector, 1 type

**Collected:** `microsoft.devices/iothubs`.

**Missing:**

| Missing | Type | Priority |
|---|---|---|
| Device Provisioning Service | `Microsoft.Devices/provisioningServices` | P1 |
| Digital Twins | `Microsoft.DigitalTwins/digitalTwinsInstances` | P2 |
| IoT Central | `Microsoft.IoTCentral/iotApps` | P2 |
| Device Update for IoT Hub | `Microsoft.DeviceUpdate/accounts` | P2 |
| Azure IoT Operations | `Microsoft.IoTOperations/instances` | P2 — strong fit given Scout's Arc/Azure Local depth |
| Device Registry | `Microsoft.DeviceRegistry/assets`, `/assetEndpointProfiles` | P2 |
| Azure Sphere | `Microsoft.AzureSphere/catalogs` | P3 |
| Time Series Insights | `Microsoft.TimeSeriesInsights/environments` | P3 — retired 2025-07 |

Realistic target: **1 → 6 collectors.** Honest caveat: IoT is genuinely rare in most enterprise
tenants. This is the one thin category where thinness is partly defensible — but one collector for a
whole Microsoft top-level category is still indefensible, and IoT Operations in particular aligns with
where the rest of Scout is strong.

### Security — 5 collectors, 1 real ARM type

The most structurally misleading category. Four of the five collectors
(`DefenderAlerts`, `DefenderAssessments`, `DefenderPricing`, `DefenderSecureScore`) read from a single
synthetic envelope, `AZSC/Subscription/SecurityPolicySweep`. Only `Vault`
(`microsoft.keyvault/vaults`) is a real ARM resource type.

**Missing:**

| Missing | Type | Priority |
|---|---|---|
| WAF policies (all three flavours) | `Microsoft.Network/frontdoorWebApplicationFirewallPolicies`, `Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies`, `Microsoft.Cdn/cdnWebApplicationFirewallPolicies` | P1 |
| Key Vault keys / secrets / certificates + expiry | `.../vaults/{keys,secrets,certificates}` | P1 |
| Microsoft Sentinel onboarding | `Microsoft.SecurityInsights/*` | P1 |
| Defender plans as a first-class sheet | `Microsoft.Security/pricings` | P1 (currently only inside the sweep envelope) |
| Security contacts | `Microsoft.Security/securityContacts` | P2 |
| Regulatory compliance standards + assignments | `Microsoft.Security/standards`, `/assignments` | P2 |
| Security automations | `Microsoft.Security/automations` | P2 |
| Defender for Cloud connectors (AWS/GCP/DevOps) | `Microsoft.Security/securityConnectors`, `Microsoft.SecurityDevOps/*` | P2 |
| Managed HSM | `Microsoft.KeyVault/managedHSMs` | P2 |
| Attestation | `Microsoft.Attestation/attestationProviders` | P3 |
| Dedicated HSM | `Microsoft.HardwareSecurityModules/dedicatedHSMs` | P3 |

Plus the two governance items that belong in a security narrative but are only ingested for rules:
`Microsoft.Authorization/roleAssignments` and `Microsoft.Authorization/locks`.

Realistic target: **5 → 14 collectors.**

---

## Recommended work breakdown

Proposed child tasks under AB#6446. Sizing assumes the manifest-only path (finding 1) — most of these
are a manifest plus a fixture plus an equivalence test, with no engine change.

### Phase 0 — make the gap visible and stop the silent drop (do this first)

| # | Task | Why first |
|---|---|---|
| 0.1 | Add an **"Uncollected resource types"** sheet: group the raw ARG rows whose `type` has no manifest, output `type` / count / example resource ID. | Turns this report into a self-updating artefact. Every future run tells the owner exactly what is being discarded in *that customer's* tenant. Highest value-per-line-of-code in the whole list. |
| 0.2 | Remove `microsoft.logic/workflows` from the `!in` exclusion at `src/collect/Get-ScoutRawInventory.ps1:245`, and document why the other three remain. | The only true collection gap. Also: the comment says "these three types" while the clause lists four — fix the comment. |
| 0.3 | Fix `docs/coverage-table.md` (says Identity 18 / total 176; actual is 16 / 174) and add a CI test pinning the numbers to the manifest count. | Known drift class; a test stops it recurring. |
| 0.4 | Confirm whether `Monitor/AppInsightsWebTests` and `Monitor/AppInsightsAvailabilityTests` duplicate rows on a live run. | Cheap; may remove a collector rather than add one. |

### Phase 1 — the thin categories (highest embarrassment reduction per manifest)

| # | Task | Manifests |
|---|---|---|
| 1.1 | Storage build-out: containers, file shares, lifecycle policies, File Sync, snapshots, disk encryption sets, Elastic SAN, NetApp accounts + pools | ~9 |
| 1.2 | Web build-out: ASE, Static Web Apps, slots, Function Apps projection, App Configuration, certificates, SignalR/Web PubSub | ~7 |
| 1.3 | Integration build-out: Logic Apps (needs 0.2), integration accounts, Event Grid ×3, Service Bus queues/topics, API connections, Notification Hubs, Relay | ~9 |
| 1.4 | Security build-out: WAF policies ×3, Key Vault objects, Sentinel, Defender pricings/contacts/standards, Managed HSM | ~9 |
| 1.5 | IoT build-out: DPS, Digital Twins, IoT Central, Device Update, IoT Operations | ~5 |

### Phase 2 — governance data that is already ingested but never reported

| # | Task |
|---|---|
| 2.1 | Surface `Microsoft.Authorization/roleAssignments` as an Identity worksheet (from the existing `Import-Governance` ingest — no new query). |
| 2.2 | Surface `Microsoft.Authorization/locks` and `/policyAssignments` as Management worksheets. |
| 2.3 | Surface `Microsoft.Consumption/budgets` as a Cost worksheet. |

These are near-free: the data already lands in `collect.json`; only the rendering is missing.

### Phase 3 — new categories

| # | Task |
|---|---|
| 3.1 | Create **Backup & Recovery**: move Backup + RecoveryVault, add protected items, ASR replicated items, `DataProtection/backupVaults`. Add the "resources with no backup" cross-reference — the single most requested assessment output this unlocks. |
| 3.2 | Create **Migration**: `Microsoft.Migrate/*`, `Microsoft.OffAzure/*`, DMS, Data Box / Stack Edge. |
| 3.3 | Create **Cost & Optimisation**: move AdvisorScore + ReservationRecom, add budgets, Advisor cost recommendations, orphaned disks/NICs/public IPs. |
| 3.4 | Promote **DevOps**: move the 5 existing `Management/DevOps*` manifests; add Managed DevOps Pools. |
| 3.5 | Promote **Virtual Desktop**: move the 7 `Compute/AVD*` manifests; add Dev Box / Dev Center. |
| 3.6 | Move `Analytics/EvtHub` → Integration. |

Category moves change worksheet grouping and `-Category` filtering, so 3.4–3.6 need a compatibility
decision (alias the old category names, or accept the break in a major version).

### Phase 4 — remaining P1/P2 by category

| # | Task |
|---|---|
| 4.1 | Networking: `Microsoft.Cdn/profiles` + endpoints, firewall policies + rule collection groups, Virtual WAN children, DDoS plans, Virtual Network Manager, Private Link services, ASGs, flow logs. Flag Front Door classic as retiring 2027-03-31. |
| 4.2 | Analytics: Data Factory, Microsoft Fabric, HDInsight, Analysis Services, Power BI Embedded. |
| 4.3 | Compute: Batch, Compute Gallery/images/snapshots, dedicated hosts, PPGs, Service Fabric, Spring Apps. |
| 4.4 | Monitor: Azure Monitor Workspace, Managed Grafana, Prometheus rule groups, alert processing rules. |
| 4.5 | Containers: AKS node pools, Container Apps jobs, AKS Fleet Manager. |
| 4.6 | Databases: SQL failover groups, Cosmos DB for PostgreSQL, Mongo vCore. |
| 4.7 | Management: resource groups as rows, Managed Applications. |
| 4.8 | Identity: Entra Domain Services, Entra ID B2C. |

**Rough total: ~75 new manifests to go from 110 → ~185 ARM resource types, and 15 → 20 categories.**

---

## Uncertainties — stated rather than guessed

1. **Whether uncollected rows are truly discarded, or land somewhere I did not find.** I searched the
   report renderers for a catch-all sheet and found none, and the React template distinguishes "not
   collected" from "collected, zero found" — which implies a fixed known set. I did not confirm this
   against a live run. **Task 0.1 would settle it definitively.**
2. **The exact count of resource types Microsoft considers "current".** ARG's `resources` table lists
   1,100+ but includes preview, internal, AWS-connector, and child types. I used provider count (~130)
   as the more honest denominator and flagged the type-count ratio as unreliable.
3. **Whether the `AZSC/Subscription/SecurityPolicySweep` envelope already carries Defender data that a
   dedicated `Microsoft.Security/pricings` collector would duplicate.** I read the manifests but did
   not trace the envelope's construction. Verify before building 1.4's Defender items.
4. **`Compute/VMDisk` → Storage.** A defensible reclassification, not an obvious one. Flagged as a
   judgement call for the owner rather than asserted as a defect.
5. **Whether IoT deserves the investment at all.** The gap is real and indefensible on paper; the
   real-world frequency in this consultancy's tenants is not something I can measure from the repo.

---

## Sources

- [Find resource providers by Azure services](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers) — the authoritative provider→service→category mapping (updated 2026-02-27)
- [Azure Resource Graph table and resource type reference](https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources) — the definitive ARG type list
- [Azure Front Door (classic) retirement FAQ](https://learn.microsoft.com/en-us/azure/frontdoor/classic-retirement-faq)
- [Azure Cache for Redis retirement FAQ](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/retirement-faq)
- [Azure Media Services retirement guide](https://learn.microsoft.com/en-us/previous-versions/azure/media-services/latest/azure-media-services-retirement)
- [Microsoft.Fabric resource types](https://learn.microsoft.com/azure/templates/microsoft.fabric/allversions)
