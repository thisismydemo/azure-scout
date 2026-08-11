#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.Synopsis
    Extract Entra ID (Azure AD) resources via Microsoft Graph API.

.DESCRIPTION
    Queries Microsoft Graph using the Entra query catalog and normalizes each item
    into a standard structure with a synthetic TYPE property (e.g., 'entra/users').

    Each normalized resource has:
      - id         : Original object ID from Entra
      - name       : Display name or principal name
      - type       : Synthetic TYPE string (e.g., 'entra/users')
      - tenantId   : The tenant ID
      - properties : Nested PSObject containing the full original data

    Uses Invoke-AZSCGraphRequest (Phase 2) for all Graph calls with automatic
    pagination, throttle handling, and exponential backoff.

.PARAMETER TenantID
    The Azure AD / Entra ID tenant identifier.

.OUTPUTS
    [PSCustomObject] with property EntraResources (array of normalized objects) and
    QueryOutcomes (array of @{ Type; Name; Success; Count } -- one per catalog entry, AB#6456).
    QueryOutcomes is what lets a later consumer (Resolve-ScoutOrphanedRoleAssignment) tell
    "this Graph query was denied/failed" apart from "it succeeded and genuinely found nothing" --
    a distinction the normalized rows alone cannot carry, since both cases produce zero rows.

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
    Version: 3.0.0 (relocated from the legacy Modules tree)
    Authors: thisismydemo
#>
function Start-AZSCEntraExtraction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantID
    )

    $allEntraResources = [System.Collections.Generic.List[object]]::new()
    # AB#6456 -- one entry per catalog query, recording whether it actually succeeded. A
    # collector consuming these rows later cannot distinguish "Graph denied this permission"
    # from "Graph allowed it and returned zero objects" by looking at the rows alone -- both
    # produce an empty set. Downstream orphan detection needs that distinction to avoid
    # reporting a denied permission as a security finding.
    $queryOutcomes = [System.Collections.Generic.List[object]]::new()

    # ── Helper: normalize a single Graph item into standard structure ──
    function Add-NormalizedResource {
        param(
            [object[]]$Items,
            [string]$SyntheticType,
            [string]$NameProperty = 'displayName'
        )
        foreach ($item in $Items) {
            if ($null -eq $item) { continue }

            $name = $null
            if ($item.PSObject.Properties.Name -contains $NameProperty) {
                $name = $item.$NameProperty
            }
            elseif ($item.PSObject.Properties.Name -contains 'displayName') {
                $name = $item.displayName
            }
            elseif ($item.PSObject.Properties.Name -contains 'userPrincipalName') {
                $name = $item.userPrincipalName
            }

            # AB#7098 -- `crossTenantAccessPolicyConfigurationDefault` (the singleton "default"
            # cross-tenant access policy External Identities reads) carries no `id` property at
            # all, unlike every query already in the catalog. An unconditional `$item.id` throws
            # under StrictMode the moment a query returns a shape without one, and that throw is
            # caught by the query loop's own try/catch -- so the new query would report SKIP on
            # every run, not "collected nothing". Guarded the same way `$name` resolution already
            # is, immediately above.
            $id = if ($item.PSObject.Properties.Name -contains 'id') { $item.id } else { $null }

            $normalized = [PSCustomObject]@{
                id         = $id
                name       = $name
                TYPE       = $SyntheticType
                tenantId   = $TenantID
                properties = $item
            }

            $allEntraResources.Add($normalized)
        }
    }

    # ── The Graph query catalog ──
    # AB#6765 -- this was a 17-entry literal here. It now lives in
    # Get-ScoutEntraQueryCatalog.ps1 so the pre-flight impact table reads the SAME list this
    # loop executes. The pre-flight used to keep its own hardcoded four-entry idea of what
    # mattered, which is why a denied permission outside those four still printed a green
    # READY banner over a scan that would render its worksheet empty.
    $entraQueries = @(Get-ScoutEntraQueryCatalog)
    $totalQueries = $entraQueries.Count

    Write-Host 'Starting Entra ID Extraction: ' -NoNewline
    Write-Host "$totalQueries Resource Types" -ForegroundColor Cyan

    # Acquire the tenant-scoped token once before entering the per-query loop. A token
    # acquisition failure is common to every catalog query; retrying it for every dataset
    # only repeats the same error and wastes time. Successful acquisition populates the
    # normal token cache, so Invoke-AZSCGraphRequest below remains unchanged.
    try {
        $null = Get-AZSCGraphToken -TenantID $TenantID
    }
    catch {
        $authenticationError = $_.Exception.Message
        Write-Host '  [' -NoNewline
        Write-Host 'SKIP' -ForegroundColor Yellow -NoNewline
        Write-Host '] Microsoft Graph authentication: ' -NoNewline
        Write-Host $authenticationError -ForegroundColor Yellow
        Write-Warning "[AzureScout] Entra authentication failed once; all $totalQueries Entra datasets are unavailable. Error: $authenticationError"

        foreach ($query in $entraQueries) {
            $queryOutcomes.Add([PSCustomObject]@{
                    Type    = $query.Type
                    Name    = $query.Name
                    Success = $false
                    Count   = 0
                })
        }

        Write-Host 'Entra ID Extraction Complete: ' -NoNewline -ForegroundColor Green
        Write-Host "0 total resources across $totalQueries types" -ForegroundColor Cyan
        return [PSCustomObject]@{
            EntraResources = $allEntraResources.ToArray()
            QueryOutcomes  = $queryOutcomes.ToArray()
        }
    }

    # ── Execute each query with graceful degradation ──
    $queryIndex = 0

    foreach ($query in $entraQueries) {
        $queryIndex++
        $percentComplete = [math]::Round(($queryIndex / $totalQueries) * 100)

        Write-Progress -Activity 'Entra ID Extraction' -Status "$($query.Name) ($queryIndex/$totalQueries)" -PercentComplete $percentComplete
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Entra: Querying $($query.Name) [$($query.Uri)]")

        try {
            # Pin token acquisition to the tenant the operator requested. Without this,
            # Invoke-AZSCGraphRequest can use an ambient context from another tenant and the
            # normalizer below would then incorrectly stamp those objects with $TenantID.
            $result = Invoke-AZSCGraphRequest -Uri $query.Uri -TenantID $TenantID

            if ($null -ne $result) {
                # Handle single-object endpoints (e.g., authorizationPolicy)
                if ($query.ContainsKey('SingleObject') -and $query.SingleObject) {
                    # Single object — wrap in array
                    if ($result -is [array]) {
                        Add-NormalizedResource -Items $result -SyntheticType $query.Type -NameProperty $query.NameProperty
                    }
                    else {
                        Add-NormalizedResource -Items @($result) -SyntheticType $query.Type -NameProperty $query.NameProperty
                    }
                }
                else {
                    # Collection endpoint — result is already an array from Invoke-AZSCGraphRequest
                    if ($result -is [array]) {
                        Add-NormalizedResource -Items $result -SyntheticType $query.Type -NameProperty $query.NameProperty
                    }
                    else {
                        Add-NormalizedResource -Items @($result) -SyntheticType $query.Type -NameProperty $query.NameProperty
                    }
                }

                Write-Host "  [" -NoNewline
                Write-Host "OK" -ForegroundColor Green -NoNewline
                Write-Host "] $($query.Name): " -NoNewline

                $count = if ($result -is [array]) { $result.Count } else { 1 }
                Write-Host "$count items" -ForegroundColor Cyan
                $queryOutcomes.Add([PSCustomObject]@{ Type = $query.Type; Name = $query.Name; Success = $true; Count = $count })
            }
            else {
                Write-Host "  [" -NoNewline
                Write-Host "--" -ForegroundColor DarkGray -NoNewline
                Write-Host "] $($query.Name): " -NoNewline
                Write-Host "No data returned" -ForegroundColor DarkGray
                # $null is a legitimate "the query ran and there is nothing" response (e.g. no
                # cross-tenant partners configured), not a failure -- Success stays true so a
                # genuinely empty dataset is never mistaken for a denied permission downstream.
                $queryOutcomes.Add([PSCustomObject]@{ Type = $query.Type; Name = $query.Name; Success = $true; Count = 0 })
            }
        }
        catch {
            # Graceful degradation — continue with the remaining resource types.
            Write-Host "  [" -NoNewline
            Write-Host "SKIP" -ForegroundColor Yellow -NoNewline
            Write-Host "] $($query.Name): " -NoNewline
            Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Entra: FAILED $($query.Name) — $($_.Exception.Message)")
            # AB#6765. The three lines above are ALL this used to do. A denied Graph permission
            # was swallowed into a coloured Write-Host that reaches no stream a caller can
            # capture, is invisible in a transcript-less automation run, and never reached the
            # run's error count -- so the report shipped a worksheet that was empty for a reason
            # the run itself had not reported. That is the exact failure this Feature exists to
            # end. The console line stays, because it is the readable one; the warning is what
            # makes it detectable.
            Write-Warning "[AzureScout] Entra collection for '$($query.Name)' failed — the collectors reading '$($query.Type)' will be EMPTY. Permission required: $($query.Permission). Error: $($_.Exception.Message)"
            $queryOutcomes.Add([PSCustomObject]@{ Type = $query.Type; Name = $query.Name; Success = $false; Count = 0 })
        }
    }

    Write-Progress -Activity 'Entra ID Extraction' -Completed

    $entraCount = $allEntraResources.Count
    Write-Host "Entra ID Extraction Complete: " -NoNewline -ForegroundColor Green
    Write-Host "$entraCount total resources across $totalQueries types" -ForegroundColor Cyan

    return [PSCustomObject]@{
        EntraResources = $allEntraResources.ToArray()
        QueryOutcomes  = $queryOutcomes.ToArray()
    }
}
