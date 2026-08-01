# AB#6444 — Collector verification audit

**Scope:** all 174 declarative collector manifests under `manifests/collectors/`
**Date:** 2026-07-30
**Method:** manifest inventory, code trace of the collect→process pipeline, test-suite reading, resource-type cross-check against the Microsoft Learn ARG table/type reference
**Status:** read-only audit. No code was changed.

---

## 1. Executive summary

**None of the 174 collectors is verified against real Azure data.** Not one.

The honest breakdown of what the 174 are backed by:

| Evidence class | Count | What it actually proves |
|---|---:|---|
| Golden-record test passes on a fixture **generated from the collector's own definition** | 174 | The interpreter shapes a row deterministically. Nothing about Azure. |
| At least one declared resource type has been observed in a real anonymised ARG capture in this repo | 38 | The type string is real and appears in *a* tenant. No collector is ever run against that capture. |
| **Proven to emit correct rows from real Azure data** | **0** | — |
| **Proven to emit ZERO rows on every run, in every tenant** | **12** | Traced to a specific defect in code. See §4. |
| Cannot emit rows on a default run (opt-in switch, off by default) | 20 | `entra/*` needs `-Scope All`; `devops/*` needs `-IncludeDevOps`. Documented, but silent. |
| Target a service that is retired — will be empty in any modern tenant | 4 | Not defects; dead weight. |

The "174 collectors run, 1 failed" line from the 2026-07-30 live run is not a verification signal. `Invoke-ScoutProcessing` counts a collector as *run* if `Invoke-ScoutCollector` returned without throwing (`src/pipeline/Invoke-ScoutProcessing.ps1:177-186`). A collector that matched zero resources returns `@()` and is indistinguishable from one that returned 5,000 correct rows. **The pipeline never records a per-collector row count anywhere that survives the run** — see §6.

**At minimum 32 of the 174 collectors (18%) produced an empty worksheet on that run and could not have done otherwise.** The remaining 142 are simply unknown.

---

## 2. How a collector silently produces nothing

Understanding the defect class matters more than the individual findings.

1. `src/collect/Get-ScoutRawInventory.ps1:424-441` issues a **broad, untyped** ARG query over `resources` and `networkresources`, plus conditional passes over `SupportResources`, `recoveryservicesresources` and `desktopvirtualizationresources`. There is no per-collector query.
2. Various helpers manufacture **synthetic pseudo-typed rows** (`AZSC/…`, `entra/…`, `devops/…`) and append them to the same collection.
3. `src/pipeline/Invoke-ScoutDeclarativeCollector.ps1:239-245` selects a collector's input by **client-side exact string match** on `$_.TYPE`:
   ```powershell
   @($Resources | Where-Object { @($Definition.ResourceTypes) -contains $_.TYPE })   # SinglePass
   @(foreach ($Type in @($Definition.ResourceTypes)) { $Resources | Where-Object { $_.TYPE -eq $Type } })  # Grouped
   ```
4. `Invoke-ScoutDeclarativeCollector.ps1:260` — `if (@($Matched).Count -eq 0) { return @() }`.

So a declared type that is misspelled, invented, retired, or that lives in an **ARG table Scout never queries**, yields `@()`. No exception. No warning. A clean run, a green failure count, and a blank worksheet.

Casing is *not* a hazard here — PowerShell `-eq`/`-contains` on strings is case-insensitive, so `Microsoft.AVS/privateClouds` matching an ARG row's `microsoft.avs/privateclouds` is fine.

---

## 3. What the existing tests actually prove

### 3.1 `tests/DeclarativeCollectorGolden.Tests.ps1` — 174 collectors, 522 assertions, **self-referential**

This is the suite that gives the impression of full coverage. It runs every definition against `tests/fixtures/collector-equivalence/<Category>.json` and compares rows and rendered worksheet cells to a committed record in `tests/fixtures/collector-golden/<Category>/<Name>.json`.

The fixtures are **not recorded from Azure**. `scripts/New-ScoutCollectorFixture.ps1` synthesises them **from the collector definition's own AST** — its own docstring is admirably blunt about it:

> "the estate is DERIVED FROM THE DEFINITION ITSELF: this script reads the same per-resource script text the interpreter builds (preamble + field expressions), walks its AST for every property path rooted at the collector's own row variable, and synthesises a resource with exactly those paths populated."
> — `scripts/New-ScoutCollectorFixture.ps1:16-20`

> "Values are synthetic and semantically meaningless — `res-value` where a real estate has `Standard_LRS`. This fixture proves the two implementations agree on the SAME input over the paths the collector reads; it does not prove either is correct about a real tenant"
> — ibid., "HONEST LIMITS", lines 68-72

The consequence for AB#6444 is decisive: **the fixture generator emits a resource carrying whatever `ResourceTypes` string the manifest declares.** `manifests/collectors/Hybrid/ArcSites.psd1` declares three type strings that do not exist in Azure; the generator dutifully fabricates rows of those three types; the collector matches them; `tests/fixtures/collector-golden/Hybrid/ArcSites.json` records the result; the test passes forever. It passed before the defect, it passes now, and it would pass after a fix. **This suite is structurally incapable of detecting the entire defect class AB#6444 is about.**

The suite is still valuable — it is a genuine regression lock on the interpreter and the Excel renderer. It just is not collector verification.

### 3.2 `tests/CollectorDefinitionSchema.Tests.ps1` — shape, not semantics

23 checks, and the catalog-wide gate at line 230 ("every definition under manifests/collectors passes every v3 catalog check"). Everything it validates is internal consistency: `Export` columns exist as `Fields`, `ResourceTypeMatching` is a recognised value, `ResourceTypes` is a non-empty array of non-empty strings, worksheet names are ≤31 chars and unique, `Preamble` parses. **There is no check that a `ResourceTypes` entry is a real Azure resource type**, and none that anything in the pipeline can produce it.

### 3.3 `tests/ManifestCollectorRuntime.Tests.ps1` — counts files

Asserts `$Actual.Count | Should -Be 174`. It proves the catalog loader finds every file. Nothing else.

### 3.4 `tests/fixtures/captured-*.json` — the only real payload, and no test uses it

