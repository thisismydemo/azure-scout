# R4 — Reference deliverable teardown

**Work item:** AB#6873 (Story) under Feature AB#6869
**Spike:** R4 of Epic AB#6450 (see [`pmo/plans/AB6450-reporting-module-rebuild.md`](../plans/AB6450-reporting-module-rebuild.md) §4)
**Sources:** the three deliverables attached to `AB#6443` — a governance report (`.docx`), an
executive readout (`.pptx`) and a gap inventory workbook (`.xlsx`).
**Method:** the OpenXML parts were read directly. Every count below is measured from the
package, not estimated.

> The reference set is client work. This teardown records **structure** — section order, table
> and figure placement, tab layout — and deliberately carries no client data. The files
> themselves are not committed to this repo.

---

## 1. Why this document exists

The plan's §2 finding is that 103 report work items closed green while the output stayed
unusable, because **not one had an acceptance criterion naming a deliverable, a section, or a
reader**. "Make the reports better" cannot be tested. A section-by-section inventory of a
document that *is* good can be.

This teardown is therefore the input to two things:

1. the quality bar (`docs/design/report-conformance.md`) and the conformance test that
   enforces it;
2. the per-assessment output contract, because the chapter shape below is the unit that gets
   repeated per assessment.

---

## 2. The Word report — measured structure

**5,643 paragraphs · 43 tables · 9 figures · 8 slide-independent styled heading levels.**

Package parts that matter, because their **absence** is the diagnosis of Scout's current
`Export-Word.ps1`:

| Part | Present | What it buys |
|---|---|---|
| `word/styles.xml` | ✅ | named styles → navigation pane, a real TOC, restyling to a client brand |
| `word/numbering.xml` | ✅ | numbered chapters and lists that renumber themselves |
| `word/header1.xml` | ✅ | running header |
| `word/footer1.xml` | ✅ | page numbers, classification |
| `word/theme/theme1.xml` | ✅ | one palette and type ramp the whole document inherits |
| `word/media/image1–9.png` | ✅ | 9 embedded raster figures |

Scout emits **none** of these. `Export-Word.ps1` hand-builds every run, never creates a
`StyleDefinitionsPart`, and has no header, footer, numbering or theme part at all. That is not
a styling shortfall, it is a different class of artefact.

### Section map

Measured; `Tables`/`Figures` are counted between one heading and the next.

| Section | Tables | Figures |
|---|--:|--:|
| *(front matter — cover, document control)* | 2 | — |
| Document Information | 1 | — |
| &nbsp;&nbsp;Table of Contents | — | — |
| **Executive Summary** | | |
| &nbsp;&nbsp;In-scope inventory | 2 | — |
| &nbsp;&nbsp;Findings Dashboard | 1 | — |
| &nbsp;&nbsp;Maturity Scoring Methodology | 1 | — |
| &nbsp;&nbsp;Key Risk Indicators | 1 | 2 |
| &nbsp;&nbsp;Initial 30-Days Plan — Consolidated Workstreams | 1 | 1 |
| &nbsp;&nbsp;Infrastructure Overview | 1 | 1 |
| Prioritised Focus Areas | 1 | — |
| **Chapter 1 — Azure Hierarchy & Organisation** | 1 | — |
| &nbsp;&nbsp;Current State | 3 | — |
| **Chapter 2 — Policy & Compliance** | 1 | — |
| &nbsp;&nbsp;Current State | 2 | 1 |
| **Chapter 3 — Identity & Access Management** | 1 | — |
| &nbsp;&nbsp;Current State | 2 | 1 |
| **Chapter 4 — Security Posture: Defender for Cloud** | 1 | — |
| &nbsp;&nbsp;Current State | 1 | 1 |
| **Chapter 5 — Network Security** | 1 | — |
| &nbsp;&nbsp;Current State | 1 | 1 |
| **Chapter 6 — Monitoring & Diagnostics** | 1 | — |
| &nbsp;&nbsp;Current State | 2 | 1 |
| **Chapter 7 — Resource Governance** | 1 | — |
| &nbsp;&nbsp;Current State | 3 | — |
| Overall Maturity Summary & 90-Day Roadmap | — | — |
| &nbsp;&nbsp;Maturity Summary | 1 | — |
| &nbsp;&nbsp;90-Day Remediation Roadmap | 3 | — |
| Appendix A — Subscription Detail *(one sub-section per environment)* | 3 | — |
| Appendix B — Service Principal Inventory *(3 sub-sections)* | 3 | — |
| Appendix C — Consolidated Gap Register | 1 | — |
| **Total** | **43** | **9** |

### The load-bearing observation

**Every chapter has the identical shape**, and it is a shape a renderer can emit:

```
Chapter N — <domain>
  └── 1 table at chapter level        ← the domain's scorecard: maturity, risk, why it matters
  └── Current State
        └── 1–3 tables                ← findings at resource grain
        └── 0–1 figure                ← the domain's one visual
```

Seven chapters, seven identical structures, differing only in domain and data. That is the
per-assessment unit. Scout's requirement in plan §5 — *one detailed report per assessment* —
is this chapter template instantiated per assessment, with the Executive Summary and the
Maturity Summary becoming the cross-assessment roll-up.

Note also what the front matter carries before any finding appears: a **cover**, a **Document
Information** table, and a **Table of Contents** — three parts, all of them absent from Scout's
output, and the first two are what make a document read as *for this client* rather than as a
tool's stdout.

And note the ordering: **Executive Summary and Prioritised Focus Areas come before Chapter 1.**
The conclusion is at the front. Scout currently orders by area, with no conclusion anywhere.

---

## 3. The deck — measured structure

