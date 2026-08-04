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

> **The React report is the deliverable. Every other rendered format is _coming soon_.**
>
> Azure Scout now produces **one** report: a self-contained single-page HTML/React document that
> hosts the inventory and every assessment behind one adaptive shell, and exports to PDF, Word,
> Markdown and CSV from the page itself. The standalone document renderers are being rebuilt to
> generate **from** that report rather than alongside it, and are on hold in the meantime
> (**AB#6922**).
>
> Asking for a held format by name still binds — the run warns, skips it, and renders the React
> report so you always get a deliverable. `-OutputFormat All` renders the React report plus the
> machine-readable data exports.

### Available now

| Tier | Output | Notes |
|------|--------|-------|
| **React** | `report-react.html` | **The deliverable.** Self-contained (CSS/JS inline, findings embedded as a JSON blob, no external/CDN requests). Adaptive navigation built from what actually ran — inventory only, inventory + Entra, or inventory + assessments with per-assessment detail. Each assessment answers what was run, what was found, and what to fix against CAF/WAF, with every score shown alongside its own arithmetic and what was excluded from the denominator. VNet topology and MG-hierarchy diagrams, KPI cards, governance section, per-section search/filter, sortable findings with evidence drill-down, and a Drift tab (see [Cross-run drift](#cross-run-drift)). |
| JSON | `findings.json` | The machine-readable contract — full assessment metadata, scores, and findings. Data, not a document; never held. |
| JSON evidence | `evidence.json` (`Export-JsonEvidence`) | Resources-only export of the raw `collect.json` data (**AB#396**) — no assessment metadata, scores, or findings. For callers that just want the discovered resources as JSON. |

### Coming soon

These renderers exist and are still tested, but are **not emitted** while the reporting engine is
rebuilt. They will return generated from the React report's model, so a document and the page it
came from can no longer disagree.

| Tier | Output | Status |
|------|--------|--------|
| PDF | `assessment_report.pdf` | **Coming soon.** Export to PDF from the React report today. |
| Word | `assessment_report.docx` | **Coming soon.** Export to Word from the React report today; a native `.docx` is tracked as **AB#6923**. |
| Excel | `assessment_evidence.xlsx` | **Coming soon.** Export findings to CSV from the React report today. |
| PowerPoint | `assessment_deck.pptx` | **Coming soon.** |
| Power BI | `powerbi/*.csv` + `.pbit` | **Coming soon.** |
| HTML | `report.html` | **Coming soon** — superseded by the React report. |
| ECharts dashboard | `assessment_dashboard.html` | **Coming soon.** |
| Governance report | `governance_report.html` | **Coming soon.** |

