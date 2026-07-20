#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Diff the live tenant against the ALZ reference, emitting Pass/Fail findings.

.NOTES
    Tracks ADO Story AB#5043.
#>
function Compare-Benchmark {
    param($Collect, $Benchmark)
    $findings = @()

    # MG structure
    $actualMgs = @($Collect.governance.managementGroups.name)
    foreach ($mg in $Benchmark.managementGroups.expected) {
        $present = $actualMgs -contains $mg
        $findings += [pscustomobject]@{
            Id            = "BENCH-MG-$mg"
            Title         = "ALZ management group '$mg' present"
            Framework     = 'CAF'
            Area          = 'Management group & subscription org'
            Severity      = 'medium'
            Status        = ($present ? 'Pass' : 'Fail')
            EvidenceCount = [int]$present
            Evidence      = @()
            Remediation   = "Create the '$mg' management group per ALZ archetype."
            Manual        = $false
        }
    }

    # required policy assignments (leverages the visualizer's ALZ checker if present)
    $assigned = @($Collect.governance.policyAssignments.properties.displayName)
    foreach ($p in $Benchmark.requiredPolicyAssignments) {
        $present = ($assigned -match $p).Count -gt 0
        $findings += [pscustomobject]@{
            Id            = "BENCH-POL-$p"
            Title         = "Required ALZ policy '$p' assigned"
            Framework     = 'CAF'
            Area          = 'Governance (policy & compliance)'
            Severity      = 'high'
            Status        = ($present ? 'Pass' : 'Fail')
            EvidenceCount = [int]$present
            Evidence      = @()
            Remediation   = "Assign ALZ policy/initiative '$p'."
            Manual        = $false
        }
    }
    return $findings
}
