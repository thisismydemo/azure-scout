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

::: info Collect runs the full query set every time
`Invoke-Collect.ps1` accepts a `-Categories` parameter (and
`Invoke-ScoutAssessment` passes each assessment's declared `Collect` list, or
your `-Category` override, into it), but in the current implementation that
value is recorded into `collect.json`'s `_meta.categories` for provenance
only — **it does not filter which Resource Graph queries run.** Every
`Invoke-Collect` call executes the same fixed set of ~25 queries regardless
of assessment or `-Category`. The practical effect: choosing `-Assessment
Security` vs. `-Assessment LandingZone` changes which **rules** are scored
and which **ingestors** run, not how much data Collect pulls. This is worth
knowing if you were expecting `-Category` to shrink scan time the way it does
for `Invoke-AzureScout` (see [Category Filtering](category-filtering.md),
which is the v1, module-loading-level behavior — different mechanism, not
shared with the assessment platform).
:::

## Run modes

Every discovery category is an independently runnable, tagged assessment —
pass one, several, or `All` to `-Assessment`. All examples assume:

```powershell
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

::: warning Only scopes the AzGovViz ingest, not Collect
`-ManagementGroupId` is passed straight through to `Import-AzGovViz`, which
needs it to invoke the Azure Governance Visualizer. It is **not** used by
`Invoke-Collect` to scope the Resource Graph queries — those already run
tenant-wide against whatever subscriptions your authenticated context can
see (no `-Subscription`/`-ManagementGroup` filter is ever passed to
`Search-AzGraph`). For the 5 assessments that ingest AzGovViz
(`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`), omitting
`-ManagementGroupId` doesn't error — it silently skips the ingest and
governance rules degrade to `Unknown`. See
[Auth & permissions per scan type](assessment-permissions.md#-managementgroupid-and-the-azgovviz-only-assessments).
:::

### `-Scope`

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -Scope All        # default
Invoke-ScoutAssessment -Assessment LandingZone -Scope ArmOnly
Invoke-ScoutAssessment -Assessment LandingZone -Scope EntraOnly
```

::: info Ambiguity flagged, not guessed
`-Scope` is accepted (`ValidateSet 'All','ArmOnly','EntraOnly'`) and forwarded
to `Invoke-Collect`, which stores it in `_meta.scope` — but `Invoke-Collect`
has no ARM-vs-Entra branch in its query logic today (it only ever runs
Resource Graph / ARM queries; there is no Graph-based collection path in the
Collect layer). Functionally, in the current code, changing `-Scope` does not
change what Collect gathers. Treat it as reserved / forward-compatible rather
than a working ARM/Entra toggle for the assessment platform specifically —
this differs from `Invoke-AzureScout -Scope`, which does gate ARM vs. Entra
extraction in the v1 inventory tool (see [Usage Guide](usage.md#scope)).
:::

### `-Category` override

```powershell
Invoke-ScoutAssessment -Assessment Compute -Category Compute,Storage
```

`-Category` replaces the categories recorded for the run rather than adding
to the chosen assessment's own `Collect` list — but per the note above, it
does not change what Collect actually queries (everything runs regardless),
and it never changes which **rules** are scored (`Compute`'s `Rules` stay
`waf.reliability`/`waf.cost`/`waf.performance` no matter what `-Category` you
pass). Prefer leaving `-Category` unset and letting each assessment use its
own manifest-declared `Collect` list unless you have a specific provenance
reason to override it.

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
