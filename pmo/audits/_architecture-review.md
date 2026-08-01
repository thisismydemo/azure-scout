# Architecture review — "one collection engine, collect once"

Reviewed 2026-07-31 against `main` (working tree at ee839e3 + 4 modified files, none of them on the paths below).

## Verdict

The direction is right, and most of it is already built — you are closer than the framing suggests. There is exactly one raw Resource Graph engine today (`Get-ScoutRawInventory`), and both the inventory pipeline and the assessment collector call it. What is *not* true is "collect once": the assessment layer still runs a second, redundant round of Azure calls after the collector finishes, in the `Ingest` phase, and one of those ingestors (`ArgQueryPack`) re-fetches six datasets the collector already has and then **overwrites the collector's better copies with worse ones**. Separately, the combined "inventory AND assessment" run only exists through the interactive wizard — from the command line `-Assessment` returns before the inventory pass ever starts, so the "both" case you are designing for is not reachable non-interactively. The one place the design needs adjustment is the carve-out: you named Azure Policy compliance state as the example of "genuinely not inventory", and it is the opposite — inventory already fetches it (`policyStates/latest/summarize`) and the assessment ignores it. The carve-out should be drawn by *API surface* (what ARG cannot index), not by *product surface*.

---

## What the code does today

### There is one raw engine, and it is shared

`Start-AZSCGraphExtraction` — the inventory pipeline's Resource Graph layer — no longer contains any query text. It is a parameter-translation shim:

- `src/collect/Start-ScoutGraphExtraction.ps1:1-33` — "It now builds no queries and issues no Resource Graph call."
- `src/collect/Start-ScoutGraphExtraction.ps1:69-90` — maps the legacy inventory parameters onto `Get-ScoutRawInventory` and returns its result under the field names the inventory pipeline expects.

The assessment collector calls the same function:

- `src/collect/Invoke-Collect.ps1:690-709` — when no `-FromInventory` was supplied and `-Source` is `Inventory` (the default), `Invoke-Collect` dot-sources and calls `Get-ScoutRawInventory` itself.

So "one collection engine" is **already true at the raw-ARG layer**. The difference between the two callers is switches: inventory asks for eleven extra tables (`Start-ScoutGraphExtraction.ps1:71-82` — support, backup, AVD, update manager, retirements, advisories, security center, ARM child resources, tenant-wide, subscription security policy, operational enrichment); the assessment path asks for three tables plus tags (`Invoke-Collect.ps1:707`). That is the correct shape for a shared engine.

### The 35 → 4 work (AB#5648) is real, and it covered the assessment half

`ConvertFrom-ScoutInventory` shapes **34 of the 35** collect datasets from raw rows — verified by enumerating its assignment targets: `aksClusters, apiManagement, arcExtensions, arcServers, azureFirewalls, azureLocalClusters, cognitiveAccounts, containerRegistries, deployments, diagnosticCoverage, digitalTwinsInstances, dpsInstances, eventHubNamespaces, firewallPolicyRuleGroups, iotHubs, keyVaults, logAnalyticsWorkspaces, nsgPublicInbound, orphanedDisks, orphanedPips, privateDnsZones, privateEndpoints, purviewAccounts, serviceBusNamespaces, sqlDatabases, sqlServers, storageAccounts, subnets, subscriptions, synapseWorkspaces, virtualMachines, virtualNetworks, vpnGateways, webApps`.

The one that is not derivable is `sqlDefenderPricing`, because it reads the `SecurityResources` table rather than `resources` (`Invoke-Collect.ps1:364-368`, rationale at `:681-686`). The skip logic is `Invoke-Collect.ps1:768` — `if ($inventoryShaped.ContainsKey($k)) { $r[$k] = @($inventoryShaped[$k]); continue }`, i.e. no Azure call for anything already shaped.

**So the answer to "once or twice" is: the *collector* queries once. The *ingest* phase then queries again.**

### The duplication that remains is in `Ingest`, and it is unconditional

`src/Invoke-ScoutAssessmentCore.ps1:124-139` runs the manifest's `Ingest` list after `Invoke-Collect` returns, with no awareness of whether the data was already collected — including when `-FromInventory` was supplied.

