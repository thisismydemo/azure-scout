#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Render a real, self-contained .pdf assessment report (cover, executive
    summary, per-area findings table, prioritized gaps, manual review) with
    zero external/network dependencies. Retained tier.

.DESCRIPTION
    ADO Stories AB#379/394/395.

    OFFLINE-PDF APPROACH (investigated and chosen deliberately): every other
    heavyweight renderer in this folder either shells out to a module
    (ImportExcel) or acquires a NuGet package at first use (Export-Pptx's
    DocumentFormat.OpenXml). A real .pdf does not need either -- the PDF file
    format itself is an openly documented, text-and-binary object graph (a
    small set of numbered objects, a cross-reference table, and a trailer),
    and Adobe's 14 base fonts (Helvetica/Helvetica-Bold here) are guaranteed
    present in every PDF-conformant reader without embedding a font program.
    This renderer hand-assembles that object graph directly with core .NET
    (System.Text.Encoding, System.Collections.Generic.List[byte]) -- no
    DocumentFormat.OpenXml, no PDFsharp/iText/QuestPDF, no dotnet/NuGet
    acquire step, no network call, ever. That is the "prefer pure-.NET/no
    network" option from the brief, taken all the way rather than falling
    back to a document-model + HTML-print stand-in.

    A print-optimized, self-contained HTML fallback (Export-ScoutPdfHtmlFallback,
    below) still exists, but purely as a non-fatal safety net if the hand-rolled
    PDF assembly throws for an unanticipated reason -- it is not the primary
    path, and Export-Pdf's own Pester coverage exercises the real .pdf path
    end-to-end, so the fallback is not expected to trigger in normal operation.
    If it ever does, the produced file is named *_fallback.html and states
    plainly that it is a fallback, not a silently-renamed non-PDF artifact.

    HONEST LIMITATIONS of this hand-rolled writer (documented rather than
    hidden):
      - ASCII-only text content. Every string drawn on the page is escaped
        through ConvertTo-ScoutPdfLiteral, which passes through printable
        ASCII (0x20-0x7E) and renders anything else (accented characters,
        真, emoji, smart quotes, ...) as '?'. Real Unicode glyph embedding
        needs an embedded font program (TrueType/CFF) with a CID mapping --
        a large undertaking deliberately out of scope here; findings/titles
        in this platform's rule files are ASCII today, so this is a
        theoretical gap, not an observed one.
      - No text measurement/kerning: layout is left-aligned with fixed
        character-width truncation heuristics (ScoutPdfTruncate), not real
        glyph-width metrics. Good enough for a tabular assessment report,
        not a typeset document.
      - "Status emoji" (AB#395) are rendered as small vector-drawn colored
        dots (Add-ScoutPdfDot), not literal Unicode emoji glyphs -- Helvetica
        (a base-14 Type1 font) has no emoji glyphs at all, and embedding a
        color-emoji font is its own multi-week project. A colored status dot
        next to the text label reads the same way at a glance and renders
        identically in every PDF viewer, which a hoped-for-but-missing emoji
        glyph would not.
      - Content streams are NOT Flate-compressed (no /Filter on page content
        streams). This trades file size for the ability to grep the raw PDF
        bytes for literal content-stream text -- which both this file's own
        Pester tests and any future debugging session rely on. A compression
        pass could be added later without touching the object model.
      - AB#379 (diagram embed): this renderer CAN embed a diagram -- but only
        a baseline JPEG (1 or 3 color components), because JPEG is the one
        common image format a PDF can embed by copying its compressed bytes
        as-is (/Filter /DCTDecode) with no decode step at all. There is no
        diagram-capture mechanism anywhere in this codebase (no headless
        browser, no draw.io export automation) to produce that JPEG
        automatically, and adding one is out of this renderer's scope/file
        ownership. So "if feasible" resolves to: drop a `diagram.jpg` (or
        `.jpeg`) into the run's -OutputPath folder before rendering, and this
        renderer will size it into the cover page automatically
        (Get-ScoutPdfDiagram/Add-ScoutPdfImage); absent that file, the cover
        page prints an explicit "not available" note instead of silently
        omitting the section. PNG source diagrams are not supported directly
        (that needs a pixel decoder this renderer intentionally does not
        carry) -- convert to JPEG first.

    CULTURE SAFETY: every numeric token written into a PDF content stream or
    object dictionary goes through ScoutPdfNum, which formats with
    [CultureInfo]::InvariantCulture. Plain PowerShell string interpolation of
    a [double] uses the CURRENT THREAD CULTURE, which renders "12.5" as
    "12,5" on a comma-decimal locale (e.g. de-DE) -- that would corrupt PDF
    number syntax outright. This is exercised directly in
    tests/Report.Pdf.Tests.ps1 by switching the thread culture mid-test.

.PARAMETER Findings
    The scored Findings object from Get-Score (GeneratedOn/Frameworks/Areas/
    Gaps/Manual/Errors/Findings).

.PARAMETER Collect
    The raw Collect object. Only Collect._meta.scope/.managementGroupId are
    read (same minimal-read contract Export-Pptx/Export-React use).

.PARAMETER OutputPath
    Folder to write assessment_report.pdf into. Created if missing. Also
    where an optional diagram.jpg/.jpeg is looked up for AB#379.

.OUTPUTS
    [string] the full path to the written .pdf (or the fallback .html if the
    primary path threw). Never throws -- failures are non-fatal by design so
    a broken renderer never sinks an otherwise-good assessment run.

.NOTES
    Tracks ADO Stories AB#379, AB#394, AB#395.
#>

# ---- palette (RGB triples, 0..1) -- names carry a "Pdf" infix so they never
# collide with Export-Pptx.ps1's identically-purposed but differently-typed
# $Script:Navy/etc (hex strings) even though every renderer in this folder is
# dot-sourced into one shared module scope by AzureScout.psm1. ----
$Script:ScoutPdfNavy  = @(0.122, 0.306, 0.471)
$Script:ScoutPdfSteel = @(0.180, 0.459, 0.714)
$Script:ScoutPdfGreen = @(0.180, 0.490, 0.196)
$Script:ScoutPdfGold  = @(0.722, 0.525, 0.043)
$Script:ScoutPdfRed   = @(0.690, 0.000, 0.125)
$Script:ScoutPdfInk   = @(0.102, 0.102, 0.102)
$Script:ScoutPdfGray  = @(0.349, 0.349, 0.349)
$Script:ScoutPdfWhite = @(1.000, 1.000, 1.000)
$Script:ScoutPdfSeverityRank = @{ high = 0; medium = 1; low = 2 }

#region Safe data access / formatting helpers

function Get-ScoutPdfProp {
    param($Obj, [Parameter(Mandatory)][string]$Name, $Default = $null)
    if ($null -eq $Obj) { return $Default }
    $p = $Obj.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $Default }
}

