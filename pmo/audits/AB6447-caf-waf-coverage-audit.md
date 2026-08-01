# AB#6447 — CAF/WAF coverage audit

**Scope:** Does Azure Scout actually assess against the Cloud Adoption Framework and the Well-Architected Framework, or does it sample them?
**Method:** Every rule file in `src/assess/rules/` read and catalogued, then matched against the current (July 2026) Microsoft-published WAF design-review checklists and CAF landing zone design areas retrieved from Microsoft Learn.
**Date:** 2026-07-30
**Status:** read-only audit — no code changed.

---

## Executive summary

**No. Scout does not fully assess against CAF/WAF, and the gap is much larger than the rule count suggests.**

| Framework | Official scope | Scout's rules | Meaningful coverage |
|---|---|---|---|
| **WAF** — 5 pillars | **59** design-review checklist items (RE 10, SE 12, CO 14, OE 11, PE 12) | 33 rules in `waf.*` (+ borrowed `caf.*`) | **~8 items solidly covered, ~18 partial, ~33 untouched → ~14% solid / ~44% touched** |
| **CAF** — 8 landing zone design areas | **~316 design considerations + ~394 design recommendations** across ~43 pages | 53 rules across the 8 `caf.*` design-area files | **~10%** |

Three findings dominate:

1. **A shipped defect means operators only ever see one assessment.** The wizard's path to the assessment manifest is wrong by two directory levels, so `Test-Path` fails silently and it falls back to a hardcoded `@('LandingZone')`. 21 of 22 registered assessments are unreachable from the wizard. Confirmed empirically, root cause identified, one-line fix. **This is the highest-priority item in this audit.** See [The wizard defect](#the-wizard-defect).

2. **32% of all rules (47 of 148) are `manual: true`** — they have `query: null`, assert nothing, and produce no automated verdict. They are prompts for a human. Several sit on top of data Scout *already collects*. Whole areas are manual-only: `waf.storage.yaml` is 4 of 5 manual, `waf.reliability.yaml` is 1 of 3.

3. **Scout collects Azure Policy compliance state and never scores it.** `Get-ScoutSubscriptionSecurityPolicySweep.ps1` pulls `PolicyComplianceStates`, `Start-ScoutPolicyJob.ps1` computes `nonCompliantResources` / `nonCompliantPolicies`, and `Get-ScoutApiResources.ps1` calls the `policyStates/latest/summarize` API. **Zero rules reference any of it.** `caf.governance.yaml` checks that policy assignments *exist* and that there are *more than five* — the single most valuable governance signal in Azure is collected, paid for in query time, and thrown away.

The rule corpus is real work and the automated rules that exist are mostly sound. The problem is not quality-per-rule, it is **breadth**: Scout covers the parts of CAF/WAF that are trivially observable from Azure Resource Graph, and skips almost everything else. The owner's instinct is correct on both counts — there should be more assessments, and the existing ones do not fully cover their pillars.

---

## The wizard defect

**Confirmed. This is a real, shipped, user-visible defect.**

### What's wrong

`src/Start-AZSCWizard.ps1:238`:

```powershell
$manifestPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) 'manifests/assessments.psd1'
$assessmentNames = @('LandingZone')
if (Test-Path $manifestPath) {
    try { $assessmentNames = @((Import-PowerShellDataFile $manifestPath).Keys | Sort-Object) }
    catch { Write-Verbose "..." }
}
```

`Start-AZSCWizard.ps1` lives in `src/`, so `$PSScriptRoot` is `<repo>/src`. Three `Split-Path -Parent` calls climb three levels from there. Resolved empirically:

```
RESOLVES TO: D:\git\manifests\assessments.psd1
EXISTS: False
```

The manifest is at `<repo>/manifests/assessments.psd1` — **one** level up, not three. `Test-Path` returns `$false`, the `if` never runs, and `$assessmentNames` stays at its hardcoded fallback. The operator is offered a one-item checklist containing only `LandingZone`.

Note the failure is **silent by design in the wrong place**: the `catch` writes a `Write-Verbose` explaining the fallback, but that catch never fires. The `Test-Path` guard swallows the real failure with no message at all. Nothing is logged even at `-Verbose`.

### Root cause

`archived/Modules/Public/PublicFunctions/Start-AZSCWizard.ps1:199` has the **identical** expression. In the original ARI-fork layout the file sat at `Modules/Public/PublicFunctions/`, where three parents correctly resolved to the repo root. The engine rewrite moved the file to `src/` and the path arithmetic was never updated. The correct sibling pattern is already used elsewhere — `src/Invoke-ScoutAssessmentCore.ps1:95`:

```powershell
$manifest = Import-PowerShellDataFile "$PSScriptRoot/../manifests/assessments.psd1"
```

### Why it shipped

**There is no wizard test.** `ls tests/ | grep -i wizard` returns nothing, and no test anywhere references `manifestPath` or the `'Assessments to run'` prompt. The manifest-discovery path has never been exercised.

### Impact

- 21 of 22 registered assessments are unreachable via the wizard — including every per-pillar and per-domain assessment the owner is asking about. From the operator's seat, Scout looks like a one-assessment tool.
- The defect is invisible: no error, no warning, no verbose output. It reads as a deliberate product decision.
- `Invoke-AzureScout -Assessment <name>` is unaffected — the direct path works. So the feature exists and is correct; only the discovery surface is broken. Anyone reading the docs is fine; anyone using the guided experience the wizard exists to provide is not.

### Fix

```powershell
$manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'manifests/assessments.psd1'
```

Plus three things that should land with it:

1. Replace the silent `Test-Path` guard with a visible warning when the manifest can't be read, so the next path regression is loud.
2. Add a Pester test asserting the wizard resolves the real manifest and returns all 22 names.
3. Reconsider `-DefaultSelected @('LandingZone')` on line 244. Even once fixed, only LandingZone is pre-checked. That is defensible (LandingZone is the `caf.* + waf.*` roll-up and running all 22 duplicates work), but it should be a deliberate documented choice, not an accident of the fallback value.

