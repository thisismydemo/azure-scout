<#
.Synopsis
    Extract Entra ID (Azure AD) resources via Microsoft Graph API.

.DESCRIPTION
    Queries Microsoft Graph for 15 Entra resource types and normalizes each item
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
    [PSCustomObject] with property EntraResources (array of normalized objects).

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
    Version: 1.0.0
    Authors: thisismydemo
#>
function Start-AZSCEntraExtraction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantID
    )

    Write-Host 'Starting Entra ID Extraction: ' -NoNewline
    Write-Host '15 Resource Types' -ForegroundColor Cyan

    $allEntraResources = [System.Collections.Generic.List[object]]::new()

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

            $normalized = [PSCustomObject]@{
                id         = $item.id
                name       = $name
                TYPE       = $SyntheticType
                tenantId   = $TenantID
                properties = $item
            }

            $allEntraResources.Add($normalized)
        }
    }

    # ── Define the 15 Entra resource type queries ──
    $entraQueries = @(
        @{
            Name         = 'Users'
            Uri          = '/v1.0/users?$select=id,displayName,userPrincipalName,userType,accountEnabled,createdDateTime,assignedLicenses,onPremisesSyncEnabled,department,jobTitle,mail,lastPasswordChangeDateTime'
            Type         = 'entra/users'
            NameProperty = 'userPrincipalName'
        },
        @{
            Name         = 'Groups'
            Uri          = '/v1.0/groups?$select=id,displayName,groupTypes,securityEnabled,mailEnabled,isAssignableToRole,membershipRule,onPremisesSyncEnabled,description'
            Type         = 'entra/groups'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Applications'
            Uri          = '/v1.0/applications?$select=id,displayName,appId,signInAudience,keyCredentials,passwordCredentials,requiredResourceAccess,publisherDomain,createdDateTime'
            Type         = 'entra/applications'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Service Principals'
            Uri          = '/v1.0/servicePrincipals?$select=id,displayName,appId,servicePrincipalType,accountEnabled,appOwnerOrganizationId,keyCredentials,passwordCredentials,tags'
            Type         = 'entra/serviceprincipals'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Managed Identities'
            Uri          = '/v1.0/servicePrincipals?$filter=servicePrincipalType eq ''ManagedIdentity''&$select=id,displayName,appId,servicePrincipalType,alternativeNames'
            Type         = 'entra/managedidentities'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Directory Roles'
            Uri          = '/v1.0/directoryRoles?$select=id,displayName,roleTemplateId,description'
            Type         = 'entra/directoryroles'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'PIM Assignments'
            Uri          = '/v1.0/roleManagement/directory/roleAssignments?$expand=principal($select=id,displayName),roleDefinition($select=id,displayName)'
            Type         = 'entra/pimassignments'
            NameProperty = 'principalId'
        },
        @{
            Name         = 'Conditional Access Policies'
            Uri          = '/v1.0/identity/conditionalAccess/policies'
            Type         = 'entra/conditionalaccesspolicies'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Named Locations'
            Uri          = '/v1.0/identity/conditionalAccess/namedLocations'
            Type         = 'entra/namedlocations'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Administrative Units'
            Uri          = '/v1.0/directory/administrativeUnits?$select=id,displayName,description,membershipType,membershipRule'
            Type         = 'entra/administrativeunits'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Domains'
            Uri          = '/v1.0/domains'
            Type         = 'entra/domains'
            NameProperty = 'id'
        },
        @{
            Name         = 'Subscribed SKUs'
            Uri          = '/v1.0/subscribedSkus'
            Type         = 'entra/subscribedskus'
            NameProperty = 'skuPartNumber'
        },
        @{
            Name         = 'Cross-Tenant Access'
            Uri          = '/v1.0/policies/crossTenantAccessPolicy/partners'
            Type         = 'entra/crosstenantaccess'
            NameProperty = 'tenantId'
        },
        @{
            Name         = 'Security Policies'
            Uri          = '/v1.0/policies/authorizationPolicy'
            Type         = 'entra/securitypolicies'
            NameProperty = 'displayName'
            SingleObject = $true
        },
        @{
            Name         = 'Risky Users'
            Uri          = '/v1.0/identityProtection/riskyUsers'
            Type         = 'entra/riskyusers'
            NameProperty = 'userPrincipalName'
        },
        @{
            Name         = 'Identity Providers'
            Uri          = '/v1.0/identity/identityProviders'
            Type         = 'entra/identityproviders'
            NameProperty = 'displayName'
        },
        @{
            Name         = 'Security Defaults'
            Uri          = '/v1.0/policies/identitySecurityDefaultsEnforcementPolicy'
            Type         = 'entra/securitydefaults'
            NameProperty = 'displayName'
            SingleObject = $true
        }
    )

    # ── Execute each query with graceful degradation ──
    $queryIndex = 0
    $totalQueries = $entraQueries.Count

    foreach ($query in $entraQueries) {
        $queryIndex++
        $percentComplete = [math]::Round(($queryIndex / $totalQueries) * 100)

        Write-Progress -Activity 'Entra ID Extraction' -Status "$($query.Name) ($queryIndex/$totalQueries)" -PercentComplete $percentComplete
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Entra: Querying $($query.Name) [$($query.Uri)]")

        try {
            $result = Invoke-AZSCGraphRequest -Uri $query.Uri

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
            }
            else {
                Write-Host "  [" -NoNewline
                Write-Host "--" -ForegroundColor DarkGray -NoNewline
                Write-Host "] $($query.Name): " -NoNewline
                Write-Host "No data returned" -ForegroundColor DarkGray
            }
        }
        catch {
            # Graceful degradation — log the error but continue with remaining resource types
            Write-Host "  [" -NoNewline
            Write-Host "SKIP" -ForegroundColor Yellow -NoNewline
            Write-Host "] $($query.Name): " -NoNewline
            Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Entra: FAILED $($query.Name) — $($_.Exception.Message)")
        }
    }

    Write-Progress -Activity 'Entra ID Extraction' -Completed

    $entraCount = $allEntraResources.Count
    Write-Host "Entra ID Extraction Complete: " -NoNewline -ForegroundColor Green
    Write-Host "$entraCount total resources across $totalQueries types" -ForegroundColor Cyan

    return [PSCustomObject]@{
        EntraResources = $allEntraResources.ToArray()
    }
}
