---
description: Complete catalog of AzureScout inventory collectors across all 18 of Microsoft's published service categories.
---

# ARM Inventory Modules

## Overview

AzureScout ships **242 collector definitions** across **18 categories** — Microsoft's
eighteen published service categories, as listed on the Azure portal's All services page.
The `Identity` category queries Microsoft Graph rather than ARM; those collectors are also
cataloged on the [Entra ID Modules](entra-modules.md) page.

Each definition targets one or more Azure resource types and generally produces one worksheet
in the Excel report.

Run ARM-only extraction with:

```powershell
Invoke-AzureScout -Scope ArmOnly
```

`ArmOnly` is the **default** `-Scope` value for `Invoke-AzureScout` — running the
cmdlet with no `-Scope` flag already does this.

::: tip This page is generated
Regenerate it with `scripts/Build-ArmModuleCatalog.ps1`. The counts and the rows come from
`manifests/collectors/`; `tests/DocsArmCatalog.Tests.ps1` fails the build if the committed page
and a fresh regeneration disagree. Do not hand-edit it — the previous, hand-maintained version
claimed to be generated and was 15 collectors out of date.
:::

## Module Catalog

### AI (27 modules)

Cognitive Services, Azure OpenAI, Machine Learning, AI Foundry, Bot Services, and AI Search.

| Module | Resource Type |
|--------|---------------|
| AIFoundryHubs | `microsoft.machinelearningservices/workspaces` *(filtered)* |
| AIFoundryProjects | `microsoft.machinelearningservices/workspaces` *(filtered)* |
| AppliedAIServices | `microsoft.cognitiveservices/accounts` *(filtered)* |
| AzureAI | `microsoft.cognitiveservices/accounts` *(filtered)* |
| BotServices | `microsoft.botservice/botservices` |
| ComputerVision | `microsoft.cognitiveservices/accounts` *(filtered)* |
| ContentModerator | `microsoft.cognitiveservices/accounts` *(filtered)* |
| ContentSafety | `microsoft.cognitiveservices/accounts` *(filtered)* |
| CustomVision | `microsoft.cognitiveservices/accounts` *(filtered)* |
| FaceAPI | `microsoft.cognitiveservices/accounts` *(filtered)* |
| FormRecognizer | `microsoft.cognitiveservices/accounts` *(filtered)* |
| HealthInsights | `microsoft.cognitiveservices/accounts` *(filtered)* |
| ImmersiveReader | `microsoft.cognitiveservices/accounts` *(filtered)* |
| MachineLearning | `microsoft.machinelearningservices/workspaces` |
| MLComputes | `AZSC/ARMChild/MLComputes` |
| MLDatasets | `AZSC/ARMChild/MLDatasets` |
| MLDatastores | `AZSC/ARMChild/MLDatastores` |
| MLEndpoints | `AZSC/ARMChild/MLEndpoints` |
| MLModels | `AZSC/ARMChild/MLModels` |
| MLPipelines | `AZSC/ARMChild/MLPipelines` |
| OpenAIAccounts | `microsoft.cognitiveservices/accounts` *(filtered)* |
| OpenAIDeployments | `AZSC/ARMChild/OpenAIDeployments` |
| SearchIndexes | `AZSC/ARMChild/SearchIndexes` |
| SearchServices | `microsoft.search/searchservices` |
| SpeechService | `microsoft.cognitiveservices/accounts` *(filtered)* |
| TextAnalytics | `microsoft.cognitiveservices/accounts` *(filtered)* |
| Translator | `microsoft.cognitiveservices/accounts` *(filtered)* |

### Analytics (6 modules)

Synapse, Databricks, Data Explorer, Event Hubs, Stream Analytics, and Purview.

| Module | Resource Type |
|--------|---------------|
| Databricks | `microsoft.databricks/workspaces` |
| DataExplorerCluster | `microsoft.kusto/clusters` |
| EvtHub | `microsoft.eventhub/namespaces` |
| Purview | `microsoft.purview/accounts` |
| Streamanalytics | `microsoft.streamanalytics/streamingjobs` |
| Synapse | `microsoft.synapse/workspaces` |

### Compute (13 modules)

