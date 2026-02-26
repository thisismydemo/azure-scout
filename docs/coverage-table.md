---
description: Every AzureScout inventory module, the Azure resource type it covers, and the Excel worksheet it writes to.
---

# Coverage Table

This page lists every inventory module in AzureScout, the Azure resource type(s) it covers, and the Excel worksheet it writes to.

## Coverage Summary

| Category | Modules | Notes |
|----------|---------|-------|
| AI | 27 | Cognitive Services, OpenAI, ML, Bot Services, AI Foundry |
| Analytics | 6 | Synapse, Databricks, Event Hub, Purview, Stream Analytics |
| Compute | 14 | VMs, VMSS, Disks, AVD, CloudServices, VMware |
| Containers | 6 | AKS, ARO, Container Apps, Container Registry |
| Databases | 13 | SQL, PostgreSQL, MySQL, Cosmos DB, Redis |
| Hybrid | 16 | Arc Servers, Arc Kubernetes, Azure Local, Arc Gateways |
| Identity | 18 | Users, Groups, Apps, Roles, PIM, Conditional Access |
| Integration | 2 | API Management, Service Bus |
| IoT | 1 | IoT Hub |
| Management | 14 | Advisor, Backup, Policy, Subscriptions, Recovery Vault |
| Monitor | 24 | App Insights, DCRs, Action Groups, Alert Rules, Workspaces |
| Networking | 21 | VNets, NSGs, Load Balancers, VPN, Firewall, Front Door |
| Security | 5 | Defender Alerts, Assessments, Secure Score, Key Vault |
| Storage | 2 | Storage Accounts, NetApp Files |
| Web | 2 | App Service, App Service Plans |
| **Total** | **171** | |

## AI Category (27 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| AIFoundryHubs | `Microsoft.MachineLearningServices/workspaces` (kind=Hub) | AI Foundry Hubs |
| AIFoundryProjects | `Microsoft.MachineLearningServices/workspaces` (kind=Project) | AI Foundry Projects |
| AppliedAIServices | `Microsoft.CognitiveServices/accounts` (Applied AI) | Applied AI Services |
| AzureAI | `Microsoft.CognitiveServices/accounts` | Cognitive Services |
| BotServices | `Microsoft.BotService/botServices` | Bot Services |
| ComputerVision | `Microsoft.CognitiveServices/accounts` (computerVision) | Computer Vision |
| ContentModerator | `Microsoft.CognitiveServices/accounts` (ContentModerator) | Content Moderator |
| ContentSafety | `Microsoft.CognitiveServices/accounts` (ContentSafety) | Content Safety |
| CustomVision | `Microsoft.CognitiveServices/accounts` (CustomVision) | Custom Vision |
| FaceAPI | `Microsoft.CognitiveServices/accounts` (Face) | Face API |
| FormRecognizer | `Microsoft.CognitiveServices/accounts` (FormRecognizer) | Form Recognizer |
| HealthInsights | `Microsoft.HealthInsights/imagingStudies` | Health Insights |
| ImmersiveReader | `Microsoft.CognitiveServices/accounts` (ImmersiveReader) | Immersive Reader |
| MachineLearning | `Microsoft.MachineLearningServices/workspaces` | ML Workspaces |
| MLComputes | `Microsoft.MachineLearningServices/workspaces/computes` | ML Computes |
| MLDatasets | ML Datasets API | ML Datasets |
| MLDatastores | ML Datastores API | ML Datastores |
| MLEndpoints | ML Online Endpoints API | ML Endpoints |
| MLModels | ML Models API | ML Models |
| MLPipelines | ML Pipeline Jobs API | ML Pipelines |
| OpenAIAccounts | `Microsoft.CognitiveServices/accounts` (OpenAI) | OpenAI Accounts |
| OpenAIDeployments | OpenAI Deployments API | OpenAI Deployments |
| SearchIndexes | Azure Search Indexes API | Search Indexes |
| SearchServices | `Microsoft.Search/searchServices` | Search Services |
| SpeechService | `Microsoft.CognitiveServices/accounts` (SpeechServices) | Speech Services |
| TextAnalytics | `Microsoft.CognitiveServices/accounts` (TextAnalytics) | Text Analytics |
| Translator | `Microsoft.CognitiveServices/accounts` (TextTranslation) | Translator |

