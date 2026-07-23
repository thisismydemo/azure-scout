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

    # AzGovViz depends on the AzAPICall module and prompts interactively to install it
    # when missing — fatal in an unattended host (AB#5050). Ensure it up front.
    if (-not (Get-Module -ListAvailable -Name AzAPICall)) {
        Write-Warning 'Import-AzGovViz: installing required AzAPICall module (CurrentUser scope).'
        Install-Module AzAPICall -Scope CurrentUser -Force -Repository PSGallery
    }

    $govPath = Join-Path $OutputPath 'govviz'
    New-Item -ItemType Directory -Path $govPath -Force | Out-Null

    # Clone/run the visualizer (pin a version in real use). Read-only.
    if (-not (Test-Path "$govPath/repo/pwsh/AzGovVizParallel.ps1")) {
        git clone --depth 1 https://github.com/Azure/Azure-Governance-Visualizer.git "$govPath/repo" 2>$null
    }
    # -NoPIMEligibility: PIM eligibility needs the PrivilegedAccess.Read.AzureResources
    # Graph app permission plus an Entra ID P2 license; without both, AzGovViz's
    # permission pre-flight hard-fails. Skip that one dataset rather than the whole run.
    # AzGovViz is third-party code that is not StrictMode-safe — this module's
    # Set-StrictMode -Version Latest propagates into it and crashes its ALZ policy
    # checker, so strict mode is disabled for the external invocation only.
    # A crash inside AzGovViz (e.g. retired ARM APIs such as classicAdministrators
    # returning 404 InvalidResourceType) must degrade the governance dataset, not kill
    # the whole Scout run — any JSON it produced before failing is still folded in below.
    try {
        & {
            Set-StrictMode -Off
            & "$govPath/repo/pwsh/AzGovVizParallel.ps1" `
                -ManagementGroupId $ManagementGroupId `
                -OutputPath        $govPath `
                -DoPSRule `
                -NoScopeInsights `
                -NoPIMEligibility `
                -ALZPolicyAssignmentsChecker
        }
    }
    catch {
        Write-Warning "Import-AzGovViz: AzGovViz run failed mid-collection: $($_.Exception.Message). Folding in any partial exports; benchmark rules degrade to Unknown where data is missing."
    }

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
