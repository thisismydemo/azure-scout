# CAF — the eight landing-zone design areas, enumerated

> **Source:** <https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas>
> and its child pages under `ready/landing-zone/design-area/` and `ready/considerations/` — see the
> per-area `Source` lines below for the exact URLs read.
> **Framework version:** Microsoft does not version CAF landing-zone recommendations; this
> enumeration uses the extraction date, 2026-08-01, as the version.
> **Extracted:** 2026-08-01
> **Verification method:** All eight design areas were fetched page-by-page via `microsoft_docs_fetch`
> (Microsoft Learn MCP server) and every recommendation bullet or, on pages Microsoft has rewritten
> away from the Considerations/Recommendations structure, every actionable numbered step or `##`
> heading, transcribed and numbered. Network topology and connectivity — the eighth area, and CAF's
> largest — was left as a documented gap in an earlier pass of this file; this session closed that gap
> by fetching its hub page plus 10 of its ~14 child pages (135 items) via Microsoft Learn MCP search
> and fetch. The remaining ~3-4 child pages (see the `CAF-NET-*` section for the exact list) were not
> retrieved this session and are recorded there as a smaller residual gap, not invented.

**Enumerated 2026-08-01.** This is the source-framework enumeration required by AB#6745 (Epic
AB#6454), covering the Cloud Adoption Framework's Ready/landing-zone design areas — the axis
`src/assess/rules/caf.*.yaml` scores today (see `docs/frameworks/smart-question-set.md` for why an
enumeration has to exist before a rule file cites it, and `pmo/audits/AZURE-SCOUT-AUDIT.md` §8
Table 3 for why "CAF" in Scout means this one methodology, Ready, not the seven CAF methodologies).

## What this is

Eight design areas, confirmed on
[Azure landing zone design areas and conceptual architecture](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas):
four **environment** design areas (billing/tenant, identity, resource organization, network) and
four **compliance** design areas (security, management, governance, platform automation). Unlike
WAF, **CAF's landing-zone recommendations have no Microsoft-published item numbers** — they are
unnumbered bullets under a `## Design recommendations` heading (or an area-specific equivalent).
The `CAF-<AREA>-<NN>` identifiers below are **Scout's own**, assigned in fetch order down each page,
using the area abbreviations already in use by `src/assess/rules/caf.*.yaml`
(`CAF-BIL`, `CAF-IDN`, `CAF-RES`, `CAF-NET`, `CAF-SEC`, `CAF-MGT`, `CAF-GOV`, `CAF-AUT`). Any
coverage percentage published against this file must say so — the denominator is Scout's own count
of bullets, not a Microsoft-published figure.

## Verification method and scope of this enumeration

Each design area's hub page and its child pages were fetched via `microsoft_docs_fetch` (Microsoft
Learn MCP server), the first seven areas on 2026-08-01 and **Network topology and connectivity** in a
follow-up pass the same day. **All eight areas are enumerated below, item by item, from real page
content — nothing in this file was invented.** Network topology and connectivity is CAF's largest
design area (the audit measured 123 formal recommendations across 14 pages on 2026-07-30); this
session fetched its hub page and 10 of its ~14 child pages, transcribing 135 items. That is more than
the audit's 123 because two of the transcribed pages (`virtual-wan-network-topology` and
`connectivity-to-other-providers`) are already in Microsoft's rewritten, numbered-task format rather
than a bulleted `## Design recommendations` list — consistent with this file's stated counting rule
for pages Microsoft has moved away from that structure — and because the base `plan-for-ip-addressing`
page carries three separate Design-recommendations subsections (base addressing, IPv6, IPAM) that the
audit's page-level count did not necessarily itemize separately. A residual ~3-4 child pages were not
retrieved this session; they are named explicitly in the `CAF-NET-*` section below as the remaining
gap for a further follow-up, not invented or estimated into the total.

Recommendation counts in this file were produced by reading each page's `## Design recommendations`
section (or equivalent) and numbering each top-level bullet once, treating nested sub-bullets as
elaboration of their parent unless they were substantively distinct actions. Pages that carry no
`## Design recommendations` heading at all are noted explicitly, per the audit's currency warning
(Microsoft is mid-rewrite of this content away from the Considerations/Recommendations structure).

| Design area | Pages read this session | Items enumerated | Prior audit figure (§8 Table 2/3, 2026-07-30) |
|---|---|---|---|
| Azure billing and Microsoft Entra tenant | 4 of ~5 (hub excluded, no recs) | **41** | 42 |
| Identity and access management | 3 of ~4 | **63** | 65 |
| Resource organization | 2 of ~3 (hub excluded, no recs) | **35** | 35 |
| Network topology and connectivity | 11 of ~14 (hub + 10 child pages; hub has no recs) | **135** | 123 formal / ~155 with numbered-task format |
| Security | 3 of ~3 | **42** | 45 |
| Management | 3 of ~5 (2 pages verified to carry no recs) | **15** | 15 |
| Governance | 1 of 1 (self-contained) | **10** | 10 |
| Platform automation and DevOps | 8 of ~10 | **52** | 30 |
| **Total (all eight areas)** | — | **393** | — |

The Platform automation figure is materially higher than the prior audit's because this session
counted every actionable imperative heading on pages that carry no `## Design recommendations`
wrapper (e.g. `security-considerations-overview`'s eight `##` headings, each a "restrict/use/do X"
instruction) as an item, consistent with the instruction to record what a page actually contains
rather than force it into the old Considerations/Recommendations shape. The prior audit's narrower
figure likely counted only pages with a literal "Design recommendations" heading. Both counts are
defensible; this file's is the one with a numbered ID a rule can cite.

## Azure billing and Microsoft Entra tenant — `CAF-BIL-*` (41 items, 4 pages)

Base URL: `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/`

Hub page (`azure-billing-ad-tenant`) is a links-only index — no recommendations of its own.

### Enterprise Agreement — `CAF-BIL-EA-*` (15 items)

Source: [Plan for Enterprise Agreement enrollment](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-enterprise-agreement)

| # | Item |
|---|---|
| CAF-BIL-EA-01 | Implement a subscription-vending strategy to automate subscription creation as a self-service function. |
| CAF-BIL-EA-02 | Use only the `Work or school account` authentication type; avoid Microsoft account (MSA). |
| CAF-BIL-EA-03 | Set up a Notification Contact email address routed to an appropriate group mailbox. |
| CAF-BIL-EA-04 | Map the organization's structure to the enrollment hierarchy via departments and accounts. |
| CAF-BIL-EA-05 | Use Cost Management reports and views (tags, location) to explore and analyze cost. |
| CAF-BIL-EA-06 | Restrict and minimize the number of account owners within the enrollment. |
| CAF-BIL-EA-07 | Assign a budget per department and account, with an alert associated with the budget. |
| CAF-BIL-EA-08 | Create new departments for IT only where the business domain has independent IT capabilities. |
| CAF-BIL-EA-09 | If using multiple Microsoft Entra tenants, verify the account owner is associated with the same tenant as its provisioned subscriptions. |
| CAF-BIL-EA-10 | Use the Enterprise Dev/Test offer for dev/test workloads where available. |
| CAF-BIL-EA-11 | Don't ignore notification emails sent to the notification account address. |
| CAF-BIL-EA-12 | Don't move, rename, or delete the Entra ID user associated with the EA enrollment account. |
| CAF-BIL-EA-13 | Periodically audit who has access in the Cost Management blade. |
| CAF-BIL-EA-14 | Enable both DA View Charges and AO View Charges on every EA enrollment. |
| CAF-BIL-EA-15 | Protect any user with subscription-creation permissions on the enrollment with multifactor authentication. |

### Microsoft Customer Agreement — `CAF-BIL-MCA-*` (9 items)

Source: [Plan for the Microsoft customer agreement service](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-microsoft-customer-agreement)

| # | Item |
|---|---|
| CAF-BIL-MCA-01 | Implement a subscription-vending strategy to automate subscription creation as a self-service function. |
| CAF-BIL-MCA-02 | Set up a Notification Contact email address on the agreement billing account. |
| CAF-BIL-MCA-03 | Assign a budget per invoice section or billing profile, with an associated alert. |
| CAF-BIL-MCA-04 | Map the organization's structure to the agreement hierarchy; invoice sections suit most scenarios. |
| CAF-BIL-MCA-05 | Create a new invoice section for IT if the business domain has independent IT capabilities. |
| CAF-BIL-MCA-06 | Don't ignore notifications sent to the contact email address. |
| CAF-BIL-MCA-07 | Periodically audit the agreement billing RBAC role assignments. |
| CAF-BIL-MCA-08 | Use the Microsoft Azure plan for dev/test for dev/test workloads where available. |
| CAF-BIL-MCA-09 | Protect any user with permissions to create subscriptions (invoice section, billing profile, or billing account) with MFA. |

### Cloud Solution Provider — `CAF-BIL-CSP-*` (9 items)

Source: [Plan for the Cloud Solution Provider service](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-billing-cloud-solution-provider)

