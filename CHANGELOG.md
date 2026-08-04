# Changelog

All notable changes to the AzureScout module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.3.4] - 2026-08-04 — one report, and it is the deliverable

Azure Scout produced six rendered report formats. A full multi-tenant render, read end to end,
found every one of them weak in a different way: a dashboard that drew its headers and no data, a
maturity report scoring 10/10 with no explanation of what it measured, documents that never named
which assessment they were, text drawn over text in the PDF, figures running off the slide, and a
Word file that opened with a repair prompt. Six renderers maintained in parallel is *why* none of
them reached deliverable quality.

### The React report is now the product's deliverable

One self-contained page hosts the inventory and every assessment behind an adaptive shell — the
navigation is built from what actually ran, so an inventory-only run shows inventory, and a full
run shows inventory plus per-assessment detail. Each assessment answers three questions in order:
what was run (scope, checks executed, and what was **not** assessed and why), what was found
(findings with their evidence and real resource ids), and what to fix against CAF/WAF guidance.

Every score is shown with its own arithmetic — numerator, denominator, and what was excluded as
not-applicable — so a number can be checked rather than trusted. That is the direct answer to a
maturity report that claimed 10/10 while a landing-zone assessment of the same tenant scored 36%.

### Every other rendered format is on hold (AB#6922)

`-OutputFormat All` now renders the React report plus the machine-readable data exports.
`Json`/`JsonEvidence` are deliberately **not** held — they are data, not documents, and the corpus
harness and drift history read them.

A held format asked for **by name** warns, is skipped, and the React report renders anyway, so a
run never returns an empty folder. The parameter still accepts every format name, so existing
scripts bind and get an explanation rather than a parameter-binding failure. The default
`-OutputFormat` moves from `Html` — itself now held — to `React`.

The renderers are untouched and still tested. They are being rebuilt to generate **from** the
React report rather than alongside it, so that a document and the page it came from can no longer
disagree. Lifting the hold is a one-line edit.

### A cited guidance URL returned 404 (AB#6913)

The CAF Platform automation design area was cited as `.../platform-automation-and-devops` and
stamped "verified 2026-08-01". That URL 404s; the canonical page has no "and". Those citations are
surfaced to the reader as *the guidance for this finding*, so the deliverable carried a dead link.

A verified-date stamp is not protection — Microsoft renamed the page after the verification and
nothing looked again. `scripts/Test-ScoutGuidanceLinks.ps1` now HEADs every cited Learn URL across
the rule files and reports each dead one with its file and line. It is a script rather than a
Pester test on purpose: it needs outbound network, and a CI suite that fails when Microsoft has a
bad afternoon is a suite people learn to ignore. 26 citations audited; this was the only rotted
one.

## [3.3.3] - 2026-08-03 — the corpus told the truth: five collection defects, none visible from a green suite

Every fix in this release was found by re-collecting eight real tenants into the banked corpus
and refusing to explain away an empty dataset.

### The v3.3.2 vault fix never reached the result (AB#6896)

`recoveryVaults` was shaped correctly from raw rows — and then dropped on the floor. The copy
loop walks `$q.Keys` and the key has no typed query, so it was never visited; and the fallback
guard tested `$r.PSObject.Properties['recoveryVaults']` on a **hashtable**, whose PSObject
adapter exposes `Keys`/`Values`/`Count` and never the keys, so the branch was unconditionally
dead. Vaults now copy explicitly, and `tests/Collect.ShapedDatasetsReachTheResult.Tests.ps1`
fails if any shaped dataset has neither a `$q` entry nor an explicit copy — the next silent
hand-off loss cannot go unnoticed.

### Export-Pptx shadowed the collect walker and corrupted every product collect (AB#6897)

Export-Pptx defined its own module-scope `Get-ScoutProp`, loaded after the collect walker of the
same name. Every **product** run (which loads the whole module) read nested `properties.*` as
null — subnets, TLS versions, retention days — while every harness probe (which dot-sources only
the collect layer) passed. The banked corpus this poisoned mis-diagnosed three healthy
collectors as broken. The renderer helper is renamed, and
`tests/Module.FunctionNameCollisions.Tests.ps1` bans same-name module-scope functions outright.
The walkers also gained `IDictionary`/`JObject` support (AB#6899).

### Management groups were empty on every run in the product's history (AB#6901)

The Resource Graph query for management groups never passed `-UseTenantScope`, so it returned
rows only for subscriptions' implicit scope — zero, everywhere. Fixed with a tenant-scoped
query: 92 management groups across the eight reference tenants, where every prior run banked
none.

### security.defenderPlans existed only as a hardcoded empty array (AB#6903)

The collect contract shipped `defenderPlans = @()` from the day it was written, while
`caf.security.yaml` and `waf.security.yaml` carry live rules querying
`$.security.defenderPlans[?(@.properties.pricingTier == 'Standard')]` — those rules could never
pass on any tenant. The old corpus explanation ("Defender not enabled in these estates") was
proven false live: one reference subscription carries 18 Microsoft.Security/pricings plans, 4 of
them Standard. Plans are now collected per subscription over plain ARM REST — no Az.Security
dependency — and an unregistered Microsoft.Security provider stays quiet (AB#6900's phrasing
fix, which also stopped a raw "Please register to Microsoft.Security" warning surfacing mid-run).

### Two runs in the same second no longer overwrite each other (AB#6902)

`Invoke-ScoutAssessmentCore` stamps its run folder `yyyyMMdd_HHmmss`; a second run inside the
same second shared the folder, overwrote the first run's artefacts, and replaced (rather than
appended) its drift-history record. The run id now takes a `_NN` suffix on collision. Found by
the drift-accumulation test on a fast CI runner.

### The corpus is now a committed, integrity-checked harness (AB#6898)

`scripts/Invoke-CorpusCollect.ps1` collects all eight reference tenants with per-tenant
service-principal auth and refuses to bank silently-bad data (relationship checks: a VNet
without subnets, workspaces all-null retention, protected items without a vault).
`scripts/Invoke-CorpusCoverage.ps1` renders a per-collector verdict over a banked run: 36
collect keys working, 23 empty-everywhere with a maintained explanation each, **0 unexplained**.

## [3.3.2] - 2026-08-03 — field fixes: Advisor, licence detection, and two collector defects

Fixes found by running against real customer tenants rather than fixtures.

### One bad subscription no longer costs the tenant

Get-AzAdvisorRecommendation could abort the Advisor sweep for an **entire tenant** and surface
as a raw stack trace mid-run:



That is a defect in Az.Advisor 3.0.0 — Azure returned a plain-text error sentence (almost
always Microsoft.Advisor not registered on that subscription) and the generated cmdlet
deserialises it as JSON regardless. Scout cannot prevent it, but it can contain it: the try/catch
is now **per subscription**, each failure is named, the parse error is translated into what it
actually means, and a closing summary gives the Register-AzResourceProvider command that fixes
it.

### A licence boundary is no longer reported as a permission denial

IdentityRiskyUser.Read.All reported [FAIL] DENIED — grant this permission on tenants that
had already consented to it. Identity Protection is an **Entra ID P2** feature; without P2 the
endpoint returns nothing however much consent it has, so that advice could never work — and since
most tenants do not carry P2, the **common** case was being reported as an error.

Scout now reads subscribedSkus and reports NOT LICENSED — requires Microsoft Entra ID P2,
naming the product and stating that granting the permission will not help. The affected collectors
are still reported as *Not assessed*, so the coverage gap stays visible.

The licence check is three-state — licensed, not licensed, or **could not tell**. Only a definitive
*not licensed* softens the verdict; if the SKU list itself cannot be read the verdict stays
Fail, because silently downgrading a real denial would hide a genuine problem.

### Recovery Services vaults are collected

management.recoveryVaults was **hardcoded to an empty array**, so no run in the product''s
history has ever reported a vault — while backupProtectedItems returned rows. A child with no
parent. Found by auditing eight banked tenants; costs no extra Resource Graph round-trip, because
the vault lives in the ordinary resources table the raw pass already reads.

### A landing-zone audit scores the landing zone

LandingZone declared Rules = caf.*, waf.*, which by now swept in every workload rule set —
AI, AVD, Azure Local, IoT, AVS — each of which has its own assessment. A run selecting LandingZone
scored **34 areas where the audit covers 14**, and the evidence workbook grew a visible tab for
each. The eight CAF design areas and five WAF pillars are now enumerated, and a new workload rule
file can no longer join by filename alone.

### Also

- GovernanceReport was missing from the -OutputFormat All list, so the CAF Govern maturity
  score never rendered on a default run.
- Evidence truncation is now visible: a finding with 198 matches said 25 and looked identical to
  one with 26. Rows now read *25 of 198 matched*.
- Docs: licence tiers (what needs P1, what needs P2, what needs neither) and both field errors.

### Known limitation

networking.subnets returns no rows. Diagnosed, not yet fixed — it is not shipped half-verified.

## [3.3.1] - 2026-08-03 — figures reach every format, and the Power BI pages actually bind

Completes the two clauses v3.3.0 shipped as known limitations.

### Figures in the deck and the PDF (AB#6883)

v3.3.0 embedded figures in Word only. They now appear in all three:

- **PowerPoint** — one figure per slide, embedded as a real picture part. One idea per slide, so
  no grid; the figures are counted against the 15-slide cap rather than added after it.
- **PDF** — previously the renderer could embed only a baseline JPEG, which is why the manual
  `diagram.jpg` drop-in convention existed. It turns out not to be needed: **PDF's `/FlateDecode`
  is zlib**, exactly what the rasteriser already produces, so the raw pixels embed as an image
  XObject with no decode round trip, no JPEG, and no new dependency.

### The Power BI pages bind to the model (AB#6886)

v3.3.0 opened the project and presented three pages of empty placeholders. A visual container
needs **three** serialised blobs — `config`, `query` and `dataTransforms` — and only
`config` was written, so nothing told Power BI which field belonged in which well. It drew the
frames and left them empty, **with no error anywhere in that path**: the project was structurally
valid and the visuals were simply unbound. That is why every file-shape assertion passed while the
report was useless.

All eleven visuals across the three pages now carry their query and field-well mapping. Clause
`B-05` is met.

### Verified

All eight tenants re-rendered offline from banked collect data: **29 artefacts each, 0 empty**.

## [3.3.0] - 2026-08-03 — Epic AB#6450: the reports become deliverables

Every report Scout produced was, in the owner's words, *"not worth putting in front of an
executive"*. **103 report work items on this board were already Closed** — every one of them
accepted on "a file came out", not one carrying an acceptance criterion naming a required section
or a reader. This release fixes the output *and* fixes the reason it stayed broken.

### The quality bar, and the test that enforces it

- `docs/design/report-conformance.md` is now **normative**: 40 numbered clauses across Word,
  PowerPoint, Excel, diagrams, Power BI and the run contract.
- `tests/Report.Conformance.Tests.ps1` asserts every `automatic` clause **against an emitted
  package read back off disk** — never against intent. **A renderer item may no longer be closed
  on the existence of a file.**
- The four `judged` clauses are deliberately *not* automated. Faking them would recreate the
  false-green problem the bar exists to prevent.

### Word — from three package parts to a document

Phase 0 measured the root defect: the `.docx` contained **three parts** and **0 of 1,803
paragraphs carried a style**. That one fact explained the missing navigation pane, the impossible
TOC, the absent cross-references and the un-rebrandable output.

- Real **styles**, **numbering** (chapters are numbered, so a cross-reference means something),
  and a **theme** carrying the palette — rebranding is now swapping a colour scheme.
- **Header and footer** referenced by the section properties, with `PAGE`/`NUMPAGES` as real
  fields rather than text that would be wrong the moment anyone edited the file.
- A real **TOC field**, a **cover** naming client, assessment, scan date and classification, and a
  **Document Information** block stating provenance and version.
- Chapters take the reference deliverable's shape: **scorecard → current state → findings →
  action items**. Tables over 30 rows move to an appendix with a pointer.

### Figures, with no new dependency

The diagram pipeline emitted `.drawio` and nothing else, so **no document could embed a figure**.
AzViz, Graphviz, D2, a headless browser and ImageMagick were all rejected on one test: *a report
that silently loses its figures because a native binary is missing is worse than one that never
promised them.* Figures are now rasterised to PNG in managed code and embedded as image parts.

### Power BI — a project, not a blank canvas

The old output was four CSVs and a `.pbit` whose authored layout was **2,190 bytes**. It is now a
**PBIP project**: TMDL semantic model, four real relationships, eleven DAX measures, a date
dimension, and authored report pages. Verified with Microsoft's own TMDL parser and opened in
Power BI Desktop.

### Deck and workbook

- The deck states **what was not assessed** and carries exactly **one** "act on this first" slide
  naming a specific item; it is bounded at 15 slides by construction.
- The workbook gains a **Cover** with scope, legend and a per-tab record count; every evidence row
  carries its **full ARM resource id** (or "None matched", which is not the same as blank) and a
  **triage verdict** seeded for review rather than guessed.

### Correctness

- **"Not assessed" is honoured everywhere** — excluded from the compliance denominator, given its
  own scorecard column and its own figure segment, never rendered as a zero or a pass.
- **Two defects only a real multi-tenant run could find.** Scout's `Export-Excel` shared a name
  with the cmdlet exported by ImportExcel — which that renderer imports — so ImportExcel's command
  shadowed ours and **every per-assessment workbook silently failed**. Renamed to
  `Export-ScoutEvidenceWorkbook`. `Get-ScoutExcelProp` also threw on evidence rows that are not
  objects. Both were live while the conformance suite was green.

### Known limitation

The Power BI report **pages render as placeholders**: the model loads and the pages exist, but the
visuals show no data. Clause `B-05` is **not** met and is not claimed. The remaining work is the
visual bindings, not the model.

## [3.2.0] - 2026-08-01 — Epic AB#6454: deep governance and compliance analytics

Scout goes from **one real assessment to roughly twenty-eight**, and from **one enumerated source
framework to all fourteen**. Releases 2 through 6 of the audit plan in `docs/audits/AZURE-SCOUT-AUDIT.md`.

### Assessments added

- Five WAF pillars, eight CAF landing-zone design areas, and the WAF Maturity Model.
- Microsoft Cloud Security Benchmark plus one assessment per assigned regulatory initiative,
  scored from policy compliance state Scout already collected and no rule read.
- Cloud Governance across CAF Govern's seven risk categories, with a 1-10 domain maturity report.
- Workload reviews: AI, Azure Virtual Desktop, Azure VMware Solution, AVS Landing Zone, CASA,
  and Azure Local.
- FinOps Review and DevOps Capability Assessment.

### Correctness

- **Three-state reporting.** `NotAssessed` is a first-class status, excluded from every score
  denominator by construction and still counted and surfaced. A control nobody chose to evaluate
  no longer reads as a pass or a fail.
- **`assert.gate`.** A rule whose data source was blocked returns Not assessed, never Fail. A
  denied billing API stops rendering as zero spend; `-IncludeDevOps` off stops rendering as "no
  pipelines".
- **Two false-pass rules removed** (CAF-GOV-05, CAF-AUT-02). Both asserted only that some policy
  assignment had a parameters block. The test had been asserting the false pass.
- **`waf.storage.yaml` retired** — it scored a WAF pillar that WAF does not define — and a gate
  now fails any rule file claiming a pillar, design area or framework axis that does not exist.
- **Every rule file carries `frameworkversion`**, and `Get-RuleSet` throws at load without it, so
  no coverage figure can ship without naming the framework version it was measured against.
- An assigned initiative Scout cannot confirm is built-in is reported Not assessed and named,
  rather than producing a silent empty report.

### Collection

- `Hybrid/ArcSites` and `Hybrid/VirtualMachines` re-sourced off Resource Graph, which does not
  index either type. Verified live: 1 and 7 real rows respectively where Resource Graph returns 0.
- Orphaned role assignments resolved locally against already-collected Entra principals, with
  "Graph denied" kept distinct from "principal deleted".
- Owned-reservation utilization collector; the five Azure DevOps collectors moved into a real
  DevOps category.

### Fixed

- `.gitignore` credential patterns were silently excluding five generated collector goldens,
  making the suite green locally and red in every clone.
- `tests/Report.SectionIndex.Tests.ps1` failed Pester discovery and had never run.
- The collect-once contract regressed to 11 Resource Graph round-trips while workload datasets
  were added; restored to 5.

### Documentation

- `docs/frameworks/` now holds all fourteen enumerated source frameworks — 59 WAF checklist items,
  393 CAF recommendations, and the workload and question sets — each carrying its source URL,
  framework version, extraction date and verification method.

### Added — AB#6746 (Epic AB#6454) restructure LandingZone into per-pillar/per-design-area assessments

