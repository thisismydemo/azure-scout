#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Native governance collector — populate collect.json's `governance` object
    directly from Azure Resource Graph + the ambient ARM token, with NO
    third-party dependency on the Azure Governance Visualizer.

.DESCRIPTION
    This is the default governance ingestor (AB#5041). It replaces the
    `Import-AzGovViz` dependency for everything the assessment rules and the ALZ
    benchmark actually query:

        governance.managementGroups[]      <- ARG resourcecontainers
        governance.policyAssignments[]     <- ARG policyresources
        governance.roleAssignments[]       <- ARG authorizationresources
        governance.budgets[]               <- ARM REST (Microsoft.Consumption)
        governance.resourceLocks[]         <- ARM REST (Microsoft.Authorization/locks)
        governance.pimEligibility[]        <- not collected here (see NOTES)
        governance.classicAdministrators[] <- not collected here (see NOTES)

    Why native instead of AzGovViz: the visualizer is heavy third-party code that
    is not StrictMode-safe and hard-fails on retired ARM APIs (e.g.
    classicAdministrators -> 404 InvalidResourceType), which took the whole Scout
    run down with it. Every governance signal the rules read is a first-class ARG
    table (policyresources / authorizationresources / resourcecontainers) or a
    simple ambient-token ARM REST call — no cloned repo, no AzAPICall install
    prompt, no interactive prompts, fully unattended. AzGovViz remains available
    as an opt-in ingestor (`Import-AzGovViz`) for anyone who wants the full
    visualizer output, but nothing depends on it by default.

    The object is attached with the SAME `Add-Member -NotePropertyName governance`
    shape the AzGovViz ingestor used, so the rule engine, Compare-Benchmark, and
    the report renderers see an identical contract.

    Read-only throughout: Reader at the management-group root is sufficient
    (policy/role/MG reads via ARG; budgets/locks via ARM GET).

.NOTES
    Tracks ADO Story AB#5041 (supersedes the AzGovViz hard dependency; Story AB#5038).

    Two datasets are deliberately NOT collected here:
      * classicAdministrators - the classic administrators ARM API is retired
        (returns 404 InvalidResourceType) and classic co-admins are being removed
        platform-wide, so an empty set reflects reality. CAF-IDN-03 asserts
        `notExists`, i.e. an empty set is the compliant (Pass) outcome.
      * pimEligibility - PIM eligible-assignment enumeration needs an Entra ID P2
        license plus the Graph `PrivilegedAccess.Read.AzureResources` application
        permission. Collecting it is out of the Reader-at-MG-root baseline this
        collector targets; left empty (unchanged from the prior AzGovViz run,
        which was invoked with -NoPIMEligibility for the same reason).
#>
function Import-Governance {
    [CmdletBinding()]
    param($Collect, [string] $ManagementGroupId)

    Import-Module Az.ResourceGraph -ErrorAction Stop
    if (-not (Get-Command Invoke-AzRestMethod -ErrorAction SilentlyContinue)) {
        Import-Module Az.Accounts -ErrorAction Stop
    }

    # ---- ARG helper: paged, scoped to the management group when one is supplied ----
    # Mirrors Invoke-Collect's paging: Search-AzGraph rejects -Skip 0
    # (ValidateRange minimum is 1), so omit it on the first page.
    function Invoke-GovArg([string] $Query, [switch] $UseTenantScope) {
        $rows = @(); $skip = 0
        do {
            $params = @{ Query = $Query; First = 1000; ErrorAction = 'Stop' }
            if ($skip -gt 0) { $params.Skip = $skip }
            # AB#6901 -- management groups are TENANT-level containers, invisible to a default
            # (subscription-scoped) Resource Graph call: proven live, 0 rows default vs 18 with
            # -UseTenantScope, same SPN, same tenant. The two scope parameters are mutually
            # exclusive on Search-AzGraph, and an explicit -ManagementGroupId run is already
            # scoped to the subtree the caller asked for, so tenant scope only applies when no
            # management group was supplied.
            if ($UseTenantScope -and -not $ManagementGroupId) { $params.UseTenantScope = $true }
            elseif ($ManagementGroupId) { $params.ManagementGroup = $ManagementGroupId }
            # AB#6779. `@(Search-AzGraph @params)` collects the PSResourceGraphResponse WRAPPER as
            # a single element rather than the rows -- always, not only when the result is empty.
            # That made $batch.Count permanently 1, so this loop's `-eq 1000` condition could NEVER
            # fire and every query here was silently capped at its first page. Reading `.Data` is
            # the only shape that behaves the same whether the result is empty or not.
            # Assigned in STATEMENTS, not as `$batch = if (...) { @($response.Data) }`: an if-block
            # yields its body through the output stream and an EMPTY array contributes zero objects
            # to it, so the expression form assigns $null on exactly the empty result this handles,
            # and `$batch.Count` below then throws under StrictMode.
            $response = Search-AzGraph @params
            $batch = @()
            if ($null -ne $response -and $response.PSObject.Properties['Data']) {
                $batch = @($response.Data)
            }
            elseif ($null -ne $response) {
                $batch = @($response)
            }
            $rows += $batch; $skip += 1000
        } while ($batch.Count -eq 1000)
        return , $rows
    }

    # 1) management groups (Compare-Benchmark matches archetype names against .name).
    #    -UseTenantScope is REQUIRED here (AB#6901): without it the query returned zero rows on
    #    every run in the product's history -- empty in all eight reference tenants across both
    #    corpus runs -- so archetype matching and the MG-hierarchy rules always scored an estate
    #    with no management groups at all.
    $mgQuery = @'
resourcecontainers
| where type =~ "microsoft.management/managementgroups"
| project name, id, displayName = tostring(properties.displayName),
          parent = tostring(properties.details.parent.name)
'@
    $mgs = @()
    try {
        $mgs = Invoke-GovArg $mgQuery -UseTenantScope
    }
    catch {
        # Tenant scope needs a tenant-level read the caller may not hold (Reader at root MG). The
        # default-scope retry keeps the old behavior as the floor rather than trading one empty
        # result for a new hard failure.
        Write-Verbose "Import-Governance: tenant-scoped management-group query failed, retrying at default scope (AB#6901): $($_.Exception.Message)"
        try { $mgs = Invoke-GovArg $mgQuery }
        catch { Write-Warning "Import-Governance: management-group query failed: $($_.Exception.Message)" }
    }

    # ---- what the collect pass already handed over (AB#6779) ----------------------------------
    # Four of the six datasets below are now collected by Get-ScoutRawInventory, because the four
    # inventory collectors that render them (Identity/RoleAssignments, Management/PolicyAssignments,
    # Management/ResourceLocks, Management/Budgets) run over the raw pass's resource rows, not over
    # collect.json. Invoke-Collect puts them on $Collect.governance before this function is called.
    #
    # Re-querying them here would be four round trips for rows already in memory -- exactly the
    # duplication AB#6773 spent a release removing -- so each one is skipped when it is already
    # populated. Nothing is skipped when it is EMPTY: an empty array is indistinguishable from
    # "the raw pass never ran" (-Source TypedQueries, -FromCollect on an old file), and quietly
    # reporting zero role assignments would be the worst possible failure mode for a governance
    # assessment.
    #
    # Every return carries the unary comma. A bare `return @()` is pipeline-UNROLLED to zero output
    # objects, so the caller captures $null and `$policy.Count` is a StrictMode throw rather than 0
    # -- the same idiom Invoke-Collect's Invoke-CollectQuery already documents.
    function Get-GovAlreadyCollected([string] $Name) {
        if (-not $Collect.PSObject.Properties['governance'] -or $null -eq $Collect.governance) { return , @() }
        if (-not $Collect.governance.PSObject.Properties[$Name]) { return , @() }
        return , @($Collect.governance.$Name | Where-Object { $_ })
    }

    # 2) policy assignments - keep the nested `properties` object so rule JSONPaths
    #    (@.properties.enforcementMode / .parameters / .displayName) resolve unchanged.
    $policy = Get-GovAlreadyCollected 'policyAssignments'
    if ($policy.Count -gt 0) {
        Write-Verbose "Import-Governance: reusing $($policy.Count) policy assignments from the collect pass (AB#6779)."
    }
    else {
        try {
            $policy = Invoke-GovArg @'
policyresources
| where type =~ "microsoft.authorization/policyassignments"
| project name, id, type, properties
'@
        }
        catch { Write-Warning "Import-Governance: policy-assignment query failed: $($_.Exception.Message)" }
    }

    # 3) role assignments - properties.principalType drives CAF-IDN-01/05.
    $roles = Get-GovAlreadyCollected 'roleAssignments'
    if ($roles.Count -gt 0) {
        Write-Verbose "Import-Governance: reusing $($roles.Count) role assignments from the collect pass (AB#6779)."
    }
    else {
        try {
            $roles = Invoke-GovArg @'
authorizationresources
| where type =~ "microsoft.authorization/roleassignments"
| project name, id, type, properties
'@
        }
        catch { Write-Warning "Import-Governance: role-assignment query failed: $($_.Exception.Message)" }
    }

    # 4/5) budgets + resource locks - neither is indexed by Resource Graph, so pull
    #      them per subscription via the ambient ARM token (Invoke-AzRestMethod uses
    #      the current Az context; works headless under an SPN login). Read-only GET.
    $budgets = Get-GovAlreadyCollected 'budgets'
    $locks = Get-GovAlreadyCollected 'resourceLocks'
    $subIds = @($Collect.subscriptions | ForEach-Object {
            if ($_ -and $_.PSObject.Properties['id']) { $_.id }
        } | Where-Object { $_ })
    # The two reads share a loop but are skipped INDEPENDENTLY. Skipping only when both are in
    # hand would be wrong the other way round: appending a second copy of the budgets to a set the
    # collect pass already supplied would double every budget row.
    $budgetsReused = $budgets.Count -gt 0
    $locksReused = $locks.Count -gt 0
    if ($budgetsReused -or $locksReused) {
        Write-Verbose "Import-Governance: reusing $($budgets.Count) budgets and $($locks.Count) resource locks from the collect pass (AB#6779)."
    }
    if ($budgetsReused -and $locksReused) { $subIds = @() }
    foreach ($sub in $subIds) {
        if (-not $budgetsReused) {
            try {
                $resp = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$sub/providers/Microsoft.Consumption/budgets?api-version=2023-11-01"
                if ($resp.StatusCode -eq 200) {
                    $val = ($resp.Content | ConvertFrom-Json -Depth 100).value
                    if ($val) { $budgets += $val }
                }
            }
            catch { Write-Warning "Import-Governance: budgets read failed for $sub`: $($_.Exception.Message)" }
        }

        if (-not $locksReused) {
            try {
                $resp = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$sub/providers/Microsoft.Authorization/locks?api-version=2020-05-01"
                if ($resp.StatusCode -eq 200) {
                    $val = ($resp.Content | ConvertFrom-Json -Depth 100).value
                    if ($val) { $locks += $val }
                }
            }
            catch { Write-Warning "Import-Governance: resource-lock read failed for $sub`: $($_.Exception.Message)" }
        }
    }

    # Normalize every dataset to a clean array of real objects. The paged ARG
    # helper's `return , $rows` idiom preserves populated arrays intact, but for a
    # query that yields ZERO rows it leaks a single-element wrapper whose element is
    # an empty array — which would otherwise report as Count=1 and trip StrictMode
    # member access downstream (and, worse, make Compare-Benchmark's governance
    # guard think management-group data exists when it does not). Filtering to
    # truthy elements collapses that wrapper back to a genuine empty set while
    # leaving real policy/role/MG objects untouched.
    $gov = [pscustomobject]@{
        managementGroups      = @($mgs     | Where-Object { $_ })
        policyAssignments     = @($policy  | Where-Object { $_ })
        roleAssignments       = @($roles   | Where-Object { $_ })
        budgets               = @($budgets | Where-Object { $_ })
        resourceLocks         = @($locks   | Where-Object { $_ })
        pimEligibility        = @()   # Entra P2 + Graph app perms required - see NOTES
        classicAdministrators = @()   # retired ARM API - see NOTES
    }
    $Collect | Add-Member -NotePropertyName governance -NotePropertyValue $gov -Force

    Write-Verbose ("Import-Governance: MGs={0} policyAssignments={1} roleAssignments={2} budgets={3} locks={4}" -f `
            @($mgs).Count, @($policy).Count, @($roles).Count, @($budgets).Count, @($locks).Count)
    return $Collect
}
