# Phase 0 baseline — `hcs`, and the cross-tenant comparison

**Work item:** AB#6867 (Story) under Feature AB#6865
**Run:** 2026-08-02, tenant `hcs` (`d6fc73cf…` — the owner's named target), **2 subscriptions**, 9.1 minutes
**Command:** identical to the `tppoc` run — `-InventoryAndAssessment -Assessment 'LandingZone','Assess: Cloud Governance' -OutputFormat All`

Read with [`tppoc-critique.md`](tppoc-critique.md). Every `tppoc` failure reproduces here, so this
document covers only what the **second** tenant adds — which turns out to be the most important
result of Phase 0.

---

## 1. The finding: the report is very nearly invariant to the tenant

Two tenants of deliberately contrasting size were run through the identical command.

| | `tppoc` | `hcs` |
|---|--:|--:|
| Subscriptions | **9** | **2** |
| Run time | 27.9 min | 9.1 min |
| Findings | 304 | 304 |
| **Word paragraphs** | **1,803** | **1,803** |
| **Word tables** | **36** | **36** |
| **Word document.xml** | **649,242 chars** | **649,250 chars** |
| `.docx` on disk | 26,392 B | 26,377 B |
| `.pptx` on disk | 23,072 B | 23,071 B |
| `.pbit` on disk | 4,689 B | 4,688 B |

A nine-subscription platform landing zone and a two-subscription demo estate produce documents
that differ by **eight characters**.

The scoring underneath *is* tenant-specific — `tppoc` scores Fail 57 / Pass 68 / Unknown 31,
`hcs` scores Fail 54 / Pass 66 / Unknown 43 — so the engine is genuinely assessing each estate.
**The document simply does not render that difference.** It renders the rule set.

## 2. Why: there is not one named resource in the document

Measured directly against `word/document.xml` in both runs:

| Probe | `tppoc` | `hcs` |
|---|--:|--:|
| ARM subscription ids (`/subscriptions/<guid>`) | **0** | **0** |
| `resourceGroups/` mentions | **0** | **0** |

**Zero.** Neither document names a single Azure resource.

The cause is upstream of the renderer: of 304 findings, only **36 carry any evidence at all**
(12%). The other 268 are a verdict with no supporting rows. So the Word renderer emits one table
row per *rule*, with a status, and nothing to point at.

This is the single largest gap against the reference, whose defining property is the opposite:

> Every risk row carries **its supporting number**. "60 of 198 storage accounts", never "storage
> accounts are misconfigured". Named resources. **A finding that cannot be actioned is decoration.**

`W-14` fails absolutely, and it is not a formatting problem. It is why the document is 1/50 the
size of the reference and why it reads the same for every client.

## 3. What this changes about the epic

The `tppoc` critique concluded "the data is not the problem — every failure is structure and
presentation". **That conclusion needs qualifying, and this run is why.**

- Collection *is* fine: `raw-inventory.json` was 317 MB for `tppoc`, and the inventory workbook
  carries real rows.
- **The assessment-to-report path is where the estate is lost.** Findings arrive at the renderer
  already stripped of evidence for 88% of rules, so no renderer — however well styled — can put a
  named resource in a table that has none.

So Feature AB#6874 (styles, cover, headers) makes the document *look* like a deliverable, and
Feature AB#6878 (per-assessment contract) makes it *plural*, but neither makes it **about the
client**. That needs evidence projection at resource grain, which is the one genuinely valuable
piece of the unmerged `feat/ab6450-reporting-v2` branch (`Build-ScoutReportModel.ps1`,
gap register, evidence at resource grain).

**Recommendation: promote evidence projection to a first-class Feature under AB#6450**, ahead of
the template work. A beautifully styled document that names no resources still cannot be sent to
a client.

## 4. Caveat — the manual-rule ceiling is not this epic's fault

148 of 304 findings on `tppoc` (49%) and 141 on `hcs` are `Manual`, and a further 31/43 are
`Unknown`. Roughly **60% of every report is "not assessed"**.

That is the known 225-of-395 `manual: true` rule ceiling and it belongs to Epic AB#6454, not
here. Clause `W-17` explicitly requires those to render as "Not assessed" rather than as a zero
or a pass, so a conformant report **still says this**. Worth stating plainly on the epic so this
work is not judged against a bar its inputs cannot reach.

## 5. Clause verdicts added by this run

| Clause | Verdict | Evidence |
|---|---|---|
| `W-14` every row carries its number and a named resource | **FAIL** | 0 ARM ids in either document; 36/304 findings carry evidence |
| `W-08` cover carrying client/tenant | **FAIL** | reconfirmed — nothing in the document identifies which tenant it describes |
| `W-09` provenance and scan date | **FAIL** | reconfirmed; two tenants, byte-identical output, no way to tell them apart |

`W-08`/`W-09` deserve re-emphasis in light of §1: **you cannot tell these two documents apart.**
Handed both, a reader has no way to know which estate either describes.

## 6. Still to run

`ptlmgmt` — the largest and messiest estate, which is where scale defects (table overflow,
render time, evidence truncation) are expected to appear. `tppoc` at 9 subscriptions took 27.9
minutes; that is the datapoint to extrapolate from.