function Get-ScoutPdfMeta {
    # Mirrors Export-React's/Export-Pptx's minimal-read contract: only ever
    # touches Collect._meta.scope / .managementGroupId, defensively (Collect
    # may be $null or a plain deserialized object missing either key).
    param($Collect)
    $scope = $null; $mgId = $null
    if ($null -ne $Collect) {
        $metaProp = $Collect.PSObject.Properties['_meta']
        if ($metaProp -and $null -ne $metaProp.Value) {
            $metaSrc = $metaProp.Value
            $scopeProp = $metaSrc.PSObject.Properties['scope']
            if ($scopeProp) { $scope = $scopeProp.Value }
            $mgProp = $metaSrc.PSObject.Properties['managementGroupId']
            if ($mgProp) { $mgId = $mgProp.Value }
        }
    }
    return [pscustomobject]@{ Scope = $scope; ManagementGroupId = $mgId }
}

function ScoutPdfNum {
    # Culture-safe numeric formatting for PDF content-stream/object tokens --
    # see the file header's CULTURE SAFETY note. Never use plain string
    # interpolation of a [double] anywhere else in this file.
    param([double]$D, [int]$Decimals = 2)
    return [math]::Round($D, $Decimals).ToString(('F' + $Decimals), [System.Globalization.CultureInfo]::InvariantCulture)
}

function ScoutPdfTruncate {
    param([string]$Text, [int]$MaxChars)
    if (-not $Text) { return '' }
    if ($Text.Length -le $MaxChars) { return $Text }
    if ($MaxChars -le 3) { return $Text.Substring(0, [math]::Max($MaxChars, 0)) }
    return $Text.Substring(0, $MaxChars - 3) + '...'
}

function Split-ScoutPdfWrap {
    param([string]$Text, [int]$MaxChars = 88)
    if (-not $Text) { return , @('') }
    $words = $Text -split '\s+'
    $lines = [System.Collections.Generic.List[string]]::new()
    $cur = ''
    foreach ($w in $words) {
        $candidate = if ($cur) { "$cur $w" } else { $w }
        if ($candidate.Length -gt $MaxChars -and $cur) {
            $lines.Add($cur)
            $cur = $w
        }
        else {
            $cur = $candidate
        }
    }
    if ($cur) { $lines.Add($cur) }
    if ($lines.Count -eq 0) { $lines.Add('') }
    return , $lines
}

function ConvertTo-ScoutPdfLiteral {
    # Escapes a string for a PDF "(...)" literal AND enforces the ASCII-only
    # content-stream limitation documented in the file header.
    param([string]$Text)
    if ($null -eq $Text) { $Text = '' }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '(' -or $ch -eq ')' -or $ch -eq '\') { [void]$sb.Append('\').Append($ch) }
        elseif ($code -eq 10 -or $code -eq 13) { [void]$sb.Append(' ') }
        elseif ($code -ge 32 -and $code -le 126) { [void]$sb.Append($ch) }
        else { [void]$sb.Append('?') }
    }
    return $sb.ToString()
}

#endregion

#region Status / severity / score color-banding (independent of, and named
# distinctly from, Export-Pptx's identically-purposed Get-ScoutSeverity*/
# Get-ScoutScoreColor helpers -- see palette-collision note above)

function Get-ScoutPdfStatusColor {
    param($Status)
    if (-not $Status) { return $Script:ScoutPdfGray }
    switch ($Status.ToString().Trim().ToLowerInvariant()) {
        'pass' { return $Script:ScoutPdfGreen }
        'partial' { return $Script:ScoutPdfGold }
        'fail' { return $Script:ScoutPdfRed }
        'manual' { return $Script:ScoutPdfSteel }
        default { return $Script:ScoutPdfGray }
    }
}

function Get-ScoutPdfStatusLabel {
    param($Status)
    if ($Status -and "$Status".Trim()) { return "$Status".ToUpperInvariant() }
    return 'UNKNOWN'
}

function Get-ScoutPdfSeverityColor {
    param($Severity)
    if (-not $Severity) { return $Script:ScoutPdfGray }
    switch ($Severity.ToString().Trim().ToLowerInvariant()) {
        'high' { return $Script:ScoutPdfRed }
        'medium' { return $Script:ScoutPdfGold }
        'low' { return $Script:ScoutPdfSteel }
        default { return $Script:ScoutPdfGray }
    }
}

function Get-ScoutPdfSeverityLabel {
    param($Severity)
    if ($Severity -and "$Severity".Trim()) { return "$Severity".ToUpperInvariant() }
    return 'UNKNOWN'
}

