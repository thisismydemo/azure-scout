---
description: Every AzureScout inventory collector, the Azure resource type it covers, and the Excel worksheet it writes to.
---

# Coverage Table

Every inventory collector in AzureScout, the Azure resource type(s) it covers, and the Excel
worksheet it writes to.

::: tip This page is generated
Regenerate it with `scripts/Build-ArmModuleCatalog.ps1`, which writes this page and
[ARM Modules](arm-modules.md) from the same pass over `manifests/collectors/`.
:::

## Coverage Summary

| Category | Modules | Notes |
|----------|---------|-------|
| AI | 27 | Cognitive Services, Azure OpenAI, Machine Learning, AI Foundry, Bot Services, and AI Search. |
| Analytics | 6 | Synapse, Databricks, Data Explorer, Event Hubs, Stream Analytics, and Purview. |
| Compute | 13 | Virtual machines, scale sets, availability sets, and the Azure Virtual Desktop estate. |
| Containers | 6 | AKS, ARO, Container Apps, container instances, and container registries. |
| Databases | 12 | Azure SQL, Cosmos DB, MySQL, PostgreSQL, MariaDB, and Redis. |
| DevOps | 17 | Chaos Studio, Dev Box and Dev Centers, DevTest and Lab Services, Load Testing, Managed DevOps Pools, and Playwright workspaces. |
| General | 5 | Support tickets, reservations, and VM quotas — the platform-level surfaces that belong to no service family. |
| Hybrid | 16 | Azure Arc, Azure Local, VMware Solution, and the hybrid data services. |
| Identity | 17 | Entra ID via Microsoft Graph — users, groups, app registrations, Conditional Access, and PIM. |
| Integration | 9 | Logic Apps, integration accounts, Event Grid, Relays, Health Data Services, API Management, and Service Bus. |
| IoT | 7 | IoT Hub and DPS, IoT Central, Device Update, Digital Twins, Azure Maps, and Defender for IoT. |
| Management | 16 | Subscriptions, management groups, policy, backup, automation, Advisor, Lighthouse, and the Azure DevOps organisation collectors. |
| Migration | 6 | Azure Migrate projects, assessments and discovery sites; Database Migration Services, Data Box, and Azure Stack Edge. |
| Monitor | 22 | Alert rules, Application Insights, data collection rules, diagnostic settings, and Log Analytics. |
| Networking | 21 | Virtual networks, NSGs, load balancers, gateways, Front Door, Firewall, Bastion, and ExpressRoute. |
| Security | 17 | Defender for Cloud, Key Vault and its secret/key expiry, Sentinel, HSMs, WAF and DDoS policies, and Entra Domain Services. |
| Storage | 11 | Storage accounts and their containers, shares and lifecycle policies; NetApp Files, snapshots, encryption sets, and Elastic SAN. |
| Web | 14 | App Services and plans, Function Apps, slots, Static Web Apps, SignalR, Web PubSub, and Communication Services. |
| **Total** | **242** | across all 18 of Microsoft's published service categories |

