---
description: Master design and delivery plan for Azure Scout — the single source of truth for architecture, work items, audit findings, and roadmap.
---

# Azure Scout — Master Design & Plan

> **Status:** Living document. This is the single consolidated source of truth for
> the Azure Scout evolution: architecture, all work items, audit findings and their
> fixes, new feature requests, and the release plan. When something is found,
> decided, or shipped, it is recorded here and reflected in ADO.

- **ADO project:** `This Is My Demo — Azure Scout` (dev.azure.com/hybridcloudsolutions)
- **GitHub repo:** `thisismydemo/azure-scout`
- **Working branch:** `claude/repo-access-wexuku`
- **Governance:** HCS split source-of-truth — ADO masters Epic→Feature→Story→Task; GitHub masters Bug/Feature-request intake.
- **Last updated:** 2026-07-21

---

## 1. Vision

Extend Azure Scout from an inventory tool into a **read-only CAF/WAF landing-zone
assessment platform** with a modern, tiered reporting engine — and make CAF/WAF
analytics available **per discovery domain**, not just as a whole-tenant roll-up.

## 2. Architecture — three layers, JSON on disk

```
COLLECT  --collect.json-->  ASSESS  --findings.json-->  REPORT
(extend, exists)            (new)                       (rebuild)
```

The JSON-on-disk contract lets each layer run independently: collect once and
assess later, or re-render reports from an existing findings set without
re-scanning. **Read-only throughout** (Reader at MG root + read-only Graph).

