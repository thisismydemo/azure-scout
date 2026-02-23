#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all 15 Entra ID Identity inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each Identity module
    using synthetic mock data that mirrors the normalized PSCustomObject shape
    produced by Start-AZTIEntraExtraction.ps1.

    Processing phase: Verifies each module correctly filters and transforms
    resources into flat hashtable arrays.

    Reporting phase: Verifies each module produces an Excel worksheet via
    Export-Excel (ImportExcel module required).

    NO live Azure/Graph authentication is required.

.NOTES
    Author:  Product Technology Team
    Version: 1.1.0
    Created: 2026-02-23
    Phase:   5.18 — Full run with Entra modules producing Excel worksheets
#>

# ===================================================================
# DISCOVERY-TIME DEFINITIONS
# Must be at script level (outside BeforeAll) so Pester v5 can resolve
# them during test discovery for -ForEach parameterization.
# ===================================================================
$IdentityPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Identity'

$ModuleSpecs = @(
    @{ Name = 'Users';              File = 'Users.ps1';              Type = 'entra/users';                        Worksheet = 'Entra Users' }
    @{ Name = 'Groups';             File = 'Groups.ps1';             Type = 'entra/groups';                       Worksheet = 'Entra Groups' }
    @{ Name = 'AppRegistrations';   File = 'AppRegistrations.ps1';   Type = 'entra/applications';                 Worksheet = 'App Registrations' }
    @{ Name = 'ServicePrincipals';  File = 'ServicePrincipals.ps1';  Type = 'entra/serviceprincipals';            Worksheet = 'Service Principals' }
    @{ Name = 'ManagedIdentities';  File = 'ManagedIdentities.ps1';  Type = 'entra/managedidentities';            Worksheet = 'Managed Identities' }
    @{ Name = 'DirectoryRoles';     File = 'DirectoryRoles.ps1';     Type = 'entra/directoryroles';               Worksheet = 'Directory Roles' }
    @{ Name = 'PIMAssignments';     File = 'PIMAssignments.ps1';     Type = 'entra/pimassignments';               Worksheet = 'PIM Assignments' }
    @{ Name = 'ConditionalAccess';  File = 'ConditionalAccess.ps1';  Type = 'entra/conditionalaccesspolicies';    Worksheet = 'Conditional Access' }
    @{ Name = 'NamedLocations';     File = 'NamedLocations.ps1';     Type = 'entra/namedlocations';               Worksheet = 'Named Locations' }
    @{ Name = 'AdminUnits';         File = 'AdminUnits.ps1';         Type = 'entra/administrativeunits';          Worksheet = 'Admin Units' }
    @{ Name = 'Domains';            File = 'Domains.ps1';            Type = 'entra/domains';                      Worksheet = 'Entra Domains' }
    @{ Name = 'Licensing';          File = 'Licensing.ps1';          Type = 'entra/subscribedskus';               Worksheet = 'Licensing' }
    @{ Name = 'CrossTenantAccess';  File = 'CrossTenantAccess.ps1';  Type = 'entra/crosstenantaccess';            Worksheet = 'Cross-Tenant Access' }
    @{ Name = 'SecurityPolicies';   File = 'SecurityPolicies.ps1';   Type = 'entra/securitypolicies';             Worksheet = 'Security Policies' }
    @{ Name = 'RiskyUsers';         File = 'RiskyUsers.ps1';         Type = 'entra/riskyusers';                   Worksheet = 'Risky Users' }
)

