#Requires -Version 7.0
#Requires -Modules Pester

<#
    Pester tests for the PowerShell-native assessment config load/save/fallback
    layer (src/assess/Import-ScoutConfig.ps1, src/assess/Export-ScoutConfig.ps1),
    plus the Get-RuleSet -Overrides threshold-override hook they feed.

    Tracks ADO Stories AB#373 (load), AB#374 (save), AB#375 (hardcoded fallback).
    Pure-logic tests -- no Azure connection, no live rule-file mutation (Get-RuleSet
    reads YAML fresh on every call, so overrides never leak between tests).
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . "$root/src/assess/Import-ScoutConfig.ps1"
    . "$root/src/assess/Export-ScoutConfig.ps1"
    . "$root/src/assess/Compare-Benchmark.ps1"
    . "$root/src/assess/engine/Get-RuleSet.ps1"

    $script:defaultBenchmarkPath = "$root/src/assess/benchmarks/alz-reference.json"
}

Describe 'Import-ScoutConfig' {

    It 'falls back to the built-in default benchmark when -ConfigPath is omitted' {
        $cfg = Import-ScoutConfig
        $cfg.Source | Should -Be 'Default'
        $cfg.ConfigPath | Should -BeNullOrEmpty
        $cfg.RulePatterns | Should -BeNullOrEmpty
        $cfg.RuleOverrides.Count | Should -Be 0
        $cfg.Benchmark.managementGroups.expected | Should -Contain 'platform'
    }

    It 'loads a valid config file and surfaces benchmark, rulePatterns, and ruleOverrides' {
        $path = Join-Path $TestDrive 'valid-config.json'
        @{
            benchmark = @{
                managementGroups          = @{ expected = @('platform', 'sandbox') }
                requiredPolicyAssignments = @('Deny-Public-IP')
                network                   = @{ requireHubSpoke = $true }
            }
            rulePatterns  = @('waf.security', 'caf.governance')
            ruleOverrides = @{ 'WAF-SE-02' = 3 }
        } | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $path -Encoding utf8

        $cfg = Import-ScoutConfig -ConfigPath $path

        $cfg.Source | Should -Be 'File'
        $cfg.ConfigPath | Should -Be (Resolve-Path $path).ProviderPath
        $cfg.Benchmark.managementGroups.expected | Should -Be @('platform', 'sandbox')
        $cfg.RulePatterns | Should -Be @('waf.security', 'caf.governance')
        $cfg.RuleOverrides['WAF-SE-02'] | Should -Be 3
    }

    It 'applies a loaded config end to end: rulePatterns select the rule set, ruleOverrides patch a threshold, and benchmark drives Compare-Benchmark' {
        $path = Join-Path $TestDrive 'applied-config.json'
        @{
            benchmark = @{
                managementGroups          = @{ expected = @('only-this-mg') }
                requiredPolicyAssignments = @('Only-This-Policy')
                network                   = @{}
            }
            rulePatterns  = @('waf.security')
            ruleOverrides = @{ 'WAF-SE-02' = 1 }   # default is countLessThan 5
        } | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $path -Encoding utf8

        $cfg = Import-ScoutConfig -ConfigPath $path

        # rulePatterns actually selects only the waf.security rule file.
        $ruleSet = Get-RuleSet -Patterns $cfg.RulePatterns -Overrides $cfg.RuleOverrides
        $ruleSet.Area | Should -Be 'Security'
        $ruleSet.Rules.Count | Should -BeGreaterThan 0

        # ruleOverrides patched WAF-SE-02's assert.value from 5 to 1.
        $rule = $ruleSet.Rules | Where-Object { $_.id -eq 'WAF-SE-02' }
        $rule.assert.value | Should -Be 1
        # an id absent from the override map is untouched.
        $untouched = $ruleSet.Rules | Where-Object { $_.id -eq 'WAF-SE-01' }
        $untouched.assert.value | Should -Be 0

        # benchmark drives Compare-Benchmark exactly as the built-in default would.
        $collect = [pscustomobject]@{
            governance = [pscustomobject]@{
                managementGroups   = @([pscustomobject]@{ name = 'only-this-mg' })
                policyAssignments  = @([pscustomobject]@{ properties = [pscustomobject]@{ displayName = 'Only-This-Policy' } })
            }
        }
        $findings = Compare-Benchmark -Collect $collect -Benchmark $cfg.Benchmark
        ($findings | Where-Object Id -eq 'BENCH-MG-only-this-mg').Status | Should -Be 'Pass'
        ($findings | Where-Object Id -eq 'BENCH-POL-Only-This-Policy').Status | Should -Be 'Pass'
    }

    It 'falls back to the built-in default (with a warning, no throw) when -ConfigPath does not exist' {
        $missing = Join-Path $TestDrive 'does-not-exist.json'
        { Import-ScoutConfig -ConfigPath $missing -WarningAction SilentlyContinue } | Should -Not -Throw

        $warnings = @()
        $cfg = Import-ScoutConfig -ConfigPath $missing -WarningAction SilentlyContinue -WarningVariable +warnings
        $cfg.Source | Should -Be 'Default'
        $cfg.Benchmark.managementGroups.expected | Should -Contain 'platform'
        $warnings.Count | Should -BeGreaterThan 0
    }

    It 'falls back to the built-in default (with a warning, no throw) when the config file is corrupt JSON' {
        $path = Join-Path $TestDrive 'corrupt.json'
        '{ this is not valid json,,, ' | Out-File -LiteralPath $path -Encoding utf8

        { Import-ScoutConfig -ConfigPath $path -WarningAction SilentlyContinue } | Should -Not -Throw

        $warnings = @()
        $cfg = Import-ScoutConfig -ConfigPath $path -WarningAction SilentlyContinue -WarningVariable +warnings
        $cfg.Source | Should -Be 'Default'
        $cfg.Benchmark.requiredPolicyAssignments | Should -Contain 'Deny-Public-IP'
        $warnings.Count | Should -BeGreaterThan 0
    }

    It 'falls back to the built-in default (with a warning, no throw) when the JSON parses but is not an object (e.g. a bare array)' {
        $path = Join-Path $TestDrive 'not-an-object.json'
        '[1, 2, 3]' | Out-File -LiteralPath $path -Encoding utf8

        { Import-ScoutConfig -ConfigPath $path -WarningAction SilentlyContinue } | Should -Not -Throw

        $warnings = @()
        $cfg = Import-ScoutConfig -ConfigPath $path -WarningAction SilentlyContinue -WarningVariable +warnings
        $cfg.Source | Should -Be 'Default'
        $warnings.Count | Should -BeGreaterThan 0
    }
}

