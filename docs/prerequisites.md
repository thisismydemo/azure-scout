---
description: Software prerequisites and required PowerShell modules for AzureScout.
---

# Prerequisites & Required Modules

## System Requirements

| Requirement | Details |
|-------------|---------|
| PowerShell | 7.0 or later (PowerShell Core). Windows PowerShell 5.1 is not supported. |
| Operating System | Windows, Linux, or macOS |
| Azure Account | An Azure identity with read access to target resources |
| Entra ID Access | `Directory.Read.All` or equivalent — required only for `-Scope All` or `-Scope EntraOnly` |

## Required PowerShell Modules

AzureScout auto-installs missing modules at first load. If auto-install fails (e.g., restricted network), install them manually.

| Module | Purpose | Required? |
|--------|---------|-----------|
| `Az.Accounts` | Azure authentication and token acquisition | **Yes** |
| `Az.ResourceGraph` | ARM resource extraction via batch KQL | **Yes** (ARM scope) |
| `Az.Compute` | VM SKU and quota details | **Yes** (ARM scope) |
| `Az.Resources` | Role assignments and policy data | **Yes** |
| `ImportExcel` | Excel report generation (.xlsx) | **Yes** (for Excel output) |
| `Az.Storage` | Upload report to Azure Storage account | Optional (only with `-StorageAccount`) |

**NOT required:** Any `Microsoft.Graph.*` module. AzureScout uses `Get-AzAccessToken -ResourceTypeName MSGraph` with REST calls instead.

## Manual Installation

```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force
Install-Module -Name Az.Compute -Scope CurrentUser -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Force
Install-Module -Name ImportExcel -Scope CurrentUser -Force
```

## Required Azure Resource Providers

AZSC queries the following resource providers during its pre-flight permission audit.

!!! important
    **Not all resource providers will be — or should be — registered in every subscription.** This is completely normal. Azure only registers providers for services you actually use, and most organisations deliberately limit provider registration per subscription as a governance best practice. For example, a connectivity subscription will not have `Microsoft.MachineLearningServices` registered, and an identity subscription will not have `Microsoft.DesktopVirtualization`. The `[FAIL]` and `[WARN]` messages in the permission audit output are **informational, not errors** — they tell you which modules will be skipped because the corresponding service is not deployed in that subscription. The scan will complete successfully regardless.

If a provider is not registered, the corresponding inventory modules are simply skipped and the report will not contain a tab for that service in that subscription.

| Resource Provider | Purpose |
|-------------------|---------|
| `Microsoft.Security` | Defender for Cloud assessments, alerts, and secure score |
| `Microsoft.Insights` | Azure Monitor: DCRs, action groups, alert rules |
| `Microsoft.Maintenance` | Azure Update Manager maintenance configurations |
| `Microsoft.RecoveryServices` | Azure Backup and Azure Site Recovery |
| `Microsoft.HybridCompute` | Arc-enabled servers |
| `Microsoft.Kubernetes` | Arc-enabled Kubernetes |
| `Microsoft.AzureStackHCI` | Azure Local (Stack HCI) clusters |

Register a provider with:

```powershell
Register-AzResourceProvider -ProviderNamespace Microsoft.Security
```

Run `Test-AZSCPermissions` to check provider registration status before a full run.
