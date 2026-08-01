# AVS Landing Zone — enumerated source for the Azure VMware Solution Landing Zone Assessment Review

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

**Framework version:** Not versioned by Microsoft — both the interactive assessment and the CAF
scenario documentation it is built from carry no release number. The extraction date above (2026-08-01)
is the version, per `docs/frameworks/README.md`; re-date this line when this file is next re-verified.

This is the AB#6810 enumeration for target #7 in the audit's fourteen-assessment programme
(`pmo/audits/AZURE-SCOUT-AUDIT.md` §14): *"Azure VMware Solution Landing Zone Assessment Review —
pairs with #6 [WAF AVS workload] — platform readiness rather than workload."* No rule file exists
against this framework yet; that is deliberate — per DQ12, a rule file is not written until its
source is enumerated here first.

## What this is

Microsoft publishes **two** artefacts under this name, and they are not the same thing:

1. **"Azure VMware Solution Landing Zone Assessment Review"** — an interactive assessment on the
   Microsoft Assessments platform
   (<https://learn.microsoft.com/en-us/assessments/43a1998e-2cb9-403c-b257-dffa8ceafd63>), ~30
   minutes, multiple-choice/multiple-response, "40+ actionable recommendations." Its questions are
   not published — same limitation as SMART (see `smart-question-set.md`).
2. **"Azure landing zone review for Microsoft Azure VMware Solution"**
   (<https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/azure-vmware/ready>)
   — a documentation page under the CAF Ready methodology's AVS scenario. This one **is** fully
   published: a checklist of best-practice statements grouped under 8 named areas.

This enumeration is built from document (2), because it is the only one of the two with retrievable
content. The interactive assessment (1) almost certainly draws on the same 8 areas — the landing
page names them explicitly ("resource organization, Entra ID usage, network topology, management
and monitoring, business continuity, HCX and governance") — but its actual question text and
per-question scoring are not extractable, so no coverage percentage against assessment (1) can be
claimed from this enumeration.

## Verification method — and the one thing this enumeration is NOT

**What was read (2026-08-01):**

| Source | What it gave |
|---|---|
| The AVS Landing Zone Assessment Review landing page (assessment ID `43a1998e-…`) | Confirms the assessment exists, its title, duration, and format. **No question text.** |
| *Azure landing zone review for Microsoft Azure VMware Solution* (`scenarios/azure-vmware/ready`) | The full, fetched content of the 8-area checklist below |
| *Azure VMware Solution landing zone accelerator* (`scenarios/azure-vmware/enterprise-scale-landing-zone`) | Confirms the 8 areas map 1:1 to the accelerator's design-guideline articles (identity, network, management/monitoring, BC/DR, security/governance/compliance, platform automation) |

**⚠️ Microsoft's own interactive-assessment question TEXT and NUMBERS are not published.** This
enumeration is the CAF documentation page's checklist content, not the assessment's question bank.
The `AVS-*` identifiers are **Scout's own**, stable and citable, not Microsoft's.

**Granularity rule applied throughout:** each item below is a bullet point or a single declarative
sentence taken directly from the source page — nothing has been split further or invented. Where
the source states one undifferentiated sentence covering several concerns (e.g. area A), it remains
one item here rather than being decomposed into sub-claims the source didn't make separately.

**Shelf life.** This is a scenario page inside the actively-rewritten CAF tree (see the audit's §8
currency warnings). Re-verify before quoting, and re-date this page when you do.

## The enumeration

### A — Resource organization plan

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-A1 | The landing zone references the subscriptions to use, resource-group usage guidance, and tagging/naming standards for AVS deployments | ⚠️ Partial — `Management/AllSubscriptions` (subscription inventory), `$.tags[*]` (tag presence), no naming-convention signal |

### B — Microsoft Entra ID and Active Directory

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-B1 | Active Directory Sites and Services directs Azure/AVS AD DS traffic to the correct domain controllers | ❌ Organisational/on-premises AD topology — not an ARM resource |
| AVS-B2 | An AD DS domain controller is deployed in the identity subscription as part of the IAM landing zone | ❌ Not reliably distinguishable from general VM inventory — no domain-controller-role signal collected |

### C — Network topology and connectivity

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-C1 | Traffic-inspection requirements are established for the AVS deployment | ⚠️ Partial — `Networking/AzureFirewall`, `Security/WafPolicies` existence |
| AVS-C2 | Network traffic flows are documented/understood before migration | ❌ No flow-log or traffic-pattern data collected |
| AVS-C3 | Internet egress and ingress paths are defined | ⚠️ Partial — `Networking/PublicIP`, `Networking/NATGateway` existence |
| AVS-C4 | NVA use is considered where required | ❌ Not distinguishable from general VM/appliance inventory |
| AVS-C5 | Connectivity exists to a standard hub VNet or an Azure Virtual WAN hub | ✅ `Compute/VMWare` "Express Route Circuit" field · `Networking/VirtualWAN`, `Networking/ExpressRoute`, `Networking/VirtualNetworkGateways` |
| AVS-C6 | Private connectivity is used rather than public exposure | ✅ `Networking/PrivateEndpoint` |

### D — Management and monitoring

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-D1 | Alerts and dashboards exist for the operations-relevant metrics | ⚠️ Partial — `Monitor/ActionGroups`, `Monitor/MetricAlertRules`, `Monitor/MonitorWorkbooks` existence only, not metric relevance |
| AVS-D2 | VMware ecosystem tooling (vRealize Operations, Log Insight, Network Insight) is licensed for AVS platform visibility | ❌ Third-party VMware tooling, not an Azure ARM resource |
| AVS-D3 | Guest monitoring is configured for AVS VMs per the hybrid Windows/Linux guidance | ⚠️ Partial — `Hybrid/ArcExtensions` (Azure Monitor Agent extension presence), same limitation as `SMART-E1` |

### E — Business continuity and disaster recovery

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-E1 | A validated backup solution (MABS or a partner product) protects the AVS VMware VMs | ❌ VMware-native/partner backup agents are not an ARM resource Scout collects — `Management/Backup` and `Management/RecoveryVault` cover Azure-native backup only |
| AVS-E2 | VMware Site Recovery Manager is configured between primary and secondary sites | ❌ VMware SRM is not ARM-visible; distinct from Azure Site Recovery |

### F — Governance and compliance

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-F1 | Environment governance controls are in place | ✅ `Management/PolicyAssignments`, `Management/PolicyComplianceStates` |
| AVS-F2 | Guest application and VM governance controls are in place | ❌ Guest-OS-level, not observed |
| AVS-F3 | Environment and guest compliance are both tracked | ⚠️ Partial — environment half only, via `Management/PolicyComplianceStates` |

### G — Security

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-G1 | Identity security for who can perform AVS functions is planned | ⚠️ Partial — `Identity/RoleAssignments`, `Identity/PIMAssignments` |
| AVS-G2 | Environment and network security are reviewed | ⚠️ Partial — `Networking/NetworkSecurityGroup`, `Security/DefenderPricing` |
| AVS-G3 | Guest application and VM security are reviewed | ❌ Guest-OS-level, not observed |

### H — Platform automation and DevOps

| # | Item | Scout can evidence? |
|---|---|---|
| AVS-H1 | Deployment options (manual vs. automated) for the AVS private cloud are decided | ❌ Deployment method is not recorded against the resource |
| AVS-H2 | Automated scale considerations and implementation details are documented | ⚠️ Partial — `Compute/VMWare` "Cluster Size" field is a static snapshot, not a scaling-activity signal |
| AVS-H3 | VMware-level automation within the private cloud (NSX-T, vCenter) is considered | ❌ Not ARM-visible |
| AVS-H4 | Automation approaches extend from the enterprise landing zone | ⚠️ Partial — `$.management.deployments[?(@.properties.templateHash)]` (generic IaC-deployment signal, not AVS-specific) |
| AVS-H5 | Automation technologies (Azure CLI, ARM templates, Bicep, PowerShell) are chosen for deployment/management | ⚠️ Partial — same IaC-deployment signal as AVS-H4 |

## What this means for the rule file

**8 of 25 items are fully answerable, 12 are partial, 5 are organisational or VMware-native and out
of reach entirely.** The strongest signal Scout already has for this assessment is network
connectivity (`AVS-C5`, `AVS-C6`) — the `Compute/VMWare` collector already carries an "Express Route
Circuit" field that answers a genuine landing-zone-readiness question directly. The weakest area is
BC/DR (`AVS-E1`, `AVS-E2`): VMware-native backup and Site Recovery Manager sit entirely outside
ARM's visibility, and no Scout collector will ever close that gap short of reading vCenter/NSX-T
APIs directly, which is out of scope for an ARM-based tool. A future `caf.avs-landingzone.yaml`
should mark those `manual: true` rather than silently omitting them.
