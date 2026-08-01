---
layout: home
description: See everything. Own your cloud. A PowerShell module for comprehensive Azure + Entra ID discovery, inventory, and CAF/WAF assessment.

hero:
  name: AzureScout
  text: See everything. Own your cloud.
  tagline: One PowerShell command that inventories your entire Azure estate — and scores it against CAF and WAF. Read-only, offline-capable, no agents.
  image:
    src: /images/azurescout-banner.svg
    alt: AzureScout
  actions:
    - theme: brand
      text: Get started
      link: /guide/
    - theme: alt
      text: What it assesses
      link: /reference/assessment-catalogue
    - theme: alt
      text: View on GitHub
      link: https://github.com/thisismydemo/azure-scout

features:
  - title: Two modes, one command
    details: Run bare for a wide inventory of everything in the tenant. Add -Assessment for a scored CAF/WAF review. Run with no parameters at all and a guided wizard walks you through it.
    link: /guide/overview
    linkText: How the modes differ
  - title: 242 collectors, 18 categories
    details: Every one of Microsoft's eighteen published service categories, from AI and Analytics through to Storage and Web — plus Entra ID identity objects via Microsoft Graph.
    link: /reference/arm-modules
    linkText: Browse the collectors
  - title: 46 assessments
    details: CAF design areas, WAF pillars, workload reviews, FinOps, DevOps and compliance — each backed by declarative rule files with published automated-versus-manual counts.
    link: /reference/assessment-catalogue
    linkText: Browse the assessments
  - title: Read-only, always
    details: Scout never creates, modifies or deletes anything in your tenant. Reader at the root management group is enough, and a pre-flight audit tells you exactly what you can and cannot collect before you run.
    link: /guide/permissions
    linkText: Permissions required
  - title: Reports in the format you need
    details: Excel workbooks, Word, PowerPoint, PDF, self-contained HTML, React, Power BI and JSON evidence — generated offline, with no service dependency.
    link: /guide/output
    linkText: Output formats
  - title: Unattended by design
    details: Azure Automation runbooks, GitHub Actions, or Azure DevOps pipelines. Managed identity or service principal, writing straight to blob storage.
    link: /automation-guide/
    linkText: Automation options
---

## Quick start

```powershell
# Install from the PowerShell Gallery
Install-Module -Name AzureScout

# Guided wizard — no parameters needed
Invoke-AzureScout

# Full inventory, ARM + Entra ID
Invoke-AzureScout -Scope All

# Scored CAF/WAF assessment
Invoke-AzureScout -Assessment LandingZone

# Check what you have access to, before running anything
Invoke-AzureScout -PermissionAudit
```

Already signed in with `Connect-AzAccount`? Scout uses that session — no extra flags.

## Where to go next

| If you want to… | Start here |
|---|---|
| Understand the two modes and pick one | [Overview](./guide/overview.md) |
| Install and run it for the first time | [Guide](./guide/) |
| Know what it can assess | [Assessment Catalogue](./reference/assessment-catalogue.md) |
| Know what it collects | [ARM Modules](./reference/arm-modules.md) |
| Work out which permissions to request | [Permissions](./guide/permissions.md) |
| Run it on a schedule | [Automation](./automation-guide/) |
| Add a collector or contribute | [Contributing](./project/contributing.md) |
