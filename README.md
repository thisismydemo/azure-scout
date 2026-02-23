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

**AzureTenantInventory** (AZTI) is a PowerShell module for generating detailed Excel and JSON reports of an Azure tenant, covering both ARM resources and Entra ID (Azure AD) objects. It is designed for Cloud Administrators and technical professionals who need a consolidated view of their Azure environment.

AZTI is forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) v3.6.11 and extends it with single-tenant Entra ID inventory capabilities, dual Excel + JSON output, and a streamlined authentication model with no dependency on Microsoft.Graph SDK.

## Key Features

- **ARM Resource Inventory**: Detailed inventory of all Azure resources via Azure Resource Graph
- **Entra ID Inventory**: Users, groups, service principals, app registrations, roles, and more (planned)
- **Dual Output**: Excel reports and JSON output for every run
- **Scoped Execution**: `-Scope All|ArmOnly|EntraOnly` to control what gets inventoried
- **Interactive Excel Reports**: Well-formatted spreadsheets with resources organized by type
- **Visual Network Diagrams**: Generate interactive topology maps of your Azure environment
- **Security Analysis**: Integration with Azure Security Center (optional)
- **Cross-Platform Support**: Works on Windows, Linux, and Mac
- **Multiple Auth Methods**: Current user, SPN+secret, SPN+certificate, device code, managed identity
- **No Microsoft.Graph Dependency**: Uses `Get-AzAccessToken -ResourceTypeName MSGraph` + REST API calls
- **Low-Impact**: Read-only operations with no changes to your environment

## Getting Started

### Prerequisites

- PowerShell 7.0+ (required)
- Azure account with read access to resources you want to inventory
- For Entra ID inventory: appropriate directory read permissions (e.g., `Directory.Read.All`)

### Required Modules

| Module | Purpose |
|--------|---------|
| `Az.Accounts` | Azure authentication |
| `Az.ResourceGraph` | ARM resource queries |
| `Az.Storage` | Storage account output (optional) |
| `Az.Compute` | VM detail collection |
| `ImportExcel` | Excel report generation |

### Installation

> **Note**: AZTI is not yet published to PowerShell Gallery. Install from source:

```powershell
git clone https://github.com/thisismydemo/azure-inventory.git
Import-Module ./azure-inventory/AzureTenantInventory.psd1
```

### Quick Start

```powershell
# Import the module
Import-Module AzureTenantInventory

# Run full inventory (ARM + Entra ID)
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID>

# ARM resources only
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -Scope ArmOnly

# Entra ID only (planned)
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -Scope EntraOnly
```

## Usage Guide

### Basic Commands

Run inventory with specific tenant:

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID>
```

Scope to specific subscription:

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -SubscriptionID <Subscription-ID>
```

Include resource tags in the report:

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -IncludeTags
```

### Common Scenarios

**Include Security Center Data:**

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -SecurityCenter
```

**Skip Azure Advisor Data Collection:**

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -SkipAdvisory
```

**Skip Network Diagram Generation:**

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -SkipDiagram
```

**Service Principal Authentication:**

```powershell
Invoke-AzureTenantInventory -TenantID <Azure-Tenant-ID> -AppId <App-ID> -Secret <Secret>
```

## Parameters Reference

| Parameter | Description | Usage |
|-----------|-------------|-------|
| **Core Parameters** | | |
| TenantID | Specify the tenant ID for inventory | `-TenantID <ID>` |
| SubscriptionID | Specify subscription(s) to inventory | `-SubscriptionID <ID>` |
| ResourceGroup | Limit inventory to specific resource group(s) | `-ResourceGroup <NAME>` |
| Scope | Control inventory scope: All, ArmOnly, EntraOnly | `-Scope <SCOPE>` |
| **Authentication** | | |
| AppId | Application ID for service principal auth | `-AppId <ID>` |
| Secret | Secret for service principal authentication | `-Secret <VALUE>` |
| CertificatePath | Certificate path for service principal | `-CertificatePath <PATH>` |
| DeviceLogin | Use device login authentication | `-DeviceLogin` |
| **Scope Control** | | |
| ManagementGroup | Inventory all subscriptions in management group | `-ManagementGroup <ID>` |
| TagKey | Filter resources by tag key | `-TagKey <NAME>` |
| TagValue | Filter resources by tag value | `-TagValue <NAME>` |
| **Content Options** | | |
| SecurityCenter | Include Security Center data | `-SecurityCenter` |
| IncludeTags | Include resource tags | `-IncludeTags` |
| SkipPolicy | Skip Azure Policy collection | `-SkipPolicy` |
| SkipVMDetails | Skip Azure VM Extra Details collection | `-SkipVMDetails` |
| SkipAdvisory | Skip Azure Advisory collection | `-SkipAdvisory` |
| **Output Options** | | |
| ReportName | Custom report filename | `-ReportName <NAME>` |
| ReportDir | Custom directory for report | `-ReportDir "<Path>"` |
| Lite | Use lightweight Excel generation (no charts) | `-Lite` |
| **Diagram Options** | | |
| SkipDiagram | Skip diagram creation | `-SkipDiagram` |
| DiagramFullEnvironment | Include all network components in diagram | `-DiagramFullEnvironment` |
| **Other Options** | | |
| Debug | Run in debug mode | `-Debug` |
| AzureEnvironment | Specify Azure cloud environment | `-AzureEnvironment <NAME>` |

## Output

### Default Locations

- **Windows**: `C:\AzureTenantInventory\`
- **Linux/Mac**: `$HOME/AzureTenantInventory/`

### Output Files

| File | Format | Description |
|------|--------|-------------|
| `AzureTenantInventory_Report_<timestamp>.xlsx` | Excel | Interactive spreadsheet with all inventory data |
| `AzureTenantInventory_Report_<timestamp>.json` | JSON | Machine-readable inventory output |
| `AzureTenantInventory_Diagram_<timestamp>.xml` | Draw.io XML | Network topology diagram |

## Attribution

This project is forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) v3.6.11, originally created by **Claudio Merola** and **Renato Gregio**. See [LICENSE](LICENSE) for full copyright details.

Special thanks to **Doug Finke**, the author of the PowerShell [ImportExcel](https://github.com/dfinke/ImportExcel) module.

## Contributing

Please read our [CONTRIBUTING.md](CONTRIBUTING.md) which outlines all policies, procedures, and requirements for contributing to this project.

## License

Copyright (c) 2026 thisismydemo. Copyright (c) 2020 RenatoGregio (original AzureResourceInventory).

Licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
