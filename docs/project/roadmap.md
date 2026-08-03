---
description: Planned features, future enhancements, and the long-term vision for AzureScout.
---

# Roadmap

*See everything. Own your cloud.*

This page outlines what's planned, what's in progress, and what's been delivered.
Community contributions are welcome — see [Contributing](./contributing.md) to get involved.

> The consolidated architecture, work-item index, audit findings, and delivery
> plan live in the [Master Design & Plan](https://github.com/thisismydemo/azure-scout/blob/main/pmo/plans/master-plan.md). This roadmap is
> the public-facing summary of it.

## v3.0.0 engine rebuild status

**Epic AB#5638 is ready for v3.0.0 release validation.** The declarative collector catalog has
replaced the retired source-script tree. Publication follows the final package and full-suite gates.

Measured on `main` as of 26 July 2026:

| Acceptance criterion | Target | Actual |
|---|---|---|
| Retired collector source tree | absent | **removed** |
| Declarative collector catalog | every collector | **236** (`manifests/collectors/*.psd1`) — 174 at v3.0.9, +62 in v3.1.0 |
| Strict declarative processing | all collectors | **236/236 verified** |
| Golden report contract | rows + two worksheet modes | **236 rows / 472 worksheet cases verified** |
| Inventory and assessment share one reporting layer | cut over | **declarative reporting path** |
| Three consecutive runs on an unchanged estate are identical | yes | **yes** (v2.6.0) |

Reporting reads each definition's `Export` section through the same manifest catalog as processing;
there is no collector-script reporting branch.

You can check every number yourself — `scripts/Test-StrictModeGuard.ps1` prints the weakening-site
count, and the rest are file counts.

### v3.0.0 completion criteria

All collector definitions, source retirement, strict runtime contracts, and reporting contracts are
complete. The remaining release steps are package validation, broad test-suite completion, tag, and
publication. Historical v2 entries below are retained as release history rather than current status.

## Current Release — v3.3.3 — The corpus told the truth

Released 3 August 2026. Five collection defects fixed, none of which a green unit suite could
see: the v3.3.2 Recovery Services vault fix never reached the collect result; Export-Pptx's
module-scope `Get-ScoutProp` shadowed the collect walker and nulled nested `properties.*` on
every product run (the defect that corrupted the banked corpus); management groups are collected
for the first time in the product's history (tenant-scoped Resource Graph, 92 groups across the
eight reference tenants); `security.defenderPlans` is collected per subscription instead of
shipping as a hardcoded empty array the CAF/WAF security rules queried in vain; and two runs in
the same second no longer share one run folder. The corpus is now a committed harness —
per-tenant integrity checks on collection, per-collector coverage verdicts offline: 36 collect
keys proven working across 8 real tenants, 0 unexplained empties.

## Previous Release — v3.3.2 — Field fixes from real tenant runs

Released 3 August 2026. Every fix in this release came from running Scout against live estates.
Advisor ingestion is contained per subscription instead of failing tenant-wide on one unregistered
`Microsoft.Advisor` provider; Entra ID P2-gated Graph features report `NOT LICENSED` instead of a
misleading `DENIED`; Recovery Services vaults are collected instead of hardcoded to an empty
array; the LandingZone assessment scores its own 13 areas instead of sweeping in every workload
rule set; `GovernanceReport` is reachable from `-OutputFormat All`; and evidence truncation is
visible in every renderer. The v3.3 line (3.3.0 → 3.3.2) delivered the reporting rebuild of Epic
AB#6450: conformance-gated Word/Excel/PowerPoint/PDF deliverables, managed-code figure
rasterisation, and a Power BI PBIP project with a TMDL model and bound visuals.

## v3.2.0 — Deep governance and compliance analytics

Released 31 July 2026. Scout modelled fifteen of Microsoft's eighteen published service
categories; it now models all eighteen. `Migration` went from zero collectors to all five of its
services, and `General` and `DevOps` exist for the first time. 62 collectors were added, taking
measured service coverage from **41% to 66%** of the 349 services the audit enumerates — recounted
mechanically from the per-service table, not asserted.

Four things this release fixed that had shipped in every prior one: Logic Apps were excluded from
the Resource Graph query outright; the golden collector suite failed on any day but the one it was
recorded on; the wizard resolved its assessment manifest to a path outside the repository and so
never listed more than one assessment; and `-Category DevOps`/`Migration` were documented aliases
that parameter binding rejected.

New capability rather than new collectors: the rule engine can now express a condition spanning
two collected datasets, declared as rule data, so "which VMs have no backup" is answerable — six
such rules ship. Key Vault secret and key expiry, blob-container public access, file shares,
lifecycle policies and Backup vault instances are collected for the first time, all on the control
plane and all within Reader. The SMART migration-readiness assessment ships with its source
framework enumerated and date-stamped first, including an explicit record of what could not be
enumerated. See **Epic AB#6741**.

## CAF/WAF assessment programme

**Planned, from the Epic AB#6731 audit. Scout ships one real assessment
today: `LandingZone`.** Everything else in
`manifests/assessments.psd1` is either a filtered slice of that same rule set
(the 15 per-category entries, prefixed `Assess: ` as of this release — see the
[Assessment Registry](../design/assessment-registry.md)), a sub-bundle, or
`Cost`. Microsoft's own [assessment catalogue](https://learn.microsoft.com/assessments/browse/)
lists 56 published assessments; of those, an owner-decided set of **14** are
Scout's build targets for the next several releases — chosen because Scout
already collects data for most of them, or is uniquely positioned to score
them (Azure Local, in particular — see below).

