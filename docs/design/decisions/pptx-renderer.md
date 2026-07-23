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

## 5. Implementation note (AB#5044, 2026-07-23)

**Status stays Accepted.** `src/report/renderers/Export-Pptx.ps1` is
implemented per §1–§3 above, with two deliberate amendments to the original
plan, both because a designer-authored binary `.pptx` cannot be committed to
this repo (§3's original text assumed one would be):

- **Template-as-code, not a committed `deck.pptx.template` binary.** Instead
  of opening a pre-authored `.pptx` and cloning its slide layouts, the deck's
  entire visual design — theme (navy `#1F4E78` / steel `#2E75B6` / gold
  `#B8860B` palette, matching `report.html.template`), slide master, title
  layout, and content layout — is built programmatically in
  `New-ScoutDeckShell` and the shared `Add-ScoutSlideChrome` function. This
  is the "template-driven approach" the acceptance criterion asks for, just
  authored in PowerShell instead of PowerPoint Desktop.
  **Extension point:** a future designer-authored `deck.pptx.template` can
  still replace this — swap `New-ScoutDeckShell`'s theme/master/layout
  construction for code that opens the template and clones its parts
  (`SlideMasterPart`/`SlideLayoutPart`/`ThemePart`), and leave every
  slide-content builder (`New-ScoutTitleSlide`, `New-ScoutExecSummarySlide`,
  `New-ScoutAreaTableSlides`, `New-ScoutGapsSlides`, `New-ScoutManualSlide`,
  `New-ScoutNextStepsSlide`) untouched — they only depend on the shell
  exposing a title `SlideLayoutPart` and a content `SlideLayoutPart`. This
  extension point is also called out in a code comment at the top of
  `Export-Pptx.ps1`.
- **Assembly acquisition instead of a `$_requiredModules` PowerShell Gallery
  entry.** No PSGallery wrapper module for `DocumentFormat.OpenXml` was
  stable enough to depend on at implementation time (the rejection of
  `PSWriteOffice` in §2 still applies), so `Export-Pptx.ps1` acquires the
  pinned `DocumentFormat.OpenXml` NuGet package itself on first use: it
  shells out to `dotnet build` against a throwaway class-library project
  referencing the package, which resolves the full transitive dependency
  graph (`DocumentFormat.OpenXml.Framework`, `System.IO.Packaging`) via
  NuGet/MSBuild rather than hand-rolling flat-container downloads, and
  caches the three resulting DLLs under `output/.tools/openxml/<version>/`
  (already `.gitignore`d — no binaries committed). Subsequent calls in the
  same or later runs load straight from the cache. If offline and nothing
  is cached, `Export-Pptx` throws a clear, actionable error rather than
  silently skipping the deck or faking success — the same failure mode the
  original python-pptx prototype had for a missing `python` binary, now
  fixed instead of inherited.
- **`Export-Pptx` gained an optional `-Collect` parameter**, matching
  `Export-Html`/`-Excel`/`-PowerBi`'s existing signature (the original §3
  text expected the signature to stay `-Findings`/`-OutputPath` only).
  `Collect._meta.scope` / `.managementGroupId` are shown on the title slide
  when present; the deck degrades gracefully to date + branding only when
  `-Collect` is omitted or empty, since neither `Get-Score`'s Findings
  contract nor `src/collect/Invoke-Collect.ps1`'s canonical collect shape
  carries a tenant field today.
- The AB#5089 defensive severity guard (null/unknown severity sorts LAST,
  never throws) is carried into the renderer as
  `Get-ScoutSeverityRank`/`Get-ScoutSeverityLabel`, applied redundantly at
  render time even though `Get-Score` already sorts gaps this way — same
  belt-and-suspenders intent as the retired `build_deck.py`'s `sev()`
  helper.

Smoke-tested via `tests/Test-PptxFromDataDump.ps1` (synthetic findings
derived from `tests/datadump/sample-report.json`, including deliberately
null/blank/unrecognized severities): renders an 8-slide deck, validates as
a well-formed OPC package, and passes `DocumentFormat.OpenXml.Validation.OpenXmlValidator`
with zero schema issues.
