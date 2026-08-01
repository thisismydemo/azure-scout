---
description: Azure Scout audit — what it covers, what is broken, what was decided, and the plan to fix and extend it.
---

# Azure Scout — Audit, Findings, Decisions & Plan

**Date:** 2026-07-31
**Scope:** ADO work items AB#6444, AB#6445, AB#6446, AB#6447 (Feature AB#6461)
**Method:** four parallel Opus audits over the full repo, cross-checked against Microsoft Learn,
plus findings that emerged in review afterwards and an adversarial fact-check of the permission
research.

## How to read this document

It is four documents in one, in the order you would actually use them.

| Part | Sections | What it is | Read it when |
|---|---|---|---|
| **I — Reference** | 1-3 | Microsoft's published lists, recorded verbatim. No opinion. | You need the authoritative answer to *"what does Azure actually have?"* |
| **II — Findings** | 4-11 | What the audit found. Coverage, gaps, permissions, architecture, defects. | You want to know where Scout stands today |
| **III — Decisions** | 12-13 | Every decision taken, with its reasoning | You want to know why something is the way it is, or is about to be |
| **IV — Plan** | 14-17 | The 14 target assessments, the collector build list, the release plan, and how we prove it worked | You are about to do the work |

**If you read one thing:** §13 — the decisions. All twelve are taken, each with its reasoning. One
(DQ7) carries a dependency only the owner can clear; nothing else is waiting on anybody.

**Status legend used throughout:** ✅ done · 🟡 agreed, not built · 🔲 not started ·
⚠️ caveat · ⛔ not possible

**Verification legend — this matters.** Claims in this document are marked:

- **Verified** — read in the repo at a named `file:line`, or fetched from Microsoft Learn with the
  URL cited.
- **Documented** — Microsoft's documentation says so. Not the same as proven in a tenant.
- **Untested** — reasoned from the above, never observed against real Azure.

**No permission claim in §9 has been tested with a Reader-only principal.** See §9's verification
status subsection before quoting any of it to a customer.

---

## Part I — Reference: what Microsoft publishes

Two authoritative lists, recorded verbatim. Nothing here is a judgement about Scout.

---

## 1. Terminology — inventory vs assessment

These are **two different products**. This document uses the words strictly, and so should the code.

| | **Inventory** (audit / discovery) | **Assessment** |
|---|---|---|
| **Question it answers** | *What is there?* | *Is what is there any good?* |
| **Output** | A list of resources and their properties | Findings, pass/fail, a score |
| **Contains opinion?** | No — facts only | Yes — measured against a standard |
| **Standard it scores against** | none | **CAF / WAF** |
| **Example** | "There is a VM, Standard_D4s_v5, in eastus, tagged env=prod" | "This VM is not zone-redundant — WAF Reliability finding" |

**"Assessment" means a CAF/WAF assessment. Full stop.** It is not a general word for looking at
things. If a thing does not run rules and produce findings, it is not an assessment.

**The relationship is one-way: assessment consumes inventory.** You cannot score what has not been
discovered. Inventory stands alone; assessment does not.

That relationship is what makes the collect-once design in row 12 and §10 correct — and it is why
two things in the current code are wrong:

- **`Estate` sits in the assessment registry with `Rules = @()`.** It scores nothing. It is
  inventory, so it does not belong there (row 11).
- **The 15 per-category assessment entries share names with the 15 inventory categories** —
  Compute, Storage, Networking and so on. One filters what is *collected*; the other filters what
  is *scored*. Same word, different meaning, presented in one menu.

---

## 2. Azure's 18 categories and their services

Captured from the Azure portal's **All services** page (`portal.azure.com/#allservices/category/All`)
on 2026-07-31. **This is the source of truth for what a category is and how many services it holds.**

**18 categories, ~364 services.**

| # | Category | Services |
|---|---:|---:|
| 1 | AI + machine learning | 21 |
| 2 | Analytics | 20 |
| 3 | Compute | 32 |
| 4 | Containers | 12 |
| 5 | Databases | 18 |
| 6 | DevOps | 23 |
| 7 | General | 10 |
| 8 | Hybrid + multicloud | 18 |
| 9 | Identity | 18 |
| 10 | Integration | 15 |
| 11 | Internet of Things | 19 |
| 12 | Management and governance | 34 |
| 13 | Migration | 5 |
| 14 | Monitor | 24 |
| 15 | Networking | 34 |
| 16 | Security | 22 |
| 17 | Storage | 17 |
| 18 | Web & Mobile | 22 |
| | **Total** | **~364** |

### Two units of measurement — do not confuse them

| Unit | Count | Where it appears |
|---|---|---|
| **Services** (portal "All services") | **~364** | This section, and §6 |
| **Resource providers** (`Microsoft.*`) | 152 | §9 and §6 |

One provider covers many services — `Microsoft.Compute` alone accounts for Virtual machines, VM
scale sets, Disks, Images, Snapshots, Availability sets, Proximity placement groups, Restore point
collections and more. **So "Scout collects 49 of 152 providers (32%)" and any service-level figure
are not comparable**, and provider-level counting overstates coverage: a provider reads as
"collected" when only one of its many services actually is.

### Azure services by category — from the portal All services page

| Category | Services |
|---|---|
| **AI + machine learning** (21) | Azure Machine Learning · AI Search · Azure AI Video Indexer · Anomaly detectors · Bot Services · Computer vision · Content moderators · Custom vision · Document Intelligence · Face APIs · Immersive readers · Language · Metrics advisor · Microsoft Foundry · Azure OpenAI · Personalizers · Speech services · Translators |
| **Analytics** (20) | Analysis Services · Data Explorer clusters · Data Lake Analytics · Data Lake Storage Gen1 · Event Hubs · HDInsight clusters · Log Analytics workspaces · Microsoft Graph Data Connect · Power BI Embedded · Power BI · Data Shares · Data Share accounts · Stream Analytics clusters · Stream Analytics jobs · Azure Synapse Analytics · Azure Synapse Analytics (private link hubs) · Azure Databricks · Data factories · Apache Kafka and Apache Flink on Confluent · Informatica Intelligent Data Management Cloud |
| **Compute** (32) | Availability sets · Community images · Compute Fleet · Azure compute galleries · Compute infrastructure · Host groups · Image templates · Images · Lab accounts · Proximity placement groups · Restore Point Collections · SSH keys · Azure Virtual Desktop · Virtual machine scale sets · Virtual machines · VM application definitions · VM application versions · VM image definitions · VM image versions · App Spaces · Cloud services (extended support) · Azure Spring Apps · Virtual instances for SAP solutions · Container Apps · Container Apps Environments · Function App · Kubernetes services - Automatic · Kubernetes services · Batch accounts · BareMetal Instances · SAP PubSub on Azure |
| **Containers** (12) | Container instances · Container registries · Kubernetes services · Kubernetes Fleet Manager · Kubernetes services - Automatic · Azure Red Hat OpenShift clusters · Service Fabric clusters · Service Fabric managed clusters · App Configuration · Container Apps · Container Apps Jobs |
| **Databases** (18) | Azure Cosmos DB · Azure Database for PostgreSQL flexible servers · Azure Database for MySQL flexible servers · Azure Database for MariaDB · Azure Database Migration Services · Azure Managed Instance for Apache Cassandra · Azure Cache for Redis · Azure Managed Redis · MongoDB Atlas · Oracle Database@Azure · Azure SQL · SQL Server instances · Azure Arc data controllers · Managed databases · SQL managed instances - Azure Arc · SQL Server stretch databases · SQL databases |
| **DevOps** (23) | Chaos Studio · Azure Deployment Environments · Dev centers · DevTest Labs · GitHub · Azure Lab Services · Azure Load Testing · Managed DevOps Pools · Microsoft Dev Box · Network connections · Playwright Testing (Classic) · Projects · API Connections · API Management services · App Configuration · Application Insights · Monitor · Azure Native LambdaTest / HyperExecute Cloud · Elastic - on Azure Native ISV Service · Plastic Cloud (Rackmarole) · Azure Native New Relic Service |
| **General** (10) | Cost Management + Billing · Pass services · Quotas · Reservations · Operations center · Resource Manager · Resources · Preview features · Quickstart Center · Help + support · Service Health |
| **Hybrid + multicloud** (18) | Azure Arc data controllers · Azure Arc · Microsoft Entra ID · Azure Network Function Manager - Devices · Site recovery - Azure Arc · Azure VMware Solution · Azure Edge Hardware Center · ExpressRoute circuits · Operator Nexus · SQL managed instances - Azure Arc · SQL Server databases · Microsoft Purview Cloud Connect Health · Microsoft Defender for Cloud · Microsoft Sentinel · Azure Local · Virtual WANs |
| **Identity** (18) | Microsoft Entra Cloud Health · Azure AD B2C · RBAC Tenants · Enterprise applications · External Identities · Access Connector for Azure Databricks · Agent IDs · App registrations · External Configuration Tenant · Guest Usages · Managed Identities · Microsoft Entra Domain Services · Microsoft Entra ID · Microsoft Entra Privileged Identity Management · Identity Governance · Microsoft Entra ID Protection · Microsoft Entra ID Security · Verified ID |
| **Integration** (15) | App Configuration · Integration accounts · Logic apps · Logic Apps Custom Connector · API Connections · Azure API for FHIR · API Management services · FHIR service · Mobile Data Services workspaces · Apache Kafka and Apache Flink on Confluent · Event Grid · Event Hubs Clusters · Event Hubs · Relays · Service Bus |
| **Internet of Things** (19) | IoT Central Applications · IoT Hub · Device Update for IoT Hubs · Azure IoT Hub Device Provisioning Service · Microsoft Defender for IoT · Azure Cosmos DB · Azure Data Explorer Clusters · Azure Digital Twins · Event Hubs · Function App · Stream Analytics jobs · Azure Synapse Analytics · Logic apps · Azure Machine Learning · Azure Maps Accounts · Azure Maps Creator Resources · Power Platform · Azure Stack Edge / Data Box Gateway · Storage accounts |
| **Management and governance** (34) | Operations center · Advisor · Change Analysis · Deployment Scripts · Diagnostic settings · Azure Monitor for SAP solutions · Azure Resource Mover · Backups · Subscriptions · Template specs · Virtual instances for SAP solutions · Azure Capital admin center · Automanage · Automation accounts · Blueprints · Capacity Reservation Groups · Cost Management · Guest Assignments · Policy · Update Center · Microsoft Entra Domain Services · Customer Lockbox for Microsoft Azure · Azure Lighthouse · Managed applications center · Intune · Intune for Education · Managed Desktop · Universal Print · Backup vaults · Azure Native Qumulo Scalable File Service · Recovery Services vaults · Resiliency |
| **Migration** (5) | Azure Database Migration Services · Azure Migrate · Azure Data Box · Recovery Services vaults · Azure Stack Edge / Data Box Gateway |
| **Monitor** (24) | Alerts · Autoscale · Change Analysis · Diagnostic settings · Log Analytics dedicated clusters · Log Analytics workspaces · Managed Prometheus · Metrics · Azure Monitor workspaces · Azure Native Dynatrace Service · Observability agents · Azure Workbooks · Application Insights · Activity log · Data collection endpoints · Data collection rules · Database watchers · Elastic - on Azure Native ISV Service · Plastic Cloud (Rackmarole) · Log Analytics query packs · Azure Managed Grafana · Monitor · Azure Monitor for SAP solutions · Network Watcher · Service Health |
| **Networking** (34) | Bastions · Custom IP Prefixes · DNS private resolvers · DNS zones · NAT gateways · Network interfaces · Network managers · Private DNS zones · Private Link · Public IP addresses · Public IP Prefixes · Route tables · Virtual networks · Connections · ExpressRoute circuits · ExpressRoute traffic collectors · Local network gateways · Peering Service · Peerings · Virtual network gateways · Networking monitoring and management · DDoS protection plans · IP Groups · Network security groups · Web Application Firewall policies (WAF) · Application gateways · Load balancers · Microsoft Connected Cache for Internet Service Providers · Monitor · Network Watcher · Front Doors · Virtual WANs · NSGWatch |
| **Security** (22) | App Compliance Automation Tool for Microsoft · Application security groups · Confidential Ledgers · Log Analytics workspaces · Web Application Firewall policies (WAF) · Artifact Signing Accounts · Microsoft Entra Domain Services · Microsoft Entra ID · Microsoft Entra ID Security · Microsoft Entra Privileged Identity Management · Multifactor authentication · Application gateways · Azure Cloud HSM · DDoS protection plans · Firewalls · Azure Key Vault Managed HSM · Key vaults · Microsoft Defender for Cloud · Microsoft Defender for IoT · Microsoft Sentinel |
| **Storage** (17) | Azure Edge Hardware Center · Azure Stack Edge / Data Box Gateway · Data Accesses · Disk Encryption Sets · Disks · Azure NetApp Files · Azure Data Box · Data resources · Data Lake Storage Gen1 · Elastic SANs · Azure Storage Locker · Azure Native Pure Storage Cloud Service · Azure Native Qumulo Scalable File Service · Snapshots · Storage accounts · Storage browser · Storage Sync Services |
| **Web and Mobile** (22) | API Connections · API Management services · App Configuration · App Service Certificates · App Service Domains · App Service Environments · App Service plans · App Services · Application Insights · Container Apps · Function App · Logic apps · Azure Spring Apps · Static Web Apps · AI Search · Communication Services · Email Communication Services · Notification Hubs · SignalR · Web PubSub for Socket.IO · Web PubSub Service · Fluid Relay |

## 3. Microsoft's 56 published assessments

Every assessment on <https://learn.microsoft.com/assessments/browse/> as of 2026-07-31.
**56 assessments across 4 pages.** Listed for reference — whether Scout can produce any of them
is a separate question, deliberately not answered here.

| Assessment | Description | Tags |
|---|---|---|
| **Azure Well-Architected Review** | Examine reliability, security, cost optimization, operational excellence and performance efficiency of workload design | Azure |
| **Azure Well-Architected Framework Maturity Model Assessment** | Structured path to improve workload maturity against the five WAF pillars | — |
| **Azure Landing Zone Review** | Assess Azure platform readiness and plan to create landing zones for workloads | Azure |
| **Go-Live \| Well-Architected Review** | Holistically evaluate an Azure workload across the five WAF tenets | Azure |
| **Mission Critical \| Well-Architected Review** | Evaluate mission-critical workloads and operational effectiveness | Azure |
| **Sustainability \| Well-Architected Review** | Examine your workload through the lens of sustainability | Azure |
| **SAP on Azure \| Well-Architected Review** | Well-architected review for SAP on Azure | — |
| **Azure Local \| Well-Architected Review** | — | Azure |
| **Azure Well-Architected AI workload** | Assess key technical design areas in AI workloads | Azure |
| **Azure Well-Architected Azure Virtual Desktop workload** | Examine AVD readiness for production against best practices | Azure |
| **Azure Well-Architected Azure VMware Solution workload** | Examine AVS readiness for production | Azure |
| **Azure Well-Architected Oracle on Azure IaaS workload** | Examine Oracle on Azure IaaS readiness for production | — |
| **Azure Well-Architected SaaS workload** | Assess key technical design areas in SaaS workloads, for ISVs | Azure |
| **Azure Machine Learning** | Examine an ML workload through reliability, cost, operational excellence, security and performance | — |
| **Azure VMware Solution Landing Zone Assessment Review** | Review platform readiness for deploying and managing AVS | Azure |
| **Power Platform Well-Architected** | Reliability, security, operational excellence, performance efficiency and user experience | Power Platform |
| **Microsoft Cloud for Financial Services \| Well-Architected for Industry** | Configuration, extension scenarios and WAF pillars | Industry Solutions |
| **Microsoft Sustainability Manager \| Well-Architected Assessment** | Assess application deployment at different implementation stages | Industry Solutions |
| **Cloud Adoption Security Assessment (CASA)** | Cloud security maturity across security teams/roles, posture modernization, incident preparedness and sustainment. **Aligned to the CAF Secure methodology** | Azure |
| **Cloud Adoption Strategy Evaluator** | Assess cloud adoption strategy; recommendations for building or advancing a business case | Azure |
| **Cloud Governance** | Assess cloud governance approach with tailored recommendations | — |
| **Cloud Journey Tracker** | Identify your cloud adoption path and navigate to relevant CAF content | Azure |
| **Strategic Migration Assessment and Readiness Tool** | Prepare for a scale migration | Azure |
| **App and Data Modernization Readiness Tool** | First steps in modernizing workloads | Azure |
| **FinOps Review** / **FinOps Review (New)** | Capability gaps against FinOps guidance; maximise cloud business value | Azure |
| **DevOps Capability Assessment** | Capabilities across the software release lifecycle | Azure |
| **Developer Velocity Assessment** | Developer Velocity Index score and guidance | Azure |
| **Platform Engineering Technical Assessment** | Platform Engineering maturity with tailored recommendations | AKS, GitHub |
| **AI Readiness Assessment** | Organizational AI preparedness across seven pillars: Business Strategy, AI Governance & Security, Data Foundations, AI Strategy & Experience, Organization & Culture, Infrastructure for AI, Model Management | Azure |
| **GenAIOps Maturity Model Assessment** | GenAIOps knowledge, practices and experience; maturity ranking | Azure |
| **Technical Assessment for Generative AI in Azure** | Readiness to develop, run and maintain Azure AI solutions in production | Azure |
| **Analytics Journey Tracker** | Data and analytics capabilities across maturity levels | Azure, Synapse |
| **Power Platform Solution Assessment** | Functionality, user experience, alignment with business goals | Power Platform |
| **Power Platform Adoption Assessment** | Evaluation of current Power Platform use | Power Platform |
| **Windows 11 Pro Migration Readiness Assessment** | Readiness to migrate to Windows 11 Pro | Windows |
| **Primary and Secondary Education: Deploy Windows devices using Intune for Education** *(Preview)* | Deployment recommendations | Intune, M365 Education |
| **Microsoft Cloud for Healthcare Learner Self-Assessment** *(Preview)* | Learning-journey guidance | Azure |
| **AI Engineer Skill Assessment** | Strengths, growth opportunities, learning recommendations | — |
| **Security Engineer Skill Assessment** | Strengths, growth opportunities, learning recommendations | 45 questions |
| **Microsoft Cybersecurity Architect Learner Journey** | Learner journey for cybersecurity architecture | Defender, Sentinel |
| **Azure Virtual Desktop \| Microsoft Partner** | Partner readiness for AVD | Azure, AVD |
| **Azure Stack HCI \| Microsoft Partners** | Bridging on-premises with Azure for VMs and containers | Azure, HCI, AKS, AVD |
| **Azure VMware Solution (AVS) \| Microsoft Partner** | Migrating VMware workloads to Azure | Azure, AVS |
| **Microsoft Sentinel in a Box \| Microsoft Partners** | Building practices and offers around the SIEM platform | Azure |
| **Unpacking Defender \| Microsoft Partners** | Defender for Endpoint expertise and offerings | Defender |
| **MXDR Roadmap \| Microsoft Partner** | Advanced threat detection and response with extended XDR | — |
| **Identity Compete \| Microsoft Partner** | Microsoft Entra identity and access management expertise | — |
| **Information Protection and Governance \| Microsoft Partner** | Microsoft Purview protection, governance and compliance | Purview |
| **Data Security for Copilot for Microsoft 365 \| Microsoft Partners** | Data security training and guidance | — |
| **Microsoft Cloud for Retail Adoption Guide \| Microsoft Partners** | Retail solutions partner readiness | Industry Solutions |
| **Microsoft Cloud for Sustainability Adoption Guide \| Microsoft Partners** | Sustainability solutions partner readiness | Industry Solutions |
| **Energy Industry \| Microsoft Partners** | Core digital technologies for energy transformation | Azure |
| **Financial Services Industry \| Microsoft Partners** | Key assets for the financial services industry | Industry Solutions |
| **Healthcare Industry \| Microsoft Partners** | Training materials and readiness approaches | Industry Solutions |
| **Manufacturing Industry \| Microsoft Partners** | How Microsoft empowers manufacturing organizations | Industry Solutions |

---

## Part II — Findings: what the audit discovered

---

## 4. Executive summary

Three questions were asked. Here are the answers.

| Question | Answer |
|---|---|
| Should Scout inventory more than 15 categories? | **Yes.** Azure has **18** official categories. Scout has 15. Missing: **General, DevOps, Migration**. |
| Should there be more assessments than LandingZone? | **Yes — and there is effectively only ONE today.** The registry's 22 entries are ~3 real assessments plus 19 filtered views of the same rule set. A separate path bug also hides 21 of the 22 menu entries. |
| Do the current assessments really cover CAF/WAF? | **No.** ~**10%** of CAF's design recommendations, ~**15%** of WAF's checklist items. |

**The four things that are wrong right now**, in priority order:

1. **Scout was not read-only.** It commanded every VM and Arc machine to run a patch scan on every
   run. **Fixed this session** — now reads Azure Update Manager instead.
2. **A one-line path bug** hides 21 of 22 assessment menu entries from the wizard.
3. **~40% of collected data is silently discarded** — Scout pulls it, then never writes it down.
4. **Nothing has ever been verified.** 0 of 174 collectors proven against real Azure; 12 provably
   return nothing, always.

---

## 5. The five discovery findings

The five things that changed the picture. Two of these correct statements made earlier in review.

### 3.1 Azure has 18 categories — Scout has 15

**Correction:** it was stated earlier that Azure has no official category taxonomy. That was wrong.
The Azure portal's All Services page and Microsoft's resource-provider documentation both publish a
defined 18-category structure.

**Source:** <https://learn.microsoft.com/azure/role-based-access-control/resource-provider-operations>

| Microsoft category | Scout? | Microsoft category | Scout? |
|---|---|---|---|
| General | ❌ **missing** | Integration | ✅ |
| Compute | ✅ | Identity | ✅ |
| Networking | ✅ | Security | ✅ |
| Storage | ✅ | **DevOps** | ❌ **missing** |
| Web and Mobile | ✅ (as "Web") | **Migration** | ❌ **missing** |
| Containers | ✅ | Monitor | ✅ |
| Databases | ✅ | Management and governance | ✅ (as "Management") |
| Analytics | ✅ | Hybrid + multicloud | ✅ (as "Hybrid") |
| AI + machine learning | ✅ (as "AI") | Internet of Things | ✅ (as "IoT") |

Scout's taxonomy is clearly modelled on Microsoft's — it just stopped three short.

**DevOps is nearly free:** Scout already has **5 DevOps collectors**, currently misfiled under
`Management/`. Creating the category is largely a directory move.
**Migration has zero coverage** — Azure Migrate, Data Box, Database Migration Service, Azure Stack
Edge are all absent.

Separately, and distinct from categories: Scout collects **110 real ARM resource types across 52
resource providers**. Measured against Microsoft's own provider directory (152 providers across the
18 categories), that is **49 of 152 = 32% coverage**. Full per-category breakdown in §6.

> Two coverage numbers appear in this document and they are not in conflict — they use different
> denominators. **32%** is against Microsoft's published 152-provider directory (the strict,
> comparable figure). **40%** appears in the AB#6446 report against a broader ~130-provider working
> estimate. The precise figure is 32%; three providers Scout collects
> (`microsoft.azurearcdata`, `microsoft.classiccompute`, `microsoft.edgeconfig`) don't appear in
> Microsoft's directory at all, which is why the collected count reads 49 there and 52 elsewhere.

### 3.2 The "22 assessments" are really about three

**Correction:** it was stated earlier that Scout has 22 assessments with a bug hiding 21. That
overstated things. Reading `manifests/assessments.psd1` in full:

| Kind | Count | What they are |
|---|---|---|
| Real cross-cutting | 2 | `LandingZone` (all `caf.*` + `waf.*` rules), `Estate` (inventory, no scoring) |
| **Per-category slices** | **15** | Management, Monitor, Networking, Identity, Security, Compute, Storage, Databases, Containers, Web, Analytics, AI, Integration, Hybrid, IoT — **named identically to Scout's 15 categories**, each just setting `Category='<itself>'` |
| Sub-bundles | 4 | Governance, Policy, UpdateManager, Monitoring |
| Targeted pull | 1 | Cost |

**Verified duplication** (`manifests/assessments.psd1:141-160`):

- **`Governance` and `Policy` are behaviourally identical** — same `Category`, `Collect`, `Ingest`,
  and `Rules=@('caf.governance')`. Only the description and tags differ.
- **`UpdateManager`** (`caf.management`) is a strict subset of **`Management`**
  (`caf.governance` + `caf.management` + `caf.billing`).
- **`Monitoring`** (`waf.operational`) is a strict subset of **`Monitor`**
  (`caf.management` + `waf.operational`).

**So: one real assessment, an inventory mode, a cost pull, and 19 filtered views of the same rules.**

The original instinct — *"right now we just have LandingZones"* — was closer to the truth than the
correction was. Fixing the wizard bug yields **21 menu entries, not 21 new assessments** -- and DQ1/DQ2/DQ10/DQ11 then cut those 21 back to the two that are real (`LandingZone` + `Cost`), because a menu entry that produces nothing is a false negative.

**The wizard bug itself is still real.** `src/Start-AZSCWizard.ps1:238` climbs **three** directory
levels to find the assessment manifest. The engine rewrite moved the file to `src/`, so it needs
**one**. It resolves to a path that doesn't exist, `Test-Path` returns false, and it silently falls
back to a hardcoded `@('LandingZone')`. No error, no warning, not even verbose output. It shipped
because there is **no wizard test at all**. `Invoke-AzureScout -Assessment <name>` is unaffected.

### 3.3 Scout collects nearly everything, then displays about 40%

This is a **display** gap, not a collection gap — which makes it far cheaper to fix than it sounds.

The query at `src/collect/Get-ScoutRawInventory.ps1:432` is:

```kql
resources | where type !in ('microsoft.logic/workflows','microsoft.portal/dashboards',
                           'microsoft.resources/templatespecs/versions','microsoft.resources/templatespecs')
```

That says **"everything EXCEPT these four"** — not a list of wanted types. Every resource of every
type comes back.

Then each of the 174 collectors selects the rows matching its own declared types, formats them, and
writes a worksheet. **Rows no collector asks for are never selected, and vanish when the process
exits.**

**Worked example.** A tenant contains an Azure Data Factory:
1. The query pulls it back — it's not excluded ✅
2. It sits in memory with everything else ✅
3. Scout looks for a collector wanting `microsoft.datafactory/factories`
4. **There isn't one.** Nobody wrote it.
5. The row is never selected. Program ends. Gone.

No error, no warning, no "1 resource skipped". **The report cannot distinguish "you don't have one"
from "Scout can't display it."**

> Think of a shop doing a full stock count. The counter walks the whole warehouse and writes down
> every single item. Then, typing up the report, he only types the items that have a pre-printed
> form — and burns his notes. The count was complete. The report isn't. And nothing tells you the
> difference.

**One genuine collection gap:** Logic Apps (`microsoft.logic/workflows`) really *is* excluded — it's
the first entry in that list. That one needs the query edited, not just a display template.

### 3.4 Scout was not read-only — now fixed

Scout POSTed `assessPatches` **once per VM and once per Arc machine, on every run**:

- `src/collect/Get-ScoutOperationalCollectorEnrichment.ps1:170` (VMs)
- `:178` (Arc machines)
- Enabled unconditionally at `src/collect/Start-ScoutGraphExtraction.ps1:78` — no operator switch

`assessPatches` is a **command**, not a query. It tells the machine to scan itself for missing
patches now. Azure classifies it as an `/action`, which is why the `Reader` role doesn't grant it.

**Proof it executed against real machines** — from the 2026-07-30 run log:

```
ArcServerOperationalData.PatchAssessment failed for '.../vm-test-vlan711': ARM returned status 409
```

**409 Conflict** = "an assessment is already running on this machine." Only obtainable if Scout
started one.

**Origin:** commit `48f822b`, 2026-02-24 — original Scout work, *not* inherited from the ARI fork.
It fed exactly two spreadsheet columns (`Pending Critical Patches`, `Pending Other Patches`) and was
carried through the v3 rebuild without anyone re-examining the verb. The wrong API was chosen for
the goal: `POST assessPatches` (*trigger a scan*) instead of reading the results Update Manager
already stores.

**The fix (implemented this session):** Azure Update Manager already writes its results into two
Resource Graph tables — `patchassessmentresources` (pending updates, 7-day retention) and
`patchinstallationresources` (installation history, 30-day retention) — both covering Azure VMs
*and* Arc machines. Scout now reads those.

Result: same report columns, **more** detail available than before (KB IDs, classifications, reboot
flags), **zero machines touched**, one tenant-wide query instead of one POST per machine, and plain
`Reader` becomes sufficient. Machines Update Manager hasn't assessed within 7 days now report
`NotAssessed` rather than a misleading zero.

