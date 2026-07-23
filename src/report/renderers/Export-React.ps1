#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Render a self-contained, interactive HTML report (client-side filter/sort/
    search dashboard + optional cross-run drift panel) from scored findings.

.DESCRIPTION
    Same renderer contract as Export-Html/Export-Pptx/Export-Excel: consumes the
    scored Findings object produced by Get-Score (GeneratedOn/Frameworks/Areas/
    Gaps/Manual/Errors/Findings) plus the raw Collect object (only its optional
    _meta.scope / _meta.managementGroupId are read, mirroring Export-Pptx).

    Everything is inlined into one report-react.html file — CSS, JS, and the
    findings/drift data as a JSON blob in a <script> tag. No CDN fetch, no
    external <script src="http...">/<link href="http..."> references, so the
    report opens and works fully offline (same offline-artifact rule the PPTX
    renderer follows for the OpenXML SDK).

    The interactive UI (Dashboard / Findings / Gaps / Manual review / Drift
    tabs) is hand-written vanilla JS reading window.__SCOUT_DATA__ — no React
    UMD bundle, no build step, per the "vanilla JS component model" option in
    the design brief for this renderer.

.PARAMETER Findings
    The scored Findings object from Get-Score.

.PARAMETER Collect
    The raw Collect object (only _meta.scope / _meta.managementGroupId read).

.PARAMETER OutputPath
    Folder to write report-react.html into. Created if missing.

.PARAMETER Drift
    Optional. The drift object from Get-ScoutDrift (see
    src/report/Get-ScoutDrift.ps1). When supplied, the report embeds it and
    renders a Drift tab (New/Resolved/Regressed/Unchanged + per-finding
    changes + overall score delta). When omitted/$null, the Drift tab is not
    shown — this keeps Export-React callable with the exact same 3-argument
    shape as every other Export-* renderer for callers that don't have drift
    data yet (e.g. a first CollectOnly/FromCollect run), while still letting
    Invoke-ScoutAssessment pass -Drift once Get-ScoutDrift has run.

.OUTPUTS
    [string] the full path to the written report-react.html file.

.NOTES
    Tracks ADO Story AB#5053.
#>
function Export-React {
    param(
        $Findings,
        $Collect,
        [string] $OutputPath,
        $Drift = $null
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Safe property access — $Collect (and, defensively, $Findings) may be a
    # plain deserialized PSCustomObject missing keys we don't require, and
    # Set-StrictMode -Version Latest throws on a missing-property dot-access.
    $metaSrc = $null
    if ($null -ne $Collect) {
        $metaProp = $Collect.PSObject.Properties['_meta']
        if ($metaProp) { $metaSrc = $metaProp.Value }
    }
    $scope = $null
    $mgId  = $null
    if ($null -ne $metaSrc) {
        $scopeProp = $metaSrc.PSObject.Properties['scope']
        if ($scopeProp) { $scope = $scopeProp.Value }
        $mgIdProp = $metaSrc.PSObject.Properties['managementGroupId']
        if ($mgIdProp) { $mgId = $mgIdProp.Value }
    }
    $meta = [pscustomobject]@{ Scope = $scope; ManagementGroupId = $mgId }

    $payload = [pscustomobject]@{
        Findings = $Findings
        Drift    = $Drift
        Meta     = $meta
    }

    # </script> inside embedded JSON would otherwise close the <script> tag early.
    $json = ($payload | ConvertTo-Json -Depth 100) -replace '</', '<\/'

    $tplPath = "$PSScriptRoot/../templates/report-react.html.template"
    $tpl = Get-Content $tplPath -Raw
    $html = $tpl.Replace('/*__SCOUT_DATA__*/', $json)

    $outFile = Join-Path $OutputPath 'report-react.html'
    $html | Out-File $outFile -Encoding utf8

    return $outFile
}
