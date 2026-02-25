#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Test-AZSCPermissions.

.DESCRIPTION
    Validates the pre-flight permission checker:
      - ARM subscription enumeration (pass/fail)
      - ARM root MG access (pass/warn)
      - Graph organization read (pass/fail)
      - Graph user read (pass/fail)
      - Graph conditional access read (pass/warn)
      - Scope gating (ArmOnly skips Graph, EntraOnly skips ARM)
      - Always returns structured object, never throws

    Tests mock Invoke-AZSCPermissionAudit (the delegated audit function) rather
    than individual Az cmdlets, since Test-AZSCPermissions is a pure mapping wrapper.

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'AzureScout.psd1') -Force -ErrorAction Stop

    # Helper to build a mock audit result with sensible defaults
    function New-MockAuditResult {
        param(
            [bool]$ArmAccess = $true,
            $GraphAccess = $true,
            [array]$ArmDetails = @(),
            [array]$ProviderResults = @(),
            [array]$GraphDetails = @(),
            [string]$OverallReadiness = 'FullARMAndEntra'
        )
        [PSCustomObject]@{
            ArmAccess        = $ArmAccess
            GraphAccess      = $GraphAccess
            CallerAccount    = 'test@contoso.com'
            CallerType       = 'User'
            TenantId         = 'test-tenant'
            ArmDetails       = $ArmDetails
            ProviderResults  = $ProviderResults
            GraphDetails     = $GraphDetails
            Recommendations  = @()
            OverallReadiness = $OverallReadiness
            AuditTimestamp   = (Get-Date -Format 'o')
        }
    }

    function New-CheckDetail {
        param([string]$Check, [string]$Status = 'Pass', [string]$Message = '', [string]$Remediation = '')
        [PSCustomObject]@{ Check = $Check; Status = $Status; Message = $Message; Remediation = $Remediation }
    }
}

