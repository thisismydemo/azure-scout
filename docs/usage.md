---
description: How to use AzureScout — scopes, output formats, category filtering, and examples.
---

# Usage Guide

## Basic Usage

```powershell
Import-Module ./AzureScout.psd1
Invoke-AzureScout
```

With no parameters, AZSC runs a full inventory (ARM + Entra) using your current Azure context and generates both Excel and JSON reports.

## Scope

The `-Scope` parameter controls which data domains are inventoried:

| Value | Behavior |
|-------|----------|
| `All` (default) | Inventories both ARM resources and Entra ID objects |
| `ArmOnly` | Skips all Entra ID extraction — ARM resources only |
| `EntraOnly` | Skips all ARM extraction — Entra ID objects only |

```powershell
# ARM only — skip Entra ID
Invoke-AzureScout -Scope ArmOnly

# Entra ID only — skip ARM resources
Invoke-AzureScout -Scope EntraOnly
```

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

Reports are saved to a timestamped folder:

- **Windows**: `C:\AzureScout\<timestamp>\`
- **Linux/macOS**: `$HOME/AzureScout/<timestamp>/`

Override with `-ReportDir`:

```powershell
Invoke-AzureScout -ReportDir 'D:\Reports'
```

## Content Toggles

Switch parameters to include/exclude specific content:

| Parameter | Effect |
|-----------|--------|
| `-SecurityCenter` | Include Microsoft Defender for Cloud findings |
| `-IncludeTags` | Include resource tags in Excel worksheets |
| `-SkipAdvisory` | Skip Azure Advisor recommendations |
| `-SkipPolicy` | Skip Azure Policy compliance data |
| `-SkipPermissionCheck` | Skip the pre-flight permission validation |

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
