#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Emit star-schema CSVs and copy the .pbit template bound to them.

.NOTES
    Tracks ADO Story AB#5046.
#>
function Export-PowerBi {
    param($Findings, $Collect, [string] $OutputPath)
    $pbiDir = Join-Path $OutputPath 'powerbi'
    New-Item -ItemType Directory -Path $pbiDir -Force | Out-Null

    $Findings.Areas      | Export-Csv "$pbiDir/fact_area_scores.csv" -NoTypeInformation
    $Findings.Frameworks | Export-Csv "$pbiDir/fact_framework.csv"   -NoTypeInformation
    $Findings.Gaps       | Export-Csv "$pbiDir/dim_gaps.csv"         -NoTypeInformation
    $Findings.Findings | Select-Object Id, Framework, Area, Severity, Status, EvidenceCount, Title, Remediation, Manual |
        Export-Csv "$pbiDir/fact_findings.csv" -NoTypeInformation

    $tpl = "$PSScriptRoot/../templates/report.pbit"
    if (Test-Path $tpl) { Copy-Item $tpl "$pbiDir/report.pbit" }
    @"
Open report.pbit in Power BI Desktop.
When prompted for the 'DataFolder' parameter, point it at:
  $pbiDir
Refresh. The model binds to the CSVs above (star schema: fact_findings + dim_gaps + fact_area_scores).
"@ | Out-File "$pbiDir/README.txt"
}
