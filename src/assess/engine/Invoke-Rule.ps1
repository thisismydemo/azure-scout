#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Evaluate a single rule against the collect object, returning a finding.

.NOTES
    Supports the seven assert types. Tracks ADO Story AB#5030.
#>
function Invoke-Rule {
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] $Collect,
        [string] $Area,
        [string] $Framework
    )

    $status = 'Unknown'; $evidenceCount = 0; $evidence = @()

    if ($Rule.manual -or $Rule.assert.type -eq 'manual') {
        # pre-fill with any evidence the scan DID find, then hand to the human
        if ($Rule.query) {
            $evidence = Resolve-JsonPath -InputObject $Collect -Path $Rule.query
            $evidenceCount = $evidence.Count
        }
        $status = 'Manual'
    }
    else {
        $matches = Resolve-JsonPath -InputObject $Collect -Path $Rule.query
        $evidenceCount = $matches.Count
        $evidence = $matches | Select-Object -First 25    # cap evidence payload
        $v = $Rule.assert.value

        switch ($Rule.assert.type) {
            'countGreaterThan'  { $status = ($evidenceCount -gt  $v) ? 'Pass' : 'Fail' }
            'countEquals'       { $status = ($evidenceCount -eq  $v) ? 'Pass' : 'Fail' }
            'countLessThan'     { $status = ($evidenceCount -lt  $v) ? 'Pass' : 'Fail' }
            'exists'            { $status = ($evidenceCount -gt   0) ? 'Pass' : 'Fail' }
            'notExists'         { $status = ($evidenceCount -eq   0) ? 'Pass' : 'Fail' }
            'percentageAtLeast' {
                $denom = (Resolve-JsonPath -InputObject $Collect -Path $Rule.assert.denominatorQuery).Count
                $pct   = if ($denom -gt 0) { $evidenceCount / $denom * 100 } else { 0 }
                $status = ($pct -ge $v) ? 'Pass' : (($pct -gt 0) ? 'Partial' : 'Fail')
            }
            default { $status = 'Unknown' }
        }
    }

    [pscustomobject]@{
        Id            = $Rule.id
        Title         = $Rule.title
        Framework     = $Framework
        Area          = $Area
        Severity      = $Rule.severity
        Status        = $status
        EvidenceCount = $evidenceCount
        Evidence      = $evidence
        Remediation   = $Rule.remediation
        Manual        = [bool]$Rule.manual
    }
}