| # | Item |
|---|---|
| CAF-BIL-CSP-01 | Use Azure Lighthouse for administer-on-behalf-of (AOBO) access for most CSP support scenarios. |
| CAF-BIL-CSP-02 | Migrate to granular delegated admin privileges (GDAP) instead of delegated admin privileges (DAP). |
| CAF-BIL-CSP-03 | Follow the Customer security best practices. |
| CAF-BIL-CSP-04 | Follow the CSP security best practices. |
| CAF-BIL-CSP-05 | Work with the CSP partner to define support-case and escalation processes. |
| CAF-BIL-CSP-06 | Discuss self-service subscription creation with the CSP partner. |
| CAF-BIL-CSP-07 | Use Cost Management reports and views to explore and analyze cost. |
| CAF-BIL-CSP-08 | Protect any user with subscription-creation permissions with MFA. |
| CAF-BIL-CSP-09 | CSP partners provision Azure subscriptions into the customer's own Microsoft Entra tenant, not a partner-managed one. |

### Define Microsoft Entra tenants — `CAF-BIL-TEN-*` (8 items)

Source: [Define Microsoft Entra tenants](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/azure-ad-define)

| # | Item |
|---|---|
| CAF-BIL-TEN-01 | Add one or more custom domains to the Microsoft Entra tenant. |
| CAF-BIL-TEN-02 | Define an Azure single sign-on strategy using Microsoft Entra Connect. |
| CAF-BIL-TEN-03 | If there is no existing identity infrastructure, start with a Microsoft Entra-only deployment. |
| CAF-BIL-TEN-04 | Enforce MFA and Conditional Access policies for all privileged accounts. |
| CAF-BIL-TEN-05 | Plan for emergency access (break-glass) accounts to prevent tenant-wide lockout. |
| CAF-BIL-TEN-06 | Use Microsoft Entra Privileged Identity Management (PIM) to manage identities and access. |
| CAF-BIL-TEN-07 | Send all Microsoft Entra diagnostic logs to a central Azure Monitor Log Analytics workspace. |
| CAF-BIL-TEN-08 | Avoid creating multiple Microsoft Entra tenants for the same organization without a specific business requirement. |

This design area is billing/tenant *setup*, not cost optimization. `caf.billing.yaml` in Scout's
rule set currently holds cost-optimization rules — the naming defect the audit's §8 flags — and does
not assess any item above; see the audit for the remediation.

## Identity and access management — `CAF-IDN-*` (63 items, 3 pages)

Base URL: same as above, `design-area/`

### Hybrid identity with Active Directory — `CAF-IDN-HYB-*` (21 items)

Source: [Hybrid identity with Active Directory and Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/identity-access-active-directory-hybrid-identity)

| # | Item |
|---|---|
| CAF-IDN-HYB-01 | Document the authentication provider each application uses to determine identity solution requirements. |
| CAF-IDN-HYB-02 | Use Domain Services for legacy-protocol applications instead of extending an on-premises domain. |
| CAF-IDN-HYB-03 | Factor resiliency into the hybrid identity design — Entra ID is globally redundant, Domain Services/AD DS are not. |
| CAF-IDN-HYB-04 | Extend on-premises AD DS sites/subnets to match Azure region deployments. |
| CAF-IDN-HYB-05 | Evaluate B2B / External ID scenarios for guest, customer, and partner access. |
| CAF-IDN-HYB-06 | Don't use Microsoft Entra application proxy for intranet access. |
| CAF-IDN-HYB-07 | Deploy an Entra Connect staging server in a different region for DR, or across availability zones for HA. |
| CAF-IDN-HYB-08 | For Entra Cloud Sync, install at least three agents across servers/regions for DR, or across availability zones for HA. |
| CAF-IDN-HYB-09 | Determine the right synchronization tool for the cloud identity solution. |
| CAF-IDN-HYB-10 | If AD FS is required, deploy per guidance; otherwise migrate to Microsoft Entra ID. |
| CAF-IDN-HYB-11 | Use Microsoft Entra application proxy to remotely access on-premises applications through Entra ID. |
| CAF-IDN-HYB-12 | Evaluate workload compatibility between AD DS and Entra Domain Services. |
| CAF-IDN-HYB-13 | Deploy domain controller VMs or Domain Services replica sets into the Identity subscription/platform management group. |
| CAF-IDN-HYB-14 | Secure the domain-controller virtual network with an isolated subnet and NSG. |
| CAF-IDN-HYB-15 | Use Azure Virtual Network Manager to enforce standard network group rules for identity connectivity. |
| CAF-IDN-HYB-16 | Secure RBAC permissions on domain-controller VMs and other identity resources. |
| CAF-IDN-HYB-17 | If using Azure Arc for on-premises domain controllers, place the Arc resources in the Identity subscription with strict access controls. |
| CAF-IDN-HYB-18 | Keep core applications close to (or in the same region as) their replica-set virtual network. |
| CAF-IDN-HYB-19 | Consider deploying AD DS domain controllers across multiple regions and availability zones for resiliency. |
| CAF-IDN-HYB-20 | Explore Microsoft Entra ID authentication methods (cloud, on-premises, or both) as part of identity planning. |
| CAF-IDN-HYB-21 | Consider Kerberos authentication for Microsoft Entra ID instead of deploying domain controllers, for Azure Files. |

### Landing zone identity and access management — `CAF-IDN-LZ-*` (30 items)

Source: [Landing zone identity and access management](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/identity-access-landing-zones)

| # | Item |
|---|---|
| CAF-IDN-LZ-01 | Enforce phishing-resistant Microsoft Entra multifactor authentication for all users with rights to the Azure environment. |
| CAF-IDN-LZ-02 | Use Microsoft Entra Conditional Access policies for users with rights to the Azure environment. |
| CAF-IDN-LZ-03 | Enable Microsoft Defender for Identity to protect user identities and credentials. |
| CAF-IDN-LZ-04 | Use Microsoft Sentinel for threat intelligence and investigation across Entra ID, Microsoft 365, and other logs. |
| CAF-IDN-LZ-05 | Separate administrative access from nonadministrative day-to-day access (cloud-only accounts for privileged roles; PIM for nonprivileged elevation). |
| CAF-IDN-LZ-06 | Assign roles to groups, not directly to users (use PIM for groups; use Entra-only groups for control-plane resources). |
| CAF-IDN-LZ-07 | Create emergency-access (break-glass) accounts to avoid Microsoft Entra tenant lockout. |
| CAF-IDN-LZ-08 | Integrate Microsoft Entra ID with Azure Monitor to analyze sign-in activity and audit trails. |
| CAF-IDN-LZ-09 | Use entitlement management to create access packages with approval workflows and access reviews for privileged groups. |
| CAF-IDN-LZ-10 | Use Microsoft Entra built-in roles (Global Administrator, Hybrid Identity Administrator, Security Administrator, Application Administrator) at the correct scope. |
| CAF-IDN-LZ-11 | Don't assign a higher-privileged role than a task requires. |
| CAF-IDN-LZ-12 | Use administrative units to restrict administrators to specific objects in the tenant. |
| CAF-IDN-LZ-13 | Use restricted management administrative units for objects that even higher-privileged roles shouldn't modify. |
| CAF-IDN-LZ-14 | Standardize RBAC roles and role assignments across all application landing zones. |
| CAF-IDN-LZ-15 | Use Azure RBAC for data-plane access (Key Vault, storage, SQL) rather than relying on control-plane access. |
| CAF-IDN-LZ-16 | Configure Azure Monitor Logs workspace permissions so application teams see only their own logs. |
| CAF-IDN-LZ-17 | Consider whether built-in roles meet requirements before creating a custom role. |
| CAF-IDN-LZ-18 | Consider the combined effect when several role assignments apply to the same principal. |
| CAF-IDN-LZ-19 | Periodically review new Microsoft Entra RBAC role definitions. |
| CAF-IDN-LZ-20 | Use the Azure landing zone reference architecture's custom administrative roles (Platform Owner, Subscription Owner, Application Owner, NetOps, SecOps) alongside built-in roles. |
| CAF-IDN-LZ-21 | Ensure the platform team creates all required identity objects (groups, role assignments, managed identities) when provisioning a landing zone. |
| CAF-IDN-LZ-22 | Create landing zone role assignments at subscription or resource-group scope, not management-group scope. |
| CAF-IDN-LZ-23 | Give each application landing zone its own groups and role assignments rather than sharing generic groups. |
| CAF-IDN-LZ-24 | Maintain separate security configurations (groups, managed identities) per environment of the same application. |
| CAF-IDN-LZ-25 | Use PIM to control whether platform administrators require standing access to application landing zones. |
| CAF-IDN-LZ-26 | Use delegated role assignments with conditions to limit what application teams can delegate and assign. |
| CAF-IDN-LZ-27 | Use Microsoft Entra PIM to correlate roles to minimum required access levels under Zero Trust. |
| CAF-IDN-LZ-28 | Use Microsoft Entra PIM access reviews to regularly validate resource entitlements. |
| CAF-IDN-LZ-29 | Use privileged identities for automation runbooks and deployment pipelines that require elevated access. |
| CAF-IDN-LZ-30 | Control highly privileged RBAC roles (Owner, User Access Administrator) with PIM for groups, requiring the same elevation process as Entra roles. |

### Application identity and access management — `CAF-IDN-APP-*` (12 items)

Source: [Application identity and access management](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/identity-access-application-access)