## AI Category (27 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AIFoundryHubs | `microsoft.machinelearningservices/workspaces` | AI Foundry Hubs |
| AIFoundryProjects | `microsoft.machinelearningservices/workspaces` | AI Foundry Projects |
| AppliedAIServices | `microsoft.cognitiveservices/accounts` | Applied AI Services |
| AzureAI | `microsoft.cognitiveservices/accounts` | Azure AI |
| BotServices | `microsoft.botservice/botservices` | Bot Services |
| ComputerVision | `microsoft.cognitiveservices/accounts` | Computer Vision |
| ContentModerator | `microsoft.cognitiveservices/accounts` | Content Moderator |
| ContentSafety | `microsoft.cognitiveservices/accounts` | Content Safety |
| CustomVision | `microsoft.cognitiveservices/accounts` | Custom Vision |
| FaceAPI | `microsoft.cognitiveservices/accounts` | Face API |
| FormRecognizer | `microsoft.cognitiveservices/accounts` | Doc Intelligence |
| HealthInsights | `microsoft.cognitiveservices/accounts` | Health Insights |
| ImmersiveReader | `microsoft.cognitiveservices/accounts` | Immersive Reader |
| MachineLearning | `microsoft.machinelearningservices/workspaces` | Machine Learning |
| MLComputes | `AZSC/ARMChild/MLComputes` | ML Compute |
| MLDatasets | `AZSC/ARMChild/MLDatasets` | ML Datasets |
| MLDatastores | `AZSC/ARMChild/MLDatastores` | ML Datastores |
| MLEndpoints | `AZSC/ARMChild/MLEndpoints` | ML Endpoints |
| MLModels | `AZSC/ARMChild/MLModels` | ML Models |
| MLPipelines | `AZSC/ARMChild/MLPipelines` | ML Pipelines |
| OpenAIAccounts | `microsoft.cognitiveservices/accounts` | OpenAI Accounts |
| OpenAIDeployments | `AZSC/ARMChild/OpenAIDeployments` | OpenAI Deployments |
| SearchIndexes | `AZSC/ARMChild/SearchIndexes` | Search Indexes |
| SearchServices | `microsoft.search/searchservices` | Search Services |
| SpeechService | `microsoft.cognitiveservices/accounts` | Speech Service |
| TextAnalytics | `microsoft.cognitiveservices/accounts` | Language |
| Translator | `microsoft.cognitiveservices/accounts` | Translator |

## Analytics Category (6 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| Databricks | `microsoft.databricks/workspaces` | Databricks |
| DataExplorerCluster | `microsoft.kusto/clusters` | Data Explorer Clusters |
| EvtHub | `microsoft.eventhub/namespaces` | Event Hubs |
| Purview | `microsoft.purview/accounts` | Purview |
| Streamanalytics | `microsoft.streamanalytics/streamingjobs` | Stream Analytics Jobs |
| Synapse | `microsoft.synapse/workspaces` | Synapse |

## Compute Category (13 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AvailabilitySets | `microsoft.compute/availabilitysets` | Availability Sets |
| AVD | `microsoft.desktopvirtualization/hostpools` | AVD |
| AVDApplicationGroups | `microsoft.desktopvirtualization/applicationgroups` | AVD Application Groups |
| AVDApplications | `AZSC/ARMChild/AVDApplications` | AVD Applications |
| AVDAzureLocal | `AZSC/AVD/AzureLocalSessionHost` | AVD on Azure Local Arc |
| AVDScalingPlans | `microsoft.desktopvirtualization/scalingplans` | AVD Scaling Plans |
| AVDSessionHosts | `microsoft.desktopvirtualization/hostpools/sessionhosts` | AVD Session Hosts |
| AVDWorkspaces | `microsoft.desktopvirtualization/workspaces` | AVD Workspaces |
| VirtualMachine | `microsoft.compute/virtualmachines` | Virtual Machines |
| VirtualMachineScaleSet | `microsoft.compute/virtualmachinescalesets` | Virtual Machine Scale Sets |
| VMDisk | `microsoft.compute/disks` | Disks |
| VMOperationalData | `microsoft.compute/virtualmachines` | VM Operational Data |
| VMWare | `Microsoft.AVS/privateClouds` | VMWare |

## Containers Category (6 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AKS | `microsoft.containerservice/managedclusters` | AKS |
| ARO | `microsoft.redhatopenshift/openshiftclusters` | ARO |
| ContainerApp | `microsoft.app/containerapps` | Container Apps |
| ContainerAppEnv | `microsoft.app/managedenvironments` | Container App Env |
| ContainerGroups | `microsoft.containerinstance/containergroups` | Containers |
| ContainerRegistries | `microsoft.containerregistry/registries` | Registries |

