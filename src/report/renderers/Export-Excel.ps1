#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Emit the raw evidence pack: one sheet per area, all findings. Retained tier.

.NOTES
    Uses ImportExcel if available; falls back to CSV-per-area. Tracks ADO Story AB#5049.
#>
function Export-Excel {
    param($Findings, $Collect, [string] $OutputPath)
    $xlsx = "$OutputPath/assessment_evidence.xlsx"
    if (Get-Module -ListAvailable -Name ImportExcel) {
        Import-Module ImportExcel
        $Findings.Findings | Group-Object Area | ForEach-Object {
            $sheet = ($_.Name -replace '[^\w]', '_') | ForEach-Object { $_.Substring(0, [math]::Min(31, $_.Length)) }
            $_.Group | Select-Object Id, Framework, Severity, Status, EvidenceCount, Title, Remediation |
                Export-Excel -Path $xlsx -WorksheetName $sheet -AutoSize -Append
        }
    }
    else {
        Write-Warning 'ImportExcel module not found — writing CSV evidence pack instead.'
        $evDir = Join-Path $OutputPath 'evidence'
        New-Item -ItemType Directory -Path $evDir -Force | Out-Null
        $Findings.Findings | Group-Object Area | ForEach-Object {
            $name = ($_.Name -replace '[^\w]', '_')
            $_.Group | Export-Csv "$evDir/$name.csv" -NoTypeInformation
        }
    }
}
