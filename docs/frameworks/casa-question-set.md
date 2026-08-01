# CASA — enumerated source for the Cloud Adoption Security Assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

**Framework version:** Not versioned by Microsoft — the CASA assessment and the CAF Secure checklist
it is built from carry no release number. The extraction date above (2026-08-01) is the version, per
`docs/frameworks/README.md`; re-date this line when this file is next re-verified.

This is the AB#6812 enumeration for target #13 in the audit's fourteen-assessment programme
(`pmo/audits/AZURE-SCOUT-AUDIT.md` §14): *"Cloud Adoption Security Assessment (CASA) — Aligned to
the CAF Secure methodology, which Scout does not model at all."* Per §9 note in that same document,
this assessment depends on RBAC assignments and Key Vault child collectors. `manifests/collectors/
Identity/RoleAssignments.psd1` and `manifests/collectors/Security/KeyVaultSecrets.psd1` /
`KeyVaultKeys.psd1` already exist and are cited below; `Security/KeyVaultCertificates.psd1` is being
added in a parallel workstream and is cited as planned, not yet present.

## What CASA is

The **Cloud Adoption Security Assessment** is an interactive assessment on the Microsoft
Assessments platform (<https://learn.microsoft.com/en-us/assessments/31e5d42d-49b2-4892-b7c7-78689f3518f5/>),
~30 minutes, multiple-choice/multiple-response. A web search summary of Microsoft's own assessment
description states it evaluates *"cloud security maturity across key domains, including security
teams and roles, security posture modernization, incident preparedness and response,
confidentiality, integrity, availability, and security sustainment"* and that *"each question is
designed to assess the implementation of best practices aligned with the Azure Cloud Adoption
Framework (CAF) Secure Methodology."*

Those seven domain names are not a coincidence — they are, verbatim, the seven steps of the CAF
Secure methodology's own cloud security checklist
(<https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/secure/overview>). That checklist
**is** fully published, with named sub-tasks per step across every CAF phase (teams and roles,
strategy, plan, ready, adopt, govern, manage). This enumeration is built from that checklist.

## Verification method — and the one thing this enumeration is NOT

**What was read (2026-08-01):**

| Source | What it gave |
|---|---|
| The CASA assessment landing page | Confirms the assessment exists, its duration/format, and — via a search-result summary of Microsoft's own description — its seven domain names and their explicit tie to the CAF Secure methodology. **No question text or numbers.** |
| [Secure overview](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/secure/overview) | The seven-item cloud security checklist (teams and roles, modernize posture, incident readiness, confidentiality, integrity, availability, sustainment) with named sub-tasks per CAF phase |
| [Perform your cloud adoption securely](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/secure/adopt) | The Azure-facilitation guidance (Secure Score, IaC tooling, Purview classification, Arc/Policy configuration management, Update Manager patching) used to ground the modernization and integrity items below |

**⚠️ The assessment's own question TEXT and NUMBERS are not published**, same limitation as SMART,
the AVS Landing Zone Assessment, and the Cloud Governance assessment. The `CASA-*` identifiers below
are **Scout's own**, built from the CAF Secure checklist's structure, not Microsoft's question
numbers. Domain names (Teams and roles, Security posture modernization, etc.) are Microsoft's,
confirmed both on the checklist page and independently in the assessment's own description.

**Shelf life.** CAF Secure is actively maintained content; re-verify before quoting.

## The enumeration

### TR — Understand security teams and roles

None of this domain is ARM-observable — it is entirely about organisational role definition, not
resource configuration.

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-TR-01 | The role of the cloud service provider in the shared-responsibility model is understood | ❌ Organisational |
| CASA-TR-02 | Infrastructure and Platform team roles (architecture, engineering, operations) are defined | ❌ Organisational |
| CASA-TR-03 | Security architecture, engineering, and posture-management team roles are defined | ❌ Organisational |
| CASA-TR-04 | Security Operations (SecOps/SOC) team roles are defined | ❌ Organisational |
| CASA-TR-05 | Security Governance, Risk, and Compliance (GRC) team roles are defined | ❌ Organisational |
| CASA-TR-06 | Security education, awareness, and policy programmes exist | ❌ Organisational |

### PM — Security posture modernization

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-PM-01 | Identity strengthening — MFA, Conditional Access, least-privilege, just-in-time access — is integrated | ⚠️ Partial — `Identity/ConditionalAccess`, `Identity/PIMAssignments` existence; policy *effectiveness* not scored |
| CASA-PM-02 | Network/workload segmentation is implemented | ⚠️ Partial — `Networking/NetworkSecurityGroup`, `$.networking.nsgPublicInbound[*]` |
| CASA-PM-03 | Threat detection is tuned and enabled via Microsoft Defender for Cloud | ✅ `Security/DefenderPricing`, `Security/DefenderAlerts` |
| CASA-PM-04 | Secure score is tracked in Microsoft Defender for Cloud | ✅ `Security/DefenderSecureScore` (point-in-time only, no trend — same limitation `waf.security.yaml`'s WAF-SE analogue records) |
| CASA-PM-05 | Validation is automated through policy, IaC, and continuous compliance scanning | ⚠️ Partial — `Management/PolicyAssignments`, `Management/PolicyComplianceStates`, `$.management.deployments[?(@.properties.templateHash)]` |

### IR — Incident preparedness and response

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-IR-01 | Incident-lifecycle roles, communication channels, evidence handling, and decision authority are codified | ❌ Organisational |
| CASA-IR-02 | Telemetry ingestion and alert fidelity are tuned to reduce mean time to detect (MTTD) | ⚠️ Partial — `Security/DefenderAlerts`, `Security/Sentinel` existence; alert-fidelity/tuning quality not observable |
| CASA-IR-03 | Runbooks are refined and tabletop simulations practiced | ❌ Organisational |
| CASA-IR-04 | Automated containment actions (isolate hosts, revoke tokens, quarantine storage) run through orchestrated workflows | ⚠️ Partial — `Management/AutomationAccounts` runbook existence only; containment-specific intent is not distinguishable from any other runbook |

### CO — Confidentiality

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-CO-01 | Encryption and key-management controls enforce confidentiality | ✅ `Security/KeyVaultKeys`, `Security/Vault` ("Enable for Disk Encryption") |
| CASA-CO-02 | Identity and access policies restrict access to sensitive data | ⚠️ Partial — `Identity/RoleAssignments` |
| CASA-CO-03 | Network segmentation restricts access to confidential data paths | ⚠️ Partial — `Networking/NetworkSecurityGroup`, `Networking/PrivateEndpoint` |
| CASA-CO-04 | Data classification and sensitivity labelling controls are applied | ❌ Microsoft Purview is not collected by Scout |

### IN — Integrity

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-IN-01 | Hashing and signing preserve data correctness and completeness | ⚠️ Partial — `Security/ArtifactSigning` existence, no per-artefact verification |
| CASA-IN-02 | Immutable storage patterns (WORM, legal hold) are applied where required | ✅ `Storage/BlobContainers` ("Immutability Policy", "Legal Hold", "Version Level WORM" fields) |
| CASA-IN-03 | A secure update supply chain is used for deployment artefacts | ⚠️ Partial — `Security/ArtifactSigning` existence only |
| CASA-IN-04 | Infrastructure changes go through version control / IaC rather than ad hoc portal edits | ⚠️ Partial — `$.management.deployments[?(@.properties.templateHash)]`, same signal as `CAF-AUT-01`/`CAF-AUT-04` |

### AV — Availability

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-AV-01 | Redundancy design (zone-redundant resources) is applied | ✅ `$.compute.virtualMachines[?(@.zoneEligible == true && @.zoneRedundant == false)]`, `$.domains.databases.sqlDatabases[?(@.zoneRedundant == true)]` |
| CASA-AV-02 | Backup and disaster-recovery protection cover workloads | ✅ `Management/Backup`, `Management/BackupInstances`, `Management/RecoveryVault` |
| CASA-AV-03 | Autoscaling is configured to sustain availability under load | ✅ `Monitor/AutoscaleSettings` |
| CASA-AV-04 | Resilience is validated through chaos testing | ⚠️ Partial — `DevOps/ChaosStudio` existence only, no experiment-run history |
| CASA-AV-05 | Health probes and fault-domain isolation are deployed (load balancing) | ⚠️ Partial — `Networking/LoadBalancer` existence only |

### SS — Sustain security posture

| # | Item | Scout can evidence? |
|---|---|---|
| CASA-SS-01 | Secure score security controls are tracked to quantify remaining gaps | ✅ `Security/DefenderSecureScore` |
| CASA-SS-02 | Risk-based metrics (exposed high-privilege identities, unencrypted stores) are coupled to secure score | ⚠️ Partial — `Identity/RoleAssignments` and Key Vault encryption fields exist individually; no composite risk metric is computed |
| CASA-SS-03 | Drift detection is automated through policy, configuration baselines, and deployment pipelines | ⚠️ Partial — `Management/PolicyAssignments[?(@.properties.parameters)]` (DINE/Modify), same signal as `CAF-AUT-02` |
| CASA-SS-04 | Incident retrospectives and threat intelligence feed backlog refinement | ❌ Organisational |

## What this means for the rule file

**8 of 32 items are fully answerable, 15 are partial, 9 are organisational and permanently out of
reach.** The `TR` domain (6 items) is entirely manual by nature — no ARM resource encodes a RACI
chart — and should be surfaced as a manual questionnaire section rather than omitted, per the
pattern `smart.migration.yaml` already established for SMART's organisational items. The strongest
signal is `AV` (availability): backup, redundancy, and autoscaling are all directly observable
today. The weakest is `CO`/data classification (`CASA-CO-04`), which is blocked on Purview
collection the same way `CGOV-DG-01`/`CGOV-DG-02` are in the Cloud Governance enumeration — the same
underlying gap surfaces in both frameworks, which is worth knowing before scoping the collector work
that would close it. `CASA-IN-02` (immutable storage) is the pleasant surprise here: `Storage/
BlobContainers` already carries exactly the three fields this item needs.