## Databases Category (12 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| CosmosDB | `microsoft.documentdb/databaseaccounts` | Cosmos DB |
| MariaDB | `microsoft.dbformariadb/servers` | MariaDB |
| MySQL | `microsoft.dbformysql/servers` | MySQL |
| MySQLflexible | `Microsoft.DBforMySQL/flexibleServers` | MySQL Flexible |
| POSTGREFlexible | `Microsoft.DBforPostgreSQL/flexibleServers` | PostgreSQL Flexible |
| RedisCache | `microsoft.cache/redis` · `microsoft.cache/redisenterprise` | Redis Cache |
| SQLDB | `microsoft.sql/servers/databases` | SQL DBs |
| SQLMI | `microsoft.sql/managedInstances` | SQL MI |
| SQLMIDB | `microsoft.sql/managedinstances/databases` | SQL MI DBs |
| SQLPOOL | `microsoft.sql/servers/elasticPools` | SQL Pools |
| SQLSERVER | `microsoft.sql/servers` | SQL Servers |
| SQLVM | `microsoft.sqlvirtualmachine/sqlvirtualmachines` | SQL VMs |

## DevOps Category (17 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| ApiConnections | `microsoft.web/connections` | API Connections |
| AppConfiguration | `microsoft.appconfiguration/configurationstores` | App Configuration |
| ChaosStudio | `microsoft.chaos/experiments` · `microsoft.chaos/targets` | Chaos Studio |
| DeploymentEnvironments | `microsoft.devcenter/devcenters/environmenttypes` · `microsoft.devcenter/projects/environmenttypes` · `microsoft.devcenter/devcenters/catalogs` · `microsoft.devcenter/projects/catalogs` | Deployment Environments |
| DevBoxPools | `microsoft.devcenter/projects/pools` | Dev Box Pools |
| DevCenterNetworkConnections | `microsoft.devcenter/networkconnections` | Dev Center Network Conns |
| DevCenters | `microsoft.devcenter/devcenters` · `microsoft.devcenter/projects` | Dev Centers |
| DevOpsAgentPools | `devops/agentpools` | ADO Agent Pools |
| DevOpsPipelines | `devops/pipelines` | ADO Pipelines |
| DevOpsProjects | `devops/projects` | ADO Projects |
| DevOpsRepositories | `devops/repositories` | ADO Repositories |
| DevOpsServiceConnections | `devops/serviceconnections` | ADO Service Connections |
| DevTestLabs | `microsoft.devtestlab/labs` · `microsoft.devtestlab/schedules` | DevTest Labs |
| LabServices | `microsoft.labservices/labs` · `microsoft.labservices/labplans` | Lab Services |
| LoadTesting | `microsoft.loadtestservice/loadtests` | Load Testing |
| ManagedDevOpsPools | `microsoft.devopsinfrastructure/pools` | Managed DevOps Pools |
| PlaywrightTesting | `microsoft.azureplaywrightservice/accounts` | Playwright Workspaces |

## General Category (5 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| Quotas | `AZSC/VM/Quotas` | Quotas |
| ReservationRecom | `Microsoft.Consumption/reservationRecommendations` | Reservation Advisor |
| Reservations | `microsoft.capacity/reservationorders` · `microsoft.capacity/reservationorders/reservations` | Reservations |
| ReservationUtilization | `AZSC/ARMChild/ReservationUtilization` | Reservation Utilization |
| SupportTickets | `Microsoft.Support/supportTickets` | Support Tickets |

