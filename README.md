---
ArtifactType: Excel spreadsheet and JSON with full Azure Scout
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

- [Full Documentation](docs/modules/ROOT/pages/index.adoc)
- [Prerequisites & Required Modules](docs/modules/ROOT/pages/prerequisites.adoc)
- [Authentication](docs/modules/ROOT/pages/authentication.adoc)
- [Usage Guide](docs/modules/ROOT/pages/usage.adoc)
- [Parameters Reference](docs/modules/ROOT/pages/parameters.adoc)
- [Permissions](docs/modules/ROOT/pages/permissions.adoc)
- [Category Filtering](docs/modules/ROOT/pages/category-filtering.adoc)
- [Output Files & Formats](docs/modules/ROOT/pages/output.adoc)
- [Troubleshooting](docs/modules/ROOT/pages/troubleshooting.adoc)
- [ARM Modules](docs/modules/ROOT/pages/arm-modules.adoc)
- [Entra Modules](docs/modules/ROOT/pages/entra-modules.adoc)
- [Testing](docs/modules/ROOT/pages/testing.adoc)
- [Contributing](docs/modules/ROOT/pages/contributing.adoc)
- [Credits & Attribution](docs/modules/ROOT/pages/credits.adoc)

## License

Licensed under the MIT License — see [LICENSE](LICENSE) for details.