**Secondary issue on the same line:** `.Keys | Sort-Object` produces alphabetical order — `AI, Analytics, Compute, Containers, ...` — which buries `LandingZone` mid-list and gives no signal that the 22 entries are three different kinds of thing (roll-ups, per-category, sub-bundles). The manifest's own comment structure groups them; the wizard discards that grouping.

---

## WAF coverage matrix

Official source: the five per-pillar design review checklists on Microsoft Learn, current July 2026. **59 items total.**

Legend: **Solid** = automated rule that genuinely tests the item. **Partial** = touches one narrow aspect, or is manual-only. **None** = no rule.

### Reliability — 3 rules against 10 checklist items

`src/assess/rules/waf.reliability.yaml` — the thinnest file in the repo, and it is the pillar most customers care about.

| Item | Scout | Verdict |
|---|---|---|
| RE:01 Simplify design | — | None |
| RE:02 Identify and rate flows | — | None |
| RE:03 Failure mode analysis | `WAF-RE-03` (`manual: true`) | Partial |
| RE:04 Reliability/recovery targets | — | None |
| RE:05 Redundancy | `WAF-RE-05` zone-redundant VMs; `WAF-STO-01` storage SKU | **Solid** (VM/storage only) |
| RE:06 Scaling strategy | — | None (`WAF-PE-04` autoscale sits in Performance) |
| RE:07 Self-preservation / self-healing | — | None |
| RE:08 Chaos / resiliency testing | — | None |
| RE:09 Disaster recovery plans | `WAF-RE-09` "Backup configured" | Partial — **mislabelled** |
| RE:10 Health monitoring | — | None (`WAF-OE-01` diagnostics sits in OpEx) |

**Coverage: 1 solid, 2 partial, 7 none ≈ 10–25%.**

`WAF-RE-09` deserves calling out. RE:09 is *"implement structured, tested, documented DR plans"*. The rule asserts `$.management.recoveryVaults[*].backupItems[*]` count > 0 — **one backup item anywhere in the tenant passes the entire DR checklist item**. Backup is not DR. There is no ASR check, no RTO/RPO check, no region-pair check, no failover-test check, despite CAF's Management design area specifying all of them.

Also absent: RE:05 only covers VMs and storage accounts. Zone redundancy for SQL, AKS, App Service, gateways, Event Hub, and APIM is checked — but in `caf.databases`, `caf.containers`, `caf.integration`. The Reliability pillar doesn't see them, so a Reliability-scoped run scores against 3 rules while the evidence for 6 more sits in adjacent files. **This is the single clearest argument for restructuring the rule namespace** (see [Recommendations](#recommendation-1-restructure-the-rule-namespace-around-the-two-real-axes)).

### Security — strongest pillar, ~8 of 12 touched

`waf.security.yaml` (7) + `caf.security.yaml` (7) + `caf.identity.yaml` (7) + service-domain rules.

| Item | Scout | Verdict |
|---|---|---|
| SE:01 Security baseline | `CAF-SEC-02` Defender enabled; `WAF-SE-02/04` Advisor; `CAF-SEC-07` secure score (manual) | Partial |
| SE:02 Secure development lifecycle | — | None |
| SE:03 Data classification | `CAF-ANL-02` Purview (manual) | Partial |
| SE:04 Segmentation | `CAF-NET-01` hub-spoke; `CAF-SEC-01` NSG | Partial |
| SE:05 Identity and access | `CAF-IDN-01…07` | **Solid** |
| SE:06 Network traffic control | `WAF-SE-01/03`, `CAF-SEC-01`, `CAF-NET-02/04/07` | **Solid** |
| SE:07 Encryption | `WAF-SE-05`, `CAF-DB-03` TDE, `CAF-AI-05` CMK, `CAF-STO-02/03` | **Solid** |
| SE:08 Harden resources | TLS/HTTPS/public-access rules across storage, web, DB, AI, IoT, containers | **Solid** |
| SE:09 Application secrets | `WAF-SE-07`, `CAF-SEC-04/05` KV soft-delete + purge protection | Partial |
| SE:10 Monitor threats | `WAF-SE-06`, `CAF-SEC-02`, `CAF-DB-04` | **Solid** |
| SE:11 Security testing | — | None |
| SE:12 Incident response | — | None |

**Coverage: 5 solid, 4 partial, 3 none ≈ 45–60%.** Genuinely respectable.

Gaps worth fixing, all observable from data Scout already has or can cheaply get: Key Vault using **RBAC data plane rather than legacy access policies**, vault firewall enabled, key/cert auto-rotation, per-environment vault separation, activity log export destination and retention, and the six default ALZ policies CAF's Security design area names explicitly (HTTPS on storage, SQL auditing, SQL encryption, no IP forwarding, no inbound RDP from internet, subnet-NSG association).

SE:11 and SE:12 are process items and reasonably out of reach for a scanner — but they should exist as `manual: true` rules so they appear in the report as *unassessed* rather than being invisible.

### Cost Optimization — 6 + 7 rules against 14 items

| Item | Scout | Verdict |
|---|---|---|
| CO:01 Culture of financial responsibility | — | None |
| CO:02 Cost model | — | None |
| CO:03 Collect and review cost data | `CAF-BIL-07` anomalies (manual) | Partial |
| CO:04 Spending guardrails | `WAF-CO-03`, `CAF-BIL-01/05` budgets | Partial |
| CO:05 Get the best rates | `WAF-CO-05`, `CAF-BIL-06` RI/SP (both manual) | Partial |
| CO:06 Align to billing increments | — | None |
| CO:07 Optimize component costs | `WAF-CO-01/04/06`, `CAF-BIL-02/03/04` orphans + Advisor | **Solid** |
| CO:08 Optimize environment costs | — | None |
| CO:09 Optimize flow costs | — | None |
| CO:10 Optimize data costs | `WAF-STO-03` lifecycle (manual) | Partial |
| CO:11 Optimize code costs | — | None (out of scope) |
| CO:12 Optimize scaling costs | `WAF-PE-04` autoscale | Partial |
| CO:13 Optimize personnel time | — | None |
| CO:14 Consolidation | — | None |