## Hybrid Category (16 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| ArcDataControllers | `microsoft.azurearcdata/datacontrollers` | Arc Data Controllers |
| ArcExtensions | `microsoft.hybridcompute/machines/extensions` | Arc Extensions |
| ArcGateways | `microsoft.hybridcompute/gateways` | Arc Gateways |
| ArcKubernetes | `microsoft.kubernetes/connectedclusters` | Arc Kubernetes |
| ArcResourceBridge | `microsoft.resourceconnector/appliances` | Arc Resource Bridge |
| ArcServerOperationalData | `microsoft.hybridcompute/machines` | Arc Server Operational Data |
| ARCServers | `microsoft.hybridcompute/machines` | ARC Servers |
| ArcSites | `AZSC/ARMChild/ArcSites` | Arc Sites |
| ArcSQLManagedInstances | `microsoft.azurearcdata/sqlmanagedinstances` | Arc SQL Managed Instances |
| ArcSQLServers | `microsoft.azurearcdata/sqlserverinstances` | Arc SQL Servers |
| Clusters | `microsoft.azurestackhci/clusters` | AzLocal Clusters |
| GalleryImages | `microsoft.azurestackhci/galleryimages` | AzLocal Images |
| LogicalNetworks | `microsoft.azurestackhci/logicalnetworks` | AzLocal Networks |
| MarketplaceGalleryImages | `microsoft.azurestackhci/marketplacegalleryimages` | AzLocal Marketplace |
| StorageContainers | `microsoft.azurestackhci/storagecontainers` | AzLocal Storage |
| VirtualMachines | `AZSC/ARMChild/AzureLocalVirtualMachineInstances` | AzLocal VMs |

## Identity Category (17 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AdminUnits | `entra/administrativeunits` | Admin Units |
| AppRegistrations | `entra/applications` | App Registrations |
| ConditionalAccess | `entra/conditionalaccesspolicies` | Conditional Access |
| CrossTenantAccess | `entra/crosstenantaccess` | Cross-Tenant Access |
| DirectoryRoles | `entra/directoryroles` | Directory Roles |
| Domains | `entra/domains` | Entra Domains |
| Groups | `entra/groups` | Entra Groups |
| Licensing | `entra/subscribedskus` | Licensing |
| ManagedIdentities | `entra/managedidentities` | Managed Identities |
| ManagedIds | `Microsoft.ManagedIdentity/userAssignedIdentities` | Managed Identity |
| NamedLocations | `entra/namedlocations` | Named Locations |
| PIMAssignments | `entra/pimassignments` | PIM Assignments |
| RiskyUsers | `entra/riskyusers` | Risky Users |
| RoleAssignments | `AZSC/Governance/RoleAssignment` | Role Assignments |
| SecurityPolicies | `entra/securitypolicies` | Security Policies |
| ServicePrincipals | `entra/serviceprincipals` | Service Principals |
| Users | `entra/users` | Entra Users |

## Integration Category (9 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| APIM | `microsoft.apimanagement/service` | APIM |
| EventGrid | `microsoft.eventgrid/topics` · `microsoft.eventgrid/systemtopics` · `microsoft.eventgrid/domains` · `microsoft.eventgrid/partnertopics` · `microsoft.eventgrid/namespaces` | Event Grid |
| EventHubClusters | `microsoft.eventhub/clusters` | Event Hubs Clusters |
| HealthDataServices | `microsoft.healthcareapis/services` · `microsoft.healthcareapis/workspaces` · `microsoft.healthcareapis/workspaces/fhirservices` · `microsoft.healthcareapis/workspaces/dicomservices` · `microsoft.healthcareapis/workspaces/iotconnectors` | Health Data Services |
| IntegrationAccounts | `microsoft.logic/integrationaccounts` · `microsoft.logic/integrationserviceenvironments` | Integration Accounts |
| LogicApps | `microsoft.logic/workflows` | Logic Apps |
| LogicAppsCustomConnectors | `microsoft.web/customapis` | Logic Apps Connectors |
| Relays | `microsoft.relay/namespaces` · `microsoft.relay/namespaces/hybridconnections` · `microsoft.relay/namespaces/wcfrelays` | Relays |
| ServiceBUS | `microsoft.servicebus/namespaces` | Service BUS |

