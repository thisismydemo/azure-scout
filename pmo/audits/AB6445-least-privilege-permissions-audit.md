# AB#6445 — Least-privilege permissions audit

**Scope:** all 174 declarative collectors (`manifests/collectors/<Category>/*.psd1`), the collect layer (`src/collect/*.ps1`), the Microsoft Graph / Entra path, the Azure DevOps path, and the existing pre-flight (`src/Invoke-AZTIPermissionAudit.ps1`, `src/Test-AZTIPermissions.ps1`).

**Method:** collectors were catalogued by the resource types they consume; the collect layer was read in full to determine what actually produces each type and by which API. Permission claims are cited to Microsoft Learn. Where a requirement cannot be settled from documentation alone it is marked **VERIFY** rather than guessed.

**Status:** read-and-report only. No code was modified.

---

## 1. Executive summary

### 1.1 The structural finding

**The collectors do not call Azure.** All 174 manifests are pure transforms over an in-memory `$Resources` bag. Every Azure call is made by ~13 functions in `src/collect/`. A per-collector permission matrix is therefore a mapping of *collector → resource type consumed → the collect-layer function that produces it → that function's API call*. This is why the matrix below collapses 174 rows into 11 distinct access classes: it is not a simplification, it is the actual shape of the system.

### 1.2 Minimum role set

Azure's **Reader** role is defined as exactly `*/read` — one wildcard action covering every control-plane read of every resource provider ([Azure built-in roles: General](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/general)). That single fact determines most of this audit's conclusions.

| Capability | Minimum roles |
|---|---|
| **Inventory only** (default run, no `-IncludeCosts`, no `-Scope All`) | **Reader** at root management group — nothing else |
| **+ Defender, Policy compliance, Advisor, Monitor** | **Reader** — still nothing else |
| **+ Costs** (`-IncludeCosts`) | Reader **+ Cost Management Reader** (see §6.2 — may need Cost Management *Contributor*) |
| **+ VM/Arc patch assessment** (default-on today) | Reader **+ a custom role** granting two `assessPatches/action` verbs (§5) |
| **+ Entra ID** (`-Scope All`) | Reader **+ Entra directory role `Global Reader`** (not an Azure RBAC role) |
| **+ Azure DevOps** (`-IncludeDevOps`) | Reader **+ Azure DevOps org membership** (not Azure RBAC at all) |

### 1.3 Headline findings

| # | Finding | Severity |
|---|---|---|
| **F1** | **Security Reader is entirely redundant.** Every *read* it grants is already inside Reader's `*/read`, for every call Scout makes. The pre-flight nags for it on every subscription. *(Corrected — it is not a strict **subset**: it also carries five IoT Defender `/action` permissions outside `*/read`, none of which Scout calls. See `_verification-report.md` E4.)* | Over-ask |
| **F2** | **Monitoring Reader is entirely redundant** — and grants `Microsoft.Support/*` (ticket **creation**), a write Scout never needs. | Over-ask + over-privilege |
| **F3** | **`assessPatches` is not a read.** Scout POSTs `Microsoft.Compute/virtualMachines/assessPatches/action` for every VM and `Microsoft.HybridCompute/machines/assessPatches/action` for every Arc machine, by default. Reader does not grant it, the pre-flight never checks it, and it **triggers real work on the target machine**. A "read-only inventory tool" performs a mutating action. | **Under-check + read-only violation** |
| **F4** | **`AuditLog.Read.All` is requested but never used.** No collector consumes sign-in or audit log data. | Over-ask |
| **F5** | **The Graph token comes from Azure CLI, not Az PowerShell.** `Get-AZSCGraphToken` shells to `az account get-access-token`. Scout silently requires a second, separate login (`az login`) and inherits the Azure CLI first-party app's delegated permissions. This is undocumented and breaks service-principal / managed-identity runs. | **Under-check + architectural** |
| **F6** | **Four Graph permissions are needed but never checked**, so their denial is silent: `AdministrativeUnit.Read.All`, `Domain.Read.All`, `RoleManagement.Read.Directory` (checked only via a weaker proxy), `IdentityProvider.Read.All`. | **Under-check** |
| **F7** | **The readiness verdict is wrong by construction.** `Invoke-AZTIPermissionAudit.ps1:418` classifies only 4 of 9 Graph checks as critical, so denials of Risky Users / Conditional Access / Directory Roles / Audit Logs leave `$graphAccess = $true` and the run reports **"READY — Full ARM + Entra ID scan supported"** while collectors emit zero rows. This is the reported real-world case. | **Silent data loss** |
| **F8** | **Azure DevOps is checked by nothing.** Five collectors, zero pre-flight coverage. | Under-check |
| **F9** | **Two collectors can never return data.** `AppInsightsContinuousExport` and `AppInsightsWorkItems` consume `AZSC/ARMChild/*` types that `Get-ScoutArmChildResource` deliberately never produces (Azure retired the endpoints). Not a permission problem — but they will look like one. | Diagnostic noise |

---

## 2. Per-collector permission matrix

### 2.1 Access classes