function Get-ScoutPdfSeverityRank {
    param($Severity)
    if ($Severity) {
        $key = $Severity.ToString().Trim().ToLowerInvariant()
        if ($Script:ScoutPdfSeverityRank.ContainsKey($key)) { return $Script:ScoutPdfSeverityRank[$key] }
    }
    return 99
}

function Get-ScoutPdfScoreColor {
    param($Score)
    if ($null -eq $Score) { return $Script:ScoutPdfGray }
    if ($Score -ge 80) { return $Script:ScoutPdfGreen }
    if ($Score -ge 50) { return $Script:ScoutPdfGold }
    return $Script:ScoutPdfRed
}

#endregion

#region Page context (a mutable Hashtable -- cheap reference-type mutation
# across every helper below, no Add-Member ceremony needed)

function New-ScoutPdfContext {
    return @{
        Pages        = [System.Collections.Generic.List[string]]::new()
        Ops          = [System.Text.StringBuilder]::new()
        Y            = 738.0
        Margin       = 54.0
        Top          = 738.0
        Bottom       = 60.0
        Started      = $false
        HeaderRepeat = $null   # scriptblock invoked right after each new page's chrome is drawn -- AB#394 hook
        FooterLabel  = $null
    }
}

function Add-ScoutPdfRaw {
    param($Ctx, [string]$Op)
    [void] $Ctx.Ops.Append($Op).Append("`n")
}

function Complete-ScoutPdfPage {
    param($Ctx)
    [void] $Ctx.Pages.Add($Ctx.Ops.ToString())
    $Ctx.Ops = [System.Text.StringBuilder]::new()
}

function Start-ScoutPdfPage {
    # Begins a new page: flushes whatever the previous page had drawn, resets
    # the Y cursor, draws the thin footer rule/label/page-number chrome, then
    # -- the AB#394 page-break-aware header repeat -- re-invokes
    # $Ctx.HeaderRepeat (if one is set) so a table's column header re-appears
    # at the top of every continuation page, not just the first.
    param($Ctx, [string]$FooterLabel = $null)
    if ($FooterLabel) { $Ctx.FooterLabel = $FooterLabel }
    elseif (-not $Ctx.FooterLabel) { $Ctx.FooterLabel = 'Azure Scout Assessment Report' }
    if ($Ctx.Started) { Complete-ScoutPdfPage $Ctx }
    $Ctx.Started = $true
    $Ctx.Y = $Ctx.Top

    $pageNum = $Ctx.Pages.Count + 1
    Add-ScoutPdfLineSeg $Ctx $Ctx.Margin 40 (612 - $Ctx.Margin) 40 @(0.83, 0.83, 0.83) 0.75
    Add-ScoutPdfText $Ctx $Ctx.Margin 26 $Ctx.FooterLabel 8 'F1' $Script:ScoutPdfGray
    Add-ScoutPdfText $Ctx (612 - $Ctx.Margin - 40) 26 "Page $pageNum" 8 'F1' $Script:ScoutPdfGray

    if ($Ctx.HeaderRepeat) { & $Ctx.HeaderRepeat $Ctx }
}

function ScoutPdfEnsureSpace {
    # Page-break trigger: if the next NeededPt of content would run past the
    # bottom margin, start a fresh page first (which re-fires HeaderRepeat).
    param($Ctx, [double]$Needed)
    if (($Ctx.Y - $Needed) -lt $Ctx.Bottom) {
        Start-ScoutPdfPage -Ctx $Ctx
    }
}

#endregion

#region Low-level drawing primitives (every numeric token routed through
# ScoutPdfNum -- see CULTURE SAFETY in the file header)

function Add-ScoutPdfText {
    param($Ctx, [double]$X, [double]$Y, [string]$Text, [double]$Size = 10, [string]$Font = 'F1', [double[]]$Color = @(0, 0, 0))
    $lit = ConvertTo-ScoutPdfLiteral $Text
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} rg" -f (ScoutPdfNum $Color[0] 3), (ScoutPdfNum $Color[1] 3), (ScoutPdfNum $Color[2] 3))
    Add-ScoutPdfRaw $Ctx 'BT'
    Add-ScoutPdfRaw $Ctx ("/{0} {1} Tf" -f $Font, (ScoutPdfNum $Size))
    Add-ScoutPdfRaw $Ctx ("{0} {1} Td" -f (ScoutPdfNum $X), (ScoutPdfNum $Y))
    Add-ScoutPdfRaw $Ctx ("($lit) Tj")
    Add-ScoutPdfRaw $Ctx 'ET'
}

function Add-ScoutPdfRect {
    param($Ctx, [double]$X, [double]$Y, [double]$W, [double]$H, [double[]]$Color)
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} rg" -f (ScoutPdfNum $Color[0] 3), (ScoutPdfNum $Color[1] 3), (ScoutPdfNum $Color[2] 3))
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} {3} re f" -f (ScoutPdfNum $X), (ScoutPdfNum $Y), (ScoutPdfNum $W), (ScoutPdfNum $H))
}

function Add-ScoutPdfLineSeg {
    param($Ctx, [double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [double[]]$Color = @(0, 0, 0), [double]$Width = 0.75)
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} RG" -f (ScoutPdfNum $Color[0] 3), (ScoutPdfNum $Color[1] 3), (ScoutPdfNum $Color[2] 3))
    Add-ScoutPdfRaw $Ctx ("{0} w" -f (ScoutPdfNum $Width))
    Add-ScoutPdfRaw $Ctx ("{0} {1} m" -f (ScoutPdfNum $X1), (ScoutPdfNum $Y1))
    Add-ScoutPdfRaw $Ctx ("{0} {1} l" -f (ScoutPdfNum $X2), (ScoutPdfNum $Y2))
    Add-ScoutPdfRaw $Ctx 'S'
}

