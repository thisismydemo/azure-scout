# Handoff

## Session 2026-08-02 — Epic AB#6450 "Enhance the reporting engine with new formats"

Started with the epic plan in DRAFT, `pmo/research/` empty, and **CI red on `main` since v3.2.0**.
Ended with **six PRs merged, `main` green at 2745/0, and Phase 0 complete.**

| PR | What |
|---|---|
| #210 | CI recovery + a real UTC date defect |
| #211 | Site logos |
| #212 | Quality bar, reference teardown, board structure |
| #213 | **Phase 0 — three real tenants measured** |
| #214 | **Clause R-01 — a report set per assessment** |
| #215 | Correction of a false Phase 0 finding |

---

### 1. CI recovery (#210)

15 failures, five causes. One was a **real product defect**: `[datetime]'1970-01-01Z'` resolves to
**local** time, so Key Vault `Expires`/`Created`/`Updated`/`NotBefore` shifted by a day with the
running machine's timezone — the same tenant scanned from Chicago and London disagreed about when
a key expires. Fixed to `[datetime]::UnixEpoch` at all seven spec sites; verified identical under
UTC / America/Chicago / Asia/Tokyo. It is also why the goldens passed locally and failed in CI.

Second real defect: `Invoke-Assessment` read `$set.Weight` and `$set.FrameworkVersion` unguarded
on the `Add-Member` chain decorating **every** finding, so one rule file without a
`frameworkVersion:` key took down the whole assessment under StrictMode.

The rest were stale contracts (collector count 241→242, the retired `Modules/` root, AB#6801's
added ArcSites call, `docs/prerequisites.md` moving under `docs/guide/`).

### 2. Phase 0 — the result that reframes the epic (#213)

Three real tenants, one identical command, every format.

| | `tppoc` | `hcs` | `ptlmgmt` |
|---|--:|--:|--:|
| Subscriptions | **9** | **2** | **8** |
| Run time | 27.9 min | 9.1 min | 15.1 min |
| Findings | 304 | 304 | 304 |
| **Word paragraphs** | **1,803** | **1,803** | **1,803** |
| **Word tables** | **36** | **36** | **36** |
| Findings with evidence | 36 | 36 | **9** |

**Three unrelated estates produce documents within 258 bytes of each other.** The scoring
underneath differs correctly per tenant, so the engine works — the document renders the **rule
set**, not the estate.

Measured on `word/document.xml`: **0** `/subscriptions/<guid>`, **0** `resourceGroups/` in every
report. **Not one Azure resource is named anywhere.**

**Zero automatic conformance clauses pass.** The `.docx` package has **three parts**; **0 of
1,803 paragraphs carry a style**. `report.pbit` is 4,689 B and its authored `Report/Layout` is
**2,190 B**.

Full critique: `pmo/research/baseline/`.

### 3. Clause R-01 shipped (#214)

`Invoke-ScoutAssessmentCore` now accumulates `$findingsByAssessment` alongside `$allFindings` and
renders each selected assessment into `assessments/<slug>/` with its own format set. Merged
run-root set **kept**; each assessment **scored independently**; only splits when >1 assessment
ran; renderer failure contained per assessment. `tests/Report.PerAssessmentContract.Tests.ps1`,
14 tests.

### 4. A finding I got wrong, and corrected (#215)

I reported eight `_dash_src_*` sheets shipping visible to clients. **There are four and all four
are hidden** — `Export-Excel.ps1` already passes `HideSheet`. AB#6891 closed as not-a-defect.

Cause: I read the sheet list from `xl/workbook.xml` **without checking each sheet's `state`
attribute**. Hidden sheets are still listed there. **Check `state` before calling a sheet
visible.** AB#6890 was re-verified the same way and **is** real — 35 of 39 sheets are visible and
the unselected-assessment tabs are among them.

---

## Board

