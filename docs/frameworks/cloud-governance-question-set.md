# Cloud Governance — enumerated source for the Cloud Governance assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

**Framework version:** Not versioned by Microsoft — the Cloud Governance assessment and the CAF Govern
documentation it is built from carry no release number. The extraction date above (2026-08-01) is the
version, per `docs/frameworks/README.md`; re-date this line when this file is next re-verified.

This is the AB#6811 enumeration for target #8 in the audit's fourteen-assessment programme
(`pmo/audits/AZURE-SCOUT-AUDIT.md` §14): *"Cloud Governance — policy data already collected …
Policy compliance state is collected and scored by nothing."* The audit's §8 Table 3 identifies this
as the **CAF Govern methodology** — a different axis from the "Governance" *design area* that
`caf.governance.yaml` already scores (that design area is part of Ready, covered in
`pmo/audits/AZURE-SCOUT-AUDIT.md` §8 Table 2, not this document). Per DQ12, no `caf.govern.yaml` (or
similarly named methodology file) is written until this enumeration exists.

## What Cloud Governance is

Microsoft ships **two** distinct things under "governance," and this file is about the second one:

1. `caf.governance.yaml`'s subject — the Ready methodology's **Governance design area**, one of the
   8 landing-zone design areas, already enumerated and scored (10 recommendations, ~70% coverage
   per the audit).
2. **This file's subject** — the **Govern methodology**, one of CAF's seven core methodologies
   (Strategy, Plan, Ready, Adopt, Govern, Secure, Manage — confirmed in `smart-question-set.md`'s
   sibling audit table). Govern is a **five-step continuous process** — build a governance team,
   assess cloud risks, document policies, enforce policies, monitor compliance — applied across
   **seven risk categories**: regulatory compliance, security, cost, operations, data, resource
   management, AI.