| Class | Producer (`src/collect/`) | Azure API | Minimum permission | Granted by |
|---|---|---|---|---|
| **A** | `Get-ScoutRawInventory.ps1` | Resource Graph (`Search-AzGraph`) over `resources`, `resourcecontainers`, `advisorresources`, `securityresources`, `healthresources`, `desktopvirtualizationresources`, `recoveryservicesresources` | `*/read` on the queried scope | **Reader** |
| **B** | `Get-ScoutSubscriptionSecurityPolicySweep.ps1` | `Get-AzSecurityAlert`, `Get-AzSecurityAssessment`, `Get-AzSecurityPricing`, `Get-AzSecuritySecureScore`, `Get-AzSecuritySecureScoreControl`, `Get-AzDiagnosticSetting`, `Get-AzPolicyState` | `Microsoft.Security/*/read`, `Microsoft.Insights/diagnosticSettings/read`, `Microsoft.PolicyInsights/policyStates/queryResults/read` | **Reader** (all ⊂ `*/read`) — see **VERIFY-2** |
| **C** | `Get-ScoutArmChildResource.ps1` | `Invoke-AzRestMethod` GET on 12 child paths | provider-specific `.../read` | **Reader** |
| **D** | `Get-ScoutApiResources.ps1` | `Invoke-RestMethod` GET/POST on 7 ARM paths | `.../read` + `policyStates/latest/summarize` | **Reader** — see **VERIFY-2** |
| **E** | `Get-ScoutTenantWideResource.ps1` | `Get-AzRoleDefinition -Custom`, `Get-AzManagementGroup -Expand -Recurse` | `Microsoft.Authorization/roleDefinitions/read`, `Microsoft.Management/managementGroups/read` | **Reader** *at management-group scope* |
| **F** | `Get-ScoutOperationalCollectorEnrichment.ps1` (metrics/replication/storage half) | `microsoft.insights/metrics`, `Microsoft.RecoveryServices/...`, `Get-AzStorageBlobServiceProperty`, `Get-AzStorageFileServiceProperty` | `.../read` | **Reader** |
| **G** | `Get-ScoutOperationalCollectorEnrichment.ps1` (**patch half**) | POST `.../assessPatches` | `Microsoft.Compute/virtualMachines/assessPatches/action`, `Microsoft.HybridCompute/machines/assessPatches/action` | ❌ **NOT Reader** — custom role or VM Contributor |
| **H** | `Get-ScoutOperationalCollectorEnrichment.ps1` / `Get-ScoutCostInventory.ps1` (**cost half**) | POST `Microsoft.CostManagement/query`, `Invoke-AzCostManagementQuery` | `Microsoft.CostManagement/query/…` | ❌ **NOT Reader** — Cost Management Reader, see **VERIFY-1** |
| **I** | `Get-ScoutVmQuotas.ps1`, `Get-ScoutVmSkuDetails.ps1` | `Get-AzVMUsage`, `Get-AzComputeResourceSku` | `Microsoft.Compute/locations/usages/read`, `.../skus/read` | **Reader** |
| **J** | `Start-ScoutEntraExtraction.ps1` | Microsoft Graph `/v1.0/*` | per-endpoint Graph permission (§2.4) | **Entra `Global Reader`** |
| **K** | `Start-ScoutDevOpsExtraction.ps1` | `dev.azure.com` / `app.vssps.visualstudio.com` REST | Azure DevOps org permissions | **DevOps group membership** (not RBAC) |

### 2.2 Collectors by class — all 174

**Class A — plain Resource Graph, Reader only (124 collectors).**
Everything not listed in 2.3 below. Full list by category:

- **AI (19)** — AIFoundryHubs, AIFoundryProjects, AppliedAIServices, AzureAI, BotServices, ComputerVision, ContentModerator, ContentSafety, CustomVision, FaceAPI, FormRecognizer, HealthInsights, ImmersiveReader, MachineLearning, OpenAIAccounts, SearchServices, SpeechService, TextAnalytics, Translator
- **Analytics (6)** — DataExplorerCluster, Databricks, EvtHub, Purview, Streamanalytics, Synapse
- **Compute (11)** — AVD, AVDApplicationGroups, AVDScalingPlans, AVDSessionHosts, AVDWorkspaces, AvailabilitySets, CloudServices, VMDisk, VMWare, VirtualMachine\*, VirtualMachineScaleSet
- **Containers (6)** — AKS, ARO, ContainerApp, ContainerAppEnv, ContainerGroups, ContainerRegistries
- **Databases (13)** — CosmosDB, MariaDB, MySQL, MySQLflexible, POSTGRE, POSTGREFlexible, RedisCache, SQLDB, SQLMI, SQLMIDB, SQLPOOL, SQLSERVER, SQLVM
- **Hybrid (15)** — ARCServers\*, ArcDataControllers, ArcExtensions, ArcGateways, ArcKubernetes, ArcResourceBridge, ArcSQLManagedInstances, ArcSQLServers, ArcSites, Clusters, GalleryImages, LogicalNetworks, MarketplaceGalleryImages, StorageContainers, VirtualMachines
- **Integration (2)** — APIM, ServiceBUS · **IoT (1)** — IOTHubs
- **Management (7)** — AutomationAccounts, Backup, LighthouseDelegations, MaintenanceConfigurations, RecoveryVault, SupportTickets, AdvisorScore†
- **Monitor (20)** — ActionGroups, ActivityLogAlertRules, AppInsights, AppInsightsAvailabilityTests, AppInsightsWebTests, AutoscaleSettings, DataCollectionEndpoints, DataCollectionRules, LAWorkspaceSolutions, MetricAlertRules, MonitorMetricsIngestion, MonitorPrivateLinkScopes, MonitorWorkbooks, ResourceDiagnosticSettings, ScheduledQueryRules, SmartDetectorAlertRules, Workspaces, Outages‡
- **Networking (21)** — ApplicationGateways, AzureFirewall, BastionHosts, Connections, ExpressRoute, Frontdoor, LoadBalancer, NATGateway, NetworkInterface, NetworkSecurityGroup, NetworkWatchers, PrivateDNS, PrivateEndpoint, PublicDNS, PublicIP, RouteTables, TrafficManager, VirtualNetwork, VirtualNetworkGateways, VirtualWAN, vNETPeering
- **Security (1)** — Vault · **Storage (2)** — NetApp, StorageAccounts\* · **Web (2)** — APPServicePlan, APPServices
- **Compute (1)** — AVDAzureLocal (derives from ARG `microsoft.azurestackhci/*` via `ConvertTo-ScoutAvdAzureLocalSessionHost.ps1`)

