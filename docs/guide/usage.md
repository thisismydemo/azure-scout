---
description: How to use AzureScout — scopes, output formats, category filtering, and examples.
---

# Usage Guide

## Basic Usage

```powershell
Import-Module ./AzureScout.psd1
Invoke-AzureScout
```

With no parameters, AZSC runs a full **ARM-only** inventory (`-Scope ArmOnly` is the default — Entra ID is skipped unless you pass `-Scope All` or `-Scope EntraOnly`) using your current Azure context, and generates both Excel and JSON reports.

## Scope

The `-Scope` parameter controls which data domains are inventoried:

| Value | Behavior |
|-------|----------|
| `ArmOnly` (default) | Inventories ARM resources only — Entra ID is **not** scanned unless requested |
| `EntraOnly` | Skips all ARM extraction — Entra ID objects only |
| `All` | Inventories both ARM resources and Entra ID objects |

```powershell
# Default — ARM only, Entra ID is skipped
Invoke-AzureScout

# ARM + Entra ID
Invoke-AzureScout -Scope All

# Entra ID only — skip ARM resources
Invoke-AzureScout -Scope EntraOnly
```

::: tip
This is the `-Scope` default for **inventory mode** only. In **assessment mode**
(`-Assessment`) the same `-Scope` parameter defaults to `All` and has different
semantics — see [Assessment mode: `-Scope`](../assessment/assessment.md#-scope).
:::

## Output Format

The `-OutputFormat` parameter controls report file types:

| Value | Produces |
|-------|----------|
| `All` (default) | Both Excel (.xlsx) and JSON (.json) |
| `Excel` | Excel only |
| `Json` | JSON only |

```powershell
# JSON only output
Invoke-AzureScout -OutputFormat Json

# Excel only output
Invoke-AzureScout -OutputFormat Excel
```

## Report Location

Every run writes to its own folder, so a rerun never overwrites the previous one:

- **Windows**: `C:\AzureScout\<timestamp>_<tenant>\`
- **Linux/macOS**: `$HOME/AzureScout/<timestamp>_<tenant>/`

Override the base path with `-ReportDir`, name the run folder with `-RunName`, or skip the run
folder entirely with `-Force`:

```powershell
# Different base path
Invoke-AzureScout -ReportDir 'D:\Reports'

# Friendly run folder name instead of the timestamp
Invoke-AzureScout -RunName 'Production-TenantA'

# Write straight into the base path, overwriting in place
Invoke-AzureScout -ReportDir 'D:\Reports' -Force
```

Full detail, including pruning old runs with `Clear-AZSCCacheFolder -OlderThan`, is in
[Output Files & Formats](./output.md#run-isolation).

Every run also writes two evidence artifacts to the run folder, not the report cache, so they
survive cache cleanup: `raw-inventory.json` (everything the Resource Graph pass collected,
before any manifest filtered it down to a worksheet) and `collector-rowcounts.json`
(per-collector Rows / Empty / Failed verdicts). See
[Output Files & Formats — evidence artifacts](./output.md#evidence-artifacts).

## Content Toggles

Switch parameters to include/exclude specific content:

| Parameter | Effect |
|-----------|--------|
| `-SecurityCenter` | Include Microsoft Defender for Cloud findings |
| `-IncludeTags` | Include resource tags in Excel worksheets |
| `-IncludeDevOps` | Include Azure DevOps projects, pipelines, service connections, repositories, and agent pools |
| `-SkipAdvisory` | Skip Azure Advisor recommendations |
| `-SkipPolicy` | Skip Azure Policy compliance data |
| `-SkipPermissionCheck` | Skip the pre-flight permission validation |

## Azure DevOps

`-IncludeDevOps` adds five worksheets covering your Azure DevOps estate. It reuses the current
Azure sign-in, so no personal access token is needed in the common case:

```powershell
# Organizations discovered from the signed-in profile
Invoke-AzureScout -TenantID '00000000-...' -IncludeDevOps

# Name them explicitly (required for service principals)
Invoke-AzureScout -TenantID '00000000-...' -IncludeDevOps -DevOpsOrganization 'contoso','fabrikam'
```

See [Azure DevOps](../automation-guide/azure-devops.md) for the service-connection-to-subscription cross-reference
and the full permission model.

## Subscription & Management Group Filters

```powershell
# Specific subscriptions only
Invoke-AzureScout -SubscriptionID 'sub-001','sub-002'

# Management group scoped
Invoke-AzureScout -ManagementGroup 'mg-prod'
```

## Naming the Report

```powershell
Invoke-AzureScout -ReportName 'Q4-2025-Audit'
```

## JSON Output Structure

The JSON report uses a normalized, flat resource schema:

```json
{
  "metadata": {
    "tenantId": "...",
    "generatedAt": "2026-01-15T10:30:00Z",
    "scope": "All",
    "moduleVersion": "1.5.0"
  },
  "resources": [
    {
      "id": "/subscriptions/.../resourceGroups/.../providers/...",
      "name": "my-vm",
      "TYPE": "microsoft.compute/virtualmachines",
      "resourceGroup": "rg-prod",
      "subscriptionId": "...",
      "location": "eastus",
      "properties": { }
    }
  ]
}
```
