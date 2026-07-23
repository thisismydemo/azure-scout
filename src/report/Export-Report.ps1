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
    param([string] $Renderer, $Findings, $Collect, [string] $OutputPath)
    switch ($Renderer) {
        'PowerBi' { Export-PowerBi -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Html'    { Export-Html    -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Pptx'    { Export-Pptx    -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Excel'   { Export-Excel   -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Json'    { $Findings | ConvertTo-Json -Depth 100 | Out-File "$OutputPath/findings.json" }
        default   { Write-Warning "Unknown renderer '$Renderer' — skipped." }
    }
}