function Add-ScoutPdfDot {
    # The AB#395 "status emoji" stand-in -- a small filled circle approximated
    # with four cubic Beziers (kappa = 0.5523*r), not a text glyph. See the
    # file header's honest-limitations note for why.
    param($Ctx, [double]$Cx, [double]$Cy, [double]$R, [double[]]$Color)
    $k = 0.5523 * $R
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} rg" -f (ScoutPdfNum $Color[0] 3), (ScoutPdfNum $Color[1] 3), (ScoutPdfNum $Color[2] 3))
    Add-ScoutPdfRaw $Ctx ("{0} {1} m" -f (ScoutPdfNum ($Cx + $R)), (ScoutPdfNum $Cy))
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} {3} {4} {5} c" -f (ScoutPdfNum ($Cx + $R)), (ScoutPdfNum ($Cy + $k)), (ScoutPdfNum ($Cx + $k)), (ScoutPdfNum ($Cy + $R)), (ScoutPdfNum $Cx), (ScoutPdfNum ($Cy + $R)))
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} {3} {4} {5} c" -f (ScoutPdfNum ($Cx - $k)), (ScoutPdfNum ($Cy + $R)), (ScoutPdfNum ($Cx - $R)), (ScoutPdfNum ($Cy + $k)), (ScoutPdfNum ($Cx - $R)), (ScoutPdfNum $Cy))
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} {3} {4} {5} c" -f (ScoutPdfNum ($Cx - $R)), (ScoutPdfNum ($Cy - $k)), (ScoutPdfNum ($Cx - $k)), (ScoutPdfNum ($Cy - $R)), (ScoutPdfNum $Cx), (ScoutPdfNum ($Cy - $R)))
    Add-ScoutPdfRaw $Ctx ("{0} {1} {2} {3} {4} {5} c" -f (ScoutPdfNum ($Cx + $k)), (ScoutPdfNum ($Cy - $R)), (ScoutPdfNum ($Cx + $R)), (ScoutPdfNum ($Cy - $k)), (ScoutPdfNum ($Cx + $R)), (ScoutPdfNum $Cy))
    Add-ScoutPdfRaw $Ctx 'f'
}

function Add-ScoutPdfImage {
    param($Ctx, [double]$X, [double]$Y, [double]$W, [double]$H)
    Add-ScoutPdfRaw $Ctx 'q'
    Add-ScoutPdfRaw $Ctx ("{0} 0 0 {1} {2} {3} cm" -f (ScoutPdfNum $W), (ScoutPdfNum $H), (ScoutPdfNum $X), (ScoutPdfNum $Y))
    Add-ScoutPdfRaw $Ctx '/Im1 Do'
    Add-ScoutPdfRaw $Ctx 'Q'
}

#endregion

#region Layout helpers -- the AB#395 "sub-section/bullet/status-emoji
# helpers". Every one of these manages its own $Ctx.Y cursor decrement and
# calls ScoutPdfEnsureSpace first, so callers never touch $Ctx.Y directly.

function Add-ScoutPdfHeading {
    param($Ctx, [string]$Text, [double]$Size = 24, [string]$Font = 'F2', [double[]]$Color = $Script:ScoutPdfNavy)
    ScoutPdfEnsureSpace $Ctx ($Size * 1.4)
    Add-ScoutPdfText $Ctx $Ctx.Margin $Ctx.Y $Text $Size $Font $Color
    $Ctx.Y -= ($Size * 1.4)
}

function Add-ScoutPdfSubsection {
    # A bold heading + a short gold underline rule -- used for every major
    # section (Executive Summary / Findings by Area / Prioritized Gaps /
    # Manual Review Items / Architecture Diagram).
    param($Ctx, [string]$Text)
    ScoutPdfEnsureSpace $Ctx 30
    Add-ScoutPdfText $Ctx $Ctx.Margin $Ctx.Y $Text 15 'F2' $Script:ScoutPdfNavy
    $underlineY = $Ctx.Y - 4
    Add-ScoutPdfLineSeg $Ctx $Ctx.Margin $underlineY ($Ctx.Margin + 60) $underlineY $Script:ScoutPdfGold 2
    $Ctx.Y -= 24
}

function Add-ScoutPdfLine {
    param($Ctx, [string]$Text, [double]$Size = 10, [string]$Font = 'F1', [double[]]$Color = $Script:ScoutPdfInk)
    ScoutPdfEnsureSpace $Ctx 14
    Add-ScoutPdfText $Ctx $Ctx.Margin $Ctx.Y $Text $Size $Font $Color
    $Ctx.Y -= 14
}

function Add-ScoutPdfBullet {
    # Word-wraps $Text to $MaxChars-wide lines; only the first line gets the
    # marker (a colored status/severity dot when $DotColor is supplied, else
    # a plain small square). Used throughout the exec summary, gaps, and
    # manual-review sections.
    param($Ctx, [string]$Text, [double[]]$DotColor = $null, [int]$MaxChars = 88)
    $lines = @(Split-ScoutPdfWrap -Text $Text -MaxChars $MaxChars)
    for ($li = 0; $li -lt $lines.Count; $li++) {
        ScoutPdfEnsureSpace $Ctx 14
        if ($li -eq 0) {
            if ($DotColor) { Add-ScoutPdfDot $Ctx ($Ctx.Margin + 3) ($Ctx.Y + 3) 3.2 $DotColor }
            else { Add-ScoutPdfRect $Ctx $Ctx.Margin ($Ctx.Y + 2) 4 4 $Script:ScoutPdfGray }
        }
        Add-ScoutPdfText $Ctx ($Ctx.Margin + 12) $Ctx.Y $lines[$li] 10 'F1' $Script:ScoutPdfInk
        $Ctx.Y -= 14
    }
}

