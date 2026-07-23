---
description: See everything. Own your cloud. A PowerShell module for comprehensive Azure + Entra ID discovery and inventory.
---

# AzureScout

![AzureScout — See everything. Own your cloud.](images/azurescout-banner.svg)

*See everything. Own your cloud.*

## Overview

**AzureScout** (AZSC) is a PowerShell module that discovers and inventories everything in your Azure environment — ARM resources, Entra ID objects, costs, security posture, policies, and more. Reports are generated as Excel workbooks, JSON, Markdown, or AsciiDoc.

::: tip Inventory vs Assessment — two tools, one module
AzureScout ships **two** entry points. `Invoke-AzureScout` (v1) builds a wide **inventory** of everything in your tenant. `Invoke-ScoutAssessment` (v2) runs a scored **CAF/WAF assessment** on top of that data. Not sure which one you need? Start with [Overview: Inventory vs Assessment](overview.md).
:::

| Feature | Description |
|---------|-------------|
| **ARM Resource Discovery** | 154 resource modules across 15 Microsoft Azure categories (AI + machine learning, Analytics, Compute, Containers, Databases, Hybrid + multicloud, Identity, Integration, IoT, Management and governance, Monitor, Networking, Security, Storage, Web) |
| **Entra ID Inventory** | 17 identity modules — Users, Groups, Applications, Service Principals, Conditional Access, PIM, Administrative Units, Named Locations, Domains, Identity Providers, Security Defaults, and more |
| **Excel Reports** | Rich multi-worksheet workbooks with charts, pivot tables, and conditional formatting |
| **JSON Output** | Machine-readable normalized output for automation pipelines |
| **Markdown & AsciiDoc** | Export reports as `.md` or `.adoc` for documentation pipelines and PDF generation |
| **Network Diagrams** | Auto-generated draw.io topology diagrams |
| **Category Filtering** | Run only the categories you need: `-Category Compute,Security,Networking` |
| **Permission Audit** | Pre-flight ARM + Graph access checker with role remediation guidance |

### Quick Start

```powershell
# Install from PSGallery
Install-Module -Name AzureScout

# Import from local clone
Import-Module ./AzureScout.psd1

# Full discovery (ARM only, uses current Azure context)
Invoke-AzureScout

# ARM + Entra ID
Invoke-AzureScout -Scope All

# ARM-only scan with JSON output
Invoke-AzureScout -Scope ArmOnly -OutputFormat Json

# Specific categories only
Invoke-AzureScout -Category Compute,Security,Networking

# Permission pre-flight check
Invoke-AzureScout -PermissionAudit
```

::: tip
If you're already logged in via `Connect-AzAccount`, AzureScout uses your existing session — no additional flags needed.
:::

## Documentation

| Page | Description |
|------|-------------|
| [Overview: Inventory vs Assessment](overview.md) | Which tool do I need? Decision guide + two mini quickstarts |
| [Authentication](authentication.md) | Five authentication methods (interactive, device-code, SPN+secret, SPN+cert, managed identity) |
| [Usage Guide](usage.md) | Scope, OutputFormat, Category filtering, and examples |
| [Permissions](permissions.md) | Required ARM RBAC roles and Microsoft Graph API permissions |
| [Category Filtering](category-filtering.md) | Run targeted scans using Microsoft's 15 Azure categories |
| [ARM Modules](arm-modules.md) | 154 resource modules across 15 categories |
| [Entra Modules](entra-modules.md) | 17 Entra ID identity modules |
| [Repository Structure](folder-structure.md) | Directory layout and module loading |
| [Contributing](contributing.md) | How to add new inventory modules |
| [Credits](credits.md) | Attribution and acknowledgments |
| [Changelog](changelog.md) | Version history |
| [Assessment Platform](assessment.md) | CAF/WAF landing-zone assessment — architecture, run modes, all 22 assessments |
| [Assessment Prerequisites](assessment-prerequisites.md) | Software, module, and .NET SDK prerequisites specific to `Invoke-ScoutAssessment` |
| [Assessment Permissions](assessment-permissions.md) | Minimum RBAC and Graph permissions per assessment, and `-PermissionAudit` |
