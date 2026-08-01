# Azure Scout — Reporting Module Rebuild

**Epic:** AB#6450 — Enhance the reporting engine with new formats
**Status:** DRAFT — plan under construction, not approved
**Author:** drafted 2026-08-01

---

## 1. The requirement, in the owner's words

> *"Every report this solution produces is not worth putting in front of an executive or
> high-level IT architect. They are a joke. The formatting, the way the data is presented.
> The Power BI is a waste of my time. The diagrams are a joke. If I am doing an inventory and
> assessment together, and picked Landing Zone and another assessment, there should be
> detailed reports for each."*

Required formats: **Word · PowerPoint · PDF · HTML/React · Excel · Power BI (a real solution,
not CSV files)**. Diagrams must be enterprise-worthy — improve draw.io or replace it.

The bar is the BECU engagement set attached to **AB#6443**: a 40-page governance report
(43 tables, 9 figures), an 11-slide executive readout, and a 13-tab gap workbook.

## 2. Why this failed before — read this before planning anything

**103 report work items on this board are Closed.** `AB#5044` "Rebuild reporting into a tiered
renderer engine". `AB#333` Word. `AB#334` PDF. `AB#329` Power BI. `AB#6458` is literally titled
*"Build consultant-grade governance assessment report generator"* and is marked **Resolved**.

Every one of them was accepted on **"a file came out"**. Not one has an acceptance criterion
naming an example deliverable, a required section, or a reader. There has never been a quality
bar on this project, so 103 tickets closed green while the output stayed unusable.

**Any plan that does not fix that fixes nothing.** Whatever is built here must be verifiable
against a written bar, and the epic is not done until a generated document sits next to the
BECU original and holds up.

### The concrete formatting diagnosis

Not opinion — this is what the code does today:

- `Export-Word.ps1` builds every run by hand and **never creates a `StyleDefinitionsPart`**.
  There are no Word styles, so there is no navigation pane, no TOC field, no
  cross-references, and nothing a client can restyle to their brand. Fonts and colours are
  hardcoded per run.
- **No headers, footers, page numbers, or cover graphics** in any document.
- The "table of contents" is a list of plain paragraphs, not a field. It does not link and
  does not update.
- `Export-PowerBi.ps1` emits **four flat CSVs and a generated `.pbit`** with no measures, no
  relationships beyond one text key, no hierarchy, no report pages. Opening it gives you a
  blank canvas and some tables — which is exactly why it wastes the owner's time.
