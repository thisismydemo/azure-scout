---
description: Complete catalog of AzureScout Azure Resource Manager inventory modules across 15 categories.
---

# ARM Inventory Modules

## Overview

AzureScout includes **154 ARM inventory modules** organized into **15 categories**
(the `Identity` category folder also holds AzureScout's 17 Entra ID modules — those
are cataloged separately on the [Entra ID Modules](entra-modules.md) page, since they
query Microsoft Graph rather than ARM).
Each module extracts data for a specific Azure resource type using the Azure Resource Manager APIs.

Run ARM-only extraction with:

```powershell
Invoke-AzureScout -Scope ArmOnly
```

`ArmOnly` is the **default** `-Scope` value for `Invoke-AzureScout` — running the
cmdlet with no `-Scope` flag already does this.

::: tip Source of truth
Counts on this page are generated from the module files under
`Modules/Public/InventoryModules/` and the `-Category` `[ValidateSet]` in
`Invoke-AzureScout.ps1`. See the [Coverage Table](coverage-table.md) for a per-category
summary that includes the Entra split, and [Category Structure](category-structure.md)
for the full `-Category` alias mapping.
:::

## Module Catalog

### AI (27 modules)

Cognitive Services, Azure OpenAI, Machine Learning, AI Foundry, Bot Services, and AI Search.

| Module | Resource Type |
|--------|---------------|
| AIFoundryHubs | `Microsoft.MachineLearningServices/workspaces` (kind=Hub) |
| AIFoundryProjects | `Microsoft.MachineLearningServices/workspaces` (kind=Project) |
| AppliedAIServices | `Microsoft.CognitiveServices/accounts` (Applied AI) |
| AzureAI | `Microsoft.CognitiveServices/accounts` |
| BotServices | `Microsoft.BotService/botServices` |
| ComputerVision | `Microsoft.CognitiveServices/accounts` (ComputerVision) |
| ContentModerator | `Microsoft.CognitiveServices/accounts` (ContentModerator) |
| ContentSafety | `Microsoft.CognitiveServices/accounts` (ContentSafety) |
| CustomVision | `Microsoft.CognitiveServices/accounts` (CustomVision) |
| FaceAPI | `Microsoft.CognitiveServices/accounts` (Face) |
| FormRecognizer | `Microsoft.CognitiveServices/accounts` (FormRecognizer) |
| HealthInsights | `Microsoft.CognitiveServices/accounts` (HealthInsights) |
| ImmersiveReader | `Microsoft.CognitiveServices/accounts` (ImmersiveReader) |
| MachineLearning | `Microsoft.MachineLearningServices/workspaces` |
| MLComputes | `Microsoft.MachineLearningServices/workspaces` (computes) |
| MLDatasets | `Microsoft.MachineLearningServices/workspaces` (datasets) |
| MLDatastores | `Microsoft.MachineLearningServices/workspaces` (datastores) |
| MLEndpoints | `Microsoft.MachineLearningServices/workspaces` (online endpoints) |
| MLModels | `Microsoft.MachineLearningServices/workspaces` (models) |
| MLPipelines | `Microsoft.MachineLearningServices/workspaces` (pipeline jobs) |
| OpenAIAccounts | `Microsoft.CognitiveServices/accounts` (OpenAI) |
| OpenAIDeployments | `Microsoft.CognitiveServices/accounts` (OpenAI deployments) |
| SearchIndexes | `Microsoft.Search/searchServices` (indexes) |
| SearchServices | `Microsoft.Search/searchServices` |
| SpeechService | `Microsoft.CognitiveServices/accounts` (SpeechServices) |
| TextAnalytics | `Microsoft.CognitiveServices/accounts` (TextAnalytics) |
| Translator | `Microsoft.CognitiveServices/accounts` (TextTranslation) |

### Analytics (6 modules)

Big data, streaming, and data governance resources.