Describe 'Export-ScoutConfig' {

    It 'writes the schema Import-ScoutConfig reads, round-tripping load -> save -> load to an equal config' {
        $srcPath = Join-Path $TestDrive 'roundtrip-source.json'
        @{
            benchmark = @{
                managementGroups          = @{ expected = @('platform', 'connectivity') }
                requiredPolicyAssignments = @('Deny-Public-IP', 'Deploy-VM-Backup')
                network                   = @{ requireHubSpoke = $true; requireFirewallInHub = $false }
            }
            rulePatterns  = @('waf.*', 'caf.security')
            ruleOverrides = @{ 'WAF-SE-02' = 3; 'WAF-SE-04' = @{ value = 1 } }
        } | ConvertTo-Json -Depth 10 | Out-File -LiteralPath $srcPath -Encoding utf8

        $loaded1     = Import-ScoutConfig -ConfigPath $srcPath
        $exportPath  = Join-Path $TestDrive 'roundtrip-export.json'
        $written     = Export-ScoutConfig -Path $exportPath -Config $loaded1
        $written | Should -Be (Resolve-Path $exportPath).ProviderPath

        $loaded2 = Import-ScoutConfig -ConfigPath $exportPath

        ($loaded2.Benchmark | ConvertTo-Json -Depth 10 -Compress) |
            Should -Be ($loaded1.Benchmark | ConvertTo-Json -Depth 10 -Compress)
        $loaded2.RulePatterns | Should -Be $loaded1.RulePatterns
        $loaded2.RuleOverrides.Count | Should -Be $loaded1.RuleOverrides.Count
        $loaded2.RuleOverrides['WAF-SE-02'] | Should -Be $loaded1.RuleOverrides['WAF-SE-02']
        $loaded2.RuleOverrides['WAF-SE-04'].value | Should -Be $loaded1.RuleOverrides['WAF-SE-04'].value
    }

    It 'accepts the Parts parameter set (Benchmark/RulePatterns/RuleOverrides) built from scratch' {
        $exportPath = Join-Path $TestDrive 'parts-export.json'
        $bench = @{ managementGroups = @{ expected = @('platform') }; requiredPolicyAssignments = @(); network = @{} }

        Export-ScoutConfig -Path $exportPath -Benchmark $bench -RulePatterns @('caf.security') -RuleOverrides @{ 'X-1' = 2 } | Out-Null

        $reloaded = Import-ScoutConfig -ConfigPath $exportPath
        $reloaded.RulePatterns | Should -Be @('caf.security')
        $reloaded.RuleOverrides['X-1'] | Should -Be 2
        $reloaded.Benchmark.managementGroups.expected | Should -Be @('platform')
    }

    It 'does not overwrite an existing file without -Force' {
        $path = Join-Path $TestDrive 'no-clobber.json'
        Export-ScoutConfig -Path $path -Benchmark @{ managementGroups = @{ expected = @('a') } } -RulePatterns @() -RuleOverrides @{} | Out-Null

        { Export-ScoutConfig -Path $path -Benchmark @{ managementGroups = @{ expected = @('b') } } -RulePatterns @() -RuleOverrides @{} -WarningAction SilentlyContinue } | Should -Not -Throw
        $result = Export-ScoutConfig -Path $path -Benchmark @{ managementGroups = @{ expected = @('b') } } -RulePatterns @() -RuleOverrides @{} -WarningAction SilentlyContinue
        $result | Should -BeNullOrEmpty

        (Import-ScoutConfig -ConfigPath $path).Benchmark.managementGroups.expected | Should -Be @('a')
    }

    It 'overwrites an existing file with -Force' {
        $path = Join-Path $TestDrive 'clobber.json'
        Export-ScoutConfig -Path $path -Benchmark @{ managementGroups = @{ expected = @('a') } } -RulePatterns @() -RuleOverrides @{} | Out-Null
        Export-ScoutConfig -Path $path -Benchmark @{ managementGroups = @{ expected = @('b') } } -RulePatterns @() -RuleOverrides @{} -Force | Out-Null

        (Import-ScoutConfig -ConfigPath $path).Benchmark.managementGroups.expected | Should -Be @('b')
    }
}

