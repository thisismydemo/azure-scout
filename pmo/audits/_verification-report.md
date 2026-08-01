# Verification report — §3c "Minimum permissions to read and collect"

Adversarial fact-check against Microsoft Learn. Every role definition below was pulled in full
(`microsoft_docs_fetch`), not from search excerpts.

---

## Verdict

**Not trustworthy as written.** The headline conclusion — *Azure RBAC `Reader` at root MG covers
every ARM collector* — is correct and now solidly proven. But the section contains **one error that
changes what a customer would grant** (CrossTenantAccess), **one load-bearing citation that says the
opposite of what it is cited for** (Cost Management), **three false "strict subset" claims about the
redundant roles**, and **an internal contradiction between the §3c prose and the document's own
Table B**. Roughly 8 defects, 2 of them serious.

---

## Errors found

### E1 — SERIOUS. "`Directory Readers` + Entra `Security Reader` covers every Entra collector Scout has" is false, and the document contradicts itself

Line 561 states this flatly. Line 1009 (Table B, same document) says CrossTenantAccess is
**Unverified** and may need Global Reader. Both cannot be true.

The correct fact: **neither recommended role grants any read on the cross-tenant access policy.**
The complete action lists are:

- `Directory Readers` — no `crossTenantAccessPolicy` entry of any kind.
- Entra `Security Reader` — only two entries, both for *templates*:
  `crossTenantAccessPolicy/partners/templates/multiTenantOrganizationIdentitySynchronization/standard/read`
  and `.../multiTenantOrganizationPartnerConfiguration/standard/read`.

Scout calls `/v1.0/policies/crossTenantAccessPolicy/partners` — the live partner configuration, not
a template. Neither role covers it.

Source: <https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference>
(sections `## Directory Readers`, `## Security Reader`).

**Severity: changes the grant.** A customer following the §3c recommendation gets a silently empty
CrossTenantAccess worksheet. Either add a third role or state the gap in §3c, not only in Table B.

### E2 — SERIOUS. Table B's supporting claim for that row is also wrong

Line 1009: *"there is **no** action for the `partners` collection itself in any role definition."*

False. `microsoft.directory/crossTenantAccessPolicy/partners/standard/read` exists and is held by
**Global Administrator, Global Reader, Security Administrator, Teams Administrator, and Tenant
Governance Administrator**. The narrower `crossTenantAccessPolicy/default/standard/read` and
`crossTenantAccessPolicy/standard/read` likewise exist.

Same URL as E1. This is the same failure mode as the previously-confirmed `namedLocations` error —
an absence asserted from an incomplete read.

**Severity: material.** The fix is not "fall back to Global Reader" — `Security Administrator` and
`Tenant Governance Administrator` also carry it, and are worth evaluating before reaching for the
privileged read-everything role.

### E3 — SERIOUS. The Cost Management citation contradicts the claim it is attached to

