---
description: Run a read-only CAF/WAF assessment with AzureScout — architecture, every run mode, all 22 assessments, and minimum auth per scan type.
---

# CAF/WAF Assessment Platform

Introduced in **v2.0.0**, AzureScout can score a tenant against the Microsoft
**Cloud Adoption Framework (CAF)** design areas and **Well-Architected
Framework (WAF)** pillars — not just inventory it. The assessment is
**read-only** end to end (ARM Reader at the management-group root, plus
read-only Graph app permissions for a subset of scans — see
[Auth & permissions per scan type](assessment-permissions.md)).

::: tip PowerShell 7 required
The assessment platform requires **PowerShell 7** (every script starts with
`#Requires -Version 7.0`). The v1 inventory features (`Invoke-AzureScout`)
still run on Windows PowerShell 5.1. Full details, including a module
bootstrap gap you need to work around manually:
[Assessment Prerequisites](assessment-prerequisites.md).
:::

## Architecture — three layers, JSON on disk

```
COLLECT  --collect.json-->  ASSESS  --findings.json-->  REPORT
```

Each layer runs independently from its JSON input, so you can collect once
and assess later, or re-render reports from an existing findings set without
re-scanning.

| Layer | What it does |
|-------|--------------|
| **Collect** | Read-only Azure Resource Graph queries produce a normalized `collect.json`, including a per-domain `domains.*` namespace. |
| **Ingest** | Folds Azure Governance Visualizer, an ARG query pack, and Azure Advisor into the same `collect.json`. |
| **Assess** | A declarative rule engine grades the collected data — **139 rules across 8 CAF design areas + 5 WAF pillars** — producing scored `findings.json` with a prioritized gap list. |
| **Report** | Renders `findings.json` into tiered deliverables. |

::: info Collect is now actually scoped by category
`Invoke-Collect.ps1`'s `-Categories` parameter (populated from each
assessment's declared `Collect` list, or your `-Category` override) **does
filter which Resource Graph queries run**. Every query in `Invoke-Collect` is
tagged with the `Collect` category name(s) whose rule files reference its
output — cross-domain references included (e.g. `waf.security` needs
`domains.databases.sqlServers`, so that query runs for both `Databases` and
`Security`). `subscriptions` always runs (base data every rule set needs).
Passing `-Categories '*'` (or an empty list, or omitting `-Category`/leaving
an assessment's own `Collect` list at `@('*')` — `LandingZone` and `Estate`
both do this) runs every query, same as before. The practical effect:
`-Assessment Security` now collects a materially smaller set of resource
types than `-Assessment LandingZone` (see the run below) — this is a
different mechanism from `Invoke-AzureScout`'s module-loading-level
[Category Filtering](category-filtering.md), but for the assessment platform
it now actually shrinks scan time and query volume, not just what gets
scored.

```powershell
# Pulls only Security-relevant resource types (Key Vaults, NSGs, private
# endpoints/DNS zones, SQL servers, ...) instead of the full ~25-query set.
Invoke-ScoutAssessment -Assessment Security -OutputFormat Json
```
:::

## Run modes

Every discovery category is an independently runnable, tagged assessment —
pass one, several, or `All` to `-Assessment`. All examples assume you've installed
and imported the module:

```powershell
# Install once, from the PowerShell Gallery (current version 2.0.1)
Install-Module -Name AzureScout

# Or import from a local clone
Import-Module ./AzureScout.psd1
```

### Full landing-zone assessment

Scores all 8 CAF areas and all 5 WAF pillars in one run, against an ALZ
benchmark diff.

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat All
```

### Single category

```powershell
Invoke-ScoutAssessment -Assessment Security -OutputFormat Html
```

### Multiple assessments in one run

```powershell
Invoke-ScoutAssessment -Assessment Networking,Security -OutputFormat Html
```

Findings from both are combined into one `findings.json` and one set of
reports for the run.

### Every assessment (`All`)

```powershell
Invoke-ScoutAssessment -Assessment All -OutputFormat All
```

`-Assessment All` expands to every key in `manifests/assessments.psd1` —
currently **22** assessments (see the [full registry](design/assessment-registry.md)).

### Collect once, assess later (`-CollectOnly` / `-FromCollect`)

```powershell
# Stop after Collect — writes collect.json and returns its path
Invoke-ScoutAssessment -Assessment LandingZone -CollectOnly

# Re-run Assess + Report from that saved collect.json, no re-scan
Invoke-ScoutAssessment -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi
```

Useful for iterating on rule changes or re-rendering a different output tier
without re-querying Azure.

### Permission pre-flight (`-PermissionAudit`)

```powershell
Invoke-ScoutAssessment -Assessment LandingZone,Identity -PermissionAudit
```

Checks read-only access for the requested assessment(s) **before** any
collection runs — see [Auth & permissions per scan type](assessment-permissions.md)
for exactly what this does and does not verify.

### Scoping to a management group (`-ManagementGroupId`)

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -ManagementGroupId 'contoso-root-mg' -OutputFormat Html
```

