---
description: Decision record R1 — how Scout generates Word documents. Hand-built OpenXML with a real styles part, not a template library.
---

# Decision record R1 — document generation

> **Status:** Accepted 2026-08-02, retroactively. The choice was made in code first and written
> down after, which is the wrong order; this record exists so the next person does not re-litigate
> it from scratch.
>
> **Epic:** AB#6450 · **Feature:** AB#6874/AB#6875 · **Author:** Claude Code

## 1. Decision

**Keep hand-built OpenXML. Add the parts that were missing, rather than adopt a template library
or a `.dotx`.**

The plan proposed evaluating PSWriteWord, PSWriteOffice, a branded `.dotx` the renderer populates,
and raw OpenXML. Raw OpenXML wins — but only because the thing that was actually broken was never
the assembly method.

## 2. Why

The diagnosis in the plan said the renderer "hand-assembles OpenXML" as though that were the
defect. It was not. Phase 0 measured the real defect: the emitted `.docx` contained **three
package parts** — `_rels/.rels`, `[Content_Types].xml`, `word/document.xml` — and **0 of 1,803
paragraphs carried a `pStyle`**.

That single absence explains every symptom at once. No styles means no navigation pane, no
possible TOC field (a TOC collects heading *styles*, and there were none), no cross-references,
and nothing a partner can restyle. A template library would have supplied those parts as a side
effect, which is why swapping the library *looks* like the fix — but the fix is the parts, and the
parts are about 400 lines of well-commented code.

Against that, each alternative costs something real:

| Option | Cost |
|---|---|
| **PSWriteWord / PSWriteOffice** | A third-party dependency on the critical path of a deliverable, for a wrapper over the same SDK. Scout already pins `DocumentFormat.OpenXml` and acquires it once into a cache; adding a second layer buys nothing it does not already have. |
| **A branded `.dotx` the renderer populates** | Genuinely attractive, and the right answer *if* a designer authors the template. Without one, the template becomes a binary asset in the repo that nobody can diff, review, or explain — and the styles inside it would be hand-authored anyway. It also makes per-assessment restyling a binary edit. |
| **Word COM** | Rejected on sight. Windows-only, needs Word installed, no CI. |

## 3. What this commits us to

The document's identity lives in `Add-ScoutDocxStyleDefinitions` and `Add-ScoutDocxThemePart`, in
code, in git. Rebranding is swapping a `clrScheme` and a font scheme — a reviewable diff rather
than a binary swap. The conformance test asserts that **no run in the body carries a hex absent
from the theme**, which is what keeps that promise honest: adding a colour to a renderer without
adding it to the theme fails the build.

## 4. Reconsider this if

A designer produces a real branded template, or a partner needs to ship their own. At that point
the `.dotx` route becomes correct, and the styles part built here is the specification for what
that template must declare.

## 5. Sources

- [PSWriteWord](https://github.com/EvotecIT/PSWriteWord) · [styling Word from PowerShell](https://petri.com/format-microsoft-word-docs-powershell/)
- ECMA-376 Part 1, §17.3 (`CT_PPrBase` / `CT_RPr` child ordering) — the ordering rules that cost
  the most time here and are commented at every site that depends on them.
