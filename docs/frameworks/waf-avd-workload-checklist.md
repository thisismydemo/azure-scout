# WAF — enumerated source for the Azure Virtual Desktop workload assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

The audit's DQ12 records why this file exists: *"Writing rules against a framework you have not
enumerated is how `waf.storage.yaml` happened"* — a rule file scoring a WAF pillar that does not
exist. A future `waf.avd.yaml` is written against this enumeration and nothing else, and every rule
in it must cite an item number from the table below.

## What this assessment is

Microsoft's **Azure Well-Architected Framework Azure Virtual Desktop workload assessment**
(<https://learn.microsoft.com/en-us/assessments/1ef67c4e-b8d1-4193-b850-d192089ae33d/>) is one of
Microsoft's per-workload specialised reviews (§14, item 5 of `pmo/audits/AZURE-SCOUT-AUDIT.md`).

## Source — and a scope correction made during verification

The AI and Azure Local pages both link to a page at `azure/well-architected/azure-virtual-desktop/overview`
as "Virtual Desktop design areas." **That URL was fetched during this enumeration and resolved to the
generic "What is Azure Virtual Desktop?" product-overview page, not a WAF-specific checklist** — the
same link-rot pattern the audit's §8 currency warnings describe for CAF design-area pages. No
five-pillar WAF service guide for general Azure Virtual Desktop could be located via Microsoft Learn
search or fetch in this pass.

What *is* published and retrievable is **"Azure Virtual Desktop for Azure Local"** — an architecture
guide scoped specifically to AVD deployed on Azure Local (not AVD in general) that carries a full
five-pillar **"Considerations"** section in the same structure as the Azure Local service guide. This
is the enumeration below.

| Field | Value |
|---|---|
| Source page | [Azure Virtual Desktop for Azure Local](https://learn.microsoft.com/en-us/azure/architecture/hybrid/azure-local-workload-virtual-desktop) — **Considerations** section |
| Scope | **AVD on Azure Local only.** This is narrower than the general Azure Virtual Desktop workload assessment, which covers AVD on native Azure infrastructure too. |
| Framework version | Azure Well-Architected Framework, current — five pillars: Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency |
| Extraction date | 2026-08-01 |
| Verification method | Full page fetched via the Microsoft Learn MCP `microsoft_docs_fetch` tool and read start to end. Every bullet under each pillar's heading in the **Considerations** section is transcribed below. |

## The gap this leaves

**General (non-Azure-Local) Azure Virtual Desktop does not have an enumerated WAF checklist in this
file.** The interactive assessment tool's question text isn't published, exactly as with SMART and
the other three checklists in this release. A rule file built only from the enumeration below will
score AVD-on-Azure-Local-shaped concerns (FSLogix-on-S2D, Azure Local cluster health) accurately, but
will under-represent concerns specific to AVD on native Azure (host pool autoscale on Azure compute,
Azure Files/NetApp Files for FSLogix, Azure-region-based landing zone design). This is a documented
gap, not a fabricated item — closing it is a follow-up task, not a guess made here.

**Shelf life.** Re-verify before quoting, and re-date this page when you do.

## The enumeration — 20 items across 5 pillars (AVD on Azure Local)

### Reliability (WAF-AVD-RE) — 4 items

| # | Item | Scout collector |
|---|---|---|
| WAF-AVD-RE-01 | Implement multiple-machine instances for high availability | ✅ `Hybrid/Clusters` (node count) |
| WAF-AVD-RE-02 | Plan and regularly test backup and restore procedures for VMs and user profiles | ✅ `Management/RecoveryVault`, `Management/BackupInstances` — presence readable; test cadence is not |
| WAF-AVD-RE-03 | Implement monitoring and alerting for Azure Local and AVD VMs | ✅ `Monitor/MetricAlertRules`, `Monitor/ActionGroups`, `Compute/AVDSessionHosts` (health state field) |
| WAF-AVD-RE-04 | Test failover and disaster recovery regularly | ❌ Unanswerable — a test-execution cadence, not an ARM property |

### Security (WAF-AVD-SE) — 4 items

| # | Item | Scout collector |
|---|---|---|
| WAF-AVD-SE-01 | Turn on Microsoft Entra multifactor authentication for AVD access | ⚠️ Partial — `Identity/ConditionalAccess` can show an MFA-requiring policy exists; per-user enforcement isn't collected |
| WAF-AVD-SE-02 | Update and patch AVD session hosts regularly (Azure Update Manager) | ✅ `Management/PolicyComplianceStates` (Update Manager compliance path) |
| WAF-AVD-SE-03 | Protect against threats and vulnerabilities (Defender for Cloud) | ✅ `Security/DefenderPricing`, `Security/DefenderAlerts` |
| WAF-AVD-SE-04 | Isolate networks (separate logical networks/VLANs for the workload) | ✅ `Hybrid/LogicalNetworks` |

### Cost Optimization (WAF-AVD-CO) — 6 items

| # | Item | Scout collector |
|---|---|---|
| WAF-AVD-CO-01 | Optimize VM sizing for cost efficiency (rightsize against usage) | ⚠️ Partial — `Compute/AVDSessionHosts` reports SKU; usage-pattern correlation is a rule-authoring task, not a missing collector |
| WAF-AVD-CO-02 | Use automatic VM guest OS patching for Azure Local VMs | ✅ Same signal as WAF-AVD-SE-02 |
| WAF-AVD-CO-03 | Choose single-session or multi-session host pools deliberately | ✅ `Compute/AVD` (host pool type property) |
| WAF-AVD-CO-04 | Consolidate cost monitoring (Insights, Update Manager) | ⚠️ Partial — `Monitor/Workspaces` evidences Insights is configured; cost-consolidation practice itself isn't scorable |
| WAF-AVD-CO-05 | Plan for initial workload capacity and growth (2/3-node switchless where it fits) | ❌ Unanswerable — a pre-deployment capacity-planning decision |
| WAF-AVD-CO-06 | Implement Azure Virtual Desktop autoscaling | ✅ `Compute/AVDScalingPlans` |

### Operational Excellence (WAF-AVD-OE) — 4 items

| # | Item | Scout collector |
|---|---|---|
| WAF-AVD-OE-01 | Use simplified provisioning and management (ARM templates for deployment) | ❌ Unanswerable — a deployment-process choice, not a post-deployment property |
| WAF-AVD-OE-02 | Create strict change-control procedures (test/validate before production) | ❌ Organisational |
| WAF-AVD-OE-03 | Use automation capabilities for VMs (Arc extensions, Update Manager, Azure Automation) | ✅ `Hybrid/ArcExtensions` |
| WAF-AVD-OE-04 | Set up monitoring and logging (Insights for Azure Local and AVD) | ✅ `Monitor/Workspaces`, `Compute/AVD` (Insights-linked workspace reference) |

### Performance Efficiency (WAF-AVD-PE) — 2 items

| # | Item | Scout collector |
|---|---|---|
| WAF-AVD-PE-01 | Use load balancing for optimal performance (breadth-first / depth-first) | ✅ `Compute/AVD` (load-balancer-type property on the host pool) |
| WAF-AVD-PE-02 | Optimize performance — high-performance storage, S2D pooling, performance testing | ⚠️ Partial — `Hybrid/Clusters` may expose storage tier data depending on API version; performance-test execution is not collected |

## Summary

| Pillar | Items | Answerable (✅) | Partial (⚠️) | Unanswerable (❌) |
|---|---|---|---|---|
| Reliability | 4 | 3 | 0 | 1 |
| Security | 4 | 3 | 1 | 0 |
| Cost Optimization | 6 | 3 | 2 | 1 |
| Operational Excellence | 4 | 2 | 0 | 2 |
| Performance Efficiency | 2 | 1 | 1 | 0 |
| **Total** | **20** | **12** | **4** | **4** |

12 of 20 items (60%) map cleanly to an existing collector — the highest automatable fraction of the
four checklists in this release, because AVD-on-Azure-Local is infrastructure-heavy and Scout already
collects both the AVD (`Compute/AVD*`) and Azure Local (`Hybrid/*`) collector families it depends on.

## What this means for the rule file

A future `waf.avd.yaml` should cite `WAF-AVD-*` item numbers. Because this enumeration is scoped to
AVD-on-Azure-Local, the rule file inherits that scope; a rule that only makes sense for AVD on native
Azure compute (for example, autoscale cost tiers specific to Azure VM pricing) should not be written
against this file without a corresponding enumeration of the general AVD workload assessment first.