::: warning Scopes Collect too now — and still gates the AzGovViz ingest
`-ManagementGroupId` is passed to **both** `Import-AzGovViz` (which needs it
to invoke the Azure Governance Visualizer) **and** `Invoke-Collect` /
`Invoke-ArgQueryPack`, which now pass it through as `Search-AzGraph
-ManagementGroup` on every Resource Graph query. Omit it and both layers keep
the previous tenant-wide behavior (no `-ManagementGroup` filter is passed to
`Search-AzGraph` at all — not an empty/wildcard scope, the parameter is left
off entirely). For the 5 assessments that ingest AzGovViz (`LandingZone`,
`Management`, `Identity`, `Governance`, `Policy`), omitting
`-ManagementGroupId` still doesn't error — it silently skips the AzGovViz
ingest and governance rules degrade to `Unknown`, same as before. See
[Auth & permissions per scan type](assessment-permissions.md#-managementgroupid-and-the-azgovviz-only-assessments).
:::

### `-Scope`

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -Scope All        # default
Invoke-ScoutAssessment -Assessment LandingZone -Scope ArmOnly    # identical to All today
Invoke-ScoutAssessment -Assessment LandingZone -Scope EntraOnly  # throws -- see below
```

::: info EntraOnly throws instead of silently collecting nothing
The assessment platform's Collect layer is ARG/ARM only — there is no
Graph-based collection path in `Invoke-Collect`. `-Scope EntraOnly` used to be
accepted and silently produce a run that could never gather any data;
it now **throws immediately** with a redirect to the tool that actually has
an Entra collection path:

```
Invoke-ScoutAssessment collects ARM/Resource Graph data only -- the assessment
platform's Collect layer has no Entra ID collection path. Use
'Invoke-AzureScout -Scope EntraOnly' for Entra ID inventory instead.
```

`ArmOnly` and `All` remain accepted and behave identically (both just run the
ARM collect) — kept for forward compatibility rather than removed, since
`Invoke-Collect` has no ARM-vs-Entra branch to differentiate them. This
differs from `Invoke-AzureScout -Scope`, which does gate ARM vs. Entra
extraction in the v1 inventory tool (see [Usage Guide](usage.md#scope)) — use
that cmdlet for Entra ID inventory.
:::

### `-Category` override

```powershell
Invoke-ScoutAssessment -Assessment Compute -Category Compute,Storage
```

`-Category` replaces the categories recorded for the run — and, per the note
above, this now **does** change what `Invoke-Collect` actually queries (it
runs only the queries tagged for the categories you pass, plus base data).
It never changes which **rules** are scored (`Compute`'s `Rules` stay
`waf.reliability`/`waf.cost`/`waf.performance` no matter what `-Category` you
pass) — so overriding `-Category` to something narrower than what those rules
need can starve them of data (they'll show `Unknown`/fail-vacuously instead
of a real result). Prefer leaving `-Category` unset and letting each
assessment use its own manifest-declared `Collect` list, which is kept in
sync with what its `Rules` actually reference.

### `-OutputFormat` — one example per tier

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat PowerBi
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Html
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Pptx
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Excel
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat Json
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat All     # PowerBi, Html, Pptx, Excel, Json
```

`-OutputFormat` also accepts an array (`-OutputFormat Html,Pptx`).

### `-OutputPath`

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -OutputPath 'D:\Reports\Scout'
```

Each run writes into a timestamped subfolder (`<OutputPath>/yyyyMMdd_HHmmss/`).

## All 22 assessments

The full catalogue — description, `Collect`/`Ingest`, CAF areas / WAF
pillars, and default report tiers, generated from
`manifests/assessments.psd1` — lives in the
**[Assessment Registry](design/assessment-registry.md)**. Minimum auth per
assessment lives in **[Auth & permissions per scan type](assessment-permissions.md)**.

## Scoring

- Each rule evaluates to **Pass**, **Fail**, **Partial**, **Manual**, **Unknown**, or **Error**.
- Framework scores are the rule-count-weighted roll-up of area/pillar scores.
- `Unknown`/`Error` are surfaced, never silently dropped — a broken rule cannot inflate a score.
- The **`Manual`** status intentionally hands the un-automatable checks to a human, with the collected evidence already attached.

## Report tiers

| Tier | Output | Notes |
|------|--------|-------|
| Power BI | `powerbi/*.csv` + `.pbit` | Primary analytics tier (star schema) |
| HTML | `report.html` | Self-contained, single file |
| PowerPoint | `assessment_deck.pptx` | Executive deck via the OpenXML SDK — **no Python dependency**. First use needs the `dotnet` SDK; see [Assessment Prerequisites](assessment-prerequisites.md#powerpoint-tier-net-sdk-not-python). |
| Excel | `assessment_evidence.xlsx` | Evidence tier |
| JSON | `findings.json` | The machine-readable contract |

## Minimum auth per scan type

- **Every assessment** needs **ARM `Reader` at the tenant-root management group**. No exceptions.
- **Only 5 assessments** additionally need Microsoft Graph **application**
  permissions — the ones whose `Ingest` includes `AzGovViz`: `LandingZone`,
  `Management`, `Identity`, `Governance`, `Policy`.
- All other 17 assessments need **ARM Reader only** — no Graph permission at all.
- `PrivilegedAccess.Read.AzureResources` needs an **Entra ID P2 license** and
  is currently never exercised anyway — `Import-AzGovViz.ps1` unconditionally
  passes `-NoPIMEligibility`.

Full matrix, the exact permissions list, and what `-PermissionAudit` does and
does not verify: **[Auth & permissions per scan type](assessment-permissions.md)**.

```powershell
# Pre-flight before any collection runs
Invoke-ScoutAssessment -Assessment LandingZone -PermissionAudit
```

## Design reference

The full architecture, rule catalogue, and decision records live in the
[Master Design & Plan](design/master-plan.md) and the
[assessment registry](design/assessment-registry.md).
