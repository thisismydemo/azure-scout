# FinOps Review — enumerated source for the FinOps Review assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

**Framework version:** Not versioned by Microsoft — the FinOps Review assessment carries no release
number. The extraction date above (2026-08-01) is the version, per `docs/frameworks/README.md`;
re-date this line when this file is next re-verified.

This is the AB#6814 enumeration for target #9 in the audit's fourteen-assessment programme
(`pmo/audits/AZURE-SCOUT-AUDIT.md` §14): *"FinOps Review — Cost surface exists … `waf.cost` (6
rules) + `caf.billing` (misnamed, holds cost rules)."* Neither existing file scores against the
FinOps Framework itself — they score WAF's Cost Optimization pillar and (mislabelled) cost-cleanup
rules respectively. Per DQ12, no FinOps-Framework-shaped rule file is written until this enumeration
exists.

## What the FinOps Review is

The **FinOps Review** is an interactive assessment on the Microsoft Assessments platform
(<https://learn.microsoft.com/en-us/assessments/ad1c0f6b-396b-44a4-924b-7a4c778a13d3>, also seen
published at assessment ID `60c02533-b280-4dec-ac5f-3f10cdd238b9` in a second Learn citation — both
resolve to the same "Complete the Microsoft FinOps Review" call to action), ~35 minutes,
multiple-choice/multiple-response, described as *"a lightweight, self-guided assessment"* to
*"identify capability gaps."*

