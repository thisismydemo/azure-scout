---
ArtifactType: Excel spreadsheet and JSON with full Azure Scout
Language: PowerShell
Platform: Windows / Linux / Mac
Tags: PowerShell, Azure, Inventory, Entra ID, Excel Report, JSON
---

<div align="center">

![AzureScout](https://raw.githubusercontent.com/thisismydemo/azure-scout/main/docs/images/azurescout-banner.svg)

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

> **Built on [Azure Resource Inventory (ARI)](https://github.com/microsoft/ARI)**
>
> AzureScout is a fork of Microsoft's [Azure Resource Inventory](https://github.com/microsoft/ARI) (ARI) v3.6.11, created by **[Claudio Merola](https://github.com/Claudio-Merola)** and **[Renato Gregio](https://github.com/RenatoGregio)**. The ARI project provided the entire foundation — 171 ARM inventory modules, draw.io diagram engine, Excel reporting pipeline, and Azure Automation support — that AzureScout builds upon. We are deeply grateful for their work.
>
> See [CREDITS.md](CREDITS.md) for full attribution and [Differences from ARI](docs/ari-differences.md) for what AzureScout has changed.

## Key Features
- ARM and Entra ID inventory
- Excel and JSON output
- Scoped execution (ARM-only, Entra-only, or both)
- Streamlined authentication
- Permission checker
- Network diagrams
- Cross-platform (Windows, Linux, Mac)

## Quick Start

### Prerequisites
- PowerShell 7.0+
- Azure account with read access
- For Entra ID inventory: Directory.Read.All permissions

### Installation

```powershell
git clone https://github.com/thisismydemo/azure-scout.git
Import-Module ./azure-scout/AzureScout.psd1
```

## Usage Example

```powershell
# Import the module
Import-Module AzureScout

# Full inventory (ARM + Entra ID)
Invoke-AzureScout -TenantID <your-tenant-id>

# ARM-only
Invoke-AzureScout -TenantID <your-tenant-id> -Scope ArmOnly

# Entra ID only
Invoke-AzureScout -TenantID <your-tenant-id> -Scope EntraOnly
```

## Documentation

For detailed guides, module catalog, parameters, permissions, troubleshooting, testing, and contributing, see:

- [Full Documentation](docs/index.md)
- [Prerequisites & Required Modules](docs/prerequisites.md)
- [Authentication](docs/authentication.md)
- [Usage Guide](docs/usage.md)
- [Parameters Reference](docs/parameters.md)
- [Permissions](docs/permissions.md)
- [Category Filtering](docs/category-filtering.md)
- [Output Files & Formats](docs/output.md)
- [Troubleshooting](docs/troubleshooting.md)
- [ARM Modules](docs/arm-modules.md)
- [Entra Modules](docs/entra-modules.md)
- [Testing](docs/testing.md)
- [Contributing](docs/contributing.md)
- [Credits & Attribution](docs/credits.md)

## License

Licensed under the MIT License — see [LICENSE](LICENSE) for details.
