---
description: The catalogue of every Azure Scout assessment — description, category, sub-bundles, CAF areas, WAF pillars, default report tiers, and tags.
---

# Assessment Registry

Every assessment Azure Scout can run — **22 in total**, categorized and
tagged. Run one with `Invoke-ScoutAssessment -Assessment <Name>`.

::: info What `Category`/`Collect` scope in practice
Each assessment declares a `Collect` list in the manifest, and the value is
recorded into `collect.json`'s `_meta.categories` for provenance — but the
Collect layer (`Invoke-Collect.ps1`) currently runs its full, fixed set of
Resource Graph queries on every run regardless of that value. What actually
differs between assessments is: which **ingestors** run (`Ingest` —
`Governance` (native, default for the 5 governance-data assessments),
`ArgQueryPack`, `AdvisorScores`, or the opt-in third-party `AzGovViz`), and
which **rule files** are scored (`Rules`) against the collected data. See
[Assessment guide — Collect runs the full query set every time](../assessment.md#architecture-three-layers-json-on-disk)
for the full explanation.
:::

Source of truth: [`manifests/assessments.psd1`](https://github.com/thisismydemo/azure-scout/blob/main/manifests/assessments.psd1).
Tracks Epic **AB#5056** (foundation **AB#5057**).

Minimum auth per assessment (ARM Reader vs. the AzGovViz-only Graph
permissions): [Auth & permissions per scan type](../assessment-permissions.md).

## Cross-category roll-ups

| Assessment | Description | Category | Rules | Frameworks | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `LandingZone` | CAF/WAF landing zone audit (all areas) | `*` | `caf.*`, `waf.*` | CAF: all 8 areas · WAF: all 5 pillars | PowerBi, Html, Pptx | caf, waf, landing-zone |
| `Estate` | Full digital estate inventory (no scoring) | `*` | — (inventory) | — | Excel, PowerBi | inventory |
| `Cost` | Cost / TCO data pull | `*` | `waf.cost` | WAF: Cost optimization | Excel, PowerBi | waf, cost |

## Per-category assessments

| Assessment | Description | Category | Rule files | CAF areas / WAF pillars | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `Management` | Governance, policy, cost, backup, automation, update manager | Management | `caf.governance`, `caf.management`, `caf.billing` | CAF Governance/Management/Billing · WAF Operational/Cost | Html, Excel | caf, governance, management |
| `Monitor` | Monitoring, alerting, diagnostics coverage | Monitor | `caf.management`, `waf.operational` | CAF Management & monitoring · WAF Operational excellence | Html, Excel | waf, monitor |
| `Networking` | Network topology, firewall, DDoS, exposure, private link | Networking | `caf.network` | CAF Network topology & connectivity · WAF Security | Html, Excel | caf, networking |
| `Identity` | Identity & access — PIM, Conditional Access, RBAC | Identity | `caf.identity` | CAF Identity & access · WAF Security | Html, Excel | caf, identity |
| `Security` | Defender, Key Vault, secure score, exposure | Security | `caf.security`, `waf.security` | CAF Security · WAF Security | Html, Excel | caf, waf, security |
| `Compute` | VM resilience, zones, backup, right-size, orphans | Compute | `waf.reliability`, `waf.cost`, `waf.performance` | WAF Reliability/Cost/Performance | Html, Excel | waf, compute |
| `Storage` | Storage public access, TLS, encryption, redundancy | Storage | `caf.storage`, `waf.storage` | CAF Security · WAF Reliability | Html, Excel | caf, waf, storage |
| `Databases` | SQL/DB private access, TDE, zone redundancy | Databases | `caf.databases` | CAF Security · WAF Reliability | Html, Excel | caf, databases |
| `Containers` | AKS private clusters, RBAC, registry hardening | Containers | `caf.containers` | CAF Security · WAF Reliability | Html, Excel | caf, containers |
| `Web` | App Service HTTPS-only, TLS, managed identity | Web | `caf.web` | CAF Security · WAF Security | Html, Excel | caf, web |
| `Analytics` | Analytics data governance and network isolation | Analytics | `caf.analytics` | CAF Governance · WAF Security | Html, Excel | caf, analytics |
| `AI` | AI/Cognitive private access and responsible-AI posture | AI | `caf.ai` | CAF Governance · WAF Security | Html, Excel | caf, ai |
| `Integration` | Messaging redundancy and APIM network isolation | Integration | `caf.integration` | CAF Network & connectivity · WAF Reliability | Html, Excel | caf, integration |
| `Hybrid` | Arc onboarding, agent currency, Azure Local | Hybrid | `caf.hybrid` | CAF Management & monitoring · WAF Operational | Html, Excel | caf, hybrid |
| `IoT` | IoT Hub/DPS network isolation and device auth | IoT | `caf.iot` | CAF Security · WAF Security | Html, Excel | caf, iot |

## Sub-bundles (finer scope inside a category)

| Assessment | Description | Parent category | Rules | Default report tiers |
|---|---|---|---|---|
| `Governance` | Management sub-bundle — policy assignments, locks, budgets | Management | `caf.governance` | Html |
| `Policy` | Management sub-bundle — Azure Policy assignment/enforcement | Management | `caf.governance` | Html |
| `UpdateManager` | Management sub-bundle — patch/update compliance | Management | `caf.management` | Html |
| `Monitoring` | Monitor sub-bundle — diagnostic settings coverage | Monitor | `waf.operational` | Html |

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
