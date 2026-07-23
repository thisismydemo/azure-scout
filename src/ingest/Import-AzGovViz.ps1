#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Run the Azure Governance Visualizer (read-only) and fold its JSON exports
    into the collect object under a 'governance' key.

.NOTES
    Read-only: Reader at MG root + read-only Graph app permissions. Tracks ADO Story AB#5038.
#>
function Import-AzGovViz {
    param($Collect, [string] $OutputPath, [string] $ManagementGroupId)

    # AzGovViz needs a management-group scope; without one its parameter prompts spin
    # forever in a non-interactive host. Skip the ingest — Compare-Benchmark already
    # degrades to Unknown when $Collect.governance is absent (AB#5084 guard).
    if (-not $ManagementGroupId) {
        Write-Warning 'Import-AzGovViz: no -ManagementGroupId supplied; skipping AzGovViz ingest (governance rules will report Unknown).'
        return $Collect
    }

    $govPath = Join-Path $OutputPath 'govviz'
    New-Item -ItemType Directory -Path $govPath -Force | Out-Null

    # Clone/run the visualizer (pin a version in real use). Read-only.
    if (-not (Test-Path "$govPath/repo/pwsh/AzGovVizParallel.ps1")) {
        git clone --depth 1 https://github.com/Azure/Azure-Governance-Visualizer.git "$govPath/repo" 2>$null
    }
    & "$govPath/repo/pwsh/AzGovVizParallel.ps1" `
        -ManagementGroupId $ManagementGroupId `
        -OutputPath        $govPath `
        -DoPSRule `
        -NoScopeInsights `
        -ALZPolicyAssignmentsChecker

    # Fold selected JSON exports into the collect object under a 'governance' key
    $jsonDir = Get-ChildItem "$govPath" -Directory -Filter 'JSON_*' | Select-Object -First 1
    if ($jsonDir) {
        $Collect | Add-Member -NotePropertyName governance -NotePropertyValue ([pscustomobject]@{
            policyAssignments = (Get-ChildItem "$($jsonDir.FullName)" -Recurse -Filter '*PolicyAssignments*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100 })
            roleAssignments   = (Get-ChildItem "$($jsonDir.FullName)" -Recurse -Filter '*RoleAssignments*.json'   | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100 })
            alzPolicyChecker  = (Get-ChildItem "$govPath" -Recurse -Filter '*ALZPolicyVersionChecker.csv' | Select-Object -First 1 | ForEach-Object { Import-Csv $_.FullName })
        }) -Force
    }
    return $Collect
}
