# WAF — the five pillar design-review checklists, enumerated

> **Source:** <https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist> ·
> <https://learn.microsoft.com/en-us/azure/well-architected/security/checklist> ·
> <https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist> ·
> <https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist> ·
> <https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist>
> **Framework version:** Microsoft does not version the WAF checklists; this enumeration uses the
> extraction date, 2026-08-01, as the version.
> **Extracted:** 2026-08-01
> **Verification method:** Each of the five pillar checklist pages was fetched directly via
> `microsoft_docs_fetch` (Microsoft Learn MCP server) and every checklist row transcribed. Nothing
> in this file was taken on trust from a prior audit; the 59-item total is a direct re-count, not a
> carried-forward figure.

**Enumerated 2026-08-01.** This is the source-framework enumeration required by AB#6745 (Epic
AB#6454). It exists so rule files under `src/assess/rules/waf.*.yaml` cite a real, checkable item
number instead of a pillar name and a vibe. The audit's DQ12 explains why this matters: *"Writing
rules against a framework you have not enumerated is how `waf.storage.yaml` happened"* — a rule
file scoring a WAF pillar that does not exist (storage is a WAF *service guide*, not a pillar; see
`pmo/audits/AZURE-SCOUT-AUDIT.md` §8).

## What this is