| # | Target | Scout's starting position |
|---|---|---|
| 1 | Azure Well-Architected Review | `waf.*` rule files exist, tagged by pillar — **~15% solid coverage** against the WAF checklist's ~26 machine-assessable items |
| 2 | Azure Landing Zone Review | `LandingZone` already aims at this — **~10%** of CAF's ~365 verified design-area recommendations |
| 3 | Azure Local \| Well-Architected Review | **Scout's strongest differentiator** — 16 Hybrid collectors, no WAF-shaped rule output yet |
| 4 | WAF AI workload | AI is Scout's best-inventoried category; rules are thin (`caf.ai`, 5 rules) |
| 5 | WAF Azure Virtual Desktop workload | 7 AVD collectors exist; no AVD-specific rule file |
| 6 | WAF Azure VMware Solution workload | AVS collected; no AVS rule file |
| 7 | AVS Landing Zone Review | Pairs with #6 — platform readiness rather than workload |
| 8 | Cloud Governance | Policy compliance state is already collected and scored by nothing |
| 9 | FinOps Review | `waf.cost` (6 rules) + a misnamed `caf.billing.yaml` that actually holds cost-optimization rules |
| 10 | DevOps Capability Assessment | 5 DevOps collectors exist via the Azure DevOps REST API |
| 11 | Microsoft Cloud Security Benchmark (MCSB) | Not on Microsoft's assessment catalogue — it's an Azure Policy initiative (223 policies, assigned by default in Defender for Cloud). The compliance state is already collected via three code paths and read by no rule — **cheapest assessment on this list, no new Azure calls** |
| 12 | WAF Maturity Model | Same rules as #1, different output shape ("level 2 of 5" vs. a fail list) |
| 13 | Cloud Adoption Security Assessment (CASA) | Aligned to the CAF **Secure** methodology, which Scout does not model at all today |
| 14 | Strategic Migration Assessment (SMART) | Blocked until the Migration category has collectors — **shipped in v3.1.0**; `smart.migration.yaml` is scored against the enumerated source in [SMART's framework page](../frameworks/smart-question-set.md) |

::: warning Only 2 of 14 are design-ready
Writing a rule file against a framework nobody enumerated is how
`waf.storage.yaml` happened — a rule file that scores a WAF pillar (Storage)
that doesn't exist; WAF has exactly five pillars. Only **#1 Azure
Well-Architected Review** (the 5-pillar checklist) and **#2 Azure Landing
Zone Review** (the 8 CAF design areas) have their source structure enumerated
and coverage-measured today — both in the audit document, §8. **#14 SMART**
now has its source enumerated too (linked above). The remaining eleven each
need their own enumeration — a published Microsoft checklist or question set,
read and tabulated — as a prerequisite task before any rule file is written
against them, because Microsoft is actively rewriting several of these pages
and a coverage number without a verification date and method will silently
go stale.
:::

**What blocks the most assessments is Scout's own defect, not new
collectors.** `-IncludeTenantWideResources` used to gate management groups,
custom role definitions, policy definitions and policy set definitions
behind a switch no production caller ever set — fixed in this release (see
[v3.1.0](#current-release-v3-1-0-eighteen-category-service-coverage) history
below) — and that single fix unblocks #2, #7, #8 and #13. A second
near-free win: role assignments, resource locks, policy assignments and
budgets are already collected into memory and rendered by nothing, which is
most of what blocks #8 Cloud Governance outright.

**Deliberately excluded:** partner-enablement guides, skills assessments, and
industry-vertical readiness guides from Microsoft's catalogue. Those are
training material, not something a scanning tool can produce.

Full detail, the release-order dependency map, and the underlying evidence:
`pmo/audits/AZURE-SCOUT-AUDIT.md` §8, §13 (decisions DQ1/DQ2/DQ10-DQ12), and
§14.

## v3.0.9 — Live-run hardening

Released 30 July 2026. A live run against a real 8-subscription tenant surfaced two fatal
crashes (JSON report export, SupportTickets collector) plus six further defects: no
retry/backoff in the operational-enrichment ARM helper, a permanently-broken Arc CPU metrics
call, an expected-but-noisy ReplicationEligibility 404, a wizard Scope/Entra silent-default gap
that caused zero Entra ID data to be collected despite full permissions, a missing Cost Data
module pre-flight check, and an unclear DefenderAlerts null-reference message. See **Epic
AB#6731** for the full defect list and fixes.

## v3.0.8 — Az breaking-change warning suppression

Released 29 July 2026. Suppresses Az module breaking-change warnings in non-debug output.

## v3.0.7 — StrictMode common-parameter fix

Released 29 July 2026. Avoids a StrictMode `VariableIsUndefined` error when common parameters
such as `-Debug` are supplied to `Invoke-AzureScout`.

## v3.0.6 — Excel and ARC resilience

Released 28 July 2026. Resilience and logging improvements for the Excel report build and
ARC-enabled server collection.

## v3.0.5 — VM cost-row regression correction

Released 28 July 2026. This patch keeps production VM reporting running when Cost Management
returns the amount and currency as a nested row. Clean Gallery v3.0.5 live verification completed
on 29 July 2026 with `-Scope ArmOnly`: 174 declarative collectors run, 0 failures, and 1,121 Excel
rows written.

## v3.0.4 — VM runtime regression correction

Released 28 July 2026. This patch keeps the production `Compute/VirtualMachine` collector
running when Azure returns repeated `MemoryGB` values in a Compute SKU payload.

## v3.0.3 — Production runtime collection

Released 28 July 2026. This patch enables the hardened ARM-child, storage enrichment, and
subscription security/policy collectors in normal extraction.

## v3.0.2 — Runtime collector hardening

Released 28 July 2026. This patch stops queries to retired Application Insights endpoints
and scopes storage service-property lookups to the resource-owning subscription.

## v3.0.1 — Tenant-scoped authentication and wizard correction

Released 28 July 2026. This patch binds every Azure subscription context switch to the
requested tenant, preventing unrelated cached-tenant authentication attempts during a
tenant-scoped run. It also preserves the interactive wizard when PowerShell common
parameters such as `-Debug` are supplied.

## v3.0.0 — Declarative engine rebuild

Released 26 July 2026, published to the PowerShell Gallery. Epic **AB#5638** — **reopened**; this
release advanced it but did not complete it (see [above](#the-engine-rebuild-is-in-progress-not-complete)).

**138 of 176 collectors are now declarative**, up from 124. The audit had classified 20
cross-resource-join collectors as escape-hatch alongside those making live cmdlet calls.
Re-examining all 48 showed the audit's *reasons* were right but its *inference* was not: **a
cross-resource join is not the same thing as a live cmdlet call.** Each of those 20 filters the
already-collected resource set a second time and correlates — data shaping over data the pipeline
already holds. The only missing capability was somewhere to put statements that run **once**, before
the row loop. Verified live: the run log reports **138 declarative, 36 imperative**.

**Definitions are now gated in CI** by a validator that runs before the test suite, so a violation
annotates the offending `.psd1` in the pull-request diff rather than surfacing as an empty worksheet
at runtime. It includes a **drift check** — regenerating a definition from its source collector must
reproduce it byte for byte. That check exists because a definition **had already drifted for a
release while its equivalence test stayed green**; nothing in the repository could have caught it.
The gate is proven to fail rather than assumed to: 13 tests each write one deliberately broken
definition and assert the message names the fault.

**The honest limit, and the weakest part of the release:** all 14 newly converted collectors agree
with their imperative counterpart row for row, but the generated estate only makes *the join itself*
change output for **5** of them. For the other 9, partners are present and both paths agree while
both take the not-found branch. Each of the 9 is pinned by name, and a test asserts output changes
when partners are removed — failing on a stale entry too, so the list can only shorten.

**Still imperative: 38**, each with a specific reason — live REST or `Get-Az*` calls, conditional
row shape or loop depth, a synthesised row set, or an unimplemented contract. No second escape hatch
was invented; not having a definition remains it.

**Not done:** reporting is still not cut over — the Excel job runs each collector's own reporting
branch through its own duplicate discovery.

Live-verified: 5:37, 136 resources, 481 Excel rows, zero leftover background jobs, zero collector
failures.

Full detail: [CHANGELOG.md § 2.11.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#2110---2026-07-26).

## Previous Release — v2.10.0 — The Declarative Collectors Actually Run

Released 26 July 2026, published to the PowerShell Gallery. Epic **AB#5638**.

**v2.9.0 converted 124 of 176 collectors to `.psd1` definitions — but nothing called the
interpreter.** The live pipeline still executed the imperative `.ps1` for every collector, so the
conversion delivered nothing to a user. It now routes on the `HasDeclarativeDefinition` /
`DefinitionPath` that `Get-ScoutCollector` already reported. Verified against a live tenant, the run
log reports **124 declarative, 50 imperative**.

Proving this needed a different technique than the conversion did: **a row comparison can never
detect a routing regression**, because both paths agree by construction. The proof is by
impossibility — a fixture collector has a valid definition and a `.ps1` whose entire processing
branch is a `throw`, and the run completes with its row present; with the kill switch on, the same
fixture fails with that exact message. A full pass over an 845-resource estate produced **1654 rows
either way, zero deltas, and byte-identical ReportCache JSON**.

**Kill switch:** `AZURESCOUT_FORCE_IMPERATIVE_COLLECTORS=1` forces every collector down the
imperative path — an environment variable, so it works on an already-installed build.

**The non-ARG collection half is inverted.** `Get-ScoutApiResources`, `Get-ScoutVmQuotas`,
`Get-ScoutVmSkuDetails` and `Get-ScoutCostInventory` — shipped in v2.7.0 and dead since — are now
the real path, with the v1 ARM REST, quota/SKU and Cost Management implementations retired to shims
and pinned by AST tests.

**`Management/ManagementGroups` no longer fails the run** — the only collector that failed on every
live run. **This is the first release with zero collector failures.** A tenant still needs
Management Group Reader at the root for that sheet to carry rows.

**Not done, stated rather than implied:** reporting is not cut over. `Start-AZSCExcelJob` still runs
each collector's `.ps1` reporting branch through its own duplicate discovery, so every definition's
`Export` section is still exercised only by tests.

Live-verified: 6:37, 136 resources, 481 Excel rows, 43 worksheets, zero leftover background jobs.

Full detail: [CHANGELOG.md § 2.10.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#2100---2026-07-26).

## Previous Release — v2.9.0 — The Collectors Become Data, and the Module Runs Strict

Released 26 July 2026, published to the PowerShell Gallery. Second wave of the engine rebuild
(Epic **AB#5638**).

**124 of 176 collectors are now `.psd1` definitions rather than PowerShell**, up from 13. Every one
is pinned by an equivalence test that runs the original imperative collector and the declarative
definition over the same input, then compares processed rows key-by-key *and* the written `.xlsx`
cell-by-cell, under both `-IncludeTags` states. Writing those tests found **six interpreter defects**
that would otherwise have shipped — including a field whose source is an `if`/`else` *statement*
being silently unreachable, and a dropped filter preamble that made one collector produce a
**silently empty sheet**.

**All 174 collectors now pass under `Set-StrictMode -Version Latest`**, with a baseline that is
empty because a run says so rather than aspirationally. Each conversion was proved real by running
the collector twice with StrictMode off, before and after, and diffing emitted rows — 20 of 23 are
byte-identical. A CI guard, AST-parsed rather than grepped, now fails the build if StrictMode is
weakened anywhere in the module.

**A blind spot in error reporting closed.** AB#402 detection compared `$Error.Count` before and
after a phase, but `$Error` is a fixed-size ring buffer — once it saturates the count stops rising,
the delta is permanently zero, and non-terminating errors stop being reported at all. Silently, and
precisely in the long runs where degraded datasets matter most.

**`ChartP6` root-caused:** a worksheet that exists but holds no cells has a `$null` dimension, so
ImportExcel's pivot source-range lookup threw, `Add-PivotTable` downgraded it to a warning, and the
chart vanished with it. The guard tested existence, not emptiness.

**`Management/ManagementGroups` was never a StrictMode fault** — it fails parameter binding on
`Get-AzManagementGroup -Expand -Recurse` with no `-GroupId`. That is the long-standing *"missing
mandatory parameters: GroupName"* failure on every live run, finally explained.

**Known limits, stated rather than buried:** the equivalence fixtures are *generated* by walking
each definition's AST, not recorded from a tenant — they prove the two implementations agree on the
same input, not that either is right about a real estate. The live pipeline still executes the
imperative `.ps1` for every collector; converting is not the same as using. And of the 174
StrictMode passes, 146 emit zero rows because the capture covers only 32 resource types.

Live-verified: 4:52, 124 resources, 438 Excel rows, 42 worksheets, zero leftover background jobs.

Full detail: [CHANGELOG.md § 2.9.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#290---2026-07-26).

## Previous Release — v2.8.0 — Collection Actually Happens Once

Released 26 July 2026, published to the PowerShell Gallery. Epic **AB#5638**, work item **AB#5648**.

**A default assessment collect now issues 4 Azure Resource Graph queries instead of 35.**

v2.7.0 shipped the single-pass collection functions, but nothing called them — outside tests the
only reference to any of them was a comment — so the round-trip count was unchanged. They are now
the real path. Both numbers were re-derived by counting invocations against a stub in place of
`Search-AzGraph`, and both are pinned by hard count assertions in a test, because a query count
with no test regresses silently within a release.

| Entry point | before | after |
|---|---|---|
| Assessment-only collect (default) | 35 | **4** |
| Assessment collect, `-Source TypedQueries` | 35 | 35 |
| Inventory extraction (default switches) | 8 | 8 |
| Combined inventory + assessment, end to end | 9 | 9 |

It is **4 rather than 1** for stated reasons: three raw tables plus `sqlDefenderPricing`, which
reads `SecurityResources` and genuinely cannot be served from inventory. Inventory extraction stays
at **8** because those are eight *distinct* ARG tables, not filters over one — merging them would
drop datasets. What changed there is ownership rather than count: one paging implementation instead
of two.

The legacy paging, batching and retry engine (`Invoke-AZTIInventoryLoop.ps1`) is **deleted**, and
`Start-AZTIGraphExtraction` is reduced to a shim that builds no query text and issues no ARG call.
Both facts are enforced by AST-based tests rather than text searches.

**A defect that would have shipped as a blank report section**, invisible to all 2144 passing
tests: the raw pass omits the `tags` column unless asked, while the collect contract aggregates its
top-level `tags` key from `subscriptions[*].tags` — so the inverted path returned an empty `tags`
array for every estate. Fixed, with a regression test.

**Trade-offs, stated and not yet measured:** the raw pass carries the full `properties` bag where
the typed queries carried narrow projections, so on a large estate the number of 1000-row pages can
*rise* even as the query count falls; and `-Categories` no longer reduces what is fetched, only what
is shaped. `-Source TypedQueries` remains fully supported as the escape hatch for a narrow
single-category collect.

**Not claimed as done:** the non-ARG half. `Get-ScoutApiResources`, `Get-ScoutVmQuotas`,
`Get-ScoutVmSkuDetails` and `Get-ScoutCostInventory` remain dead code, and a live run still uses the
v1 implementations for ARM REST, VM quota/SKU and Cost Management.

Live-verified: 5:11, 124 resources, 438 Excel rows, 42 worksheets, zero leftover background jobs.

Full detail: [CHANGELOG.md § 2.8.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#280---2026-07-26).

## Previous Release — v2.7.0 — Reporting Leaves `Modules/`, and Collectors Become Data

Released 26 July 2026, published to the PowerShell Gallery. Second phase of the engine rebuild
(Epic **AB#5638**).

**Excel COM is gone.** All 26 inventory report renderers moved out of `Modules/Private/Reporting/`
into `src/report/renderers/`, each file renamed to match the function it defines, and
`Build-AZTIExcelComObject.ps1` was deleted outright — chart styling now runs on EPPlus/ImportExcel
only. COM is why `-Lite` defaulted to true, and why the module surfaced a raw
`0x80040154 REGDB_E_CLASSNOTREG` on every machine and CI runner without Excel installed. Verified
against a live tenant on a machine with no Excel: a 42-worksheet workbook, `SecurityCenter`
carrying 489 rows.

**The first collector category is now data rather than code.** All 13 Databases collectors ship as
`.psd1` definitions interpreted at runtime. Each one is pinned by an equivalence test that runs the
original imperative collector and the declarative definition over the same input, then compares the
processed rows key-by-key *and* the written `.xlsx` cell-by-cell, under both `-IncludeTags` states.
Writing that test caught two defects that would have silently changed shipped reports: tag columns
were being appended rather than inserted, reordering the last three columns of every tagged
worksheet, and `ResourceTypes` was applied as a membership test rather than a grouping.

An AST audit of all 176 collectors now ships alongside it: of the 163 that remain, **115 are
mechanically convertible** and **48 must stay hand-written** — 29 make live cmdlet calls, 20 do
cross-resource joins, 10 never filter `$Resources`, and 2 are unimplemented.

**A single-pass collection layer landed — as capability only.** `src/collect/` gained five
functions and a resource-type map covering 128 ARM types; one raw pass satisfies 34 of the 35
collect queries. But **nothing in the product calls them yet**, so a run still reaches Resource
Graph exactly as often as it did in v2.6.0. Inverting the pipeline onto this layer is **AB#5648**
and is not in this release.

**A defect that had shipped in every release:** an unbound `[string[]]` parameter is `$null`, and
`@($null).Count` is **1**, not 0 — so the subscription-resolution branch in `Invoke-Collect` never
fired on the default path. The subscription list was never derived from `resourcecontainers`, and
every later table degraded to a single un-batched tenant-wide call with none of the documented
per-batch isolation. Same `@($null).Count` class as the empty-Excel-loop bug fixed in v2.6.0.

Full detail: [CHANGELOG.md § 2.7.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#270---2026-07-26).

## Previous Release — v2.6.0 — The Engine Stops Using Background Jobs

Released 25 July 2026, published to the PowerShell Gallery. First phase of the engine rebuild
(Epic **AB#5638**).

The inventory processing phase used to create one `Start-Job` per category, and each of those
created one `[PowerShell]::Create()` runspace **per collector**. Every defect of the v2.5.x wave
lived in that coordination rather than in the collectors themselves: `Start-Job` is asynchronous,
so a job still in `NotStarted` was excluded from the wait, harvested empty and then deleted —
taking its whole category out of the report with no trace. The inner wait read
`$Job.Runspace.IsCompleted`, but those handles have no `Runspace` property, so the loop never
waited at all. Each job re-imported the module, which is why the v2.5.3 StrictMode opt-out needed
**17** entry points. And category ordering came from `Get-Job`, so the same tenant could produce
different reports on consecutive runs.

Collectors are pure functions of the resource set, so none of that concurrency was ever required.
All 176 now run **in-process, in a fixed order**. Identical input produces an identical report
cache — verified against a live tenant across two consecutive full runs: 32 collector sections
compared, **31 byte-identical**, and the single difference checked against Resource Graph and
confirmed as the estate genuinely changing between runs.

Resilience improved rather than regressed: each collector's failure is contained individually, so
one bad collector no longer empties its category or aborts the batch. `Wait-AZSCJob` and the job
machinery are **deleted**; the run orchestration starts no background jobs.

**Four defects that had shipped in every release surfaced the moment collectors ran in-process:**

- The **Security Center worksheet had been empty in every release that had one**.
  `Invoke-AZSCSecurityCenterJob` was called with `-SecurityCenter` against a parameter block that
  declared no such parameter — and PowerShell does not reject an unknown named argument to a
  simple function, it collects it into `$args` and carries on. `$null` crossed the job boundary
  as the security rows. It now carries real data.
- Five collectors called `Write-AZSCLog -Color` / `-Level Verbose`, neither of which the function
  accepted, so each threw on its first log line and produced nothing.
- Per-file `.CATEGORY` filtering had **never matched a single file** — the expression required a
  line break between the keyword and its value, and all 176 collectors write it on one line.
- The Excel report loop invoked every collector whether or not it had data, because it counted
  rows with `@($SmaResources).count` and **`@($null).Count` is 1, not 0**.

Full detail: [CHANGELOG.md § 2.6.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#260---2026-07-25).

## Previous Release — v2.5.3 — Empty Is Not Null, and Runs That Explain Themselves

Released 25 July 2026, published to the PowerShell Gallery.

A full inventory run against a real tenant aborted with `The property 'ReservationRecomen' cannot
be found on this object`. It was not a null-reference fault. The module runs under
`Set-StrictMode -Version Latest` — every `src/*.ps1` sets it at file scope and the `.psm1`
dot-sources them — and under StrictMode, member enumeration over a collection reports a property
as missing when the enumeration yields **nothing at all**. A `$null` value on every element is
fine. An **empty collection** on every element is not: the empties flatten away and nothing
remains. Azure returns `{ "value": [] }` for a subscription with no reservation recommendations,
so a perfectly healthy tenant crashed the run.

Because the fault is data-dependent, 1697 passing tests and three earlier live runs never saw it.

The same class was swept out of the two collectors that filter the mixed `$Resources` array in
module scope — in `Get-AZSCVMQuotas` a bare `$_.subscriptionId` aborted the pipeline, so **no**
subscription got quota data rather than merely the offending one. A diagram job wait that had
never actually waited was fixed (the `.Runspace` no-op v2.5.2 corrected in only one of its two
copies), and an unavailable Cost Management API no longer destroys the whole report.

**Every run now writes a diagnostic log into its own run folder**, with no extra parameter:
`scout-run.log` carries the run metadata, each phase with elapsed time and counts, warnings, and —
on failure — the full error record including the failing script, line number and script stack
trace. `scout-console.log` carries the transcript. It paid for itself during this release: two of
the four defects above were found by reading the log rather than by re-running with `-Debug`.

Full detail: [CHANGELOG.md § 2.5.3](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#253---2026-07-25).

## Earlier Release — v2.5.2 — Determinism

Released 25 July 2026, published to the PowerShell Gallery.

A whole report category could silently vanish from a run. `Start-Job` is asynchronous, so a job
created moments earlier sits in `NotStarted` — a state the wait loop and the batch filter both
ignored, so it was never waited on, then harvested and destroyed before it produced anything.
`Compute.json` came back 5,158 bytes on one run and 470 on the next against an unchanged tenant.

Both now treat every non-terminal state as pending, a dropped category emits a warning naming it
instead of failing silently, and a machine without Excel installed gets a plain one-line
explanation rather than a raw COM `0x80040154` error on a run that otherwise succeeded.

Verified by **three consecutive live runs producing byte-identical results**: 227 Azure resources,
994 Excel rows, 40 Power BI files / 1013 rows, 166 Azure DevOps resources, 0 empty-category
warnings, 0 raw COM errors.

Full detail: [CHANGELOG.md § 2.5.2](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#252---2026-07-25).

## Earlier Release — v2.5.1 — Live-Run Hardening

Released 25 July 2026, published to the PowerShell Gallery.

Seven defects stopped a full `Invoke-AzureScout` run from completing against a real tenant.
Extraction and processing succeeded, then the reporting layer threw *after* every worksheet had
already been built. Fixed: an uninitialised extraction variable, 41 `.IsPresent` reads on
parameters that are not declared `[switch]`, Excel styling and tables applied over empty
worksheets, VM property names the Compute collector never emitted, 29 unguarded worksheet
dereferences, 10 pivot titles read before assignment, and a Markdown string-interpolation bug.

**Every one was found by running the product end to end against live Azure.** The 1692-test suite
passed the whole time, because nothing exercised the extraction, processing and reporting chain
against real collector output. This release also carries the first live-tenant verification of the
`-IncludeDevOps` collectors — 166 resources across 74 projects — which previously had only mocked
tests.

Full detail: [CHANGELOG.md § 2.5.1](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#251---2026-07-25).

## Previous Release — v2.5.0 — One Collection Pass

Released 25 July 2026, published to the PowerShell Gallery.

A combined inventory + assessment run now queries Azure **once** (AB#5543). The inventory pass
already projects the full property bag for every resource, so the assessment shapes its scores
from those rows rather than re-issuing its own Resource Graph pack over the same resource types.
One query still goes to Azure in a combined run — the Defender for SQL pricing lookup, which
reads a table the inventory does not collect. The assessment-only path is unchanged.

Full detail: [CHANGELOG.md § 2.5.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#250---2026-07-25).

## Previous Release — v2.4.0 — One Command, and a Guided Wizard

Released 25 July 2026, published to the PowerShell Gallery.

| Capability | What shipped |
|---|---|
| One entry point | Inventory and assessment are modes of a single `Invoke-AzureScout`, not two cmdlets. `-Assessment` selects the CAF/WAF assessment; `-CollectOnly` and `-FromCollect` moved across too. Assessment mode now honours the inventory sign-in parameters, which the standalone cmdlet never did (AB#5540) |
| Guided wizard | A bare `Invoke-AzureScout` in an interactive session signs you in, lets you pick the tenant, verifies your rights, then offers pre-selected checklists for run type, categories/assessments, formats, and report directory — and prints the equivalent one-liner. Never fires in CI; `-NoWizard` opts out (AB#5541) |
| Output formats | `-OutputFormat` accepts several renderers in one run and spans both modes; a wrong-mode format now throws an error naming the switch you wanted |
| Assessment entry point | The former standalone assessment command is removed in v3.0.0; use `Invoke-AzureScout -Assessment` |
| Documentation | Corrected pages claiming a PowerShell 5.1 floor the module never had, and collapsed the "Inventory vs Assessment" framing across the site |

Full detail: [CHANGELOG.md § 2.4.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#240---2026-07-25).

::: tip Resolved in v2.5.0
The duplicate collection pass described here was collapsed in v2.5.0 (AB#5543) — a combined run
now collects from Azure once.
:::

## v2.3.0 — Collection Hardening & External Platform Integrations

Released 25 July 2026, published to the PowerShell Gallery. Closes the collection-hardening
epic and the external-platform integrations.

| Capability | What shipped |
|---|---|
| Run isolation | Every invocation writes to its own run folder, so a rescan — or a scan of a second tenant — can no longer destroy the previous run's cache or report. `-RunName`, `-Force`, `Clear-AZSCCacheFolder -OlderThan <days>` (AB#331) |
| Azure DevOps inventory | `-IncludeDevOps` adds projects, pipelines, service connections, repositories, and agent pools. The service-connection sheet cross-references each ARM connection against the subscriptions in scope (AB#327) |
| Unattended execution | Composite GitHub Action at the repository root (AB#328); the eight-step [Azure Automation Account](../automation-guide/automation.md) guide plus two runbook upload fixes (AB#343) |
| Reliability | Subscription context restored in a `finally` at all five `Set-AzContext` sites (AB#368); post-login management group access probe naming the role to assign (AB#351) |
| Documentation | [Category Reference](../reference/category-reference.md) (AB#318/5417) and [Validation Matrix](../reference/validation-matrix.md) (AB#315) |

Full detail: [CHANGELOG.md § 2.3.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#230---2026-07-25).

## v2.2.0 — Report Tiers, Deeper Analytics, Hardened Collectors

Four new report tiers, richer visuals on the existing ones, three new offline analysis
functions, deeper collector coverage, and a round of platform hardening on top of v2.1.0.

| Capability | What shipped |
|---|---|
| Report tiers | `Word` (`.docx` via OpenXML, AB#333), `EChartsDashboard` (offline ECharts HTML, AB#344), `Pdf` (dependency-free, AB#379/394/395), `JsonEvidence` (resources-only, AB#396) — all on `Export-Report` / `-OutputFormat` |
| Reporting depth | Excel visual dashboard tabs with pivot charts (AB#322); richer React report — topology diagram, MG hierarchy, 14 KPI cards, Governance section, drill-downs, search/filter, badges, tooltips (AB#376–378, 380, 386, 387, 389–393); `report.pbit` generation (AB#5046) |
| New analysis | `Get-ScoutInventoryDrift` (cross-run resource drift, AB#326), `Get-ScoutCostAnomaly` (cost outliers, AB#324), `Get-ScoutIacGap` (Bicep/IaC coverage gaps, AB#325) — all offline, never call Azure |
| Collect layer | IoT deep coverage — DPS + Digital Twins (AB#330); tag-value aggregation (AB#367); deeper Database/Analytics/IoT rule automation (AB#5068/5071/5075); per-subscription collector/pipeline resilience + live progress (AB#397–402, 405) |
| Config | `Import-ScoutConfig` / `Export-ScoutConfig` (AB#373–375) — save/reload a benchmark + rule-selection + threshold-override config as JSON, with a safe fallback to the built-in default |
| Platform | CI pipeline (AB#317); a real, non-simulated `azure-inventory` workflow (AB#340); module auto-update check (AB#369); login auth banner (AB#349); five v1 inventory bug fixes (AB#335–340); draw.io merge/StrictMode repairs (AB#342); documented Entra Graph delegated scopes (AB#347/338) |

Full detail: [CHANGELOG.md § 2.2.0](https://github.com/thisismydemo/azure-scout/blob/main/CHANGELOG.md#220---2026-07-24).

## v2.1.0 — Platform Hardening

Released 23 July 2026. Native governance collector (AB#5041), unattended
one-command pipeline (AB#5050), and the React report variant + cross-run
drift tracking (AB#5053). See the
[v2.1.0 section](#major-—-v2-1-0-—-platform-hardening-epic-ab-5023-carryover-—-released-2026-07-23)
below for the full breakdown.

## v2.0.0 — CAF/WAF Assessment Platform

Released 23 July 2026. Turns AzureScout from an inventory tool into a read-only
CAF/WAF landing-zone assessment. Runtime-verified offline (Pester) and against a
live Azure tenant.

| Capability | What shipped |
|---|---|
| Assessment engine | Declarative YAML rules (JSONPath + assert types), dual CAF/WAF scoring, prioritized gap list — **139 rules across 8 CAF design areas + 5 WAF pillars** |
| Collect + ingest | Read-only ARG collect layer (`collect.json`); native governance collector (v2.1.0) / ARG query pack / Advisor ingest — AzGovViz retained as opt-in only |
| ALZ benchmark | Live tenant diffed against a canonical ALZ reference |
| Tiered reporting | Power BI, self-contained HTML, executive **PowerPoint (OpenXML SDK — no Python)**, Excel + JSON evidence |
| Per-domain analytics | Every discovery category runnable + tagged: `Invoke-AzureScout -Assessment <Category>` |
| Entry point | `Invoke-AzureScout -Assessment` (run one/some/all), read-only permission pre-flight |

> **Breaking:** introduces the `findings.json` contract and demotes Excel-first
> output to an evidence tier. Assessment features require PowerShell 7.

Deferred to v2.1.0: full per-category rule depth (AB#5061–5075). The native
governance collector (AB#5041), the fully unattended pipeline (AB#5050), and
the React report variant + cross-run drift tracking (AB#5053) shipped in
v2.1.0; four new report tiers, deeper analysis functions, and collector
hardening shipped in v2.2.0 above.

## Previous Release — v1.0.0

Released February 2026.

| Area | What's included |
|------|-----------------|
| Excel Reports | 171 worksheets (154 ARM + 17 Entra ID) covering all 15 Azure resource categories |
| Category Filtering | `-Category` parameter to scope runs to specific resource types |
| AI / ML Coverage | 27 modules: OpenAI, AI Foundry, Azure ML, Cognitive Services, Bot Services, Search |
| AVD Coverage | 6 modules: Host Pools, App Groups, Workspaces, Session Hosts, Scaling Plans, Applications |
| Arc Coverage | Sites, SQL Servers, Data Controllers, SQL Managed Instances, Arc-enabled Kubernetes enhancements |
| VM & Arc Enrichment | Backup status, Site Recovery, Update Manager, Advisor score, Monitor metrics, Cost estimates |
| Monitor Coverage | 24 modules: Diagnostic settings, alert rules, DCRs, App Insights deep data, autoscale, workbooks |
| Markdown / AsciiDoc Export | `-OutputFormat Markdown\|AsciiDoc` generates portable reports alongside Excel/JSON |
| Permission Audit | `Invoke-AZSCPermissionAudit` with ARM + Graph checks, color output, Markdown/AsciiDoc export |
| Subscription & MG Completeness | Captures ALL subscriptions (including empty/disabled) and full MG hierarchy |
| Module Naming | Renamed from *AzureTenantInventory* to *AzureScout* (prefix: `AZSC`) |

## Near-term — v1.1.0

Focus: quality, reliability, and community onboarding.

| Feature | Description | Status |
|---------|-------------|--------|
| Pester test suite | Full unit + integration tests for all public functions and key private functions | :white_check_mark: Done — 1,648 tests across 56 files, run offline |
| PSGallery publish | Publish `AzureScout` module to PowerShell Gallery | :white_check_mark: Done (v2.0.0) |
| GitHub Actions CI | Run Pester tests on PR + push; block merge on failure | :white_check_mark: Done — `ci.yml` runs Pester + PSScriptAnalyzer on every push and PR |
| Category alias documentation | Comprehensive table of all accepted `-Category` aliases and their canonical names | :white_check_mark: Done (v2.3.0, AB#318/AB#5417) — see [Category Reference](../reference/category-reference.md) |
| Resource provider pre-flight | Warn before scan when required providers are not registered in a subscription | :white_check_mark: Done — `-CheckResourceProviders` |
| Throttling / retry improvements | Exponential backoff on 429 responses, honouring `Retry-After`, plus 5xx retry | :white_check_mark: Done — `Invoke-AZSCGraphRequest` (`-MaxRetries`, default 5) |
| `Invoke-AzureScout -WhatIf` | Show which modules would run without actually executing | :x: Won't do (AB#321) — Azure Scout is read-only, so `-WhatIf` has no state change to preview |
| Non-destructive cache | Prevent `ReportCache` and `DiagramCache` from being overwritten on subsequent runs. Each invocation writes to a timestamped (or `-RunName` named) subfolder. Previous scan data is never lost unless `-Force` is specified. `Clear-AZSCCacheFolder -OlderThan <days>` for cleanup. | :white_check_mark: Done (v2.3.0, AB#331) |
| Cross-subscription context restore | Restore the caller's subscription context after every per-subscription loop, including on error | :white_check_mark: Done (v2.3.0, AB#368) |
| Management group access probe | Report management group visibility at login and name the role to assign when it is missing | :white_check_mark: Done (v2.3.0, AB#351) |

### Visual Dashboard Tabs (DarkBlue "overview-style" worksheets)

Phase 10 added raw data tabs (Cost Management, Security Overview, Azure Update Manager, Azure Monitor) that collect data into flat tables. The next step is to add **visual dashboard tabs** — styled like the Overview sheet (DarkBlue tab color, EPPlus shapes, pivot charts) — that summarize and visualize the data from those raw tabs.

| Dashboard | Charts / Visualizations | Status |
|-----------|-------------------------|--------|
| Cost Dashboard | Cost by Resource Type (bar), Cost by Subscription (pie), Cost by Region (column), Cost by SKU (bar) | :blue_circle: Planned |
| Security Dashboard | Assessments by Severity (pie), Findings by Subscription (bar), Defender Plans (column), Active Alerts by Severity (bar) | :blue_circle: Planned |
| Update Manager Dashboard | Machines by Platform (pie), Machines by OS Type (pie), Machines by Region (column), Machines by Power State (bar), Machines by Subscription (bar) | :blue_circle: Planned |
| Monitor Dashboard | Alert Rules by Subscription (bar), Action Groups by Subscription (pie), DCRs by Subscription (column), App Insights by Subscription (bar) | :blue_circle: Planned |

Each dashboard tab will:

- Use DarkBlue tab color (matching Overview, Subscriptions, Advisor)
- Be pinned after the Overview sheet group via `MoveAfter` in the ordering function
- Contain EPPlus pivot tables + charts generated by `Build-AZSCDashboardTabs`
- Only appear when the corresponding raw data tab has data (no empty dashboards)

## Medium-term — v1.2.0

Focus: depth, breadth, and multi-tenant scenarios.

| Feature | Description | Status |
|---------|-------------|--------|
| Multi-tenant scanning (Lighthouse) | `-TenantID` accepts multiple tenant IDs. Authenticates to each tenant sequentially, runs the full extraction → processing → reporting pipeline per tenant. Supports combined workbook (with Tenant column) or separate per-tenant workbooks via `-MergeOutput` switch. Auth failure on one tenant does not block others. The run-isolation prerequisite shipped in v2.3.0 (AB#331). | :bulb: Idea (AB#323) |
| Word document export (#22) | Shipped as `-OutputFormat Word` in assessment mode: `Export-Word` generates a self-contained `.docx` via OpenXML, no Python. | :white_check_mark: Done (v2.2.0, AB#333) |
| PDF report export (#23) | Shipped as `-OutputFormat Pdf` in assessment mode: `Export-Pdf` is a hand-rolled, dependency-free renderer (cover, executive summary, per-area findings table, gaps, manual review). | :white_check_mark: Done (v2.2.0, AB#379/394/395) |
| Cost anomaly detection | Shipped as the offline `Get-ScoutCostAnomaly` function (v2.2.0) — flags statistical outliers (spike/z-score/IQR) in an already-collected cost dataset; never calls Azure. | :white_check_mark: Done (v2.2.0, AB#324) |
| Bicep / IaC gap detection | Shipped as the offline `Get-ScoutIacGap` function (v2.2.0) — compares discovered resources against a folder of Bicep/ARM-JSON templates and flags unmanaged resources; never calls Azure. | :white_check_mark: Done (v2.2.0, AB#325) |
| Resource drift reporting | Shipped as the offline `Get-ScoutInventoryDrift` function (v2.2.0) — compares the current `collect.json` against the previous run's snapshot and reports Added/Removed/Changed resources. | :white_check_mark: Done (v2.2.0, AB#326) |
| Azure DevOps integration | Shipped as `-IncludeDevOps` (v2.3.0) — inventories projects, pipelines, service connections, repositories, and agent pools across one or more organizations, adding five worksheets. Authentication reuses the current Azure sign-in; `-DevOpsPat` covers a separate identity. The ADO Service Connections sheet cross-references each ARM connection against the subscriptions in scope. | :white_check_mark: Done (v2.3.0, AB#327) |
| GitHub Actions module | Shipped as a composite `action.yml` at the repository root (v2.3.0) — `uses: thisismydemo/azure-scout@v2` installs the module, authenticates, collects, and uploads reports as an artifact. | :white_check_mark: Done (v2.3.0, AB#328) |
| Azure Automation Account | Shipped as first-class unattended execution (v2.3.0) — the eight-step setup guide now exists, plus fixes for the blob-upload collision on a second scheduled run and the diagnostic log that never uploaded. | :white_check_mark: Done (v2.3.0, AB#343) |
| Fabric / Power BI export (#17) | `-OutputFormat PowerBI` generates a flat normalized CSV bundle (`PowerBI/` folder) with `_metadata.csv`, `Subscriptions.csv`, per-module `Resources_*.csv` and `Entra_*.csv` files, and a `_relationships.json` star-schema manifest for Power BI Desktop / Microsoft Fabric | :white_check_mark: Done |
| IoT deep coverage | Shipped in the assessment Collect layer (v2.2.0) — `Invoke-Collect` gains Device Provisioning Service and Azure Digital Twins queries; new `caf.iot` rules score them. | :white_check_mark: Done (v2.2.0, AB#330) |

## Major — v2.0.0 — CAF/WAF Assessment Platform (Epic AB#5023) — Delivered

Turned inventory into a **scored CAF/WAF landing-zone assessment**. Collection stays as-is; a three-layer, JSON-on-disk architecture (`collect.json` → `findings.json` → deliverables) adds assessment and rebuilds reporting. Read-only throughout. **Shipped in v2.0.0 (2026-07-23).**

| Capability | Description | Status |
|---|---|---|
| Assessment engine | Declarative YAML rules (JSONPath + assert types), dual CAF/WAF scoring, prioritized gap list | :white_check_mark: Done (AB#5027, AB#5034) |
| CAF/WAF rule content | 8 CAF design areas + 5 WAF pillars — 139 rules across 23 version-controlled files | :white_check_mark: Done (AB#5031, AB#5057) |
| Ingest layer | Fold an ARG query pack and Advisor into one `collect.json`; governance now ingested natively by default (see v2.1.0 below) — Azure Governance Visualizer remains available as an opt-in ingestor | :white_check_mark: Done (AB#5037) |
| ALZ benchmark diff | Compare the live tenant against a canonical ALZ reference (MG archetypes, required policies) | :white_check_mark: Done — engine + native governance collection, no upstream AzGovViz dependency (AB#5041, v2.1.0) |
| Tiered reporting | Power BI (primary), self-contained HTML, executive PPTX (OpenXML SDK); Excel/JSON retained as evidence | :white_check_mark: Done (AB#5044) |
| Module registry + entry point | `-Assessment` run one/some/all; read-only permission pre-flight | :white_check_mark: Done (AB#5024); unattended one-command pipeline :white_check_mark: Done (AB#5050, v2.1.0) |
| React report + drift tracking | Richer React report variant and cross-run score-drift tracking | :white_check_mark: Done (AB#5053, v2.1.0) |

## Major — v2.1.0 — Platform Hardening (Epic AB#5023 carryover) — Released 2026-07-23

Three more Epic AB#5023 capabilities shipped ahead of the full per-domain
analytics epic below. Tagged and released as `v2.1.0` — see
[`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md)
for the build ledger.

| Capability | Description | Status |
|---|---|---|
| Native governance collector | `Import-Governance` replaces the AzGovViz hard dependency as the **default** governance collector — populates `collect.json`'s `governance` object natively from Azure Resource Graph and ambient-token ARM REST, needing only Reader at the management-group root. No cloned repo, no `AzAPICall` install prompt, fully unattended, StrictMode-safe. Live-verified against the HCS tenant. `AzGovViz` remains available as an opt-in `Ingest` value; nothing depends on it by default anymore. | :white_check_mark: Done (AB#5041) |
| Unattended pipeline | `Invoke-ScoutPipeline` runs collect → assess → report headless into one dated run folder — non-interactive throughout, runs the read-only permission pre-flight first, and degrades to `PartialSuccess` (rather than losing output) if an exporter fails. Writes `pipeline-summary.json`/`.md`. | :white_check_mark: Done (AB#5050) |
| React report + cross-run drift | `-OutputFormat React` renders a single self-contained `report-react.html` (client-side filter/sort/search, summary dashboard, Drift tab). `Get-ScoutDrift` computes cross-run New / Resolved / Regressed / Unchanged findings plus a weighted score delta, tracked in an append-only `.scout-history/findings-history.json`. | :white_check_mark: Done (AB#5053) |

Not included in v2.1.0: full per-category rule depth (AB#5061–5075) — tracked
below. Four new report tiers, richer report visuals, and three new offline
analysis functions shipped in v2.2.0 next.

## Major — v2.2.0 — Report Tiers, Deeper Analytics, Hardened Collectors

Delivered on `main` — not yet tagged/published, see
[`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md)
for cut status.

| Capability | Description | Status |
|---|---|---|
| Report tiers — Word/ECharts/PDF/JSON evidence | `Export-Word` (`.docx` via OpenXML), `Export-EChartsDashboard` (offline ECharts HTML, no CDN), `Export-Pdf` (hand-rolled, dependency-free), `Export-JsonEvidence` (resources-only JSON, no assessment metadata/scores). All wired into `Export-Report`, `Invoke-AzureScout -Assessment`, and `Invoke-ScoutPipeline`. | :white_check_mark: Done (AB#333, AB#344, AB#396, AB#379/394/395) |
| Excel visual dashboard tabs | Native ImportExcel PivotTable/PivotChart dashboard sheets in the assessment Excel evidence tier: Findings-by-Severity (pie), Score-by-Area (column), Pass-Fail-Manual (stacked column), Resource-Counts (bar) — omitted when a sheet's data is empty. | :white_check_mark: Done (AB#322) |
| Richer React report + `report.pbit` | The self-contained `report-react.html` gains a vis.js VNet topology diagram, an MG-hierarchy diagram, 14 KPI cards, an Azure Firewall drill-down, a Governance section (budgets/locks/tag chips), a policy-enforcement badge, per-section search/filter, clickable rows with a side panel, and scope tooltips. The Power BI tier also generates a `report.pbit` bound to the star-schema CSVs. | :white_check_mark: Done (AB#376–378, 380, 386, 387, 389–393, AB#5046) |
| Cross-run resource drift | `Get-ScoutInventoryDrift` — offline, compares the current `collect.json` against the previous run and reports Added/Removed/Changed resources, complementing the existing findings-level `Get-ScoutDrift` (v2.1.0). | :white_check_mark: Done (AB#326) |
| Cost anomaly detection | `Get-ScoutCostAnomaly` — offline, flags statistical outliers (month-over-month spike, z-score, IQR) in an already-collected cost dataset. | :white_check_mark: Done (AB#324) |
| Bicep / IaC gap detection | `Get-ScoutIacGap` — offline, compares discovered resources against a folder of Bicep/ARM-JSON templates (best-effort text/JSON parsing) and flags resources not represented in any template. | :white_check_mark: Done (AB#325) |
| IoT deep coverage | `Invoke-Collect` gains Device Provisioning Service and Azure Digital Twins queries; new `caf.iot` rules score them. | :white_check_mark: Done (AB#330) |
| Tag aggregation | `Invoke-Collect` aggregates tag values to their unique set per key across subscriptions instead of last-write-wins. | :white_check_mark: Done (AB#367) |
| Database/Analytics/IoT rule depth | New `sqlDefenderPricing`/`purviewAccounts` collect queries plus `iotHubs.disableLocalAuth`; CAF-DB-04, CAF-ANL-02, and new CAF-IOT-06 flip from `Manual` to automated. | :white_check_mark: Done (AB#5068, AB#5071, AB#5075) |
| Collector/pipeline resilience + progress | Per-subscription try/catch/continue in `Invoke-Collect`; a management-group role-requirement hint on RP/authorization errors; an empty-data guard; a pipeline `HadErrors` summary flag; live `Write-ScoutProgress` output during collection. | :white_check_mark: Done (AB#397–402, AB#405) |
| Assessment config load/save | `Import-ScoutConfig` / `Export-ScoutConfig` — load/save an alternative benchmark, rule-selection patterns, and per-rule threshold overrides as JSON; never throws on a bad file (falls back to the built-in default with a warning). | :white_check_mark: Done (AB#373–375) |
| Platform hardening | CI pipeline (`ci.yml`); a real, non-simulated `azure-inventory` workflow; module auto-update check on import; UPN/subscription auth banner; five v1 inventory bug fixes; draw.io merge/StrictMode repairs; documented Entra Graph delegated scopes. | :white_check_mark: Done (AB#317, AB#340, AB#369, AB#349, AB#335–340, AB#342, AB#347/338) |

Not yet included: full per-category rule depth (AB#5061–5075) — tracked below
under Epic AB#5056.

## Major — v2.1.0 — Per-Domain CAF/WAF Analytics (Epic AB#5056)

Focus: extend CAF/WAF analytics to **every** Scout category, not just the landing-zone roll-up. Each of the 15 discovery categories becomes an **independently runnable, categorized and tagged assessment** — so you can run and score *just* Governance, *just* Monitoring, *just* Update Manager, etc.

| Capability | Description | Status |
|---|---|---|
| Assessment taxonomy & tagging | Manifest gains `Category` / `Frameworks` / `Tags`; `-Assessment <Category>` runs scoped discovery + scoped scoring; sub-bundles (Governance/Policy/UpdateManager under Management, Monitoring under Monitor) | :blue_circle: Planned (AB#5057) |
| Per-category coverage | CAF/WAF rule coverage authored for each category — Management, Monitor, Networking, Identity, Security, Compute, Storage, Databases, Containers, Web, Analytics, AI, Integration, Hybrid, IoT | :blue_circle: Planned (AB#5061–AB#5075) |
| Registry document | A table of every possible assessment: category, sub-bundles, CAF areas, WAF pillars, tags | :blue_circle: Planned (AB#5057) |

See [`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md) for the build/release ledger.

## Far-future — Web version of Azure Scout (Epic AB#5093)

> A **web-UI version with the same capabilities as the PowerShell version** — same engine,
> browser instead of terminal. **Far-future, not scheduled.** Only the web-only plumbing
> (server, runspace, progress polling, launchers) is unique to it. The actual product features
> are **buildable in the PowerShell version now** (Epic AB#5094) and the web version inherits them.


> **Status: under evaluation — NOT committed.** This is a possible future direction, not
> planned work, and it would be a **departure from the current "no portals" stance** in the
> [Long-term Vision](#long-term-vision) below. Captured here so the direction is tracked and
> can be decided deliberately rather than drifting into the backlog.

A **served web-application** as a **second delivery surface** for the same engine — not a
different product. It would run a local HTTP listener with a browser UI (background-runspace
collection with live progress, interactive vis.js topology, in-browser PDF export, config
upload/download). **The web portal must reach FEATURE PARITY with the PowerShell version** —
every product feature is available through both surfaces; neither has a feature the other
lacks. Only the *delivery plumbing* below is web-specific. It is weeks of net-new engineering
(web server + JS front-end + IPC layer).

**Web delivery surface — plumbing only (Epic AB#5093, exploratory):**

| Area | Web-surface plumbing (no PowerShell equivalent) | Status |
|---|---|---|
| Server core | HTTP listener + background runspace, file-based progress IPC (client polls), named stages %, concurrent-collection guard, cached-inventory serving, runspace disposal, double-poll guard | :bulb: Exploratory (AB#381–385, 403, 404) |
| Launchers | `start.cmd` / `start.sh` to launch the server | :bulb: Exploratory (AB#388) |

### Feature parity — shared across both surfaces (Epic AB#5094)

The product **features** below are **not web-only or PowerShell-only — they belong to both
surfaces**. They live in the core product and are surfaced through the PowerShell module (CLI +
static/React reports) *and* the web portal. Same capability, per-surface delivery:

- **Report visuals** (in the React/HTML report today, and the web portal later): vis.js VNet
  topology + click-to-details + reset/fit controls, MG-hierarchy diagram, per-section
  search/filter, clickable rows + side panel, 14 KPI cards, Azure Firewall drill-down,
  Governance section (budgets/locks/tag chips), policy-enforcement badge, scope tooltips,
  resources-only JSON evidence export (AB#376–378, 380, 386, 387, 389–393, 396). *Several
  partially exist in the React report already — extend them.*
- **WAF config load/save + report PDF export** (PowerShell via parameters/file output; web via
  browser upload/download + in-browser render) (AB#373–375, 379, 394, 395).
- **Collector / pipeline resilience** (shared engine): per-subscription try/catch/continue, MG
  role-requirement hint, false RP-registration-error swallow, per-group firewall-parse-error
  logging, empty-data guard, pipeline-`HadErrors` warning capture (AB#397–402).
- **Live-progress UX** — same feature, per-surface delivery: Spectre.Console TUI in the CLI,
  browser progress in the web portal (AB#405).

## Long-term Vision

AzureScout aims to be the definitive open-source Azure visibility tool for:

- **Architects** — understand the full shape of a tenant before designing changes
- **Security teams** — identify misconfigured, unmonitored, or over-privileged resources
- **FinOps practitioners** — surface cost waste, reservation opportunities, and untagged resources
- **Managed service providers** — generate client-ready reports across multiple tenants

The tool will remain **open-source, PowerShell-native, and Excel-friendly** — no agents, no portals, no licensing fees.

## Completed Phases

All implementation phases from the original migration plan are complete.
See the [Changelog](./changelog.md) for the full history.

| Phase | Summary |
|-------|---------|
| Phase 1-9 | Core engine, module loading, Excel generation, JSON output, Draw.io diagrams, auth methods, connection handling, permission pre-flight |
| Phase 10 | Specialized Excel tabs: Cost Management, Security Overview, Azure Update Manager, Azure Monitor |
| Phase 11 | All-subscriptions + full MG hierarchy enumeration |
| Phase 12 | ARM-only default scope, permission documentation, README overhaul |
| Phase 13 | 15 new Azure Monitor/Insights modules |
| Phase 14 | 15 new AI/ML modules |
| Phase 15 | 6 AVD modules + AVD on Azure Local/Arc detection |
| Phase 16 | Arc site configs, Arc SQL Server, Arc Data Services enhancements |
| Phase 17 | VM + Arc deep enrichment (metrics, backup, DR, cost, advisor) |
| Phase 18 | Category folder alignment + `.CATEGORY` metadata parsing |
| Phase 19 | Richer progress indicators, clear permission error messages |
| Phase 20 | `Invoke-AZSCPermissionAudit` + `Test-AZSCPermissions` refactor |
| Phase 21 | Markdown + AsciiDoc export, `Export-AZSCMarkdownReport`, `Export-AZSCAsciiDocReport` |

## Suggest a Feature

Open an issue at [github.com/thisismydemo/azure-scout/issues](https://github.com/thisismydemo/azure-scout/issues) with the label `enhancement`.

Pull requests are welcome — see [Contributing](./contributing.md) for guidelines.

## Fork Attribution

::: info Fork Attribution
**AzureScout is a fork of [Azure Resource Inventory (ARI)](https://github.com/microsoft/ARI)** by Microsoft, originally created by [Claudio Merola](https://github.com/Claudio-Merola) and [Renato Gregio](https://github.com/RenatoGregio). The ARI project provided the entire foundation that AzureScout builds upon — its ARM inventory module set, the draw.io diagram engine, Excel reporting, and more. AzureScout is now at 240 collector definitions across all 18 Azure service categories — see [ARM Modules](../reference/arm-modules.md) and [Entra ID Modules](../reference/entra-modules.md). We are deeply grateful for their work.

See [Credits & Attribution](./credits.md) for full details, or [Differences from ARI](./ari-differences.md) for what has changed.
:::