Describe 'Test-AZSCPermissions' {

    # ── Return Structure ───────────────────────────────────────────────
    Context 'Return Structure' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult `
                    -ArmDetails @( New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' 'Found 1 subscription(s)' ) `
                    -GraphDetails @(
                        New-CheckDetail 'Graph: Organization Read' 'Pass'
                        New-CheckDetail 'Graph: Users Read' 'Pass'
                        New-CheckDetail 'Graph: Conditional Access Read' 'Pass'
                    )
            } -ModuleName AzureScout
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
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true `
                    -ArmDetails @(
                        New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' 'Found 1 subscription(s)'
                        New-CheckDetail 'ARM: Root Management Group Access' 'Pass' 'Can read root MG'
                    ) `
                    -GraphAccess $null
            } -ModuleName AzureScout
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

        It 'Reports ARM: Root Management Group Access as Pass' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $roleCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Root Management Group Access' }
            $roleCheck.Status | Should -Be 'Pass'
        }
    }

    # ── ARM Checks — No Subscriptions ─────────────────────────────────
    Context 'ARM Checks — No Subscriptions' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $false `
                    -ArmDetails @(
                        New-CheckDetail 'ARM: Subscription Enumeration' 'Fail' 'No subscriptions found' 'Grant Reader role'
                    ) `
                    -GraphAccess $null -OverallReadiness 'Insufficient'
            } -ModuleName AzureScout
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
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $false `
                    -ArmDetails @(
                        New-CheckDetail 'ARM: Subscription Enumeration' 'Fail' 'Unauthorized' 'Grant Reader role on sub'
                    ) `
                    -GraphAccess $null -OverallReadiness 'Insufficient'
            } -ModuleName AzureScout
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

    # ── ARM Checks — Root MG Access Warns ─────────────────────────────
    Context 'ARM Checks — Root MG Access Warning' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true `
                    -ArmDetails @(
                        New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' 'Found 1 sub'
                        New-CheckDetail 'ARM: Root Management Group Access' 'Warn' 'Cannot read root MG' 'Grant Reader at root MG'
                    ) `
                    -GraphAccess $null
            } -ModuleName AzureScout
        }

        It 'ArmAccess remains $true (root MG access is non-blocking)' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $result.ArmAccess | Should -BeTrue
        }

        It 'Reports root MG access as Warn' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope ArmOnly
            $roleCheck = $result.Details | Where-Object { $_.Check -eq 'ARM: Root Management Group Access' }
            $roleCheck.Status | Should -Be 'Warn'
        }
    }

    # ── Graph Checks — All Pass ───────────────────────────────────────
    Context 'Graph Checks — All Pass' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true -GraphAccess $true `
                    -ArmDetails @( New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' ) `
                    -GraphDetails @(
                        New-CheckDetail 'Graph: Organization Read' 'Pass'
                        New-CheckDetail 'Graph: Users Read' 'Pass'
                        New-CheckDetail 'Graph: Groups Read' 'Pass'
                        New-CheckDetail 'Graph: Applications Read' 'Pass'
                        New-CheckDetail 'Graph: Service Principals Read' 'Pass'
                        New-CheckDetail 'Graph: Directory Roles Read' 'Pass'
                        New-CheckDetail 'Graph: Conditional Access Read' 'Pass'
                        New-CheckDetail 'Graph: Risky Users Read' 'Pass'
                        New-CheckDetail 'Graph: Audit Logs Read' 'Pass'
                    )
            } -ModuleName AzureScout
        }

        It 'Sets GraphAccess to $true when all Graph checks pass' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeTrue
        }

        It 'Has Graph detail entries' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $graphChecks = $result.Details | Where-Object { $_.Check -like 'Graph:*' }
            $graphChecks.Count | Should -BeGreaterOrEqual 3
        }
    }

    # ── Graph Checks — Organization Read Fails ────────────────────────
    Context 'Graph Checks — Organization Read Fails' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true -GraphAccess $false `
                    -ArmDetails @( New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' ) `
                    -GraphDetails @(
                        New-CheckDetail 'Graph: Organization Read' 'Fail' 'DENIED' 'Grant Organization.Read.All'
                        New-CheckDetail 'Graph: Users Read' 'Pass'
                        New-CheckDetail 'Graph: Conditional Access Read' 'Pass'
                    )
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
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true -GraphAccess $false `
                    -ArmDetails @( New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' ) `
                    -GraphDetails @(
                        New-CheckDetail 'Graph: Organization Read' 'Pass'
                        New-CheckDetail 'Graph: Users Read' 'Fail' 'DENIED' 'Grant User.Read.All'
                    )
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
            Mock Invoke-AZSCPermissionAudit {
                New-MockAuditResult -ArmAccess $true -GraphAccess $true `
                    -ArmDetails @( New-CheckDetail 'ARM: Subscription Enumeration' 'Pass' ) `
                    -GraphDetails @(
                        New-CheckDetail 'Graph: Organization Read' 'Pass'
                        New-CheckDetail 'Graph: Users Read' 'Pass'
                        New-CheckDetail 'Graph: Conditional Access Read' 'Warn' 'DENIED — optional' 'Grant Policy.Read.All'
                    )
            } -ModuleName AzureScout
        }

        It 'GraphAccess remains $true (CA is optional, warn-only)' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $result.GraphAccess | Should -BeTrue
        }

        It 'Reports CA policies check as Warn' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope EntraOnly
            $caCheck = $result.Details | Where-Object { $_.Check -eq 'Graph: Conditional Access Read' }
            $caCheck.Status | Should -Be 'Warn'
        }
    }

    # ── Scope Gating ──────────────────────────────────────────────────
    Context 'Scope Gating' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit {
                $gd = @()
                $ga = $null
                if ($IncludeEntraPermissions) {
                    $gd = @(
                        New-CheckDetail 'Graph: Organization Read' 'Pass'
                        New-CheckDetail 'Graph: Users Read' 'Pass'
                    )
                    $ga = $true
                }
                New-MockAuditResult -ArmAccess $true -GraphAccess $ga `
                    -ArmDetails @(
                        New-CheckDetail 'ARM: Subscription Enumeration' 'Pass'
                        New-CheckDetail 'ARM: Root Management Group Access' 'Pass'
                    ) `
                    -GraphDetails $gd
            } -ModuleName AzureScout
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

    # ── No Auth Context (Invoke-AZSCPermissionAudit returns null) ─────
    Context 'Never Throws' {

        BeforeAll {
            Mock Invoke-AZSCPermissionAudit { return $null } -ModuleName AzureScout
        }

        It 'Returns a result even when all checks fail' {
            $result = Test-AZSCPermissions -TenantID 'test-tenant' -Scope All
            $result | Should -Not -BeNullOrEmpty
            $result.ArmAccess | Should -BeFalse
            $result.GraphAccess | Should -BeFalse
        }
    }
}
