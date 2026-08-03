#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Auto-assemble a Word (.docx) assessment report from scored findings via the
    OpenXML SDK (DocumentFormat.OpenXml) — no Word install required.

.DESCRIPTION
    Renders a print/share-friendly Word document directly from the scored
    Findings object (the output of Get-Score: GeneratedOn/Frameworks/Areas/
    Gaps/Manual/Errors/Findings) plus the raw Collect object (only its optional
    _meta.scope / _meta.managementGroupId are read, mirroring Export-Pptx).
    Every part of the .docx OPC package (document body, section properties,
    tables) is constructed programmatically with the OpenXML SDK
    (DocumentFormat.OpenXml.Wordprocessing) — the same accepted design used by
    Export-Pptx.ps1 for the executive deck (AB#5044).

    Section inventory:
      1. Cover           — title, subtitle, generated date/scope/mgmt-group
      2. Executive Summary — framework score table + rollup counts
      3. Findings by Area  — one heading + findings table per assessed area
      4. Prioritized Gaps  — Severity/Area/Gap table, sorted worst-first,
                             capped at top $Script:ScoutDocxMaxGaps rows
      5. Manual Review     — outstanding manual-review worklist, capped at
                             $Script:ScoutDocxMaxManual rows

    ASSEMBLY ACQUISITION: reuses the exact acquire-once-and-cache pattern
    Export-Pptx.ps1 established (Import-ScoutOpenXmlAssembly) — a throwaway
    dotnet-build csproj that pulls DocumentFormat.OpenXml from NuGet on first
    use and caches the DLLs under output/.tools/openxml/<version>. This file
    defines its own copy (Import-ScoutDocxOpenXmlAssembly) rather than calling
    Export-Pptx.ps1's function directly, so this renderer stays fully
    self-contained and loadable on its own (every existing renderer test
    harness in tests/ dot-sources only the one renderer .ps1 file it needs) —
    but it deliberately points at the SAME cache directory and version pin, so
    a prior Export-Pptx run (or Pptx Pester run) that already populated the
    cache means this renderer's first use costs nothing extra: Wordprocessing
    types live in the very same DocumentFormat.OpenXml.dll the deck renderer
    already downloaded.

.NOTES
    Tracks ADO Story AB#333.

    OpenXML SDK GOTCHA (also documented in Export-Pptx.ps1): every
    OpenXmlElement implements IEnumerable<OpenXmlElement> over its own
    children, and PowerShell's function-output pipeline auto-enumerates any
    IEnumerable it sees. A bare "return $element" silently flattens the
    element into its (often zero) children instead of returning the element
    itself — every helper below returns via the unary comma operator
    (`return ,$x`) to suppress that unrolling. The same is true of a plain
    System.Collections.Generic.List[object] (also IEnumerable), so
    New-ScoutDocxList follows the same pattern. Do not remove the commas.

    Non-fatal on failure: the whole render is wrapped in try/catch. If
    anything throws (a broken OpenXML acquire, a malformed Findings object,
    etc.) this writes a self-contained "assessment_word_fallback.html" next
    to where the .docx would have gone (mirroring Export-Pdf.ps1's
    Export-ScoutPdfHtmlFallback pattern) instead of throwing and aborting the
    whole multi-renderer Export-Report loop in the assessment core.
#>

#region Assembly acquisition (first-use NuGet acquire + cache, no committed binaries)

# Pinned so every run resolves the exact same OpenXML SDK build; bump deliberately.
# Deliberately the same version Export-Pptx.ps1 pins — see this file's header.
$Script:ScoutDocxOpenXmlVersion = '3.0.2'

function Import-ScoutDocxOpenXmlAssembly {
    [CmdletBinding()]
    param()

    # Idempotent within a process — a prior Export-Pptx (or Export-Word) call
    # in the same pwsh session already loaded these.
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'DocumentFormat.OpenXml' }
    if ($loaded) { return }

    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $cacheDir = Join-Path $repoRoot 'output' '.tools' 'openxml' $Script:ScoutDocxOpenXmlVersion
    $requiredDlls = @('DocumentFormat.OpenXml.Framework.dll', 'System.IO.Packaging.dll', 'DocumentFormat.OpenXml.dll')

    $haveAll = -not ($requiredDlls | Where-Object { -not (Test-Path (Join-Path $cacheDir $_)) })
    if (-not $haveAll) {
        if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            throw "Export-Word: DocumentFormat.OpenXml $($Script:ScoutDocxOpenXmlVersion) is not cached at '$cacheDir' and the 'dotnet' SDK is not on PATH to acquire it. Install the .NET SDK (or pre-seed the cache folder with the three DLLs above) and retry."
        }

        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AzScoutOpenXmlAcquire_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $tempProj = Join-Path $tempDir 'acquire.csproj'
        @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>disable</Nullable>
    <ImplicitUsings>disable</ImplicitUsings>
    <CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>
    <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="DocumentFormat.OpenXml" Version="$($Script:ScoutDocxOpenXmlVersion)" />
  </ItemGroup>
</Project>
"@ | Out-File -FilePath $tempProj -Encoding utf8

        Write-Host "[Export-Word] Acquiring DocumentFormat.OpenXml $($Script:ScoutDocxOpenXmlVersion) via dotnet/NuGet (first use — cached under $cacheDir for subsequent runs)..." -ForegroundColor Cyan
        $buildOutput = & dotnet build $tempProj -c Release -o $cacheDir --nologo 2>&1
        $exitCode = $LASTEXITCODE
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem $cacheDir -Filter 'acquire.*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

        if ($exitCode -ne 0 -or -not (Test-Path (Join-Path $cacheDir 'DocumentFormat.OpenXml.dll'))) {
            throw "Export-Word: could not acquire DocumentFormat.OpenXml $($Script:ScoutDocxOpenXmlVersion) (offline, and nothing cached at '$cacheDir'?). dotnet build exit code $exitCode.`n$($buildOutput -join "`n")"
        }
        Write-Host "[Export-Word] DocumentFormat.OpenXml $($Script:ScoutDocxOpenXmlVersion) cached at $cacheDir" -ForegroundColor Green
    }

    foreach ($dll in $requiredDlls) {
        Add-Type -Path (Join-Path $cacheDir $dll) -ErrorAction Stop
    }
}

#endregion

#region Low-level OpenXML element helpers

$Script:ScoutDocxWNs = 'DocumentFormat.OpenXml.Wordprocessing'

function New-ScoutDocxEl {
    param([Parameter(Mandatory)][string]$TypeName)
    $o = New-Object -TypeName $TypeName
    return , $o
}

function New-ScoutDocxList {
    return , ([System.Collections.Generic.List[object]]::new())
}

function Add-ScoutDocxStyleDefinitions {
    <#
    .SYNOPSIS
        Create the StyleDefinitionsPart and declare the named styles the document uses.

    .DESCRIPTION
        AB#6874, clauses W-01 and W-02. Phase 0 measured that the generated .docx contained
        THREE package parts -- _rels/.rels, [Content_Types].xml, word/document.xml -- and that
        0 of its 1,803 paragraphs carried a pStyle. Every heading was direct run formatting, so
        Word had no idea any line was a heading.

        That single fact explains four separate symptoms at once: no navigation pane, no possible
        TOC field (a TOC collects heading STYLES, and there were none), no cross-references, and
        nothing a partner could restyle to their brand.

        Sizes here are half-points (w:sz), which is why they are double the point size used by
        the direct-formatting helpers.
    #>
    param([Parameter(Mandatory)]$MainPart)

    # PowerShell 7 generic-method syntax. `AddNewPart([type])` binds to no overload -- AddNewPart
    # is generic over the part type, not a parameter taking one.
    $stylePart = $MainPart.AddNewPart[DocumentFormat.OpenXml.Packaging.StyleDefinitionsPart]()
    $styles = New-ScoutDocxEl "$Script:ScoutDocxWNs.Styles"

    # Heading 1-3 carry the built-in style IDs Word looks for. A custom ID would render
    # identically and still produce no navigation pane, because Word keys the outline off these.
    $spec = @(
        @{ Id = 'Heading1'; Name = 'heading 1'; SizeHalfPt = 44; Outline = 0; Before = 240; After = 120 }
        @{ Id = 'Heading2'; Name = 'heading 2'; SizeHalfPt = 32; Outline = 1; Before = 200; After = 100 }
        @{ Id = 'Heading3'; Name = 'heading 3'; SizeHalfPt = 26; Outline = 2; Before = 160; After = 80 }
    )

    foreach ($s in $spec) {
        $style = New-ScoutDocxEl "$Script:ScoutDocxWNs.Style"
        $style.Type = [DocumentFormat.OpenXml.Wordprocessing.StyleValues]::Paragraph
        $style.StyleId = $s.Id
        # PrimaryStyle marks it as one Word offers in the styles gallery, which is also what
        # makes it available as a TOC source in the UI.
        $style.CustomStyle = $false

        $name = New-ScoutDocxEl "$Script:ScoutDocxWNs.StyleName"
        $name.Val = $s.Name
        $style.Append($name)

        # CHILD ORDER IS PART OF THE SCHEMA, not a style choice. CT_PPrBase fixes the sequence
        # keepNext -> spacing -> outlineLvl, and CT_RPr fixes rFonts -> b -> color -> sz.
        # Appending them in any other order produces a package Word still opens but that fails
        # Sch_UnexpectedElementContentExpectingComplex under the SDK validator -- which the
        # Report.Word suite gates on.
        $pPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.StyleParagraphProperties"
        $keepNext = New-ScoutDocxEl "$Script:ScoutDocxWNs.KeepNext"
        $pPr.Append($keepNext)
        $spacing = New-ScoutDocxEl "$Script:ScoutDocxWNs.SpacingBetweenLines"
        $spacing.Before = [string]$s.Before
        $spacing.After = [string]$s.After
        $pPr.Append($spacing)
        $outline = New-ScoutDocxEl "$Script:ScoutDocxWNs.OutlineLevel"
        $outline.Val = [int]$s.Outline
        $pPr.Append($outline)
        $style.Append($pPr)

        $rPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.StyleRunProperties"
        $fonts = New-ScoutDocxEl "$Script:ScoutDocxWNs.RunFonts"
        $fonts.Ascii = 'Segoe UI Semibold'
        $fonts.HighAnsi = 'Segoe UI Semibold'
        $rPr.Append($fonts)
        $bold = New-ScoutDocxEl "$Script:ScoutDocxWNs.Bold"
        $rPr.Append($bold)
        $color = New-ScoutDocxEl "$Script:ScoutDocxWNs.Color"
        $color.Val = $Script:ScoutDocxNavy
        $rPr.Append($color)
        $sz = New-ScoutDocxEl "$Script:ScoutDocxWNs.FontSize"
        $sz.Val = [string]$s.SizeHalfPt
        $rPr.Append($sz)
        $style.Append($rPr)

        $styles.Append($style)
    }

    $stylePart.Styles = $styles
    return $stylePart
}

function ScoutDocxDxa {
    # Twentieths of a point ("dxa") — the unit w:tblGrid/w:tcW/w:pgSz/w:pgMar all use.
    # 1440 dxa per inch.
    param([double]$Inches)
    return [int64][math]::Round($Inches * 1440)
}

#endregion

#region Palette (mirrors Export-Pptx.ps1's navy/steel/gold corporate palette)

$Script:ScoutDocxNavy = '1F4E78'
$Script:ScoutDocxSteel = '2E75B6'
$Script:ScoutDocxGreen = '2E7D32'
$Script:ScoutDocxGold = 'B8860B'
$Script:ScoutDocxRed = 'B00020'
$Script:ScoutDocxInk = '1A1A1A'
$Script:ScoutDocxPaper = 'FFFFFF'
$Script:ScoutDocxMist = 'F6F9FD'
$Script:ScoutDocxLine = 'D9D9D9'
$Script:ScoutDocxGray = '595959'

# Bounds on the doc's longer, unbounded-in-theory lists — a document naturally
# paginates (unlike a slide deck), so these are generous, but still finite so a
# pathological Findings object (thousands of gaps) can't produce a runaway render.
$Script:ScoutDocxMaxGaps = 50
$Script:ScoutDocxMaxManual = 100

#endregion

#region Paragraph / run helpers

function New-ScoutDocxRun {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [double]$SizePt = 11,
        [string]$Hex = $Script:ScoutDocxInk,
        [bool]$Bold = $false,
        [bool]$Italic = $false,
        [string]$Font = 'Segoe UI'
    )
    $run = New-ScoutDocxEl "$Script:ScoutDocxWNs.Run"
    $rPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.RunProperties"
    $rFonts = New-ScoutDocxEl "$Script:ScoutDocxWNs.RunFonts"
    $rFonts.Ascii = $Font
    $rFonts.HighAnsi = $Font
    $rPr.Append($rFonts)
    if ($Bold) { $rPr.Append((New-ScoutDocxEl "$Script:ScoutDocxWNs.Bold")) }
    if ($Italic) { $rPr.Append((New-ScoutDocxEl "$Script:ScoutDocxWNs.Italic")) }
    # CT_RPr child order (ECMA-376 §17.3.2.30) requires color BEFORE sz/szCs —
    # putting FontSize first (as an earlier draft of this file did) validates
    # as a schema error ("unexpected child element w:color") even though Word
    # itself tolerates it; keep this order to stay strictly schema-valid.
    $color = New-ScoutDocxEl "$Script:ScoutDocxWNs.Color"
    $color.Val = $Hex
    $rPr.Append($color)
    $sz = New-ScoutDocxEl "$Script:ScoutDocxWNs.FontSize"
    $sz.Val = "$([int][math]::Round($SizePt * 2))"
    $rPr.Append($sz)
    $run.Append($rPr)
    $t = New-ScoutDocxEl "$Script:ScoutDocxWNs.Text"
    $t.Text = $Text
    $t.Space = [DocumentFormat.OpenXml.SpaceProcessingModeValues]::Preserve
    $run.Append($t)
    return , $run
}

function New-ScoutDocxBreakRun {
    # A page-break run — appended as its own run inside the last paragraph of a
    # section so the next content starts on a fresh page.
    $run = New-ScoutDocxEl "$Script:ScoutDocxWNs.Run"
    $br = New-ScoutDocxEl "$Script:ScoutDocxWNs.Break"
    $br.Type = [DocumentFormat.OpenXml.Wordprocessing.BreakValues]::Page
    $run.Append($br)
    return , $run
}

function New-ScoutDocxPara {
    param(
        $Runs,
        [string]$Align = $null,
        [double]$SpaceBeforePt = 0,
        [double]$SpaceAfterPt = 6,
        [bool]$KeepNext = $false
    )
    $p = New-ScoutDocxEl "$Script:ScoutDocxWNs.Paragraph"
    $pPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.ParagraphProperties"
    $any = $false
    # CT_PPrBase child order (ECMA-376 §17.3.1.26) is keepNext, then spacing,
    # then jc — appending Justification first (as an earlier draft did)
    # validates as a schema error ("unexpected child element w:keepNext"/
    # "w:spacing" showing up after w:jc). Keep this order.
    if ($KeepNext) {
        $pPr.Append((New-ScoutDocxEl "$Script:ScoutDocxWNs.KeepNext"))
        $any = $true
    }
    if ($SpaceBeforePt -gt 0 -or $SpaceAfterPt -gt 0) {
        $spacing = New-ScoutDocxEl "$Script:ScoutDocxWNs.SpacingBetweenLines"
        if ($SpaceBeforePt -gt 0) { $spacing.Before = "$([int][math]::Round($SpaceBeforePt * 20))" }
        if ($SpaceAfterPt -gt 0) { $spacing.After = "$([int][math]::Round($SpaceAfterPt * 20))" }
        $pPr.Append($spacing)
        $any = $true
    }
    if ($Align) {
        $jc = New-ScoutDocxEl "$Script:ScoutDocxWNs.Justification"
        $jc.Val = switch ($Align) {
            'center' { [DocumentFormat.OpenXml.Wordprocessing.JustificationValues]::Center }
            'right' { [DocumentFormat.OpenXml.Wordprocessing.JustificationValues]::Right }
            default { [DocumentFormat.OpenXml.Wordprocessing.JustificationValues]::Left }
        }
        $pPr.Append($jc)
        $any = $true
    }
    if ($any) { $p.Append($pPr) }
    foreach ($r in $Runs) { $p.Append($r) }
    return , $p
}

function Add-ScoutDocxHeading {
    param($Body, [Parameter(Mandatory)][string]$Text, [int]$Level = 1)
    $sizePt = switch ($Level) { 1 { 22 } 2 { 16 } default { 13 } }
    $runs = New-ScoutDocxList
    $runs.Add((New-ScoutDocxRun -Text $Text -SizePt $sizePt -Hex $Script:ScoutDocxNavy -Bold $true -Font 'Segoe UI Semibold'))
    $spaceBefore = if ($Level -eq 1) { 12 } else { 8 }
    $para = New-ScoutDocxPara -Runs $runs -SpaceBeforePt $spaceBefore -SpaceAfterPt 6 -KeepNext $true

    # AB#6874, clause W-02. The pStyle is what makes this a HEADING rather than large bold text.
    # Without it Word builds no navigation pane and a TOC field collects nothing, which is
    # exactly what Phase 0 measured: 0 of 1,803 paragraphs styled.
    #
    # The direct formatting above is deliberately KEPT alongside it. The style supplies the
    # outline level and the semantics; the direct run properties guarantee the document still
    # looks right in a reader that ignores the style part, and they render identically because
    # both describe the same Segoe UI Semibold navy.
    $pStyle = New-ScoutDocxEl "$Script:ScoutDocxWNs.ParagraphStyleId"
    $pStyle.Val = "Heading$([Math]::Min([Math]::Max($Level, 1), 3))"
    # Generic, like AddNewPart above -- `GetFirstChild([type])` binds to no overload.
    $pPr = $para.GetFirstChild[DocumentFormat.OpenXml.Wordprocessing.ParagraphProperties]()
    if ($null -eq $pPr) {
        $pPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.ParagraphProperties"
        $para.InsertAt($pPr, 0)
    }
    $pPr.InsertAt($pStyle, 0)

    $Body.Append($para)
}

function Add-ScoutDocxParagraph {
    param($Body, [Parameter(Mandatory)][AllowEmptyString()][string]$Text, [double]$SizePt = 11, [string]$Hex = $Script:ScoutDocxInk, [bool]$Italic = $false, [string]$Align = $null)
    $runs = New-ScoutDocxList
    $runs.Add((New-ScoutDocxRun -Text $Text -SizePt $SizePt -Hex $Hex -Italic $Italic))
    $Body.Append((New-ScoutDocxPara -Runs $runs -Align $Align))
}

function Add-ScoutDocxPageBreak {
    param($Body)
    $runs = New-ScoutDocxList
    $runs.Add((New-ScoutDocxBreakRun))
    $p = New-ScoutDocxEl "$Script:ScoutDocxWNs.Paragraph"
    foreach ($r in $runs) { $p.Append($r) }
    $Body.Append($p)
}

#endregion

#region Table helpers

function New-ScoutDocxShading {
    param([Parameter(Mandatory)][string]$Hex)
    $sh = New-ScoutDocxEl "$Script:ScoutDocxWNs.Shading"
    $sh.Val = [DocumentFormat.OpenXml.Wordprocessing.ShadingPatternValues]::Clear
    $sh.Color = 'auto'
    $sh.Fill = $Hex
    return , $sh
}

function New-ScoutDocxCell {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][double]$WidthIn,
        [double]$SizePt = 10,
        [string]$Hex = $Script:ScoutDocxInk,
        [bool]$Bold = $false,
        [string]$FillHex = $null,
        [string]$Align = $null
    )
    $tc = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableCell"
    $tcPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableCellProperties"
    $tcW = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableCellWidth"
    $tcW.Width = "$(ScoutDocxDxa $WidthIn)"
    $tcW.Type = [DocumentFormat.OpenXml.Wordprocessing.TableWidthUnitValues]::Dxa
    $tcPr.Append($tcW)
    if ($FillHex) { $tcPr.Append((New-ScoutDocxShading -Hex $FillHex)) }
    $vAlign = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableCellVerticalAlignment"
    $vAlign.Val = [DocumentFormat.OpenXml.Wordprocessing.TableVerticalAlignmentValues]::Center
    $tcPr.Append($vAlign)
    $tc.Append($tcPr)
    $runs = New-ScoutDocxList
    $runs.Add((New-ScoutDocxRun -Text $Text -SizePt $SizePt -Hex $Hex -Bold $Bold))
    $tc.Append((New-ScoutDocxPara -Runs $runs -Align $Align -SpaceAfterPt 0))
    return , $tc
}

function New-ScoutDocxRow {
    param($Cells, [bool]$Header = $false)
    $tr = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableRow"
    if ($Header) {
        $trPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableRowProperties"
        # AB#394-style header repeat (the same idea Export-Pdf.ps1 hand-rolls for
        # its findings table): w:tblHeader marks this row to repeat on every page
        # a long table spills onto, without duplicating it in the source content.
        $trPr.Append((New-ScoutDocxEl "$Script:ScoutDocxWNs.TableHeader"))
        $tr.Append($trPr)
    }
    foreach ($c in $Cells) { $tr.Append($c) }
    return , $tr
}

function New-ScoutDocxTable {
    param([Parameter(Mandatory)][double[]]$ColWidthsIn, [Parameter(Mandatory)]$Rows)
    $tbl = New-ScoutDocxEl "$Script:ScoutDocxWNs.Table"
    $tblPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableProperties"

    $tblW = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableWidth"
    $tblW.Width = '5000'
    $tblW.Type = [DocumentFormat.OpenXml.Wordprocessing.TableWidthUnitValues]::Pct
    $tblPr.Append($tblW)

    $borders = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableBorders"
    # CT_TblBorders child order (ECMA-376 §17.4.38) is top, left, bottom,
    # right, insideH, insideV — NOT top/bottom/left/right.
    foreach ($side in 'TopBorder', 'LeftBorder', 'BottomBorder', 'RightBorder', 'InsideHorizontalBorder', 'InsideVerticalBorder') {
        $b = New-ScoutDocxEl "$Script:ScoutDocxWNs.$side"
        $b.Val = [DocumentFormat.OpenXml.Wordprocessing.BorderValues]::Single
        $b.Size = [uint32]4
        $b.Color = $Script:ScoutDocxLine
        $borders.Append($b)
    }
    $tblPr.Append($borders)

    $tblLook = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableLook"
    $tblLook.FirstRow = $true
    $tblLook.LastRow = $false
    $tblLook.FirstColumn = $false
    $tblLook.LastColumn = $false
    $tblLook.NoHorizontalBand = $false
    $tblLook.NoVerticalBand = $true
    $tblPr.Append($tblLook)

    $tbl.Append($tblPr)

    $grid = New-ScoutDocxEl "$Script:ScoutDocxWNs.TableGrid"
    foreach ($w in $ColWidthsIn) {
        $gc = New-ScoutDocxEl "$Script:ScoutDocxWNs.GridColumn"
        $gc.Width = "$(ScoutDocxDxa $w)"
        $grid.Append($gc)
    }
    $tbl.Append($grid)

    foreach ($r in $Rows) { $tbl.Append($r) }
    return , $tbl
}

#endregion

#region Data helpers (safe property access, score/severity bands — mirrors Export-Pptx.ps1)

function Get-ScoutDocxProp {
    param($Obj, [Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($null -eq $Obj) { return $Default }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $Default }
}

function Get-ScoutDocxScoreColor {
    param($Score)
    if ($null -eq $Score) { return $Script:ScoutDocxGray }
    if ($Score -ge 80) { return $Script:ScoutDocxGreen }
    if ($Score -ge 50) { return $Script:ScoutDocxGold }
    return $Script:ScoutDocxRed
}

$Script:ScoutDocxSeverityRank = @{ high = 0; medium = 1; low = 2 }

function Get-ScoutDocxSeverityRank {
    # AB#5089-style guard: null/missing/unrecognized severity sorts LAST, never throws.
    param($Severity)
    if ($Severity) {
        $key = $Severity.ToString().Trim().ToLowerInvariant()
        if ($Script:ScoutDocxSeverityRank.ContainsKey($key)) { return $Script:ScoutDocxSeverityRank[$key] }
    }
    return 99
}

function Get-ScoutDocxSeverityLabel {
    param($Severity)
    if ($Severity -and "$Severity".Trim()) { return "$Severity".ToUpperInvariant() }
    return 'UNKNOWN'
}

function Get-ScoutDocxSeverityColor {
    param($Severity)
    if (-not $Severity) { return $Script:ScoutDocxGray }
    switch ($Severity.ToString().Trim().ToLowerInvariant()) {
        'high' { return $Script:ScoutDocxRed }
        'medium' { return $Script:ScoutDocxGold }
        'low' { return $Script:ScoutDocxSteel }
        default { return $Script:ScoutDocxGray }
    }
}

#endregion

#region HTML fallback (non-fatal-on-failure companion, mirrors Export-Pdf.ps1's pattern)

function Export-ScoutDocxHtmlFallback {
    param($Findings, $Collect, [string] $OutputPath, [string] $Reason)
    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    $json = ($Findings | ConvertTo-Json -Depth 100) -replace '</', '<\/'
    $safeReason = $Reason -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    $generatedOn = Get-ScoutDocxProp $Findings 'GeneratedOn' '(unknown)'
    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Azure Scout Assessment Report (fallback)</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; color:#1a1a1a; margin: 2rem; }
  .banner { background:#B00020; color:#fff; padding: 0.75rem 1rem; margin-bottom:1rem; }
</style>
</head>
<body>
<div class="banner">
  Word (.docx) generation failed for this run -- this is a plain HTML fallback, not a renamed non-docx file.
  Reason: $safeReason
</div>
<h1>Azure Scout Assessment Report</h1>
<p>Generated: $generatedOn</p>
<script>window.__FINDINGS__ = $json;</script>
</body>
</html>
"@
    $path = Join-Path $OutputPath 'assessment_word_fallback.html'
    $html | Out-File -FilePath $path -Encoding utf8
    return $path
}

#endregion

#region Section builders

function New-ScoutDocxCoverParagraphs {
    param($Body, [string]$Title, [string]$Subtitle, [string]$MetaLine)

    $wmRuns = New-ScoutDocxList
    $wmRuns.Add((New-ScoutDocxRun -Text 'AZURE SCOUT' -SizePt 12 -Hex $Script:ScoutDocxSteel -Bold $true))
    $Body.Append((New-ScoutDocxPara -Runs $wmRuns -Align 'center' -SpaceBeforePt 60 -SpaceAfterPt 12))

    $titleRuns = New-ScoutDocxList
    $titleRuns.Add((New-ScoutDocxRun -Text $Title -SizePt 32 -Hex $Script:ScoutDocxNavy -Bold $true -Font 'Segoe UI Semibold'))
    $Body.Append((New-ScoutDocxPara -Runs $titleRuns -Align 'center' -SpaceAfterPt 8))

    if ($Subtitle) {
        $subRuns = New-ScoutDocxList
        $subRuns.Add((New-ScoutDocxRun -Text $Subtitle -SizePt 15 -Hex $Script:ScoutDocxGray))
        $Body.Append((New-ScoutDocxPara -Runs $subRuns -Align 'center' -SpaceAfterPt 24))
    }

    if ($MetaLine) {
        $metaRuns = New-ScoutDocxList
        $metaRuns.Add((New-ScoutDocxRun -Text $MetaLine -SizePt 11 -Hex $Script:ScoutDocxGray -Italic $true))
        $Body.Append((New-ScoutDocxPara -Runs $metaRuns -Align 'center' -SpaceAfterPt 6))
    }
}

function New-ScoutDocxExecSummary {
    param($Body, $Frameworks, $Areas, $Gaps, $Manual, $Errors)

    Add-ScoutDocxHeading -Body $Body -Text 'Executive Summary' -Level 1

    if (@($Frameworks).Count -eq 0) {
        Add-ScoutDocxParagraph -Body $Body -Text 'No framework scored for this run.' -Hex $Script:ScoutDocxGray
    }
    else {
        $rows = New-ScoutDocxList
        $header = New-ScoutDocxList
        $header.Add((New-ScoutDocxCell -Text 'Framework' -WidthIn 3.0 -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy))
        $header.Add((New-ScoutDocxCell -Text 'Alignment Score' -WidthIn 3.0 -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy -Align 'center'))
        $rows.Add((New-ScoutDocxRow -Cells $header -Header $true))

        $r = 0
        foreach ($fw in @($Frameworks)) {
            $r++
            $bg = if ($r % 2 -eq 0) { $Script:ScoutDocxMist } else { $Script:ScoutDocxPaper }
            $score = Get-ScoutDocxProp $fw 'Score'
            $scoreText = if ($null -eq $score) { 'Not scored' } else { "$score / 100" }
            $cells = New-ScoutDocxList
            $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $fw 'Framework')" -WidthIn 3.0 -FillHex $bg))
            $cells.Add((New-ScoutDocxCell -Text $scoreText -WidthIn 3.0 -Bold $true -Hex (Get-ScoutDocxScoreColor $score) -FillHex $bg -Align 'center'))
            $rows.Add((New-ScoutDocxRow -Cells $cells))
        }
        $Body.Append((New-ScoutDocxTable -ColWidthsIn @(3.0, 3.0) -Rows $rows))
    }

    $areaArr = @($Areas)
    $passSum = ($areaArr | ForEach-Object { Get-ScoutDocxProp $_ 'Pass' 0 } | Measure-Object -Sum).Sum
    $partialSum = ($areaArr | ForEach-Object { Get-ScoutDocxProp $_ 'Partial' 0 } | Measure-Object -Sum).Sum
    $failSum = ($areaArr | ForEach-Object { Get-ScoutDocxProp $_ 'Fail' 0 } | Measure-Object -Sum).Sum
    $manualCount = @($Manual).Count
    $errorCount = @($Errors).Count
    $highGaps = @($Gaps | Where-Object { (Get-ScoutDocxSeverityLabel (Get-ScoutDocxProp $_ 'Severity')) -eq 'HIGH' }).Count

    Add-ScoutDocxParagraph -Body $Body -Text ' ' -SizePt 4
    foreach ($line in @(
            "Areas assessed: $($areaArr.Count)"
            "Rules evaluated — Pass: $passSum, Partial: $partialSum, Fail: $failSum"
            "Critical (High severity) gaps: $highGaps"
            "Manual review items pending: $manualCount"
            "Unknown/Error findings (check collector permissions): $errorCount"
        )) {
        Add-ScoutDocxParagraph -Body $Body -Text "•   $line" -SizePt 12
    }
}

function New-ScoutDocxAreaFindingsSection {
    param($Body, $Areas, $AllFindings)

    Add-ScoutDocxHeading -Body $Body -Text 'Findings by Area' -Level 1

    # @(...) wraps the WHOLE pipeline, not just $Areas -- Sort-Object over zero
    # input emits nothing, which collapses a bare assignment to $null (and
    # $null.Count throws under Set-StrictMode -Version Latest). Same
    # load-bearing pattern Get-Score.ps1 documents for its own Pass/Fail counters.
    $sortedAreas = @(@($Areas) | Sort-Object Framework, Area)
    if ($sortedAreas.Count -eq 0) {
        Add-ScoutDocxParagraph -Body $Body -Text 'No areas were assessed for this run.' -Hex $Script:ScoutDocxGray
        return
    }

    foreach ($area in $sortedAreas) {
        $framework = Get-ScoutDocxProp $area 'Framework'
        $areaName = Get-ScoutDocxProp $area 'Area'
        $score = Get-ScoutDocxProp $area 'Score'
        $scoreText = if ($null -eq $score) { 'not scored' } else { "$score / 100" }
        Add-ScoutDocxHeading -Body $Body -Text "$framework — $areaName (Score: $scoreText)" -Level 2

        $areaFindings = @($AllFindings | Where-Object {
                (Get-ScoutDocxProp $_ 'Framework') -eq $framework -and (Get-ScoutDocxProp $_ 'Area') -eq $areaName
            })

        if ($areaFindings.Count -eq 0) {
            Add-ScoutDocxParagraph -Body $Body -Text 'No individual findings recorded for this area.' -Hex $Script:ScoutDocxGray -Italic $true
            continue
        }

        $rows = New-ScoutDocxList
        $header = New-ScoutDocxList
        foreach ($h in 'Id', 'Severity', 'Status', 'Title') {
            $w = switch ($h) { 'Id' { 1.3 } 'Severity' { 1.0 } 'Status' { 1.0 } default { 3.2 } }
            $header.Add((New-ScoutDocxCell -Text $h -WidthIn $w -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy))
        }
        $rows.Add((New-ScoutDocxRow -Cells $header -Header $true))

        $r = 0
        foreach ($f in ($areaFindings | Sort-Object @{ Expression = { Get-ScoutDocxSeverityRank (Get-ScoutDocxProp $_ 'Severity') } }, Id)) {
            $r++
            $bg = if ($r % 2 -eq 0) { $Script:ScoutDocxMist } else { $Script:ScoutDocxPaper }
            $sevLabel = Get-ScoutDocxSeverityLabel (Get-ScoutDocxProp $f 'Severity')
            $sevColor = Get-ScoutDocxSeverityColor (Get-ScoutDocxProp $f 'Severity')
            $cells = New-ScoutDocxList
            $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $f 'Id')" -WidthIn 1.3 -FillHex $bg))
            $cells.Add((New-ScoutDocxCell -Text $sevLabel -WidthIn 1.0 -Bold $true -Hex $Script:ScoutDocxPaper -FillHex $sevColor -Align 'center'))
            $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $f 'Status')" -WidthIn 1.0 -FillHex $bg -Align 'center'))
            $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $f 'Title')" -WidthIn 3.2 -FillHex $bg))
            $rows.Add((New-ScoutDocxRow -Cells $cells))
        }
        $Body.Append((New-ScoutDocxTable -ColWidthsIn @(1.3, 1.0, 1.0, 3.2) -Rows $rows))
        Add-ScoutDocxParagraph -Body $Body -Text ' ' -SizePt 4
    }
}

function Get-ScoutDocxEvidenceSummary {
    <#
    .SYNOPSIS
        The supporting number for one finding, as a short cell string.

    .DESCRIPTION
        AB#6862/AB#6892, clause W-14. The hard case is a finding with NO evidence, which Phase 0
        found on 42 of 57 failing controls. Those are not renderer failures: an `exists` rule
        fails precisely BECAUSE its query matched nothing, so there is no resource to name and
        there never will be.

        What such a row still owes the reader is the SCOPE -- what was looked for. "None found"
        beats an empty cell, because an empty cell is indistinguishable from a rule that never
        ran. Where the engine supplied a denominator (AB#6892), the row states "N of M", which is
        the reference deliverable's defining property.
    #>
    [OutputType([string])]
    param($Gap)

    $count = Get-ScoutDocxProp $Gap 'EvidenceCount'
    $denom = Get-ScoutDocxProp $Gap 'Denominator'

    if ($null -eq $count) { return '' }

    $n = 0
    try { $n = [int]$count } catch { return '' }

    # "17 of 198" -- only when the engine actually resolved a denominator. $null means the rule
    # has no denominator concept; 0 would be a claim that no candidates exist, which is different.
    if ($null -ne $denom) {
        $m = 0
        try { $m = [int]$denom } catch { $m = 0 }
        if ($m -gt 0) { return "$n of $m" }
    }

    if ($n -eq 0) { return 'None found' }
    if ($n -eq 1) { return '1 resource' }
    return "$n resources"
}

function New-ScoutDocxGapsSection {
    param($Body, $Gaps)

    Add-ScoutDocxHeading -Body $Body -Text 'Prioritized Gaps' -Level 1

    # @() wraps the whole pipeline for the same reason New-ScoutDocxAreaFindingsSection
    # wraps its Sort-Object above -- zero-input Sort-Object collapses to $null otherwise.
    $sorted = @(@($Gaps) | Sort-Object @{ Expression = { Get-ScoutDocxSeverityRank (Get-ScoutDocxProp $_ 'Severity') } }, Area)
    $top = @($sorted | Select-Object -First $Script:ScoutDocxMaxGaps)

    if ($top.Count -eq 0) {
        Add-ScoutDocxParagraph -Body $Body -Text 'No prioritized gaps — all assessed rules are passing.' -Hex $Script:ScoutDocxGreen
        return
    }

    # AB#6862/AB#6892, clause W-14. The table was Severity | Area | Gap and nothing else, so a
    # reader got a verdict with no supporting number and no resource to act on. Phase 0 measured
    # the consequence: 0 ARM ids in the whole document across three real tenants, and three
    # unrelated estates producing documents within 258 bytes of each other.
    #
    # The fourth column is the reference deliverable's defining property -- "60 of 198 storage
    # accounts", never "storage accounts are misconfigured".
    $rows = New-ScoutDocxList
    $header = New-ScoutDocxList
    foreach ($h in 'Severity', 'Area', 'Gap', 'Evidence') {
        $w = switch ($h) { 'Severity' { 1.0 } 'Area' { 1.4 } 'Gap' { 2.6 } default { 1.5 } }
        $header.Add((New-ScoutDocxCell -Text $h -WidthIn $w -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy))
    }
    $rows.Add((New-ScoutDocxRow -Cells $header -Header $true))

    $r = 0
    foreach ($gap in $top) {
        $r++
        $bg = if ($r % 2 -eq 0) { $Script:ScoutDocxMist } else { $Script:ScoutDocxPaper }
        $sevLabel = Get-ScoutDocxSeverityLabel (Get-ScoutDocxProp $gap 'Severity')
        $sevColor = Get-ScoutDocxSeverityColor (Get-ScoutDocxProp $gap 'Severity')
        $cells = New-ScoutDocxList
        $cells.Add((New-ScoutDocxCell -Text $sevLabel -WidthIn 1.0 -Bold $true -Hex $Script:ScoutDocxPaper -FillHex $sevColor -Align 'center'))
        $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $gap 'Area')" -WidthIn 1.4 -FillHex $bg))
        $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $gap 'Title')" -WidthIn 2.6 -FillHex $bg))
        $cells.Add((New-ScoutDocxCell -Text (Get-ScoutDocxEvidenceSummary $gap) -WidthIn 1.5 -FillHex $bg -SizePt 9))
        $rows.Add((New-ScoutDocxRow -Cells $cells))
    }
    $Body.Append((New-ScoutDocxTable -ColWidthsIn @(1.0, 1.4, 2.6, 1.5) -Rows $rows))

    $truncated = @($sorted).Count - $top.Count
    if ($truncated -gt 0) {
        Add-ScoutDocxParagraph -Body $Body -Text "+$truncated more not shown — see the evidence pack (Excel tier) for the full list." -SizePt 9 -Hex $Script:ScoutDocxGray -Italic $true
    }
}

function New-ScoutDocxManualSection {
    param($Body, $Manual)

    Add-ScoutDocxHeading -Body $Body -Text 'Manual Review Worklist' -Level 1

    $items = @($Manual)
    if ($items.Count -eq 0) {
        Add-ScoutDocxParagraph -Body $Body -Text 'No manual review items — full automated coverage for the selected assessment(s).' -Hex $Script:ScoutDocxGreen
        return
    }

    $shown = @($items | Select-Object -First $Script:ScoutDocxMaxManual)
    $rows = New-ScoutDocxList
    $header = New-ScoutDocxList
    $header.Add((New-ScoutDocxCell -Text 'Area' -WidthIn 2.0 -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy))
    $header.Add((New-ScoutDocxCell -Text 'Item' -WidthIn 4.5 -Hex $Script:ScoutDocxPaper -Bold $true -FillHex $Script:ScoutDocxNavy))
    $rows.Add((New-ScoutDocxRow -Cells $header -Header $true))

    $r = 0
    foreach ($m in $shown) {
        $r++
        $bg = if ($r % 2 -eq 0) { $Script:ScoutDocxMist } else { $Script:ScoutDocxPaper }
        $cells = New-ScoutDocxList
        $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $m 'Area')" -WidthIn 2.0 -FillHex $bg))
        $cells.Add((New-ScoutDocxCell -Text "$(Get-ScoutDocxProp $m 'Title')" -WidthIn 4.5 -FillHex $bg))
        $rows.Add((New-ScoutDocxRow -Cells $cells))
    }
    $Body.Append((New-ScoutDocxTable -ColWidthsIn @(2.0, 4.5) -Rows $rows))

    $truncated = $items.Count - $shown.Count
    if ($truncated -gt 0) {
        Add-ScoutDocxParagraph -Body $Body -Text "+$truncated more not shown — see the evidence pack (Excel tier) for the full list." -SizePt 9 -Hex $Script:ScoutDocxGray -Italic $true
    }
}

function New-ScoutDocxSectionProperties {
    # US Letter, portrait, 1" top/bottom, 0.75" left/right — twips (dxa) throughout.
    $sectPr = New-ScoutDocxEl "$Script:ScoutDocxWNs.SectionProperties"
    $pgSz = New-ScoutDocxEl "$Script:ScoutDocxWNs.PageSize"
    $pgSz.Width = [uint32](ScoutDocxDxa 8.5)
    $pgSz.Height = [uint32](ScoutDocxDxa 11)
    $sectPr.Append($pgSz)
    $pgMar = New-ScoutDocxEl "$Script:ScoutDocxWNs.PageMargin"
    $pgMar.Top = [int32](ScoutDocxDxa 1.0)
    $pgMar.Bottom = [int32](ScoutDocxDxa 1.0)
    $pgMar.Left = [uint32](ScoutDocxDxa 0.75)
    $pgMar.Right = [uint32](ScoutDocxDxa 0.75)
    $pgMar.Header = [uint32](ScoutDocxDxa 0.5)
    $pgMar.Footer = [uint32](ScoutDocxDxa 0.5)
    $pgMar.Gutter = [uint32]0
    $sectPr.Append($pgMar)
    return , $sectPr
}

#endregion

function Export-Word {
    <#
    .SYNOPSIS
        Renders the Word (.docx) assessment report for a scored Findings object.

    .PARAMETER Findings
        The scored object returned by Get-Score (GeneratedOn/Frameworks/Areas/
        Gaps/Manual/Errors/Findings).

    .PARAMETER Collect
        Optional — the raw collect object (same one Export-Html/-Excel/-Pptx
        already receive from Export-Report.ps1). Used only to surface scope /
        management-group context on the cover page when present.

    .PARAMETER OutputPath
        Directory the rendered assessment_report.docx is written into.
    #>
    param($Findings, $Collect, [string] $OutputPath)

    try {
        Import-ScoutDocxOpenXmlAssembly

        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        $outFile = Join-Path $OutputPath 'assessment_report.docx'
        if (Test-Path $outFile) { Remove-Item $outFile -Force }

        $frameworks = @(Get-ScoutDocxProp $Findings 'Frameworks')
        $areas = @(Get-ScoutDocxProp $Findings 'Areas')
        $gaps = @(Get-ScoutDocxProp $Findings 'Gaps')
        $manual = @(Get-ScoutDocxProp $Findings 'Manual')
        $errors = @(Get-ScoutDocxProp $Findings 'Errors')
        $allFindings = @(Get-ScoutDocxProp $Findings 'Findings')
        $generatedOn = Get-ScoutDocxProp $Findings 'GeneratedOn'
        $generatedText = if ($generatedOn) {
            try { ([datetime]$generatedOn).ToString('yyyy-MM-dd') } catch { "$generatedOn" }
        } else { (Get-Date).ToString('yyyy-MM-dd') }

        $scope = Get-ScoutDocxProp (Get-ScoutDocxProp $Collect '_meta') 'scope'
        $mgId = Get-ScoutDocxProp (Get-ScoutDocxProp $Collect '_meta') 'managementGroupId'
        $metaParts = [System.Collections.Generic.List[string]]::new()
        $metaParts.Add("Generated $generatedText")
        if ($scope) { $metaParts.Add("Scope: $scope") }
        if ($mgId) { $metaParts.Add("Management Group: $mgId") }
        $metaLine = [string]::Join('  ·  ', $metaParts)

        $doc = [DocumentFormat.OpenXml.Packaging.WordprocessingDocument]::Create($outFile, [DocumentFormat.OpenXml.WordprocessingDocumentType]::Document)
        $mainPart = $doc.AddMainDocumentPart()
        # AB#6874 (W-01). Added BEFORE the body is populated so every heading emitted below has a
        # style to reference. Phase 0 measured the absence of this part as the root formatting
        # defect -- no styles means no navigation pane, no TOC field, and no rebranding.
        $null = Add-ScoutDocxStyleDefinitions -MainPart $mainPart
        $mainPart.Document = New-ScoutDocxEl "$Script:ScoutDocxWNs.Document"
        $body = New-ScoutDocxEl "$Script:ScoutDocxWNs.Body"
        $mainPart.Document.Append($body)

        # ---- Cover ----
        New-ScoutDocxCoverParagraphs -Body $body -Title 'Azure Landing Zone Assessment' `
            -Subtitle 'Executive Assessment — CAF & WAF Alignment' -MetaLine $metaLine
        Add-ScoutDocxPageBreak -Body $body

        # ---- Executive Summary ----
        New-ScoutDocxExecSummary -Body $body -Frameworks $frameworks -Areas $areas -Gaps $gaps -Manual $manual -Errors $errors
        Add-ScoutDocxPageBreak -Body $body

        # ---- Findings by Area ----
        New-ScoutDocxAreaFindingsSection -Body $body -Areas $areas -AllFindings $allFindings
        Add-ScoutDocxPageBreak -Body $body

        # ---- Prioritized Gaps ----
        New-ScoutDocxGapsSection -Body $body -Gaps $gaps
        Add-ScoutDocxPageBreak -Body $body

        # ---- Manual Review Worklist ----
        New-ScoutDocxManualSection -Body $body -Manual $manual

        # ---- Section properties (must be the last child of w:body) ----
        $body.Append((New-ScoutDocxSectionProperties))

        $mainPart.Document.Save()
        $doc.Dispose()

        return $outFile
    }
    catch {
        Write-Warning "Export-Word: .docx generation failed ($_) -- writing an HTML fallback instead."
        return (Export-ScoutDocxHtmlFallback -Findings $Findings -Collect $Collect -OutputPath $OutputPath -Reason $_.Exception.Message)
    }
}