## IoT Category (7 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| DefenderForIoT | `microsoft.iotsecurity/defendersettings` · `microsoft.iotsecurity/sites` · `microsoft.iotsecurity/sensors` · `microsoft.iotsecurity/onpremisesensors` | Defender for IoT |
| DeviceProvisioningServices | `microsoft.devices/provisioningservices` | IoT DPS |
| DeviceUpdate | `microsoft.deviceupdate/accounts` · `microsoft.deviceupdate/accounts/instances` | Device Update |
| DigitalTwins | `microsoft.digitaltwins/digitaltwinsinstances` · `microsoft.digitaltwins/digitaltwinsinstances/endpoints` · `microsoft.digitaltwins/digitaltwinsinstances/timeseriesdatabaseconnections` | Digital Twins |
| IoTCentral | `microsoft.iotcentral/iotapps` | IoT Central |
| IOTHubs | `microsoft.devices/iothubs` | IOTHubs |
| Maps | `microsoft.maps/accounts` · `microsoft.maps/accounts/creators` | Azure Maps |

## Management Category (16 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AdvisorScore | `Microsoft.Advisor/advisorScore` | AdvisorScore |
| AllSubscriptions | `AZSC/Management/SubscriptionEnrichment` | All Subscriptions |
| AutomationAccounts | `microsoft.automation/automationaccounts` | Runbooks |
| Backup | `microsoft.recoveryservices/vaults/backuppolicies` | Backup |
| BackupInstances | `AZSC/ARMChild/BackupInstances` | Backup Instances |
| Budgets | `AZSC/Governance/Budget` | Budgets |
| CustomRoleDefinitions | `AZSC/Management/RoleDefinition` | Custom Roles |
| LighthouseDelegations | `Microsoft.ManagedServices/registrationDefinitions` | Lighthouse Delegations |
| MaintenanceConfigurations | `microsoft.maintenance/maintenanceconfigurations` | Maintenance Configs |
| ManagementGroups | `AZSC/Management/ManagementGroup` | Management Groups |
| PolicyAssignments | `AZSC/Governance/PolicyAssignment` | Policy Assignments |
| PolicyComplianceStates | `AZSC/Subscription/SecurityPolicySweep` | Policy Compliance |
| PolicyDefinitions | `AZSC/Management/PolicyDefinition` | Policy Definitions |
| PolicySetDefinitions | `AZSC/Management/PolicySetDefinition` | Policy Initiatives |
| RecoveryVault | `microsoft.recoveryservices/vaults` | Recovery Vaults |
| ResourceLocks | `AZSC/Governance/ResourceLock` | Resource Locks |

## Migration Category (6 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AzureMigrateAssessments | `microsoft.migrate/assessmentprojects` | Migrate Assessment Projects |
| AzureMigrateDiscoverySites | `microsoft.offazure/vmwaresites` · `microsoft.offazure/hypervsites` · `microsoft.offazure/serversites` · `microsoft.offazure/mastersites` | Migrate Discovery Sites |
| AzureMigrateProjects | `microsoft.migrate/migrateprojects` | Migrate Projects |
| DatabaseMigrationServices | `microsoft.datamigration/services` · `microsoft.datamigration/sqlmigrationservices` | Database Migration Services |
| DataBox | `microsoft.databox/jobs` | Data Box Jobs |
| StackEdge | `microsoft.databoxedge/databoxedgedevices` | Stack Edge Devices |

