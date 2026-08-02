# Report conformance — the quality bar

**Status:** normative. This document is the **definition of done** for every item under Epic
AB#6450.
**Work item:** Feature AB#6887; the test is Story AB#6888.
**Enforced by:** `tests/Report.Conformance.Tests.ps1` (not yet written — Story AB#6888).
**Derived from:** `pmo/research/R4-reference-deliverable-teardown.md` in the repository. Not
linked: `/pmo` holds internal programme records and is deliberately not published to this site,
so a relative link out of `docs/` is a dead link at build time.

---

## Why this exists

103 report work items on this board are Closed. `AB#5044` "Rebuild reporting into a tiered
renderer engine". `AB#333` Word. `AB#334` PDF. `AB#329` Power BI. `AB#6458`
"Build consultant-grade governance assessment report generator" is marked Resolved.

Every one of them was accepted on **"a file came out."** Not one had an acceptance criterion
naming an example deliverable, a required section, or a reader. There had never been a quality
bar on this project, so 103 tickets closed green while the output stayed unusable.

**A renderer work item may not be closed on the existence of a file.** It closes when the
clauses below that apply to it pass, and the conformance test is what says so.

---

## How to read this

Each clause has an id, a statement, and a **verification** that is either `automatic`
(asserted by the conformance test against an emitted package) or `judged` (needs a human
reading the artefact next to the reference).

`automatic` clauses are the ones worth arguing about, because they are the ones that cannot
be closed by opinion. Most of them are properties of the **package**, so they need no tenant
and no live data — the test emits a report from a fixture and reads the OpenXML back.

---

## W — Word document

| Id | Clause | Verification |
|---|---|---|
| `W-01` | The package contains a `StyleDefinitionsPart` declaring named styles for Title, Heading 1–3, Normal, Caption and a table style. | automatic |
| `W-02` | Every heading paragraph carries a `pStyle` referencing a declared style. No heading is formatted by direct run properties. | automatic |
| `W-03` | The package contains a header part, and it is referenced by the section properties. | automatic |
| `W-04` | The package contains a footer part containing a `PAGE` field. | automatic |
| `W-05` | The document contains a real TOC **field** (`TOC \o`), not a list of paragraphs. | automatic |
| `W-06` | The package contains a numbering part, and chapter headings reference it. | automatic |
| `W-07` | The package contains a theme part. No run in the body hardcodes a hex colour that is absent from the theme. | automatic |
| `W-08` | The first page is a cover carrying: client/tenant name, assessment name, scan date, and classification. | automatic |
| `W-09` | A Document Information block follows the cover, carrying version, author, frameworks referenced, **source data provenance and scan date**. | automatic |
| `W-10` | An Executive Summary precedes the first finding chapter. Conclusion before detail. | automatic |
| `W-11` | Each assessment domain is emitted as a chapter with the shape: chapter-level scorecard table → Current State → findings table(s) → action items. | automatic |
| `W-12` | Every figure referenced in the body is an embedded image part. A figure that failed to render is omitted with a caption saying so — never a broken reference. | automatic |
| `W-13` | Long tables (> 30 rows) are emitted to an appendix, not the body. | automatic |
| `W-14` | Every findings-table row carries its supporting number and at least one named resource. | judged |
| `W-15` | Passing controls appear alongside failures. An all-negative report is non-conformant. | judged |
| `W-16` | Narrative sentences are comparative or aggregate — properties of the whole run, not per-rule templates. | judged |
| `W-17` | Nothing that was not measured is asserted. "Not assessed" is a first-class state and is never rendered as a zero or a pass. | automatic |

## P — PowerPoint deck

| Id | Clause | Verification |
|---|---|---|
| `P-01` | The deck uses slide layouts from a master. No slide is built purely from free-floating shapes. | automatic |
| `P-02` | Slide 1 is a title slide carrying client/tenant, assessment name and date. | automatic |
| `P-03` | The deck contains a scope slide stating what was **not** assessed. | automatic |
| `P-04` | The deck contains exactly one "act on this first" slide naming a specific item. | automatic |
| `P-05` | Deck length is bounded — a roll-up deck is ≤ 15 slides. One idea per slide. | automatic |
| `P-06` | Scorecard tiles carry a band label, not a bare number. | judged |

## X — Excel workbook

| Id | Clause | Verification |
|---|---|---|
| `X-01` | Sheet 1 is a Cover carrying scope, a legend, and a contents index listing every other tab **with its record count**. | automatic |
| `X-02` | One tab per gap class, named for the gap, not for the collector. | automatic |
| `X-03` | Every data tab has frozen panes and an autofilter on the header row. | automatic |
| `X-04` | Every evidence row carries the full ARM resource id. | automatic |
| `X-05` | Every gap row carries a triage verdict (real / by-design / sandbox / legacy). | automatic |

## D — Diagrams

| Id | Clause | Verification |
|---|---|---|
| `D-01` | Every generated diagram is rasterised to PNG alongside its source form. | automatic |
| `D-02` | A diagram that fails to render is reported as a warning and omitted — never emitted broken or empty. | automatic |
| `D-03` | Diagrams embedded in Word/PPTX/PDF are the rasterised output, not a link. | automatic |

## B — Power BI

| Id | Clause | Verification |
|---|---|---|
| `B-01` | The output is a PBIP project (semantic model + report, as text), not a `.pbit` over flat CSVs. | automatic |
| `B-02` | The model declares relationships between fact and dimension tables. A single text key is non-conformant. | automatic |
| `B-03` | The model declares DAX measures. A model with zero measures is non-conformant. | automatic |
| `B-04` | The model declares a date dimension. | automatic |
| `B-05` | The project contains **authored report pages**. Opening it must not present a blank canvas. | automatic |

## R — Run output contract

| Id | Clause | Verification |
|---|---|---|
| `R-01` | A run that selects N assessments produces N per-assessment report sets, not one merged document. | automatic |
| `R-02` | Inventory output is emitted under `inventory/`, per-assessment output under `assessments/<name>/`. | automatic |
| `R-03` | A run of more than one assessment additionally produces a cross-assessment roll-up under `executive/`. | automatic |
| `R-04` | Every renderer consumes the same derived report model. No renderer re-derives findings. | automatic |

---

## Scope note — what the bar does not cover

Report depth is capped by assessment depth. Scout has 395 rules, 225 of them `manual: true`,
and rule authoring belongs to Epic AB#6454, not here. A conformant report that says
"not assessed" for a manual control **is conformant** — clause `W-17` requires exactly that.
This bar governs whether the artefact is fit to put in front of an executive, not whether the
assessment behind it is deep.

---

## Changing this document

A clause may be removed or weakened only with a recorded reason on the epic. Adding a clause
needs no ceremony. If a renderer cannot meet a clause, that is a finding about the renderer —
the bar does not move to meet the implementation, because that is precisely the failure this
document exists to prevent.
