# WAF — enumerated source for the Azure Local | Well-Architected Review

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

The audit's DQ12 records why this file exists: *"Writing rules against a framework you have not
enumerated is how `waf.storage.yaml` happened"* — a rule file scoring a WAF pillar that does not
exist. A future `waf.azurelocal.yaml` is written against this enumeration and nothing else, and
every rule in it must cite an item number from the table below.

## What this assessment is

Microsoft's **Azure Local \| Well-Architected Review** is one of Microsoft's per-workload
specialised reviews (§14, item 3 of `pmo/audits/AZURE-SCOUT-AUDIT.md`) — the Well-Architected
Framework applied to the specific technology scope of Azure Local (platform, 2311 and later) and
Azure Local VMs (workload). It sits alongside the "Core Well-Architected Review" rather than
replacing it.

## Source

| Field | Value |
|---|---|
| Source page | [Architecture best practices for Azure Local](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-local) |
| Framework version | Azure Well-Architected Framework, current (`learn.microsoft.com/azure/well-architected/`) — five pillars: Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency |
| Extraction date | 2026-08-01 |
| Verification method | Full page fetched via the Microsoft Learn MCP `microsoft_docs_fetch` tool and read start to end. Every checklist bullet under each pillar's **"Workload design checklist"** heading is transcribed below, in the order it appears on the page. |

## The one thing this enumeration is NOT

**The interactive Microsoft Assessments version of this review (`learn.microsoft.com/assessments/`)
is not published as text.** Like SMART (see `smart-question-set.md`), the assessment tool renders a
client-side application shell; its question text and numbering aren't extractable from
documentation. What *is* published, and what this file enumerates, is the article's own **"Workload
design checklist"** under each pillar — Microsoft's own words describe this as the place to "start
your design strategy" for the review. It is the closest thing to a citable, stable checklist that
Microsoft publishes for this workload, and it is organised by the same five pillars the interactive
tool scores.

The `WAF-AZLOCAL-*` identifiers below are **Scout's**, stable and citable, and they are not
Microsoft item numbers.

**Shelf life.** This service guide is actively maintained (Azure Local ships new baseline builds on
a regular cadence). Re-verify before quoting, and re-date this page when you do.

## The enumeration — 33 items across 5 pillars

### Reliability (WAF-AZLOCAL-RE) — 6 items

| # | Item | Scope | Scout collector |
|---|---|---|---|
| WAF-AZLOCAL-RE-01 | Define workload reliability targets (SLOs) for the platform and workload | Platform + workload | ❌ Organisational — no ARM property records an intended SLO |
| WAF-AZLOCAL-RE-02 | Consider how performance and operations affect reliability (rightsizing, disk type choice, firmware currency) | Platform | ⚠️ Partial — `Hybrid/Clusters` reports cluster health and node count; firmware/driver currency isn't collected |
| WAF-AZLOCAL-RE-03 | Provide fault tolerance to the instance and its infrastructure dependencies (storage resiliency, network topology) | Platform | ✅ `Hybrid/Clusters` (storage resiliency, node count) · `Hybrid/LogicalNetworks` (network topology) |
| WAF-AZLOCAL-RE-04 | Build redundancy to provide resiliency (multi-instance deployment across sites) | Workload | ⚠️ Partial — Scout sees one cluster's inventory per collection scope; cross-instance redundancy isn't correlated |
| WAF-AZLOCAL-RE-05 | Plan and test recoverability (RTO/RPO, Azure Site Recovery) | Workload | ❌ Unanswerable — recovery testing cadence isn't an ARM-readable property |
| WAF-AZLOCAL-RE-06 | Configure and regularly test workload backup and restore procedures | Workload | ✅ `Management/RecoveryVault`, `Management/BackupInstances` — presence and coverage are readable; test cadence is not |

### Security (WAF-AZLOCAL-SE) — 9 items