\* also consumes a Class F/G enrichment envelope — see 2.3. † AdvisorScore is Class D. ‡ Outages consumes `AZSC/Monitor/Outage`, built from ARG `healthresources` rows.

### 2.3 Collectors requiring more than plain ARG

| Collector | Type consumed | Class | Producing API | Minimum permission | Reader enough? |
|---|---|---|---|---|---|
| Security/**DefenderAlerts** | `AZSC/Subscription/SecurityPolicySweep` | B | `Get-AzSecurityAlert` | `Microsoft.Security/alerts/read` | ✅ |
| Security/**DefenderAssessments** | ″ | B | `Get-AzSecurityAssessment` | `Microsoft.Security/assessments/read` | ✅ |
| Security/**DefenderPricing** | ″ | B | `Get-AzSecurityPricing` | `Microsoft.Security/pricings/read` | ✅ |
| Security/**DefenderSecureScore** | ″ | B | `Get-AzSecuritySecureScore(Control)` | `Microsoft.Security/secureScores*/read` | ✅ |
| Monitor/**SubscriptionDiagnosticSettings** | ″ | B | `Get-AzDiagnosticSetting` | `Microsoft.Insights/diagnosticSettings/read` | ✅ |
| Management/**PolicyComplianceStates** | ″ | B | `Get-AzPolicyState` | `Microsoft.PolicyInsights/policyStates/queryResults/read` | ✅ **VERIFY-2** |
| AI/**MLComputes** | `AZSC/ARMChild/MLComputes` | C | GET `{ws}/computes?api-version=2023-04-01` | `Microsoft.MachineLearningServices/workspaces/computes/read` | ✅ |
| AI/**MLDatasets** | `AZSC/ARMChild/MLDatasets` | C | GET `{ws}/data` + `/versions` | `.../workspaces/data/read` | ✅ |
| AI/**MLDatastores** | `AZSC/ARMChild/MLDatastores` | C | GET `{ws}/datastores` | `.../workspaces/datastores/read` | ✅ |
| AI/**MLEndpoints** | `AZSC/ARMChild/MLEndpoints` | C | GET `{ws}/onlineEndpoints`, `/batchEndpoints`, `/deployments` | `.../workspaces/*Endpoints/read` | ✅ |
| AI/**MLModels** | `AZSC/ARMChild/MLModels` | C | GET `{ws}/models` + `/versions` | `.../workspaces/models/read` | ✅ |
| AI/**MLPipelines** | `AZSC/ARMChild/MLPipelines` | C | GET `{ws}/jobs?$filter=jobType eq 'Pipeline'` | `.../workspaces/jobs/read` | ✅ |
| AI/**OpenAIDeployments** | `AZSC/ARMChild/OpenAIDeployments` | C | GET `{acct}/deployments?api-version=2023-05-01` | `Microsoft.CognitiveServices/accounts/deployments/read` | ✅ |
| AI/**SearchIndexes** | `AZSC/ARMChild/SearchIndexes` | C | GET `{svc}/indexes?api-version=2023-11-01` | `Microsoft.Search/searchServices/indexes/read` | ✅ |
| Compute/**AVDApplications** | `AZSC/ARMChild/AVDApplications` | C | GET `{appgroup}/applications` | `Microsoft.DesktopVirtualization/applicationGroups/applications/read` | ✅ |
| Monitor/**AppInsightsProactiveDetection** | `AZSC/ARMChild/…` | C | GET `{comp}/ProactiveDetectionConfigs` | `Microsoft.Insights/components/ProactiveDetectionConfigs/read` | ✅ |
| Monitor/**LAWorkspaceLinkedServices** | `AZSC/ARMChild/…` | C | GET `{ws}/linkedServices` | `Microsoft.OperationalInsights/workspaces/linkedServices/read` | ✅ |
| Monitor/**LAWorkspaceSavedSearches** | `AZSC/ARMChild/…` | C | GET `{ws}/savedSearches` | `Microsoft.OperationalInsights/workspaces/savedSearches/read` | ✅ |
| Monitor/**AppInsightsContinuousExport** | `AZSC/ARMChild/AppInsightsContinuousExport` | — | **no producer** | n/a | **always empty (F9)** |
| Monitor/**AppInsightsWorkItems** | `AZSC/ARMChild/AppInsightsWorkItems` | — | **no producer** | n/a | **always empty (F9)** |
| Management/**AdvisorScore** | `Microsoft.Advisor/advisorScore` | D | GET `/providers/Microsoft.Advisor/advisorScore?api-version=2023-01-01` | `Microsoft.Advisor/advisorScore/read` | ✅ |
| Management/**ReservationRecom** | `Microsoft.Consumption/reservationRecommendations` | D | GET `/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01` | `Microsoft.Consumption/reservationRecommendations/read` | ✅ |
| Identity/**ManagedIds** | `Microsoft.ManagedIdentity/userAssignedIdentities` | D | GET `/providers/Microsoft.ManagedIdentity/userAssignedIdentities?api-version=2023-01-31` | `Microsoft.ManagedIdentity/userAssignedIdentities/read` | ✅ |
| Management/**PolicyDefinitions** | `AZSC/Management/PolicyDefinition` | D→E | GET `Microsoft.Authorization/policyDefinitions?api-version=2023-04-01` | `Microsoft.Authorization/policyDefinitions/read` | ✅ |
| Management/**PolicySetDefinitions** | `AZSC/Management/PolicySetDefinition` | D→E | GET `Microsoft.Authorization/policySetDefinitions` | `Microsoft.Authorization/policySetDefinitions/read` | ✅ |
| Management/**CustomRoleDefinitions** | `AZSC/Management/RoleDefinition` | E | `Get-AzRoleDefinition -Custom` | `Microsoft.Authorization/roleDefinitions/read` | ✅ |
| Management/**ManagementGroups** | `AZSC/Management/ManagementGroup` | E | `Get-AzManagementGroup -Expand -Recurse` | `Microsoft.Management/managementGroups/read` | ✅ **but requires assignment at MG scope, not subscription** |
| Management/**AllSubscriptions** | `AZSC/Management/SubscriptionEnrichment` | E/F | `Search-AzGraph` on `resourcecontainers` mgChain | `*/read` | ✅ |
| Storage/**StorageAccounts** | + `AZSC/Operational/StorageAccount` | F | `Get-AzStorageBlobServiceProperty`, `Get-AzStorageFileServiceProperty` | `Microsoft.Storage/storageAccounts/blobServices/read`, `/fileServices/read` | ✅ |
| Compute/**VirtualMachine** | + `AZSC/Operational/VirtualMachine`, `AZSC/VM/SKU`, `AZSC/VM/Quotas` | F/H/I | metrics, `replicationEligibilityResults`, RSV, `Get-AzVMUsage`, `Get-AzComputeResourceSku`, **POST CostManagement/query** | reads ✅ / **cost ❌** | partial |
| Compute/**VMOperationalData** | + `AZSC/Operational/VMOperationalData` | **G** | **POST `{vm}/assessPatches?api-version=2023-03-01`** | `Microsoft.Compute/virtualMachines/assessPatches/action` | ❌ **F3** |
| Hybrid/**ArcServerOperationalData** | + `AZSC/Operational/ArcServerOperationalData` | **G** | **POST `{arc}/assessPatches?api-version=2023-06-20-preview`** | `Microsoft.HybridCompute/machines/assessPatches/action` | ❌ **F3** |
| Hybrid/**ARCServers** | + `AZSC/Operational/ARCServers` | G/H | POST `policyStates/latest/queryResults`, **POST CostManagement/query** | **VERIFY-2** / **cost ❌** | partial |

### 2.4 Entra ID collectors (Class J) — 15 collectors, 17 Graph queries

All produced by `Start-ScoutEntraExtraction.ps1`, all on `/v1.0` (no `/beta`). Each query is individually wrapped in try/catch that prints `[SKIP]` and continues — **a denied permission produces an empty worksheet, never an error**.

| Collector | Graph endpoint | Least-privilege permission | Pre-flight checks it? |
|---|---|---|---|
| **Users** | `/v1.0/users` | `User.Read.All` | ✅ |
| **Groups** | `/v1.0/groups` | `Group.Read.All` | ✅ |
| **AppRegistrations** | `/v1.0/applications` | `Application.Read.All` | ✅ |
| **ServicePrincipals** | `/v1.0/servicePrincipals` | `Application.Read.All` | ✅ |
| **ManagedIdentities** | `/v1.0/servicePrincipals?$filter=servicePrincipalType eq 'ManagedIdentity'` | `Application.Read.All` | ✅ (via SP check) |
| **DirectoryRoles** | `/v1.0/directoryRoles` | `RoleManagement.Read.Directory` | ⚠️ proxy only |
| **PIMAssignments** | `/v1.0/roleManagement/directory/roleAssignments` | `RoleManagement.Read.Directory` | ❌ **F6** |
| **ConditionalAccess** | `/v1.0/identity/conditionalAccess/policies` | `Policy.Read.All` | ✅ |
| **NamedLocations** | `/v1.0/identity/conditionalAccess/namedLocations` | `Policy.Read.All` | ✅ (same perm) |
| **SecurityPolicies** | `/v1.0/policies/authorizationPolicy` | `Policy.Read.All` | ✅ (same perm) |
| **CrossTenantAccess** | `/v1.0/policies/crossTenantAccessPolicy/partners` | `Policy.Read.All` ([docs](https://learn.microsoft.com/graph/api/crosstenantaccesspolicy-list-partners?view=graph-rest-1.0)) | ✅ (same perm) |
| **AdminUnits** | `/v1.0/directory/administrativeUnits` | `AdministrativeUnit.Read.All` ([docs](https://learn.microsoft.com/graph/api/directory-list-administrativeunits?view=graph-rest-1.0)) | ❌ **F6** |
| **Domains** | `/v1.0/domains` | `Domain.Read.All` | ❌ **F6** |
| **Licensing** | `/v1.0/subscribedSkus` | `Organization.Read.All` | ✅ (via `/organization`) |
| **RiskyUsers** | `/v1.0/identityProtection/riskyUsers` | `IdentityRiskyUser.Read.All` ([docs](https://learn.microsoft.com/graph/api/riskyuser-list?view=graph-rest-1.0)) — also needs **Entra ID P2** | ⚠️ checked but non-critical (**F7**) |
| *(no collector)* | `/v1.0/identity/identityProviders` | `IdentityProvider.Read.All` ([docs](https://learn.microsoft.com/graph/api/identitycontainer-list-identityproviders?view=graph-rest-1.0)) | ❌ — and **nothing consumes it** |
| *(no collector)* | `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy` | `Policy.Read.All` | — and **nothing consumes it** |
| *(not called)* | `/v1.0/auditLogs/signIns` | `AuditLog.Read.All` | ✅ checked — **but never called by any collector (F4)** |

**Delegated-vs-application note.** Because the token comes from Azure CLI (F5), a *user* identity gets a **delegated** token whose effective rights are governed by the user's Entra directory role, not by consented app roles. The single directory role that covers every endpoint above is **Global Reader**. For a service principal, `az account get-access-token` yields an app-only token requiring the application permissions listed, each with admin consent.

### 2.5 Azure DevOps collectors (Class K) — 5 collectors

Auth: `Get-AzAccessToken -ResourceUrl '499b84ac-1321-427f-aa17-267ca6975798'` (`Start-ScoutDevOpsExtraction.ps1:83`) — the Azure DevOps first-party app — or a PAT via `-DevOpsPat`.

| Collector | Endpoint | Required access |
|---|---|---|
| **DevOpsProjects** | `https://dev.azure.com/{org}/_apis/projects` | Project-level **View project-level information** |
| **DevOpsPipelines** | `.../{project}/_apis/pipelines` | **View build pipeline** |
| **DevOpsServiceConnections** | `.../{project}/_apis/serviceendpoint/endpoints` | **Reader** on service connections |
| **DevOpsRepositories** | `.../{project}/_apis/git/repositories` | **Read** on Git repositories |
| **DevOpsAgentPools** | `.../_apis/distributedtask/pools` | Org-level **Reader** on agent pools |