**`ArgQueryPack` (`src/ingest/Invoke-ArgQueryPack.ps1:19-62`) — six queries, six duplicates:**

| ArgQueryPack query | Already collected by `Invoke-Collect` |
|---|---|
| `subnetIpUsage` (:20) | `subnets` (`Invoke-Collect.ps1:239`) |
| `orphanedDisks` (:30) | `orphanedDisks` (`Invoke-Collect.ps1:316`) |
| `orphanedPips` (:35) | `orphanedPips` (`Invoke-Collect.ps1:320`) |
| `diagCoverage` (:40) | `diagnosticCoverage` (`Invoke-Collect.ps1:324`) |
| `publicExposure` (:46) | `nsgPublicInbound` (`Invoke-Collect.ps1:288`) |
| `nonZonalVms` (:55) | `virtualMachines.zoneRedundant` (`Invoke-Collect.ps1:297`) |

This is not merely wasted work — it is **destructive**. `Invoke-ArgQueryPack.ps1:87-95` writes its results over the collector's with `Add-Member -Force`, and its copies are strictly worse:

- `subnetIpUsage` (:28) computes `round(todouble(used)/total*100,1)` with **no divide-by-zero guard**. The collector's version has one: `iff(total > 0, ..., todouble(0))` (`Invoke-Collect.ps1:247`). A `/31` or `/32` subnet makes `total` zero or negative.
- `orphanedDisks` (:33) projects `sku = sku.name` and `sizeGb = properties.diskSizeGB` untyped; the collector projects `tostring(sku.name)` / `toint(...)` (`Invoke-Collect.ps1:318`).
- `diagCoverage` (:44) has no `total > 0` guard either; the collector's does (`Invoke-Collect.ps1:328`).
- `nonZonalVms` is queried and **never merged into `$Collect` at all** (nothing in :78-96 references it). It is a pure wasted round-trip on every run of the 15 assessments that declare `ArgQueryPack`.

There is a comment at `:79-83` recording that a previous `-Force` replace already caused a live incident (wiped `networking`, false-failed CAF-SEC-03/06). The same hazard is still present for the four properties it does replace.

**`Governance` (`src/ingest/Import-Governance.ps1:82-138`)** — three ARG queries (`resourcecontainers` for management groups, `policyresources`, `authorizationresources`) plus two ARM REST calls **per subscription** (budgets `:123`, locks `:132`). Of these:
- Management groups: `resourcecontainers` is a table the raw pass already reads (`Get-ScoutRawInventory` collects containers first), but the raw pass filters to subscriptions/resource groups, not `microsoft.management/managementgroups` — so this is *nearly* a duplicate but not literally one today.
- `policyresources` / `authorizationresources`: genuinely different ARG tables, not collected by the raw pass. **Legitimately assessment-only under the current raw-pass switches.**
- Budgets and locks: not ARG-indexed at all (`:114-116`). **Legitimately non-inventory.**

**`AdvisorScores` (`src/ingest/Import-AdvisorScores.ps1:16-24`)** — enumerates subscriptions and calls `Get-AzAdvisorRecommendation` per subscription. Inventory already collects Advisor rows from the `advisorresources` ARG table (`Start-ScoutGraphExtraction.ps1:76,94` → `$Raw.Advisories`, surfaced as `$ExtractionData.Advisories`). In a combined run this is a straight duplicate of data already in memory, fetched by a slower API.

It also has a side effect worth fixing regardless: `:21` calls `Set-AzContext` inside the loop and never restores the caller's original context. Anything that runs after an assessment in the same session inherits whichever subscription happened to be last.

### `-Assessment` alone does *not* run the full inventory collection

`src/Invoke-AzureScout.ps1:565` enters assessment mode on `-Assessment`, `-CollectOnly` or `-FromCollect`, and `:595` `return`s from `Invoke-ScoutAssessmentCore` before the inventory pipeline at `:833-843` is ever reached. The assessment's own collect asks `Get-ScoutRawInventory` for three tables + tags, not the eleven-switch inventory pass. This is correct behaviour and matches your design.

