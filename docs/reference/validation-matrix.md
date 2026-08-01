---
description: The phase-by-phase validation matrix for collection phases 5-21, mapping every check to its automated test or its manual live-tenant procedure.
---

# Validation Matrix

Collection phases 1–21 are code-complete. This page is the validation record for phases
5–21: every check, and how it is verified.

Each check falls into one of two categories:

| Marker | Meaning |
|---|---|
| **Automated** | Covered by the Pester suite. Runs offline on every push and pull request via `ci.yml`. No Azure credentials required. |
| **Live tenant** | Requires a real Azure tenant with the relevant service deployed. Cannot be verified offline — mocked data proves the code path, not the shape of real API responses. |

The distinction matters: an automated pass proves AzureScout handles the documented
response shape correctly. Only a live-tenant run proves the shape is what Azure actually
returns today.

## Current state

The suite is **1,648 automated tests across 56 files**, run by
[`ci.yml`](https://github.com/thisismydemo/azure-scout/blob/main/.github/workflows/ci.yml)
on every push and pull request.

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path .\tests\ -Output Detailed
```

Live-tenant checks are run against a scratch subscription before a release. The
[`azure-inventory.yml`](https://github.com/thisismydemo/azure-scout/blob/main/.github/workflows/azure-inventory.yml)
workflow (`workflow_dispatch`) is the harness for that — it runs a real headless scan with
a service principal and uploads the reports as artifacts for inspection.

## Phase 5 — Entra ID modules

| Check | Verification |
|---|---|
| Entra modules produce populated worksheets | **Live tenant** — needs a tenant with Graph permissions granted |
| Graph pagination, throttling, and backoff | **Automated** — `Invoke-AZSCGraphRequest.Tests.ps1` |
| All 17 Entra resource types normalize correctly | **Automated** — `Start-AZSCEntraExtraction.Tests.ps1` |
| Each Entra collector's Processing and Reporting phases | **Automated** — `Identity.Module.Tests.ps1` |

## Phase 6 — JSON output layer

| Check | Verification |
|---|---|
| `-OutputFormat Json` produces JSON only | **Automated** — `OutputFormat.Tests.ps1` |
| `-OutputFormat All` produces every format | **Automated** — `OutputFormat.Tests.ps1` |
| JSON evidence structure | **Automated** — `Report.JsonEvidence.Tests.ps1` |

## Phase 8 — ARM module expansion

| Check | Verification |
|---|---|
| Azure Local modules populate worksheets | **Live tenant** — needs an Azure Local deployment |
| Arc modules populate worksheets | **Live tenant** — needs Arc-enabled machines |
| Enhanced VPN fields for S2S, P2S, ExpressRoute | **Live tenant** — needs each connection type provisioned |
| Hybrid collector Processing and Reporting phases | **Automated** — `Hybrid.Module.Tests.ps1` |
| Networking collector Processing and Reporting phases | **Automated** — `Networking.Module.Tests.ps1` |

## Phase 10 — Excel specialized tabs

| Check | Verification |
|---|---|
| Overview tab holds only tenant-level summary | **Automated** — `Report.Excel.Tests.ps1` |
| Cost Management tab renders | **Automated** — `Report.Excel.Tests.ps1` |
| Security Overview tab renders | **Automated** — `Report.Excel.Tests.ps1` |
| Azure Update Manager tab renders | **Automated** — `Report.Excel.Tests.ps1` |
| Azure Monitor tab renders | **Automated** — `Report.Excel.Tests.ps1` |
| Chart/shape/tab styling (EPPlus-native, no Excel COM) | **Automated** — `Private.Reporting.Tests.ps1` (`Build-AZSCExcelChartStyle` unit tests, plus an end-to-end assertion that no `EXCEL` process was ever started). Needs no Excel install, so it runs on a hosted runner. |
| Overview pivots P0–P9 and their charts build from a real ReportCache | **Automated** — `Private.Reporting.Tests.ps1`; the P6 pivot is pinned in both directions (skipped cleanly on an empty source worksheet, built when the source has rows) |

## Phase 11 — Subscription and management group logging

| Check | Verification |
|---|---|
| All subscriptions listed, including empty and disabled | **Automated** — `Private.Extraction.Tests.ps1` |
| All management groups listed with hierarchy | **Live tenant** — needs a real MG tree and Management Group Reader |
| Management group access probe reports the count | **Automated** — `RunIsolation.Tests.ps1` |
| Missing tenant-root role prints the remediation tip | **Automated** — `RunIsolation.Tests.ps1` |
| Overview counts cover all subs and MGs, not just resource-bearing ones | **Automated** — `Report.Excel.Tests.ps1` |

## Phase 12 — Scope and auth defaults

| Check | Verification |
|---|---|
| Default run performs ARM-only discovery | **Automated** — `Invoke-AzureScout.Tests.ps1` |
| `-Scope All` includes Entra ID | **Automated** — `Invoke-AzureScout.Tests.ps1` |
| Permission pre-flight warns on missing Graph permissions | **Automated** — `Test-AZSCPermissions.Tests.ps1` |
| Resource provider check warns on unregistered providers | **Automated** — `PermissionAudit.Tests.ps1` |
| SPN + secret and SPN + certificate login | **Automated** — `Connect-AZSCLoginSession.Tests.ps1` |
| Device-code login | **Live tenant** — interactive by definition |

## Phase 13 — Azure Monitor and Insights coverage

| Check | Verification |
|---|---|
| All 24 monitoring collectors execute without error | **Automated** — `Monitor.Module.Tests.ps1` |
| Diagnostic settings capture resource-level configuration | **Live tenant** — needs resources with diagnostics configured |
| App Insights deep-data modules handle missing configuration | **Automated** — `Monitor.Module.Tests.ps1` |
| Report contains a worksheet per monitoring collector | **Automated** — `Monitor.Module.Tests.ps1` |

## Phase 14 — AI, Foundry, and ML coverage

| Check | Verification |
|---|---|
| All 27 AI/ML collectors execute without error | **Automated** — `AI.Module.Tests.ps1` |
| OpenAI deployments capture model details | **Live tenant** — needs an Azure OpenAI resource |
| AI Foundry hubs and projects detected via Kind filtering | **Live tenant** — needs a Foundry hub |
| ML workspace child resources enumerate | **Live tenant** — needs an ML workspace with compute and datastores |
| Resource provider warnings fire for unregistered AI providers | **Automated** — `PermissionAudit.Tests.ps1` |

## Phase 15 — Azure Virtual Desktop

| Check | Verification |
|---|---|
| Host pools, application groups, workspaces enumerate | **Automated** — `Compute.Module.Tests.ps1` |
| Session hosts capture status and session counts | **Live tenant** — needs running session hosts |
| Scaling plans capture all four time periods | **Automated** — `Compute.Module.Tests.ps1` |
| AVD on Azure Local detection via Arc association | **Live tenant** — needs AVD on Azure Local |
| Report contains all six AVD worksheets | **Automated** — `Compute.Module.Tests.ps1` |

## Phase 16 — Arc enhanced configuration

| Check | Verification |
|---|---|
| Arc site configurations enumerate | **Live tenant** — needs Arc sites |
| Arc extensions capture version, settings, auto-upgrade | **Automated** — `Hybrid.Module.Tests.ps1` |
| Arc-enabled SQL Server captures database count and ESU status | **Live tenant** — needs Arc-enabled SQL |
| Arc Data Services handles direct and indirect connectivity | **Automated** — `Hybrid.Module.Tests.ps1` |
| Report contains the four Arc worksheets | **Automated** — `Hybrid.Module.Tests.ps1` |

## Phase 17 — VM and Arc enrichment

| Check | Verification |
|---|---|
| VM extensions enumerate with versions and settings | **Automated** — `Compute.Module.Tests.ps1` |
| Backup status identifies protected vs unprotected VMs | **Live tenant** — needs a Recovery Services vault |
| Update compliance shows pending patch counts | **Live tenant** — needs Azure Update Manager |
| Arc servers capture the same depth as Azure VMs | **Automated** — `Hybrid.Module.Tests.ps1` |
| Performance metrics populate when the Monitor agent is installed | **Live tenant** — needs the agent deployed |
| Cost estimates appear for VMs | **Live tenant** — needs Cost Management API access |
| 500 VMs complete in under 30 minutes with parallel processing | **Live tenant** — a scale test |
| Graceful degradation: VMs without enrichment show N/A, no errors | **Automated** — `Compute.Module.Tests.ps1` |
| Per-subscription context is restored after quota collection | **Automated** — `RunIsolation.Tests.ps1` |

## Phase 18 — Category filtering

| Check | Verification |
|---|---|
| Module auto-discovery works after the folder restructure | **Automated** — `CategoryFiltering.Tests.ps1` |
| Single category runs only that category's modules | **Automated** — `CategoryFiltering.Tests.ps1` |
| Multiple categories | **Automated** — `CategoryFiltering.Tests.ps1` |
| Hybrid category runs Arc and Azure Local modules | **Automated** — `CategoryFiltering.Tests.ps1` |
| Category combined with scope | **Automated** — `CategoryFiltering.Tests.ps1` |
| Every alias resolves to its canonical value | **Automated** — `CategoryFiltering.Tests.ps1` |
| `Monitor` is canonical, `Monitoring` is the alias | **Automated** — `CategoryFiltering.Tests.ps1` |
| Report contains worksheets only for selected categories | **Automated** — `Report.Excel.Tests.ps1` |

The alias set itself is documented in the [Category Reference](./category-reference.md).

## Phase 19 — Final validation (cross-phase)

| Check | Verification |
|---|---|
| Full tenant scan completes | **Live tenant** — the end-to-end acceptance run |
| Empty tenant completes with zero resources and no errors | **Automated** — `Pipeline.Tests.ps1` |
| 1000+ resources complete with graceful throttling | **Live tenant** — a scale test |
| SPN auth scans both ARM and Entra | **Live tenant** — needs consented Graph application permissions |
| Multi-subscription tenant scans every subscription | **Live tenant** |
| Management groups capture parent-child relationships | **Live tenant** |
| Policy compliance captures recent compliance states | **Automated** — `Management.Module.Tests.ps1` |
| Defender assessments, secure score, alerts, pricing | **Automated** — `Security.Module.Tests.ps1` |
| Non-terminating errors do not abort the pipeline | **Automated** — `Pipeline.NonTerminatingErrors.Tests.ps1` |
| Collection resilience under partial failure | **Automated** — `Collect.Resilience.Tests.ps1` |

## Phase 20 — Permission audit

| Check | Verification |
|---|---|
| `-PermissionAudit` exits early — no extraction, no report | **Automated** — `PermissionAudit.Tests.ps1` |
| ARM output shows subscriptions and role assignments | **Automated** — `PermissionAudit.Tests.ps1` |
| `-IncludeEntraPermissions` produces the Graph permission table | **Automated** — `PermissionAudit.Tests.ps1` |
| Limited-permission SPN shows warnings | **Automated** — `PermissionAudit.Tests.ps1` |
| Fully-permissioned SPN shows all green for ARM | **Automated** — `PermissionAudit.Tests.ps1` |
| Global Reader shows all Graph permissions green | **Live tenant** — needs the directory role assigned |
| Provider table shows Registered/NotRegistered correctly | **Automated** — `PermissionAudit.Tests.ps1` |
| `-PermissionAudit -OutputFormat Json` saves a JSON report | **Automated** — `PermissionAudit.Tests.ps1` |
| The audit restores the caller's subscription context | **Automated** — `PermissionAudit.Tests.ps1`, `RunIsolation.Tests.ps1` |
| Audit survives a scalar-collapsing single subscription under StrictMode | **Automated** — `PermissionAudit.Tests.ps1` |

## Phase 21 — Markdown and AsciiDoc export

| Check | Verification |
|---|---|
| `-OutputFormat Markdown` generates a valid `.md` file | **Automated** — `OutputFormat.Tests.ps1` |
| `-OutputFormat AsciiDoc` generates a valid `.adoc` file | **Automated** — `OutputFormat.Tests.ps1` |
| Markdown tables render on GitHub (pipe-table format) | **Automated** — `OutputFormat.Tests.ps1` |
| AsciiDoc converts to PDF via `asciidoctor-pdf` | **Live tenant** — external toolchain |
| AsciiDoc converts to Word via Pandoc | **Live tenant** — external toolchain |
| `-OutputFormat Excel,AsciiDoc` generates both | **Automated** — `OutputFormat.Tests.ps1` |
| Modules with zero resources are skipped in Markdown/AsciiDoc | **Automated** — `OutputFormat.Tests.ps1` |
| Large tenant Markdown output streams without OOM | **Live tenant** — a scale test |
| AsciiDoc admonitions appear for security findings | **Automated** — `OutputFormat.Tests.ps1` |
| `-PermissionAudit -OutputFormat Markdown` generates a permissions report | **Automated** — `PermissionAudit.Tests.ps1` |

## Running the live-tenant checks

The live-tenant rows need a scratch subscription. The minimum useful setup is a
subscription with a VM, a storage account, a virtual network, and a Log Analytics
workspace; each additional service unlocks the rows that name it.

```powershell
# Full scan, all formats, into a named run folder
Invoke-AzureScout -TenantID '<tenant-id>' -Scope All -RunName 'release-validation' -Debug

# Scale check
Invoke-AzureScout -TenantID '<tenant-id>' -Category Compute -Debug

# Permission audit
Invoke-AzureScout -TenantID '<tenant-id>' -PermissionAudit -IncludeEntraPermissions
```

`-RunName` keeps each validation run in its own folder, so a re-run does not overwrite the
evidence from the previous one — see [Output Files & Formats](../guide/output.md).

## Related

- [Testing](../project/testing.md) — running and writing the Pester suite
- [Category Reference](./category-reference.md) — the category and alias mapping
- [Permissions](../guide/permissions.md) — the roles each check needs