Virtual machines, scale sets, availability sets, and the Azure Virtual Desktop estate.

| Module | Resource Type |
|--------|---------------|
| AvailabilitySets | `microsoft.compute/availabilitysets` |
| AVD | `microsoft.desktopvirtualization/hostpools` |
| AVDApplicationGroups | `microsoft.desktopvirtualization/applicationgroups` |
| AVDApplications | `AZSC/ARMChild/AVDApplications` |
| AVDAzureLocal | `AZSC/AVD/AzureLocalSessionHost` |
| AVDScalingPlans | `microsoft.desktopvirtualization/scalingplans` |
| AVDSessionHosts | `microsoft.desktopvirtualization/hostpools/sessionhosts` |
| AVDWorkspaces | `microsoft.desktopvirtualization/workspaces` |
| VirtualMachine | `microsoft.compute/virtualmachines` |
| VirtualMachineScaleSet | `microsoft.compute/virtualmachinescalesets` |
| VMDisk | `microsoft.compute/disks` |
| VMOperationalData | `microsoft.compute/virtualmachines` |
| VMWare | `Microsoft.AVS/privateClouds` |

### Containers (6 modules)

AKS, ARO, Container Apps, container instances, and container registries.

| Module | Resource Type |
|--------|---------------|
| AKS | `microsoft.containerservice/managedclusters` |
| ARO | `microsoft.redhatopenshift/openshiftclusters` |
| ContainerApp | `microsoft.app/containerapps` |
| ContainerAppEnv | `microsoft.app/managedenvironments` |
| ContainerGroups | `microsoft.containerinstance/containergroups` |
| ContainerRegistries | `microsoft.containerregistry/registries` |

### Databases (12 modules)

Azure SQL, Cosmos DB, MySQL, PostgreSQL, MariaDB, and Redis.

| Module | Resource Type |
|--------|---------------|
| CosmosDB | `microsoft.documentdb/databaseaccounts` |
| MariaDB | `microsoft.dbformariadb/servers` |
| MySQL | `microsoft.dbformysql/servers` |
| MySQLflexible | `Microsoft.DBforMySQL/flexibleServers` |
| POSTGREFlexible | `Microsoft.DBforPostgreSQL/flexibleServers` |
| RedisCache | `microsoft.cache/redis` · `microsoft.cache/redisenterprise` |
| SQLDB | `microsoft.sql/servers/databases` *(filtered)* |
| SQLMI | `microsoft.sql/managedInstances` |
| SQLMIDB | `microsoft.sql/managedinstances/databases` |
| SQLPOOL | `microsoft.sql/servers/elasticPools` |
| SQLSERVER | `microsoft.sql/servers` |
| SQLVM | `microsoft.sqlvirtualmachine/sqlvirtualmachines` |

### DevOps (17 modules)

Chaos Studio, Dev Box and Dev Centers, DevTest and Lab Services, Load Testing, Managed DevOps Pools, and Playwright workspaces.

| Module | Resource Type |
|--------|---------------|
| ApiConnections | `microsoft.web/connections` |
| AppConfiguration | `microsoft.appconfiguration/configurationstores` |
| ChaosStudio | `microsoft.chaos/experiments` · `microsoft.chaos/targets` |
| DeploymentEnvironments | `microsoft.devcenter/devcenters/environmenttypes` · `microsoft.devcenter/projects/environmenttypes` · `microsoft.devcenter/devcenters/catalogs` · `microsoft.devcenter/projects/catalogs` |
| DevBoxPools | `microsoft.devcenter/projects/pools` |
| DevCenterNetworkConnections | `microsoft.devcenter/networkconnections` |
| DevCenters | `microsoft.devcenter/devcenters` · `microsoft.devcenter/projects` |
| DevOpsAgentPools | `devops/agentpools` |
| DevOpsPipelines | `devops/pipelines` |
| DevOpsProjects | `devops/projects` |
| DevOpsRepositories | `devops/repositories` |
| DevOpsServiceConnections | `devops/serviceconnections` |
| DevTestLabs | `microsoft.devtestlab/labs` · `microsoft.devtestlab/schedules` |
| LabServices | `microsoft.labservices/labs` · `microsoft.labservices/labplans` |
| LoadTesting | `microsoft.loadtestservice/loadtests` |
| ManagedDevOpsPools | `microsoft.devopsinfrastructure/pools` |
| PlaywrightTesting | `microsoft.azureplaywrightservice/accounts` |