| # | Item | Scope | Scout collector |
|---|---|---|---|
| WAF-AZLOCAL-SE-01 | Review the security baselines (drift protection, regulatory standards) | Platform | ⚠️ Partial — `Security/DefenderSecureScore` reflects posture; the specific Azure Local security-baseline drift-control setting isn't a discrete collected property |
| WAF-AZLOCAL-SE-02 | Detect, prevent, and respond to threats (Defender for Cloud, Defender for Servers) | Platform | ✅ `Security/DefenderPricing`, `Security/DefenderAlerts`, `Security/DefenderAssessments` |
| WAF-AZLOCAL-SE-03 | Create segmentation to contain the blast radius (identity role separation, network isolation) | Platform + workload | ⚠️ Partial — `Hybrid/LogicalNetworks` shows network segmentation; RBAC role-scope separation isn't collected (audit §14 item 2, gap B1) |
| WAF-AZLOCAL-SE-04 | Use a trusted identity provider to control access (Microsoft Entra ID) | Platform + workload | ✅ `Identity/*` collectors evidence Entra-backed identities; the specific Azure Local built-in-role assignment isn't yet a distinct collector |
| WAF-AZLOCAL-SE-05 | Isolate, filter, and block network traffic (Network Controller, NSGs, virtual appliance chaining) | Platform + workload | ✅ `Networking/PrivateEndpoint` and NSG collectors under `Networking/` for the workload side; Network Controller-specific policy objects aren't collected |
| WAF-AZLOCAL-SE-06 | Encrypt data to protect against tampering (BitLocker at rest, trusted launch for Gen 2 VMs) | Platform + workload | ❌ Unanswerable — BitLocker volume-encryption state and trusted-launch VM security-type flags aren't in the current `Hybrid/Clusters` / `Hybrid/VirtualMachines` field set |
| WAF-AZLOCAL-SE-07 | Operationalise secret management (deployment-identity credential rotation) | Platform | ❌ Unanswerable — rotation cadence isn't an ARM-readable property |
| WAF-AZLOCAL-SE-08 | Enforce security controls via Azure Policy (application control, encrypted volumes) | Platform | ✅ `Management/PolicyComplianceStates` against the relevant Azure Local built-in policy set |
| WAF-AZLOCAL-SE-09 | Improve workload security posture with built-in policies (guest configuration, patch currency) | Workload | ✅ `Management/PolicyComplianceStates` (Update Manager compliance path) |

### Cost Optimization (WAF-AZLOCAL-CO) — 6 items

| # | Item | Scope | Scout collector |
|---|---|---|---|
| WAF-AZLOCAL-CO-01 | Estimate realistic costs as part of cost modeling | Platform + workload | ❌ Organisational — a pricing-calculator exercise, not a collected property |
| WAF-AZLOCAL-CO-02 | Optimize the cost of Azure Local hardware (validated OEM catalog choice) | Platform | ❌ Unanswerable — hardware procurement choice predates any ARM resource |
| WAF-AZLOCAL-CO-03 | Optimize licensing costs (Azure Hybrid Benefit) | Platform | ⚠️ Partial — `Hybrid/VirtualMachines` records licence type where the API exposes it; Hybrid Benefit attach state for the cluster itself is not collected |
| WAF-AZLOCAL-CO-04 | Save on environment costs (Hybrid Benefit, promotional/trial offers) | Platform | ⚠️ Partial — same as CO-03 |
| WAF-AZLOCAL-CO-05 | Save on operational costs (Update Manager, right-sized observability retention) | Platform | ⚠️ Partial — `Monitor/Workspaces` reports retention settings; Update Manager cost itself isn't a billable collected metric |
| WAF-AZLOCAL-CO-06 | Evaluate density over isolation (AKS on Azure Local for containerised workloads) | Workload | ✅ `Hybrid/ArcKubernetes` — presence indicates the density option is in use |

### Operational Excellence (WAF-AZLOCAL-OE) — 6 items

