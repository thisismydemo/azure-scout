#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Connect-AZSCLoginSession.

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

$ModuleRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $ModuleRoot 'AzureScout.psd1') -Force -ErrorAction Stop

Describe 'Connect-AZSCLoginSession' {

    # ── SPN + Certificate ─────────────────────────────────────────────
    Context 'SPN + Certificate Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-123' } } }
            } -ModuleName AzureScout

            Mock Get-AzContext { return $null } -ModuleName AzureScout
        }

        It 'Calls Connect-AzAccount with CertificatePath when AppId and CertificatePath are provided' {
            InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-123' -AppId 'app-id' -CertificatePath 'C:\cert.pfx'
            }
            Should -Invoke Connect-AzAccount -ModuleName AzureScout -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-123' -AppId 'app-id' -CertificatePath 'C:\cert.pfx'
            }
            $result | Should -Be 'tenant-123'
        }

        It 'Throws when TenantID is not provided for SPN auth' {
            { InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -AppId 'app-id' -CertificatePath 'C:\cert.pfx'
            } } | Should -Throw
        }
    }

    # ── SPN + Secret ──────────────────────────────────────────────────
    Context 'SPN + Secret Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-456' } } }
            } -ModuleName AzureScout

            Mock Get-AzContext { return $null } -ModuleName AzureScout
        }

        It 'Calls Connect-AzAccount with credential when AppId and Secret are provided' {
            InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-456' -AppId 'app-id' -Secret 'my-secret'
            }
            Should -Invoke Connect-AzAccount -ModuleName AzureScout -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-456' -AppId 'app-id' -Secret 'my-secret'
            }
            $result | Should -Be 'tenant-456'
        }

        It 'Throws when TenantID is not provided for SPN secret auth' {
            { InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -AppId 'app-id' -Secret 'my-secret'
            } } | Should -Throw
        }
    }

    # ── Device Code ───────────────────────────────────────────────────
    Context 'Device Code Auth' {

        BeforeAll {
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-789' } } }
            } -ModuleName AzureScout

            Mock Get-AzContext { return $null } -ModuleName AzureScout
        }

        It 'Calls Connect-AzAccount with UseDeviceAuthentication when DeviceLogin switch is set' {
            InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-789' -DeviceLogin
            }
            Should -Invoke Connect-AzAccount -ModuleName AzureScout -Times 1
        }

        It 'Returns the TenantID on success' {
            $result = InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-789' -DeviceLogin
            }
            $result | Should -Be 'tenant-789'
        }
    }

    # ── Current User / Interactive ────────────────────────────────────
    Context 'Current User Auth' {

        It 'Reuses existing context when tenant matches' {
            Mock Get-AzContext {
                return [PSCustomObject]@{
                    Tenant  = [PSCustomObject]@{ Id = 'tenant-existing' }
                    Account = [PSCustomObject]@{ Id = 'user@example.com' }
                }
            } -ModuleName AzureScout

            Mock Connect-AzAccount { } -ModuleName AzureScout

            $result = InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-existing'
            }
            Should -Not -Invoke Connect-AzAccount -ModuleName AzureScout
            $result | Should -Be 'tenant-existing'
        }

        It 'Calls Connect-AzAccount when no existing context' {
            Mock Get-AzContext { return $null } -ModuleName AzureScout
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-new' } } }
            } -ModuleName AzureScout
            Mock Get-AzConfig { return [PSCustomObject]@{ Value = 'On' } } -ModuleName AzureScout
            Mock Update-AzConfig { } -ModuleName AzureScout

            $result = InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-new'
            }
            Should -Invoke Connect-AzAccount -ModuleName AzureScout -Times 1
        }
    }

    # ── LoginExperienceV2 Handling ────────────────────────────────────
    Context 'LoginExperienceV2 Handling' {

        BeforeAll {
            Mock Get-AzContext { return $null } -ModuleName AzureScout
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-v2' } } }
            } -ModuleName AzureScout
            Mock Get-AzConfig {
                return [PSCustomObject]@{ Value = 'On' }
            } -ModuleName AzureScout
            Mock Update-AzConfig { } -ModuleName AzureScout
        }

        It 'Checks LoginExperienceV2 config for interactive login' {
            InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-v2'
            }
            Should -Invoke Get-AzConfig -ModuleName AzureScout
        }
    }

    # ── AzureEnvironment Passthrough ──────────────────────────────────
    Context 'AzureEnvironment Passthrough' {

        BeforeAll {
            Mock Get-AzContext { return $null } -ModuleName AzureScout
            Mock Connect-AzAccount {
                return [PSCustomObject]@{ Context = [PSCustomObject]@{ Tenant = [PSCustomObject]@{ Id = 'tenant-gov' } } }
            } -ModuleName AzureScout
            Mock Get-AzConfig { return [PSCustomObject]@{ Value = 'Off' } } -ModuleName AzureScout
            Mock Update-AzConfig { } -ModuleName AzureScout
        }

        It 'Passes AzureEnvironment through to Connect-AzAccount' {
            InModuleScope 'AzureScout' {
                Connect-AZSCLoginSession -TenantID 'tenant-gov' -AzureEnvironment 'AzureUSGovernment'
            }
            Should -Invoke Connect-AzAccount -ModuleName AzureScout -ParameterFilter {
                $Environment -eq 'AzureUSGovernment'
            }
        }
    }
}