Epic AB#6450 now has **7 Features and 18 Stories** (AB#6865–6889); AB#6450 and AB#6449 had no
description at all and were backfilled. Every item carries acceptance criteria bound to a clause
id in `docs/design/report-conformance.md`. **No child may close on "a file came out"** — that is
the failure mode that let 103 report items close green.

Done: AB#6865/6866/6867/6868 (Phase 0), AB#6873 (R4 teardown), AB#6879 (R-01).
Open bug: **AB#6890**. Closed not-a-defect: AB#6891.

## Next, in the order Phase 0 argues for

1. **Evidence projection at resource grain** — *this outranks the template work.* Only 9–36 of
   304 findings carry evidence, so no renderer can name a resource in a table that has none.
   Needs a new Feature; the useful code is on the unmerged `feat/ab6450-reporting-v2` branch
   (`Build-ScoutReportModel.ps1`, gap register, triage verdicts).
2. **AB#6880** — the cross-assessment executive roll-up (`R-03`).
3. **AB#6874** — styles/cover/headers (`W-01`…`W-09`). `W-01`/`W-02` are the keystone: styles
   unlock nav pane, TOC, numbering and rebranding in one move.
4. **AB#6888** — write `tests/Report.Conformance.Tests.ps1`. Expect red at first; that is the point.
5. **AB#6890** — rule-glob leakage into the workbook.
6. R1/R2/R3 spikes (AB#6870–6872), incl. the AzViz/AzGovViz/D2 evaluation.

## Scope caveat to state on the epic

~60% of every report is `Manual` or `Unknown` (141–148 Manual, 31–45 Unknown of 304). That is the
225-of-395 `manual: true` ceiling, owned by **Epic AB#6454**. Clause `W-17` requires a conformant
report to say "Not assessed" plainly, so this is correct behaviour — AB#6450 must not be judged
against a bar its inputs cannot reach.

## Gotchas found this session

- **`Az.Accounts 5.5.0` declares `-AccessToken` as `[String]`.** Passing a `SecureString`
  stringifies to `System.Security.SecureString`; Az then warns *"The access token is invalid"* and
  reports **0 subscriptions** — indistinguishable from a permissions failure. Verify the token
  against ARM REST before believing a permissions story.
- **`Select-Object -Unique` returns a scalar** for a one-element result; `.Count` then throws
  under StrictMode. Wrap in `@()`.
- **The collector generator strips comments hand-added to a generated manifest.**
  `Collector.VanishingParent.Tests.ps1` requires the AB#6845 decision comment *next to its loop in
  the manifest*, so the generator now emits a per-loop `Comment` from the spec.
- **ADO rejects `System.AreaPath`** when the create URL uses the project GUID. Omit AreaPath and
  IterationPath — they default to the project root.
- **VitePress resolves relative links at build time**; `/pmo` is unpublished, so a link out of
  `docs/` into it fails the docs build. Run `npm run docs:build` after adding any docs page.
- **Local suite ≠ CI.** Locally ~56 failures vs CI's 15: ~40 are the *installed* AzureScout module
  colliding with the repo copy, 7 more are a live Az context. Judge against CI; reproduce a CI
  failure by running the single test file in isolation.
- **GitHub App tokens expire in ~1h.** Re-mint via HCS MCP `get_auth_token`; push by temporarily
  rewriting the remote to `https://x-access-token:<tok>@github.com/...`.

## How to re-run a baseline

Runner script lives in the session scratchpad (`baseline-run.ps1`). Env: `SCOUT_REPO`,
`SCOUT_TENANT`, `SCOUT_APPID` (the token's `appid` claim), `SCOUT_OUT`, `SCOUT_TOKEN` from
HCS MCP `get_auth_token -provider azure -scope <alias>`. It issues:

```powershell
Invoke-AzureScout -TenantID $t -InventoryAndAssessment `
  -Assessment 'LandingZone','Assess: Cloud Governance' -OutputFormat All -ReportDir $out
```