## Monitor Category (22 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| ActionGroups | `microsoft.insights/actiongroups` | Action Groups |
| ActivityLogAlertRules | `microsoft.insights/activitylogalerts` | Activity Log Alerts |
| AppInsights | `microsoft.insights/components` | AppInsights |
| AppInsightsAvailabilityTests | `microsoft.insights/webtests` | App Insights Availability Tests |
| AppInsightsProactiveDetection | `AZSC/ARMChild/AppInsightsProactiveDetection` | App Insights ProactiveDetection |
| AppInsightsWebTests | `microsoft.insights/webtests` | App Insights Web Tests |
| AutoscaleSettings | `microsoft.insights/autoscalesettings` | Autoscale Settings |
| DataCollectionEndpoints | `microsoft.insights/datacollectionendpoints` | Data Collection Endpoints |
| DataCollectionRules | `microsoft.insights/datacollectionrules` | Data Collection Rules |
| LAWorkspaceLinkedServices | `AZSC/ARMChild/LAWorkspaceLinkedServices` | LA Linked Services |
| LAWorkspaceSavedSearches | `AZSC/ARMChild/LAWorkspaceSavedSearches` | LA Saved Searches |
| LAWorkspaceSolutions | `microsoft.operationsmanagement/solutions` | LA Solutions |
| MetricAlertRules | `microsoft.insights/metricalerts` | Metric Alerts |
| MonitorMetricsIngestion | `microsoft.operationalinsights/workspaces` | Monitor Metrics Ingestion |
| MonitorPrivateLinkScopes | `microsoft.insights/privatelinkscopes` | Monitor Private Link Scopes |
| MonitorWorkbooks | `microsoft.insights/workbooks` | Monitor Workbooks |
| Outages | `AZSC/Monitor/Outage` | Outages |
| ResourceDiagnosticSettings | `AZSC/ARMChild/ResourceDiagnosticSettings` | Resource Diagnostic Settings |
| ScheduledQueryRules | `microsoft.insights/scheduledqueryrules` | Scheduled Queries |
| SmartDetectorAlertRules | `microsoft.alertsmanagement/smartdetectoralertrules` | Smart Detector Alerts |
| SubscriptionDiagnosticSettings | `AZSC/Subscription/SecurityPolicySweep` | Subscription Diagnostics |
| Workspaces | `microsoft.operationalinsights/workspaces` | Workspaces |

## Networking Category (21 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| ApplicationGateways | `microsoft.network/applicationgateways` | App Gateway |
| AzureFirewall | `microsoft.network/azurefirewalls` | Azure Firewall |
| BastionHosts | `microsoft.network/bastionhosts` | Bastion Hosts |
| Connections | `microsoft.network/connections` | Connections |
| ExpressRoute | `microsoft.network/expressroutecircuits` | Express Route |
| Frontdoor | `microsoft.network/frontdoors` | FrontDoor |
| LoadBalancer | `microsoft.network/loadbalancers` | Load Balancers |
| NATGateway | `microsoft.network/natgateways` | NAT Gateway |
| NetworkInterface | `microsoft.network/networkinterfaces` | Network Interface |
| NetworkSecurityGroup | `microsoft.network/networksecuritygroups` | Network Security Groups |
| NetworkWatchers | `microsoft.network/networkwatchers` | Network Watchers |
| PrivateDNS | `microsoft.network/privatednszones` | Private DNS |
| PrivateEndpoint | `microsoft.network/privateendpoints` | Private Endpoint |
| PublicDNS | `microsoft.network/dnszones` | Public DNS |
| PublicIP | `microsoft.network/publicipaddresses` | Public IPs |
| RouteTables | `microsoft.network/routetables` | Route Tables |
| TrafficManager | `microsoft.network/trafficmanagerprofiles` | Traffic Manager |
| VirtualNetwork | `microsoft.network/virtualnetworks` | Virtual Networks |
| VirtualNetworkGateways | `microsoft.network/virtualnetworkgateways` | VNET Gateways |
| VirtualWAN | `microsoft.network/virtualwans` | Virtual WAN |
| vNETPeering | `microsoft.network/virtualnetworks` | Peering |

