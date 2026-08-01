#Requires -Version 7.0

<#
.SYNOPSIS
    Regenerate docs/reference/collector-fields.md — the worksheet and columns each collector
    produces.

.DESCRIPTION
    docs/reference/arm-modules.md answers "what is covered" by mapping each collector to the
    resource types it targets. It does not answer "what comes back", which is the question
    someone asks before trusting a worksheet or building anything on top of the JSON.

    Every collector definition already declares an Export block with a WorksheetName and an
    ordered Columns list, so this is generated from the manifests rather than written by hand —
    the same discipline as the other two catalogues, adopted because the previously
    hand-maintained module catalogue drifted fifteen collectors out of date while claiming to
    be generated (AB#6741).

.PARAMETER OutputPath
    Defaults to docs/reference/collector-fields.md.

.PARAMETER Check
    Compare against the committed page; exit non-zero on any difference.
#>
[CmdletBinding()]
param(
    [string] $OutputPath,
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot 'docs' 'reference' 'collector-fields.md'
}

$CollectorRoot = Join-Path $RepoRoot 'manifests' 'collectors'
$Categories = @(Get-ChildItem -LiteralPath $CollectorRoot -Directory | Sort-Object Name)

$Rows = [System.Collections.Generic.List[object]]::new()
foreach ($cat in $Categories) {
    foreach ($file in (Get-ChildItem -LiteralPath $cat.FullName -Filter '*.psd1' -File -Recurse | Sort-Object BaseName)) {
        $def = Import-PowerShellDataFile -LiteralPath $file.FullName

        $worksheet = ''
        $columns = @()
        if ($def.ContainsKey('Export') -and $def.Export) {
            if ($def.Export.ContainsKey('WorksheetName')) { $worksheet = "$($def.Export.WorksheetName)" }
            if ($def.Export.ContainsKey('Columns')) { $columns = @($def.Export.Columns) }
        }

        $Rows.Add([pscustomobject]@{
                Category  = $cat.Name
                Collector = $file.BaseName
                Worksheet = $worksheet
                Columns   = $columns
            })
    }
}

$Total = $Rows.Count
$WithColumns = @($Rows | Where-Object { $_.Columns.Count -gt 0 }).Count
$NoExport = @($Rows | Where-Object { $_.Columns.Count -eq 0 })

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('description: The worksheet and columns each Azure Scout collector produces.')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('# Collector Fields')
[void]$sb.AppendLine()
if ($WithColumns -eq $Total) {
    [void]$sb.AppendLine("What each collector actually returns. **All $Total collectors** declare a worksheet and an")
    [void]$sb.AppendLine('ordered column list.')
}
else {
    [void]$sb.AppendLine("What each collector actually returns. **$WithColumns of $Total collectors** declare a worksheet")
    [void]$sb.AppendLine('and an ordered column list; the rest feed the assessment engine or another collector rather')
    [void]$sb.AppendLine('than producing a worksheet of their own.')
}
[void]$sb.AppendLine()
[void]$sb.AppendLine('[ARM Modules](./arm-modules.md) answers *what is covered* — collector to resource type.')
[void]$sb.AppendLine('This page answers *what comes back*, which is the question worth asking before trusting a')
[void]$sb.AppendLine('worksheet or building on the JSON.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: tip This page is generated')
[void]$sb.AppendLine('Regenerate with `scripts/Build-CollectorFieldCatalog.ps1`. Columns come from each')
[void]$sb.AppendLine('definition''s `Export` block in `manifests/collectors/`; a test fails the build if the')
[void]$sb.AppendLine('committed page and a fresh regeneration disagree.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: warning A column is not a guarantee of data')
[void]$sb.AppendLine('These are the columns a collector *would* emit. Whether any row appears depends on what')
[void]$sb.AppendLine('exists in the tenant and on what the signed-in identity is permitted to read. Every run')
[void]$sb.AppendLine('writes `collector-rowcounts.json` recording what each collector produced **and why it')
[void]$sb.AppendLine('produced nothing** — that file, not this page, tells you whether an empty worksheet means')
[void]$sb.AppendLine('"none exist" or "not permitted".')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()

foreach ($cat in $Categories) {
    $group = @($Rows | Where-Object { $_.Category -eq $cat.Name })
    if ($group.Count -eq 0) { continue }
    [void]$sb.AppendLine("## $($cat.Name) ($($group.Count) collectors)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Collector | Worksheet | Columns |')
    [void]$sb.AppendLine('|---|---|---|')
    foreach ($r in $group) {
        $ws = if ($r.Worksheet) { $r.Worksheet } else { '*none*' }
        $cols = if ($r.Columns.Count -gt 0) {
            (($r.Columns | ForEach-Object { "``$_``" }) -join ', ')
        } else { '*no worksheet export*' }
        [void]$sb.AppendLine("| **$($r.Collector)** | $ws | $cols |")
    }
    [void]$sb.AppendLine()
}

if ($NoExport.Count -gt 0) {
    [void]$sb.AppendLine('## Collectors with no worksheet export')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("$($NoExport.Count) collectors declare no `Export` block. They collect data consumed by the")
    [void]$sb.AppendLine('assessment engine, by another collector, or by the raw inventory dump — not by a worksheet.')
    [void]$sb.AppendLine('They are listed so their absence from the Excel report is explained rather than mysterious.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine((($NoExport | ForEach-Object { "``$($_.Category)/$($_.Collector)``" }) -join ', '))
    [void]$sb.AppendLine()
}

$Content = $sb.ToString()

if ($Check) {
    $committed = if (Test-Path -LiteralPath $OutputPath) { Get-Content -LiteralPath $OutputPath -Raw } else { '' }
    $normalise = { param($s) (($s -replace "`r`n", "`n").TrimEnd("`n")) }
    if ((& $normalise $committed) -ne (& $normalise $Content)) {
        Write-Error "$OutputPath is out of date. Regenerate it with scripts/Build-CollectorFieldCatalog.ps1"
        exit 1
    }
    Write-Host '[Build-CollectorFieldCatalog] docs/reference/collector-fields.md is current.'
    exit 0
}

Set-Content -LiteralPath $OutputPath -Value $Content -Encoding utf8NoBOM
Write-Host "[Build-CollectorFieldCatalog] Wrote $OutputPath ($Total collectors, $WithColumns with a worksheet export)"