Its subject is the **FinOps Framework**, published in full by Microsoft
(<https://learn.microsoft.com/cloud-computing/finops/framework/finops-framework>), attributed to the
FinOps Foundation. The framework organises **22 capabilities** into 4 domains — 3 operational
domains (Understand usage and cost, Quantify business value, Optimize usage and cost) plus one
practice-management domain (Manage the FinOps practice). This enumeration is built from that
published capability list.

## Verification method — and the one thing this enumeration is NOT

**What was read (2026-08-01):**

| Source | What it gave |
|---|---|
| The FinOps Review assessment landing page | Confirms the assessment exists, its duration/format, and that it is self-guided against the FinOps Framework. **No question text.** |
| [FinOps capabilities](https://learn.microsoft.com/cloud-computing/finops/framework/capabilities) | The full 22-capability, 4-domain structure enumerated below |
| [Optimize usage and cost](https://learn.microsoft.com/cloud-computing/finops/framework/optimize/optimize-cloud-usage-cost) | Per-capability definitions for the Optimize domain |
| [Quantify business value](https://learn.microsoft.com/cloud-computing/finops/framework/quantify/quantify-business-value) | Per-capability definitions for the Quantify domain |
| `src/collect/Get-ScoutCostInventory.ps1`, `src/analyze/Get-ScoutCostAnomaly.ps1` | Ground truth for what cost data Scout actually collects and computes, versus what is merely available as an unused function — read directly, not inferred from the audit |

**⚠️ The assessment's own question TEXT and NUMBERS are not published.** The `FINOPS-*` identifiers
below are **Scout's own**, built from the FinOps Framework's published capability names — Microsoft
attributes the framework itself to the FinOps Foundation, not to the assessment.

**Shelf life.** The FinOps Framework and FinOps toolkit ship monthly releases (see the toolkit's own
roadmap page); re-verify before quoting.

## The enumeration

### Understand usage and cost

| # | Item | Scout can evidence? |
|---|---|---|
| FINOPS-U01 | Cost and usage data is ingested from the cloud provider (and ideally other sources) into a single accessible repository | ⚠️ Partial — `src/collect/Get-ScoutCostInventory.ps1` (per-subscription cost grouped by type/resource group/location/service) exists but is **opt-in**: it requires `Az.CostManagement`, a module deliberately excluded from Scout's auto-installed dependencies (a second `Az.Accounts` version crashes module import — see the repo's `Az.Accounts 5.5.1` trap). No non-Azure source is ever ingested. |
| FINOPS-U02 | Cost is allocated meaningfully — broken down by tag, resource group, or business unit | ⚠️ Partial — cost is grouped by resource group/location/service/type per subscription; that grouping is not joined to `$.tags[*]`, so tag-based allocation is not currently possible from the same dataset |
| FINOPS-U03 | Cost and usage data is reported on and made visible to stakeholders | ⚠️ Partial — a "Costs" worksheet is produced via `Start-AZTIExtractionOrchestration.ps1`, but that call path is separate from the unified `-Assessment` entry point's `collect.json`, so no rule can currently query it |
| FINOPS-U04 | Anomalies (spikes, unexpected changes) are proactively identified and reacted to | ⚠️ Partial — `src/analyze/Get-ScoutCostAnomaly.ps1` implements three independent detection techniques (spike, z-score, IQR) against `Get-ScoutCostInventory` output, but nothing in `Invoke-Collect.ps1` calls it — the capability is built, not wired in |

### Quantify business value

| # | Item | Scout can evidence? |
|---|---|---|
| FINOPS-Q01 | Cost and usage of new or changing workloads is predicted before deployment | ❌ Not collected — no pre-deployment cost-estimation data source |
| FINOPS-Q02 | Future cost is forecast from historical trends | ✅ `Management/Budgets` ("Forecast Spend" field) |
| FINOPS-Q03 | Budgets are actively monitored and managed, with alerts configured | ✅ `Management/Budgets` ("Amount", "Current Spend", "Budget Used %", "Alerts Configured") |
| FINOPS-Q04 | Cloud efficiency is benchmarked against internal teams or industry peers | ❌ Not collected — no benchmarking dataset |
| FINOPS-Q05 | Unit economics (cost per business unit of value) are calculated | ❌ Not collected — requires business-metric data outside Azure's control plane |

### Optimize usage and cost

| # | Item | Scout can evidence? |
|---|---|---|
| FINOPS-O01 | Cloud solutions are architected for cost efficiency during design/migration, not retrofitted after deployment | ❌ Design-time decision, not observable post-deployment |
| FINOPS-O02 | Workload cost/usage is analyzed to identify efficiency opportunities | ✅ `$.advisor[?(@.Category == 'Cost')]`, `$.costCleanup.orphanedDisks[*]`, `$.costCleanup.orphanedPips[*]` |
| FINOPS-O03 | Rate optimization is pursued — reservations, savings plans, commitment-discount planning | ✅ `General/Reservations`, `General/ReservationRecom` |
| FINOPS-O04 | Software licenses and prepaid SaaS products (including Azure Hybrid Benefit) are tracked and fully utilized | ❌ Not collected — no license/AHB-flag field on any current collector |
| FINOPS-O05 | Carbon emissions are measured alongside cost as part of cloud sustainability | ❌ Not collected — Scout has no Emissions/Carbon API collector |

### Manage the FinOps practice

This domain is almost entirely organisational — it describes running and maturing the FinOps
practice itself, not the resources it manages.

| # | Item | Scout can evidence? |
|---|---|---|
| FINOPS-M01 | A FinOps education and enablement programme exists | ❌ Organisational |
| FINOPS-M02 | FinOps practice operations (cadence, ownership, processes) are defined | ❌ Organisational |
| FINOPS-M03 | Workloads are onboarded to the FinOps practice based on financial/technical feasibility | ❌ Organisational |
| FINOPS-M04 | FinOps-specific policy and governance (cost-allocation tagging, spend guardrails) is enforced | ⚠️ Partial — `$.tags[*]`, `Management/PolicyAssignments` are generic governance signals, not FinOps-specific enforcement |
| FINOPS-M05 | Invoices are reconciled and cross-charged (chargeback/showback) to internal teams | ❌ Not collected — same billing-hierarchy gap `caf.billing.yaml`'s misnaming note documents (EA/MCA enrollment, invoice sections) |
| FINOPS-M06 | The FinOps practice's own maturity is periodically reassessed | ❌ Organisational — this is the meta-capability describing running assessments like this one |
| FINOPS-M07 | FinOps tools and services are selected and integrated to fit organizational needs | ❌ Organisational/tooling choice |
| FINOPS-M08 | FinOps practices are aligned with intersecting frameworks (ITAM, ITSM, security) | ❌ Organisational |

## What this means for the rule file

**4 of 22 items are fully answerable, 6 are partial, 12 are organisational or entirely uncollected.**
The Manage domain (8 capabilities) is close to a hard floor — only tagging/policy gives any
automatable signal at all, and even that is generic governance data repurposed, not FinOps-specific.
The more consequential finding is upstream of any rule file: **`Get-ScoutCostInventory` is gated
behind an opt-in module Scout deliberately does not install**, so `FINOPS-U01` through `FINOPS-U04`
— the entire "Understand usage and cost" domain, which every other Optimize/Quantify capability
ultimately depends on — is only ever partial in an environment where an operator has separately
installed `Az.CostManagement`. Wiring `Get-ScoutCostAnomaly` into the collect pipeline (`FINOPS-U04`)
is cheap once that module is present — the detection logic already exists and is tested — but it is
downstream of that same dependency decision, not an independent piece of work.
