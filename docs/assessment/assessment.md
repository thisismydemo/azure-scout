---
description: Run a read-only CAF/WAF assessment with AzureScout — architecture, every run mode, the assessment registry, and minimum auth per scan type.
---

# CAF/WAF Assessment Platform

Introduced in **v2.0.0**, AzureScout can score a tenant against the Microsoft
**Cloud Adoption Framework (CAF)** design areas and **Well-Architected
Framework (WAF)** pillars — not just inventory it. The assessment is
**read-only** end to end (ARM Reader at the management-group root, plus
read-only Graph app permissions for a subset of scans — see
[Auth & permissions per scan type](./assessment-permissions.md)).

::: info Inventory and assessment are different questions
**Inventory** answers *"what is there?"* — a list of resources and their
properties, no opinion attached. **Assessment** answers *"is what is there any
good?"* — findings, a Pass/Fail/Partial verdict per rule, and a score, measured
against CAF/WAF. Assessment always *consumes* inventory (you cannot score what
has not been discovered); inventory stands alone and needs no assessment to be
useful. This page is about assessment. For the resources themselves, run
`Invoke-AzureScout` without `-Assessment` — see [Overview](../guide/overview.md).
:::

::: tip PowerShell 7 required
**PowerShell 7 on PowerShell Core** — for the whole module, not just this mode.
`AzureScout.psd1` declares `PowerShellVersion = '7.0'` and
`CompatiblePSEditions = @('Core')`, so `Import-Module` rejects Windows
PowerShell 5.1 outright. Assessment mode additionally needs modules the
inventory auto-install list does not cover, plus a `.NET SDK` for the
PowerPoint tier — see [Assessment Prerequisites](./assessment-prerequisites.md).
:::

::: info One command
Assessment is a mode of `Invoke-AzureScout`, not a separate tool:
`Invoke-AzureScout -Assessment LandingZone`. The former standalone assessment
command was removed in v3.0.0; use the unified entry point — see [Overview](../guide/overview.md).
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
| **Ingest** | Folds governance data (natively collected by default — see below) and Azure Advisor into the same `collect.json`. |
| **Assess** | A declarative rule engine grades the collected data — **395 rules across 44 rule files** (170 evaluated automatically, 225 requiring manual confirmation) — producing scored `findings.json` with a prioritized gap list. |
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

Since AB#6779, four of those five datasets are collected once by the
collection pass (`src/collect/Get-ScoutGovernanceDataset.ps1`) rather than
here: role assignments, policy assignments, resource locks and budgets. That
is what lets the inventory report render them as worksheets — `Role
Assignments`, `Policy Assignments`, `Resource Locks` and `Budgets` — without
a second round trip. `Import-Governance` reuses whatever the collect pass
hands it and queries only what it is not given, so the call count for an
assessment run is unchanged. Management groups are still collected here.

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

::: info `ArgQueryPack` is retired
The `ArgQueryPack` ingestor is gone. It re-ran six Resource Graph queries that
`Invoke-Collect` had already gathered, and it **overwrote** the collector's
results with worse copies — two of its six queries had no divide-by-zero
guard where the collector's had one, and a `-Force` replace from this
ingestor had already caused a live incident (a false `CAF-SEC-03`/`CAF-SEC-06`
fail from wiped networking data). If a manifest entry still names
`ArgQueryPack` in its `Ingest` list, it is now silently ignored (with a
verbose message) rather than run — no assessment depended on data that
`ArgQueryPack` alone provided.
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
`-Assessment 'Assess: Security'` now collects a materially smaller set of resource
types than `-Assessment LandingZone` (see the run below) — this is a
different mechanism from `Invoke-AzureScout`'s module-loading-level
[Category Filtering](../guide/category-filtering.md), but for the assessment platform
it now actually shrinks scan time and query volume, not just what gets
scored.

```powershell
# Pulls only Security-relevant resource types (Key Vaults, NSGs, private
# endpoints/DNS zones, SQL servers, ...) instead of the full ~25-query set.
Invoke-AzureScout -Assessment 'Assess: Security' -OutputFormat Json
```
:::

## Run modes

Every discovery category is an independently runnable, tagged assessment —
pass one, several, or `All` to `-Assessment`. All examples assume you've installed
and imported the module:

```powershell
# Install once, from the PowerShell Gallery
Install-Module -Name AzureScout

# Or import from a local clone
Import-Module ./AzureScout.psd1
```

### Full landing-zone assessment

Scores all 8 CAF areas and all 5 WAF pillars in one run, against an ALZ
benchmark diff.

```powershell
Invoke-AzureScout -Assessment LandingZone -OutputFormat All
```

### Single category

```powershell
Invoke-AzureScout -Assessment 'Assess: Security' -OutputFormat Html
```

### Multiple assessments in one run

```powershell
Invoke-AzureScout -Assessment 'Assess: Networking','Assess: Security' -OutputFormat Html
```

Findings from both are combined into one `findings.json` and one set of
reports for the run.

### Every assessment (`All`)

```powershell
Invoke-AzureScout -Assessment All -OutputFormat All
```

`-Assessment All` expands to every key in `manifests/assessments.psd1` —
currently **46 registry entries** (see the generated [Assessment Catalogue](../reference/assessment-catalogue.md)). Most are not distinct assessments — see
[the registry entries section below](#all-24-registry-entries-and-what-the-wizard-actually-offers)
and the [full registry](../design/assessment-registry.md) for what that number
actually breaks down into.

### Inventory + assessment in one collect (`-InventoryAndAssessment` / `-Both`)

```powershell
Invoke-AzureScout -Assessment LandingZone -InventoryAndAssessment -OutputFormat All
```

Runs the full inventory pass and the assessment from **one** Azure collection —
the assessment is handed the inventory's already-collected rows instead of
re-querying. Previously this collect-once path was reachable only by
answering "both" in the interactive wizard; `-InventoryAndAssessment`
(alias `-Both`) reaches it from a script or CI without going through the
wizard at all.

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
semantics described throughout this page apply
here too.

### Collect once, assess later (`-CollectOnly` / `-FromCollect`)

```powershell
# Stop after Collect — writes collect.json and returns its path
Invoke-AzureScout -Assessment LandingZone -CollectOnly

# Re-run Assess + Report from that saved collect.json, no re-scan
Invoke-AzureScout -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi
```

Useful for iterating on rule changes or re-rendering a different output tier
without re-querying Azure.

### Permission pre-flight (`-PermissionAudit`)

```powershell
Invoke-AzureScout -Assessment LandingZone,Identity -PermissionAudit
```

Checks read-only access for the requested assessment(s) **before** any
collection runs — see [Auth & permissions per scan type](./assessment-permissions.md)
for exactly what this does and does not verify.

### Scoping to a management group (`-ManagementGroupId`)

```powershell
Invoke-AzureScout -Assessment LandingZone -ManagementGroup 'contoso-root-mg' -OutputFormat Html
```

::: warning Scopes Collect too now — and the benchmark still needs MG-root visibility
`-ManagementGroupId` is passed to `Invoke-Collect`,
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
type](./assessment-permissions.md#-managementgroupid-and-governance-data-collection).
:::

### `-Scope`

```powershell
Invoke-AzureScout -Assessment LandingZone -Scope All        # default
Invoke-AzureScout -Assessment LandingZone -Scope ArmOnly    # identical to All today
Invoke-AzureScout -Assessment LandingZone -Scope EntraOnly  # throws -- see below
```

::: info EntraOnly throws instead of silently collecting nothing
The assessment platform's Collect layer is ARG/ARM only — there is no
Graph-based collection path in `Invoke-Collect`. `-Scope EntraOnly` used to be
accepted and silently produce a run that could never gather any data;
it now **throws immediately** with a redirect to the tool that actually has
an Entra collection path:

```
Invoke-AzureScout collects ARM/Resource Graph data only -- the assessment
platform's Collect layer has no Entra ID collection path. Use
'Invoke-AzureScout -Scope EntraOnly' for Entra ID inventory instead.
```

`ArmOnly` and `All` remain accepted and behave identically (both just run the
ARM collect) — kept for forward compatibility rather than removed, since
`Invoke-Collect` has no ARM-vs-Entra branch to differentiate them. This
differs from `Invoke-AzureScout -Scope`, which does gate ARM vs. Entra
extraction in inventory mode (see [Usage Guide](../guide/usage.md#scope)) — use
that cmdlet for Entra ID inventory.
:::

### `-Category` override

```powershell
Invoke-AzureScout -Assessment 'Assess: Compute' -Category Compute,Storage
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
Invoke-AzureScout -Assessment LandingZone -OutputFormat PowerBi
Invoke-AzureScout -Assessment LandingZone -OutputFormat Html
Invoke-AzureScout -Assessment LandingZone -OutputFormat Pptx
Invoke-AzureScout -Assessment LandingZone -OutputFormat Excel
Invoke-AzureScout -Assessment LandingZone -OutputFormat Json
Invoke-AzureScout -Assessment LandingZone -OutputFormat JsonEvidence
Invoke-AzureScout -Assessment LandingZone -OutputFormat React
Invoke-AzureScout -Assessment LandingZone -OutputFormat Word
Invoke-AzureScout -Assessment LandingZone -OutputFormat EChartsDashboard
Invoke-AzureScout -Assessment LandingZone -OutputFormat Pdf
Invoke-AzureScout -Assessment LandingZone -OutputFormat All     # PowerBi, Html, Pptx, Excel, Json, JsonEvidence, React, Word, EChartsDashboard, Pdf
```

`-OutputFormat` also accepts an array (`-OutputFormat Html,Pptx`). `React`
produces a single self-contained `report-react.html`; `Word`, `EChartsDashboard`,
and `Pdf` are three more self-contained tiers added in v2.2.0 — see
[Report tiers](#report-tiers) below — and all are also available on
`Invoke-ScoutPipeline` via its own `-OutputFormat` parameter.

### `-OutputPath`

```powershell
Invoke-AzureScout -Assessment LandingZone -OutputPath 'D:\Reports\Scout'
```

Each run writes into a timestamped subfolder (`<OutputPath>/yyyyMMdd_HHmmss/`).

## All 46 registry entries — and what the wizard actually offers

The full catalogue — description, `Collect`/`Ingest`, CAF areas / WAF
pillars, and default report tiers, generated from
`manifests/assessments.psd1` — lives in the
**[Assessment Registry](../design/assessment-registry.md)**. Minimum auth per
assessment lives in **[Auth & permissions per scan type](./assessment-permissions.md)**.

::: warning 46 registry entries is not 46 independent assessments
`manifests/assessments.psd1` has **46 keys**, but that is a count of registry
*entries*, not of distinct things Scout scores. **`LandingZone` is the one
real roll-up assessment** — it pulls in every CAF design-area and WAF-pillar
rule file. Many of the other entries are narrower *views* over that same
rule set, not separate assessments:

- **15 are the `Assess: ` category slices** (`Assess: Compute`, `Assess:
  Security`, …) — a category filter over `LandingZone`'s rule set, one per
  Scout inventory category. They collided with Scout's fifteen **inventory**
  category names — `Compute` filters what gets *collected*, `Assess: Compute`
  filters what gets *scored* — so they're now prefixed `Assess: ` to stop the
  two different things sitting side by side under one label
  (`-Assessment 'Assess: Compute'`, quoted — the name has a colon and a
  space). **The old unprefixed name still works**: `Resolve-ScoutAssessmentName`
  maps it to the prefixed one and prints a warning telling you what to
  change. This is a stopgap, not the end state — a future release retires
  these fifteen once genuine per-pillar and per-design-area assessments exist
  to replace them (see [Roadmap](../project/roadmap.md#caf-waf-assessment-programme)).
- **4 are sub-bundles** narrower still than a category (`Governance`,
  `Policy`, `UpdateManager`, `Monitoring`). `Governance` and `Policy` are
  presently byte-identical — same `Category`/`Collect`/`Ingest`/`Rules` — a
  known duplicate, not two different assessments.
- **`Estate` is not an assessment at all.** Its `Rules` list is empty, so it
  scores nothing — it is a full inventory pull that happens to sit in the
  assessment registry.

What's left after subtracting those: `LandingZone` (the roll-up), `Cost` (a
targeted cost/TCO pull), `CrossResource` (findings that need two datasets
correlated), and `SMART` (the migration-readiness assessment, scored against
its own enumerated source — see [SMART's framework page](../frameworks/smart-question-set.md)).
**Four genuinely distinct things, not 24.**

**The interactive wizard does not list `Estate`**, and does not list any
entry whose declared rule-file glob matches no file on disk — an entry that
would run and silently return zero findings reads as "nothing wrong" rather
than "nothing was checked," so it is left off rather than shown. You can
still run `Estate` directly — `-Assessment Estate` — since the wizard's
filtering is a menu courtesy, not an authorization check. Every other entry
has at least one matching rule file, so the wizard's rule-file filter admits
**23 of the 24**; `SMART` is then further gated separately, at the wizard
level, on whether the current estate actually has migration data to score.
:::

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
the baseline (nothing to diff against yet). Assessment mode computes
drift automatically after scoring and feeds it into the [React
report](#report-tiers)'s Drift tab; a drift computation failure is non-fatal
to the rest of the run.

## Cross-run resource (inventory) drift

`Get-ScoutInventoryDrift` (AB#326) is the resource-level counterpart to
`Get-ScoutDrift` above: `Get-ScoutDrift` tracks how each **rule** scored across
runs, while `Get-ScoutInventoryDrift` tracks what actually changed in the
**collected Azure estate itself** — independent of how any rule scored it.
It is not wired into assessment mode automatically; call it yourself
with the same `collect.json` and a caller-controlled run id:

```powershell
$collect = Get-Content ./output/20260724_101500/collect.json -Raw | ConvertFrom-Json
Get-ScoutInventoryDrift -Collect $collect -HistoryPath ./output/.scout-history -RunId '20260724_101500'
```

Each resource gets a stable id built from whichever recognized identity
fields it carries (falling back to a content hash so nothing is silently
dropped), then compared against the previous run's snapshot: **Added**,
**Removed**, **Changed** (with a per-field before/after diff), or
**Unchanged** (rolled into the summary count only). The first-ever run for a
given `-HistoryPath` returns an explicit baseline (`IsBaseline = $true`)
rather than reporting every resource as Added. History is appended to
`inventory-history.json`, alongside `Get-ScoutDrift`'s
`findings-history.json`, under the same `.scout-history/` folder.

## Cost anomaly detection

`Get-ScoutCostAnomaly` (AB#324) is an offline analysis function — it never
calls Azure. Point it at an already-collected cost dataset (the raw
`Get-AZSCCostInventory` shape, or a pre-normalized array of cost records) and
it flags outliers using three independent techniques: a sudden month-over-month
spike, a z-score check, and an IQR (Tukey) check, grouped by `-GroupBy`
(default `Scope`, `ResourceType`). It also always returns the top movers by
absolute dollar swing, independent of whether anything crossed a threshold.

```powershell
Get-ScoutCostAnomaly -CostData $costData -ZScoreThreshold 2.5 -SpikeThresholdPct 75
```

::: tip Needs more than the default 2-month lookback for z-score/IQR
The z-score and IQR techniques need at least `-MinDataPoints` (default 4)
periods per group; the default `Get-AZSCCostInventory` lookback is only 2
months, so only spike detection reliably fires unless you collect cost data
with a longer `-Days` window first.
:::

## IaC gap detection

`Get-ScoutIacGap` (AB#325) is an offline analysis function — it never calls
Azure. It compares resources discovered in `collect.json` against a folder of
`.bicep`/ARM-JSON templates (best-effort text/JSON parsing — no `bicep build`
or other external dependency) and reports resources that exist in Azure but
aren't represented in any template (`Unmanaged`).

```powershell
Get-ScoutIacGap -CollectData $collect -TemplatePath ./infra -IncludeTemplatedButMissing
```

Matching is exact on a normalized (Type, Name) pair — it does not currently
account for a resource being deployed to a different resource group/
subscription than its template declares.

## IoT deep coverage

The Collect layer's IoT queries (`Invoke-Collect`, AB#330) now go beyond IoT
Hub device registries to include **Device Provisioning Service** (DPS) and
**Azure Digital Twins** instances, scored by the `caf.iot` rule file — so
`-Assessment 'Assess: IoT'` (and `LandingZone`) picks up DPS/Digital Twins findings
without any extra configuration.

## Assessment config load/save

`Import-ScoutConfig` / `Export-ScoutConfig` (AB#373–375) let you save and
reload the effective assessment config — an alternative benchmark,
rule-selection glob patterns, and per-rule threshold overrides — as a single
JSON file, mirroring exactly what the engine already consumes (no new schema
invented):

```powershell
# Load a config (falls back to the built-in ALZ reference benchmark if the
# file is absent, missing, or unparsable -- never throws)
$config = Import-ScoutConfig -ConfigPath ./my-config.json

# Round-trip: save the effective config back out
Export-ScoutConfig -Config $config -Path ./my-config.json -Force
```

Every key (`benchmark`, `rulePatterns`, `ruleOverrides`) is optional and
independently overridable. A missing/invalid `-ConfigPath` degrades to
"run with defaults" with a `Write-Warning` rather than aborting the
assessment.

## Report tiers

| Tier | Output | Notes |
|------|--------|-------|
| Power BI | `powerbi/*.csv` + `.pbit` | Primary analytics tier (star schema); the `.pbit` template is bound to the CSVs so it opens pre-wired in Power BI Desktop. |
| HTML | `report.html` | Self-contained, single file |
| PowerPoint | `assessment_deck.pptx` | Executive deck via the OpenXML SDK — **no Python dependency**. First use needs the `dotnet` SDK; see [Assessment Prerequisites](./assessment-prerequisites.md#powerpoint-tier-net-sdk-not-python). |
| Excel | `assessment_evidence.xlsx` | Evidence tier, plus pivot-chart visual dashboard tabs (Findings-by-Severity, Score-by-Area, Pass-Fail-Manual, Resource-Counts) generated with `ImportExcel` — each tab is omitted when its underlying data is empty. |
| JSON | `findings.json` | The machine-readable contract — full assessment metadata, scores, and findings. |
| JSON evidence | `evidence.json` (`Export-JsonEvidence`) | Resources-only export of the raw `collect.json` data (**AB#396**) — no assessment metadata, scores, or findings. For callers that just want the discovered resources as JSON. |
| React | `report-react.html` | Self-contained (CSS/JS inline, findings embedded as a JSON blob, no external/CDN requests). A vis.js VNet topology diagram with click-to-details and reset/fit controls, an MG-hierarchy diagram, 14 KPI cards, an Azure Firewall drill-down, a Governance section (budgets/locks/tag chips), a policy-enforcement badge, per-section search/filter, clickable rows with a side panel, scope tooltips, client-side filter by Framework/Area/Severity/Status, a sortable/searchable findings table, and a Drift tab showing cross-run drift (see [Cross-run drift](#cross-run-drift)). |
| Word | `assessment_report.docx` (`Export-Word`) | Self-contained `.docx` via the OpenXML SDK — **no Python dependency**, same NuGet-on-first-use pattern as the PowerPoint tier (**AB#333**). Falls back to a plain HTML file (clearly labeled, not a renamed `.docx`) if generation fails. |
| ECharts dashboard | `assessment_dashboard.html` (`Export-EChartsDashboard`) | Self-contained offline HTML dashboard — Apache ECharts is inlined into the file, no CDN/external requests (**AB#344**). |
| PDF | `assessment_report.pdf` (`Export-Pdf`) | Hand-rolled, dependency-free PDF renderer — cover page, executive summary, per-area findings table with a repeating header, prioritized gaps, and the manual-review worklist (**AB#379/394/395**). Falls back to an HTML file with print-to-PDF instructions if generation fails. |

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
  type](./assessment-permissions.md) for exactly which permissions and when.
- `PrivilegedAccess.Read.AzureResources` needs an **Entra ID P2 license** and,
  even on the opt-in `AzGovViz` path, is currently never exercised —
  `Import-AzGovViz.ps1` unconditionally passes `-NoPIMEligibility`. The native
  `Import-Governance` collector doesn't collect PIM-eligible role assignments
  either (`pimEligibility` is intentionally always empty for the same
  license/permission reason).

Full matrix, the exact permissions list, and what `-PermissionAudit` does and
does not verify: **[Auth & permissions per scan type](./assessment-permissions.md)**.

```powershell
# Pre-flight before any collection runs
Invoke-AzureScout -Assessment LandingZone -PermissionAudit
```

## Design reference

The full architecture, rule catalogue, and decision records live in the
[Master Design & Plan](https://github.com/thisismydemo/azure-scout/blob/main/pmo/plans/master-plan.md) and the
[assessment registry](../design/assessment-registry.md).