### General (5 modules)

Support tickets, reservations, and VM quotas — the platform-level surfaces that belong to no service family.

| Module | Resource Type |
|--------|---------------|
| Quotas | `AZSC/VM/Quotas` |
| ReservationRecom | `Microsoft.Consumption/reservationRecommendations` |
| Reservations | `microsoft.capacity/reservationorders` · `microsoft.capacity/reservationorders/reservations` |
| ReservationUtilization | `AZSC/ARMChild/ReservationUtilization` |
| SupportTickets | `Microsoft.Support/supportTickets` |

### Hybrid (16 modules)

Azure Arc, Azure Local, VMware Solution, and the hybrid data services.

| Module | Resource Type |
|--------|---------------|
| ArcDataControllers | `microsoft.azurearcdata/datacontrollers` |
| ArcExtensions | `microsoft.hybridcompute/machines/extensions` |
| ArcGateways | `microsoft.hybridcompute/gateways` |
| ArcKubernetes | `microsoft.kubernetes/connectedclusters` |
| ArcResourceBridge | `microsoft.resourceconnector/appliances` |
| ArcServerOperationalData | `microsoft.hybridcompute/machines` |
| ARCServers | `microsoft.hybridcompute/machines` |
| ArcSites | `AZSC/ARMChild/ArcSites` |
| ArcSQLManagedInstances | `microsoft.azurearcdata/sqlmanagedinstances` |
| ArcSQLServers | `microsoft.azurearcdata/sqlserverinstances` |
| Clusters | `microsoft.azurestackhci/clusters` |
| GalleryImages | `microsoft.azurestackhci/galleryimages` |
| LogicalNetworks | `microsoft.azurestackhci/logicalnetworks` |
| MarketplaceGalleryImages | `microsoft.azurestackhci/marketplacegalleryimages` |
| StorageContainers | `microsoft.azurestackhci/storagecontainers` |
| VirtualMachines | `AZSC/ARMChild/AzureLocalVirtualMachineInstances` |

### Identity (17 modules)

Entra ID via Microsoft Graph — users, groups, app registrations, Conditional Access, and PIM.

| Module | Resource Type |
|--------|---------------|
| AdminUnits | `entra/administrativeunits` |
| AppRegistrations | `entra/applications` |
| ConditionalAccess | `entra/conditionalaccesspolicies` |
| CrossTenantAccess | `entra/crosstenantaccess` |
| DirectoryRoles | `entra/directoryroles` |
| Domains | `entra/domains` |
| Groups | `entra/groups` |
| Licensing | `entra/subscribedskus` |
| ManagedIdentities | `entra/managedidentities` |
| ManagedIds | `Microsoft.ManagedIdentity/userAssignedIdentities` |
| NamedLocations | `entra/namedlocations` |
| PIMAssignments | `entra/pimassignments` |
| RiskyUsers | `entra/riskyusers` |
| RoleAssignments | `AZSC/Governance/RoleAssignment` |
| SecurityPolicies | `entra/securitypolicies` |
| ServicePrincipals | `entra/serviceprincipals` |
| Users | `entra/users` |

### Integration (9 modules)

Logic Apps, integration accounts, Event Grid, Relays, Health Data Services, API Management, and Service Bus.

| Module | Resource Type |
|--------|---------------|
| APIM | `microsoft.apimanagement/service` |
| EventGrid | `microsoft.eventgrid/topics` · `microsoft.eventgrid/systemtopics` · `microsoft.eventgrid/domains` · `microsoft.eventgrid/partnertopics` · `microsoft.eventgrid/namespaces` |
| EventHubClusters | `microsoft.eventhub/clusters` |
| HealthDataServices | `microsoft.healthcareapis/services` · `microsoft.healthcareapis/workspaces` · `microsoft.healthcareapis/workspaces/fhirservices` · `microsoft.healthcareapis/workspaces/dicomservices` · `microsoft.healthcareapis/workspaces/iotconnectors` |
| IntegrationAccounts | `microsoft.logic/integrationaccounts` · `microsoft.logic/integrationserviceenvironments` |
| LogicApps | `microsoft.logic/workflows` |
| LogicAppsCustomConnectors | `microsoft.web/customapis` |
| Relays | `microsoft.relay/namespaces` · `microsoft.relay/namespaces/hybridconnections` · `microsoft.relay/namespaces/wcfrelays` |
| ServiceBUS | `microsoft.servicebus/namespaces` |

