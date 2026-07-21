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
        # Excel worksheet names cap at 31 chars. Truncating alone can collapse two
        # similarly-prefixed areas into one sheet and -Append silently interleaves
        # their evidence. Disambiguate on collision (AB#5091).
        $used = @{}
        $Findings.Findings | Group-Object Area | ForEach-Object {
            $base = ($_.Name -replace '[^\w]', '_')
            $sheet = $base.Substring(0, [math]::Min(31, $base.Length))
            if ($used.ContainsKey($sheet)) {
                $used[$sheet]++
                $suffix = "~$($used[$sheet])"
                $sheet = $base.Substring(0, [math]::Min(31 - $suffix.Length, $base.Length)) + $suffix
            }
            else { $used[$sheet] = 1 }
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
