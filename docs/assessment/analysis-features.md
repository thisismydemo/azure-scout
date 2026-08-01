---
description: Cross-run drift, cost anomaly detection, IaC gap detection, and IoT deep coverage.
---

# Analysis features

Beyond scoring a single run, AzureScout compares runs over time and applies a few
targeted analyses to the collected data. All of these run from data already collected —
none of them makes an extra Azure call.

These were previously buried in the middle of the assessment platform page, between the
scoring model and the report tiers, where nobody looking for them would find them.

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