function Add-ScoutPdfTableHeader {
    # The AB#394 "page-break-aware header repeat" is this function, wired up
    # as $Ctx.HeaderRepeat by Export-Pdf before the findings table begins --
    # Start-ScoutPdfPage re-invokes it on every continuation page.
    param($Ctx, [double[]]$ColX)
    ScoutPdfEnsureSpace $Ctx 18
    Add-ScoutPdfRect $Ctx $Ctx.Margin ($Ctx.Y - 2) (612 - 2 * $Ctx.Margin) 16 $Script:ScoutPdfNavy
    $labels = @('ID', 'Severity', 'Status', 'Title')
    for ($i = 0; $i -lt $labels.Count; $i++) {
        Add-ScoutPdfText $Ctx ($ColX[$i] + 2) ($Ctx.Y + 2) $labels[$i] 9 'F2' $Script:ScoutPdfWhite
    }
    $Ctx.Y -= 18
}

function Add-ScoutPdfAreaHeading {
    param($Ctx, [string]$Text, $Score)
    ScoutPdfEnsureSpace $Ctx 16
    $scoreTxt = if ($null -eq $Score) { '(not scored)' } else { "Score: $Score" }
    Add-ScoutPdfText $Ctx $Ctx.Margin $Ctx.Y "$Text -- $scoreTxt" 10 'F2' $Script:ScoutPdfSteel
    $Ctx.Y -= 15
}

function Add-ScoutPdfTableRow {
    param($Ctx, [double[]]$ColX, $Finding)
    ScoutPdfEnsureSpace $Ctx 14
    $status = Get-ScoutPdfProp $Finding 'Status' 'Unknown'
    $sev = Get-ScoutPdfProp $Finding 'Severity' $null
    $id = "$(Get-ScoutPdfProp $Finding 'Id' '')"
    $title = "$(Get-ScoutPdfProp $Finding 'Title' '')"
    Add-ScoutPdfText $Ctx ($ColX[0] + 2) $Ctx.Y (ScoutPdfTruncate $id 13) 9 'F1' $Script:ScoutPdfInk
    Add-ScoutPdfText $Ctx ($ColX[1] + 2) $Ctx.Y (Get-ScoutPdfSeverityLabel $sev) 9 'F1' (Get-ScoutPdfSeverityColor $sev)
    Add-ScoutPdfDot $Ctx ($ColX[2] + 5) ($Ctx.Y + 3) 3.2 (Get-ScoutPdfStatusColor $status)
    Add-ScoutPdfText $Ctx ($ColX[2] + 12) $Ctx.Y (Get-ScoutPdfStatusLabel $status) 9 'F1' $Script:ScoutPdfInk
    Add-ScoutPdfText $Ctx ($ColX[3] + 2) $Ctx.Y (ScoutPdfTruncate $title 58) 9 'F1' $Script:ScoutPdfInk
    $Ctx.Y -= 14
}

#endregion

#region AB#379 diagram embed -- baseline-JPEG-only, no decode step (see the
# file header's honest-limitations note on why PNG is out of scope here)

function Get-ScoutPdfJpegInfo {
    # Minimal JPEG marker scan: finds the first SOFn (start-of-frame) marker
    # and reads precision/height/width/component-count directly out of it.
    # Returns $null for anything that isn't a well-formed baseline/progressive
    # JPEG (SOI marker + a recognizable SOF segment before the scan begins).
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -lt 4 -or $Bytes[0] -ne 0xFF -or $Bytes[1] -ne 0xD8) { return $null }
    $i = 2
    while ($i -lt ($Bytes.Length - 1)) {
        if ($Bytes[$i] -ne 0xFF) { $i++; continue }
        $marker = $Bytes[$i + 1]
        if ($marker -eq 0xFF) { $i++; continue }                                   # padding fill byte
        if ($marker -eq 0xD8 -or $marker -eq 0xD9) { $i += 2; continue }            # SOI/EOI -- no length field
        if ($marker -ge 0xD0 -and $marker -le 0xD7) { $i += 2; continue }           # RSTn -- no length field
        if ($marker -eq 0xDA) { break }                                            # start-of-scan reached, no SOF found first
        if ($i + 3 -ge $Bytes.Length) { break }
        $segLen = ([int]$Bytes[$i + 2] -shl 8) -bor [int]$Bytes[$i + 3]
        $isSof = ($marker -ge 0xC0 -and $marker -le 0xCF) -and $marker -ne 0xC4 -and $marker -ne 0xC8 -and $marker -ne 0xCC
        if ($isSof) {
            $p = $i + 4
            if ($p + 5 -ge $Bytes.Length) { return $null }
            $height = ([int]$Bytes[$p + 1] -shl 8) -bor [int]$Bytes[$p + 2]
            $width = ([int]$Bytes[$p + 3] -shl 8) -bor [int]$Bytes[$p + 4]
            $components = $Bytes[$p + 5]
            return [pscustomobject]@{ Width = $width; Height = $height; Components = $components }
        }
        $i = $i + 2 + $segLen
    }
    return $null
}