The Azure Well-Architected Framework publishes exactly **five pillars** — Reliability, Security,
Cost Optimization, Operational Excellence, Performance Efficiency — confirmed on
[What is the Well-Architected Framework?](https://learn.microsoft.com/en-us/azure/well-architected/what-is-well-architected-framework).
Each pillar ships one **design review checklist** page. Every checklist item on that page has a
Microsoft-published, stable code (`RE:01`, `SE:04`, and so on) — unlike CAF's landing-zone
recommendations, which have no Microsoft item numbers at all (see
`docs/frameworks/caf-landing-zone-design-areas.md`). Scout's `WAF-<PILLAR>-<NN>` identifiers below
are a direct, 1:1 restatement of Microsoft's own codes, using the pillar abbreviation
(`RE`/`SE`/`CO`/`OE`/`PE`) already in use by `src/assess/rules/waf.*.yaml`
(e.g. `WAF-SE-01` in `waf.security.yaml`, `WAF-RE-05` in `waf.reliability.yaml`).

## Verification method

Each pillar's checklist page was fetched directly on 2026-08-01 via
`microsoft_docs_fetch` (Microsoft Learn MCP server), not taken on trust from the prior audit. The
audit's §8 Table 1 stated 59 items total across the five pillars; that figure is **confirmed exactly**
by this re-fetch — 10 + 12 + 14 + 11 + 12 = 59. Item text below is Microsoft's own checklist wording,
transcribed from the fetched page (the lead sentence of each checklist row; the fuller elaboration
sentence that follows each item on Microsoft's page is omitted here for table width, and readers
needing the full wording should follow the `Code` link to the live page).

| Pillar | Source URL | Items fetched |
|---|---|---|
| Reliability | <https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist> | 10 |
| Security | <https://learn.microsoft.com/en-us/azure/well-architected/security/checklist> | 12 |
| Cost Optimization | <https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist> | 14 |
| Operational Excellence | <https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist> | 11 |
| Performance Efficiency | <https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist> | 12 |
| **Total** | — | **59** |

**Framework version:** the current (2026-08-01) Azure Well-Architected Framework checklist content.
Microsoft does not date-stamp or version-number this content; "current" means "as published on the
URL above on the extraction date."

## Reliability — `WAF-RE-*` (10 items)

Source: <https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist>

| # | Item |
|---|---|
| WAF-RE-01 | Focus your workload design on simplicity and efficiency. |
| WAF-RE-02 | Identify and rate user and system flows, using a criticality scale based on business requirements. |
| WAF-RE-03 | Use failure mode analysis (FMA) to identify potential failures in your workload. |
| WAF-RE-04 | Define reliability and recovery targets for your workload. |
| WAF-RE-05 | Add redundancy at different levels, especially for critical flows, to help meet reliability targets. |
| WAF-RE-06 | Implement a timely and reliable scaling strategy at the application, data, and infrastructure levels. |
| WAF-RE-07 | Strengthen resiliency by implementing self-preservation and self-healing measures. |
| WAF-RE-08 | Test for resiliency and availability scenarios by applying the principles of chaos engineering. |
| WAF-RE-09 | Implement structured, tested, and documented disaster recovery (DR) plans that align with recovery targets. |
| WAF-RE-10 | Continuously measure and track system health using uptime and reliability indicators. |

## Security — `WAF-SE-*` (12 items)

Source: <https://learn.microsoft.com/en-us/azure/well-architected/security/checklist>

| # | Item |
|---|---|
| WAF-SE-01 | Establish a security baseline aligned to compliance requirements, industry standards, and platform recommendations. |
| WAF-SE-02 | Align the secure development lifecycle (SDL) throughout the software development lifecycle. |
| WAF-SE-03 | Classify and consistently apply sensitivity and information-type labels on all workload data. |
| WAF-SE-04 | Create intentional segmentation and perimeters in your architecture design and platform footprint. |
| WAF-SE-05 | Implement strict, conditional, and auditable identity and access management (IAM) across all workload users, team members, and system components. |
| WAF-SE-06 | Isolate, filter, and control network traffic across both ingress and egress flows. |
| WAF-SE-07 | Encrypt data by using modern, industry-standard methods. |
| WAF-SE-08 | Harden all workload components by reducing extraneous surface area and tightening configurations. |
| WAF-SE-09 | Protect application secrets by hardening their storage, restricting access, and rotating regularly. |
| WAF-SE-10 | Implement a holistic monitoring strategy that relies on modern threat detection mechanisms. |
| WAF-SE-11 | Establish a comprehensive testing regimen combining approaches to prevent, validate, and detect threats. |
| WAF-SE-12 | Define and test effective incident response procedures. |

Note: `waf.security.yaml`'s `WAF-SE-01`–`WAF-SE-07` are Scout's own rule IDs, assigned before this
enumeration existed, and do **not** currently map one-to-one to the Microsoft codes above (Scout's
`WAF-SE-03` is a SQL public-access rule, unrelated to Microsoft's `SE:03` data classification item).
This is a naming collision the rule file inherited, not a citation — see "What this means for the
rule file" below.

## Cost Optimization — `WAF-CO-*` (14 items)

Source: <https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist>

| # | Item |
|---|---|
| WAF-CO-01 | Create a culture of financial responsibility. |
| WAF-CO-02 | Create and maintain a cost model estimating initial cost, run rates, and ongoing costs. |
| WAF-CO-03 | Collect and review cost data, including incurred, prepaid, trends, and forecasts. |
| WAF-CO-04 | Set spending guardrails — release gates, governance policies, resource limits, access controls. |
| WAF-CO-05 | Get the best rates from providers — regional pricing, tiers, commitment models, license portability. |
| WAF-CO-06 | Align usage to billing increments (meters). |
| WAF-CO-07 | Optimize component costs — remove or optimize legacy, unneeded, and underutilized components. |
| WAF-CO-08 | Optimize environment costs — align spend to preproduction, production, operations, and DR needs. |
| WAF-CO-09 | Optimize flow costs — align cost of each flow with flow priority. |
| WAF-CO-10 | Optimize data costs — tiering, retention, volume, replication, backups, file formats. |
| WAF-CO-11 | Optimize code costs — evaluate and modify code to meet requirements with fewer/cheaper resources. |
| WAF-CO-12 | Optimize scaling costs — evaluate alternative scaling configurations against the cost model. |
| WAF-CO-13 | Optimize personnel time on tasks aligned with task priority. |
| WAF-CO-14 | Consolidate resources and responsibility to increase density. |

## Operational Excellence — `WAF-OE-*` (11 items)

Source: <https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist>

| # | Item |
|---|---|
| WAF-OE-01 | Define your standard practices to develop and operate your workload. |
| WAF-OE-02 | Use standardization to make routine, ad-hoc, and emergency operations consistent and predictable. |
| WAF-OE-03 | Formalize processes across the full software development lifecycle, from ideation to delivery. |
| WAF-OE-04 | Enhance software development and QA by implementing industry-standard practices. |
| WAF-OE-05 | Use a standardized infrastructure as code (IaC) approach to prepare resources and configurations. |
| WAF-OE-06 | Build a workload supply chain that drives changes through predictable, automated pipelines. |
| WAF-OE-07 | Design a monitoring stack that captures operational telemetry, metrics, and logs. |
| WAF-OE-08 | Establish a clear, structured incident management process. |
| WAF-OE-09 | Enhance workload quality by adopting testing practices aligned with business objectives. |
| WAF-OE-10 | Design automation to be reliable, secure, and maintainable across the workload lifecycle. |
| WAF-OE-11 | Clearly define your workload's safe deployment practices. |

## Performance Efficiency — `WAF-PE-*` (12 items)

Source: <https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist>

| # | Item |
|---|---|
| WAF-PE-01 | Define performance targets, as numerical values tied to workload requirements. |
| WAF-PE-02 | Conduct capacity planning ahead of predicted usage-pattern changes. |
| WAF-PE-03 | Select the right services, infrastructure, and tiers to reach performance targets. |
| WAF-PE-04 | Establish consistent performance measurement so behavior can be analyzed over time. |
| WAF-PE-05 | Optimize scaling and partitioning — the scale-unit design is the basis of the strategy. |
| WAF-PE-06 | Regularly test performance in a production-like environment. |
| WAF-PE-07 | Optimize code and infrastructure — performant code that offloads responsibility to the platform. |
| WAF-PE-08 | Optimize data usage — data stores, partitions, and indexes for intended and actual use. |
| WAF-PE-09 | Prioritize the performance of critical flows. |
| WAF-PE-10 | Optimize operational tasks that affect workload performance (patching, scans, backups, reindexing). |
| WAF-PE-11 | Respond to live performance issues with clear communication and responsibility lines. |
| WAF-PE-12 | Continuously optimize performance, focusing on components with deteriorating performance over time. |

## What this means for the rule file

`src/assess/rules/waf.storage.yaml` scores a sixth "WAF pillar" — storage — that does not exist in
this enumeration. Per the audit's §8 recommendation, its five rules should be redistributed into the
pillar files they actually belong to (durability/replication → `WAF-RE-05`, encryption/public-access
→ `WAF-SE-06`/`WAF-SE-07`, tiering/lifecycle → `WAF-CO-10`) and the file deleted, or the whole thing
re-modeled as a WAF *service guide* axis (`svc.storage.yaml`) that is explicitly not a pillar score.

The existing `waf.*.yaml` rule IDs (`WAF-SE-01` through `WAF-SE-07`, etc.) predate this enumeration
and were assigned by rule area, not by Microsoft checklist code — they are **not** citations of the
items above. Any rule written or renumbered after this file exists should cite the Microsoft code
directly (e.g. a new segmentation rule cites `WAF-SE-04`), so `manual: true` rules can state exactly
which unscorable checklist item they stand in for, the way `smart-question-set.md`'s items map to
named CAF pages.