`tests/fixtures/captured-resources.json` (83 rows, 29 distinct types) and its three siblings are genuine anonymised captures from a live tenant, produced by `scripts/Export-ScoutFixture.ps1`. This is exactly the input that could verify collectors.

**No collector is ever executed against them.** A repo-wide grep for `captured-` outside the fixture directory returns only `scripts/Export-ScoutFixture.ps1` (the producer) and `tests/FixtureAnonymity.Tests.ps1` — and that test only checks the files contain no un-anonymised identifiers. The one real-tenant dataset in the repo drives zero collector assertions.

Coverage would be thin anyway: of the 29 captured types, 21 are targeted by a collector, reaching 38 of 174 collectors.

### 3.5 Producer-side unit tests — all mocked

`tests/Collect.ArmChildResources.Tests.ps1`, `tests/Collect.TenantWideResources.Tests.ps1`, `tests/Start-AZSCEntraExtraction.Tests.ps1` and the rest mock every Azure call. They prove the envelope-shaping logic, not that an envelope ever arrives.

### 3.6 Bottom line on the test suite

The 1787-test suite proves the *engine* is correct and deterministic. It contains **no test that could fail because a collector returned nothing from Azure**, and no test that would fail if every one of the 152 declared resource type strings were replaced with gibberish — because the fixtures would be regenerated from the gibberish.

---

## 4. Confirmed broken — 12 collectors that emit zero rows on every run

These are traced to a specific line of code or a specific documented fact, not inferred.

### 4.1 Invented resource type strings