### The combined run exists, but only through the wizard

`src/Invoke-AzureScout.ps1:594` — `if ($wizardRunBoth) { $deferredAssessArgs = $assessArgs }` — and `$wizardRunBoth` is set from exactly one source: `:557`, `$wizard.RunBoth`, produced by `src/Start-AZSCWizard.ps1:280`. There is no parameter that sets it. The deferred handoff at `:842-843` passes `$ExtractionData` (which carries `.Resources` / `.ResourceContainers`, `Start-AZTIExtractionOrchestration.ps1:188-192`) into `Invoke-ScoutAssessmentCore -FromInventory`, and `Invoke-Collect.ps1:725-727` reads exactly those two properties.

So collect-once for the "both" case is implemented — but a scripted or CI caller cannot reach it. `Invoke-AzureScout -Assessment LandingZone -OutputFormat All` does not produce an inventory report; it errors or returns only the assessment run folder.

**One live defect in that handoff:** `Invoke-Collect` forces `IncludeTags = $true` on its *own* raw pass and documents why (`Invoke-Collect.ps1:700-707`: without it the canonical `tags` key is silently empty). The inventory pass sets `IncludeTags = [bool]$IncludeTags` (`Start-ScoutGraphExtraction.ps1:81`), defaulting to false. So a wizard "both" run **without** `-IncludeTags` hands the assessment rows with no `tags` column, and `ConvertFrom-ScoutInventory.ps1:135` reads `tags` off the container row — producing an empty `collect.tags` aggregation. The assessment-only path gets tags; the collect-once path silently does not.

### Other collect paths

`src/collect/` also holds `Get-ScoutApiResources`, `Get-ScoutVmQuotas`, `Get-ScoutVmSkuDetails`, `Get-ScoutCostInventory`, `Get-ScoutSubscriptionSecurityPolicySweep`, `Get-ScoutTenantWideResource`, `Get-ScoutManagementGroups`, `Start-ScoutEntraExtraction`, `Start-ScoutDevOpsExtraction`. All are driven from `Start-AZTIExtractionOrchestration.ps1:67-169` — the **inventory** side only. None is reachable from the assessment path. There is no collect path reachable only from the assessment side other than the three ingestors above and the single `sqlDefenderPricing` query.

---

## Assessment of the design

### Where it is right

**"One collection engine" is the correct call**, and the objections that usually justify a second one do not apply here:

- *Different scoping* — handled by parameters (`-SubscriptionIds`, `-ManagementGroupName`, `-ResourceGroups`, `-TagKey/-TagValue`), already threaded through both callers.
- *Different point-in-time semantics* — both paths are read-only snapshots of the same ARG index. There is no case where the assessment wants a *different instant* than the inventory in the same invocation; if anything, a shared instant is what makes the two reports defensible against each other.
- *Data that only makes sense when scoring* — this is real, but it is a small set (below), and it is an argument for extra *fetches*, not a second *engine*.

**The pipeline shape it implies — collect → (report | score | both) — is already the actual shape of the code**, not a refactor target. `Invoke-Collect` returns a data structure; `Invoke-Assessment` consumes it (`src/assess/Invoke-Assessment.ps1:13-22` takes `$Collect` and never queries Azure); `Export-Report` consumes findings + collect (`Invoke-ScoutAssessmentCore.ps1:194`). The separation does not leak on the assess side at all. It leaks on the *collect* side, in `Ingest`.

**Refusing a second scoring-only collection path is worth defending on correctness grounds, not just cost.** Today a combined run can produce an inventory report saying one thing and an assessment saying another about the same resource, because the ingestors re-query and can observe a different state seconds later. Collect-once makes the two artefacts consistent by construction.

### Where it needs adjustment

**1. The carve-out example is wrong. Policy compliance state is already inventory data.**

