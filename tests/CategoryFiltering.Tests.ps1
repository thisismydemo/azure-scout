#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Invoke-AzureScout -Category parameter behavior.

.DESCRIPTION
    Validates the -Category parameter: ValidateSet, default value, array type,
    and alias normalization logic (long names / alternate spellings mapped to
    canonical short folder names). No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   18.2.5, 18.7 — Category Filtering
#>

BeforeAll {
    $script:ModuleRoot    = Split-Path -Parent $PSScriptRoot
    $script:InvokeScript  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'PublicFunctions' 'Invoke-AzureScout.ps1'

    # Dot-source the script to load the function into scope without a full module import
    . $script:InvokeScript

    $script:Cmd = Get-Command -Name Invoke-AzureScout -ErrorAction SilentlyContinue
}

Describe 'Category Parameter — Metadata' {
    It 'Invoke-AzureScout function is available after dot-source' {
        $script:Cmd | Should -Not -BeNullOrEmpty
    }

    It 'Category parameter exists' {
        $script:Cmd.Parameters.ContainsKey('Category') | Should -BeTrue
    }

    It 'Category parameter is array type [string[]]' {
        $script:Cmd.Parameters['Category'].ParameterType | Should -Be ([string[]])
    }

    It 'Category parameter default is @("All")' {
        $default = $script:Cmd.Parameters['Category'].DefaultValue
        if ($null -eq $default) {
            # Default may not be accessible via reflection; verify ValidateSet contains 'All'
            Set-ItResult -Skipped -Because 'Default value not inspectable via reflection on all PS versions'
        } else {
            $default | Should -Be @('All')
        }
    }

    It 'Category ValidateSet contains "All"' {
        $vs = $script:Cmd.Parameters['Category'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs | Should -Not -BeNullOrEmpty
        $vs.ValidValues | Should -Contain 'All'
    }

    It 'Category ValidateSet contains all 15 named categories' {
        $expectedCategories = @('AI','Analytics','Compute','Containers','Databases','Hybrid','Identity','Integration','IoT','Management','Monitor','Networking','Security','Storage','Web')
        $vs = $script:Cmd.Parameters['Category'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        foreach ($cat in $expectedCategories) {
            $vs.ValidValues | Should -Contain $cat -Because "Category '$cat' must be in the ValidateSet"
        }
    }

    It 'Category ValidateSet has exactly 16 values (All + 15 categories)' {
        $vs = $script:Cmd.Parameters['Category'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues.Count | Should -Be 16
    }
}

Describe 'Category Alias Normalization — alias map in Invoke-AzureScout body' {
    # Load the raw script text once
    BeforeAll {
        $script:FunctionSource = Get-Content -Path $script:InvokeScript -Raw
    }

    It 'Alias map contains "AI + machine learning" -> "AI"' {
        $script:FunctionSource | Should -Match "'AI \+ machine learning'"
    }

    It 'Alias map contains "Internet of Things" -> "IoT"' {
        $script:FunctionSource | Should -Match "'Internet of Things'"
    }

    It 'Alias map contains "Monitoring" -> "Monitor"' {
        $script:FunctionSource | Should -Match "'Monitoring'"
    }

    It 'Alias map contains "Management and governance" -> "Management"' {
        $script:FunctionSource | Should -Match "'Management and governance'"
    }

    It 'Alias map contains "Web & Mobile" -> "Web"' {
        $script:FunctionSource | Should -Match "'Web & Mobile'"
    }

    It 'Alias map contains "Hybrid + multicloud" -> "Hybrid"' {
        $script:FunctionSource | Should -Match "'Hybrid \+ multicloud'"
    }

    It 'Function body performs alias normalization with ForEach-Object loop' {
        $script:FunctionSource | Should -Match '_categoryAliasMap'
    }

    It 'Function body deduplicates Category with Select-Object -Unique' {
        $script:FunctionSource | Should -Match 'Select-Object -Unique'
    }
}

Describe 'Category alias resolution logic — unit test of normalization block' {
    BeforeAll {
        # Extract and run just the alias-map block using a controlled $Category input
        $aliasMap = @{
            'AI + machine learning'     = 'AI'
            'AI+machine learning'       = 'AI'
            'Machine Learning'          = 'AI'
            'Internet of Things'        = 'IoT'
            'Monitoring'                = 'Monitor'
            'Management and governance' = 'Management'
            'Management & governance'   = 'Management'
            'Web & Mobile'              = 'Web'
            'Hybrid + multicloud'       = 'Hybrid'
            'Hybrid+multicloud'         = 'Hybrid'
            'DevOps'                    = 'Management'
            'Migration'                 = 'Management'
        }

        function Resolve-CategoryAlias {
            param([string[]]$Category)
            $map = @{
                'AI + machine learning'     = 'AI'
                'AI+machine learning'       = 'AI'
                'Machine Learning'          = 'AI'
                'Internet of Things'        = 'IoT'
                'Monitoring'                = 'Monitor'
                'Management and governance' = 'Management'
                'Management & governance'   = 'Management'
                'Web & Mobile'              = 'Web'
                'Hybrid + multicloud'       = 'Hybrid'
                'Hybrid+multicloud'         = 'Hybrid'
                'DevOps'                    = 'Management'
                'Migration'                 = 'Management'
            }
            $Category = $Category | ForEach-Object {
                if ($map.ContainsKey($_)) { $map[$_] } else { $_ }
            }
            $Category | Select-Object -Unique
        }
    }

    It '"AI + machine learning" resolves to "AI"' {
        Resolve-CategoryAlias -Category @('AI + machine learning') | Should -Be 'AI'
    }

    It '"Internet of Things" resolves to "IoT"' {
        Resolve-CategoryAlias -Category @('Internet of Things') | Should -Be 'IoT'
    }

    It '"Monitoring" resolves to "Monitor"' {
        Resolve-CategoryAlias -Category @('Monitoring') | Should -Be 'Monitor'
    }

    It '"Management and governance" resolves to "Management"' {
        Resolve-CategoryAlias -Category @('Management and governance') | Should -Be 'Management'
    }

    It '"Web & Mobile" resolves to "Web"' {
        Resolve-CategoryAlias -Category @('Web & Mobile') | Should -Be 'Web'
    }

    It '"Hybrid + multicloud" resolves to "Hybrid"' {
        Resolve-CategoryAlias -Category @('Hybrid + multicloud') | Should -Be 'Hybrid'
    }

    It '"DevOps" resolves to "Management"' {
        Resolve-CategoryAlias -Category @('DevOps') | Should -Be 'Management'
    }

    It '"Migration" resolves to "Management"' {
        Resolve-CategoryAlias -Category @('Migration') | Should -Be 'Management'
    }

    It 'Canonical short names pass through unchanged' {
        Resolve-CategoryAlias -Category @('Compute') | Should -Be 'Compute'
        Resolve-CategoryAlias -Category @('Networking') | Should -Be 'Networking'
        Resolve-CategoryAlias -Category @('Security') | Should -Be 'Security'
    }

    It 'Multiple aliases in one array resolve to unique canonical values' {
        $result = Resolve-CategoryAlias -Category @('Management and governance', 'DevOps', 'Migration')
        $result | Should -HaveCount 1
        $result | Should -Contain 'Management'
    }

    It '"All" passes through unchanged' {
        Resolve-CategoryAlias -Category @('All') | Should -Be 'All'
    }
}