| Module | Resource Type |
|--------|---------------|
| DataExplorerCluster | `Microsoft.Kusto/clusters` |
| Databricks | `Microsoft.Databricks/workspaces` |
| EvtHub | `Microsoft.EventHub/namespaces` |
| Purview | `Microsoft.Purview/accounts` |
| Streamanalytics | `Microsoft.StreamAnalytics/clusters` |
| Synapse | `Microsoft.Synapse/workspaces` |

### Compute (14 modules)

Virtual machines, scale sets, Azure Virtual Desktop, and VMware.

| Module | Resource Type |
|--------|---------------|
| AVD | `Microsoft.DesktopVirtualization/hostpools` |
| AVDApplicationGroups | `Microsoft.DesktopVirtualization/applicationgroups` |
| AVDApplications | `Microsoft.DesktopVirtualization/applicationgroups` (applications) |
| AVDAzureLocal | AVD session hosts running on Arc-enabled / Azure Local machines |
| AVDScalingPlans | `Microsoft.DesktopVirtualization/scalingplans` |
| AVDSessionHosts | `Microsoft.DesktopVirtualization/hostpools/sessionhosts` |
| AVDWorkspaces | `Microsoft.DesktopVirtualization/workspaces` |
| AvailabilitySets | `Microsoft.Compute/availabilitySets` |
| CloudServices | `Microsoft.Compute/cloudServices` |
| VMDisk | `Microsoft.Compute/disks` |
| VMOperationalData | VM operational enrichment (metrics, backup, DR, cost) |
| VMWare | `Microsoft.AVS/privateClouds` |
| VirtualMachine | `Microsoft.Compute/virtualMachines` |
| VirtualMachineScaleSet | `Microsoft.Compute/virtualMachineScaleSets` |

### Containers (6 modules)

Kubernetes, container apps, and container registries.

| Module | Resource Type |
|--------|---------------|
| AKS | `Microsoft.ContainerService/managedClusters` |
| ARO | `Microsoft.RedHatOpenShift/openShiftClusters` |
| ContainerApp | `Microsoft.App/containerApps` |
| ContainerAppEnv | `Microsoft.App/managedEnvironments` |
| ContainerGroups | `Microsoft.ContainerInstance/containerGroups` |
| ContainerRegistries | `Microsoft.ContainerRegistry/registries` |

### Databases (13 modules)

Relational, NoSQL, and cache database services.

| Module | Resource Type |
|--------|---------------|
| CosmosDB | `Microsoft.DocumentDB/databaseAccounts` |
| MariaDB | `Microsoft.DBforMariaDB/servers` |
| MySQL | `Microsoft.DBforMySQL/servers` |
| MySQLflexible | `Microsoft.DBforMySQL/flexibleServers` |
| POSTGRE | `Microsoft.DBforPostgreSQL/servers` |
| POSTGREFlexible | `Microsoft.DBforPostgreSQL/flexibleServers` |
| RedisCache | `Microsoft.Cache/redis` |
| SQLDB | `Microsoft.Sql/servers/databases` |
| SQLMI | `Microsoft.Sql/managedInstances` |
| SQLMIDB | `Microsoft.Sql/managedInstances/databases` |
| SQLPOOL | `Microsoft.Sql/servers/elasticPools` |
| SQLSERVER | `Microsoft.Sql/servers` |
| SQLVM | `Microsoft.SqlVirtualMachine/sqlVirtualMachines` |

### Hybrid (16 modules)

Azure Arc and Azure Local (Azure Stack HCI) resource management.

| Module | Resource Type |
|--------|---------------|
| ARCServers | `Microsoft.HybridCompute/machines` |
| ArcDataControllers | `Microsoft.AzureArcData/dataControllers` |
| ArcExtensions | `Microsoft.HybridCompute/machines/extensions` |
| ArcGateways | `Microsoft.HybridCompute/gateways` |
| ArcKubernetes | `Microsoft.Kubernetes/connectedClusters` |
| ArcResourceBridge | `Microsoft.ResourceConnector/appliances` |
| ArcServerOperationalData | Arc server operational enrichment (metrics, backup, DR, cost, policy) |
| ArcSites | `Microsoft.AzureStackHCI/sites` |
| ArcSQLManagedInstances | `Microsoft.AzureArcData/sqlManagedInstances` |
| ArcSQLServers | `Microsoft.AzureArcData/sqlServerInstances` |
| Clusters | `Microsoft.AzureStackHCI/clusters` |
| GalleryImages | `Microsoft.AzureStackHCI/galleryImages` |
| LogicalNetworks | `Microsoft.AzureStackHCI/logicalNetworks` |
| MarketplaceGalleryImages | `Microsoft.AzureStackHCI/marketplaceGalleryImages` |
| StorageContainers | `Microsoft.AzureStackHCI/storageContainers` |
| VirtualMachines | `Microsoft.AzureStackHCI/virtualMachineInstances` |

