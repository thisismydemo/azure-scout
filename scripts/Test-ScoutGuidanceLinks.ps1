#Requires -Version 7.0
<#
.SYNOPSIS
    Link-rot audit over every learn.microsoft.com URL cited by the assessment rule files.

.DESCRIPTION
    AB#6913. Every rule file carries a `frameworkversion:` citation naming the Microsoft Learn
    guidance it was written against, and the renderers surface those citations to the reader as
    "here is the guidance for this finding". A citation that 404s is therefore a customer-facing
    defect, not a cosmetic one -- and the "verified <date>" stamp in the file is no protection,
    because Microsoft renames pages after the verification happens.

    Found in the field: the Platform automation & DevOps design area was cited as
    `.../design-area/platform-automation-and-devops` (with "and") and marked verified 2026-08-01;
    the real canonical page is `.../design-area/platform-automation-devops`, and the cited form
    returns HTTP 404.

    Deliberately a script and not a Pester test: it needs outbound network, which would make the
    CI suite flaky and dependent on Microsoft's uptime. Run it when rule files change or when
    refreshing guidance citations.

.PARAMETER RulePath
    Glob for the rule files to audit. Defaults to the repo's assessment rules.

.EXAMPLE
    ./scripts/Test-ScoutGuidanceLinks.ps1
    Audits every cited Learn URL and exits non-zero if any is dead.

.NOTES
    Exit code 1 when any cited URL fails, so it can gate a guidance-refresh PR.
#>
[CmdletBinding()]
param(
    [string] $RulePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $RulePath) { $RulePath = Join-Path $repoRoot 'src/assess/rules/*.yaml' }

# Trailing '.' and ',' are prose punctuation in the citation sentence, not part of the URL.
$urls = @(
    Select-String -Path $RulePath -Pattern 'learn\.microsoft\.com/[a-zA-Z0-9/_.-]+' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Value.TrimEnd('.', ',') } |
        Sort-Object -Unique
)
if ($urls.Count -eq 0) { throw "No learn.microsoft.com citations found under '$RulePath'." }

Write-Host "Auditing $($urls.Count) distinct cited guidance URL(s)`n" -ForegroundColor Cyan
$dead = [System.Collections.Generic.List[object]]::new()

foreach ($u in $urls) {
    $status = -1
    try {
        # HEAD is enough and cheap; -SkipHttpErrorCheck keeps a 404 from throwing so the audit
        # reports every URL rather than stopping at the first dead one.
        $response = Invoke-WebRequest -Uri "https://$u" -Method Head -MaximumRedirection 5 `
            -SkipHttpErrorCheck -TimeoutSec 30
        $status = [int] $response.StatusCode
    }
    catch {
        $status = -1
    }

    if ($status -ge 200 -and $status -lt 400) {
        Write-Host ('  OK   {0}  {1}' -f $status, $u)
    }
    else {
        Write-Host ('  DEAD {0}  {1}' -f $status, $u) -ForegroundColor Red
        $dead.Add([pscustomobject]@{ Url = $u; Status = $status })
    }
}

Write-Host ("`n=== {0} dead citation(s) ===" -f $dead.Count) -ForegroundColor Cyan
foreach ($d in $dead) {
    $sites = @(
        Select-String -Path $RulePath -Pattern ([regex]::Escape($d.Url)) |
            ForEach-Object { '{0}:{1}' -f (Split-Path $_.Path -Leaf), $_.LineNumber } |
            Sort-Object -Unique
    )
    Write-Host ('  {0}  [{1}]  <- {2}' -f $d.Url, $d.Status, ($sites -join ', ')) -ForegroundColor Red
}

if ($dead.Count -gt 0) { exit 1 }
Write-Host 'All cited guidance URLs resolve.' -ForegroundColor Green
