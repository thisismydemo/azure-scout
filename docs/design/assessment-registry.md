---
description: The catalogue of every Azure Scout assessment — description, category, sub-bundles, CAF areas, WAF pillars, default report tiers, and tags.
---

# Assessment Registry

`manifests/assessments.psd1` has **46 entries**, categorized and tagged. Run
one with `Invoke-AzureScout -Assessment <Name>`.

The full list, with the rule files and the automated-versus-manual split behind each, is on the
generated **[Assessment Catalogue](../reference/assessment-catalogue.md)** — prefer it to any
count written in prose. This page explains how the entries are *structured*.

::: warning What those entries actually break down into
Since the AB#6746 restructure the per-pillar and per-design-area entries are **real scored
assessments in their own right**, not views over a single roll-up. `LandingZone` remains the
roll-up that pulls in every CAF and WAF rule file at once. What is left to explain is the rest:

- **19 per-category slices**, prefixed `Assess: ` (`Assess: Compute`,
  `Assess: Security`, …). They collided with Scout's **inventory**
  category names — `Compute` filters what gets *collected*, `Assess: Compute`
  filters what gets *scored* — so they're now prefixed to stop the two
  different things sitting side by side under one label (quote the value —
  it has a colon and a space: `-Assessment 'Assess: Compute'`). The old
  unprefixed name still resolves — `Resolve-ScoutAssessmentName` maps it to
  the prefixed one and warns — so an existing script keeps working. This is a
  named stopgap: a future release retires these fifteen once per-WAF-pillar
  and per-CAF-design-area assessments exist to replace them (see the
  14-target programme on the
  [Roadmap](../project/roadmap.md#caf-waf-assessment-programme)).
- **3 sub-bundles**, narrower still than a category (`Governance`,
  `UpdateManager`, `Monitoring`). `UpdateManager` and `Monitoring` are each a
  strict subset of a broader entry above (`Assess: Management` and
  `Assess: Monitor` respectively) and now say so in their description
  (AB#6795). `Policy`, which used to sit here byte-identical to `Governance`
  (same `Category`/`Collect`/`Ingest`/`Rules`), was deleted rather than
  fixed — script `-Assessment Governance` instead.
- **`Estate` was removed entirely (AB#6795)** — it declared no `Rules`, so it
  scored nothing; it was a full inventory pull that happened to live in this
  registry, which meant it ran and returned "no findings" for anyone who
  named it directly (the wizard already hid it — AB#6763 — on the same
  evidence, but the registry itself still carried a dead entry). Run
  inventory with `Invoke-AzureScout` (no `-Assessment`); it is a different
  product, not a smaller assessment.
- **`Assess: Compliance`** (AB#6792/#6793/#6794) is a compliance-engine
  entry, not a YAML rule set — it scores every Azure Policy
  regulatory-compliance initiative (MCSB, CIS, ISO 27001, NIST, PCI-DSS, …)
  actually **assigned** in the scanned scope, one Framework score card per
  initiative + exact version, from compliance state Azure has already
  evaluated. The source of truth is
  `src/assess/engine/Get-ScoutComplianceScore.ps1` and
  `src/assess/engine/Resolve-ScoutAssignedInitiative.ps1`.

That leaves **4 genuinely distinct rule-scored assessments**: `LandingZone`
(the roll-up), `Cost` (targeted cost/TCO pull), `CrossResource` (findings
that need two collected datasets correlated), and `SMART` (migration
readiness, scored against its own enumerated source — see
[SMART's framework page](../frameworks/smart-question-set.md)) — plus the one
compliance-engine assessment above.
:::

::: info What `Category`/`Collect` scope in practice
Each assessment declares a `Collect` list in the manifest, and the Collect
layer (`Invoke-Collect.ps1`) **does** use it to filter which Resource Graph
queries run — every query is tagged with the category name(s) whose rule
files reference its output, including cross-domain references, and
`subscriptions` always runs as base data. Passing `Collect = @('*')` (as
`LandingZone` does) runs every query. What else differs
between assessments: which **ingestors** run (`Ingest` — `Governance`,
native and the default for the 5 governance-data assessments; `AdvisorScores`;
or the opt-in third-party `AzGovViz`), and which **rule files** are scored
(`Rules`) against the collected data. `ArgQueryPack` is retired — a manifest
entry that still names it in `Ingest` is now silently ignored, not run. See
[Assessment guide — Collect is now actually scoped by
category](../assessment/assessment.md#architecture-three-layers-json-on-disk) for the
full explanation.
:::

Source of truth: [`manifests/assessments.psd1`](https://github.com/thisismydemo/azure-scout/blob/main/manifests/assessments.psd1).
Tracks Epic **AB#5056** (foundation **AB#5057**).

Minimum auth per assessment (ARM Reader vs. the AzGovViz-only Graph
permissions): [Auth & permissions per scan type](../assessment/assessment-permissions.md).

## Cross-category roll-ups

| Assessment | Description | Category | Rules | Frameworks | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `LandingZone` | CAF/WAF landing zone audit (all areas) | `*` | `caf.*`, `waf.*`, `xr.*` | CAF: all 8 areas · WAF: all 5 pillars · XR: Cross-resource posture | PowerBi, Html, Pptx, React | caf, waf, landing-zone, cross-resource |
| `Cost` | Cost / TCO data pull | `*` | `waf.cost` | WAF: Cost optimization | Excel, PowerBi | waf, cost |

## Compliance (engine-scored, not a YAML rule set)

| Assessment | Description | Category | "Rules" (menu-gate marker only) | Frameworks | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `Assess: Compliance` | Every Azure Policy regulatory-compliance initiative assigned in the scanned scope (MCSB, CIS, ISO 27001, NIST, PCI-DSS, …), scored from compliance state Azure already evaluated — one Framework card per initiative + exact version, three states (Pass/Fail/Not assessed) so an unassigned or unevaluated control is never counted as a pass or a fail | Management | `compliance.*` | CAF: Govern · CAF: Secure | Html, Excel | compliance, policy, regulatory |

## Per-category assessments

Legacy unprefixed names (`Management`, `Compute`, …) still resolve — see the
`Assess: ` note above.

| Assessment | Description | Category | Rule files | CAF areas / WAF pillars | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `Assess: Management` | Governance, policy, cost, backup, automation, update manager | Management | `caf.governance`, `caf.management`, `caf.billing` | CAF Governance/Management/Billing · WAF Operational/Cost | Html, Excel | caf, governance, management |
| `Assess: Monitor` | Monitoring, alerting, diagnostics coverage | Monitor | `caf.management`, `waf.operational` | CAF Management & monitoring · WAF Operational excellence | Html, Excel | waf, monitor |
| `Assess: Networking` | Network topology, firewall, DDoS, exposure, private link | Networking | `caf.network` | CAF Network topology & connectivity · WAF Security | Html, Excel | caf, networking |
| `Assess: Identity` | Identity & access — PIM, Conditional Access, RBAC | Identity | `caf.identity` | CAF Identity & access · WAF Security | Html, Excel | caf, identity |
| `Assess: Security` | Defender, Key Vault, secure score, exposure | Security | `caf.security`, `waf.security` | CAF Security · WAF Security | Html, Excel | caf, waf, security |
| `Assess: Compute` | VM resilience, zones, backup, right-size, orphans | Compute | `waf.reliability`, `waf.cost`, `waf.performance` | WAF Reliability/Cost/Performance | Html, Excel | waf, compute |
| `Assess: Storage` | Storage public access, TLS, encryption, redundancy | Storage | `caf.storage`, `waf.storage` | CAF Security · WAF Reliability | Html, Excel | caf, waf, storage |
| `Assess: Databases` | SQL/DB private access, TDE, zone redundancy | Databases | `caf.databases` | CAF Security · WAF Reliability | Html, Excel | caf, databases |
| `Assess: Containers` | AKS private clusters, RBAC, registry hardening | Containers | `caf.containers` | CAF Security · WAF Reliability | Html, Excel | caf, containers |
| `Assess: Web` | App Service HTTPS-only, TLS, managed identity | Web | `caf.web` | CAF Security · WAF Security | Html, Excel | caf, web |
| `Assess: Analytics` | Analytics data governance and network isolation | Analytics | `caf.analytics` | CAF Governance · WAF Security | Html, Excel | caf, analytics |
| `Assess: AI` | AI/Cognitive private access and responsible-AI posture | AI | `caf.ai` | CAF Governance · WAF Security | Html, Excel | caf, ai |
| `Assess: Integration` | Messaging redundancy and APIM network isolation | Integration | `caf.integration` | CAF Network & connectivity · WAF Reliability | Html, Excel | caf, integration |
| `Assess: Hybrid` | Arc onboarding, agent currency, Azure Local | Hybrid | `caf.hybrid` | CAF Management & monitoring · WAF Operational | Html, Excel | caf, hybrid |
| `Assess: IoT` | IoT Hub/DPS network isolation and device auth | IoT | `caf.iot` | CAF Security · WAF Security | Html, Excel | caf, iot |

## Sub-bundles (finer scope inside a category)

| Assessment | Description | Parent category | Rules | Default report tiers |
|---|---|---|---|---|
| `Governance` | Management sub-bundle — policy assignments, locks, budgets | Management | `caf.governance` | Html |
| `UpdateManager` | Management sub-bundle (subset of `Assess: Management`) — patch/update compliance only | Management | `caf.management` | Html |
| `Monitoring` | Monitor sub-bundle (subset of `Assess: Monitor`) — diagnostic settings coverage only | Monitor | `waf.operational` | Html |

## Migration readiness and cross-resource correlation

Two entries that don't fit the roll-up/category/sub-bundle shape above.

| Assessment | Description | Category | Rules | Frameworks | Default report tiers | Tags |
|---|---|---|---|---|---|---|
| `SMART` | Strategic Migration Assessment — migration readiness, scored against its own enumerated source (see [SMART's framework page](../frameworks/smart-question-set.md)) | Migration | `smart.*` | CAF: Migrate · SMART: readiness | Html, Excel | caf, migration, smart |
| `CrossResource` | Findings that require two collected datasets correlated (e.g. "which VMs have no backup") | `*` | `xr.*` | XR: Cross-resource posture | Html, Excel | cross-resource, waf, caf |

`SMART` additionally declares `RequiresData` — the wizard hides it unless the
current tenant's `collect.json` actually has Azure Migrate project,
discovery-site, or migration-service data, so a tenant that hasn't started a
migration doesn't get a manufactured "Unknown" result offered as a real
choice.

## Examples

```powershell
Invoke-AzureScout -Assessment 'Assess: Management'                    # governance + policy + update manager, scored
Invoke-AzureScout -Assessment 'Assess: Monitor'                       # monitoring/diagnostics only
Invoke-AzureScout -Assessment 'Assess: Networking','Assess: Security' -OutputFormat Html
Invoke-AzureScout -Assessment LandingZone -OutputFormat PowerBi,Html,Pptx
Invoke-AzureScout -Assessment LandingZone -InventoryAndAssessment      # collect once, get both reports
```

## Adding an assessment

1. Add a rule file `caf.<domain>.yaml` / `waf.<domain>.yaml` under `src/assess/rules/`.
2. Add an entry to `manifests/assessments.psd1` with `Category`, `Collect`, `Rules`, `Frameworks`, `Tags`, `Reporters`.
3. Add a row to this table. No core code change is required.
