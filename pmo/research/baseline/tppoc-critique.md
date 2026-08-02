# Phase 0 baseline — `tppoc`, critique against the conformance bar

**Work item:** AB#6866 (Story) under Feature AB#6865
**Run:** 2026-08-02, tenant `tppoc` (`2e21f99f…`), **9 subscriptions**, 27.9 minutes
**Command:** `Invoke-AzureScout -InventoryAndAssessment -Assessment 'LandingZone','Assess: Cloud Governance' -OutputFormat All`
**Bar:** [`docs/design/report-conformance.md`](../../../docs/design/report-conformance.md)

> This is the first time this project has measured its own output against a written standard.
> Every number below was read out of the emitted package, not estimated.

---

## 0. The estate it ran against

Not a toy. A real platform/workload landing zone: `platform-connectivity`, `platform-identity`,
`platform-management`, `platform-security`, `platform-devops`, `lz-corp`, `lz-workloads`, plus two
Azure Local subscriptions. **303 findings** were produced — 285 from LandingZone, 18 from Cloud
Governance.

So the thin-data excuse does not apply. This is what the product does with a genuine estate.

---

## 1. The headline: two assessments in, one report out

`R-01` is the owner's stated requirement and it **fails outright**.

Two assessments were selected. `findings.json` correctly carries both. The run then emitted:

```
20260802_130540/
  assessment_report.docx      ← ONE
  assessment_deck.pptx        ← ONE
  assessment_report.pdf       ← ONE
  assessment_evidence.xlsx    ← ONE
  report.html / report-react.html / assessment_dashboard.html
  powerbi/report.pbit
```

There is no `assessments/landing-zone/`, no `assessments/cloud-governance/`, no `executive/`
roll-up. `R-01`, `R-02`, `R-03` all **FAIL**. This is exactly the defect §5 of the plan predicted
from reading the code, now confirmed on real data.

## 2. Scale, against the reference

| Artefact | Scout (tppoc, 303 findings) | Reference | Ratio |
|---|--:|--:|--:|
| Word report | **26 KB** | 1,295 KB | **1/50** |
| Deck | **23 KB** | 292 KB | **1/13** |
| Workbook | 84 KB | 76 KB | ~1 |
| Power BI | **4.7 KB `.pbit`** | — | — |

The workbook is the only artefact in the same league, and §5 below shows why that is misleading.

## 3. Word — `assessment_report.docx`

**The package contains three parts.** That is the whole document:

```
_rels/.rels
[Content_Types].xml
word/document.xml
```

The reference carries `styles.xml`, `numbering.xml`, `header1.xml`, `footer1.xml`,
`theme/theme1.xml`, `fontTable.xml`, `settings.xml`, and nine `media/image*.png`. Scout emits
**none of them**.

Measured: **1,803 paragraphs · 36 tables · 0 drawings · 0 styled paragraphs.**

That last number is the one that matters. **Not a single paragraph carries a `pStyle`.** Every
heading in the document is direct run formatting, so Word has no idea any of it is a heading.
Consequences, all verified rather than inferred:

- no navigation pane
- no TOC field is even possible — there are no heading styles for it to collect
- no cross-references
- nothing a client can restyle to their brand
- no header, no footer, **no page numbers**

| Clause | Verdict | Evidence |
|---|---|---|
| `W-01` StyleDefinitionsPart | **FAIL** | part absent |
| `W-02` headings carry `pStyle` | **FAIL** | 0 of 1,803 paragraphs styled |
| `W-03` header part | **FAIL** | absent |
| `W-04` footer with PAGE field | **FAIL** | absent |
| `W-05` real TOC field | **FAIL** | impossible without W-01/W-02 |
| `W-06` numbering part | **FAIL** | absent |
| `W-07` theme part | **FAIL** | absent |
| `W-08` cover | **FAIL** | no cover page |
| `W-09` Document Information / provenance | **FAIL** | absent — nothing states the tenant or scan date |
| `W-12` figures embedded | **FAIL** | **0 drawings** against the reference's 9 |

36 tables is not far off the reference's 43. **The data is largely there; the document is not.**
That is the single most useful finding in this critique — the gap is presentation and structure,
not collection.

## 4. Deck — `assessment_deck.pptx`

10 slides, **2 layouts, 0 media**.

| # | Slide | Note |
|--:|---|---|
| 1 | AZURE SCOUT | product name, not the client's |
| 2 | Executive Summary | |
| 3–6 | **Area Score Breakdown (1/4) … (4/4)** | one idea spread over four slides |
| 7–8 | Prioritized Gaps (Top 15) — 1/2, 2/2 | pagination, again |
| 9 | Manual Review Worklist | |
| 10 | Recommended Next Steps | |

Six of ten slides are **pagination of two ideas**. The reference's rule is one idea per slide with
a deliberate dense/visual rhythm; this is a table that overflowed and kept going. With `0 media`
there is not one figure in the deck — no heatmap, no scorecard tiles, no roadmap timeline.

