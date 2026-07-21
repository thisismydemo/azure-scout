---
description: The catalogue of every Azure Scout assessment — category, sub-bundles, CAF areas, WAF pillars, and tags.
---

# Assessment Registry

Every assessment Azure Scout can run, categorized and tagged. Run one with
`Invoke-ScoutAssessment -Assessment <Name>`; discovery is scoped to the
assessment's `Category` and only that assessment's CAF/WAF rules are scored.

Source of truth: [`manifests/assessments.psd1`](https://github.com/thisismydemo/azure-scout/blob/main/manifests/assessments.psd1).
Tracks Epic **AB#5056** (foundation **AB#5057**).

## Cross-category roll-ups

| Assessment | Category | Rules | Frameworks | Tags |
|---|---|---|---|---|
| `LandingZone` | `*` | `caf.*`, `waf.*` | CAF: all 8 areas · WAF: all 5 pillars | caf, waf, landing-zone |
| `Estate` | `*` | — (inventory) | — | inventory |
| `Cost` | `*` | `waf.cost` | WAF: Cost optimization | waf, cost |

## Per-category assessments

| Assessment | Category | Rule files | CAF areas / WAF pillars | Tags |
|---|---|---|---|---|
| `Management` | Management | `caf.governance`, `caf.management`, `caf.billing` | CAF Governance/Management/Billing · WAF Operational/Cost | caf, governance, management |
| `Monitor` | Monitor | `caf.management`, `waf.operational` | CAF Management & monitoring · WAF Operational excellence | waf, monitor |
| `Networking` | Networking | `caf.network` | CAF Network topology & connectivity · WAF Security | caf, networking |
| `Identity` | Identity | `caf.identity` | CAF Identity & access · WAF Security | caf, identity |
| `Security` | Security | `caf.security`, `waf.security` | CAF Security · WAF Security | caf, waf, security |
| `Compute` | Compute | `waf.reliability`, `waf.cost`, `waf.performance` | WAF Reliability/Cost/Performance | waf, compute |
| `Storage` | Storage | `caf.storage`, `waf.storage` | CAF Security · WAF Reliability | caf, waf, storage |
| `Databases` | Databases | `caf.databases` | CAF Security · WAF Reliability | caf, databases |
| `Containers` | Containers | `caf.containers` | CAF Security · WAF Reliability | caf, containers |
| `Web` | Web | `caf.web` | CAF Security · WAF Security | caf, web |
| `Analytics` | Analytics | `caf.analytics` | CAF Governance · WAF Security | caf, analytics |
| `AI` | AI | `caf.ai` | CAF Governance · WAF Security | caf, ai |
| `Integration` | Integration | `caf.integration` | CAF Network & connectivity · WAF Reliability | caf, integration |
| `Hybrid` | Hybrid | `caf.hybrid` | CAF Management & monitoring · WAF Operational | caf, hybrid |
| `IoT` | IoT | `caf.iot` | CAF Security · WAF Security | caf, iot |

## Sub-bundles (finer scope inside a category)

| Assessment | Parent category | Rules | Purpose |
|---|---|---|---|
| `Governance` | Management | `caf.governance` | Policy assignments, locks, budgets |
| `Policy` | Management | `caf.governance` | Azure Policy assignment & enforcement mode |
| `UpdateManager` | Management | `caf.management` | Patch / update compliance |
| `Monitoring` | Monitor | `waf.operational` | Diagnostic settings coverage |

## Examples

```powershell
Invoke-ScoutAssessment -Assessment Management      # governance + policy + update manager, scored
Invoke-ScoutAssessment -Assessment Monitor         # monitoring/diagnostics only
Invoke-ScoutAssessment -Assessment Networking,Security -OutputFormat Html
Invoke-ScoutAssessment -Assessment LandingZone -OutputFormat PowerBi,Html,Pptx
```

## Adding an assessment

1. Add a rule file `caf.<domain>.yaml` / `waf.<domain>.yaml` under `src/assess/rules/`.
2. Add an entry to `manifests/assessments.psd1` with `Category`, `Collect`, `Rules`, `Frameworks`, `Tags`, `Reporters`.
3. Add a row to this table. No core code change is required.
