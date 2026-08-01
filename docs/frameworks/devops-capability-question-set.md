# DevOps Capability — enumerated source for the DevOps Capability Assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

**Framework version:** Not versioned by Microsoft — the DevOps Capability Assessment carries no
release number. The extraction date above (2026-08-01) is the version, per
`docs/frameworks/README.md`; re-date this line when this file is next re-verified.

This is the AB#6815 enumeration for target #10 in the audit's fourteen-assessment programme
(`pmo/audits/AZURE-SCOUT-AUDIT.md` §14): *"DevOps Capability Assessment — 5 DevOps collectors exist
via the ADO REST API … `caf.platformauto` (6 rules, ~8% coverage)."* `caf.platformauto.yaml` scores
the CAF Ready methodology's **Platform automation and DevOps design area** (§8 Table 2 — 30
recommendations, largely CI/CD process guidance ARM telemetry can't observe). This document is
about a **different**, narrower, named assessment; the two overlap in subject matter but are not the
same enumeration. Per the note in this Feature's brief, the five ADO collectors currently sit under
`manifests/collectors/Management/DevOps*.psd1` pending relocation to the `DevOps/` category in a
parallel workstream; they are cited below by collector name, not by their current path.

## What the DevOps Capability Assessment is

An interactive assessment on the Microsoft Assessments platform
(<https://learn.microsoft.com/en-us/assessments/56ec577c-acb6-4c7b-ad13-e224b0846153/>), ~30
minutes, multiple-choice/multiple-response, described as helping organisations *"understand current
capabilities across the entire software release lifecycle … based on the Microsoft DevOps
practices."* It also appears under its older name, **DevOps Capability Assessment**, in Microsoft's
long-running Services Hub On-Demand Assessments catalogue, confirming it predates the Microsoft
Assessments platform migration.

The CAF's own DevOps considerations page names the **Microsoft DevOps Resource Center**
(<https://learn.microsoft.com/en-us/devops/what-is-devops>) as the framework to use when building a
DevOps capability, and cites this exact assessment as the tool to measure current-state against it.
The Resource Center organises DevOps practice into five named phases — Plan, Develop/Continuous
Integration, Continuous Delivery, Operations/Reliability, DevSecOps — and this enumeration is built
from that published structure, cross-checked against the CAF DevOps-considerations page's own
recommendations (metrics, toolchain, framework selection).

## Verification method — and the one thing this enumeration is NOT

**What was read (2026-08-01):**

| Source | What it gave |
|---|---|
| The DevOps Capability Assessment landing page | Confirms the assessment exists, its duration/format, its explicit tie to Microsoft DevOps practices. **No question text.** |
| [What is DevOps?](https://learn.microsoft.com/en-us/devops/what-is-devops) (Microsoft DevOps Resource Center) | The five-phase structure (Plan, Develop, Deliver, Operate, DevSecOps) this enumeration is organised under |
| [DevOps considerations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/devops-principles-and-practices) | The explicit citation of this assessment as the tool for measuring current DevOps state; DORA-style software-delivery-performance metrics (lead time, deployment frequency, MTTR, change-fail %) |
| `manifests/collectors/Management/DevOps*.psd1`, `manifests/collectors/DevOps/ManagedDevOpsPools.psd1` | Ground truth for which ADO/DevOps fields Scout actually collects |

**⚠️ The assessment's own question TEXT and NUMBERS are not published.** The `DEVOPS-*` identifiers
below are **Scout's own**, built from the DevOps Resource Center's published phase structure, not
Microsoft's question numbers.

**Shelf life.** The DevOps Resource Center and CAF DevOps-considerations pages are actively
maintained; re-verify before quoting.

## The enumeration

### Plan

| # | Item | Scout can evidence? |
|---|---|---|
| DEVOPS-PLN-01 | Work is planned and tracked through Azure DevOps (or an equivalent) rather than ad hoc | ✅ `DevOpsProjects` |
| DEVOPS-PLN-02 | Outcome-oriented metrics (OKRs, delivery performance, quality) are defined and tracked | ❌ Organisational — no metric-definition artefact is ARM/ADO-API-visible |

### Develop / Continuous Integration

| # | Item | Scout can evidence? |
|---|---|---|
| DEVOPS-DEV-01 | Source code is held in version-controlled repositories, not ad hoc file shares | ✅ `DevOpsRepositories` |
| DEVOPS-DEV-02 | Continuous integration pipelines build and test on every change | ⚠️ Partial — `DevOpsPipelines` records pipeline existence and configuration type, not trigger-on-commit behaviour or run history |
| DEVOPS-DEV-03 | Pipelines are defined as YAML-as-code rather than authored through the classic UI editor | ✅ `DevOpsPipelines` ("Configuration Type", "YAML Path" fields) |

### Deliver / Continuous Delivery

| # | Item | Scout can evidence? |
|---|---|---|
| DEVOPS-DEL-01 | Deployments run through automated CI/CD pipelines rather than manual portal changes | ⚠️ Partial — `$.management.deployments[?(@.properties.templateHash)]` (generic IaC signal, same as `CAF-AUT-01`), `DevOpsPipelines` existence |
| DEVOPS-DEL-02 | Service connections authenticate via credential-free (workload identity federation), not long-lived secrets | ✅ `DevOpsServiceConnections` ("Credential Free" field) |
| DEVOPS-DEL-03 | Releases use safe-deployment practices — approvals, gates, canary/blue-green rollout | ❌ Pipeline stage/approval/gate configuration is not collected |
| DEVOPS-DEL-04 | Feature flags and progressive-exposure deployment strategies are used | ❌ Not collected |

### Operate / Operations and Reliability

| # | Item | Scout can evidence? |
|---|---|---|
| DEVOPS-OPS-01 | Build/release agent capacity uses managed pools rather than unmanaged self-hosted agents | ✅ `ManagedDevOpsPools`, `DevOpsAgentPools` ("Hosting Model" field) |
| DEVOPS-OPS-02 | Standardized, self-service developer environments are provisioned (Dev Centers / Dev Box) | ✅ `DevCenters`, `DevBoxPools` |
| DEVOPS-OPS-03 | Load and resilience testing are part of the operational pipeline | ⚠️ Partial — `LoadTesting`, `ChaosStudio` existence only, no test-run history |
| DEVOPS-OPS-04 | Continuous monitoring instruments health, performance, and reliability across dev through production | ⚠️ Partial — `Monitor/ActionGroups`, `Monitor/MetricAlertRules` are generic monitoring signals, not scoped to DevOps pipeline stages |
| DEVOPS-OPS-05 | Software delivery performance is measured — lead time for change, deployment frequency, mean time to restore, change-failure percentage (the DORA four keys) | ❌ Not collected — Scout has pipeline *definitions*, not run or deployment history, which is what these four metrics require |

### DevSecOps

| # | Item | Scout can evidence? |
|---|---|---|
| DEVOPS-SEC-01 | Security and policy-compliance gates run in the pipeline before production promotion | ❌ Pipeline stage/gate configuration and YAML content are not collected |
| DEVOPS-SEC-02 | Automated pipelines enforce policy-as-code (DeployIfNotExists/Modify) for platform configuration | ✅ `$.governance.policyAssignments[?(@.properties.parameters)]`, same signal as `CAF-AUT-02` |
| DEVOPS-SEC-03 | Repositories and build artefacts are scanned for vulnerabilities before deployment | ❌ Not collected |
| DEVOPS-SEC-04 | End-to-end functional/UI test automation is part of the release process | ⚠️ Partial — `PlaywrightTesting` existence only, no test-run or pass-rate data |

## What this means for the rule file

**6 of 18 items are fully answerable, 6 are partial, 6 are not collected at all.** The pattern here
is consistent with the audit's observation about #10 in §14: *"mostly ready … inventory exists; they
need rule files, not collectors."* Every fully-answerable item resolves to a collector Scout already
has. The genuine gap is **run-history data** — `DEVOPS-OPS-05`'s four DORA metrics, pipeline
trigger-on-commit behaviour (`DEVOPS-DEV-02`), and approval-gate configuration (`DEVOPS-DEL-03`) all
need the Azure DevOps *Pipelines Runs* / *Releases* APIs, which Scout's five ADO collectors do not
call — they read project/repo/pipeline/service-connection/agent-pool *definitions*, not execution
history. That is a materially different, heavier API surface (per-run pagination across every
pipeline) and should be scoped as its own decision before any `caf.devops-capability.yaml` claims
credit for delivery-performance scoring it cannot actually do.