`P-01` FAIL (2 layouts, no real master usage) · `P-02` FAIL (titled with the tool's name, not the
client, scope or date) · `P-03` FAIL (no scope slide) · `P-04` **FAIL — no "act on this first"
slide**, the highest-value slide in the reference set · `P-05` FAIL (10 slides, but by pagination).

## 5. Workbook — `assessment_evidence.xlsx`

39 sheets — **35 visible, 4 hidden**.

> **CORRECTION, 2026-08-02.** An earlier revision of this section claimed *"eight internal
> `_dash_src_*` scaffolding sheets are leaked to the user"* and that a consultant would have to
> delete them before sending the file. **That was wrong on both counts.** There are **four**, and
> **all four are hidden** — `Export-Excel.ps1` already passes `HideSheet` when it builds each
> pivot. Hidden pivot-source sheets are normal practice and are not a defect.
>
> The error came from reading the sheet list out of `xl/workbook.xml` without checking each
> sheet's `state` attribute — a hidden sheet is still listed there. `AB#6891` was raised on this
> mistake and is closed as not-a-defect. The other finding in this section, `AB#6890`, was
> re-verified against `state` and **is** real: those tabs are genuinely visible.

The visible tabs are **one per assessment area** — `AI_governance___security`, `AVD_workload__Azure_Local_`,
`Azure_VMware_Solution_Landing_Z`, `IoT_security` … Two problems:

1. They are named for the **rule area**, not the gap. `X-02` requires one tab per *gap class*,
   named for the thing that is wrong. `Integration_connectivity___reli` is a truncated slug, not a
   finding a reader recognises.
2. **Tabs exist for assessments that were never selected.** AVS Landing Zone, AVD workload and IoT
   are all present in a run of LandingZone + Cloud Governance. That is rule-glob leakage into the
   report surface, and it invites the reader to think those areas were assessed.

No `Cover` sheet, so `X-01` **FAILS** — no scope, no legend, no contents index with per-tab record
counts. In a 39-tab workbook that is the difference between navigable and unusable.

## 6. Power BI — the blank canvas, quantified

`report.pbit` is **4,689 bytes**. Inside:

| Part | Bytes |
|---|--:|
| `DataModelSchema` | 18,962 |
| **`Report/Layout`** | **2,190** |
| `DiagramState` | 678 |

`Report/Layout` is the authored report. **2,190 bytes is an empty canvas** — there are no pages
to speak of. Alongside it sit **70 flat CSVs** and a `README.txt` telling the user what to do next.

`B-01` FAIL · `B-03` FAIL (no measures) · `B-05` **FAIL**. This is precisely why the owner called
it a waste of time, and the number makes it undeniable.

## 7. Diagrams

One `AzureScout_Diagram_….drawio` (106 KB) plus three `DiagramCache/*.xml`. **No raster output of
any kind.** `D-01` FAIL, and it cascades: the Word document's 0 drawings is a direct consequence.
Nothing can embed a diagram because nothing ever produces an embeddable one. `AB#6737`.

## 8. Scorecard

| Group | Pass | Fail |
|---|--:|--:|
| Word (W-01…W-13) | 0 | 10 measured |
| Deck (P-01…P-05) | 0 | 5 |
| Workbook (X-01…X-05) | — | X-01, X-02 fail |
| Diagrams (D-01…D-03) | 0 | 3 |
| Power BI (B-01…B-05) | 0 | 4 measured |
| Run contract (R-01…R-03) | 0 | 3 |

**Zero automatic clauses pass.** Not one.

## 9. What this changes about the plan

1. **The data is not the problem.** 36 tables and 303 findings from a real estate says collection
   is broadly doing its job. Every failure above is structure, presentation, or output contract.
   Fixing the renderers does not require fixing the collectors first.
2. **`W-01`/`W-02` are the keystone.** Styles unlock the navigation pane, the TOC, numbering and
   rebranding in one move. Feature AB#6874 should go first.
3. **`R-01` is independent of all of it** and is the owner's stated ask. AB#6878 can proceed in
   parallel — it is a change to the run loop, not to any renderer.
4. **The deck needs authored slides, not paginated tables.** "Area Score Breakdown (3/4)" is the
   clearest symptom that the deck is a data dump with slide breaks.
5. **New finding, not in the plan:** rule-glob leakage puts unselected assessments into the
   workbook, and internal `_dash_src_*` sheets ship to the user. Neither was known before this run.
   Both need work items.

## 10. Method note

The `tppoc` service principal initially reported **0 subscriptions**. That was not a permissions
problem: Az.Accounts 5.5.0 declares `-AccessToken` as `[String]`, and passing a `SecureString`
stringifies to `System.Security.SecureString`, after which Az reports *"The access token is
invalid"* — which reads exactly like a bad token. The token was verified good against ARM REST
first, then the call shape corrected. Worth knowing before the `hcs` and `ptlmgmt` runs.
