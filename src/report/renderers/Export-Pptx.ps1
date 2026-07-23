#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Auto-assemble an executive PowerPoint deck from scored findings via the
    OpenXML SDK (DocumentFormat.OpenXml) — no Python, no PowerPoint install.

.DESCRIPTION
    Renders the Tier-3 executive deck directly from the scored Findings object
    (the output of Get-Score: GeneratedOn/Frameworks/Areas/Gaps/Manual/Errors/
    Findings). Every element of the .pptx OPC package (theme, slide master,
    slide layouts, slides, tables) is constructed programmatically with the
    OpenXML SDK — this is the accepted design in
    docs/design/decisions/pptx-renderer.md (AB#5044).

    Slide inventory:
      1. Title            — deck branding, generated date, scope/mgmt-group if known
      2. Executive Summary — CAF/WAF score cards + rollup counts
      3..N Area Breakdown  — Framework/Area/Score/Pass/Partial/Fail/Manual table,
                             paginated at 10 rows/slide
      N+1.. Prioritized Gaps — Severity/Area/Gap table, sorted worst-first,
                             paginated at 10 rows/slide, capped at top 15
      .. Manual Review     — outstanding manual-review worklist (capped at 12 rows)
      .. Next Steps        — closing recommendations

    TEMPLATE-AS-CODE EXTENSION POINT: the theme/master/layout/chrome built by
    New-ScoutDeckShell and Add-ScoutSlideChrome below is the programmatic
    stand-in for a designer-authored deck.pptx.template (see the decision
    record's amendment). A future iteration can replace this function pair
    with code that opens a designer-authored .pptx template and clones its
    slide master/layout parts instead of building them from scratch here —
    every other function in this file (the slide-content builders) is
    unaffected by that swap, since they only depend on the shell exposing a
    content SlideLayoutPart + title SlideLayoutPart relationship ids.

.NOTES
    Tracks ADO Story AB#5048, Epic AB#5044. Carries forward the AB#5089
    defensive severity guard from the retired build_deck.py (null/unknown
    severity sorts LAST and never throws — see Get-ScoutSeverityRank/-Label).
#>

#region Assembly acquisition (first-use NuGet acquire + cache, no committed binaries)

# Pinned so every run resolves the exact same OpenXML SDK build; bump deliberately.
$Script:ScoutOpenXmlVersion = '3.0.2'

function Import-ScoutOpenXmlAssembly {
    [CmdletBinding()]
    param()

    # Idempotent within a process — a prior Export-Pptx call (or Pester run)
    # in the same pwsh session already loaded these.
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'DocumentFormat.OpenXml' }
    if ($loaded) { return }

    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $cacheDir = Join-Path $repoRoot 'output' '.tools' 'openxml' $Script:ScoutOpenXmlVersion
    $requiredDlls = @('DocumentFormat.OpenXml.Framework.dll', 'System.IO.Packaging.dll', 'DocumentFormat.OpenXml.dll')

    $haveAll = -not ($requiredDlls | Where-Object { -not (Test-Path (Join-Path $cacheDir $_)) })
    if (-not $haveAll) {
        if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            throw "Export-Pptx: DocumentFormat.OpenXml $($Script:ScoutOpenXmlVersion) is not cached at '$cacheDir' and the 'dotnet' SDK is not on PATH to acquire it. Install the .NET SDK (or pre-seed the cache folder with the three DLLs above) and retry."
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
    <PackageReference Include="DocumentFormat.OpenXml" Version="$($Script:ScoutOpenXmlVersion)" />
  </ItemGroup>
</Project>
"@ | Out-File -FilePath $tempProj -Encoding utf8

        Write-Host "[Export-Pptx] Acquiring DocumentFormat.OpenXml $($Script:ScoutOpenXmlVersion) via dotnet/NuGet (first use — cached under $cacheDir for subsequent runs)..." -ForegroundColor Cyan
        $buildOutput = & dotnet build $tempProj -c Release -o $cacheDir --nologo 2>&1
        $exitCode = $LASTEXITCODE
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem $cacheDir -Filter 'acquire.*' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

        if ($exitCode -ne 0 -or -not (Test-Path (Join-Path $cacheDir 'DocumentFormat.OpenXml.dll'))) {
            throw "Export-Pptx: could not acquire DocumentFormat.OpenXml $($Script:ScoutOpenXmlVersion) (offline, and nothing cached at '$cacheDir'?). dotnet build exit code $exitCode.`n$($buildOutput -join "`n")"
        }
        Write-Host "[Export-Pptx] DocumentFormat.OpenXml $($Script:ScoutOpenXmlVersion) cached at $cacheDir" -ForegroundColor Green
    }

    foreach ($dll in $requiredDlls) {
        Add-Type -Path (Join-Path $cacheDir $dll) -ErrorAction Stop
    }
}

#endregion

#region Low-level OpenXML element/part helpers
#
# IMPORTANT: every OpenXmlElement in this SDK implements IEnumerable<OpenXmlElement>
# over its own children. PowerShell's function-output pipeline auto-enumerates any
# IEnumerable it sees, so a bare "return $element" silently flattens the element
# into its (often zero) children instead of returning the element itself. Every
# helper below returns via the unary comma operator (`return ,$x`) to suppress
# that unrolling — do not remove the commas.
#
# For the same reason, never build an array of OpenXmlElement objects with `@(...)`
# or a bare comma list — use New-ScoutList + .Add(), which is a plain .NET method
# call and is not subject to pipeline enumeration.

$Script:PresNs = 'DocumentFormat.OpenXml.Presentation'
$Script:DrawNs = 'DocumentFormat.OpenXml.Drawing'

function New-ScoutEl {
    param([Parameter(Mandatory)][string]$TypeName)
    $o = New-Object -TypeName $TypeName
    return , $o
}

function New-ScoutList {
    return , ([System.Collections.Generic.List[object]]::new())
}

function New-ScoutPart {
    # Wraps the generic OpenXmlPartContainer.AddNewPart<T>(string id) method,
    # which PowerShell cannot call with normal method-call syntax.
    param($Parent, [Parameter(Mandatory)][type]$PartType, [Parameter(Mandatory)][string]$Id)
    $mi = $Parent.GetType().GetMethods() | Where-Object {
        $_.Name -eq 'AddNewPart' -and $_.IsGenericMethodDefinition -and
        $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType -eq [string]
    } | Select-Object -First 1
    if (-not $mi) { throw "Export-Pptx: could not locate generic AddNewPart<T> on $($Parent.GetType().FullName)." }
    $gmi = $mi.MakeGenericMethod($PartType)
    $part = $gmi.Invoke($Parent, @($Id))
    return , $part
}

function ScoutEmu {
    # EMU (English Metric Units), 914400 per inch. Int64 — used for a:off/a:ext,
    # table row heights and grid column widths (ST_PositiveCoordinate).
    param([double]$Inches)
    return [int64][math]::Round($Inches * 914400)
}

function ScoutEmu32 {
    # Int32 EMU — required specifically by p:sldSz / p:notesSz (ST_PositiveCoordinate32).
    param([double]$Inches)
    return [int32][math]::Round($Inches * 914400)
}

#endregion

#region Fill / text / table-cell helpers

function New-ScoutFill {
    param([Parameter(Mandatory)][string]$Hex)
    $fill = New-ScoutEl "$Script:DrawNs.SolidFill"
    $rgb = New-ScoutEl "$Script:DrawNs.RgbColorModelHex"
    $rgb.Val = $Hex
    $fill.Append($rgb)
    return , $fill
}

function New-ScoutPhColor {
    # Placeholder scheme-color reference used inside a theme's FormatScheme
    # boilerplate (fill/line/effect/background style lists).
    $sc = New-ScoutEl "$Script:DrawNs.SchemeColor"
    $sc.Val = [DocumentFormat.OpenXml.Drawing.SchemeColorValues]::PhColor
    return , $sc
}

function New-ScoutRun {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [double]$SizePt = 12,
        [string]$Hex = '1A1A1A',
        [bool]$Bold = $false,
        [string]$Font = 'Segoe UI'
    )
    $run = New-ScoutEl "$Script:DrawNs.Run"
    $rPr = New-ScoutEl "$Script:DrawNs.RunProperties"
    $rPr.Language = 'en-US'
    $rPr.FontSize = [int]([math]::Round($SizePt * 100))
    $rPr.Bold = $Bold
    $rPr.Append((New-ScoutFill $Hex))
    $latin = New-ScoutEl "$Script:DrawNs.LatinFont"
    $latin.Typeface = $Font
    $rPr.Append($latin)
    $run.Append($rPr)
    $t = New-ScoutEl "$Script:DrawNs.Text"
    $t.Text = $Text
    $run.Append($t)
    return , $run
}

function New-ScoutPara {
    # $Runs: a List[object] of Drawing.Run elements (built with New-ScoutList/.Add()).
    param($Runs, [string]$Align = $null, [double]$SpaceBeforePt = 0)
    $p = New-ScoutEl "$Script:DrawNs.Paragraph"
    if ($Align -or $SpaceBeforePt -gt 0) {
        $pPr = New-ScoutEl "$Script:DrawNs.ParagraphProperties"
        if ($Align) {
            $pPr.Alignment = switch ($Align) {
                'ctr' { [DocumentFormat.OpenXml.Drawing.TextAlignmentTypeValues]::Center }
                'r' { [DocumentFormat.OpenXml.Drawing.TextAlignmentTypeValues]::Right }
                default { [DocumentFormat.OpenXml.Drawing.TextAlignmentTypeValues]::Left }
            }
        }
        if ($SpaceBeforePt -gt 0) {
            $spcBef = New-ScoutEl "$Script:DrawNs.SpaceBefore"
            $spcPts = New-ScoutEl "$Script:DrawNs.SpacingPoints"
            $spcPts.Val = [int]([math]::Round($SpaceBeforePt * 100))
            $spcBef.Append($spcPts)
            $pPr.Append($spcBef)
        }
        $p.Append($pPr)
    }
    foreach ($r in $Runs) { $p.Append($r) }
    return , $p
}

function New-ScoutShapeTextBody {
    # $Paragraphs: a List[object] of Drawing.Paragraph — wrapped for a p:sp (shape).
    param($Paragraphs, [string]$Anchor = 't', [bool]$Wrap = $true)
    $tb = New-ScoutEl "$Script:PresNs.TextBody"
    $bp = New-ScoutEl "$Script:DrawNs.BodyProperties"
    $bp.Wrap = if ($Wrap) { [DocumentFormat.OpenXml.Drawing.TextWrappingValues]::Square } else { [DocumentFormat.OpenXml.Drawing.TextWrappingValues]::None }
    $bp.Anchor = switch ($Anchor) {
        'ctr' { [DocumentFormat.OpenXml.Drawing.TextAnchoringTypeValues]::Center }
        'b' { [DocumentFormat.OpenXml.Drawing.TextAnchoringTypeValues]::Bottom }
        default { [DocumentFormat.OpenXml.Drawing.TextAnchoringTypeValues]::Top }
    }
    $tb.Append($bp)
    $tb.Append((New-ScoutEl "$Script:DrawNs.ListStyle"))
    foreach ($p in $Paragraphs) { $tb.Append($p) }
    return , $tb
}

function New-ScoutCellTextBody {
    # $Paragraphs: a List[object] of Drawing.Paragraph — wrapped for an a:tc (table cell).
    param($Paragraphs)
    $tb = New-ScoutEl "$Script:DrawNs.TextBody"
    $tb.Append((New-ScoutEl "$Script:DrawNs.BodyProperties"))
    $tb.Append((New-ScoutEl "$Script:DrawNs.ListStyle"))
    foreach ($p in $Paragraphs) { $tb.Append($p) }
    return , $tb
}

#endregion

#region Shape / table builders

$Script:ScoutShapeId = 10

function New-ScoutShape {
    # A rectangle or rounded rectangle with optional fill and text content —
    # the one shape primitive every slide/card/label in this deck is built from.
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][double]$X, [Parameter(Mandatory)][double]$Y,
        [Parameter(Mandatory)][double]$Cx, [Parameter(Mandatory)][double]$Cy,
        [string]$FillHex = $null,
        $Paragraphs,
        [string]$Anchor = 't',
        [double]$RadiusPct = 0
    )
    $Script:ScoutShapeId++
    $sh = New-ScoutEl "$Script:PresNs.Shape"

    $nvSp = New-ScoutEl "$Script:PresNs.NonVisualShapeProperties"
    $cnv = New-ScoutEl "$Script:PresNs.NonVisualDrawingProperties"
    $cnv.Id = [uint32]$Script:ScoutShapeId
    $cnv.Name = $Name
    $nvSp.Append($cnv)
    $nvSp.Append((New-ScoutEl "$Script:PresNs.NonVisualShapeDrawingProperties"))
    $nvSp.Append((New-ScoutEl "$Script:PresNs.ApplicationNonVisualDrawingProperties"))
    $sh.Append($nvSp)

    $spPr = New-ScoutEl "$Script:PresNs.ShapeProperties"
    $xfrm = New-ScoutEl "$Script:DrawNs.Transform2D"
    $off = New-ScoutEl "$Script:DrawNs.Offset"; $off.X = (ScoutEmu $X); $off.Y = (ScoutEmu $Y)
    $ext = New-ScoutEl "$Script:DrawNs.Extents"; $ext.Cx = (ScoutEmu $Cx); $ext.Cy = (ScoutEmu $Cy)
    $xfrm.Append($off); $xfrm.Append($ext)
    $spPr.Append($xfrm)

    $geom = New-ScoutEl "$Script:DrawNs.PresetGeometry"
    $geom.Preset = if ($RadiusPct -gt 0) {
        [DocumentFormat.OpenXml.Drawing.ShapeTypeValues]::RoundRectangle
    } else {
        [DocumentFormat.OpenXml.Drawing.ShapeTypeValues]::Rectangle
    }
    $avLst = New-ScoutEl "$Script:DrawNs.AdjustValueList"
    if ($RadiusPct -gt 0) {
        $av = New-ScoutEl "$Script:DrawNs.ShapeGuide"
        $av.Name = 'adj'
        $av.Formula = "val $([int]($RadiusPct * 1000))"
        $avLst.Append($av)
    }
    $geom.Append($avLst)
    $spPr.Append($geom)

    if ($FillHex) { $spPr.Append((New-ScoutFill $FillHex)) }
    else { $spPr.Append((New-ScoutEl "$Script:DrawNs.NoFill")) }
    $noLineOutline = New-ScoutEl "$Script:DrawNs.Outline"
    $noLineOutline.Append((New-ScoutEl "$Script:DrawNs.NoFill"))
    $spPr.Append($noLineOutline)
    $sh.Append($spPr)

    if ($Paragraphs) { $sh.Append((New-ScoutShapeTextBody -Paragraphs $Paragraphs -Anchor $Anchor)) }
    return , $sh
}

function New-ScoutTableCell {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [double]$SizePt = 11,
        [string]$Hex = '1A1A1A',
        [bool]$Bold = $false,
        [string]$FillHex = 'FFFFFF',
        [string]$Align = $null
    )
    $tc = New-ScoutEl "$Script:DrawNs.TableCell"
    $runs = New-ScoutList
    $runs.Add((New-ScoutRun -Text $Text -SizePt $SizePt -Hex $Hex -Bold $Bold))
    $paras = New-ScoutList
    $paras.Add((New-ScoutPara -Runs $runs -Align $Align))
    $tc.Append((New-ScoutCellTextBody $paras))

    $tcPr = New-ScoutEl "$Script:DrawNs.TableCellProperties"
    $tcPr.Anchor = [DocumentFormat.OpenXml.Drawing.TextAnchoringTypeValues]::Center
    $tcPr.LeftMargin = [int32](ScoutEmu 0.08)
    $tcPr.RightMargin = [int32](ScoutEmu 0.08)
    $tcPr.TopMargin = [int32](ScoutEmu 0.02)
    $tcPr.BottomMargin = [int32](ScoutEmu 0.02)
    if ($FillHex) { $tcPr.Append((New-ScoutFill $FillHex)) }
    $tc.Append($tcPr)
    return , $tc
}

function New-ScoutTableRow {
    param([double]$HeightIn, $Cells)
    $row = New-ScoutEl "$Script:DrawNs.TableRow"
    $row.Height = (ScoutEmu $HeightIn)
    foreach ($c in $Cells) { $row.Append($c) }
    return , $row
}

function New-ScoutTable {
    # $ColWidthsIn: double[] of column widths in inches.
    # $Rows: List[object] of Drawing.TableRow (header row typically at index 0).
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][double]$X, [Parameter(Mandatory)][double]$Y,
        [Parameter(Mandatory)][double[]]$ColWidthsIn,
        [Parameter(Mandatory)]$Rows
    )
    $Script:ScoutShapeId++
    $gf = New-ScoutEl "$Script:PresNs.GraphicFrame"

    $nvGfp = New-ScoutEl "$Script:PresNs.NonVisualGraphicFrameProperties"
    $cnv = New-ScoutEl "$Script:PresNs.NonVisualDrawingProperties"
    $cnv.Id = [uint32]$Script:ScoutShapeId
    $cnv.Name = $Name
    $nvGfp.Append($cnv)
    $locks = New-ScoutEl "$Script:DrawNs.GraphicFrameLocks"; $locks.NoGrouping = $true
    $nvGfdp = New-ScoutEl "$Script:PresNs.NonVisualGraphicFrameDrawingProperties"
    $nvGfdp.Append($locks)
    $nvGfp.Append($nvGfdp)
    $nvGfp.Append((New-ScoutEl "$Script:PresNs.ApplicationNonVisualDrawingProperties"))
    $gf.Append($nvGfp)

    $totalWidth = ($ColWidthsIn | Measure-Object -Sum).Sum
    $totalHeight = 0.0
    foreach ($r in $Rows) { $totalHeight += ([double]$r.Height.Value / 914400.0) }

    $xfrm = New-ScoutEl "$Script:PresNs.Transform"
    $off = New-ScoutEl "$Script:DrawNs.Offset"; $off.X = (ScoutEmu $X); $off.Y = (ScoutEmu $Y)
    $ext = New-ScoutEl "$Script:DrawNs.Extents"; $ext.Cx = (ScoutEmu $totalWidth); $ext.Cy = (ScoutEmu $totalHeight)
    $xfrm.Append($off); $xfrm.Append($ext)
    $gf.Append($xfrm)

    $graphic = New-ScoutEl "$Script:DrawNs.Graphic"
    $graphicData = New-ScoutEl "$Script:DrawNs.GraphicData"
    $graphicData.Uri = 'http://schemas.openxmlformats.org/drawingml/2006/table'

    $table = New-ScoutEl "$Script:DrawNs.Table"
    $tblPr = New-ScoutEl "$Script:DrawNs.TableProperties"
    $tblPr.FirstRow = $true
    $tblPr.BandRow = $true
    $table.Append($tblPr)

    $grid = New-ScoutEl "$Script:DrawNs.TableGrid"
    foreach ($w in $ColWidthsIn) {
        $gc = New-ScoutEl "$Script:DrawNs.GridColumn"
        $gc.Width = (ScoutEmu $w)
        $grid.Append($gc)
    }
    $table.Append($grid)
    foreach ($r in $Rows) { $table.Append($r) }

    $graphicData.Append($table)
    $graphic.Append($graphicData)
    $gf.Append($graphic)

    return , $gf
}

#endregion

#region Data helpers (safe property access, score/severity bands, pagination)

function Get-ScoutProp {
    param($Obj, [Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($null -eq $Obj) { return $Default }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $Default }
}

function Get-ScoutScoreColor {
    param($Score)
    if ($null -eq $Score) { return '595959' }
    if ($Score -ge 80) { return '2E7D32' }
    if ($Score -ge 50) { return 'B8860B' }
    return 'B00020'
}

$Script:ScoutSeverityRank = @{ high = 0; medium = 1; low = 2 }

function Get-ScoutSeverityRank {
    # AB#5089: null/missing/unrecognized severity sorts LAST, never throws.
    param($Severity)
    if ($Severity) {
        $key = $Severity.ToString().Trim().ToLowerInvariant()
        if ($Script:ScoutSeverityRank.ContainsKey($key)) { return $Script:ScoutSeverityRank[$key] }
    }
    return 99
}

function Get-ScoutSeverityLabel {
    # AB#5089 companion: always renders a label, never crashes on null/blank.
    param($Severity)
    if ($Severity -and "$Severity".Trim()) { return "$Severity".ToUpperInvariant() }
    return 'UNKNOWN'
}

function Get-ScoutSeverityColor {
    param($Severity)
    if (-not $Severity) { return '595959' }
    switch ($Severity.ToString().Trim().ToLowerInvariant()) {
        'high' { return 'B00020' }
        'medium' { return 'B8860B' }
        'low' { return '2E75B6' }
        default { return '595959' }
    }
}

function Split-ScoutChunks {
    param([array]$Items, [int]$Size)
    $chunks = [System.Collections.Generic.List[object]]::new()
    if (-not $Items -or $Items.Count -eq 0) { return $chunks }
    for ($i = 0; $i -lt $Items.Count; $i += $Size) {
        $endIdx = [Math]::Min($i + $Size, $Items.Count) - 1
        $chunks.Add(@($Items[$i..$endIdx]))
    }
    return $chunks
}

#endregion

#region Palette

$Script:Navy = '1F4E78'
$Script:Steel = '2E75B6'
$Script:Green = '2E7D32'
$Script:Gold = 'B8860B'
$Script:Red = 'B00020'
$Script:Ink = '1A1A1A'
$Script:Paper = 'FFFFFF'
$Script:Mist = 'F6F9FD'
$Script:Line = 'E2E2E2'
$Script:Gray = '595959'

$Script:SlideWIn = 13.333
$Script:SlideHIn = 7.5

#endregion

#region Deck shell — theme, slide master, two slide layouts (title-as-code template)

function New-ScoutDeckShell {
    param([Parameter(Mandatory)][string]$OutFile)

    if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
    $doc = [DocumentFormat.OpenXml.Packaging.PresentationDocument]::Create($OutFile, [DocumentFormat.OpenXml.PresentationDocumentType]::Presentation)
    $presPart = $doc.AddPresentationPart()
    $presPart.Presentation = New-ScoutEl "$Script:PresNs.Presentation"

    function New-ScoutEmptyShapeTree {
        $tree = New-ScoutEl "$Script:PresNs.ShapeTree"
        $nvGrp = New-ScoutEl "$Script:PresNs.NonVisualGroupShapeProperties"
        $cnv = New-ScoutEl "$Script:PresNs.NonVisualDrawingProperties"
        $cnv.Id = [uint32]1
        $cnv.Name = ''
        $nvGrp.Append($cnv)
        $nvGrp.Append((New-ScoutEl "$Script:PresNs.NonVisualGroupShapeDrawingProperties"))
        $nvGrp.Append((New-ScoutEl "$Script:PresNs.ApplicationNonVisualDrawingProperties"))
        $tree.Append($nvGrp)
        $tree.Append((New-ScoutEl "$Script:PresNs.GroupShapeProperties"))
        return , $tree
    }

    # ---- Slide master ----
    $masterPart = New-ScoutPart $presPart ([DocumentFormat.OpenXml.Packaging.SlideMasterPart]) 'rIdMaster1'
    $master = New-ScoutEl "$Script:PresNs.SlideMaster"
    $mcsd = New-ScoutEl "$Script:PresNs.CommonSlideData"
    $mcsd.Append((New-ScoutEmptyShapeTree))
    $master.Append($mcsd)

    $cm = New-ScoutEl "$Script:PresNs.ColorMap"
    $cm.Background1 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Light1
    $cm.Text1 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Dark1
    $cm.Background2 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Light2
    $cm.Text2 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Dark2
    $cm.Accent1 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent1
    $cm.Accent2 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent2
    $cm.Accent3 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent3
    $cm.Accent4 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent4
    $cm.Accent5 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent5
    $cm.Accent6 = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Accent6
    $cm.Hyperlink = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::Hyperlink
    $cm.FollowedHyperlink = [DocumentFormat.OpenXml.Drawing.ColorSchemeIndexValues]::FollowedHyperlink
    $master.Append($cm)

    $sliList = New-ScoutEl "$Script:PresNs.SlideLayoutIdList"
    $sliTitle = New-ScoutEl "$Script:PresNs.SlideLayoutId"; $sliTitle.Id = [uint32]2147483649; $sliTitle.RelationshipId = 'rIdLayoutTitle'
    $sliContent = New-ScoutEl "$Script:PresNs.SlideLayoutId"; $sliContent.Id = [uint32]2147483650; $sliContent.RelationshipId = 'rIdLayoutContent'
    $sliList.Append($sliTitle); $sliList.Append($sliContent)
    $master.Append($sliList)

    $ts = New-ScoutEl "$Script:PresNs.TextStyles"
    $ts.Append((New-ScoutEl "$Script:PresNs.TitleStyle"))
    $ts.Append((New-ScoutEl "$Script:PresNs.BodyStyle"))
    $ts.Append((New-ScoutEl "$Script:PresNs.OtherStyle"))
    $master.Append($ts)
    $masterPart.SlideMaster = $master

    # ---- Slide layouts (title + content) ----
    $layoutTitlePart = New-ScoutPart $masterPart ([DocumentFormat.OpenXml.Packaging.SlideLayoutPart]) 'rIdLayoutTitle'
    $layoutTitle = New-ScoutEl "$Script:PresNs.SlideLayout"
    $layoutTitle.Type = [DocumentFormat.OpenXml.Presentation.SlideLayoutValues]::Title
    $ltCsd = New-ScoutEl "$Script:PresNs.CommonSlideData"
    $ltCsd.Name = 'Azure Scout Title'
    $ltCsd.Append((New-ScoutEmptyShapeTree))
    $layoutTitle.Append($ltCsd)
    $ltCmo = New-ScoutEl "$Script:PresNs.ColorMapOverride"; $ltCmo.Append((New-ScoutEl "$Script:DrawNs.MasterColorMapping"))
    $layoutTitle.Append($ltCmo)
    $layoutTitlePart.SlideLayout = $layoutTitle

    $layoutContentPart = New-ScoutPart $masterPart ([DocumentFormat.OpenXml.Packaging.SlideLayoutPart]) 'rIdLayoutContent'
    $layoutContent = New-ScoutEl "$Script:PresNs.SlideLayout"
    $layoutContent.Type = [DocumentFormat.OpenXml.Presentation.SlideLayoutValues]::Text
    $lcCsd = New-ScoutEl "$Script:PresNs.CommonSlideData"
    $lcCsd.Name = 'Azure Scout Content'
    $lcCsd.Append((New-ScoutEmptyShapeTree))
    $layoutContent.Append($lcCsd)
    $lcCmo = New-ScoutEl "$Script:PresNs.ColorMapOverride"; $lcCmo.Append((New-ScoutEl "$Script:DrawNs.MasterColorMapping"))
    $layoutContent.Append($lcCmo)
    $layoutContentPart.SlideLayout = $layoutContent

    # ---- Theme (navy/steel/gold corporate palette, matches report.html.template) ----
    $themePart = New-ScoutPart $masterPart ([DocumentFormat.OpenXml.Packaging.ThemePart]) 'rIdTheme1'
    $theme = New-ScoutEl "$Script:DrawNs.Theme"
    $theme.Name = 'Azure Scout'

    $colorScheme = New-ScoutEl "$Script:DrawNs.ColorScheme"
    $colorScheme.Name = 'Azure Scout'
    $dk1 = New-ScoutEl "$Script:DrawNs.Dark1Color"
    $sysDk = New-ScoutEl "$Script:DrawNs.SystemColor"; $sysDk.Val = [DocumentFormat.OpenXml.Drawing.SystemColorValues]::WindowText; $sysDk.LastColor = $Script:Ink
    $dk1.Append($sysDk)
    $lt1 = New-ScoutEl "$Script:DrawNs.Light1Color"
    $sysLt = New-ScoutEl "$Script:DrawNs.SystemColor"; $sysLt.Val = [DocumentFormat.OpenXml.Drawing.SystemColorValues]::Window; $sysLt.LastColor = $Script:Paper
    $lt1.Append($sysLt)
    $dk2 = New-ScoutEl "$Script:DrawNs.Dark2Color"; $dk2.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex"))
    $dk2.RgbColorModelHex.Val = $Script:Navy
    $lt2 = New-ScoutEl "$Script:DrawNs.Light2Color"; $lt2.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex"))
    $lt2.RgbColorModelHex.Val = $Script:Mist
    $a1 = New-ScoutEl "$Script:DrawNs.Accent1Color"; $a1.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a1.RgbColorModelHex.Val = $Script:Navy
    $a2 = New-ScoutEl "$Script:DrawNs.Accent2Color"; $a2.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a2.RgbColorModelHex.Val = $Script:Steel
    $a3 = New-ScoutEl "$Script:DrawNs.Accent3Color"; $a3.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a3.RgbColorModelHex.Val = $Script:Green
    $a4 = New-ScoutEl "$Script:DrawNs.Accent4Color"; $a4.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a4.RgbColorModelHex.Val = $Script:Gold
    $a5 = New-ScoutEl "$Script:DrawNs.Accent5Color"; $a5.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a5.RgbColorModelHex.Val = $Script:Red
    $a6 = New-ScoutEl "$Script:DrawNs.Accent6Color"; $a6.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $a6.RgbColorModelHex.Val = $Script:Gray
    $hl = New-ScoutEl "$Script:DrawNs.Hyperlink"; $hl.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $hl.RgbColorModelHex.Val = $Script:Steel
    $fhl = New-ScoutEl "$Script:DrawNs.FollowedHyperlinkColor"; $fhl.Append((New-ScoutEl "$Script:DrawNs.RgbColorModelHex")); $fhl.RgbColorModelHex.Val = $Script:Navy
    $colorScheme.Append($dk1, $lt1, $dk2, $lt2, $a1, $a2, $a3, $a4, $a5, $a6, $hl, $fhl)

    $fontScheme = New-ScoutEl "$Script:DrawNs.FontScheme"
    $fontScheme.Name = 'Azure Scout'
    $majorFont = New-ScoutEl "$Script:DrawNs.MajorFont"
    $majorLatin = New-ScoutEl "$Script:DrawNs.LatinFont"; $majorLatin.Typeface = 'Segoe UI Semibold'
    $majorFont.Append($majorLatin); $majorFont.Append((New-ScoutEl "$Script:DrawNs.EastAsianFont")); $majorFont.Append((New-ScoutEl "$Script:DrawNs.ComplexScriptFont"))
    $minorFont = New-ScoutEl "$Script:DrawNs.MinorFont"
    $minorLatin = New-ScoutEl "$Script:DrawNs.LatinFont"; $minorLatin.Typeface = 'Segoe UI'
    $minorFont.Append($minorLatin); $minorFont.Append((New-ScoutEl "$Script:DrawNs.EastAsianFont")); $minorFont.Append((New-ScoutEl "$Script:DrawNs.ComplexScriptFont"))
    $fontScheme.Append($majorFont, $minorFont)

    $fmtScheme = New-ScoutEl "$Script:DrawNs.FormatScheme"
    $fmtScheme.Name = 'Azure Scout'
    $fillList = New-ScoutEl "$Script:DrawNs.FillStyleList"
    1..3 | ForEach-Object { $s = New-ScoutEl "$Script:DrawNs.SolidFill"; $s.Append((New-ScoutPhColor)); $fillList.Append($s) }
    $lineList = New-ScoutEl "$Script:DrawNs.LineStyleList"
    1..3 | ForEach-Object {
        $ol = New-ScoutEl "$Script:DrawNs.Outline"; $ol.Width = 9525
        $olFill = New-ScoutEl "$Script:DrawNs.SolidFill"; $olFill.Append((New-ScoutPhColor))
        $ol.Append($olFill)
        $lineList.Append($ol)
    }
    $effList = New-ScoutEl "$Script:DrawNs.EffectStyleList"
    1..3 | ForEach-Object { $es = New-ScoutEl "$Script:DrawNs.EffectStyle"; $es.Append((New-ScoutEl "$Script:DrawNs.EffectList")); $effList.Append($es) }
    $bgList = New-ScoutEl "$Script:DrawNs.BackgroundFillStyleList"
    1..3 | ForEach-Object { $s = New-ScoutEl "$Script:DrawNs.SolidFill"; $s.Append((New-ScoutPhColor)); $bgList.Append($s) }
    $fmtScheme.Append($fillList, $lineList, $effList, $bgList)

    $themeElements = New-ScoutEl "$Script:DrawNs.ThemeElements"
    $themeElements.Append($colorScheme, $fontScheme, $fmtScheme)
    $theme.Append($themeElements)
    $theme.Append((New-ScoutEl "$Script:DrawNs.ObjectDefaults"))
    $theme.Append((New-ScoutEl "$Script:DrawNs.ExtraColorSchemeList"))
    $themePart.Theme = $theme

    return [pscustomobject]@{
        Doc                = $doc
        PresPart           = $presPart
        MasterPart         = $masterPart
        LayoutTitlePart    = $layoutTitlePart
        LayoutContentPart  = $layoutContentPart
        NextSlideRelIdNum  = 1
        NextSlideIdNum     = 256
    }
}

#endregion

#region Slide chrome + slide assembly

function Add-ScoutSlideChrome {
    # Appends the shared navy-bar / title / gold-underline / footer shapes
    # that make every content slide read as one consistent template.
    param($Tree, [string]$Title, [int]$PageNum, [int]$TotalPages)

    $bar = New-ScoutShape -Name 'TopBar' -X 0 -Y 0 -Cx $Script:SlideWIn -Cy 0.09 -FillHex $Script:Navy
    $Tree.Append($bar)

    $titleParas = New-ScoutList
    $titleRuns = New-ScoutList
    $titleRuns.Add((New-ScoutRun -Text $Title -SizePt 26 -Hex $Script:Navy -Bold $true -Font 'Segoe UI Semibold'))
    $titleParas.Add((New-ScoutPara -Runs $titleRuns))
    $titleShape = New-ScoutShape -Name 'SlideTitle' -X 0.55 -Y 0.26 -Cx 12.2 -Cy 0.62 -Paragraphs $titleParas
    $Tree.Append($titleShape)

    $underline = New-ScoutShape -Name 'TitleUnderline' -X 0.55 -Y 0.92 -Cx 1.1 -Cy 0.045 -FillHex $Script:Gold
    $Tree.Append($underline)

    $divider = New-ScoutShape -Name 'FooterDivider' -X 0.55 -Y 7.02 -Cx 12.23 -Cy 0.012 -FillHex $Script:Line
    $Tree.Append($divider)

    $wmParas = New-ScoutList
    $wmRuns = New-ScoutList
    $wmRuns.Add((New-ScoutRun -Text 'AZURE SCOUT' -SizePt 9 -Hex $Script:Gray -Bold $true))
    $wmParas.Add((New-ScoutPara -Runs $wmRuns))
    $wordmark = New-ScoutShape -Name 'FooterWordmark' -X 0.55 -Y 7.09 -Cx 4 -Cy 0.3 -Paragraphs $wmParas
    $Tree.Append($wordmark)

    if ($PageNum -gt 0) {
        $pgParas = New-ScoutList
        $pgRuns = New-ScoutList
        $pgRuns.Add((New-ScoutRun -Text "$PageNum / $TotalPages" -SizePt 9 -Hex $Script:Gray))
        $pgParas.Add((New-ScoutPara -Runs $pgRuns -Align 'r'))
        $pgShape = New-ScoutShape -Name 'FooterPage' -X 10.78 -Y 7.09 -Cx 2 -Cy 0.3 -Paragraphs $pgParas
        $Tree.Append($pgShape)
    }
}

function New-ScoutEmptyShapeTreeStandalone {
    # Same structure as the shell's private helper, exposed here for slide bodies.
    $tree = New-ScoutEl "$Script:PresNs.ShapeTree"
    $nvGrp = New-ScoutEl "$Script:PresNs.NonVisualGroupShapeProperties"
    $cnv = New-ScoutEl "$Script:PresNs.NonVisualDrawingProperties"
    $cnv.Id = [uint32]1
    $cnv.Name = ''
    $nvGrp.Append($cnv)
    $nvGrp.Append((New-ScoutEl "$Script:PresNs.NonVisualGroupShapeDrawingProperties"))
    $nvGrp.Append((New-ScoutEl "$Script:PresNs.ApplicationNonVisualDrawingProperties"))
    $tree.Append($nvGrp)
    $tree.Append((New-ScoutEl "$Script:PresNs.GroupShapeProperties"))
    return , $tree
}

function New-ScoutSlideElement {
    param($Tree)
    $slide = New-ScoutEl "$Script:PresNs.Slide"
    $scsd = New-ScoutEl "$Script:PresNs.CommonSlideData"
    $scsd.Append($Tree)
    $slide.Append($scsd)
    $cmo = New-ScoutEl "$Script:PresNs.ColorMapOverride"
    $cmo.Append((New-ScoutEl "$Script:DrawNs.MasterColorMapping"))
    $slide.Append($cmo)
    return , $slide
}

function Add-ScoutSlideToDeck {
    # Creates the SlidePart for a fully-built Slide element, wires it to the
    # given layout part, and registers it in the presentation's SlideIdList.
    param($Shell, $SlideElement, $LayoutPart)
    $relId = "rIdSlide$($Shell.NextSlideRelIdNum)"
    $slidePart = New-ScoutPart $Shell.PresPart ([DocumentFormat.OpenXml.Packaging.SlidePart]) $relId
    $slidePart.Slide = $SlideElement
    $null = $slidePart.AddPart($LayoutPart)

    if (-not $Shell.PSObject.Properties['SlideIdList']) {
        $Shell | Add-Member -NotePropertyName SlideIdList -NotePropertyValue (New-ScoutEl "$Script:PresNs.SlideIdList")
    }
    $sid = New-ScoutEl "$Script:PresNs.SlideId"
    $sid.Id = [uint32]$Shell.NextSlideIdNum
    $sid.RelationshipId = $Shell.PresPart.GetIdOfPart($slidePart)
    $Shell.SlideIdList.Append($sid)

    $Shell.NextSlideRelIdNum++
    $Shell.NextSlideIdNum++
}

#endregion

#region Slide content builders

function New-ScoutTitleSlide {
    param([Parameter(Mandatory)]$Shell, [string]$Title, [string]$Subtitle, [string]$MetaLine)

    $tree = New-ScoutEmptyShapeTreeStandalone
    $bg = New-ScoutShape -Name 'TitleBackground' -X 0 -Y 0 -Cx $Script:SlideWIn -Cy $Script:SlideHIn -FillHex $Script:Navy
    $tree.Append($bg)

    $wmParas = New-ScoutList; $wmRuns = New-ScoutList
    $wmRuns.Add((New-ScoutRun -Text 'AZURE SCOUT' -SizePt 14 -Hex $Script:Paper -Bold $true))
    $wmParas.Add((New-ScoutPara -Runs $wmRuns))
    $tree.Append((New-ScoutShape -Name 'Wordmark' -X 0.6 -Y 0.45 -Cx 5 -Cy 0.4 -Paragraphs $wmParas))

    $accent = New-ScoutShape -Name 'TitleAccent' -X 5.67 -Y 2.45 -Cx 2 -Cy 0.05 -FillHex $Script:Gold
    $tree.Append($accent)

    $titleParas = New-ScoutList; $titleRuns = New-ScoutList
    $titleRuns.Add((New-ScoutRun -Text $Title -SizePt 40 -Hex $Script:Paper -Bold $true -Font 'Segoe UI Semibold'))
    $titleParas.Add((New-ScoutPara -Runs $titleRuns -Align 'ctr'))
    $tree.Append((New-ScoutShape -Name 'Title' -X 1 -Y 2.65 -Cx 11.33 -Cy 1.1 -Paragraphs $titleParas -Anchor 'ctr'))

    if ($Subtitle) {
        $subParas = New-ScoutList; $subRuns = New-ScoutList
        $subRuns.Add((New-ScoutRun -Text $Subtitle -SizePt 18 -Hex 'D9E4EF'))
        $subParas.Add((New-ScoutPara -Runs $subRuns -Align 'ctr'))
        $tree.Append((New-ScoutShape -Name 'Subtitle' -X 1 -Y 3.75 -Cx 11.33 -Cy 0.55 -Paragraphs $subParas -Anchor 'ctr'))
    }

    if ($MetaLine) {
        $metaParas = New-ScoutList; $metaRuns = New-ScoutList
        $metaRuns.Add((New-ScoutRun -Text $MetaLine -SizePt 13 -Hex 'AFC3D9'))
        $metaParas.Add((New-ScoutPara -Runs $metaRuns -Align 'ctr'))
        $tree.Append((New-ScoutShape -Name 'MetaLine' -X 1 -Y 4.35 -Cx 11.33 -Cy 0.5 -Paragraphs $metaParas -Anchor 'ctr'))
    }

    $footParas = New-ScoutList; $footRuns = New-ScoutList
    $footRuns.Add((New-ScoutRun -Text 'Confidential — prepared by Azure Scout' -SizePt 10 -Hex 'AFC3D9'))
    $footParas.Add((New-ScoutPara -Runs $footRuns -Align 'ctr'))
    $tree.Append((New-ScoutShape -Name 'TitleFooter' -X 1 -Y 6.85 -Cx 11.33 -Cy 0.4 -Paragraphs $footParas -Anchor 'ctr'))

    $slide = New-ScoutSlideElement -Tree $tree
    Add-ScoutSlideToDeck -Shell $Shell -SlideElement $slide -LayoutPart $Shell.LayoutTitlePart
}

function New-ScoutContentSlide {
    # $BodyShapeBuilder: scriptblock that appends body shapes onto $tree (receives $tree as arg).
    param([Parameter(Mandatory)]$Shell, [string]$Title, [int]$PageNum, [int]$TotalPages, [scriptblock]$BodyShapeBuilder)
    $tree = New-ScoutEmptyShapeTreeStandalone
    Add-ScoutSlideChrome -Tree $tree -Title $Title -PageNum $PageNum -TotalPages $TotalPages
    & $BodyShapeBuilder $tree
    $slide = New-ScoutSlideElement -Tree $tree
    Add-ScoutSlideToDeck -Shell $Shell -SlideElement $slide -LayoutPart $Shell.LayoutContentPart
}

function Add-ScoutBulletList {
    param($Tree, [double]$X, [double]$Y, [double]$Cx, [string[]]$Lines, [double]$SizePt = 15, [double]$LineGapIn = 0.5)
    $paras = New-ScoutList
    foreach ($line in $Lines) {
        $runs = New-ScoutList
        $runs.Add((New-ScoutRun -Text "•   $line" -SizePt $SizePt -Hex $Script:Ink))
        $paras.Add((New-ScoutPara -Runs $runs -SpaceBeforePt 6))
    }
    $height = [math]::Max($LineGapIn * $Lines.Count, 0.4)
    $Tree.Append((New-ScoutShape -Name 'BulletList' -X $X -Y $Y -Cx $Cx -Cy $height -Paragraphs $paras))
}

function Add-ScoutScoreCard {
    param($Tree, [double]$X, [double]$Y, [double]$Cx, [double]$Cy, [string]$Label, $Score)
    $color = Get-ScoutScoreColor $Score
    $scoreText = if ($null -eq $Score) { '—' } else { "$Score" }
    $paras = New-ScoutList
    $bigRuns = New-ScoutList
    $bigRuns.Add((New-ScoutRun -Text $scoreText -SizePt 44 -Hex $Script:Paper -Bold $true -Font 'Segoe UI Semibold'))
    $paras.Add((New-ScoutPara -Runs $bigRuns -Align 'ctr'))
    $lblRuns = New-ScoutList
    $lblRuns.Add((New-ScoutRun -Text $Label -SizePt 13 -Hex $Script:Paper))
    $paras.Add((New-ScoutPara -Runs $lblRuns -Align 'ctr'))
    $Tree.Append((New-ScoutShape -Name "Card_$Label" -X $X -Y $Y -Cx $Cx -Cy $Cy -FillHex $color -Anchor 'ctr' -RadiusPct 6 -Paragraphs $paras))
}

function New-ScoutExecSummarySlide {
    param($Shell, $Frameworks, $Areas, $Gaps, $Manual, $Errors, [int]$PageNum, [int]$TotalPages)

    New-ScoutContentSlide -Shell $Shell -Title 'Executive Summary' -PageNum $PageNum -TotalPages $TotalPages -BodyShapeBuilder {
        param($tree)

        $cardW = 2.7
        $gap = 0.25
        $startX = 0.55
        $i = 0
        if (@($Frameworks).Count -eq 0) {
            Add-ScoutScoreCard -Tree $tree -X $startX -Y 1.25 -Cx $cardW -Cy 1.7 -Label 'No framework scored' -Score $null
        } else {
            foreach ($fw in @($Frameworks)) {
                $x = $startX + ($i * ($cardW + $gap))
                $label = "$(Get-ScoutProp $fw 'Framework') Alignment Score"
                Add-ScoutScoreCard -Tree $tree -X $x -Y 1.25 -Cx $cardW -Cy 1.7 -Label $label -Score (Get-ScoutProp $fw 'Score')
                $i++
            }
        }

        $areaArr = @($Areas)
        $passSum = ($areaArr | ForEach-Object { Get-ScoutProp $_ 'Pass' 0 } | Measure-Object -Sum).Sum
        $partialSum = ($areaArr | ForEach-Object { Get-ScoutProp $_ 'Partial' 0 } | Measure-Object -Sum).Sum
        $failSum = ($areaArr | ForEach-Object { Get-ScoutProp $_ 'Fail' 0 } | Measure-Object -Sum).Sum
        $manualCount = @($Manual).Count
        $errorCount = @($Errors).Count
        $highGaps = (@($Gaps) | Where-Object { (Get-ScoutSeverityLabel (Get-ScoutProp $_ 'Severity')) -eq 'HIGH' } | Measure-Object).Count

        $lines = @(
            "Areas assessed: $($areaArr.Count)"
            "Rules evaluated — Pass: $passSum, Partial: $partialSum, Fail: $failSum"
            "Critical (High severity) gaps: $highGaps"
            "Manual review items pending: $manualCount"
            "Unknown/Error findings (check collector permissions): $errorCount"
        )
        Add-ScoutBulletList -Tree $tree -X 0.55 -Y 3.5 -Cx 12.2 -Lines $lines -SizePt 15 -LineGapIn 0.5
    }
}

function New-ScoutAreaTableSlides {
    param($Shell, $Areas, [ref]$PageCounter, [int]$TotalPages)

    $rows = @($Areas) | Sort-Object Framework, Area
    if ($rows.Count -eq 0) { return }
    $chunks = Split-ScoutChunks -Items $rows -Size 10
    $pageOfPages = $chunks.Count

    $chunkIdx = 0
    foreach ($chunk in $chunks) {
        $chunkIdx++
        $title = if ($pageOfPages -gt 1) { "Area Score Breakdown ($chunkIdx/$pageOfPages)" } else { 'Area Score Breakdown' }
        $capturedChunk = $chunk
        New-ScoutContentSlide -Shell $Shell -Title $title -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
            param($tree)
            $colW = @(1.6, 3.5, 1.0, 0.9, 0.9, 0.9, 1.0)
            $rowsList = New-ScoutList
            $headerCells = New-ScoutList
            foreach ($h in 'Framework', 'Area', 'Score', 'Pass', 'Partial', 'Fail', 'Manual') {
                $headerCells.Add((New-ScoutTableCell -Text $h -SizePt 12 -Hex $Script:Paper -Bold $true -FillHex $Script:Navy))
            }
            $rowsList.Add((New-ScoutTableRow -HeightIn 0.38 -Cells $headerCells))

            $r = 0
            foreach ($area in $capturedChunk) {
                $r++
                $bg = if ($r % 2 -eq 0) { $Script:Mist } else { $Script:Paper }
                $score = Get-ScoutProp $area 'Score'
                $scoreColor = Get-ScoutScoreColor $score
                $scoreText = if ($null -eq $score) { '—' } else { "$score" }
                $cells = New-ScoutList
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Framework')" -Hex $Script:Ink -FillHex $bg))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Area')" -Hex $Script:Ink -FillHex $bg -Align 'l'))
                $cells.Add((New-ScoutTableCell -Text $scoreText -Bold $true -Hex $scoreColor -FillHex $bg))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Pass' 0)" -Hex $Script:Ink -FillHex $bg))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Partial' 0)" -Hex $Script:Ink -FillHex $bg))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Fail' 0)" -Hex $Script:Ink -FillHex $bg))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $area 'Manual' 0)" -Hex $Script:Ink -FillHex $bg))
                $rowsList.Add((New-ScoutTableRow -HeightIn 0.32 -Cells $cells))
            }

            $tree.Append((New-ScoutTable -Name 'AreaTable' -X 0.55 -Y 1.25 -ColWidthsIn $colW -Rows $rowsList))
        }
        $PageCounter.Value++
    }
}

function New-ScoutGapsSlides {
    param($Shell, $Gaps, [ref]$PageCounter, [int]$TotalPages, [int]$MaxGaps = 15)

    # AB#5089: defensive re-sort at render time too — null/unrecognized severity
    # sorts LAST — even if the caller passes gaps that were never run through
    # Get-Score's own sort.
    $sorted = @($Gaps) | Sort-Object @{ Expression = { Get-ScoutSeverityRank (Get-ScoutProp $_ 'Severity') } }, Area
    $top = $sorted | Select-Object -First $MaxGaps

    if ($top.Count -eq 0) {
        New-ScoutContentSlide -Shell $Shell -Title 'Prioritized Gaps' -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
            param($tree)
            Add-ScoutBulletList -Tree $tree -X 0.55 -Y 1.6 -Cx 12.2 -Lines @('No prioritized gaps — all assessed rules are passing.') -SizePt 16
        }
        $PageCounter.Value++
        return
    }

    $chunks = Split-ScoutChunks -Items $top -Size 10
    $pageOfPages = $chunks.Count
    $chunkIdx = 0
    foreach ($chunk in $chunks) {
        $chunkIdx++
        $title = if ($pageOfPages -gt 1) { "Prioritized Gaps (Top $($top.Count)) — $chunkIdx/$pageOfPages" } else { "Prioritized Gaps (Top $($top.Count))" }
        $capturedChunk = $chunk
        New-ScoutContentSlide -Shell $Shell -Title $title -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
            param($tree)
            $colW = @(1.3, 2.6, 7.0)
            $rowsList = New-ScoutList
            $headerCells = New-ScoutList
            foreach ($h in 'Severity', 'Area', 'Gap') {
                $headerCells.Add((New-ScoutTableCell -Text $h -SizePt 12 -Hex $Script:Paper -Bold $true -FillHex $Script:Navy))
            }
            $rowsList.Add((New-ScoutTableRow -HeightIn 0.38 -Cells $headerCells))

            $r = 0
            foreach ($gap in $capturedChunk) {
                $r++
                $bg = if ($r % 2 -eq 0) { $Script:Mist } else { $Script:Paper }
                $sevLabel = Get-ScoutSeverityLabel (Get-ScoutProp $gap 'Severity')
                $sevColor = Get-ScoutSeverityColor (Get-ScoutProp $gap 'Severity')
                $cells = New-ScoutList
                $cells.Add((New-ScoutTableCell -Text $sevLabel -Bold $true -Hex $Script:Paper -FillHex $sevColor))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $gap 'Area')" -Hex $Script:Ink -FillHex $bg -Align 'l'))
                $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $gap 'Title')" -Hex $Script:Ink -FillHex $bg -Align 'l'))
                $rowsList.Add((New-ScoutTableRow -HeightIn 0.4 -Cells $cells))
            }

            $tree.Append((New-ScoutTable -Name 'GapsTable' -X 0.55 -Y 1.25 -ColWidthsIn $colW -Rows $rowsList))
        }
        $PageCounter.Value++
    }
}

function New-ScoutManualSlide {
    param($Shell, $Manual, [ref]$PageCounter, [int]$TotalPages, [int]$MaxRows = 12)

    $items = @($Manual)
    if ($items.Count -eq 0) {
        New-ScoutContentSlide -Shell $Shell -Title 'Manual Review Worklist' -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
            param($tree)
            Add-ScoutBulletList -Tree $tree -X 0.55 -Y 1.6 -Cx 12.2 -Lines @('No manual review items — full automated coverage for the selected assessment(s).') -SizePt 16
        }
        $PageCounter.Value++
        return
    }

    $shown = $items | Select-Object -First $MaxRows
    $truncated = $items.Count - $shown.Count
    New-ScoutContentSlide -Shell $Shell -Title 'Manual Review Worklist' -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
        param($tree)
        $colW = @(3.5, 8.5)
        $rowsList = New-ScoutList
        $headerCells = New-ScoutList
        foreach ($h in 'Area', 'Item') {
            $headerCells.Add((New-ScoutTableCell -Text $h -SizePt 12 -Hex $Script:Paper -Bold $true -FillHex $Script:Navy))
        }
        $rowsList.Add((New-ScoutTableRow -HeightIn 0.38 -Cells $headerCells))

        $r = 0
        foreach ($m in $shown) {
            $r++
            $bg = if ($r % 2 -eq 0) { $Script:Mist } else { $Script:Paper }
            $cells = New-ScoutList
            $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $m 'Area')" -Hex $Script:Ink -FillHex $bg -Align 'l'))
            $cells.Add((New-ScoutTableCell -Text "$(Get-ScoutProp $m 'Title')" -Hex $Script:Ink -FillHex $bg -Align 'l'))
            $rowsList.Add((New-ScoutTableRow -HeightIn 0.36 -Cells $cells))
        }
        $tree.Append((New-ScoutTable -Name 'ManualTable' -X 0.55 -Y 1.25 -ColWidthsIn $colW -Rows $rowsList))

        if ($truncated -gt 0) {
            Add-ScoutBulletList -Tree $tree -X 0.55 -Y 6.55 -Cx 12.2 -Lines @("+$truncated more not shown — see the evidence pack (Excel tier) for the full list.") -SizePt 11 -LineGapIn 0.3
        }
    }
    $PageCounter.Value++
}

function New-ScoutNextStepsSlide {
    param($Shell, [ref]$PageCounter, [int]$TotalPages)

    New-ScoutContentSlide -Shell $Shell -Title 'Recommended Next Steps' -PageNum $PageCounter.Value -TotalPages $TotalPages -BodyShapeBuilder {
        param($tree)
        $lines = @(
            'Prioritize remediation of High severity gaps identified in this report.'
            'Assign owners and target dates for each Fail finding using the evidence pack (Excel tier).'
            'Complete outstanding Manual review items with the platform/security team.'
            'Re-run Azure Scout after remediation to track score improvement over time.'
            'Revisit Unknown/Error findings — these usually indicate a collector permission or query issue, not a compliance failure.'
        )
        Add-ScoutBulletList -Tree $tree -X 0.55 -Y 1.5 -Cx 12.2 -Lines $lines -SizePt 16 -LineGapIn 0.7
    }
    $PageCounter.Value++
}

#endregion

function Export-Pptx {
    <#
    .SYNOPSIS
        Renders the executive PowerPoint deck for a scored Findings object.

    .PARAMETER Findings
        The scored object returned by Get-Score (GeneratedOn/Frameworks/Areas/
        Gaps/Manual/Errors/Findings).

    .PARAMETER Collect
        Optional — the raw collect object (same one Export-Html/-Excel/-PowerBi
        already receive from Export-Report.ps1). Used only to surface scope /
        management-group context on the title slide when present; the deck
        renders fine without it (Collect carries no tenant field today — see
        src/collect/Invoke-Collect.ps1 — so the title slide degrades gracefully
        to date + branding only when Collect is absent or _meta is empty).

    .PARAMETER OutputPath
        Directory the rendered assessment_deck.pptx is written into.
    #>
    param($Findings, $Collect, [string] $OutputPath)

    Import-ScoutOpenXmlAssembly

    $outFile = Join-Path $OutputPath 'assessment_deck.pptx'
    New-Item -ItemType Directory -Path $OutputPath -Force -ErrorAction SilentlyContinue | Out-Null

    $frameworks = @(Get-ScoutProp $Findings 'Frameworks')
    $areas = @(Get-ScoutProp $Findings 'Areas')
    $gaps = @(Get-ScoutProp $Findings 'Gaps')
    $manual = @(Get-ScoutProp $Findings 'Manual')
    $errors = @(Get-ScoutProp $Findings 'Errors')
    $generatedOn = Get-ScoutProp $Findings 'GeneratedOn'
    $generatedText = if ($generatedOn) {
        try { ([datetime]$generatedOn).ToString('yyyy-MM-dd') } catch { "$generatedOn" }
    } else { (Get-Date).ToString('yyyy-MM-dd') }

    $scope = Get-ScoutProp (Get-ScoutProp $Collect '_meta') 'scope'
    $mgId = Get-ScoutProp (Get-ScoutProp $Collect '_meta') 'managementGroupId'
    $metaParts = New-Object System.Collections.Generic.List[string]
    $metaParts.Add("Generated $generatedText")
    if ($scope) { $metaParts.Add("Scope: $scope") }
    if ($mgId) { $metaParts.Add("Management Group: $mgId") }
    $metaLine = [string]::Join('  ·  ', $metaParts)

    # Slide count plan (used for the "n / total" footer):
    #   1 title + 1 summary + area-table pages + gap pages (>=1) + 1 manual + 1 next-steps
    $areaPages = if (@($areas).Count -gt 0) { [Math]::Ceiling(@($areas).Count / 10.0) } else { 0 }
    $gapCandidates = @($gaps) | Select-Object -First 15
    $gapPages = if ($gapCandidates.Count -gt 0) { [Math]::Ceiling($gapCandidates.Count / 10.0) } else { 1 }
    $totalPages = 1 + 1 + $areaPages + $gapPages + 1 + 1

    $shell = New-ScoutDeckShell -OutFile $outFile

    New-ScoutTitleSlide -Shell $shell -Title 'Azure Landing Zone Assessment' `
        -Subtitle 'Executive Assessment — CAF & WAF Alignment' -MetaLine $metaLine

    $page = 2
    New-ScoutExecSummarySlide -Shell $shell -Frameworks $frameworks -Areas $areas -Gaps $gaps -Manual $manual -Errors $errors -PageNum $page -TotalPages $totalPages
    $page++

    $pageRef = [ref]$page
    New-ScoutAreaTableSlides -Shell $shell -Areas $areas -PageCounter $pageRef -TotalPages $totalPages
    New-ScoutGapsSlides -Shell $shell -Gaps $gaps -PageCounter $pageRef -TotalPages $totalPages
    New-ScoutManualSlide -Shell $shell -Manual $manual -PageCounter $pageRef -TotalPages $totalPages
    New-ScoutNextStepsSlide -Shell $shell -PageCounter $pageRef -TotalPages $totalPages

    # ---- wire the presentation-level lists and save ----
    $slideMasterIdList = New-ScoutEl "$Script:PresNs.SlideMasterIdList"
    $smId = New-ScoutEl "$Script:PresNs.SlideMasterId"
    $smId.Id = [uint32]2147483648
    $smId.RelationshipId = $shell.PresPart.GetIdOfPart($shell.MasterPart)
    $slideMasterIdList.Append($smId)

    $slideSize = New-ScoutEl "$Script:PresNs.SlideSize"
    $slideSize.Cx = [int32](ScoutEmu32 $Script:SlideWIn)
    $slideSize.Cy = [int32](ScoutEmu32 $Script:SlideHIn)
    $slideSize.Type = [DocumentFormat.OpenXml.Presentation.SlideSizeValues]::Screen16x9

    $notesSize = New-ScoutEl "$Script:PresNs.NotesSize"
    $notesSize.Cx = [int32](ScoutEmu32 7.5)
    $notesSize.Cy = [int32](ScoutEmu32 10)

    $shell.PresPart.Presentation.Append($slideMasterIdList, $shell.SlideIdList, $slideSize, $notesSize, (New-ScoutEl "$Script:PresNs.DefaultTextStyle"))
    $shell.PresPart.Presentation.Save()
    $shell.Doc.Dispose()

    return $outFile
}