## Security Category (17 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AppComplianceAutomation | `microsoft.appcomplianceautomation/reports` · `microsoft.appcomplianceautomation/reports/snapshots` | App Compliance Automation |
| ApplicationSecurityGroups | `microsoft.network/applicationsecuritygroups` | App Security Groups |
| ArtifactSigning | `microsoft.codesigning/codesigningaccounts` | Artifact Signing |
| CloudHSM | `microsoft.hardwaresecuritymodules/cloudhsmclusters` | Cloud HSM |
| ConfidentialLedger | `microsoft.confidentialledger/ledgers` | Confidential Ledger |
| DdosProtectionPlans | `microsoft.network/ddosprotectionplans` | DDoS Protection Plans |
| DefenderAlerts | `AZSC/Subscription/SecurityPolicySweep` | Defender Alerts |
| DefenderAssessments | `AZSC/Subscription/SecurityPolicySweep` | Defender Assessments |
| DefenderPricing | `AZSC/Subscription/SecurityPolicySweep` | Defender Pricing |
| DefenderSecureScore | `AZSC/Subscription/SecurityPolicySweep` | Defender Secure Score |
| EntraDomainServices | `microsoft.aad/domainservices` | Entra Domain Services |
| KeyVaultKeys | `AZSC/ARMChild/KeyVaultKeys` | Key Vault Keys |
| KeyVaultSecrets | `AZSC/ARMChild/KeyVaultSecrets` | Key Vault Secrets |
| ManagedHSM | `microsoft.keyvault/managedhsms` | Managed HSM |
| Sentinel | `microsoft.operationsmanagement/solutions` · `microsoft.securityinsights/onboardingstates` | Sentinel |
| Vault | `microsoft.keyvault/vaults` | Key Vaults |
| WafPolicies | `microsoft.network/applicationgatewaywebapplicationfirewallpolicies` · `microsoft.network/frontdoorwebapplicationfirewallpolicies` · `microsoft.cdn/cdnwebapplicationfirewallpolicies` | WAF Policies |

## Storage Category (11 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| BlobContainers | `AZSC/ARMChild/StorageBlobContainers` | Blob Containers |
| DiskEncryptionSets | `microsoft.compute/diskencryptionsets` | Disk Encryption Sets |
| EdgeHardwareCenter | `microsoft.edgeorder/orders` · `microsoft.edgeorder/orderitems` · `microsoft.edgeorder/addresses` | Edge Hardware Center |
| ElasticSan | `microsoft.elasticsan/elasticsans` · `microsoft.elasticsan/elasticsans/volumegroups` | Elastic SAN |
| FileShares | `AZSC/ARMChild/StorageFileShares` | File Shares |
| LifecyclePolicies | `AZSC/ARMChild/StorageLifecyclePolicies` | Storage Lifecycle Policies |
| NetApp | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` | NetApp |
| PartnerStorage | `purestorage.block/storagepools` · `purestorage.block/reservations` · `qumulo.storage/filesystems` | Partner Storage Services |
| Snapshots | `microsoft.compute/snapshots` | Snapshots |
| StorageAccounts | `microsoft.storage/storageaccounts` | Storage Accounts |
| StorageSync | `microsoft.storagesync/storagesyncservices` · `microsoft.storagesync/storagesyncservices/syncgroups` · `microsoft.storagesync/storagesyncservices/registeredservers` | Storage Sync Services |

## Web Category (14 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AppServiceCertificates | `microsoft.certificateregistration/certificateorders` · `microsoft.web/certificates` | App Service Certificates |
| AppServiceDomains | `microsoft.domainregistration/domains` | App Service Domains |
| AppServiceEnvironments | `microsoft.web/hostingenvironments` | App Service Environments |
| APPServicePlan | `microsoft.web/serverfarms` | App Service Plan |
| APPServices | `microsoft.web/sites` | App Services |
| CommunicationServices | `microsoft.communication/communicationservices` · `microsoft.communication/emailservices` · `microsoft.communication/emailservices/domains` | Communication Services |
| DeploymentSlots | `microsoft.web/sites/slots` | Deployment Slots |
| FluidRelay | `microsoft.fluidrelay/fluidrelayservers` | Fluid Relay |
| FunctionApps | `microsoft.web/sites` | Function Apps |
| NotificationHubs | `microsoft.notificationhubs/namespaces` · `microsoft.notificationhubs/namespaces/notificationhubs` | Notification Hubs |
| SignalR | `microsoft.signalrservice/signalr` | SignalR |
| SpringApps | `microsoft.appplatform/spring` · `microsoft.appplatform/spring/apps` | Spring Apps |
| StaticWebApps | `microsoft.web/staticsites` | Static Web Apps |
| WebPubSub | `microsoft.signalrservice/webpubsub` | Web PubSub |

