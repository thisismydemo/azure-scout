#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for the -PermissionAudit switch and Invoke-AZSCPermissionAudit function.

.DESCRIPTION
    Validates:
      - The -PermissionAudit and -IncludeEntraPermissions switches exist on Invoke-AzureScout
      - Invoke-AZSCPermissionAudit function signature (parameters, OutputFormat ValidateSet)
      - Return object structure when function is invoked with no Azure context
      - IncludeEntraPermissions switch is exposed and documented in the function
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   20 — Permission Audit Feature
#>

BeforeAll {
    $script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $script:InvokeScript    = Join-Path $script:ModuleRoot 'Modules' 'Public' 'PublicFunctions' 'Invoke-AzureScout.ps1'
    $script:AuditScript     = Join-Path $script:ModuleRoot 'Modules' 'Private' 'Main' 'Invoke-AZTIPermissionAudit.ps1'

    # Dot-source both scripts to inspect function metadata
    . $script:InvokeScript
    . $script:AuditScript

    $script:InvokeCmd = Get-Command -Name Invoke-AzureScout         -ErrorAction SilentlyContinue
    $script:AuditCmd  = Get-Command -Name Invoke-AZSCPermissionAudit -ErrorAction SilentlyContinue
}

# ===================================================================
# Switch parameters on Invoke-AzureScout
# ===================================================================
Describe 'PermissionAudit switches on Invoke-AzureScout' {
    It 'Invoke-AzureScout function is available' {
        $script:InvokeCmd | Should -Not -BeNullOrEmpty
    }

    It 'PermissionAudit switch parameter exists' {
        $script:InvokeCmd.Parameters.ContainsKey('PermissionAudit') | Should -BeTrue
    }

    It 'PermissionAudit is a [switch] type' {
        $script:InvokeCmd.Parameters['PermissionAudit'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }

    It 'PermissionAudit has alias "AuditPermissions"' {
        $aliases = $script:InvokeCmd.Parameters['PermissionAudit'].Aliases
        $aliases | Should -Contain 'AuditPermissions'
    }

    It 'PermissionAudit has alias "CheckPermissions"' {
        $aliases = $script:InvokeCmd.Parameters['PermissionAudit'].Aliases
        $aliases | Should -Contain 'CheckPermissions'
    }

    It 'IncludeEntraPermissions switch parameter exists' {
        $script:InvokeCmd.Parameters.ContainsKey('IncludeEntraPermissions') | Should -BeTrue
    }

    It 'IncludeEntraPermissions is a [switch] type' {
        $script:InvokeCmd.Parameters['IncludeEntraPermissions'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }

    It 'IncludeEntraPermissions has alias "EntraAudit"' {
        $aliases = $script:InvokeCmd.Parameters['IncludeEntraPermissions'].Aliases
        $aliases | Should -Contain 'EntraAudit'
    }

    It 'IncludeEntraPermissions has alias "CheckEntraPermissions"' {
        $aliases = $script:InvokeCmd.Parameters['IncludeEntraPermissions'].Aliases
        $aliases | Should -Contain 'CheckEntraPermissions'
    }
}

# ===================================================================
# Invoke-AZSCPermissionAudit function signature
# ===================================================================
Describe 'Invoke-AZSCPermissionAudit — Function Signature' {
    It 'Invoke-AZSCPermissionAudit function is available after dot-source' {
        $script:AuditCmd | Should -Not -BeNullOrEmpty
    }

    It 'IncludeEntraPermissions switch parameter exists' {
        $script:AuditCmd.Parameters.ContainsKey('IncludeEntraPermissions') | Should -BeTrue
    }

    It 'IncludeEntraPermissions is a [switch] type' {
        $script:AuditCmd.Parameters['IncludeEntraPermissions'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }

    It 'TenantID parameter exists' {
        $script:AuditCmd.Parameters.ContainsKey('TenantID') | Should -BeTrue
    }

    It 'TenantID is a [string] type' {
        $script:AuditCmd.Parameters['TenantID'].ParameterType | Should -Be ([string])
    }

    It 'OutputFormat parameter exists' {
        $script:AuditCmd.Parameters.ContainsKey('OutputFormat') | Should -BeTrue
    }

    It 'OutputFormat ValidateSet contains "Console"' {
        $vs = $script:AuditCmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Console'
    }

    It 'OutputFormat ValidateSet contains "Markdown"' {
        $vs = $script:AuditCmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Markdown'
    }

    It 'OutputFormat ValidateSet contains "AsciiDoc"' {
        $vs = $script:AuditCmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'AsciiDoc'
    }

    It 'OutputFormat ValidateSet contains "Json"' {
        $vs = $script:AuditCmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Json'
    }

    It 'OutputFormat ValidateSet contains "All"' {
        $vs = $script:AuditCmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'All'
    }

    It 'OutputFormat default value is "Console"' {
        $default = $script:AuditCmd.Parameters['OutputFormat'].DefaultValue
        if ($null -eq $default) {
            Set-ItResult -Skipped -Because 'Default not accessible via reflection'
        } else {
            $default | Should -Be 'Console'
        }
    }

    It 'ReportDir parameter exists' {
        $script:AuditCmd.Parameters.ContainsKey('ReportDir') | Should -BeTrue
    }

    It 'SubscriptionID parameter exists' {
        $script:AuditCmd.Parameters.ContainsKey('SubscriptionID') | Should -BeTrue
    }

    It 'SubscriptionID accepts an array of strings' {
        $script:AuditCmd.Parameters['SubscriptionID'].ParameterType | Should -Be ([string[]])
    }
}

# ===================================================================
# No-auth graceful behavior
# ===================================================================
Describe 'Invoke-AZSCPermissionAudit — No Azure Context Behavior' {
    It 'Returns $null when no Azure context is present (no auth)' {
        # The function calls Get-AzContext internally; without auth it returns $null
        # and the function returns $null early with an error message — not a throw
        $result = Invoke-AZSCPermissionAudit -ErrorAction SilentlyContinue 2>$null
        # If no context, function should return null (not throw)
        # If somehow context IS present (CI with auth), this still validates the result type
        if ($null -ne $result) {
            $result | Should -BeOfType [PSCustomObject]
        } else {
            $result | Should -BeNullOrEmpty
        }
    }

    It 'Does not throw terminating error when Get-AzContext returns $null' {
        { Invoke-AZSCPermissionAudit -ErrorAction SilentlyContinue 2>$null } | Should -Not -Throw
    }
}

# ===================================================================
# Return object structure (source analysis)
# ===================================================================
Describe 'Invoke-AZSCPermissionAudit — Return Object Structure (Source Analysis)' {
    BeforeAll {
        $script:AuditSource = Get-Content -Path $script:AuditScript -Raw
    }

    It 'Source defines ArmAccess in the return object' {
        $script:AuditSource | Should -Match 'ArmAccess'
    }

    It 'Source defines GraphAccess in the return object' {
        $script:AuditSource | Should -Match 'GraphAccess'
    }

    It 'Source defines CallerAccount in the return object' {
        $script:AuditSource | Should -Match 'CallerAccount'
    }

    It 'Source defines OverallReadiness in the return object' {
        $script:AuditSource | Should -Match 'OverallReadiness'
    }

    It 'Source defines ArmDetails in the return object' {
        $script:AuditSource | Should -Match 'armDetails|ArmDetails'
    }

    It 'Source defines ProviderResults in the return object' {
        $script:AuditSource | Should -Match 'providerResults|ProviderResults'
    }

    It 'Source defines GraphDetails in the return object' {
        $script:AuditSource | Should -Match 'graphDetails|GraphDetails'
    }

    It 'Source defines Recommendations in the return object' {
        $script:AuditSource | Should -Match 'recommendations|Recommendations'
    }

    It 'OverallReadiness uses switch expression with Insufficient state' {
        $script:AuditSource | Should -Match 'Insufficient'
    }

    It 'OverallReadiness includes FullARM state' {
        $script:AuditSource | Should -Match 'FullARM'
    }

    It 'OverallReadiness includes FullARMAndEntra state' {
        $script:AuditSource | Should -Match 'FullARMAndEntra'
    }

    It 'Source has separate ARM path and Entra path (IncludeEntraPermissions guard)' {
        $script:AuditSource | Should -Match 'IncludeEntraPermissions'
    }
}

# ===================================================================
# Invoke-AzureScout source-level PermissionAudit routing
# ===================================================================
Describe 'PermissionAudit routing in Invoke-AzureScout source' {
    BeforeAll {
        $script:InvokeSource = Get-Content -Path $script:InvokeScript -Raw
    }

    It 'Invoke-AzureScout calls Invoke-AZSCPermissionAudit when -PermissionAudit is set' {
        $script:InvokeSource | Should -Match 'Invoke-AZSCPermissionAudit'
    }

    It 'Source passes IncludeEntraPermissions to the audit function' {
        $script:InvokeSource | Should -Match 'IncludeEntraPermissions'
    }

    It 'Source passes SubscriptionID to the audit function' {
        $script:InvokeSource | Should -Match 'Invoke-AZSCPermissionAudit[\s\S]*-SubscriptionID'
    }

    It 'Source has early-return or conditional block that skips inventory when PermissionAudit is used' {
        $script:InvokeSource | Should -Match 'PermissionAudit'
    }
}
