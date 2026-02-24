#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Test-AZSCPermissions.

.DESCRIPTION
    Validates the pre-flight permission checker:
      - ARM subscription enumeration (pass/fail)
      - ARM role assignment read (pass/warn)
      - Graph organization read (pass/fail)
      - Graph user read (pass/fail)
      - Graph conditional access read (pass/warn)
      - Scope gating (ArmOnly skips Graph, EntraOnly skips ARM)
      - Always returns structured object, never throws

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'AzureScout.psd1') -Force -ErrorAction Stop
}

Describe 'Test-AZSCPermissions' {

    # ── Return Structure ───────────────────────────────────────────────
    Context 'Return Structure' {

        BeforeAll {
            Mock Get-AzSubscription { return @([PSCustomObject]@{ Id = 'sub-001'; Name = 'Test Sub' }) } -ModuleName AzureScout
            Mock Get-AzRoleAssignment { return @([PSCustomObject]@{ RoleDefinitionName = 'Reader' }) } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'Returns an object with ArmAccess, GraphAccess, and Details properties' {
            $result = Test-AZSCPermissions -TenantID '00000000-0000-0000-0000-000000000000'
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'ArmAccess'
            $result.PSObject.Properties.Name | Should -Contain 'GraphAccess'
            $result.PSObject.Properties.Name | Should -Contain 'Details'
        }

        It 'ArmAccess and GraphAccess are booleans' {
            $result = Test-AZSCPermissions -TenantID '00000000-0000-0000-0000-000000000000'
            $result.ArmAccess | Should -BeOfType [bool]
            $result.GraphAccess | Should -BeOfType [bool]
        }

        It 'Details is a collection' {
            $result = Test-AZSCPermissions -TenantID '00000000-0000-0000-0000-000000000000'
            $result.Details.Count | Should -BeGreaterThan 0
        }
    }

    # ── ARM Checks — All Pass ─────────────────────────────────────────
    Context 'ARM Checks — All Pass' {

        BeforeAll {
            Mock Get-AzSubscription { return @([PSCustomObject]@{ Id = 'sub-001'; Name = 'Test Sub' }) } -ModuleName AzureScout
            Mock Get-AzRoleAssignment { return @([PSCustomObject]@{ RoleDefinitionName = 'Reader' }) } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'Sets ArmAccess to $true when subscriptions are found' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $result.ArmAccess | Should -BeTrue
        }

        It 'Reports ARM: Subscription Enumeration as Pass' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $subCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Subscription Enumeration' }
            $subCheck.Status | Should -Be 'Pass'
        }

        It 'Reports ARM: Role Assignment Read as Pass' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $roleCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Role Assignment Read' }
            $roleCheck.Status | Should -Be 'Pass'
        }
    }

    # ── ARM Checks — No Subscriptions ─────────────────────────────────
    Context 'ARM Checks — No Subscriptions' {

        BeforeAll {
            Mock Get-AzSubscription { return @() } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'Sets ArmAccess to $false when no subscriptions found' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $result.ArmAccess | Should -BeFalse
        }

        It 'Reports subscription enumeration as Fail' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $subCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Subscription Enumeration' }
            $subCheck.Status | Should -Be 'Fail'
        }
    }

    # ── ARM Checks — Get-AzSubscription Throws ────────────────────────
    Context 'ARM Checks — Subscription Enumeration Fails' {

        BeforeAll {
            Mock Get-AzSubscription { throw 'Unauthorized' } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'Sets ArmAccess to $false when Get-AzSubscription throws' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $result.ArmAccess | Should -BeFalse
        }

        It 'Captures the error message in Details' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $subCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Subscription Enumeration' }
            $subCheck.Status | Should -Be 'Fail'
            $subCheck.Remediation | Should -Not -BeNullOrEmpty
        }
    }

    # ── ARM Checks — Role Assignment Read Warns ───────────────────────
    Context 'ARM Checks — Role Assignment Read Warning' {

        BeforeAll {
            Mock Get-AzSubscription { return @([PSCustomObject]@{ Id = 'sub-001'; Name = 'Test Sub' }) } -ModuleName AzureScout
            Mock Get-AzRoleAssignment { throw 'AuthorizationFailed' } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'ArmAccess remains $true (role assignment read is non-blocking)' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $result.ArmAccess | Should -BeTrue
        }

        It 'Reports role assignment read as Warn' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $roleCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Role Assignment Read' }
            $roleCheck.Status | Should -Be 'Warn'
        }
    }

    # ── Graph Checks — All Pass ───────────────────────────────────────
    Context 'Graph Checks — All Pass' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'Sets GraphAccess to $true when all Graph checks pass' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeTrue
        }

        It 'Has three Graph detail entries' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $graphChecks = $result.Details | Where-Object { $_.Check -like 'Graph:*' }
            $graphChecks.Count | Should -Be 3
        }
    }

    # ── Graph Checks — Organization Read Fails ────────────────────────
    Context 'Graph Checks — Organization Read Fails' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                if ($Uri -like '*/organization*') { throw 'Forbidden' }
                return [PSCustomObject]@{ displayName = 'Test' }
            } -ModuleName AzureScout
        }

        It 'Sets GraphAccess to $false' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeFalse
        }

        It 'Reports Organization Read as Fail with remediation' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $orgCheck = $result.Details | Where-Object { $_.Check -eq 'Graph: Organization Read' }
            $orgCheck.Status | Should -Be 'Fail'
            $orgCheck.Remediation | Should -Not -BeNullOrEmpty
        }
    }

    # ── Graph Checks — User Read Fails ────────────────────────────────
    Context 'Graph Checks — User Read Fails' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                if ($Uri -like '*/users*') { throw 'Insufficient privileges' }
                return [PSCustomObject]@{ displayName = 'Contoso' }
            } -ModuleName AzureScout
        }

        It 'Sets GraphAccess to $false when user read fails' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeFalse
        }
    }

    # ── Graph Checks — Conditional Access Warns ───────────────────────
    Context 'Graph Checks — Conditional Access Warns' {

        BeforeAll {
            Mock Invoke-AZSCGraphRequest {
                param($Uri)
                if ($Uri -like '*/conditionalAccess*') { throw 'Forbidden' }
                return [PSCustomObject]@{ displayName = 'Contoso' }
            } -ModuleName AzureScout
        }

        It 'GraphAccess remains $true (CA is optional, warn-only)' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeTrue
        }

        It 'Reports CA policies check as Warn' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $caCheck = $result.Details | Where-Object { $_.Check -eq 'Graph: Conditional Access Policies' }
            $caCheck.Status | Should -Be 'Warn'
        }
    }

    # ── Scope Gating ──────────────────────────────────────────────────
    Context 'Scope Gating' {

        BeforeAll {
            Mock Get-AzSubscription { return @([PSCustomObject]@{ Id = 'sub-001'; Name = 'Test Sub' }) } -ModuleName AzureScout
            Mock Get-AzRoleAssignment { return @([PSCustomObject]@{ RoleDefinitionName = 'Reader' }) } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { return [PSCustomObject]@{ displayName = 'Contoso' } } -ModuleName AzureScout
        }

        It 'ArmOnly scope produces no Graph checks' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $graphChecks = $result.Details | Where-Object { $_.Check -like 'Graph:*' }
            $graphChecks | Should -BeNullOrEmpty
        }

        It 'EntraOnly scope produces no ARM checks' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $armChecks = $result.Details | Where-Object { $_.Check -like 'ARM:*' }
            $armChecks | Should -BeNullOrEmpty
        }

        It 'All scope produces both ARM and Graph checks' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope All
            $armChecks = $result.Details | Where-Object { $_.Check -like 'ARM:*' }
            $graphChecks = $result.Details | Where-Object { $_.Check -like 'Graph:*' }
            $armChecks.Count | Should -BeGreaterThan 0
            $graphChecks.Count | Should -BeGreaterThan 0
        }
    }

    # ── Never Throws ──────────────────────────────────────────────────
    Context 'Never Throws' {

        BeforeAll {
            Mock Get-AzSubscription { throw 'Total failure' } -ModuleName AzureScout
            Mock Invoke-AZSCGraphRequest { throw 'Total failure' } -ModuleName AzureScout
        }

        It 'Returns a result even when all checks fail' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope All
            $result | Should -Not -BeNullOrEmpty
            $result.ArmAccess | Should -BeFalse
            $result.GraphAccess | Should -BeFalse
        }
    }
}
