#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Dispatch a requested renderer to its Export-* implementation.

.NOTES
    Every renderer reads the same findings.json. Tracks ADO Story AB#5045.
#>
function Export-Report {
    # $Drift (optional) is the cross-run drift object from Get-ScoutDrift; only the
    # React renderer consumes it (to populate its Drift tab). Other renderers ignore it.
    param([string] $Renderer, $Findings, $Collect, [string] $OutputPath, $Drift = $null)
    switch ($Renderer) {
        'PowerBi' { Export-PowerBi -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Html'    { Export-Html    -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Pptx'    { Export-Pptx    -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Excel'   { Export-Excel   -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'React'   { Export-React   -Findings $Findings -Collect $Collect -OutputPath $OutputPath -Drift $Drift }
        'Json'    { $Findings | ConvertTo-Json -Depth 100 | Out-File "$OutputPath/findings.json" }
        # AB#396: resources-only evidence export (raw Collect only -- no assessment
        # metadata/scores/findings; see Export-JsonEvidence.ps1's own header for why).
        'JsonEvidence' { Export-JsonEvidence -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        # AB#379/394/395: hand-rolled, dependency-free .pdf renderer (cover, exec
        # summary, per-area findings table with repeating header, gaps, manual
        # review). See Export-Pdf.ps1's own header for the offline-PDF design.
        'Pdf' { Export-Pdf -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        default   { Write-Warning "Unknown renderer '$Renderer' — skipped." }
    }
}
