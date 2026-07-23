---
description: Run a read-only CAF/WAF landing-zone assessment with AzureScout — engine, layers, scoring, and report tiers.
---

# CAF/WAF Assessment Platform

Introduced in **v2.0.0**, AzureScout can score a tenant against the Microsoft
**Cloud Adoption Framework (CAF)** design areas and **Well-Architected Framework
(WAF)** pillars — not just inventory it. The assessment is **read-only** end to
end (Reader at the management-group root + read-only Graph).

::: tip PowerShell 7 required
The assessment platform requires **PowerShell 7**. The v1 inventory features
(`Invoke-AzureScout`) still run on Windows PowerShell 5.1.
:::

## Architecture — three layers, JSON on disk

```
COLLECT  --collect.json-->  ASSESS  --findings.json-->  REPORT
```

Each layer runs independently from its JSON input, so you can collect once and
assess later, or re-render reports from an existing findings set without
re-scanning.

| Layer | What it does |
|-------|--------------|
| **Collect** | Read-only Azure Resource Graph queries produce a normalized `collect.json`, including a per-domain `domains.*` namespace. |
| **Ingest** | Folds Azure Governance Visualizer, an ARG query pack, and Azure Advisor into the same `collect.json`. |
| **Assess** | A declarative rule engine grades the collected data — **139 rules across 8 CAF design areas + 5 WAF pillars** — producing scored `findings.json` with a prioritized gap list. |
| **Report** | Renders `findings.json` into tiered deliverables. |

## Quick start

```powershell
Import-Module ./AzureScout.psd1

# Full landing-zone assessment, every report tier
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat All

# Assess a single domain
Invoke-ScoutAssessment -Assessment Security -OutputFormat Html

# Collect once, assess later from the saved collect.json
Invoke-ScoutAssessment -Assessment LandingZone -CollectOnly
Invoke-ScoutAssessment -Assessment LandingZone -FromCollect ./output/<run>/collect.json -OutputFormat PowerBi
```

Every discovery category is an independently runnable, tagged assessment — pass
one, several, or `All` to `-Assessment`.

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
| PowerPoint | `assessment_deck.pptx` | Executive deck via the OpenXML SDK — **no Python dependency** |
| Excel | `assessment_evidence.xlsx` | Evidence tier |
| JSON | `findings.json` | The machine-readable contract |

## Permission pre-flight

```powershell
Invoke-ScoutAssessment -Assessment LandingZone -PermissionAudit
```

Reports whether the current identity has the read-only access each selected
assessment needs, before any collection runs.

## Design reference

The full architecture, rule catalogue, and decision records live in the
[Master Design & Plan](design/master-plan.md) and the
[assessment registry](design/assessment-registry.md).