**11 slides · 8 layouts · 7 media items.** No tables — every slide is shapes and text, which is
why it reads as a designed deck rather than a document that lost its margins.

| # | Slide | Role |
|--:|---|---|
| 1 | Azure Governance Assessment | title |
| 2 | Engagement Scope and Approach | what was and was not looked at |
| 3 | Executive Summary | the three-paragraph verdict |
| 4 | Section A — Cloud Foundation: Maturity Scorecard | scorecard tiles with band labels |
| 5 | Section B — Cybersecurity Posture | second scorecard |
| 6 | Key Risk Indicators | the numbers |
| 7 | Risk Heatmap | one figure, no text (2 runs) |
| 8 | Potentially Actively-Exploitable Item | **the one thing to act on this week** |
| 9 | Summary of Identified Gaps | the register, condensed |
| 10 | Assessment Remediation Roadmap | timeline figure (2 runs) |
| 11 | Assessment Remediation Roadmap | the roadmap detail (51 runs — the densest slide) |

Two slides (7 and 10) carry **2 text runs each**: they are a single full-bleed visual with a
title. That is a deliberate rhythm — dense slide, visual slide, dense slide — and it is the
opposite of Scout's current deck, which is uniform.

Slide 8 is the single highest-value slide in the set and has no equivalent anywhere in Scout:
one named, currently-exploitable item, isolated on its own slide.

---

## 4. The workbook — measured structure

**13 sheets.** One cover, twelve gap classes.

| Sheet | Class |
|---|---|
| `Cover` | scope, legend, contents index with per-tab record counts |
| `Deprecated_Policy_Assignments` | policy |
| `Deprecated_PolicySet_Entries` | policy |
| `Policy_Exemptions` | policy |
| `Owner_NonGroup` | identity |
| `UAA_NonGroup` | identity |
| `Orphaned_Role_Assignments` | identity |
| `Custom_Roles_Unused` | identity |
| `SP_Owner_All` | identity |
| `Storage_PublicNetwork` | data |
| `Storage_PublicBlob` | data |
| `Storage_TLS10` | data |
| `Group_Owner_at_MG` | identity |

The organising principle is **one tab per gap class**, not one tab per collector and not one
tab per severity. A gap class is "a specific thing that is wrong, with a name a reader
recognises" — which is what makes each tab actionable on its own.

The `Cover` tab carrying a **contents index with per-tab record counts** is the detail that
makes a 13-tab workbook navigable. Scout's Excel output has no cover.

---

## 5. What this converts to

Each row is a checklist item for the conformance test. The "Scout today" column is asserted
only where it was read from the code; anything depending on live output is deferred to the
Phase 0 baseline (plan §3), which has not yet been run.

| # | Requirement from the reference | Scout today |
|--:|---|---|
| 1 | Cover carrying client, scope, date, classification | ❌ absent |
| 2 | Document Information block with data provenance and scan date | ❌ absent |
| 3 | Real TOC **field** (links, updates) | ❌ plain paragraphs |
| 4 | Named Word styles (`StyleDefinitionsPart`) | ❌ absent — no nav pane, no rebranding |
| 5 | Running header | ❌ absent |
| 6 | Footer with page number and classification | ❌ absent |
| 7 | Numbering part for chapters and lists | ❌ absent |
| 8 | Theme part — one palette, one type ramp | ❌ absent; colours hardcoded per run |
| 9 | Conclusion before detail (exec summary at front) | ❌ ordered by area |
| 10 | Repeatable per-chapter template (scorecard → current state → findings → actions) | ❌ no chapter concept |
| 11 | 9 embedded figures | ❌ **0** — diagram pipeline emits `.drawio` only, no rasterisation (AB#6737) |
| 12 | Appendices carrying long tables so the body stays narrative | ❌ no appendix concept |
| 13 | Deck: 11 slides, one idea per slide, dense/visual rhythm | ⚠️ uniform, count not fixed |
| 14 | Deck: a single "actively exploitable" slide | ❌ absent |
| 15 | Workbook: cover with legend and per-tab record counts | ❌ absent |
| 16 | Workbook: one tab per gap class | ⚠️ v2 branch adds per-gap tabs; unmerged |
| 17 | Every risk row carries its supporting number | ⚠️ deferred to Phase 0 |
| 18 | Triage verdict per row (real / by-design / sandbox / legacy) | ⚠️ v2 branch adds; unmerged |
| 19 | Named resources on every finding | ⚠️ deferred to Phase 0 |
| 20 | GOOD rows alongside failures | ⚠️ deferred to Phase 0 |

Items 1–12 and 14–15 are **structural and verifiable offline** — they are properties of the
emitted package, so the conformance test can assert them without a tenant. That is the set
worth automating first, because it is also the set that is entirely absent today.

---

## 6. Rejected alternatives

- **Rebuild the reference documents by hand as a template.** Rejected: they are client
  deliverables and carry client data. The structure is the reusable part, and it is captured
  above.
- **Treat the PDF as the reference instead of the `.docx`.** Rejected: the PDF is a rendering,
  so it cannot show which structure came from styles and which from manual formatting — which
  is precisely the question R1 has to answer.
- **Infer the structure from the report's own table of contents.** Rejected: the TOC lists
  headings only. It would have missed the 43/9 table and figure placement, which is where the
  per-chapter template became visible.

---

## 7. What this spike does not answer

- Whether the template is produced as a `.dotx` or as an OpenXML `StyleDefinitionsPart` built
  in code — that is **R1**.
- Which tool draws the 9 figures — that is **R3**.
- Whether Scout's collected data can populate each table — that needs the **Phase 0** baseline
  against a real tenant, and no design decision below the structural level should be taken
  before it exists.