**Coverage: 1 solid, 5 partial, 8 none ≈ 15–25%.**

Cost is where the cheapest wins are, because CAF's Governance design area enumerates 12 concrete cost considerations Scout already has the data for and doesn't check: **Azure Hybrid Benefit** enablement on Windows/SQL VMs, reservation coverage (currently manual and could be automated), savings plan coverage, allowed-region/SKU policies, storage lifecycle policies, Spot VM adoption, and dev/test subscription offer usage.

`WAF-CO-01`/`CAF-BIL-02` and `WAF-CO-04`/`CAF-BIL-03` are exact duplicates — orphaned disks and orphaned public IPs, checked twice under different IDs. A LandingZone run (`caf.* + waf.*`) counts both, double-weighting orphan cleanup against the whole framework.

### Operational Excellence — 6 + 6 rules against 11 items

| Item | Scout | Verdict |
|---|---|---|
| OE:01 DevOps culture / standard practices | — | None |
| OE:02 Formalize operational tasks | `WAF-OE-05` runbooks (manual) | Partial |
| OE:03 Formalize development practices | — | None |
| OE:04 Tools and processes | — | None |
| OE:05 Infrastructure as code | `WAF-OE-02/08`, `CAF-AUT-01/04` | **Solid** |
| OE:06 Workload supply chain | `CAF-AUT-03/06` (both manual) | Partial |
| OE:07 Observability | `WAF-OE-01`, `CAF-MGT-01/05/06` | **Solid** |
| OE:08 Incident response | `WAF-OE-06` alert rules (manual) | Partial |
| OE:09 Testing | — | None |
| OE:10 Automation | `WAF-OE-07` (manual) | Partial |
| OE:11 Safe deployment practices | — | None |

**Coverage: 2 solid, 4 partial, 5 none ≈ 20–30%.**

`WAF-OE-06` (alert rules) is manual with the note *"collect.json does not yet collect an alert-rule inventory"*, and `WAF-OE-07` says *"No automation-account collector exists yet"*. Both are collector gaps, not rule-design gaps — Azure Monitor alert rules and Automation Accounts are both trivially available via ARG. These are the two easiest manual→automated conversions in the repo.

