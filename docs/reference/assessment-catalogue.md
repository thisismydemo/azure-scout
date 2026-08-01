---
description: Every CAF, WAF and specialised assessment Azure Scout performs, with the rule files and rule counts behind each.
---

# Assessment Catalogue

Azure Scout ships **46 assessments** backed by **44 rule files** holding
**395 rules**, of which **170 are evaluated automatically** and
**225 require manual confirmation**.

Run one, several, or all of them:

```powershell
Invoke-AzureScout -TenantID '<guid>' -Assessment 'LandingZone'
Invoke-AzureScout -TenantID '<guid>' -Assessment 'WAF: Security','Assess: Networking'
Invoke-AzureScout -TenantID '<guid>' -Assessment 'All'
```

::: tip This page is generated
Regenerate it with `scripts/Build-AssessmentCatalog.ps1`. Rows and counts come from
`manifests/assessments.psd1` and `src/assess/rules/`; `tests/DocsAssessmentCatalog.Tests.ps1`
fails the build if the committed page and a fresh regeneration disagree. Do not hand-edit it.
:::

::: warning Manual rules are not failures
A manual rule is one no collected data can decide — a process control, or a source Azure
does not expose. Manual rules are excluded from every score rather than counted as failures,
and they are reported separately. An assessment whose rules are largely manual produces a
worklist, not a grade.
:::

## Cloud Adoption Framework (11)

| Assessment | What it covers | Rules | Automated | Manual | Rule files |
|---|---|--:|--:|--:|---|
| **CAF: Azure billing and Microsoft Entra tenant** | CAF landing zone design area — Azure billing and Microsoft Entra ID tenant setup | 6 | 0 | 6 | `caf.billing` |
| **CAF: Governance** | CAF landing zone design area — Governance (policy & compliance) | 7 | 4 | 3 | `caf.governance` |
| **CAF: Identity and access management** | CAF landing zone design area — Identity and access management | 7 | 4 | 3 | `caf.identity` |
| **CAF: Management** | CAF landing zone design area — Management (monitoring, operations baseline) | 6 | 5 | 1 | `caf.management` |
| **CAF: Network topology and connectivity** | CAF landing zone design area — Network topology and connectivity | 7 | 6 | 1 | `caf.network` |
| **CAF: Platform automation and DevOps** | CAF landing zone design area — Platform automation and DevOps | 6 | 2 | 4 | `caf.platformauto` |
| **CAF: Resource organization** | CAF landing zone design area — Resource organization (management groups, subscriptions, tags) | 6 | 4 | 2 | `caf.resourceorg` |
| **CAF: Security** | CAF landing zone design area — Security | 7 | 6 | 1 | `caf.security` |
| **Governance** | Management sub-bundle — policy assignments, locks, budgets | 7 | 4 | 3 | `caf.governance` |
| **LandingZone** | CAF/WAF landing zone audit (all areas) | 285 | 131 | 154 | `caf.ai`<br>`caf.analytics`<br>`caf.avslandingzone`<br>`caf.billing`<br>`caf.containers`<br>`caf.databases`<br>`caf.govern.ai`<br>`caf.govern.cm`<br>`caf.govern.dg`<br>`caf.govern.op`<br>`caf.govern.rc`<br>`caf.govern.rm`<br>`caf.govern.sc`<br>`caf.governance`<br>`caf.hybrid`<br>`caf.identity`<br>`caf.integration`<br>`caf.iot`<br>`caf.management`<br>`caf.network`<br>`caf.platformauto`<br>`caf.resourceorg`<br>`caf.security`<br>`caf.storage`<br>`caf.web`<br>`waf.ai`<br>`waf.avd`<br>`waf.azurelocal.cost`<br>`waf.azurelocal.operational`<br>`waf.azurelocal.performance`<br>`waf.azurelocal.reliability`<br>`waf.azurelocal.security`<br>`waf.cost`<br>`waf.operational`<br>`waf.performance`<br>`waf.reliability`<br>`waf.security`<br>`xr.crossresource` |
| **UpdateManager** | Management sub-bundle (subset of "Assess: Management") — patch/update compliance only | 6 | 5 | 1 | `caf.management` |

## Well-Architected Framework (9)