### IoT (7 modules)

IoT Hub and DPS, IoT Central, Device Update, Digital Twins, Azure Maps, and Defender for IoT.

| Module | Resource Type |
|--------|---------------|
| DefenderForIoT | `microsoft.iotsecurity/defendersettings` · `microsoft.iotsecurity/sites` · `microsoft.iotsecurity/sensors` · `microsoft.iotsecurity/onpremisesensors` |
| DeviceProvisioningServices | `microsoft.devices/provisioningservices` |
| DeviceUpdate | `microsoft.deviceupdate/accounts` · `microsoft.deviceupdate/accounts/instances` |
| DigitalTwins | `microsoft.digitaltwins/digitaltwinsinstances` · `microsoft.digitaltwins/digitaltwinsinstances/endpoints` · `microsoft.digitaltwins/digitaltwinsinstances/timeseriesdatabaseconnections` |
| IoTCentral | `microsoft.iotcentral/iotapps` |
| IOTHubs | `microsoft.devices/iothubs` |
| Maps | `microsoft.maps/accounts` · `microsoft.maps/accounts/creators` |

### Management (16 modules)

Subscriptions, management groups, policy, backup, automation, Advisor, Lighthouse, and the Azure DevOps organisation collectors.

| Module | Resource Type |
|--------|---------------|
| AdvisorScore | `Microsoft.Advisor/advisorScore` |
| AllSubscriptions | `AZSC/Management/SubscriptionEnrichment` |
| AutomationAccounts | `microsoft.automation/automationaccounts` |
| Backup | `microsoft.recoveryservices/vaults/backuppolicies` |
| BackupInstances | `AZSC/ARMChild/BackupInstances` |
| Budgets | `AZSC/Governance/Budget` |
| CustomRoleDefinitions | `AZSC/Management/RoleDefinition` |
| LighthouseDelegations | `Microsoft.ManagedServices/registrationDefinitions` |
| MaintenanceConfigurations | `microsoft.maintenance/maintenanceconfigurations` |
| ManagementGroups | `AZSC/Management/ManagementGroup` |
| PolicyAssignments | `AZSC/Governance/PolicyAssignment` |
| PolicyComplianceStates | `AZSC/Subscription/SecurityPolicySweep` |
| PolicyDefinitions | `AZSC/Management/PolicyDefinition` |
| PolicySetDefinitions | `AZSC/Management/PolicySetDefinition` |
| RecoveryVault | `microsoft.recoveryservices/vaults` |
| ResourceLocks | `AZSC/Governance/ResourceLock` |

### Migration (6 modules)

Azure Migrate projects, assessments and discovery sites; Database Migration Services, Data Box, and Azure Stack Edge.

| Module | Resource Type |
|--------|---------------|
| AzureMigrateAssessments | `microsoft.migrate/assessmentprojects` |
| AzureMigrateDiscoverySites | `microsoft.offazure/vmwaresites` · `microsoft.offazure/hypervsites` · `microsoft.offazure/serversites` · `microsoft.offazure/mastersites` |
| AzureMigrateProjects | `microsoft.migrate/migrateprojects` |
| DatabaseMigrationServices | `microsoft.datamigration/services` · `microsoft.datamigration/sqlmigrationservices` |
| DataBox | `microsoft.databox/jobs` |
| StackEdge | `microsoft.databoxedge/databoxedgedevices` |

### Monitor (22 modules)

Alert rules, Application Insights, data collection rules, diagnostic settings, and Log Analytics.

