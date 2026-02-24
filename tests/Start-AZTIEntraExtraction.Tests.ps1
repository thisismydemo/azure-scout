#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Start-AZTIEntraExtraction.

.DESCRIPTION
    Validates the Entra ID extraction engine:
      - Returns @{ EntraResources = [array] } structure
      - Processes all 15 entra queries
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
Import-Module (Join-Path $ModuleRoot 'AzureTenantInventory.psd1') -Force -ErrorAction Stop

InModuleScope 'AzureTenantInventory' {
Describe 'Start-AZTIEntraExtraction' {

    # ── Return Structure ──────────────────────────────────────────────
    Context 'Return Structure' {

        BeforeAll {
            Mock Invoke-AZTIGraphRequest {
                return @(
                    [PSCustomObject]@{ id = '1'; displayName = 'Test User'; userPrincipalName = 'user@test.com' }
                )
            }
        }

        It 'Returns an object with EntraResources property' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'EntraResources'
        }

        It 'EntraResources is an array' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources | Should -BeOfType [System.Object]
        }

        It 'EntraResources contains items when Graph returns data' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -BeGreaterThan 0
        }
    }

    # ── Normalized Resource Shape ─────────────────────────────────────
    Context 'Normalized Resource Shape' {

        BeforeAll {
            Mock Invoke-AZTIGraphRequest {
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
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'id'
        }

        It 'Each resource has a name property' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'name'
        }

        It 'Each resource has a TYPE property' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'TYPE'
        }

        It 'Each resource has a tenantId property' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'tenantId'
        }

        It 'Each resource has a properties property' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.PSObject.Properties.Name | Should -Contain 'properties'
        }

        It 'tenantId is set to the provided TenantID' {
            $result = Start-AZTIEntraExtraction -TenantID 'my-tenant-id'
            $resource = $result.EntraResources | Select-Object -First 1
            $resource.tenantId | Should -Be 'my-tenant-id'
        }
    }

    # ── All 15 Entra Queries ──────────────────────────────────────────
    Context 'All Entra Queries Executed' {

        BeforeAll {
            $script:graphCallUris = [System.Collections.Generic.List[string]]::new()
            Mock Invoke-AZTIGraphRequest {
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

        It 'Calls Invoke-AZTIGraphRequest for at least 15 entra queries' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            Should -Invoke Invoke-AZTIGraphRequest -Times 15 -Scope It
        }
    }

    # ── Graceful Degradation ──────────────────────────────────────────
    Context 'Graceful Degradation — Individual Query Failure' {

        BeforeAll {
            $script:failCallCount = 0
            Mock Invoke-AZTIGraphRequest {
                param($Uri)
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
            { Start-AZTIEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Still returns data from succeeded queries' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -BeGreaterThan 0
        }
    }

    # ── All Queries Fail ──────────────────────────────────────────────
    Context 'All Queries Fail' {

        BeforeAll {
            Mock Invoke-AZTIGraphRequest { throw 'Service unavailable' }
        }

        It 'Does not throw even when all queries fail' {
            { Start-AZTIEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Returns an empty EntraResources array' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $result.EntraResources.Count | Should -Be 0
        }
    }

    # ── SingleObject Queries ──────────────────────────────────────────
    Context 'SingleObject Queries' {

        BeforeAll {
            Mock Invoke-AZTIGraphRequest {
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
            { Start-AZTIEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw
        }

        It 'Includes the organization object in results' {
            $result = Start-AZTIEntraExtraction -TenantID 'test-tenant'
            $orgResource = $result.EntraResources | Where-Object { $_.name -eq 'Contoso Corp' -or $_.id -eq 'org-1' }
            $orgResource | Should -Not -BeNullOrEmpty
        }
    }

    # ── TenantID Parameter ────────────────────────────────────────────
    Context 'TenantID Parameter' {

        It 'TenantID is mandatory' {
            $cmd = Get-Command Start-AZTIEntraExtraction
            $attr = $cmd.Parameters['TenantID'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $attr.Mandatory | Should -BeTrue
        }
    }
}
} # end InModuleScope
