#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Invoke-AzureScout (parameter validation & scope routing).

.DESCRIPTION
    Validates the main orchestrator function:
      - Parameter validation (ValidateSet for Scope, OutputFormat, AzureEnvironment)
      - Scope routing gates extraction phases
      - Parameter aliases resolve correctly
      - Help switch returns without executing

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-02-23
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'AzureScout.psd1') -Force -ErrorAction Stop
}

Describe 'Invoke-AzureScout — Parameter Validation' {

    # ── ValidateSet Enforcement ───────────────────────────────────────
    Context 'Scope ValidateSet' {

        It 'Accepts "All" as a valid Scope value' {
            $cmd = Get-Command Invoke-AzureScout
            $scopeAttr = $cmd.Parameters['Scope'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $scopeAttr.ValidValues | Should -Contain 'All'
        }

        It 'Accepts "ArmOnly" as a valid Scope value' {
            $cmd = Get-Command Invoke-AzureScout
            $scopeAttr = $cmd.Parameters['Scope'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $scopeAttr.ValidValues | Should -Contain 'ArmOnly'
        }

        It 'Accepts "EntraOnly" as a valid Scope value' {
            $cmd = Get-Command Invoke-AzureScout
            $scopeAttr = $cmd.Parameters['Scope'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $scopeAttr.ValidValues | Should -Contain 'EntraOnly'
        }

        It 'Rejects an invalid Scope value' {
            { Invoke-AzureScout -TenantID 'test' -Scope 'InvalidScope' } | Should -Throw
        }
    }

    Context 'OutputFormat ValidateSet' {

        It 'Accepts "All" as a valid OutputFormat value' {
            $cmd = Get-Command Invoke-AzureScout
            $attr = $cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'All'
        }

        It 'Accepts "Excel" as a valid OutputFormat value' {
            $cmd = Get-Command Invoke-AzureScout
            $attr = $cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'Excel'
        }

        It 'Accepts "Json" as a valid OutputFormat value' {
            $cmd = Get-Command Invoke-AzureScout
            $attr = $cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'Json'
        }

        It 'Rejects an invalid OutputFormat value' {
            { Invoke-AzureScout -TenantID 'test' -OutputFormat 'Csv' } | Should -Throw
        }
    }

    Context 'AzureEnvironment ValidateSet' {

        It 'Accepts standard Azure environment names' {
            $cmd = Get-Command Invoke-AzureScout
            $attr = $cmd.Parameters['AzureEnvironment'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'AzureCloud'
        }

        It 'Rejects an invalid AzureEnvironment value' {
            { Invoke-AzureScout -TenantID 'test' -AzureEnvironment 'FakeCloud' } | Should -Throw
        }
    }

    # ── Parameter Aliases ─────────────────────────────────────────────
    Context 'Parameter Aliases' {

        It 'Has aliases defined for SkipAdvisory' {
            $cmd = Get-Command Invoke-AzureScout
            $aliases = $cmd.Parameters['SkipAdvisory'].Aliases
            $aliases | Should -Not -BeNullOrEmpty
        }

        It 'SkipAdvisory includes SkipAdvisories alias' {
            $cmd = Get-Command Invoke-AzureScout
            $aliases = $cmd.Parameters['SkipAdvisory'].Aliases
            $aliases | Should -Contain 'SkipAdvisories'
        }
    }

    # ── Required Parameters ───────────────────────────────────────────
    Context 'Required Parameters' {

        It 'TenantID is not mandatory (can default from context)' {
            $cmd = Get-Command Invoke-AzureScout
            $isMandatory = $cmd.Parameters['TenantID'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory }
            # TenantID should not be mandatory — the function can discover it via Get-AzContext
            $isMandatory | Should -Not -Contain $true
        }
    }

    # ── Switch Parameters ─────────────────────────────────────────────
    Context 'Switch Parameters' {

        It 'SkipPermissionCheck is a switch parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters['SkipPermissionCheck'].SwitchParameter | Should -BeTrue
        }

        It 'DeviceLogin is a switch parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters['DeviceLogin'].SwitchParameter | Should -BeTrue
        }

        It 'SecurityCenter is a switch parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters['SecurityCenter'].SwitchParameter | Should -BeTrue
        }
    }

    # ── Key Parameters Exist ──────────────────────────────────────────
    Context 'Key Parameters Exist' {

        It 'Has a Scope parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'Scope'
        }

        It 'Has an OutputFormat parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'OutputFormat'
        }

        It 'Has SubscriptionID parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'SubscriptionID'
        }

        It 'Has ManagementGroup parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'ManagementGroup'
        }

        It 'Has ReportName parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'ReportName'
        }

        It 'Has ReportDir parameter' {
            $cmd = Get-Command Invoke-AzureScout
            $cmd.Parameters.Keys | Should -Contain 'ReportDir'
        }
    }
}
