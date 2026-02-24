# Azure Tenant Inventory — Coverage Table

This document lists every inventory module in AZSC, the Azure resource type(s) it covers, and the Excel worksheet it writes to.

## Coverage Summary

| Category | Modules | Notes |
|----------|--------:|-------|
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
|--------|--------------|-----------|
| AIFoundryHubs | Microsoft.MachineLearningServices/workspaces (kind=Hub) | AI Foundry Hubs |
| AIFoundryProjects | Microsoft.MachineLearningServices/workspaces (kind=Project) | AI Foundry Projects |
| AppliedAIServices | Microsoft.CognitiveServices/accounts (Applied AI) | Applied AI Services |
| AzureAI | Microsoft.CognitiveServices/accounts | Cognitive Services |
| BotServices | Microsoft.BotService/botServices | Bot Services |
| ComputerVision | Microsoft.CognitiveServices/accounts (computerVision) | Computer Vision |
| ContentModerator | Microsoft.CognitiveServices/accounts (ContentModerator) | Content Moderator |
| ContentSafety | Microsoft.CognitiveServices/accounts (ContentSafety) | Content Safety |
| CustomVision | Microsoft.CognitiveServices/accounts (CustomVision) | Custom Vision |
| FaceAPI | Microsoft.CognitiveServices/accounts (Face) | Face API |
| FormRecognizer | Microsoft.CognitiveServices/accounts (FormRecognizer) | Form Recognizer |
| HealthInsights | Microsoft.HealthInsights/imagingStudies | Health Insights |
| ImmersiveReader | Microsoft.CognitiveServices/accounts (ImmersiveReader) | Immersive Reader |
| MachineLearning | Microsoft.MachineLearningServices/workspaces | ML Workspaces |
| MLComputes | Microsoft.MachineLearningServices/workspaces/computes | ML Computes |
| MLDatasets | ML Datasets API | ML Datasets |
| MLDatastores | ML Datastores API | ML Datastores |
| MLEndpoints | ML Online Endpoints API | ML Endpoints |
| MLModels | ML Models API | ML Models |
| MLPipelines | ML Pipeline Jobs API | ML Pipelines |
| OpenAIAccounts | Microsoft.CognitiveServices/accounts (OpenAI) | OpenAI Accounts |
| *(+ more)* | | |

## Compute Category (14 modules)

| Module | Resource Type | Worksheet |
|--------|--------------|-----------|
| VirtualMachine | Microsoft.Compute/virtualMachines | Virtual Machines |
| VirtualMachineScaleSet | Microsoft.Compute/virtualMachineScaleSets | VM Scale Sets |
| VMDisk | Microsoft.Compute/disks | Managed Disks |
| AvailabilitySets | Microsoft.Compute/availabilitySets | Availability Sets |
| AVD | Microsoft.DesktopVirtualization/hostpools | AVD Host Pools |
| AVDSessionHosts | AVD Session Hosts API | AVD Session Hosts |
| AVDApplicationGroups | Microsoft.DesktopVirtualization/applicationgroups | AVD App Groups |
| AVDApplications | AVD Applications API | AVD Applications |
| AVDWorkspaces | Microsoft.DesktopVirtualization/workspaces | AVD Workspaces |
| AVDScalingPlans | Microsoft.DesktopVirtualization/scalingplans | AVD Scaling Plans |
| AVDAzureLocal | Arc Machines + HCI VMs (AVD on Azure Local) | AVD on Azure Local/Arc |
| CloudServices | Microsoft.Compute/cloudServices | Cloud Services |
| VMWare | Microsoft.ConnectedVMwarevSphere/virtualMachines | VMware VMs |
| VMOperationalData | *(operational enrich)* | VM Operational Data |

## Hybrid Category (16 modules)

| Module | Resource Type | Worksheet |
|--------|--------------|-----------|
| ARCServers | Microsoft.HybridCompute/machines | Arc Servers |
| ArcExtensions | Microsoft.HybridCompute/machines/extensions | Arc Extensions |
| ArcGateways | Microsoft.HybridCompute/gateways | Arc Gateways |
| ArcKubernetes | Microsoft.Kubernetes/connectedClusters | Arc Kubernetes |
| ArcResourceBridge | Microsoft.ResourceConnector/appliances | Arc Resource Bridge |
| ArcDataControllers | Microsoft.AzureArcData/dataControllers | Arc Data Controllers |
| ArcSQLServers | Microsoft.AzureArcData/sqlServerInstances | Arc SQL Servers |
| ArcSQLManagedInstances | Microsoft.AzureArcData/sqlManagedInstances | Arc SQL MIs |
| ArcSites | Microsoft.ExtendedLocation/customLocations | Arc Sites |
| ArcServerOperationalData | *(enrichment)* | Arc Server Operational |
| Clusters | Microsoft.AzureStackHCI/clusters | Azure Local Clusters |
| VirtualMachines | Microsoft.AzureStackHCI/virtualMachineInstances | Azure Local VMs |
| LogicalNetworks | Microsoft.AzureStackHCI/logicalNetworks | Azure Local Networks |
| StorageContainers | Microsoft.AzureStackHCI/storageContainers | Azure Local Storage |
| GalleryImages | Microsoft.AzureStackHCI/galleryImages | Azure Local Gallery |
| MarketplaceGalleryImages | Microsoft.AzureStackHCI/marketplaceGalleryImages | Azure Local Marketplace |

---

*Generated from AZSC module inventory. Last updated: February 2026.*