`src/collect/Get-ScoutApiResources.ps1:150-157` — the inventory pass calls `Microsoft.PolicyInsights/policyStates/latest/summarize`, `Microsoft.Authorization/policySetDefinitions` and `Microsoft.Authorization/policyDefinitions` per subscription, and returns them as `PolicyAssignments` / `PolicyDefinitions` / `PolicySetDefinitions` (`:168-172`), surfaced on `$ExtractionData.PolicyAssign` / `.PolicyDef` / `.PolicySetDef` (`Start-AZTIExtractionOrchestration.ps1:186-192`). Note the field name `PolicyAssignments` actually holds the *compliance summary*, not assignments.

Meanwhile the assessment's `Governance` ingestor fetches policy *assignments* from ARG `policyresources` (`Import-Governance.ps1:95-99`) and never sees the inventory's compliance data. So today: inventory has compliance state and does not score it; assessment has assignments and cannot see compliance. The example you chose to justify the carve-out is in fact the strongest case *for* sharing.

**Draw the line by API surface instead:** an assessment-specific fetch is legitimate when the data is *not in the ARG tables the raw pass reads* — not when it is "assessment-flavoured". By that test the honest list is:

- `SecurityResources` / `microsoft.security/pricings` — Defender plan tiers (`Invoke-Collect.ps1:364`). Inventory can reach this table but only under `-SecurityCenter`, and then filters to assessments.
- `policyresources`, `authorizationresources` — genuine additional ARG tables.
- Consumption budgets, resource locks — not ARG-indexed (`Import-Governance.ps1:114-116`).
- PIM eligibility, Conditional Access, classic administrators — Graph/Entra, currently stubbed to `@()` (`Import-Governance.ps1:155-156`).
- Metric-backed signals (Azure Monitor time series for right-sizing) — a genuinely different data plane, and the one case where "point in time" really does differ: a metric needs a *window*, not an instant.

The cleaner formulation of your rule: **the raw pass is parameterised by which tables it reads; assessment turns on the tables it needs. A separate fetch is only permitted for a data plane the raw pass structurally cannot cover.** That collapses items 1–3 above into switches on the one engine and leaves only Graph and Monitor as true carve-outs.

**2. Failure semantics — the current answer is "score silently on partial data", and that is the wrong default.**

Every layer degrades quietly: `Invoke-Collect.ps1:628-671` warns and retries per subscription, then returns whatever it got; `:656` returns an empty array when there is no subscription list; `Import-Governance.ps1:89,101,112,129,138` warns and continues with empty sets. The only guard is a warning when *literally everything* is empty (`Invoke-Collect.ps1:829-831`). A rule that reads an empty array does not distinguish "no such resource exists" from "we could not see it" — so a partially-blind collect produces a *better-looking* score, which is the worst possible failure direction for an assessment product.

Recommendation: `collect.json` should carry per-dataset provenance (`collected` / `partial` / `failed`, with the scope that failed), and findings derived from a `failed` dataset should be emitted as `Unknown`, not `Pass`. Refusing to score outright is too blunt — a Reader gap in one subscription should not void the tenant — but silently passing is worse than either.

**3. `Estate` is an inventory product living inside the assessment manifest.**

`manifests/assessments.psd1:37-46` — `Estate = @{ Description = 'Full digital estate inventory (no scoring)'; Rules = @(); Reporters = @('Excel','PowerBi') }`. It is also the default when `-CollectOnly` is used with no `-Assessment` (`Invoke-AzureScout.ps1:577`). If "assessment means CAF/WAF, full stop", this entry contradicts the terminology in the one file that defines the vocabulary, and it gives you a *third* inventory-shaped output path (assessment-mode Excel from `collect.json`) distinct from both the real inventory report and the CAF/WAF report.

**4. Cache reuse across runs is the right idea, and nothing implements it.**

`-FromCollect` (`Invoke-ScoutAssessmentCore.ps1:103-105`) already lets you re-assess a saved `collect.json`, which is the assessment half of AB#6483. The inventory half does not exist: `ReportCache` is a within-run scratch directory, cleared at the start (`Invoke-AzureScout.ps1:827`) and again at the end (`:1035`) of every run, and `Write-ScoutCacheFile` writes per-category rows for the reporting phase only. No code in the repo references AB#6483 outside `RELEASES.md`.