Org discovery uses `app.vssps.visualstudio.com/_apis/profile/profiles/me` then `/_apis/accounts?memberId=`. **These permissions are Azure DevOps security-group permissions, entirely separate from Azure RBAC and from Entra directory roles.** The pre-flight validates none of it (**F8**).

---

## 3. Minimum viable role sets

### 3.1 Inventory-only (recommended default)

```
Reader   @  /providers/Microsoft.Management/managementGroups/<tenant-root>
```

**One role, one assignment.** Covers classes A, B, C, D, E, F, I — that is 172 of 174 collectors including all Defender data, all policy data, Advisor, Monitor, management groups and custom roles. Root-MG scope (rather than per-subscription) is what makes `ManagementGroups` and `AllSubscriptions` return a real hierarchy.

Run as: `Invoke-AzureScout -TenantID <id> -Scope ArmOnly`

### 3.2 Full-capability

```
Reader                  @ root management group
Cost Management Reader  @ each subscription (or the MG)   # VERIFY-1
<custom role, §5>       @ root management group           # assessPatches only
Global Reader           (Entra directory role)
Azure DevOps org reader (DevOps security groups)
```

### 3.3 Assessment-only (CAF/WAF, no VM operational data)

Same as 3.1. The CAF/WAF assessment path consumes policy, Defender and ARG data — all inside `*/read`.