| # | Item | Scope | Scout collector |
|---|---|---|---|
| WAF-AZLOCAL-OE-01 | Increase supportability (telemetry and diagnostics extension enabled by default) | Platform | ✅ `Hybrid/ArcExtensions` — presence of the `AzureEdgeTelemetryAndDiagnostics` extension is readable |
| WAF-AZLOCAL-OE-02 | Use Azure services to reduce operational complexity (Update Manager, Azure Monitor, Arc, Policy, Defender) | Platform | ✅ Composite — `Management/PolicyComplianceStates`, `Security/DefenderPricing`, `Monitor/*`, `Hybrid/ArcExtensions` together evidence this |
| WAF-AZLOCAL-OE-03 | Plan IP address network range requirements for workloads in advance | Workload | ✅ `Hybrid/LogicalNetworks` |
| WAF-AZLOCAL-OE-04 | Enable monitoring and alerting for workloads deployed on Azure Local | Workload | ✅ `Monitor/DataCollectionRules`, `Monitor/MetricAlertRules`, `Monitor/ActionGroups` |
| WAF-AZLOCAL-OE-05 | Use proper validation techniques for a safe deployment (environment checker tool) | Platform | ❌ Unanswerable — a pre-deployment tool run, not a post-deployment ARM property |
| WAF-AZLOCAL-OE-06 | Get current and stay current (solution catalog, Update Manager, automatic extension upgrade) | Platform | ✅ `Hybrid/Clusters` reports the current build/version; `Hybrid/ArcExtensions` reports auto-upgrade setting per extension |

### Performance Efficiency (WAF-AZLOCAL-PE) — 6 items

| # | Item | Scope | Scout collector |
|---|---|---|---|
| WAF-AZLOCAL-PE-01 | Use Azure Local-validated hardware or premium solution builder offerings | Platform | ❌ Unanswerable — hardware validation status isn't an ARM-readable property |
| WAF-AZLOCAL-PE-02 | Choose the right physical disk types for the machines (all-flash vs. hybrid storage) | Platform | ⚠️ Partial — `Hybrid/Clusters` may expose storage tier data depending on API version; not confirmed as a stable field |
| WAF-AZLOCAL-PE-03 | Use the Azure Local sizer tool during the instance design phase | Platform | ❌ Unanswerable — a pre-deployment sizing exercise |
| WAF-AZLOCAL-PE-04 | Use all-flash storage for high-performance or low-latency workloads | Platform | ⚠️ Partial — same field as PE-02 |
| WAF-AZLOCAL-PE-05 | Establish a performance baseline for instance storage before production | Platform | ❌ Unanswerable — a benchmarking exercise (DiskSpd/VMFleet), not a collected property |
| WAF-AZLOCAL-PE-06 | Consider ReFS deduplication and compression monitoring | Platform | ❌ Unanswerable — not exposed via ARM/ARG for Azure Local storage |

## Summary

| Pillar | Items | Answerable (✅) | Partial (⚠️) | Unanswerable (❌) |
|---|---|---|---|---|
| Reliability | 6 | 2 | 2 | 2 |
| Security | 9 | 4 | 2 | 3 |
| Cost Optimization | 6 | 1 | 3 | 2 |
| Operational Excellence | 6 | 5 | 0 | 1 |
| Performance Efficiency | 6 | 0 | 2 | 4 |
| **Total** | **33** | **12** | **9** | **12** |

12 of 33 items (36%) map cleanly to an existing collector. A further 9 are partially answerable —
the collector exists but doesn't expose the specific field the checklist item asks about, which is
build work rather than a new collector. 12 are genuinely unanswerable from ARM/ARG data (pre-deployment
sizing/validation exercises, benchmarking runs, and organisational commitments), and any future
`waf.azurelocal.yaml` must mark those `manual: true` rather than silently score them.

## What this means for the rule file

A future `waf.azurelocal.yaml` should cite `WAF-AZLOCAL-*` item numbers directly in each rule's
`title` or a comment, the way `smart.migration.yaml` cites `SMART-*`. Items marked ❌ above are
candidates for `manual: true` rules so they surface as questions for the customer rather than
disappearing; items marked ⚠️ are the priority list for new collector fields, not new collectors.