The design question worth settling *before* building it: a cached collect must carry its scope and switch set, or a resumed run will silently assess a narrower estate than the operator believes. `collect.json` already records `_meta.scope` / `categories` / `managementGroupId` (`Invoke-Collect.ps1:920-923`); a raw-inventory cache needs the same, plus the `Include*` switches, plus an age, with a refusal (not a warning) when the requested scope exceeds the cached scope.

---

## Gap analysis — what assessment needs that inventory does not collect today

| Need | Status | Where |
|---|---|---|
| Defender plan tiers (`microsoft.security/pricings`) | Assessment-only; inventory reads `securityresources` only under `-SecurityCenter` and filters to assessments | `Invoke-Collect.ps1:364-368`, `:681-686` |
| Policy assignments with `properties` (`policyresources`) | Assessment-only ARG table; raw pass does not read it | `Import-Governance.ps1:95-99` |
| Role assignments (`authorizationresources`) | Assessment-only ARG table | `Import-Governance.ps1:106-110` |
| Management group hierarchy | Fetched twice by different code — `Import-Governance.ps1:82-87` for assessment, `Get-ScoutManagementGroups` / `ConvertTo-ScoutManagementGroupHierarchy` for inventory | both |
| Consumption budgets, resource locks | Not ARG-indexed; per-subscription ARM REST. Genuine carve-out | `Import-Governance.ps1:121-138` |
| PIM eligibility, classic administrators | Declared in the contract, hard-coded empty. Rules reading them see "none" | `Import-Governance.ps1:155-156` |
| Advisor recommendations | Inventory has them (`advisorresources`); assessment re-fetches via `Get-AzAdvisorRecommendation`. Not a gap — a duplicate | `Start-ScoutGraphExtraction.ps1:76`, `Import-AdvisorScores.ps1:22` |
| Policy **compliance state** | Inventory has it; assessment cannot see it. Gap in the *wrong direction* | `Get-ScoutApiResources.ps1:150-152` vs `Import-Governance.ps1` |
| Cost / VM quota / VM SKU capability | Inventory-only (`Get-ScoutCostInventory`, `Get-ScoutVmQuotas`, `Get-ScoutVmSkuDetails`); WAF cost and `zoneEligible` rules would benefit. `zoneEligible` is currently a hard-coded region list | `Invoke-Collect.ps1:306-312` |
| Entra / Graph data | Inventory-only (`Start-ScoutEntraExtraction`); the assessment core explicitly throws on `-Scope EntraOnly` | `Invoke-ScoutAssessmentCore.ps1:113-115` |
| Monitor metrics | Neither side collects. Documented as out of scope | `Invoke-Collect.ps1:75-76` |

The two rows that break the "assessment reuses inventory" model cleanly are **Entra/Graph** (a different token audience and permission model, and the assessment core deliberately refuses it today) and **Monitor metrics** (needs a time window, not a snapshot). Everything else is reconcilable inside one parameterised engine.

---

## Path from here

### Already true

- One raw ARG engine, shared by both callers (`Get-ScoutRawInventory`).
- 34/35 assessment datasets shaped from raw rows with zero extra Azure calls.
- `-Assessment` does not trigger the inventory pass or an inventory report.
- Assess and report layers are pure functions of collected data — no Azure access.
- Collect-once plumbing for the "both" case exists end to end (`-FromInventory`).
- Re-assess from a saved `collect.json` (`-FromCollect`).

### Small change