# ===================================================================
# EXECUTION-TIME SETUP (BeforeAll runs before any tests)
# ===================================================================
BeforeAll {
    $script:ModuleRoot    = Split-Path -Parent $PSScriptRoot
    $script:IdentityPath  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Identity'
    $script:TestOutputDir = Join-Path $env:TEMP 'AZTI_IdentityTests'

    if (Test-Path $script:TestOutputDir) { Remove-Item $script:TestOutputDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null

    # --- Helper: Build a normalized Entra resource object ---
    function New-MockEntraResource {
        param(
            [string]$Id,
            [string]$Name,
            [string]$Type,
            [string]$TenantId = '00000000-0000-0000-0000-000000000001',
            [object]$Properties
        )
        [PSCustomObject]@{
            id         = $Id
            name       = $Name
            TYPE       = $Type
            tenantId   = $TenantId
            properties = $Properties
        }
    }

    # --- Helper: Invoke a module's Processing or Reporting phase ---
    function Invoke-IdentityModule {
        param(
            [string]$ModuleFile,
            [string]$Task,
            [object]$Resources    = $null,
            [object]$SmaResources = $null,
            [string]$File         = $null,
            [string]$TableStyle   = 'Light20'
        )
        $content = Get-Content -Path $ModuleFile -Raw
        $sb = [ScriptBlock]::Create($content)
        # param order: $SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported
        Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $Resources, $null, $Task, $File, $SmaResources, $TableStyle, $null
    }

    # ===================================================================
    # Build mock resources for ALL 15 Entra types (2 items each)
    # ===================================================================
    $script:MockResources = @()

    # 1. Users
    $script:MockResources += New-MockEntraResource -Id 'u1' -Name 'Alice Smith' -Type 'entra/users' -Properties ([PSCustomObject]@{
        displayName                 = 'Alice Smith'
        userPrincipalName           = 'alice@contoso.com'
        userType                    = 'Member'
        accountEnabled              = $true
        createdDateTime             = '2025-01-15T10:00:00Z'
        lastPasswordChangeDateTime  = '2025-06-01T08:00:00Z'
        assignedLicenses            = @(@{ skuId = 'sku1' }, @{ skuId = 'sku2' })
        onPremisesSyncEnabled       = $false
        department                  = 'Engineering'
        jobTitle                    = 'Developer'
        mail                        = 'alice@contoso.com'
    })
    $script:MockResources += New-MockEntraResource -Id 'u2' -Name 'Bob Jones' -Type 'entra/users' -Properties ([PSCustomObject]@{
        displayName                 = 'Bob Jones'
        userPrincipalName           = 'bob@contoso.com'
        userType                    = 'Guest'
        accountEnabled              = $false
        createdDateTime             = '2024-11-01T12:00:00Z'
        lastPasswordChangeDateTime  = $null
        assignedLicenses            = $null
        onPremisesSyncEnabled       = $true
        department                  = 'IT'
        jobTitle                    = 'Admin'
        mail                        = 'bob@contoso.com'
    })

    # 2. Groups
    $script:MockResources += New-MockEntraResource -Id 'g1' -Name 'Dev Team' -Type 'entra/groups' -Properties ([PSCustomObject]@{
        displayName             = 'Dev Team'
        groupTypes              = @('Unified')
        securityEnabled         = $true
        mailEnabled             = $true
        isAssignableToRole      = $false
        membershipRule          = $null
        onPremisesSyncEnabled   = $false
        description             = 'Development team group'
    })
    $script:MockResources += New-MockEntraResource -Id 'g2' -Name 'Security Admins' -Type 'entra/groups' -Properties ([PSCustomObject]@{
        displayName             = 'Security Admins'
        groupTypes              = @()
        securityEnabled         = $true
        mailEnabled             = $false
        isAssignableToRole      = $true
        membershipRule          = 'user.department -eq "Security"'
        onPremisesSyncEnabled   = $false
        description             = 'Security administrators'
    })

    # 3. App Registrations
    $script:MockResources += New-MockEntraResource -Id 'app1' -Name 'MyWebApp' -Type 'entra/applications' -Properties ([PSCustomObject]@{
        displayName             = 'MyWebApp'
        appId                   = 'a1b2c3d4-e5f6-0000-0000-000000000001'
        signInAudience          = 'AzureADMyOrg'
        keyCredentials          = @(@{ endDateTime = '2026-12-31T00:00:00Z' })
        passwordCredentials     = @(@{ endDateTime = '2026-06-30T00:00:00Z' })
        requiredResourceAccess  = @(@{ resourceAppId = '00000003-0000-0000-c000-000000000000' })
        publisherDomain         = 'contoso.com'
        createdDateTime         = '2025-03-01T09:00:00Z'
    })
    $script:MockResources += New-MockEntraResource -Id 'app2' -Name 'BackendAPI' -Type 'entra/applications' -Properties ([PSCustomObject]@{
        displayName             = 'BackendAPI'
        appId                   = 'a1b2c3d4-e5f6-0000-0000-000000000002'
        signInAudience          = 'AzureADMultipleOrgs'
        keyCredentials          = $null
        passwordCredentials     = $null
        requiredResourceAccess  = $null
        publisherDomain         = 'contoso.com'
        createdDateTime         = '2025-05-10T14:00:00Z'
    })

    # 4. Service Principals
    $script:MockResources += New-MockEntraResource -Id 'sp1' -Name 'MyWebApp SP' -Type 'entra/serviceprincipals' -Properties ([PSCustomObject]@{
        displayName              = 'MyWebApp SP'
        appId                    = 'a1b2c3d4-e5f6-0000-0000-000000000001'
        servicePrincipalType     = 'Application'
        accountEnabled           = $true
        appOwnerOrganizationId   = '00000000-0000-0000-0000-000000000001'
        keyCredentials           = @(@{ endDateTime = '2026-12-31T00:00:00Z' })
        passwordCredentials      = @(@{ endDateTime = '2026-06-30T00:00:00Z' })
        tags                     = @('WindowsAzureActiveDirectoryIntegratedApp')
    })
    $script:MockResources += New-MockEntraResource -Id 'sp2' -Name 'Graph Explorer' -Type 'entra/serviceprincipals' -Properties ([PSCustomObject]@{
        displayName              = 'Graph Explorer'
        appId                    = 'a1b2c3d4-e5f6-0000-0000-000000000099'
        servicePrincipalType     = 'ManagedIdentity'
        accountEnabled           = $false
        appOwnerOrganizationId   = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
        keyCredentials           = $null
        passwordCredentials      = $null
        tags                     = $null
    })

    # 5. Managed Identities
    $script:MockResources += New-MockEntraResource -Id 'mi1' -Name 'webapp-identity' -Type 'entra/managedidentities' -Properties ([PSCustomObject]@{
        displayName      = 'webapp-identity'
        appId            = 'mi-app-id-001'
        alternativeNames = @('isExplicit=True', '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Web/sites/myapp')
    })
    $script:MockResources += New-MockEntraResource -Id 'mi2' -Name 'vm-system-identity' -Type 'entra/managedidentities' -Properties ([PSCustomObject]@{
        displayName      = 'vm-system-identity'
        appId            = 'mi-app-id-002'
        alternativeNames = @('isExplicit=False', '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/myvm')
    })

    # 6. Directory Roles
    $script:MockResources += New-MockEntraResource -Id 'dr1' -Name 'Global Administrator' -Type 'entra/directoryroles' -Properties ([PSCustomObject]@{
        displayName     = 'Global Administrator'
        roleTemplateId  = '62e90394-69f5-4237-9190-012177145e10'
        description     = 'Can manage all aspects of Azure AD and Microsoft services.'
    })
    $script:MockResources += New-MockEntraResource -Id 'dr2' -Name 'User Administrator' -Type 'entra/directoryroles' -Properties ([PSCustomObject]@{
        displayName     = 'User Administrator'
        roleTemplateId  = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
        description     = 'Can manage all aspects of users and groups.'
    })

    # 7. PIM Assignments
    $script:MockResources += New-MockEntraResource -Id 'pim1' -Name 'PIM-Alice-GA' -Type 'entra/pimassignments' -Properties ([PSCustomObject]@{
        id               = 'pim-assign-001'
        principalId      = 'u1'
        roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10'
        directoryScopeId = '/'
        principal        = [PSCustomObject]@{
            displayName    = 'Alice Smith'
            '@odata.type'  = '#microsoft.graph.user'
        }
        roleDefinition   = [PSCustomObject]@{
            displayName = 'Global Administrator'
        }
    })
    $script:MockResources += New-MockEntraResource -Id 'pim2' -Name 'PIM-Group-UA' -Type 'entra/pimassignments' -Properties ([PSCustomObject]@{
        id               = 'pim-assign-002'
        principalId      = 'g2'
        roleDefinitionId = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
        directoryScopeId = '/'
        principal        = [PSCustomObject]@{
            displayName    = 'Security Admins'
            '@odata.type'  = '#microsoft.graph.group'
        }
        roleDefinition   = [PSCustomObject]@{
            displayName = 'User Administrator'
        }
    })

    # 8. Conditional Access Policies
    $script:MockResources += New-MockEntraResource -Id 'ca1' -Name 'Require MFA for All' -Type 'entra/conditionalaccesspolicies' -Properties ([PSCustomObject]@{
        displayName      = 'Require MFA for All'
        state            = 'enabled'
        conditions       = [PSCustomObject]@{
            users        = [PSCustomObject]@{
                includeUsers = @('All')
                excludeUsers = @('breakglass@contoso.com')
            }
            applications = [PSCustomObject]@{
                includeApplications = @('All')
            }
        }
        grantControls    = [PSCustomObject]@{
            builtInControls = @('mfa')
        }
        sessionControls  = [PSCustomObject]@{
            signInFrequency   = [PSCustomObject]@{ value = 1; type = 'hours' }
            persistentBrowser = $null
            cloudAppSecurity  = $null
            applicationEnforcedRestrictions = $null
        }
        createdDateTime  = '2025-02-01T10:00:00Z'
        modifiedDateTime = '2025-06-15T14:30:00Z'
    })
    $script:MockResources += New-MockEntraResource -Id 'ca2' -Name 'Block Legacy Auth' -Type 'entra/conditionalaccesspolicies' -Properties ([PSCustomObject]@{
        displayName      = 'Block Legacy Auth'
        state            = 'disabled'
        conditions       = [PSCustomObject]@{
            users        = [PSCustomObject]@{
                includeUsers = @('All')
                excludeUsers = $null
            }
            applications = [PSCustomObject]@{
                includeApplications = @('All')
            }
        }
        grantControls    = [PSCustomObject]@{
            builtInControls = @('block')
        }
        sessionControls  = $null
        createdDateTime  = '2025-03-10T08:00:00Z'
        modifiedDateTime = $null
    })

    # 9. Named Locations
    $script:MockResources += New-MockEntraResource -Id 'nl1' -Name 'Corporate Network' -Type 'entra/namedlocations' -Properties ([PSCustomObject]@{
        displayName      = 'Corporate Network'
        '@odata.type'    = '#microsoft.graph.ipNamedLocation'
        isTrusted        = $true
        ipRanges         = @([PSCustomObject]@{ cidrAddress = '10.0.0.0/8' }, [PSCustomObject]@{ cidrAddress = '172.16.0.0/12' })
        createdDateTime  = '2025-01-01T00:00:00Z'
        modifiedDateTime = '2025-05-20T12:00:00Z'
    })
    $script:MockResources += New-MockEntraResource -Id 'nl2' -Name 'Allowed Countries' -Type 'entra/namedlocations' -Properties ([PSCustomObject]@{
        displayName          = 'Allowed Countries'
        '@odata.type'        = '#microsoft.graph.countryNamedLocation'
        countriesAndRegions  = @('US', 'CA', 'GB')
        createdDateTime      = '2025-02-15T09:00:00Z'
        modifiedDateTime     = $null
    })

    # 10. Admin Units
    $script:MockResources += New-MockEntraResource -Id 'au1' -Name 'Engineering AU' -Type 'entra/administrativeunits' -Properties ([PSCustomObject]@{
        displayName     = 'Engineering AU'
        description     = 'Administrative unit for engineering'
        membershipType  = 'Dynamic'
        membershipRule  = 'user.department -eq "Engineering"'
        visibility      = 'Public'
    })
    $script:MockResources += New-MockEntraResource -Id 'au2' -Name 'HR AU' -Type 'entra/administrativeunits' -Properties ([PSCustomObject]@{
        displayName     = 'HR AU'
        description     = 'Administrative unit for HR'
        membershipType  = $null
        membershipRule  = $null
        visibility      = 'HiddenMembership'
    })

    # 11. Domains
    $script:MockResources += New-MockEntraResource -Id 'd1' -Name 'contoso.com' -Type 'entra/domains' -Properties ([PSCustomObject]@{
        id                  = 'contoso.com'
        isVerified          = $true
        isDefault           = $true
        isAdminManaged      = $true
        authenticationType  = 'Managed'
        supportedServices   = @('Email', 'OfficeCommunicationsOnline')
    })
    $script:MockResources += New-MockEntraResource -Id 'd2' -Name 'contoso.onmicrosoft.com' -Type 'entra/domains' -Properties ([PSCustomObject]@{
        id                  = 'contoso.onmicrosoft.com'
        isVerified          = $true
        isDefault           = $false
        isAdminManaged      = $false
        authenticationType  = 'Managed'
        supportedServices   = @('Email')
    })

    # 12. Licensing (Subscribed SKUs)
    $script:MockResources += New-MockEntraResource -Id 'lic1' -Name 'E5 License' -Type 'entra/subscribedskus' -Properties ([PSCustomObject]@{
        skuPartNumber  = 'SPE_E5'
        skuId          = '06ebc4ee-1bb5-47dd-8120-11324bc54e06'
        consumedUnits  = 45
        prepaidUnits   = [PSCustomObject]@{ enabled = 100; suspended = 0; warning = 0 }
        appliesTo      = 'User'
        capabilityStatus = 'Enabled'
    })
    $script:MockResources += New-MockEntraResource -Id 'lic2' -Name 'P2 License' -Type 'entra/subscribedskus' -Properties ([PSCustomObject]@{
        skuPartNumber  = 'AAD_PREMIUM_P2'
        skuId          = '84a661c4-e949-4bd2-a560-ed7766fcaf2b'
        consumedUnits  = 10
        prepaidUnits   = [PSCustomObject]@{ enabled = 50; suspended = 5; warning = 2 }
        appliesTo      = 'User'
        capabilityStatus = 'Warning'
    })

    # 13. Cross-Tenant Access
    $script:MockResources += New-MockEntraResource -Id 'cta1' -Name 'Partner Org' -Type 'entra/crosstenantaccess' -Properties ([PSCustomObject]@{
        tenantId                = '11111111-1111-1111-1111-111111111111'
        inboundTrust            = [PSCustomObject]@{
            isMfaAccepted                       = $true
            isCompliantDeviceAccepted           = $true
            isHybridAzureADJoinedDeviceAccepted = $false
        }
        b2bCollaborationInbound = [PSCustomObject]@{
            applications = [PSCustomObject]@{ accessType = 'allowed' }
        }
        b2bDirectConnectInbound = [PSCustomObject]@{
            applications = [PSCustomObject]@{ accessType = 'blocked' }
        }
        isServiceProvider       = $false
    })
    $script:MockResources += New-MockEntraResource -Id 'cta2' -Name 'Vendor Org' -Type 'entra/crosstenantaccess' -Properties ([PSCustomObject]@{
        tenantId                = '22222222-2222-2222-2222-222222222222'
        inboundTrust            = $null
        b2bCollaborationInbound = $null
        b2bDirectConnectInbound = $null
        isServiceProvider       = $true
    })

    # 14. Security Policies (Authorization Policy)
    $script:MockResources += New-MockEntraResource -Id 'secpol1' -Name 'Authorization Policy' -Type 'entra/securitypolicies' -Properties ([PSCustomObject]@{
        guestUserRoleId                             = '10dae51f-b6af-4016-8d66-8c2a99b929b3'
        allowInvitesFrom                            = 'adminsAndGuestInviters'
        allowedToSignUpEmailBasedSubscriptions       = $true
        allowEmailVerifiedUsersToJoinOrganization    = $false
        allowedToUseSSPR                             = $true
        blockMsolPowerShell                          = $false
        defaultUserRolePermissions                   = [PSCustomObject]@{
            allowedToCreateApps            = $true
            allowedToCreateSecurityGroups  = $false
            allowedToReadOtherUsers        = $true
        }
    })

    # 15. Risky Users
    $script:MockResources += New-MockEntraResource -Id 'risk1' -Name 'risky-alice' -Type 'entra/riskyusers' -Properties ([PSCustomObject]@{
        userPrincipalName         = 'alice@contoso.com'
        userDisplayName           = 'Alice Smith'
        riskLevel                 = 'high'
        riskState                 = 'atRisk'
        riskDetail                = 'adminConfirmedCompromised'
        riskLastUpdatedDateTime   = '2025-06-20T15:00:00Z'
        isDeleted                 = $false
        isProcessing              = $false
    })
    $script:MockResources += New-MockEntraResource -Id 'risk2' -Name 'risky-bob' -Type 'entra/riskyusers' -Properties ([PSCustomObject]@{
        userPrincipalName         = 'bob@contoso.com'
        userDisplayName           = 'Bob Jones'
        riskLevel                 = 'medium'
        riskState                 = 'confirmedCompromised'
        riskDetail                = 'userPassedMFADrivenByRiskBasedPolicy'
        riskLastUpdatedDateTime   = '2025-06-18T09:00:00Z'
        isDeleted                 = $false
        isProcessing              = $true
    })

    # Pre-compute module specs in script scope for execution-time use
    $script:ModuleSpecs = @(
        @{ Name = 'Users';              File = 'Users.ps1';              Type = 'entra/users';                        Worksheet = 'Entra Users' }
        @{ Name = 'Groups';             File = 'Groups.ps1';             Type = 'entra/groups';                       Worksheet = 'Entra Groups' }
        @{ Name = 'AppRegistrations';   File = 'AppRegistrations.ps1';   Type = 'entra/applications';                 Worksheet = 'App Registrations' }
        @{ Name = 'ServicePrincipals';  File = 'ServicePrincipals.ps1';  Type = 'entra/serviceprincipals';            Worksheet = 'Service Principals' }
        @{ Name = 'ManagedIdentities';  File = 'ManagedIdentities.ps1';  Type = 'entra/managedidentities';            Worksheet = 'Managed Identities' }
        @{ Name = 'DirectoryRoles';     File = 'DirectoryRoles.ps1';     Type = 'entra/directoryroles';               Worksheet = 'Directory Roles' }
        @{ Name = 'PIMAssignments';     File = 'PIMAssignments.ps1';     Type = 'entra/pimassignments';               Worksheet = 'PIM Assignments' }
        @{ Name = 'ConditionalAccess';  File = 'ConditionalAccess.ps1';  Type = 'entra/conditionalaccesspolicies';    Worksheet = 'Conditional Access' }
        @{ Name = 'NamedLocations';     File = 'NamedLocations.ps1';     Type = 'entra/namedlocations';               Worksheet = 'Named Locations' }
        @{ Name = 'AdminUnits';         File = 'AdminUnits.ps1';         Type = 'entra/administrativeunits';          Worksheet = 'Admin Units' }
        @{ Name = 'Domains';            File = 'Domains.ps1';            Type = 'entra/domains';                      Worksheet = 'Entra Domains' }
        @{ Name = 'Licensing';          File = 'Licensing.ps1';          Type = 'entra/subscribedskus';               Worksheet = 'Licensing' }
        @{ Name = 'CrossTenantAccess';  File = 'CrossTenantAccess.ps1';  Type = 'entra/crosstenantaccess';            Worksheet = 'Cross-Tenant Access' }
        @{ Name = 'SecurityPolicies';   File = 'SecurityPolicies.ps1';   Type = 'entra/securitypolicies';             Worksheet = 'Security Policies' }
        @{ Name = 'RiskyUsers';         File = 'RiskyUsers.ps1';         Type = 'entra/riskyusers';                   Worksheet = 'Risky Users' }
    )
}

AfterAll {
    # Clean up temp output
    if (Test-Path $script:TestOutputDir) { Remove-Item $script:TestOutputDir -Recurse -Force }
}

# =====================================================================
# PROCESSING PHASE TESTS — uses -ForEach for Pester v5 discovery
# =====================================================================
Describe 'Identity Module Processing Phase' -Tag 'Processing' {

    Context '<Name> module' -ForEach $ModuleSpecs {

        BeforeAll {
            $moduleFile = Join-Path $script:IdentityPath $File
            $script:procResult = Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Processing' -Resources $script:MockResources
        }

        It 'Module file exists' {
            (Join-Path $script:IdentityPath $File) | Should -Exist
        }

        It 'Returns non-null output' {
            $script:procResult | Should -Not -BeNullOrEmpty
        }

        It 'Returns at least one record' {
            @($script:procResult).Count | Should -BeGreaterOrEqual 1
        }

        It 'Each record contains a Resource U key' {
            foreach ($record in @($script:procResult)) {
                $record.'Resource U' | Should -Not -BeNullOrEmpty
            }
        }
    }
}

# =====================================================================
# REPORTING PHASE TESTS (Excel worksheet generation)
# =====================================================================
Describe 'Identity Module Reporting Phase' -Tag 'Reporting' {

    BeforeAll {
        $script:ExcelFile = Join-Path $script:TestOutputDir 'EntraIdentityTest.xlsx'

        # First run Processing for ALL modules to collect SmaResources
        $script:ProcessedData = @{}
        foreach ($spec in $script:ModuleSpecs) {
            $moduleFile = Join-Path $script:IdentityPath $spec.File
            $procResult = Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Processing' -Resources $script:MockResources
            $script:ProcessedData[$spec.Name] = $procResult
        }

        # Now run Reporting for each module, all writing to the same Excel file
        foreach ($spec in $script:ModuleSpecs) {
            $moduleFile = Join-Path $script:IdentityPath $spec.File
            $sma = $script:ProcessedData[$spec.Name]
            if ($sma) {
                Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Reporting' -SmaResources $sma -File $script:ExcelFile -TableStyle 'Light20'
            }
        }
    }

    It 'Excel report file was created' {
        $script:ExcelFile | Should -Exist
    }

    It 'Excel file is non-empty' {
        (Get-Item $script:ExcelFile).Length | Should -BeGreaterThan 0
    }

    Context 'Worksheet <Worksheet>' -ForEach $ModuleSpecs {

        It 'Exists in Excel file' {
            $worksheets = (Get-ExcelSheetInfo -Path $script:ExcelFile).Name
            $worksheets | Should -Contain $Worksheet
        }

        It 'Has data rows' {
            $data = Import-Excel -Path $script:ExcelFile -WorksheetName $Worksheet
            @($data).Count | Should -BeGreaterOrEqual 1
        }
    }
}

# =====================================================================
# EDGE CASE TESTS
# =====================================================================
Describe 'Identity Module Edge Cases' -Tag 'EdgeCases' {

    It 'Processing returns nothing for empty resource set' {
        $moduleFile = Join-Path $script:IdentityPath 'Users.ps1'
        $result = Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Processing' -Resources @()
        $result | Should -BeNullOrEmpty
    }

    It 'Processing returns nothing when no matching TYPE exists' {
        $fakeResources = @(
            New-MockEntraResource -Id 'x1' -Name 'Fake' -Type 'entra/fake' -Properties ([PSCustomObject]@{ displayName = 'Fake' })
        )
        $moduleFile = Join-Path $script:IdentityPath 'Users.ps1'
        $result = Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Processing' -Resources $fakeResources
        $result | Should -BeNullOrEmpty
    }

    It 'Reporting with null SmaResources does not throw' {
        $moduleFile = Join-Path $script:IdentityPath 'Users.ps1'
        $tempFile = Join-Path $script:TestOutputDir 'edge_empty.xlsx'
        { Invoke-IdentityModule -ModuleFile $moduleFile -Task 'Reporting' -SmaResources $null -File $tempFile } | Should -Not -Throw
    }
}