function Get-ScoutPdfDiagram {
    # Looks for diagram.jpg/.jpeg directly inside -OutputPath (the run
    # folder) -- the one convention this renderer defines for AB#379. Nothing
    # in this codebase produces that file automatically today (no
    # diagram-capture mechanism exists) -- see the file header note.
    param([string]$OutputPath)
    try {
        $candidate = @('diagram.jpg', 'diagram.jpeg') |
            ForEach-Object { Join-Path $OutputPath $_ } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1
        if (-not $candidate) { return $null }

        $bytes = [System.IO.File]::ReadAllBytes($candidate)
        $info = Get-ScoutPdfJpegInfo -Bytes $bytes
        if (-not $info -or $info.Width -le 0 -or $info.Height -le 0) {
            Write-Warning "Export-Pdf: '$candidate' does not look like a valid JPEG (no SOF marker found) -- skipping diagram embed."
            return $null
        }
        $colorSpace = switch ($info.Components) {
            1 { 'DeviceGray' }
            3 { 'DeviceRGB' }
            default { $null }
        }
        if (-not $colorSpace) {
            Write-Warning "Export-Pdf: '$candidate' has $($info.Components) color components -- only grayscale (1) or RGB/YCbCr (3) baseline JPEGs can be embedded -- skipping diagram embed."
            return $null
        }
        return [pscustomobject]@{ Bytes = $bytes; Width = $info.Width; Height = $info.Height; ColorSpace = $colorSpace }
    }
    catch {
        Write-Warning "Export-Pdf: could not read diagram image: $_"
        return $null
    }
}

#endregion

#region Document assembly -- writes the literal PDF byte stream (header,
# numbered objects, xref table, trailer). Content streams are intentionally
# left uncompressed (see file header). Every offset is tracked against a real
# List[byte].Count, so binary segments (the %-marker line, an embedded JPEG)
# mix safely with the ASCII structure/text around them.

function New-ScoutPdfDocument {
    param($Ctx, $Diagram)

    $bytes = [System.Collections.Generic.List[byte]]::new()
    $offsets = @{}

    function AddAscii([string]$S) { $bytes.AddRange([System.Text.Encoding]::ASCII.GetBytes($S)) }
    function AddRawBytes([byte[]]$B) { $bytes.AddRange($B) }

    AddAscii "%PDF-1.4`n"
    AddRawBytes ([byte[]]@(0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A))   # binary-file marker comment, per convention

    $pageCount = $Ctx.Pages.Count
    $objCatalog = 1
    $objPages = 2
    $objFontRegular = 3
    $objFontBold = 4
    $next = 5
    $objImage = $null
    if ($Diagram) { $objImage = $next; $next++ }

    $pageObjNums = [System.Collections.Generic.List[int]]::new()
    $contentObjNums = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $pageCount; $i++) {
        $pageObjNums.Add($next); $next++
        $contentObjNums.Add($next); $next++
    }
    $objInfo = $next; $next++
    $totalObjects = $next   # objects are numbered 1..(totalObjects-1)

    $offsets[$objCatalog] = $bytes.Count
    AddAscii "$objCatalog 0 obj`n<< /Type /Catalog /Pages $objPages 0 R >>`nendobj`n"

    $kids = (($pageObjNums | ForEach-Object { "$_ 0 R" })) -join ' '
    $offsets[$objPages] = $bytes.Count
    AddAscii "$objPages 0 obj`n<< /Type /Pages /Kids [ $kids ] /Count $pageCount >>`nendobj`n"

    $offsets[$objFontRegular] = $bytes.Count
    AddAscii "$objFontRegular 0 obj`n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>`nendobj`n"
    $offsets[$objFontBold] = $bytes.Count
    AddAscii "$objFontBold 0 obj`n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>`nendobj`n"

    if ($Diagram) {
        $offsets[$objImage] = $bytes.Count
        AddAscii "$objImage 0 obj`n<< /Type /XObject /Subtype /Image /Width $($Diagram.Width) /Height $($Diagram.Height) /ColorSpace /$($Diagram.ColorSpace) /BitsPerComponent 8 /Filter /DCTDecode /Length $($Diagram.Bytes.Length) >>`nstream`n"
        AddRawBytes $Diagram.Bytes
        AddAscii "`nendstream`nendobj`n"
    }

    $resourceDict = if ($Diagram) {
        "/Resources << /Font << /F1 $objFontRegular 0 R /F2 $objFontBold 0 R >> /XObject << /Im1 $objImage 0 R >> >>"
    }
    else {
        "/Resources << /Font << /F1 $objFontRegular 0 R /F2 $objFontBold 0 R >> >>"
    }

    for ($i = 0; $i -lt $pageCount; $i++) {
        $pObj = $pageObjNums[$i]; $cObj = $contentObjNums[$i]
        $offsets[$pObj] = $bytes.Count
        AddAscii "$pObj 0 obj`n<< /Type /Page /Parent $objPages 0 R /MediaBox [0 0 612 792] $resourceDict /Contents $cObj 0 R >>`nendobj`n"

        $opsBytes = [System.Text.Encoding]::ASCII.GetBytes($Ctx.Pages[$i])
        $offsets[$cObj] = $bytes.Count
        AddAscii "$cObj 0 obj`n<< /Length $($opsBytes.Length) >>`nstream`n"
        AddRawBytes $opsBytes
        AddAscii "`nendstream`nendobj`n"
    }

    $offsets[$objInfo] = $bytes.Count
    AddAscii "$objInfo 0 obj`n<< /Title (Azure Scout Assessment Report) >>`nendobj`n"

    $xrefStart = $bytes.Count
    AddAscii "xref`n0 $totalObjects`n"
    AddAscii "0000000000 65535 f `n"
    for ($n = 1; $n -lt $totalObjects; $n++) {
        AddAscii ("{0:D10} 00000 n `n" -f $offsets[$n])
    }
    AddAscii "trailer`n<< /Size $totalObjects /Root $objCatalog 0 R /Info $objInfo 0 R >>`nstartxref`n$xrefStart`n%%EOF"

    return $bytes.ToArray()
}

