---
description: How much of each enumerated framework Azure Scout actually has a rule for.
---

# Framework Coverage

Across every framework Azure Scout enumerates, **221 of 647 items (34%) have a rule behind them**.

::: warning Read this number the right way
Scout **enumerates** each framework in full — see [Frameworks](../frameworks/README.md) — and a test
keeps those enumerations current. Enumerating an item is not the same as testing it.
This page is the difference between the two, and it is published because the alternative
is a reader assuming that "supports CAF and WAF" means full coverage. It does not.

An item counts as **covered** when a rule references its identifier. That is a coverage
measure, not a quality one: it says a rule exists, not that the rule is a good test of the
item. A `manual: true` rule still counts, because a human is at least being asked the
question — see the [Assessment Catalogue](./assessment-catalogue.md) for how many rules are
manual, which is a large share of them.
:::

::: tip This page is generated
Regenerate with `scripts/Build-FrameworkCoverage.ps1`. Counts come from
`docs/frameworks/*.md` and `src/assess/rules/`; a test fails the build if the committed page
and a fresh regeneration disagree.
:::

## Coverage by framework

| Framework enumeration | Items | Covered | Item coverage | Areas covered |
|---|--:|--:|--:|--:|
| [`caf-landing-zone-design-areas`](../frameworks/caf-landing-zone-design-areas.md) | 393 | 0 | **0%** | 8 / 8 |
| [`waf-pillar-checklists`](../frameworks/waf-pillar-checklists.md) | 59 | 31 | **53%** | 1 / 1 |
| [`casa-question-set`](../frameworks/casa-question-set.md) | 37 | 37 | **100%** | 3 / 3 |
| [`waf-ai-workload-checklist`](../frameworks/waf-ai-workload-checklist.md) | 34 | 34 | **100%** | 1 / 1 |
| [`waf-azure-local-checklist`](../frameworks/waf-azure-local-checklist.md) | 33 | 33 | **100%** | 1 / 1 |
| [`waf-avs-workload-checklist`](../frameworks/waf-avs-workload-checklist.md) | 27 | 27 | **100%** | 1 / 1 |
| [`cloud-governance-question-set`](../frameworks/cloud-governance-question-set.md) | 23 | 18 | **78%** | 1 / 1 |
| [`devops-capability-question-set`](../frameworks/devops-capability-question-set.md) | 20 | 20 | **100%** | 2 / 2 |
| [`waf-avd-workload-checklist`](../frameworks/waf-avd-workload-checklist.md) | 20 | 20 | **100%** | 1 / 1 |
| [`smart-question-set`](../frameworks/smart-question-set.md) | 1 | 1 | **100%** | 1 / 1 |
| `avs-landing-zone-question-set` | — | — | *not enumerated with item ids* | — |
| `finops-review-question-set` | — | — | *not enumerated with item ids* | — |
| **Total** | **647** | **221** | **34%** | |

::: warning Where item coverage reads 0%, check the areas column
`caf-landing-zone-design-areas` enumerates individual recommendations (`AUT-DEV-01`,
`AUT-DEV-02`, …) while Scout's CAF rules are written one level up, per design area
(`CAF-AUT-01`…`CAF-AUT-06`). No rule maps to a specific enumerated recommendation, so
item coverage is 0% **by construction** — but rules for those areas do exist, which is what
the areas column shows.

Read that as: Scout checks something in most CAF design areas, and checks it broadly. It
does not test the 393 individual recommendations Microsoft publishes, and no page should
imply that it does.
:::

## What is not covered

The specific items with no rule of their own. This is the backlog, stated rather than implied.

### `caf-landing-zone-design-areas` — 393 of 393 uncovered