**`Hybrid/ArcSites`** — `manifests/collectors/Hybrid/ArcSites.psd1:8-12` declares:
```
'microsoft.azurestackhci/sites'
'microsoft.edgeconfig/sites'
'microsoft.hybridcompute/sites'
```
None exists. There is no `Microsoft.EdgeConfig` resource provider at all; `Microsoft.HybridCompute` has no `sites` child; `Microsoft.AzureStackHCI` has no `sites` child. Azure Arc Site Manager sites are **`Microsoft.Edge/sites`** ([template reference](https://learn.microsoft.com/azure/templates/microsoft.edge/sites), [Arc Site Manager overview](https://learn.microsoft.com/azure/azure-arc/site-manager/overview)). *Caveat for whoever fixes this:* `microsoft.edge/sites` does **not** appear in the ARG supported-types reference either (the doc lists `microsoft.edge/solutions`, `/targets`, `/configurations`, `/contexts`, `/diagnostics`), so substituting the correct string may still return nothing while Site Manager is in preview. Verify in Resource Graph Explorer before committing.

**`Hybrid/VirtualMachines`** — `manifests/collectors/Hybrid/VirtualMachines.psd1:9` declares `microsoft.azurestackhci/virtualmachineinstances`. The ARM type is real but it is an **extension resource** nested under `Microsoft.HybridCompute/machines/{name}/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default` ([REST reference](https://learn.microsoft.com/rest/api/stackhci/virtual-machine-instances/list)) and is not indexed in the ARG `resources` table. Azure Local VMs surface in ARG as `microsoft.hybridcompute/machines` with `kind =~ 'HCI'`. This also poisons `src/collect/ConvertTo-ScoutAvdAzureLocalSessionHost.ps1:101`, which gates the whole AVD-on-Azure-Local fallback on the same dead string — so `Compute/AVDAzureLocal` is collateral damage (counted separately below as unverified-at-best).

### 4.2 Right type, wrong ARG table

**`Management/LighthouseDelegations`** — `Microsoft.ManagedServices/registrationDefinitions` is real and ARG-visible, but lives in the **`managedserviceresources`** table. `Get-ScoutRawInventory` never queries it. Fix: add a table pass mirroring the `recoveryservicesresources` pattern at `Get-ScoutRawInventory.ps1:431`.

**`Monitor/ResourceDiagnosticSettings`** — `microsoft.insights/diagnosticsettings` is an extension resource and is not indexed in ARG at all. (ARG lists 17 `microsoft.insights/*` types including `datacollectionruleassociations` and `guestdiagnosticsettings`; `diagnosticsettings` is not among them.) Diagnostic-setting presence has to come from per-resource ARM REST.

### 4.3 Retired to the point of removal from ARG

**`Databases/POSTGRE`** — `microsoft.dbforpostgresql/servers`. PostgreSQL Single Server retired 28 March 2025 and the type has been **removed** from the ARG type reference (only `flexibleservers`, `servergroups`, `servergroupsv2` remain). Note the asymmetry: the MySQL and MariaDB single-server types are still *listed* despite also being retired. `Microsoft.DBforPostgreSQL/flexibleServers` is separately declared by `Databases/POSTGREFlex`, so this is a dead collector rather than a coverage gap.

### 4.4 Synthetic types that nothing produces — the worst category

These four collectors depend on `AZSC/Management/*` envelopes from `src/collect/Get-ScoutTenantWideResource.ps1`, which is gated at `src/collect/Get-ScoutRawInventory.ps1:557` on `$IncludeTenantWideResources`:

- `Management/CustomRoleDefinitions` (`AZSC/Management/RoleDefinition`)
- `Management/ManagementGroups` (`AZSC/Management/ManagementGroup`)
- `Management/PolicyDefinitions` (`AZSC/Management/PolicyDefinition`)
- `Management/PolicySetDefinitions` (`AZSC/Management/PolicySetDefinition`)

**That switch has no production caller.** Verified: the string `IncludeTenantWideResources` appears in exactly four places in the repo — the doc comment (`Get-ScoutRawInventory.ps1:91`), the parameter declaration (`:226`), the `if` (`:557`), and one Pester test (`tests/Collect.RawInventory.Tests.ps1:162`). The only production construction of the argument splat, `src/collect/Start-ScoutGraphExtraction.ps1:69-82`, sets `IncludeArmChildResources`, `IncludeOperationalCollectorEnrichment` and `IncludeSubscriptionSecurityPolicy` but **not** this one. `Invoke-Collect.ps1:707` builds its own splat and doesn't set it either.

`Get-ScoutTenantWideResource` is therefore never invoked in production, and no operator flag can turn these four on.

This also settles the long-standing `Management/ManagementGroups` question. The Management Group Reader role is a *second* problem, not the first one: even with the switch set, `Get-AzManagementGroup … -Expand -Recurse` failing is caught at `Get-ScoutTenantWideResource.ps1:99` with `Write-Verbose`, and the fallback enumeration typically *succeeds with an empty list* under insufficient permissions, so the `Write-Warning` at `:146` never fires. The envelope is emitted with `properties = @()` — indistinguishable from a tenant with no management groups. Silent either way.

**`Monitor/Outages`** (`AZSC/Monitor/Outage`) — a call-ordering bug. `Get-ScoutOutageResource` filters for `type -ieq 'Microsoft.ResourceHealth/events'` (`src/collect/Get-ScoutOutageResource.ps1:85`) and is invoked at `Get-ScoutRawInventory.ps1:483`, over the `$resources` list built at lines 424-441. ResourceHealth events live in the ARG **`ServiceHealthResources`** table ([confirmed](https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources#servicehealthresources)), which Scout never queries. The events *do* arrive — via ARM REST at `src/collect/Get-ScoutApiResources.ps1:130-131`, merged into `$Resources` at `src/Start-AZTIExtractionOrchestration.ps1:94` — but that happens **after** `Get-ScoutRawInventory` has already returned. The transform sees zero candidates on every run. Line 85 is a `continue`, so the outer `try` at `:482` never sees an exception. Total silence.

### 4.5 Manifests for datasets deliberately removed from the producer

**`Monitor/AppInsightsContinuousExport`** and **`Monitor/AppInsightsWorkItems`**. `src/collect/Get-ScoutArmChildResource.ps1:11-13` states the exclusion outright — "Application Insights Continuous Export and Work Item Config endpoints are deliberately not represented: Azure retired them" — and both datasets are absent from the `ValidateSet` (lines 57-71) and `$DatasetOrder` (75-88). The two manifests were never retired with them. Two permanently blank worksheets with no explanation to the reader. Arguably correct producer behaviour with orphaned manifests, but it ships as data loss to the operator.

---

## 5. Off by default, silently — 20 collectors

Not defects, but they contribute to the same "green run, blank sheet" experience, and their failure modes are worse than the defaults suggest.

**15 `Identity/*` collectors** (`entra/*` types). `src/Invoke-AzureScout.ps1:340` declares `[string]$Scope = 'ArmOnly'`; `src/Start-AZTIExtractionOrchestration.ps1:140` runs Entra extraction only when `$Scope -in @('All','EntraOnly')`. This is documented (`Invoke-AzureScout.ps1:64`). What is *not* acceptable: when the scope **is** enabled, a Microsoft Graph permission failure is swallowed. `Invoke-AZSCGraphRequest` re-throws a non-retryable 403 (`src/Invoke-AZTIGraphRequest.ps1:144-145`) and `src/collect/Start-ScoutEntraExtraction.ps1:237-244` catches it and emits only a coloured `Write-Host "SKIP"`. Nothing reaches the warning stream or `$Error`, so the run's error-count check cannot see it. An identity lacking `Policy.Read.All` gets a silently empty Conditional Access sheet.

**5 `DevOps/DevOps*` collectors** (`devops/*` types; relocated from `Management/` — AB#6828). Gated on `-IncludeDevOps` (`Start-AZTIExtractionOrchestration.ps1:165`). `Invoke-DevOpsRequest` (`src/collect/Start-ScoutDevOpsExtraction.ps1:118-134`) returns `$null` on *every* failure and logs 401/403/404 via `Write-Debug` only. A per-project 403 on service connections is invisible outside `-Debug`.

---

## 6. Evidence from real run artifacts

**There is none, and that is itself the finding.**

`output/` contains eleven run folders. The two newest (`output/20260728_144730`, `output/20260728_144954`) hold `collect.json`, `findings.json` and `report.html` — these are **Assessment**-surface artifacts (top-level keys: `subscriptions, tags, networking, compute, management, security, domains, _meta, governance, costCleanup, opsPosture, advisor`). They contain no per-collector inventory output. Nothing from the 2026-07-30 inventory run was retained in the repo, and which collector was the "1 failed" is not recoverable from anything committed.

The per-collector data **does exist transiently**. `src/pipeline/Invoke-ScoutProcessing.ps1:174` builds `$Bucket[$Result.Name] = $Result.Rows` per category and `Write-ScoutCacheFile` writes it to `<run>/ReportCache/<Category>.json`, keyed by collector name. Two problems:

1. `src/pipeline/Write-ScoutCacheFile.ps1:58-63` — if a category's total row count is 0, **the file is not written at all**. An entirely empty category vanishes rather than recording zeros.
2. `src/Invoke-AzureScout.ps1:1035` — `Clear-AZSCCacheFolder -ReportCache $ReportCache` runs unconditionally at the end of every run. **The only per-collector row-count evidence Scout ever produces is deleted before the operator sees it.**

The run log (`scout-run.log`) records the phase summary only: `Collectors run`, `Collectors declarative`, `Collectors failed`, `Collectors skipped`, `Categories cached`, `Rows cached` (`Invoke-ScoutProcessing.ps1:221-231`). Aggregate `Rows cached` across all categories — no per-collector breakdown.

---

## 7. Proposed verification methodology

Four layers, cheapest first. Layers 1-3 are cheap and should be done regardless; layer 4 is the only thing that produces genuine verification, and it is expensive.

### Layer 1 — Static resource-type existence gate (~1 day)

A Pester test that asserts every Azure-namespace string in every manifest's `ResourceTypes` appears in the ARG supported-types reference, and every `AZSC/` / `entra/` / `devops/` string is produced by a known producer. Two sources, both automatable:

- **Live:** `Search-AzGraph -Query "resources | distinct type"` against any tenant gives the ARG-visible set. Better: publish the Microsoft Learn `supported-tables-resources` page into a committed `manifests/arg-type-catalog.json`, refreshed by a script, so the test runs offline in CI.
- **Producer side:** parse `Get-ScoutArmChildResource.ps1`'s `$DatasetOrder`, `Get-ScoutTenantWideResource.ps1`, `Start-ScoutEntraExtraction.ps1` etc. for the literal `type = '…'` assignments and assert every declared synthetic type has exactly one producer *and* that its gating switch is set somewhere in production code.

This single test would have caught 11 of the 12 confirmed defects. It is the highest-value item in this document.

### Layer 2 — Retain and report per-collector row counts (~1 day)

Three small changes:
1. `Write-ScoutCacheFile` — write the file even when `RowCount -eq 0`, or at minimum record the zero.
2. `Invoke-ScoutProcessing` — add a per-collector `{Category, Name, RowCount}` list to `$Summary` and write it to `<run>/collector-rowcounts.csv` next to `scout-run.log`.
3. `Invoke-AzureScout.ps1:1035` — do not delete the row-count artifact with the cache.

This converts "174 ran, 1 failed" into an actionable report *on every run, for every customer, forever*. It is the difference between one verification exercise and continuous verification.

### Layer 3 — Run the 174 against the captured live payload (~2-3 days)

`tests/fixtures/captured-resources.json` already exists and is anonymised. Add a test that runs every collector against the captured tables and asserts, per collector, either a recorded non-zero row count or an explicit `ExpectedEmpty = $true` with a stated reason. Expand the capture first — the current one covers 29 types across 38 collectors. Recapturing from the 8-subscription tenant with `scripts/Export-ScoutFixture.ps1` will lift that, and the anonymity gate (`tests/FixtureAnonymity.Tests.ps1`) already exists to make that safe.

This is the layer that makes golden coverage non-vacuous. It gives real values (`Standard_LRS`, not `res-value`) and would surface the "property is sometimes a string, sometimes an object" class that `New-ScoutCollectorFixture.ps1` explicitly says it cannot.

### Layer 4 — Canary subscription (weeks, and ongoing cost)

The only thing that proves the remaining collectors. One subscription containing a minimal instance of each of the ~110 targetable Azure services, deployed by Bicep, torn down and rebuilt on a schedule. Realistically: many services cannot be cheaply instantiated (AVS, ExpressRoute, Azure Local clusters, Red Hat OpenShift, NetApp), several require quota or approval, and the monthly cost is material.

**Recommendation: do not attempt full coverage.** Build a canary covering the cheap tier — storage, networking, Key Vault, App Service, SQL, Cosmos, monitor rules, container apps, ACR, AKS — which is perhaps 60 of the 174, and accept layer 1+3 as the verification for the rest. A `-WhatIf`-style "types I expected but did not see" report from a real run against a rich customer tenant is a better return on effort than owning an estate.

---

## 8. Recommended work breakdown under AB#6444

Ordered by value per unit effort.

| # | Proposed child task | Effort | Rationale |
|---|---|---|---|
| 1 | **Fix the 5 dead-by-defect collectors: wire `-IncludeTenantWideResources` into `Start-ScoutGraphExtraction`, and move `Get-ScoutOutageResource` after the API merge** | 1-2 d | 5 collectors no operator flag can enable. Clean-exit blank sheets today. |
| 2 | **Add the static resource-type existence gate (layer 1)** | 1 d | Catches 11 of 12 defects; prevents recurrence permanently. |
| 3 | **Emit and retain a per-collector row-count artifact (layer 2)** | 1 d | Turns every future run into evidence. Prerequisite for tasks 5-7. |
| 4 | **Correct or retire the 5 bad type strings** — `ArcSites` (×3), `azurestackhci/virtualmachineinstances`, `dbforpostgresql/servers` | 2-3 d | Requires a live ARG check per type; `Microsoft.Edge/sites` may still be unavailable. |
| 5 | **Retire `Monitor/AppInsightsContinuousExport` + `AppInsightsWorkItems` manifests** | 2 h | The producer already refuses these; the manifests are orphans. |
| 6 | **Route `Monitor/ResourceDiagnosticSettings` and `Management/LighthouseDelegations` to a source that can return data** — `managedserviceresources` ARG table for Lighthouse, per-resource ARM REST for diagnostic settings | 3-5 d | Both are genuinely useful sheets that have never had data. |
| 7 | **Stop swallowing Entra 403s and DevOps 4xx** — promote to `Write-Warning` and record in the run summary | 1 d | An empty Conditional Access sheet must not look like a compliant tenant. |
| 8 | **Re-capture and expand `tests/fixtures/captured-*.json` from the 8-subscription tenant** | 2 d | Input for task 9. Anonymity gate already exists. |
| 9 | **Add the live-payload collector suite (layer 3), with per-collector expected-empty declarations** | 3 d | Makes golden coverage non-vacuous for the covered types. |
| 10 | **Decide and document the 4 retired-service collectors** (`Compute/CloudServices`, `Databases/MariaDB`, `Databases/MySQL`, `Monitor/LAWorkspaceSolutions`) | 4 h | Keep with a "legacy estate" note, or retire. Either is fine; ambiguity is not. |
| 11 | **Scope and cost a canary subscription (layer 4)** | 1 wk spike | Decide the cheap tier and whether it is worth owning. |

Tasks 1-3 together are roughly one week and move the audit from "0 of 174 verified" to "5 defects fixed, recurrence prevented, and every future run self-reports".

---

## 9. Full 174-collector inventory

**Status legend**

| Code | Meaning |
|---|---|
| `BROKEN` | Traced to a defect; emits zero rows on every run in every tenant. §4 |
| `OPT-IN` | Cannot emit on a default run; needs `-Scope All` or `-IncludeDevOps`. §5 |
| `RETIRED` | Valid string, but the Azure service is retired. Empty in any modern tenant. |
| `SYNTH-OK` | Depends on a synthetic pseudo-type whose producer runs unconditionally on a default run. Plausible, unverified. |
| `ARG-SEEN` | Targets a real ARG type that has been observed in this repo's live capture. Unverified — no test runs the collector against it. |
| `ARG-UNSEEN` | Targets a real ARG type never observed in any captured payload here. Unverified. |

No row in this table is "verified working". `ARG-SEEN` is the strongest evidence any collector has, and it only means the type string is real.

| Category | Collector | Declared resource type(s) | Worksheet | Status |
|---|---|---|---|---|
| AI | AIFoundryHubs | `microsoft.machinelearningservices/workspaces` | AI Foundry Hubs | `ARG-UNSEEN` |
| AI | AIFoundryProjects | `microsoft.machinelearningservices/workspaces` | AI Foundry Projects | `ARG-UNSEEN` |
| AI | AppliedAIServices | `microsoft.cognitiveservices/accounts` | Applied AI Services | `ARG-SEEN` |
| AI | AzureAI | `microsoft.cognitiveservices/accounts` | Azure AI | `ARG-SEEN` |
| AI | BotServices | `microsoft.botservice/botservices` | Bot Services | `ARG-UNSEEN` |
| AI | ComputerVision | `microsoft.cognitiveservices/accounts` | Computer Vision | `ARG-SEEN` |
| AI | ContentModerator | `microsoft.cognitiveservices/accounts` | Content Moderator | `ARG-SEEN` |
| AI | ContentSafety | `microsoft.cognitiveservices/accounts` | Content Safety | `ARG-SEEN` |
| AI | CustomVision | `microsoft.cognitiveservices/accounts` | Custom Vision | `ARG-SEEN` |
| AI | FaceAPI | `microsoft.cognitiveservices/accounts` | Face API | `ARG-SEEN` |
| AI | FormRecognizer | `microsoft.cognitiveservices/accounts` | Doc Intelligence | `ARG-SEEN` |
| AI | HealthInsights | `microsoft.cognitiveservices/accounts` | Health Insights | `ARG-SEEN` |
| AI | ImmersiveReader | `microsoft.cognitiveservices/accounts` | Immersive Reader | `ARG-SEEN` |
| AI | MachineLearning | `microsoft.machinelearningservices/workspaces` | Machine Learning | `ARG-UNSEEN` |
| AI | MLComputes | `AZSC/ARMChild/MLComputes` | ML Compute | `SYNTH-OK` |
| AI | MLDatasets | `AZSC/ARMChild/MLDatasets` | ML Datasets | `SYNTH-OK` |
| AI | MLDatastores | `AZSC/ARMChild/MLDatastores` | ML Datastores | `SYNTH-OK` |
| AI | MLEndpoints | `AZSC/ARMChild/MLEndpoints` | ML Endpoints | `SYNTH-OK` |
| AI | MLModels | `AZSC/ARMChild/MLModels` | ML Models | `SYNTH-OK` |
| AI | MLPipelines | `AZSC/ARMChild/MLPipelines` | ML Pipelines | `SYNTH-OK` |
| AI | OpenAIAccounts | `microsoft.cognitiveservices/accounts` | OpenAI Accounts | `ARG-SEEN` |
| AI | OpenAIDeployments | `AZSC/ARMChild/OpenAIDeployments` | OpenAI Deployments | `SYNTH-OK` |
| AI | SearchIndexes | `AZSC/ARMChild/SearchIndexes` | Search Indexes | `SYNTH-OK` |
| AI | SearchServices | `microsoft.search/searchservices` | Search Services | `ARG-UNSEEN` |
| AI | SpeechService | `microsoft.cognitiveservices/accounts` | Speech Service | `ARG-SEEN` |
| AI | TextAnalytics | `microsoft.cognitiveservices/accounts` | Language | `ARG-SEEN` |
| AI | Translator | `microsoft.cognitiveservices/accounts` | Translator | `ARG-SEEN` |
| Analytics | Databricks | `microsoft.databricks/workspaces` | Databricks | `ARG-UNSEEN` |
| Analytics | DataExplorerCluster | `microsoft.kusto/clusters` | Data Explorer Clusters | `ARG-UNSEEN` |
| Analytics | EvtHub | `microsoft.eventhub/namespaces` | Event Hubs | `ARG-UNSEEN` |
| Analytics | Purview | `microsoft.purview/accounts` | Purview | `ARG-UNSEEN` |
| Analytics | Streamanalytics | `microsoft.streamanalytics/streamingjobs` | Stream Analytics Jobs | `ARG-UNSEEN` |
| Analytics | Synapse | `microsoft.synapse/workspaces` | Synapse | `ARG-UNSEEN` |
| Compute | AvailabilitySets | `microsoft.compute/availabilitysets` | Availability Sets | `ARG-UNSEEN` |
| Compute | AVD | `microsoft.desktopvirtualization/hostpools` | AVD | `ARG-UNSEEN` |
| Compute | AVDApplicationGroups | `microsoft.desktopvirtualization/applicationgroups` | AVD Application Groups | `ARG-UNSEEN` |
| Compute | AVDApplications | `AZSC/ARMChild/AVDApplications` | AVD Applications | `SYNTH-OK` |
| Compute | AVDAzureLocal | `AZSC/AVD/AzureLocalSessionHost` | AVD on Azure Local Arc | `SYNTH-OK` |
| Compute | AVDScalingPlans | `microsoft.desktopvirtualization/scalingplans` | AVD Scaling Plans | `ARG-UNSEEN` |
| Compute | AVDSessionHosts | `microsoft.desktopvirtualization/hostpools/sessionhosts` | AVD Session Hosts | `ARG-UNSEEN` |
| Compute | AVDWorkspaces | `microsoft.desktopvirtualization/workspaces` | AVD Workspaces | `ARG-UNSEEN` |
| Compute | CloudServices | `microsoft.classiccompute/domainnames` | CloudServices | `RETIRED` |
| Compute | VirtualMachine | `microsoft.compute/virtualmachines` | Virtual Machines | `ARG-SEEN` |
| Compute | VirtualMachineScaleSet | `microsoft.compute/virtualmachinescalesets` | Virtual Machine Scale Sets | `ARG-UNSEEN` |
| Compute | VMDisk | `microsoft.compute/disks` | Disks | `ARG-SEEN` |
| Compute | VMOperationalData | `microsoft.compute/virtualmachines` | VM Operational Data | `ARG-SEEN` |
| Compute | VMWare | `Microsoft.AVS/privateClouds` | VMWare | `ARG-UNSEEN` |
| Containers | AKS | `microsoft.containerservice/managedclusters` | AKS | `ARG-UNSEEN` |
| Containers | ARO | `microsoft.redhatopenshift/openshiftclusters` | ARO | `ARG-UNSEEN` |
| Containers | ContainerApp | `microsoft.app/containerapps` | Container Apps | `ARG-SEEN` |
| Containers | ContainerAppEnv | `microsoft.app/managedenvironments` | Container App Env | `ARG-SEEN` |
| Containers | ContainerGroups | `microsoft.containerinstance/containergroups` | Containers | `ARG-UNSEEN` |
| Containers | ContainerRegistries | `microsoft.containerregistry/registries` | Registries | `ARG-SEEN` |
| Databases | CosmosDB | `microsoft.documentdb/databaseaccounts` | Cosmos DB | `ARG-UNSEEN` |
| Databases | MariaDB | `microsoft.dbformariadb/servers` | MariaDB | `RETIRED` |
| Databases | MySQL | `microsoft.dbformysql/servers` | MySQL | `RETIRED` |
| Databases | MySQLflexible | `Microsoft.DBforMySQL/flexibleServers` | MySQL Flexible | `ARG-UNSEEN` |
| Databases | POSTGRE | `microsoft.dbforpostgresql/servers` | PostgreSQL | `BROKEN` |
| Databases | POSTGREFlexible | `Microsoft.DBforPostgreSQL/flexibleServers` | PostgreSQL Flexible | `ARG-SEEN` |
| Databases | RedisCache | `microsoft.cache/redis``<br>``microsoft.cache/redisenterprise` | Redis Cache | `ARG-UNSEEN` |
| Databases | SQLDB | `microsoft.sql/servers/databases` | SQL DBs | `ARG-UNSEEN` |
| Databases | SQLMI | `microsoft.sql/managedInstances` | SQL MI | `ARG-UNSEEN` |
| Databases | SQLMIDB | `microsoft.sql/managedinstances/databases` | SQL MI DBs | `ARG-UNSEEN` |
| Databases | SQLPOOL | `microsoft.sql/servers/elasticPools` | SQL Pools | `ARG-UNSEEN` |
| Databases | SQLSERVER | `microsoft.sql/servers` | SQL Servers | `ARG-UNSEEN` |
| Databases | SQLVM | `microsoft.sqlvirtualmachine/sqlvirtualmachines` | SQL VMs | `ARG-UNSEEN` |
| Hybrid | ArcDataControllers | `microsoft.azurearcdata/datacontrollers` | Arc Data Controllers | `ARG-UNSEEN` |
| Hybrid | ArcExtensions | `microsoft.hybridcompute/machines/extensions` | Arc Extensions | `ARG-UNSEEN` |
| Hybrid | ArcGateways | `microsoft.hybridcompute/gateways` | Arc Gateways | `ARG-UNSEEN` |
| Hybrid | ArcKubernetes | `microsoft.kubernetes/connectedclusters` | Arc Kubernetes | `ARG-UNSEEN` |
| Hybrid | ArcResourceBridge | `microsoft.resourceconnector/appliances` | Arc Resource Bridge | `ARG-UNSEEN` |
| Hybrid | ArcServerOperationalData | `microsoft.hybridcompute/machines` | Arc Server Operational Data | `ARG-UNSEEN` |
| Hybrid | ARCServers | `microsoft.hybridcompute/machines` | ARC Servers | `ARG-UNSEEN` |
| Hybrid | ArcSites | `microsoft.azurestackhci/sites``<br>``microsoft.edgeconfig/sites``<br>``microsoft.hybridcompute/sites` | Arc Sites | `BROKEN` |
| Hybrid | ArcSQLManagedInstances | `microsoft.azurearcdata/sqlmanagedinstances` | Arc SQL Managed Instances | `ARG-UNSEEN` |
| Hybrid | ArcSQLServers | `microsoft.azurearcdata/sqlserverinstances` | Arc SQL Servers | `ARG-UNSEEN` |
| Hybrid | Clusters | `microsoft.azurestackhci/clusters` | AzLocal Clusters | `ARG-UNSEEN` |
| Hybrid | GalleryImages | `microsoft.azurestackhci/galleryimages` | AzLocal Images | `ARG-UNSEEN` |
| Hybrid | LogicalNetworks | `microsoft.azurestackhci/logicalnetworks` | AzLocal Networks | `ARG-UNSEEN` |
| Hybrid | MarketplaceGalleryImages | `microsoft.azurestackhci/marketplacegalleryimages` | AzLocal Marketplace | `ARG-UNSEEN` |
| Hybrid | StorageContainers | `microsoft.azurestackhci/storagecontainers` | AzLocal Storage | `ARG-UNSEEN` |
| Hybrid | VirtualMachines | `microsoft.azurestackhci/virtualmachineinstances` | AzLocal VMs | `BROKEN` |
| Identity | AdminUnits | `entra/administrativeunits` | Admin Units | `OPT-IN` |
| Identity | AppRegistrations | `entra/applications` | App Registrations | `OPT-IN` |
| Identity | ConditionalAccess | `entra/conditionalaccesspolicies` | Conditional Access | `OPT-IN` |
| Identity | CrossTenantAccess | `entra/crosstenantaccess` | Cross-Tenant Access | `OPT-IN` |
| Identity | DirectoryRoles | `entra/directoryroles` | Directory Roles | `OPT-IN` |
| Identity | Domains | `entra/domains` | Entra Domains | `OPT-IN` |
| Identity | Groups | `entra/groups` | Entra Groups | `OPT-IN` |
| Identity | Licensing | `entra/subscribedskus` | Licensing | `OPT-IN` |
| Identity | ManagedIdentities | `entra/managedidentities` | Managed Identities | `OPT-IN` |
| Identity | ManagedIds | `Microsoft.ManagedIdentity/userAssignedIdentities` | Managed Identity | `ARG-SEEN` |
| Identity | NamedLocations | `entra/namedlocations` | Named Locations | `OPT-IN` |
| Identity | PIMAssignments | `entra/pimassignments` | PIM Assignments | `OPT-IN` |
| Identity | RiskyUsers | `entra/riskyusers` | Risky Users | `OPT-IN` |
| Identity | SecurityPolicies | `entra/securitypolicies` | Security Policies | `OPT-IN` |
| Identity | ServicePrincipals | `entra/serviceprincipals` | Service Principals | `OPT-IN` |
| Identity | Users | `entra/users` | Entra Users | `OPT-IN` |
| Integration | APIM | `microsoft.apimanagement/service` | APIM | `ARG-UNSEEN` |
| Integration | ServiceBUS | `microsoft.servicebus/namespaces` | Service BUS | `ARG-SEEN` |
| IoT | IOTHubs | `microsoft.devices/iothubs` | IOTHubs | `ARG-UNSEEN` |
| Management | AdvisorScore | `Microsoft.Advisor/advisorScore` | AdvisorScore | `ARG-UNSEEN` |
| Management | AllSubscriptions | `AZSC/Management/SubscriptionEnrichment` | All Subscriptions | `SYNTH-OK` |
| Management | AutomationAccounts | `microsoft.automation/automationaccounts` | Runbooks | `ARG-UNSEEN` |
| Management | Backup | `microsoft.recoveryservices/vaults/backuppolicies` | Backup | `ARG-UNSEEN` |
| Management | CustomRoleDefinitions | `AZSC/Management/RoleDefinition` | Custom Roles | `BROKEN` |
| Management | DevOpsAgentPools | `devops/agentpools` | ADO Agent Pools | `OPT-IN` |
| Management | DevOpsPipelines | `devops/pipelines` | ADO Pipelines | `OPT-IN` |
| Management | DevOpsProjects | `devops/projects` | ADO Projects | `OPT-IN` |
| Management | DevOpsRepositories | `devops/repositories` | ADO Repositories | `OPT-IN` |
| Management | DevOpsServiceConnections | `devops/serviceconnections` | ADO Service Connections | `OPT-IN` |
| Management | LighthouseDelegations | `Microsoft.ManagedServices/registrationDefinitions` | Lighthouse Delegations | `BROKEN` |
| Management | MaintenanceConfigurations | `microsoft.maintenance/maintenanceconfigurations` | Maintenance Configs | `ARG-UNSEEN` |
| Management | ManagementGroups | `AZSC/Management/ManagementGroup` | Management Groups | `BROKEN` |
| Management | PolicyComplianceStates | `AZSC/Subscription/SecurityPolicySweep` | Policy Compliance | `SYNTH-OK` |
| Management | PolicyDefinitions | `AZSC/Management/PolicyDefinition` | Policy Definitions | `BROKEN` |
| Management | PolicySetDefinitions | `AZSC/Management/PolicySetDefinition` | Policy Initiatives | `BROKEN` |
| Management | RecoveryVault | `microsoft.recoveryservices/vaults` | Recovery Vaults | `ARG-UNSEEN` |
| Management | ReservationRecom | `Microsoft.Consumption/reservationRecommendations` | Reservation Advisor | `ARG-UNSEEN` |
| Management | SupportTickets | `Microsoft.Support/supportTickets` | Support Tickets | `ARG-UNSEEN` |
| Monitor | ActionGroups | `microsoft.insights/actiongroups` | Action Groups | `ARG-SEEN` |
| Monitor | ActivityLogAlertRules | `microsoft.insights/activitylogalerts` | Activity Log Alerts | `ARG-UNSEEN` |
| Monitor | AppInsights | `microsoft.insights/components` | AppInsights | `ARG-SEEN` |
| Monitor | AppInsightsAvailabilityTests | `microsoft.insights/webtests` | App Insights Availability Tests | `ARG-UNSEEN` |
| Monitor | AppInsightsContinuousExport | `AZSC/ARMChild/AppInsightsContinuousExport` | App Insights Continuous Export | `BROKEN` |
| Monitor | AppInsightsProactiveDetection | `AZSC/ARMChild/AppInsightsProactiveDetection` | App Insights ProactiveDetection | `SYNTH-OK` |
| Monitor | AppInsightsWebTests | `microsoft.insights/webtests` | App Insights Web Tests | `ARG-UNSEEN` |
| Monitor | AppInsightsWorkItems | `AZSC/ARMChild/AppInsightsWorkItems` | App Insights Work Items | `BROKEN` |
| Monitor | AutoscaleSettings | `microsoft.insights/autoscalesettings` | Autoscale Settings | `ARG-UNSEEN` |
| Monitor | DataCollectionEndpoints | `microsoft.insights/datacollectionendpoints` | Data Collection Endpoints | `ARG-UNSEEN` |
| Monitor | DataCollectionRules | `microsoft.insights/datacollectionrules` | Data Collection Rules | `ARG-UNSEEN` |
| Monitor | LAWorkspaceLinkedServices | `AZSC/ARMChild/LAWorkspaceLinkedServices` | LA Linked Services | `SYNTH-OK` |
| Monitor | LAWorkspaceSavedSearches | `AZSC/ARMChild/LAWorkspaceSavedSearches` | LA Saved Searches | `SYNTH-OK` |
| Monitor | LAWorkspaceSolutions | `microsoft.operationsmanagement/solutions` | LA Solutions | `RETIRED` |
| Monitor | MetricAlertRules | `microsoft.insights/metricalerts` | Metric Alerts | `ARG-SEEN` |
| Monitor | MonitorMetricsIngestion | `microsoft.operationalinsights/workspaces` | Monitor Metrics Ingestion | `ARG-SEEN` |
| Monitor | MonitorPrivateLinkScopes | `microsoft.insights/privatelinkscopes` | Monitor Private Link Scopes | `ARG-UNSEEN` |
| Monitor | MonitorWorkbooks | `microsoft.insights/workbooks` | Monitor Workbooks | `ARG-UNSEEN` |
| Monitor | Outages | `AZSC/Monitor/Outage` | Outages | `BROKEN` |
| Monitor | ResourceDiagnosticSettings | `microsoft.insights/diagnosticsettings` | Resource Diagnostic Settings | `BROKEN` |
| Monitor | ScheduledQueryRules | `microsoft.insights/scheduledqueryrules` | Scheduled Queries | `ARG-UNSEEN` |
| Monitor | SmartDetectorAlertRules | `microsoft.alertsmanagement/smartdetectoralertrules` | Smart Detector Alerts | `ARG-SEEN` |
| Monitor | SubscriptionDiagnosticSettings | `AZSC/Subscription/SecurityPolicySweep` | Subscription Diagnostics | `SYNTH-OK` |
| Monitor | Workspaces | `microsoft.operationalinsights/workspaces` | Workspaces | `ARG-SEEN` |
| Networking | ApplicationGateways | `microsoft.network/applicationgateways` | App Gateway | `ARG-UNSEEN` |
| Networking | AzureFirewall | `microsoft.network/azurefirewalls` | Azure Firewall | `ARG-UNSEEN` |
| Networking | BastionHosts | `microsoft.network/bastionhosts` | Bastion Hosts | `ARG-UNSEEN` |
| Networking | Connections | `microsoft.network/connections` | Connections | `ARG-UNSEEN` |
| Networking | ExpressRoute | `microsoft.network/expressroutecircuits` | Express Route | `ARG-UNSEEN` |
| Networking | Frontdoor | `microsoft.network/frontdoors` | FrontDoor | `ARG-UNSEEN` |
| Networking | LoadBalancer | `microsoft.network/loadbalancers` | Load Balancers | `ARG-SEEN` |
| Networking | NATGateway | `microsoft.network/natgateways` | NAT Gateway | `ARG-UNSEEN` |
| Networking | NetworkInterface | `microsoft.network/networkinterfaces` | Network Interface | `ARG-SEEN` |
| Networking | NetworkSecurityGroup | `microsoft.network/networksecuritygroups` | Network Security Groups | `ARG-UNSEEN` |
| Networking | NetworkWatchers | `microsoft.network/networkwatchers` | Network Watchers | `ARG-SEEN` |
| Networking | PrivateDNS | `microsoft.network/privatednszones` | Private DNS | `ARG-SEEN` |
| Networking | PrivateEndpoint | `microsoft.network/privateendpoints` | Private Endpoint | `ARG-SEEN` |
| Networking | PublicDNS | `microsoft.network/dnszones` | Public DNS | `ARG-UNSEEN` |
| Networking | PublicIP | `microsoft.network/publicipaddresses` | Public IPs | `ARG-UNSEEN` |
| Networking | RouteTables | `microsoft.network/routetables` | Route Tables | `ARG-UNSEEN` |
| Networking | TrafficManager | `microsoft.network/trafficmanagerprofiles` | Traffic Manager | `ARG-UNSEEN` |
| Networking | VirtualNetwork | `microsoft.network/virtualnetworks` | Virtual Networks | `ARG-SEEN` |
| Networking | VirtualNetworkGateways | `microsoft.network/virtualnetworkgateways` | VNET Gateways | `ARG-UNSEEN` |
| Networking | VirtualWAN | `microsoft.network/virtualwans` | Virtual WAN | `ARG-UNSEEN` |
| Networking | vNETPeering | `microsoft.network/virtualnetworks` | Peering | `ARG-SEEN` |
| Security | DefenderAlerts | `AZSC/Subscription/SecurityPolicySweep` | Defender Alerts | `SYNTH-OK` |
| Security | DefenderAssessments | `AZSC/Subscription/SecurityPolicySweep` | Defender Assessments | `SYNTH-OK` |
| Security | DefenderPricing | `AZSC/Subscription/SecurityPolicySweep` | Defender Pricing | `SYNTH-OK` |
| Security | DefenderSecureScore | `AZSC/Subscription/SecurityPolicySweep` | Defender Secure Score | `SYNTH-OK` |
| Security | Vault | `microsoft.keyvault/vaults` | Key Vaults | `ARG-SEEN` |
| Storage | NetApp | `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` | NetApp | `ARG-UNSEEN` |
| Storage | StorageAccounts | `microsoft.storage/storageaccounts` | Storage Accounts | `ARG-SEEN` |
| Web | APPServicePlan | `microsoft.web/serverfarms` | App Service Plan | `ARG-UNSEEN` |
| Web | APPServices | `microsoft.web/sites` | App Services | `ARG-UNSEEN` |

**Totals:** `BROKEN` 12 · `OPT-IN` 20 · `RETIRED` 4 · `SYNTH-OK` 20 · `ARG-SEEN` 38 · `ARG-UNSEEN` 80 · **verified against real Azure: 0**

---

## 10. Two corrections to priors worth recording

Both were checked against the Microsoft Learn ARG reference rather than assumed, and both cut *against* the audit's initial suspicions:

- **`microsoft.desktopvirtualization/hostpools/sessionhosts` and `microsoft.recoveryservices/vaults/backuppolicies` are fine.** They live in the `desktopvirtualizationresources` and `recoveryservicesresources` tables, which `Get-ScoutRawInventory.ps1:431-441` folds into `$resources`, with both switches hard-set `$true` at `Start-ScoutGraphExtraction.ps1:73-74`.
- **`SupportResources` is a real ARG table** ("Includes resources related to `Microsoft.Support`" — [query language reference](https://learn.microsoft.com/azure/governance/resource-graph/concepts/query-language#resource-graph-tables)), queried at `Get-ScoutRawInventory.ps1:428` when not in Azure US Government. `Management/SupportTickets` is therefore not broken. Likewise `Management/AdvisorScore` and `Management/ReservationRecom`: the ARM REST responses carry `"type": "Microsoft.Advisor/advisorScore"` ([template reference](https://learn.microsoft.com/azure/templates/microsoft.advisor/2025-01-01/advisorscore)) and the equivalent for reservation recommendations, and `src/Start-AZTIExtractionOrchestration.ps1:96-97` appends them to `$Resources`. All three are unverified, not broken.

Also confirmed *not* a hazard: `microsoft.hybridcompute/gateways` and `Microsoft.NetApp/netAppAccounts/capacityPools/volumes` are both genuinely indexed in the ARG `resources` table despite looking exotic.