Describe 'Get-RuleSet -Overrides' {
    It 'is a no-op when -Overrides is $null or empty' {
        $withNull  = Get-RuleSet -Patterns @('waf.security') -Overrides $null
        $withEmpty = Get-RuleSet -Patterns @('waf.security') -Overrides @{}
        $plain     = Get-RuleSet -Patterns @('waf.security')

        ($withNull.Rules | Where-Object id -eq 'WAF-SE-02').assert.value | Should -Be 5
        ($withEmpty.Rules | Where-Object id -eq 'WAF-SE-02').assert.value | Should -Be 5
        ($plain.Rules | Where-Object id -eq 'WAF-SE-02').assert.value | Should -Be 5
    }

    It 'supports overriding both assert.value and assert.type via an object override' {
        $ruleSet = Get-RuleSet -Patterns @('waf.security') -Overrides @{ 'WAF-SE-02' = @{ value = 2; type = 'countLessThan' } }
        $rule = $ruleSet.Rules | Where-Object id -eq 'WAF-SE-02'
        $rule.assert.value | Should -Be 2
        $rule.assert.type | Should -Be 'countLessThan'
    }

    It 'leaves manual rules (no assert) untouched even if named in -Overrides' {
        $ruleSet = Get-RuleSet -Patterns @('waf.security') -Overrides @{ 'WAF-SE-05' = 99 }
        $rule = $ruleSet.Rules | Where-Object id -eq 'WAF-SE-05'
        $rule.assert.type | Should -Be 'manual'
    }
}