`AUT-DEV-01`, `AUT-DEV-02`, `AUT-DEV-03`, `AUT-DEV-04`, `AUT-DEV-05`, `AUT-DEV-06`, `AUT-DEV-07`, `AUT-DEV-08`, `AUT-DEV-09`, `AUT-DEV-10`, `AUT-DEV-11`, `AUT-DEV-12`, `AUT-DEV-13`, `AUT-DEV-14`, `AUT-DEV-15`, `AUT-DEV-16`, `AUT-DEV-17`, `AUT-DEV-18`, `AUT-ENV-01`, `AUT-ENV-02`, `AUT-ENV-03`, `AUT-PA-01`, `AUT-PA-02`, `AUT-PA-03`, `AUT-PA-04`, `AUT-PA-05`, `AUT-PA-06`, `AUT-PA-07`, `AUT-PA-08`, `AUT-PA-09`, `AUT-PA-10`, `AUT-PA-11`, `AUT-PA-12`, `AUT-SEC-01`, `AUT-SEC-02`, `AUT-SEC-03`, `AUT-SEC-04`, `AUT-SEC-05`, `AUT-SEC-06`, `AUT-SEC-07`, `AUT-SEC-08`, `AUT-SEC-09`, `AUT-SEC-10`, `AUT-TOP-01`, `AUT-TOP-02`, `AUT-TOP-03`, `AUT-TOP-04`, `AUT-TOP-05`, `AUT-TOP-06`, `AUT-TOP-07`, `AUT-TOP-08`, `AUT-TOP-09`, `BIL-CSP-01`, `BIL-CSP-02`, `BIL-CSP-03`, `BIL-CSP-04`, `BIL-CSP-05`, `BIL-CSP-06`, `BIL-CSP-07`, `BIL-CSP-08`, `BIL-CSP-09`, `BIL-EA-01`, `BIL-EA-02`, `BIL-EA-03`, `BIL-EA-04`, `BIL-EA-05`, `BIL-EA-06`, `BIL-EA-07`, `BIL-EA-08`, `BIL-EA-09`, `BIL-EA-10`, `BIL-EA-11`, `BIL-EA-12`, `BIL-EA-13`, `BIL-EA-14`, `BIL-EA-15`, `BIL-MCA-01`, `BIL-MCA-02`, `BIL-MCA-03`, `BIL-MCA-04`, `BIL-MCA-05`, `BIL-MCA-06`, `BIL-MCA-07`, `BIL-MCA-08`, `BIL-MCA-09`, `BIL-TEN-01`, `BIL-TEN-02`, `BIL-TEN-03`, `BIL-TEN-04`, `BIL-TEN-05`, `BIL-TEN-06`, `BIL-TEN-07`, `BIL-TEN-08`, `GOV-CST-01`, `GOV-CST-02`, `GOV-DEP-01`, `GOV-DEP-02`, `GOV-DEP-03`, `GOV-DEP-04`, `GOV-DEP-05`, `GOV-DEP-06`, `GOV-DEP-07`, `GOV-DEP-08`, `IDN-APP-01`, `IDN-APP-02`, `IDN-APP-03`, `IDN-APP-04`, `IDN-APP-05`, `IDN-APP-06`, `IDN-APP-07`, `IDN-APP-08`, `IDN-APP-09`, `IDN-APP-10`, `IDN-APP-11`, `IDN-APP-12`, `IDN-HYB-01`, `IDN-HYB-02`, `IDN-HYB-03`, `IDN-HYB-04`, `IDN-HYB-05`, `IDN-HYB-06`, `IDN-HYB-07`, `IDN-HYB-08`, `IDN-HYB-09`, `IDN-HYB-10`, `IDN-HYB-11`, `IDN-HYB-12`, `IDN-HYB-13`, `IDN-HYB-14`, `IDN-HYB-15`, `IDN-HYB-16`, `IDN-HYB-17`, `IDN-HYB-18`, `IDN-HYB-19`, `IDN-HYB-20`, `IDN-HYB-21`, `IDN-LZ-01`, `IDN-LZ-02`, `IDN-LZ-03`, `IDN-LZ-04`, `IDN-LZ-05`, `IDN-LZ-06`, `IDN-LZ-07`, `IDN-LZ-08`, `IDN-LZ-09`, `IDN-LZ-10`, `IDN-LZ-11`, `IDN-LZ-12`, `IDN-LZ-13`, `IDN-LZ-14`, `IDN-LZ-15`, `IDN-LZ-16`, `IDN-LZ-17`, `IDN-LZ-18`, `IDN-LZ-19`, `IDN-LZ-20`, `IDN-LZ-21`, `IDN-LZ-22`, `IDN-LZ-23`, `IDN-LZ-24`, `IDN-LZ-25`, `IDN-LZ-26`, `IDN-LZ-27`, `IDN-LZ-28`, `IDN-LZ-29`, `IDN-LZ-30`, `MGT-BCDR-01`, `MGT-BCDR-02`, `MGT-BCDR-03`, `MGT-BCDR-04`, `MGT-BCDR-05`, `MGT-INV-01`, `MGT-INV-02`, `MGT-INV-03`, `MGT-INV-04`, `MGT-INV-05`, `MGT-INV-06`, `MGT-INV-07`, `MGT-INV-08`, `MGT-OPC-01`, `MGT-OPC-02`, `NET-CTA-01`, `NET-CTA-02`, `NET-CTA-03`, `NET-CTA-04`, `NET-CTA-05`, `NET-CTA-06`, `NET-CTA-07`, `NET-CTA-08`, `NET-CTA-09`, `NET-CTA-10`, `NET-CTA-11`, `NET-CTA-12`, `NET-DNS-01`, `NET-DNS-02`, `NET-DNS-03`, `NET-DNS-04`, `NET-DNS-05`, `NET-DNS-06`, `NET-DNS-07`, `NET-DNS-08`, `NET-ENC-01`, `NET-ENC-02`, `NET-ENC-03`, `NET-ENC-04`, `NET-ENC-05`, `NET-ENC-06`, `NET-HYB-01`, `NET-HYB-02`, `NET-HYB-03`, `NET-HYB-04`, `NET-HYB-05`, `NET-HYB-06`, `NET-HYB-07`, `NET-HYB-08`, `NET-HYB-09`, `NET-HYB-10`, `NET-HYB-11`, `NET-HYB-12`, `NET-HYB-13`, `NET-HYB-14`, `NET-HYB-15`, `NET-HYB-16`, `NET-HYB-17`, `NET-HYB-18`, `NET-HYB-19`, `NET-HYB-20`, `NET-HYB-21`, `NET-INS-01`, `NET-INS-02`, `NET-INS-03`, `NET-INS-04`, `NET-INS-05`, `NET-INT-01`, `NET-INT-02`, `NET-INT-03`, `NET-INT-04`, `NET-INT-05`, `NET-INT-06`, `NET-INT-07`, `NET-INT-08`, `NET-INT-09`, `NET-INT-10`, `NET-INT-11`, `NET-INT-12`, `NET-INT-13`, `NET-INT-14`, `NET-INT-15`, `NET-INT-16`, `NET-INT-17`, `NET-INT-18`, `NET-INT-19`, `NET-IP-01`, `NET-IP-02`, `NET-IP-03`, `NET-IP-04`, `NET-IP-05`, `NET-IP-06`, `NET-IP-07`, `NET-IP-08`, `NET-IP-09`, `NET-IP-10`, `NET-IP-11`, `NET-IP-12`, `NET-IP-13`, `NET-IP-14`, `NET-IP-15`, `NET-IP-16`, `NET-IP-17`, `NET-IP-18`, `NET-IP-19`, `NET-IP-20`, `NET-IP-21`, `NET-IP-22`, `NET-IP-23`, `NET-OCP-01`, `NET-OCP-02`, `NET-OCP-03`, `NET-OCP-04`, `NET-OCP-05`, `NET-OCP-06`, `NET-OCP-07`, `NET-OCP-08`, `NET-OCP-09`, `NET-OCP-10`, `NET-OCP-11`, `NET-OCP-12`, `NET-OCP-13`, `NET-OCP-14`, `NET-OCP-15`, `NET-OCP-16`, `NET-OCP-17`, `NET-OCP-18`, `NET-SEG-01`, `NET-SEG-02`, `NET-SEG-03`, `NET-SEG-04`, `NET-SEG-05`, `NET-SEG-06`, `NET-SEG-07`, `NET-SEG-08`, `NET-SEG-09`, `NET-VWN-01`, `NET-VWN-02`, `NET-VWN-03`, `NET-VWN-04`, `NET-VWN-05`, `NET-VWN-06`, `NET-VWN-07`, `NET-VWN-08`, `NET-VWN-09`, `NET-VWN-10`, `NET-VWN-11`, `NET-VWN-12`, `NET-VWN-13`, `NET-VWN-14`, `RES-MG-01`, `RES-MG-02`, `RES-MG-03`, `RES-MG-04`, `RES-MG-05`, `RES-MG-06`, `RES-MG-07`, `RES-MG-08`, `RES-MG-09`, `RES-MG-10`, `RES-MG-11`, `RES-MG-12`, `RES-MG-13`, `RES-SUB-01`, `RES-SUB-02`, `RES-SUB-03`, `RES-SUB-04`, `RES-SUB-05`, `RES-SUB-06`, `RES-SUB-07`, `RES-SUB-08`, `RES-SUB-09`, `RES-SUB-10`, `RES-SUB-11`, `RES-SUB-12`, `RES-SUB-13`, `RES-SUB-14`, `RES-SUB-15`, `RES-SUB-16`, `RES-SUB-17`, `RES-SUB-18`, `RES-SUB-19`, `RES-SUB-20`, `RES-SUB-21`, `RES-SUB-22`, `SEC-AC-01`, `SEC-AC-02`, `SEC-AC-03`, `SEC-AC-04`, `SEC-AC-05`, `SEC-ENC-01`, `SEC-ENC-02`, `SEC-ENC-03`, `SEC-ENC-04`, `SEC-ENC-05`, `SEC-ENC-06`, `SEC-ENC-07`, `SEC-ENC-08`, `SEC-ENC-09`, `SEC-ENC-10`, `SEC-ENC-11`, `SEC-ENC-12`, `SEC-OPS-01`, `SEC-OPS-02`, `SEC-OPS-03`, `SEC-OPS-04`, `SEC-OPS-05`, `SEC-OPS-06`, `SEC-OPS-07`, `SEC-OPS-08`, `SEC-OPS-09`, `SEC-ZT-01`, `SEC-ZT-02`, `SEC-ZT-03`, `SEC-ZT-04`, `SEC-ZT-05`, `SEC-ZT-06`, `SEC-ZT-07`, `SEC-ZT-08`, `SEC-ZT-09`, `SEC-ZT-10`, `SEC-ZT-11`, `SEC-ZT-12`, `SEC-ZT-13`, `SEC-ZT-14`, `SEC-ZT-15`, `SEC-ZT-16`

### `waf-pillar-checklists` — 28 of 59 uncovered

`WAF-CO-10`, `WAF-CO-11`, `WAF-CO-12`, `WAF-CO-13`, `WAF-CO-14`, `WAF-OE-03`, `WAF-OE-04`, `WAF-OE-09`, `WAF-OE-10`, `WAF-OE-11`, `WAF-PE-03`, `WAF-PE-08`, `WAF-PE-09`, `WAF-PE-10`, `WAF-PE-11`, `WAF-PE-12`, `WAF-RE-01`, `WAF-RE-02`, `WAF-RE-04`, `WAF-RE-06`, `WAF-RE-07`, `WAF-RE-08`, `WAF-RE-10`, `WAF-SE-08`, `WAF-SE-09`, `WAF-SE-10`, `WAF-SE-11`, `WAF-SE-12`

### `cloud-governance-question-set` — 5 of 23 uncovered

`CGOV-PROC-01`, `CGOV-PROC-02`, `CGOV-PROC-03`, `CGOV-PROC-04`, `CGOV-PROC-05`


