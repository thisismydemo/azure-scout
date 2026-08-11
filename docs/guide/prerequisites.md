---
description: Software prerequisites and required PowerShell modules for AzureScout.
---

# Prerequisites & Required Modules

::: tip This page covers inventory mode
This page covers `Invoke-AzureScout` in its default **inventory mode**. Assessment
mode (`-Assessment`) needs extra scoring modules. A .NET SDK is needed only by developers
directly testing the held PowerPoint renderer—not by any live output—
see [Assessment Prerequisites](../assessment/assessment-prerequisites.md). New here? See the
[Overview](./overview.md).
:::

## System Requirements

A few requirements differ by mode — see the [Overview](./overview.md) for the
full comparison.

| Requirement | Inventory mode | Assessment mode (`-Assessment`) |
|-------------|-------------------------------------|-------------------------------------------|
| PowerShell | **7.0 or later, PowerShell Core** — the manifest declares `PowerShellVersion = '7.0'` and `CompatiblePSEditions = @('Core')`, so Windows PowerShell 5.1 cannot import the module | Same — **7.0 or later only**; every assessment script also starts with `#Requires -Version 7.0` |
| Operating System | Windows, Linux, or macOS | Windows, Linux, or macOS |
| Azure Account | Azure RBAC `Reader` — no more, on any subscription — with read access to target resources | ARM `Reader` at the tenant-root management group — see [Assessment Permissions](../assessment/assessment-permissions.md) |
| Entra ID Access | Entra directory roles `Directory Readers` + `Security Reader` (user sign-in), or the equivalent Graph app permissions (service principal) — required only for `-Scope All` or `-Scope EntraOnly` | Not required by default — 26 assessments collect governance data natively via ARM; Graph only applies if you opt one back into the legacy `AzGovViz` ingestor |

`Reader` is the whole ARM ask — no elevated role, and no other Azure RBAC role, is required for
either mode. If a checklist you're handing to a security team lists `Security Reader`,
`Monitoring Reader`, or `Cost Management Reader` (the **Azure RBAC** ones) as optional extras,
drop them — see [Permissions](./permissions.md#arm-permissions) for why they add nothing Scout
calls and, in two cases, add a write. Cost data is gated on a billing setting, not a role — see
the same page.

The rest of this page covers **inventory-mode** prerequisites only. For assessment
mode's additional modules and held-renderer development notes, see
[Assessment Prerequisites](../assessment/assessment-prerequisites.md).

## Installing AzureScout

```powershell
# From the PowerShell Gallery
Install-Module -Name AzureScout

# Or import directly from a local clone
Import-Module ./AzureScout.psd1
```

## Required PowerShell Modules

AzureScout declares its core dependencies in `AzureScout.psd1`. Installing from the
PowerShell Gallery resolves them through normal PowerShellGet dependency handling.
Importing a local clone does not install software; if a dependency is missing, install
it explicitly with the commands below and import the module again.

| Module | Purpose | Required? |
|--------|---------|-----------|
| `Az.Accounts` | Azure authentication and token acquisition | **Yes** |
| `Az.ResourceGraph` | ARM resource extraction via batch KQL | **Yes** (ARM scope) |
| `Az.Compute` | VM SKU and quota details | **Yes** (ARM scope) |
| `Az.Resources` | Role assignments and policy data | **Yes** |
| `ImportExcel` | Package dependency retained for held legacy Excel compatibility/tests | Declared by the module; no live output emits Excel |
| `Az.Storage` | Upload report to Azure Storage account | Optional (only with `-StorageAccount`) |
| `Az.CostManagement` | Cost data extraction | Optional (only with `-IncludeCosts`) |

**NOT required:** Any `Microsoft.Graph.*` module. AzureScout uses `Get-AzAccessToken -ResourceUrl <environment-Graph-endpoint>` with REST calls instead.

## Manual Installation

```powershell
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force
Install-Module -Name Az.Compute -Scope CurrentUser -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Force
Install-Module -Name ImportExcel -Scope CurrentUser -Force

# Only needed for -IncludeCosts. Without it the run still completes; cost data is skipped
# with a warning rather than failing the report (v2.5.3+).
Install-Module -Name Az.CostManagement -Scope CurrentUser -Force
```

## Required Azure Resource Providers

AZSC queries the following resource providers during its pre-flight permission audit.

::: warning
**Not all resource providers will be — or should be — registered in every subscription.** This is completely normal. Azure only registers providers for services you actually use, and most organisations deliberately limit provider registration per subscription as a governance best practice. For example, a connectivity subscription will not have `Microsoft.MachineLearningServices` registered, and an identity subscription will not have `Microsoft.DesktopVirtualization`. The `[FAIL]` and `[WARN]` messages in the permission audit output are **informational, not errors** — they tell you which modules will be skipped because the corresponding service is not deployed in that subscription. The scan will complete successfully regardless.
:::

If a provider is not registered, the corresponding collectors are skipped and the React/JSON
outputs will not contain that service for the subscription.

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

## Running an assessment?

Everything above covers `Invoke-AzureScout` in its default inventory mode.
**PowerShell 7 on PowerShell Core is a hard requirement for the whole module**
— `AzureScout.psd1` declares `PowerShellVersion = '7.0'` and
`CompatiblePSEditions = @('Core')`, so Windows PowerShell 5.1 cannot import it
in either mode.

Assessment mode (`Invoke-AzureScout -Assessment ...`) uses `powershell-yaml`
and `Az.Advisor`, which are declared by the module manifest. Live outputs need no .NET SDK;
the SDK note applies only to direct development/testing of the held PowerPoint renderer. See
[Assessment Prerequisites](../assessment/assessment-prerequisites.md) for the
full list.
