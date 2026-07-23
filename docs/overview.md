---
description: Which AzureScout tool do you need — the v1 inventory cmdlet or the v2 CAF/WAF assessment platform? A decision guide with two mini quickstarts.
---

# Overview: Inventory vs Assessment

AzureScout ships **two** entry points from the same module. They answer different questions,
have different defaults, and — for the assessment platform — a different PowerShell version
requirement. Read this page first if you're new to AzureScout.

| | `Invoke-AzureScout` (v1) | `Invoke-ScoutAssessment` (v2) |
|---|---|---|
| Answers | "What's in my tenant?" | "How well does my tenant conform to CAF/WAF?" |
| Output | Excel workbook, JSON, Markdown, AsciiDoc, Power BI CSVs — raw inventory | Scored `findings.json`, Power BI, HTML, PowerPoint, Excel evidence |
| `-Scope` default | `ArmOnly` | `All` |
| PowerShell | 5.1+ (Desktop or Core) | **7.0+ only** (`#Requires -Version 7.0`) |
| Read the full guide | [Usage Guide](usage.md) | [Assessment Platform](assessment.md) |

## Which one do I need?

- **I want a spreadsheet/JSON of every resource in my tenant** → use `Invoke-AzureScout` (inventory).
- **I want a scored gap analysis against Microsoft's Cloud Adoption Framework / Well-Architected Framework, with a prioritized remediation list** → use `Invoke-ScoutAssessment` (assessment).
- **I want both** → run the inventory first for a full raw dataset, then run an assessment for the scored analysis. They are independent — you don't need to run one before the other.

## Quickstart: Inventory (`Invoke-AzureScout`)

```powershell
# 1. Install from the PowerShell Gallery
Install-Module -Name AzureScout

# 2. Sign in (or reuse an existing Connect-AzAccount session)
Connect-AzAccount

# 3. Run a full ARM inventory (default scope — ARM only, no Entra ID)
Invoke-AzureScout

# ARM + Entra ID in one run
Invoke-AzureScout -Scope All
```

Runs on PowerShell 5.1+ or 7+. See [Prerequisites](prerequisites.md), [Usage Guide](usage.md),
and [Category Filtering](category-filtering.md) for targeted scans.

## Quickstart: Assessment (`Invoke-ScoutAssessment`)

```powershell
# 1. Install from the PowerShell Gallery (same module as inventory)
Install-Module -Name AzureScout

# 2. Sign in — same authentication as the inventory cmdlet, no separate login
Connect-AzAccount

# 3. Run a full CAF/WAF landing-zone assessment
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Html
```

**Requires PowerShell 7.0+** — the assessment platform will not load under Windows PowerShell 5.1.
See [Assessment Prerequisites](assessment-prerequisites.md) (additional modules and a `.NET SDK`
requirement for the PowerPoint tier) and [Assessment Permissions](assessment-permissions.md)
before your first run.

## Both tools, one module

Both cmdlets ship in the same `AzureScout` module and share the same sign-in flow
(`Connect-AZSCLoginSession` under the hood) — see [Authentication](authentication.md). What
differs between them is *scope defaults*, *output shape*, and — for the assessment
platform — the PowerShell version floor.

::: tip Next steps
- New to the inventory tool? Start at [Prerequisites & Required Modules](prerequisites.md).
- New to the assessment platform? Start at [Assessment Prerequisites](assessment-prerequisites.md).
:::