| # | Item |
|---|---|
| CAF-IDN-APP-01 | Configure OpenID Connect from CI/CD platforms to Azure services; fall back to a service principal only if OIDC isn't supported. |
| CAF-IDN-APP-02 | Use attribute-based access control (ABAC) where supported (e.g. Azure Blob Storage). |
| CAF-IDN-APP-03 | Use Microsoft Entra ID identities rather than local authentication to access virtual machines. |
| CAF-IDN-APP-04 | Use managed identities to enable access between Azure resources without credentials. |
| CAF-IDN-APP-05 | Don't share credentials or managed identities across environments (dev/test vs. production). |
| CAF-IDN-APP-06 | At scale, use one user-assigned managed identity per resource type per region rather than many system-assigned identities. |
| CAF-IDN-APP-07 | Use Key Vault (with RBAC for data-plane and control-plane access) to manage application secrets, keys, and certificates. |
| CAF-IDN-APP-08 | Use a separate Key Vault per application environment (dev, preproduction, production) per region. |
| CAF-IDN-APP-09 | Use Microsoft Entra application proxy for remote access to on-premises web applications. |
| CAF-IDN-APP-10 | Where the application uses legacy protocols (Kerberos), ensure landing-zone connectivity to the identity subscription's domain controllers. |
| CAF-IDN-APP-11 | Use the Microsoft identity platform as the identity provider for cloud-native application development. |
| CAF-IDN-APP-12 | Follow the Microsoft identity platform integration-checklist best practices. |

## Resource organization — `CAF-RES-*` (35 items, 2 pages)

Hub page (`resource-org`) is scope/context only — no recommendations of its own.

### Management groups — `CAF-RES-MG-*` (13 items)

Source: [Management groups](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups)

| # | Item |
|---|---|
| CAF-RES-MG-01 | Keep the management group hierarchy reasonably flat — no more than three to four levels. |
| CAF-RES-MG-02 | Don't duplicate the org chart into a deeply nested management group hierarchy; use MGs for policy assignment, not billing/RBAC. |
| CAF-RES-MG-03 | Don't assign application-team RBAC permissions at management-group scope; assign at subscription/resource-group scope instead. |
| CAF-RES-MG-04 | Use resource tags, not a complex management-group hierarchy, to query and navigate horizontally across resources. |
| CAF-RES-MG-05 | Create a `sandbox` management group isolated from development, test, and production. |
| CAF-RES-MG-06 | Create a `platform` management group under the root for common platform policies and role assignments. |
| CAF-RES-MG-07 | Create management groups under the landing-zone group by workload type (`online`, `corp`, `local`, `sandbox`). |
| CAF-RES-MG-08 | Limit the number of Azure Policy assignments at the root management-group scope. |
| CAF-RES-MG-09 | Use policies at management-group or subscription scope to achieve policy-driven governance. |
| CAF-RES-MG-10 | Ensure only privileged users can operate management groups (enable RBAC authorization in hierarchy settings). |
| CAF-RES-MG-11 | Configure a default, dedicated management group for new subscriptions so none land under the root by default. |
| CAF-RES-MG-12 | Don't create separate management groups for production/test/development; separate by subscription within the same MG instead. |
| CAF-RES-MG-13 | Use the standard ALZ management-group structure for multiregion deployments; don't create region-based MGs unless data-residency regulation requires it. |

### Subscriptions — `CAF-RES-SUB-*` (22 items)

Source: [Subscription considerations and recommendations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-subscriptions)

| # | Item |
|---|---|
| CAF-RES-SUB-01 | Treat subscriptions as a unit of management aligned with business needs and priorities. |
| CAF-RES-SUB-02 | Inform subscription owners of roles/responsibilities: periodic PIM access review, budget ownership, policy compliance. |
| CAF-RES-SUB-03 | Weigh scale, management-boundary, policy-boundary, and network-topology principles when identifying new subscription requirements. |
| CAF-RES-SUB-04 | Group subscriptions under management groups aligned to the same policy and RBAC requirements. |
| CAF-RES-SUB-05 | Establish separate dedicated platform subscriptions for management, security, connectivity, and identity. |
| CAF-RES-SUB-06 | Build a subscription-vending process to automate creation via self-service request workflow. |
| CAF-RES-SUB-07 | Avoid a rigid subscription model; use flexible grouping criteria as org structure evolves. |
| CAF-RES-SUB-08 | Always enable Azure Service Health on every subscription. |
| CAF-RES-SUB-09 | Create additional per-region subscriptions only where region-specific governance/scale requirements exist. |
| CAF-RES-SUB-10 | For geo-DR without a scaling concern, use the same subscription for primary/secondary regions; use separate subscriptions for active-active. |
| CAF-RES-SUB-11 | Ensure a resource group's region matches the region of its contained resources. |
| CAF-RES-SUB-12 | A single resource group shouldn't contain resources from different regions. |
| CAF-RES-SUB-13 | Use subscriptions as scale units and scale out resources/subscriptions as required. |
| CAF-RES-SUB-14 | Use capacity reservations for high-demand resources in a specific region. |
| CAF-RES-SUB-15 | Establish a dashboard with custom views to monitor capacity levels, with alerts near critical thresholds. |
| CAF-RES-SUB-16 | Raise support requests for quota increases before workloads exceed default limits. |
| CAF-RES-SUB-17 | Ensure required services/features are available in chosen deployment regions. |
| CAF-RES-SUB-18 | Use Quota Groups to manage and share quotas across multiple subscriptions. |
| CAF-RES-SUB-19 | Automate quota requests via the Azure Quota REST API. |
| CAF-RES-SUB-20 | Configure quota alerts to notify subscription owners approaching their limits. |
| CAF-RES-SUB-21 | Configure tenant transfer settings to `Permit no one` in both directions to prevent subscription transfer. |
| CAF-RES-SUB-22 | Configure a limited exempted-users list (platform ops team, break-glass accounts) for the tenant-transfer policy. |

## Network topology and connectivity — `CAF-NET-*` (135 items, 11 of ~14 pages)

Base URL: `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/network-topology-and-connectivity`
(hub) and its child pages under `ready/azure-best-practices/`.

**Status:** this section was a documented gap in the first pass of this file (2026-08-01, morning) and
was closed in a follow-up pass the same day. The hub page and 10 child pages were fetched via
`microsoft_docs_fetch`/`microsoft_docs_search` (Microsoft Learn MCP server) and every recommendation
bullet, or — on the two pages Microsoft has already rewritten away from the
Considerations/Recommendations structure — every actionable numbered step, transcribed and numbered
below. **Nothing in this section was invented;** every `CAF-NET-*` row traces to a real fetched page.

**Format note — two pages are numbered-task format, not bullets:** `virtual-wan-network-topology`
and `connectivity-to-other-providers` carry no `## Design recommendations` heading at all; their
content is organized as numbered how-to steps under topic `##`/`###` headings. Per this file's
established convention (see `CAF-AUT-TOP-*` and `CAF-AUT-ENV-*` above), each numbered step is recorded
as one item. This is also why the design area's total (135) exceeds the audit's **123** formal-bullet
figure — the audit's narrower count likely excluded these two pages' content, consistent with its own
"~155 with numbered-task format" upper estimate.