| Assessment | What it covers | Rules | Automated | Manual | Rule files |
|---|---|--:|--:|--:|---|
| **Cost** | Cost / TCO data pull | 9 | 6 | 3 | `waf.cost` |
| **Monitoring** | Monitor sub-bundle (subset of "Assess: Monitor") — diagnostic settings coverage only | 6 | 3 | 3 | `waf.operational` |
| **WAF: Azure Local** | Well-Architected Framework — Azure Local (platform 2311+ and Azure Local VMs) workload review | 33 | 5 | 28 | `waf.azurelocal.cost`<br>`waf.azurelocal.operational`<br>`waf.azurelocal.performance`<br>`waf.azurelocal.reliability`<br>`waf.azurelocal.security` |
| **WAF: Cost Optimization** | Well-Architected Framework — Cost Optimization pillar only | 9 | 6 | 3 | `waf.cost` |
| **WAF: Maturity Model** | Well-Architected Framework — maturity levels per pillar (same rules as the five WAF pillar assessments, different output framing) | 35 | 21 | 14 | `waf.reliability`<br>`waf.security`<br>`waf.cost`<br>`waf.operational`<br>`waf.performance` |
| **WAF: Operational Excellence** | Well-Architected Framework — Operational Excellence pillar only | 6 | 3 | 3 | `waf.operational` |
| **WAF: Performance Efficiency** | Well-Architected Framework — Performance Efficiency pillar only | 6 | 4 | 2 | `waf.performance` |
| **WAF: Reliability** | Well-Architected Framework — Reliability pillar only | 7 | 3 | 4 | `waf.reliability` |
| **WAF: Security** | Well-Architected Framework — Security pillar only | 7 | 5 | 2 | `waf.security` |

## Service category slices (19)

| Assessment | What it covers | Rules | Automated | Manual | Rule files |
|---|---|--:|--:|--:|---|
| **Assess: AI** | AI/Cognitive private access and responsible-AI posture | 5 | 4 | 1 | `caf.ai` |
| **Assess: AI Workload** | AI workload review (Well-Architected Framework AI workload guidance) -- 34 items across 7 of 10 AI design areas; mostly manual, see docs/frameworks/waf-ai-workload-checklist.md | 34 | 2 | 32 | `waf.ai` |
| **Assess: Analytics** | Analytics data governance and network isolation | 5 | 3 | 2 | `caf.analytics` |
| **Assess: AVD Workload** | AVD-on-Azure-Local workload review (Well-Architected Framework) -- 20 items across all 5 pillars; scoped to AVD deployed on Azure Local, not general Azure Virtual Desktop | 20 | 6 | 14 | `waf.avd` |
| **Assess: Cloud Governance** | CAF Govern methodology -- 1-10 maturity score per risk category (regulatory compliance, security, cost, operations, data, resource management, AI), radar + heatmap report | 18 | 8 | 10 | `caf.govern.ai`<br>`caf.govern.cm`<br>`caf.govern.dg`<br>`caf.govern.op`<br>`caf.govern.rc`<br>`caf.govern.rm`<br>`caf.govern.sc` |
| **Assess: Compliance** | Regulatory compliance — scores every Azure Policy regulatory-compliance initiative assigned in the scanned scope (MCSB, CIS, ISO 27001, NIST, PCI-DSS, ...) from compliance state Azure already evaluated | — | — | — | `compliance.initiative` |
| **Assess: Compute** | VM resilience, zones, backup, right-size, orphans | 22 | 13 | 9 | `waf.reliability`<br>`waf.cost`<br>`waf.performance` |
| **Assess: Containers** | AKS private clusters, RBAC, registry hardening | 8 | 7 | 1 | `caf.containers` |
| **Assess: Databases** | SQL/DB private access, TDE, zone redundancy | 7 | 3 | 4 | `caf.databases` |
| **Assess: Hybrid** | Arc onboarding, agent currency, Azure Local | 6 | 4 | 2 | `caf.hybrid` |
| **Assess: Identity** | Identity & access — PIM, Conditional Access, RBAC | 7 | 4 | 3 | `caf.identity` |
| **Assess: Integration** | Messaging redundancy and APIM network isolation | 6 | 6 | 0 | `caf.integration` |
| **Assess: IoT** | IoT Hub/DPS network isolation and device auth | 13 | 8 | 5 | `caf.iot` |
| **Assess: Management** | Governance, policy, cost, backup, automation, update manager | 19 | 9 | 10 | `caf.governance`<br>`caf.management`<br>`caf.billing` |
| **Assess: Monitor** | Monitoring, alerting, diagnostics coverage | 12 | 8 | 4 | `caf.management`<br>`waf.operational` |
| **Assess: Networking** | Network topology, firewall, DDoS, exposure, private link | 7 | 6 | 1 | `caf.network` |
| **Assess: Security** | Defender, Key Vault, secure score, exposure | 14 | 11 | 3 | `caf.security`<br>`waf.security` |
| **Assess: Storage** | Storage public access, TLS, encryption, redundancy | 6 | 4 | 2 | `caf.storage` |
| **Assess: Web** | App Service HTTPS-only, TLS, managed identity | 6 | 4 | 2 | `caf.web` |

## Specialised and workload assessments (7)