- The diagram pipeline emits `.drawio` XML only, with **no rasterisation path at all**
  (AB#6737), so no document can embed a diagram even when one was generated.
- Every renderer is a bespoke hand-rolled emitter. There is no template, no theme, no brand
  asset, and no shared layout system.

## 3. Ground truth first — before any code

**Nothing in this plan may be designed against imagination.** The current output has never
been examined at scale, and the samples reviewed so far were synthetic.

**Phase 0 — collect real data and render what exists today.** The HCS MCP gives access to
eight tenants with Azure subscriptions:

| shortName | Tenant | Why it is useful |
|---|---|---|
| `hcs` | This Is My Demo / hybridsolutions.cloud | Owner's primary; the named target tenant |
| `ptlmgmt` | TierPoint Lab Management | Active migration target — messy, realistic |
| `tpdemos` | TierPoint Demos | Demo estate, broad service spread |
| `tplabs` | TierPoint Product Labs | Lab estate |
| `phx` | Project Phoenix | Security-focused RG layout |
| `tppoc` | TierPoint PoC | Small estate — tests the thin-data path |
| `azlmgmt` | Azure Local Management | Azure Local / hybrid coverage |
| `tl` | Turner Legacy | Smallest — the degenerate case |

Run **inventory + assessment together** on at least three of these with contrasting size and
shape, produce **every** current output format, and file them in `pmo/research/baseline/`
with a written critique of each artefact against the BECU bar. That critique is the input to
every design decision below — and it is also the first honest measurement this project has
ever taken of its own output.

Token/time cost is real; a large tenant run is not free. Sequence: `tppoc` (smallest, proves
the pipeline) → `hcs` (the target) → `ptlmgmt` (largest, finds the scale defects).

## 4. Research spikes — `pmo/research/`

Each spike is timeboxed, produces a recommendation with a rejected-alternatives section, and
lands as a decision record in `docs/design/decisions/` the way `decisions/pptx-renderer.md`
already did.

### R1 — Document generation: template-driven vs hand-built

Current code hand-assembles OpenXML. The professional route is a **branded `.dotx`/`.potx`
template** carrying real styles, cover page, headers/footers and numbering, which the renderer
populates — the same way every consultancy produces deliverables.

Evaluate: [PSWriteWord](https://github.com/EvotecIT/PSWriteWord) (DocX/Xceed wrapper) ·
[PSWriteOffice](https://evotec.xyz) · raw OpenXML **with** a `StyleDefinitionsPart` and a
template · Word COM (rejected on sight — no CI, Windows-only).
Reference: [styling Word from PowerShell](https://petri.com/format-microsoft-word-docs-powershell/).

Decide: does Scout ship a template that a partner can rebrand? (Strong yes, on the evidence of
every deliverable in the BECU set.)

### R2 — Power BI: a real semantic model, not CSVs

The answer is **PBIP + TMDL**, not `.pbit` over flat CSVs.
[PBIP](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) stores
the semantic model and report pages as plain text;
[TMDL](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-tmdl-view) is a
human-editable folder format, and the
[Tabular Object Model](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)
can generate and serialise it programmatically from PowerShell via
`Microsoft.AnalysisServices.Tabular`.

Target: a **shipped, version-controlled Power BI project** — star schema with real
relationships, DAX measures (compliance %, maturity by domain, cost by tag, resources by
subscription), a date dimension, and **authored report pages** — that Scout refreshes with a
run's data. Not a blank canvas the user has to build themselves.

### R3 — Diagrams

draw.io XML generation is the current approach and it produces poor output. Evaluate:

- **[AzViz](https://github.com/PrateekKumarSingh/AzViz)** — PowerShell module, auto-detects
  resource dependencies (NIC → subnet → VNet), inserts real Azure icons, themes, SVG/PNG out.
  Requires Graphviz. Purpose-built for exactly this, and it is the tool the owner half-remembered.
  ([docs](https://azviz.readthedocs.io/en/latest/) ·
  [walkthrough](https://blog.darrenjrobinson.com/generate-azure-resource-diagrams-using-powershell/))
- **[D2](https://d2lang.com)** — TALA auto-layout, the best-looking architecture output of the
  diagram-as-code tools ([comparison](https://diagrams.so/learn/diagram-as-code-comparison)).
- **Mermaid** — weakest layout, but renders natively in HTML/React and Markdown for free.
- **Graphviz direct** — what AzViz wraps; full control, more work.
- **Structurizr / C4** — right if we want context→container→component views from one model.

Likely outcome: **AzViz or Graphviz for topology, D2 for architecture and flow, Mermaid for
the HTML/React surface**, all rasterised to PNG for Word/PPTX/PDF embedding. That
rasterisation step is `AB#6737`, still open, and it blocks every document.

Also evaluate [AzGovViz](https://github.com/JulianHayward/Azure-MG-Sub-Governance-Reporting)
properly — it is what the BECU report was built from, `AB#6448` only evaluated its
*methodology*, and its hierarchy/tenant-summary visuals are the specific thing the reference
report's figures are.

### R4 — Reference deliverable teardown

Take the BECU Word/PPTX/XLSX apart section by section and write down, per section: the data it
needs, whether Scout can supply it today, and what it would take. This converts "make it
better" into a checklist. Partially done in `docs/design/reporting-engine-v2.md` §2 — finish it.

## 5. One report per assessment — the structural change

Today a run produces **one** `assessment_report.docx` regardless of what was assessed. The
owner's requirement: inventory + Landing Zone + a second assessment must produce **detailed
reports for each**.

This is a change to the run's output contract, not a renderer tweak:

```
<run>/
  inventory/           AzureScout_Report.xlsx, PowerBI project, diagrams
  assessments/
    landing-zone/      report.docx  deck.pptx  report.pdf  evidence.xlsx  report.html
    cloud-governance/  report.docx  deck.pptx  report.pdf  evidence.xlsx  report.html
  executive/           one cross-assessment roll-up deck + PDF
  report-model.json
```

`Invoke-ScoutAssessmentCore.ps1` currently scores every selected assessment into **one**
`$allFindings` collection and renders once. It must loop per assessment, and a roll-up must
sit above them. That roll-up — "here is your estate, here is how it scored across three
frameworks" — is the artefact an executive actually wants and Scout has never produced.

## 6. Brain dump — what makes the BECU documents good

Unstructured on purpose. Harvest into the design once the Phase 0 critique exists.

**Structure**
- Cover carrying client, project, tenant, scope, date, classification — it reads as *for them*.
- Document Information block: version, author, distribution list, frameworks referenced,
  **source data provenance and scan date**. Establishes that the numbers are auditable.
- Real TOC. 14 numbered sections. Chapters, not "sections of a tool's output".
- Every chapter: *Why this matters* → *Current state* → *findings table* → *action items*.
  The "why this matters" paragraph is what makes it readable by a non-specialist.
- Appendices carry the long tables so the body stays narrative.

**Data presentation**
- Stat tiles for estate size — the reader gets scale in two seconds.
- Every risk row carries **its supporting number**. "60 of 198 storage accounts", never
  "storage accounts are misconfigured".
- Named resources. A finding that cannot be actioned is decoration.
- A **triage verdict per row** — real / by-design / sandbox / legacy. This is what turns 149
  raw findings into "141 deliberate, 8 real" and is the single highest-value column in the
  whole workbook.
- GOOD rows alongside failures. An all-negative report gets discounted wholesale.
- Severity **and** blast radius, separately.
- Owner and effort on every action, so it can be assigned rather than admired.

**Narrative**
- The sentences that carry weight are **comparative or aggregate** — "the highest of the
  seven", "driven by hygiene, not architecture", "the four-point gap". These are properties of
  the whole run and cannot come from a per-rule template.
- Three-paragraph executive summary with named leads: what is sound / what drags it down /
  how to read the score.
- Never assert what was not measured. "Not assessed" is a first-class state, never a zero.

**Visual**
- 9 figures. Risk heatmap, MG hierarchy, maturity radar, current-vs-target, inventory
  composition, Defender coverage grid, network exposure heatmap.
- A consistent palette and one type ramp across Word, PPTX and PDF.
- Page numbers, running headers, classification in the footer.

**Deck**
- 11 slides, not 40. Numbered takeaways. One slide per idea.
- Scorecard tiles with band labels. Effort key spelled out. Roadmap as a timeline.
- A single "actively exploitable" slide — the one thing to act on this week.

**Workbook**
- Cover with scope, legend and a contents index with per-tab record counts.
- One tab per gap class. Full ARM IDs. Freeze panes, autofilter, conditional formatting.

## 7. Work items to create

The epic currently has two empty parents and one story. It needs a real structure — and, per
the owner, **AzViz/AzGovViz evaluation should have been a work item from the start**.

Under **AB#6449**, as Features with Stories beneath:

1. **Baseline and critique** — Phase 0 runs across three tenants; written critique per artefact.
2. **Research spikes R1–R4** — one Story each, each landing a decision record. *Includes the
   AzViz / AzGovViz / D2 diagram evaluation that was never raised.*
3. **Report identity and template system** — branded template, styles, headers/footers,
   palette, type ramp, shared across Word/PPTX/PDF.
4. **Per-assessment report output contract** — the folder structure in §5 plus the roll-up.
5. **Diagram engine replacement** — including `AB#6737` (rasterisation) and `AB#379`
   (html2canvas), both already open and both blocking.
6. **Power BI project** — PBIP/TMDL semantic model with measures and authored pages.
7. **Quality bar and conformance test** — `pmo/plans` bar → `docs/design/report-conformance.md`
   → `tests/Report.Conformance.Tests.ps1`. **Definition of done for every item above.**

Backfill descriptions and acceptance criteria onto **AB#6450** and **AB#6449** — they are the
only two report items on the entire board with no description, which is how this drifted.

## 8. What already exists and should be reused, not rebuilt

From the unmerged branch `feat/ab6450-reporting-v2` (8 commits, 405 tests green):

- `src/report/Build-ScoutReportModel.ps1` — one derived model all renderers consume.
- `src/report/Build-ScoutNarrative.ps1` — comparative-fact narrative composition.
- Gap register, evidence at resource grain, triage verdicts, roadmap phases.

**This is scaffolding, not the deliverable.** It fixes *what the documents say*; it does
nothing about *how they look*, the diagrams, Power BI, or per-assessment reports — which is
most of the owner's complaint. Keep it if the Phase 0 critique supports it; drop it without
sentiment if not.

## 9. Non-goals

- **Rule authoring.** Scout has 395 rules, 229 of them `manual: true`. Report depth is capped
  by assessment depth, and that belongs to Epic AB#6454. Say so rather than be judged against
  a bar the inputs cannot reach.
- **Tenant mutation.** Scout stays read-only.
- **A hosted service.** Files on disk, offline-capable.

## 10. Verification

1. Reports generated from **real tenant data**, not fixtures.
2. Every artefact opened and read next to its BECU counterpart.
3. Conformance test green.
4. The set sent to the owner for judgement — the only acceptance test that has ever mattered
   here.

---

### Sources

- [AzViz](https://github.com/PrateekKumarSingh/AzViz) · [AzViz docs](https://azviz.readthedocs.io/en/latest/) · [walkthrough](https://blog.darrenjrobinson.com/generate-azure-resource-diagrams-using-powershell/) · [AzViz & AzGovViz field notes](https://www.ddhaliwal.me/field-notes/04-visualizing-azure-topology/)
- [Power BI Desktop projects (PBIP)](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) · [TMDL view](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-tmdl-view) · [semantic model folder / TOM](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) · [deploying TMDL from PowerShell](https://richardswinbank.net/pbi/deploy_tmdl_semantic_models_to_power_bi)
- [Diagram-as-code comparison](https://diagrams.so/learn/diagram-as-code-comparison) · [best diagram-as-code tools 2026](https://infrasketch.net/blog/best-diagram-as-code-tools-2026)
- [PSWriteWord](https://github.com/EvotecIT/PSWriteWord) · [styling Word documents with PowerShell](https://petri.com/format-microsoft-word-docs-powershell/)
