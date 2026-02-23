#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Connect-AZTILoginSession.

.DESCRIPTION
    Validates the authentication manager:
      - SPN + Certificate auth path
      - SPN + Secret auth path
      - Device-code auth path
      - Current-user / interactive auth path
      - Throws when TenantID is missing for SPN auth
      - Returns TenantID string on success
      - LoginExperienceV2 handling (Get-AzConfig / Update-AzConfig)

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'AzureTenantInventory.psd1') -Force -ErrorAction Stop
}

Describe 'Connect-AZTILoginSession' {

    # ── SPN + Certificate ─────────────────────────────────────────────
    Context 'SPN + Certificate Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-123' } } }
            } -ModuleName AzureTenantInventory

            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
        }

        It 'Calls Connect-AzAccount with CertificatePath when AppId and CertificatePath are provided' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-123' -AppId 'app-id' -CertificatePath 'C:\cert.pfx'
            Should -Invoke Connect-AzAccount -ModuleName AzureTenantInventory -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-123' -AppId 'app-id' -CertificatePath 'C:\cert.pfx'
            $result | Should -Be 'tenant-123'
        }

        It 'Throws when TenantID is not provided for SPN auth' {
            { Connect-AZTILoginSession -AppId 'app-id' -CertificatePath 'C:\cert.pfx' } | Should -Throw
        }
    }

    # ── SPN + Secret ──────────────────────────────────────────────────
    Context 'SPN + Secret Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-456' } } }
            } -ModuleName AzureTenantInventory

            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
        }

        It 'Calls Connect-AzAccount with credential when AppId and Secret are provided' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-456' -AppId 'app-id' -Secret 'my-secret'
            Should -Invoke Connect-AzAccount -ModuleName AzureTenantInventory -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-456' -AppId 'app-id' -Secret 'my-secret'
            $result | Should -Be 'tenant-456'
        }

        It 'Throws when TenantID is not provided for SPN secret auth' {
            { Connect-AZTILoginSession -AppId 'app-id' -Secret 'my-secret' } | Should -Throw
        }
    }

    # ── Device Code ───────────────────────────────────────────────────
    Context 'Device Code Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-789' } } }
            } -ModuleName AzureTenantInventory

            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
        }

        It 'Calls Connect-AzAccount with UseDeviceAuthentication when DeviceLogin switch is set' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-789' -DeviceLogin
            Should -Invoke Connect-AzAccount -ModuleName AzureTenantInventory -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-789' -DeviceLogin
            $result | Should -Be 'tenant-789'
        }
    }

    # ── Current User / Interactive ────────────────────────────────────
    Context 'Current User Auth' {

        It 'Reuses existing context when tenant matches' {
            Mock Get-AzContext {
                return [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-existing' } }
            } -ModuleName AzureTenantInventory

            Mock Connect-AzAccount { } -ModuleName AzureTenantInventory

            $result = Connect-AZTILoginSession -TenantID 'tenant-existing'
            Should -Not -Invoke Connect-AzAccount -ModuleName AzureTenantInventory
            $result | Should -Be 'tenant-existing'
        }

        It 'Calls Connect-AzAccount when no existing context' {
            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-new' } } }
            } -ModuleName AzureTenantInventory
            Mock Get-AzConfig { return [PSCustomObject]@{ Value = 'On' } } -ModuleName AzureTenantInventory
            Mock Update-AzConfig { } -ModuleName AzureTenantInventory

            $result = Connect-AZTILoginSession -TenantID 'tenant-new'
            Should -Invoke Connect-AzAccount -ModuleName AzureTenantInventory -Times 1
        }
    }

    # ── LoginExperienceV2 Handling ────────────────────────────────────
    Context 'LoginExperienceV2 Handling' {

        BeforeAll {
            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-v2' } } }
            } -ModuleName AzureTenantInventory
            Mock Get-AzConfig {
                return [PSCustomObject]@{ Value = 'On' }
            } -ModuleName AzureTenantInventory
            Mock Update-AzConfig { } -ModuleName AzureTenantInventory
        }

        It 'Checks LoginExperienceV2 config for interactive login' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-v2'
            Should -Invoke Get-AzConfig -ModuleName AzureTenantInventory
        }
    }

    # ── AzureEnvironment Passthrough ──────────────────────────────────
    Context 'AzureEnvironment Passthrough' {

        BeforeAll {
            Mock Get-AzContext { return $null } -ModuleName AzureTenantInventory
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-gov' } } }
            } -ModuleName AzureTenantInventory
            Mock Get-AzConfig { return [PSCustomObject]@{ Value = 'Off' } } -ModuleName AzureTenantInventory
            Mock Update-AzConfig { } -ModuleName AzureTenantInventory
        }

        It 'Passes AzureEnvironment through to Connect-AzAccount' {
            $result = Connect-AZTILoginSession -TenantID 'tenant-gov' -AzureEnvironment 'AzureUSGovernment'
            Should -Invoke Connect-AzAccount -ModuleName AzureTenantInventory -ParameterFilter {
                $Environment -eq 'AzureUSGovernment'
            }
        }
    }
}