| Module | Resource Type |
|--------|---------------|
| ActionGroups | `microsoft.insights/actiongroups` |
| ActivityLogAlertRules | `microsoft.insights/activitylogalerts` |
| AppInsights | `microsoft.insights/components` |
| AppInsightsAvailabilityTests | `microsoft.insights/webtests` |
| AppInsightsProactiveDetection | `AZSC/ARMChild/AppInsightsProactiveDetection` |
| AppInsightsWebTests | `microsoft.insights/webtests` *(filtered)* |
| AutoscaleSettings | `microsoft.insights/autoscalesettings` |
| DataCollectionEndpoints | `microsoft.insights/datacollectionendpoints` |
| DataCollectionRules | `microsoft.insights/datacollectionrules` |
| LAWorkspaceLinkedServices | `AZSC/ARMChild/LAWorkspaceLinkedServices` |
| LAWorkspaceSavedSearches | `AZSC/ARMChild/LAWorkspaceSavedSearches` *(filtered)* |
| LAWorkspaceSolutions | `microsoft.operationsmanagement/solutions` |
| MetricAlertRules | `microsoft.insights/metricalerts` |
| MonitorMetricsIngestion | `microsoft.operationalinsights/workspaces` |
| MonitorPrivateLinkScopes | `microsoft.insights/privatelinkscopes` |
| MonitorWorkbooks | `microsoft.insights/workbooks` |
| Outages | `AZSC/Monitor/Outage` |
| ResourceDiagnosticSettings | `AZSC/ARMChild/ResourceDiagnosticSettings` |
| ScheduledQueryRules | `microsoft.insights/scheduledqueryrules` |
| SmartDetectorAlertRules | `microsoft.alertsmanagement/smartdetectoralertrules` |
| SubscriptionDiagnosticSettings | `AZSC/Subscription/SecurityPolicySweep` |
| Workspaces | `microsoft.operationalinsights/workspaces` |

### Networking (21 modules)

Virtual networks, NSGs, load balancers, gateways, Front Door, Firewall, Bastion, and ExpressRoute.

| Module | Resource Type |
|--------|---------------|
| ApplicationGateways | `microsoft.network/applicationgateways` |
| AzureFirewall | `microsoft.network/azurefirewalls` |
| BastionHosts | `microsoft.network/bastionhosts` |
| Connections | `microsoft.network/connections` |
| ExpressRoute | `microsoft.network/expressroutecircuits` |
| Frontdoor | `microsoft.network/frontdoors` |
| LoadBalancer | `microsoft.network/loadbalancers` |
| NATGateway | `microsoft.network/natgateways` |
| NetworkInterface | `microsoft.network/networkinterfaces` |
| NetworkSecurityGroup | `microsoft.network/networksecuritygroups` |
| NetworkWatchers | `microsoft.network/networkwatchers` |
| PrivateDNS | `microsoft.network/privatednszones` |
| PrivateEndpoint | `microsoft.network/privateendpoints` |
| PublicDNS | `microsoft.network/dnszones` |
| PublicIP | `microsoft.network/publicipaddresses` |
| RouteTables | `microsoft.network/routetables` |
| TrafficManager | `microsoft.network/trafficmanagerprofiles` |
| VirtualNetwork | `microsoft.network/virtualnetworks` |
| VirtualNetworkGateways | `microsoft.network/virtualnetworkgateways` |
| VirtualWAN | `microsoft.network/virtualwans` |
| vNETPeering | `microsoft.network/virtualnetworks` *(filtered)* |

### Security (17 modules)

Defender for Cloud, Key Vault and its secret/key expiry, Sentinel, HSMs, WAF and DDoS policies, and Entra Domain Services.