There is also an interactive **"Cloud Governance"** assessment on the Microsoft Assessments platform
(<https://learn.microsoft.com/en-us/assessments/b1891add-7646-4d60-a875-32a4ab26327e/>), which is
almost certainly built on the Govern methodology's five steps and seven categories, but — as with
SMART, the AVS assessment, and CASA — its question text and numbers are not published. This
enumeration draws on the fully-published CAF Govern documentation instead.

## Verification method — and the one thing this enumeration is NOT

**What was read (2026-08-01):**

| Source | What it gave |
|---|---|
| The Cloud Governance assessment landing page | Confirms the assessment exists. **No question text.** |
| [What is the Microsoft Cloud Adoption Framework?](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/overview) | The seven-methodology structure and Govern's place in it |
| [Assess cloud risks](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/assess-cloud-risks) | The seven risk categories (RC/SC/CM/OP/DG/RM/AI), already verified in the audit's §8 Table 3 |
| [Document cloud governance policies](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/document-cloud-governance-policies) | The policy-documentation structure (ID, category, risk ID, statement, scope, remediation, monitoring tool) and a worked example table naming a monitoring tool per category |
| [Monitor cloud compliance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/monitor-cloud-governance) | Per-category "Azure facilitation" recommendations — the concrete, tool-named observable signals this enumeration is built from |

**⚠️ The interactive assessment's question TEXT and NUMBERS are not published.** The `CGOV-*`
identifiers below are **Scout's own**, built from the CAF Govern documentation's per-category
Azure-facilitation guidance, not Microsoft's question numbers.

**Shelf life.** CAF Govern is actively maintained content; re-verify before quoting.

## The enumeration

### RC — Regulatory compliance

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-RC-01 | Policy compliance dashboards are used to get compliance data on assigned policies | ✅ `Management/PolicyComplianceStates` |
| CGOV-RC-02 | Causes of noncompliance are determined and root-caused, not just observed | ❌ Compliance state is collected; no root-cause field |

### SC — Security

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-SC-01 | Security recommendations are reviewed and secure score is monitored over time | ⚠️ Partial — `Security/DefenderSecureScore`, `Security/DefenderAssessments` are point-in-time, not a trend |
| CGOV-SC-02 | A regulatory-compliance dashboard is checked against common security frameworks (MCSB, CIS, etc.) | ⚠️ Partial — `Management/PolicyComplianceStates` carries the data; nothing distinguishes which framework initiative each state belongs to (same gap the audit's §8 Table 4 documents) |
| CGOV-SC-03 | Identity governance monitoring is configured — audit/sign-in/provisioning logs, identity secure score, an identity-governance dashboard | ❌ Sign-in/audit logs not collected; `Identity/PIMAssignments` gives a partial standing-vs-eligible signal only |

### CM — Cost management

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-CM-01 | Cost analysis gives full visibility into cloud costs | ⚠️ Partial — `General/Reservations`, `Management/AdvisorScore` give partial visibility; no full cost-analysis dataset |
| CGOV-CM-02 | Budgets are created that align with the desired cloud investment | ✅ `Management/Budgets` |
| CGOV-CM-03 | Cost-optimization recommendations are used to detect idle resources | ✅ `$.advisor[?(@.Category == 'Cost')]`, `$.costCleanup.orphanedDisks`, `$.costCleanup.orphanedPips` |
| CGOV-CM-04 | Cost anomalies and unexpected changes are identified | ⚠️ Partial — `src/analyze/Get-ScoutCostAnomaly.ps1` implements spike/z-score/IQR detection against `src/collect/Get-ScoutCostInventory.ps1` output, but nothing in `Invoke-Collect.ps1` calls it; the function exists and is unused, not absent |

### OP — Operations

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-OP-01 | Policy compliance is tracked for operations-scoped governance policies | ✅ `Management/PolicyComplianceStates` (generic — not operations-specific) |
| CGOV-OP-02 | Logs and metrics are monitored for availability and performance | ⚠️ Partial — `Monitor/Workspaces`, `Monitor/DataCollectionRules` existence only, not coverage or content |
| CGOV-OP-03 | Advisor is used to monitor reliability/security/performance/cost, with alerts set on new recommendations | ⚠️ Partial — `$.advisor[*]` gives the recommendations; whether alerts are configured on *new* ones is not observable |
| CGOV-OP-04 | Resource health is monitored for service-impacting events and planned maintenance | ❌ `Monitor/Outages` exists but the audit's build-list item A5 records it as currently broken (runs before the data it reads is merged) |

### DG — Data

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-DG-01 | Data compliance, management, and usage are monitored (Microsoft Purview) | ❌ Purview is not collected by Scout |
| CGOV-DG-02 | Dashboards monitor compliance with data-plane policies | ❌ Data-plane policy state is not collected |

### RM — Resource management

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-RM-01 | Policies on resource deployments — e.g. tag-enforcement policies — are monitored for compliance | ✅ `Management/PolicyComplianceStates`, `$.tags[*]` |

### AI — Artificial intelligence

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-AI-01 | AI system outputs are monitored — abuse monitoring and content filtering configured | ❌ Not collected — no AI Foundry/content-filter configuration ingest |
| CGOV-AI-02 | Customer-facing AI systems are red-teamed on a recurring cadence | ❌ Organisational/process; no Azure artefact records a red-team cadence |

### PROC — The governance process itself (steps 1–3 of the five-step cycle)

These sit before the two steps (enforce, monitor) that the categories above already draw on. All
five are organisational — Scout reads the *result* of governance being enforced, never the process
that produced the policy.

| # | Item | Scout can evidence? |
|---|---|---|
| CGOV-PROC-01 | A cloud governance team is formally established with a charter and defined membership | ❌ Organisational |
| CGOV-PROC-02 | Governance policies are documented in a standard format (policy ID, category, risk ID, statement, scope, remediation, monitoring tool) | ❌ Organisational — `Management/PolicyDefinitions`/`PolicyAssignments` carry display name and description, but not whether they follow this authoring standard |
| CGOV-PROC-03 | Policies are distributed via a centralized repository, with compliance checklists for teams | ❌ Organisational |
| CGOV-PROC-04 | A compliance baseline was established and is tracked against over time | ❌ Scout collects a single point-in-time snapshot per run; no historical baseline is retained between runs |
| CGOV-PROC-05 | Noncompliance remediation has a defined timeline and escalation path scaled to risk severity | ❌ Organisational |

## What this means for the rule file

**9 of 23 items are fully or partially answerable from data Scout already collects; 14 are
organisational, unobservable, or blocked by a known defect.** The single biggest lever here is the
same one the audit's §10 flags for the whole document: **`Management/PolicyComplianceStates` is
collected and read by nothing.** Four of the nine answerable items (`CGOV-RC-01`, `CGOV-SC-02`,
`CGOV-OP-01`, `CGOV-RM-01`) all resolve to that single dataset. Writing the render/scoring layer for
policy compliance state — already flagged as the cheapest high-value work in §8 Table 4 — closes
nearly half of what this assessment can ever automate. The `CGOV-DG-*` and `CGOV-AI-*` categories
are close to a hard floor: Purview and AI Foundry content-filter configuration are simply not in
Scout's collection scope today, and closing them means adding new collectors, not new rules.