### 3.4 What each elevated grant buys — and who forces it

| Elevated grant | Collectors that force it | Count | Make optional? |
|---|---|---|---|
| `assessPatches/action` (custom role / VM Contributor) | `VMOperationalData`, `ArcServerOperationalData` | **2** | **Yes — highest-value change.** Two collectors currently force a mutating permission across the whole estate. |
| Cost Management | `VirtualMachine` (EstimatedCost field), `ARCServers` (EstimatedCost field), plus the cost report sheets | **2 fields + reports** | Already opt-in via `-IncludeCosts` for `Get-ScoutCostInventory`, but the **per-VM cost POST in the enrichment path is not gated** — see §6.3 |
| Global Reader (Entra) | the 15 Identity collectors | 15 | Already opt-in via `-Scope` |
| `IdentityRiskyUser.Read.All` + Entra ID P2 | `RiskyUsers` | **1** | Yes — one collector forces a P2 licence dependency |
| `AdministrativeUnit.Read.All` | `AdminUnits` | **1** | — |
| `Domain.Read.All` | `Domains` | **1** | — |
| `RoleManagement.Read.Directory` | `DirectoryRoles`, `PIMAssignments` | 2 | — |
| DevOps org access | the 5 DevOps collectors | 5 | Already opt-in via `-IncludeDevOps` |

**The single most useful action from this audit:** gate `assessPatches` behind an explicit opt-in switch. Two collectors out of 174 are the sole reason Scout cannot run with pure Reader.

---

## 4. Is Security Reader / Monitoring Reader ever needed? No.

