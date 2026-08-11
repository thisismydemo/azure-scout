#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Start-AZSCEntraExtraction.

.DESCRIPTION
    Validates the Entra ID extraction engine:
      - Returns @{ EntraResources = [array] } structure
      - Processes every query in the Entra catalog
      - Normalizes resources to { id, name, TYPE, tenantId, properties }
      - Handles SingleObject queries (e.g., organization)
      - Graceful degradation — failed queries do not stop execution
      - Empty results produce an empty array, not $null

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path -Path $ModuleRoot -ChildPath 'AzureScout.psd1') -Force -ErrorAction Stop

InModuleScope 'AzureScout' {
Describe 'Start-AZSCEntraExtraction' {

    BeforeEach {
        Mock Get-AZSCGraphToken {
            @{ Authorization = 'Bearer preflight-token'; 'Content-Type' = 'application/json' }
        }
    }

    # ── Return Structure ──────────────────────────────────────────────
    Context 'Return Structure' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                return @(
                    [PSCustomObject]@{ id = '1'; displayName = 'Test User'; userPrincipalName = 'user@test.com' }
                )
            }
        }

        It 'Returns an object with EntraResources property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'EntraResources'
        }

        It 'EntraResources is an array' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources | Should -BeOfType [System.Object]
        }

        It 'EntraResources contains items when Graph returns data' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -BeGreaterThan 0
        }
    }

    # ── Normalized Resource Shape ─────────────────────────────────────
    Context 'Normalized Resource Shape' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                if ($Uri -like '*users*') {
                    return @(
                        [PSCustomObject]@{ id = 'user-001'; displayName = 'Alice'; userPrincipalName = 'alice@test.com' }
                    )
                }
                return @(
                    [PSCustomObject]@{ id = 'obj-001'; displayName = 'Generic Object' }
                )
            }
        }

        It 'Each resource has an id property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'id'
        }

        It 'Each resource has a name property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'name'
        }

        It 'Each resource has a TYPE property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'TYPE'
        }

        It 'Each resource has a tenantId property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'tenantId'
        }

        It 'Each resource has a properties property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'properties'
        }

        It 'tenantId is set to the provided TenantID' {
            $result = Start-AZSCEntraExtraction -TenantID 'my-tenant-id'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.tenantId | Should -Be 'my-tenant-id'
        }
    }

    # ── All Entra Queries ─────────────────────────────────────────────
    Context 'All Entra Queries Executed' {

        BeforeAll {
            $script:graphCallUris = [System.Collections.Generic.List[string]]::new()
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                $script:graphCallUris.Add($Uri)
                return @(
                    [PSCustomObject]@{ id = 'obj-1'; displayName = 'Test Object' }
                )
            }
        }

        AfterAll {
            Remove-Variable -Name graphCallUris -Scope Script -ErrorAction SilentlyContinue
        }

        It 'calls Invoke-AZSCGraphRequest once for every catalog query' {
            $null = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $expected = @(Get-ScoutEntraQueryCatalog).Count
            Should -Invoke Invoke-AZSCGraphRequest -Times $expected -Scope It
        }

        It 'pins every Graph query to the requested tenant' {
            $null = Start-AZSCEntraExtraction -TenantID 'target-tenant'
            $expected = @(Get-ScoutEntraQueryCatalog).Count
            Should -Invoke Invoke-AZSCGraphRequest -Times $expected -Scope It -ParameterFilter {
                $TenantID -eq 'target-tenant'
            }
        }
    }

    Context 'Graph authentication gate' {
        BeforeEach {
            Mock Get-AZSCGraphToken { throw 'AADSTS500213 cross-tenant access denied' }
            Mock Invoke-AZSCGraphRequest { throw 'A Graph query must not run after authentication fails.' }
        }

        It 'attempts Graph authentication once and skips every query without retry spam' {
            $result = Start-AZSCEntraExtraction -TenantID 'target-tenant' -WarningAction SilentlyContinue

            Should -Invoke Get-AZSCGraphToken -Times 1 -Scope It -ParameterFilter {
                $TenantID -eq 'target-tenant'
            }
            Should -Invoke Invoke-AZSCGraphRequest -Times 0 -Scope It
            @($result.QueryOutcomes).Count | Should -Be @(Get-ScoutEntraQueryCatalog).Count
            @($result.QueryOutcomes | Where-Object Success).Count | Should -Be 0
            @($result.EntraResources).Count | Should -Be 0
        }

        It 'emits one warning for the authentication failure' {
            $warnings = @()
            $null = Start-AZSCEntraExtraction -TenantID 'target-tenant' -WarningVariable warnings

            @($warnings).Count | Should -Be 1
            [string]$warnings[0] | Should -Match 'authentication failed'
            [string]$warnings[0] | Should -Match 'AADSTS500213'
        }
    }

    # ── Graceful Degradation ──────────────────────────────────────────
    Context 'Graceful Degradation — Individual Query Failure' {

        BeforeAll {
            $script:failCallCount = 0
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                $null = $Uri
                $script:failCallCount++
                # Fail the first query, succeed all others
                if ($script:failCallCount -eq 1) {
                    throw 'Forbidden — insufficient privileges'
                }
                return @(
                    [PSCustomObject]@{ id = "obj-$($script:failCallCount)"; displayName = 'Item' }
                )
            }
        }

        AfterAll {
            Remove-Variable -Name failCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'Does not throw when a single query fails' {
            { Start-AZSCEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Still returns data from succeeded queries' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -BeGreaterThan 0
        }
    }

    # ── All Queries Fail ──────────────────────────────────────────────
    Context 'All Queries Fail' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest { throw 'Service unavailable' }
        }

        It 'Does not throw even when all queries fail' {
            { Start-AZSCEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Returns an empty EntraResources array' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -Be 0
        }
    }

    # ── SingleObject Queries ──────────────────────────────────────────
    Context 'SingleObject Queries' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                # Organization endpoint returns a single object
                if ($Uri -like '*organization*') {
                    return [PSCustomObject]@{ id = 'org-1'; displayName = 'Contoso Corp' }
                }
                # Collection endpoints return arrays
                return @(
                    [PSCustomObject]@{ id = 'item-1'; displayName = 'Item' }
                )
            }
        }

        It 'Handles single-object responses without error' {
            { Start-AZSCEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Includes the organization object in results' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $orgResource = $result.EntraResources | Where-Object { $_.name -eq 'Contoso Corp' -or $_.id -eq 'org-1' }
            $orgResource | Should -Not -BeNullOrEmpty
        }
    }

    # ── QueryOutcomes (AB#6456) ─────────────────────────────────────────
    Context 'QueryOutcomes -- per-query success/failure record' {

        BeforeAll {
            $script:outcomeCallCount = 0
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                $script:outcomeCallCount++
                # Fail the Users query specifically (the first catalog entry), succeed the rest --
                # including one that returns zero rows so the two are distinguishable.
                if ($Uri -like '*/users*') { throw 'Forbidden — insufficient privileges' }
                if ($Uri -like '*crossTenantAccessPolicy*') { return @() }
                return @([PSCustomObject]@{ id = "obj-$($script:outcomeCallCount)"; displayName = 'Item' })
            }
        }

        AfterAll {
            Remove-Variable -Name outcomeCallCount -Scope Script -ErrorAction SilentlyContinue
        }

        It 'returns a QueryOutcomes property' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $result.PSObject.Properties.Name | Should -Contain 'QueryOutcomes'
        }

        It 'records one outcome per catalog query' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $expected = @(Get-ScoutEntraQueryCatalog).Count
            @($result.QueryOutcomes).Count | Should -Be $expected
        }

        It 'marks a failed query Success = $false' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $usersOutcome = @($result.QueryOutcomes | Where-Object { $_.Type -eq 'entra/users' })[0]
            $usersOutcome.Success | Should -BeFalse
        }

        It 'marks a query that succeeded and returned zero rows Success = $true' {
            # The distinction this whole field exists for: empty is not the same as denied.
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $crossTenantOutcome = @($result.QueryOutcomes | Where-Object { $_.Type -eq 'entra/crosstenantaccess' })[0]
            $crossTenantOutcome.Success | Should -BeTrue
            $crossTenantOutcome.Count   | Should -Be 0
        }

        It 'marks a normally-succeeding query Success = $true with its row count' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $groupsOutcome = @($result.QueryOutcomes | Where-Object { $_.Type -eq 'entra/groups' })[0]
            $groupsOutcome.Success | Should -BeTrue
            $groupsOutcome.Count   | Should -Be 1
        }
    }

    # ── TenantID Parameter ────────────────────────────────────────────
    Context 'TenantID Parameter' {

        It 'TenantID is mandatory' {
            $cmd = Get-Command Start-AZSCEntraExtraction
            $attr = $cmd.Parameters['TenantID'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }

    # ── Verified ID catalog entries (AB#7097) ──────────────────────────
    Context 'Verified ID catalog entries' {

        It 'declares the authentication-method configuration as a SingleObject query under graph.microsoft.com' {
            $entry = @(Get-ScoutEntraQueryCatalog | Where-Object { $_.Type -eq 'entra/verifiedidconfiguration' })
            $entry.Count | Should -Be 1
            $entry[0].Uri | Should -Be '/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/VerifiableCredentials'
            $entry[0].SingleObject | Should -BeTrue
            $entry[0].Permission | Should -Be 'Policy.Read.AuthenticationMethod'
        }

        It 'declares the profiles collection query under graph.microsoft.com' {
            $entry = @(Get-ScoutEntraQueryCatalog | Where-Object { $_.Type -eq 'entra/verifiedidprofiles' })
            $entry.Count | Should -Be 1
            $entry[0].Uri | Should -Be '/v1.0/identity/verifiedId/profiles'
            $entry[0].Permission | Should -Be 'VerifiedId-Profile.Read.All'
        }

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                if ($Uri -like '*authenticationMethodConfigurations/VerifiableCredentials*') {
                    return [PSCustomObject]@{
                        id             = 'VerifiableCredentials'
                        state          = 'enabled'
                        excludeTargets = @()
                    }
                }
                if ($Uri -like '*verifiedId/profiles*') {
                    return @(
                        [PSCustomObject]@{
                            id                            = 'profile-001'
                            name                           = 'Recovery Profile'
                            description                    = 'Self-service recovery'
                            state                           = 'enabled'
                            priority                        = 1
                            verifierDid                     = 'did:web:contoso.com'
                            verifiedIdProfileConfiguration  = [PSCustomObject]@{ acceptedIssuer = 'did:web:contoso.com'; type = 'VerifiedEmployee' }
                            verifiedIdUsageConfigurations   = @([PSCustomObject]@{ purpose = 'recovery'; isEnabledForTestOnly = $false })
                            faceCheckConfiguration          = [PSCustomObject]@{ state = 'disabled' }
                            lastModifiedDateTime            = '2026-07-01T00:00:00Z'
                        }
                    )
                }
                return @([PSCustomObject]@{ id = 'obj-1'; displayName = 'Item' })
            }
        }

        It 'normalises the single-object configuration response into one entra/verifiedidconfiguration row' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $rows = @($result.EntraResources | Where-Object { $_.TYPE -eq 'entra/verifiedidconfiguration' })
            $rows.Count | Should -Be 1
            $rows[0].properties.state | Should -Be 'enabled'
        }

        It 'normalises the profiles collection into entra/verifiedidprofiles rows' {
            $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
            $rows = @($result.EntraResources | Where-Object { $_.TYPE -eq 'entra/verifiedidprofiles' })
            $rows.Count | Should -Be 1
            $rows[0].name | Should -Be 'Recovery Profile'
            $rows[0].properties.verifierDid | Should -Be 'did:web:contoso.com'
        }
    }
}
} # end InModuleScope
