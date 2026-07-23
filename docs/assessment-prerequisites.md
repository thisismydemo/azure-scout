---
description: Software, PowerShell module, and .NET SDK prerequisites specific to the AzureScout CAF/WAF assessment platform (Invoke-ScoutAssessment).
---

# Assessment Prerequisites

These prerequisites are **specific to the CAF/WAF assessment platform**
(`Invoke-ScoutAssessment`, `Test-ScoutPermission`). They are additional to —
not a replacement for — the v1 inventory prerequisites in
[Prerequisites & Required Modules](prerequisites.md).

::: tip PowerShell 7 is a hard requirement
Every assessment-platform script starts with `#Requires -Version 7.0`. Unlike
the v1 inventory cmdlet (`Invoke-AzureScout`), which still runs on Windows
PowerShell 5.1, **`Invoke-ScoutAssessment` will not load under PowerShell
5.1** — the `#Requires` statement blocks it outright.
:::

## System requirements

| Requirement | Details |
|---|---|
| PowerShell | 7.0.3+ (source: [`docs/design/master-plan.md` §10](design/master-plan.md#10-dependencies-from-spec-10)) |
| Operating System | Windows, Linux, or macOS — the platform is pure PowerShell/.NET |
| .NET SDK | Required only for the PowerPoint (`Pptx`) report tier — see [below](#powerpoint-tier-net-sdk-not-python) |
| `git` | Required only when an assessment ingests AzGovViz (see [Auth & permissions](assessment-permissions.md)) — used to shallow-clone the Azure Governance Visualizer tool at first use |

## Required PowerShell modules

::: warning Not all of these are auto-installed
AzureScout's module bootstrap (`AzureScout.psm1`) auto-installs a fixed list
of modules on import: `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`,
`Az.Storage`, `Az.Compute`, `Az.Resources`. That list was written for the v1
inventory cmdlet and **does not include `powershell-yaml` or `Az.Advisor`**,
both of which the assessment platform needs. If either is missing,
`Invoke-ScoutAssessment` throws when it reaches the step that needs it,
rather than auto-installing it for you. Install them manually before your
first assessment run (below).
:::

| Module | Purpose | Required for | Auto-installed by `AzureScout.psm1`? |
|---|---|---|---|
| `Az.Accounts` | Authentication / token acquisition | All | Yes |
| `Az.ResourceGraph` | The Collect layer's Resource Graph queries | All | Yes |
| `Az.Resources` | Role assignment reads (permission pre-flight) | All | Yes |
| `powershell-yaml` | Parses the `caf.*`/`waf.*` rule YAML files (`Get-RuleSet`) | All scoring (any assessment with `Rules`) | **No — install manually** |
| `Az.Advisor` | `Get-AzAdvisorRecommendation`, used by the `AdvisorScores` ingest | Assessments whose `Ingest` includes `AdvisorScores` (`LandingZone`, `Management`, `Security`, `Compute`, `Cost`) | **No — install manually** |
| `ImportExcel` | Excel evidence-tier report (`Export-Excel`) | `-OutputFormat Excel` | Yes |
| `AzAPICall` | Dependency of the third-party Azure Governance Visualizer | Assessments whose `Ingest` includes `AzGovViz` | No — `Import-AzGovViz.ps1` installs it itself at first use (`Install-Module AzAPICall -Scope CurrentUser -Force`) if not already present |

```powershell
# Manual install — covers the gap in AzureScout.psm1's auto-bootstrap
Install-Module -Name powershell-yaml -Scope CurrentUser -Force
Install-Module -Name Az.Advisor       -Scope CurrentUser -Force
```

::: info `Az.Security` is documented, not yet wired up
`docs/design/master-plan.md` §10 and `src/README.md` list `Az.Security` as a
dependency, but no current assessment code calls an `Az.Security` cmdlet —
`Security`-category rules read `collect.security.defenderPlans`, which the
Collect layer (`Invoke-Collect.ps1`) currently always returns empty (`@()`).
Installing it does no harm, but it is not load-bearing for any assessment
today.
:::

## PowerPoint tier — .NET SDK, not Python

The `Pptx` report tier (`-OutputFormat Pptx`) renders the executive deck with
the **OpenXML SDK** (`DocumentFormat.OpenXml`), not `python-pptx` and not
PowerPoint COM automation — see the accepted decision record,
[PPTX executive-deck renderer](design/decisions/pptx-renderer.md).

::: tip No Python required
Earlier design drafts specced a `python3` + `python-pptx` shell-out for the
PPTX tier. That was superseded — `src/report/renderers/Export-Pptx.ps1` is
pure PowerShell/.NET today. **You do not need Python installed anywhere in
the pipeline for any output format.**
:::

What `Export-Pptx.ps1` actually needs, and what happens the first time you run it:

1. On first use, it checks for a cached copy of `DocumentFormat.OpenXml`
   3.0.2 (and its transitive dependencies) under
   `output/.tools/openxml/3.0.2/`.
2. If not cached, it requires the **`dotnet` CLI on `PATH`** — it shells out
   to `dotnet build` against a throwaway class-library project that
   references the NuGet package, which resolves and downloads the assembly
   graph via NuGet/MSBuild, then caches the three resulting DLLs.
3. Every later run (same machine) loads the cached DLLs via `Add-Type -Path`
   — no network access, no `dotnet` needed once the cache is warm.
4. If `dotnet` is not on `PATH` and nothing is cached, `Export-Pptx` throws a
   clear error rather than silently skipping the deck.

```powershell
# Verify the .NET SDK is available before your first -OutputFormat Pptx run
dotnet --version
```

::: warning `src/README.md` is stale
`src/README.md`'s Dependencies table still lists `python3 + python-pptx` for
the PPTX tier. That reflects an earlier prototype
(`src/report/renderers/Export-Pptx.ps1` pre-AB#5044) and does not match the
accepted, implemented renderer described above and in
[the decision record](design/decisions/pptx-renderer.md). Trust this page and
the decision record, not `src/README.md`, for the PPTX tier.
:::

## What the Estate / v1 inventory does NOT need

The `Estate` assessment (`-Assessment Estate`) is inventory-only — it has no
`Rules`, so it never calls `Get-RuleSet` and therefore never needs
`powershell-yaml`. It still runs under PowerShell 7 through the same
`Invoke-ScoutAssessment` entry point, so the PS7 requirement above still
applies even though it doesn't score anything.

## Next steps

- [Auth & permissions per scan type](assessment-permissions.md)
- [Assessment guide — run modes and examples](assessment.md)
- [Assessment Registry — all 22 assessments](design/assessment-registry.md)