- **Five WAF pillar assessments** (`WAF: Reliability`, `WAF: Security`, `WAF: Cost Optimization`,
  `WAF: Operational Excellence`, `WAF: Performance Efficiency`), each scoring only its own pillar's
  rule file. `LandingZone`'s WAF framework score reconciles with the weighted sum of these five by
  construction (AB#6796).
- **Eight CAF landing-zone design-area assessments** (`CAF: Azure billing and Microsoft Entra
  tenant`, `Identity and access management`, `Resource organization`, `Network topology and
  connectivity`, `Security`, `Management`, `Governance`, `Platform automation and DevOps`).
  Design-area weights are proportional to each area's verified Microsoft-published recommendation
  count (`docs/design/caf-design-area-weighting.md`), not a flat 1.0 (AB#6797).
- **`WAF: Maturity Model` assessment.** Reuses the same five WAF pillar rule files with zero
  duplicated rule definitions and reports Microsoft's published 5-level maturity model per pillar
  (`src/assess/engine/Get-MaturityLevel.ps1`, `docs/design/waf-maturity-model-mapping.md`).
  `Get-Score` now attaches a `MaturityLevel` to every area/framework score it produces (AB#6800).

### Fixed — AB#6798 false-pass rules and misclassified rule files

- **`CAF-GOV-05` and `CAF-AUT-02`** claimed a Pass whenever any policy assignment had a
  `parameters` block — true of nearly every estate — without checking whether the assignment was
  actually a DeployIfNotExists/Modify effect. Both are `manual` now; collect.json does not carry a
  resolved policy effect to score this automatically without reintroducing the false pass.
- **`waf.storage.yaml` retired.** "Storage" is not a WAF pillar (WAF has exactly five). Its five
  rules were redistributed into `waf.reliability.yaml` (durability/redundancy/recovery) and
  `waf.cost.yaml` (lifecycle/tiering).
- **`caf.billing.yaml` rewritten.** It previously held cost-optimization rules that duplicated
  `waf.cost.yaml` under the CAF "Azure billing and Microsoft Entra tenant" design-area name — a
  mismatch, since that design area is about EA/MCA/tenant setup, not cost telemetry. The two
  non-duplicate cost rules moved to `waf.cost.yaml` (`WAF-CO-08`, `WAF-CO-09`); the file now holds
  genuine (manual) billing/tenant rules — break-glass accounts, MFA on subscription creators,
  billing RBAC review, tenant topology, subscription vending.
- **New CI-style gate** (`tests/Assessment.Restructure.Tests.ps1`): every `framework: WAF` rule
  file's `area` must be one of the five pillars; every `framework: CAF` rule file must either be
  one of the eight design areas or declare `kind: service-guide` with a `designAreaRef` pointing
  at one. The nine per-service CAF rule files (`ai`, `analytics`, `containers`, `databases`,
  `hybrid`, `integration`, `iot`, `storage`, `web`) now carry that `kind`/`designAreaRef` pair.

### Updated — AB#6799 retired/changed CAF guidance

- **`CAF-GOV-06`** now names the current default landing-zone management-group set (`Corp`,
  `Online`, `Local` — added for Azure Local/hybrid clusters — plus `Sandboxes` and
  `Decommissioned`), not the older `Corp`/`Online`-only pair.
- **Verified: no rule requires a dedicated AI landing zone.** CAF states explicitly that AI
  workloads use the existing landing zone architecture; `caf.ai.yaml` was checked and does not
  require one (pinned by a test).
- **Verified: no rule tags the five retired CAF governance disciplines** (Cost Management,
  Security Baseline, Identity Baseline, Resource Consistency, Deployment Acceleration) as a live
  taxonomy — none did.
- **Every rule file now records a `verifiedAgainst` guidance version/date** (24 files, all
  verified 2026-08-01 against the specific Microsoft Learn page(s) it scores against).

Hardening pass over real-world collection and reporting failures. See **Epic AB#6731**. Suite:
2,243 tests — 2,236 passing, 3 skipped, 4 known cross-file flakes (VM quota context restore,
Excel retired-registration, two `Test-AZSCPermissions` scoping tests) that fail only in a
full-suite run and pass in isolation.

### Added

- **`-InventoryAndAssessment` (alias `-Both`)** on `Invoke-AzureScout`. The collect-once path —
  inventory and a scored assessment from one Resource Graph collection — used to be reachable
  only by answering the wizard's "run both?" prompt, which no script or CI pipeline could reach;
  they had to invoke the command twice and collect from Azure twice (AB#6773–6777).
- **Two evidence artifacts, written to every run folder:** `raw-inventory.json` (everything the
  Resource Graph pass collected, before any manifest filtered it down to a worksheet — roughly
  40% of collected data never reached a report) and `collector-rowcounts.json` (per-collector
  Rows / Empty / Failed verdicts, so a `Rows: 0` line can be told apart from a broken collector).
  Neither lives in `ReportCache`, so neither is removed by end-of-run cache cleanup (AB#6764–6766).
- **A per-collector permission-impact table** in the `-PermissionAudit` pre-flight, replacing a
  bare READY/PARTIAL verdict as the whole answer. It names every collector a denied permission
  will leave empty and which permission fixes it — a verdict word could read READY over
  worksheets that were about to come back empty; a list cannot lie the same way (AB#6765).
- **Tenant-wide collection, unconditional.** Management groups, custom role definitions, policy
  definitions and policy set definitions are now always collected — a dead `-IncludeTenantWideResources`
  migration gate that no production caller ever set had been silently discarding all four
  (AB#6755–6759).
- **A resource-type existence gate** (`manifests/azure-provider-types.json`, 316 providers, 4,661
  type pairs) checks every declared collector resource type against Azure at build time. Its
  first run found eight real defects; **six collectors were retired and three corrected** as a
  result, taking the collector count from 242 to **236** (AB#6842, 6772, 6767, 6768).

### Changed

- **Fifteen per-category assessment names are now prefixed `Assess: `** — e.g. `'Assess: Compute'`
  instead of `Compute` — because they collided with the inventory `-Category` value of the same
  name (one filters what is *collected*, the other what is *scored*). Legacy unprefixed names
  still resolve, with a warning naming the new value. The `Estate` entry (inventory with no
  scoring rules) no longer appears in the wizard's assessment menu (AB#6754, 6762, 6763).
- **Three Azure RBAC roles dropped from the ask** — Security Reader, Monitoring Reader and Cost
  Management Reader — from the pre-flight, `docs/automation.md` and the customer grant list. They
  are redundant: every read they grant is already inside `Reader`'s `*/read`. Two are worse than
  redundant — Monitoring Reader and Cost Management Reader both carry `Microsoft.Support/*`, which
  includes support-ticket *creation*, a write, in a tool sold as read-only. Cost data was never
  gated on Cost Management Reader either; it is gated on the EA/MCA billing setting, which no RBAC
  role can grant (AB#6761, 6778).
- **Two Graph permissions dropped from the pre-flight** for a different reason — `AuditLog.Read.All`
  and `IdentityProvider.Read.All` are consumed by no collector at all. The pre-flight now reports
  any such permission as "queried but unused — do not grant" rather than probing it every run
  (AB#6765).

### Fixed

- **A combined run collected from Azure twice.** `-InventoryAndAssessment`/wizard-both now defers
  the assessment until after the inventory pass and hands it the inventory's already-collected
  rows instead of re-querying the same resource types (part of AB#6773–6777, alongside a tags-loss
  regression in the handoff and `AdvisorScores` not being fed from `$ExtractionData.Advisories`).
- **Tenant-wide collection was still conditional after the first attempt to fix it.** The dead
  gate above was initially replaced with `-not $SkipAPIs` — the same trap, and factually wrong: only
  policy definitions come from the REST sweep, while management groups and custom roles come from
  Az cmdlets that `-SkipAPIs` has no business touching. The parameter was deleted; `-SkipAPIs` now
  only degrades the REST sweep, in its own `try` block (AB#6755, correction).

See [`.ai/state/HANDOFF.md`](https://github.com/thisismydemo/azure-scout/blob/main/.ai/state/HANDOFF.md)
for the full session account, including what this epic left open (governance-data rendering,
`ResourceDiagnosticSettings` re-sourcing, `LighthouseDelegations`, network-diagram rasterization,
and 40 remaining child-loop collectors that can still drop their parent resource on a sparse
payload).

## [3.1.0] - 2026-07-31

Service coverage across Microsoft's eighteen published categories. See **Epic AB#6741**.
Measured against the audit's per-service table, coverage rises from **41% to 66%** (144 → 232 of
349 enumerated services); the table in `docs/audits/AZURE-SCOUT-AUDIT.md` §6 was recounted
mechanically, not asserted.

### Added

- **Three new categories.** `Migration`, `General` and `DevOps` now exist as first-class
  categories with their own collector directories, `-Category` values and wizard entries. Scout
  modelled fifteen of Microsoft's eighteen; it now models all eighteen. Migration went from zero
  collectors to complete coverage of all five of its services (AB#6830, AB#6831, AB#6838).
- **62 new collectors**, generated from a reviewable spec (`manifests/specs/service-collectors.psd1`)
  by `scripts/Build-ScoutServiceCollector.ps1`. Every resource-type string is taken from the ARM
  template reference and pinned by a test against the spec.
  - *Migration*: Azure Migrate projects, assessment projects and discovery sites; Database
    Migration Services; Data Box; Azure Stack Edge.
  - *General*: owned Reservations; VM Quotas — the `AZSC/VM/Quotas` envelope Scout has always
    fetched and never displayed.
  - *DevOps*: Chaos Studio, Dev centers/projects, Dev Box pools, network connections, deployment
    environments, DevTest Labs, Lab Services, Load Testing, Managed DevOps Pools, Playwright
    workspaces, App Configuration, API Connections.
  - *Integration* (3 → 13 of 15): **Logic Apps**, integration accounts, custom connectors, Event
    Grid, Event Hubs clusters, Relays, Health Data Services.
  - *Web* (6 → 22 of 22): App Service Environments, Static Web Apps, Function Apps, deployment
    slots, certificates, domains, SignalR, Web PubSub, Communication Services, Notification Hubs,
    Fluid Relay, Spring Apps.
  - *Storage* (3 → 15 of 17): snapshots, disk encryption sets, Elastic SAN, Storage Sync, Edge
    Hardware Center, Data Lake Gen1, partner storage.
  - *IoT* (8 → 18 of 19): DPS, IoT Central, Device Update, Digital Twins, Azure Maps, Defender
    for IoT.
  - *Security* (6 → 18 of 19): Sentinel, Managed HSM, Cloud HSM, application security groups, WAF
    policies, DDoS protection plans, Confidential Ledger, artifact signing, Entra Domain Services,
    App Compliance Automation.
- **Six collectors that render the child resources** — `Security/KeyVaultSecrets` and
  `KeyVaultKeys` (with computed days-to-expiry and an expiry status, and certificate-backed
  secrets classified as such), `Storage/BlobContainers` (with an explicit anonymous-access
  verdict per container), `Storage/FileShares`, `Storage/LifecyclePolicies` and
  `Management/BackupInstances`. Collecting the data without a collector to render it would have
  repeated the collect-versus-display defect §5.3 of the audit is about — fetched every run and
  thrown away.
- **Child-resource collection** (AB#6833, AB#6834). Six new `Get-ScoutArmChildResource` datasets:
  Key Vault secrets and keys, storage blob containers, file shares and lifecycle policies, and
  Backup vault instances. All control plane — **no secret value and no blob content is ever
  read**, and nothing needs more than Reader. Certificate expiry arrives on the certificate's
  backing secret, identified by `contentType`; Azure publishes no ARM list endpoint for
  certificates themselves.
  **Cost, stated up front:** these are per-parent REST calls, so an inventory run now makes two
  extra calls per key vault, three per storage account and one per Backup vault. Each is
  independently non-fatal — a failure warns and omits that one child collection. On a large
  estate this is the most expensive thing in the release; if it proves material, gate it on
  `-Category` rather than leaving a switch nobody sets (the failure mode
  `-IncludeTenantWideResources` demonstrated).
- **Cross-resource rules** (AB#6835). The rule engine can now express a condition spanning two
  collected datasets, declared as data (`join:` in place of `query:`) — so adding the next such
  rule needs no engine change. Six ship in `src/assess/rules/xr.crossresource.yaml`, including
  *which VMs have no backup*, *which storage accounts and key vaults have no private endpoint*,
  and *which snapshots outlived their source disk*. Every finding names both resources.
- **SMART migration-readiness assessment** (AB#6832), with its source framework enumerated and
  date-stamped first in `docs/frameworks/smart-question-set.md` — including an explicit statement
  of what could NOT be enumerated (Microsoft publishes no SMART question text or numbering). Rules
  cite enumerated items, and a test fails any rule citing an item the enumeration does not contain.
- `scripts/New-ScoutCollectorGolden.ps1` — the golden-record writer. The golden suite has always
  had a reader and no writer, so a new collector could not be added without hand-authoring a file
  whose format was defined only by the code that read it.

### Fixed

- **Logic Apps were excluded from collection outright.** `microsoft.logic/workflows` sat in the
  Resource Graph query's `!in` exclusion list, described in a comment as a "designer workflow
  def" — it is the Logic App itself. One of the most common resources in Azure was invisible in
  every release, in Scout's thinnest category, with no way for a user to opt back in.
- **The golden collector suite failed on any day but the one it was recorded on.**
  `Management/Backup` computed "days since last backup" from `Get-Date` inside its own preamble,
  so its committed record drifted by one every calendar day. The interpreter now binds a single
  `$ScoutRunTime` per collector, which the golden harness pins — and which also removes a
  same-run inconsistency where each row read a slightly different instant.
- **The wizard never listed the real assessments.** It resolved `manifests/assessments.psd1` by
  climbing three directories from `src/`, landing outside the repository; the path never existed,
  so it silently fell back to a hard-coded list of one.
- `-Category DevOps` and `-Category Migration` were documented as aliases for `Management` but
  were absent from the `[ValidateSet]`, so parameter binding rejected them before the alias map
  was consulted. Both are now real categories.
- **AB#6839 — a collector lost its whole worksheet when Azure omitted an optional property.**
  Reading a `properties` key the payload does not carry throws under `Set-StrictMode -Version
  Latest`, and because the row script is one statement the run lost every row that collector would
  have produced. Estate-wide and pre-existing — `Integration/APIM`, shipped since v1, failed on
  `virtualNetworkType` exactly as the new `Integration/LogicApps` failed on `integrationAccount`.
  The row, filter and setup scopes now run at `Set-StrictMode -Version 1.0`, which still errors on
  an uninitialised variable — the protection that matters and that a fixture *can* exercise — while
  reading a missing property as `$null`. One change in the interpreter covers all 242 collectors
  identically, and **all 242 golden records are byte-unchanged**, so it alters no existing output.
  `tests/Collector.SparsePayload.Tests.ps1` builds its estate by *removing* properties, which is
  the one shape the fixture generator can never produce.
- **AB#6844 — 75 unguarded string-method calls on payload values.** A collector that called
  `….subnetResourceId.split('/')[8]` threw *"You cannot call a method on a null-valued
  expression"* whenever Azure omitted the property, taking the whole worksheet with it. This is a
  null *method call* rather than a property read, so AB#6839's fix does not prevent it. 75 sites
  across 46 definitions now route through the existing `Get-AZSCIdSegment` helper, which returns
  `$null` for an absent id or an out-of-range index and the identical segment otherwise.
  `Integration/APIM` also guarded its VNet lookup, which tested `virtualNetworkType -eq 'None'`
  when an instance that is not VNet-injected omits the key entirely.
- Two further sparse-payload failures the extended test exposed, both pre-existing and both
  estate-visible: `Analytics/Databricks` cast `[datetime]$null` on a workspace whose deployment
  never completed, and `Networking/NetworkSecurityGroup` assigned `$FinalNICs`/`$FinalSubs` only
  inside conditional branches, so an NSG associated with neither a NIC nor a subnet hit
  StrictMode's uninitialised-variable check. Both took the whole worksheet down.
- **AB#6845 — an AKS cluster vanished from the report when its agent pools were absent from the
  payload.** `Containers/AKS` emits one row per agent pool, so a cluster with no
  `agentPoolProfiles` produced no row at all and disappeared from the worksheet — no error, no
  warning, just one cluster fewer. Its loop now sets `EmitNullWhenEmpty`, so the cluster appears
  with blank pool columns instead. This is the most dangerous of the four sparse-payload classes
  because it is the only one that does not throw.

  **The other 42 collectors have now had that per-collector reading, and the audit is closed.**
  Of the 50 child row loops in the estate, 26 never had the defect — their source variable is
  assigned through a conditional with a non-empty fallback (`$Auths =
  if(...){$data.authorizations}else{'0'}`), so the loop always runs at least once. **18 more loops
  across 15 collectors did have it and are fixed**: `Compute/AvailabilitySets`, `Compute/AVD`,
  `Containers/ContainerApp` (both loops), `Containers/ContainerAppEnv`,
  `Containers/ContainerGroups`, `IoT/IOTHubs`, `Management/AdvisorScore`, `Monitor/Outages`,
  `Networking/NATGateway`, `Networking/NetworkInterface`, `Networking/RouteTables`,
  `Networking/VirtualNetwork`, `Networking/VirtualWAN`, `Networking/vNETPeering` (two of its three
  loops) and `Web/APPServices`. Three loops are deliberately left unguarded and documented as such,
  because the row there IS the child: both of `General/Quotas`' loops fan out a synthetic quota
  envelope whose every column is read off the loop variable, and `Networking/vNETPeering`'s peering
  loop feeds a worksheet that inventories PEERINGS — an unpeered VNet belongs on the Virtual
  Networks sheet, where it already appears.

  Some of these were not edge cases at all. `Containers/ContainerAppEnv` fanned out over
  `workloadProfiles`, which is absent on every **Consumption-plan** environment — the default —
  so those environments were missing from the report while their dedicated-plan siblings appeared.
  `Compute/AvailabilitySets` computed `Orphaned = $true` for a set with no VMs and then dropped the
  row, making the one condition the collector exists to flag the one condition it could never
  report. `Networking/NATGateway` did the same for the idle-gateway cost finding.

  Two consequences of reaching code that was previously unreachable had to be fixed with it.
  `Monitor/Outages` and `Management/AdvisorScore` each cast a payload value straight to
  `[datetime]`, which throws on `$null` and takes the whole worksheet down — previously the row was
  dropped before the cast was reached, so both casts are now guarded. And
  `Networking/VirtualNetwork` carried a switch whose `Default` branch was a bare `$null`, lifted
  verbatim from the original collector where it was a harmless no-op; under the interpreter the row
  script's output stream IS the row set, so it emitted a **phantom null row**. Its committed golden
  record contained twelve of them.

  `tests/Collector.VanishingParent.Tests.ps1` now holds the class open for inspection: it empties
  each child loop against the collector's real fixture and asserts the parent survives, and it
  requires every child loop in the estate to be one of the three reviewed states — so a collector
  written next year with an unguarded child loop fails on the day it is added.
- **239 of the 242 golden records are byte-unchanged across every one of these fixes**, so nothing
  that works today renders differently. The three that moved are the point of the exercise rather
  than collateral, and each was read line by line before it was re-recorded: `Compute/AVD` gains
  the one host pool in its fixture that has no session hosts, `Networking/VirtualWAN` gains the one
  virtual WAN that has no hub — both previously missing from their worksheets — and
  `Networking/VirtualNetwork` **loses twelve phantom null rows** that the bare-`$null` switch
  branch had been writing into the record all along.

### Changed

- `SupportTickets` and `ReservationRecom` moved from `Management` to `General`. Their output is
  unchanged — the golden records prove the rows are byte-identical.
- `scripts/New-ScoutCollectorFixture.ps1` gained `-PreserveExisting`. Regenerating a category
  fixture to add one collector used to re-derive its neighbours' estates with the current
  generator, silently weakening their proofs (`Security/DefenderAlerts` lost a populated property
  and a compared column became `N/A`).
- The assessment collect pass projects `id` on virtual machines, storage accounts and key vaults,
  and adds backup protected items, snapshots, managed disks, disk encryption sets and the
  Migration domain — the join sources the cross-resource rules read.
- A rule file may declare a `requires:` data prerequisite. When none of its paths returns rows the
  whole set reports **Unknown** instead of scoring: "0 migrate projects with public access" and
  "no migrate project exists" are the same count and opposite findings.

## [3.0.9] - 2026-07-30

### Fixed

- `Export-AZSCJsonReport` crashed every run at the final report-export step with "The property
  'Count' cannot be found on this object" under StrictMode. A cache-section lookup wrapped a
  possibly-`$null` value in an `if/else` that produced a bare scalar instead of a real array in
  one path; it now always wraps through `@(...)`.
- The `SupportTickets` declarative collector crashed with "Cannot convert null to type
  System.DateTime" whenever a ticket's `createdDate`, `problemStartTime`, or `modifiedDate` was
  absent. All three now null-guard before the cast.
- Each report-format export (Excel/JSON/Markdown/AsciiDoc/PowerBI) is now individually wrapped in
  its own try/catch, so one failing format can no longer abort every other format in the same run.
- `ARCServers.CpuMetrics` queried an ARM Insights metric that Arc-enabled servers cannot ever
  serve (guest-OS metrics are not exposed through that API for `Microsoft.HybridCompute/machines`)
  and failed 400 for every Arc machine, every run. The call is removed in favor of a clear
  "not supported for Arc" status.
- `Invoke-ScoutOperationalArm` (the VM/Arc/storage operational-enrichment helper) had no
  retry/backoff at all. A 429 (rate limit) or transient 5xx now retries up to 3 times with
  backoff instead of failing immediately; a 409 (operation already in progress, e.g. patch
  assessment) is now recorded as a distinct in-progress status rather than a generic error.
- `VirtualMachine.ReplicationEligibility` logged a failure-looking warning on a 404, which is the
  expected state for any VM Azure Site Recovery has never evaluated. It's now recognized as
  "not configured" and no longer warns.
- The guided wizard's own Step 2 permission audit could report full Entra ID readiness while the
  wizard never asked about `-Scope`, silently defaulting the run to `ArmOnly` and collecting zero
  Entra ID data. `Test-AZSCPermissions` now surfaces `OverallReadiness`, and the wizard asks
  whether to include Entra ID data when the account is fully permissioned for it.
- The wizard's "Cost data" option offered no warning if `Az.CostManagement` wasn't installed,
  silently producing empty cost data discovered only deep into a run. The wizard now detects this
  and offers an explicit, user-confirmed install at the point of choice.
- A `Get-AzSecurityAlert` null-reference exception (typically Defender for Cloud not fully
  provisioned on the subscription) now surfaces a clearer hint instead of the bare CLR message.

## [3.0.8] - 2026-07-29

### Fixed

- Suppressed Az module breaking-change warnings so they no longer clutter non-debug output.

## [3.0.7] - 2026-07-29

### Fixed

- Avoided a StrictMode `VariableIsUndefined` error when common parameters such as `-Debug` were
  supplied to `Invoke-AzureScout`.

## [3.0.6] - 2026-07-28

### Fixed

- Enhanced resilience and logging for the Excel report build and ARC-enabled server collection.

## [3.0.5] - 2026-07-28

### Fixed

- Cost Management returns VM cost rows as nested arrays. The VM collector now extracts the
  amount cell before conversion, preventing one cost response from skipping all VM rows.

### Verification

- Repeated-`MemoryGB` and nested-cost-row declarative VM regression contract: 1 passed / 0 failed.
- Clean PowerShell Gallery **3.0.5** install, live tenant, `-Scope ArmOnly` (2026-07-29):
  174 declarative collectors run, 0 failed, 1,121 Excel rows written, and the Excel report
  completed successfully in 4:59. The immutable run evidence is retained under
  `D:\tmp\AzureScoutGallery305ArmOnly-20260729\scout-run.log`.

## [3.0.4] - 2026-07-28

### Fixed

- A live Compute SKU payload can repeat the `MemoryGB` capability. The VM report calculation
  now selects one usable value before numeric conversion, so that shape cannot skip the entire
  `Compute/VirtualMachine` collector.

### Verification

- Repeated-`MemoryGB` declarative VM regression contract: 1 passed / 0 failed.

## [3.0.3] - 2026-07-28

### Fixed

- Enabled ARM child-resource collection, storage operational enrichment, and the subscription
  security/policy sweep in the production extraction path rather than leaving them opt-in helpers.

### Verification

- Raw inventory contract: 18 passed / 0 failed.
- Single-pass and StrictMode graph-extraction contracts: 22 passed / 0 failed.

## [3.0.2] - 2026-07-28

### Fixed

- Stopped issuing requests to Azure's retired Application Insights Continuous Export and
  Work Item Config endpoints.
- Storage blob and file service-property lookups now enter the owning subscription and
  never fall back to an unrelated ambient context when that switch fails.

### Verification

- App Insights child-resource contract: 9 passed / 0 failed.
- Operational storage-enrichment contract: 5 passed / 0 failed.

## [3.0.1] - 2026-07-28

### Fixed

- Tenant-scoped runs now pass the requested tenant through every subscription-context
  switch, including quota collection, Defender/security sweeps, Advisor ingestion, and
  permission-audit restoration. This prevents authentication attempts against unrelated
  cached tenants.
- The guided wizard remains available when an interactive operator supplies a PowerShell
  common parameter such as `-Debug` or `-Verbose`.

### Verification

- A live tenant-scoped run completed with 174 declarative collectors, zero collector
  failures, no unrelated-tenant authentication attempts, and a generated Excel report.

## [3.0.0] - 2026-07-28

### Changed

- Completed Epic AB#5638: production collection and reporting now run the 174-definition
  declarative catalog under StrictMode; no imperative collector fallback remains.
- Retired `Modules/Public/InventoryModules` and moved the remaining engine implementation to
  `src/`.
- Replaced source-script equivalence with committed canonical golden contracts for 174 ordered
  row sets and 348 workbook cases.

### Verification

- All 174 definitions validate and execute against strict optional-property fixtures.
- Category-level, deterministic-pipeline, rendering, and golden row/workbook contract tests pass.

### Documentation

- **Corrected the claim that the engine rebuild is finished.** Epic AB#5638 was closed as complete
  and released under that framing in v2.9.0, v2.10.0 and v2.11.0; it has since been **reopened**,
  because it never met its own acceptance criteria. The release entries below are unchanged — every
  one of them shipped and is on the PowerShell Gallery — but the "Epic AB#5638 completes" line on
  v2.11.0 now carries a correction, and `docs/roadmap.md` states the remaining work with measured
  numbers rather than implying the rebuild is done.

## [2.11.0] - 2026-07-26

Epic **AB#5638** completes.

> **Correction — 2026-07-26.** *The line above was wrong when it was written, and Epic AB#5638 has
> been reopened.* Everything described in this entry shipped and is real; what was false was the
> claim of completion. The epic's own acceptance criteria are not met, measured on `main`:
>
> | Acceptance criterion | Measured |
> |---|---|
> | `Modules/` is deleted and no code path depends on it | **221 `.ps1` files** still present |
> | `Modules/Public/InventoryModules/` is empty (AB#5659) | **176 collector `.ps1`** still present |
> | All 176 collectors expressed as definitions (AB#5656) | **138 of 176** (`manifests/collectors/*.psd1`) |
> | `Set-StrictMode -Version Latest` in every module scope | **20 weakening sites** across 19 files — 4 live, 15 dead |
> | Inventory and assessment share one reporting layer | **Not cut over** — `Start-AZSCExcelJob` still walks `Modules/Public/InventoryModules/` and executes each collector's own reporting branch |
>
> Verify with `scripts/Test-StrictModeGuard.ps1` and a file count under `Modules/`. See
> [the roadmap](docs/roadmap.md) for what remains before the fork can be deleted.

### Changed

- **138 of 176 collectors are now declarative** (AB#5659), up from 124.

  The audit had classified 20 **cross-resource-join** collectors as escape-hatch, alongside those
  making live cmdlet calls. Re-examining all 48 showed the audit's *reasons* were accurate but its
  *inference* was not: **a cross-resource join is not the same thing as a live cmdlet call.** Every
  one of those 20 filters the already-collected resource set a second time for another type and
  correlates against the result — data shaping over data the pipeline already holds. The only
  missing capability was somewhere to put statements that run **once**, before the row loop.

  Two schema keys were added: **`SetupPreamble`** (the contiguous verbatim source above the row
  loop) and **`SetupVariables`** (the names it exports). Names are **declared, not harvested** —
  harvesting sweeps up automatic variables, and a preamble that stopped assigning a variable would
  otherwise silently stop binding it. The interpreter throws on any declared name it cannot
  resolve, and the loader rejects either key without the other.

  Verified live: the run log reports **138 declarative, 36 imperative**.

### Added

- **Collector definitions are gated in CI** (AB#5661). A validator runs as its own step **before**
  the test suite, so a violation annotates the offending `.psd1` in the pull-request diff rather
  than surfacing as an empty worksheet at runtime. Seven checks:

  1. The definition parses and satisfies the schema.
  2. The generated row script parses — the `if`/`else`-statement-as-field class that was silently
     unreachable before.
  3. Every preamble parses on its own.
  4. Every exported column resolves to a declared field. The five known blank columns are
     allow-listed **by name with a reason**, so a sixth fails the build **and a fixed one also
     fails** — the list can only shorten.
  5. Every declared `SetupVariable` is statically assigned by its preamble.
  6. `SourceCollector` exists.
  7. **Drift** — regenerating the definition from its source collector must reproduce the file byte
     for byte.

  Check 7 exists because a definition **had already drifted for a release while its equivalence
  test stayed green** — with StrictMode off, the stale and current property accessors agreed on the
  fixture. Nothing in the repository could have caught it.

  The gate is **proven to fail**, not assumed to: 13 tests each write one deliberately broken
  definition and assert both a non-zero exit **and** that the message names the fault — after first
  asserting a correct definition passes, so the failure assertions are not vacuous.

### Fixed

- **The conversion tool could never have converted `Web/APPServicePlan` correctly** — it treated
  *every* filtered assignment as a row source, so that collector's **secondary** filter would have
  been lifted onto the row set itself, **silently dropping every app service plan**.
- A definition that had **drifted** since the StrictMode hardening was regenerated.
- The fixture generator was **not reproducible between processes** — unordered hashtable
  enumeration made every regeneration produce a spurious difference.
- The fixture writer emitted **case-variant duplicate JSON keys**.
- Shape resolution had **no pipeline pass-through**, so a join partner was synthesised carrying
  only the properties its own predicate mentioned — leaving every joined column `$null` on **both**
  paths, and therefore passing equivalence.

### Honest limit — the weakest part of this release

All 14 newly converted collectors agree with their imperative counterpart row for row. But the
generated estate only makes **the join itself** change the output for **5** of them. For the other
**9**, the join partners are present and both paths agree *while both take the not-found branch*.

That is a fixture limitation, not a conversion defect. Each of the 9 is pinned by name with the
specific predicate that defeats the fixture generator. A test removes the partners from the estate
and asserts the output changes, failing both on an unlisted collector **and** on a stale entry — so
that list can only shorten.

### Still imperative — 38, with specific reasons

Those calling `Invoke-AzRestMethod` inside the row loop; those making live `Get-Az*` calls with no
resource-type filter to drive the interpreter; three whose row *shape* or *loop depth* is
conditional; one whose row loop iterates a **synthesised** set with no type to declare; and two
written against a registration contract that only ever existed as a test mock.

**No second escape hatch was invented — not having a definition remains it.**

### Not done

**Reporting is still not cut over.** `Start-AZSCExcelJob` executes each collector's own reporting
branch through its own duplicate discovery, so every definition's `Export` section is exercised only
by tests.

### Verification

Live-verified: **5:37**, 136 resources, 481 Excel rows, 514 security advisories, **zero leftover
background jobs, zero collector failures**. Suite: **2937 / 0 / 3**.

## [2.10.0] - 2026-07-26

Epic **AB#5638**.

### Changed

- **The declarative collector definitions actually run** (AB#5656). v2.9.0 shipped 124 of 176
  collectors as `.psd1` definitions, but **nothing called the interpreter** — the live pipeline
  still executed the imperative `.ps1` for every collector, so the conversion delivered nothing to
  a user.

  `Invoke-ScoutCollector` now routes on the `HasDeclarativeDefinition` / `DefinitionPath` that
  `Get-ScoutCollector` already reported: definition present → interpreter, absent → `.ps1`. No
  second discovery mechanism was added.

  **Verified against a live tenant** — the run log now reports:

  ```
  Collectors declarative : 124
  Collectors imperative  : 50
  ```

  Proving this needed a different technique than the conversion did: **a row comparison can never
  detect a routing regression**, because both paths agree by construction. The proof is by
  impossibility instead — a fixture collector has a valid definition and a `.ps1` whose entire
  processing branch is a `throw`, and the run completes with its row present. With the kill switch
  on, the same fixture fails with that exact message, so the switch cannot pass on a sentinel
  string alone.

  A full processing pass over an 845-resource estate produced identical output with the switch on
  and off: **1654 rows either way, zero collector-level deltas, byte-identical ReportCache JSON**.

- **The non-ARG collection half is inverted** (AB#5648, AB#5639). The four functions shipped in
  v2.7.0 and left dead in v2.8.0 — `Get-ScoutApiResources`, `Get-ScoutVmQuotas`,
  `Get-ScoutVmSkuDetails`, `Get-ScoutCostInventory` — are now the real path. The v1 ARM REST, VM
  quota/SKU and Cost Management implementations are retired to shims, proven by AST tests asserting
  that no file under `Modules/` calls `Invoke-RestMethod`, `Get-AzAccessToken`, `Get-AzVMUsage`,
  `Get-AzComputeResourceSku` or `Invoke-AzCostManagementQuery` outside a two-file allow-list.

### Added

- **A kill switch: `AZURESCOUT_FORCE_IMPERATIVE_COLLECTORS`** (`1`/`true`/`yes`/`on`) forces every
  collector down the imperative path. An environment variable rather than a parameter, so it works
  on an already-installed build with nothing threaded through `Invoke-AzureScout`.
  `Invoke-ScoutProcessing -ForceImperativeCollectors` is the programmatic form.

  A definition that fails **schema validation** falls back to its `.ps1` with a warning. An
  **execution** failure does not fall back — it stays contained and reported, as before.

### Fixed

- **Two shape regressions**, both introduced by an `@()` that looked like hardening, caught by the
  per-dataset equivalence comparison: `CostData` wrapped in an array meant `Get-ScoutCostAnomaly`,
  which reads the raw shape through `PSObject.Properties`, would have produced **zero records with
  no error at all**; and returning a collection member unrolled single-element arrays, so every
  endpoint answering with exactly one row changed shape.

- **`Management/ManagementGroups` no longer fails the run.** Its earlier `try`/`catch` stopped the
  crash but left the fallback **returning nothing on every run**, so that worksheet was empty for
  any tenant whose root management-group id is not the tenant id. It now enumerates without
  switches, expands each group by id, and keeps only roots so subtrees are not rendered twice. Six
  tests assert on **the calls made**, because not throwing was already true while it produced no
  rows.

  Note that a tenant still needs **Management Group Reader at the root** — without
  `Microsoft.Management/register/action` the collector returns zero rows **by design** rather than
  failing. This was the only collector failing on every live run, and **this release is the first
  with zero collector failures**.

### Not done — stated rather than implied

**Reporting is not cut over.** `Start-AZSCExcelJob` still executes each collector's `.ps1`
reporting branch, because it walks the module directory with its own duplicate discovery — so every
definition's `Export` section is still exercised only by tests. Mixing the two is safe because the
equivalence suite compares the written workbook **cell by cell**, not because it is assumed.

### Verification

Live-verified: **6:37**, 136 resources, 481 Excel rows, 43 worksheets, 503 security advisories,
**zero leftover background jobs, zero collector failures**. Suite: **2834 / 0 / 3** plus the
StrictMode harness at 174/174.

## [2.9.0] - 2026-07-26

Second wave of the engine rebuild (Epic **AB#5638**).

### Changed

- **124 of 176 collectors are now `.psd1` data rather than PowerShell** (AB#5659), up from 13 —
  AI 19, Monitor 17, Identity 16, Hybrid 14, Databases 13, Networking 12, Management 10,
  Compute 8, Analytics 5, Containers 4, and the rest.

  Every one is pinned by an equivalence test that runs the original imperative collector and the
  declarative definition over the same input, then compares the processed rows **key-by-key in
  order** *and* the written `.xlsx` **cell-by-cell**, under both `-IncludeTags` states.

  Four collectors stay imperative for stated reasons (`Management/AllSubscriptions`,
  `Management/AdvisorScore`, `Networking/PublicIP`, `Monitor/Outages`) and are pinned as test data,
  so shortening that set is a visible edit.

- **All 174 collectors pass under `Set-StrictMode -Version Latest`** (AB#5671), and the recorded
  baseline is empty *because a run says so* rather than aspirationally. Each conversion was proved
  real by running the collector twice with StrictMode off, before and after, and diffing emitted
  rows — 20 of 23 are byte-identical, which is only possible by executing the row-emitting path.

- **A CI guard against weakening StrictMode** (AB#5672), AST-parsed rather than grepped.

### Fixed

- **AB#402 non-terminating-error detection had gone blind.** It compared `$Error.Count` before and
  after a phase, but `$Error` is a fixed-size ring buffer (`$MaximumErrorCount`, 256 by default) —
  so once it saturates the count stops rising, the delta is permanently zero, and non-terminating
  errors stop being reported **entirely**. Silently, and precisely in the long runs where degraded
  datasets matter most. Demonstrated: with the buffer saturated and one new error raised, the old
  technique reports `False`. It now remembers the record at the front of `$Error` and counts by
  reference identity.

- **`ChartP6` root-caused and fixed** (AB#5666). ImportExcel builds a pivot source range from the
  worksheet dimension, and a worksheet that **exists but holds no cells** has a `$null` dimension —
  so the range lookup threw, `Add-PivotTable` downgraded it to a warning, and the chart vanished
  with it. The existing guard tested existence, not emptiness. All 30 call sites now check the
  dimension.

- **An out-of-scope subscription name had changed from `$null` to `''`** during the StrictMode
  conversion, making a single estate render two different blanks depending on which sheet you
  looked at. The declarative equivalence proof caught it on 11 collectors; it would have been
  invisible on the rest.

- **Six interpreter defects**, all caught by the equivalence gate: a field whose source is an
  `if`/`else` **statement** rather than an expression was silently unreachable (`( )` takes a
  pipeline, and `$( )` unrolls a single-element array to a scalar — expressions are now emitted
  unwrapped); per-loop preambles were dropped, so `Security/Vault` lost all three permission
  columns and `Networking/VirtualNetwork` its entire subnet calculation; the tag loop was assumed
  universal and always named `Tag`, when 25 collectors have none and `RouteTables` uses another
  name; resource-type matching was treated as a grouping where `Hybrid/ArcSites` needs arrival
  order; a filter preamble was dropped, so `AI/AppliedAIServices` matched nothing and produced a
  **silently empty sheet**; and tag columns defaulted on, adding columns to 10 Monitor sheets that
  no release has ever contained.

- **`Management/ManagementGroups` was never a StrictMode fault.** It fails parameter binding on
  `Get-AzManagementGroup -Expand -Recurse` with no `-GroupId` — the long-standing *"missing
  mandatory parameters: GroupName"* failure seen on every live run, finally explained.

- **Documentation that was actively misleading:** `docs/github-actions.md`,
  `docs/troubleshooting.md` and `docs/validation-matrix.md` all still said chart customization
  drives Excel over COM and that `lite: true` is mandatory on hosted runners. v2.7.0 made that
  false — those pages were pushing users to disable a working feature.

### Known limits — stated, not buried

- The equivalence fixtures are **generated** by walking each definition's AST, **not recorded from
  a tenant**. They prove the two implementations agree on the same input; they do **not** prove
  either is right about a real estate.
- **The live pipeline still executes the imperative `.ps1` for every collector.** Converting is not
  the same as using; the cutover is staged separately.
- Of the 174 StrictMode passes, **146 emit zero rows** because the recorded capture covers only 32
  resource types. Those passes are real but weak; exact row counts are now pinned for the 25
  meaningfully exercised collectors.
- `Modules/` cannot yet be retired: 101 functions remain across 31 private and 14 public scripts,
  and 52 are still called from other files inside `Modules/`.

### Verification

Live-verified: **4:52**, 124 resources, 438 Excel rows, 42 worksheets, 464 security advisories,
**zero leftover background jobs**. Suite: **2763 / 0 / 3** plus the StrictMode harness at 174/174.

## [2.8.0] - 2026-07-26

### Changed

- **A default assessment collect now issues 4 Azure Resource Graph queries instead of 35**
  (AB#5648, Epic AB#5638).

  v2.7.0 shipped the single-pass collection functions, but **nothing called them** — outside tests
  the only reference to any of them was a comment — so the round-trip count was unchanged. They are
  now the real path.

  Both numbers were re-derived by counting invocations against a stub in place of `Search-AzGraph`,
  and both are pinned by hard count assertions in `tests/Collect.SinglePassInversion.Tests.ps1`.
  A query count with no test regresses silently within a release.

  | Entry point | before | after |
  |---|---|---|
  | Assessment-only collect (default) | 35 | **4** |
  | Assessment collect, `-Source TypedQueries` | 35 | 35 |
  | Collect `-FromInventory` (combined run) | 1 | 1 |
  | Inventory extraction (default switches) | 8 | 8 |
  | Combined inventory + assessment, end to end | 9 | 9 |

  It is **4 rather than 1** for stated reasons: three raw tables (`resourcecontainers`,
  `resources`, `networkresources`) plus `sqlDefenderPricing`, which reads `SecurityResources` and
  genuinely cannot be served from inventory.

  Inventory extraction stays at **8** because those are eight *distinct* ARG tables —
  `resourcecontainers`, `resources`, `networkresources`, `SupportResources`,
  `recoveryservicesresources`, `desktopvirtualizationresources`, `advisorresources` and
  retirements — not filters over one table. Merging them would drop datasets. What changed there is
  **ownership, not count**: one paging implementation instead of two.

### Removed

- **`Modules/Private/Extraction/Invoke-AZTIInventoryLoop.ps1`** — the legacy paging, batching and
  retry engine. A test asserts both that the file is absent and that **no AST command node**
  anywhere in `Modules/` or `src/` still calls it.

- `Start-AZTIGraphExtraction` is reduced to a shim that builds no query text and issues no ARG
  call. Its resource-group, tag and management-group filter clauses moved into
  `Get-ScoutRawInventory`, reproducing the legacy `if`/`elseif` precedence exactly, each with its
  own test.

### Fixed

- **The inverted path returned an empty `tags` array for every estate** — a blank report section,
  no error, invisible to all 2144 passing tests. The raw pass omits the `tags` column unless asked,
  while the collect contract aggregates its top-level `tags` key from `subscriptions[*].tags`
  (AB#367). The internal raw call now requests tags, with a regression test.

### Trade-offs, stated and not yet measured

- The raw pass carries the full `properties` bag where the typed queries carried narrow
  projections, so on a large estate the number of 1000-row pages can **rise** even as the query
  count falls.
- **`-Categories` no longer reduces what is fetched**, only what is shaped.
- `-Source TypedQueries` is the escape hatch for a narrow single-category collect. That path is
  unchanged at 35 queries and remains fully supported.

### Not done — deliberately not claimed

The **non-ARG half** of AB#5648. `Get-ScoutApiResources`, `Get-ScoutVmQuotas`,
`Get-ScoutVmSkuDetails` and `Get-ScoutCostInventory` remain dead code; a live run still uses the v1
implementations for ARM REST resources, VM quota and SKU lookups, and Cost Management. The
round-trip numbers above say nothing about those.

Still standing in `Modules/Private/Extraction/`: `Get-AZTIManagementGroups.ps1` (issues its own
query for management-group to subscription expansion), `Get-AZTIAPIResources.ps1`,
`Get-AZTICostInventory.ps1`, `ResourceDetails/Get-AZTIVMQuotas.ps1`,
`ResourceDetails/Get-AZTIVMSkuDetails.ps1`, `Start-AZTIEntraExtraction.ps1`,
`Start-AZTIDevOpsExtraction.ps1`, `Get-AZTISubscriptions.ps1`.

### Verification

Live-verified against a real tenant: **5:11** runtime, 124 resources, 438 Excel rows,
42 worksheets, 452 security advisories, **zero leftover background jobs**, one collector failing
(`Management/ManagementGroups` — environment and permissions, not a code defect). Suite:
**2160 passed / 0 failed / 4 skipped**.

## [2.7.0] - 2026-07-26

Second phase of the engine rebuild (Epic **AB#5638**).

### Changed

- **The inventory reporting layer moved out of `Modules/`** (AB#5662). All 26 renderers now live
  under `src/report/renderers/inventory/` and `src/report/renderers/inventory/style/`, each file
  renamed to match the function it defines — the legacy `AZTI`-file / `AZSC`-function mismatch is
  gone. Function names are unchanged, so no call site changed behaviour.

- **Excel COM is deleted** (AB#5662). `Build-AZTIExcelComObject.ps1` is gone; chart styling runs
  on EPPlus/ImportExcel only, via the new `Build-AZSCExcelChartStyle`. COM is why `-Lite`
  defaulted to true and why the module surfaced a raw `0x80040154 REGDB_E_CLASSNOTREG` on every
  machine and CI runner without Excel installed. No live COM call remains anywhere in `src/`,
  `Modules/` or `tests/`.

  Verified against a live tenant on a machine with no Excel: a 42-worksheet workbook, with
  `SecurityCenter` carrying 489 rows.

  The EPPlus chart styling is an **approximation** of the former COM styling, documented in the
  function's `.NOTES`. Nobody has yet compared the two workbooks side by side.

- **The Databases collectors are now data, not code** (AB#5656). All 13 ship as
  `manifests/collectors/Databases/*.psd1`, interpreted at runtime by
  `Invoke-ScoutDeclarativeCollector`. `Get-ScoutCollector` was extended to report
  `HasDeclarativeDefinition` and `DefinitionPath` rather than adding a second discovery mechanism.

  Each definition is pinned by an equivalence test that runs the original imperative collector
  and the declarative definition over the same input, then compares the processed rows
  key-by-key **and** the written `.xlsx` cell-by-cell, under both `-IncludeTags` states.

### Added

- **A single-pass collection layer** (AB#5639) — `Get-ScoutRawInventory`, `Get-ScoutApiResources`,
  `Get-ScoutCostInventory`, `Get-ScoutVmQuotas`, `Get-ScoutVmSkuDetails` in `src/collect/`, plus
  an AST-derived resource-type map covering 128 ARM types, 17 cognitive-services `kind` values and
  the VM quota/SKU pseudo-types. One raw pass satisfies **34 of the 35** collect queries;
  `sqlDefenderPricing` reads `SecurityResources` and genuinely cannot be served from inventory.

  **This is capability only.** Nothing in the product calls these functions yet, so a run still
  reaches Resource Graph exactly as many times as it did in v2.6.0. Inverting the pipeline onto
  this layer is **AB#5648** and is not in this release.

- **An AST audit of all 176 collectors** — `docs/design/collector-audit.md`. Of the 163
  non-Databases collectors, **115 are mechanically convertible** and **48 must stay hand-written**:
  29 make live cmdlet calls (18 of them `Invoke-AzRestMethod`), 20 do cross-resource joins, 10
  never filter `$Resources`, and 2 are unimplemented.

- **A StrictMode-safe property accessor** and the first collector converted to use it, with
  recorded live-payload fixtures and edge-case fixtures for the shapes that have historically
  broken runs (AB#5667).

### Fixed

- **Subscription batching never happened on the default path** (AB#5639). An unbound `[string[]]`
  parameter is `$null`, and `@($null).Count` is **1**, not 0 — so the subscription-resolution
  branch in `Invoke-Collect` gated on `.Count -eq 0` never fired. The subscription list was never
  derived from `resourcecontainers`, and every later table degraded to a single un-batched
  tenant-wide call with none of the documented per-batch isolation. The existing test passed
  either way because it asserted only the container count; the regression test now asserts the
  actual `-Subscription` argument.

  This is the **same `@($null).Count` class** that made the Excel loop run every collector
  regardless of data in v2.6.0.

- **Tag columns were appended rather than inserted** in the declarative interpreter (AB#5656), so
  every tagged worksheet came out with its last three columns reordered — all 13 collectors add
  their trailing column *after* the tag block. A definition naming a column that does not exist
  is now a load-time error rather than a silent fallback to appending.

- **`ResourceTypes` was a membership test rather than a grouping** (AB#5656), so `RedisCache` lost
  the ordering its original produced by concatenating `redis` then `redisenterprise`.

- Three callers left pointing at the old reporting paths (`Export-PowerBi.ps1`,
  `tests/OutputFormat.Tests.ps1`, `tests/Private.Processing.Tests.ps1`), plus the `Support.json`
  and `Retirement.kql` path walk-ups.

### Known limitations

- `Management/ManagementGroups` fails on every live run with *"missing mandatory parameters:
  GroupName"* — environment and permissions, not a code defect.
- `RedisCache` exports a blank `Resource Group` column and `SQLMI` a blank
  `ActiveDirectoryOnlyAuthentication` column. Both have been blank in every shipped release; the
  declarative definitions reproduce them faithfully rather than diverge from the imperative path.
- `Identity/IdentityProviders` and `Identity/SecurityDefaults` are still written against a
  registration API that exists only as a test mock and have never produced a row.
- `ChartP6` fails due to an unconditional `Add-PivotTable` in `Build-AZSCExcelChart.ps1`.
- `tests/Web.Module.Tests.ps1` uses a fixed shared temp path and deletes it in `BeforeAll`, so
  concurrent suite runs interfere with each other.

## [2.6.0] - 2026-07-25

### Changed

- **The inventory processing phase no longer uses background jobs** (AB#5649, Epic AB#5638) —
  first phase of the engine rebuild. Processing was four coordinated pieces of job machinery:
  `Start-AZSCProcessJob` (or `Start-AZSCAutProcessJob` under `-Automation`) created one
  `Start-Job` per category, each of which then created one `[PowerShell]::Create()` runspace per
  collector; `Wait-AZSCJob` waited on them; `Build-AZSCCacheFiles` harvested and destroyed them.

  Every defect of the v2.5.x wave lived in that coordination rather than in the collectors:

  | Mechanism | What it produced |
  |---|---|
  | `Start-Job` is asynchronous | a `NotStarted` job was excluded from the wait, harvested empty and then deleted — the category vanished with no trace (AB#5629) |
  | `$Job.Runspace.IsCompleted` | `PowerShellAsyncResult` has no `.Runspace`, so the wait was a no-op and `EndInvoke` raced its own work |
  | each job re-imports the module | module-scope StrictMode returned inside the job, which is why the v2.5.3 opt-out needed **17** entry points rather than 5 |
  | `Get-Job` ordering | the same tenant produced different reports on consecutive runs |
  | the whole estate serialised to JSON per category | 16 round-trips through `ConvertTo-Json -Depth 40` |

  Collectors are pure functions of the resource set, so none of that concurrency was ever
  required. `Invoke-ScoutProcessing` (new, `src/pipeline/`) runs all 176 in-process in a fixed
  order and writes the same `ReportCache` layout. Identical input now produces an identical
  report cache — pinned by a test that hashes the cache files across two runs.

  Resilience improved rather than regressed: each collector's failure is contained
  individually, so one bad collector no longer empties its category or aborts the batch. The
  run reports what failed instead of silently shipping a thinner report.

  The `-Automation` processing branch is gone. It existed only to substitute `Start-ThreadJob`
  where `Start-Job` was unavailable; with no jobs, both modes execute the same code and can no
  longer drift apart — as the two collector-discovery implementations already had.

  Deleted: `Start-AZTIProcessJob.ps1`, `Start-AZTIAutProcessJob.ps1`, `Build-AZTICacheFiles.ps1`,
  `Invoke-AZTIAdvisoryJob.ps1`, `Invoke-AZTIPolicyJob.ps1`, `Invoke-AZTISecurityCenterJob.ps1`,
  `Invoke-AZTISubJob.ps1`. `-Heavy` no longer affects this phase (it only sized the job batch);
  it still applies to extraction.

  The draw.io diagram subsystem still uses background jobs and is unchanged.

### Fixed

- **The Security Center sheet has been empty in every release that had one** (AB#5649) —
  `Invoke-AZSCSecurityCenterJob` was called with `-SecurityCenter $SecurityCenter` against a
  parameter block that declared no such parameter. PowerShell does **not** reject an unknown
  named argument to a simple function; it collects it into `$args` and carries on. So
  `$SecurityCenter` was undefined inside the wrapper, `$null` crossed the job boundary as the
  `-Security` argument, and `Start-AZSCSecCenterJob`'s `foreach ($1 in $Security)` iterated
  nothing. Calling the function directly is what surfaced it; it now receives `$Security`.

- **Five collectors threw on their first log call** (AB#5649) —
  `Monitor/SubscriptionDiagnosticSettings` and the four `Security/Defender*` collectors call
  `Write-AZSCLog -Color 'Cyan'` and `-Level Verbose`. The function accepted neither, so each
  threw *"A parameter cannot be found that matches parameter name 'Color'"* the moment it was
  reached, and produced nothing. The old pipeline surfaced runspace errors detached at
  `EndInvoke` time, so this was invisible. `Write-AZSCLog` now accepts both.

- **Per-file `.CATEGORY` filtering never worked** (AB#5649) — the engine matched
  `\.CATEGORY\s*[\r\n]+\s*(...)`, which requires a line break between the keyword and its value.
  All 176 collectors write `.CATEGORY Compute` on one line, so the expression never matched a
  single file and every collector silently fell back to its folder name. Both forms are now
  accepted. No collector currently declares a category different from its folder, so this
  changes no present behaviour — it makes the documented feature real.

- **Every collector ran in Reporting mode whether or not it had data** (AB#5649) —
  `Start-AZSCExcelJob` guarded on `@($SmaResources).count -gt 0`, and **`@($null).Count` is 1, not
  0**, so a collector with no cache entry scored 1 and was invoked anyway. All 176 ran on every
  report build instead of the ~30 with rows. That was merely wasted work until it reached the two
  Identity files whose top-level statement is `Register-AZSCInventoryModule` — invoking them at
  all throws, and that killed the Excel build. The count now filters nulls, and the reporting
  loop refuses the unimplemented-contract collectors the same way discovery does.

- **All four report exporters threw on a cache with no entry for a collector** (AB#5649) —
  `Export-AZSCJsonReport`, `Export-AZSCMarkdownReport`, `Export-AZSCAsciiDocReport` and
  `Export-AZSCPowerBIReport` each read `$CacheData.$ModName` unguarded, which under StrictMode
  throws *"The property 'IdentityProviders' cannot be found on this object"*. It never fired
  before because the old pipeline created a hashtable key for **every** module file, including
  ones that produced nothing. The deterministic pipeline writes keys only for collectors it
  actually ran, so a skipped or filtered collector legitimately has no key. All four now check
  before reading.

- **Four more copies of the AB#5629 `NotStarted` race** (AB#5649) — the security, policy,
  advisory and subscription sheets were harvested with
  `while (get-job -Name 'X' | Where-Object { $_.State -eq 'Running' })`, which does not match a
  job that has not started yet. The resource pipeline's copy of this bug was fixed in v2.5.2;
  these four were missed. All four now run in-process and hand their results over directly.

### Known limitation

- `Identity/IdentityProviders.ps1` and `Identity/SecurityDefaults.ps1` are written against a
  registration API (`Register-AZSCInventoryModule`, `Get-AZSCProcessedData`, `$Context.EntraData`)
  that exists **only as a mock inside `tests/Identity.Module.Tests.ps1`** and was never
  implemented in the module. They have never produced a row in any release. They are now
  detected during discovery and reported as skipped rather than executed, so a genuine collector
  failure is not buried under two guaranteed ones. Porting them needs the Entra data plumbing
  and is tracked under AB#5656.

## [2.5.3] - 2026-07-25

### Fixed

- **A normal Azure response aborted the entire inventory run** (AB#5633) — a run against a real
  tenant died immediately after the API inventory phase with:

  ```
  Invoke-AzureScout: The property 'ReservationRecomen' cannot be found on this object.
  ```

  This was **not** a null-reference fault. Every `src/*.ps1` calls
  `Set-StrictMode -Version Latest` at file scope and `AzureScout.psm1` dot-sources them, so the
  whole module — the v1 inventory path included — runs under StrictMode. Under StrictMode,
  member enumeration over a collection (`$APIResults.ReservationRecomen`) reports the property as
  missing when the enumeration yields **nothing at all**, and that is exactly what an **empty
  collection on every element** produces: the empties flatten away and nothing is left. A `$null`
  value is safe; an empty one is not.

  The Consumption `reservationRecommendations` API returns `{ "value": [] }` for a subscription
  with no reservation recommendations, so a perfectly healthy tenant crashed the run. All seven
  reads at that site — `ResourceHealth`, `ManagedIdentities`, `AdvisorScore`,
  `ReservationRecomen`, `PolicyAssign`, `PolicyDef`, `PolicySetDef` — carried the same defect and
  now read element-wise through `Get-AZSCCollectedValue`.

  Because the fault is data-dependent, 1697 passing tests and three earlier live runs did not
  catch it.

- **The same crash class, swept** (AB#5633) — `$Resources` is a mixed array: Resource Graph rows
  carry `subscriptionId`/`Type`, the REST API rows appended beside them do not. Two collectors
  that run in module scope (where StrictMode applies) filtered it with bare property reads and
  aborted the whole pipeline on the first foreign row:
  - `Get-AZSCVMQuotas` — `$_.subscriptionId`, which meant **no quota was collected for any
    subscription**, not merely the offending one.
  - `Get-AZSCVMSkuDetails` — `$_.TYPE`, and a `-ExpandProperty location` over rows without one.

  The ~176 inventory modules use the same filter shape safely, because they execute inside fresh
  runspaces where StrictMode is not set. They are unchanged.

- **Diagram jobs never actually waited** (AB#5633) — `Start-AZSCDiagramJob` looped on
  `$Job.Runspace.IsCompleted -contains $false`. Those handles are `PowerShellAsyncResult` and have
  **no `Runspace` property**, so the expression was empty, `-contains $false` was always false, and
  the loop exited immediately — the `EndInvoke` calls below it raced the work they were meant to
  collect. v2.5.2 fixed this identical line in `Start-AZSCProcessJob` and left this copy behind.
  Both now test the handle's own `IsCompleted`, filter rather than member-enumerate (so an empty
  job set is safe under StrictMode), and sleep between polls instead of spinning a core.

- **An unavailable Cost Management API destroyed the whole run** (AB#5636) —
  `Get-AZSCCostInventory` ended its catch block with `throw $_.Exception.Message`, and the
  `$Costs = @()` fallback on the very next line was **unreachable dead code**, so the graceful
  degradation the author intended never ran. Any Cost Management failure on any single
  subscription cost the caller their entire report; on a machine without `Az.CostManagement`
  installed, `-IncludeCosts` failed outright with `The term 'Invoke-AzCostManagementQuery' is not
  recognized`. Cost data is optional enrichment: a failure now warns — naming the install command
  when the module is simply absent — records the reason in the run log, and the run continues with
  empty cost data for that subscription only.

  `Az.CostManagement` is deliberately **not** added to the module's auto-install list. Doing so
  drags in a newer `Az.Accounts` as a dependency, and on a machine that already has one that
  leaves two versions side by side — after which every `Import-Module` dies with a stack overflow
  inside Az.Accounts' own assembly-load-context resolver. An opt-in feature must not force a
  dependency upgrade on everyone. It is documented as an optional prerequisite instead.

### Changed

- **The v1 inventory engine no longer runs under StrictMode** (AB#5633) — this is the root cause
  behind every crash above, and fixing the symptoms one at a time was never going to end.

  The inventory engine under `Modules/` is forked from `microsoft/ARI` and was written without
  StrictMode. The v2 assessment platform under `src/` sets `Set-StrictMode -Version Latest` at
  **file** scope, and `AzureScout.psm1` dot-sources those files — so StrictMode was silently
  applied to the entire module, engine included. Nothing in that engine had ever been tested under
  it. An AST sweep found **~800 property reads in module scope that are only valid without it**:
  chained reads over API payloads whose shape varies by tenant, and member enumeration over
  collections that are legitimately empty.

  The consequence was a run that aborted on a perfectly normal Azure response, **in a different
  place on every tenant**, because every one of these faults is data-dependent — an empty API
  result set, an estate with no VMs, a subscription with no quota rows. Five separate crashes were
  hit in sequence on a single tenant while fixing this release, each one only reachable once the
  previous had been cleared.

  StrictMode is dynamically scoped, so each of the five engine entry points
  (`Start-AZSCExtractionOrchestration`, `Start-AZSCProcessOrchestration`,
  `Start-AZSCReporOrchestration`, `Start-AZSCExtraJobs`, `Start-AZSCExcelCustomization`) now opts
  out for its own call tree. **The assessment platform is unaffected** — it is invoked from
  `Invoke-AzureScout`'s own scope and keeps StrictMode in full force, as it was written to. Tests
  pin both halves of that boundary.

  This restores the behaviour v1 shipped with for years. It is not a licence to write sloppy code
  in the engine: the genuine defects found alongside it — a job wait that never waited, an
  unreachable error fallback, a rethrow that destroyed optional data, a job list that failed
  validation when empty — were fixed properly rather than papered over, and the element-wise
  reads introduced above are kept because they are simply more robust.

### Added

- **Every run now writes a detailed log into its own run folder** (AB#5634, AB#5635) — no extra
  parameter required. Previously a failed run left nothing behind but one red line on the console,
  and diagnosing it meant re-running the whole tool with `-Debug` and watching the screen.

  | File | Contents |
  |---|---|
  | `scout-run.log` | Metadata header (module and PowerShell version, OS, account, tenant, subscriptions in scope, resolved switches), every phase boundary with elapsed time and counts, warnings, and — on failure — the full error record: message, exception type, failing script, line number, statement, and script stack trace |
  | `scout-console.log` | Console transcript including warnings. Skipped silently on hosts without transcription support |

  A failed run prints the log path before exiting. Logging is best-effort throughout: if the log
  cannot be written the run still proceeds, warning once. A lost log is a lost diagnostic, never a
  lost report.

  This paid for itself immediately — the Cost Management defect above and both mixed-array
  collector crashes were found by reading `scout-run.log`, not by re-running with `-Debug`.

## [2.5.2] - 2026-07-25

### Fixed

- **A whole report category could silently vanish from a run** (AB#5629) — inventory output was
  non-deterministic: `ReportCache/Compute.json` came back 5,158 bytes on one run and 470 on the
  next, against the same tenant and the same scope. In the degraded run every Compute module
  reported zero rows while the hashtable keys were still present, which located the loss at the
  **job** level rather than the collector.

  The cause was a race, not throttling. `Wait-AZSCJob` looped only while a job was `Running`, but
  `Start-Job` is asynchronous — a job created moments earlier sits in `NotStarted`, a state that
  satisfied neither the wait loop nor the caller's job-selection filter. It was therefore never
  waited on, and `Build-AZSCCacheFiles` then ran `Receive-Job` (nothing to receive) followed by
  `Remove-Job`, destroying the job before it had produced anything. Both now treat every
  non-terminal state as pending.

  The inner wait `While ($Job.Runspace.IsCompleted -contains $false)` was additionally a **no-op**:
  those handles are `PowerShellAsyncResult` and have no `Runspace` property, so the expression was
  empty and `-contains $false` was always false. It now reads `$Job.IsCompleted`.

- **A dropped category left no trace** (AB#5629) — `Build-AZSCCacheFiles` now warns when a job is
  harvested in a non-`Completed` state, and when a category returns no data, naming the category.
  Previously a run could report an empty estate with complete silence.

- **Excel chart customization raised a raw COM error on machines without Excel** (AB#5629) —
  `Build-AZSCExcelComObject` surfaced `0x80040154 REGDB_E_CLASSNOTREG` through `Write-Error` on
  every hosted runner and container. The report is already complete and saved at that point, so
  the missing `Excel.Application` ProgID is now detected up front and explained in one line. This
  is the same condition `-Lite` skips, and the reason the GitHub Action defaults `lite` to true.

### Verified

Three consecutive live runs against the same tenant produced **byte-identical** results: 227 Azure
resources, 994 Excel rows, 40 Power BI files / 1013 rows, 166 Azure DevOps resources, **0**
empty-category warnings and **0** raw COM errors. Before this change those numbers varied run to
run. Pester **1697 passed, 0 failed, 3 skipped**.

## [2.5.1] - 2026-07-25

### Fixed

Seven defects that stopped a full `Invoke-AzureScout` inventory run from completing against a real
tenant. **Every one was found by running the product end to end against live Azure — the 1692-test
suite passed throughout, because nothing drove the extraction, processing and reporting chain
against real collector output.**

- **Extraction: `$MGContainerExtension` was never initialised** (AB#5547) — it is consumed
  unconditionally by the `resourcecontainers` query but was only assigned inside the
  `-ManagementGroup` branch, so a run without that switch died on an unset variable. Its three
  sibling query-extension variables were all initialised; this one was missed.

- **Processing: 41 `.IsPresent` reads on parameters that are not declared `[switch]`** (AB#5547) —
  `$Heavy`, `$InTag`, `$Automation`, `$SkipAdvisory`, `$IncludeCosts` and others are `$null` when a
  caller omits them, and `.IsPresent` on `$null` throws. Replaced with a null-safe `[bool]`
  coercion, which is identical for a real `SwitchParameter` and yields `$false` for `$null`.

- **Reporting: Excel styling on an empty worksheet** (AB#5567) — ImportExcel resolves a `-Style`
  range against the written sheet; with zero data rows `Set-ExcelRange` throws *"The property
  'HorizontalAlignment' cannot be found on this object"*. `-TableName` fails the same way. Style
  and table arguments are now supplied only when there is at least one row.

- **Reporting: the cost and update-manager worksheets read property names the collector does not
  emit** (AB#5567) — `$vm.Name`, `$vm.Size` and `$vm.'OS SKU'` against a Compute collector that
  emits `VM Name`, `VM Size` and `OS Version`. **These worksheets have never carried VM rows.**

- **Charts: `$excel.'<Name>'` threw whenever the estate produced no such worksheet** (AB#5567) — no
  public IPs, no disks, no VMs. 29 sites now resolve through a `Worksheets | Where-Object` lookup,
  so the existing null guards actually apply.

- **Charts: pivot titles read before assignment** (AB#5567) — each `$P<n>Name` is assigned only
  inside a worksheet-exists branch but read unconditionally; P7 and P9 have a single branch. A
  pivot that cannot be built now gets no title instead of killing the report.

- **Markdown: `"$totalResources_"`** (AB#5567) — the trailing underscore closes a markdown italic
  run, but an underscore is a legal identifier character, so PowerShell parsed it as a variable
  that never existed.

### Verified

A full `Invoke-AzureScout -IncludeDevOps` run against a live tenant now completes: **227 Azure
resources, 994 Excel rows, 40 Power BI CSVs / 1013 rows**, plus JSON, Markdown and the draw.io
diagram. Azure DevOps extraction returned **166 resources** (74 projects, 4 pipelines, 4 service
connections, 74 repositories, 10 agent pools) — the first live-tenant verification of the
`-IncludeDevOps` collectors, which until now had only 36 mocked tests.

### Known limitations

- `Build-AZSCExcelComObject` emits a non-fatal error when Excel is not installed
  (`0x80040154 Class not registered`). This is the existing limitation behind `lite` defaulting to
  true; the run completes and every artifact is still produced.
- Compute collection returned inconsistent row counts across otherwise-identical runs. Not yet
  explained; possibly Resource Graph throttling.

## [2.5.0] - 2026-07-25

### Changed

- **A combined run now collects from Azure once, not twice** (AB#5543) — when the setup wizard
  is asked for both inventory and assessment, the assessment no longer issues its own Resource
  Graph query pack over resource types the inventory pass has already fetched. The inventory
  extraction already projects the full `properties` bag from `resources`, `networkresources` and
  `resourcecontainers`, which is a superset of what the assessment's typed queries were
  re-fetching, so the assessment's scalars are now shaped from those in-memory rows.

  In a combined run, **one** Resource Graph query still goes to Azure: `sqlDefenderPricing`
  reads the `SecurityResources` table (`Microsoft.Security/pricings`), which the inventory only
  touches under `-SecurityCenter` and then filters to `microsoft.security/assessments`, so those
  rows are genuinely never present. Every other query is served from memory.

  The assessment-only path (`Invoke-AzureScout -Assessment` without an inventory pass) is
  **unchanged** — it still runs the full Resource Graph pack, and that KQL remains the reference
  implementation. If the shaping layer ever throws, the run falls back to querying Resource Graph
  rather than costing the caller their assessment.

### Added

- `ConvertFrom-ScoutInventory` (`src/collect/ConvertFrom-ScoutInventory.ps1`) — derives every
  assessment scalar from already-collected inventory rows, mirroring the KQL field for field.
- `-FromInventory` on `Invoke-Collect` and `Invoke-ScoutAssessment`, threading the inventory
  extraction result through to the collector.
- `tests/CollectorCollapse.Tests.ps1` — 17 tests pinning the KQL semantics a naive PowerShell
  rewrite gets wrong (`array_length(null)` is null and not `0`; `tobool(null)` is null and not
  `$false`; subnet capacity is `2^(32-prefix) - 5`; `allPoolsZoned` only when every AKS pool has
  zones), plus an assertion that a `-FromInventory` run reaches Resource Graph exactly once while
  an assessment-only run still issues every query.

### Fixed

- Rows appearing in both the `resources` and `networkresources` tables are de-duplicated by
  resource id before shaping. Without this a VNet present in both would be counted twice and
  inflate every existence-count rule.

## [2.4.0] - 2026-07-25

### Added

- **Guided setup wizard** (AB#5541) — running `Invoke-AzureScout` with no parameters in an
  interactive session now opens a wizard instead of immediately starting a full scan. It
  confirms or establishes the Azure sign-in, lets you pick the tenant when the account can
  see more than one, verifies the account holds the rights the run needs (and lets you bail
  out before a long scan fails halfway), then presents checklists for the run type, the
  resource categories or assessments, the report formats, and the report directory.
  Everything is pre-selected, so you uncheck what you don't want. The final step prints the
  equivalent one-line command so the wizard doubles as a way to learn the parameters.

  The wizard is gated on `Test-AZSCInteractiveHost` and **never** fires in a non-interactive
  host — CI runners, scheduled tasks, containers, and any session with redirected stdin fall
  straight through to the previous default (full ARM inventory), so an existing bare
  `Invoke-AzureScout` in a pipeline cannot block on a prompt. `-NoWizard` (alias
  `-NonInteractive`) forces that same path at a terminal. `Start-AZSCWizard` is exported so
  it can be re-run on demand.

### Changed

- **One entry point** (AB#5540) — inventory and assessment are now modes of a single
  command rather than two cmdlets. `Invoke-AzureScout -Assessment LandingZone` runs the
  CAF/WAF assessment; without `-Assessment` the command behaves exactly as before.
  `-CollectOnly` and `-FromCollect` moved onto `Invoke-AzureScout` as well. Assessment mode
  now also honours the inventory sign-in parameters (`-TenantID`, `-DeviceLogin`, `-AppId`,
  `-Secret`, certificate auth), which the standalone cmdlet never did — it silently required
  a pre-existing `Connect-AzAccount` context.

  This is the layout ADO Feature AB#5024 originally specified; the v2 scaffold shipped a
  second entry point instead, and the docs were written around that split.

- **`-OutputFormat` widened** from `[string]` to `[string[]]`, so a single run can request
  several renderers (`-OutputFormat Html,Pptx`). The ValidateSet grew from 8 to 15 values to
  cover both modes. Requesting a format from the wrong mode now throws an error naming the
  switch you actually wanted, instead of silently producing no output.

### Deprecated

- **`Invoke-ScoutAssessment`** — superseded by `Invoke-AzureScout -Assessment`. It still
  works and is still exported, and will be removed in **v3.0.0**. Every parameter maps
  across unchanged except `-OutputPath`, which is `-ReportDir` on `Invoke-AzureScout`.

### Fixed

- **Documentation stated a PowerShell floor the module does not have** — `docs/overview.md`,
  `docs/prerequisites.md`, and `docs/assessment.md` each claimed the inventory cmdlet ran on
  "PowerShell 5.1+ (Desktop or Core)" and that only the assessment platform needed 7.0. The
  manifest has always declared `PowerShellVersion = '7.0'` and `CompatiblePSEditions =
  @('Core')`, and `Invoke-AzureScout` throws on Desktop, so 5.1 could never import the
  module in either mode. The differing PowerShell requirement was also the main justification
  the overview page gave for presenting inventory and assessment as two separate products.

### Known limitations

- Inventory mode and assessment mode still collect their Azure data independently — the
  inventory runs its per-resource-type modules while the assessment runs its own ~26-query
  Resource Graph pack over the same resource types. Running both queries Azure twice.
  Collapsing them onto one collection pass is tracked as AB#5543.
  **Resolved in 2.5.0 — see below.**

## [2.3.0] - 2026-07-25

Closes the collection-hardening epic (AB#5411) and the external-platform integrations
(AB#5410) other than multi-tenant Lighthouse, which stays on the roadmap.

### Added

- **Azure DevOps inventory** (AB#327) — `-IncludeDevOps` extends a scan to cover Azure
  DevOps projects, pipelines, service connections, repositories, and agent pools, adding
  five worksheets. Authentication reuses the current Azure sign-in by requesting an Entra
  token for the Azure DevOps resource, so no personal access token is needed in the common
  case; `-DevOpsPat` covers the case where the two identities differ. Organizations are
  discovered from the signed-in profile, or named explicitly with `-DevOpsOrganization`
  (required for service principals, which have no profile to enumerate).
  The **ADO Service Connections** sheet cross-references every Azure Resource Manager
  connection against the subscriptions in scope, so a pipeline with a credentialled path
  into the inventoried estate is visible, and flags connections still using a secret or
  certificate rather than workload identity federation. **ADO Agent Pools** highlights
  self-hosted pools. Partial access is handled: a 401/403 on one endpoint skips that slice
  and collection continues. Every call is a GET — Azure Scout stays read-only.
- **Run isolation / non-destructive cache** (AB#331) — every invocation now gets its own
  run folder under the base output directory, so rescanning, or scanning a second tenant,
  can no longer destroy the previous run's `ReportCache`, `DiagramCache`, or report.
  `-RunName` names the folder instead of using the generated timestamp; `-Force` restores
  the previous overwrite-in-place behaviour; `Clear-AZSCCacheFolder -OlderThan <days>`
  prunes aged run folders.
- **Post-login management group access probe** (AB#351) — `Get-AzManagementGroup` is called
  right after login and the count is reported in the login summary. An authorization
  failure prints the exact role to assign rather than surfacing an hour later as a silently
  empty worksheet. The probe never aborts the run; collection continues at subscription
  scope.
- **GitHub Action** (AB#328) — the repository now ships a composite `action.yml`, so a
  workflow can generate an inventory with
  `uses: thisismydemo/azure-scout@v2`. It installs the module and dependencies,
  authenticates, runs the collection, and uploads the reports as an artifact. Every input
  reaches PowerShell as an environment variable rather than through `${{ }}` interpolation
  into a script body, so a crafted input value cannot break out and execute.
- **Documentation** — [Azure Automation Account](docs/automation.md) (AB#343), the
  eight-step unattended setup guide that previously did not exist;
  [GitHub Actions](docs/github-actions.md) (AB#328); [Azure DevOps](docs/azure-devops.md)
  (AB#327); [Category Reference](docs/category-reference.md) (AB#318, AB#5417), mapping
  every report section heading to its category, aliases, collector folder, and module
  count; and [Validation Matrix](docs/validation-matrix.md) (AB#315), recording for every
  phase 5-21 check whether it is covered by an automated test or requires a live tenant.
  README gains a category quick-reference table.

### Fixed

- **Cross-subscription context is restored** (AB#368) — every loop that called
  `Set-AzContext` left the caller parked in whichever subscription came last, or in
  whichever one an error surfaced from. All five call sites — the resource provider
  pre-flight, VM quota collection, policy compliance states, and both permission-audit
  sweeps — now capture the context up front and restore it in a `finally` block.
- **Automation blob uploads on a second run** (AB#343) — `Set-AzStorageBlobContent` now
  passes `-Force`. Without it the second scheduled runbook execution failed with "blob
  already exists" and the report never landed.
- **Diagnostic log never uploaded from a runbook** (AB#343) — the upload was gated on
  `$Debug.IsPresent`, which is always `$null` because `-Debug` is a common parameter, not a
  declared one. It now tests `$DebugPreference`. The diagram upload is additionally guarded
  on the file existing.
- **Documented category aliases that did not work** (AB#318) — `docs/category-structure.md`
  listed `Networking + CDN` as an accepted alias, but it was absent from the alias map.
  It has been added, along with `Web and mobile`, `Mobile`, and `Networking+CDN`, and the
  documented table now matches the code in both directions.
- **Stale figures in `docs/testing.md`** — the page claimed 29 test files and ~1,240 tests
  across 237 scripts; the real numbers are 56 files, 1,648 tests, and 274 scripts.

### Changed

- Context-restore guards use `PSObject.Properties` rather than bare property access, which
  throws under `Set-StrictMode` when the property is absent. The two sites that execute
  inside thread jobs, and the permission audit (dot-sourced standalone by callers and
  tests), carry the restore inline rather than depending on a sibling file being loaded.
- `.github/workflows/azure-inventory.yml` now consumes the repository's own composite
  action, so the workflow exercises the same code path external consumers get. It
  previously omitted `ImportExcel` from its dependency install and interpolated workflow
  inputs directly into a PowerShell script body.

### Testing

Full suite **1,648 passed, 0 failed, 3 skipped** across 56 files (66 new: 30 in
`tests/RunIsolation.Tests.ps1`, 36 in `tests/DevOps.Module.Tests.ps1`).
PSScriptAnalyzer: 0 Error-severity findings across `Modules/`.

## [2.2.1] - 2026-07-24

### Fixed

- **Repo-wide `.Count`-on-null/scalar crash class** — hardened ~180 sites across the whole
  solution (`Modules/Private` ~45, `Modules/Public` 63 across 106 files, `src/` 6, plus the
  permission audit). These threw `The property 'Count' cannot be found on this object` on
  Windows PowerShell 5.1 and under `Set-StrictMode -Version Latest` whenever a value collapsed
  to `$null` or a single scalar. Root case: `Invoke-AzureScout -EntraAudit` crashed at
  `Invoke-AZSCPermissionAudit` (`$targetSubs.Count` on a single-subscription tenant). Other real
  crashers fixed: `Get-AZTIVMQuotas` (any env with a VM location), `Start-AZTIGraphExtraction`
  (uninitialised vars on the default path), the `$RetiredFeature.count` pattern copy-pasted
  across 87 inventory modules, `Test-ScoutPermission` leaking `Format-Table` objects into its
  return stream, `Export-Pptx` on all-Pass assessments, and several diagram null-property chains
  on ordinary single-subnet environments. Fixes are surgical (`@()`-wrap, null-guards, `@()`
  initialisers, `return ,$x`); no logic changes. ~35 new regression tests. Full suite 1582/0/3.

### Changed

- **Requires PowerShell 7** — `AzureScout.psd1` now declares `PowerShellVersion = '7.0'` and
  `CompatiblePSEditions = @('Core')`, and `Invoke-AzureScout` fails fast with a clear
  "requires PowerShell 7+, run in `pwsh`" message on Windows PowerShell 5.1 instead of crashing
  deep in a run. This enforces the long-documented PS7 requirement (per `AGENTS.md`).
  **Breaking** for anyone importing the module under Windows PowerShell 5.1.

## [2.2.0] - 2026-07-24

### Added

- **Report tiers — Word, ECharts dashboard, PDF, JSON evidence** (AB#333, AB#344, AB#396, AB#379, AB#394, AB#395): four new renderers, all wired into `Export-Report` and `Invoke-ScoutAssessment -OutputFormat` / `Invoke-ScoutPipeline -OutputFormat`.
  - `Export-Word` (`src/report/renderers/Export-Word.ps1`, AB#333) — self-contained `.docx` via OpenXML, no Python.
  - `Export-EChartsDashboard` (`src/report/renderers/Export-EChartsDashboard.ps1`, AB#344) — a single offline HTML dashboard with ECharts inlined (no CDN).
  - `Export-Pdf` (`src/report/renderers/Export-Pdf.ps1`, AB#379/394/395) — a hand-rolled, dependency-free `.pdf` renderer (cover, executive summary, per-area findings table with repeating header, gaps, manual review).
  - `Export-JsonEvidence` (`src/report/renderers/Export-JsonEvidence.ps1`, AB#396) — resources-only JSON evidence export (raw Collect data, no assessment metadata/scores/findings).
  - `-OutputFormat` on `Invoke-ScoutAssessment` gains `Word`, `EChartsDashboard`, `Pdf`, `JsonEvidence` values (all included in `All`); `Export-Report`'s dispatcher switch gains matching cases.
- **Excel visual dashboard tabs** (AB#322): pivot-chart dashboard worksheets added to the assessment Excel evidence tier, mirroring the v1 inventory's Cost/Security/Update Manager/Monitor dashboard pattern.
- **Richer interactive React report** (AB#376, 377, 378, 380, 386, 387, 389–393): the self-contained `report-react.html` (`-OutputFormat React`) gains a vis.js VNet topology diagram with click-to-details and reset/fit controls, a management-group hierarchy diagram, 14 KPI cards, an Azure Firewall drill-down, a Governance section (budgets/locks/tag chips), a policy-enforcement badge, per-section search/filter, clickable rows with a side panel, and scope tooltips.
- **`report.pbit` generation** (AB#5046): `Invoke-ScoutAssessment`'s Power BI tier now wires the existing `New-AZSCPowerBITemplate` generator to produce a `.pbit` bound to the star-schema CSVs, alongside the CSV bundle.
- **Cross-run resource/inventory drift** — `Get-ScoutInventoryDrift` (`src/report/Get-ScoutInventoryDrift.ps1`, AB#326): computes Added/Removed/Changed drift between the current `collect.json` and the previous run's snapshot, independent of how any rule scored a resource. Complements the existing findings-level `Get-ScoutDrift` (v2.1.0). Maintains a durable inventory-history log alongside `.scout-history/findings-history.json`.
- **Cost anomaly detection** — `Get-ScoutCostAnomaly` (`src/analyze/Get-ScoutCostAnomaly.ps1`, AB#324): offline, never calls Azure. Flags statistical outliers in an already-collected cost dataset using three additive techniques (month-over-month spike, z-score, IQR), grouped by `-GroupBy` (default `Scope`, `ResourceType`). Accepts both the raw `Get-AZSCCostInventory` shape and a pre-normalized cost dataset.
- **Bicep/IaC gap detection** — `Get-ScoutIacGap` (`src/analyze/Get-ScoutIacGap.ps1`, AB#325): offline, never calls Azure. Compares discovered resources (from `collect.json`) against a folder of `.bicep`/ARM-JSON templates (best-effort text/JSON parsing, no `bicep build`) and reports resources present in Azure but not represented in any template (`Unmanaged`).
- **IoT deep coverage** (AB#330): `Invoke-Collect` gains Device Provisioning Service and Azure Digital Twins queries; new `caf.iot` rules score them.
- **Tag aggregation** (AB#367): `Invoke-Collect` now aggregates tag values to their unique set per key across subscriptions instead of last-write-wins.
- **Database/Analytics/IoT rule depth** (AB#5068, AB#5071, AB#5075): new `sqlDefenderPricing` / `purviewAccounts` collect queries plus `iotHubs.disableLocalAuth`; CAF-DB-04, CAF-ANL-02, and new CAF-IOT-06 flip from `Manual` to automated.
- **Collector/pipeline resilience + progress UX** (AB#397–402, 405): per-subscription try/catch/continue in `Invoke-Collect` so one subscription's failure doesn't abort the run; a management-group role-requirement hint on RP/authorization errors; an empty-data guard; a pipeline `HadErrors` summary flag surfaced in `pipeline-summary.json`; live `Write-ScoutProgress` (`src/Write-ScoutProgress.ps1`) output during collection.
- **Assessment config load/save** (AB#373, 374, 375): `Import-ScoutConfig` (`src/assess/Import-ScoutConfig.ps1`) loads an optional JSON config — an alternative benchmark, rule-selection patterns, and/or per-rule threshold overrides — falling back to the built-in ALZ reference benchmark whenever the path is absent, missing, or unparsable (never throws). `Export-ScoutConfig` (`src/assess/Export-ScoutConfig.ps1`) writes the identical schema back out, so a round trip reproduces the same effective config.
- **UPN + active-subscription auth banner** (AB#349): login now prints the signed-in UPN and active subscription before a run starts.
- **CI pipeline** (AB#317): `.github/workflows/ci.yml` runs the Pester suite and PSScriptAnalyzer on PR + push.

### Changed

- **`azure-inventory.yml` workflow is a real inventory run** (AB#340): replaced the echo-only simulation with a headless run that validates SPN secrets, installs `Az` + `AzureScout` from PSGallery, authenticates non-interactively, runs the inventory, and uploads the reports as a build artifact.
- **Module auto-update check** (AB#369): importing `AzureScout` checks PSGallery for a newer version and notifies by default (CI-guarded so it never runs in automated pipelines); no forced update.

### Fixed

- **v1 inventory collector bugs** (AB#335, 336, 337, 339): automation-mode batch cache writes no longer target a null path (missing `$DefaultPath` parameter); the progress bar advances instead of sticking at 0% (undeclared `$ReportCounter` → `$Counter`); the automation branch assigns `$JobNames` after `Wait-Job` so the final cache flush gets the full job list; `$VMQuotas` is initialized up front so the `Quotas` return field is populated and safe under `-SkipVMDetails`.
- **draw.io diagram merge + StrictMode crashes** (AB#342): repaired a broken draw.io XML merge that produced invalid diagrams under some topologies, and fixed StrictMode violations in the diagram build path that could crash mid-run; general diagram-quality improvements.

### Documentation

- **Entra Graph delegated scopes** (AB#347, AB#338): documented the required Microsoft Graph delegated scopes in `docs/entra-modules.md`; confirmed the "fails with Global Admin" report (AB#347) is a Graph consent/scope issue, not a code defect — it degrades per-endpoint as designed.
- **Roadmap reconciliation** (AB#5093, AB#5094): corrected the web-portal vision to explicit feature parity with the PowerShell version rather than a separate product; the served web portal is marked exploratory/far-future, not scheduled.

## [2.1.0] - 2026-07-23

### Added

- **Native governance collector** (AB#5041): `src/ingest/Import-Governance.ps1` replaces the AzGovViz hard dependency as the default governance collector. Populates `collect.json`'s `governance` object natively from Azure Resource Graph (`policyresources` → policyAssignments, `authorizationresources` → roleAssignments, `resourcecontainers` → managementGroups) plus ambient-token ARM REST (`Microsoft.Consumption/budgets`, `Microsoft.Authorization/locks`). No cloned repo, no `AzAPICall` install prompt, fully unattended, StrictMode-safe. Needs only Reader at the management-group root. Live-verified against the HCS tenant: real policy/role assignments collected, CAF governance/identity rules scored real Pass/Fail, and the ALZ benchmark correctly degrades to an explicit `Unknown` (instead of a false 0%) when management-group data isn't visible. Two datasets are intentionally empty: `classicAdministrators` (retired API — CAF-IDN-03 asserts `notExists`, so empty is compliant) and `pimEligibility` (needs Entra ID P2 + `PrivilegedAccess.Read.AzureResources`).
- **Unattended pipeline** (AB#5050): new public cmdlet `Invoke-ScoutPipeline` (`src/Invoke-ScoutPipeline.ps1`) runs collect → assess → report headless into a single dated run folder — non-interactive throughout (`ConfirmPreference = 'None'`, `ProgressPreference = 'SilentlyContinue'`). Runs the read-only permission pre-flight first (unless `-SkipPermissionAudit`) and wraps the orchestrator in try/catch so an exporter failure degrades to `PartialSuccess` instead of losing output. Writes `pipeline-summary.json` (CI-facing: `schemaVersion`, `startedOn`/`finishedOn`, `elapsedSeconds`, `assessments`, `formats`, `findingsByStatus`, `permissionAudit`, `outcome` ∈ `Success`/`PartialSuccess`/`Failed`) and `pipeline-summary.md`. Returns the run-folder path; throws and sets `$LASTEXITCODE = 1` only on `Failed`. Parameters: `-Assessment`, `-OutputFormat` (default `All`), `-OutputPath`, `-ManagementGroupId`, `-Category`, `-SkipPermissionAudit`.
- **React report + cross-run drift** (AB#5053): new renderer `Export-React` produces a single self-contained `report-react.html` (all CSS/JS inline, findings embedded as a JSON blob, no external/CDN requests) with client-side filter by Framework/Area/Severity/Status, a sortable/searchable findings table, a summary dashboard, and a Drift tab. New `-OutputFormat React` value on `Invoke-ScoutAssessment` (included in `All`) and wired into `Invoke-ScoutPipeline` via `-OutputFormat`. New `Get-ScoutDrift` computes cross-run drift: per finding New / Resolved (Fail/Partial → Pass) / Regressed (Pass → Fail/Partial) / Unchanged, plus an overall weighted score delta, maintained in an append-only `findings-history.json` under a `.scout-history/` folder in the output root (keyed by run id; first run = baseline). `Invoke-ScoutAssessment` computes drift after scoring and feeds it to the React report; a drift failure is non-fatal.

### Changed

- **AzGovViz is no longer a default dependency.** The manifest assessments that previously used `Ingest = AzGovViz` (`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`) now use `Ingest = Governance` (the native collector, AB#5041). AzGovViz remains available as an opt-in `Ingest` value for anyone who wants the third-party tool specifically, but nothing depends on it by default. This corrects the earlier assumption that the ALZ benchmark / governance data was blocked pending an upstream AzGovViz fix — it no longer depends on AzGovViz at all; the only remaining caveat is that the benchmark needs Reader at the MG root for MG/policy visibility.

## [2.0.1] - 2026-07-23

### Changed

- **Manifest `ProjectUri`** now points at the documentation site (`https://thisismydemo.cloud/azure-scout/`) so the PowerShell Gallery "Project Site" link lands on the docs rather than the GitHub repo.

## [2.0.0] - 2026-07-23

Major release — the **CAF/WAF Assessment Platform**. Extends AzureScout from an
inventory tool into a read-only Cloud Adoption Framework / Well-Architected
landing-zone assessment. Runtime-verified offline (Pester) and against a live
Azure tenant.

> **Breaking:** introduces the `findings.json` output contract and demotes
> Excel-first output to an evidence tier. Assessment features require
> PowerShell 7; the v1 inventory functionality is unchanged and still runs on 5.1.

### Fixed

- **Discovery data-loss fixes**: `Get-AZSCManagementGroups` now pages Resource Graph via SkipToken (was capped at 1000 subs — AB#5076) and throws instead of `Exit` on a bad management group (AB#5077); `Start-AZTIGraphExtraction` throws instead of `Exit` (AB#5077); `Invoke-AZTIInventoryLoop` no longer double-counts boundary subscriptions in the >200-subscription batch loop (AB#5078).
- **Assessment correctness**: rewrote `.length` JSONPath filters to scalar fields; `Resolve-JsonPath` no longer swallows a thrown query into an empty result and `Invoke-Rule` surfaces it as `Error` rather than a false Pass (AB#5083); `percentageAtLeast` with a zero denominator yields `Unknown` (AB#5085); `Compare-Benchmark` guards absent governance data instead of emitting false all-Fail (AB#5084).
- **Scoring/reporting**: framework score is weighted by `AreaWeight` (AB#5087); `Unknown`/`Error` statuses are surfaced, not silently dropped (AB#5088); unknown severities sort last and can't crash the PPTX deck (AB#5089); null area scores render neutral in HTML, not red (AB#5090); deterministic rounding.
- **StrictMode runtime defects surfaced by first engine execution** (AB#5027): `Resolve-JsonPath` empty-result collapse to `$null` across the function boundary; `Get-Score` zero-match pipeline null-collapse under `Set-StrictMode -Version Latest`; `Invoke-Rule` unconditional `assert.value` access for `exists`/`notExists`/`manual` rules; and an unguarded `$spec.Benchmark` lookup in `Invoke-ScoutAssessment` that broke 21 of 22 manifest assessments.
- **WAF-RE-05** zone-redundancy rule scoped to zone-eligible regions instead of flagging every non-zone-redundant VM (AB#5086).
- **Ingest robustness surfaced by live root-MG runs** (AB#5037): `Invoke-ArgQueryPack` and `Invoke-Collect` no longer pass `-Skip 0` (rejected by `Search-AzGraph`); `Import-AzGovViz` preinstalls its `AzAPICall` dependency, passes `-NoPIMEligibility` when PIM data is unavailable, isolates the third-party script from the module's strict mode, and folds in partial exports if AzGovViz crashes mid-run instead of failing the whole assessment.

### Added

- **Reporting — OpenXML PowerPoint renderer** (AB#5044): `Export-Pptx.ps1` rebuilt on `DocumentFormat.OpenXml` (acquired via NuGet on first use, cached locally, no committed binaries) — the Python `python-pptx`/`build_deck.py` prototype is removed entirely. Generates a themed executive deck (title, executive summary, area-score breakdown, prioritized gaps, manual worklist, next steps) with a designer-template extension point. Decision recorded in `docs/design/decisions/pptx-renderer.md`.
- **Collect layer — per-domain ARG collectors**: extended `Invoke-Collect.ps1` (Service Bus, Arc extensions, Azure Local clusters, Log Analytics retention, private-endpoint target linkage, plus storage/web/AKS/AI/analytics/integration fields) so 16 previously manual rules now evaluate automatically. Rule set is 139 rules across 23 files (93 automated / 46 manual, each documenting the data source it needs).
- **Verification fixtures & tests**: `tests/datadump/sample-collect.json` canonical fixture exercising every status path; `tests/Test-PptxFromDataDump.ps1` smoke test; engine Pester suite green (6/6), full repo suite passing.

- **`src/collect/Invoke-Collect.ps1`** — normalized, read-only Azure Resource Graph adapter that produces the canonical `collect.json` (scalar fields) the rule engine evaluates against, resolving the discovery→assessment data-shape gap (AB#5081, AB#5082).
- **`tests/Assessment.Engine.Tests.ps1`** — Pester smoke tests for the scoring math and assert semantics.

#### CAF/WAF assessment platform — three-layer architecture (Epic AB#5023)

- **Assessment layer** (`src/assess/`) — declarative rule engine that grades collected data against CAF design areas and WAF pillars, producing scored findings and a prioritized gap list:
  - `engine/Get-RuleSet.ps1`, `Resolve-JsonPath.ps1`, `Invoke-Rule.ps1` (7 assert types), `Get-Score.ps1` (dual CAF/WAF scoring)
  - `rules/caf.*.yaml` (8 CAF design areas) and `rules/waf.*.yaml` (5 WAF pillars)
  - `benchmarks/alz-reference.json` + `Compare-Benchmark.ps1` (ALZ benchmark diff)
- **Ingest layer** (`src/ingest/`) — `Import-AzGovViz.ps1`, `Invoke-ArgQueryPack.ps1`, `Import-AdvisorScores.ps1` normalize external collectors into a single `collect.json`
- **Reporting layer** (`src/report/`) — tiered renderer engine (`Export-Report` → PowerBi / Html / Pptx / Excel / Json) reading a shared `findings.json`
- **Module registry** (`manifests/assessments.psd1`) + `Invoke-AzureScout` entry point for run-one/some/all; read-only permission pre-flight; unattended `.ado/azure-pipelines.yml`
- JSON-on-disk contract (`collect.json` → `findings.json`) so each layer runs independently

#### Per-domain CAF/WAF analytics across all categories (Epic AB#5056)

- Every Scout discovery category (15: AI, Analytics, Compute, Containers, Databases, Hybrid, Identity, Integration, IoT, Management, Monitor, Networking, Security, Storage, Web) becomes an **independently runnable, categorized and tagged assessment** with its own CAF/WAF analytics
- Manifest schema extended with `Category`, `Frameworks`, and `Tags` so `-Assessment <Category>` runs scoped discovery + scoped scoring (planned — AB#5057)
- Finer named sub-bundles inside a category (e.g. Governance / Policy / UpdateManager under Management; Monitoring under Monitor)

#### Power BI / Microsoft Fabric Export (Issue #17)

- **`Export-AZSCPowerBIReport.ps1`** (`Modules/Private/Reporting/`) — New function that exports normalized inventory data as a flat CSV bundle optimized for Power BI Desktop and Microsoft Fabric:
  - `_metadata.csv` — Scan metadata (tenant ID, date, scope, version, subscription count)
  - `Subscriptions.csv` — Subscription dimension table (`SubscriptionId`, `SubscriptionName`)
  - `Resources_{Module}.csv` — One file per ARM inventory module with `_Category` and `_Module` columns
  - `Entra_{Module}.csv` — One file per Entra ID / Identity module with `_Category` and `_Module` columns
  - `_relationships.json` — Star-schema relationship manifest describing many-to-one joins from resource tables to `Subscriptions` via `Subscription → SubscriptionName`
- **`-OutputFormat PowerBI`** added to `Invoke-AzureScout` `ValidateSet` — generates the `PowerBI/` folder as a sibling of the main report file; included in `All` by default
- **`Test-PowerBIFromDataDump.ps1`** (`tests/`) — Offline test harness that reconstructs the `ReportCache` from a JSON data dump and validates the full CSV bundle without requiring a live Azure connection
- Pester tests in `OutputFormat.Tests.ps1` covering `Export-AZSCPowerBIReport` function discovery, `_metadata.csv` content, `Subscriptions.csv`, `_relationships.json` validity, and `Resources_*.csv` / `Entra_*.csv` file generation with correct columns

## [1.0.0] - 2026-02-25

### Added

- Initial fork from [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11
- Renamed module to `AzureScout` (prefix `AZSC`)
- New module manifest with fresh GUID, v1.0.0
- Repository scaffolding (CHANGELOG, README, tests/)

#### Visual Dashboard Tabs

- **`Build-AZTIDashboardTabs.ps1`** (`Modules/Private/Reporting/StyleFunctions/`) — New 725-line function generating 4 visual dashboard worksheets with EPPlus pivot charts and DarkBlue tab coloring:
  - **Cost Dashboard** — Cost by Resource Type (bar), Cost by Subscription (pie), Cost by Region (column), Cost by SKU (bar)
  - **Security Dashboard** — Assessments by Severity (pie), Findings by Subscription (bar), Defender Plans (column), Active Alerts by Severity (bar)
  - **Update Manager Dashboard** — Machines by Platform (pie), Machines by OS Type (pie), Machines by Region (column), Machines by Power State (bar), Machines by Subscription (bar)
  - **Monitor Dashboard** — Alert Rules by Subscription (bar), Action Groups by Subscription (pie), DCRs by Subscription (column), App Insights by Subscription (bar)
  - Each dashboard only appears when its corresponding raw data tab has data (no empty dashboards)

#### Excel StyleFunctions Recreation

- **`Build-AZTIExcelComObject.ps1`** — Recreated from ARI original with AZSC namespace (COM-based chart generation for Windows environments)
- **`Start-AZTIExcelCustomization.ps1`** — Recreated from ARI original with AZSC namespace (Excel chart customization, version resolution from module manifest, Overview sheet assembly)
- **`Start-AZTIExcelOrdening.ps1`** — Recreated from ARI original with AZSC namespace (worksheet tab ordering and color assignment — Overview/Subscriptions/Advisor tabs pinned as DarkBlue)

#### Full Rebranding

- Replaced all remaining "Azure Tenant Inventory" references with "Azure Scout" across 239 files (`.ps1`, `.psm1`, `.psd1`, `.md`, `.yml`, `.adoc`)
- Updated permission audit banner, report titles, module metadata, comment blocks, and documentation

#### Version Alignment

- Reset `ModuleVersion` from `2.0.0` to `1.0.0` — module has not been published to PSGallery yet
- Updated version in module manifest, `.NOTES` blocks (3 source files), test assertions (2 test files), and all documentation (roadmap, changelog, output docs)
- Aligned report output versions: Excel fallback `3.6` → `1.0.0`, JSON `_metadata.version` `1.5.0` → `1.0.0`
- Roadmap future versions updated: `v2.1.0` → `v1.1.0`, `v2.2.0` → `v1.2.0`

#### Phase 7 — Cleanup & Polish

**Documentation**
- Rewrote `README.md` — comprehensive parameter reference table, 17-category module catalog (95 ARM + 15 Entra = 110 total), 5 authentication methods, `-Scope`/`-OutputFormat` quick start, JSON output structure
- Created `CREDITS.md` — attribution to original ARI project (Claudio Merola, RenatoGregio, Doug Finke/ImportExcel), MIT license notes
- Updated `Set-AZSCReportPath.ps1` comment-based help (Synopsis, Description, Link, Version, Authors)

**Antora Documentation Site** (8 new pages)
- `authentication.adoc` — 5 auth methods with code examples, priority order, LoginExperienceV2 handling
- `usage.adoc` — Scope, OutputFormat, content toggles, report location, JSON structure
- `permissions.adoc` — ARM RBAC and Graph API permissions, pre-flight checker behavior, scope-based gating
- `arm-modules.adoc` — Complete catalog of 95 ARM modules across 16 categories with resource type descriptions
- `entra-modules.adoc` — 15 Entra ID modules with Graph endpoints, data normalization, graceful degradation
- `contributing.adoc` — How to add new modules, Pester test patterns, PR guidelines, code style
- `credits.adoc` — AsciiDoc version of CREDITS.md
- `changelog.adoc` — Version history summary with link to CHANGELOG.md
- Updated `index.adoc` — landing page with correct module counts and navigation grid
- Updated `nav.adoc` — full 10-page navigation tree with Getting Started / Module Reference / Project sections
- Updated `folder-structure.adoc` — corrected module counts (110/17), added Identity/AzureLocal categories, CREDITS.md

**GitHub Actions**
- Replaced MkDocs workflow (Python/pip/mkdocs) with Antora workflow (Node.js 20, `npx antora`, `build/site` output)

**Pester Tests** (5 new test files)
- `Test-AZSCPermissions.Tests.ps1` — return structure, ARM/Graph pass/fail/warn, scope gating, never-throws guarantee
- `Invoke-AzureScout.Tests.ps1` — ValidateSet enforcement, parameter aliases, switch params
- `Connect-AZSCLoginSession.Tests.ps1` — 4 auth paths (SPN+cert, SPN+secret, device-code, current-user), TenantID enforcement, LoginExperienceV2
- `Invoke-AZSCGraphRequest.Tests.ps1` — URI normalization, pagination, SinglePage switch, retry 429/5xx, max retries
- `Start-AZSCEntraExtraction.Tests.ps1` — return structure, normalized shape, all 15 queries, graceful degradation

#### Phase 6 — JSON Output Layer

- **`Export-AZSCJsonReport.ps1`** — New function at `Modules/Private/Reporting/Export-AZSCJsonReport.ps1`
  - Reads all `{FolderName}.json` cache files produced by the processing phase
  - Assembles a structured JSON document with `_metadata` envelope (tool, version, tenantId, subscriptions, generatedAt, scope)
  - ARM inventory data organized under `arm` key by module folder (compute, network, storage, etc.)
  - Entra/Identity data organized under `entra` key (users, groups, appRegistrations, etc.)
  - Extra reports (advisory, policy, security, quotas) included as top-level keys when available
  - Outputs to `{ReportDir}/{ReportName}_Report_{timestamp}.json` alongside the Excel file
- **`-OutputFormat` parameter** added to `Invoke-AzureScout`
  - `All` (default): Generate both Excel (.xlsx) and JSON (.json) reports
  - `Excel`: Generate Excel report only, skip JSON export
  - `Json`: Generate JSON report only, skip Excel generation
- Conditional logic wraps Excel reporting (`Start-AZSCReporOrchestration`, `Start-AZSCExcelCustomization`) to skip when `OutputFormat = 'Json'`
- JSON file automatically uploaded to Storage Account in automation mode when `OutputFormat` includes Json

#### Phase 8 — Inventory Module Expansion (ARM)

**Azure Local (Stack HCI) — 6 new modules** (`Modules/Public/InventoryModules/AzureLocal/`):
- `Clusters.ps1` — Cluster inventory (`microsoft.azurestackhci/clusters`): status, version, node count, connectivity, diagnostics level
- `VirtualMachines.ps1` — VM instances (`microsoft.azurestackhci/virtualmachineinstances`): power state, VM size, OS type, CPU/memory, dynamic memory, disks, image reference
- `LogicalNetworks.ps1` — Logical networks (`microsoft.azurestackhci/logicalnetworks`): VM switch, subnets, address prefix, VLAN, DHCP, IP pools, DNS, routes
- `StorageContainers.ps1` — Storage containers (`microsoft.azurestackhci/storagecontainers`): provisioning state, path, available/container size (GB)
- `GalleryImages.ps1` — Gallery images (`microsoft.azurestackhci/galleryimages`): OS type, Hyper-V generation, publisher/offer/SKU/version
- `MarketplaceGalleryImages.ps1` — Marketplace images (`microsoft.azurestackhci/marketplacegalleryimages`): OS type, generation, publisher/offer/SKU/version, download size, progress

**Azure Arc — 4 new modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcGateways.ps1` — Arc Gateway inventory (`microsoft.hybridcompute/gateways`): gateway type, endpoint, allowed features
- `ArcKubernetes.ps1` — Arc-enabled Kubernetes (`microsoft.kubernetes/connectedclusters`): connectivity, distribution, K8s version, node count, agent version, infrastructure
- `ArcResourceBridge.ps1` — Resource bridge/appliances (`microsoft.resourceconnector/appliances`): status, distro, version, infrastructure type
- `ArcExtensions.ps1` — Machine extensions (`microsoft.hybridcompute/machines/extensions`): machine name, publisher, type, version, auto upgrade, status

#### Phase 9 — Governance, Security & Monitoring Expansion

**Azure Policy & Governance — 6 new modules** (`Modules/Public/InventoryModules/Management/`):
- `ManagementGroups.ps1` — Management group hierarchy (`microsoft.management/managementgroups`): parent chain, child count (recursive enumeration)
- `CustomRoleDefinitions.ps1` — Custom RBAC roles (`microsoft.authorization/roledefinitions`): assigned scope, Actions, NotActions (parsed from JSON permissions)
- `PolicyDefinitions.ps1` — Custom policy definitions (`microsoft.authorization/policydefinitions`): policy type, mode, metadata, rule JSON (parsed)
- `PolicySetDefinitions.ps1` — Policy initiatives (`microsoft.authorization/policysetdefinitions`): definition references count, parameter count, policy definition groups
- `PolicyComplianceStates.ps1` — Per-subscription compliance (`microsoft.policyinsights/policyStates`): compliance state (Compliant/NonCompliant), yellow conditional formatting for NonCompliant
- `MaintenanceConfigurations.ps1` — Update Manager configurations (`microsoft.maintenance/maintenanceconfigurations`): scope, maintenance window (start/expiration/duration/time zone/recurrence), install patches configuration (Windows/Linux classifications, KB numbers, reboot setting), extension properties count

**Microsoft Defender for Cloud — 4 new modules** (`Modules/Public/InventoryModules/Security/`):
- `DefenderAssessments.ps1` — Security recommendations (`/microsoft.security/securescores/.../assessments`): status, severity, category, resource ID parsing, red highlighting for High/Non-Compliant
- `DefenderSecureScore.ps1` — Secure Score tracking (`/microsoft.security/securescores`): current/max points, percentage calculation, weight, nested control retrieval, red highlighting <50%
- `DefenderAlerts.ps1` — Security alerts (`microsoft.security/locations/.../alerts`): MITRE ATT&CK tactics/techniques, entity parsing (account/host/IP/mailbox/process), remediation steps, red/yellow conditional formatting
- `DefenderPricing.ps1` — Defender plan enablement (`microsoft.security/pricings`): per-resource-type pricing tier, friendly name mapping (VirtualMachines, SqlServers, Storage, KeyVaults, etc.), green/red conditional formatting

**Azure Monitor Resources — 6 new modules** (`Modules/Public/InventoryModules/Monitoring/`):
- `ActionGroups.ps1` — Alert notification channels (`microsoft.insights/actiongroups`): email receivers (name:address pairs), SMS receivers (name:country-phone), webhook receivers, Azure App Push, automation runbooks, Azure Functions, Logic Apps, total receiver count, enabled status
- `MetricAlertRules.ps1` — Metric-based alert rules (`microsoft.insights/metricalerts`): criteria type, condition parsing (metric name, operator, threshold, time aggregation), target resource enumeration, action group references, severity mapping (0-4 to Critical/Error/Warning/Informational/Verbose), evaluation frequency/window size, auto-mitigate status
- `ScheduledQueryRules.ps1` — Log query-based alerts (`microsoft.insights/scheduledqueryrules`): KQL query extraction, data source identification (Log Analytics workspaces), condition parsing (metric measure column, operator, threshold), action group references, legacy alert detection (kind != 'LogAlert'), legacy API warning flag
- `DataCollectionRules.ps1` — Azure Monitor Agent configurations (`microsoft.insights/datacollectionrules`): data source parsing (performance counters, Windows event logs, syslog, extensions), destination tracking (Log Analytics workspace names, Azure Monitor Metrics, Event Hub, Storage), data flow enumeration (streams to destinations mapping), KQL transformation detection, data collection endpoint association, immutable ID tracking
- `DataCollectionEndpoints.ps1` — Log ingestion endpoints (`microsoft.insights/datacollectionendpoints`): network access configuration (public/private), configuration/logs/metrics ingestion endpoint URLs, private link scope connections, failover configuration parsing, immutable ID tracking
- `SubscriptionDiagnosticSettings.ps1` — Activity Log configurations (per-subscription iteration via `Get-AzDiagnosticSetting`): enabled log category enumeration, retention policy parsing (days or unlimited), multi-destination support (Log Analytics workspace, Storage account, Event Hub namespace, Partner solutions), category enablement count (enabled/total), per-subscription iteration with error handling

**Network & Managed Services — 2 new modules**:
- `NetworkWatchers.ps1` — Network diagnostic instances (`microsoft.network/networkwatchers` in `Network/`): flow log enumeration (child resource aggregation), connection monitor tracking, packet capture counting, provisioning state, capability listing (IP Flow Verify, Next Hop, VPN Troubleshoot, NSG Diagnostics, Topology, Connection Troubleshoot)
- `LighthouseDelegations.ps1` — Service provider delegations (`Microsoft.ManagedServices/registrationDefinitions` in `Management/`): managing tenant identification (ID and display name), authorization parsing (principal ID, principal display name, role definition ID), role GUID to friendly name mapping (Contributor, Owner, Reader, monitoring/log analytics roles), delegation type detection (Permanent vs Eligible/JIT based on delegatedRoleDefinitionIds), eligible authorization counting, provisioning state tracking

**Entra ID Verification — 2 new modules** (`Modules/Public/InventoryModules/Identity/`):
- `IdentityProviders.ps1` — Federated/social identity providers (`/v1.0/identity/identityProviders`): provider type (Built-In, Social, SAML/WS-Fed, OIDC, Apple), identity provider type, client ID, client secret configured flag, issuer URL, domains hint, response mode/type, scope, enabled status, yellow conditional formatting if client secret not configured
- `SecurityDefaults.ps1` — Security Defaults enforcement policy (`/v1.0/policies/identitySecurityDefaultsEnforcementPolicy`): enabled status, description, last modified date, protections provided (MFA requirements, legacy auth blocking), recommendation status, green formatting if enabled, yellow if disabled

**Extraction Layer Enhancement**:
- `Start-AZSCEntraExtraction.ps1` — Added 2 new Graph API queries: `/v1.0/identity/identityProviders` (array), `/v1.0/policies/identitySecurityDefaultsEnforcementPolicy` (SingleObject)

### Changed

#### Phase 8 — Enhanced VPN & Networking Detail

- `VirtualNetworkGateways.ps1` — Added 10 new fields: P2S address pool, VPN client protocols, auth type, root/revoked cert counts, RADIUS server, AAD tenant, custom DNS servers, NAT rules count, policy group count
- `Connections.ps1` — Added 13 new fields: IPsec/IKE encryption & integrity, DH group, PFS group, SA lifetime/data size, policy-based traffic selectors, traffic selectors, DPD timeout, ingress/egress bytes, shared key presence (boolean only)

### Removed

- RAMP functions (`Modules/Private/4.RAMPFunctions/`)
- `Invoke-AzureRAMPInventory` public function
- Auto-update logic (`Update-Module` call)
- `Remove-ARIExcelProcess` (aggressive Excel process killer)

### Fixed

- **Permission audit subscription scoping** (#19) — `Invoke-AZSCPermissionAudit` now accepts `-SubscriptionID` and scopes RBAC/provider checks to only targeted subscriptions instead of auditing all accessible subscriptions in the tenant. Passed through from `Invoke-AzureScout` and `Test-AZSCPermissions`

### Changed

- All exported function names: `*-ARI*` → `*-AZSC*`
- Module metadata (author, description, project URI, tags)
- LICENSE updated with dual copyright (original + fork)

#### Phase 11 — Comprehensive Subscription & Management Group Logging

- **Subscription completeness**: Updated extraction layer to enumerate ALL tenant subscriptions (including empty/disabled ones), not just subscriptions containing resources
- **Subscription properties** per record: Subscription ID, Name, State (Enabled/Disabled/Warned), Tenant ID, Management Group path/hierarchy, Tags, Resource count, Spending limit status, Authorization source
- **"All Subscriptions" worksheet** added to Excel report with conditional formatting (empty subscriptions highlighted)
- **Management Group completeness**: Captures ALL management groups in tenant hierarchy via `Get-AzManagementGroup -Expand -Recurse`
- **Management Group properties** per record: ID, display name, parent MG ID, children (child MGs + subscriptions), hierarchy level/depth, policy assignment count, role assignment count
- **"Management Groups" worksheet** added to Excel report with indented hierarchy visualization
- Overview tab resource counts updated to reflect all subscriptions and management groups (not just resource-bearing ones)

#### Phase 13 — Comprehensive Azure Monitor / Insights Coverage

**Core Azure Monitor Resources — 6 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `ResourceDiagnosticSettings.ps1` — Per-resource diagnostic settings via `Get-AzDiagnosticSetting`: ResourceId, ResourceName, ResourceType, log/metric categories (enabled/disabled), destinations (Log Analytics, Storage, Event Hub, Partner Solutions). Excel: "Resource Diagnostic Settings"
- `ActivityLogAlertRules.ps1` — Activity log alerts via `Get-AzActivityLogAlert`: Name, ResourceGroup, Enabled, Scopes, Condition (category, level, status), Actions (Action Group names). Excel: "Activity Log Alerts"
- `SmartDetectorAlertRules.ps1` — Smart detector alerts via `microsoft.alertsmanagement/smartDetectorAlertRules`: Name, Severity, Frequency, Detector type, Application Insights scope, ActionGroups. Excel: "Smart Detector Alerts"
- `AutoscaleSettings.ps1` — Autoscale configurations via `Get-AzAutoscaleSetting`: TargetResourceId, Enabled, Profiles (name, capacity min/max/default, rules count), Notifications (webhooks, email). Excel: "Autoscale Settings"
- `MonitorWorkbooks.ps1` — Azure Monitor Workbooks via `microsoft.insights/workbooks`: Name, Category, SourceId (linked resource), TimeModified. Excel: "Azure Monitor Workbooks"
- `MonitorPrivateLinkScopes.ps1` — Monitor Private Link Scopes via `microsoft.insights/privateLinkScopes`: Name, PrivateEndpointConnections count, ScopedResources count/types. Excel: "Monitor Private Link Scopes"

**Log Analytics Enhancements — 3 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `LAWorkspaceSavedSearches.ps1` — Saved searches per workspace: DisplayName, Category, Query, Version. Excel: "LA Saved Searches"
- `LAWorkspaceSolutions.ps1` — Installed solutions via `microsoft.operationsmanagement/solutions`: WorkspaceResourceId, Plan (name, publisher, product), ProvisioningState. Excel: "LA Solutions"
- `LAWorkspaceLinkedServices.ps1` — Linked services per workspace: WorkspaceName, ResourceId, WriteAccessResourceId (Automation Account). Excel: "LA Linked Services"

**Application Insights Deep Data — 5 new modules** (`Modules/Public/InventoryModules/Monitor/`):
- `AppInsightsAvailabilityTests.ps1` — Classic availability tests, Enabled, Frequency, Timeout, Locations count. Excel: "App Insights Availability Tests"
- `AppInsightsWebTests.ps1` — Web tests via `microsoft.insights/webtests`: Kind (ping/multistep/standard), SyntheticMonitorId, Enabled, Frequency, Timeout. Excel: "App Insights Web Tests"
- `AppInsightsProactiveDetection.ps1` — Proactive detection configurations: RuleDefinitions (name, enabled, email settings). Excel: "App Insights Proactive Detection"
- `AppInsightsContinuousExport.ps1` — Continuous export configurations: ExportId, DestinationStorageId, IsEnabled, RecordTypes. Excel: "App Insights Continuous Export"
- `AppInsightsWorkItems.ps1` — Work item configurations via `microsoft.insights/workitemconfigs`: ConnectorId (Azure DevOps, GitHub), IsValidated. Excel: "App Insights Work Items"

**Metrics & Ingestion — 1 new module** (`Modules/Public/InventoryModules/Monitor/`):
- `MonitorMetricsIngestion.ps1` — Log Analytics workspace ingestion statistics: WorkspaceName, DailyIngestionGB, MonthlyIngestionGB, RetentionDays, CapGB (daily cap). Excel: "Metrics Ingestion Stats"

#### Phase 16 — Arc Enhanced Configuration Coverage

**New Hybrid modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcSiteConfigurations.ps1` — Arc Site Manager configurations via `microsoft.hybridcompute/sites`: SiteName, ResourceGroup, Location, ConnectedMachines count, Kubernetes clusters count, governance policy count, update schedule configuration. Excel: "Arc Site Configurations"
- `ArcEnabledSQLServer.ps1` — Arc-enabled SQL Server instances via `microsoft.azurearcdata/sqlServerInstances`: ServerName, ArcServerResourceId, SQLVersion, Edition, LicenseType, Cores, MemoryMB, Databases count, ESU (enabled/disabled). Excel: "Arc-Enabled SQL Server"
- `ArcDataServices.ps1` — Arc Data Controllers and SQL Managed Instances via `microsoft.azurearcdata/dataControllers`: DataControllerName, K8sNamespace, InfrastructureType (direct/indirect), K8sDistribution, SQLManagedInstances count, PostgreSQL count, DataUploadState. Excel: "Arc Data Services"

**Enhanced existing modules** (`Modules/Public/InventoryModules/Hybrid/`):
- `ArcExtensions.ps1` — Enhanced with deep configuration data: extension settings (parsed JSON), version, auto-upgrade settings, protected settings indicator (yes/no — never actual values), provisioning state, error messages
- `ArcResourceBridge.ps1` — Enhanced with detailed configurations: management IP, subnet, connected cluster details, custom locations linked, provider configurations (VMware, SCVMM, Azure Local)

#### Phase 10 — Excel Specialized Tabs

**New Excel worksheets — all read from `{ReportCache}/{Category}.json` cache files:**
- **`Build-AZSCCostManagementReport.ps1`** — "Cost Management" worksheet: VM cost estimates from `Compute.json`, Arc Server ESU/cost estimates from `Hybrid.json`, reservation recommendations from `Management.json`
- **`Build-AZSCSecurityOverviewReport.ps1`** — "Security Overview" worksheet: Defender for Cloud secure score, high/critical assessments, active alerts, and Defender plan pricing (reads `Security.json`)
- **`Build-AZSCUpdateManagerReport.ps1`** — "Azure Update Manager" worksheet: VMs and Arc servers with patch compliance, NonCompliant rows highlighted yellow
- **`Build-AZSCMonitorReport.ps1`** — "Azure Monitor" worksheet: Action groups, DCRs, DCEs, App Insights, alert rules, autoscale settings — rendered as sequential table sections from `Monitor.json`
- **`Start-AZSCExtraReports.ps1`** — Updated: added `$ReportCache` parameter; calls all four Phase 10 builders after existing quota/policy/advisory reports
- **`Start-AZSCReporOrchestration.ps1`** — Updated: passes `-ReportCache $ReportCache` to `Start-AZSCExtraReports`
- **`Start-AZSCExcelCustomization.ps1`** — Updated: Phase 10 tab names (`Cost Management`, `Security Overview`, `Azure Update Manager`, `Azure Monitor`) excluded from Overview tab row count and resource size sort
- **`Build-AZSCExcelChart.ps1`** — Updated (10.1.2): P00 Overview chart no longer shows "Reservation Advisor" pivot when a "Cost Management" tab exists; reservation data is now exclusively in the dedicated tab. Falls through to the resources area chart instead

#### Phase 18 — Category Metadata Auto-Discovery (18.4.1)

- **`Start-AZSCProcessJob.ps1`** — Enhanced module auto-discovery to parse `.CATEGORY` comment headers from individual `.ps1` files:
  - Builds per-file `ModuleInfoList` objects with `Name`, `FolderCategory`, `FileCategory`, and `Categories` properties
  - When category filtering is active, applies a second per-file filter pass using the `.CATEGORY` header to support cross-category modules that live in one folder but logically belong to another
  - Files with no `.CATEGORY` header fall back to their folder name (backward compatible)
  - Logs filtered file names via `Write-Debug` for traceability

#### Phase 19 — Polish & Documentation

- Updated `README.md` with ARM-only default documentation, expanded permission tables (ARM + Graph), resource provider requirements, and troubleshooting guide
- Added Markdown and AsciiDoc to output file table in README

#### Phase 14 — AI Category Expansion

- **`MLPipelines.ps1`** (`Modules/Public/InventoryModules/AI/`) — Pipeline job inventory via ML REST API (`workspaces/{name}/jobs?$filter=jobType eq 'Pipeline'`): workspace name, pipeline name, pipeline ID, status, created/modified time, experiment name, compute ID. Excel sheet: "ML Pipelines"

#### Phase 15 — Compute Category Expansion

- **`AVDAzureLocal.ps1`** (`Modules/Public/InventoryModules/Compute/`) — AVD session hosts running on Azure Local (HCI) and Arc-enabled infrastructure. Discovers Arc machines and HCI VM instances tagged `AvdSessionHost=true`, plus registered AVD session hosts whose resource IDs reference Arc/HCI VMs. Fields: Platform, Host Pool, Status, Agent Version, Last Heartbeat, Azure Local Cluster, Sessions. Excel sheet: "AVD on Azure Local/Arc"

#### Phase 17 — Resource Enrichment

**Virtual Machine enhancements** (`VirtualMachine.ps1`):
- Azure Monitor Metrics integration: CPU percentage (7-day average) and memory percentage via `/providers/microsoft.insights/metrics?metricnames=Percentage+CPU`
- Azure Site Recovery integration: DR replication status, target region, replication health via Recovery Vault `/replicationProtectedItems` API
- Cost Management integration: Estimated monthly cost (USD) via `Microsoft.CostManagement/query` API
- New Excel columns: `Avg CPU % (7d)`, `Avg Memory % (7d)`, `DR Replicated`, `DR Target Region`, `DR Replication Health`, `Est. Monthly Cost (USD)`

**Arc Server enhancements** (`ARCServers.ps1`):
- PolicyInsights API: Policy assignment count and compliance state (Compliant/NonCompliant)
- Azure Monitor Metrics: CPU usage active percentage (7-day average) for Arc agents
- Cost Management API: ESU enablement status and estimated monthly cost
- Hybrid connectivity: Proxy configuration status and private link scope association
- New Excel columns: `ESU Enabled`, `Est. Monthly Cost (USD)`, `Policy Assignments`, `Policy Compliance`, `Avg CPU % (7d)`, `Proxy Configured`, `Private Link Scope`

#### Phase 18 — Category Structure Alignment

- Category alias normalization added to `Invoke-AzureScout.ps1`: long-form Azure portal names (e.g., `AI + machine learning`, `Internet of Things`, `Management and governance`) automatically mapped to short folder names
- Updated `.vscode/settings.json` with PowerShell extension settings, formatting rules, file associations, and Pester test path configuration
- Created `docs/azure-category-structure.md` — category-to-folder mapping reference with alias table and instructions for adding new categories
- Created `docs/azure-coverage-table.md` — comprehensive inventory coverage table (171 modules across 15 categories)
- Created `docs/modules/ROOT/pages/category-filtering.adoc` — Antora AsciiDoc guide for category filtering with examples, alias support, and execution flow diagram
- Updated `docs/modules/ROOT/nav.adoc` — added Category Filtering to navigation

#### Phase 20 — Help & Examples

- Added 4 `.EXAMPLE` blocks to `Invoke-AzureScout`:
  - `-PermissionAudit` basic usage
  - `-PermissionAudit -OutputFormat Markdown`
  - `-PermissionAudit -Scope All` (ARM + Graph)
  - Full inventory with `-PermissionAudit -Scope All -OutputFormat All`
- **`Test-AZSCPermissions.ps1`** refactored (20.4.1): Now delegates to `Invoke-AZSCPermissionAudit` instead of containing duplicate permission-check logic. Maps the richer audit result back to the simplified `{ArmAccess, GraphAccess, Details}` shape that existing callers expect. Backward compatible — same parameter surface, same return properties

#### Phase 21 — Markdown & AsciiDoc Report Output

- **`Export-AZSCMarkdownReport.ps1`** (`Modules/Private/Reporting/`) — New function generating GitHub-Flavored Markdown reports from cache files. Reads `{CategoryFolder}.json` cache files, renders per-module pipe tables, generates anchored ToC, writes `{ReportName}.md`. Parameters: `ReportCache`, `File`, `TenantID`, `Subscriptions`, `Scope`
- **`Export-AZSCAsciiDocReport.ps1`** (`Modules/Private/Reporting/`) — New function generating AsciiDoc reports from cache files. Same cache-reading pattern as Markdown export, outputs AsciiDoc tables with `:toc: left`, `[TIP]` admonitions per module, writes `{ReportName}.adoc`. Compatible with Antora and Confluence
- **`-OutputFormat Markdown` / `-OutputFormat AsciiDoc`** wired into `Invoke-AzureScout.ps1` — parallel to JSON export block in the reporting phase
- Added `MD` and `Adoc` as `[ValidateSet]` aliases for `Markdown` and `AsciiDoc` respectively
- Updated `-OutputFormat` description in `README.md` to include Markdown and AsciiDoc values with aliases
- Updated output files table in `README.md` to include `.md` and `.adoc` entries
- **21.5.1/21.5.2 — PermissionAudit format support**: `-PermissionAudit -OutputFormat Markdown` now saves a permission audit `.md` report; `-PermissionAudit -OutputFormat AsciiDoc` saves a permission audit `.adoc` report with AsciiDoc role icons and `[source,powershell]` recommendation blocks
- **`Invoke-AZSCPermissionAudit.ps1`** — Added `AsciiDoc` to `[ValidateSet]` for `-OutputFormat`; new AsciiDoc output block with `:toc: left`, `icon:check-circle[]`/`icon:times-circle[]` status icons, and `[source,powershell]` blocks for each recommendation
- **`Invoke-AzureScout.ps1`** — Updated `auditOutputFormat` switch: `MD` → `Markdown`, `AsciiDoc` → `AsciiDoc`, `Adoc` → `AsciiDoc`, `All` → `All` (previously `All` mapped to `Console`)

#### Dependency Bootstrap

- Removed `RequiredModules` hard requirement from `AzureScout.psd1` (changed to `@()`)
- Added auto-install bootstrap to `AzureScout.psm1`: automatically installs and imports `ImportExcel`, `Az.Accounts`, `Az.ResourceGraph`, `Az.Storage`, `Az.Compute`, `Az.Authorization`, `Az.Resources` if not already available

---

**Version Control**
- Created: 2026-02-22 by Kristopher Turner
- Last Edited: 2026-07-24 by Kristopher Turner
- Version: 2.2.0
- Tags: changelog, AzureScout, assessment, CAF, WAF, landing-zone, openxml, pptx, ingest, runtime-verification, report-tiers, drift, cost-anomaly, iac-gap