| Module | Resource Type |
|--------|---------------|
| AppComplianceAutomation | `microsoft.appcomplianceautomation/reports` · `microsoft.appcomplianceautomation/reports/snapshots` |
| ApplicationSecurityGroups | `microsoft.network/applicationsecuritygroups` |
| ArtifactSigning | `microsoft.codesigning/codesigningaccounts` |
| CloudHSM | `microsoft.hardwaresecuritymodules/cloudhsmclusters` |
| ConfidentialLedger | `microsoft.confidentialledger/ledgers` |
| DdosProtectionPlans | `microsoft.network/ddosprotectionplans` |
| DefenderAlerts | `AZSC/Subscription/SecurityPolicySweep` |
| DefenderAssessments | `AZSC/Subscription/SecurityPolicySweep` |
| DefenderPricing | `AZSC/Subscription/SecurityPolicySweep` |
| DefenderSecureScore | `AZSC/Subscription/SecurityPolicySweep` |
| EntraDomainServices | `microsoft.aad/domainservices` |
| KeyVaultKeys | `AZSC/ARMChild/KeyVaultKeys` |
| KeyVaultSecrets | `AZSC/ARMChild/KeyVaultSecrets` |
| ManagedHSM | `microsoft.keyvault/managedhsms` |
| Sentinel | `microsoft.operationsmanagement/solutions` · `microsoft.securityinsights/onboardingstates` *(filtered)* |
| Vault | `microsoft.keyvault/vaults` |
| WafPolicies | `microsoft.network/applicationgatewaywebapplicationfirewallpolicies` · `microsoft.network/frontdoorwebapplicationfirewallpolicies` · `microsoft.cdn/cdnwebapplicationfirewallpolicies` |

### Storage (11 modules)

Storage accounts and their containers, shares and lifecycle policies; NetApp Files, snapshots, encryption sets, and Elastic SAN.

| Module | Resource Type |
|--------|---------------|
| BlobContainers | `AZSC/ARMChild/StorageBlobContainers` |
| DiskEncryptionSets | `microsoft.compute/diskencryptionsets` |
| EdgeHardwareCenter | `microsoft.edgeorder/orders` · `microsoft.edgeorder/orderitems` · `microsoft.edgeorder/addresses` |
| ElasticSan | `microsoft.elasticsan/elasticsans` · `microsoft.elasticsan/elasticsans/volumegroups` |
| FileShares | `AZSC/ARMChild/StorageFileShares` |
| LifecyclePolicies | `AZSC/ARMChild/StorageLifecyclePolicies` |
| NetApp | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` |
| PartnerStorage | `purestorage.block/storagepools` · `purestorage.block/reservations` · `qumulo.storage/filesystems` |
| Snapshots | `microsoft.compute/snapshots` |
| StorageAccounts | `microsoft.storage/storageaccounts` |
| StorageSync | `microsoft.storagesync/storagesyncservices` · `microsoft.storagesync/storagesyncservices/syncgroups` · `microsoft.storagesync/storagesyncservices/registeredservers` |

### Web (14 modules)

App Services and plans, Function Apps, slots, Static Web Apps, SignalR, Web PubSub, and Communication Services.

| Module | Resource Type |
|--------|---------------|
| AppServiceCertificates | `microsoft.certificateregistration/certificateorders` · `microsoft.web/certificates` |
| AppServiceDomains | `microsoft.domainregistration/domains` |
| AppServiceEnvironments | `microsoft.web/hostingenvironments` |
| APPServicePlan | `microsoft.web/serverfarms` |
| APPServices | `microsoft.web/sites` |
| CommunicationServices | `microsoft.communication/communicationservices` · `microsoft.communication/emailservices` · `microsoft.communication/emailservices/domains` |
| DeploymentSlots | `microsoft.web/sites/slots` |
| FluidRelay | `microsoft.fluidrelay/fluidrelayservers` |
| FunctionApps | `microsoft.web/sites` *(filtered)* |
| NotificationHubs | `microsoft.notificationhubs/namespaces` · `microsoft.notificationhubs/namespaces/notificationhubs` |
| SignalR | `microsoft.signalrservice/signalr` |
| SpringApps | `microsoft.appplatform/spring` · `microsoft.appplatform/spring/apps` |
| StaticWebApps | `microsoft.web/staticsites` |
| WebPubSub | `microsoft.signalrservice/webpubsub` |

## Valid `-Category` filter values

Every category above is a valid `-Category` value. The full `[ValidateSet]` is:

```
All, AI, Analytics, Compute, Containers, Databases, DevOps, General, Hybrid, Identity, Integration, IoT, Management, Migration, Monitor, Networking, Security, Storage, Web
```

`Identity` runs the Entra collectors subject to `-Scope`. See
[Category Reference](category-reference.md) for the accepted long-form aliases (e.g.
`-Category 'AI + machine learning'` normalises to `-Category AI`).