| Role | Actions | Anything Scout uses that Reader lacks? |
|---|---|---|
| **Reader** | `*/read` | — |
| **Security Reader** | `Microsoft.Authorization/*/read`, `Microsoft.Insights/alertRules/read`, `Microsoft.operationalInsights/workspaces/*/read`, `Microsoft.Resources/deployments/*/read`, `Microsoft.Resources/subscriptions/resourceGroups/read`, `Microsoft.Security/*/read`, `Microsoft.IoTSecurity/*/read`, `Microsoft.Support/*/read`, `Microsoft.Management/managementGroups/read`, + 5 IoT Defender **download** actions | **No.** Every read is ⊂ `*/read`. The only non-read actions are IoT Defender package downloads, which Scout never calls. |
| **Monitoring Reader** | `*/read`, `Microsoft.OperationalInsights/workspaces/search/action`, `Microsoft.Support/*` | **No.** Scout runs no Log Analytics search. `Microsoft.Support/*` is a **write** grant (create/update support tickets) — Scout only *reads* `Microsoft.Support/supportTickets`. |
| **Cost Management Reader** | `Microsoft.Consumption/*/read`, `Microsoft.CostManagement/*/read`, `Microsoft.Billing/billingPeriods/read`, `Microsoft.Billing/billingProperty/read`, `Microsoft.Resources/subscriptions*/read`, `Microsoft.Advisor/{configurations,recommendations}/read`, `Microsoft.Management/managementGroups/read`, **`Microsoft.Support/*`** | **Only for the Cost Management query POST** — and see VERIFY-1. It too carries the `Microsoft.Support/*` write grant. |

