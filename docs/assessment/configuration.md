---
description: Saving and loading an assessment configuration, and the report tiers each run can emit.
---

# Configuration and report tiers

How to pin an assessment's configuration so a run is reproducible, and what each output
tier produces.

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