1. **Delete `ArgQueryPack`.** All six queries are duplicates; one (`nonZonalVms`) is dead. Remove the ingestor and the `'ArgQueryPack'` entries from `manifests/assessments.psd1` (15 assessments reference it). Before deleting, port the two things its consumers rely on — nothing, as far as the merge at `Invoke-ArgQueryPack.ps1:87-95` shows: every property it writes is already populated by `Invoke-Collect`. This is a strict improvement in both cost and correctness.
2. **Fix the tags defect in the combined path.** Either force `IncludeTags` when a run will also assess, or have `Invoke-Collect` detect a missing `tags` column on `-FromInventory` rows and warn loudly instead of returning an empty aggregation. `Invoke-Collect.ps1:700-707` vs `Start-ScoutGraphExtraction.ps1:81`.
3. **Restore the Az context in `Import-AdvisorScores`** (`:21`), or replace the whole function with an ARG `advisorresources` query — which also makes it satisfiable from `-FromInventory`.
4. **Expose the "both" mode as a parameter.** The mechanism exists; it is gated on `$wizardRunBoth` alone (`Invoke-AzureScout.ps1:594`). A `-Both` / `-WithInventory` switch that sets `$deferredAssessArgs` makes collect-once reachable from CI.
5. **Rename or move `Estate`** out of `manifests/assessments.psd1` if "assessment" is to mean CAF/WAF only.

### Real work

6. **Fold the remaining ingest fetches into the one engine as switches.** Add `-IncludePolicyResources`, `-IncludeAuthorizationResources`, `-IncludeManagementGroups` to `Get-ScoutRawInventory`, have `Invoke-Collect` request them, and reduce `Import-Governance` to the budgets/locks REST calls plus shaping. That makes a combined run genuinely one pass and gives inventory access to the same data. Touches `Get-ScoutRawInventory.ps1`, `Invoke-Collect.ps1`, `ConvertFrom-ScoutInventory.ps1`, `Import-Governance.ps1` and the fixture set.
7. **Wire inventory's policy compliance data into the collect contract** so CAF governance rules can score against real compliance rather than assignment existence. Needs a new `collect.governance.policyCompliance` key, a fixture, and rules to consume it — the rules are the bulk of the work.
8. **Provenance + `Unknown` findings.** Per-dataset status on `collect.json`, plumbed into `Invoke-Rule` so a rule over a failed dataset yields `Unknown` rather than `Pass`. This changes the finding schema and every renderer that groups by status.
9. **AB#6483 cache resume**, with the scope-fencing rule above. Depends on 8 (a cache without provenance is a scoring hazard).

---

## Risks and open questions

- **The biggest risk in "collect once" is not cost, it is scope drift.** The inventory pass and the assessment pass ask `Get-ScoutRawInventory` for *different tables and different filters*. Reusing inventory rows for scoring is only sound if the assessment's scope is a subset of the inventory's. Today nothing checks that: `Invoke-Collect.ps1:725-727` accepts whatever rows it is handed. If someone runs an inventory scoped to one resource group and then assesses "the tenant" off those rows, the score is wrong and nothing says so. The `tags` bug is the mild version of this failure mode; a `-ResourceGroup`-scoped inventory feeding a landing-zone assessment is the severe one. **Any collect-once path needs a scope compatibility check, not just a data handoff.**
- **The `-Source TypedQueries` escape hatch is now the only equivalence oracle** for 34 shaped datasets (`Invoke-Collect.ps1:180-183`). If you keep collapsing paths, do not delete it — it is what proves the shaping is faithful.
- **`Invoke-Collect` silently falls back to typed queries when the raw pass throws** (`:711-716`). That is good resilience but it means "collect once" is a default, not a guarantee; a run can quietly cost 35 round-trips. Worth logging at a level the operator actually sees.
- **`Start-ScoutGraphExtraction` still forces eleven `Include*` switches to `$true` unconditionally** (`:71-82`). If the assessment side ever wants inventory's rows, inventory will always have over-collected relative to what assessment needs — fine — but there is no path where assessment's needs *widen* the inventory pass. If you build item 6, decide whether an assessment-in-a-combined-run may turn additional tables **on** for the inventory pass, or whether it fetches those itself. The former is truer to "collect once"; the latter is simpler and keeps the inventory report's cost predictable.
- **Open question I could not resolve from the code:** whether any downstream consumer depends on `collect.costCleanup` / `collect.opsPosture` being the `ArgQueryPack` versions rather than the collector's. The shapes are compatible field-for-field, but the `ArgQueryPack` copies lack the divide-by-zero guards, so any fixture recorded from a live run *through* the ingest path may encode a divide-by-zero artifact that a post-deletion run will not reproduce. Check the fixture set before deleting the ingestor.
