#Requires -Version 7.0

<#
.SYNOPSIS
    Regenerate docs/reference/framework-coverage.md — how much of each enumerated framework
    Azure Scout actually has a rule for.

.DESCRIPTION
    docs/frameworks/*.md faithfully enumerate each published framework, and
    tests/FrameworkCurrency.Tests.ps1 keeps those enumerations fresh. What no page has ever
    stated is how much of each framework Scout COVERS. The figure existed — the AB#6447 audit
    put CAF at roughly 10% and WAF at roughly 15% — but it lived in a PMO audit nobody outside
    the programme reads, while the documentation implied full framework alignment.

    Coverage here is deliberately narrow and checkable: an enumerated item counts as covered
    when its identifier appears anywhere in src/assess/rules/. For most sets the rule id IS the
    framework item id (CGOV-AI-01, WAF-CO-01, CASA-AV-01), so this is an exact match rather
    than a judgement.

    It is a COVERAGE measure, not a quality one. It says a rule exists for the item; it does
    not say the rule is a good test of it, and a rule that is `manual: true` still counts as
    covered because a human is being asked the question. The page says so.

.PARAMETER OutputPath
    Defaults to docs/reference/framework-coverage.md.

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
    $OutputPath = Join-Path $RepoRoot 'docs' 'reference' 'framework-coverage.md'
}

$FrameworkDir = Join-Path $RepoRoot 'docs' 'frameworks'
$RulesText = (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'src' 'assess' 'rules') -Filter '*.yaml' -File |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

# An enumerated item id: two or three uppercase segments then a number, e.g. WAF-CO-01,
# CGOV-SC-02, AUT-DEV-01. Anchored to a table cell or list item so prose mentions of a
# framework name are not mistaken for items.
$IdPattern = '\b([A-Z][A-Z0-9]{1,7}-[A-Z0-9]{1,6}-[0-9]{1,3})\b'

$Rows = [System.Collections.Generic.List[object]]::new()
foreach ($f in (Get-ChildItem -LiteralPath $FrameworkDir -Filter '*.md' -File | Sort-Object Name)) {
    if ($f.Name -eq 'README.md') { continue }
    $text = Get-Content -LiteralPath $f.FullName -Raw
    $ids = @([regex]::Matches($text, $IdPattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($ids.Count -eq 0) {
        $Rows.Add([pscustomobject]@{
                File = $f.BaseName; Enumerated = 0; Covered = 0; Percent = $null
                Missing = @(); Areas = 0; AreasCovered = 0
            })
        continue
    }
    $covered = @($ids | Where-Object { $RulesText -match [regex]::Escape($_) })

    # GRANULARITY MISMATCH, handled rather than hidden. The CAF landing-zone enumeration lists
    # individual recommendations (AUT-DEV-01, AUT-DEV-02, ...) while the rule set works one
    # level up, at design-area granularity (CAF-AUT-01..06). Item-for-item matching therefore
    # reports 0% for CAF, which is as misleading as claiming full coverage: rules for that area
    # do exist, they simply are not written per recommendation. So the area-level figure is
    # computed too, and the page reports both and says which is which.
    $areas = @($ids | ForEach-Object { ($_ -split '-')[0] } | Sort-Object -Unique)
    $areasCovered = @($areas | Where-Object { $RulesText -match "\b[A-Z]{2,5}-$([regex]::Escape($_))-[0-9]" -or $RulesText -match "\b$([regex]::Escape($_))-[A-Z0-9]{1,6}-[0-9]" })

    $Rows.Add([pscustomobject]@{
            File         = $f.BaseName
            Enumerated   = $ids.Count
            Covered      = $covered.Count
            Percent      = [Math]::Round($covered.Count / $ids.Count * 100)
            Missing      = @($ids | Where-Object { $_ -notin $covered })
            Areas        = $areas.Count
            AreasCovered = $areasCovered.Count
        })
}

$TotalEnum = ($Rows | Measure-Object -Property Enumerated -Sum).Sum
$TotalCov = ($Rows | Measure-Object -Property Covered -Sum).Sum
$TotalPct = if ($TotalEnum -gt 0) { [Math]::Round($TotalCov / $TotalEnum * 100) } else { 0 }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('description: How much of each enumerated framework Azure Scout actually has a rule for.')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('# Framework Coverage')
[void]$sb.AppendLine()
[void]$sb.AppendLine("Across every framework Azure Scout enumerates, **$TotalCov of $TotalEnum items ($TotalPct%) have a rule behind them**.")
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: warning Read this number the right way')
[void]$sb.AppendLine('Scout **enumerates** each framework in full — see [Frameworks](../frameworks/README.md) — and a test')
[void]$sb.AppendLine('keeps those enumerations current. Enumerating an item is not the same as testing it.')
[void]$sb.AppendLine('This page is the difference between the two, and it is published because the alternative')
[void]$sb.AppendLine('is a reader assuming that "supports CAF and WAF" means full coverage. It does not.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('An item counts as **covered** when a rule references its identifier. That is a coverage')
[void]$sb.AppendLine('measure, not a quality one: it says a rule exists, not that the rule is a good test of the')
[void]$sb.AppendLine('item. A `manual: true` rule still counts, because a human is at least being asked the')
[void]$sb.AppendLine('question — see the [Assessment Catalogue](./assessment-catalogue.md) for how many rules are')
[void]$sb.AppendLine('manual, which is a large share of them.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: tip This page is generated')
[void]$sb.AppendLine('Regenerate with `scripts/Build-FrameworkCoverage.ps1`. Counts come from')
[void]$sb.AppendLine('`docs/frameworks/*.md` and `src/assess/rules/`; a test fails the build if the committed page')
[void]$sb.AppendLine('and a fresh regeneration disagree.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()
[void]$sb.AppendLine('## Coverage by framework')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| Framework enumeration | Items | Covered | Item coverage | Areas covered |')
[void]$sb.AppendLine('|---|--:|--:|--:|--:|')
foreach ($r in ($Rows | Sort-Object { -$_.Enumerated })) {
    if ($r.Enumerated -eq 0) {
        [void]$sb.AppendLine("| ``$($r.File)`` | — | — | *not enumerated with item ids* | — |")
        continue
    }
    $areaCol = "$($r.AreasCovered) / $($r.Areas)"
    [void]$sb.AppendLine("| [``$($r.File)``](../frameworks/$($r.File).md) | $($r.Enumerated) | $($r.Covered) | **$($r.Percent)%** | $areaCol |")
}
[void]$sb.AppendLine("| **Total** | **$TotalEnum** | **$TotalCov** | **$TotalPct%** | |")
[void]$sb.AppendLine()
[void]$sb.AppendLine('::: warning Where item coverage reads 0%, check the areas column')
[void]$sb.AppendLine('`caf-landing-zone-design-areas` enumerates individual recommendations (`AUT-DEV-01`,')
[void]$sb.AppendLine('`AUT-DEV-02`, …) while Scout''s CAF rules are written one level up, per design area')
[void]$sb.AppendLine('(`CAF-AUT-01`…`CAF-AUT-06`). No rule maps to a specific enumerated recommendation, so')
[void]$sb.AppendLine('item coverage is 0% **by construction** — but rules for those areas do exist, which is what')
[void]$sb.AppendLine('the areas column shows.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('Read that as: Scout checks something in most CAF design areas, and checks it broadly. It')
[void]$sb.AppendLine('does not test the 393 individual recommendations Microsoft publishes, and no page should')
[void]$sb.AppendLine('imply that it does.')
[void]$sb.AppendLine(':::')
[void]$sb.AppendLine()

$gaps = @($Rows | Where-Object { $_.Enumerated -gt 0 -and $_.Missing.Count -gt 0 } | Sort-Object { -$_.Missing.Count })
if ($gaps.Count -gt 0) {
    [void]$sb.AppendLine('## What is not covered')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('The specific items with no rule of their own. This is the backlog, stated rather than implied.')
    [void]$sb.AppendLine()
    foreach ($g in ($gaps | Select-Object -First 4)) {
        [void]$sb.AppendLine("### ``$($g.File)`` — $($g.Missing.Count) of $($g.Enumerated) uncovered")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((($g.Missing | ForEach-Object { "``$_``" }) -join ', '))
        [void]$sb.AppendLine()
    }
}

$Content = $sb.ToString()

if ($Check) {
    $committed = if (Test-Path -LiteralPath $OutputPath) { Get-Content -LiteralPath $OutputPath -Raw } else { '' }
    $normalise = { param($s) (($s -replace "`r`n", "`n").TrimEnd("`n")) }
    if ((& $normalise $committed) -ne (& $normalise $Content)) {
        Write-Error "$OutputPath is out of date. Regenerate it with scripts/Build-FrameworkCoverage.ps1"
        exit 1
    }
    Write-Host '[Build-FrameworkCoverage] docs/reference/framework-coverage.md is current.'
    exit 0
}

Set-Content -LiteralPath $OutputPath -Value $Content -Encoding utf8NoBOM
Write-Host "[Build-FrameworkCoverage] Wrote $OutputPath ($TotalCov/$TotalEnum items covered, $TotalPct%)"