### Identity (1 ARM module)

The `Identity` category folder is shared: this is the **only** ARM-based module in it.
The other 17 files in `Modules/Public/InventoryModules/Identity/` are Microsoft
Graph-based and cataloged on the [Entra ID Modules](entra-modules.md) page.

| Module | Resource Type |
|--------|---------------|
| ManagedIds | `Microsoft.ManagedIdentity/userAssignedIdentities` |

### Integration (2 modules)

API management and messaging services.

| Module | Resource Type |
|--------|---------------|
| APIM | `Microsoft.ApiManagement/service` |
| ServiceBUS | `Microsoft.ServiceBus/namespaces` |

### IoT (1 module)

Internet of Things platform resources.

| Module | Resource Type |
|--------|---------------|
| IOTHubs | `Microsoft.Devices/IotHubs` |

### Management (14 modules)

Governance, policy, automation, backup, and support resources.

| Module | Resource Type |
|--------|---------------|
| AdvisorScore | `Microsoft.Advisor/advisorScore` |
| AllSubscriptions | `Microsoft.Resources/subscriptions` (all, including empty/disabled) |
| AutomationAccounts | `Microsoft.Automation/automationAccounts` (runbooks) |
| Backup | `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems` |
| CustomRoleDefinitions | `Get-AzRoleDefinition -Custom` (custom RBAC role definitions) |
| LighthouseDelegations | `Microsoft.ManagedServices/registrationDefinitions` |
| MaintenanceConfigurations | `Microsoft.Maintenance/maintenanceConfigurations` |
| ManagementGroups | `Get-AzManagementGroup` (full MG hierarchy) |
| PolicyComplianceStates | `Get-AzPolicyState` (per-subscription compliance) |
| PolicyDefinitions | `Get-AzPolicyDefinition -Custom` |
| PolicySetDefinitions | `Get-AzPolicySetDefinition -Custom` |
| RecoveryVault | `Microsoft.RecoveryServices/vaults` |
| ReservationRecom | `Microsoft.Consumption/reservationRecommendations` |
| SupportTickets | `Microsoft.Support/supportTickets` |

### Monitor (24 modules)

Observability, alerting, and logging resources.

| Module | Resource Type |
|--------|---------------|
| ActionGroups | `Microsoft.Insights/actionGroups` |
| ActivityLogAlertRules | `Microsoft.Insights/activityLogAlerts` |
| AppInsights | `Microsoft.Insights/components` |
| AppInsightsAvailabilityTests | `Microsoft.Insights/webtests` |
| AppInsightsContinuousExport | `Microsoft.Insights/components` (continuous export config) |
| AppInsightsProactiveDetection | `Microsoft.Insights/components` (proactive detection config) |
| AppInsightsWebTests | `Microsoft.Insights/webtests` |
| AppInsightsWorkItems | `Microsoft.Insights/components` (work item config) |
| AutoscaleSettings | `Microsoft.Insights/autoscalesettings` |
| DataCollectionEndpoints | `Microsoft.Insights/dataCollectionEndpoints` |
| DataCollectionRules | `Microsoft.Insights/dataCollectionRules` |
| LAWorkspaceLinkedServices | `Microsoft.OperationalInsights/workspaces` (linked services) |
| LAWorkspaceSavedSearches | `Microsoft.OperationalInsights/workspaces` (saved searches) |
| LAWorkspaceSolutions | `Microsoft.OperationsManagement/solutions` |
| MetricAlertRules | `Microsoft.Insights/metricAlerts` |
| MonitorMetricsIngestion | `Microsoft.OperationalInsights/workspaces` (metrics ingestion) |
| MonitorPrivateLinkScopes | `Microsoft.Insights/privateLinkScopes` |
| MonitorWorkbooks | `Microsoft.Insights/workbooks` |
| Outages | `Microsoft.ResourceHealth/events` |
| ResourceDiagnosticSettings | `Microsoft.Insights/diagnosticSettings` |
| ScheduledQueryRules | `Microsoft.Insights/scheduledQueryRules` |
| SmartDetectorAlertRules | `Microsoft.AlertsManagement/smartDetectorAlertRules` |
| SubscriptionDiagnosticSettings | Subscription-level diagnostic settings |
| Workspaces | `Microsoft.OperationalInsights/workspaces` |