**Numbering warning:** `waf.operational.yaml` uses `WAF-OE-01, 02, 05, 06, 07, 08`. Microsoft consolidated OpEx from 12 items to 11 in 2026 (old OE:07 observability and OE:08 instrument-application merged into a single OE:07; everything below renumbered). If these IDs were ever intended to track checklist codes, they now track the **pre-2026** numbering. See [Rule identity is inconsistent](#rule-identity-is-inconsistent).

### Performance Efficiency — weakest pillar

| Item | Scout | Verdict |
|---|---|---|
| PE:01 Performance targets | — | None |
| PE:02 Capacity planning | `WAF-PE-01/06` subnet IP headroom | Partial (network only) |
| PE:03 Select the right services | — | None |
| PE:04 Performance measurement | — | None |
| PE:05 Scaling and partitioning | `WAF-PE-04` autoscale (manual) | Partial |
| PE:06 Performance testing | — | None |
| PE:07 Optimize code and infrastructure | `WAF-PE-02/07` Advisor | Partial |
| PE:08 Optimize data performance | — | None |
| PE:09 Prioritize critical flows | — | None |
| PE:10 Optimize operational tasks | — | None |
| PE:11 Respond to live performance issues | — | None |
| PE:12 Continuous performance optimization | `WAF-PE-05` CDN/caching (manual) | Partial |

**Coverage: 0 solid, 4 partial, 8 none ≈ 10%.**

Four of six rules are about subnet IP exhaustion or Advisor pass-through. There is no check on VM SKU generation currency, disk tier vs workload, SQL service tier, App Service plan tier, or accelerated networking — all directly observable and all squarely PE:03/PE:07.

### WAF totals

| Pillar | Items | Solid | Partial | None | Rough coverage |
|---|---|---|---|---|---|
| Reliability | 10 | 1 | 2 | 7 | ~20% |
| Security | 12 | 5 | 4 | 3 | ~55% |
| Cost Optimization | 14 | 1 | 5 | 8 | ~20% |
| Operational Excellence | 11 | 2 | 4 | 5 | ~25% |
| Performance Efficiency | 12 | 0 | 4 | 8 | ~10% |
| **Total** | **59** | **9** | **19** | **31** | **~15% solid / ~47% touched** |

---

## CAF coverage matrix

Official source: the 8 Azure landing zone design areas, confirmed still 8 in 2026, now grouped as **environment** (billing/tenant, IAM, resource org, network) and **compliance** (security, management, governance, platform automation). ~394 design recommendations across ~43 pages.

| # | Design area | Official recs | Scout rules | Coverage | Headline gaps |
|---|---|---|---|---|---|
| 1 | **Azure billing & Entra tenant** | 42 | `caf.billing.yaml` — 7 | **~5%** | See below — this file is **misnamed** |
| 2 | **Identity & access management** | 69 | `caf.identity.yaml` — 7 | **~10%** | break-glass accounts, workload identity federation, managed identity usage, admin units, entitlement management, Defender for Identity, ABAC conditions, Global Admin count ≤5, per-landing-zone groups |
| 3 | **Resource organization** | 35 | `caf.resourceorg.yaml` — 6 (+`CAF-GOV-06`) | **~17%** | MG RBAC authorization enabled, default MG for new subscriptions, 3–4 level depth cap, dedicated platform subscriptions (mgmt/security/connectivity/identity), Service Health enabled per subscription, tenant transfer set to `Permit no one`, the five CAF tag categories, Sandbox/Decommissioned MGs, **new default Security and Local MGs** |
| 4 | **Network topology & connectivity** | 141 | `caf.network.yaml` — 7 | **~5%** | the largest area, the thinnest coverage — see below |
| 5 | **Security** | ~100 (45 hub + 19 Zero Trust + 12 encryption + …) | `caf.security.yaml` — 7 | **~10%** | KV RBAC data plane vs access policies, vault firewall, key/cert rotation, per-env vault separation, CMK-vs-MMK default, activity log export + retention, Azure Attestation, the 6 default ALZ policies, Zero Trust's 7 pillars |
| 6 | **Management** | 46 (22 recs + 5 BCDR) | `caf.management.yaml` — 6 | **~13%** | single-LAW design, immutable WORM export beyond 7 years, locks on shared services, Traffic Analytics, service/resource health alerts, **the entire BCDR child page** (ASR replication, drills, PaaS-native DR, no overlapping prod/DR IP ranges, Key Vault DR), Automanage machine-config drift, Service Groups, Azure Monitor health models |
| 7 | **Governance** | 42 (10 recs + 32 cons) | `caf.governance.yaml` — 7 | **~17%** | **policy compliance state (collected, unused)**, regulatory compliance initiatives (HIPAA/PCI-DSS/SOC 2), definitions at root MG, root-MG assignment limits, append-mode required tags, resource-provider registration control, Hybrid Benefit, reservations, savings plans, allowed region/SKU policies, Spot VMs |
| 8 | **Platform automation & DevOps** | ~80 across 8 children | `caf.platformauto.yaml` — 6 | **~8%** | policy exemption process, **`deny` preferred over `modify`**, OIDC/workload identity federation vs client secrets (partly observable via Entra app credentials), per-environment deploy identities, service-connection scoping, 4-eyes / branch policies |

**CAF total: 53 rules against ~394 recommendations ≈ 10%.**

### Area 1 is misnamed, and that hides the gap

`caf.billing.yaml` contains cost-optimization rules — budgets, orphaned disks, orphaned public IPs, Advisor cost items, RI/savings-plan review, cost anomalies. **None of that is the CAF "Azure billing and Microsoft Entra tenant" design area**, which is about EA/MCA/CSP enrollment structure, department and account hierarchy, notification contacts, subscription vending, `DA View Charges` / `AO View Charges`, MFA on subscription creators, custom domains, SSO topology, break-glass accounts, and tenant-count discipline.

Scout's Area 1 coverage is effectively **`CAF-BIL-01` (budgets exist), and nothing else** — roughly 1 of 42 recommendations. The file's name makes the area look covered on the registry's `Frameworks` list when it is not. It also means the six `WAF-CO-*` rules and the seven `CAF-BIL-*` rules are the same subject matter filed under two different frameworks, with two literal duplicates between them.

### Area 4 is the biggest single gap

141 recommendations, 7 rules. The uncovered list includes items that are both high-consequence and cheaply checkable from ARG:

- **NAT Gateway for outbound** — CAF says never rely on Azure default outbound access (which retires).
- **Non-AZ VPN gateway SKUs (VpnGw1–5) retire 30 September 2026.** Scout checks `CAF-NET-05` active-active but not zone-redundant SKU. This is a dated migration deadline inside the audit window.
- **NSG flow logs retire 30 September 2027**, no new ones after 30 June 2025 — migration to VNet flow logs is unchecked.
- Azure Firewall **Management NIC** enabled and a ≥`/26` `AzureFirewallManagementSubnet`; Firewall Premium for TLS inspection/IDPS.
- **No public IPs on VM management ports; Bastion for remote access** — CAF calls this out explicitly and it is the classic ALZ review finding.
- NSG on **every** subnet; ASGs for multitier workloads.
- WAF policy on Front Door / Application Gateway; Application Gateway in the spoke, not the hub.
- Reserved/invalid IP ranges (`224.0.0.0/4`, `127.0.0.0/8`, `169.254.0.0/16`, `168.63.129.16/32`); oversized `/16` VNets; IPv6 subnets must be exactly `/64`.
- DNS Private Resolver with two dedicated ≥`/28` subnets; `privatelink.*` zones in the connectivity subscription.
- Dual ExpressRoute circuits from **different peering locations**.

`CAF-NET-03` (subnet IP utilization) is duplicated as `WAF-PE-01`/`WAF-PE-06` — three rules on subnet headroom, against zero rules on any of the above.

### What CAF changed that Scout doesn't reflect

- **Two new default management groups**: `Security` (under Platform, for Sentinel/SIEM tooling) and `Local` (Azure Local clusters). `CAF-GOV-06`'s manual remediation text describes the **old** archetype — "Platform (Management/Identity/Connectivity) … Landing Zones (Corp/Online) and Sandbox" — with no Security, no Local, no Decommissioned.
- **The five CAF governance disciplines are retired.** Cost Management, Security Baseline, Identity Baseline, Resource Consistency, and Deployment Acceleration now all 301-redirect to `govern/enforce-cloud-governance-policies`. The current Govern methodology is five steps (build team → assess risks → document policies → enforce policies → monitor compliance) with a seven-category taxonomy: **RC** regulatory compliance, **SC** security, **CM** cost management, **OP** operations, **DG** data, **RM** resource management, **AI** AI. Any Scout documentation or roadmap still using discipline vocabulary is against a dead model.
- **Sovereignty moved out of CAF** to a separate `/azure/azure-sovereign-clouds/` docset; "Microsoft Cloud for Sovereignty" is now "Microsoft Sovereign Cloud".
- **AI does not need its own landing zone** — CAF's FAQ says so explicitly. Any future rule flagging a missing AI landing zone would score against guidance that says the opposite.
- **Microsoft's own Azure Landing Zone Review** (34 questions) weights the areas very unevenly: Network 11, Identity 7, Platform automation 4, Billing 3, Resource org 3, Governance 3, Management 2, Security 2. Scout's registry weights every rule file at `weight: 1.0`. Worth a deliberate decision rather than a default.

---

## Rule quality assessment

101 of 148 rules are automated; 47 are `manual: true`. Assert types:

| Assert | Count | Comment |
|---|---|---|
| `countEquals` | 57 | Usually `value: 0` — "no resources violate X". Sound pattern. |
| `manual` | 47 | No verdict produced. |
| `exists` | 16 | **The problem class** — see below. |
| `countGreaterThan` | 14 | Mostly `value: 0`, same weakness as `exists`. |
| `percentageAtLeast` | 11 | **The best pattern in the repo.** |
| `countLessThan` | 2 | |
| `notExists` | 1 | |

### The good

`percentageAtLeast` rules are genuinely meaningful and are what the rest of the corpus should look like:

```yaml
- id: WAF-OE-08
  query: "$.management.deployments[?(@.properties.templateHash)]"
  assert: { type: percentageAtLeast, value: 70, denominatorQuery: "$.management.deployments[*]" }
```

That measures a *ratio* against a denominator, so it can't be satisfied by a single token resource. `CAF-MGT-04` (backup coverage across the VM estate), `CAF-RES-06` (environment tag coverage), and `CAF-IDN-05` (share of privileged assignments that are PIM-eligible) are all in this class and all defensible.

`WAF-RE-05` is a good example of a rule that has been thought about — it scopes to `zoneEligible == true` so SKUs and regions without zone support don't generate false negatives, with a comment explaining why. `caf.storage.yaml`'s TLS/HTTPS/public-access rules and `caf.containers.yaml`'s eight AKS/ACR rules are straightforward, correct, and check the right properties.

The manual rules are also, mostly, *honestly* manual. Several state exactly which collector field is missing and give the `az` command to check by hand — e.g. `WAF-STO-04`: *"collect.json does not yet capture deleteRetentionPolicy.days — verify via `az storage account blob-service-properties show`"*. That is good practice and makes the backlog self-documenting.

### The shallow

**16 `exists` rules pass on a single matching resource anywhere in the tenant.** The worst offenders:

| Rule | Query | Why it's weak |
|---|---|---|
| `CAF-GOV-03` "Resource locks **protect critical scopes**" | `$.governance.resourceLocks[*]` | One lock on one dev resource group passes. Nothing checks *which* scopes are locked. |
| `CAF-SEC-03` "Private endpoints used for PaaS data services" | `$.networking.privateEndpoints[*]` | One private endpoint anywhere passes. Should be a ratio over PaaS data services. |
| `CAF-SEC-06` "Private DNS zones support private endpoint name resolution" | `$.networking.privateDnsZones[*]` | Any private DNS zone passes — doesn't check for `privatelink.*` zones, or that they match the private endpoints in use. |
| `CAF-HYB-02` "Arc footprint is present" | `$.domains.hybrid.arcServers[*]` | One Arc server passes. |
| `CAF-IDN-02` "PIM eligibility in use" | `$.governance.pimEligibility[*]` | One eligible assignment passes. Mitigated by `CAF-IDN-05`, which does the ratio properly — so the shallow version adds noise, not signal. |
| `CAF-RES-03` "Consistent tag values per key across subscriptions" | `$.tags[*]` | Asserts tags exist. Does not check consistency at all. **The title claims something the query cannot test.** |
| `CAF-SEC-02` "Defender for Cloud enabled" | `$.security.defenderPlans[?(@.properties.pricingTier == 'Standard')]` | One Standard plan on one subscription passes for the whole tenant. |

### The wrong

Two rules are semantically incorrect, not merely shallow:

**`CAF-GOV-05` — "DeployIfNotExists / Modify assignments enforce configuration drift correction"**

```yaml
query: "$.governance.policyAssignments[?(@.properties.parameters)]"
assert: { type: exists }
```

The query selects assignments that have a **`parameters` block**. Having parameters has nothing to do with having a `DeployIfNotExists` or `Modify` effect — most parameterised assignments are `Audit` or `Deny`. This rule will pass in essentially every tenant with any parameterised policy assignment, and will report drift-correction enforcement that does not exist. **This is a false-pass on a high-value control.**

**`CAF-AUT-02` — "Policy-as-code / DINE assignments deploy configuration"** uses the *identical* query and has the *identical* flaw.

Both need to inspect the policy **definition's** effect, or the assignment's effect override — not the presence of a parameters bag.

**`WAF-RE-09`** (covered above) — asserts backup exists and is titled/scored as the disaster recovery checklist item.

### Rule identity is inconsistent

The ID schemes don't agree with each other, which will make any future checklist mapping painful:

- `waf.reliability.yaml` uses `WAF-RE-05, 09, 03` — non-sequential, clearly intended as **WAF checklist codes** RE:05/RE:09/RE:03.
- `waf.performance.yaml` uses `PE-01, 02, 04, 05, 06, 07` — skips 03, so also apparently checklist codes, but `WAF-PE-01` maps to capacity/IP headroom which is PE:02, not PE:01.
- `waf.operational.yaml` uses `OE-01, 02, 05, 06, 07, 08` — skips 03 and 04, against the **pre-2026** 12-item numbering.
- `waf.security.yaml` uses `SE-01…07` sequentially — these are **not** checklist codes (`WAF-SE-07` "secrets in Key Vault" is SE:09; `WAF-SE-06` "threat detection" is SE:10).
- `waf.cost.yaml` uses `CO-01…06` sequentially — also not checklist codes.

So the corpus is half-mapped to Microsoft's codes and half not, with no field recording which. There is no `control:` or `checklistItem:` key in the schema — the mapping is *implied by the ID*, inconsistently. **Any coverage reporting Scout wants to produce against WAF requires an explicit mapping field.**

### Duplication

Rules duplicated across files, each counted separately in a `LandingZone` run:

| Subject | Rules |
|---|---|
| Orphaned managed disks | `WAF-CO-01`, `CAF-BIL-02` |
| Orphaned public IPs | `WAF-CO-04`, `CAF-BIL-03` |
| RI / Savings Plan coverage | `WAF-CO-05`, `CAF-BIL-06` |
| Diagnostic settings coverage ≥80% | `WAF-OE-01`, `CAF-MGT-01` (identical query and assert) |
| IaC deployments present | `WAF-OE-02`, `CAF-AUT-01` (identical) |
| IaC deployment ratio ≥70% | `WAF-OE-08`, `CAF-AUT-04` |
| Policy `parameters` heuristic | `CAF-GOV-05`, `CAF-AUT-02` (identical, both wrong) |
| Backup items present | `WAF-RE-09`, `CAF-MGT-02` |
| Subnet IP headroom | `CAF-NET-03`, `WAF-PE-01`, `WAF-PE-06` |

That is ~17 rules of overlap — **11% of the corpus** — which inflates the headline count and skews `LandingZone` scoring toward whatever happens to be double-filed.

---

## The `waf.storage.yaml` anomaly

**Storage is not a WAF pillar. There are exactly five, and there never has been a sixth.**

But the file is not arbitrary — it maps onto a real Microsoft concept that Scout has mislabelled. Microsoft publishes **service guides** (`/azure/well-architected/service-guides/<service>`) grouped into service *categories*, and one of those categories is literally **Storage** (Azure Blob Storage, Azure Files, Azure NetApp Files, Disk Storage). Critically, **each service guide is itself organised by the five pillars**. So "Storage" in Microsoft's taxonomy is a *service axis*, orthogonal to the pillar axis — not a peer of Reliability.

`waf.storage.yaml` declares `area: "Storage reliability"`, which shows the intent was right. Its five rules are: redundancy SKU (RE:05), Advisor reliability items (RE:10-ish), lifecycle policy (CO:10), soft-delete retention (RE:09), and failover readiness (RE:09). They are **Reliability and Cost items scoped to storage**, and four of the five are `manual: true`.

**Recommendation:** fold the contents into the pillar files with a service tag rather than keeping a pseudo-pillar.

- `WAF-STO-01` (redundancy SKU) → `waf.reliability.yaml` as an RE:05 rule. This alone takes Reliability from 3 rules to 4 and gives RE:05 storage coverage inside the pillar that scores it.
- `WAF-STO-04` (soft-delete retention) and `WAF-STO-05` (GRS/GZRS failover readiness) → `waf.reliability.yaml` under RE:09, where they materially improve the DR story that `WAF-RE-09` currently fakes.
- `WAF-STO-03` (lifecycle policy) → `waf.cost.yaml` under CO:10.
- `WAF-STO-02` (Advisor reliability on storage) → merge into a general Advisor-reliability rule in `waf.reliability.yaml`; it is redundant with the Advisor pattern used in every other pillar.
- Delete `waf.storage.yaml`; update the `Storage` assessment in `manifests/assessments.psd1:88` from `Rules = @('caf.storage', 'waf.storage')` to `@('caf.storage', 'waf.reliability', 'waf.cost')` — or, better, introduce a service-scoping mechanism (below).

**Note this is not a cosmetic fix.** As long as `waf.storage` exists, the `LandingZone` roll-up's `Rules = @('caf.*', 'waf.*')` glob pulls in a sixth "pillar" and reports six WAF areas to the customer. Any per-pillar scoring or radar chart Scout renders is structurally wrong.

The same conflation exists on the CAF side: of the 17 `caf.*` files, **8 are genuine CAF design areas** (billing, identity, resourceorg, network, security, management, governance, platformauto) and **9 are service domains** (ai, analytics, containers, databases, hybrid, integration, iot, storage, web). The nine service-domain files contain overwhelmingly *security-hardening* rules — public network access, TLS, managed identity, private endpoints — which belong to CAF's Security design area and WAF's SE:06/SE:07/SE:08. Filing them as if they were CAF areas means **CAF area coverage looks like 17 areas when there are 8**, and the Security area looks like it has 7 rules when it really has ~60 spread across ten files.

---

## Recommendations

### Recommendation 1: restructure the rule namespace around the two real axes

The single highest-leverage change. Today one flat `framework.domain` namespace encodes three different things (CAF design areas, WAF pillars, service domains), which is why Reliability appears to have 3 rules while zone-redundancy evidence for six other services sits in files Reliability never reads.

Give every rule two explicit mapping fields alongside its existing home:

```yaml
- id: CAF-DB-02
  title: "Production SQL databases are zone-redundant"
  service: databases          # service axis
  caf: [security]             # CAF design area(s)
  waf: [RE:05]                # WAF checklist code(s)
```

Then a "Reliability" run selects on `waf: RE:*` regardless of which file the rule lives in, and a "Databases" run selects on `service: databases`. This is what makes honest per-pillar and per-area coverage reporting possible — and it is a precondition for every other recommendation here.

It also fixes duplication cleanly: `WAF-CO-01` and `CAF-BIL-02` become one rule tagged `caf: [governance]`, `waf: [CO:07]`.

### Recommendation 2: fix the wizard, then the two false-pass rules

Ordered by ratio of harm to effort:

1. The wizard path (one line, plus a test) — 21 assessments are invisible today.
2. `CAF-GOV-05` and `CAF-AUT-02` — currently report drift-correction enforcement that doesn't exist. A false pass is worse than no rule.
3. `WAF-RE-09` — retitle to what it checks ("Backup configured") and add real DR rules for RE:09.
4. `CAF-RES-03` — the title promises tag-value consistency; the query checks tags exist. Either implement the consistency check or retitle.

### Recommendation 3: score the policy compliance data already being collected

Scout already pulls `PolicyComplianceStates`, `nonCompliantResources`, `nonCompliantPolicies`, and the `policyStates/latest/summarize` API — and no rule reads any of it. Adding compliance-state rules to `caf.governance.yaml` requires **no new collector work** and would take Governance from "policy assignments exist" to actual governance measurement. Highest value-per-hour item in this audit after the wizard.

The same applies, at slightly higher cost, to two collector gaps whose absence is already documented in rule comments: **Azure Monitor alert rules** (`WAF-OE-06`) and **Automation Accounts** (`WAF-OE-07`). Both are single ARG queries and both convert a manual rule to automated.

### Recommendation 4: new assessments

**Per WAF pillar (5 new).** `Reliability`, `Security`, `CostOptimization`, `OperationalExcellence`, `PerformanceEfficiency`. This is what customers ask for by name, it matches Microsoft's own Well-Architected Review, and it is what makes a pillar radar chart meaningful. Today there is no way to run "assess my Reliability" — the closest is `Compute`, which bundles reliability, cost, and performance for VMs only. Depends on Recommendation 1.

**Per CAF design area (8 new).** `Billing` (properly scoped to enrollment/tenant, not cost), `IdentityAccess`, `ResourceOrganization`, `NetworkTopology`, `SecurityBaseline`, `ManagementBaseline`, `Governance` (exists but should be promoted from sub-bundle to full area), `PlatformAutomation`. Aligns Scout's output with Microsoft's Azure Landing Zone Review, so a customer can compare Scout's result to the official 34-question assessment.

**Compliance frameworks (new class).** Worth doing, and Scout is closer than it looks — Defender for Cloud's regulatory compliance API exposes assessment results for **MCSB (Microsoft Cloud Security Benchmark)**, CIS Azure Foundations, NIST SP 800-53, PCI-DSS, ISO 27001, and SOC 2 as first-party data. That means a compliance assessment is largely an *ingest-and-map* job rather than 200 hand-written rules.

Priority order: **MCSB first** (it is the Azure-native baseline, it is what Defender scores against by default, and it maps cleanly onto WAF SE:01), then **CIS Azure Foundations** (most requested in practice), then NIST/ISO/PCI as ingest targets. Recommend a `Compliance` assessment with a `-Framework` selector rather than five separate registry entries.

**Anti-recommendation:** do not build a separate "AI landing zone" assessment. CAF explicitly states no separate AI landing zone is needed. Extend `caf.ai.yaml` within the existing areas instead.

### Recommendation 5: track framework currency

CAF and WAF both moved materially in 2025–2026 and Scout is scoring against a stale snapshot in at least four places (OpEx 12→11 items, the two new default MGs, the retired governance disciplines, sovereignty leaving CAF). There is no mechanism to notice this. A dated `frameworkVersion:` header per rule file, plus a periodic review task, would at least make staleness visible.

Two dated deadlines fall inside the next audit window and should become rules now: **non-AZ VPN gateway SKUs (VpnGw1–5) retire 30 September 2026**, and **NSG flow logs retire 30 September 2027** (no new ones since 30 June 2025).

---

## Proposed work breakdown under AB#6447

Sized S/M/L. The first three are independent of the restructure and can start immediately.

### Phase 0 — defects (do first)

| # | Item | Size |
|---|---|---|
| 0.1 | **Fix `Start-AZSCWizard.ps1:238` manifest path**; replace silent `Test-Path` fallback with a visible warning; add Pester coverage asserting all 22 assessments are offered | S |
| 0.2 | Fix `CAF-GOV-05` and `CAF-AUT-02` — inspect policy effect, not the presence of a `parameters` block | S |
| 0.3 | Retitle `WAF-RE-09` to "Backup configured"; fix `CAF-RES-03` title-vs-query mismatch | S |
| 0.4 | Decide and document the wizard's `-DefaultSelected` behaviour now that the full list is reachable | S |

### Phase 1 — free wins from existing data

| # | Item | Size |
|---|---|---|
| 1.1 | Add Azure Policy **compliance-state** rules to `caf.governance.yaml` using already-collected `PolicyComplianceStates` / `nonCompliantResources` | M |
| 1.2 | Add an Azure Monitor **alert-rule** collector; convert `WAF-OE-06` from manual to automated | M |
| 1.3 | Add an **Automation Account** collector; convert `WAF-OE-07` from manual to automated | S |
| 1.4 | Automate `WAF-CO-05` / `CAF-BIL-06` reservation and savings-plan coverage from Cost Management data | M |

### Phase 2 — structural

| # | Item | Size |
|---|---|---|
| 2.1 | Add `service:`, `caf:`, `waf:` mapping fields to the rule schema; backfill all 148 rules; update the rule interpreter and registry to select on them | L |
| 2.2 | **Retire `waf.storage.yaml`** — redistribute its 5 rules to `waf.reliability` and `waf.cost`; update the `Storage` assessment's `Rules` | S |
| 2.3 | De-duplicate the ~17 overlapping rules identified above | M |
| 2.4 | Rename/rescope `caf.billing.yaml` — move its cost rules to the WAF Cost pillar, and create genuine CAF Area 1 (enrollment/tenant) rules | M |
| 2.5 | Reclassify the 9 service-domain `caf.*` files so CAF area coverage reports 8 areas, not 17 | M |

### Phase 3 — coverage depth (largest body of work; per-area/per-pillar child tasks)

| # | Item | Size |
|---|---|---|
| 3.1 | **Reliability** — RE:04, RE:06, RE:07, RE:10; real DR rules (ASR replication, region pairing, no overlapping prod/DR IP ranges, Key Vault DR) | L |
| 3.2 | **Performance Efficiency** — PE:03/PE:07 service-tier and SKU-currency rules (VM generation, disk tier, SQL tier, App Service plan, accelerated networking) | M |
| 3.3 | **Network topology** — the highest-count gap: NAT Gateway/default outbound, Firewall Management NIC + Premium, Bastion + no public management ports, NSG-per-subnet, WAF policies, reserved/oversized IP ranges, DNS Private Resolver, dual-ER peering locations, **VpnGw non-AZ SKU retirement**, **NSG flow log migration** | L |
| 3.4 | **Security / Key Vault depth** — RBAC data plane vs access policies, vault firewall, key/cert rotation, per-env separation, CMK-vs-MMK, activity log export + retention, the 6 default ALZ policies | M |
| 3.5 | **Management** — single-LAW design, WORM export beyond 7 years, service/resource health alerts, Automanage machine-config drift, locks on shared services | M |
| 3.6 | **Resource organization** — MG RBAC authorization, default MG for new subscriptions, depth cap, dedicated platform subscriptions, Service Health per subscription, tenant transfer `Permit no one`, the five CAF tag categories | M |
| 3.7 | **Cost** — Hybrid Benefit, allowed region/SKU policies, Spot adoption, dev/test offer, storage lifecycle | M |
| 3.8 | **Identity** — break-glass accounts, Global Admin count, workload identity federation vs client secrets, admin units, entitlement management, ABAC conditions | M |
| 3.9 | Add `manual: true` placeholder rules for legitimately unassessable checklist items (SE:02, SE:11, SE:12, OE:01, OE:03, OE:09, RE:01, RE:02, RE:08, CO:01, CO:02, PE:01, PE:06) so the report shows them as **unassessed** rather than invisible | S |

### Phase 4 — new assessments

| # | Item | Size |
|---|---|---|
| 4.1 | 5 per-WAF-pillar assessments (depends on 2.1) | M |
| 4.2 | 8 per-CAF-design-area assessments (depends on 2.1, 2.4, 2.5) | M |
| 4.3 | `Compliance` assessment with `-Framework` selector; ingest Defender for Cloud regulatory compliance results — **MCSB first**, then CIS Azure Foundations | L |
| 4.4 | NIST SP 800-53 / ISO 27001 / PCI-DSS as additional ingest targets under 4.3 | M |

### Phase 5 — currency

| # | Item | Size |
|---|---|---|
| 5.1 | Add `frameworkVersion:` headers; refresh `CAF-GOV-06` for the new Security and Local management groups; purge retired governance-discipline vocabulary from rules and docs | S |
| 5.2 | Establish a periodic CAF/WAF currency review against Microsoft Learn "what's new" | S |

---

## Appendix — rule inventory

| File | Area declared | Rules | Manual |
|---|---|---|---|
| `caf.ai.yaml` | AI | 5 | 1 |
| `caf.analytics.yaml` | Analytics | 5 | 2 |
| `caf.billing.yaml` | Billing (**misnamed — is cost**) | 7 | 2 |
| `caf.containers.yaml` | Containers | 8 | 1 |
| `caf.databases.yaml` | Databases | 7 | 4 |
| `caf.governance.yaml` | Governance (policy & compliance) | 7 | 2 |
| `caf.hybrid.yaml` | Hybrid | 6 | 2 |
| `caf.identity.yaml` | Identity | 7 | 3 |
| `caf.integration.yaml` | Integration | 6 | 0 |
| `caf.iot.yaml` | IoT | 13 | 5 |
| `caf.management.yaml` | Management | 6 | 1 |
| `caf.network.yaml` | Network | 7 | 1 |
| `caf.platformauto.yaml` | Platform automation | 6 | 3 |
| `caf.resourceorg.yaml` | Resource organization | 6 | 2 |
| `caf.security.yaml` | Security | 7 | 1 |
| `caf.storage.yaml` | Storage | 6 | 2 |
| `caf.web.yaml` | Web | 6 | 2 |
| `waf.cost.yaml` | Cost optimization | 6 | 1 |
| `waf.operational.yaml` | Operational excellence | 6 | 3 |
| `waf.performance.yaml` | Performance efficiency | 6 | 2 |
| `waf.reliability.yaml` | Reliability | 3 | 1 |
| `waf.security.yaml` | Security | 7 | 2 |
| `waf.storage.yaml` | Storage reliability (**not a pillar**) | 5 | 4 |
| **Total** | | **148** | **47 (32%)** |

### Sources

- [WAF pillars](https://learn.microsoft.com/en-us/azure/well-architected/pillars) · per-pillar checklists: [Reliability](https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist) · [Security](https://learn.microsoft.com/en-us/azure/well-architected/security/checklist) · [Cost Optimization](https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist) · [Operational Excellence](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist) · [Performance Efficiency](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist)
- [WAF service guides](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/) · [What's new in WAF](https://learn.microsoft.com/en-us/azure/well-architected/whats-new)
- [Azure landing zone design areas](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas) · [Tailor the ALZ architecture](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/tailoring-alz) · [ALZ FAQ](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/faq) · [What's new in CAF](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/whats-new)
- CAF Govern methodology: [Build a cloud governance team](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/build-cloud-governance-team) · [Enforce cloud governance policies](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/enforce-cloud-governance-policies)
- [Azure Landing Zone Review assessment](https://learn.microsoft.com/en-us/assessments/21765fea-dfe6-4bc4-8bb7-db9df5a6f6c0/) · [Cloud Governance assessment](https://learn.microsoft.com/en-us/assessments/b1891add-7646-4d60-a875-32a4ab26327e)
