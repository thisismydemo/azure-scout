---
description: The CAF/WAF assessment platform — how scoring works, what it needs, and what it can assess.
---

# Assessment

Add `-Assessment` and AzureScout stops being an inventory tool and becomes a scored review:
it collects, applies declarative rule files, and produces a `findings.json` with per-area
scores, a prioritised gap list, and evidence for every finding.

## Pages

| Page | What it answers |
|---|---|
| [Assessment platform](./assessment.md) | Architecture, the collect → ingest → assess → report flow, run modes, the registry, and scoring |
| [Analysis features](./analysis-features.md) | Cross-run drift, cost anomaly detection, IaC gap detection, IoT deep coverage |
| [Configuration and report tiers](./configuration.md) | Saving and loading a config, and what each output tier produces |
| [Prerequisites](./assessment-prerequisites.md) | What assessment mode needs beyond a normal inventory run |
| [Auth and permissions per scan type](./assessment-permissions.md) | The minimum RBAC and Graph permissions each assessment needs |

## What can be assessed

The full list lives on one generated page — **[Assessment Catalogue](../reference/assessment-catalogue.md)**
— covering all 46 assessments grouped into CAF design areas, WAF pillars, per-service slices,
and specialised reviews, with the rule files and rule counts behind each.

## Read this before quoting a score

A rule is either **automated** — decided by collected data — or **manual**, meaning no data
Azure exposes can settle it and a human must confirm it. **225 of Scout's 395 rules (57%) are
manual.** They are excluded from every score rather than counted as failures, and reported
separately.

That ratio varies enormously by assessment, and it changes what the output *is*. Some
assessments return a grade; others return a worklist. The catalogue publishes the split per
assessment, so check it before assuming a low score means a problem — or that a high one means
everything was checked.

Two related guarantees the reports hold to:

- A control that could not be evaluated reads as **"Not assessed"**, never as a zero and never
  as a pass. "We did not look" and "we looked and found nothing" are different statements.
- A finding names the resources behind it, so it can be actioned rather than admired.
