# Phase 0 — baseline runs and critique

**Feature:** AB#6865 · Stories AB#6866 (`tppoc`), AB#6867 (`hcs`), AB#6868 (`ptlmgmt`)
**Bar:** [`docs/design/report-conformance.md`](../../../docs/design/report-conformance.md)

Three real tenants, one identical command, every output format:

```powershell
Invoke-AzureScout -TenantID <t> -InventoryAndAssessment `
  -Assessment 'LandingZone','Assess: Cloud Governance' -OutputFormat All
```

Detail: [`tppoc-critique.md`](tppoc-critique.md) ·
[`hcs-critique-and-cross-tenant.md`](hcs-critique-and-cross-tenant.md)

---

## The result

| | `tppoc` | `hcs` | `ptlmgmt` |
|---|--:|--:|--:|
| Subscriptions | **9** | **2** | **8** |
| Estate | platform/workload landing zone | demo estate | CMP landing zone |
| Run time | 27.9 min | 9.1 min | 15.1 min |
| Raw inventory | 317 MB | — | 266 MB |
| Findings | 304 | 304 | 304 |
| **Word paragraphs** | **1,803** | **1,803** | **1,803** |
| **Word tables** | **36** | **36** | **36** |
| `.docx` bytes | 26,392 | 26,377 | 26,635 |
| Findings **with evidence** | 36 | 36 | **9** |
| Status split | F57 P68 M148 U31 | F54 P66 M141 U43 | F53 P65 M141 U45 |

**Three unrelated estates. Identical paragraph and table counts. Documents within 258 bytes of
each other.**

The scoring underneath differs correctly per tenant — Fail 57 / 54 / 53, Unknown 31 / 43 / 45 —
so the assessment engine works. **The document does not render the estate. It renders the rule
set**: one row per rule, with a verdict.

## Why: the documents name nothing

Measured directly on `word/document.xml`:

| Probe | `tppoc` | `hcs` |
|---|--:|--:|
| `/subscriptions/<guid>` occurrences | **0** | **0** |
| `resourceGroups/` occurrences | **0** | **0** |

Not one Azure resource is named in any report. Upstream, only 36 / 36 / **9** of 304 findings
carry evidence at all — so there is nothing for a renderer to point at.

This is the largest single gap against the reference deliverable, whose defining property is the
opposite: *"60 of 198 storage accounts", never "storage accounts are misconfigured"*. A finding
that cannot be actioned is decoration.

## Conformance scorecard

**Zero automatic clauses pass**, across all three runs:

| Group | Failing |
|---|---|
| Run contract | `R-01` `R-02` `R-03` — two assessments in, **one** `assessment_report.docx` out |
| Word | `W-01`…`W-09`, `W-12`, `W-14` — package has **3 parts**; **0 of 1,803 paragraphs styled**; 0 figures |
| Deck | `P-01`…`P-05` — 10 slides, 2 layouts, **0 media**; six slides paginate two ideas |
| Workbook | `X-01` `X-02` — no cover; tabs named per rule-area, not per gap class |
| Diagrams | `D-01`…`D-03` — `.drawio` only, no raster, so nothing can embed |
| Power BI | `B-01` `B-03` `B-05` — `Report/Layout` is **2,190 bytes**: a blank canvas |

## What Phase 0 changed about the plan

1. **Collection is not the problem.** 266–317 MB of raw inventory per run. Every failure is in the
   assessment→report path or in the renderers.
2. **But styling alone will not fix it.** The initial `tppoc` read was "structure and presentation
   only". The cross-tenant comparison disproves that: no renderer, however well styled, can name a
   resource in a table that has none. **Evidence projection at resource grain should be promoted
   to a first-class Feature ahead of the template work (AB#6874)** — it is the one genuinely
   valuable piece of the unmerged `feat/ab6450-reporting-v2` branch.
3. **`R-01` is independent** of all of it and is the owner's stated ask. AB#6878 can proceed in
   parallel; it is a change to the run loop, not to any renderer.
4. **`W-01`/`W-02` remain the keystone** for the document itself — styles unlock the navigation
   pane, TOC, numbering and rebranding in one move.

## Two defects found here that were not in the plan

Both are now tracked:

1. **AB#6890 — rule-glob leakage into the report surface.** The evidence workbook carries tabs for
   assessments that were never selected — `AVS_Landing_Zone`, `AVD_workload__Azure_Local_`,
   `IoT_security` — in a run of LandingZone + Cloud Governance. It invites the reader to believe
   those areas were assessed.
2. **AB#6891 — internal scaffolding ships to the client.** Eight `_dash_src_*` sheets are present in the
   39-sheet workbook.

## Scope caveat, to be stated on the epic

Roughly **60% of every report is `Manual` or `Unknown`** (141–148 Manual, 31–45 Unknown of 304).
That is the 225-of-395 `manual: true` rule ceiling and it belongs to **Epic AB#6454, not this
one**. Clause `W-17` requires a conformant report to say "Not assessed" plainly rather than render
a zero or a pass — so this is correct behaviour, and AB#6450 must not be judged against a bar its
inputs cannot reach.

## Method note

Az.Accounts 5.5.0 declares `-AccessToken` as `[String]`. Passing a `SecureString` stringifies to
`System.Security.SecureString`, after which Az warns *"The access token is invalid"* and reports
**0 subscriptions** — indistinguishable from a permissions failure. Verify any token against ARM
REST before accepting a permissions explanation.
