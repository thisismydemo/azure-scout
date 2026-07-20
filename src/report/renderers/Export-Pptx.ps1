#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Auto-assemble an executive PowerPoint from findings.json via python-pptx.

.NOTES
    Tracks ADO Story AB#5048.
#>
function Export-Pptx {
    param($Findings, [string] $OutputPath)
    $data = $Findings | ConvertTo-Json -Depth 100
    $data | Out-File "$OutputPath/_deck_data.json" -Encoding utf8
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { Write-Warning 'python not found — skipping PPTX deck.'; return }
    python "$PSScriptRoot/../templates/build_deck.py" "$OutputPath/_deck_data.json" "$OutputPath/assessment_deck.pptx"
}
