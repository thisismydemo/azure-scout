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
governance collector for the 26 assessments that need governance data
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
Invoke-AzureScout -Assessment 'Assess: Security' -OutputFormat React
```

### Multiple assessments in one run

```powershell
Invoke-AzureScout -Assessment 'Assess: Networking','Assess: Security' -OutputFormat React
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
Invoke-AzureScout -Assessment LandingZone -ManagementGroup 'contoso-root-mg' -OutputFormat React
```

::: warning Scopes Collect too now — and the benchmark still needs MG-root visibility
`-ManagementGroupId` is passed to `Invoke-Collect`,
which pass it through as `Search-AzGraph -ManagementGroup` on every Resource
Graph query (and, if you've opted into the legacy `AzGovViz` ingestor, to
`Import-AzGovViz` too). Omit it and Collect keeps tenant-wide behavior (no
`-ManagementGroup` filter is passed to `Search-AzGraph` at all — not an
empty/wildcard scope, the parameter is left off entirely).

For the **26 assessments that ingest governance data** — every one marked **Gov** in the
[Assessment Catalogue](../reference/assessment-catalogue.md), including `LandingZone`,
every `CAF:` design area and every `WAF:` pillar — the **native**
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

::: warning What the 46 registry entries actually are
`manifests/assessments.psd1` has **46 keys**. They are not 46 unrelated products, and they
are no longer mostly views over one roll-up — the AB#6746 restructure turned the per-pillar
and per-design-area assessments into real scored entries. They group as:

- **11 Cloud Adoption Framework** — one per design area (`CAF: Governance`, `CAF: Security`,
  `CAF: Network topology and connectivity`, …) plus the `LandingZone` roll-up, which pulls in
  every CAF and WAF rule file at once.
- **9 Well-Architected Framework** — one per pillar (`WAF: Reliability`, `WAF: Security`, …),
  plus `WAF: Azure Local` and `WAF: Maturity Model`.
- **19 `Assess: ` service-category slices** — a category filter over the shared rule set, one
  per Scout inventory category. `Compute` filters what gets *collected*; `Assess: Compute`
  filters what gets *scored*, which is why they carry the prefix. The old unprefixed name
  still resolves, with a warning telling you what to change.
- **7 specialised and workload** — `AVS Workload`, `AVS Landing Zone`, `CASA`,
  `DevOps Capability Assessment`, `FinOps Review`, `SMART` and `Assess: Compliance`.

A few legacy sub-bundles still sit inside those groups — `Governance`, `Monitoring` and
`UpdateManager`, each a narrower cut of a broader entry. Two earlier entries are gone:
`Policy` (byte-identical to `Governance`) and `Estate` (declared no rules, so it scored
nothing) were both removed under AB#6795 rather than left to return a misleading
"no findings".

**The full list, with the rule files and the automated-versus-manual split behind each, is on
one generated page: [Assessment Catalogue](../reference/assessment-catalogue.md).** Prefer it
to any count written in prose here — it is generated from the registry and cannot drift.

**The interactive wizard hides any entry whose rule-file glob matches no file on disk.** An
entry that runs and silently returns zero findings reads as "nothing wrong" rather than
"nothing was checked", so it is left off the menu rather than shown. You can still run one
directly with `-Assessment <Name>` — the filter is a menu courtesy, not an authorization
check. `SMART` is gated separately, on whether the estate actually has migration data to score.
:::

## Scoring

- Each rule evaluates to **Pass**, **Fail**, **Partial**, **Manual**, **Unknown**, or **Error**.
- Framework scores are the rule-count-weighted roll-up of area/pillar scores.
- `Unknown`/`Error` are surfaced, never silently dropped — a broken rule cannot inflate a score.
- The **`Manual`** status intentionally hands the un-automatable checks to a human, with the collected evidence already attached.


## Permissions

Every assessment needs **ARM `Reader` at the tenant-root management group**. There are no
exceptions, and a narrower scope degrades results to an explicit `Unknown` rather than a
false zero.

The full story — the per-assessment matrix, when Microsoft Graph permissions are actually
required, and precisely what `-PermissionAudit` does and does not verify — lives on one
page: **[Auth & permissions per scan type](./assessment-permissions.md)**.

```powershell
# Pre-flight before any collection runs
Invoke-AzureScout -Assessment LandingZone -PermissionAudit
```

::: tip Why this section is short
This page used to restate the permissions model in full, giving three separate
descriptions of it across the documentation — this page, the assessment permissions page,
and the inventory [Permissions](../guide/permissions.md) page. They drifted, as three
copies of anything do. The detail now lives in one place and the other two link to it.
:::

## More on assessment

| Page | Contents |
|---|---|
| [Analysis features](./analysis-features.md) | Cross-run drift, cost anomaly detection, IaC gap detection, IoT deep coverage |
| [Configuration and report tiers](./configuration.md) | Saving and loading a config, and what each output tier produces |
| [Assessment Catalogue](../reference/assessment-catalogue.md) | All 46 assessments, their rule files, and the automated-versus-manual split |

## Design reference

The full architecture, rule catalogue, and decision records live in the
[Master Design & Plan](https://github.com/thisismydemo/azure-scout/blob/main/pmo/plans/master-plan.md) and the
[assessment registry](../design/assessment-registry.md).