> ⚠️ **KNOWN PAST DEFECT — assessments run before 2026-08-01 on a large estate scored truncated
> data.** Recorded here because the code is fixed but the consequence is historical and nobody who
> ran an assessment knows it applied to them.
>
> `Search-AzGraph` returns a single un-enumerated `PSResourceGraphResponse`. Four of Scout's six
> call sites wrapped the *invocation* — `@(Search-AzGraph @params)` — which collects the **wrapper**
> as one element rather than the rows. In the two paging loops, including `Invoke-Collect.ps1`
> (the assessment platform's **main** query loop), that made `$batch.Count` permanently 1, so
> `while ($batch.Count -eq 1000)` could never fire.
>
> **Every paged ARG query stopped after its first 1000 rows.** Measured against a simulated
> 2500-row, 3-page result: the old loop made **1 call and returned 1 object**; the corrected loop
> makes 3 calls and returns 2500 rows.
>
> It went unnoticed because the failure is second-order. The rows *inside* that first page were
> recovered by accidental enumeration further downstream, so output looked plausible and
> populated — the missing pages were simply never requested. Any estate holding more than 1000
> resources of a single type was scored against a silent subset.
>
> Fixed in `b07cb72`. **If you have an assessment result from before that commit against an estate
> of any size, re-run it.**

### 3.5 Nothing has ever been verified — *superseded 2026-08-01, see the run below*

> ✅ **First per-collector verification run, 2026-08-01 (AB#6843).** All **240** collectors were
> executed against tenant `d6fc73cf` as the **Reader-only** service principal, and every one of
> them carries an explicit verdict. The artifact is committed at
> `tests/fixtures/verification/baseline-2026-08-01.json` so a later run can be diffed against it.
>
> | Verdict | Count | Meaning |
> |---|---:|---|
> | **Rows** | **39** | Ran and produced data from real Azure |
> | **Empty** | 201 | Ran cleanly and produced nothing |
> | **Failed** | **0** | None threw |
>
> **Read the 201 correctly — it is not a failure count.** This estate holds 118 resources across
> 38 types and has **zero** Arc, **zero** Azure Local and **zero** Lighthouse footprint. A
> collector for a service nobody deployed here *should* return nothing. That is precisely why the
> row-count artifact carries three verdicts rather than two: this run proves a collector WORKS, but
> it can never prove one is broken, because absence of rows is only evidence when the resource type
> is known to be present. **The whole Hybrid category (15 collectors) remains unverifiable in this
> tenant**, and so does most of Databases, IoT, Analytics and Migration.
>
> **The run immediately earned its keep.** `Identity/RoleAssignments` and
> `Management/ResourceLocks` — two of the four collectors AB#6779 had just added — returned **0
> rows in a tenant that demonstrably has role assignments**. Their data comes from the ARG
> `authorizationresources` table, and the inventory pass queries eleven tables of which that is not
> one. Two of the four new collectors have no producer wired. Nothing in 2,394 passing tests could
> see that; one live run did. Tracked back on AB#6779.
>
> The three collectors fixed under AB#6767 also reported here: `Monitor/Outages` returned a row,
> confirming the call-ordering fix works against real data.


| Evidence class | Count | What it proves |
|---|---|---|
| Passes a golden test generated from its own definition | 174 | The interpreter is deterministic. Nothing about Azure. |
| Declared type observed in a real anonymised capture | 38 | The type string is real. No collector is ever run against that capture. |
| **Proven to emit correct rows from real Azure** | **39** *(was 0)* | See the verification run below |
| **Proven to emit ZERO rows, every run, every tenant** | **12** | Traced to specific defects. |
| Cannot emit on a default run (opt-in switches) | 20 | `entra/*` needs `-Scope All`; `devops/*` needs `-IncludeDevOps`. |
| Target a retired service | 4 | Dead weight. |

**At minimum 32 of 174 (18%) produced an empty worksheet on the 2026-07-30 run and could not have
done otherwise.** The other 142 are simply unknown.

**Why the test suite can't catch this:** `scripts/New-ScoutCollectorFixture.ps1` synthesises test
fixtures **from each collector definition's own AST**. `Hybrid/ArcSites` declares three resource
types that **do not exist in Azure** — the generator fabricates matching rows, the collector matches
them, the golden test passes forever. It would still pass if all 152 type strings were replaced with
gibberish.

**Among the 12 confirmed broken:** four Management collectors (CustomRoleDefinitions,
ManagementGroups, PolicyDefinitions, PolicySetDefinitions) gate on `-IncludeTenantWideResources`, **a
switch with no production caller anywhere in the repo**. This finally settles the long-running
ManagementGroups mystery — the permissions issue was the *second* problem; the first is that the
producer is never invoked at all.

**Evidence is destroyed by design:** `src/Invoke-AzureScout.ps1:1035` runs `Clear-AZSCCacheFolder`
unconditionally at the end of every run, deleting the only per-collector row-count evidence Scout
produces.

---

## 6. Coverage — service by service

Every Azure service from the portal, mapped to the Scout collector that covers it.

**Status:** ✅ **Have** — a collector exists · 🔲 **Need** — collectable, not built ·
⛔ **Not collectable** — not an ARM resource, so ARG-based collection cannot reach it

### AI + machine learning (21)

| Service | Scout collector | Status |
|---|---|---|
| Azure Machine Learning | AI/MachineLearning (+ MLComputes, MLDatasets, MLDatastores, MLEndpoints, MLModels, MLPipelines) | ✅ Have |
| Microsoft Foundry | AI/AIFoundryHubs, AI/AIFoundryProjects | ✅ Have |
| Azure OpenAI | AI/OpenAIAccounts, AI/OpenAIDeployments | ✅ Have |
| AI Search | AI/SearchServices, AI/SearchIndexes | ✅ Have |
| Bot Services | AI/BotServices | ✅ Have |
| Computer vision | AI/ComputerVision | ✅ Have |
| Content moderators | AI/ContentModerator | ✅ Have |
| Custom vision | AI/CustomVision | ✅ Have |
| Document Intelligence | AI/FormRecognizer | ✅ Have |
| Face APIs | AI/FaceAPI | ✅ Have |
| Immersive readers | AI/ImmersiveReader | ✅ Have |
| Language | AI/TextAnalytics | ✅ Have |
| Speech services | AI/SpeechService | ✅ Have |
| Translators | AI/Translator | ✅ Have |
| Anomaly detectors | AI/AppliedAIServices | ✅ Have |
| Metrics advisor | AI/AppliedAIServices | ✅ Have |
| Azure AI Video Indexer | — | 🔲 Need |
| Personalizers | — | 🔲 Need — `Microsoft.CognitiveServices` (`kind=Personalizer`). **Retired by Microsoft 2026-10-01**; collect only if estates still hold one | 

### Analytics (20)

| Service | Scout collector | Status |
|---|---|---|
| Azure Databricks | Analytics/Databricks | ✅ Have |
| Data Explorer clusters | Analytics/DataExplorerCluster | ✅ Have |
| Event Hubs | Analytics/EvtHub | ✅ Have |
| Log Analytics workspaces | Monitor/Workspaces | ✅ Have |
| Azure Synapse Analytics | Analytics/Synapse | ✅ Have |
| Stream Analytics jobs | Analytics/Streamanalytics | ✅ Have |
| *(Purview — Analytics adjacent)* | Analytics/Purview | ✅ Have |
| Data factories | — | 🔲 Need |
| HDInsight clusters | — | 🔲 Need |
| Analysis Services | — | 🔲 Need |
| Power BI Embedded | — | 🔲 Need |
| Stream Analytics clusters | — | 🔲 Need |
| Azure Synapse Analytics (private link hubs) | — | 🔲 Need |
| Data Shares · Data Share accounts | — | 🔲 Need |
| Data Lake Analytics | — | 🔲 Need *(service retired)* |
| Data Lake Storage Gen1 | Storage/DataLakeStoreGen1 | ✅ Have *(AB#6837 — service retired)* |
| Microsoft Graph Data Connect | — | 🔲 Need |
| Apache Kafka / Flink on Confluent | — | 🔲 Need *(marketplace ISV)* |
| Informatica IDMC | — | 🔲 Need *(marketplace ISV)* |
| Power BI | — | ⛔ Not collectable — Power BI service, not ARM |

### Compute (32)

| Service | Scout collector | Status |
|---|---|---|
| Virtual machines | Compute/VirtualMachine, Compute/VMOperationalData | ✅ Have |
| Virtual machine scale sets | Compute/VirtualMachineScaleSet | ✅ Have |
| Availability sets | Compute/AvailabilitySets | ✅ Have |
| Azure Virtual Desktop | Compute/AVD, AVDSessionHosts, AVDWorkspaces, AVDApplicationGroups, AVDScalingPlans, AVDApplications, AVDAzureLocal | ✅ Have |
| Cloud services (extended support) | Compute/CloudServices | ✅ Have |
| Container Apps | Containers/ContainerApp | ✅ Have |
| Container Apps Environments | Containers/ContainerAppEnv | ✅ Have |
| Kubernetes services | Containers/AKS | ✅ Have |
| *(Disks — listed under Storage)* | Compute/VMDisk | ✅ Have |
| Azure compute galleries | — | 🔲 Need |
| Images | — | 🔲 Need |
| Image templates | — | 🔲 Need |
| VM image definitions | — | 🔲 Need |
| VM image versions | — | 🔲 Need |
| VM application definitions | — | 🔲 Need |
| VM application versions | — | 🔲 Need |
| Community images | — | 🔲 Need |
| Restore Point Collections | — | 🔲 Need |
| Host groups | — | 🔲 Need |
| Proximity placement groups | — | 🔲 Need |
| SSH keys | — | 🔲 Need |
| Compute Fleet | — | 🔲 Need |
| Batch accounts | — | 🔲 Need |
| Azure Spring Apps | Web/SpringApps | ✅ Have *(AB#6836 — retiring 2028)* |
| Virtual instances for SAP solutions | — | 🔲 Need |
| BareMetal Instances | — | 🔲 Need |
| Lab accounts | DevOps/LabServices | ✅ Have *(AB#6741)* |
| Function App | Web/FunctionApps | ✅ Have *(AB#6836)* |
| Kubernetes services – Automatic | — | 🔲 Need — same ARM type as AKS, differs by config |
| SAP PubSub on Azure | — | 🔲 Need |
| Compute infrastructure | — | ⛔ Not collectable — portal view, not a resource |
| App Spaces | — | ⛔ Not collectable — portal experience |

### Containers (12)

| Service | Scout collector | Status |
|---|---|---|
| Kubernetes services | Containers/AKS | ✅ Have |
| Azure Red Hat OpenShift clusters | Containers/ARO | ✅ Have |
| Container registries | Containers/ContainerRegistries | ✅ Have |
| Container instances | Containers/ContainerGroups | ✅ Have |
| Container Apps | Containers/ContainerApp | ✅ Have |
| Container Apps Environments | Containers/ContainerAppEnv | ✅ Have |
| Kubernetes Fleet Manager | — | 🔲 Need |
| Container Apps Jobs | — | 🔲 Need |
| Service Fabric clusters | — | 🔲 Need |
| Service Fabric managed clusters | — | 🔲 Need |
| App Configuration | DevOps/AppConfiguration | ✅ Have *(AB#6741)* |
| Kubernetes services – Automatic | — | 🔲 Need |

### Databases (18)

| Service | Scout collector | Status |
|---|---|---|
| Azure SQL / SQL databases | Databases/SQLDB, Databases/SQLSERVER, Databases/SQLPOOL | ✅ Have |
| SQL managed instances | Databases/SQLMI, Databases/SQLMIDB | ✅ Have |
| SQL Server instances *(on VM)* | Databases/SQLVM | ✅ Have |
| Managed databases | Databases/SQLMIDB | ✅ Have |
| Azure Cosmos DB | Databases/CosmosDB | ✅ Have |
| Azure Cache for Redis | Databases/RedisCache | ✅ Have |
| Azure Managed Redis | Databases/RedisCache | ✅ Have |
| Azure Database for PostgreSQL flexible servers | Databases/POSTGREFlexible | ✅ Have |
| Azure Database for MySQL flexible servers | Databases/MySQLflexible | ✅ Have |
| Azure Database for MariaDB | Databases/MariaDB | ✅ Have |
| Azure Arc data controllers | Hybrid/ArcDataControllers | ✅ Have |
| SQL managed instances – Azure Arc | Hybrid/ArcSQLManagedInstances | ✅ Have |
| Azure Managed Instance for Apache Cassandra | — | 🔲 Need |
| Oracle Database@Azure | — | 🔲 Need |
| MongoDB Atlas | — | 🔲 Need *(marketplace ISV)* |
| Azure Database Migration Services | — | 🔲 Need |
| SQL Server stretch databases | — | 🔲 Need *(retired)* |

### DevOps (23)

| Service | Scout collector | Status |
|---|---|---|
| Application Insights | Monitor/AppInsights | ✅ Have |
| Monitor | Monitor/* | ✅ Have |
| API Management services | Integration/APIM | ✅ Have |
| Chaos Studio | DevOps/ChaosStudio | ✅ Have *(AB#6741)* |
| Azure Deployment Environments | DevOps/DeploymentEnvironments | ✅ Have *(AB#6741)* |
| Dev centers | DevOps/DevCenters | ✅ Have *(AB#6741)* |
| Projects | DevOps/DevCenters | ✅ Have *(AB#6741)* |
| Microsoft Dev Box | DevOps/DevBoxPools | ✅ Have *(AB#6741)* |
| Network connections | DevOps/DevCenterNetworkConnections | ✅ Have *(AB#6741)* |
| DevTest Labs | DevOps/DevTestLabs | ✅ Have *(AB#6741)* |
| Azure Lab Services | DevOps/LabServices | ✅ Have *(AB#6741)* |
| Azure Load Testing | DevOps/LoadTesting | ✅ Have *(AB#6741)* |
| Managed DevOps Pools | DevOps/ManagedDevOpsPools | ✅ Have *(AB#6741)* |
| Playwright Testing (Classic) | DevOps/PlaywrightTesting | ✅ Have *(AB#6741)* |
| API Connections | DevOps/ApiConnections | ✅ Have *(AB#6741)* |
| App Configuration | DevOps/AppConfiguration | ✅ Have *(AB#6741)* |
| Azure Native LambdaTest · Elastic · Plastic Cloud · New Relic | — | 🔲 Need *(marketplace ISV)* |
| Azure DevOps *(organizations, projects, pipelines, repositories, service connections, agent pools)* | DevOps/DevOpsProjects, DevOpsPipelines, DevOpsRepositories, DevOpsServiceConnections, DevOpsAgentPools *(via ADO REST, not ARM — relocated from `Management/`, AB#6828)* | ✅ Have — gated behind `-IncludeDevOps`, see §9 |
| GitHub | — | 🔲 Need — Scout has no GitHub integration; the row above was previously mislabeled "GitHub" while actually describing the five Azure DevOps REST collectors |

### General (10)

| Service | Scout collector | Status |
|---|---|---|
| Help + support | General/SupportTickets *(relocated from Management, AB#6838)* | ✅ Have |
| Reservations | General/Reservations *(owned)* + General/ReservationRecom *(recommendations)* | ✅ Have *(AB#6838)* |
| Quotas | General/Quotas | ✅ Have *(AB#6838)* — renders the `AZSC/VM/Quotas` envelope Scout has always fetched and never displayed |
| Subscriptions | Management/AllSubscriptions | ✅ Have |
| Cost Management + Billing | — | 🔲 Need — see §9 billing gates |
| Resources · Resource Manager | — | ⛔ Not collectable — the platform itself |
| Operations center · Preview features · Quickstart Center · Pass services | — | ⛔ Not collectable — portal views |
| Service Health | — | ⛔ Not collectable — a data plane, not a resource |

### Hybrid + multicloud (18)

| Service | Scout collector | Status |
|---|---|---|
| Azure Arc *(servers)* | Hybrid/ARCServers, ArcExtensions, ArcGateways, ArcServerOperationalData | ✅ Have |
| Azure Arc data controllers | Hybrid/ArcDataControllers | ✅ Have |
| SQL managed instances – Azure Arc | Hybrid/ArcSQLManagedInstances | ✅ Have |
| SQL Server databases *(Arc)* | Hybrid/ArcSQLServers | ✅ Have |
| Azure Local / Azure Stack HCI | Hybrid/Clusters, LogicalNetworks, StorageContainers, GalleryImages, MarketplaceGalleryImages, VirtualMachines, ArcSites | ✅ Have |
| Azure VMware Solution | Compute/VMWare | ✅ Have |
| *(Arc Kubernetes)* | Hybrid/ArcKubernetes | ✅ Have |
| *(Arc resource bridge)* | Hybrid/ArcResourceBridge | ✅ Have |
| Virtual WANs | Networking/VirtualWAN | ✅ Have |
| ExpressRoute circuits | Networking/ExpressRoute | ✅ Have |
| Microsoft Defender for Cloud | Security/Defender* | ✅ Have |
| Azure Operator Nexus | — | 🔲 Need |
| Azure Edge Hardware Center | — | 🔲 Need |
| Azure Network Function Manager – Devices | — | 🔲 Need |
| Site recovery – Azure Arc | — | 🔲 Need |
| Microsoft Sentinel | — | 🔲 Need |
| Microsoft Purview Cloud Connect Health | — | 🔲 Need |
| Microsoft Entra ID | Identity/* *(Graph, `-Scope All`)* | ✅ Have |

### Identity (18)

| Service | Scout collector | Status |
|---|---|---|
| Microsoft Entra ID | Identity/Users, Groups, Domains, Licensing | ✅ Have *(Graph)* |
| App registrations | Identity/AppRegistrations | ✅ Have *(Graph)* |
| Enterprise applications | Identity/ServicePrincipals | ✅ Have *(Graph)* |
| Managed Identities | Identity/ManagedIds | ✅ Have *(ARM)* |
| Microsoft Entra Privileged Identity Management | Identity/PIMAssignments | ✅ Have *(Graph)* |
| Microsoft Entra ID Protection | Identity/RiskyUsers | ✅ Have *(Graph)* |
| Microsoft Entra ID Security | Identity/ConditionalAccess, NamedLocations, SecurityPolicies | ✅ Have *(Graph)* |
| *(Administrative units)* | Identity/AdminUnits | ✅ Have *(Graph)* |
| *(Directory roles)* | Identity/DirectoryRoles | ✅ Have *(Graph)* |
| Microsoft Entra Domain Services | — | 🔲 Need *(ARM: `microsoft.aad/domainservices`)* |
| Azure AD B2C | — | 🔲 Need *(ARM: `microsoft.azureactivedirectory/b2cdirectories`)* |
| Access Connector for Azure Databricks | — | 🔲 Need |
| Identity Governance | — | 🔲 Need *(Graph: entitlement management)* |
| External Identities · External Configuration Tenant | — | 🔲 Need *(Graph)* |
| Guest Usages | — | 🔲 Need *(Graph)* |
| Verified ID | — | ⛔ Not collectable — separate service, no ARM/Graph inventory surface |
| Agent IDs | — | ⛔ Not collectable — preview, no documented inventory API |
| RBAC Tenants | — | ⛔ Not collectable — portal view |
| Microsoft Entra Cloud Health | — | ⛔ Not collectable — portal experience |

### Integration (15)

| Service | Scout collector | Status |
|---|---|---|
| API Management services | Integration/APIM | ✅ Have |
| Service Bus | Integration/ServiceBUS | ✅ Have |
| Event Hubs | Analytics/EvtHub | ✅ Have |
| **Logic apps** | Integration/LogicApps | ✅ Have *(AB#6836 — the `microsoft.logic/workflows` exclusion was removed from the ARG query)* |
| Integration accounts | Integration/IntegrationAccounts | ✅ Have *(AB#6836)* |
| Logic Apps Custom Connector | Integration/LogicAppsCustomConnectors | ✅ Have *(AB#6836)* |
| API Connections | DevOps/ApiConnections | ✅ Have *(AB#6741)* |
| Event Grid | Integration/EventGrid | ✅ Have *(AB#6836)* |
| Event Hubs Clusters | Integration/EventHubClusters | ✅ Have *(AB#6836)* |
| Relays | Integration/Relays | ✅ Have *(AB#6836)* |
| App Configuration | DevOps/AppConfiguration | ✅ Have *(AB#6741)* |
| Azure API for FHIR | Integration/HealthDataServices | ✅ Have *(AB#6836)* |
| FHIR service | Integration/HealthDataServices | ✅ Have *(AB#6836)* |
| Mobile Data Services workspaces | — | 🔲 Need |
| Apache Kafka / Flink on Confluent | — | 🔲 Need *(marketplace ISV)* |

### Internet of Things (19)

| Service | Scout collector | Status |
|---|---|---|
| IoT Hub | IoT/IOTHubs | ✅ Have |
| Azure Cosmos DB | Databases/CosmosDB | ✅ Have |
| Azure Data Explorer Clusters | Analytics/DataExplorerCluster | ✅ Have |
| Event Hubs | Analytics/EvtHub | ✅ Have |
| Stream Analytics jobs | Analytics/Streamanalytics | ✅ Have |
| Azure Synapse Analytics | Analytics/Synapse | ✅ Have |
| Azure Machine Learning | AI/MachineLearning | ✅ Have |
| Storage accounts | Storage/StorageAccounts | ✅ Have |
| Azure IoT Hub Device Provisioning Service | IoT/DeviceProvisioningServices | ✅ Have *(AB#6837)* |
| IoT Central Applications | IoT/IoTCentral | ✅ Have *(AB#6837)* |
| Device Update for IoT Hubs | IoT/DeviceUpdate | ✅ Have *(AB#6837)* |
| Azure Digital Twins | IoT/DigitalTwins | ✅ Have *(AB#6837)* |
| Microsoft Defender for IoT | IoT/DefenderForIoT | ✅ Have *(AB#6837)* |
| Azure Maps Accounts | IoT/Maps | ✅ Have *(AB#6837)* |
| Azure Maps Creator Resources | IoT/Maps | ✅ Have *(AB#6837)* |
| Azure Stack Edge / Data Box Gateway | Migration/StackEdge | ✅ Have *(AB#6831)* |
| Function App | Web/FunctionApps | ✅ Have *(AB#6836)* |
| Logic apps | Integration/LogicApps | ✅ Have *(AB#6836)* |
| Power Platform | — | ⛔ Not collectable — Power Platform admin API, not ARM |

### Management and governance (34)

| Service | Scout collector | Status |
|---|---|---|
| Advisor | Management/AdvisorScore | ✅ Have |
| Automation accounts | Management/AutomationAccounts | ✅ Have |
| Update Center | Management/MaintenanceConfigurations | ✅ Have |
| Azure Lighthouse | Management/LighthouseDelegations | ✅ Have |
| Recovery Services vaults | Management/RecoveryVault | ✅ Have |
| Backups *(policies only)* | Management/Backup | ✅ Have — **protected items not collected** |
| Diagnostic settings | Monitor/ResourceDiagnosticSettings | ✅ Have |
| *(Policy definitions / set definitions)* | Management/PolicyDefinitions, PolicySetDefinitions | ✅ Have — **but gated behind a switch with no production caller (§10)** |
| *(Management groups)* | Management/ManagementGroups | ✅ Have — **same switch defect** |
| *(Custom role definitions)* | Management/CustomRoleDefinitions | ✅ Have — **same switch defect** |
| **Policy** *(assignments)* | — | 🔲 Need — **ingested by `Import-Governance`, never rendered** |
| **Cost Management** *(budgets)* | — | 🔲 Need — **ingested, never rendered** |
| *(Resource locks)* | — | 🔲 Need — **ingested, never rendered** |
| *(RBAC role assignments)* | — | 🔲 Need — **ingested, never rendered** |
| Backup vaults *(DataProtection)* | — | 🔲 Need |
| Subscriptions | — | 🔲 Need |
| Template specs | — | 🔲 Need — **excluded from the ARG query** |
| Deployment Scripts | — | 🔲 Need |
| Blueprints | — | 🔲 Need *(deprecated)* |
| Capacity Reservation Groups | — | 🔲 Need |
| Managed applications center | — | 🔲 Need |
| Automanage | — | 🔲 Need |
| Guest Assignments | — | 🔲 Need |
| Azure Resource Mover | — | 🔲 Need |
| Customer Lockbox for Microsoft Azure | — | 🔲 Need |
| Azure Monitor for SAP solutions | — | 🔲 Need |
| Virtual instances for SAP solutions | — | 🔲 Need |
| Microsoft Entra Domain Services | — | 🔲 Need |
| Azure Native Qumulo Scalable File Service | — | 🔲 Need *(marketplace ISV)* |
| Resiliency | — | ⛔ Not collectable — portal view |
| Change Analysis | — | ⛔ Not collectable — a data plane |
| Operations center · Azure Capital admin center | — | ⛔ Not collectable — portal views |
| Intune · Intune for Education · Managed Desktop · Universal Print | — | ⛔ Not collectable — Microsoft 365 services, not ARM |

### Migration (5)

| Service | Scout collector | Status |
|---|---|---|
| Recovery Services vaults | Management/RecoveryVault | ✅ Have |
| Azure Migrate | Migration/AzureMigrateProjects, AzureMigrateAssessments, AzureMigrateDiscoverySites | ✅ Have *(AB#6830)* |
| Azure Database Migration Services | Migration/DatabaseMigrationServices | ✅ Have *(AB#6831)* |
| Azure Data Box | Migration/DataBox | ✅ Have *(AB#6831)* |
| Azure Stack Edge / Data Box Gateway | Migration/StackEdge | ✅ Have *(AB#6831)* |

### Monitor (24)

| Service | Scout collector | Status |
|---|---|---|
| Log Analytics workspaces | Monitor/Workspaces, LAWorkspaceSolutions, LAWorkspaceLinkedServices, LAWorkspaceSavedSearches | ✅ Have |
| Application Insights | Monitor/AppInsights, AppInsightsWebTests, AppInsightsProactiveDetection, AppInsightsAvailabilityTests | ✅ Have |
| Alerts | Monitor/MetricAlertRules, ActivityLogAlertRules, ScheduledQueryRules, SmartDetectorAlertRules | ✅ Have |
| *(Action groups)* | Monitor/ActionGroups | ✅ Have |
| Autoscale | Monitor/AutoscaleSettings | ✅ Have |
| Data collection rules | Monitor/DataCollectionRules | ✅ Have |
| Data collection endpoints | Monitor/DataCollectionEndpoints | ✅ Have |
| Azure Workbooks | Monitor/MonitorWorkbooks | ✅ Have |
| Diagnostic settings | Monitor/ResourceDiagnosticSettings | ✅ Have |
| Network Watcher | Networking/NetworkWatchers | ✅ Have |
| *(Private link scopes)* | Monitor/MonitorPrivateLinkScopes | ✅ Have |
| *(Outages / Resource Health)* | Monitor/Outages | ✅ Have — **broken by a call-ordering defect (§5.5)** |
| Azure Monitor workspaces | — | 🔲 Need |
| Azure Managed Grafana | — | 🔲 Need |
| Managed Prometheus | — | 🔲 Need |
| Log Analytics dedicated clusters | — | 🔲 Need |
| Log Analytics query packs | — | 🔲 Need |
| Database watchers | — | 🔲 Need |
| Azure Monitor for SAP solutions | — | 🔲 Need |
| Azure Native Dynatrace · Elastic · Plastic Cloud | — | 🔲 Need *(marketplace ISV)* |
| Metrics · Activity log | — | ⛔ Not collectable — data planes, not resources |
| Change Analysis · Observability agents · Service Health · Monitor | — | ⛔ Not collectable — portal views |

### Networking (34)

| Service | Scout collector | Status |
|---|---|---|
| Virtual networks | Networking/VirtualNetwork, vNETPeering | ✅ Have |
| Network security groups | Networking/NetworkSecurityGroup | ✅ Have |
| Network interfaces | Networking/NetworkInterface | ✅ Have |
| Public IP addresses | Networking/PublicIP | ✅ Have |
| Load balancers | Networking/LoadBalancer | ✅ Have |
| Application gateways | Networking/ApplicationGateways | ✅ Have |
| Firewalls | Networking/AzureFirewall | ✅ Have |
| Bastions | Networking/BastionHosts | ✅ Have |
| NAT gateways | Networking/NATGateway | ✅ Have |
| Route tables | Networking/RouteTables | ✅ Have |
| DNS zones | Networking/PublicDNS | ✅ Have |
| Private DNS zones | Networking/PrivateDNS | ✅ Have |
| Private Link | Networking/PrivateEndpoint | ✅ Have |
| Connections | Networking/Connections | ✅ Have |
| ExpressRoute circuits | Networking/ExpressRoute | ✅ Have |
| Virtual network gateways | Networking/VirtualNetworkGateways | ✅ Have |
| Virtual WANs | Networking/VirtualWAN | ✅ Have |
| Network Watcher | Networking/NetworkWatchers | ✅ Have |
| Front Doors | Networking/Frontdoor | ✅ Have — **classic only; modern `microsoft.cdn/profiles` missing** |
| *(Traffic Manager)* | Networking/TrafficManager | ✅ Have |
| **Web Application Firewall policies (WAF)** | Security/WafPolicies | ✅ Have *(AB#6837 — Application Gateway, Front Door and CDN policy types)* |
| **Firewall Policy** | — | 🔲 Need |
| **Front Door and CDN profiles** *(modern)* | — | 🔲 Need |
| DDoS protection plans | Security/DdosProtectionPlans | ✅ Have *(AB#6837)* |
| Network managers | — | 🔲 Need |
| IP Groups | — | 🔲 Need |
| Custom IP Prefixes | — | 🔲 Need |
| Public IP Prefixes | — | 🔲 Need |
| DNS private resolvers | — | 🔲 Need |
| Local network gateways | — | 🔲 Need |
| ExpressRoute traffic collectors | — | 🔲 Need |
| Peerings · Peering Service | — | 🔲 Need |
| Application security groups | Security/ApplicationSecurityGroups | ✅ Have *(AB#6837)* |
| Microsoft Connected Cache | — | 🔲 Need |
| Networking monitoring and management · Monitor · NSGWatch | — | ⛔ Not collectable — portal views |

### Security (22)

| Service | Scout collector | Status |
|---|---|---|
| Key vaults | Security/Vault | ✅ Have |
| Microsoft Defender for Cloud | Security/DefenderAlerts, DefenderAssessments, DefenderPricing, DefenderSecureScore | ✅ Have |
| Firewalls | Networking/AzureFirewall | ✅ Have |
| Application gateways | Networking/ApplicationGateways | ✅ Have |
| Log Analytics workspaces | Monitor/Workspaces | ✅ Have |
| Microsoft Entra ID · ID Security · PIM | Identity/* | ✅ Have *(Graph)* |
| **Microsoft Sentinel** | Security/Sentinel | ✅ Have *(AB#6837)* |
| **Key Vault keys / secrets / certificates** | `Get-ScoutArmChildResource` datasets `KeyVaultSecrets`, `KeyVaultKeys` | ✅ Have *(AB#6837)* — **control plane only: metadata and `attributes.exp`, never a secret value. Certificate expiry arrives under secrets, identified by `contentType`; there is no ARM list endpoint for certificates** |
| Azure Key Vault Managed HSM | Security/ManagedHSM | ✅ Have *(AB#6837)* |
| Azure Cloud HSM | Security/CloudHSM | ✅ Have *(AB#6837)* |
| Application security groups | Security/ApplicationSecurityGroups | ✅ Have *(AB#6837)* |
| Web Application Firewall policies (WAF) | Security/WafPolicies | ✅ Have *(AB#6837)* |
| DDoS protection plans | Security/DdosProtectionPlans | ✅ Have *(AB#6837)* |
| Confidential Ledgers | Security/ConfidentialLedger | ✅ Have *(AB#6837)* |
| Artifact Signing Accounts | Security/ArtifactSigning | ✅ Have *(AB#6837)* |
| Microsoft Defender for IoT | IoT/DefenderForIoT | ✅ Have *(AB#6837)* |
| Microsoft Entra Domain Services | Security/EntraDomainServices | ✅ Have *(AB#6837)* |
| App Compliance Automation Tool | Security/AppComplianceAutomation | ✅ Have *(AB#6837)* |
| Multifactor authentication | — | ⛔ Not collectable — Entra config, not an inventoried resource |

### Storage (17)

| Service | Scout collector | Status |
|---|---|---|
| Storage accounts | Storage/StorageAccounts | ✅ Have |
| Disks | Compute/VMDisk | ✅ Have |
| Azure NetApp Files | Storage/NetApp | ✅ Have |
| **Blob containers** *(child)* | `Get-ScoutArmChildResource` dataset `StorageBlobContainers` | ✅ Have *(AB#6834)* — carries `publicAccess`, which is what makes anonymous exposure detectable |
| **File shares** *(child)* | `Get-ScoutArmChildResource` dataset `StorageFileShares` | ✅ Have *(AB#6834)* |
| **Lifecycle / management policies** *(child)* | `Get-ScoutArmChildResource` dataset `StorageLifecyclePolicies` | ✅ Have *(AB#6834)* |
| Snapshots | Storage/Snapshots | ✅ Have *(AB#6837)* |
| Disk Encryption Sets | Storage/DiskEncryptionSets | ✅ Have *(AB#6837)* |
| Elastic SANs | Storage/ElasticSan | ✅ Have *(AB#6837)* |
| Storage Sync Services *(File Sync)* | Storage/StorageSync | ✅ Have *(AB#6837)* |
| Azure Data Box | Migration/DataBox | ✅ Have *(AB#6831)* |
| Azure Stack Edge / Data Box Gateway | Migration/StackEdge | ✅ Have *(AB#6831)* |
| Azure Edge Hardware Center | Storage/EdgeHardwareCenter | ✅ Have *(AB#6837)* |
| Data Lake Storage Gen1 | Storage/DataLakeStoreGen1 | ✅ Have *(AB#6837 — service retired 2024-02-29; collected so a lingering account is visible)* |
| Azure Native Pure Storage · Qumulo | Storage/PartnerStorage | ✅ Have *(AB#6837)* |
| Azure Storage Locker | — | 🔲 Need |
| Storage browser · Data Accesses · Data resources | — | ⛔ Not collectable — portal views |

### Web and Mobile (22)

| Service | Scout collector | Status |
|---|---|---|
| App Services | Web/APPServices | ✅ Have |
| App Service plans | Web/APPServicePlan | ✅ Have |
| Application Insights | Monitor/AppInsights | ✅ Have |
| API Management services | Integration/APIM | ✅ Have |
| Container Apps | Containers/ContainerApp | ✅ Have |
| AI Search | AI/SearchServices | ✅ Have |
| **App Service Environments** | Web/AppServiceEnvironments | ✅ Have *(AB#6836)* |
| **Static Web Apps** | Web/StaticWebApps | ✅ Have *(AB#6836)* |
| **Function App** | Web/FunctionApps | ✅ Have *(AB#6836)* — same ARM type as App Services, split by `kind` |
| **Deployment slots** | Web/DeploymentSlots | ✅ Have *(AB#6836)* |
| App Service Certificates | Web/AppServiceCertificates | ✅ Have *(AB#6836)* |
| App Service Domains | Web/AppServiceDomains | ✅ Have *(AB#6836)* |
| App Configuration | DevOps/AppConfiguration | ✅ Have *(AB#6741)* |
| API Connections | DevOps/ApiConnections | ✅ Have *(AB#6741)* |
| SignalR | Web/SignalR | ✅ Have *(AB#6836)* |
| Web PubSub Service · Web PubSub for Socket.IO | Web/WebPubSub | ✅ Have *(AB#6836)* |
| Communication Services | Web/CommunicationServices | ✅ Have *(AB#6836)* |
| Email Communication Services | Web/CommunicationServices | ✅ Have *(AB#6836)* |
| Notification Hubs | Web/NotificationHubs | ✅ Have *(AB#6836)* |
| Fluid Relay | Web/FluidRelay | ✅ Have *(AB#6836)* |
| Azure Spring Apps | Web/SpringApps | ✅ Have *(AB#6836 — retiring 2028)* |
| Logic apps | Integration/LogicApps | ✅ Have *(AB#6836)* |

---

### Summary — coverage by category

Counted from the tables above, not from a separate source. "Listed" is how many services this
section enumerates; "Portal" is Microsoft's own count from §12. Where they differ, this section is
**incomplete** — see DQ5.

**Recounted 2026-07-31 after Epic AB#6741**, mechanically from the tables above (count of ✅/🔲/⛔
rows per section) rather than by hand. The "was" column is the figure this section carried before
the Epic, so the movement is visible rather than asserted.

| Category | Listed | Portal | ✅ Have | 🔲 Need | ⛔ Not collectable | Have % | *(was)* |
|---|---:|---:|---:|---:|---:|---:|---:|
| AI + machine learning | 18 | 21 | 16 | 2 | 0 | 89% | 94% |
| Analytics | 20 | 20 | 8 | 11 | 1 | 40% | 35% |
| Compute | 32 | 32 | 12 | 18 | 2 | 38% | 28% |
| Containers | 12 | 12 | 7 | 5 | 0 | 58% | 50% |
| Databases | 17 | 18 | 12 | 5 | 0 | 71% | 71% |
| DevOps | 19 | 23 | 17 | 2 | 0 | 89% | 17% |
| General | 8 | 10 | 4 | 1 | 3 | 50% | 13% |
| Hybrid + multicloud | 18 | 18 | 12 | 6 | 0 | 67% | 67% |
| Identity | 19 | 18 | 9 | 6 | 4 | 47% | 47% |
| Integration | 15 | 15 | 13 | 2 | 0 | 87% | 20% |
| Internet of Things | 19 | 19 | 18 | 0 | 1 | 95% | 42% |
| Management and governance | 33 | 34 | 10 | 19 | 4 | 30% | 30% |
| Migration | 5 | 5 | 5 | 0 | 0 | 100% | 20% |
| Monitor | 22 | 24 | 12 | 8 | 2 | 55% | 55% |
| Networking | 35 | 34 | 23 | 11 | 1 | 66% | 57% |
| Security | 19 | 22 | 18 | 0 | 1 | 95% | 32% |
| Storage | 17 | 17 | 15 | 1 | 1 | 88% | 18% |
| Web and Mobile | 22 | 22 | 22 | 0 | 0 | 100% | 27% |
| **Total** | **350** | **364** | **233** | **97** | **20** | **67%** | **41%** |

**AI moved DOWN, from 94% to 89%, and nothing about it got worse.** The category gained a row --
`Personalizers`, added when DQ5 was closed -- so the denominator grew by one while the numerator did
not. It is the only category whose percentage fell, and it is an arithmetic artefact, recorded here
rather than quietly smoothed over.

**Correction (AB#6828, 2026-08-01): the five Azure DevOps REST collectors were physically misfiled
under `manifests/collectors/Management/` and the DevOps row above (line "GitHub") mislabeled them.**
They have been relocated to `manifests/collectors/DevOps/` -- Scout's folder-equals-category
convention (`Get-ScoutCollector.ps1`) now matches what this table already implied. The row that read
"GitHub | Management/DevOps\* | ⛔ Not collectable" was wrong on every count: the service is Azure
DevOps, not GitHub, the collector lives under `DevOps/` now, and it *is* collected (behind
`-IncludeDevOps`) -- Scout genuinely has no GitHub integration, which is now its own, honest 🔲 row.
DevOps's Have count rises from 16 to 17 (Listed 18→19, since the one mislabeled row split into two).
**Management's own enumeration (§6, 34-service table) never listed these five collectors** -- the
audit already treated them as DevOps services, not Management ones -- so Management's Have/Need
figures are unchanged; only the codebase needed to catch up to what this document already claimed.

**Three things this table says that the percentages alone do not:**

1. **67% is the honest headline** — 233 of 350 enumerated services have a collector. Measured only
   against services that *can* be collected (excluding the 20 ⛔), it is **71%**.
2. **The "Listed" and "Portal" columns differ for an arithmetic reason, not a coverage one.**
   A single row here often carries several portal services — `Microsoft Entra ID · ID Security ·
   PIM` is one row and three portal entries; the four Azure Native ISV services (LambdaTest,
   Elastic, Plastic Cloud, New Relic) share one row in both DevOps and Monitor. Counting rows
   therefore undercounts services. **A category-by-category diff against §2 was run on 2026-07-31**
   and found exactly **one genuinely absent service: `Personalizers`** (AI + machine learning),
   now listed. Every other portal entry appears somewhere in these tables, alone or inside a
   collapsed row. That closes DQ5 — the shortfall was in the arithmetic, not the coverage.
3. **Two categories exceed the portal count.** *Identity* (19 vs 18) and *Networking* (35 vs 34)
   each keep one row Microsoft has merged — `Front Doors (classic)` is held separate because
   Scout's only Front Door collector targets the classic type and merging it would hide the
   2027-03-31 retirement finding. Nothing was padded.

**What "Have" does and does not mean.** A ✅ means *a collector targets this service*. It does not
mean the collector returns rows, that it returns the right fields, or that any rule reads them. 12
collectors under a ✅ are **provably broken** (§9 note 3), and none of the 242 has ever been verified
against real Azure (§5.5) — **including all 62 added by AB#6741**, whose resource-type strings were
taken from the ARM template reference and pinned by `tests/ServiceCollectorTypes`-style assertions
in `tests/ServiceCoverage.Tests.ps1`, but which no live run has yet confirmed return rows. Read §7
immediately after this section — a large share of what a
customer actually asks about is not a "service" at all and can never appear in this table.

> **⚠️ Found and FIXED 2026-07-31 while building AB#6741 — it applied to the whole estate, not
> just the new collectors.** A collector preamble that read a `properties` key Azure did not return
> **threw** under `Set-StrictMode -Version Latest`, and because the row script is one statement the
> run lost that collector's entire output — not one row, all of them. Probed against a realistic
> sparse Resource Graph row (every projected column present, most `$null`, `properties` holding
> only the keys that resource actually has), `Integration/APIM` — shipped since v1 — failed on
> `virtualNetworkType` exactly as the newly added `Integration/LogicApps` failed on
> `integrationAccount`.
>
> **AB#6839 — fixed.** The row, filter and setup scopes now run at `Set-StrictMode -Version 1.0`,
> which still errors on an uninitialised variable (the protection AB#5671/5672 bought) but reads a
> missing property as `$null`. One change in `Invoke-ScoutDeclarativeCollector`, uniform across all
> 242 collectors, and **all 242 golden records are byte-unchanged** — the fix alters no existing
> output. `tests/Collector.SparsePayload.Tests.ps1` builds its estate by *removing* properties and
> is proven non-vacuous: the same probe threw for four collectors before the change and returns
> rows for all four after.
>
> **AB#6844 — the second class, also fixed.** 75 sites across 46 definitions called a string method
> directly on a payload value (`….subnetResourceId.split("/")[8]`). That is a null *method call* on
> the `$null` the fix above produces, and no StrictMode setting prevents it. All 75 now route
> through the existing `Get-AZSCIdSegment` helper, which returns `$null` for an absent id or an
> out-of-range index and the identical segment otherwise — **all 236 goldens byte-unchanged**.
>
> Extending the sparse-payload suite to cover the guarded collectors then exposed **two more
> pre-existing failures of the same family**: `Analytics/Databricks` cast `[datetime]$null` on a
> workspace whose deployment never completed, and `Networking/NetworkSecurityGroup` assigned
> `$FinalNICs`/`$FinalSubs` only inside conditional branches, so an NSG associated with neither a
> NIC nor a subnet tripped StrictMode's uninitialised-variable check. Both lost the whole
> worksheet; both fixed.
>
> **AB#6845 — a fourth class, and the most dangerous, because it does not throw.** A collector that
> emits one row per child produces **no row at all** when the child collection is absent, so the
> parent resource *disappears from the worksheet*: no error, no warning, just a plausible smaller
> report. **43 collectors have a child row loop and 41 never set `EmitNullWhenEmpty`**, the key
> that exists to emit the parent anyway. `Containers/AKS` was fixed on the spot — a cluster
> vanishing from an inventory is indefensible — and the rest were then read one by one, because
> the answer turns on whether the parent has meaning without its children.
>
> **That reading is now done and the class is closed.** Of the 50 child row loops in the estate,
> **26 never had the defect**: their source variable is assigned through a conditional with a
> non-empty fallback (`$Auths = if(...){$data.authorizations}else{'0'}`), so the loop always runs at
> least once. **18 loops across 15 collectors did have it and are fixed.** **Three are deliberately
> left unguarded**, because there the row IS the child rather than the parent — both `General/Quotas`
> loops (the parent is a synthetic quota envelope whose every column is read off the loop variable)
> and `Networking/vNETPeering`'s peering loop (that worksheet inventories peerings; an unpeered VNet
> belongs on the Virtual Networks sheet, where it already appears).
>
> **The initial guess about which collectors mattered was wrong in both directions**, which is the
> argument for reading rather than sweeping. The NSG loop cited above as an example of one that
> should NOT emit a parent row turned out to need no change at all — it already had the sentinel
> idiom. Meanwhile `Containers/ContainerAppEnv` fanned out over `workloadProfiles`, absent on every
> **Consumption-plan** environment — the default — so this was never an edge case there:
> those environments were simply missing from the report. `Compute/AvailabilitySets` computed
> `Orphaned = $true` for a set with no VMs and then dropped the row, making the one condition the
> collector exists to flag the one condition it could never report.
>
> Reaching previously unreachable code exposed two more defects behind it. `Monitor/Outages` and
> `Management/AdvisorScore` each cast a payload value straight to `[datetime]`, which throws on
> `$null`; the row had been dropped before the cast was reached. And `Networking/VirtualNetwork`
> carried a switch whose `Default` branch was a bare `$null` — a harmless no-op in the original
> imperative collector, but under the interpreter the row script's output stream IS the row set, so
> it wrote a **phantom null row**. Twelve of them were sitting in its committed golden record.
>
> **Every one of these was found by widening the test, not by reading the code** — which is the
> argument for AB#6840.
>
> **No test in this repository could have caught either**, which is why they survived. The fixture
> generator derives its estate *from the collector's own expressions*, so every path a collector
> reads is present by construction — the same structural blindness §5.5 and AB#6444 describe for
> fabricated resource types, extended from "the type does not exist" to "the payload is sparse".
> That blindness is what **Feature AB#6840** exists to close.

**Not every ✅ is an ARM query.** Whole blocks come from non-ARM surfaces: Identity's from Microsoft
Graph (`entra/…` pseudo-types), DevOps' from the Azure DevOps REST API (`devops/…`), and Security's
Defender rows plus most of Management and governance's from synthetic `AZSC/…` collectors reading
REST sweeps. Those need permissions §9 grants through entirely different systems.
### Notes on the portal categories

- **AVD (`Microsoft.DesktopVirtualization`) is under Compute** — it is not a separate category, and
  proposing "Virtual Desktop" as a new one was wrong.
- **Logic Apps is under Integration** — Scout's thinnest category by far.
- **Networking (34) and Management and governance (34) are the largest**; **Migration (5) is the
  smallest** and Scout collects none of it.
- The portal list is per-tenant and reflects what is available to that tenant — counts may differ
  slightly elsewhere, but the **category names and structure are Microsoft's**.

---

## 7. The gaps the service list cannot show

**Read this straight after §6.** The portal's All services page lists *services*. A large share of what
Scout is missing is **not a service** — it is a child resource, a tenant-level construct, or
configuration attached to something else. None of it appears on any service list, in this document
or in the portal, so a per-service table marks the parent ✅ and the gap disappears.

These are the ones that matter most, because they are where the actual findings live.

### Child resources — the parent is collected, the contents are not

| Missing | Lives under | Consequence |
|---|---|---|
| ~~**Backup protected items**~~ | Recovery Services vaults ✅ | **CLOSED (AB#6833).** Recovery Services protected items come from the `recoveryservicesresources` ARG table; Backup vault instances from the new `BackupInstances` ARM-child dataset. `XR-BKP-01` answers "which VMs have no backup" directly. |
| ~~**Key Vault keys, secrets, certificates**~~ | Key vaults ✅ | **CLOSED (AB#6837)** — control plane only. `attributes.exp` gives expiry for secrets and keys; certificate expiry arrives on the certificate's backing secret, identified by `contentType`. No secret VALUE is ever read. |
| ~~**Blob containers**~~ | Storage accounts ✅ | **CLOSED (AB#6834)** — `StorageBlobContainers` carries `publicAccess`, so anonymous exposure is detectable. |
| ~~**File shares**~~ | Storage accounts ✅ | **CLOSED (AB#6834)** — `StorageFileShares`. |
| ~~**Lifecycle / management policies**~~ | Storage accounts ✅ | **CLOSED (AB#6834)** — `StorageLifecyclePolicies`. An account with no policy 404s, and the absence is the finding. |
| **Compute galleries, images, restore points, dedicated hosts, PPGs, capacity reservations** | Virtual machines ✅ | Still missing. **Snapshots and disk encryption sets are now collected** (AB#6837), and `XR-SNP-01` produces the orphaned-snapshot finding; the rest of this row is untouched. |
| **AKS node pools** | Kubernetes services ✅ | Cluster-level only; per-pool sizing and version invisible. |
| **Deployment slots** | App Services ✅ | Slot configuration drift undetectable. |
| **SQL failover groups** | Azure SQL ✅ | HA posture unreportable. |
| **Virtual WAN hubs, VPN gateways, ExpressRoute gateways** | Virtual WANs ✅ | The WAN topology is unreadable. |

### Configuration attached to resources — never a "service"

| Missing | What it answers | Status |
|---|---|---|
| **RBAC role assignments** | **"Who has Owner"** — table stakes for any assessment | **Already collected by `Import-Governance`, never rendered** |
| **Resource locks** | What is protected from deletion | **Already collected, never rendered** |
| **Policy assignments** | Which policies are actually applied, and where | **Already collected, never rendered** |
| **Budgets** | Cost guardrails in place | **Already collected, never rendered** |
| **Diagnostic settings** | Whether logging is configured | Collector exists but targets a type ARG does not index |
| **NSG flow logs, connection monitors** | Network observability config | Not collected |

> **Four of these are already in memory on every run.** The data is fetched, shaped, and then no
> collector writes it to a sheet. Rendering them is the cheapest coverage work in this document.

### Tenant-level constructs — above the subscription, so never a "service"

| Missing | Status |
|---|---|
| **Management groups** | Collector exists — **gated behind `-IncludeTenantWideResources`, a switch with no production caller** |
| **Custom role definitions** | Same dead switch |
| **Policy definitions / set definitions** | Same dead switch |
| **Subscriptions** | Enrichment metadata only, not a first-class inventory row |
| **Resource groups** | Not collected as rows — no empty/untagged RG analysis |

### Cross-resource questions nothing collects

These need two datasets correlated. **The engine could not express a two-dataset condition at all
until AB#6835**; it now can, as declared rule data (`join:` in place of `query:`), so adding the
next such rule needs no engine change. `src/assess/rules/xr.crossresource.yaml` ships six.

- ~~**Which VMs have no backup**~~ — **CLOSED**: `XR-BKP-01` (and `XR-BKP-02` for the mirror case,
  a protected item whose VM is gone)
- ~~**Which PaaS services lack a private endpoint**~~ — **CLOSED** for storage and key vaults:
  `XR-STO-01`, `XR-KV-01`. Other PaaS targets are a rule each, no code
- ~~**Which resources are orphaned**~~ — snapshots **CLOSED** by `XR-SNP-01`; disks/NICs/PIPs were
  already single-dataset queries
- **Which subnets have no NSG** — still open: needs subnets ✅ + NSG associations (partial). The
  join mechanism exists; the NSG-association half of the projection does not yet
- **Which secrets expire in 30 days** — the DATA is now collected (`KeyVaultSecrets`, AB#6837).
  A rule reading `attributes.exp` against a date threshold is not yet written

### Why this section exists

§6 marks a service ✅ when *any* collector targets it. That is the correct answer to "does Scout
know this service exists" and the **wrong** answer to "can Scout tell me anything useful about it."
Every row above sits underneath a ✅.

---

## 8. Assessment coverage — the CAF/WAF/compliance menu

### Table 1 — WAF pillars as candidate assessments

Official checklist item counts verified 2026-07-30 by fetching each pillar's design-review checklist page directly. All five totals match the prior audit exactly (59 items). Scout rule counts are `- id:` occurrences in each file under `src/assess/rules/`.

The "assessable" figure is the subset of checklist items that can be evaluated from Azure control-plane telemetry at all. The rest are process, cultural, or design-intent items (define targets, run FMA, train staff, formalise practices) that no scanner can score without human input. Coverage is given against that subset, because coverage against the full 59 understates Scout by treating unscorable items as gaps.

| Pillar | Official checklist items | Machine-assessable subset | Scout rule file | Scout rule count | Est. coverage | Verdict |
|---|---|---|---|---|---|---|
| Reliability | 10 (`RE:01`–`RE:10`) | ~4 (`RE:05` redundancy, `RE:06` scaling, `RE:07` self-healing, `RE:10` health monitoring) | `waf.reliability.yaml` | 3 | ~75% of assessable / 30% of full | **Promote to a real assessment.** Thinnest file in the repo at 3 rules and the only pillar below 6. Add `RE:10` monitoring coverage and depth on `RE:05`. |
| Security | 12 (`SE:01`–`SE:12`) | ~7 (`SE:04` segmentation, `SE:05` IAM, `SE:06` networking, `SE:07` encryption, `SE:08` hardening, `SE:09` secrets, `SE:10` monitoring) | `waf.security.yaml` | 7 | ~100% of assessable / 58% of full | **Promote.** Best-aligned pillar. Depth per rule is the gap, not breadth. |
| Cost Optimization | 14 (`CO:01`–`CO:14`) | ~6 (`CO:03` cost data, `CO:05` rates/reservations, `CO:07` component costs, `CO:08` environment costs, `CO:10` data costs, `CO:12` scaling costs) | `waf.cost.yaml` | 6 | ~100% of assessable / 43% of full | **Promote.** Already surfaced separately as the registry's `Cost` view — that view should become this pillar assessment. |
| Operational Excellence | 11 (`OE:01`–`OE:11`) | ~4 (`OE:05` IaC, `OE:07` monitoring stack, `OE:10` automation, `OE:11` safe deployment) | `waf.operational.yaml` | 6 | ~100% of assessable / 55% of full | **Promote.** Largest pillar-to-telemetry gap: 7 of 11 items are unscorable process items. Report must say so rather than score them as failures. |
| Performance Efficiency | 12 (`PE:01`–`PE:12`) | ~5 (`PE:03` service/tier selection, `PE:04` measurement, `PE:05` scaling/partitioning, `PE:07` code+infrastructure, `PE:08` data) | `waf.performance.yaml` | 6 | ~100% of assessable / 50% of full | **Promote.** |
| **Total** | **59** | **~26** | 5 files | **28** | — | Five pillar assessments are viable today. |

Sources: [Reliability](https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist) · [Security](https://learn.microsoft.com/en-us/azure/well-architected/security/checklist) · [Cost Optimization](https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist) · [Operational Excellence](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist) · [Performance Efficiency](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist)

The machine-assessable subsets are this audit's own judgement, applied consistently across pillars. They are not a Microsoft-published figure and are marked `unverified` as a citable number.

#### The `waf.storage.yaml` anomaly

`src/assess/rules/waf.storage.yaml` (5 rules) carries a `waf.` prefix but **storage is not a WAF pillar**. The Well-Architected Framework has exactly five pillars, confirmed on every checklist page above and on [What is the Well-Architected Framework?](https://learn.microsoft.com/en-us/azure/well-architected/what-is-well-architected-framework). Storage appears in WAF only as a *service guide*, which is a different artefact — service guides are per-service configuration advice that feeds the pillars, not a scoring axis alongside them.

The file also collides conceptually with `caf.storage.yaml` (6 rules), giving Scout two storage rule files under two different framework prefixes.

**What should happen to it:** redistribute its 5 rules into the pillar files they actually belong to — durability/replication rules to `waf.reliability.yaml`, encryption and public-access rules to `waf.security.yaml`, tiering/lifecycle rules to `waf.cost.yaml` — then delete the file. Keeping it means Scout reports a sixth WAF pillar that does not exist, which is the single most visible correctness defect in the rule set. If per-service grouping is wanted, model it explicitly as a WAF *service guide* axis with its own prefix (`svc.storage.yaml`), never as `waf.*`.

---

### Table 2 — CAF landing zone design areas as candidate assessments

Eight design areas confirmed against [Azure landing zone design areas and conceptual architecture](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas) — four "environment" design areas (billing/tenant, IAM, resource organization, network) and four "compliance" design areas (security, management, governance, platform automation). The count of 8 matches the prior audit.

Recommendation counts were verified by fetching **43 Microsoft Learn pages** across all eight areas, counting top-level bullets under `## Design recommendations` (and area-specific equivalents such as "Management group recommendations"). Totals differ materially from the prior audit — see the discrepancy note below the table.

| Design area | Official recommendations (verified) | Prior audit said | Scout rule file | Scout rule count | Est. coverage | Verdict |
|---|---|---|---|---|---|---|
| Azure billing and Microsoft Entra tenant | **42** (5 pages) | 42 | `caf.billing.yaml` | 7 | **~0%** — see misnaming note | **Highest-priority gap.** The one design area with a rule file that does not assess it at all. |
| Identity and access management | **65** (4 pages) | 69 | `caf.identity.yaml` | 7 | ~11% | Promote, but 7 rules against 65 recommendations is a token sample. IAM deserves the deepest rule set of any area. |
| Resource organization | **35** (3 pages) | 35 | `caf.resourceorg.yaml` | 6 | ~17% | Promote. Highly telemetry-friendly (management groups, subscriptions, tags) — cheapest area to raise coverage. |
| Network topology and connectivity | **123** formal (+ ~32 in rewritten numbered format ≈ **155**) across 14 pages | 141 | `caf.network.yaml` | 7 | ~5% | Promote. Largest design area by a wide margin and Scout's weakest ratio. Warrants splitting into sub-assessments (topology, IP addressing, DNS, ingress/egress, segmentation). |
| Security | **45** (3 pages) | ~100 | `caf.security.yaml` | 7 | ~16% | Promote. Prior audit's ~100 is not supported — see discrepancy note. |
| Management | **15** (5 pages) | 46 | `caf.management.yaml` | 6 | ~40% | Promote. Best-covered CAF area, and the prior audit badly overstated the target. |
| Governance | **10** (1 page, self-contained) | 42 | `caf.governance.yaml` | 7 | ~70% | Promote. Effectively near-complete; the prior audit's 42 appears to have counted design *considerations* (~40 bullets on that page) rather than recommendations. |
| Platform automation and DevOps | **30** formal (10 pages) | ~80 | `caf.platformauto.yaml` | 6 | ~20% | Promote with caution — most content is CI/CD process that Azure telemetry cannot observe. Realistic ceiling is low. |
| **Total** | **~365 formal** | ~394 | 8 files | **53** | ~15% | Eight design-area assessments are viable; three are severely under-ruled. |

Base URL for all design-area pages: `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/`

**Discrepancy against the prior audit — use the verified figures.** The verified total is **~365**, not ~394. Three areas differ enough to matter:
- **Security: 45 verified, not ~100.** The prior figure likely double-counted the four `azure-best-practices` network-security pages that the security design area links to but which belong to the network design area.
- **Management: 15 verified, not 46.** Two of the five sub-pages have no recommendations section at all.
- **Governance: 10 verified, not 42.** That page's *considerations* section runs to ~40 bullets; the *recommendations* section is 10. Almost certainly a considerations/recommendations mix-up.
- **Network: 123 formal, not 141** — but with ~32 further recommendations now written as numbered task steps rather than bullets, the true figure is ~155, i.e. the prior audit understated this one.

**Caveat on all counts — Microsoft is mid-rewrite.** The `## Design considerations` / `## Design recommendations` structure is no longer universal. `virtual-wan-network-topology`, `connectivity-to-other-providers`, and `considerations/devops-teams-topologies` now have **no** design-recommendations heading; their ~41 combined recommendations are numbered task sections. Any count is therefore a snapshot, and a rule set pinned to bullet counts will drift. Four pages were not read (`subscription-vending`, `subscription-vending-product-lines`, `connectivity-to-other-providers-oci`, and the multi-tenant set), so ~365 is a floor, not a ceiling.

#### `caf.billing.yaml` is misnamed

`caf.billing.yaml` holds **cost-optimization rules** — the same subject matter as `waf.cost.yaml`, not the CAF "Azure billing and Microsoft Entra tenant" design area. That design area is about commercial and tenant *setup*, and its 42 recommendations cover things Scout does not touch:

- EA vs MCA vs CSP enrollment structure and which agreement the estate is on
- billing account → billing profile → invoice section hierarchy, and mapping it to organizational structure
- department/enrollment-account hierarchy and per-invoice-section budgets with alerts
- **subscription vending** as an automated self-service function
- **MFA required on every identity holding subscription-creation permissions** on a billing account, profile, or invoice section
- notification-contact email configured on the billing account, and periodic audit of billing RBAC role assignments
- Microsoft Entra tenant creation and whether one tenant or several is correct
- break-glass / emergency-access accounts excluded from Conditional Access

Verified against [Plan for the Microsoft customer agreement service](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement), which states the MFA-on-subscription-creators and billing-RBAC-audit recommendations explicitly.

Consequence: **the billing/tenant design area has ~0% real coverage**, and Scout has two files scoring cost optimization while one of them claims to score tenant setup. Rename the existing file to `caf.cost.yaml` (or fold it into `waf.cost.yaml`, which it duplicates), and write a genuine `caf.billing.yaml` against the list above. Break-glass accounts, MFA on subscription creators, and billing RBAC assignments are all reachable from data Scout already collects, so this is a cheap, high-value gap to close.

---

### Table 3 — CAF methodologies as a second assessment axis

The Cloud Adoption Framework is organised into **seven core methodologies**, confirmed on [What is the Microsoft Cloud Adoption Framework?](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/overview): four sequential foundational methodologies (Strategy, Plan, Ready, Adopt) and three parallel operational ones (Govern, Secure, Manage). **Secure is a full methodology in its own right** — a change from older CAF material where security was folded into Govern.

Scout models **none** of the seven. Its 17 `caf.*.yaml` files map to the *design areas* of a single methodology (Ready), plus nine service-category files that sit outside the CAF structure entirely (`ai`, `analytics`, `containers`, `databases`, `hybrid`, `integration`, `iot`, `storage`, `web` — 62 of the 111 CAF rules). This is the more important structural finding of Table 2 and Table 3 combined: **Scout's "CAF" coverage is really "one methodology's design areas, plus a service taxonomy that CAF does not have."**

| Methodology | What it covers | Assessable from Azure telemetry? | Verdict |
|---|---|---|---|
| **1. Strategy** | Map business drivers to cloud outcomes; motivations, business justification, first adoption project. | **No.** Purely organisational. There is no Azure artefact that encodes a motivation statement. | **Do not build.** Any score would be fabricated. Offer as a questionnaire at most. |
| **2. Plan** | Operating model, cloud skills readiness, migration/adoption plan, cloud cost estimation. | **Barely.** Digital-estate inventory and cost forecasting are observable; skills plans and operating-model choice are not. | **Do not build as a scored assessment.** The observable part is already Scout's `Estate` inventory view. |
| **3. Ready** | Azure purchasing, tenant setup, platform landing zone, application landing zones — i.e. the 8 design areas. | **Yes, extensively.** This is the whole of Table 2. | **Already Scout's only real assessment.** Should be named honestly as "CAF Ready / Landing Zone", not "CAF". |
| **4. Adopt** | Migrate, modernise, or build cloud-native workloads. | **Partially.** Migration tooling state and workload modernity (PaaS vs IaaS ratio, container adoption, deprecated SKUs) are observable; adoption sequencing is not. | **Build second.** A "modernisation posture" assessment scoring IaaS-vs-PaaS mix, legacy SKUs, and OS/runtime end-of-support is genuinely useful and entirely telemetry-driven. |
| **5. Govern** | Assess cloud risks and mitigate them with Azure tooling, across seven risk categories (below). | **Yes, substantially** — via Azure Policy compliance state, which Scout collects and does not score (Table 4). | **Build first after Ready.** The cheapest high-value new assessment Scout can add. |
| **6. Secure** | Protect workloads: security posture modernisation, Zero Trust access controls, incident readiness. | **Yes** — Defender for Cloud secure score, MCSB compliance, identity posture. | **Build.** Overlaps WAF Security but scores the *estate*, not a workload — a genuinely different question. |
| **7. Manage** | Administer and optimise workloads: management baseline, monitoring, business continuity, operational compliance. | **Yes.** Backup/DR configuration, Log Analytics coverage, alert rules, Update Manager and agent deployment are all observable. | **Build.** Maps closely to the existing `caf.management.yaml`, which could be promoted and expanded to fill it. |

#### Current Govern taxonomy — verified

The prior audit's 7 categories are **confirmed correct**, though the abbreviations RC/SC/CM/OP/DG/RM/AI are Scout's shorthand, not Microsoft's. Microsoft names them, verbatim from [Assess cloud risks](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/assess-cloud-risks):

| Category | Microsoft's wording | Scout shorthand |
|---|---|---|
| Regulatory compliance | "Identify regulatory compliance risks" | RC |
| Security | "Identify security risks" | SC |
| Cost | "Identify cost risks" | CM |
| Operations | "Identify operations risks" | OP |
| Data | "Identify data risks" | DG |
| Resource management | "Identify resource management risks" | RM |
| AI | "Identify AI risks" | AI |

The same seven appear as the `Category` field of the CAF risk register and in the Govern overview's domain list. Independently corroborated by the [FinOps toolkit Governance report](https://learn.microsoft.com/cloud-computing/finops/toolkit/power-bi/governance), which lists "regulatory compliance, security, operations, cost, data, resource management, and artificial intelligence (AI)".

Govern is also now a **five-step process** — build a governance team → assess risks → document policies → enforce policies → monitor compliance — with steps 2–5 running as a continuous cycle. An assessment could score steps 4 and 5 (enforcement and monitoring) from telemetry; steps 1–3 are organisational.

#### The five old governance disciplines are retired — verified

The legacy CAF governance disciplines (**Cost Management, Security Baseline, Identity Baseline, Resource Consistency, Deployment Acceleration**) no longer exist as a taxonomy. Two independent confirmations:

1. Fetching `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/governance-disciplines` **redirects** to [Build a cloud governance team](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/build-cloud-governance-team) — the discipline hub page is gone, not merely moved.
2. Targeted search of Microsoft Learn for the five discipline names returns **no** current CAF Govern discipline pages; the only surviving hits are scenario-specific pages (SAP, Azure Arc) that use "governance disciplines" as a generic phrase.

The two discipline names that survive do so in a different sense and must not be treated as the old disciplines: **Deployment Acceleration** and **Cost Management** are now recommendation headings *inside* the Governance design area page (8 and 2 recommendations respectively — the whole of that page's 10). If Scout's rule metadata still tags rules with discipline names, those tags are stale.

---

### Table 4 — Compliance and benchmark assessments (none exist in Scout today)

**The economics here are unlike anything else in this catalogue.** Azure ships regulatory-compliance initiatives as built-in policy set definitions, and Azure Policy already evaluates every in-scope resource against them continuously. An assessment built on this reads a compliance result Azure has already computed — it does not re-implement hundreds of controls.

**Scout's position:** `Get-ScoutApiResources.ps1:151` calls `Microsoft.PolicyInsights/policyStates/latest/summarize`, and `Get-ScoutSubscriptionSecurityPolicySweep.ps1` and `Get-ScoutOperationalCollectorEnrichment.ps1:249` (`policyStates/latest/queryResults`) collect further policy state. Policy set definitions and definitions are collected too. **No rule scores any of it.** The four rules that mention policy (`caf.governance.yaml`, `caf.platformauto.yaml`) query `$.governance.policyAssignments` for assignment *existence*, `enforcementMode`, and presence of parameters — never compliance state.

**A naming defect worth fixing while you are here:** in `Get-ScoutApiResources.ps1:150-151` the field named `PolicyAssignments` is populated from the `policyStates/latest/summarize` endpoint, which returns a *compliance summary*, not assignments. Meanwhile `caf.hybrid.yaml:55` documents that `governance.policyAssignments` is populated by the AzGovViz ingest step. Two different shapes, one name.

The `Controls` column below is Microsoft's published **policy count** for each initiative — the number of policy definitions it contains, not the number of framework controls, which is generally lower (many controls need several policies). All names and counts are from [Azure Policy built-in initiative definitions](https://learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-initiatives), verified 2026-07-30.

| Framework | Azure Policy built-in initiative name (exact) | Controls (= policies) | Buildable from Scout's data? | Priority |
|---|---|---|---|---|
| **Microsoft Cloud Security Benchmark** | `Microsoft cloud security benchmark` | 223 | **Yes — free.** Defender for Cloud's *default* initiative, so it is assigned in essentially every subscription. Compliance state is already in Scout's collected data. | **1 — build first.** Highest coverage, zero assignment prerequisite. |
| MCSB v2 (preview) | `[Preview]: Microsoft cloud security benchmark v2` | 414 | Yes, where assigned. Preview — do not make it the default. | 1b — support alongside v1. |
| **CIS Azure Foundations** | `CIS Azure Foundations v3.0.0` (current) | 53 | **Yes, if assigned.** Also available: `CIS Microsoft Azure Foundations Benchmark v2.0.0` (108), `v1.4.0` (167), `v1.3.0` (168), `v1.1.0` (152), `CIS Azure Foundations v2.1.0` (31) | **2.** Most-requested benchmark in customer conversations. Ship v3.0.0 and v2.0.0. |
| CIS Controls (non-Azure-specific) | `CIS Controls v8.1` | 167 | Yes, if assigned. | 4 |
| **NIST SP 800-53 Rev 5** | `NIST SP 800-53 Rev. 5` | 696 | **Yes, if assigned.** Also `NIST SP 800-53 R5.1.1` (221), the newer revision-5.1.1 set. | **3.** Largest initiative Azure ships; only meaningful via policy state — hand-writing 696 rules is not viable. |
| **NIST CSF** | `NIST CSF v2.0` | 103 | Yes, if assigned. | 3 |
| **ISO/IEC 27001** | `ISO/IEC 27001 2022` (current) | 58 | **Yes, if assigned.** Legacy `ISO 27001:2013` (448) still shipped. Companions: `ISO/IEC 27002 2022` (145), `ISO/IEC 27017 2015` (92, cloud-specific) | **2.** Ship the 2022 set; offer 2013 for customers mid-recertification. |
| **PCI-DSS v4** | `PCI DSS v4.0.1` (current) | 202 | **Yes, if assigned.** Also `PCI DSS v4` (269) and legacy `PCI v3.2.1:2018` (30) | 3 |
| **SOC 2** | `SOC 2 Type 2` | 307 | **Yes, if assigned.** Also `SOC 2023` (221) | 3 |
| **HIPAA / HITRUST** | `HITRUST/HIPAA` | 589 | **Yes, if assigned.** Also `HITRUST CSF v11.3` (216) | 3 |
| **FedRAMP Moderate** | `FedRAMP Moderate` | 641 | Yes, if assigned. | 4 (US public sector only) |
| **FedRAMP High** | `FedRAMP High` | 711 | Yes, if assigned. Largest US-federal set. | 4 (US public sector only) |
| **UK OFFICIAL** | `UK OFFICIAL and UK NHS` | 45 | Yes, if assigned. Single initiative covers both. | 4 |
| **Australian ISM** | `Australian Government ISM PROTECTED` | 38 | Yes, if assigned. Also `APRA CPS 234 2019` (18) for AU financial services. | 4 |
| CMMC | `CMMC 2.0 Level 2` (217); `Cybersecurity Maturity Model Certification (CMMC) Level 2 v1.9.0` (200); `CMMC Level 3` (142) | 142–217 | Yes, if assigned. | 5 |
| NIST SP 800-171 | `NIST 800-171 R3` (206); `NIST SP 800-171 Rev. 2` (435) | 206 / 435 | Yes, if assigned. | 5 |
| Canada Federal PBMM | `Canada Federal PBMM 3-1-2020` (189); legacy `Canada Federal PBMM` (41) | 189 | Yes, if assigned. | 5 |
| New Zealand ISM | `New Zealand ISM` (208); `NZISM v3.7` (209) | 208 | Yes, if assigned. | 5 |
| Spain ENS | `Spain ENS` | 821 | Yes, if assigned. Largest single initiative Azure ships. | 5 |
| Netherlands BIO | `NL BIO Cloud Theme V2` (278); `NL BIO Cloud Theme` (228) | 278 | Yes, if assigned. | 5 |
| SWIFT CSP-CSCF | `SWIFT Customer Security Controls Framework 2024` (193); `SWIFT CSP-CSCF v2022` (323) | 193 | Yes, if assigned. | 5 |
| South Korea ISMS-P | `K ISMS P 2023` | 364 | Yes, if assigned. | 5 |
| RMIT Malaysia | `RMIT Malaysia` | 183 | Yes, if assigned. | 5 |
| NIST AI RMF | `NIST AI RMF v1.0` | **1** | Technically yes, but a 1-policy initiative scores almost nothing. | Do not ship as an assessment — it would mislead. |
| CIS Kubernetes | `[Preview]: Kubernetes cluster should follow the security control recommendations of Center for Internet Security (CIS) Kubernetes benchmark` | 7 | Yes, AKS only. | 5 |

**Which frameworks have a built-in initiative:** all of the above. **Which would need hand-written rules:** none of the frameworks named in the brief. Every one — MCSB, CIS, NIST 800-53 Rev 5, NIST CSF, ISO 27001, PCI-DSS v4, SOC 2, HIPAA/HITRUST, FedRAMP Moderate and High, UK OFFICIAL, Australian ISM — ships as a built-in regulatory-compliance initiative. Hand-writing rules for any of them would duplicate work Azure already does and would drift from Microsoft's control mappings on every framework revision.

**The one real constraint, and it is a hard one:** apart from MCSB, an initiative returns compliance data **only where it has been assigned**. An unassigned initiative yields nothing — not a zero score, but no data at all. Scout must distinguish "assigned and non-compliant" from "never assessed" and report the second as a coverage gap, never as a pass or a fail. This distinction is the entire difference between a trustworthy compliance report and a dangerous one. Scout already collects `policySetDefinitions` per subscription, so detecting which initiatives are assigned is straightforward.

Suggested build order: read the summarised compliance state Scout already collects → render MCSB as a scored assessment → detect which other regulatory initiatives are assigned → expose each assigned one as its own assessment → for unassigned frameworks, emit a recommendation to assign the initiative rather than a score.

#### Microsoft's own review tooling as candidate structures

**Azure Well-Architected Review** — [Complete an Azure Well-Architected Review assessment](https://learn.microsoft.com/en-us/azure/well-architected/design-guides/implementing-recommendations) states the core review "consists of approximately 60 questions based on the key recommendations from the Well-Architected Framework pillars", which corroborates the 59-item checklist total in Table 1. Take the "Core Well-Architected Review" when prompted; the platform also hosts narrower specialised reviews (AI workload, Analytics, Azure AI Search, Azure Virtual Desktop, Data Services, SaaS workload, Mission Critical). Azure Advisor now surfaces WAF assessments directly — see [Use Azure WAF assessments](https://learn.microsoft.com/en-us/azure/advisor/advisor-assessments) — which is the closest existing product to what Scout does and worth studying as both a structural model and a competitive reference.

**Azure Landing Zone Review** — the assessment exists on the Microsoft Assessments platform, but its question count and per-area weighting are **not published in Microsoft Learn documentation**. The prior audit's figures — 34 questions weighted Network 11, Identity 7, Platform automation 4, Billing 3, Resource org 3, Governance 3, Management 2, Security 2 — **could not be verified** from Learn and are marked `unverified`. Do not cite them as fact. Two observations that neither confirm nor refute them: the weighting is directionally consistent with the verified recommendation counts in Table 2 (network is by far the largest area at ~155, identity second at 65), but it is sharply inconsistent for Management (2 questions against 15 recommendations) and Security (2 questions against 45). Verifying this requires running the assessment on the Microsoft Assessments platform, which Learn's documentation tooling cannot reach.

Both review tools are worth adopting as *structure* regardless of Scout's rule content: they give customers a vocabulary they already recognise, and aligning Scout's output sections to them makes Scout's findings directly comparable to a Microsoft-run review.

---

### Framework currency warnings

Places where Microsoft's guidance has moved and Scout would now score against stale guidance. Each verified 2026-07-30.

| # | Warning | Status | Impact on Scout |
|---|---|---|---|
| 1 | **The five CAF governance disciplines are retired.** Cost Management, Security Baseline, Identity Baseline, Resource Consistency, and Deployment Acceleration no longer exist as a taxonomy. The `govern/governance-disciplines` URL redirects to [Build a cloud governance team](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/govern/build-cloud-governance-team). Govern is now a 5-step process across 7 risk categories. **Deployment Acceleration and Cost Management survive only as recommendation headings inside the Governance *design area*** — not as disciplines. | **Confirmed retired** | Any rule metadata, doc page, or report section using discipline names is stale. Re-tag to the 7 risk categories. |
| 2 | **Two new default management groups: `Security` and `Local`.** Both are now in the default ALZ hierarchy, not tailoring options. `Security` sits under `Platform` and holds SIEM/SOC tooling (Sentinel, syslog collectors). `Local` sits under `Landing zones` alongside `Corp` and `Online`, for Azure Local clusters and their workloads, which have different Azure Policy requirements. Microsoft now states "the default `Corp`, `Online`, and `Local` management groups provide an ideal starting point". Source: [Management groups](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups). | **Confirmed — both are default** | Any rule validating management-group hierarchy against a `Platform`/`Landing zones`/`Sandbox`/`Decommissioned` shape will now flag conforming estates as non-conforming. Note the tailoring page still describes `Security` as an example of tailoring while the design-area page treats it as default — Microsoft's own docs are inconsistent; trust the design-area page. |
| 3 | **Sovereignty has moved out of CAF into its own docset.** Sovereign Landing Zone content now lives under `learn.microsoft.com/azure/azure-sovereign-clouds/` (and `learn.microsoft.com/industry/sovereignty/`), not under CAF. SLZ is now positioned as an *architectural variant* layered onto an existing landing zone — "You don't need to replace your Azure landing zone implementation" — with L1–L3 policy tiers plus a Secure Landing Zone initiative. Some older Cloud for Sovereignty pages are explicitly banner-marked **archived and not being updated**. Sources: [Sovereign Landing Zone (SLZ)](https://learn.microsoft.com/azure/azure-sovereign-clouds/public/overview-sovereign-landing-zone) · [implementation options](https://learn.microsoft.com/azure/azure-sovereign-clouds/public/implementation-options) | **Confirmed moved** | Sovereignty is now a separate assessment axis, not a CAF design area. Any Scout link into CAF for sovereignty guidance is dead or archived. |
| 4 | **CAF explicitly states AI does NOT need its own landing zone.** From the [Azure landing zone FAQ](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/faq): *"Do I need a dedicated or separate AI landing zone? No, you do not need a separate AI landing zone."* AI workloads deploy into ordinary application landing zones. | **Confirmed** | Scout's `caf.ai.yaml` (5 rules) must not score for a separate AI landing zone or AI-specific platform subscriptions. The correct AI checks are management-group separation of internet-facing vs internal AI workloads, AI-specific Azure Policy on those groups, and AI resources in *workload* subscriptions — per [AI Ready](https://learn.microsoft.com/azure/cloud-adoption-framework/ai/ready). |
| 5 | **NEW — CAF now has seven methodologies, and `Secure` is one of them.** Secure is a peer of Govern and Manage, not a sub-topic of Govern. Foundational (Strategy, Plan, Ready, Adopt) are sequential; operational (Govern, Secure, Manage) run in parallel. Source: [CAF overview](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/overview). | **Newly flagged** | Scout models zero methodologies and its `caf.*` files cover only Ready's design areas. Naming them "CAF" overstates scope — see Table 3. |
| 6 | **NEW — the design area is "Azure billing and Microsoft Entra tenant", not "Active Directory tenant".** The design-areas index page still renders the legacy "Azure billing and Active Directory tenant" label in its table while the underlying pages use Microsoft Entra throughout. | **Newly flagged** | Cosmetic in Scout, but any doc text saying "Azure AD" is stale. Microsoft's own index page has not caught up — do not treat the index label as authoritative. |
| 7 | **NEW — Microsoft is rewriting design-area pages away from the `Design considerations` / `Design recommendations` structure.** At least three pages (`virtual-wan-network-topology`, `connectivity-to-other-providers`, `considerations/devops-teams-topologies`) have no recommendations heading at all; their ~41 combined recommendations are numbered task sections. Others use bespoke headings ("Management group recommendations", "Inventory and visibility recommendations"). | **Newly flagged** | Any coverage percentage Scout publishes against a recommendation count will silently drift as more pages are rewritten. If Scout states coverage numbers, date-stamp them and record the verification method. |
| 8 | **NEW — regulatory-compliance initiatives are versioned and the older versions are still shipped.** Azure simultaneously offers, e.g., six CIS Azure Foundations initiatives (v1.1.0 through v3.0.0), two ISO 27001 sets (2013 and 2022), three PCI sets, and both `NIST SP 800-53 Rev. 5` and `NIST SP 800-53 R5.1.1`. | **Newly flagged** | Scout must name the exact initiative version it scored. "CIS compliance: 72%" is meaningless across a 31-policy and a 168-policy initiative. |
| 9 | **NEW — `waf.storage.yaml` scores a WAF pillar that does not exist.** WAF has exactly five pillars. Storage is a WAF *service guide*, a different artefact. | **Newly flagged** | See Table 1. The most visible correctness defect in the rule set. |

---

## 9. Permissions — the least-privilege grant list

**The short answer: `Reader` at the root management group covers every ARM resource provider Scout
collects — all 152 of them.** Azure's `Reader` role is defined as `*/read`, a single wildcard over
every control-plane read operation. There is no provider in the table below that needs more.

**No elevated roles are required.** Not Owner, not Contributor, not Global Administrator, not any
ADO admin role. Everything Scout does is a read.

### ARM resource providers — by category

| # | Category | Providers | Minimum permission | Role that grants it |
|---|---|---:|---|---|
| 1 | General | 8 | `*/read` | **Reader** |
| 2 | Compute | 12 | `*/read` | **Reader** |
| 3 | Networking | 2 | `*/read` | **Reader** |
| 4 | Storage | 6 | `*/read` | **Reader** |
| 5 | Web and Mobile | 5 | `*/read` | **Reader** |
| 6 | Containers | 4 | `*/read` | **Reader** |
| 7 | Databases | 8 | `*/read` | **Reader** |
| 8 | Analytics | 11 | `*/read` | **Reader** |
| 9 | AI + machine learning | 6 | `*/read` | **Reader** |
| 10 | Internet of Things | 11 | `*/read` | **Reader** |
| 11 | Integration | 15 | `*/read` | **Reader** |
| 12 | Identity (ARM only) | 5 | `*/read` | **Reader** |
| 13 | Security | 6 | `*/read` | **Reader** |
| 14 | DevOps | 7 | `*/read` | **Reader** |
| 15 | Migration | 5 | `*/read` | **Reader** |
| 16 | Monitor | 6 | `*/read` | **Reader** |
| 17 | Management and governance | 25 | `*/read` | **Reader** |
| 18 | Hybrid + multicloud | 10 | `*/read` | **Reader** |
| | **Total** | **152** | | **Reader — one assignment at root MG** |

### The calls that people assume need more — they don't

These are the ones worth stating explicitly, because they're the usual reason someone over-grants:

| What Scout calls | Specific permission | Reader enough? | Evidence |
|---|---|---|---|
| Defender alerts, assessments, pricing, secure score | `Microsoft.Security/*/read` | ✅ **Yes** | Subset of `*/read`. **Azure RBAC "Security Reader" is redundant** — note this is *not* the Entra role of the same name, which is separate and may be needed. |
| Diagnostic settings, metrics | `Microsoft.Insights/*/read` | ✅ **Yes** | Subset of `*/read`. **Monitoring Reader is redundant** — and it additionally grants `Microsoft.Support/*` (ticket *creation*), a write Scout never uses. |
| Cost Management query | `Microsoft.CostManagement/query/read` | ✅ **Yes** | Microsoft's [role-behaviour table](https://learn.microsoft.com/azure/cost-management-billing/costs/understand-work-scopes#azure-rbac-scopes) shows **Reader** = "Read only" on *Cost Analysis / Forecast / Query / Cost Details API*. **Cost Management Reader is redundant.** |
| Policy compliance state | `Microsoft.PolicyInsights/policyStates/queryResults/read`, `summarize/read` | ✅ **Yes** | Both `/read` and `/action` variants exist; the `/read` ones are covered by `Reader`. The `/action` variants belong to writer roles. |
| Advisor recommendations and score | `Microsoft.Advisor/*/read` | ✅ **Yes** | Subset of `*/read`. |
| VM quotas, SKUs | `Microsoft.Compute/locations/{usages,skus}/read` | ✅ **Yes** | Subset of `*/read`. |
| Patch data (Update Manager) | ARG tables `patchassessmentresources`, `patchinstallationresources` | ✅ **Yes** | Since the assessPatches fix. **Previously required a mutating `/action`** — see §5.4. |
| Management groups | `Microsoft.Management/managementGroups/read` | ⚠️ **Unconfirmed** | Reader must be assigned **at management-group scope**, not subscription scope. Whether that alone suffices, or **Management Group Reader** is genuinely additional, is untested — and currently confounded by a separate defect (§5.5). |

### These are FIVE separate permission systems

This is the part most commonly got wrong, including earlier drafts of this document. They are not
variants of one model — they are unrelated systems with different scoping, different portals, and
different approvers. **An Owner on every subscription in the tenant still reads zero directory
data, and zero billing data.**

| # | System | What it governs | Scope model | Example | Scout needs it for |
|---|---|---|---|---|---|
| 1 | **Azure RBAC** | Azure *resources* (ARM control plane) | MG → subscription → RG → resource | `Reader` | All 154 ARM collectors |
| 2 | **Entra directory roles** | The *directory* | Tenant-wide, no hierarchy | `Directory Readers` | 15 Entra collectors (`-Scope All`) |
| 3 | **Graph app permissions** | Directory, for *applications* | Per app registration, admin-consented | `User.Read.All` | Same 15, when running as a service principal |
| 4 | **Azure DevOps** | ADO orgs/projects | Per organisation / project | Project-level read | 5 DevOps collectors (`-IncludeDevOps`) |
| 5 | **Billing (EA/MCA)** | Billing accounts, profiles, invoice sections | Billing account → profile → invoice section | `Enterprise Administrator (read only)` | **Nothing today** — but gates cost data via two settings, and would be required for the CAF billing design area |

Systems 2 and 3 are two routes to the same data — pick one based on whether Scout runs as a user or
a service principal. Systems 1, 2/3, 4 and 5 are genuinely independent grants.

> ### ⚠️ Name collision — "Security Reader" exists in BOTH systems and they are different roles
>
> - **Azure RBAC "Security Reader"** — governs `Microsoft.Security/*` on Azure resources.
>   **Redundant**; `Reader` already covers it. This is the one to drop.
> - **Entra "Security Reader"** — governs Entra ID Protection, PIM, and sign-in/audit logs.
>   **A completely different role, and Scout may genuinely need it** (see below).
>
> Dropping the wrong one silently empties the risky-users and PIM worksheets. Always state which
> system a role belongs to.

### Entra ID — only if you run `-Scope All`

**Correction to an earlier draft of this document:** it recommended `Global Reader`. That is **not**
least-privilege — Microsoft classifies **Global Reader as a privileged role** (it is the read-only
counterpart to *Global Administrator*, spanning Microsoft 365, Exchange, SharePoint, Teams, Defender
and Purview — vastly more than Scout needs).

**Lower-privilege alternative — two narrow roles instead of one broad one:**

| Role | Privileged? | Covers | Scout data it unlocks |
|---|---|---|---|
| **`Directory Readers`** | **No** | Basic directory: users, groups, applications, service principals, org details, **directory roles** | Users, Groups, Apps, ServicePrincipals, ManagedIdentities, Organization, Domains, AdminUnits, Licensing, **DirectoryRoles** |
| **`Security Reader`** *(Entra)* | Yes | ID Protection, PIM, Conditional Access, named locations, policies | RiskyUsers, PIMAssignments, ConditionalAccess, NamedLocations, SecurityPolicies. **Required** — `Directory Readers` has zero Conditional Access actions. |
| `Reports Reader` | No | Sign-in and audit reports only | *Nothing Scout uses* — see `AuditLog.Read.All` below |
| ~~`Global Reader`~~ | **Yes** | Everything above **plus all of M365** | Works, but far more than required |

**Minimum: `Directory Readers` + Entra `Security Reader`.**
`Directory Readers` alone is enough if you skip risky-users, PIM and Conditional Access.

> #### ⚠️ `CrossTenantAccess` is NOT covered at minimum privilege — corrected 2026-07-31
>
> An earlier draft claimed these two roles cover every Entra collector. **They do not.** Scout calls
> `/v1.0/policies/crossTenantAccessPolicy/partners` — the live partner configuration.
>
> - `Directory Readers` — no `crossTenantAccessPolicy` action of any kind.
> - Entra `Security Reader` — only two, and both are for **templates**
>   (`.../partners/templates/multiTenantOrganization*/standard/read`), not the live policy.
>
> `microsoft.directory/crossTenantAccessPolicy/partners/standard/read` **does** exist — a second
> earlier claim that it did not was also wrong. But it is held only by **Global Administrator,
> Global Reader, Security Administrator, Teams Administrator and Tenant Governance Administrator** —
> **every one of them a privileged or administrative role. None qualifies as a minimum-privilege
> grant.**
>
> **Therefore: at minimum privilege, the CrossTenantAccess worksheet will be empty.** That is the
> honest position — do not resolve it by recommending a privileged role.
>
> **Two acceptable paths, both of which stay least-privilege:**
> 1. **Service principal instead of a user** — the Graph application permission `Policy.Read.All`
>    covers cross-tenant access policy without any directory role. **Untested for this endpoint.**
> 2. **Accept the gap** — treat CrossTenantAccess as out of scope for the minimum grant, and let
>    the product documentation describe the privileged roles that would enable it for customers who
>    want it.
>
> Source: <https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference>
> (complete `Directory Readers` and `Security Reader` definitions).

**Running as a service principal instead** — Graph *application* permissions, admin-consented:
`Organization.Read.All`, `User.Read.All`, `Group.Read.All`, `Application.Read.All`,
`RoleManagement.Read.Directory`, `Policy.Read.All`, `IdentityRiskyUser.Read.All`.

**Also needed but never checked by Scout:** `AdministrativeUnit.Read.All`, `Domain.Read.All`,
`IdentityProvider.Read.All` — their absence silently empties worksheets.
**`AuditLog.Read.All` is requested but no collector consumes it** — drop the ask.
Risky Users additionally requires an **Entra ID P2 licence**, regardless of role or permission.

#### Conditional Access boundary — RESOLVED

Checked against the published action lists in
[Microsoft Entra built-in roles](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference):

| Role | Conditional Access actions | Reads CA? |
|---|---|---|
| `Directory Readers` | **none — the action list contains no `conditionalAccessPolicies` entry at all** | ❌ **No** |
| **Entra `Security Reader`** | `conditionalAccessPolicies/standard/read`, `/owners/read`, `/policyAppliedTo/read` | ✅ Standard properties |
| `Global Reader` | `conditionalAccessPolicies/allProperties/read` | ✅ All properties |

**Conclusion: Entra `Security Reader` is required for Conditional Access — `Directory Readers`
alone cannot read it.** The two-role recommendation stands; it is not optional if you want the
ConditionalAccess worksheet populated.

#### Entra `Security Reader` — the verified actions Scout depends on

Read from the complete role definition (not a search excerpt) at
[Microsoft Entra built-in roles → Security Reader](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#security-reader):

| Action | Scout collector it enables |
|---|---|
| `microsoft.directory/conditionalAccessPolicies/standard/read` | ConditionalAccess |
| `microsoft.directory/conditionalAccessPolicies/owners/read` | ConditionalAccess |
| `microsoft.directory/conditionalAccessPolicies/policyAppliedTo/read` | ConditionalAccess |
| `microsoft.directory/namedLocations/standard/read` | **NamedLocations** |
| `microsoft.directory/identityProtection/allProperties/read` | RiskyUsers |
| `microsoft.directory/privilegedIdentityManagement/allProperties/read` | PIMAssignments |
| `microsoft.directory/policies/standard/read` | SecurityPolicies |
| `microsoft.directory/signInReports/allProperties/read` | *(unused — no collector)* |
| `microsoft.directory/auditLogs/allProperties/read` | *(unused — no collector)* |

**`Directory Readers` + Entra `Security Reader` covers 14 of the 15 Entra collectors.** No
`Global Reader` required for those 14.

> ⚠️ **The one exception is `CrossTenantAccess`, and it needs a third role.** Scout calls
> `/v1.0/policies/crossTenantAccessPolicy/partners` — the **live partner configuration**. Neither
> recommended role reaches it: `Directory Readers` has no `crossTenantAccessPolicy` entry at all,
> and Entra `Security Reader` carries only two, both for *templates*
> (`.../partners/templates/multiTenantOrganizationIdentitySynchronization/standard/read` and
> `.../multiTenantOrganizationPartnerConfiguration/standard/read`).
>
> The action that *is* required — `microsoft.directory/crossTenantAccessPolicy/partners/standard/read`
> — **does exist**, and is held by **Security Administrator**, **Tenant Governance Administrator**,
> **Teams Administrator**, **Global Reader** and **Global Administrator**. An earlier draft of this
> document claimed no role definition contained it. That was wrong — the same failure mode as the
> `namedLocations` correction below: an absence asserted from an incomplete read.
>
> **Evaluate `Security Administrator` or `Tenant Governance Administrator` before reaching for
> `Global Reader`** — all three work, and the first two are far narrower. If none is granted, say
> so up front: the CrossTenantAccess worksheet renders empty, and an empty sheet is not a finding.
> Source: [Entra built-in roles](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference).

> **Correction:** an earlier draft of this section claimed `Security Reader` lacked
> `namedLocations/standard/read` and that NamedLocations might therefore fail. That was wrong — it
> came from a truncated search result rather than the full role definition. The complete definition
> includes it. There is no NamedLocations gap.

The last two rows are worth noting for the opposite reason: `Security Reader` grants sign-in and
audit log read, and **no Scout collector consumes either** — consistent with the finding that
`AuditLog.Read.All` is requested but unused.

### Azure DevOps — only if you run `-IncludeDevOps`

A **fourth** system, unrelated to both Azure RBAC and Entra. Read-only **project-level** membership
(Stakeholder or Basic with read access) is sufficient — **no organisation administrator role is
required**. Scout has **zero pre-flight coverage** here, so a permission failure surfaces only under
`-Debug`.

### Cost and billing — a FIFTH permission system

Billing has its own role model, entirely separate from Azure RBAC. Critically:

> **"Subscription ownership alone doesn't provide access to EA historical charges, because
> subscription roles don't grant access to the EA billing scope."**
> — [MCA billing transition checklist](https://learn.microsoft.com/azure/cost-management-billing/microsoft-customer-agreement/checklist-microsoft-customer-agreement-billing-migration)

And billing scope doesn't even follow the same boundaries: **"Although RBAC scopes are bound to a
single directory, EA billing scopes aren't. An EA billing account may have subscriptions across any
number of Microsoft Entra directories."**
— [Understand and work with scopes](https://learn.microsoft.com/azure/cost-management-billing/costs/understand-work-scopes#billing-scopes)

#### Two different questions, two different answers

| What you want | Scope | Minimum access |
|---|---|---|
| **Cost of resources in a subscription** *(what Scout collects today)* | Azure RBAC | **`Reader`** + the view-charges gate below |
| **Invoices, EA enrollment structure, billing profiles, departments, billing RBAC** *(Scout collects none of this)* | Billing account | An actual **billing role** — see below |

**Everything Scout collects today is the first row.** `Get-ScoutCostInventory`, the VM/Arc
`EstimatedCost` calls, and `ReservationRecom` all query at subscription scope, so `Reader` covers
them. No billing role required.

**Reservation utilization (AB#6829, `General/ReservationUtilization`) is neither row above — it is
a SIXTH scope.** `Microsoft.Consumption/reservationSummaries` reads at the **reservation**, not the
subscription or the billing account: Microsoft's reservation permission model is its own,
tenant-level system (`Reservations Reader`/`Reservations Administrator`/etc., or a built-in role
held **at the reservation itself**) that reservations do not inherit from subscription RBAC —
*"The reservation lifecycle is independent of an Azure subscription… Reservations don't inherit
permissions from subscriptions after the purchase."* (
[Permissions to view and manage Azure reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/view-reservations)).
Microsoft's own utilization page states the practical minimum: *"To view reservation utilization,
you must have Azure RBAC access to the reservation… Reservation scope: Built-in reader roles or
higher"* (
[View reservation utilization](https://learn.microsoft.com/azure/cost-management-billing/reservations/reservation-utilization)).
Since the parent `Microsoft.Capacity/reservationOrders/reservations` resource already comes back
from Resource Graph today (`General/Reservations`), the same principal already holds that
reservation-scope visibility — **no additional grant, and specifically no EA/MCA billing role, is
required.** Do not conflate this with the "Cost and billing" gates above; the AO/DA view-charges
switches govern subscription cost data, not reservation utilization.

#### Read-only billing roles, if you ever collect the second row

| Agreement | Read-only roles |
|---|---|
| **EA** | **Enterprise Administrator (read only)**, **Department Administrator (read only)** |
| **MCA** | **Billing account Reader**, **Billing profile Reader**, **Invoice section Reader** |
| Either | `Billing Reader` — an *Azure RBAC* role at subscription scope. **In preview, and unsupported in non-global clouds.** |

EA also has Enterprise Administrator, EA Purchaser, Department Administrator and Account Owner —
all write-capable. Scout would never need them.

#### ⚠️ The gates no role can satisfy — there are TWO, not one

Cost data can be empty with a perfectly correct role assignment:

| Gate | Applies to | Effect when disabled |
|---|---|---|
| **AO view charges** | Account Owners | No cost visibility |
| **DA view charges** | Department Administrators *and department read-only users* | **"Department users can't see costs at any level, even if they're an account or subscription owner."** |
| MCA equivalent | **"Azure charges"** *(formerly "Allow Azure subscription users to view and optimize costs")* | Same effect |

Only an **Enterprise Administrator** (EA) or, for MCA, a **Billing Profile Owner** can change
these — the setting sits on the **billing profile**, not the billing account, and Microsoft states
*"You must have Billing Profile Owners permission to enable the setting."* Even
the `Billing Reader` RBAC role is subject to them — Microsoft states it explicitly: *"for that
Billing Reader to view billing information for the department or account, the Enterprise
Administrator must enable AO view charges or DA view charges policies."*

**This is almost certainly a more common cause of empty cost sheets than any permission problem**,
and Scout's pre-flight **cannot detect it by inspecting roles** — it would have to attempt the call
and interpret the failure.

#### Where this connects to the CAF gap

The CAF **"Azure billing and Microsoft Entra tenant"** design area (§8, ~0% covered) is precisely
this second row — EA/MCA enrollment structure, department and invoice-section hierarchy, MFA on
subscription creators, billing RBAC assignments. Closing that gap is the one piece of work that
*would* require billing-scope read access. Worth knowing before scoping it.

### Verification status — read this before quoting the table

> ✅ **TESTED 2026-07-31 — `Reader` at the root management group is sufficient. Proven, not
> probable.**
>
> This section previously read *"documentation analysis, not a tested result… probable, not
> proven"*. The test it described has now been run.
>
> **Method.** A purpose-made service principal (`azure-scout-leastpriv-test`) was created in
> tenant `d6fc73cf` holding **exactly one role assignment** — `Reader`, scoped to the root
> management group. No subscription-scoped grant, no `Management Group Reader`, no Graph
> permission, nothing else. Verified by enumerating every assignment on the principal: total 1.
> The identical collection was then run as that principal and as a fully-privileged user
> (`User Access Administrator` at `/` plus `Owner`), and the results compared.
>
> | | Privileged user | **Reader-only SPN** |
> |---|---:|---:|
> | `Resources` | 113 | **113** |
> | `ResourceContainers` | 19 | **19** |
> | `ApiResources` (ARM REST sweep) | 2 | **2** |
> | `AZSC/Management/ManagementGroup` | 1 | **1** |
> | `AZSC/Management/RoleDefinition` | 1 | **1** |
> | `AZSC/Management/PolicyDefinition` | 1000 | **1000** |
> | `AZSC/Management/PolicySetDefinition` | 300 | **300** |
> | Distinct resource types | 42 | **42** |
>
> **Identical on every measure.** `Reader` at root MG returned everything the privileged identity
> did, including the ARM REST policy sweep and the tenant-wide envelopes.
>
> ⚠️ **What this does and does not establish.** It confirms the ARM half against *this* estate —
> 42 resource types across two subscriptions. It cannot speak for a collector whose resource type
> is absent here, and it says nothing about the Entra or Azure DevOps halves, which are separate
> permission systems and were not granted to the principal. The `Untested` grades in Tables A–D
> stay as they are for individual rows; what is now proven is the section's *headline claim*, which
> is the one customers act on.
>
> ⚠️ **A note on how nearly this went wrong.** The first Reader-only run reported 4 resources
> against the privileged run's 113, which reads exactly like a permission failure and would have
> been a dramatic (and false) finding. It was a defect in the test harness — a scriptblock
> parameter-passing mistake, not Azure. The tell was that the 4 "resources" were precisely the 4
> synthetic tenant-wide envelopes, meaning Resource Graph had returned nothing at all rather than
> a reduced set. **A permission conclusion drawn from a single run is worth very little**; this
> section's own history (note 4, where a permission theory absorbed the blame for dead code for
> several releases) is the reason to re-derive before believing it.

---

### Per-collector permission tables

### How to read these tables

The 174 collectors in `manifests/collectors/<Category>/*.psd1` **do not call Azure**. They are pure transforms over an in-memory `$Resources` bag. Every Azure call is made by ~13 functions in `src/collect/`. A collector's permission requirement is therefore the requirement of *the collect-layer function that produces the resource type it consumes*.

Access classes A–K are carried over from `docs/audits/AB6445-least-privilege-permissions-audit.md` §2.1:

| Class | Producer (`src/collect/`) | API surface |
|---|---|---|
| **A** | `Get-ScoutRawInventory.ps1` | Azure Resource Graph — `resources`, `resourcecontainers`, `recoveryservicesresources`, `desktopvirtualizationresources`, `advisorresources`, `securityresources`, `supportresources`, `patchassessmentresources`, `patchinstallationresources` |
| **B** | `Get-ScoutSubscriptionSecurityPolicySweep.ps1` | `Get-AzSecurity*`, `Get-AzDiagnosticSetting`, `Get-AzPolicyState` |
| **C** | `Get-ScoutArmChildResource.ps1` | `Invoke-AzRestMethod` GET on 12 ARM child paths |
| **D** | `Get-ScoutApiResources.ps1` | `Invoke-RestMethod` GET/POST on 7 ARM paths |
| **E** | `Get-ScoutTenantWideResource.ps1` | `Get-AzRoleDefinition -Custom`, `Get-AzManagementGroup -Expand -Recurse` |
| **F** | `Get-ScoutOperationalCollectorEnrichment.ps1` | `microsoft.insights/metrics`, `replicationEligibilityResults`, `Get-AzStorage*ServiceProperty` |
| **G** | *(retired)* | was `POST .../assessPatches`; replaced this session by ARG `patchassessmentresources` / `patchinstallationresources` — read-only. Class G no longer exists. |
| **H** | `Get-ScoutCostInventory.ps1` + enrichment cost half | `POST Microsoft.CostManagement/query` |
| **I** | `Get-ScoutVmQuotas.ps1`, `Get-ScoutVmSkuDetails.ps1` | `Get-AzVMUsage`, `Get-AzComputeResourceSku` |
| **J** | `Start-ScoutEntraExtraction.ps1` | Microsoft Graph `/v1.0/*` |
| **K** | `Start-ScoutDevOpsExtraction.ps1` | `dev.azure.com` / `app.vssps.visualstudio.com` REST |

**Four separate permission systems appear below. They are not interchangeable.** Every role name states its system.

1. **Azure RBAC** — Azure resources; scoped MG → subscription → RG → resource.
2. **Entra directory roles** — the directory; tenant-wide; no scope hierarchy.
3. **Microsoft Graph app permissions** — for service principals; require admin consent.
4. **Azure DevOps** — org/project security-group membership.

> ⚠️ **"Security Reader" exists in both Azure RBAC and Entra and they are different roles.** The **Azure RBAC** Security Reader is redundant here (every read it grants is already inside Reader's `*/read`; note 1 below is precise about why "strict subset" is the wrong phrase) and should not be granted. The **Entra** Security Reader is genuinely required for four Identity collectors. Wherever the name appears below it is qualified.

**`Verified` column:** `Doc` = confirmed against Microsoft Learn. `Untested` = derived by reasoning from the documented role definition, no live run. **Nothing here has been tested against a Reader-only principal** — no such run has been performed.

#### Established facts these tables rest on

| Fact | Source |
|---|---|
| Azure RBAC **`Reader`** = `Actions: */read`, `NotActions: none`, `DataActions: none`. Control plane only. | [Built-in roles — General](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/general) |
| **Cost Management query → `Reader` is sufficient** *(documented, untested)*. `Microsoft.CostManagement/query/read` exists, and Microsoft's role-behaviour table shows Reader = "Read only" on Cost Analysis / Forecast / Query / Cost Details API. **Cost Management Reader is redundant.** ⚠️ Microsoft's two pages **conflict**: *Assign access to Cost Management data* implies a dedicated role is needed, and is deliberately **not** cited here. Cost data is fetched with a **POST** to `/query`; whether that authorizes on `query/read` or `query/action` is **unresolved from documentation** — this row is `Untested`, not `Doc`. | [Permissions — Management and governance](https://learn.microsoft.com/azure/role-based-access-control/permissions/management-and-governance#microsoftcostmanagement) |
| **Policy Insights → `Reader` is sufficient.** Both `policyStates/queryResults/{read,action}` and `policyStates/summarize/{read,action}` exist; the `/read` variants fall inside `*/read`. | [Permissions — Management and governance](https://learn.microsoft.com/azure/role-based-access-control/permissions/management-and-governance#microsoftpolicyinsights) |
| Azure RBAC **`Security Reader`** and **`Monitoring Reader`** are both redundant, but **neither is a strict subset of `*/read`** — an earlier draft said so and was wrong. Security Reader carries five `/action` permissions outside `*/read` (IoT Defender package downloads); Monitoring Reader is a **superset**, adding `Microsoft.Support/*` — which includes ticket **creation**, a write. The accurate statement is narrower and still decisive: **neither grants anything Scout calls that `Reader` does not already grant.** **Cost Management Reader** is the same shape — redundant for Scout's calls, and it *also* carries `Microsoft.Support/*`. | [Security roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/security#security-reader), [Monitor roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/monitor#monitoring-reader) |
| Patch data now comes from ARG tables `patchassessmentresources` / `patchinstallationresources` (read-only). The old `assessPatches` POST — an ARM `/action`, not a read — was removed. `src/collect/Get-ScoutRawInventory.ps1:455-476`, `Get-ScoutOperationalCollectorEnrichment.ps1:230-232`. | Repo code |

**Net effect: every one of the 154 ARM collectors is satisfied by Azure RBAC `Reader` alone.** No custom role, no Cost Management Reader, no Security Reader, no Monitoring Reader.

---

### Citation coverage

Every row of Tables A, B and C now carries a `Source`. The numbers, blunt:

| | Count |
|---|---:|
| Distinct ARM permission claims in Table A | **142** |
| Cited to a Microsoft Learn page | **125** (88.0%) |
| **`NOT FOUND`** — no Microsoft page lists the action | **9** (6.3%) |
| **`Uncited`** — asserted with no citation, corrected from a false `Doc` | **8** (5.6%) |

> ⚠️ **Corrected 2026-07-31.** This table previously read *133 cited (93.7%)*. An adversarial
> fact-check of this section found **eight rows marked `Verified: Doc` whose `Source` cell said
> `NOT FOUND` or `n/a`** — CloudServices, ArcDataControllers, ArcSQLManagedInstances, ArcSQLServers,
> NATGateway, AVDApplicationGroups, AVDApplications, AutomationAccounts. Their `Verified` cells now
> read **`Uncited`** and the coverage figure is restated accordingly. Some overlap the 9 `NOT FOUND`
> rows below; the two buckets are reported separately rather than netted, because "no Microsoft page
> lists this action" and "nobody checked" are different failures and only the second is ours to fix.
| Entra claims in Table B | 15 collectors / **5** role definitions — **15 cited, 0 `NOT FOUND`**. *(Was "14 cited, 1 `NOT FOUND`". The `CrossTenantAccess` row's `NOT FOUND` asserted an absence from an incomplete read: `crossTenantAccessPolicy/partners/standard/read` does exist, in five roles. Same failure mode as the `namedLocations` error before it.)* |
| Azure DevOps claims in Table C | 5 — **5 cited** |

**Providers that could not be verified — 3:**

| Provider | Status |
|---|---|
| `Microsoft.AzureArcData` | Appears on **no** `permissions/` category page. Only `sqlServerInstances/read` is citable, and only via `built-in-roles/databases`. `dataControllers/read` and `sqlManagedInstances/read` are uncited. |
| `Microsoft.ClassicCompute` | Appears on **no** `permissions/` category page. Classic (ASM) is retired; the provider has been dropped from the RBAC reference. |
| `Microsoft.EdgeConfig` | Appears on **no** page anywhere. Not a real resource provider. |

**The 9 `NOT FOUND` actions, and what each means:**

| Action | Finding |
|---|---|
| `Microsoft.AzureArcData/dataControllers/read` | Provider absent from RBAC docs; type is real (ARM template reference) |
| `Microsoft.AzureArcData/sqlManagedInstances/read` | Same |
| `Microsoft.ClassicCompute/domainNames/read` | Provider absent from RBAC docs; retired deployment model |
| `Microsoft.AzureStackHCI/sites/read` | Provider **is** documented — and lists **no `sites` type** |
| `Microsoft.HybridCompute/sites/read` | Provider **is** documented — and lists **no `sites` type** |
| `Microsoft.EdgeConfig/sites/read` | Provider does not exist |
| `Microsoft.DBforPostgreSQL/servers/read` | Provider **is** documented — lists **only `flexibleServers`**. Single Server is retired. |
| `Microsoft.Network/natGateways/read` | Provider documented; only `natGateways/join/action` listed. Type is real — the read action is simply undocumented. |
| `Microsoft.RecoveryServices/replicationEligibilityResults/read` | Provider documented; no `replicationEligibilityResults` type listed. The ARM API exists. |

**Two of these are code findings, not documentation gaps**, and they corroborate AB#6444 independently:

- **`Hybrid/ArcSites`** declares three provider/type pairs. `Microsoft.EdgeConfig` is not a provider at all, and neither `AzureStackHCI` nor `HybridCompute` has a `sites` type. All three targets are unreal — which is a complete explanation for a collector that emits zero rows in every tenant.
- **`Databases/POSTGRE`** targets `Microsoft.DBforPostgreSQL/servers`, a type Microsoft no longer documents. Only `flexibleServers` exists. Same conclusion.

The other seven are gaps in Microsoft's own reference, not in Scout. `Microsoft.Network/natGateways/read` in particular is plainly a documentation omission — the type is real and Scout returns rows from it.

**Source column format.** Values are anchors relative to `https://learn.microsoft.com/azure/role-based-access-control/` (e.g. `permissions/compute#microsoftcompute` →
<https://learn.microsoft.com/azure/role-based-access-control/permissions/compute#microsoftcompute>). Entra anchors are relative to `https://learn.microsoft.com/` (`entra/permissions-reference#...` →
<https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#security-reader>). Azure DevOps anchors are relative to `https://learn.microsoft.com/azure/` (`devops/...`).

Where several rows share one provider page the same reference repeats — that is expected. **The `Source` column is the evidence for the `Verified: Doc` claim; it does not upgrade `Untested` rows.** No individual row here has been proven against a `Reader`-only principal — but the section's headline claim has: a Reader-only run on 2026-07-31 returned results identical to a fully-privileged one across 42 resource types. See the verification-status callout above for the method and its limits.

---

### Table A — ARM collectors (154)

`Minimum permission` is the control-plane action the call authorizes on. All of them are `.../read` and therefore inside Reader's `*/read`.

> **Every class-A row also needs `Microsoft.ResourceGraph/resources/read`, and it is listed on none
> of them.** Roughly 130 of the 154 collectors reach Azure through Azure Resource Graph, so the
> per-row `Minimum permission` cell is the *resource provider* action, not the whole ask. The
> conclusion is unaffected — `Reader`'s `*/read` covers the ARG action too — but the tables understate
> the minimum for the majority of rows and this note is the correction. Sources:
> [Permissions — Management and governance](https://learn.microsoft.com/azure/role-based-access-control/permissions/management-and-governance#microsoftresourcegraph)
> and [Permissions in Azure Resource Graph](https://learn.microsoft.com/azure/governance/resource-graph/overview#permissions-in-azure-resource-graph)
> — *"you must have appropriate rights … with at least `read` access to the resources you want to query."*

#### AI (27)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| AIFoundryHubs | `microsoft.machinelearningservices/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.MachineLearningServices/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| AIFoundryProjects | `microsoft.machinelearningservices/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.MachineLearningServices/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| AppliedAIServices | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| AzureAI | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| BotServices | `microsoft.botservice/botservices` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.BotService/botServices/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftbotservice` |
| ComputerVision | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| ContentModerator | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| ContentSafety | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| CustomVision | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| FaceAPI | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| FormRecognizer | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| HealthInsights | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| ImmersiveReader | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| MachineLearning | `microsoft.machinelearningservices/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.MachineLearningServices/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLComputes | `AZSC/ARMChild/MLComputes` | `Get-ScoutArmChildResource` — GET `{ws}/computes?api-version=2023-04-01` | C | `Microsoft.MachineLearningServices/workspaces/computes/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLDatasets | `AZSC/ARMChild/MLDatasets` | `Get-ScoutArmChildResource` — GET `{ws}/data` + `/versions` | C | `Microsoft.MachineLearningServices/workspaces/data/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLDatastores | `AZSC/ARMChild/MLDatastores` | `Get-ScoutArmChildResource` — GET `{ws}/datastores` | C | `Microsoft.MachineLearningServices/workspaces/datastores/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLEndpoints | `AZSC/ARMChild/MLEndpoints` | `Get-ScoutArmChildResource` — GET `{ws}/onlineEndpoints`, `/batchEndpoints`, `/deployments` | C | `Microsoft.MachineLearningServices/workspaces/onlineEndpoints/read`, `/batchEndpoints/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLModels | `AZSC/ARMChild/MLModels` | `Get-ScoutArmChildResource` — GET `{ws}/models` + `/versions` | C | `Microsoft.MachineLearningServices/workspaces/models/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| MLPipelines | `AZSC/ARMChild/MLPipelines` | `Get-ScoutArmChildResource` — GET `{ws}/jobs?$filter=jobType eq 'Pipeline'` | C | `Microsoft.MachineLearningServices/workspaces/jobs/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftmachinelearningservices` |
| OpenAIAccounts | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| OpenAIDeployments | `AZSC/ARMChild/OpenAIDeployments` | `Get-ScoutArmChildResource` — GET `{acct}/deployments?api-version=2023-05-01` | C | `Microsoft.CognitiveServices/accounts/deployments/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| SearchIndexes | `AZSC/ARMChild/SearchIndexes` | `Get-ScoutArmChildResource` — GET `{svc}/indexes?api-version=2023-11-01` | C | `Microsoft.Search/searchServices/indexes/read` (control plane) | Azure RBAC **Reader** | Untested | `permissions/ai-machine-learning#microsoftsearch` |
| SearchServices | `microsoft.search/searchservices` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Search/searchServices/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftsearch` |
| SpeechService | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| TextAnalytics | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |
| Translator | `microsoft.cognitiveservices/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.CognitiveServices/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/ai-machine-learning#microsoftcognitiveservices` |

*`SearchIndexes` marked Untested: the ARM control-plane `indexes` path is served by the Search management plane, but Search index enumeration also exists as a data-plane API. The collect layer uses `Invoke-AzRestMethod` against ARM, so it should authorize on `*/read`; not proven against a Reader-only principal.*

#### Analytics (6)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| Databricks | `microsoft.databricks/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Databricks/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/analytics#microsoftdatabricks` |
| DataExplorerCluster | `microsoft.kusto/clusters` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Kusto/clusters/read` | Azure RBAC **Reader** | Doc | `permissions/analytics#microsoftkusto` |
| EvtHub | `microsoft.eventhub/namespaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.EventHub/namespaces/read` | Azure RBAC **Reader** | Doc | `permissions/integration#microsofteventhub` |
| Purview | `microsoft.purview/accounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Purview/accounts/read` | Azure RBAC **Reader** | Doc | `permissions/analytics#microsoftpurview` |
| Streamanalytics | `microsoft.streamanalytics/streamingjobs` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.StreamAnalytics/streamingJobs/read` | Azure RBAC **Reader** | Doc | `permissions/internet-of-things#microsoftstreamanalytics` |
| Synapse | `microsoft.synapse/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Synapse/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/analytics#microsoftsynapse` |

#### Compute (14)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| AvailabilitySets | `microsoft.compute/availabilitysets` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Compute/availabilitySets/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftcompute` |
| AVD | `microsoft.desktopvirtualization/hostpools` | `Get-ScoutRawInventory` (ARG `desktopvirtualizationresources`) | A | `Microsoft.DesktopVirtualization/hostPools/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftdesktopvirtualization` |
| AVDApplicationGroups | `microsoft.desktopvirtualization/applicationgroups` | `Get-ScoutRawInventory` (ARG `desktopvirtualizationresources`) | A | `Microsoft.DesktopVirtualization/applicationGroups/read` | Azure RBAC **Reader** | **Uncited** | n/a |
| AVDApplications | `AZSC/ARMChild/AVDApplications` | `Get-ScoutArmChildResource` — GET `{appgroup}/applications?api-version=2022-09-09` | C | `Microsoft.DesktopVirtualization/applicationGroups/applications/read` | Azure RBAC **Reader** | **Uncited** | n/a |
| AVDAzureLocal | `AZSC/AVD/AzureLocalSessionHost` | `ConvertTo-ScoutAvdAzureLocalSessionHost` over ARG `microsoft.azurestackhci/*` + `desktopvirtualizationresources` | A (derived) | `Microsoft.AzureStackHCI/*/read` + `Microsoft.DesktopVirtualization/hostPools/sessionHosts/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` + `permissions/compute#microsoftdesktopvirtualization` |
| AVDScalingPlans | `microsoft.desktopvirtualization/scalingplans` | `Get-ScoutRawInventory` (ARG `desktopvirtualizationresources`) | A | `Microsoft.DesktopVirtualization/scalingPlans/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftdesktopvirtualization` |
| AVDSessionHosts | `microsoft.desktopvirtualization/hostpools/sessionhosts` | `Get-ScoutRawInventory` (ARG `desktopvirtualizationresources`) | A | `Microsoft.DesktopVirtualization/hostPools/sessionHosts/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftdesktopvirtualization` |
| AVDWorkspaces | `microsoft.desktopvirtualization/workspaces` | `Get-ScoutRawInventory` (ARG `desktopvirtualizationresources`) | A | `Microsoft.DesktopVirtualization/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftdesktopvirtualization` |
| CloudServices | `microsoft.classiccompute/domainnames` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ClassicCompute/domainNames/read` | Azure RBAC **Reader** | **Uncited** | **NOT FOUND** — `Microsoft.ClassicCompute` appears on no `permissions/` category page. Classic (ASM) deployments are retired; the provider has been dropped from the RBAC reference. |
| **VirtualMachine** | `microsoft.compute/virtualmachines` **+** `AZSC/Operational/VirtualMachine`, `AZSC/VM/SKU`, `AZSC/VM/Quotas` | `Get-ScoutRawInventory` **+** `Get-ScoutOperationalCollectorEnrichment` (metrics, `replicationEligibilityResults`, **POST CostManagement/query**) **+** `Get-ScoutVmQuotas` / `Get-ScoutVmSkuDetails` | A + F + H + I | `Microsoft.Compute/virtualMachines/read`, `microsoft.insights/metrics/read`, `Microsoft.RecoveryServices/replicationEligibilityResults/read`, `Microsoft.CostManagement/query/read`, `Microsoft.Compute/locations/usages/read`, `Microsoft.Compute/skus/read` | Azure RBAC **Reader** | Doc for reads; **Untested** for the cost POST authorizing on `/read` | `permissions/compute#microsoftcompute`, `permissions/monitor#microsoftinsights`, `permissions/management-and-governance#microsoftcostmanagement`. ⚠️ `Microsoft.RecoveryServices/replicationEligibilityResults/read` is **NOT FOUND** — `Microsoft.RecoveryServices` is documented but lists no `replicationEligibilityResults` type |
| VirtualMachineScaleSet | `microsoft.compute/virtualmachinescalesets` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Compute/virtualMachineScaleSets/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftcompute` |
| VMDisk | `microsoft.compute/disks` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Compute/disks/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftcompute` |
| **VMOperationalData** | `microsoft.compute/virtualmachines` **+** `AZSC/Operational/VMOperationalData` | `Get-ScoutRawInventory` (ARG `patchassessmentresources`, `patchinstallationresources`) → shaped by `Get-ScoutOperationalCollectorEnrichment` | A | `Microsoft.Compute/virtualMachines/read` + ARG read of the patch tables | Azure RBAC **Reader** | Doc — **was** the only Azure collector needing a non-read action; `assessPatches` POST removed this session | `permissions/compute#microsoftcompute` |
| VMWare | `Microsoft.AVS/privateClouds` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AVS/privateClouds/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftavs` |

#### Containers (6)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| AKS | `microsoft.containerservice/managedclusters` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ContainerService/managedClusters/read` | Azure RBAC **Reader** | Doc | `permissions/containers#microsoftcontainerservice` |
| ARO | `microsoft.redhatopenshift/openshiftclusters` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.RedHatOpenShift/openShiftClusters/read` | Azure RBAC **Reader** | Doc | `permissions/containers#microsoftredhatopenshift` |
| ContainerApp | `microsoft.app/containerapps` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.App/containerApps/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftapp` |
| ContainerAppEnv | `microsoft.app/managedenvironments` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.App/managedEnvironments/read` | Azure RBAC **Reader** | Doc | `permissions/compute#microsoftapp` |
| ContainerGroups | `microsoft.containerinstance/containergroups` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ContainerInstance/containerGroups/read` | Azure RBAC **Reader** | Doc | `permissions/containers#microsoftcontainerinstance` |
| ContainerRegistries | `microsoft.containerregistry/registries` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ContainerRegistry/registries/read` | Azure RBAC **Reader** | Doc | `permissions/containers#microsoftcontainerregistry` |

#### Databases (13)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| CosmosDB | `microsoft.documentdb/databaseaccounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DocumentDB/databaseAccounts/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftdocumentdb` |
| MariaDB | `microsoft.dbformariadb/servers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DBforMariaDB/servers/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftdbformariadb` |
| MySQL | `microsoft.dbformysql/servers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DBforMySQL/servers/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftdbformysql` |
| MySQLflexible | `Microsoft.DBforMySQL/flexibleServers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DBforMySQL/flexibleServers/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftdbformysql` |
| **POSTGRE** ⚠️ | `microsoft.dbforpostgresql/servers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DBforPostgreSQL/servers/read` | Azure RBAC **Reader** | **BROKEN** — emits zero rows regardless of permission (AB#6444 §6) | **NOT FOUND** ⚠️ `permissions/databases#microsoftdbforpostgresql` lists **only `flexibleServers/read`** — there is no `servers` type. Single Server is retired; the collector targets a type that no longer exists. |
| POSTGREFlexible | `Microsoft.DBforPostgreSQL/flexibleServers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.DBforPostgreSQL/flexibleServers/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftdbforpostgresql` |
| RedisCache | `microsoft.cache/redis` + `microsoft.cache/redisenterprise` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Cache/redis/read`, `Microsoft.Cache/redisEnterprise/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftcache` |
| SQLDB | `microsoft.sql/servers/databases` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Sql/servers/databases/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsql` |
| SQLMI | `microsoft.sql/managedInstances` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Sql/managedInstances/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsql` |
| SQLMIDB | `microsoft.sql/managedinstances/databases` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Sql/managedInstances/databases/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsql` |
| SQLPOOL | `microsoft.sql/servers/elasticPools` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Sql/servers/elasticPools/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsql` |
| SQLSERVER | `microsoft.sql/servers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Sql/servers/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsql` |
| SQLVM | `microsoft.sqlvirtualmachine/sqlvirtualmachines` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.SqlVirtualMachine/sqlVirtualMachines/read` | Azure RBAC **Reader** | Doc | `permissions/databases#microsoftsqlvirtualmachine` |

#### Hybrid (16)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| ArcDataControllers | `microsoft.azurearcdata/datacontrollers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureArcData/dataControllers/read` | Azure RBAC **Reader** | **Uncited** | **NOT FOUND** — `Microsoft.AzureArcData` appears on no `permissions/` category page. The type exists in the ARM template reference; only `sqlServerInstances/read` is cited anywhere in RBAC docs. |
| ArcExtensions | `microsoft.hybridcompute/machines/extensions` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.HybridCompute/machines/extensions/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsofthybridcompute` |
| ArcGateways | `microsoft.hybridcompute/gateways` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.HybridCompute/gateways/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsofthybridcompute` |
| ArcKubernetes | `microsoft.kubernetes/connectedclusters` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Kubernetes/connectedClusters/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftkubernetes` |
| ArcResourceBridge | `microsoft.resourceconnector/appliances` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ResourceConnector/appliances/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftresourceconnector` |
| **ArcServerOperationalData** | `microsoft.hybridcompute/machines` **+** `AZSC/Operational/ArcServerOperationalData` | `Get-ScoutRawInventory` (ARG `patchassessmentresources`, `patchinstallationresources`) → shaped by `Get-ScoutOperationalCollectorEnrichment` | A | `Microsoft.HybridCompute/machines/read` + ARG read of the patch tables | Azure RBAC **Reader** | Doc — `assessPatches` POST removed this session | `permissions/hybrid-multicloud#microsofthybridcompute` |
| **ARCServers** | `microsoft.hybridcompute/machines` **+** `AZSC/Operational/ARCServers` | `Get-ScoutRawInventory` **+** `Get-ScoutOperationalCollectorEnrichment` (**POST** `policyStates/latest/queryResults`, **POST** `CostManagement/query`) | A + H | `Microsoft.HybridCompute/machines/read`, `Microsoft.PolicyInsights/policyStates/queryResults/read`, `Microsoft.CostManagement/query/read` | Azure RBAC **Reader** | Doc for the type read; **Untested** for the two POSTs authorizing on `/read` | `permissions/hybrid-multicloud#microsofthybridcompute`, `permissions/management-and-governance#microsoftpolicyinsights`, `permissions/management-and-governance#microsoftcostmanagement` |
| **ArcSites** ⚠️ | `microsoft.azurestackhci/sites` + `microsoft.edgeconfig/sites` + `microsoft.hybridcompute/sites` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/sites/read`, `Microsoft.EdgeConfig/sites/read`, `Microsoft.HybridCompute/sites/read` | Azure RBAC **Reader** | **BROKEN** — emits zero rows regardless of permission (AB#6444 §6) | **NOT FOUND — all three** ⚠️ `AzureStackHCI` and `HybridCompute` are documented at `permissions/hybrid-multicloud` but **neither lists a `sites` type**; `Microsoft.EdgeConfig` appears on **no** provider page. Corroborates AB#6444. |
| ArcSQLManagedInstances | `microsoft.azurearcdata/sqlmanagedinstances` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureArcData/sqlManagedInstances/read` | Azure RBAC **Reader** | **Uncited** | **NOT FOUND** — same cause as `ArcDataControllers` |
| ArcSQLServers | `microsoft.azurearcdata/sqlserverinstances` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureArcData/sqlServerInstances/read` | Azure RBAC **Reader** | **Uncited** | `built-in-roles/databases#azure-connected-sql-server-onboarding` — **not on any `permissions/` provider page** |
| Clusters | `microsoft.azurestackhci/clusters` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/clusters/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` |
| GalleryImages | `microsoft.azurestackhci/galleryimages` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/galleryImages/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` |
| LogicalNetworks | `microsoft.azurestackhci/logicalnetworks` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/logicalNetworks/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` |
| MarketplaceGalleryImages | `microsoft.azurestackhci/marketplacegalleryimages` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/marketplaceGalleryImages/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` |
| StorageContainers | `microsoft.azurestackhci/storagecontainers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/storageContainers/read` | Azure RBAC **Reader** | Doc | `permissions/hybrid-multicloud#microsoftazurestackhci` |
| **VirtualMachines** ⚠️ | `microsoft.azurestackhci/virtualmachineinstances` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AzureStackHCI/virtualMachineInstances/read` | Azure RBAC **Reader** | **BROKEN** — emits zero rows regardless of permission (AB#6444 §6) | `permissions/hybrid-multicloud#microsoftazurestackhci` |

#### Identity — the ARM one (1)

*The other 15 Identity collectors are Microsoft Graph and appear in Table B.*

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| ManagedIds | `Microsoft.ManagedIdentity/userAssignedIdentities` | `Get-ScoutApiResources` — GET `/subscriptions/{id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities?api-version=2023-01-31` | D | `Microsoft.ManagedIdentity/userAssignedIdentities/read` | Azure RBAC **Reader** | Doc | `permissions/identity#microsoftmanagedidentity` |

#### Integration (2) · IoT (1)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| APIM | `microsoft.apimanagement/service` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ApiManagement/service/read` | Azure RBAC **Reader** | Doc | `permissions/integration#microsoftapimanagement` |
| ServiceBUS | `microsoft.servicebus/namespaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.ServiceBus/namespaces/read` | Azure RBAC **Reader** | Doc | `permissions/integration#microsoftservicebus` |
| IOTHubs | `microsoft.devices/iothubs` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Devices/IotHubs/read` | Azure RBAC **Reader** | Doc | `permissions/internet-of-things#microsoftdevices` |

#### Management — ARM (14)

*The five DevOps collectors live in this category on disk but are Azure DevOps, not Azure RBAC — see Table C.*

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| AdvisorScore | `Microsoft.Advisor/advisorScore` | `Get-ScoutApiResources` — GET `/providers/Microsoft.Advisor/advisorScore?api-version=2023-01-01` | D | `Microsoft.Advisor/advisorScore/read` | Azure RBAC **Reader** | Doc | `permissions/management-and-governance#microsoftadvisor` |
| AllSubscriptions | `AZSC/Management/SubscriptionEnrichment` | `Get-ScoutOperationalCollectorEnrichment` over ARG `resourcecontainers` mgChain | F | `Microsoft.Resources/subscriptions/read`, `Microsoft.Management/managementGroups/read` | Azure RBAC **Reader** — **must be assigned at MG scope** for the mgChain to resolve | Untested | `permissions/management-and-governance#microsoftresources` + `permissions/management-and-governance#microsoftmanagement` |
| AutomationAccounts | `microsoft.automation/automationaccounts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Automation/automationAccounts/read` | Azure RBAC **Reader** | **Uncited** | n/a |
| Backup | `microsoft.recoveryservices/vaults/backuppolicies` | `Get-ScoutRawInventory` (ARG `recoveryservicesresources`) | A | `Microsoft.RecoveryServices/vaults/backupPolicies/read` | Azure RBAC **Reader** | Doc | `permissions/management-and-governance#microsoftrecoveryservices` |
| **CustomRoleDefinitions** ⚠️ | `AZSC/Management/RoleDefinition` | `Get-ScoutTenantWideResource` — `Get-AzRoleDefinition -Custom` | E | `Microsoft.Authorization/roleDefinitions/read` | Azure RBAC **Reader** at MG scope | **BROKEN** — gated on `-IncludeTenantWideResources`, a switch with no production caller (AB#6444 §6). Permission answer is moot until wired. | `permissions/management-and-governance#microsoftauthorization` |
| LighthouseDelegations | `Microsoft.ManagedServices/registrationDefinitions` | `Get-ScoutRawInventory` (ARG `managedserviceresources`) | A | `Microsoft.ManagedServices/registrationDefinitions/read` | Azure RBAC **Reader** | Doc — was BROKEN (the type is real but no pass read the one table carrying it); fixed AB#6771 | `permissions/management-and-governance#microsoftmanagedservices` |
| MaintenanceConfigurations | `microsoft.maintenance/maintenanceconfigurations` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Maintenance/maintenanceConfigurations/read` | Azure RBAC **Reader** | Doc | `permissions/management-and-governance#microsoftmaintenance` |
| **ManagementGroups** ⚠️ | `AZSC/Management/ManagementGroup` | `Get-ScoutTenantWideResource` — `Get-AzManagementGroup -Expand -Recurse` | E | `Microsoft.Management/managementGroups/read` | Azure RBAC **Reader assigned at MG scope**; whether **Management Group Reader** is additionally required is **unresolved** | **BROKEN** — same `-IncludeTenantWideResources` gate. The permission question is confounded by the defect: no run has ever exercised this path in production. | `permissions/management-and-governance#microsoftmanagement` |
| PolicyComplianceStates | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzPolicyState` | B | `Microsoft.PolicyInsights/policyStates/queryResults/read` | Azure RBAC **Reader** | Doc | `permissions/management-and-governance#microsoftpolicyinsights` |
| **PolicyDefinitions** ⚠️ | `AZSC/Management/PolicyDefinition` | `Get-ScoutTenantWideResource` (E); `Get-ScoutApiResources` also GETs `Microsoft.Authorization/policyDefinitions?api-version=2023-04-01` (D) | E / D | `Microsoft.Authorization/policyDefinitions/read` | Azure RBAC **Reader** | **BROKEN** — the collector consumes the class-E type, which the ungated switch never produces (AB#6444 §6) | `permissions/management-and-governance#microsoftauthorization` |
| **PolicySetDefinitions** ⚠️ | `AZSC/Management/PolicySetDefinition` | `Get-ScoutTenantWideResource` (E); `Get-ScoutApiResources` also GETs `Microsoft.Authorization/policySetDefinitions` (D) | E / D | `Microsoft.Authorization/policySetDefinitions/read` | Azure RBAC **Reader** | **BROKEN** — same cause | `permissions/management-and-governance#microsoftauthorization` |
| RecoveryVault | `microsoft.recoveryservices/vaults` | `Get-ScoutRawInventory` (ARG `recoveryservicesresources`) | A | `Microsoft.RecoveryServices/vaults/read` | Azure RBAC **Reader** | Doc | `permissions/management-and-governance#microsoftrecoveryservices` |
| ReservationRecom | `Microsoft.Consumption/reservationRecommendations` | `Get-ScoutApiResources` — GET `/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01` | D | `Microsoft.Consumption/reservationRecommendations/read` | Azure RBAC **Reader** | Doc — **but gated by the EA/MCA billing setting; see note below** | `permissions/management-and-governance#microsoftconsumption` |
| SupportTickets | `Microsoft.Support/supportTickets` | `Get-ScoutRawInventory` (ARG `supportresources`; skipped in Azure US Government) | A | `Microsoft.Support/supportTickets/read` | Azure RBAC **Reader** | Doc | `permissions/general#microsoftsupport` |

#### Monitor (24)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| ActionGroups | `microsoft.insights/actiongroups` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/actionGroups/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| ActivityLogAlertRules | `microsoft.insights/activitylogalerts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/activityLogAlerts/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| AppInsights | `microsoft.insights/components` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/components/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| AppInsightsAvailabilityTests | `microsoft.insights/webtests` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/webTests/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| **AppInsightsContinuousExport** ⚠️ | `AZSC/ARMChild/AppInsightsContinuousExport` | **none** — `Get-ScoutArmChildResource` deliberately never produces this type (Azure retired the endpoint) | — | n/a | n/a | **BROKEN / RETIRED** — permanently empty; not a permission problem, but will look like one | n/a |
| AppInsightsProactiveDetection | `AZSC/ARMChild/AppInsightsProactiveDetection` | `Get-ScoutArmChildResource` — GET `{comp}/ProactiveDetectionConfigs?api-version=2018-05-01-preview` | C | `Microsoft.Insights/components/ProactiveDetectionConfigs/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| AppInsightsWebTests | `microsoft.insights/webtests` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/webTests/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| **AppInsightsWorkItems** ⚠️ | `AZSC/ARMChild/AppInsightsWorkItems` | **none** — endpoint retired by Azure | — | n/a | n/a | **BROKEN / RETIRED** — permanently empty | n/a |
| AutoscaleSettings | `microsoft.insights/autoscalesettings` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/autoscaleSettings/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| DataCollectionEndpoints | `microsoft.insights/datacollectionendpoints` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/dataCollectionEndpoints/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| DataCollectionRules | `microsoft.insights/datacollectionrules` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/dataCollectionRules/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| LAWorkspaceLinkedServices | `AZSC/ARMChild/LAWorkspaceLinkedServices` | `Get-ScoutArmChildResource` — GET `{ws}/linkedServices?api-version=2020-08-01` | C | `Microsoft.OperationalInsights/workspaces/linkedServices/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftoperationalinsights` |
| LAWorkspaceSavedSearches | `AZSC/ARMChild/LAWorkspaceSavedSearches` | `Get-ScoutArmChildResource` — GET `{ws}/savedSearches?api-version=2020-08-01` | C | `Microsoft.OperationalInsights/workspaces/savedSearches/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftoperationalinsights` |
| LAWorkspaceSolutions | `microsoft.operationsmanagement/solutions` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.OperationsManagement/solutions/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftoperationsmanagement` |
| MetricAlertRules | `microsoft.insights/metricalerts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/metricAlerts/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| MonitorMetricsIngestion | `microsoft.operationalinsights/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.OperationalInsights/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftoperationalinsights` |
| MonitorPrivateLinkScopes | `microsoft.insights/privatelinkscopes` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/privateLinkScopes/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| MonitorWorkbooks | `microsoft.insights/workbooks` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/workbooks/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| Outages | `AZSC/Monitor/Outage` | `Get-ScoutApiResources` — GET `/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01` → `Get-ScoutOutageResource` | D | `Microsoft.ResourceHealth/events/read` | Azure RBAC **Reader** | Doc — was BROKEN (the transform ran *before* the API sweep); fixed AB#6770 | `permissions/management-and-governance#microsoftresourcehealth` |
| ResourceDiagnosticSettings | `AZSC/ARMChild/ResourceDiagnosticSettings` | `Get-ScoutArmChildResource` — GET `{resourceId}/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview` | B | `Microsoft.Insights/diagnosticSettings/read` | Azure RBAC **Reader** | Doc — was BROKEN (`diagnosticSettings` is an extension resource ARG indexes in no table); re-sourced AB#6769, scoped to 20 parent types | `permissions/monitor#microsoftinsights` |
| ScheduledQueryRules | `microsoft.insights/scheduledqueryrules` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Insights/scheduledQueryRules/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| SmartDetectorAlertRules | `microsoft.alertsmanagement/smartdetectoralertrules` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.AlertsManagement/smartDetectorAlertRules/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftalertsmanagement` |
| SubscriptionDiagnosticSettings | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzDiagnosticSetting` | B | `Microsoft.Insights/diagnosticSettings/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftinsights` |
| Workspaces | `microsoft.operationalinsights/workspaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.OperationalInsights/workspaces/read` | Azure RBAC **Reader** | Doc | `permissions/monitor#microsoftoperationalinsights` |

#### Networking (21)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| ApplicationGateways | `microsoft.network/applicationgateways` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/applicationGateways/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| AzureFirewall | `microsoft.network/azurefirewalls` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/azureFirewalls/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| BastionHosts | `microsoft.network/bastionhosts` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/bastionHosts/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| Connections | `microsoft.network/connections` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/connections/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| ExpressRoute | `microsoft.network/expressroutecircuits` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/expressRouteCircuits/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| Frontdoor | `microsoft.network/frontdoors` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/frontDoors/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| LoadBalancer | `microsoft.network/loadbalancers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/loadBalancers/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| NATGateway | `microsoft.network/natgateways` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/natGateways/read` | Azure RBAC **Reader** | **Uncited** | **NOT FOUND** ⚠️ `permissions/networking#microsoftnetwork` lists only `natGateways/join/action` and the diagnostic-settings sub-paths — no `natGateways/read`. The type exists; the action is undocumented. `*/read` almost certainly still covers it. |
| NetworkInterface | `microsoft.network/networkinterfaces` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/networkInterfaces/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| NetworkSecurityGroup | `microsoft.network/networksecuritygroups` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/networkSecurityGroups/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| NetworkWatchers | `microsoft.network/networkwatchers` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/networkWatchers/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| PrivateDNS | `microsoft.network/privatednszones` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/privateDnsZones/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| PrivateEndpoint | `microsoft.network/privateendpoints` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/privateEndpoints/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| PublicDNS | `microsoft.network/dnszones` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/dnsZones/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| PublicIP | `microsoft.network/publicipaddresses` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/publicIPAddresses/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| RouteTables | `microsoft.network/routetables` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/routeTables/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| TrafficManager | `microsoft.network/trafficmanagerprofiles` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/trafficManagerProfiles/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| VirtualNetwork | `microsoft.network/virtualnetworks` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/virtualNetworks/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| VirtualNetworkGateways | `microsoft.network/virtualnetworkgateways` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/virtualNetworkGateways/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| VirtualWAN | `microsoft.network/virtualwans` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/virtualWans/read` | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |
| vNETPeering | `microsoft.network/virtualnetworks` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Network/virtualNetworks/read` (peerings are inline properties) | Azure RBAC **Reader** | Doc | `permissions/networking#microsoftnetwork` |

#### Security (5)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| DefenderAlerts | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzSecurityAlert` | B | `Microsoft.Security/alerts/read` | Azure RBAC **Reader** (Azure RBAC *Security Reader* is redundant) | Doc | `permissions/security#microsoftsecurity` |
| DefenderAssessments | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzSecurityAssessment`; also ARG `securityresources` | B / A | `Microsoft.Security/assessments/read` | Azure RBAC **Reader** | Doc | `permissions/security#microsoftsecurity` |
| DefenderPricing | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzSecurityPricing` | B | `Microsoft.Security/pricings/read` | Azure RBAC **Reader** | Doc | `permissions/security#microsoftsecurity` |
| DefenderSecureScore | `AZSC/Subscription/SecurityPolicySweep` | `Get-ScoutSubscriptionSecurityPolicySweep` — `Get-AzSecuritySecureScore`, `Get-AzSecuritySecureScoreControl` | B | `Microsoft.Security/secureScores/read`, `/secureScoreControls/read` | Azure RBAC **Reader** | Doc | `permissions/security#microsoftsecurity` |
| Vault | `microsoft.keyvault/vaults` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.KeyVault/vaults/read` | Azure RBAC **Reader** | Doc — **control plane only.** Vault metadata, network ACLs, RBAC/access-policy mode, soft-delete and purge-protection flags. **No secret, key, or certificate value is read.** | `permissions/security#microsoftkeyvault` |

#### Storage (2) · Web (2)

| Collector | Resource type(s) collected | Producer (src/collect fn) | Access class | Minimum permission | Role required | Verified | Source |
|---|---|---|---|---|---|---|---|
| NetApp | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes/read` | Azure RBAC **Reader** | Doc | `permissions/storage#microsoftnetapp` |
| **StorageAccounts** | `microsoft.storage/storageaccounts` **+** `AZSC/Operational/StorageAccount` | `Get-ScoutRawInventory` **+** `Get-ScoutOperationalCollectorEnrichment` — `Get-AzStorageBlobServiceProperty`, `Get-AzStorageFileServiceProperty` | A + F | `Microsoft.Storage/storageAccounts/read`, `/blobServices/read`, `/fileServices/read` | Azure RBAC **Reader** | Doc — **control plane only.** Service *properties* (versioning, soft delete, CORS, retention). **No blob or file content, and no account keys, are read.** | `permissions/storage#microsoftstorage` |
| APPServicePlan | `microsoft.web/serverfarms` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Web/serverFarms/read` | Azure RBAC **Reader** | Doc | `permissions/web-and-mobile#microsoftweb` |
| APPServices | `microsoft.web/sites` | `Get-ScoutRawInventory` (ARG `resources`) | A | `Microsoft.Web/sites/read` | Azure RBAC **Reader** | Doc | `permissions/web-and-mobile#microsoftweb` |

---

### Table B — Entra / Identity collectors (15)

All produced by `src/collect/Start-ScoutEntraExtraction.ps1`, all against `/v1.0` (no `/beta`). Each query is individually wrapped in try/catch that prints `[SKIP]` and continues — **a denied permission produces an empty worksheet, never an error.**

**Two identity models, and they use different permission systems:**

- **Running as a user** (the normal case — the Graph token comes from `az account get-access-token`, so an interactive `az login` is required *in addition to* `Connect-AzAccount`): effective rights come from the user's **Entra directory role**, not from consented app roles. Use the "Entra role that grants it" column.
- **Running as a service principal**: an app-only token, requiring the **Graph application permissions** in the third column, each with admin consent.

**The `Entra role` answer is two roles, not one.** `Global Reader` works but Microsoft classifies it as a **privileged** role — the read-only counterpart to Global Administrator, spanning all of Microsoft 365. The lower-privilege pairing is **`Directory Readers`** (not privileged) for 11 collectors, plus **Entra `Security Reader`** (privileged, but scoped to security/ID Protection/Conditional Access) for the remaining 4.

**Conditional Access boundary — RESOLVED.** `Directory Readers` does **not** include `microsoft.directory/conditionalAccessPolicies/standard/read`. Microsoft's least-privilege-by-task table names **Entra `Security Reader`** as the least privileged role for "Read all configuration" and "Read named locations" under Conditional Access, and the Security Reader role definition lists `conditionalAccessPolicies/standard/read` explicitly. So **two roles are needed**, not one. Sources: [Least privileged roles by task — Conditional Access](https://learn.microsoft.com/entra/identity/role-based-access-control/delegate-by-task#security---conditional-access-least-privileged-roles), [Built-in roles — Security Reader](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#security-reader), [Built-in roles — Directory Readers](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#directory-readers).

| Collector | Graph endpoint | Graph permission | Entra role that grants it | Privileged? | Verified | Source |
|---|---|---|---|---|---|---|
| Users | `/v1.0/users` | `User.Read.All` | Entra **Directory Readers** (`microsoft.directory/users/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| Groups | `/v1.0/groups` | `Group.Read.All` | Entra **Directory Readers** (`groups/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| AppRegistrations | `/v1.0/applications` | `Application.Read.All` | Entra **Directory Readers** (`applications/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| ServicePrincipals | `/v1.0/servicePrincipals` | `Application.Read.All` | Entra **Directory Readers** (`servicePrincipals/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| ManagedIdentities | `/v1.0/servicePrincipals?$filter=servicePrincipalType eq 'ManagedIdentity'` | `Application.Read.All` | Entra **Directory Readers** (same action) | No | Doc | `entra/permissions-reference#directory-readers` |
| DirectoryRoles | `/v1.0/directoryRoles` | `RoleManagement.Read.Directory` | Entra **Directory Readers** (`directoryRoles/standard/read`, `/members/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| PIMAssignments | `/v1.0/roleManagement/directory/roleAssignments?$expand=principal,roleDefinition` | `RoleManagement.Read.Directory` | Entra **Directory Readers** (`roleAssignments/standard/read`, `roleDefinitions/standard/read`) | No | Doc for the directory-role path; **Untested** whether `$expand=principal` needs more | `entra/permissions-reference#directory-readers` |
| AdminUnits | `/v1.0/directory/administrativeUnits` | `AdministrativeUnit.Read.All` | Entra **Directory Readers** (`administrativeUnits/standard/read`, `/members/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| Domains | `/v1.0/domains` | `Domain.Read.All` | Entra **Directory Readers** (`domains/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| Licensing | `/v1.0/subscribedSkus` | `Organization.Read.All` | Entra **Directory Readers** (`subscribedSkus/standard/read`) | No | Doc | `entra/permissions-reference#directory-readers` |
| **ConditionalAccess** | `/v1.0/identity/conditionalAccess/policies` | `Policy.Read.All` (or least-privileged `Policy.Read.ConditionalAccess`) | Entra **Security Reader** (`conditionalAccessPolicies/standard/read`) — **Directory Readers is NOT enough** | **Yes** | Doc | `entra/permissions-reference#security-reader` |
| **NamedLocations** | `/v1.0/identity/conditionalAccess/namedLocations` | `Policy.Read.All` | Entra **Security Reader** ("Read named locations", least privileged) | **Yes** | Doc | `entra/permissions-reference#security-reader` |
| **SecurityPolicies** | `/v1.0/policies/authorizationPolicy` | `Policy.Read.All` | Entra **Security Reader** (`authorizationPolicy/standard/read`) | **Yes** | Doc | `entra/permissions-reference#security-reader` |
| **RiskyUsers** | `/v1.0/identityProtection/riskyUsers` | `IdentityRiskyUser.Read.All` | Entra **Security Reader** (`identityProtection/allProperties/read`) | **Yes** | Doc — **also requires an Entra ID P2 licence.** A P1 tenant with the permission granted still returns nothing. | `entra/permissions-reference#security-reader` |
| **CrossTenantAccess** | `/v1.0/policies/crossTenantAccessPolicy/partners` | `Policy.Read.All` | **Neither recommended role covers this call.** Needs a role holding `microsoft.directory/crossTenantAccessPolicy/partners/standard/read` — **Security Administrator**, **Tenant Governance Administrator**, or **Global Reader** | **No** — this is the one collector the recommended pair does not reach | Doc | `entra/permissions-reference` — Entra **Security Reader** lists only `crossTenantAccessPolicy/partners/templates/.../standard/read`, and **`Directory Readers` has no `crossTenantAccessPolicy` entry at all**. The `partners` action **does** exist and is held by Global Administrator, Global Reader, Security Administrator, Teams Administrator and Tenant Governance Administrator |

**Two Graph queries are issued that no collector consumes** — `/v1.0/identity/identityProviders` (`IdentityProvider.Read.All`) and `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy`. Their output is discarded. `AuditLog.Read.All` is checked by the pre-flight but `/v1.0/auditLogs/signIns` is never called; it can be dropped from the ask entirely.

---

### Table C — Azure DevOps collectors (5)

**Azure DevOps is a fourth, entirely separate permission system.** These are DevOps security-group permissions — not Azure RBAC, not Entra directory roles. An identity with Owner on every Azure subscription and Global Administrator in Entra still gets zero rows here without DevOps org membership.

Auth: `Get-AzAccessToken -ResourceUrl '499b84ac-1321-427f-aa17-267ca6975798'` (the Azure DevOps first-party app) at `Start-ScoutDevOpsExtraction.ps1:83`, or a PAT via `-DevOpsPat`. Org discovery is `app.vssps.visualstudio.com/_apis/profile/profiles/me` then `/_apis/accounts?memberId=`.

| Collector | ADO API | Minimum ADO access | Verified | Source |
|---|---|---|---|---|
| DevOpsProjects | `GET https://dev.azure.com/{org}/_apis/projects?api-version=7.0` | Org member + project-level **View project-level information** | Untested | `devops/organizations/security/permissions#project-level-permissions` — *"To access project-level resources, the View project-level information permission must be set to Allow. This permission gates all other project-level permissions."* |
| DevOpsPipelines | `GET .../{org}/{project}/_apis/pipelines?api-version=7.0` | Project **View build pipeline** | Untested | `devops/organizations/security/permissions#pipeline-or-build-object-level` (`Build, ViewBuildDefinition`); role matrix at `devops/pipelines/policies/permissions#set-pipeline-permissions-in-azure-pipelines` shows **Readers** have *View build pipeline* |
| DevOpsServiceConnections | `GET .../{org}/{project}/_apis/serviceendpoint/endpoints?api-version=7.0` | **Reader** on service connections (returns metadata only — no secrets) | Untested | `devops/pipelines/policies/permissions#set-service-connection-security-in-azure-pipelines` — *"Reader: Can view service connections."* |
| DevOpsRepositories | `GET .../{org}/{project}/_apis/git/repositories?api-version=7.0` | **Read** on Git repositories | Untested | `devops/repos/git/set-git-repository-permissions#default-repository-permissions` — **Read** (clone, fetch, explore) is granted to the **Readers** group |
| DevOpsAgentPools | `GET .../{org}/_apis/distributedtask/pools?api-version=7.0` | Org-level **Reader** on agent pools | Untested | `devops/organizations/security/about-security-roles#agent-pool-security-roles,-project-level` — *"Reader: View the pool."* ⚠️ Documented as a **project-level** role; Scout calls the **org-level** `/_apis/distributedtask/pools` endpoint, so the org-level equivalent at `devops/pipelines/policies/permissions#set-agent-pool-security-in-azure-pipelines` (roles **Reader**, Service Account, Administrator) is the applicable one |

Also required, and easy to miss: the org's **"Third-party application access via OAuth"** policy must permit the token, and if the identity is a service principal it must be added to the DevOps org. Nothing in Scout's pre-flight validates any of this.

---

### Table D — Assessments

`manifests/assessments.psd1` declares **22 entries, but they are not 22 distinct things.** 15 are per-category slices of the same collect-and-score pipeline, 4 more are narrower sub-bundles of two of those, and `Governance` and `Policy` are byte-for-byte duplicates of each other (same Category, Collect, Ingest, Rules, Frameworks, Reporters — only `Tags` differ). The real shape is: 2 roll-ups, 15 category slices, 4 sub-bundles, 1 cost pull.

**No assessment needs a permission that its underlying collectors do not already need.** An assessment is rule evaluation over already-collected data.

| Assessment | Data it needs | Minimum permission set |
|---|---|---|
| **LandingZone** *(roll-up)* | Every category (`Collect = '*'`), all `caf.*` + `waf.*` rules | Azure RBAC **Reader** at root MG. Add Entra **Directory Readers** + Entra **Security Reader** for the Identity slice. |
| **Estate** *(roll-up)* | Every category, no scoring | Azure RBAC **Reader** at root MG |
| Management *(slice)* | Management collectors + Governance/ArgQueryPack/AdvisorScores ingest | Azure RBAC **Reader** — at **MG scope** for management-group and custom-role data |
| Monitor *(slice)* | Monitor collectors | Azure RBAC **Reader** |
| Networking *(slice)* | Networking collectors | Azure RBAC **Reader** |
| **Identity** *(slice)* | Identity **and** Security collectors — 15 Graph + 1 ARM | Azure RBAC **Reader** **+** Entra **Directory Readers** **+** Entra **Security Reader** (for Conditional Access, Named Locations, authorization policy, Risky Users) **+ Entra ID P2** for Risky Users |
| Security *(slice)* | Security collectors (Defender, Key Vault) | Azure RBAC **Reader** — control plane only; no Key Vault data-plane access |
| Compute *(slice)* | Compute collectors incl. VM enrichment | Azure RBAC **Reader** |
| Storage *(slice)* | Storage collectors | Azure RBAC **Reader** — no blob data-plane access |
| Databases *(slice)* | Databases collectors | Azure RBAC **Reader** |
| Containers *(slice)* | Containers collectors | Azure RBAC **Reader** |
| Web *(slice)* | Web collectors | Azure RBAC **Reader** |
| Analytics *(slice)* | Analytics collectors | Azure RBAC **Reader** |
| AI *(slice)* | AI collectors | Azure RBAC **Reader** |
| Integration *(slice)* | Integration collectors | Azure RBAC **Reader** |
| Hybrid *(slice)* | Hybrid collectors | Azure RBAC **Reader** |
| IoT *(slice)* | IoT collectors | Azure RBAC **Reader** |
| Governance *(sub-bundle of Management)* | Management collect + Governance ingest, `caf.governance` rules | Azure RBAC **Reader** at MG scope |
| **Policy** *(sub-bundle)* | **Identical to `Governance` in every field except `Tags`** | Azure RBAC **Reader** at MG scope — same as Governance |
| UpdateManager *(sub-bundle of Management)* | Management collect + ArgQueryPack; patch data from ARG `patchassessmentresources` / `patchinstallationresources` | Azure RBAC **Reader** — read-only since the `assessPatches` POST was removed |
| Monitoring *(sub-bundle of Monitor)* | Monitor collect, diagnostic-settings coverage | Azure RBAC **Reader** |
| **Cost** | Cost + Compute + Storage collect; `POST Microsoft.CostManagement/query` | Azure RBAC **Reader** **+ the EA/MCA billing setting below** (which is not a role) |

---

### Notes, exceptions, and things that are not roles

#### 1. No collector requires data-plane access — and Reader grants none

Azure RBAC `Reader` has `DataActions: []`. It grants **zero** data-plane access. That would be a hard blocker if any collector needed it. **None does — this was checked and is a clean result.**

- **Key Vault (`Security/Vault`)**: reads `microsoft.keyvault/vaults` from ARG only. No `Get-AzKeyVaultSecret` / `-Key` / `-Certificate` call exists anywhere in `src/`. Secret *names* are not read, let alone values.
- **Storage (`Storage/StorageAccounts`)**: `Get-AzStorageBlobServiceProperty` / `Get-AzStorageFileServiceProperty` are **control-plane** calls (`Microsoft.Storage/storageAccounts/blobServices/read`). No blob is enumerated or downloaded; no account key is listed (`listKeys` appears nowhere in `src/`).
- **DevOps service connections**: the REST endpoint returns connection metadata; secrets are never returned by that API.

**The one data-plane exception is an output feature, not a collector.** `-StorageAccount` calls `New-AzStorageContext -UseConnectedAccount` (`src/Invoke-AzureScout.ps1:705`) and then `Set-AzStorageBlobContent` (`:1055, :1061, :1067, :1080`) to upload the finished report. That is a data-plane **write** and needs **Storage Blob Data Contributor** on the destination container — a role Scout needs only if you ask it to publish its own output, and only on the one account you name.

#### 2. The EA/MCA billing gate — no role satisfies it

Cost data can be empty with a correct role assignment. Beyond RBAC, the billing account must permit subscription-scoped users to see cost:

- **EA**: the enrollment setting **"AO view charges"** (and **"DA view charges"**) must be enabled by the Enterprise Administrator.
- **MCA**: **"Allow Azure subscription users to view and optimize costs"** must be enabled at the billing profile.

With these off, `Microsoft.CostManagement/query` returns empty or 403 for a subscription-scoped principal **regardless of Reader, Cost Management Reader, or Cost Management Contributor**. This is not an RBAC role and cannot be granted with `New-AzRoleAssignment`; it must be changed by a billing administrator in the EA portal or Cost Management + Billing blade. Source: [Assign access to Cost Management data](https://learn.microsoft.com/azure/cost-management-billing/costs/assign-access-acm-data). Affects the **Cost** assessment, the `VirtualMachine` and `ARCServers` EstimatedCost fields, and `ReservationRecom`.

#### 3. Collectors with no meaningful permission answer — 12 provably broken

AB#6444 traced these to defects in code. They emit zero rows **in every tenant, on every run, at any permission level.** Granting more access does not change the output; they will *present* as a permission failure and are not one.

| Collector | Why it is broken | Status |
|---|---|---|
| Management/**CustomRoleDefinitions** | Consumes `AZSC/Management/RoleDefinition`, produced only by `Get-ScoutTenantWideResource`, which was gated on `-IncludeTenantWideResources` — a switch no production caller set | ✅ **Fixed** — AB#6755 wired both call sites |
| Management/**ManagementGroups** | Same gate — `AZSC/Management/ManagementGroup` | ✅ **Fixed** — AB#6755 |
| Management/**PolicyDefinitions** | Same gate — `AZSC/Management/PolicyDefinition` | ✅ **Fixed** — AB#6755 |
| Management/**PolicySetDefinitions** | Same gate — `AZSC/Management/PolicySetDefinition` | ✅ **Fixed** — AB#6755 |
| Databases/**POSTGRE** | Targets `microsoft.dbforpostgresql/servers`. Single Server reached end of life; no customer can own one | 🗑️ **Retired** — AB#6768 |
| Monitor/**AppInsightsContinuousExport** | No producer — Azure retired the endpoint. Permanently empty by design | 🗑️ **Retired** — AB#6768 |
| Monitor/**AppInsightsWorkItems** | No producer — endpoint retired | 🗑️ **Retired** — AB#6768 |
| Hybrid/**ArcSites** | Declared three type strings that do not exist: `microsoft.azurestackhci/sites`, `microsoft.edgeconfig/sites`, `microsoft.hybridcompute/sites` | ✅ **Fixed** — AB#6801 re-created it against `Microsoft.Edge/sites`, confirmed real by [Microsoft Learn](https://learn.microsoft.com/azure/templates/microsoft.edge/2025-06-01/sites) and by `manifests/azure-provider-types.json`, but Resource Graph's own [supported-type reference](https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources#resources) does not index `microsoft.edge/sites` either — it is re-sourced via the same per-subscription ARM REST sweep `Get-ScoutApiResources.ps1` already runs, not a Resource Graph query |
| Hybrid/**VirtualMachines** | **AB#6846's "not broken" verdict below is retracted.** Its live-tenant result (zero rows, zero HCI/Arc resources present) was real, but the reasoning was not: it treated "the type passes the AB#6842 existence gate" as proof Resource Graph can return rows for it, and the gate never checked that — only that the string is real ARM ground truth. `Microsoft.AzureStackHCI/virtualMachineInstances` is listed on Microsoft's own [extension-resource-types reference](https://learn.microsoft.com/azure/azure-resource-manager/management/extension-resource-types#microsoftazurestackhci) as an ARM EXTENSION resource scoped under a `Microsoft.HybridCompute/machines` parent, and Resource Graph's [supported-type reference](https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources#resources) lists eleven other `microsoft.azurestackhci/*` types it indexes — including the confusingly similar `microsoft.azurestackhci/virtualmachines` (no "instances") — but not `virtualmachineinstances`. This collector could not have returned a row in ANY tenant, deployed or not, and the AB#6846 live run against a tenant with zero HCI resources could never have distinguished the two hypotheses. Same defect class as AB#6769 (ResourceDiagnosticSettings) | ✅ **Fixed** — AB#6802 re-sourced it as an `AZSC/ARMChild/AzureLocalVirtualMachineInstances` per-parent ARM REST sweep, singleton per `Microsoft.HybridCompute/machines` guest, which also unblocks `Compute/AVDAzureLocal`'s Azure Local branch |

<details>
<summary>Retracted: AB#6846's original "not broken" verdict, kept for the record</summary>

> Its type, `microsoft.azurestackhci/virtualmachineinstances`, **is** real — it passes the AB#6842
> existence gate, so this was never the ArcSites failure. Diagnosed 2026-07-31 (AB#6846): the test
> estate contains **zero** `microsoft.azurestackhci` resources and **zero** `microsoft.hybridcompute`
> resources, out of 109 resources across 38 types. The verdict was **"no rows because the tenant has
> none"**, not "broken".
>
> This was wrong. A live query against a tenant with zero HCI/Arc resources cannot distinguish "the
> type is real but this tenant owns none" from "Resource Graph cannot return this type in any
> tenant" — both produce zero rows. The AB#6842 existence gate answers a narrower question than the
> verdict needed: it confirms a provider/type STRING is real ARM ground truth, not that Resource
> Graph indexes it for querying. See AB#6801/AB#6802 (Feature AB#6747) for the citation-backed
> correction.

</details>

| Management/**LighthouseDelegations** | `Microsoft.ManagedServices/registrationDefinitions` is real, but no pass reads the `managedserviceresources` ARG table that carries it | ✅ **Fixed** — AB#6771 added the `managedserviceresources` pass, on unconditionally |
| Monitor/**Outages** | `Get-ScoutOutageResource` runs before the API merge, so it never sees the ResourceHealth events | ✅ **Fixed** — AB#6770 moved the transform below the ARM REST sweep and feeds it the events |
| Monitor/**ResourceDiagnosticSettings** | `microsoft.insights/diagnosticsettings` is not an ARG-indexed type; it must be re-sourced via ARM REST | ✅ **Fixed** — AB#6769 re-sourced it as an `AZSC/ARMChild/*` sweep, scoped to 20 parent types |

**Three more were found afterwards, by the gate rather than by reading.** AB#6842 built a
resource-type existence check against provider metadata read from ARM — ground truth that does not
come from the manifests — and its first run flagged eight strings. Three were collectors this
audit had not identified at all:

| Collector | Declared | Finding | Status |
|---|---|---|---|
| Compute/**CloudServices** | `microsoft.classiccompute/domainnames` | The provider now lists **zero** types. Classic/ASM is gone | 🗑️ **Retired** |
| Storage/**DataLakeStoreGen1** | `microsoft.datalakestore/accounts` | Provider lists seven types and `accounts` is not among them. Gen1 retired 2024-02-29 | 🗑️ **Retired** |
| Migration/**AzureMigrateProjects**, Security/**CloudHSM**, Security/**ConfidentialLedger** | `microsoft.migrate/projects`, `…/dedicatedhsms`, `…/managedccfs` | Each carried a **renamed or retired** type string alongside a live one, so each was half-collecting silently | ✅ **Corrected** — dead strings dropped from the spec |

That is the argument for the gate in one table: reading the code found nine, and a check against
Azure's own answer found five more in its first minute.

**The `-IncludeTenantWideResources` switch has no production caller.** The string appears in exactly four places in the repo: the doc comment, the parameter declaration, the `if`, and one Pester test. Neither `Start-ScoutGraphExtraction.ps1:69-83` nor `Invoke-Collect.ps1:707` sets it. There is no operator flag that turns these four collectors on.

##### Why it is dead — root cause

This is Scout's own defect, not an Azure limitation, and it is a one-line fix at each of two call sites.

`src/collect/Get-ScoutTenantWideResource.ps1` says so in its own header (lines 31-33):

> *Isolated collect-phase implementation for AB#5933 (Epic AB#5917). Invoke-Collect does not call this function yet; old collectors remain the live path until definitions are ready.*

The switch was a **temporary gate**, added deliberately so half-finished tenant-wide collection could land without disturbing the then-live collectors. The declarative definitions it was waiting on **shipped** — all four manifests (`manifests/collectors/Management/{ManagementGroups,CustomRoleDefinitions,PolicyDefinitions,PolicySetDefinitions}.psd1`) now filter on exactly the four envelope types this function emits. The consumer end of the migration was completed. The producer end was never switched on. **The gate outlived its reason.**

**Why nothing caught it — three independent reasons, all worth fixing:**

1. **The function is built to degrade silently.** Its header states the contract: *"Every envelope is returned even when its properties array is empty."* Downstream, an empty envelope renders an empty worksheet. There is no error, no warning, no non-zero exit — a blank sheet is indistinguishable from a tenant that genuinely has no custom roles.
2. **The test suite passes the switch explicitly.** `tests/Collect.RawInventory.Tests.ps1:162` calls `Get-ScoutRawInventory -IncludeTenantWideResources`. The code path is covered and green; the production path that omits it is not asserted anywhere. This is the exact defect class the 1787-test suite is structurally unable to see — a test proving code *works when called* says nothing about whether anything calls it.
3. **A permission theory absorbed the blame.** The `ManagementGroups` failure was attributed to missing Management Group Reader (see note 4 above). That theory was never falsifiable, because the producer had never executed.

**Second-order consequence — the REST pass is dead too.** `Get-ScoutApiResources` is invoked from exactly one place on the live path: `Get-ScoutRawInventory.ps1:603`, **inside this block**. Its only other caller, `Start-AZTIExtractionOrchestration.ps1:84`, is classified `DEAD` by `scripts/Test-StrictModeGuard.ps1:84`. So with the switch off, Scout's entire ARM REST collection pass never runs. This also means turning the switch on is **not free**: it adds one REST pass per subscription to every run. Measure it before defaulting it on.

##### The fix

Two call sites. Both are needed — fixing only the first leaves every assessment still starved.

| # | File | Line | Change | Unblocks |
|---|---|---|---|---|
| 1 | `src/collect/Start-ScoutGraphExtraction.ps1` | 69-83 | Add `IncludeTenantWideResources = $true` to the `$RawArgs` splat, alongside the ten `Include*` switches already there | The four Management **worksheets** (inventory path) |
| 2 | `src/collect/Invoke-Collect.ps1` | 707 | `$rawArgs = @{ IncludeTags = $true }` → add `IncludeTenantWideResources = $true` | **Assessments #2 Landing Zone, #7 AVS Landing Zone, #8 Cloud Governance, #13 CASA** |

Call site 2 is the important one and the easier one to miss. Its surrounding comment explains that the raw pass is deliberately kept minimal because the `-Include*` tables "feed inventory REPORT collectors, not assessment scalars" — a judgement that was correct when written and is now wrong for this switch specifically: management groups, custom roles, and policy definitions **are** assessment inputs. Four CAF/ALZ assessments cannot be scored without them.

Then, in order:

1. Wire both call sites; assert in a test that the production splat sets the switch (not merely that the function honours it).
2. Re-run the Management Group Reader question from note 4 — it is only answerable once the producer executes.
3. Measure the added REST cost per subscription. If it is material, gate it on `-Scope`/assessment selection rather than reverting to a switch nobody sets.
4. Delete the switch once both call sites set it unconditionally. A parameter with no `$false` caller is dead weight that invites this failure again.

#### 4. Management groups — scope, and an unresolved question

Azure RBAC `Reader` must be assigned **at management-group scope**, not per-subscription, for management-group and cross-subscription hierarchy data to resolve. Subscription-scoped Reader silently returns an empty or flattened hierarchy — no error.

> ✅ **RESOLVED 2026-07-31 by a live run — `Management Group Reader` is NOT required.**
>
> This note previously read *"whether Reader at root MG alone is sufficient, or whether
> `Management Group Reader` is genuinely additional, is UNRESOLVED"*, and said the question was
> confounded by defect #3: the producer had never executed, so no observation could distinguish
> "wrong permission" from "code path never ran". AB#6755 fixed the switch; the producer now runs;
> the question was re-tested as note 3 instructed.
>
> **Result** — `Get-ScoutRawInventory` against tenant `d6fc73cf` (two subscriptions), with **no**
> `Management Group Reader` assignment anywhere:
>
> | Envelope | Rows |
> |---|---:|
> | `AZSC/Management/ManagementGroup` | **1** *(the tenant root MG, correctly resolved)* |
> | `AZSC/Management/RoleDefinition` | **1** *(a real custom role)* |
> | `AZSC/Management/PolicyDefinition` | **1000** |
> | `AZSC/Management/PolicySetDefinition` | **300** |
>
> The signed-in identity held `User Access Administrator` at `/` — whose `Actions` include
> `*/read`, so it is Reader-equivalent for every read Scout makes — plus `Owner` on one
> subscription. No management-group-specific role was present.
>
> **So the repo history that blamed permissions was wrong.** `ManagementGroups` returned no rows
> because its producer was gated behind a switch nobody set, exactly as defect #3 concluded. This
> is the third safeguard from that section closing out: a permission theory had absorbed the blame
> for a code defect, and it survived precisely because it was never falsifiable.
>
> ⚠️ Still true, and unchanged: read access must reach **management-group scope**. A principal
> holding Reader only at subscription scope still gets an empty or flattened hierarchy with no
> error. What is now disproven is that a *dedicated* `Management Group Reader` role is needed on
> top of that.

Affected: `ManagementGroups`, `CustomRoleDefinitions`, `AllSubscriptions` (mgChain), and the `Management` / `Governance` / `Policy` assessments.

#### 5. Roles you should NOT grant

| Role | System | Why not |
|---|---|---|
| **Security Reader** | **Azure RBAC** | Every read it grants is inside Reader's `*/read`. Its only non-read actions are IoT Defender package downloads, which Scout never calls. Adds nothing. *(The Entra role of the same name IS needed — see Table B.)* |
| **Monitoring Reader** | Azure RBAC | Redundant against `*/read`, and grants `Microsoft.Support/*`, which includes support-ticket **creation**. Scout only reads `Microsoft.Support/supportTickets`. |
| **Cost Management Reader** | Azure RBAC | Redundant — `Microsoft.CostManagement/query/read` is inside `*/read`, and Microsoft's role-behaviour table shows Reader as "Read only" on the Query and Cost Details APIs. It also carries `Microsoft.Support/*`. The real cost blocker is the billing setting in note 2, which this role does not fix. |
| **Global Reader** | Entra | Works, but Microsoft classifies it as **privileged** — the read-only counterpart to Global Administrator across all of Microsoft 365. `Directory Readers` + Entra `Security Reader` covers **14 of the 15** collectors with a narrower blast radius. The fifteenth, `CrossTenantAccess`, needs `crossTenantAccessPolicy/partners/standard/read` — and **Security Administrator** or **Tenant Governance Administrator** also carry it, so evaluate those before reaching for Global Reader. |
| **Virtual Machine Contributor** | Azure RBAC | Was previously needed for `assessPatches`. **No longer required** — patch data now comes from read-only ARG tables. Do not grant it. |

---

### Table E — The complete grant list

What a customer actually has to grant, by system.

#### (a) Inventory only — the default run

| System | Grant | Scope | Assignments |
|---|---|---|---|
| **Azure RBAC** | `Reader` | `/providers/Microsoft.Management/managementGroups/<tenant-root-mg-id>` | **1** |

**One role, one assignment.** Covers all 154 ARM collectors — every service inventory, all Defender data, policy compliance, Advisor, Monitor, patch assessment, storage and VM enrichment, quotas and SKUs. Nothing else, from any system.

```powershell
New-AzRoleAssignment -ObjectId <principalId> -RoleDefinitionName 'Reader' `
  -Scope '/providers/Microsoft.Management/managementGroups/<tenantRootId>'
```

Root-MG scope, not per-subscription, is what makes management-group hierarchy and cross-subscription rollups resolve.

#### (b) Inventory + assessment (CAF/WAF, no Entra, no DevOps)

| System | Grant | Scope | Assignments |
|---|---|---|---|
| **Azure RBAC** | `Reader` | root management group | **1** |

**Identical to (a).** The CAF/WAF rule engine scores data Scout has already collected; it issues no additional Azure calls. Every assessment in Table D except `Identity` and `Cost` runs on Reader alone.

For the **Cost** assessment, add a **non-role** prerequisite: EA **"AO view charges"** enabled, or MCA **"Allow Azure subscription users to view and optimize costs"** enabled. See note 2. There is no role that substitutes for this.

#### (c) Everything — including Entra and DevOps

| System | Grant | Scope | Privileged? | Notes |
|---|---|---|---|---|
| **Azure RBAC** | `Reader` | root management group | No | All 154 ARM collectors |
| **Entra directory role** | `Directory Readers` | tenant | No | 10 of the 15 Graph collectors: Users, Groups, AppRegistrations, ServicePrincipals, ManagedIdentities, DirectoryRoles, PIMAssignments, AdminUnits, Domains, Licensing |
| **Entra directory role** | `Security Reader` ⚠️ *Entra, not Azure RBAC* | tenant | **Yes** | ConditionalAccess, NamedLocations, SecurityPolicies, RiskyUsers. ⚠️ Also grants `bitlockerKeys/key/read` — recovery-key read. Nothing in Scout calls it, but a security team reviewing the grant will find it, so it is named here rather than discovered. |
| **Entra directory role** *(optional)* | `Security Administrator`, `Tenant Governance Administrator`, or `Global Reader` | tenant | **Yes** | `CrossTenantAccess` **only** — the one Graph collector the pair above does not reach. It needs `microsoft.directory/crossTenantAccessPolicy/partners/standard/read`, which neither `Directory Readers` nor Entra `Security Reader` holds. Skip the grant and accept an empty CrossTenantAccess worksheet if the narrower blast radius matters more. |
| **Azure DevOps** | Org membership + project-level read: View project-level information, View build pipeline, Reader on service connections, Read on Git repos, Reader on agent pools | per org / per project | n/a | The 5 DevOps collectors. Also needs the org's third-party-OAuth policy to permit the token. |
| *(if using `-StorageAccount`)* **Azure RBAC** | `Storage Blob Data Contributor` | the one destination storage account | No | Data-plane **write**, for uploading the finished report. Output only — no collector needs it. |

**Non-role prerequisites for (c):**

| Prerequisite | Needed for | Who grants it |
|---|---|---|
| EA **"AO view charges"** / MCA **"Allow Azure subscription users to view and optimize costs"** | all cost data | Billing administrator / Enterprise Administrator |
| **Entra ID P2 licence** | `RiskyUsers` only | Tenant licensing |
| **Azure CLI logged in** (`az login`) *in addition to* `Connect-AzAccount` | all 15 Graph collectors — `Get-AZSCGraphToken` shells to `az account get-access-token` | The operator, at run time |
| DevOps org **third-party application access via OAuth** enabled | the 5 DevOps collectors | DevOps org administrator |

**For a service principal instead of a user**, replace the two Entra directory roles with these admin-consented Microsoft Graph **application** permissions: `User.Read.All`, `Group.Read.All`, `Application.Read.All`, `RoleManagement.Read.Directory`, `AdministrativeUnit.Read.All`, `Domain.Read.All`, `Organization.Read.All`, `Policy.Read.All`, `IdentityRiskyUser.Read.All`. `AuditLog.Read.All` and `IdentityProvider.Read.All` are checked or queried but consumed by no collector — do not request them.

#### Summary count

| Capability | Azure RBAC roles | Entra roles | Graph app permissions (SP only) | DevOps | Non-role prerequisites |
|---|---|---|---|---|---|
| Inventory only | **1** (`Reader`) | 0 | 0 | 0 | 0 |
| + assessment | **1** (`Reader`) | 0 | 0 | 0 | 1 (billing, for Cost only) |
| + Entra | 1 | **2** (`Directory Readers`, `Security Reader`) | 9 | 0 | 2 (P2 for RiskyUsers, `az login`) |
| + DevOps | 1 | 2 | 9 | **org + 5 project/org reads** | 3 (+ OAuth policy) |
| + report upload | 2 (`+ Storage Blob Data Contributor`) | 2 | 9 | org + 5 | 3 |

---

## 10. Architecture — collect once

**Design (decision-table row 12):** one collection engine. Inventory's collector is the only thing
that pulls from Azure. Assessment reuses what it collected and fetches only what ARG cannot index.

**Verdict: the direction is correct and most of it is already built.** Four defects stand between
the current code and the design.

### Already true

- **`Get-ScoutRawInventory` is the single ARG engine.** `Start-AZSCGraphExtraction` contains no
  query text at all — it is a parameter-translation shim onto it
  (`src/collect/Start-ScoutGraphExtraction.ps1:1-33`, `:69-90`). The assessment collector calls the
  same function (`src/collect/Invoke-Collect.ps1:690-709`). The two callers differ only in which
  tables they request — inventory asks for eleven extra, assessment asks for three plus tags. That
  is the correct shape for a shared engine.
- **AB#5648 covered the assessment half.** `ConvertFrom-ScoutInventory` shapes **34 of 35** collect
  datasets from raw rows; the skip logic at `Invoke-Collect.ps1:768` issues no Azure call for
  anything already shaped. Only `sqlDefenderPricing` is not derivable, because it reads
  `SecurityResources` rather than `resources` (`Invoke-Collect.ps1:364-368`, rationale `:681-686`).
- **`-Assessment` alone correctly does *not* run the full inventory pass**
  (`src/Invoke-AzureScout.ps1:565`, `:595`).
- **Collect-once for the combined run is implemented** — `$ExtractionData` is handed to
  `Invoke-ScoutAssessmentCore -FromInventory` (`Invoke-AzureScout.ps1:842-843`,
  `Invoke-Collect.ps1:725-727`).

### Defect 1 — `ArgQueryPack` re-queries six datasets and overwrites the good copies with worse ones

`src/Invoke-ScoutAssessmentCore.ps1:124-139` runs the manifest's `Ingest` list after
`Invoke-Collect` returns, **with no awareness of whether the data was already collected** —
including when `-FromInventory` was supplied.

| ArgQueryPack query | Already collected by |
|---|---|
| `subnetIpUsage` (`Invoke-ArgQueryPack.ps1:20`) | `subnets` (`Invoke-Collect.ps1:239`) |
| `orphanedDisks` (:30) | `orphanedDisks` (`:316`) |
| `orphanedPips` (:35) | `orphanedPips` (`:320`) |
| `diagCoverage` (:40) | `diagnosticCoverage` (`:324`) |
| `publicExposure` (:46) | `nsgPublicInbound` (`:288`) |
| `nonZonalVms` (:55) | `virtualMachines.zoneRedundant` (`:297`) |

**It is destructive, not merely wasteful.** `Invoke-ArgQueryPack.ps1:87-95` writes over the
collector's results with `Add-Member -Force`, and its copies are strictly worse:

- `subnetIpUsage` (:28) computes a percentage with **no divide-by-zero guard**. The collector has
  one — `iff(total > 0, ..., todouble(0))` (`Invoke-Collect.ps1:247`). A `/31` or `/32` subnet
  makes `total` zero or negative.
- `diagCoverage` (:44) — same missing guard; the collector's has it (`:328`).
- `orphanedDisks` (:33) projects `sku`/`sizeGb` untyped; the collector casts (`:318`).
- **`nonZonalVms` is queried and never merged into `$Collect` at all** — a pure wasted round-trip on
  every run of the 15 assessments declaring `ArgQueryPack`.

A comment at `:79-83` records that a previous `-Force` replace **already caused a live incident** —
wiped `networking`, false-failed `CAF-SEC-03`/`CAF-SEC-06`. The same hazard remains for the four
properties it still replaces.

### Defect 2 — the combined run is unreachable from the command line

`$wizardRunBoth` (`Invoke-AzureScout.ps1:594`) is set from exactly one source: `:557`, from
`$wizard.RunBoth` (`Start-AZSCWizard.ps1:280`). **No parameter sets it.**

So `Invoke-AzureScout -Assessment LandingZone -OutputFormat All` does not produce an inventory
report — CI and scripted callers cannot reach the collect-once path at all.

### Defect 3 — the collect-once handoff silently loses tags

`Invoke-Collect` forces `IncludeTags = $true` on its own raw pass and documents why
(`Invoke-Collect.ps1:700-707`: without it the canonical `tags` key is silently empty). The
inventory pass sets `IncludeTags = [bool]$IncludeTags` (`Start-ScoutGraphExtraction.ps1:81`),
defaulting to **false**.

**A wizard "both" run without `-IncludeTags` hands the assessment rows with no `tags` column**, and
`ConvertFrom-ScoutInventory.ps1:135` reads `tags` off the container row — producing an empty
`collect.tags` aggregation. The assessment-only path gets tags; the collect-once path does not.

### Defect 4 — `AdvisorScores` duplicates inventory data and leaks Az context

`src/ingest/Import-AdvisorScores.ps1:16-24` enumerates subscriptions and calls
`Get-AzAdvisorRecommendation` per subscription. Inventory already collects Advisor rows from the
`advisorresources` ARG table (`Start-ScoutGraphExtraction.ps1:76,94` → `$ExtractionData.Advisories`).
In a combined run this re-fetches data already in memory, via a slower API.

Separately: `:21` calls `Set-AzContext` inside the loop and **never restores the caller's original
context**. Anything running after an assessment in the same session inherits whichever subscription
happened to be last.

### Where the carve-out actually falls

Drawn by **API surface — what ARG cannot index** — not by product surface:

| Ingest source | Verdict |
|---|---|
| `ArgQueryPack` | **All six are duplicates.** Retire it. |
| `Governance` — `policyresources`, `authorizationresources` | **Legitimately assessment-only** — different ARG tables the raw pass does not read. |
| `Governance` — budgets, resource locks (`Import-Governance.ps1:114-116`) | **Legitimately non-inventory** — not ARG-indexed at all. These are the correct examples of the carve-out. |
| `Governance` — management groups | *Nearly* a duplicate; the raw pass reads `resourcecontainers` but filters to subscriptions/RGs. |
| `AdvisorScores` | **Duplicate** of `$ExtractionData.Advisories` in a combined run. |
| Azure Policy compliance state | **Already inventory** — `policyStates/latest/summarize`. Not a carve-out example. |

---


---

## 11. The four source audits, summarised

### AB#6444 — Collector verification

**Verdict: 0 of 174 verified against real Azure; 12 provably always-empty.**
Detail in §5.5. Proposes a four-layer verification approach: a static resource-type existence gate
(~1 day, would have caught 11 of the 12 defects), retained per-collector row counts (~1 day, turns
every future run into evidence), running the 174 against the existing-but-unused real anonymised
capture (~2-3 days), and — explicitly *not* recommended at full scope — a canary subscription.
→ `AB6444-collector-verification-audit.md`

### AB#6445 — Least-privilege permissions

**Verdict: the minimum role set is `Reader` at root management group. Everything else is opt-in.**
Scout over-asks for **Security Reader** (redundant — every read it grants is inside Reader's
`*/read`, yet nagged for on every subscription) and **Monitoring Reader** (redundant, *and* grants
`Microsoft.Support/*` = ticket creation, a write). Neither is a *strict subset* of `*/read` — that
wording appeared in an earlier draft and is wrong both ways round; see §9. `AuditLog.Read.All` is
requested but no collector consumes it.

The structural insight: the 174 collectors **don't call Azure at all** — they're transforms over an
in-memory bag. All Azure calls come from ~13 functions in `src/collect/`, so the permission matrix
collapses to 11 access classes.

Also found: Graph tokens come from `az account get-access-token`, so Scout silently requires a
*second* login beyond `Connect-AzAccount` and breaks under service-principal runs; Azure DevOps has
zero pre-flight coverage.
→ `AB6445-least-privilege-permissions-audit.md`

### AB#6446 — Service coverage gaps

**Verdict: 52 of ~130 providers ≈ 40% coverage; the taxonomy should grow.**
Detail in §5.1 and §6. Notable specifics: AI's 27 collectors are inflated (11 are the same resource
type split by `kind`); Storage's 2 is genuinely thin; Data Factory, modern Front Door
(`Microsoft.Cdn/profiles`), and backup *protected items* are absent — meaning **"which VMs have no
backup" is unanswerable today**. RBAC role assignments, resource locks, policy assignments and
budgets are **already ingested but never rendered** — near-free wins.
Recommends *against* building Media Services, Blockchain, and Mixed Reality (all retired).
→ `AB6446-service-coverage-gap-analysis.md`

### AB#6447 — CAF/WAF coverage

**Verdict: ~10% of CAF, ~15% of WAF.**
Root-caused the wizard path bug (§5.2). Found that **32% of all rules (47 of 148) are `manual: true`**
— they assert nothing and produce no verdict. Found that **Azure Policy compliance state is
collected through three separate code paths and never scored by any rule** — the most valuable
governance signal in Azure, paid for in query time and discarded. Found **two false-pass rules**
(`CAF-GOV-05`, `CAF-AUT-02`) that claim to verify policy drift correction but actually just check
whether an assignment has a parameters block.
→ `AB6447-caf-waf-coverage-audit.md`

---

---

## Part III — Decisions

---

## 12. Decisions already taken

These are settled. They are recorded here so nobody relitigates them, and so the plan in Part IV
has something to stand on. **Decided ≠ implemented** — the "Where it stands" column is the truth.

Legend: ✅ done · 🟡 agreed, not built

| # | Decision | Status | Decided by | Rationale | Where it stands |
|---|---|---|---|---|---|
| 1 | **Stop triggering patch assessments.** Read Azure Update Manager's Resource Graph tables instead of POSTing `assessPatches` per machine. | ✅ | Owner | *"To do a patch assessment is worthless cause that can take hours to run."* It was also an ARM **write** action, making a read-only tool mutate customer machines. | Implemented + 30/30 tests pass. Regression lock proven non-vacuous. **Uncommitted.** Not yet live-verified. |
| 2 | **Dump ALL raw collected data to a file**, regardless of whether a collector exists to display it. | 🟡 | Owner | *"Shouldn't all the data that is collected no matter what be dumped into a .json or some other file?"* Better than the audit's proposal (a summary of skipped types) — eliminates silent data loss entirely instead of reporting on it. | Agreed. Not built. |
| 3 | **Ship v3.0.9 without the diagram→PDF rasterisation fix.** | ✅ | Owner | Needs a new dependency (headless renderer) or a multi-week custom rasteriser. Not a point-release fix. | v3.0.9 shipped. **AB#6737 left open** with the scoping analysis recorded on it. |
| 4 | **Fix the wizard manifest path bug.** | ✅ **Decided — do it** | Owner | One line. Exposes the 21 hidden registry entries -- of which DQ1/DQ2/DQ10/DQ11 keep only the ones Scout can actually run. `src/Start-AZSCWizard.ps1:238` climbs three directory levels to find `manifests/assessments.psd1`; the file lives in `src/` so it needs one. It resolves outside the repo, `Test-Path` returns false, and it silently falls back to a hardcoded `@('LandingZone')`. | **Decision: change the three `Split-Path` calls to one.**<br><br>From:<br>`$manifestPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) 'manifests/assessments.psd1'`<br><br>To:<br>`$manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'manifests/assessments.psd1'`<br><br>Not yet applied. See §3.2. |
| 5 | **Drop the redundant roles** from the required role set. | ✅ **Answered — it is THREE roles, not two** | Owner asked *"are you 100&#37; sure?"*; researched against Microsoft Learn | Azure `Reader` is `Actions: */read`, `NotActions: none` — a single wildcard over every control-plane read. Every action these three grant that Scout uses is inside it. | **Drop all three:**<br><br>**1. Security Reader** *(Azure RBAC — **not** the Entra role of the same name)* — every read it grants is inside `*/read`; its five non-read actions (IoT Defender package downloads) are ones Scout never calls.<br>**2. Monitoring Reader** — a **superset** of `*/read`, adding `Microsoft.OperationalInsights/workspaces/search/action` and `Microsoft.Support/*` = ticket *creation*, a write Scout never uses.<br>**3. Cost Management Reader** — **newly found redundant.** Microsoft's role-behaviour table shows `Reader` = "Read only" on Cost Analysis / Forecast / **Query** / Cost Details API, and `Microsoft.CostManagement/query/read` exists.<br><br>⚠️ **Entra `Security Reader` is a different role and IS required** — `Directory Readers` has zero Conditional Access actions.<br><br>Not applied to code. See §9. |
| 6 | **Fix the readiness verdict** so a denied permission that empties a collector degrades the result. | ✅ **Decided — Option 2** | Owner | `Invoke-AZTIPermissionAudit.ps1:418` hardcodes only 4 of 9 Graph checks as critical, so a denied `IdentityRiskyUser.Read.All` still printed **"READY — Full ARM + Entra ID scan supported"** while the RiskyUsers worksheet rendered empty. Empty and "none found" are indistinguishable in a security report. | **Decision: replace the READY/PARTIAL verdict with a per-collector impact table.**<br><br>Not *"READY"*, but *"142 of 174 collectors will produce data. These 32 will be empty: RiskyUsers (needs `IdentityRiskyUser.Read.All`), ConditionalAccess (needs `Policy.Read.All`), …"*<br><br>**Why not the smaller fix:** deleting the hardcoded `$isCritical` list and deriving criticality from collector consumption fixes *this* instance, but keeps one word standing in for 174 outcomes — the same bug class returns the next time a collector is added. A list of what you will actually get cannot lie; a verdict word can. Roughly a day versus an hour.<br><br>**Should land with it:** stop swallowing Graph 403s into a coloured `Write-Host "SKIP"` that never reaches the warning stream, so the run's own error count can see them.<br><br>**Not implemented.** See §9 and AB#6445 §6.4. |
| 11 | **`Estate` is inventory, not an assessment — get it out of the assessment registry.** | ✅ **Decided — fix it** | Owner | `manifests/assessments.psd1:37-46` declares `Estate` with **`Rules = @()`**. It scores nothing. It is a full-estate inventory pull sitting in the list the wizard presents as *"Assessments to run"*. Inventory and assessment are different products; the registry conflates them. | **Decision: separate them.** An operator choosing from an assessment menu cannot tell that one entry performs no assessment. **Resolved by DQ10: move it out of `assessments.psd1` entirely** — it duplicates `Invoke-AzureScout` without `-Assessment`. Separate wizard prompts for inventory and assessment are worth doing on their own merits, but are not a reason to keep a duplicate registry entry alive.<br><br>**Related naming collision, same root cause:** the 15 per-category assessment entries carry **the same names as the 15 inventory categories** (Compute, Storage, Networking…). One filters what is *collected*, the other filters what is *scored*. Same words, different meaning, one menu. **Resolved by DQ11: retire the 15 slices in Release 3** — once per-pillar assessments exist they are redundant — with an `Assess:` prefix shipped in Release 0 as a stopgap.<br><br>**Not implemented.** |
| 12 | **One collection engine; collect once.** Inventory's collector is the *only* mechanism that pulls from Azure. Assessment reuses what inventory collected and fetches only what ARG genuinely cannot index. | ✅ **Decided — this is the design** | Owner | Running inventory + assessment must not pay for the same Azure queries twice. Assessment has no separate collection path. | **Direction confirmed correct, and mostly already built** — `Get-ScoutRawInventory` is already the single ARG engine for both paths, and AB#5648 shaped 34 of 35 assessment datasets from raw rows. **Four defects block it — see §10.**<br><br>**Correction to the design as originally stated:** policy compliance state was named as the "genuinely not inventory" example. It is the opposite — inventory already fetches `policyStates/latest/summarize` and the assessment ignores it. **Draw the carve-out by API surface (what ARG cannot index), not by product surface.** Budgets and resource locks are the real examples.<br><br>**Not implemented.** |

---


### Implementation status of the decided items

Six of the eight decisions above are **decided but not written**. This is the single largest risk
in the document — a decision log that outruns the code produces exactly the drift this audit was
commissioned to find.

| Decision | Decided | In code? | Where it lands in the plan |
|---|---|---|---|
| 1 — patch assessment → read-only | ✅ | ✅ **Written, 30/30 tests, uncommitted** | Commit it. Release 0. |
| 2 — dump all raw collected data | 🟡 | 🔲 | Release 1 |
| 4 — wizard manifest path | ✅ | 🔲 *(one line)* | Release 0 |
| 5 — drop three redundant roles | ✅ | 🔲 *(docs + pre-flight)* | Release 1 |
| 6 — replace READY verdict with per-collector impact | ✅ | 🔲 | Release 1 |
| 11 — `Estate` out of the assessment registry | ✅ | 🔲 | Release 2 |
| 12 — one collection engine, collect once | ✅ | ⚠️ **Mostly built, 4 defects** | Release 1 (see §10) |

---

## 13. The remaining decisions — taken

These were open when this document was written. **All twelve are now decided.** Each was
resolved on the evidence already in this document; none is a preference call that needed
relitigating, and none is left waiting.

Three (DQ10-DQ12) were not on the original list at all — they surfaced when this section was swept against the rest of the document, each hiding inside a row that already read as decided. That is worth noting: **a decision log finds its own gaps only when something forces a sweep.**

The rule applied: **where the evidence in Parts I-II determines an answer, take it.** Only DQ7
depends on something outside the repo, and even there the decision is *yes* — what is outstanding
is a prerequisite, not a choice.

Legend: ✅ decided · ⚠️ decided, with a dependency

| # | Question | ✅ Decision | Why this and not the alternative | Lands in |
|---|---|---|---|---|
| **DQ1** | What does the wizard menu list, and what is pre-checked, after the path fix? | ✅ **The menu lists only assessments Scout can actually run. `LandingZone` is pre-checked — because today it is the only real one.** | **The 22 entries the path fix exposes are not the 14 chosen assessments.** 15 are category filters over the same rule set (retired by DQ11), 4 are sub-bundles (DQ2), 1 is `Estate`, which scores nothing (DQ10). After DQ2/DQ10/DQ11 the menu honestly collapses to **`LandingZone` + `Cost`** — and that is the correct state to ship, because it is the truth. Each of §14's 14 targets joins the menu **as it is built**, not before. **An unbuilt assessment must never appear as a menu entry**: a customer selects it, it runs, it returns nothing, and they read that as "no findings" — the same false negative DQ9 retires broken collectors to avoid. `LandingZone` stays pre-checked because it is the roll-up containing every `caf.*` and `waf.*` rule, so pressing Enter yields strictly more than today and nobody's behaviour regresses. **Revisit the default when Release 3 splits it** — the right default for a per-pillar menu is a genuinely different question. | Release 0; menu grows through Releases 2-7 |
| **DQ2** | De-duplicate the assessment registry | ✅ **Delete `Policy`. Keep `UpdateManager` and `Monitoring`, renamed to show the subset.** | `Governance` and `Policy` are byte-identical — same `Category`, `Collect`, `Ingest`, `Rules`. Two menu entries that do the same thing is a bug, and the fix is deletion, not documentation. `UpdateManager` and `Monitoring` are *strict subsets* of `Management` and `Monitor`, which is a different thing: a narrow slice is useful **if it is labelled as one**. Rename to `Management — Update Manager only` and `Monitor — operational excellence only` so the relationship is visible in the menu. Keep `Governance` over `Policy` as the survivor: it matches the CAF design-area name. | Release 2 |
| **DQ3** | Add Backup & Recovery, Cost & Optimisation, Virtual Desktop as categories? | ✅ **No. Hold to Microsoft's 18.** | These are *opinion* — consulting-driven splits — and each is already somewhere real: **AVD sits under Compute** (confirmed from the portal; proposing it as its own category was my error), Backup under Management and governance, Cost under General. The single property that makes §2 and §6 auditable is that they map 1:1 to something Microsoft publishes; the moment Scout invents a category, no one can check its coverage claim against anything. **Serve the same need with report views, not taxonomy** — a "Backup posture" view can draw from Management, Compute and Storage without fracturing the category model. This is also why DevOps, Migration and General *are* being added: those are objective gaps against Microsoft's list, not opinions. | Release 3 |
| **DQ4** | `-IncludeTenantWideResources`: always on, or gated? | ✅ **Wire it on unconditionally. Measure. Only then consider gating.** | The four assessments it blocks (#2, #7, #8, #13) are worth more than the round-trips. The cost is real — it pulls `Get-ScoutApiResources` onto the live path, one ARM REST pass per subscription — but it is *unmeasured*, and gating on an unmeasured cost is how this defect happened in the first place. **If the measurement does hurt, gate on assessment selection, never back on a default-off switch.** Then delete the parameter: one with no `$false` caller is dead weight that invites the same failure again. | Release 0 |
| **DQ5** | Finish §6's apparently-unenumerated services? | ✅ **Done — and the premise was wrong.** | The decision stands: §6's entire value is that it is *complete*, because a 95% list cannot answer "is X covered?" without also opening the portal. **So it was finished immediately rather than deferred, and the diff against §2 found the gap was arithmetic, not coverage** — rows here often carry several portal services (`Microsoft Entra ID · ID Security · PIM` is one row and three entries), so counting rows undercounts. **Exactly one service was genuinely absent: `Personalizers`.** It is now listed. The lesson is worth keeping: *"16 services missing"* came from subtracting two column totals, and nobody had checked whether the totals counted the same thing. | ✅ Complete |
| **DQ6** | Correct the eight fact-check defects in §9? | ✅ **Yes — before §9 goes to anyone outside this repo.** | `docs/audits/_verification-report.md` found eight wrong claims in my own permission research: the CrossTenantAccess coverage claim, the Cost Management citation, three "strict subset" claims, the DirectoryRoles attribution, and the MCA Billing Profile Owner role name. **A permission table with known-wrong rows is worse than no table** — its purpose is to be handed to a customer's security team as a grant request, so a wrong row becomes either a failed scan or an over-grant. Documentation fix, no code. | Release 0 |
| **DQ7** | Run the Reader-only live test? | ⚠️ **Yes — decided. Prerequisites: build item 1.3, plus a tenant and a service principal.** | Every claim in §9 is *documented*; none is *tested*. One run with a Reader-only SP, compared against a run with the full role stack, simultaneously settles the Management Group Reader question, whether partial ARG access is detectable at all, and the EA/MCA billing gate's failure signature. Nothing else in this document resolves three open questions at once. **This is not an open decision — it is scheduled work with a dependency.** It cannot run before 1.3 (per-collector row counts) exists, because there would be nothing to compare. | Release 1 |
| **DQ8** | Three-state compliance reporting? | ✅ **Yes: `Pass` / `Fail` / `Not assessed`. Non-negotiable.** | Apart from MCSB, a regulatory initiative returns data only where it has been *assigned*. Unassigned yields **no data — not a zero score**. Collapsing "not assessed" into "fail" produces alarm about controls nobody chose to evaluate; collapsing it into "pass" produces a compliance report that certifies nothing as compliant. That distinction is the entire difference between a trustworthy compliance product and a dangerous one. **Decided now because it constrains the §14 MCSB work** — retrofitting a third state after the renderer exists is far more expensive than designing for it. | Release 2 |
| **DQ9** | The permanently-broken collectors | ✅ **Retire `POSTGRE`, `AppInsightsContinuousExport`, `AppInsightsWorkItems`. Re-source `ResourceDiagnosticSettings` via ARM REST.** | The three retirements target endpoints or types Azure has removed — no permission, no fix, and no future in which they return rows. **An empty worksheet is a false negative**: a customer reads "no diagnostic settings" as "we have none", which is the opposite of the truth. Deleting a collector is honest; shipping a permanently blank one is not. `ResourceDiagnosticSettings` is different — the data exists, it is simply not ARG-indexed, so it is re-sourced rather than retired. | Release 1 |

**Two more surfaced during the final sweep of this document.** Both were forks left open *inside* a
row of §12 that reads as decided, which is exactly how a decision goes missing. Both are now taken:

| # | Question | ✅ Decision | Why this and not the alternative | Lands in |
|---|---|---|---|---|
| **DQ10** | `Estate` — §12 row 11 decided to *"separate them"* but left the how open: move `Estate` out of `assessments.psd1` entirely, or keep it and have the wizard present inventory and assessment as separate prompts? | ✅ **Move it out entirely.** | `Estate` has `Rules = @()` — it scores nothing. It is a full-estate inventory pull that already exists as `Invoke-AzureScout` without `-Assessment`, so keeping it means maintaining two entry points to identical output, which is the split-product failure Scout was unified to escape. **Separate wizard prompts for inventory and assessment should happen anyway** — that is a UX fix worth doing on its own merits, and it is not a reason to keep a duplicate registry entry alive. | Release 2 |
| **DQ11** | The 15 per-category assessment entries carry **the same names as the 15 inventory categories** (`Compute`, `Storage`, `Networking`…). One filters what is *collected*, the other what is *scored*. §12 row 11 flags this and proposes nothing. | ✅ **Retire them in Release 3; prefix with `Assess:` until then.** | Renaming alone treats a symptom. Release 3 splits `LandingZone` into per-WAF-pillar and per-CAF-design-area assessments, and **once those exist the 15 category slices are redundant** — an operator wanting Compute findings picks the pillars, not a category filter over the same rule set. So the end state is retirement, not a better name. In the meantime the collision is live and confusing in a menu that is about to grow from 1 visible entry to 21, so ship the `Assess:` prefix with the wizard fix in Release 0 as a stopgap. | Release 0 (prefix) → Release 3 (retire) |

**A third gap, found by asking whether the 14 targets are actually design-ready. They are not.**

| # | Question | ✅ Decision | Why this and not the alternative | Lands in |
|---|---|---|---|---|
| **DQ12** | Do the 14 target assessments have their source structure documented — the pillars, design areas, or question sets they score against? | ✅ **Only 2 of 14 do. Enumerating the other 12 is a prerequisite task in its own release phase, before any rule file is written.** | §8 enumerates **WAF's 5 pillars (59 checklist items)** and **CAF's 8 design areas (~394 recommendations)** with Scout's per-area coverage. That makes **#1 Azure Well-Architected Review** and **#2 Azure Landing Zone Review** design-ready, and **#12 WAF Maturity Model** derivative of #1. **The other eleven have no enumerated source in this document**: the four workload reviews (#3 Azure Local, #4 AI, #5 AVD, #6 AVS) each have a published Microsoft checklist that nobody has extracted; #7 AVS Landing Zone, #8 Cloud Governance, #9 FinOps, #10 DevOps Capability, #13 CASA and #14 SMART have published question sets, none enumerated. **Writing rules against a framework you have not enumerated is how `waf.storage.yaml` happened** — a rule file scoring a WAF pillar that does not exist. The enumeration is cheap (reading and tabulating published Microsoft content) and it is the only thing that makes a coverage percentage meaningful. ⚠️ **It also carries a shelf life**: §8's currency warnings record that Microsoft is actively rewriting CAF design-area pages away from the `Design recommendations` structure, so every enumeration must be **date-stamped with its verification method**, and any published coverage percentage must name the version it was measured against. | **New phase, before Release 3** — one enumeration per target, each gating its own rule file |

### What is actually outstanding

**Nothing.** This document is an audit. Implementation has not started, every decision is taken,
every item of work is specified, and nothing is blocked on anybody.

DQ7's Reader-only verification run is **documented here as a prerequisite, not scheduled as a task
in this document**. Whoever performs that run supplies their own environment. What this audit owes
them is the specification, and it is recorded in §17:

| Prerequisite | Detail |
|---|---|
| **Test principal** | A service principal holding **only** Azure RBAC `Reader`, assigned at **root management group** scope — no Entra directory role, no additional Azure RBAC role |
| **Rights needed to establish it** | Creating the principal is an Entra app registration; assigning Reader at root MG requires **Owner or User Access Administrator** at that scope |
| **Comparison baseline** | A second run with the full role stack, in the same tenant, against the same estate |
| **Build dependency** | Build item 1.3 — per-collector row counts, retained per run. Without it there is nothing to compare |
| **What it settles** | Whether Management Group Reader is genuinely additional · whether partially-scoped ARG access is detectable at all · the EA/MCA billing gate's failure signature |

Everything else in this document is either finished research or specified work that can start
without another word from anybody.

### Questions deliberately NOT asked

Recorded so they are not re-raised:

- **"Should assessment reuse inventory's collector?"** — answered (decision 12). It is the design,
  and it is mostly built.
- **"Should we split web and PowerShell features?"** — no. Parity, always.
- **"Should Scout have its own category taxonomy?"** — no, see DQ3.
- **"Is `LandingZone` really only one assessment?"** — yes, verified by reading the registry. See §5.

---

---

## Part IV — The plan

---

## 14. The assessment programme — 14 targets

### 🎯 DECIDED — the assessments Scout will implement

Owner decision, 2026-07-31. These are the targets for the next few releases, taken from
Microsoft's published catalogue above.

| # | Assessment | Why | Scout's starting position |
|---|---|---|---|
| 1 | **Azure Well-Architected Review** | The canonical WAF assessment — ~60 questions across the five pillars | `waf.*` rule files exist and are already tagged by pillar. **~15% solid coverage.** |
| 2 | **Azure Landing Zone Review** | The canonical CAF landing-zone assessment | `LandingZone` already aims at this. **~10% of CAF's ~394 recommendations.** |
| 3 | **Azure Local \| Well-Architected Review** | **Strongest differentiator** — 16 Hybrid collectors, Scout's deepest coverage area | `caf.hybrid` (6 rules) + Azure Local collectors. No WAF-shaped output yet. |
| 4 | **Azure Well-Architected AI workload** | AI is Scout's best-covered category — 16 of 18 portal services (§6) | `caf.ai` (5 rules). Inventory strong, rules thin. |
| 5 | **Azure Well-Architected Azure Virtual Desktop workload** | 7 AVD collectors already exist | No AVD-specific rule file. |
| 6 | **Azure Well-Architected Azure VMware Solution workload** | AVS collected (`Compute/VMWare`) | No AVS rule file. |
| 7 | **Azure VMware Solution Landing Zone Assessment Review** | Pairs with #6 — platform readiness rather than workload | Same starting point. |
| 8 | **Cloud Governance** | Policy data already collected | **Policy compliance state is collected and scored by nothing** — see §10. |
| 9 | **FinOps Review** | Cost surface exists | `waf.cost` (6 rules) + `caf.billing` (misnamed, holds cost rules). |
| 10 | **DevOps Capability Assessment** | 5 DevOps collectors exist via the ADO REST API | `caf.platformauto` (6 rules, ~8% coverage). |

| 11 | **Microsoft Cloud Security Benchmark (MCSB)** | **Not on Microsoft's assessment page — it is an Azure Policy initiative** — but the cheapest high-value assessment available. 223 policies, Defender for Cloud's *default* initiative so assigned in essentially every subscription, and **Scout already collects the compliance state without scoring it.** A rendering job, not rule authoring. See §8 Table 4. | Compliance state collected via three code paths, read by no rule. |
| 12 | **Azure Well-Architected Framework Maturity Model** | Same rules as #1, different output shape — "level 2 of 5" lands better with customers than a list of failures. | Nothing extra needed beyond #1. |
| 13 | **Cloud Adoption Security Assessment (CASA)** | Aligned to the CAF **Secure** methodology, which Scout does not model at all. Pairs with #2. | `caf.security` (7 rules). No Secure-methodology structure. |
| 14 | **Strategic Migration Assessment (SMART)** | **Only after the Migration category is built** — currently **zero collectors** (§6 group D7). | Blocked on D7. |

### Deliberately excluded

Partner-enablement guides, skills assessments and industry-vertical readiness guides are training
material, not tooling. Scout cannot produce them and should not try.

### What this implies

**Fourteen assessments where Scout has one.** The work splits three ways:

1. **Restructuring** — #1 and #2 are largely re-registering rules that already exist, split by
   pillar and design area rather than lumped into `LandingZone`. Hours, not weeks.
2. **New rule files** — #3 through #7 need workload-specific rule sets. The *inventory* is already
   there for Azure Local, AI, AVD and AVS; only the scoring is missing.
3. **Depth** — #1, #2, #8, #9, #10 all need their existing rule files taken from ~10-15% coverage
   toward something defensible. This is the largest body of work in the document.

**Prerequisite:** the wizard path bug (decision row 4) must be fixed first, or none of these will
be reachable from the guided experience.

---

### The ones that matter for Scout

Of the 56, these are the **workload/platform assessments** in Scout's problem space — the rest are
partner-enablement, skills, or industry-vertical guides:

| Assessment | Why it matters |
|---|---|
| **Azure Well-Architected Review** | The canonical WAF assessment — ~60 questions across the five pillars |
| **Azure Landing Zone Review** | The canonical CAF landing-zone assessment |
| **Azure Well-Architected Framework Maturity Model** | Maturity scoring rather than pass/fail |
| **Go-Live**, **Mission Critical**, **Sustainability** WAF Reviews | Narrower WAF lenses |
| **Per-workload WAF reviews** — AI, AVD, AVS, Oracle IaaS, SaaS, Azure Local, SAP, Azure ML | WAF applied to a specific workload type |
| **Cloud Adoption Security Assessment (CASA)** | Aligned to the CAF **Secure** methodology |
| **Cloud Governance**, **Cloud Adoption Strategy Evaluator**, **Cloud Journey Tracker** | CAF methodology assessments |
| **FinOps Review** | Cost/FinOps — overlaps Scout's cost surface |
| **DevOps Capability**, **Platform Engineering** | CAF platform-automation design area |
| **Strategic Migration Assessment (SMART)** | CAF Migrate |

**Scout implements one thing today: `LandingZone`**, a rule set drawing on both WAF pillars and CAF
design areas. Microsoft ships **at least 13** distinct workload/platform assessments in that space
plus **5 CAF methodology assessments**.

---

### Which collectors each target assessment depends on

The ten assessments in §3, mapped to the collectors they need. **A collector is not optional if an
assessment depends on it** — this is what turns the build list above into a release order.

Legend: ✅ have · ⚠️ partial · 🔲 need *(build-list ref)*

| Assessment | Collectors it depends on | Blocking gaps |
|---|---|---|
| **1. Azure Well-Architected Review** | VMs ✅ · disks ✅ · storage ✅ · SQL ✅ · networking ✅ · backup ⚠️ · monitor ✅ · cost ⚠️ | **C1** backup protected items *(Reliability pillar cannot score without it)* · **B4** budgets *(Cost pillar)* · **C8** snapshots *(Cost)* |
| **2. Azure Landing Zone Review** | management groups ⚠️ · policy defs ⚠️ · policy assignments 🔲 · RBAC 🔲 · locks 🔲 · subscriptions ⚠️ · networking ✅ · Entra ✅ | **A1-A4** the dead switch *(4 collectors that can never run)* · **B1-B3** RBAC, locks, policy assignments · **D15** resource groups |
| **3. Azure Local \| WAF Review** | Azure Local clusters ✅ · logical networks ✅ · storage containers ✅ · gallery images ✅ · Arc servers ✅ · Arc extensions ✅ · Arc sites ✅ *(AB#6801)* · Azure Local VM instances ✅ *(AB#6802)* | **A8/A9 fixed** — see §9 note 3's revised verdict; not yet proven against a live Azure Local estate (see AB#6802's evidence note) |
| **4. WAF AI workload** | Cognitive Services ✅ · ML workspaces ✅ · ML computes/endpoints/models ✅ · AI Search ✅ · Key Vault ⚠️ · private endpoints ✅ | **C2-C4** Key Vault children *(AI workloads score on secret handling)* |
| **5. WAF Azure Virtual Desktop workload** | AVD host pools ✅ · session hosts ✅ · workspaces ✅ · app groups ✅ · scaling plans ✅ · VMs ✅ · storage ⚠️ | **C6** file shares *(FSLogix profile containers)* · **C1** backup protected items |
| **6. WAF Azure VMware Solution workload** | AVS private clouds ✅ · networking ✅ · ExpressRoute ✅ | **C16** Virtual WAN hubs/gateways *(AVS connectivity)* |
| **7. AVS Landing Zone Review** | Same as #6 + management groups ⚠️ · policy ⚠️ | **A1-A4** dead switch · **C16** |
| **8. Cloud Governance** | policy defs ⚠️ · policy assignments 🔲 · policy **compliance state** 🔲 · RBAC 🔲 · locks 🔲 · management groups ⚠️ · budgets 🔲 | **A1-A4** · **B1-B4** — **this assessment is almost entirely blocked**, and every blocker is already-collected data that nothing renders |
| **9. FinOps Review** | cost data ⚠️ · reservations ⚠️ · advisor ✅ · orphaned disks ✅ · orphaned PIPs ✅ · snapshots 🔲 · budgets 🔲 | **B4** budgets · **C8** snapshots *(orphaned spend)* · owned reservations *(recommendations only today)* |
| **10. DevOps Capability Assessment** | ADO orgs/projects/pipelines/repos/service connections ✅ *(REST)* · deployments ✅ | **D-new** Managed DevOps Pools, Dev centers, Load Testing — none collected |
| **11. MCSB** | policy **compliance state** 🔲 · policy set definitions ⚠️ | **B3-adjacent** — the compliance state is already collected and read by nothing. **No new Azure calls required.** Also **A3-A4** to detect which initiatives are assigned. |
| **12. WAF Maturity Model** | Identical to #1 | Same blockers as #1 — no additional collectors |
| **13. CASA** | Defender ✅ · Key Vault ⚠️ · policy ⚠️ · RBAC 🔲 · Entra ✅ · networking ✅ | **B1** RBAC assignments · **C2-C4** Key Vault children · **A1-A4** |
| **14. SMART** | Azure Migrate 🔲 · DMS 🔲 · Data Box 🔲 · Stack Edge 🔲 · VMs ✅ | **D7 — the entire Migration category is at zero.** Blocked until built. |

### What this ordering tells you

**Group A (the 12 fixes) blocks four assessments.** The dead `-IncludeTenantWideResources` switch
alone blocks #2, #7, #8 and #13 — because management groups, policy definitions, policy set
definitions and custom role definitions can never run. **This is Scout's own defect and it is two
lines of code** — a temporary AB#5933 migration gate whose consumers shipped without anyone
removing it. Root cause, both call sites, and the follow-on work are in **§9 note 3**. That single
wiring fix is the highest-leverage item in the entire document.

**Group B (the 4 free renders) blocks two assessments outright.** #8 Cloud Governance is
*almost entirely* blocked by data Scout already has in memory and never writes down. #2 Landing
Zone Review is heavily degraded by the same four.

**#3 Azure Local was the differentiator with a hole in it — the hole is closed at the code level.**
`ArcSites` and `azurestackhci/virtualmachineinstances` both returned nothing in every tenant, on
every run, regardless of permission (§9 note 3). AB#6801/AB#6802 (Feature AB#6747) re-sourced
both against the correct, cited endpoints. Static verification is complete; live confirmation
against a tenant that actually runs Azure Local and Arc site manager is still open (see AB#6802's
report for what was and was not proven).

**Only #4, #5, #6 and #10 are mostly ready.** Their inventory exists; they need rule files, not
collectors.

## 15. The collector build list

Every gap above, with the resource type to build against and whether a collector already exists.
**This is the work list.**

#### A. Collector exists — fix it, don't build it

| # | Collector | Problem | Fix |
|---|---|---|---|
| A1 | `Management/ManagementGroups` | Gated on `-IncludeTenantWideResources`, a temporary AB#5933 migration gate that was never removed after its consumers shipped | Set the switch at **both** call sites — `Start-ScoutGraphExtraction.ps1:69-83` (worksheets) **and** `Invoke-Collect.ps1:707` (assessments). Root cause and full fix: §9 note 3 |
| A2 | `Management/CustomRoleDefinitions` | Same dead switch | Same fix — both call sites |
| A3 | `Management/PolicyDefinitions` | Same dead switch | Same fix — both call sites |
| A4 | `Management/PolicySetDefinitions` | Same dead switch | Same fix — both call sites |
| A5 | `Monitor/Outages` | Runs before the data it reads is merged | Move `Get-ScoutOutageResource` after the API merge |
| A6 | `Management/LighthouseDelegations` | Queries `managedserviceresources`, a table Scout never reads | Add that table pass |
| A7 | `Monitor/ResourceDiagnosticSettings` | `microsoft.insights/diagnosticsettings` is not ARG-indexed | Re-source via per-resource ARM REST |
| A8 | `Hybrid/ArcSites` | Declares 3 provider/type pairs that do not exist | Correct to `Microsoft.Edge/sites` — **verify it is ARG-indexed first** |
| A9 | `Hybrid/VirtualMachines` | `azurestackhci/virtualmachineinstances` is an extension resource, not ARG-indexed | Re-source; also unblocks `Compute/AVDAzureLocal` |
| A10 | `Databases/POSTGRE` | Targets retired `dbforpostgresql/servers` | Retire the collector |
| A11 | `Monitor/AppInsightsContinuousExport` | Producer removed — Azure retired the endpoint | Retire the collector |
| A12 | `Monitor/AppInsightsWorkItems` | Same | Retire the collector |

#### B. Data already collected — build the collector to render it

**Cheapest work in this document.** No new Azure calls; the data is in memory every run.

| # | Build | Source | Answers |
|---|---|---|---|
| B1 | `Identity/RoleAssignments` | `Import-Governance` | **"Who has Owner"** |
| B2 | `Management/ResourceLocks` | `Import-Governance` | What is protected from deletion |
| B3 | `Management/PolicyAssignments` | `Import-Governance` | Which policies apply, and where |
| B4 | `Cost/Budgets` | `Import-Governance` | Cost guardrails in place |

#### C. Child resources — new collectors, high value

| # | Build | Resource type | Answers |
|---|---|---|---|
| C1 | `Management/BackupProtectedItems` | `microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems` | **Which VMs have no backup** |
| C2 | `Security/KeyVaultSecrets` | `microsoft.keyvault/vaults/secrets` | **Which secrets expire soon** |
| C3 | *(built as part of C2, not a separate collector — AB#6822/AB#6837)* | *there is no `.../vaults/certificates` ARM list endpoint* | Certificate expiry — a certificate is a secret whose `contentType` is `x-pkcs12`/`x-pem-file`; `KeyVaultSecrets`' `Kind`/`Expires` columns already answer this |
| C4 | `Security/KeyVaultKeys` | `.../vaults/keys` | Key rotation posture |
| C5 | `Storage/BlobContainers` | `microsoft.storage/storageaccounts/blobservices/containers` | **Public container exposure** |
| C6 | `Storage/FileShares` | `.../storageaccounts/fileservices/shares` | Share inventory and quotas |
| C7 | `Storage/LifecyclePolicies` | `.../storageaccounts/managementpolicies` | Tiering and lifecycle findings |
| C8 | `Compute/Snapshots` | `microsoft.compute/snapshots` | **Orphaned snapshot spend** |
| C9 | `Compute/Galleries` + images + versions | `microsoft.compute/galleries*` | Image estate |
| C10 | `Compute/DiskEncryptionSets` | `microsoft.compute/diskencryptionsets` | CMK coverage |
| C11 | `Compute/RestorePointCollections` | `microsoft.compute/restorepointcollections` | Restore posture |
| C12 | `Compute/HostGroups` · `ProximityPlacementGroups` · `CapacityReservationGroups` | `microsoft.compute/*` | Dedicated capacity |
| C13 | `Containers/AKSNodePools` | `.../managedclusters/agentpools` | Per-pool sizing and version |
| C14 | `Web/DeploymentSlots` | `microsoft.web/sites/slots` | Slot config drift |
| C15 | `Databases/SQLFailoverGroups` | `microsoft.sql/servers/failovergroups` | SQL HA posture |
| C16 | `Networking/VirtualWANHubs` + gateways | `microsoft.network/virtualhubs`, `/vpngateways`, `/expressroutegateways` | WAN topology |

#### D. Missing services — new collectors

| # | Build | Resource type | Note |
|---|---|---|---|
| D1 | `Integration/LogicApps` | `microsoft.logic/workflows` | **Must remove the ARG query exclusion first** |
| D2 | `Networking/WAFPolicies` | `.../frontdoorwebapplicationfirewallpolicies`, `.../applicationgatewaywebapplicationfirewallpolicies` | Whether a WAF is attached |
| D3 | `Networking/FirewallPolicies` | `microsoft.network/firewallpolicies` | React template already says "not collected" |
| D4 | `Networking/FrontDoorCDN` | `microsoft.cdn/profiles` | Modern AFD — classic retires 2027-03-31 |
| D5 | `Analytics/DataFactory` | `microsoft.datafactory/factories` | Largest data-estate omission |
| D6 | `Security/Sentinel` | `microsoft.securityinsights/*` | Whether Sentinel is onboarded |
| D7 | `Migration/*` — Azure Migrate, DMS, Data Box, Stack Edge | `microsoft.migrate/*`, `microsoft.offazure/*`, `microsoft.datamigration/*`, `microsoft.databox*` | **Entire category at zero** |
| D8 | `Storage/FileSync` | `microsoft.storagesync/storagesyncservices` | |
| D9 | `Storage/ElasticSAN` | `microsoft.elasticsan/elasticsans` | |
| D10 | `Web/AppServiceEnvironments` | `microsoft.web/hostingenvironments` | High-value ASE footprint |
| D11 | `Web/StaticWebApps` | `microsoft.web/staticsites` | |
| D12 | `Integration/EventGrid` | `microsoft.eventgrid/topics`, `/systemtopics`, `/domains` | |
| D13 | `Compute/Batch` | `microsoft.batch/batchaccounts` | |
| D14 | `Management/BackupVaults` | `microsoft.dataprotection/backupvaults` | Current-generation vault type |
| D15 | `Management/ResourceGroups` | `microsoft.resources/subscriptions/resourcegroups` | Empty/untagged RG analysis |
| D16 | `Monitor/AzureMonitorWorkspaces` | `microsoft.monitor/accounts` | |
| D17 | `Monitor/ManagedGrafana` | `microsoft.dashboard/grafana` | |
| D18 | `Identity/EntraDomainServices` | `microsoft.aad/domainservices` | |
| D19 | `Security/ManagedHSM` | `microsoft.keyvault/managedhsms` | |
| D20 | `Networking/DDoSProtectionPlans` | `microsoft.network/ddosprotectionplans` | |

#### E. Cross-resource rules — need two datasets joined

Not collectors. Assessment rules that depend on the above.

| # | Question | Depends on |
|---|---|---|
| E1 | Which VMs have no backup | VMs ✅ + C1 |
| E2 | Which secrets expire in 30 days | C2 |
| E3 | Which subnets have no NSG | subnets ✅ + NSG associations |
| E4 | Which PaaS services lack a private endpoint | both ✅ — **rule missing, not data** |
| E5 | Which resources are orphaned | disks/NICs/PIPs ✅ + C8 |

---

**Totals: 12 to fix, 4 free renders, 16 child collectors, 20 new services, 5 rules.**
Group B is the cheapest and Group C carries the most consulting value.

---

## 16. The release plan

Everything in Parts II-IV, sequenced. Three rules govern the order:

1. **Defects before features.** A broken collector that ships an empty worksheet is a false
   negative; a missing collector is an honest gap. Fix the lies first.
2. **Unblock before build.** Items that unblock several downstream things run early even when they
   are small — the dead switch is two lines and unblocks four assessments.
3. **Nothing ships unverified.** Every release below has an exit check in §17.

Effort is engineering time, not calendar time.

---

### Release 0 — Land what is already decided *(days)*

Nothing here is new work. It is the backlog of decisions that outran the code.

| # | Work | Effort | Source |
|---|---|---|---|
| 0.1 | **Commit the patch-assessment read-only fix.** Written, 30/30 tests, regression lock proven non-vacuous, sitting uncommitted. | Minutes | §5.4, decision 1 |
| 0.2 | **Fix the wizard manifest path** — three `Split-Path` calls to one. Exposes the hidden registry entries; 0.5 and 0.6 then make the menu honest. | 15 min | §5.2, decision 4 |
| 0.3 | **Wire `-IncludeTenantWideResources` at both call sites** — `Start-ScoutGraphExtraction.ps1:69-83` and `Invoke-Collect.ps1:707`. Assert the **production splat** sets it, not just that the function honours it. | Hours | §9 note 3, DQ4 |
| 0.4 | **Correct the eight fact-check defects in §9** before that table goes to any customer. | Hours | DQ6 |
| 0.5 | **Prefix the 15 category-named assessment entries with `Assess:`** so the menu stops colliding with the 15 inventory category names the moment it grows from 1 visible entry to 21. Stopgap — they are retired in Release 3. | Minutes | DQ11 |
| 0.6 | **Hide unbuilt assessments from the menu.** Only entries Scout can actually run may appear; one that returns nothing reads as *"no findings"*. | Small | DQ1 |

**Why these four together:** 0.1 makes Scout read-only in shipped code rather than in the working
tree. 0.2 and 0.3 are the two smallest fixes in the document and between them unblock 21 menu
entries and four assessments. 0.4 stops a known-wrong table being used as a grant request.

---

### Release 1 — Stop lying *(1-2 weeks)*

Every item is a case where Scout currently reports something untrue: an empty sheet that reads as
"none found", a green banner over a failed scan, or data collected and silently dropped.

| # | Work | Effort | Source |
|---|---|---|---|
| 1.1 | **Dump ALL raw collected data** to JSON regardless of whether a collector renders it. Eliminates the ~40% silent discard outright. | Small | §5.3, decision 2 |
| 1.2 | **Replace the READY/PARTIAL verdict with a per-collector impact table.** *"142 of 174 collectors will produce data. These 32 will be empty, and why."* Stop swallowing Graph 403s into a `Write-Host "SKIP"` that never reaches the warning stream. | 1-2 d | §9, decision 6 |
| 1.3 | **Per-collector row-count artifact, retained per run.** Prerequisite for DQ7 and for any regression detection at all. | 1 d | AB#6444 |
| 1.4 | **Retire or re-source the broken collectors** — retire `POSTGRE`, `AppInsightsContinuousExport`, `AppInsightsWorkItems`; re-source `ResourceDiagnosticSettings` via ARM REST; fix `Monitor/Outages` call ordering; add the `managedserviceresources` pass for `LighthouseDelegations`. | 2-3 d | §9 note 3, DQ9, build list A5-A12 |
| 1.5 | **Static resource-type existence gate** in CI — a manifest declaring a type Azure does not have must fail the build, not ship an empty sheet. | 1 d | AB#6444 |
| 1.6 | **Fix the four collect-once defects** — retire `ArgQueryPack`, expose the combined run as a parameter, fix the tags loss in the handoff, feed `AdvisorScores` from `$ExtractionData.Advisories`. | 2-3 d | §10 |
| 1.7 | **Drop the three redundant roles** from docs, pre-flight, and the customer grant list. | Hours | §9, decision 5 |
| 1.8 | **Build the four free renders** — `Identity/RoleAssignments`, `Management/ResourceLocks`, `Management/PolicyAssignments`, `Cost/Budgets`. No new Azure calls; the data is in memory every run. Answers *"who has Owner"*. | 2-3 d | Build list B1-B4 |
| 1.9 | **Finish §6's enumeration** — the 16 portal services not yet listed. | Half a day | DQ5 |
| 1.10 | **Un-exclude Logic Apps** from the ARG query. | Minutes | §5.3 |

**Exit criterion:** a run produces no worksheet that is empty for a reason the run itself did not
report.

---

### Release 2 — Compliance, the cheapest new capability *(1 week)*

| # | Work | Effort | Source |
|---|---|---|---|
| 2.1 | **Score the Microsoft Cloud Security Benchmark** from the policy compliance state Scout **already collects and no rule reads.** 223 policies, Defender for Cloud's *default* initiative, therefore assigned in essentially every subscription. | Days | §8 Table 4, target #11 |
| 2.2 | **Three-state reporting: `Pass` / `Fail` / `Not assessed`.** Non-negotiable, and it constrains 2.1 — decide DQ8 before starting, not after. | Included in 2.1 | DQ8 |
| 2.3 | **Detect which other regulatory initiatives are assigned** and expose each as its own assessment — CIS, ISO 27001, NIST 800-53, NIST CSF, PCI-DSS. Rendering, not rule-authoring. | 1 wk | §8 Table 4 |
| 2.4 | **Move `Estate` out of the assessment registry entirely** — not merely re-prompted (DQ10). Delete `Policy` and rename the `UpdateManager` / `Monitoring` subsets so the relationship is visible (DQ2). | Small | Decision 11, DQ2, DQ10 |

**Why this is second:** it is the highest ratio of new customer-visible capability to engineering
effort anywhere in this document. Azure has already done the control evaluation. Scout already
collects the answer. Nothing reads it.

---

### Release 2b — Enumerate the frameworks *(1-2 weeks, gates everything after it)*

**This phase exists because of DQ12: only 2 of the 14 target assessments have an enumerated source
framework.** No rule file may be written for a target until its source is tabulated. Skipping this
is how `waf.storage.yaml` came to score a WAF pillar that does not exist.

| # | Enumerate | Already done? |
|---|---|---|
| 2b.1 | WAF — 5 pillars, 59 checklist items | ✅ §8 Table 1 |
| 2b.2 | CAF — 8 design areas, ~394 recommendations | ✅ §8 Table 2 |
| 2b.3 | Azure Local WAF Review checklist | 🔲 |
| 2b.4 | WAF AI workload checklist | 🔲 |
| 2b.5 | WAF AVD workload checklist | 🔲 |
| 2b.6 | WAF AVS workload checklist | 🔲 |
| 2b.7 | AVS Landing Zone Assessment question set | 🔲 |
| 2b.8 | Cloud Governance question set | 🔲 |
| 2b.9 | FinOps Review question set | 🔲 |
| 2b.10 | DevOps Capability Assessment question set | 🔲 |
| 2b.11 | CASA question set | 🔲 |
| 2b.12 | SMART question set | 🔲 |

**Each enumeration must be date-stamped with its verification method.** §8's currency warnings
record Microsoft actively rewriting CAF design-area pages away from the `Design considerations` /
`Design recommendations` structure — at least three pages already have no recommendations heading
at all. **Any coverage percentage Scout publishes must name the framework version it was measured
against**, or it will silently drift into being wrong.

This is reading and tabulating published Microsoft content — cheap, unglamorous, and the only thing
that makes a coverage number mean anything.

---

### Release 3 — Restructure the assessments *(2-3 weeks)*

| # | Work | Effort | Source |
|---|---|---|---|
| 3.1 | **Split `LandingZone` into per-WAF-pillar and per-CAF-design-area assessments.** This is the real assessment gap and it survives every other fix. | 1-2 wks | §8 Tables 1-2, targets #1, #2 |
| 3.2 | **Fix the two false-pass rules**; retire or reclassify `waf.storage.yaml`, which is not a WAF pillar. | Days | AB#6447 |
| 3.3 | **Rename `caf.billing.yaml`** — it contains cost rules, not billing-tenant rules. | Small | §8 |
| 3.4 | **WAF Maturity Model** — falls out of 3.1 for free, same rules, different output shape. | Small | Target #12 |
| 3.5 | Update the retired-guidance rules: five CAF governance disciplines are gone, two new default management groups exist, CAF states AI does **not** need its own landing zone. | Days | §8 currency warnings |

---

### Release 4 — Differentiate on Azure Local *(1-2 weeks)*

| # | Work | Effort |
|---|---|---|
| 4.1 | **Fix `Hybrid/ArcSites`** — correct to `Microsoft.Edge/sites`, verify it is ARG-indexed first. | Days |
| 4.2 | **Re-source `azurestackhci/virtualmachineinstances`** — an extension resource, not ARG-indexed. Also unblocks `Compute/AVDAzureLocal`. | Days |
| 4.3 | **Azure Local rule file** → target #3, Azure Local WAF Review. | 1 wk |

**Why it rates its own release:** Azure Local is the strongest competitive position in the product
and two of its collectors return nothing in every tenant today.

---

### Release 5 — Workload assessments *(3-4 weeks)*

Targets #4 AI, #5 AVD, #6 AVS, #7 AVS Landing Zone, #13 CASA. Rule files plus the Key Vault child
collectors (C2-C4) and the remaining workload types. #4/#5/#6 are the closest to ready in the
whole programme — their inventory already exists.

### Release 6 — Cost, FinOps and DevOps *(2-3 weeks)*

Targets #9 FinOps, #10 DevOps Capability. Snapshot and owned-reservation collectors, the DevOps
service collectors, and the DevOps category itself — which is *mostly a directory move*, since
five collectors already exist misfiled under Management.

### Release 7 — Migration from zero *(2-3 weeks)*

The only category at 0% coverage. Azure Migrate, Database Migration Services, Data Box, Stack Edge.
Unlocks target #14 SMART, which is blocked outright until this exists.

### Release 8 — Depth *(ongoing)*

Build out the thin categories — Storage, Web, Integration, IoT, Security — and push CAF/WAF rule
depth toward real coverage. This is the long tail and it does not end.

---

### The whole programme, at a glance

| Release | Theme | Effort | Unlocks |
|---|---|---|---|
| **0** | Land what is decided | Days | An honest menu · assessments #2, #7, #8, #13 unblocked |
| **1** | Stop lying | 1-2 wks | Trustworthy output; **prerequisite for everything** |
| **2** | Compliance | 1 wk | #11 MCSB + CIS/ISO/NIST/PCI as rendering |
| **2b** | **Enumerate the frameworks** | 1-2 wks | **Gates every rule file after it (DQ12)** — 12 of 14 targets have no tabulated source |
| **3** | Restructure | 2-3 wks | #1, #2 in Microsoft-recognised shape; #12 free |
| **4** | Azure Local | 1-2 wks | #3 — the differentiator |
| **5** | Workloads | 3-4 wks | #4, #5, #6, #7, #13 |
| **6** | Cost & DevOps | 2-3 wks | #9, #10 · DevOps category |
| **7** | Migration | 2-3 wks | #14 · the 0% category |
| **8** | Depth | Ongoing | Real CAF/WAF coverage |

**Releases 0-2 are ~3 weeks and deliver most of the value in this document**: Scout becomes
read-only in shipped code, stops reporting empty as "none found", exposes 21 hidden assessments,
unblocks four more, and gains a compliance capability from data it already has.

---

## 17. How we will know it worked

An audit that produces no exit criteria produces another audit. Each release above has one.

| Release | Exit check | How it is proven |
|---|---|---|
| **0** | The four Management collectors return rows | Per-collector row count > 0 in a live run against the demo tenant |
| **0** | The wizard menu lists every assessment Scout can run, and nothing it cannot | Screenshot / transcript of the menu; cross-check each entry against a run that produces rows |
| **1** | No worksheet is silently empty | Every empty sheet has a matching line in the run's impact table |
| **1** | Reader-only is sufficient, or we know exactly where it is not | **DQ7 — the Reader-only live run.** Compare per-collector row counts against the full role stack |
| **1** | The Management Group Reader question is settled | Re-test after 0.3; it is unanswerable before then |
| **2** | MCSB scores against a real subscription | Compliance percentage matches the Defender for Cloud blade |
| **2** | "Not assessed" never renders as a pass | Test with a deliberately unassigned initiative |
| **3** | Per-pillar scores are defensible | Spot-check against Microsoft's own WAF review questions |
| **4** | Azure Local returns rows | Live run against an Azure Local tenant |
| **All** | Fixtures are not vacuous | Reintroduce the defect; the test must fail |

**The standing verification gap:** test fixtures are *generated from the collectors' own
definitions*, so a collector that declares a resource type Azure does not have produces a fixture
that agrees with it. **The suite cannot catch this class of defect** — item 1.5 (the static
existence gate) is the structural fix, and DQ7 is the empirical one. Until both land, "1787 tests
pass" is not evidence that Scout collects anything.

---

## Appendix — detailed reports

| Report | Work item |
|---|---|
| [`AB6444-collector-verification-audit.md`](./AB6444-collector-verification-audit.md) | AB#6444 |
| [`AB6445-least-privilege-permissions-audit.md`](./AB6445-least-privilege-permissions-audit.md) | AB#6445 |
| [`AB6446-service-coverage-gap-analysis.md`](./AB6446-service-coverage-gap-analysis.md) | AB#6446 |
| [`AB6447-caf-waf-coverage-audit.md`](./AB6447-caf-waf-coverage-audit.md) | AB#6447 |