Line 691 cites [Assign access to Cost Management data](https://learn.microsoft.com/azure/cost-management-billing/costs/assign-access-acm-data)
as evidence that `Reader` suffices and *"Cost Management Reader is redundant."*

That page says the opposite. Repeatedly:

> "Access to a subscription requires at least the **Cost Management Reader** (or Contributor)
> permission." — and the same sentence for resource-group and management-group scope. Its EA scope
> table lists "Cost Management Reader (or Contributor)" as the *Required access to view data* for
> management group, subscription, and resource group. `Reader` is never named.

The *other* citation — the role-behaviour table in
[Understand and work with scopes](https://learn.microsoft.com/azure/cost-management-billing/costs/understand-work-scopes#azure-rbac-scopes)
— **does** support the claim: `Reader` = "Read only" on *Cost Analysis / Forecast / Query / Cost
Details API*. So Microsoft's own two pages conflict.

**Severity: the conclusion is probably right, the evidence as presented is not.** Cite only
`understand-work-scopes`, drop `assign-access-acm-data`, and say plainly that a second Microsoft page
contradicts it.

### E4 — "Azure RBAC `Security Reader` is a strict subset of `*/read`" is false

Line 693. The full definition (role id `39bc4728-0917-49c7-9d2c-d95423bc2eb4`) contains **five
`/action` permissions**, none of which is inside `*/read`:

```
Microsoft.Security/iotDefenderSettings/packageDownloads/action
Microsoft.Security/iotDefenderSettings/downloadManagerActivation/action
Microsoft.Security/iotSensors/downloadResetPassword/action
Microsoft.IoTSecurity/defenderSettings/packageDownloads/action
Microsoft.IoTSecurity/defenderSettings/downloadManagerActivation/action
```

Source: <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/security#security-reader>

Note `iotSensors/downloadResetPassword/action` — downloads a password-reset file. The document
flags Monitoring Reader for granting a write while missing that Security Reader grants five.

**Severity: reasoning, not outcome.** The role is still redundant *for Scout* (line 1120 in Table C's
preamble gets this right). But "strict subset" is wrong and would fail review.

### E5 — "Monitoring Reader is a strict subset of `*/read`" is false — it is a strict **superset**

Same line 693. Monitoring Reader (`43d0d8ad-25c7-4714-9337-8ba259a9fe05`) is:

```
*/read
Microsoft.OperationalInsights/workspaces/search/action
Microsoft.Support/*
```

It contains all of Reader plus two more. The document also omits
`OperationalInsights/workspaces/search/action` when listing what it adds.

Source: <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/monitor#monitoring-reader>

### E6 — Cost Management Reader also grants `Microsoft.Support/*`, and the document does not say so

Line 466 singles out Monitoring Reader for the `Microsoft.Support/*` ticket-creation write. Cost
Management Reader (`72fafb9e-0641-4937-9268-a91bfd8191a3`) carries the identical
`Microsoft.Support/*`. So does `Billing Reader`. If the write is worth flagging on one role it is
worth flagging on all three — otherwise a reader concludes Cost Management Reader is write-free.

Source: <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/management-and-governance#cost-management-reader>

### E7 — §3c attributes `DirectoryRoles` to Entra `Security Reader`; it is covered by `Directory Readers`

Line 513 lists `DirectoryRoles` among what Security Reader unlocks. Security Reader's action list
contains **no** `directoryRoles/` entry at all. `Directory Readers` has
`directoryRoles/standard/read`, `/members/read`, `/eligibleMembers/read`. Table B line 1000 gets
this right; §3c does not.

**Severity: low**, but it inflates the apparent necessity of the privileged role.

### E8 — MCA gate: wrong role named

Line 625: *"Only an Enterprise Administrator (EA) or **Billing account owner** (MCA) can change
these."* For MCA the setting sits on the **billing profile** and Microsoft states: *"You must have
**Billing Profile Owners** permission to enable the setting."*

Source: <https://learn.microsoft.com/azure/cost-management-billing/costs/assign-access-acm-data#enable-mca-access-to-costs>

Also minor: the MCA setting's current name is **"Azure charges"**; the document uses the older
"Allow Azure subscription users to view and optimize costs".

### E9 — `Verified` column contradicts the `Source` column on at least 7 rows

`Doc` is defined at line 684 as "confirmed against Microsoft Learn". These rows say `Doc` while
their own Source says otherwise:

| Row | Verified | Source |
|---|---|---|
| CloudServices | Doc | **NOT FOUND** |
| ArcDataControllers | Doc | **NOT FOUND** |
| ArcSQLManagedInstances | Doc | **NOT FOUND** |
| ArcSQLServers | Doc | "not on any `permissions/` provider page" |
| NATGateway | Doc | **NOT FOUND** |
| AVDApplicationGroups | Doc | `n/a` |
| AVDApplications | Doc | `n/a` |
| AutomationAccounts | Doc | `n/a` |

Either the row is documented or it is not. The `n/a` rows are also uncounted in the 133/142
citation-coverage arithmetic, so 93.7% is not reproducible from the table.

---

## Claims confirmed

1. **`Reader` = `Actions: ["*/read"]`, `notActions: []`, `dataActions: []`, `notDataActions: []`.**
   Verified against the JSON in the role definition itself, id `acdd72a7-3385-48ef-bd42-f606fba81ae7`.
   `NotActions` is genuinely empty. <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/general>

2. **Monitoring Reader grants `Microsoft.Support/*` — ticket creation, a write.** Confirmed verbatim
   ("Create and update a support ticket"). Claim 3 stands.

3. **All five Entra `Security Reader` actions Scout depends on are present.** Individually checked in
   the full definition: `conditionalAccessPolicies/standard/read`, `namedLocations/standard/read`,
   `identityProtection/allProperties/read`, `privilegedIdentityManagement/allProperties/read`,
   `policies/standard/read`. Also present: `authorizationPolicy/standard/read` (the action Table B
   actually needs for SecurityPolicies), `signInReports/*`, `auditLogs/*`. The earlier namedLocations
   correction is itself correct.

4. **`Directory Readers` has zero Conditional Access actions.** Confirmed — the complete 56-action
   list contains no `conditionalAccessPolicies` entry. Claim 6 stands.

5. **`Global Reader` is a privileged role.** Confirmed — carries the privileged label and the
   sentence "This is a privileged role". Claim 9 stands.
   *Not flagged by the document but true and relevant:* **Entra `Security Reader` is also labelled
   privileged**, and includes `microsoft.directory/bitlockerKeys/key/read` — itself individually
   privileged. The table marks it "Privileged? Yes" but never mentions BitLocker recovery-key read
   in the "Covers" column. Worth stating; it is the strongest argument a security reviewer will make.

6. **`Reports Reader` is not privileged** and grants nothing Scout uses (audit logs, sign-in reports,
   provisioning logs only). Confirmed.

7. **EA/MCA billing claims (claim 10) — all confirmed.**
   - "Enterprise Administrator (read only)" and "Department Administrator (read only)" are real role
     names in the usage-and-costs-access table.
     <https://learn.microsoft.com/azure/cost-management-billing/manage/understand-ea-roles>
   - Both **AO view charges** and **DA view charges** gates exist and are independent.
   - *"If DA view charges option is disabled, department users can't see costs at any level, even if
     they're an account or subscription owner"* — verbatim.
   - The Billing Reader quote is verbatim from
     <https://learn.microsoft.com/azure/cost-management-billing/manage/manage-billing-access#give-read-only-access-to-billing>,
     as is "The Billing Reader feature is in preview, and doesn't yet support nonglobal clouds."
   - "Although RBAC scopes are bound to a single directory, EA billing scopes aren't" — verbatim.
   - MCA read-only roles (Billing account / Billing profile / Invoice section Reader) — supported.

8. **`Microsoft.CostManagement/query/read` and `/action` both exist**, as do
   `policyStates/queryResults/{read,action}` and `policyStates/summarize/{read,action}`. The
   document's statement of the ambiguity is accurate; its resolution is not (see below).

---

## Claims that could not be verified from documentation

### Claim 4 — does POST `/query` authorize on `query/read` or `query/action`?

**Unresolvable from Microsoft's docs directly**, but the strongest available inference favours
`/read`, and the document's conclusion is probably right for the wrong reason:

- `Cost Management Reader`'s only CostManagement grant is `Microsoft.CostManagement/*/read`. It has
  **no** `query/action`. Microsoft's capability table says it can "View cost data (Cost Analysis,
  Forecast, etc.)". Cost Analysis is the Query API. Therefore the enforced permission must be
  `query/read` — and `Reader`'s `*/read` is a superset of `CostManagement/*/read`.
- Direct precedent that ARM POSTs are routinely gated on `/read`:
  `Microsoft.ResourceGraph/resources/read` — *"Submits a query on resources"* — is the permission
  for the ARG POST, and Microsoft states explicitly for another operation:
  *"This **read** permission, not `setAzureNetworkManagerConfiguration/action`, is required to call
  Set Azure Network Manager Configuration."*
  (<https://learn.microsoft.com/azure/role-based-access-control/permissions/networking#microsoftnetwork>)

**But this is an inference, not documentation**, and it is contradicted by the `assign-access-acm-data`
page (E3). Grade it `Untested`, not `Doc`.

### Claim 5 — Policy Insights `/read` vs `/action`

**Genuinely unresolved.** Both variants exist. The document asserts "the `/action` variants belong to
writer roles" (line 467) — that is not supported. Counter-evidence: **App Compliance Automation
Administrator**, a role whose job is reading compliance state, holds
`policyStates/queryResults/action`, *not* `/read`. That is exactly a role reaching for the `/action`
variant to query. No page states which one a POST to `policyStates/latest/queryResults` enforces.
Grade `Untested`.

### The ARG permission is missing from the tables entirely

Every class-A row (~130 of 154 collectors) reaches Azure through Azure Resource Graph, yet no row
lists `Microsoft.ResourceGraph/resources/read` in its `Minimum permission` column. `Reader` covers it,
so the conclusion is unaffected — but the tables' stated minimum permission is incomplete for the
majority of collectors. Confirmed the action exists and is a `/read`:
<https://learn.microsoft.com/azure/role-based-access-control/permissions/management-and-governance#microsoftresourcegraph>
plus *"you must have appropriate rights ... with at least `read` access to the resources you want to
query"* (<https://learn.microsoft.com/azure/governance/resource-graph/overview#permissions-in-azure-resource-graph>).

### Claim 11's premise, restated

The document is honest that nothing has been run against a Reader-only principal, and the "probable,
not proven" paragraph (lines 641-649) is fair. That framing is fine. The defects above are all in
things that *are* documentable and were documented wrongly.

---

## Spot-check results

### Source anchors (claim 12) — 15 sampled, 13 correct

| Row | Anchor claimed | Result |
|---|---|---|
| AIFoundryHubs / MachineLearning | `permissions/ai-machine-learning#microsoftmachinelearningservices` | ✅ |
| AzureAI + 12 Cognitive rows | `permissions/ai-machine-learning#microsoftcognitiveservices` | ✅ |
| Streamanalytics | `permissions/internet-of-things#microsoftstreamanalytics` | ✅ provider genuinely on the IoT page; action is `streamingjobs/Read` (case differs, immaterial) |
| ContainerApp / ContainerAppEnv | `permissions/compute#microsoftapp` | ✅ `microsoft.app` is on the Compute page |
| AVD / AVDSessionHosts / AVDScalingPlans / AVDWorkspaces | `permissions/compute#microsoftdesktopvirtualization` | ✅ `hostpools/read`, `workspaces/read` present |
| MariaDB | `permissions/databases#microsoftdbformariadb` | ✅ provider page exists |
| NATGateway | **NOT FOUND** | ✅ correctly flagged — page lists only `natGateways/join/action` and `natGateways/providers/Microsoft.Insights/metricDefinitions/read` |
| PolicyComplianceStates | `permissions/management-and-governance#microsoftpolicyinsights` | ✅ anchor right, but `/read` vs `/action` unresolved (see above) |
| VirtualMachine (cost leg) | `permissions/management-and-governance#microsoftcostmanagement` | ✅ anchor right, `query/read` present |
| SupportTickets | `permissions/general#microsoftsupport` | ✅ |
| DefenderAlerts/Assessments/Pricing/SecureScore | `permissions/security#microsoftsecurity` | ✅ |
| AVDApplicationGroups | `n/a` | ❌ marked `Verified: Doc` with no citation (E9) |
| AVDApplications | `n/a` | ❌ same |
| AutomationAccounts | `n/a` | ❌ same |
| CloudServices | NOT FOUND but `Verified: Doc` | ❌ (E9) |

No anchor was found pointing at a page that does not contain the claimed action. The citation *targets*
are sound; the `Verified` *grades* are not.

### The 9 `NOT FOUND` rows (claim 13) — spot-checked 3, all genuine

- **`Microsoft.Network/natGateways/read`** — genuinely absent. The Microsoft.Network table jumps from
  `masterCustomIpPrefixes/delete` straight to `natGateways/join/action`. The document's reading is
  correct and its conclusion ("real type, undocumented action, `*/read` covers it") is the right call.
- **`Microsoft.DBforPostgreSQL/servers`** — correct; only `flexibleServers` is documented. Single
  Server is retired. *Adjacent observation the document does not make:* Azure Database for **MariaDB**
  was also retired, so the `MariaDB` collector is likely in the same state as `POSTGRE` even though
  its provider page still exists. Worth checking before the next revision.
- **`Microsoft.ResourceGraph`** — *not* in the NOT FOUND list because it is not in the tables at all.
  It is fully documented and should be added rather than being an unlisted gap.

### Internal consistency

Three places in §3c contradict Table B or Table C's preamble: line 561 vs line 1009 (E1),
line 513 vs line 1000 (E7), line 693 vs line 1120 (E4). §3c's prose is consistently the less careful
of the two.

---

## Recommended fixes, in priority order

1. Rewrite line 561. `Directory Readers` + Entra `Security Reader` covers **14 of 15** Entra
   collectors. CrossTenantAccess needs a role carrying
   `microsoft.directory/crossTenantAccessPolicy/partners/standard/read` — Security Administrator,
   Tenant Governance Administrator, or Global Reader.
2. Delete the "no action for the `partners` collection in any role definition" sentence at line 1009;
   it is false.
3. Drop `assign-access-acm-data` as a citation for Cost Management; keep only the role-behaviour
   table, and note the conflict.
4. Replace "strict subsets of `*/read`" (line 693) with the accurate statement: both roles grant
   non-read actions; neither grants anything Scout calls.
5. Add `Microsoft.Support/*` to the Cost Management Reader description, or drop the callout from
   Monitoring Reader for consistency.
6. Downgrade the Cost Management and Policy Insights POST rows from `Doc` to `Untested`.
7. Fix the 8 rows where `Verified: Doc` sits beside `NOT FOUND` or `n/a`, and recompute 133/142.
8. Fix `DirectoryRoles` attribution (line 513) and the MCA gate role name (line 625).
9. Add `Microsoft.ResourceGraph/resources/read` to the class-A rows.
10. Mention that Entra `Security Reader` includes `bitlockerKeys/key/read` before someone else does.
