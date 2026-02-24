---
ArtifactType: Excel spreadsheet and JSON with full Azure tenant inventory
Language: PowerShell
Platform: Windows / Linux / Mac
Tags: PowerShell, Azure, Inventory, Entra ID, Excel Report, JSON
---

<div align="center">

![AzureScout](https://raw.githubusercontent.com/thisismydemo/azure-scout/main/docs/modules/ROOT/images/azurescout-banner.svg)

# AzureScout

### See everything. Own your cloud.

[![GitHub](https://img.shields.io/github/license/thisismydemo/azure-scout)](https://github.com/thisismydemo/azure-scout/blob/main/LICENSE)
[![GitHub repo size](https://img.shields.io/github/repo-size/thisismydemo/azure-scout)](https://github.com/thisismydemo/azure-scout)
[![GitHub last commit](https://img.shields.io/github/last-commit/thisismydemo/azure-scout)](https://github.com/thisismydemo/azure-scout/commits/main)
[![GitHub top language](https://img.shields.io/github/languages/top/thisismydemo/azure-scout)](https://github.com/thisismydemo/azure-scout)
[![Azure](https://badgen.net/badge/icon/azure?icon=azure&label)](https://azure.microsoft.com)

</div>

## Overview

**AzureScout** (AZSC) is a PowerShell module that generates detailed Excel and JSON reports of an Azure tenant, covering both ARM resources and Entra ID (Azure AD) objects. It is designed for Cloud Administrators and technical professionals who need a consolidated view of their Azure environment.

AZSC is forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) v3.6.11 and extends it with:

- **Entra ID inventory** — 15 modules covering users, groups, apps, conditional access, PIM, and more
- **Dual Excel + JSON output** — Machine-readable JSON alongside interactive Excel reports
- **Scoped execution** — Run ARM-only, Entra-only, or both
- **Streamlined auth** — Five authentication methods with no Microsoft.Graph SDK dependency
- **Pre-flight permission checker** — Validates ARM and Graph access before running
- **Azure Local & Arc expansion** — Inventory for Stack HCI clusters, Arc gateways, Arc Kubernetes, and resource bridges
- **Enhanced VPN detail** — P2S configuration, IPsec/IKE policies, and traffic selectors

## Key Features

| Feature | Description |
|---------|-------------|
| **ARM Resource Inventory** | 95 modules across 16 categories via Azure Resource Graph |
| **Entra ID Inventory** | 15 modules: users, groups, apps, roles, PIM, conditional access, and more |
| **Dual Output** | Excel (.xlsx) and JSON (.json) reports from every run |
| **Scoped Execution** | `-Scope All\|ArmOnly\|EntraOnly` to control what gets inventoried |
| **Output Format Control** | `-OutputFormat All\|Excel\|Json\|Markdown\|AsciiDoc` to control report format |
| **Category Filtering** | `-Category AI,Compute,Networking` to limit scope to selected categories |
| **Network Diagrams** | Auto-generated draw.io topology diagrams |
| **Permission Checker** | `Test-AZSCPermissions` validates access before running |
| **Security Analysis** | Optional Azure Security Center integration |
| **Cross-Platform** | Windows, Linux, and Mac |
| **No MgGraph Dependency** | Uses `Get-AzAccessToken -ResourceTypeName MSGraph` + REST API |
| **Read-Only** | No changes to your environment |

## Getting Started

### Prerequisites

- **PowerShell 7.0+** (required)
- Azure account with read access to target resources
- For Entra ID inventory: `Directory.Read.All` (or equivalent) permissions

### Required Modules

| Module | Purpose | Required |
|--------|---------|----------|
| `Az.Accounts` | Azure authentication | Yes |
| `Az.ResourceGraph` | ARM resource queries | Yes |
| `Az.Compute` | VM detail collection | Yes |
| `ImportExcel` | Excel report generation | Yes (for Excel output) |
| `Az.Storage` | Storage account output | Optional |

### Installation

> **Note**: AZSC is not yet published to PowerShell Gallery. Install from source:

```powershell
git clone https://github.com/thisismydemo/azure-scout.git
Import-Module ./azure-scout/AzureScout.psd1
```

Future PSGallery installation:

```powershell
Install-Module -Name AzureScout
```

## Quick Start

```powershell
# Import the module
Import-Module AzureScout

# Full inventory (ARM + Entra ID) — uses current Azure context
Invoke-AzureScout -TenantID <your-tenant-id>

# Default run — ARM resources only (Entra ID excluded)
Invoke-AzureScout -TenantID <your-tenant-id>

# Full inventory: ARM + Entra ID
Invoke-AzureScout -TenantID <your-tenant-id> -Scope All

# Entra ID only (fast — skips all Resource Graph queries)
Invoke-AzureScout -TenantID <your-tenant-id> -Scope EntraOnly

# JSON output only (no Excel)
Invoke-AzureScout -TenantID <your-tenant-id> -OutputFormat Json

# Markdown + AsciiDoc outputs
Invoke-AzureScout -TenantID <your-tenant-id> -OutputFormat Markdown
Invoke-AzureScout -TenantID <your-tenant-id> -OutputFormat AsciiDoc

# Check permissions before running
Test-AZSCPermissions -TenantID <your-tenant-id>
```

## Authentication Methods

AZSC supports five authentication methods. If you are already logged in via `Connect-AzAccount`, AZSC reuses your existing session.

### 1. Current User (Default)

```powershell
# Already logged in — just run
Invoke-AzureScout -TenantID <tenant-id>
```

### 2. Service Principal + Secret

```powershell
Invoke-AzureScout -TenantID <tenant-id> -AppId <app-id> -Secret <secret>
```

### 3. Service Principal + Certificate

```powershell
Invoke-AzureScout -TenantID <tenant-id> -AppId <app-id> `
    -CertificatePath "C:\certs\spn.pfx" -Secret <cert-password>
```

### 4. Device Code

```powershell
Invoke-AzureScout -TenantID <tenant-id> -DeviceLogin
```

### 5. Managed Identity

```powershell
# From an Azure VM or container with managed identity
Invoke-AzureScout -TenantID <tenant-id>
```

## Usage Guide

### Scope Control (`-Scope`)

| Value | Behavior |
|-------|----------|
| `ArmOnly` **(default)** | ARM resources only — skips all Graph/Entra calls |
| `All` | Inventory ARM resources **and** Entra ID objects |
| `EntraOnly` | Entra ID only — skips all Resource Graph queries |

> **Note**: The default scope is `ArmOnly`. Pass `-Scope All` to include Entra ID (Azure AD) data — this requires Microsoft Graph permissions in addition to ARM Reader access.

### Output Format (`-OutputFormat`)

| Value | Aliases | Behavior |
|-------|---------|----------|
| `All` (default) | — | Excel + JSON + Markdown + AsciiDoc |
| `Excel` | — | Excel report only |
| `Json` | — | JSON report only — fastest (no formatting) |
| `Markdown` | `MD` | GitHub-Flavored Markdown (`.md`) |
| `AsciiDoc` | `Adoc` | AsciiDoc document (`.adoc`) for Antora/Confluence |

### Permission Checker

Run `Test-AZSCPermissions` to validate access before a full inventory:

```powershell
$result = Test-AZSCPermissions -TenantID <tenant-id> -Scope All
$result.ArmAccess    # $true / $false
$result.GraphAccess  # $true / $false
$result.Details      # Array of check results with remediation guidance
```

### Content Options

```powershell
# Include Security Center recommendations
Invoke-AzureScout -TenantID <id> -SecurityCenter

# Include resource tags in reports
Invoke-AzureScout -TenantID <id> -IncludeTags

# Skip optional data collections
Invoke-AzureScout -TenantID <id> -SkipAdvisory -SkipPolicy -SkipDiagram

# Target specific subscriptions
Invoke-AzureScout -TenantID <id> -SubscriptionID <sub-id>

# Target a management group
Invoke-AzureScout -TenantID <id> -ManagementGroup <mg-id>
```

### Custom Output Location

```powershell
Invoke-AzureScout -TenantID <id> -ReportDir "D:\Reports" -ReportName "Q1-Inventory"
```

## Required Permissions

### ARM Permissions

| Role | Scope | Purpose |
|------|-------|---------|
| `Reader` | Root Management Group or all target Subscription(s) | Read all ARM resources |
| `Security Reader` | Subscription(s) | Defender for Cloud assessments and secure score |
| `Monitoring Reader` | Subscription(s) | Azure Monitor resources (DCRs, alerts, workspaces) |

> **Tip**: Assigning `Reader` at the **Root Management Group** is the easiest approach — it automatically covers all subscriptions in the tenant. Use subscription-level roles for least-privilege deployments.

### Microsoft Graph Permissions

Required only when using `-Scope All` or `-Scope EntraOnly`.

**Minimum permission:**

| Permission | Type | Purpose |
|------------|------|--------|
| `Directory.Read.All` | Application or Delegated | Users, groups, roles, apps |

**Recommended set for full Entra ID inventory:**

| Permission | Type | Purpose |
|------------|------|--------|
| `Directory.Read.All` | App or Delegated | Core directory objects |
| `User.Read.All` | App or Delegated | Full user property set |
| `Group.Read.All` | App or Delegated | Group membership and owners |
| `Application.Read.All` | App or Delegated | App registrations and service principals |
| `RoleManagement.Read.Directory` | App or Delegated | Directory role assignments |
| `Policy.Read.All` | App or Delegated | Conditional access, auth policies |
| `IdentityRiskyUser.Read.All` | App or Delegated | Risky users (optional) |
| `PrivilegedAccess.Read.AzureADGroup` | App or Delegated | PIM group assignments (optional) |

**For interactive user accounts:** Assign the **Global Reader** or **Directory Readers** Entra role.  
**For service principals (non-interactive):** Grant application permissions above and perform admin consent.

> **Tip**: Missing Graph permissions cause only the affected module to be skipped — AZSC continues with available data.

### Troubleshooting Permission Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Insufficient privileges to complete the operation` | Missing Graph permission | Grant the permission and re-run admin consent |
| `Authorization_RequestDenied` | Delegated permission not consented | Sign-in with Global Admin and consent |
| `Get-AzRoleAssignment: command not found` | `Az.Authorization` not installed | Module is auto-installed at first load |
| `Resource provider not registered` | Provider not enabled in subscription | Run `Register-AzResourceProvider -ProviderNamespace <ns>` |

### Required Resource Providers

AZSC queries the following resource providers. If a provider is not registered, the corresponding modules are skipped with a warning.

| Resource Provider | Purpose |
|-------------------|---------|
| `Microsoft.Security` | Defender for Cloud assessments, alerts, and secure score |
| `Microsoft.Insights` | Azure Monitor: DCRs, action groups, alert rules |
| `Microsoft.Maintenance` | Azure Update Manager maintenance configurations |
| `Microsoft.RecoveryServices` | Azure Backup and Azure Site Recovery |
| `Microsoft.HybridCompute` | Arc-enabled servers |
| `Microsoft.Kubernetes` | Arc-enabled Kubernetes |
| `Microsoft.AzureStackHCI` | Azure Local (Stack HCI) clusters |

Run `Test-AZSCPermissions` to check provider registration status before a full run.

## Output

### Default Locations

| OS | Path |
|----|------|
| Windows | `C:\AzureScout\` |
| Linux/Mac | `$HOME/AzureScout/` |

### Output Files

| File | Format | Description |
|------|--------|-------------|
| `AzureScout_Report_<timestamp>.xlsx` | Excel | Interactive spreadsheet with all inventory data |
| `AzureScout_Report_<timestamp>.json` | JSON | Machine-readable inventory with `_metadata` envelope |
| `AzureScout_Report_<timestamp>.md` | Markdown | GitHub-Flavored Markdown with pipe tables per module |
| `AzureScout_Report_<timestamp>.adoc` | AsciiDoc | AsciiDoc document for Antora/Confluence rendering |
| `AzureScout_Diagram_<timestamp>.drawio` | Draw.io | Network topology diagram |

### JSON Structure

```json
{
  "_metadata": {
    "tool": "AzureScout",
    "version": "1.5.0",
    "tenantId": "...",
    "subscriptions": ["..."],
    "generatedAt": "2026-02-23T...",
    "scope": "All"
  },
  "arm": {
    "compute": { ... },
    "network": { ... },
    "storage": { ... }
  },
  "entra": {
    "users": [ ... ],
    "groups": [ ... ],
    "appRegistrations": [ ... ]
  },
  "advisory": [ ... ],
  "policy": [ ... ],
  "security": [ ... ],
  "quotas": [ ... ]
}
```

## Category Filtering

Use `-Category` to limit the inventory to specific Azure resource categories. This can significantly speed up targeted scans. Multiple values are accepted as comma-separated or as an array.

| Category | Azure Portal Label | Key Resource Types |
|----------|--------------------|-------------------|
| `AI` | AI + Machine Learning | Cognitive Services, OpenAI, ML Workspaces, Bot Service |
| `Analytics` | Analytics | Synapse, Databricks, Data Factory, Stream Analytics |
| `Compute` | Compute | VMs, VMSS, Disks, Availability Sets, AVD |
| `Containers` | Containers | AKS, Container Instances, Container Registry |
| `Databases` | Databases | SQL, PostgreSQL, MySQL, Cosmos DB, Redis |
| `Hybrid` | Hybrid + Multicloud | Arc Servers, Arc Kubernetes, Arc Gateways, Arc Extensions |
| `Identity` | Identity | Key Vault |
| `Integration` | Integration | Service Bus, Event Hubs, API Management, Logic Apps |
| `IoT` | Internet of Things | IoT Hub, IoT DPS |
| `Management` | Management and governance | Recovery Services, Automation, Log Analytics |
| `Monitor` | Monitor | Application Insights, Alert Rules, Action Groups, DCRs |
| `Networking` | Networking | VNets, NSGs, Load Balancers, VPN, Firewall, Front Door |
| `Security` | Security | Key Vault, Defender |
| `Storage` | Storage | Storage Accounts, Data Lake |
| `Web` | Web & Mobile | App Service, Function Apps |

**Examples:**

```powershell
# Inventory only Compute and Networking resources
Invoke-AzureScout -TenantID <id> -Category Compute,Networking

# Inventory AI resources with JSON output
Invoke-AzureScout -TenantID <id> -Category AI -OutputFormat Json

# Long-form names (from the Azure Portal) are also accepted
Invoke-AzureScout -TenantID <id> -Category 'AI + Machine Learning'
Invoke-AzureScout -TenantID <id> -Category 'Internet of Things'
```

## Module Catalog

### ARM Resource Modules (95 modules, 16 categories)

| Category | Modules | Key Resource Types |
|----------|--------:|---------------------|
| AI | 14 | Cognitive Services, Machine Learning, OpenAI, Bot Service |
| Analytics | 6 | Data Factory, Synapse, Databricks, Stream Analytics |
| APIs | 5 | API Management, API Apps, Logic Apps |
| Azure Local | 6 | HCI Clusters, VMs, Logical Networks, Storage, Gallery Images |
| Compute | 7 | Virtual Machines, VMSS, Availability Sets, Disks |
| Container | 6 | AKS, Container Instances, Container Registry |
| Database | 13 | SQL, PostgreSQL, MySQL, Cosmos DB, Redis |
| Hybrid | 5 | Arc Servers, Arc Gateways, Arc Kubernetes, Arc Resource Bridge, Arc Extensions |
| Integration | 2 | Service Bus, Event Hubs |
| IoT | 1 | IoT Hub |
| Management | 3 | Recovery Services, Automation, Log Analytics |
| Monitoring | 2 | Application Insights, Workspaces |
| Network | 20 | VNets, NSGs, Load Balancers, VPN Gateways, Firewalls, Front Door |
| Security | 1 | Key Vault |
| Storage | 2 | Storage Accounts, Data Lake |
| Web | 2 | App Service, Function Apps |

### Entra ID Modules (15 modules)

| Module | Graph Endpoint | Excel Worksheet |
|--------|---------------|-----------------|
| Users | `/v1.0/users` | Entra Users |
| Groups | `/v1.0/groups` | Entra Groups |
| App Registrations | `/v1.0/applications` | App Registrations |
| Service Principals | `/v1.0/servicePrincipals` | Service Principals |
| Managed Identities | `/v1.0/servicePrincipals` (filtered) | Managed Identities |
| Directory Roles | `/v1.0/directoryRoles` | Directory Roles |
| PIM Assignments | `/beta/privilegedAccess/aadGroups/resources` | PIM Assignments |
| Conditional Access | `/v1.0/identity/conditionalAccess/policies` | Conditional Access |
| Named Locations | `/v1.0/identity/conditionalAccess/namedLocations` | Named Locations |
| Admin Units | `/v1.0/directory/administrativeUnits` | Admin Units |
| Domains | `/v1.0/domains` | Entra Domains |
| Licensing | `/v1.0/subscribedSkus` | Licensing |
| Cross-Tenant Access | `/v1.0/policies/crossTenantAccessPolicy/partners` | Cross-Tenant Access |
| Security Policies | `/v1.0/policies/authorizationPolicy` | Security Policies |
| Risky Users | `/v1.0/identityProtection/riskyUsers` | Risky Users |

## Parameters Reference

| Parameter | Description |
|-----------|-------------|
| **Core** | |
| `-TenantID` | Target tenant ID |
| `-SubscriptionID` | Limit to specific subscription(s) |
| `-ResourceGroup` | Limit to specific resource group(s) |
| `-ManagementGroup` | Inventory all subscriptions in a management group |
| `-Scope` | `ArmOnly` (default), `All`, `EntraOnly` |
| `-OutputFormat` | `All` (default), `Excel`, `Json`, `Markdown` (`MD`), `AsciiDoc` (`Adoc`) |
| `-Category` | Filter by category: `AI`, `Compute`, `Networking`, `Storage`, … (see [Category Filtering](#category-filtering)) |
| **Authentication** | |
| `-AppId` | Service principal application ID |
| `-Secret` | SPN secret or certificate password |
| `-CertificatePath` | Path to .pfx certificate |
| `-DeviceLogin` | Use device code authentication |
| **Content** | |
| `-SecurityCenter` | Include Security Center data |
| `-IncludeTags` | Include resource tags |
| `-SkipPolicy` | Skip Azure Policy collection |
| `-SkipAdvisory` | Skip Azure Advisor collection |
| `-SkipVMDetails` | Skip Azure VM extra details |
| `-SkipDiagram` | Skip network diagram generation |
| `-SkipPermissionCheck` | Skip the pre-flight permission validation |
| **Output** | |
| `-ReportName` | Custom report filename |
| `-ReportDir` | Custom output directory |
| `-Lite` | Lightweight Excel (no charts) |
| **Diagram** | |
| `-DiagramFullEnvironment` | Include all network components in diagram |
| **Other** | |
| `-AzureEnvironment` | Azure cloud (`AzureCloud`, `AzureUSGovernment`, etc.) |
| `-Debug` | Verbose debug output |

### Category Filtering

Use `-Category` to limit the inventory to specific Azure resource categories. This can significantly speed up targeted scans.

| Category | Azure Portal Label | Key Resource Types |
|----------|--------------------|--------------------|
| `AI` | AI + Machine Learning | Cognitive Services, OpenAI, ML Workspaces |
| `Analytics` | Analytics | Synapse, Databricks, Data Factory |
| `Compute` | Compute | VMs, VMSS, Disks, Availability Sets |
| `Containers` | Containers | AKS, Container Instances, Container Registry |
| `Databases` | Databases | SQL, PostgreSQL, MySQL, Cosmos DB, Redis |
| `Hybrid` | Hybrid + Multicloud | Arc Servers, Arc Kubernetes, Arc Gateways |
| `Identity` | Identity | Key Vault, Managed Identities |
| `Integration` | Integration | Service Bus, Event Hubs, API Management |
| `IoT` | Internet of Things | IoT Hub, IoT DPS |
| `Management` | Management and governance | Recovery Services, Automation, Log Analytics |
| `Monitor` | Monitor | Application Insights, Alert Rules, DCRs |
| `Networking` | Networking | VNets, NSGs, Load Balancers, VPN, Firewall |
| `Security` | Security | Defender, Key Vault, Sentinel |
| `Storage` | Storage | Storage Accounts, Data Lake |
| `Web` | Web & Mobile | App Service, Function Apps |

**Examples:**

```powershell
# Inventory only Compute and Networking resources
Invoke-AzureScout -TenantID <id> -Category Compute,Networking

# Inventory only AI resources, JSON output
Invoke-AzureScout -TenantID <id> -Category AI -OutputFormat Json

# Long-form category names are also accepted
Invoke-AzureScout -TenantID <id> -Category 'AI + Machine Learning'
```

## Attribution

This project is forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) v3.6.11, originally created by **Claudio Merola** and **Renato Gregio**. See [CREDITS.md](CREDITS.md) for full attribution details.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for policies and procedures.

### Adding a New Inventory Module

1. Copy `Modules/Public/InventoryModules/Module-template.tpl` to the appropriate category folder
2. Implement `Processing` phase (extract and transform resource data)
3. Implement `Reporting` phase (write to Excel via `Export-Excel`)
4. The module is auto-discovered — no registration required

## License

Copyright (c) 2026 thisismydemo. Copyright (c) 2020 RenatoGregio (original AzureResourceInventory).

Licensed under the MIT License — see [LICENSE](LICENSE) for details.