Sources: [built-in roles — General](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/general), [Security](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/security#security-reader), [Monitor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/monitor#monitoring-reader), [Management and governance](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/management-and-governance#cost-management-reader).

**Conclusion:** recommending Security Reader and Monitoring Reader alongside Reader grants Scout *less* than Reader already does, plus a support-ticket write it should never hold. Both should be dropped from the pre-flight's required set.

---

## 5. Proposed custom role

A custom role is **warranted, but not to replace Reader** — Reader is already minimal at `*/read` and no custom role can beat one wildcard for 172 collectors. The custom role's job is to add the two-to-three non-read verbs Scout needs, so operators can grant them *without* handing out Virtual Machine Contributor (which grants `Microsoft.Compute/virtualMachines/*` — start, stop, delete).

```json
{
  "Name": "Azure Scout Operational Reader",
  "IsCustom": true,
  "Description": "Adds the small set of non-read operations Azure Scout requires beyond the built-in Reader role: on-demand patch assessment for Azure VMs and Arc-enabled servers, and Cost Management queries. Grant together with Reader. Contains no write, delete, or state-changing operation on any resource.",
  "Actions": [
    "Microsoft.Compute/virtualMachines/assessPatches/action",
    "Microsoft.Compute/locations/operations/read",
    "Microsoft.HybridCompute/machines/assessPatches/action",
    "Microsoft.HybridCompute/locations/updateCenterOperationResults/read",
    "Microsoft.CostManagement/query/action",
    "Microsoft.CostManagement/query/read",
    "Microsoft.PolicyInsights/policyStates/queryResults/action",
    "Microsoft.PolicyInsights/policyStates/summarize/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/providers/Microsoft.Management/managementGroups/<TENANT-ROOT-MG-ID>"
  ]
}
```

Action sources: [Azure permissions for Compute](https://learn.microsoft.com/azure/role-based-access-control/permissions/compute#microsoftcompute), [Roles and permissions in Azure Update Manager](https://learn.microsoft.com/azure/update-manager/roles-permissions#permissions), [Azure permissions for Management and governance](https://learn.microsoft.com/azure/role-based-access-control/permissions/management-and-governance#microsoftcostmanagement).

The two `.../operations/read` and `.../updateCenterOperationResults/read` entries are already inside Reader's `*/read`; they are listed so the role also works standalone for the Update Manager async-result polling documented by Microsoft.

**Caveat:** the `policyStates` and `CostManagement/query` `/action` entries are belt-and-braces for VERIFY-1/VERIFY-2. If live testing shows the `/read` variants authorize the POSTs, drop the three `/action` lines and the custom role reduces to the two `assessPatches` verbs — which is the ideal end state.

---

## 6. Audit of the existing pre-flight

Files: `src/Invoke-AZTIPermissionAudit.ps1` (653 lines, does the work), `src/Test-AZTIPermissions.ps1` (116 lines, thin adapter).

### 6.1 Over-asks — remove these

| Line(s) | Issue |
|---|---|
| `Invoke-AZTIPermissionAudit.ps1:196–201` | `$requiredRoles` lists **Security Reader**, **Monitoring Reader**, **Cost Management Reader** as things to warn about. Security Reader and Monitoring Reader add nothing over Reader (§4). |
| `:249–251` | Unconditionally appends a *"Add Security Reader … for Defender data"* recommendation for **every** subscription lacking it — including subscriptions where Reader already grants every Defender read. This is the noisiest false positive in the tool. |
| `:406` | Checks `AuditLog.Read.All` via `/v1.0/auditLogs/signIns`. **No collector consumes audit or sign-in logs** (F4). Remove the check, or add the collector that justifies it. |
| `:398` | Checks `/v1.0/organization` for `Organization.Read.All`. Legitimate — but note it is validating `subscribedSkus` (Licensing) by proxy, which is worth stating in the message. |
| `:212–235` | Role detection uses `Get-AzRoleAssignment` and matches on `RoleDefinitionName`. This **misses inherited assignments expressed at management-group scope** in some cases, and misses **custom roles that grant the same actions**. An identity with a perfectly adequate custom role is reported as failing. Prefer an *effective-permission* probe (attempt the call) over a *role-name* probe. |

### 6.2 Under-checks — the dangerous half

| Missing check | Consequence |
|---|---|
| **`assessPatches/action` on VMs and Arc machines** | `VMOperationalData` and `ArcServerOperationalData` silently emit empty patch data. `Get-ScoutOperationalCollectorEnrichment.ps1:170,178` swallows the 403 into `@{ __AZSCError = … }` behind a `Write-Warning`. Pre-flight says READY. |
| **`Microsoft.CostManagement/query`** | Not probed at all. `Get-ScoutCostInventory.ps1:99–124` catches everything and sets `$costs = @()`. Cost sheets come out empty with a warning buried in the transcript. |
| **Azure DevOps access** (F8) | Five collectors, no check whatsoever. |
| **`az login` / Azure CLI presence** (F5) | `Get-AZSCGraphToken` shells out to `az`. If Azure CLI is absent or logged out, *all Entra collection fails* even though `Connect-AzAccount` succeeded. The pre-flight surfaces this only as a generic "Cannot acquire Microsoft Graph token". |
| **`AdministrativeUnit.Read.All`, `Domain.Read.All`, `IdentityProvider.Read.All`** (F6) | `AdminUnits` and `Domains` collectors silently empty. |
| **`RoleManagement.Read.Directory` against the endpoint that needs it** | `:403` probes `/v1.0/directoryRoles`, which is also satisfied by `Directory.Read.All`. `PIMAssignments` calls `/v1.0/roleManagement/directory/roleAssignments`, which genuinely requires `RoleManagement.Read.Directory`. A tenant can pass the check and still lose PIM data. |
| **Management-group *scope* of the Reader assignment** | `:176–187` probes root-MG *role-assignment readability* and only warns. But `ManagementGroups` needs `Get-AzManagementGroup -Expand -Recurse` to succeed — a different thing. Per Scout's own memory record, ManagementGroups needs **Management Group Reader** (or Reader at MG scope) to return rows; a subscription-scoped Reader silently returns none. |
| **Entra ID P2 licence** | `RiskyUsers` requires P2 regardless of permission ([docs](https://learn.microsoft.com/graph/api/riskyusers-list?view=graph-rest-beta)). A P1 tenant with the permission granted still gets nothing. |

### 6.3 The silent-data-loss case (F7) — root cause

```powershell
# src/Invoke-AZTIPermissionAudit.ps1:418-419
$isCritical = $checkName -in 'Graph: Organization Read', 'Graph: Users Read',
                             'Graph: Groups Read', 'Graph: Applications Read'
$status = if ($isCritical) { 'Fail'; $graphAccess = $false } else { 'Warn' }
```

Only 4 of 9 Graph checks can clear `$graphAccess`. `IdentityRiskyUser.Read.All` and `AuditLog.Read.All` are both non-critical, so both denials leave `$graphAccess = $true`, which at `:443` selects `FullARMAndEntra`, which at `:458` prints:

> **READY — Full ARM + Entra ID scan supported**

**Data actually lost in the reported run:**

| Denied permission | Data lost | Real impact |
|---|---|---|
| `IdentityRiskyUser.Read.All` | `/v1.0/identityProtection/riskyUsers` → `entra/riskyusers` → **Identity/RiskyUsers collector produces zero rows** | The Risky Users worksheet is present and **empty**, indistinguishable from "this tenant has no risky users" — the worst possible failure mode for a security report. |
| `AuditLog.Read.All` | **Nothing.** No collector consumes `auditLogs/*`. | None. The check is pure over-ask (F4). |

So the honest answer to "what was silently lost": **exactly one collector, RiskyUsers**, and the alarming part is not the volume but that a security-relevant sheet rendered empty under a green READY banner.

The same defect applies to `Policy.Read.All` (would empty **ConditionalAccess, NamedLocations, SecurityPolicies, CrossTenantAccess** — 4 collectors) and `RoleManagement.Read.Directory` (**DirectoryRoles, PIMAssignments** — 2 collectors). Those are larger silent losses hiding behind the same `Warn`.

### 6.4 Recommended pre-flight redesign

1. **Report per-collector impact, not per-permission status.** Replace `READY / PARTIAL` with a table: *"N of 174 collectors will produce data; the following M will be empty because …"*. This is the only output that cannot lie.
2. **Probe effective permissions, not role names** — attempt a representative call per access class (§2.1) and report the actual result. This automatically handles custom roles, inherited assignments and MG-scope subtleties.
3. **Any denied check that maps to at least one collector must degrade the verdict.** Delete the `$isCritical` allow-list; derive criticality from whether a collector consumes the resulting type.
4. **Drop Security Reader and Monitoring Reader** from the required set entirely.
5. **Add** probes for: `assessPatches` (both providers), `CostManagement/query`, DevOps org access, Azure CLI login state, and the four unchecked Graph permissions.

---

## 7. Documentation recommendation

Publish a single page, `docs/reference/permissions.md`, containing:

1. **The one-liner** — "Scout needs `Reader` at your root management group. Everything else is opt-in."
2. **A copy-paste grant block** for the default case:
   ```powershell
   New-AzRoleAssignment -ObjectId <principalId> -RoleDefinitionName 'Reader' `
     -Scope '/providers/Microsoft.Management/managementGroups/<tenantRootId>'
   ```
3. **An opt-in table** — one row per switch (`-IncludeCosts`, `-Scope All`, `-IncludeDevOps`, patch assessment once gated), each stating the extra grant, who must approve it, and **what worksheets go empty without it**. The empty-worksheet column is what operators actually need.
4. **The custom role JSON** from §5, with `New-AzRoleDefinition` instructions.
5. **The Entra section stated in the two identity models** — "if you run as a user: ask for the **Global Reader** directory role; if you run as a service principal: ask for these 7 application permissions with admin consent" — plus the explicit note that **`az login` is required in addition to `Connect-AzAccount`** (F5).
6. **A 'why we do NOT ask for Security Reader' note.** Operators who have granted it historically will ask.
7. **The P2 caveat** on Risky Users.

---

## 8. Recommended work breakdown — proposed child tasks under AB#6445

> Work-item IDs are deliberately not written here; they are unpredictable and must be created on the board first.

| # | Proposed task | Type | Priority | Why |
|---|---|---|---|---|
| 1 | **Gate `assessPatches` behind an explicit opt-in switch** (e.g. `-IncludePatchAssessment`), default off | Bug/Feature | **P1** | Scout is documented as read-only but performs a mutating action on every VM and Arc machine by default. This is the only thing preventing a pure-Reader run. |
| 2 | **Fix the readiness verdict** — delete the `$isCritical` allow-list at `Invoke-AZTIPermissionAudit.ps1:418`; derive criticality from collector consumption | Bug | **P1** | F7 — green banner over empty security data. |
| 3 | **Add the missing pre-flight probes**: `assessPatches`, `CostManagement/query`, DevOps, Azure CLI login, `AdministrativeUnit.Read.All`, `Domain.Read.All`, `RoleManagement.Read.Directory` (correct endpoint) | Bug | **P1** | F5, F6, F8 — every one is a silent-empty-data path. |
| 4 | **Remove Security Reader and Monitoring Reader from the required role set**, and drop the unconditional Security Reader recommendation | Chore | **P2** | F1, F2 — removes the tool's loudest false positive and stops asking for a support-ticket write grant. |
| 5 | **Remove the `AuditLog.Read.All` check** (or add the collector that justifies it) | Chore | P2 | F4. |
| 6 | **Live-verify VERIFY-1 and VERIFY-2** (below) with a Reader-only principal | Spike | **P2** | Determines whether the custom role needs 2 actions or 5. |
| 7 | **Rewrite the pre-flight output as a per-collector impact table** | Feature | P2 | §6.4.1 — the only output that cannot mislead. |
| 8 | **Publish `docs/reference/permissions.md`** per §7, and ship the custom role JSON in the repo | Docs | P2 | Owner's stated goal: let users request the right access up front. |
| 9 | **Make `RiskyUsers` degrade explicitly** — emit a "requires Entra ID P2 + IdentityRiskyUser.Read.All" marker row rather than an empty sheet | Bug | P3 | Empty ≠ none. |
| 10 | **Remove the two dead Entra queries** (`identityProviders`, `identitySecurityDefaultsEnforcementPolicy`) or add their collectors | Chore | P3 | Two Graph round-trips per run whose output nothing reads. |
| 11 | **Resolve the two permanently-empty collectors** `AppInsightsContinuousExport` / `AppInsightsWorkItems` — retire them or mark them as retired in the report | Chore | P3 | F9 — they look like a permission failure and are not. |
| 12 | **Gate the per-VM Cost Management POST** in `Get-ScoutOperationalCollectorEnrichment.ps1:162,191` behind `-IncludeCosts` | Bug | P3 | The dedicated cost function is opt-in; this one is not, so a run without `-IncludeCosts` still issues one cost POST per VM and per Arc machine. |

---

## 9. Items requiring live verification

These could not be settled from documentation and **must not be assumed**:

- **VERIFY-1 — Cost Management query authorization.** Microsoft registers both `Microsoft.CostManagement/query/action` and `Microsoft.CostManagement/query/read`. Cost Management Reader holds only `Microsoft.CostManagement/*/read`; Reader holds `*/read`. If the POST authorizes on `/read`, **plain Reader is sufficient for costs and Cost Management Reader is a third redundant role**. If it authorizes on `/action`, then *neither* Reader *nor* Cost Management Reader is sufficient and only Cost Management **Contributor** works. Test: `Invoke-AzCostManagementQuery` as a Reader-only principal, then as Cost Management Reader.
- **VERIFY-2 — Policy Insights query authorization.** Same ambiguity: `policyStates/queryResults/{action,read}` and `policyStates/summarize/{action,read}` both exist. Affects `Get-AzPolicyState` (PolicyComplianceStates), the ARC policy-compliance POST, and the `policyStates/latest/summarize` POST in `Get-ScoutApiResources.ps1:151`. Test: run those three calls as a Reader-only principal.
- **VERIFY-3 — Management group data under subscription-scoped Reader.** Repo memory records that `ManagementGroups` returned no rows until Management Group Reader was granted, and that both parameter binding *and* permissions were involved. Confirm whether Reader at root MG alone is sufficient, or whether Management Group Reader is genuinely additional.
- **VERIFY-4 — ARG behaviour under partial access.** `Search-AzGraph` returns only resources the caller can read, without error. Confirm whether a partially-scoped Reader produces a detectable signal, or whether reduced inventory is indistinguishable from a smaller estate. This determines whether §6.4.1's per-collector table can be trusted for Class A.
