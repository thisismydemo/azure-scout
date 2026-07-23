---
description: Decision record — executive-deck (PPTX) renderer for the Report layer's Tier 3 output. Resolves the open item flagged in master-plan.md §9a.
---

# Decision record — PPTX executive-deck renderer

> **Status:** Accepted 2026-07-22. The repo owner deferred the library choice
> to this record and stated the acceptance criterion directly: **the output
> must be professional-looking PowerPoint decks.** That requirement is met by
> the template-driven approach below — visual quality comes from the
> designer-authored `deck.pptx.template` (slide masters, brand colors,
> typography, authored once in PowerPoint Desktop), not from the fill
> library; the OpenXML SDK is only the mechanism that populates it. If the
> first rendered decks don't meet the bar visually, iterate on the template
> asset, not the renderer.
>
> **Date:** 2026-07-22 · **Author:** Claude Code (engineer agent) · **Unblocks:** AB#5044 (Tiered renderer engine)

## 1. Decision

**Recommend: OpenXML SDK (`DocumentFormat.OpenXml`), not `python-pptx`, not COM automation.**

Build the executive deck by opening a pre-authored `deck.pptx.template` (title +
content slide layouts, styled once in PowerPoint, per the layout already
named in `enhancement-spec.md` §1.1) and populating it programmatically via
the OpenXML SDK — cloning the repeating slide (area scores, gap list, manual
review) and replacing text runs, rather than hand-building the OPC part tree
from nothing.

## 2. Why (this repo's actual constraints)

- **CI is `ubuntu-latest`** (`.ado/azure-pipelines.yml:4`) — this alone
  eliminates COM automation outright; it needs PowerPoint installed and is
  Windows-only. Not a real option for an unattended pipeline that has to run
  on a Linux Microsoft-hosted agent.
- **python-pptx adds a second runtime the pipeline doesn't otherwise need.**
  Every other renderer (`Export-Html.ps1`, `Export-Excel.ps1` via
  `ImportExcel`/EPPlus, `Export-PowerBi.ps1`) is pure PowerShell/.NET. The
  current prototype (`src/report/renderers/Export-Pptx.ps1:16-18`) shells out
  to `python` and only checks that the `python` binary exists — it does not
  check that `python-pptx` is installed, and `.ado/azure-pipelines.yml` has
  no `pip install` step. Today, a pipeline run with `-OutputFormat Pptx`
  either silently skips the deck (if `python` itself is missing) or crashes
  on an unguarded `ImportError` inside `build_deck.py` (if `python` exists
  but the package doesn't) — this is a live gap, not a hypothetical one.
- **The tool's stated identity is "PowerShell module," cross-platform
  (Windows/Linux/macOS per `README.md` frontmatter), no licensing fees, no
  extra runtimes.** Every other collect/assess/report component is
  PowerShell + .NET (Az modules, `ImportExcel`, `powershell-yaml`). Adding
  Python for exactly one of five output tiers means every environment that
  wants the full `-OutputFormat All` matrix now needs two interpreters
  provisioned and kept in sync, doubling the dependency surface for one
  slide deck.
- **OpenXML SDK is pure .NET, ships as a NuGet package, and loads with
  `Add-Type` inside PowerShell 7 the same way `ImportExcel` already loads
  EPPlus.** No separate interpreter, no `pip`, no version drift between a
  Python venv and the PowerShell host, works identically wherever `pwsh`
  already runs (Windows, the Linux CI agent, or a contributor's Mac).
- **The "more code" cost is real but bounded.** The deck only needs four
  slide shapes (title, framework scores, area scores, prioritized gaps,
  manual-review worklist) — all bullet-list content, no charts or images.
  Templating against a pre-built `.pptx` (clone one populated slide N times,
  replace text runs) avoids hand-assembling the full Open Packaging
  Conventions part tree, which is where OpenXML SDK code volume usually
  balloons. This keeps the SDK route's added code proportional to the
  content, not to the file format's complexity.
- **Rejected: PSWriteOffice / community OpenXML wrapper modules.** These
  exist (PowerShell Gallery) but are pre-1.0 / experimental
  (`PSWriteOffice` is at `0.0.2`). Depending on an unstable third-party
  wrapper trades one dependency risk for another; referencing
  `DocumentFormat.OpenXml` directly is the more stable pure-.NET path and
  keeps AzureScout's supply chain to Microsoft-published packages, matching
  how the Excel tier already depends on EPPlus (a mature, versioned
  package) rather than a thin wrapper around it.

## 3. What changes if adopted

- **`src/report/renderers/Export-Pptx.ps1` gets rewritten.** The
  `python "$PSScriptRoot/../templates/build_deck.py" ...` shell-out is
  replaced with PowerShell that loads `DocumentFormat.OpenXml` via
  `Add-Type`, opens `deck.pptx.template`, and populates it from the scored
  `findings.json` object — same function signature
  (`Export-Pptx -Findings $Findings -OutputPath $OutputPath`), same
  `Export-Report.ps1` dispatch contract (`src/report/Export-Report.ps1`).
- **`src/report/templates/build_deck.py` is removed.** Its slide content
  (title slide, framework scores, area scores, top-10 gaps, manual-review
  worklist — including the AB#5089 defensive `sev()` null-severity guard)
  becomes the spec for the new PowerShell implementation; the guard logic
  must be carried over, not dropped.
- **A new template asset is added**: `src/report/templates/deck.pptx.template`
  (referenced in `enhancement-spec.md` §1.1 but not present in the current
  prototype tree) — a PowerPoint file with the title layout and one styled
  content-slide layout (navy `#1F4E78` branding, matching
  `report.html.template`), authored once in PowerPoint Desktop, committed
  as a binary asset like `report.pbit` already is for the Power BI tier.
- **`AzureScout.psm1`'s `$_requiredModules` list gains an entry** for the
  OpenXML dependency. Two viable forms — pick one at implementation time:
  install `DocumentFormat.OpenXml` as a NuGet package and load with
  `Add-Type -Path`, or (simpler for a `$_requiredModules` + `Install-Module`
  pattern that mirrors the existing `ImportExcel`/`Az.*` entries) depend on
  a PowerShell Gallery module that itself references the SDK assembly. This
  repo's existing bootstrap pattern (`AzureScout.psm1:21-42`) favors a
  gallery module if one is stable enough by implementation time; otherwise
  a `NuGet`-sourced `Add-Type -Path` load next to the other dependency
  bootstrap code.
- **`.ado/azure-pipelines.yml` needs no new step.** No `pip install`, no
  Python provisioning — the Linux Microsoft-hosted agent already has the
  .NET runtime PowerShell 7 itself needs; nothing extra to add for this
  tier.
- **`docs/design/enhancement-spec.md` §6.4 and §10 stay as historical
  record** (the spec is "verbatim source of record," per its own
  frontmatter) — they are not edited to reflect this decision. The
  divergence from the spec's python-pptx default is captured here instead.

## 4. What this does NOT decide

- **Power BI (Tier 1) is unaffected.** `Export-PowerBi.ps1` continues
  emitting flat CSVs against a `.pbit` template; nothing here touches it.
- **Self-contained HTML (Tier 2) is unaffected.** `Export-Html.ps1` and
  `report.html.template` are untouched.
- **Excel/JSON (evidence tier) are unaffected.**
- **This is not final.** It is a recommendation for the repo owner to
  confirm before AB#5044 (tiered renderer engine) is built out against it.
  If the owner prefers to accept the Python dependency (e.g., because
  `python-pptx` is already provisioned elsewhere in their environment), that
  is a valid override — record it as an amendment to this file rather than
  a silent reversal.
