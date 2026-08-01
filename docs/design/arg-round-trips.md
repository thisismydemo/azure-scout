# Azure Resource Graph round-trips per run

Tracks ADO AB#5648 (Epic AB#5638).

::: warning Partly stale — written mid-rewrite, `Modules/` is now deleted
This document was written during the AB#5648 inversion, while the collector tree still had a
live `Modules/Private/...` shim layer alongside the new `src/collect/` functions. As of v3.0.0
that shim layer — every `Modules/Private/...` path named below — **no longer exists in the
repository**; the retired collector-script tree and imperative fallback were deleted outright
(see [`docs/changelog.md`](../project/changelog.md) v3.0.0, and [`docs/ari-differences.md`](../project/ari-differences.md#engine-rewrite-ari-shipped-none-of-this)).
The query counts and call-site *purposes* below are still the right mental model — the
`src/collect/` half of every row is current — but any `Modules/Private/...` path is historical,
not a file you can open today. **`src/ingest/Invoke-ArgQueryPack.ps1`, listed as a call site
below, was also deleted** — AB#6774 (2026-07-31) retired it outright once its six queries were
confirmed to duplicate data `Invoke-Collect` already collects. Treat this page as an explanation
of *why* the numbers are what they are, not as a current file map.
:::

This is the map of **every** Azure Resource Graph and ARM REST call the product issues, where it
is issued from, and what changed when `src/collect` became the single source of the raw data.
It was derived by reading each call site, not from an earlier estimate.

A "round-trip" here means one `Search-AzGraph` invocation for one query and one subscription
batch — not one page. Paging multiplies each entry by however many 1000-row pages the estate
needs.

## Where Resource Graph is reached from

Every `Search-AzGraph` call site in the shipped module:

| Call site | Purpose | Queries issued |
|---|---|---|
| `src/collect/Get-ScoutRawInventory.ps1` | the single raw pass | 3 tables always; up to 6 more behind `-Include*` switches |
| `src/collect/Get-ScoutGovernanceDataset.ps1` | governance, collected once for both consumers (AB#6779) | 2 always (`authorizationresources`, `policyresources`), issued from the raw pass |
| `src/collect/Invoke-Collect.ps1` | typed assessment pack | 1 (`sqlDefenderPricing`) by default; 35 under `-Source TypedQueries` |
| `Modules/Private/Extraction/Get-AZTIManagementGroups.ps1` | expand a management group into its subscriptions | 1, only when `-ManagementGroup` is supplied |
| `manifests/collectors/Management/AllSubscriptions.ps1` | one inventory collector's own lookup | 1, during processing |
| `src/ingest/Import-Governance.ps1` | governance ingestor | 1 (management groups), only for assessments whose manifest lists `Ingest = 'Governance'`. Was 3; the other two moved to `Get-ScoutGovernanceDataset` (AB#6779) and are skipped here when the collect pass supplies them |
| ~~`src/ingest/Invoke-ArgQueryPack.ps1`~~ | *(deleted, AB#6774)* — opt-in ARG query pack ingestor | All six of its queries duplicated data `Invoke-Collect` already collected, and it overwrote the collector's results with `Add-Member -Force`. A manifest that still names the ingest is ignored with a verbose line rather than erroring |
| `scripts/Export-ScoutFixture.ps1` | developer fixture capture | not part of a product run |

`Modules/Private/Extraction/Start-AZTIGraphExtraction.ps1` and
`Modules/Private/Extraction/Invoke-AZTIInventoryLoop.ps1` **used to** be call sites. The first is
now a parameter-translation shim with no query text and no ARG call; the second is deleted.

## Before and after

Measured with a counting stub in place of `Search-AzGraph`, and pinned by
`tests/Collect.SinglePassInversion.Tests.ps1`.

| Entry point | v2.7.0 | after AB#5648 |
|---|---|---|
| Assessment-only collect (`Invoke-AzureScout -Assessment`, default) | **35** | **4** |
| Assessment collect, `-Source TypedQueries` (opt-in) | 35 | 35 |
| Assessment collect, `-FromInventory` (combined run) | 1 | 1 |
| Inventory extraction (`Invoke-AzureScout`, default switches) | 8 | 8 |
| Combined inventory + assessment, end to end | 9 | 9 |

Excluded from those numbers because they are conditional on flags or manifest entries, and
unchanged by this work: the management-group expansion (1, only with `-ManagementGroup`), the
`AllSubscriptions` collector (1, during processing), and the two ingestors.

### Governance (AB#6779)

Rendering role assignments, policy assignments, resource locks and budgets as worksheets added no
round trip. It moved two of them:

| | before AB#6779 | after |
|---|---|---|
| `Get-ScoutGovernanceDataset`, inside the raw pass | — | 2 ARG + 2 ARM REST per subscription |
| `Import-Governance`, on a run the collect pass fed | 3 ARG + 2 ARM REST per subscription | 1 ARG, 0 REST |
| **Total, assessment run** | **3 ARG + 2/sub REST** | **3 ARG + 2/sub REST** |

The inventory-only run does pay the 2 ARG + 2/sub REST it did not pay before, because it did not
previously collect governance at all — that is the cost of the four worksheets existing, and it is
the only place the number moves. Both sides are counted in
`tests/Collect.Governance.Tests.ps1`.

## Why the inventory number is 8 and not 1

The inventory extraction reads eight **distinct** Resource Graph tables. They are not different
filters over one table, so they cannot be merged into one query without dropping datasets:

`resourcecontainers`, `resources`, `networkresources`, `SupportResources`,
`recoveryservicesresources`, `desktopvirtualizationresources`, `advisorresources`, plus the
file-backed retirement query. `securityresources` makes a ninth when `-SecurityCenter` is
supplied.

What changed is not the count but the ownership: all eight are now issued by one function, with
one paging implementation (`SkipToken`), one batching rule (1000 subscriptions per call), one
throttle-retry policy and one per-batch error-isolation policy. Before, there were two
independent implementations of that machinery and 43 round-trips across a combined run's two
passes over the same resource types.

## The two documented exceptions to "one pass"

Both are real, both are asserted in the test file rather than hidden:

1. **`sqlDefenderPricing`** reads the `SecurityResources` table (`microsoft.security/pricings`).
   No inventory pass collects it: the inventory `securityresources` query filters to
   `microsoft.security/assessments` with an `Unhealthy` status, which cannot contain a pricings
   row. It stays a live typed query, so a default assessment collect is 3 + 1, not 3.
2. **`Retirements`** is a file-backed KQL query
   (`src/report/renderers/inventory/style/Retirement.kql`) with its own joins over service-health
   data. It is not derivable from the raw row set either. It moved into
   `Get-ScoutRawInventory -IncludeRetirements` so it is issued from the same place as everything
   else, but it is still its own round-trip.

## The trade-off, stated plainly

The round-trip **count** dropped from 35 to 4 for an assessment collect. The raw pass transfers
the full `properties` bag for every resource in scope, where the typed queries transferred narrow
projections — so on a large estate the number of 1000-row **pages** can go up even as the number
of queries goes down. `-Categories` no longer reduces what is *fetched* (it still filters what is
shaped and returned).

This is the same trade the combined-run `-FromInventory` path has made since v2.5.0.
`-Source TypedQueries` remains available for a narrow single-category collect where projection
size matters more than call count.

**Unverified:** the page-count effect has not been measured against a large live estate. The
numbers in this document are query counts from a mocked run, not page counts or wall-clock time.

## Non-ARG data sources

Not Resource Graph. Every one of these is a control-plane or data-plane call with **no Resource
Graph table at all** — they are not resources, they are point-in-time computed data — so none of
them can be folded into `Get-ScoutRawInventory` no matter how the raw row set is shaped.

As of the second half of AB#5648 all four run from `src/collect`. The `Modules/Private` files
are parameter-translation shims that issue no Azure call of their own.

| Source | Cmdlet / endpoint | Implementation (live) | Shim |
|---|---|---|---|
| ARM REST — resource health, managed identities, advisor score, reservation recommendations, policy | `Invoke-RestMethod` over 7 ARM endpoints | `src/collect/Get-ScoutApiResources.ps1` | `Modules/Private/Extraction/Get-AZTIAPIResources.ps1` |
| VM quotas | `Get-AzVMUsage` | `src/collect/Get-ScoutVmQuotas.ps1` | `.../ResourceDetails/Get-AZTIVMQuotas.ps1` |
| VM SKU details | `Get-AzComputeResourceSku` | `src/collect/Get-ScoutVmSkuDetails.ps1` | `.../ResourceDetails/Get-AZTIVMSkuDetails.ps1` |
| Cost Management | `Invoke-AzCostManagementQuery` | `src/collect/Get-ScoutCostInventory.ps1` | `Modules/Private/Extraction/Get-AZTICostInventory.ps1` |

### Call counts per default inventory run

None of these are Resource Graph round-trips, so they do not appear in the table above. They
are listed here because they are the rest of the answer to "how many times do we call Azure",
and on a large tenant they dominate it — the ARM REST pull alone is **7 sequential calls per
subscription** with 200ms of deliberate pacing between them.

| Source | Calls | Scope | Gated by |
|---|---|---|---|
| ARM REST | 7 × subscriptions (4 × when `-SkipPolicy`) | per subscription | `-SkipAPIs` |
| VM quotas | 1 × (subscription, location) pairs that actually contain a VM or VMSS | per subscription **and** region | `-SkipVMDetails` |
| VM SKU details | 1 × distinct locations that actually contain a VM or VMSS | per region | `-SkipVMDetails` |
| Cost Management | 1 × subscriptions | per subscription | `-IncludeCosts` (off by default) |

The quota and SKU calls are targeted rather than exhaustive: only regions the tenant actually
deploys into are queried, which is the v1 behaviour and is preserved.

`tests/Collect.NonArgInversion.Tests.ps1` pins this two ways — an AST assertion that no file
under `Modules/` calls any of these five cmdlets any more, and an equivalence comparison against
the retired v1 implementations (reproduced verbatim in that file) over identical stubbed Azure
responses, compared key by key.

### Deliberate behaviour changes

Three, all in the direction of "one optional dataset failing must not destroy its neighbours",
which is the AB#5636 defect class:

1. A failed `policyStates/summarize` call no longer discards the two Policy **definition** lists.
   v1 wrapped all three in one `try`, so a denial on the first — the one most often denied —
   threw away two lists that were never attempted.
2. A `Get-AzVMUsage` failure for one (subscription, region) pair skips that pair instead of
   terminating the whole quota pass. Likewise `Get-AzComputeResourceSku` per region.
3. A VM row with no location no longer produces an empty-string region lookup.

Two shapes were deliberately **kept** rather than "improved", because a consumer depends on them:

- `CostData` is not wrapped in `@()`. `Get-ScoutCostAnomaly` reads the raw shape with
  `$item.CostData.PSObject.Properties['Row']`, which is `$null` on an array — wrapping it
  produced zero anomaly records with no error.
- The API-resource result elements stay **hashtables** with the v1 key names
  (`ReservationRecomen`, `PolicyAssign`, `PolicyDef`, `PolicySetDef`), because
  `Start-AZSCExtractionOrchestration` reads them by string through `Get-AZSCCollectedValue`'s
  `IDictionary` branch.

### Still standing, and why

| File | Verdict |
|---|---|
| `Get-AZTIManagementGroups.ps1` | **Left standing.** It issues one ARG query, only when `-ManagementGroup` is supplied, to expand a management group into its subscriptions. It runs *before* collection to decide the subscription scope, so it cannot be served from a pass that has not happened yet. Folding it into `Get-ScoutRawInventory` would mean two passes, which is the thing this epic is removing. |
| `Get-AZTISubscriptions.ps1` | **Left standing.** Wraps `Get-AzSubscription`/`Get-AzContext`; no Resource Graph, no duplication. |
| `Start-AZTIEntraExtraction.ps1` | **Left standing.** Microsoft Graph, not ARM. Different service, different token audience, nothing in `src/collect` covers it. |
| `Start-AZTIDevOpsExtraction.ps1` | **Left standing.** `dev.azure.com` REST, not ARM. Same reasoning. |

After this work exactly two files under `Modules/` still call `Invoke-RestMethod`:
`Start-AZTIDevOpsExtraction.ps1` (Azure DevOps) and `Modules/Private/Main/Invoke-AZTIGraphRequest.ps1`
(Microsoft Graph, which is what the Entra extraction goes through). Both are named individually
in the AST test's allow-list rather than excluded by directory, so a third one cannot appear
unnoticed.
