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
| **Ingest** | Folds governance data (natively collected by default — see below), an ARG query pack, and Azure Advisor into the same `collect.json`. |
| **Assess** | A declarative rule engine grades the collected data — **139 rules across 8 CAF design areas + 5 WAF pillars** — producing scored `findings.json` with a prioritized gap list. |
| **Report** | Renders `findings.json` into tiered deliverables. |

::: info Governance data is collected natively — no AzGovViz dependency
`Import-Governance` (`src/ingest/Import-Governance.ps1`) is the **default**
governance collector for the five assessments that need governance data
(`LandingZone`, `Management`, `Identity`, `Governance`, `Policy` — their
manifest `Ingest` value is `Governance`, not `AzGovViz`). It populates
`collect.json`'s `governance` object natively from Azure Resource Graph
(policy assignments, role assignments, management groups) plus ambient-token
ARM REST calls (budgets, resource locks) — no cloned repo, no `AzAPICall`
install prompt, fully unattended. It needs only **ARM Reader at the
management-group root**, same as every other assessment — no additional
Graph permission.

The third-party Azure Governance Visualizer remains available as an **opt-in**
`Ingest` value if you want it specifically, but nothing depends on it by
default anymore. Live-verified against the HCS tenant: real policy/role
assignments are collected, CAF governance/identity rules score real
Pass/Fail, and the ALZ benchmark degrades to an explicit `Unknown` — not a
false 0% — when management-group data isn't visible to the identity running
the scan. Two datasets are intentionally always empty: `classicAdministrators`
(a retired API — the CAF-IDN-03 rule asserts `notExists`, so empty is
compliant) and `pimEligibility` (needs an Entra ID P2 license plus
`PrivilegedAccess.Read.AzureResources`, which only the opt-in AzGovViz path
ever requests).
:::

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

### Unattended, one-command run (`Invoke-ScoutPipeline`)

```powershell
Invoke-ScoutPipeline -Assessment LandingZone -OutputFormat All -OutputPath 'D:\Reports\Scout'
```

`Invoke-ScoutPipeline` (exported public cmdlet, `src/Invoke-ScoutPipeline.ps1`)
runs collect → assess → report **headless** in one call, writing everything
into a single dated run folder. It is non-interactive throughout — it forces
`$ConfirmPreference = 'None'` and `$ProgressPreference = 'SilentlyContinue'`
for the duration of the run. By default it runs the read-only permission
pre-flight first (pass `-SkipPermissionAudit` to skip it), and it wraps the
orchestrator in try/catch so a failure in one exporter degrades the run to
`PartialSuccess` rather than losing the output that did succeed.

It writes two summary files into the run folder alongside the usual report
tiers:

- `pipeline-summary.json` — CI-facing: `schemaVersion`, `startedOn` /
  `finishedOn`, `elapsedSeconds`, `assessments`, `formats`,
  `findingsByStatus`, `permissionAudit`, and `outcome` (one of `Success`,
  `PartialSuccess`, `Failed`).
- `pipeline-summary.md` — the human-readable equivalent.

`Invoke-ScoutPipeline` returns the run-folder path. It only throws (and sets
`$LASTEXITCODE = 1`) when `outcome` is `Failed` — a `PartialSuccess` outcome
returns normally so a CI step can inspect `pipeline-summary.json` and decide
what to do with a partial run.

Parameters: `-Assessment`, `-OutputFormat` (default `All`), `-OutputPath`,
`-ManagementGroupId`, `-Category`, `-SkipPermissionAudit` — the same run-mode
semantics as `Invoke-ScoutAssessment` described throughout this page apply
here too.

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

::: warning Scopes Collect too now — and the benchmark still needs MG-root visibility
`-ManagementGroupId` is passed to `Invoke-Collect` / `Invoke-ArgQueryPack`,
which pass it through as `Search-AzGraph -ManagementGroup` on every Resource
Graph query (and, if you've opted into the legacy `AzGovViz` ingestor, to
`Import-AzGovViz` too). Omit it and Collect keeps tenant-wide behavior (no
`-ManagementGroup` filter is passed to `Search-AzGraph` at all — not an
empty/wildcard scope, the parameter is left off entirely).

