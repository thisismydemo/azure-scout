# Handoff

## Session 2026-08-02 — Epic AB#6450 "Enhance the reporting engine with new formats"

Picked up with the epic plan in DRAFT, `pmo/research/` empty, and **CI red on `main` since
v3.2.0**. Nothing could merge, so that came first.

### 1. CI is green again — PR #210, awaiting review

`main` had **15 failures**, five distinct causes. One was a real product defect.

| Cause | Fix |
|---|---|
| **Key Vault dates were rendered in LOCAL time** | `[datetime]'1970-01-01Z'` resolves to local. A key's `Expires`/`Created`/`Updated`/`NotBefore` shifted by a day depending on the machine's timezone, and `Days To Expiry` shifted with it — the same tenant scanned from Chicago and from London disagreed about when a key expires. Now `[datetime]::UnixEpoch` (Kind=Utc) at all seven spec sites. Verified identical under `UTC`, `America/Chicago`, `Asia/Tokyo`. **This is also why the goldens passed locally and failed in CI** — they were captured in a negative-offset zone. |
| Collector count pinned at 241/240 | AB#6829 added `General/ReservationUtilization` → **242** |
| `Modules/` (retired imperative root) is gone | the gate asserting its *absence* threw on a missing path instead of passing |
| AB#6801 added a per-subscription `Microsoft.Edge/sites` call | the equivalence gate compares against a frozen copy of retired v1 which predates that type; the call is now asserted explicitly and excluded from the ordering comparison. REST cost **7 → 8**; `-DefinitionsOnly` unchanged at 2 |
| `docs/prerequisites.md` moved to `docs/guide/` | test was failing on a missing file, not missing content |

Plus a second real defect found on the way: `Invoke-Assessment` read `$set.Weight` and
`$set.FrameworkVersion` unguarded. Both are optional rule-set metadata read on the
`Add-Member` chain that decorates **every** finding, so one rule file without a
`frameworkVersion:` key threw under StrictMode and took down the whole assessment.

**Result: 2745 passed, 0 failed.**

### 2. The site logos — PR #211, awaiting review

Both logo slots pointed at the 640x160 wordmark. The navbar slot is 24px tall so it rendered
~96x24 and was unreadable; the home hero caps `.image-src` at 192/256/320px, sizing for a
square app icon, so the 4:1 banner was pinned by its **width** at 320x80.

Navbar now uses `azurescout-icon.svg`. The hero drops the icon-shaped circular `.image-bg`
halo and the square cap, giving 320/420/480px — **480x120 against the previous 320x80**.
Needed a custom theme (`docs/.vitepress/theme/`), which the site did not have. Overrides win
on source order at equal specificity, verified against the built bundle, so no `!important`.

### 3. Epic AB#6450 — board built and the quality bar written

Branch `feat/ab6450-reporting-rebuild`.

**The board.** AB#6450 and AB#6449 were the only two report items with **no description at
all**, which is how this drifted. Both backfilled. Created **7 Features and 18 Stories**:

| Feature | Theme |
|---|---|
| AB#6865 | Baseline and critique — Phase 0 real-tenant runs (Stories 6866–6868: tppoc, hcs, ptlmgmt) |
| AB#6869 | Research spikes R1–R4 (6870–6873) — **includes the AzViz/AzGovViz/D2 evaluation that was never a work item** |
| AB#6874 | Report identity and template system (6875–6877) |
| AB#6878 | Per-assessment output contract (6879–6880) |
| AB#6881 | Diagram engine + rasterisation (6882–6883); Related-linked to the blocking AB#6737 and AB#379 |
| AB#6884 | Power BI PBIP/TMDL (6885–6886) |
| AB#6887 | Quality bar and conformance test (6888–6889) |

Every one carries acceptance criteria bound to a clause id. **No child may close on "a file
came out"** — that is the failure mode that let 103 report items close green.

**R4 teardown** (`pmo/research/R4-reference-deliverable-teardown.md`) — done, and it is the
one spike that is genuinely complete. The reference `.docx`/`.pptx`/`.xlsx` packages were read
directly; every count is measured, not estimated. 5,643 paragraphs, **43 tables, 9 figures**
mapped to sections; 11 slides and 13 workbook tabs inventoried.

> **The load-bearing finding:** all seven chapters have the *identical* shape — chapter-level
> scorecard table → Current State → 1–3 findings tables → ≤1 figure. That is a shape a renderer
> can emit, and it **is** the per-assessment unit. Plan §5's "a detailed report for each" is this
> chapter template instantiated per assessment, with the Executive Summary becoming the roll-up.
> Also: the conclusion comes **first** (exec summary precedes chapter 1; Scout orders by area
> and has no conclusion anywhere).

**The quality bar** (`docs/design/report-conformance.md`) — 46 numbered clauses across Word,
PowerPoint, Excel, diagrams, Power BI and the run output contract, each marked `automatic` or
`judged`. Most automatic clauses are properties of the emitted **package**, so they are
verifiable offline against a fixture — no tenant, CI-enforceable.

### Blockers

- **PRs #210 and #211 need an approving review.** `main` requires 1, I cannot self-approve, and
  repo-level auto-merge is disabled (`enablePullRequestAutoMerge` not allowed). Nothing else
  lands until #210 does.
- `feat/ab6450-reporting-rebuild` is based on pre-fix `main`, so its own CI will show the old 15
  failures until #210 merges. Rebase after.

### Next, in order

1. Merge #210, then #211, then rebase the epic branch.
2. **AB#6865 Phase 0** — the real-tenant baselines. Everything below is blocked on it by the
   plan's own rule that nothing may be designed against imagination. Azure tokens come from the
   HCS MCP `get_auth_token -provider azure -scope <alias>`; verified working for `tppoc`.
3. AB#6888 — write the conformance test. Expect it red at first; that is the point.
4. `feat/ab6450-reporting-v2` (8 commits, unmerged) carries the report model and narrative
   engine. Its docs commits already landed via #207, so **rebase onto main to drop them**. It is
   scaffolding, not the deliverable — keep it only if the Phase 0 critique supports it.

### Gotchas found this session

- `Select-Object -Unique` returns a **scalar** for a one-element result; `$x.Count` then throws
  under StrictMode. Wrap in `@()`.
- The ADO work-item create API rejects the literal project name as `System.AreaPath` when the
  URL uses the **project GUID**. Omit AreaPath/IterationPath — they default to the project root.
- `scripts/Build-ScoutServiceCollector.ps1` regenerates from the spec and **strips any comment
  hand-added to a generated manifest**. `tests/Collector.VanishingParent.Tests.ps1` requires the
  AB#6845 decision comment to sit *next to its loop in the manifest*, so the generator now emits
  a per-loop `Comment` from the spec. Moving rationale to the spec alone is not sufficient.
- The GitHub App installation token expires in ~1h. Re-mint via HCS MCP `get_auth_token`, and
  push by temporarily rewriting the remote to `https://x-access-token:<tok>@github.com/...`.
- Locally the suite shows ~56 failures against CI's 15: ~40 are the **installed** AzureScout
  module colliding with the repo copy ("Multiple script or manifest modules named 'AzureScout'"),
  and 7 more are a live Az context. Neither reproduces in CI. Judge against CI, not local.