| Assessment | What it covers | Rules | Automated | Manual | Rule files |
|---|---|--:|--:|--:|---|
| **AVS Landing Zone** | Azure VMware Solution Landing Zone Assessment Review — platform readiness (see docs/frameworks/avs-landing-zone-question-set.md) | 25 | 9 | 16 | `caf.avslandingzone` |
| **AVS Workload** | Azure VMware Solution workload — Reliability, Security, and Governance coverage (no published WAF pillar service guide exists for AVS; see docs/frameworks/waf-avs-workload-checklist.md) | 27 | 9 | 18 | `avs.workload` |
| **CASA** | Cloud Adoption Security Assessment — cloud security maturity aligned to the CAF Secure methodology (question text is Scout's own inference from the published CAF Secure checklist, not Microsoft's numbered CASA questions; see docs/frameworks/casa-question-set.md) | 32 | 8 | 24 | `casa.security` |
| **CrossResource** | Findings that require two collected datasets correlated | 6 | 6 | 0 | `xr.crossresource` |
| **DevOps Capability Assessment** | DevOps Capability Assessment -- scores against the Microsoft DevOps Resource Center's five practice phases (docs/frameworks/devops-capability-question-set.md). The assessment itself and its question numbering are INFERRED, not Microsoft-published. A DIFFERENT, narrower assessment than "CAF: Platform automation and DevOps" (the landing-zone design area) -- the two overlap in subject but are not the same enumeration. Azure DevOps access is opt-in (-IncludeDevOps) and sits behind its own auth boundary; when it was not granted, the affected findings report NotAssessed, never a scored zero. | 18 | 9 | 9 | `devops.capability` |
| **FinOps Review** | FinOps Review -- scores against the FinOps Framework's 22 published capabilities (docs/frameworks/finops-review-question-set.md). The assessment itself and its question numbering are INFERRED, not Microsoft-published -- Microsoft names the assessment and publishes the framework, but not the assessment's own question text. Cost data sits behind the EA/MCA billing permission system, a different boundary than ARM Reader; when that gate blocks the pull, the affected findings report NotAssessed, never a scored zero. | 22 | 6 | 16 | `finops.review` |
| **SMART** | Strategic Migration Assessment — migration readiness (see docs/frameworks/smart-question-set.md) | 11 | 7 | 4 | `smart.migration` |

## Rule files

Each file declares one framework area. An assessment selects files by glob.

| Rule file | Rules | Automated | Manual |
|---|--:|--:|--:|
| `avs.workload` | 27 | 9 | 18 |
| `caf.ai` | 5 | 4 | 1 |
| `caf.analytics` | 5 | 3 | 2 |
| `caf.avslandingzone` | 25 | 9 | 16 |
| `caf.billing` | 6 | 0 | 6 |
| `caf.containers` | 8 | 7 | 1 |
| `caf.databases` | 7 | 3 | 4 |
| `caf.govern.ai` | 2 | 0 | 2 |
| `caf.govern.cm` | 4 | 2 | 2 |
| `caf.govern.dg` | 2 | 1 | 1 |
| `caf.govern.op` | 4 | 2 | 2 |
| `caf.govern.rc` | 2 | 1 | 1 |
| `caf.govern.rm` | 1 | 1 | 0 |
| `caf.govern.sc` | 3 | 1 | 2 |
| `caf.governance` | 7 | 4 | 3 |
| `caf.hybrid` | 6 | 4 | 2 |
| `caf.identity` | 7 | 4 | 3 |
| `caf.integration` | 6 | 6 | 0 |
| `caf.iot` | 13 | 8 | 5 |
| `caf.management` | 6 | 5 | 1 |
| `caf.network` | 7 | 6 | 1 |
| `caf.platformauto` | 6 | 2 | 4 |
| `caf.resourceorg` | 6 | 4 | 2 |
| `caf.security` | 7 | 6 | 1 |
| `caf.storage` | 6 | 4 | 2 |
| `caf.web` | 6 | 4 | 2 |
| `casa.security` | 32 | 8 | 24 |
| `compliance.initiative` | 0 | 0 | 0 |
| `devops.capability` | 18 | 9 | 9 |
| `finops.review` | 22 | 6 | 16 |
| `smart.migration` | 11 | 7 | 4 |
| `waf.ai` | 34 | 2 | 32 |
| `waf.avd` | 20 | 6 | 14 |
| `waf.azurelocal.cost` | 6 | 0 | 6 |
| `waf.azurelocal.operational` | 6 | 4 | 2 |
| `waf.azurelocal.performance` | 6 | 0 | 6 |
| `waf.azurelocal.reliability` | 6 | 1 | 5 |
| `waf.azurelocal.security` | 9 | 0 | 9 |
| `waf.cost` | 9 | 6 | 3 |
| `waf.operational` | 6 | 3 | 3 |
| `waf.performance` | 6 | 4 | 2 |
| `waf.reliability` | 7 | 3 | 4 |
| `waf.security` | 7 | 5 | 2 |
| `xr.crossresource` | 6 | 6 | 0 |

**Total — 44 files, 395 rules, 170 automated, 225 manual.**