For the 5 assessments that ingest governance data (`LandingZone`,
`Management`, `Identity`, `Governance`, `Policy`), the **native**
`Import-Governance` collector (the default `Ingest = Governance`) runs
regardless of whether `-ManagementGroupId` is supplied — it does not silently
skip. What actually needs management-group visibility is the **ALZ benchmark
diff**: if the identity running the scan doesn't have Reader at the
management-group root (with or without `-ManagementGroupId` set), the
benchmark degrades to an explicit `Unknown` — not a false 0% — rather than
failing loudly. See [Auth & permissions per scan
type](assessment-permissions.md#-managementgroupid-and-governance-data-collection).
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
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat React
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat All     # PowerBi, Html, Pptx, Excel, Json, React
```

`-OutputFormat` also accepts an array (`-OutputFormat Html,Pptx`). `React`
produces a single self-contained `report-react.html` — see
[Report tiers](#report-tiers) below — and is also available on
`Invoke-ScoutPipeline` via its own `-OutputFormat` parameter.

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

## Cross-run drift

`Get-ScoutDrift` computes drift between the current run and the previous run
for the same assessment: each finding is classified **New**, **Resolved**
(`Fail`/`Partial` → `Pass`), **Regressed** (`Pass` → `Fail`/`Partial`), or
**Unchanged**, plus an overall weighted score delta. History is kept in an
append-only `findings-history.json` under a `.scout-history/` folder in the
output root, keyed by run id — the first run for a given assessment becomes
the baseline (nothing to diff against yet). `Invoke-ScoutAssessment` computes
drift automatically after scoring and feeds it into the [React
report](#report-tiers)'s Drift tab; a drift computation failure is non-fatal
to the rest of the run.

## Report tiers

| Tier | Output | Notes |
|------|--------|-------|
| Power BI | `powerbi/*.csv` + `.pbit` | Primary analytics tier (star schema) |
| HTML | `report.html` | Self-contained, single file |
| PowerPoint | `assessment_deck.pptx` | Executive deck via the OpenXML SDK — **no Python dependency**. First use needs the `dotnet` SDK; see [Assessment Prerequisites](assessment-prerequisites.md#powerpoint-tier-net-sdk-not-python). |
| Excel | `assessment_evidence.xlsx` | Evidence tier |
| JSON | `findings.json` | The machine-readable contract |
| React | `report-react.html` | Self-contained (CSS/JS inline, findings embedded as a JSON blob, no external/CDN requests). Client-side filter by Framework/Area/Severity/Status, sortable/searchable findings table, a summary dashboard, and a Drift tab showing cross-run drift (see [Cross-run drift](#cross-run-drift)). |

## Minimum auth per scan type

- **Every assessment** needs **ARM `Reader` at the tenant-root management group**. No exceptions.
- The 5 assessments that ingest governance data (`LandingZone`, `Management`,
  `Identity`, `Governance`, `Policy`) use the **native** `Import-Governance`
  collector by default — ARM Reader at the MG root is enough for them too; no
  Graph permission is required by default. The ALZ benchmark specifically
  needs that MG-root visibility to fully resolve; without it, it degrades to
  an explicit `Unknown` rather than a false 0%.
- Microsoft Graph **application** permissions are only needed if you opt one
  of those 5 assessments into the legacy `AzGovViz` ingestor instead of the
  native default — see [Auth & permissions per scan
  type](assessment-permissions.md) for exactly which permissions and when.
- `PrivilegedAccess.Read.AzureResources` needs an **Entra ID P2 license** and,
  even on the opt-in `AzGovViz` path, is currently never exercised —
  `Import-AzGovViz.ps1` unconditionally passes `-NoPIMEligibility`. The native
  `Import-Governance` collector doesn't collect PIM-eligible role assignments
  either (`pimEligibility` is intentionally always empty for the same
  license/permission reason).

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
