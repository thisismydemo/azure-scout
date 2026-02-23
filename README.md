---
ArtifactType: Excel spreadsheet and JSON with full Azure tenant inventory
Language: PowerShell
Platform: Windows / Linux / Mac
Tags: PowerShell, Azure, Inventory, Entra ID, Excel Report, JSON
---

<div align="center">

# Azure Tenant Inventory (AZTI)

### A PowerShell module for generating comprehensive Azure ARM and Entra ID inventory reports

[![GitHub](https://img.shields.io/github/license/thisismydemo/azure-inventory)](https://github.com/thisismydemo/azure-inventory/blob/main/LICENSE)
[![GitHub repo size](https://img.shields.io/github/repo-size/thisismydemo/azure-inventory)](https://github.com/thisismydemo/azure-inventory)
[![GitHub last commit](https://img.shields.io/github/last-commit/thisismydemo/azure-inventory)](https://github.com/thisismydemo/azure-inventory/commits/main)
[![GitHub top language](https://img.shields.io/github/languages/top/thisismydemo/azure-inventory)](https://github.com/thisismydemo/azure-inventory)
[![Azure](https://badgen.net/badge/icon/azure?icon=azure&label)](https://azure.microsoft.com)

</div>

## Overview

**AzureTenantInventory** (AZTI) is a PowerShell module that generates detailed Excel and JSON reports of an Azure tenant, covering both ARM resources and Entra ID (Azure AD) objects. It is designed for Cloud Administrators and technical professionals who need a consolidated view of their Azure environment.

AZTI is forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) v3.6.11 and extends it with:

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
| **Output Format Control** | `-OutputFormat All\|Excel\|Json` to control report format |
| **Network Diagrams** | Auto-generated draw.io topology diagrams |
| **Permission Checker** | `Test-AZTIPermissions` validates access before running |
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

> **Note**: AZTI is not yet published to PowerShell Gallery. Install from source:

```powershell
git clone https://github.com/thisismydemo/azure-inventory.git
Import-Module ./azure-inventory/AzureTenantInventory.psd1
```

Future PSGallery installation:

```powershell
Install-Module -Name AzureTenantInventory
```

## Quick Start

```powershell
# Import the module
Import-Module AzureTenantInventory

# Full inventory (ARM + Entra ID) — uses current Azure context
Invoke-AzureTenantInventory -TenantID <your-tenant-id>

# ARM resources only
Invoke-AzureTenantInventory -TenantID <your-tenant-id> -Scope ArmOnly

# Entra ID only (fast — skips all resource graph queries)
Invoke-AzureTenantInventory -TenantID <your-tenant-id> -Scope EntraOnly

# JSON output only (no Excel)
Invoke-AzureTenantInventory -TenantID <your-tenant-id> -OutputFormat Json

# Check permissions before running
Test-AZTIPermissions -TenantID <your-tenant-id>
```

## Authentication Methods

AZTI supports five authentication methods. If you are already logged in via `Connect-AzAccount`, AZTI reuses your existing session.

### 1. Current User (Default)

```powershell
# Already logged in — just run
Invoke-AzureTenantInventory -TenantID <tenant-id>
```

### 2. Service Principal + Secret

```powershell
Invoke-AzureTenantInventory -TenantID <tenant-id> -AppId <app-id> -Secret <secret>
```

### 3. Service Principal + Certificate

```powershell
Invoke-AzureTenantInventory -TenantID <tenant-id> -AppId <app-id> `
    -CertificatePath "C:\certs\spn.pfx" -Secret <cert-password>
```

### 4. Device Code

```powershell
Invoke-AzureTenantInventory -TenantID <tenant-id> -DeviceLogin
```

### 5. Managed Identity

```powershell
# From an Azure VM or container with managed identity
Invoke-AzureTenantInventory -TenantID <tenant-id>
```

## Usage Guide

### Scope Control (`-Scope`)

| Value | Behavior |
|-------|----------|
| `All` (default) | Inventory ARM resources and Entra ID objects |
| `ArmOnly` | ARM resources only — skips all Graph/Entra calls |
| `EntraOnly` | Entra ID only — skips all Resource Graph queries |

### Output Format (`-OutputFormat`)

| Value | Behavior |
|-------|----------|
| `All` (default) | Generates both Excel (.xlsx) and JSON (.json) |
| `Excel` | Excel report only |
| `Json` | JSON report only — significantly faster (no Excel formatting) |

### Permission Checker

Run `Test-AZTIPermissions` to validate access before a full inventory:

```powershell
$result = Test-AZTIPermissions -TenantID <tenant-id> -Scope All
$result.ArmAccess    # $true / $false
$result.GraphAccess  # $true / $false
$result.Details      # Array of check results with remediation guidance
```

### Content Options

```powershell
# Include Security Center recommendations
Invoke-AzureTenantInventory -TenantID <id> -SecurityCenter

# Include resource tags in reports
Invoke-AzureTenantInventory -TenantID <id> -IncludeTags

# Skip optional data collections
Invoke-AzureTenantInventory -TenantID <id> -SkipAdvisory -SkipPolicy -SkipDiagram

# Target specific subscriptions
Invoke-AzureTenantInventory -TenantID <id> -SubscriptionID <sub-id>

# Target a management group
Invoke-AzureTenantInventory -TenantID <id> -ManagementGroup <mg-id>
```

### Custom Output Location

```powershell
Invoke-AzureTenantInventory -TenantID <id> -ReportDir "D:\Reports" -ReportName "Q1-Inventory"
```

## Required Permissions

### ARM Permissions

| Role | Scope | Purpose |
|------|-------|---------|
| `Reader` | Subscription(s) | Read all ARM resources |

### Microsoft Graph Permissions

| Permission | Type | Purpose |
|------------|------|---------|
| `Directory.Read.All` | Application or Delegated | Users, groups, roles, apps |
| `Policy.Read.All` | Application or Delegated | Conditional access, auth policies |
| `IdentityRiskyUser.Read.All` | Application or Delegated | Risky users (optional) |
| `PrivilegedAccess.Read.AzureADGroup` | Application or Delegated | PIM assignments (optional) |

> **Tip**: If specific Graph permissions are missing, AZTI gracefully skips those modules and continues with available data.

## Output

### Default Locations

| OS | Path |
|----|------|
| Windows | `C:\AzureTenantInventory\` |
| Linux/Mac | `$HOME/AzureTenantInventory/` |

### Output Files

| File | Format | Description |
|------|--------|-------------|
| `AzureTenantInventory_Report_<timestamp>.xlsx` | Excel | Interactive spreadsheet with all inventory data |
| `AzureTenantInventory_Report_<timestamp>.json` | JSON | Machine-readable inventory with `_metadata` envelope |
| `AzureTenantInventory_Diagram_<timestamp>.xml` | Draw.io XML | Network topology diagram |

### JSON Structure

```json
{
  "_metadata": {
    "tool": "AzureTenantInventory",
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
| `-Scope` | `All` (default), `ArmOnly`, `EntraOnly` |
| `-OutputFormat` | `All` (default), `Excel`, `Json` |
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