**Residual gap — 3-4 child pages not fetched this session:** `private-link-and-dns-integration-at-scale`
(referenced from multiple scenario pages as "enterprise-scale proven practices" for DNS/Private Link
but not confirmed as part of this design area's own page inventory), `connectivity-to-other-providers-oci`
(the Oracle Cloud Infrastructure-specific addendum to `connectivity-to-other-providers`), and the
`ready/enterprise-scale/network-topology-and-connectivity` legacy variant of the hub page (may be a
redirect to the design-area hub rather than distinct content — not verified this session). None of
these were fetched or transcribed; no `CAF-NET-*` IDs are assigned against them. A further follow-up
pass should fetch and either enumerate or explicitly rule out each one.

### Hub page — `network-topology-and-connectivity` (0 items, no recommendations)

The design-area hub page carries scope/context and the Connectivity/Corp/Online management-group
rationale only — no `## Design recommendations` section of its own. No items are assigned against it.

### Traditional and hub-and-spoke topology — `CAF-NET-HYB-*` (21 items)

Source: [Traditional Azure networking topology](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/traditional-azure-networking-topology)

This page's `## Design recommendations` section repeats several bullets verbatim (an artefact of
Microsoft's own page, not a transcription error); each repeated bullet is counted once below.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-HYB-01 | Consider traditional hub-and-spoke for: single-region deployments; multi-region without a transitive-connectivity requirement; multi-region already using global VNet peering; no ExpressRoute/VPN transitivity need; ExpressRoute as the primary hybrid method with under 100 VPN connections per gateway; or a dependency on centralized NVAs and granular routing. | unanswerable from collected data |
| CAF-NET-HYB-02 | For regional deployments, use a regional hub per spoke region connected via virtual network peering — for dual-peering-location cross-premises connectivity, VPN branch connectivity, spoke-to-spoke via NVA/UDR, or internet-outbound protection via Firewall/NVA. | unanswerable from collected data |
| CAF-NET-HYB-03 | Use multiple virtual networks connected via multiple ExpressRoute circuits at different peering locations for high isolation, dedicated per-business-unit bandwidth, or when a single gateway's connection limit is reached. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-HYB-04 | For dual-homed peering within the same city, consider ExpressRoute Metro. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-HYB-05 | Deploy Azure Firewall or partner NVAs in the central-hub virtual network for east/west and north/south traffic protection and filtering. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-HYB-06 | Deploy a minimal set of shared services (ExpressRoute/VPN gateways, Firewall/NVAs, and, if needed, AD domain controllers and DNS servers) in the central-hub virtual network. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-HYB-07 | Deploy a single DDoS Protection standard plan in the connectivity subscription and use it for all landing-zone and platform virtual networks. | `manifests/collectors/Security/DdosProtectionPlans.psd1` |
| CAF-NET-HYB-08 | Use existing MPLS/SD-WAN networks to connect branch locations to headquarters; without Route Server there's no transit support between ExpressRoute and VPN gateways. | unanswerable from collected data |
| CAF-NET-HYB-09 | When deploying partner networking technologies or NVAs, follow the vendor's guidance for supported deployment, HA/performance, and non-conflicting Azure networking configuration. | unanswerable from collected data |
| CAF-NET-HYB-10 | Don't deploy Layer 7 inbound NVAs (e.g. Application Gateway) as a shared service in the central hub; deploy them with the application in its own landing zone. | `manifests/collectors/Networking/ApplicationGateways.psd1` |
| CAF-NET-HYB-11 | Use Azure Route Server if transitivity is needed between ExpressRoute and VPN gateways in a hub-and-spoke scenario. | unanswerable from collected data (no Route Server collector) |
| CAF-NET-HYB-12 | For multi-region hub-and-spoke connecting only a few landing zones across regions, use global virtual network peering to connect them directly. | `manifests/collectors/Networking/vNETPeering.psd1` |
| CAF-NET-HYB-13 | For multi-region hub-and-spoke connecting most landing zones across regions, or where direct peering can't bypass hub NVAs, use hub NVAs to connect regional hub virtual networks and route cross-region traffic. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-HYB-14 | To connect two Azure regions, use global virtual network peering between the hub virtual networks in each region. | `manifests/collectors/Networking/vNETPeering.psd1` |
| CAF-NET-HYB-15 | Use a managed global transit network architecture based on Azure Virtual WAN when hub-and-spoke is required across more than two regions, global transit connectivity is required, and the organization wants to minimize network-management overhead. | `manifests/collectors/Networking/VirtualWAN.psd1` |
| CAF-NET-HYB-16 | When connecting more than two regions without Virtual WAN, connect each region's hub virtual network to the same ExpressRoute circuits rather than a full mesh of global peerings. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-HYB-17 | When ExpressRoute circuits carry cross-region traffic and hub firewall NVAs must inspect cross-spoke traffic, either add specific spoke UDR entries for the local hub firewall or disable BGP route propagation on the spoke route tables. | `manifests/collectors/Networking/RouteTables.psd1` |
| CAF-NET-HYB-18 | Deploy each region's hub network resources into its own resource group. | unanswerable from collected data |
| CAF-NET-HYB-19 | Use Azure Virtual Network Manager to manage connectivity and security configuration of virtual networks globally across subscriptions. | unanswerable from collected data (no Virtual Network Manager collector) |
| CAF-NET-HYB-20 | Use Network Watcher network insights to monitor the end-to-end state of Azure networks. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-HYB-21 | When connecting spoke virtual networks to the central hub, stay within the virtual-network-peering-connection limit and the ExpressRoute private-peering advertised-prefix limit. | `manifests/collectors/Networking/vNETPeering.psd1` |

### Virtual WAN topology — `CAF-NET-VWN-*` (14 items, numbered-task format — no recommendations heading)

Source: [Virtual WAN network topology in an Azure landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/virtual-wan-network-topology).
This is one of the audit's two named rewritten pages: content sits under topic headings
("Plan your Virtual WAN deployment," "Connect on-premises locations and branches," "Implement security
controls," and others), most already numbered by Microsoft; unnumbered topic paragraphs are recorded
as one item each.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-VWN-01 | Use one or more Virtual WAN hubs per Azure region; deploy multiple hubs in the same region to scale beyond single-hub limits. | `manifests/collectors/Networking/VirtualWAN.psd1` |
| CAF-NET-VWN-02 | Place all Virtual WAN resources, Azure Firewall, and the DDoS standard protection plan in the connectivity subscription. | unanswerable from collected data |
| CAF-NET-VWN-03 | Create a single Azure DDoS Network Protection plan in the connectivity subscription and use it for all application-landing-zone and platform virtual networks. | `manifests/collectors/Security/DdosProtectionPlans.psd1` |
| CAF-NET-VWN-04 | Deploy all Virtual WAN resources into a single resource group within the connectivity subscription (a portal requirement). | unanswerable from collected data |
| CAF-NET-VWN-05 | Deploy required shared services (e.g. DNS servers) in a dedicated spoke virtual network; customer-deployed shared resources can't be deployed inside the Virtual WAN hub itself. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-VWN-06 | Plan deployments within Azure Virtual WAN subscription limits; deploy an additional virtual hub in the same region/WAN/resource group if more connections are needed than a single hub allows. | `manifests/collectors/Networking/VirtualWAN.psd1` |
| CAF-NET-VWN-07 | Connect ExpressRoute circuits to the Virtual WAN hub using a Local, Standard, or Premium SKU; use ExpressRoute Metro for same-city deployments. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-VWN-08 | Connect branches and remote locations to the nearest Virtual WAN hub via Site-to-Site VPN or an SD-WAN partner solution. | `manifests/collectors/Networking/Connections.psd1` |
| CAF-NET-VWN-09 | Connect individual users to the Virtual WAN hub via Point-to-Site VPN. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-VWN-10 | Configure virtual hub routing and custom route tables to segment traffic between VNets and branches and enforce security/compliance requirements; keep Azure traffic on the Microsoft backbone and configure outbound filtering through Azure Firewall for internet-bound traffic. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-VWN-11 | Consider deploying NVA firewalls into a Virtual WAN hub for combined SD-WAN and next-generation-firewall capability, following partner vendor guidance to avoid conflicting Azure networking configuration. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-VWN-12 | Consider secured virtual hubs (Azure Firewall Manager-configured security/routing policy) and use routing intent and routing policies for hub-to-hub traffic inspection; note secured virtual hubs don't support DDoS standard protection plans. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-VWN-13 | Configure Azure Monitor insights for Virtual WAN and alerts on critical thresholds to detect and respond to issues proactively. | unanswerable from collected data |
| CAF-NET-VWN-14 | When migrating from a non-Virtual-WAN hub-and-spoke topology, follow the dedicated Virtual WAN migration guidance. | unanswerable from collected data |

### Connectivity to Azure — `CAF-NET-CTA-*` (12 items)

Source: [Connectivity to Azure](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/connectivity-to-azure)

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-CTA-01 | Use ExpressRoute as the primary connectivity channel; use VPN as backup connectivity for resiliency. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-CTA-02 | Use dual ExpressRoute circuits from different peering locations to remove single points of failure. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-CTA-03 | When using multiple ExpressRoute circuits, optimize routing via BGP local preference and AS PATH prepending. | unanswerable from collected data |
| CAF-NET-CTA-04 | Use the right SKU for ExpressRoute/VPN gateways based on bandwidth and performance requirements. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-CTA-05 | Deploy a zone-redundant ExpressRoute gateway in supported regions. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-CTA-06 | Use ExpressRoute Direct for bandwidth needs above 10 Gbps or dedicated 10/100-Gbps ports. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-CTA-07 | Enable FastPath when low latency is required or on-premises-to-Azure throughput must exceed 10 Gbps. | unanswerable from collected data |
| CAF-NET-CTA-08 | Use VPN gateways to connect branches or remote locations to Azure; deploy zone-redundant gateways for higher resilience. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-CTA-09 | Use ExpressRoute Global Reach to connect large offices, regional headquarters, or datacenters already connected to Azure via ExpressRoute. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-CTA-10 | Use separate ExpressRoute circuits when traffic isolation or dedicated bandwidth is required (e.g. production vs. nonproduction). | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-CTA-11 | Use ExpressRoute network insights and Connection Monitor for ExpressRoute to monitor components and detect connectivity issues. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-CTA-12 | Don't use ExpressRoute circuits from a single peering location — it creates a single point of failure. | `manifests/collectors/Networking/ExpressRoute.psd1` |

### Connectivity to other cloud providers — `CAF-NET-OCP-*` (18 items, numbered-task format — no recommendations heading)

Source: [Connectivity to other cloud providers](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/connectivity-to-other-providers).
This is the audit's second named rewritten page: five topic sections ("Evaluate connectivity options,"
"Plan network architecture requirements," "Optimize performance with FastPath," "Implement
connectivity solutions," "Deploy optimized network configurations"), each already numbered by
Microsoft.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-OCP-01 | Choose ExpressRoute with customer-managed routing for maximum control and performance when advanced networking expertise is available. | unanswerable from collected data |
| CAF-NET-OCP-02 | Choose ExpressRoute with a cloud-exchange provider (e.g. Equinix, Megaport, PacketFabric) to reduce operational overhead while keeping private-connectivity performance. | unanswerable from collected data |
| CAF-NET-OCP-03 | Use Site-to-Site VPN for cost-effective, fast-to-deploy internet-based connectivity when private circuits aren't feasible. | unanswerable from collected data |
| CAF-NET-OCP-04 | Verify non-overlapping IP address spaces before connecting to another cloud provider; use CIDR planning and a centralized IPAM system. | unanswerable from collected data |
| CAF-NET-OCP-05 | Evaluate performance requirements against connection options — ExpressRoute for predictable bandwidth/latency, Site-to-Site VPN for lower-throughput/cost-sensitive scenarios. | unanswerable from collected data |
| CAF-NET-OCP-06 | Assess deployment-timeline constraints; use Site-to-Site VPN when a fast deployment is needed while longer-term private connectivity is provisioned. | unanswerable from collected data |
| CAF-NET-OCP-07 | Weigh routing complexity and operational overhead when choosing customer-managed ExpressRoute routing versus a cloud exchange provider. | unanswerable from collected data |
| CAF-NET-OCP-08 | Plan DNS resolution between cloud environments with dedicated forwarding rules (e.g. DNS Private Resolver) and account for the associated operational cost. | `manifests/collectors/Networking/PrivateDNS.psd1` |
| CAF-NET-OCP-09 | Enable FastPath to bypass ExpressRoute gateway processing for optimal cross-cloud network performance. | unanswerable from collected data |
| CAF-NET-OCP-10 | Implement FastPath on ExpressRoute Direct or provider circuits based on performance requirements and circuit specifications. | unanswerable from collected data |
| CAF-NET-OCP-11 | Deploy a virtual network gateway with the Ultra Performance or ErGw3AZ SKU to support FastPath route exchange. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-OCP-12 | Review FastPath limitations (e.g. UDRs on the gateway subnet, specific NSG settings) before enabling it. | unanswerable from collected data |
| CAF-NET-OCP-13 | Choose private connectivity (ExpressRoute) over internet-based connections for production and mission-critical workloads. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-OCP-14 | Create ExpressRoute circuits in a dedicated connectivity subscription for centralized resource organization, billing, and access control. | unanswerable from collected data |
| CAF-NET-OCP-15 | Connect ExpressRoute circuits to the hub virtual network (hub-and-spoke) or the virtual hub (Virtual WAN) based on the chosen topology. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-OCP-16 | Consider ExpressRoute Metro for same-city deployments to reduce latency and cost. | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-OCP-17 | Deploy a single virtual network with an ExpressRoute gateway and FastPath enabled for latency-sensitive cross-cloud applications. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-OCP-18 | Use Site-to-Site VPN when ExpressRoute isn't available, cost-effective, or technically required. | `manifests/collectors/Networking/Connections.psd1` |

### Plan for IP addressing — `CAF-NET-IP-*` (23 items)

Source: [Plan for IP addressing](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-ip-addressing).
This page carries three separate `## Design recommendations` blocks — base addressing, IPv6, and IP
address management (IPAM) — each numbered as its own sub-range below.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-IP-01 | Plan for non-overlapping IP address spaces across Azure regions and on-premises locations in advance. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-02 | Use RFC 1918 private-internet address allocations. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-03 | Don't use reserved/special-purpose ranges: multicast `224.0.0.0/4`, broadcast `255.255.255.255/32`, loopback `127.0.0.0/8`, link-local `169.254.0.0/16`, internal DNS `168.63.129.16/32`. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-04 | Consider IPv6 for environments with limited private IPv4 address availability. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-05 | Don't create oversized virtual networks like `/16`; size subnets appropriately (`/29` smallest, `/2` largest IPv4 CIDR; IPv6 subnets must be exactly `/64`). | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-06 | Don't create virtual networks without planning the required address space in advance. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-07 | Don't use public IP addresses that don't belong to your organization for virtual networks. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-08 | Account for services with reserved/required IP ranges (e.g. AKS with Azure CNI networking) when planning address space. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-09 | Use nonroutable landing-zone spoke virtual networks and Azure Private Link service to prevent IPv4 exhaustion. | `manifests/collectors/Networking/PrivateEndpoint.psd1` |
| CAF-NET-IP-10 | Deploy IPv4/IPv6 translation NVAs in Virtual Machine Scale Sets Flexible orchestration behind an Azure Standard Load Balancer for IPv6-to-IPv4-only-backend translation. | `manifests/collectors/Networking/LoadBalancer.psd1` |
| CAF-NET-IP-11 | Deploy Azure Front Door to proxy IPv6 client traffic to an IPv4-only back end for web workloads (combine with NVAs in complex multi-region environments). | `manifests/collectors/Networking/Frontdoor.psd1` |
| CAF-NET-IP-12 | Use exactly `/64`-sized IPv6 CIDR blocks for future on-premises routing compatibility. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-13 | Enable IPv6 dual-stack support on existing IPv4-only virtual networks rather than trying to disable IPv4 (IPv4 can't be disabled). | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-IP-14 | Update route tables to route IPv6 traffic (e.g. to a VPN Gateway or ExpressRoute gateway for public IPv6 traffic). | `manifests/collectors/Networking/RouteTables.psd1` |
| CAF-NET-IP-15 | Update NSG rules to include IPv6 address rules alongside IPv4. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |
| CAF-NET-IP-16 | If an instance type doesn't support IPv6, use dual stack or an NVA translation approach. | unanswerable from collected data (VM-SKU IPv6 support is a Compute-category fact, not a Networking one) |
| CAF-NET-IP-17 | Evaluate IPAM tools against minimum required features, total cost of ownership, audit/logging/RBAC, Microsoft Entra ID authentication/authorization, API accessibility, and integration with other network-management tooling. | unanswerable from collected data |
| CAF-NET-IP-18 | Consider an open-source IPAM tool (e.g. Azure IPAM) for centralized, API-driven IP address discovery and management within the Azure tenant. | unanswerable from collected data |
| CAF-NET-IP-19 | Align IPAM tool ownership with the organization's operating model to streamline self-service IP address space requests. | unanswerable from collected data |
| CAF-NET-IP-20 | Use T-shirt sizing (e.g. Small `/24`, Medium `/22`, Large `/20`) to standardize non-overlapping IP address space requests per application landing zone. | unanswerable from collected data |
| CAF-NET-IP-21 | Ensure the IPAM tool exposes an API for reserving non-overlapping IP address spaces, to support Infrastructure as Code and subscription-vending integration. | unanswerable from collected data |
| CAF-NET-IP-22 | Structure IP address space inventory systematically by Azure region and workload archetype. | unanswerable from collected data |
| CAF-NET-IP-23 | Decommission and reclaim IP address spaces from retired workloads for reuse. | unanswerable from collected data |

### DNS for on-premises and Azure resources — `CAF-NET-DNS-*` (8 items)

Source: [DNS for on-premises and Azure resources](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/dns-for-on-premises-and-azure-resources)

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-DNS-01 | For Azure-only name resolution, use an Azure Private DNS zone with a delegated zone (e.g. `azure.contoso.com`) and auto-registration enabled. | `manifests/collectors/Networking/PrivateDNS.psd1` |
| CAF-NET-DNS-02 | For cross-premises name resolution, use DNS Private Resolver together with Azure Private DNS zones rather than VM-based DNS solutions. | `manifests/collectors/Networking/PrivateDNS.psd1` |
| CAF-NET-DNS-03 | If existing on-premises DNS infrastructure (e.g. AD-integrated DNS) must be used, deploy the DNS server role on at least two VMs and point virtual network DNS settings to them. | unanswerable from collected data |
| CAF-NET-DNS-04 | For environments with Azure Firewall, consider using it as a DNS proxy. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-DNS-05 | Use DNS Private Resolver forwarding rulesets (linked to the Private DNS zone and virtual networks) to route Azure-to-on-premises and on-premises-to-Azure DNS queries via conditional forwarders. | `manifests/collectors/Networking/PrivateDNS.psd1` |
| CAF-NET-DNS-06 | Create two dedicated `/28`-minimum subnets (inbound and outbound) for DNS Private Resolver in the hub virtual network of the connectivity subscription, respecting the 5-endpoint maximum per direction and keeping public-FQDN resolution permitted if deployed alongside an ExpressRoute gateway. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-DNS-07 | Let workloads that deploy and require their own DNS (e.g. Red Hat OpenShift) use their preferred DNS solution. | unanswerable from collected data |
| CAF-NET-DNS-08 | Create the required Azure Private DNS zones (e.g. `privatelink.database.windows.net`, `privatelink.blob.core.windows.net`) for private-endpoint-based PaaS access, within a global connectivity subscription. | `manifests/collectors/Networking/PrivateDNS.psd1` |

### Plan for inbound and outbound internet connectivity — `CAF-NET-INT-*` (19 items)

Source: [Plan for inbound and outbound internet connectivity](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-inbound-and-outbound-internet-connectivity).
This is one of the two pages the `CAF-SEC` section's design-considerations table cross-links as
context; its recommendations belong to Network, not Security — see the note at the end of `CAF-SEC`
above.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-INT-01 | Use Azure NAT Gateway for direct outbound internet connectivity — for dynamic/large workloads, predictable outbound public IPs, SNAT-exhaustion mitigation, and to keep only outbound/return traffic reachable. | `manifests/collectors/Networking/NATGateway.psd1` |
| CAF-NET-INT-02 | Use Azure Firewall to govern outbound internet traffic, non-HTTP/S inbound connections, and east-west traffic filtering where required. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-03 | Deploy Azure Firewall with the Management NIC enabled: pre-create `AzureFirewallManagementSubnet` at `/26` minimum, assign it a public IP, and disable gateway-route propagation on its default system route table. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-04 | Use Azure Firewall Premium for TLS inspection, network intrusion detection/prevention, URL filtering, and web-category filtering. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-05 | Use Firewall Manager (with Virtual WAN or standalone virtual networks) to deploy and manage Azure Firewalls centrally. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-06 | Set up IP Groups in Azure Firewall when using multiple IP addresses/ranges consistently across firewall rules. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-07 | When using a custom user-defined route for outbound connectivity to Azure PaaS services, specify a service tag as the address prefix rather than a static IP range. | `manifests/collectors/Networking/RouteTables.psd1` |
| CAF-NET-INT-08 | Create a global Azure Firewall policy for baseline security posture across all firewall instances, and delegate granular regional policies via RBAC where needed. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-09 | Use Web Application Firewall (WAF) within a landing-zone virtual network to protect inbound HTTP/S traffic. | `manifests/collectors/Security/WafPolicies.psd1` |
| CAF-NET-INT-10 | Use Azure Front Door with WAF policies for global inbound HTTP/S protection across regions. | `manifests/collectors/Networking/Frontdoor.psd1` |
| CAF-NET-INT-11 | Lock down Application Gateway to accept traffic only from Azure Front Door when combining the two for HTTP/S protection. | `manifests/collectors/Networking/ApplicationGateways.psd1` |
| CAF-NET-INT-12 | Deploy partner NVAs for inbound HTTP/S connections within the landing-zone virtual network, alongside the application they protect. | unanswerable from collected data (third-party NVA resources aren't a distinct Scout collector) |
| CAF-NET-INT-13 | Don't use Azure's default internet outbound access for any scenario — it risks SNAT exhaustion, is insecure by default, and its IPs aren't customer-owned or stable. | `manifests/collectors/Networking/NATGateway.psd1` |
| CAF-NET-INT-14 | Use a NAT gateway for online landing zones, or landing zones not connected to the hub virtual network, when Azure Firewall/NVA-grade security isn't required. | `manifests/collectors/Networking/NATGateway.psd1` |
| CAF-NET-INT-15 | Configure supported SaaS security-provider partners within Firewall Manager to protect outbound connections, if desired. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-INT-16 | Deploy partner NVAs for east-west/north-south traffic filtering in a dedicated NVA virtual network (Virtual WAN) or the central hub virtual network (non-Virtual WAN). | unanswerable from collected data |
| CAF-NET-INT-17 | Don't expose VM management ports to the internet — use Azure Policy to block public-IP VM creation and Azure Bastion for jumpbox access. | `manifests/collectors/Networking/BastionHosts.psd1` |
| CAF-NET-INT-18 | Use Azure DDoS Protection plans to protect public endpoints hosted within your virtual networks. | `manifests/collectors/Security/DdosProtectionPlans.psd1` |
| CAF-NET-INT-19 | Don't try to replicate on-premises perimeter-network concepts and architectures directly into Azure. | unanswerable from collected data |

### Plan for landing zone network segmentation — `CAF-NET-SEG-*` (9 items)

Source: [Plan for landing zone network segmentation](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-landing-zone-network-segmentation).
This is the second of the two pages `CAF-SEC`'s design-considerations table cross-links as context;
its recommendations belong to Network, not Security.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-SEG-01 | Delegate subnet creation to the landing-zone owner, with the platform team enforcing (via Azure Policy) that an NSG with baseline deny rules is always associated with subnets governed by deny-only policies. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |
| CAF-NET-SEG-02 | Use NSGs to protect cross-subnet traffic and east/west traffic between landing zones. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |
| CAF-NET-SEG-03 | Use application security groups at subnet-level NSGs to protect multitier VMs within a landing zone. | `manifests/collectors/Security/ApplicationSecurityGroups.psd1` |
| CAF-NET-SEG-04 | Use NSGs and ASGs to micro-segment traffic within the landing zone and avoid relying on a central NVA to filter flows. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |
| CAF-NET-SEG-05 | Enable virtual network flow logs (migrating off NSG flow logs) and use traffic analytics on all critical virtual networks/subnets to gain ingress/egress traffic visibility. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-SEG-06 | Plan and migrate existing NSG flow-log configuration to virtual network flow logs before the NSG flow-logs retirement. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-SEG-07 | Use NSGs to selectively allow connectivity between landing zones. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |
| CAF-NET-SEG-08 | For Virtual WAN topologies, route cross-landing-zone traffic via Azure Firewall when filtering and logging are required. | `manifests/collectors/Networking/AzureFirewall.psd1` |
| CAF-NET-SEG-09 | If forced tunneling to on-premises is implemented, add outbound NSG rules that deny direct-to-internet egress if the BGP session advertising the default route drops. | `manifests/collectors/Networking/NetworkSecurityGroup.psd1` |

### Define network encryption requirements — `CAF-NET-ENC-*` (6 items)

Source: [Define network encryption requirements](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/define-network-encryption-requirements)

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-ENC-01 | Encrypt on-premises-to-Azure VPN traffic at the protocol level via IPsec tunnels on VPN gateways. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-ENC-02 | Use Virtual Network encryption to encrypt VM-to-VM traffic within a virtual network or across regionally/globally peered virtual networks. | `manifests/collectors/Networking/VirtualNetwork.psd1` |
| CAF-NET-ENC-03 | When using ExpressRoute Direct, configure MACsec to encrypt traffic at Layer 2 between the organization's routers and the Microsoft Enterprise Edge (MSEE). | `manifests/collectors/Networking/ExpressRoute.psd1` |
| CAF-NET-ENC-04 | For Virtual WAN scenarios where MACsec isn't an option, use a Virtual WAN VPN Gateway to establish IPsec tunnels over ExpressRoute private peering. | `manifests/collectors/Networking/VirtualNetworkGateways.psd1` |
| CAF-NET-ENC-05 | For non-Virtual-WAN scenarios where MACsec isn't an option, use partner NVAs for IPsec over ExpressRoute private peering, a VPN tunnel over ExpressRoute Microsoft peering, or a Site-to-Site VPN over ExpressRoute private peering. | `manifests/collectors/Networking/Connections.psd1` |
| CAF-NET-ENC-06 | If none of the native Azure encryption options meet requirements, use partner NVAs in Azure to encrypt traffic over ExpressRoute private peering. | unanswerable from collected data |

### Plan for traffic inspection — `CAF-NET-INS-*` (5 items)

Source: [Plan for traffic inspection](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/plan-for-traffic-inspection).
Only the page's `## Design recommendations` section is enumerated below; its SaaS-network-security and
other-platforms sections are informational/considerations content, not imperative recommendations, and
are excluded per this file's counting rule.

| # | Item | Scout collector |
|---|---|---|
| CAF-NET-INS-01 | Use virtual network flow logs (migrating from NSG flow logs) to simplify traffic-monitoring scope to the virtual-network level and gain Virtual Network encryption/Azure Virtual Network Manager security-admin-rule visibility. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-INS-02 | Enable traffic analytics for out-of-the-box dashboard visualization and security analysis of captured traffic. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-INS-03 | Supplement traffic analytics with a Microsoft Marketplace partner solution if additional capability is needed. | unanswerable from collected data |
| CAF-NET-INS-04 | Use Network Watcher packet capture regularly, at varied times, to build a detailed understanding of network traffic patterns. | `manifests/collectors/Networking/NetworkWatchers.psd1` |
| CAF-NET-INS-05 | Don't build a custom traffic-mirroring solution for large deployments — custom solutions are complex and hard to support. | unanswerable from collected data |

`CAF-NET-*` totals: **135 items** across 10 content-bearing pages (95 map to a real Scout collector;
40 are unanswerable from collected data — mostly decision criteria, external tooling, or organizational
process that has no Azure Resource Graph-visible configuration state).

## Security — `CAF-SEC-*` (42 items, 3 pages)

Source pages: [Security](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/security)
(hub, self-contained recommendations), [Encryption and key management](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/encryption-and-keys),
[Incorporate Zero Trust practices in your landing zone](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/security-zero-trust).

This is one item lower than the prior audit's verified 45 — an artefact of this session's
parent-bullet counting on the zero-trust page rather than a missed item; both counts are within
normal counting variance for this content.

### Security hub — operations and access control — `CAF-SEC-OPS-*` / `CAF-SEC-AC-*` (14 items)

| # | Item |
|---|---|
| CAF-SEC-OPS-01 | Use Microsoft Entra ID reporting to generate access-control audit reports. |
| CAF-SEC-OPS-02 | Export Azure activity logs to Azure Monitor Logs; export to Storage for retention beyond two years. |
| CAF-SEC-OPS-03 | Enable Defender for Cloud standard for all subscriptions; enforce with Azure Policy. |
| CAF-SEC-OPS-04 | Monitor base OS patching drift via Azure Monitor Logs and Defender for Cloud. |
| CAF-SEC-OPS-05 | Use Azure Policy to auto-deploy software configuration through VM extensions and enforce a compliant baseline. |
| CAF-SEC-OPS-06 | Monitor VM security configuration drift via Azure Policy. |
| CAF-SEC-OPS-07 | Connect default resource configurations to a centralized Azure Monitor Log Analytics workspace. |
| CAF-SEC-OPS-08 | Use an Azure Event Grid-based solution for log-oriented, real-time alerts. |
| CAF-SEC-OPS-09 | Use Azure Attestation for VM boot-chain integrity, confidential-disk-encryption key release, and workload trusted execution environments. |
| CAF-SEC-AC-01 | Jointly examine each required service's BYOK support and region-pair/DR-region choices before committing. |
| CAF-SEC-AC-02 | Develop a security allowlist plan for configuration, monitoring, and alerting, then integrate with existing systems. |
| CAF-SEC-AC-03 | Determine the incident response plan for each Azure service before it moves to production. |
| CAF-SEC-AC-04 | Align security requirements with Azure platform roadmaps to stay current with new security controls. |
| CAF-SEC-AC-05 | Implement a zero-trust approach for access to the Azure platform where appropriate. |

### Encryption and key management — `CAF-SEC-ENC-*` (12 items)

| # | Item |
|---|---|
| CAF-SEC-ENC-01 | Use a federated Azure Key Vault model to avoid transaction scale limits. |
| CAF-SEC-ENC-02 | Use Azure RBAC, not access policies, as the authorization system for the Key Vault data plane. |
| CAF-SEC-ENC-03 | Provision Key Vault with soft delete and purge protection enabled. |
| CAF-SEC-ENC-04 | Limit permanent-delete authorization on keys/secrets/certificates to specialized custom Entra roles. |
| CAF-SEC-ENC-05 | Automate certificate management and renewal with public certificate authorities. |
| CAF-SEC-ENC-06 | Establish an automated process for key and certificate rotation. |
| CAF-SEC-ENC-07 | Enable firewall and virtual-network service endpoints on the vault to control access. |
| CAF-SEC-ENC-08 | Audit key, certificate, and secret usage via the platform-central Log Analytics workspace. |
| CAF-SEC-ENC-09 | Delegate Key Vault instantiation and privileged access; enforce compliant configuration via Azure Policy. |
| CAF-SEC-ENC-10 | Default to Microsoft-managed keys; use customer-managed keys only when required. |
| CAF-SEC-ENC-11 | Don't centralize application keys/secrets in one Key Vault instance unless using a Managed HSM. |
| CAF-SEC-ENC-12 | Don't share Key Vault instances between applications. |

### Zero Trust practices in the landing zone — `CAF-SEC-ZT-*` (16 items)

| # | Item |
|---|---|
| CAF-SEC-ZT-01 | Develop a plan for managing identities in Microsoft Entra ID beyond Azure resources (federation, Conditional Access, risk-based authorization). |
| CAF-SEC-ZT-02 | Deploy the landing zone with separate subscriptions for identity resources such as domain controllers. |
| CAF-SEC-ZT-03 | Use Microsoft Entra managed identities where possible. |
| CAF-SEC-ZT-04 | Develop a Zero Trust plan for endpoints in addition to the landing-zone deployment plan. |
| CAF-SEC-ZT-05 | Use Microsoft Defender for Cloud Apps to manage and standardize policies for application access. |
| CAF-SEC-ZT-06 | Develop a plan to onboard organization-hosted applications to the same access-control practices as third-party apps. |
| CAF-SEC-ZT-07 | Use Microsoft Purview for data governance, protection, and risk management. |
| CAF-SEC-ZT-08 | Use the standard Azure landing zone policies to block noncompliant deployments and resources. |
| CAF-SEC-ZT-09 | Configure Privileged Identity Management for just-in-time access to highly privileged roles. |
| CAF-SEC-ZT-10 | Configure just-in-time VM access in Defender for Cloud for the landing zone. |
| CAF-SEC-ZT-11 | Create a plan to monitor and manage individual workloads deployed in Azure. |
| CAF-SEC-ZT-12 | Deploy firewalls capable of HTTPS traffic inspection and isolate identity/management network resources from the central hub. |
| CAF-SEC-ZT-13 | Plan micro-segmentation of individual workloads in their spoke virtual networks, with fine-grained NSGs per workload. |
| CAF-SEC-ZT-14 | Use the Zero Trust-specific deployment guides (portal accelerator, Bicep, Terraform) to deploy the landing zone with Zero Trust network principles. |
| CAF-SEC-ZT-15 | Deploy Microsoft Sentinel as part of the Azure landing zone. |
| CAF-SEC-ZT-16 | Create a plan for threat-hunting exercises and continual security improvement. |

## Management — `CAF-MGT-*` (15 items, 3 of 5 pages)

Source pages: [Inventory and visibility considerations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/management-platform),
[Operational compliance considerations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/management-operational-compliance),
[Business continuity and disaster recovery](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/management-business-continuity-disaster-recovery).

This count matches the audit's verified figure exactly. Per the audit, two of the design area's five
sub-pages carry no recommendations section at all; this session did not re-fetch those two, since a
page with zero recommendations contributes zero items either way.

### Inventory and visibility — `CAF-MGT-INV-*` (8 items)

| # | Item |
|---|---|
| CAF-MGT-INV-01 | Use a single centralized Log Analytics workspace, except where RBAC, data-sovereignty, or retention policy mandates separate workspaces. |
| CAF-MGT-INV-02 | Export logs to Azure Storage with immutable, write-once-read-many policy if retention exceeds seven years. |
| CAF-MGT-INV-03 | Use Azure Policy for access control and compliance reporting. |
| CAF-MGT-INV-04 | Use Traffic Analytics to gather IP traffic insights within virtual networks. |
| CAF-MGT-INV-05 | Use resource locks to prevent accidental deletion of critical shared services. |
| CAF-MGT-INV-06 | Use deny-effect policies to supplement Azure role assignments as deployment guardrails. |
| CAF-MGT-INV-07 | Include service- and resource-health events as part of overall platform monitoring. |
| CAF-MGT-INV-08 | Don't send raw log entries to on-premises monitoring systems; send critical alerts only if SIEM integration is required. |

### Operational compliance — `CAF-MGT-OPC-*` (2 items)

| # | Item |
|---|---|
| CAF-MGT-OPC-01 | Use Azure Update Manager as the long-term patching mechanism for Windows and Linux VMs, enforced by Azure Policy. |
| CAF-MGT-OPC-02 | Use Azure Policy with Azure Automanage Machine Configuration to monitor in-guest VM configuration drift. |

### Business continuity and disaster recovery — `CAF-MGT-BCDR-*` (5 items)

| # | Item |
|---|---|
| CAF-MGT-BCDR-01 | Use Azure Site Recovery for Azure-to-Azure VM disaster recovery. |
| CAF-MGT-BCDR-02 | Use native PaaS disaster-recovery capabilities rather than third-party equivalents. |
| CAF-MGT-BCDR-03 | Use Azure-native backup capabilities (Azure Backup, PaaS-native backup) audited/enforced via Azure Policy. |
| CAF-MGT-BCDR-04 | Use multiple regions and peering locations for ExpressRoute connectivity resiliency. |
| CAF-MGT-BCDR-05 | Avoid overlapping IP address ranges between production and disaster-recovery networks. |

## Governance — `CAF-GOV-*` (10 items, 1 self-contained page)

Source: [Design area: Azure governance](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/governance)

This is the one design area whose landing page carries its own full recommendation set — no child
pages. This count matches the audit's verified figure exactly.

### Deployment acceleration — `CAF-GOV-DEP-*` (8 items)

| # | Item |
|---|---|
| CAF-GOV-DEP-01 | Identify required Azure tags and enforce them with an append policy. |
| CAF-GOV-DEP-02 | Map regulatory and compliance requirements to Azure Policy definitions and role assignments. |
| CAF-GOV-DEP-03 | Establish Azure Policy definitions at the top-level root management group so they can be assigned at inherited scopes. |
| CAF-GOV-DEP-04 | Manage policy assignments at the highest appropriate level, with exclusions at lower levels only if necessary. |
| CAF-GOV-DEP-05 | Use Azure Policy to control resource-provider registrations at subscription or management-group level. |
| CAF-GOV-DEP-06 | Use built-in policies to minimize operational overhead. |
| CAF-GOV-DEP-07 | Assign the built-in Resource Policy Contributor role at a specific scope for application-level governance. |
| CAF-GOV-DEP-08 | Limit Azure Policy assignments at the root management-group scope to avoid managing exclusions at inherited scopes. |

### Cost management — `CAF-GOV-CST-*` (2 items)

| # | Item |
|---|---|
| CAF-GOV-CST-01 | Use Cost Management to implement financial oversight on resources in the environment. |
| CAF-GOV-CST-02 | Use tags (cost center, project name) to enable granular expense analysis. |

## Platform automation and DevOps — `CAF-AUT-*` (52 items, 8 of ~10 pages)

Source pages (all under `https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/`
unless noted):
[`automation`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/automation),
[`devops-teams-topologies`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/devops-teams-topologies),
[`development-strategy-development-lifecycle`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/development-strategy-development-lifecycle),
[`environments`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/environments),
[`security-considerations-overview`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/security-considerations-overview),
[`security-considerations-tools`](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/security-considerations-tools).
Two child pages carry no actionable recommendation content and are excluded: `devops-principles-and-practices`
(a definitions/metrics/toolchain-selection guide, no imperative list) and
`development-strategy-test-driven-development` (a process methodology walkthrough, no imperative list).

`devops-teams-topologies` is one of the three pages the audit's currency warning names explicitly —
it carries no `## Design recommendations` heading, only three numbered how-to-structure-your-team
sequences. Its items below are numbered-task format, not bullets, flagged as such per item.

### Platform automation — `CAF-AUT-PA-*` (12 items)

Source: [Automation](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/automation)

| # | Item |
|---|---|
| CAF-AUT-PA-01 | Follow an Everything-as-Code approach for full transparency and configuration control. |
| CAF-AUT-PA-02 | Use version control for all repositories: infrastructure, policy, configuration, deployment, and documentation as code. |
| CAF-AUT-PA-03 | Implement the 4-eyes principle (peer programming / peer review) so no code change is deployed unreviewed. |
| CAF-AUT-PA-04 | Adopt a branching strategy with branch policies requiring pull requests for protected branches. |
| CAF-AUT-PA-05 | Use CI/CD to automate code testing and deployment across environments. |
| CAF-AUT-PA-06 | Automate everything — platform provisioning, configuration, management, and landing-zone subscription provisioning. |
| CAF-AUT-PA-07 | Use the accelerator (portal, Bicep, or Terraform) matching the team's current IaC maturity. |
| CAF-AUT-PA-08 | Plan a layered deployment approach for capabilities not covered by the chosen accelerator. |
| CAF-AUT-PA-09 | Establish a process for code-based emergency fixes, registering every quick fix in the backlog for rework. |
| CAF-AUT-PA-10 | Use Infrastructure as Code to deploy and manage Azure Policies (Policy-as-Code). |
| CAF-AUT-PA-11 | Implement a policy exemption request process for workload teams. |
| CAF-AUT-PA-12 | Use policy-driven governance with `deny` effects to block noncompliant deployments rather than `modify` effects that mask code/deployed-state drift. |

### DevOps team topologies — `CAF-AUT-TOP-*` (9 items, numbered-task format — no recommendations heading)

Source: [DevOps team topologies](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/devops-teams-topologies)

| # | Item |
|---|---|
| CAF-AUT-TOP-01 | Create a cross-functional platform team spanning IT, security, compliance, and business units. |
| CAF-AUT-TOP-02 | Define clear platform-team responsibilities (governance/compliance, resource provisioning, identity/access, network, operations, key management, observability). |
| CAF-AUT-TOP-03 | Build platforms that reduce cognitive load — self-service capabilities, automated provisioning, clear guardrails. |
| CAF-AUT-TOP-04 | Delegate full application-lifecycle ownership to application workload teams. |
| CAF-AUT-TOP-05 | Enforce governance through policy and Azure RBAC, not centralized manual process gates. |
| CAF-AUT-TOP-06 | Establish clear contracts/boundaries between the platform team and application workload teams. |
| CAF-AUT-TOP-07 | Identify capability gaps across teams and focus enabling-team effort on the highest-impact ones. |
| CAF-AUT-TOP-08 | Provide time-bound support and coaching from enabling teams rather than open-ended dependency. |
| CAF-AUT-TOP-09 | Build reusable templates/libraries and foster InnerSourcing across teams. |

### Development lifecycle — `CAF-AUT-DEV-*` (18 items)

Source: [Development lifecycle](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/development-strategy-development-lifecycle)

| # | Item |
|---|---|
| CAF-AUT-DEV-01 | Use Git as the version control system. |
| CAF-AUT-DEV-02 | Use private repositories when building Azure landing zones. |
| CAF-AUT-DEV-03 | Use public repositories only for nonconfidential material (automation examples, public docs). |
| CAF-AUT-DEV-04 | Adopt an Infrastructure as Code approach for deploying, managing, governing, and supporting cloud resources. |
| CAF-AUT-DEV-05 | Adopt a trunk-based development model with all feature work merged to a single branch. |
| CAF-AUT-DEV-06 | Define and use consistent branch naming conventions. |
| CAF-AUT-DEV-07 | Set repository/branch permissions to control who can read and update code. |
| CAF-AUT-DEV-08 | Set branch policies: require pull requests, minimum reviewers, reset approvals on source-branch change, auto-include reviewers, check comment resolution. |
| CAF-AUT-DEV-09 | Set squash as the merge strategy to condense topic-branch history into a single commit. |
| CAF-AUT-DEV-10 | Use continuous integration to automate builds and testing on every commit. |
| CAF-AUT-DEV-11 | Include unit tests for both IaC and application code in the build process. |
| CAF-AUT-DEV-12 | Prefer Microsoft-hosted build pools over self-hosted pools where possible. |
| CAF-AUT-DEV-13 | Scope service connections (Azure DevOps) or GitHub secrets to only the resources they need to access. |
| CAF-AUT-DEV-14 | Use Key Vault secrets as build/release pipeline variables instead of hard-coded credentials. |
| CAF-AUT-DEV-15 | Use continuous delivery so code is always ready to deploy to production-like environments. |
| CAF-AUT-DEV-16 | Use environments as part of the deployment strategy for history, traceability, health diagnostics, and security. |
| CAF-AUT-DEV-17 | Include IaC predeployment checks (what-if / plan) to preview create/modify/delete before applying. |
| CAF-AUT-DEV-18 | Adopt Git's undo-changes capability as the rollback mechanism for reverting or resetting deployments. |

### Environments — `CAF-AUT-ENV-*` (3 items, non-standard format — "Design considerations" only, no "Design recommendations" heading)

Source: [Environments](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/environments). The
page's own imperative content sits under "Azure Landing Zones," phrased as things you "should always" do —
recorded here as recommendations despite the absent heading, per the instruction to record what a page
actually contains.

| # | Item |
|---|---|
| CAF-AUT-ENV-01 | Adopt at least one dedicated environment for landing-zone testing. |
| CAF-AUT-ENV-02 | Use separate service principals for test and production purposes. |
| CAF-AUT-ENV-03 | Implement automated checks and approvals to validate and approve changes before deploying to any environment. |

### DevOps security — `CAF-AUT-SEC-*` (10 items — H2-level recommendation themes, not a bulleted list)

Source: [Security considerations for DevOps platforms](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/security-considerations-overview)
(8 items) and [Role-based access control for DevOps tools](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/security-considerations-tools)
(2 items). Neither page carries a "Design recommendations" heading; each `##` section is itself an
imperative instruction, recorded here as one item per heading.

| # | Item |
|---|---|
| CAF-AUT-SEC-01 | Restrict access to DevOps tooling using least-privilege RBAC through Microsoft Entra ID. |
| CAF-AUT-SEC-02 | Restrict repository and branch access/permissions with security groups. |
| CAF-AUT-SEC-03 | Restrict pipeline access and permissions to prevent malicious code deployment and lateral exposure. |
| CAF-AUT-SEC-04 | Select the DevOps agent type (Microsoft-hosted vs. self-hosted) based on the workload's security needs. |
| CAF-AUT-SEC-05 | Use secure, scoped service identities (OpenID Connect / workload identity federation) rather than user accounts or long-lived secrets, one identity per application and environment. |
| CAF-AUT-SEC-06 | Use a secret store (Key Vault) referenced from the pipeline; never hard-code secrets in code or documentation. |
| CAF-AUT-SEC-07 | Use hardened secure admin workstations (SAWs) to deploy changes to high-risk and production environments. |
| CAF-AUT-SEC-08 | Perform security scanning and testing in the pipeline (static analysis, secret scanning, dependency scanning) as part of DevSecOps practice. |
| CAF-AUT-SEC-09 | Maintain tight, least-privilege control of administrator and service-account groups across Microsoft Entra ID and the DevOps tool; don't synchronize privileged AD credentials into Entra ID. |
| CAF-AUT-SEC-10 | Disable permission inheritance where possible and periodically review DevOps audit events for unexpected usage patterns. |

## What this means for the rule file

`caf.billing.yaml` currently scores cost-optimization content, not the 41 items under
`CAF-BIL-*` above — the audit's misnaming finding stands and this enumeration makes it checkable: a
real `caf.billing.yaml` rewrite would cite `CAF-BIL-TEN-04`/`CAF-BIL-TEN-05` (MFA on
subscription/tenant creators) and `CAF-BIL-EA-13`/`CAF-BIL-MCA-07` (periodic billing-RBAC audit) as
concrete, evidenceable targets. `caf.network.yaml` can now cite the `CAF-NET-*` IDs above — 95 of the
135 map to a real collector under `manifests/collectors/Networking/` or an adjacent category
(`Security/DdosProtectionPlans.psd1`, `Security/WafPolicies.psd1`, `Security/ApplicationSecurityGroups.psd1`),
concrete starting targets being `CAF-NET-SEG-01`/`CAF-NET-SEG-09` (baseline-deny NSGs and forced-tunneling
egress rules), `CAF-NET-INT-13`/`CAF-NET-INT-17` (no default outbound access, no internet-exposed
management ports), and `CAF-NET-HYB-07` (a single DDoS standard plan covering every landing-zone
virtual network). The 40 unanswerable rows and the ~3-4 still-unfetched child pages (see the
`CAF-NET-*` section) are the residual gap — cite the Learn URL and quoted recommendation directly for
those, the way `smart-question-set.md` does for SMART's undocumented question text.
