# CAF design-area weighting scheme (AB#6797)

## The problem

Every `caf.*.yaml` rule file previously carried `weight: 1.0`. `Get-Score` computes the CAF
framework score as a weighted average of each area's score, weighted by `weight`
(`src/assess/engine/Get-Score.ps1`, AB#5087). A flat weight of 1.0 across all eight CAF landing
zone design areas means Scout's `LandingZone` roll-up treats the Governance design area (10
verified recommendations) as carrying exactly as much weight in the overall CAF score as the
Network topology and connectivity design area (123 verified recommendations, ~155 counting
numbered task steps in pages mid-rewrite). Microsoft does not publish a numeric weighting for the
landing zone design areas — the [design area review process](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas)
is a sequential checklist, not a scored rubric — but the *volume* of guidance Microsoft ships per
area is itself a signal of how much of the overall "is this landing zone ready" question that area
represents. An assessment that scores Governance and Network as equally weighty when Microsoft's
own guidance is 12x larger for one of them produces a CAF score that does not track how much
landing-zone risk each area actually carries.

## The scheme

Weight each design area proportionally to its **verified recommendation count**, normalized so the
mean weight across the eight areas is ~1.0 (so a roll-up computed before this change and one
computed after differ only in *how much each area's score moves the needle*, not in scale).

```
weight(area) = recommendation_count(area) / mean(recommendation_count across all 8 areas)
```

Recommendation counts are the **verified** figures from
[`pmo/audits/AZURE-SCOUT-AUDIT.md` §8 Table 2](https://github.com/thisismydemo/azure-scout/blob/main/pmo/audits/AZURE-SCOUT-AUDIT.md), which were
produced by fetching all 43 Microsoft Learn pages across the eight design areas on 2026-07-30 and
counting top-level bullets under each page's `## Design recommendations` heading (or the
area-specific equivalent, e.g. "Management group recommendations"). That table also documents
where the prior audit's figures were wrong (Security was double-counted against network-security
pages it only links to; Management and Governance conflated "considerations" bullets with
"recommendations" bullets) — this scheme uses the corrected numbers, not the prior ones.

| Design area | Rule file | Verified recommendations | Mean (365/8 = 45.625) | Weight |
|---|---|---:|---:|---:|
| Azure billing and Microsoft Entra tenant | `caf.billing.yaml` | 42 | 45.625 | **0.92** |
| Identity and access management | `caf.identity.yaml` | 65 | 45.625 | **1.42** |
| Resource organization | `caf.resourceorg.yaml` | 35 | 45.625 | **0.77** |
| Network topology and connectivity | `caf.network.yaml` | 123 (formal) | 45.625 | **2.70** |
| Security | `caf.security.yaml` | 45 | 45.625 | **0.99** |
| Management | `caf.management.yaml` | 15 | 45.625 | **0.33** |
| Governance | `caf.governance.yaml` | 10 | 45.625 | **0.22** |
| Platform automation and DevOps | `caf.platformauto.yaml` | 30 | 45.625 | **0.66** |

`weight` lives in each rule file's YAML header next to a one-line citation back to this document,
so a future rule-count change (new rules added, or Microsoft republishing the design-area pages)
has a clear place to recompute from.

## What this deliberately does NOT do

- **It does not claim to be Microsoft's weighting.** Microsoft ships no landing-zone-review scoring
  weight; this is Scout's own derived scheme, built from a number Microsoft *does* publish
  (recommendation count per area) rather than invented from nothing. The audit and the citation
  comment in each rule file make this distinction explicit so a reader does not mistake Scout's
  weighting for an official Microsoft score.
- **It does not change per-area scoring.** Each design-area assessment (see the registry entries
  added under `manifests/assessments.psd1` for AB#6797) scores only its own rules at 100% weight
  internally — the weighting only changes how the eight area scores combine into the single CAF
  framework number inside the `LandingZone` roll-up and inside `Get-Score`'s `Frameworks` output.
- **It is not a coverage weight.** Scout's own rule-count-per-area (6-7 rules per file today) is
  intentionally NOT used as the weighting basis — that would reward files that happen to be
  under-built with a lower influence on the score, which is the opposite of what an honest
  "how much does this area matter" weighting should do. The weighting tracks Microsoft's
  guidance volume, not Scout's current implementation depth.

## Reconciliation

Because `Get-Score`'s framework score is *computed from* the area scores it weights (not scored
independently), the `LandingZone` roll-up's CAF framework score is guaranteed, by construction, to
equal the weighted average of the eight `CAF: <design area>` assessments' own framework scores
when run against the same collect.json. `tests/Assessment.Restructure.Tests.ps1` pins this with a
non-vacuous test (break the weight, watch the reconciliation assertion fail, restore).