Repository layout (implemented on the working branch): `src/Invoke-AzureScout.ps1`,
`manifests/assessments.psd1`, `src/assess/` (engine + rules + benchmarks),
`src/ingest/`, `src/report/` (+ renderers + templates), `.ado/azure-pipelines.yml`.
See [`src/README.md`](https://github.com/thisismydemo/azure-scout/blob/main/src/README.md).

## 3. Scope model — how Scout collects

- **Default = tenant-wide**: `Get-AzSubscription -TenantId` returns every accessible subscription.
- **"Root MG down = everything"** holds **when the identity has Reader at the tenant-root management group** (inheritance is what delivers full coverage). Collection is access-driven at the subscription plane; the MG hierarchy is captured as inventory and used as a *filter*, not a tree-walk.
- `-ManagementGroup` narrows to a subtree; `-SubscriptionID` narrows to specific subs; `-Category` narrows to a resource domain.

---

## 4. Current state (verified)

- **ADO ↔ GitHub reconciled**: 91 ADO items (#315–#405) ↔ 91 GitHub issues (#1–#161), 1:1 linked. GitHub issues carry `ado-tracked` + ADO-link comment; ADO items carry a Hyperlink to their GitHub issue and are parented to Epic #5023.
- **Standards applied**: detailed descriptions (what/why/in-scope/out-of-scope), acceptance criteria, area paths (Collect/Assess/Ingest/Benchmark/Report/Platform), iterations (`2026-Q3-S1..S6`), vocabulary tags.
- **Code scaffolded** on the working branch (commit history): full three-layer tree + CAF/WAF rule files + tiered reporting + docs.

---

## 5. Work-item index

### Epic AB#5023 — CAF/WAF landing-zone assessment platform
9 new Features + 23 stories, plus 79 reconciled existing Features/Stories/Bugs.

| Feature | Area | Focus |
|---|---|---|
| AB#5024 | Platform | Module registry + `Invoke-AzureScout` entry point |
| AB#5027 | Assess | Declarative rule engine (JSONPath, evaluator, loader) |
| AB#5031 | Assess | CAF 8-area + WAF 5-pillar rule files |
| AB#5034 | Assess | Assessment runner + dual CAF/WAF scoring |
| AB#5037 | Ingest | AzGovViz + ARG query pack + Advisor → `collect.json` |
| AB#5041 | Benchmark | ALZ benchmark diff |
| AB#5044 | Report | Tiered renderer engine (PowerBi/Html/Pptx/Excel/Json) |
| AB#5050 | Platform | Permission pre-flight + unattended pipeline |
| AB#5053 | Report | React report variant + cross-run drift tracking |

### Epic AB#5056 — Per-domain CAF/WAF analytics across all categories
Foundation + one Feature per Scout category (independently runnable, categorized, tagged).

| Feature | Scope |
|---|---|
| AB#5057 (+ stories #5058–#5060) | Taxonomy: manifest `Category`/`Frameworks`/`Tags`, `-Assessment <Category>` scoped run, assessment registry doc |
| AB#5061 | Management (sub-bundles: Governance, Policy, UpdateManager, Backup, Automation) |
| AB#5062 | Monitor (Monitoring, Alerting, Diagnostics) |
| AB#5063 | Networking (Connectivity, Firewall, PrivateLink) |
| AB#5064 | Identity (PIM, ConditionalAccess, RBAC) |
| AB#5065 | Security (Defender, KeyVault, SecureScore) |
| AB#5066 | Compute (Resiliency, CostCleanup) |
| AB#5067 | Storage (DataProtection, Redundancy) |
| AB#5068 | Databases (Resiliency, DataProtection) |
| AB#5069 | Containers (AKS, Registry) |
| AB#5070 | Web (AppService, Functions) |
| AB#5071 | Analytics (Purview, DataPlatform) |
| AB#5072 | AI (ResponsibleAI, PrivateAI) |
| AB#5073 | Integration (Messaging, APIM) |
| AB#5074 | Hybrid (Arc, AzureLocal) |
| AB#5075 | IoT (IoTHub, DPS) |

### Reconciled existing Features (from GitHub) — AB#315–#405
Collectors, runtime/auth/pipeline, and the reporting/diagram features. Full list in ADO under Epic #5023. Mapped to code files on the working branch.

---

## 6. Audit findings & recommendations

Cross-layer correctness audit (2026-07-20). **All findings are now logged as authored ADO Bugs (AB#5076–#5092), each parented to the Feature that owns the fix and tagged `audit`.** Severity: 🔴 wrong/lost data · 🟠 robustness · 🟡 polish.

| Bug | Finding | Parent Feature |
|---|---|---|
| AB#5076 | MG query unpaged (drops subs >1000) | AB#353 |
| AB#5077 | Bare `Exit` kills host/runbook | AB#353 |
| AB#5078 | >200-sub batch off-by-one / double-count | AB#354 |
| AB#5079 | One bad sub aborts whole tenant run | AB#397 |
| AB#5080 | No zero-resources guard | AB#401 |
| AB#5081 | `Invoke-Collect` adapter missing | AB#5024 |
| AB#5082 | Discovery↔assessment data-shape mismatch | AB#5024 |
| AB#5083 | JSONPath `.length` + exception-as-Pass | AB#5027 |
| AB#5084 | Benchmark silent all-Fail w/o governance | AB#5041 |
| AB#5085 | `percentageAtLeast` zero-denom / value:0 | AB#5027 |
| AB#5086 | WAF-RE-05 no "where supported" | AB#5031 |
| AB#5087 | `AreaWeight` dead / unweighted framework score | AB#5034 |
| AB#5088 | `Unknown` rules silently dropped | AB#5034 |
| AB#5089 | Null severity sorts to top / PPTX crash | AB#5034 |
| AB#5090 | HTML null area score renders red | AB#5044 |
| AB#5091 | Banker's rounding / Excel sheet collision | AB#5044 |
| AB#5092 | Power BI join needs stable `AreaKey` | AB#5044 |

### Discovery / collection (`Modules/`)
| Sev | Location | Finding | Fix | Track under |
|---|---|---|---|---|
| 🔴 | `Get-AZTIManagementGroups.ps1:25` | `Search-AzGraph -First 1000` unpaged — drops subs past 1000 in large MGs | Add `SkipToken` paging loop | new Bug → AB#354/#353 area |
| 🔴 | `Get-AZTIManagementGroups.ps1:34`, `Start-AZTIGraphExtraction.ps1:61` | Bare `Exit` kills host/runbook, uncatchable | `throw` instead | new Bug |
| 🔴 | `Invoke-AZTIInventoryLoop.ps1:41-82` | Off-by-one inclusive range → subs double-queried/double-counted | `..($NEnd-1)` + clamp | new Bug |
| 🟠 | `Invoke-AZTIInventoryLoop.ps1:50-96` | Fallback query unwrapped — one bad sub aborts whole tenant | try/catch + continue | new Bug |
| 🟠 | orchestrator | No "0 resources extracted" guard | add top-level warning | AB#401 (empty-data guard) |
| 🟡 | `AllSubscriptions.ps1:61` | MG-path enrichment capped at 1000 (cosmetic) | page or flag | new Bug |

**Correct as-is:** main inventory loop pages correctly; default = all accessible subs; MG hierarchy captured top-down; permission model matches "Reader @ root MG → everything".

### Assessment (`src/assess/`)
| Sev | Location | Finding | Fix | Track under |
|---|---|---|---|---|
| 🔴 | `Invoke-AzureScout.ps1:63` | `Invoke-Collect` (flat→nested adapter) does not exist — assessment can't run end-to-end | Build the adapter, or rewrite rule queries against the flat collector schema | AB#5024 |
| 🔴 | rules vs `Modules/**` output | **Data-shape mismatch**: rules assume nested ARM tree (`$.networking.virtualNetworks[*].properties…`); collectors emit flat Excel-row objects → every query returns 0 → false Fail / vacuous Pass | Adapter or rule rewrite (same as above) | AB#5024/#5031 |
| 🔴 | `caf.network.yaml:8`, `waf.reliability.yaml:8` | Newtonsoft JSONPath doesn't support `.length` in filters; exception swallowed → for `countEquals 0` reads as false **Pass** | Precompute scalar counts in adapter; make `Resolve-JsonPath` distinguish "threw" from "0 matches" | AB#5027/#5031 |
| 🔴 | `Compare-Benchmark.ps1` | Silently all-Fail when `$Collect.governance` unset (AzGovViz not run) | Guard: return Unknown/skip when governance absent | AB#5041 |
| 🟡 | `Invoke-Rule.ps1:42` | `percentageAtLeast` zero-denominator → Fail instead of Unknown; `value:0` always passes | Treat 0-denom as Unknown | AB#5027 |
| 🟡 | `waf.reliability.yaml` WAF-RE-05 | Zone rule has no "where supported" qualifier → false negatives | Scope to zone-eligible SKUs | AB#5031 |

### Analytics / scoring & reporting (`Get-Score.ps1`, `src/report/`)
| Sev | Location | Finding | Fix | Track under |
|---|---|---|---|---|
| 🔴 | `Get-Score.ps1:32-37` | `AreaWeight` is dead data; framework score is unweighted mean of area scores | Weight by rule count or `AreaWeight`, or remove the field | AB#5034 |
| 🔴 | `Get-Score.ps1:18` / `Invoke-Rule.ps1:47` | `Unknown`-status rules silently dropped from denominator — broken rule *raises* score with no signal | Surface `Unknown` or fail loudly | AB#5034 |
| 🔴 | `Get-Score.ps1:40-43`, `build_deck.py:46` | Null/unknown severity sorts to **top** of exec gap list and crashes PPTX on `.upper()` | `$sevRank[...] ?? 99`; defensive `.get()` | AB#5034/#5048 |
| 🟠 | `report.html.template:34` | Null area score renders **red** (`null>=50` false) though text shows "—" | Null-check the class expression | AB#5047 |
| 🟡 | `Get-Score.ps1:24,35` | Banker's rounding at report thresholds | `MidpointRounding::AwayFromZero` | AB#5036 |
| 🟡 | `Export-Excel.ps1:18` | 31-char sheet-name truncation can merge two areas' evidence | disambiguate on collision | AB#5049 |
| 🟡 | `Export-PowerBi.ps1` | Star-schema join by raw `(Framework,Area)` text — fragile | emit normalized `AreaKey` | AB#5046 |

---

## 7. New feature requests / decisions captured here

- **Per-domain CAF/WAF analytics** (Epic AB#5056) — every category an independently runnable, tagged assessment. **Added.**
- **Release/build ledger** — [`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md). **Added.**
- `azure-scout` retained as a de-facto repo tag (not in the formal vocabulary) — pending decision to keep or strip.
- GitHub roadmap projection (Flow 2) for approved Features — **not done** (bot-only per standard); pending "approve + project" decision.

## 8. Open actions (next)

1. ✅ **Log the §6 audit findings as ADO Bugs** — done: AB#5076–#5092, parented to their Features.
2. ✅ **Unblock assessment** (AB#5081, AB#5082, AB#5083) — `src/collect/Invoke-Collect.ps1` normalized ARG adapter added; `.length` filters rewritten to scalar fields; `Resolve-JsonPath`/`Invoke-Rule` surface thrown queries as `Error`. _Committed, static-validated, not yet runtime-verified._
3. ✅ **Discovery data-loss fixes** (AB#5076, AB#5077, AB#5078) — SkipToken paging, `Exit`→`throw`, batch off-by-one. _Committed, static-validated._
4. ✅ **Scoring/reporting holes** (AB#5084, AB#5085, AB#5087, AB#5088, AB#5089, AB#5090) — weighted framework score, Unknown/Error surfaced, deterministic rounding, severity-null sort, HTML null-neutral, benchmark governance guard, PPTX severity guard. _Committed, static-validated._
5. **Remaining — needs a PowerShell + Az environment:**
   - **Runtime-verify** the above (run `tests/Assessment.Engine.Tests.ps1` + an end-to-end `-FromCollect` pass) — no `pwsh`/Az in the authoring environment, so all fixes above are parse/brace-validated only.
   - **Wire the module manifest** (`AzureScout.psd1`) to dot-source `src/` functions so `Invoke-AzureScout`, `Invoke-Collect`, etc. load as a module (AB#5024).
   - Author the **per-category rule content** and manifest entries (Epic AB#5056).
   - Remaining polish bugs: AB#5086 (zone "where supported"), AB#5091 (Excel sheet collision), AB#5092 (Power BI AreaKey), AB#5079/#5080 (discovery fallback isolation + zero-resource guard).

### Planning gap-check (2026-07-21)
Full ADO scan: **161 items** (2 Epics, 106 Features, 29 Stories, 24 Bugs) — **0 missing priority, 0 missing acceptance criteria, 0 orphaned items, 0 non-vocabulary tags.** The board is internally consistent.

### Delivery state (2026-07-21)
**All 161 items are New (planned/backlog).** ADO reflects planning only — no item is marked delivered, because nothing has been verified.

Some implementation code exists on branch `claude/repo-access-wexuku` (the assessment platform scaffold, per-domain rules, and audit fixes), but it is **prototype/unverified** — static-validated only (no pwsh/Az to run it) — and is **not** claimed as done on the board. Work items advance out of New only when their acceptance criteria are actually met and verified.

## 9. Release plan

See [`RELEASES.md`](https://github.com/thisismydemo/azure-scout/blob/main/RELEASES.md). Summary: v1.1.0 (quality), v1.2.0 (collector depth), **v2.0.0** (assessment platform — major, breaking output surface), **v2.1.0** (per-domain analytics).

---

## Change log for this document

| Date | Change |
|---|---|
| 2026-07-21 | Initial master plan consolidating architecture, work-item index (Epics #5023 + #5056), the cross-layer audit findings, new feature requests, and the release plan. |
| 2026-07-21 | Logged all 17 audit findings as ADO Bugs (AB#5076–#5092) parented to their Features; ran full ADO gap-check (0 missing priority/AC/parent/tag issues). |
| 2026-07-21 | Implemented the critical-path fixes: `Invoke-Collect` adapter, scalar-field rule rewrites, JSONPath error-surfacing, weighted scoring + Unknown/Error surfacing, reporting null-guards, benchmark governance guard, and the 3 discovery data-loss fixes. Committed and static-validated (no pwsh/Az to runtime-verify). |
| 2026-07-21 | Added per-domain CAF/WAF analytics prototype (Epic AB#5056): domain ARG collection, 15 category assessments + sub-bundles in the manifest, 10 rule files, registry doc; wired `src/` into the module as `Invoke-ScoutAssessment`. |
| 2026-07-21 | Corrected an overreach: 64 items had been moved to Resolved prematurely — reverted all to New. ADO now reflects planning only; no item is marked delivered until its acceptance criteria are verified. |
