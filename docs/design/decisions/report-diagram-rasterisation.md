---
description: Decision record R3 — how Scout produces figures. A managed PNG rasteriser, not AzViz, Graphviz, D2, or a headless browser.
---

# Decision record R3 — diagrams and figures

> **Status:** Accepted 2026-08-02. Resolves `AB#6737`, open since the diagram pipeline shipped.
>
> **Epic:** AB#6450 · **Feature:** AB#6885 · **Author:** Claude Code

## 1. Decision

**Rasterise figures in managed code, with no external binary. Reject AzViz, Graphviz, D2,
Mermaid-via-browser and ImageMagick for the document pipeline.**

## 2. The problem this had to solve

The diagram pipeline emitted `.drawio` XML and nothing else. Phase 0 measured the consequence:
**0 image parts in every report across three tenants.** No document could embed a figure even when
one had been generated, and `Export-Pdf` shipped a 700-character warning telling the reader to
open draw.io, export a JPEG by hand, and re-render.

## 3. Why every dependency-based option was rejected

The plan expected AzViz or D2. Both were rejected on the same test, and it is the test that
matters more than the verdict:

> Scout is installed from the PowerShell Gallery and run on a laptop. **A report that silently
> loses its figures because a native binary is missing is worse than one that never promised
> them** — the reader cannot tell the difference between "there is nothing to show" and "this
> machine could not draw it".

| Option | Requires | Verdict |
|---|---|---|
| **AzViz** | Graphviz on `PATH` | Purpose-built for Azure topology and genuinely good. Not installed on the authoring machine, not installed on CI, and not something a module can install for a user. |
| **D2** | The `d2` binary | Best-looking output of the diagram-as-code tools. Same objection. |
| **draw.io export** | A headless browser | Bundling Chromium into a PowerShell module is not proportionate to three charts. |
| **ImageMagick** | Native install | Same objection, plus a supply-chain surface for a rasteriser. |
| **`System.Drawing`** | Nothing — but | `System.Drawing.Common` is **Windows-only from .NET 6**. Scout runs wherever PowerShell 7 does. |

Confirmed empirically rather than assumed: neither `dot` nor `d2` is on `PATH` on the machine this
was built on — which is precisely the situation a user will be in.

## 4. What was built instead

A PNG is a zlib stream of filtered scanlines wrapped in four chunks.
`System.IO.Compression.DeflateStream` ships in the base class library and produces the raw deflate,
so only the two-byte zlib header, the Adler-32 and the CRC-32 have to be written by hand. That is
the entire trick, and it is why `src/report/Build-ScoutFigure.ps1` has no `Add-Type`, no P/Invoke
and no `dotnet` acquire.

Text comes from a 5×7 bitmap font defined in the file. That is a deliberate ceiling: a figure
label is a word or a number, and a renderer that needed real typography would need a font file,
which is a dependency again.

## 5. What this does NOT do

**This is not a topology diagram engine.** It draws the three figures the assessment report argues
with — alignment by area, status composition, severity heatmap. It does not draw NIC → subnet →
VNet dependency graphs, and it should not grow into something that does. The `.drawio` output
stays for that job.

If enterprise topology diagrams become a requirement, that is a separate decision, and AzViz
becomes the right answer *provided* the Graphviz dependency is made explicit and optional — a
documented prerequisite that degrades to "topology diagram not generated" rather than a silent
gap.

## 6. Sources

- [PNG specification, §5 (datastream) and §12 (filtering)](https://www.w3.org/TR/png/)
- [AzViz](https://github.com/PrateekKumarSingh/AzViz) · [D2](https://d2lang.com)
- [`System.Drawing.Common` is Windows-only](https://learn.microsoft.com/dotnet/core/compatibility/core-libraries/6.0/system-drawing-common-windows-only)
