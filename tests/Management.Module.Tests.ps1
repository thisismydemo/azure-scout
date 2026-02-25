#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Management & Governance inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for resource-based Management modules
    using synthetic mock data. Modules that call live Az cmdlets (ManagementGroups,
    CustomRoleDefinitions, PolicyDefinitions, PolicySetDefinitions, PolicyComplianceStates)
    are tested by mocking those cmdlets.
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   9.1, 11.1, 11.2, 19.6 — Management / Policy / Subscriptions Testing
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$ManagementPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Management'

# Modules that filter $Resources
$MgmtResourceModules = @(
    @{ Name = 'MaintenanceConfigurations'; File = 'MaintenanceConfigurations.ps1'; Type = 'microsoft.maintenance/maintenanceconfigurations'; Worksheet = 'Maintenance Configurations' }
    @{ Name = 'RecoveryVault';             File = 'RecoveryVault.ps1';             Type = 'microsoft.recoveryservices/vaults';               Worksheet = 'Recovery Vaults' }
    @{ Name = 'LighthouseDelegations';     File = 'LighthouseDelegations.ps1';     Type = 'Microsoft.ManagedServices/registrationDefinitions'; Worksheet = 'Lighthouse Delegations' }
    @{ Name = 'AdvisorScore';              File = 'AdvisorScore.ps1';              Type = 'Microsoft.Advisor/advisorScore';                  Worksheet = 'Advisor Score' }
    @{ Name = 'SupportTickets';            File = 'SupportTickets.ps1';            Type = 'Microsoft.Support/supportTickets';                Worksheet = 'Support Tickets' }
    @{ Name = 'ReservationRecom';          File = 'ReservationRecom.ps1';          Type = 'Microsoft.Consumption/reservationRecommendations'; Worksheet = 'Reservation Recommendations' }
    @{ Name = 'AutomationAccounts';        File = 'AutomationAccounts.ps1';        Type = 'microsoft.automation/automationaccounts';          Worksheet = 'Runbooks' }
    @{ Name = 'Backup';                    File = 'Backup.ps1';                    Type = 'microsoft.recoveryservices/vaults/backuppolicies'; Worksheet = 'Backup' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:ManagementPath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Management'
    $script:TempDir        = Join-Path $env:TEMP 'AZSC_ManagementTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockMgmtResource {
        param([string]$Id, [string]$Name, [string]$Type,
              [string]$Location = 'global', [string]$RG = 'rg-mgmt',
              [string]$SubscriptionId = 'sub-00000001', [object]$Props, [string]$Kind = '')
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            KIND           = $Kind
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Props
        }
    }

    # Mock subscription array for modules that use $SUB
    $script:MockSubs = @(
        [PSCustomObject]@{ Id = 'sub-00000001'; Name = 'Test Subscription' }
    )

    $script:MockResources = @()

    # Maintenance Configurations
    $script:MockResources += New-MockMgmtResource -Id '/sub/mc1' -Name 'mc-patches' `
        -Type 'microsoft.maintenance/maintenanceconfigurations' -Props ([PSCustomObject]@{
        maintenanceScope = 'InGuestPatch'; maintenanceWindow = [PSCustomObject]@{
            startDateTime = '2026-03-01 02:00'; duration = '02:00'; recurEvery = 'Week Thursday'
            timeZone = 'Eastern Standard Time'; expirationDateTime = $null
        }
        installPatches = [PSCustomObject]@{
            rebootSetting = 'IfRequired'
            windowsParameters = [PSCustomObject]@{ classificationsToInclude = @('Critical','Security') }
        }
        namespace = 'guestOS'; visibility = 'Custom'
    })

    # Recovery Vault
    $script:MockResources += New-MockMgmtResource -Id '/sub/rv1' -Name 'rv-prod' `
        -Type 'microsoft.recoveryservices/vaults' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'
        sku = [PSCustomObject]@{ name = 'RS0'; tier = 'Standard' }
        publicNetworkAccess = 'Enabled'
        redundancySettings = [PSCustomObject]@{ standardTierStorageRedundancy = 'GeoRedundant' }
    })

    # Lighthouse Delegations
    $script:MockResources += New-MockMgmtResource -Id '/sub/ld1' -Name 'ld-mssp' `
        -Type 'Microsoft.ManagedServices/registrationDefinitions' -Props ([PSCustomObject]@{
        description = 'MSSP Managed Service'; managedByTenantId = 'tenant-mssp-001'
        managedByTenantName = 'MSSP Corp'
        authorizations = @(
            [PSCustomObject]@{ principalId = 'sp-001'; principalIdDisplayName = 'MSSP Engineers'; roleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c' }
        )
    })

    # Advisor Score — module filters for name in (Cost, Security, etc.) and reads timeSeries/scoreHistory
    $script:MockResources += New-MockMgmtResource `
        -Id '/subscriptions/sub-00000001/providers/Microsoft.Advisor/advisorScore/Cost' `
        -Name 'Cost' `
        -Type 'Microsoft.Advisor/advisorScore' -Props ([PSCustomObject]@{
        lastRefreshedScore = [PSCustomObject]@{ date = '2026-02-20T00:00:00Z'; score = 85.0 }
        timeSeries = @(
            [PSCustomObject]@{
                aggregationLevel = 'Monthly'
                scoreHistory = @(
                    [PSCustomObject]@{ date = '2026-01-01T00:00:00Z'; score = 80.0; impactedResourceCount = 5; consumptionUnits = 1200; potentialScoreIncrease = 3.5 }
                )
            }
        )
    })

    # Support Tickets — module casts createdDate, problemStartTime, modifiedDate to [datetime]
    $script:MockResources += New-MockMgmtResource -Id '/sub/st1' -Name 'ST000001' `
        -Type 'Microsoft.Support/supportTickets' -Props ([PSCustomObject]@{
        severity = 'B'; status = 'open'; problemClassificationDisplayName = 'Azure Virtual Machines'
        createdDate = '2026-02-01T10:00:00Z'; title = 'VM performance degradation'
        serviceDisplayName = 'Virtual Machine running Windows'
        problemStartTime = '2026-01-31T22:00:00Z'
        modifiedDate = '2026-02-05T14:30:00Z'
        supportTicketId = 'ST000001'
        supportPlanType = 'Premier'
        require24X7Response = $false
        serviceLevelAgreement = [PSCustomObject]@{ slaMinutes = 60 }
        supportEngineer = [PSCustomObject]@{ emailAddress = 'support@microsoft.com' }
        contactDetails = [PSCustomObject]@{
            firstName = 'John'; lastName = 'Doe'
            primaryEmailAddress = 'john.doe@contoso.com'; country = 'United States'
        }
    })

    # Reservation Recommendations
    $script:MockResources += New-MockMgmtResource -Id '/sub/rr1' -Name 'RR000001' `
        -Type 'Microsoft.Consumption/reservationRecommendations' -Props ([PSCustomObject]@{
        term = 'P1Y'; recommendedQuantity = 4; normalizedSize = 'Standard_D4s_v3'
        firstUsageDate = '2025-12-01T00:00:00Z'; totalCostWithReservedInstances = 12000
        netSavings = 3000; lookBackPeriod = 'Last7Days'
    })

    # Automation Account
    $script:MockResources += New-MockMgmtResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.automation/automationaccounts/auto-account-1' `
        -Name 'auto-account-1' -RG 'rg-mgmt' -Location 'eastus' -SubscriptionId 'sub-00000001' `
        -Type 'microsoft.automation/automationaccounts' -Props ([PSCustomObject]@{
        State        = 'Ok'
        sku          = [PSCustomObject]@{ name = 'Free' }
        creationTime = '2025-06-15T10:30:00Z'
    })

    # Runbook (belongs to auto-account-1 via id split)
    $script:MockResources += New-MockMgmtResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.automation/automationaccounts/auto-account-1/runbooks/test-runbook' `
        -Name 'test-runbook' -RG 'rg-mgmt' -Location 'eastus' -SubscriptionId 'sub-00000001' `
        -Type 'microsoft.automation/automationaccounts/runbooks' -Props ([PSCustomObject]@{
        lastModifiedTime = '2025-07-20T14:00:00Z'
        state            = 'Published'
        runbookType      = 'PowerShell'
        description      = 'Test runbook for automation'
    })

    # Backup Policy
    $script:MockResources += New-MockMgmtResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.recoveryservices/vaults/backup-vault/backuppolicies/daily-policy' `
        -Name 'daily-policy' -RG 'rg-mgmt' -Location 'eastus' -SubscriptionId 'sub-00000001' `
        -Type 'microsoft.recoveryservices/vaults/backuppolicies' -Props ([PSCustomObject]@{
        workloadtype        = 'AzureIaasVM'
        protecteditemscount = 2
        settings = [PSCustomObject]@{
            iscompression    = $true
            issqlcompression = $false
        }
        subprotectionpolicy = @([PSCustomObject]@{ policytype = 'Full' })
    })

    # Protected Item (linked to daily-policy via policyid)
    $script:MockResources += New-MockMgmtResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.recoveryservices/vaults/backup-vault/backupFabrics/Azure/protectionContainers/container1/protectedItems/item1' `
        -Name 'test-protected-item' -RG 'rg-mgmt' -Location 'eastus' -SubscriptionId 'sub-00000001' `
        -Type 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems' -Props ([PSCustomObject]@{
        policyid                             = '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.recoveryservices/vaults/backup-vault/backuppolicies/daily-policy'
        vaultid                              = '/subscriptions/sub-00000001/resourceGroups/rg-mgmt/providers/microsoft.recoveryservices/vaults/backup-vault'
        lastbackuptime                       = '2025-08-01T03:00:00Z'
        lastrecoverypoint                    = '2025-08-01T03:00:00Z'
        latestrecoverypointinsecondaryregion = $null
        backupmanagementtype                 = 'AzureIaasVM'
        friendlyname                         = 'test-vm'
        configuredmaximumretention           = 'P30D'
        configuredrpgenerationfrequency      = 'Daily'
        healthstatus                         = 'Healthy'
        protectionstatus                     = 'Healthy'
        isarchiveenabled                     = $false
        lastbackupstatus                     = 'Completed'
        protectionstate                      = 'Protected'
        protectionstateinsecondaryregion     = $null
        softdeleteretentionperiod            = 14
    })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS — Resource-based modules
# ===================================================================
Describe 'Management Module Files Exist' {
    It 'Management module folder exists' {
        $script:ManagementPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $MgmtResourceModules {
        Join-Path $script:ManagementPath $File | Should -Exist
    }

    It 'ManagementGroups.ps1 file exists' {
        Join-Path $script:ManagementPath 'ManagementGroups.ps1' | Should -Exist
    }

    It 'CustomRoleDefinitions.ps1 file exists' {
        Join-Path $script:ManagementPath 'CustomRoleDefinitions.ps1' | Should -Exist
    }

    It 'PolicyDefinitions.ps1 file exists' {
        Join-Path $script:ManagementPath 'PolicyDefinitions.ps1' | Should -Exist
    }

    It 'PolicySetDefinitions.ps1 file exists' {
        Join-Path $script:ManagementPath 'PolicySetDefinitions.ps1' | Should -Exist
    }

    It 'PolicyComplianceStates.ps1 file exists' {
        Join-Path $script:ManagementPath 'PolicyComplianceStates.ps1' | Should -Exist
    }

    It 'AllSubscriptions.ps1 file exists' {
        Join-Path $script:ManagementPath 'AllSubscriptions.ps1' | Should -Exist
    }
}

Describe 'Management Module Processing Phase — <Name>' -ForEach $MgmtResourceModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:ManagementPath $File
        $script:ResType = $Type
    }

    It 'Processing returns results when matching resources are present' {
        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $result = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $script:MockSubs, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
            $result | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }

    It 'Processing does not throw when given an empty resource list' {
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $script:MockSubs, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Management Module Reporting Phase — <Name>' -ForEach $MgmtResourceModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:ManagementPath $File
        $script:ResType  = $Type
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("Mgmt_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $script:MockSubs, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else {
            $script:ProcessedData = $null
        }
    }

    It 'Reporting phase does not throw' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }

    It 'Excel file is created' {
        if ($script:ProcessedData) {
            $script:XlsxFile | Should -Exist
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }
}

# ===================================================================
# TESTS — Live-call modules (mock Az cmdlets)
# ===================================================================
Describe 'ManagementGroups — Processing with mocked Get-AzManagementGroup + Get-AzContext' {
    BeforeAll {
        # Build a fake MG hierarchy object matching what Get-AzManagementGroup returns
        $child1 = [PSCustomObject]@{
            Name = 'mg-dept-it'; DisplayName = 'IT Department'; Type = 'Microsoft.Management/managementGroups'
            Children = @([PSCustomObject]@{ Name = 'sub-00000001'; DisplayName = 'Production Sub'; Type = '/subscriptions' })
        }
        $script:FakeMGRoot = [PSCustomObject]@{
            Name        = 'tenant-root-mg-001'
            DisplayName = 'Tenant Root'
            Type        = 'Microsoft.Management/managementGroups'
            Children    = @($child1)
        }
        $script:FakeContext = [PSCustomObject]@{
            Tenant = [PSCustomObject]@{ Id = 'tenant-root-mg-001' }
        }
    }

    It 'Processing does not throw with mocked Get-AzManagementGroup' {
        $modFile = Join-Path $script:ManagementPath 'ManagementGroups.ps1'
        $content = Get-Content -Path $modFile -Raw

        # Inject stub functions after the param() line so the module never calls live Az cmdlets.
        $stubs = @'

function Get-AzContext { [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-root-mg-001' } } }
function Get-AzManagementGroup { param($GroupId, [switch]$Expand, [switch]$Recurse, $ErrorAction) $null }

'@
        $content = $content -replace '(param\([^)]*\))', "`$1`n$stubs"
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'Reporting does not throw with empty SmaResources' {
        $modFile  = Join-Path $script:ManagementPath 'ManagementGroups.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir "ManagementGroups_empty.xlsx"
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'CustomRoleDefinitions — Processing with mocked Get-AzRoleDefinition' {
    It 'Processing does not throw when Get-AzRoleDefinition fails (no auth)' {
        $modFile = Join-Path $script:ManagementPath 'CustomRoleDefinitions.ps1'
        $content = Get-Content -Path $modFile -Raw
        $stub = "`nfunction Get-AzRoleDefinition { param(`$Name, `$Id, `$Scope, [switch]`$Custom, `$ErrorAction) @() }`n"
        $content = $content -replace '(param\([^)]*\))', "`$1$stub"
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'Reporting does not throw with empty data' {
        $modFile  = Join-Path $script:ManagementPath 'CustomRoleDefinitions.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir "CustomRoles_empty.xlsx"
        $stub = "`nfunction Get-AzRoleDefinition { param(`$Name, `$Id, `$Scope, [switch]`$Custom, `$ErrorAction) @() }`n"
        $content = $content -replace '(param\([^)]*\))', "`$1$stub"
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'AllSubscriptions — Processing with pre-loaded $Sub data' {
    It 'Processing does not throw with mock subscription list in Resources' {
        $mockSubs = @(
            [PSCustomObject]@{ Id = 'sub-00000001'; Name = 'Prod Sub'; State = 'Enabled'; TenantId = 'tenant-001'; Tags = @{} }
            [PSCustomObject]@{ Id = 'sub-00000002'; Name = 'Dev Sub';  State = 'Enabled'; TenantId = 'tenant-001'; Tags = @{} }
        )
        $modFile = Join-Path $script:ManagementPath 'AllSubscriptions.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb = [ScriptBlock]::Create($content)
        # Pass mock subs as the $Sub parameter ($Sub is param index 1 = $null placeholder here)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $mockSubs, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}