### Networking (21 modules)

Virtual networking, firewalls, load balancers, and DNS.

| Module | Resource Type |
|--------|---------------|
| ApplicationGateways | `Microsoft.Network/applicationGateways` |
| AzureFirewall | `Microsoft.Network/azureFirewalls` |
| BastionHosts | `Microsoft.Network/bastionHosts` |
| Connections | `Microsoft.Network/connections` |
| ExpressRoute | `Microsoft.Network/expressRouteCircuits` |
| Frontdoor | `Microsoft.Network/frontDoors` |
| LoadBalancer | `Microsoft.Network/loadBalancers` |
| NATGateway | `Microsoft.Network/natGateways` |
| NetworkInterface | `Microsoft.Network/networkInterfaces` |
| NetworkSecurityGroup | `Microsoft.Network/networkSecurityGroups` |
| NetworkWatchers | `Microsoft.Network/networkWatchers` |
| PrivateDNS | `Microsoft.Network/privateDnsZones` |
| PrivateEndpoint | `Microsoft.Network/privateEndpoints` |
| PublicDNS | `Microsoft.Network/dnsZones` |
| PublicIP | `Microsoft.Network/publicIPAddresses` |
| RouteTables | `Microsoft.Network/routeTables` |
| TrafficManager | `Microsoft.Network/trafficManagerProfiles` |
| VirtualNetwork | `Microsoft.Network/virtualNetworks` |
| VirtualNetworkGateways | `Microsoft.Network/virtualNetworkGateways` |
| VirtualWAN | `Microsoft.Network/virtualWans` |
| vNETPeering | `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` |

### Security (5 modules)

Microsoft Defender for Cloud and Key Vault.

| Module | Resource Type |
|--------|---------------|
| DefenderAlerts | Microsoft Defender for Cloud security alerts |
| DefenderAssessments | Microsoft Defender for Cloud security assessments |
| DefenderPricing | Microsoft Defender for Cloud pricing plans |
| DefenderSecureScore | Microsoft Defender for Cloud secure score |
| Vault | `Microsoft.KeyVault/vaults` |

### Storage (2 modules)

Block, file, and object storage services.

| Module | Resource Type |
|--------|---------------|
| NetApp | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` |
| StorageAccounts | `Microsoft.Storage/storageAccounts` |

### Web (2 modules)

App Service hosting and web applications.

| Module | Resource Type |
|--------|---------------|
| APPServicePlan | `Microsoft.Web/serverfarms` |
| APPServices | `Microsoft.Web/sites` |

## Valid `-Category` filter values

The module groupings above (and on the [Coverage Table](coverage-table.md)) are catalog
labels for browsing this page — they are **not** all necessarily valid `-Category`
values to pass to `Invoke-AzureScout`. The actual `[ValidateSet]` for `-Category` is:

```
All, AI, Analytics, Compute, Containers, Databases, Hybrid, Identity, Integration,
IoT, Management, Monitor, Networking, Security, Storage, Web
```

`Identity` runs **both** the ARM module above and all 17 Entra modules (subject to
`-Scope`). See [Category Filtering](category-filtering.md) for alias support (e.g.
`-Category 'AI + machine learning'` is normalized to `-Category AI`).