## Compute Category (14 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| VirtualMachine | `Microsoft.Compute/virtualMachines` | Virtual Machines |
| VirtualMachineScaleSet | `Microsoft.Compute/virtualMachineScaleSets` | VM Scale Sets |
| VMDisk | `Microsoft.Compute/disks` | Managed Disks |
| AvailabilitySets | `Microsoft.Compute/availabilitySets` | Availability Sets |
| AVD | `Microsoft.DesktopVirtualization/hostpools` | AVD Host Pools |
| AVDSessionHosts | AVD Session Hosts API | AVD Session Hosts |
| AVDApplicationGroups | `Microsoft.DesktopVirtualization/applicationgroups` | AVD App Groups |
| AVDApplications | AVD Applications API | AVD Applications |
| AVDWorkspaces | `Microsoft.DesktopVirtualization/workspaces` | AVD Workspaces |
| AVDScalingPlans | `Microsoft.DesktopVirtualization/scalingplans` | AVD Scaling Plans |
| AVDAzureLocal | Arc Machines + HCI VMs (AVD on Azure Local) | AVD on Azure Local/Arc |
| CloudServices | `Microsoft.Compute/cloudServices` | Cloud Services |
| VMWare | `Microsoft.ConnectedVMwarevSphere/virtualMachines` | VMware VMs |
| VMOperationalData | *(operational enrichment)* | VM Operational Data |

## Hybrid Category (16 modules)

| Module | Resource Type | Worksheet |
|--------|---------------|-----------|
| ARCServers | `Microsoft.HybridCompute/machines` | Arc Servers |
| ArcExtensions | `Microsoft.HybridCompute/machines/extensions` | Arc Extensions |
| ArcGateways | `Microsoft.HybridCompute/gateways` | Arc Gateways |
| ArcKubernetes | `Microsoft.Kubernetes/connectedClusters` | Arc Kubernetes |
| ArcResourceBridge | `Microsoft.ResourceConnector/appliances` | Arc Resource Bridge |
| ArcDataControllers | `Microsoft.AzureArcData/dataControllers` | Arc Data Controllers |
| ArcSQLServers | `Microsoft.AzureArcData/sqlServerInstances` | Arc SQL Servers |
| ArcSQLManagedInstances | `Microsoft.AzureArcData/sqlManagedInstances` | Arc SQL Managed Instances |
| ArcSites | `Microsoft.ExtendedLocation/customLocations` | Arc Sites |
| ArcServerOperationalData | *(enrichment)* | Arc Server Operational Data |
| Clusters | `Microsoft.AzureStackHCI/clusters` | Azure Local Clusters |
| VirtualMachines | `Microsoft.AzureStackHCI/virtualMachineInstances` | Azure Local VMs |
| LogicalNetworks | `Microsoft.AzureStackHCI/logicalNetworks` | Azure Local Networks |
| StorageContainers | `Microsoft.AzureStackHCI/storageContainers` | Azure Local Storage |
| GalleryImages | `Microsoft.AzureStackHCI/galleryImages` | Azure Local Gallery |
| MarketplaceGalleryImages | `Microsoft.AzureStackHCI/marketplaceGalleryImages` | Azure Local Marketplace |

## Networking Category (21 modules)

| Module | Resource Type |
|--------|---------------|
| VirtualNetwork | `Microsoft.Network/virtualNetworks` |
| vNETPeering | `Microsoft.Network/virtualNetworks/virtualNetworkPeerings` |
| NetworkSecurityGroup | `Microsoft.Network/networkSecurityGroups` |
| NetworkInterface | `Microsoft.Network/networkInterfaces` |
| PublicIP | `Microsoft.Network/publicIPAddresses` |
| LoadBalancer | `Microsoft.Network/loadBalancers` |
| ApplicationGateways | `Microsoft.Network/applicationGateways` |
| VirtualNetworkGateways | `Microsoft.Network/virtualNetworkGateways` |
| Connections | `Microsoft.Network/connections` |
| ExpressRoute | `Microsoft.Network/expressRouteCircuits` |
| AzureFirewall | `Microsoft.Network/azureFirewalls` |
| BastionHosts | `Microsoft.Network/bastionHosts` |
| NATGateway | `Microsoft.Network/natGateways` |
| PrivateEndpoint | `Microsoft.Network/privateEndpoints` |
| PrivateDNS | `Microsoft.Network/privateDnsZones` |
| PublicDNS | `Microsoft.Network/dnsZones` |
| RouteTables | `Microsoft.Network/routeTables` |
| NetworkWatchers | `Microsoft.Network/networkWatchers` |
| Frontdoor | `Microsoft.Network/frontDoors` |
| TrafficManager | `Microsoft.Network/trafficManagerProfiles` |
| VirtualWAN | `Microsoft.Network/virtualWans` |

*Last updated: February 2026. See [Category Structure](category-structure.md) for folder mapping details.*