#endregion

#region Fallback (non-fatal safety net only -- see file header)

function Export-ScoutPdfHtmlFallback {
    param($Findings, $Collect, [string] $OutputPath, [string] $Reason)
    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    $json = ($Findings | ConvertTo-Json -Depth 100) -replace '</', '<\/'
    $safeReason = $Reason -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    $generatedOn = Get-ScoutPdfProp $Findings 'GeneratedOn' '(unknown)'
    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Azure Scout Assessment Report (fallback)</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; color:#1a1a1a; margin: 2rem; }
  .banner { background:#B00020; color:#fff; padding: 0.75rem 1rem; margin-bottom:1rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ccc; padding: 4px 6px; font-size: 12px; text-align: left; }
  th { background:#1F4E78; color:#fff; }
  @media print {
    table { page-break-inside: auto; }
    tr { page-break-inside: avoid; page-break-after: auto; }
    thead { display: table-header-group; }
  }
</style>
</head>
<body>
<div class="banner">
  PDF generation failed for this run -- this is a print-optimized HTML fallback, not a renamed non-PDF file.
  Open it and use your browser's Print -&gt; Save as PDF to get a .pdf. Reason: $safeReason
</div>
<h1>Azure Scout Assessment Report</h1>
<p>Generated: $generatedOn</p>
<script>window.__FINDINGS__ = $json;</script>
</body>
</html>
"@
    $path = Join-Path $OutputPath 'assessment_report_fallback.html'
    $html | Out-File -FilePath $path -Encoding utf8
    return $path
}

#endregion

function Export-Pdf {
    param($Findings, $Collect, [string] $OutputPath)

    try {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }

        $ctx = New-ScoutPdfContext

        $meta = Get-ScoutPdfMeta $Collect
        $generatedOn = Get-ScoutPdfProp $Findings 'GeneratedOn' ''
        $frameworks = @(Get-ScoutPdfProp $Findings 'Frameworks' @())
        $areas = @(Get-ScoutPdfProp $Findings 'Areas' @())
        $gaps = @(Get-ScoutPdfProp $Findings 'Gaps' @())
        $manual = @(Get-ScoutPdfProp $Findings 'Manual' @())
        $errors = @(Get-ScoutPdfProp $Findings 'Errors' @())
        $allFindings = @(Get-ScoutPdfProp $Findings 'Findings' @())

        # ---- AB#379 diagram lookup ----
        $diagram = Get-ScoutPdfDiagram -OutputPath $OutputPath
        $diagramNote = $null
        if (-not $diagram) {
            $diagramNote = 'Architecture diagram not embedded for this run: no diagram.jpg/.jpeg was found in the output folder (or it was not a supported baseline JPEG). Place a JPEG-format diagram export at "<OutputPath>/diagram.jpg" before rendering to include one -- PNG sources must be converted to JPEG first, since this renderer embeds JPEG bytes directly with zero external dependencies and carries no PNG pixel decoder.'
        }

        # ==== Cover page ====
        Start-ScoutPdfPage $ctx -FooterLabel 'Azure Scout Assessment Report'
        Add-ScoutPdfHeading $ctx 'AZURE SCOUT' 13 'F2' $Script:ScoutPdfSteel
        Add-ScoutPdfHeading $ctx 'Assessment Report' 26 'F2' $Script:ScoutPdfNavy
        Add-ScoutPdfLine $ctx "Scope: $(if ($meta.Scope) { $meta.Scope } else { '(unspecified)' })" 11 'F1' $Script:ScoutPdfGray
        if ($meta.ManagementGroupId) {
            Add-ScoutPdfLine $ctx "Management Group: $($meta.ManagementGroupId)" 11 'F1' $Script:ScoutPdfGray
        }
        Add-ScoutPdfLine $ctx "Generated: $(if ($generatedOn) { $generatedOn } else { '(unknown)' })" 11 'F1' $Script:ScoutPdfGray
        $ctx.Y -= 6

        Add-ScoutPdfSubsection $ctx 'Framework Alignment'
        if (@($frameworks).Count -eq 0) {
            Add-ScoutPdfBullet $ctx 'No framework scored for this run.' $Script:ScoutPdfGray
        }
        else {
            foreach ($fw in @($frameworks)) {
                $fwScore = Get-ScoutPdfProp $fw 'Score' $null
                $scoreTxt = if ($null -eq $fwScore) { 'not scored' } else { "$fwScore / 100" }
                Add-ScoutPdfBullet $ctx "$(Get-ScoutPdfProp $fw 'Framework' '?') alignment score: $scoreTxt" (Get-ScoutPdfScoreColor $fwScore)
            }
        }
        $ctx.Y -= 6

        Add-ScoutPdfSubsection $ctx 'Architecture Diagram'
        if ($diagram) {
            $boxW = 300.0; $boxH = 180.0
            $scale = [math]::Min($boxW / $diagram.Width, $boxH / $diagram.Height)
            $imgW = $diagram.Width * $scale
            $imgH = $diagram.Height * $scale
            ScoutPdfEnsureSpace $ctx ($imgH + 10)
            Add-ScoutPdfImage $ctx $ctx.Margin ($ctx.Y - $imgH) $imgW $imgH
            $ctx.Y -= ($imgH + 10)
        }
        else {
            Add-ScoutPdfBullet $ctx $diagramNote $Script:ScoutPdfGray
        }

        # ==== Executive summary ====
        Start-ScoutPdfPage $ctx
        Add-ScoutPdfSubsection $ctx 'Executive Summary'
        $areaArr = @($areas)
        $passSum = ($areaArr | ForEach-Object { Get-ScoutPdfProp $_ 'Pass' 0 } | Measure-Object -Sum).Sum
        $partialSum = ($areaArr | ForEach-Object { Get-ScoutPdfProp $_ 'Partial' 0 } | Measure-Object -Sum).Sum
        $failSum = ($areaArr | ForEach-Object { Get-ScoutPdfProp $_ 'Fail' 0 } | Measure-Object -Sum).Sum
        $manualCount = @($manual).Count
        $errorCount = @($errors).Count
        $highGaps = @($gaps | Where-Object { (Get-ScoutPdfSeverityLabel (Get-ScoutPdfProp $_ 'Severity' $null)) -eq 'HIGH' }).Count

        Add-ScoutPdfBullet $ctx "Areas assessed: $($areaArr.Count)"
        Add-ScoutPdfBullet $ctx "Rules evaluated -- Pass: $passSum, Partial: $partialSum, Fail: $failSum"
        $criticalColor = if ($highGaps -gt 0) { $Script:ScoutPdfRed } else { $Script:ScoutPdfGreen }
        Add-ScoutPdfBullet $ctx "Critical (High severity) gaps: $highGaps" $criticalColor
        Add-ScoutPdfBullet $ctx "Manual review items pending: $manualCount"
        Add-ScoutPdfBullet $ctx "Unknown/Error findings (check collector permissions): $errorCount"

        # ==== Findings by area (AB#394 header repeat lives here) ====
        Start-ScoutPdfPage $ctx
        Add-ScoutPdfSubsection $ctx 'Findings by Area'
        $colX = @($ctx.Margin, $ctx.Margin + 65, $ctx.Margin + 140, $ctx.Margin + 215)
        $ctx.HeaderRepeat = { param($c) Add-ScoutPdfTableHeader $c $colX }
        Add-ScoutPdfTableHeader $ctx $colX

        $grouped = @($allFindings | Group-Object Framework, Area | Sort-Object Name)
        if ($grouped.Count -eq 0) {
            $ctx.HeaderRepeat = $null
            Add-ScoutPdfLine $ctx 'No findings recorded for this run.'
        }
        else {
            foreach ($grp in $grouped) {
                $fw0 = $grp.Group[0].Framework
                $ar0 = $grp.Group[0].Area
                $areaMatch = $areaArr | Where-Object { $_.Framework -eq $fw0 -and $_.Area -eq $ar0 } | Select-Object -First 1
                $areaScore = if ($areaMatch) { Get-ScoutPdfProp $areaMatch 'Score' $null } else { $null }
                ScoutPdfEnsureSpace $ctx 32   # heading + room for at least one row -- avoid an orphaned heading
                Add-ScoutPdfAreaHeading $ctx "$fw0 - $ar0" $areaScore
                foreach ($f in $grp.Group) { Add-ScoutPdfTableRow $ctx $colX $f }
            }
            $ctx.HeaderRepeat = $null
        }

        # ==== Prioritized gaps ====
        Start-ScoutPdfPage $ctx
        Add-ScoutPdfSubsection $ctx 'Prioritized Gaps'
        if (@($gaps).Count -eq 0) {
            Add-ScoutPdfBullet $ctx 'No gaps -- every scorable rule passed.' $Script:ScoutPdfGreen
        }
        else {
            $gapsSorted = @($gaps | Sort-Object @{ Expression = { Get-ScoutPdfSeverityRank (Get-ScoutPdfProp $_ 'Severity' $null) } }, Area)
            $top = @($gapsSorted | Select-Object -First 25)
            foreach ($g in $top) {
                $sev = Get-ScoutPdfProp $g 'Severity' $null
                $label = "[$(Get-ScoutPdfSeverityLabel $sev)] $(Get-ScoutPdfProp $g 'Area' '') -- $(Get-ScoutPdfProp $g 'Title' '')"
                Add-ScoutPdfBullet $ctx $label (Get-ScoutPdfSeverityColor $sev)
            }
            if (@($gaps).Count -gt $top.Count) {
                Add-ScoutPdfLine $ctx "... and $((@($gaps).Count) - $top.Count) more (see the JSON/Excel evidence exports for the full list)." 9 'F1' $Script:ScoutPdfGray
            }
        }

        # ==== Manual review ====
        Start-ScoutPdfPage $ctx
        Add-ScoutPdfSubsection $ctx 'Manual Review Items'
        if (@($manual).Count -eq 0) {
            Add-ScoutPdfBullet $ctx 'No items require manual review.' $Script:ScoutPdfGreen
        }
        else {
            foreach ($m in @($manual)) {
                $label = "$(Get-ScoutPdfProp $m 'Area' '') -- $(Get-ScoutPdfProp $m 'Title' '')"
                Add-ScoutPdfBullet $ctx $label $Script:ScoutPdfSteel
            }
        }

        Complete-ScoutPdfPage $ctx

        $bytes = New-ScoutPdfDocument -Ctx $ctx -Diagram $diagram
        $pdfPath = Join-Path $OutputPath 'assessment_report.pdf'
        [System.IO.File]::WriteAllBytes($pdfPath, $bytes)

        if ($diagramNote) { Write-Warning "Export-Pdf: $diagramNote" }

        return $pdfPath
    }
    catch {
        Write-Warning "Export-Pdf: PDF generation failed ($_) -- writing a print-optimized HTML fallback instead."
        try {
            return (Export-ScoutPdfHtmlFallback -Findings $Findings -Collect $Collect -OutputPath $OutputPath -Reason $_.Exception.Message)
        }
        catch {
            Write-Warning "Export-Pdf: HTML fallback also failed: $_"
            return $null
        }
    }
}
