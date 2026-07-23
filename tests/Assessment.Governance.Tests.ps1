#Requires -Version 7.0
#Requires -Modules Pester
#Requires -Modules Az.ResourceGraph

<#
    Pester tests for the native governance collector (src/ingest/Import-Governance.ps1,
    ADO AB#5041) — the replacement for the AzGovViz hard dependency.

    Two layers are covered:
      1. Import-Governance shapes collect.json's `governance` object from mocked
         Resource Graph (MGs / policy / role assignments) + mocked ARM REST
         (budgets / locks) — no AzGovViz, no live Azure.
      2. The REAL governance rule files + Compare-Benchmark score against that
         shape, proving the benchmark and CAF governance/identity/billing rules
         actually resolve (instead of degrading to Unknown) once native
         governance data is present.

    Search-AzGraph and Invoke-AzRestMethod are mocked throughout.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module Az.ResourceGraph -ErrorAction Stop
    Import-Module powershell-yaml -ErrorAction Stop
    . "$root/src/ingest/Import-Governance.ps1"
    . "$root/src/assess/Compare-Benchmark.ps1"
    . "$root/src/assess/Invoke-Assessment.ps1"
    . "$root/src/assess/engine/Get-RuleSet.ps1"
    . "$root/src/assess/engine/Resolve-JsonPath.ps1"
    . "$root/src/assess/engine/Invoke-Rule.ps1"

    # Stub Invoke-AzRestMethod so Import-Governance's Get-Command probe finds it
    # (skipping the Az.Accounts import) and Pester can mock it below.
    if (-not (Get-Command Invoke-AzRestMethod -ErrorAction SilentlyContinue)) {
        function Invoke-AzRestMethod { param([string] $Method, [string] $Path) }
    }

    # Deterministic synthetic governance dataset used across the collector +
    # rule-scoring tests. Six policy assignments (all Default enforcement, all
    # carrying parameters), two management groups, three User role assignments,
    # two budgets, one lock — chosen so each governance rule has a predictable outcome.
    function Get-MockCollect {
        [pscustomobject]@{
            subscriptions = @(
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000001'; name = 'sub-a' }
                [pscustomobject]@{ id = '00000000-0000-0000-0000-000000000002'; name = 'sub-b' }
            )
        }
    }

    $script:MockPolicy = 1..6 | ForEach-Object {
        [pscustomobject]@{
            name = "assignment-$_"; id = "/pa/$_"; type = 'microsoft.authorization/policyassignments'
            properties = [pscustomobject]@{
                displayName = "ALZ-Policy-$_"; enforcementMode = 'Default'
                parameters  = [pscustomobject]@{ effect = [pscustomobject]@{ value = 'DeployIfNotExists' } }
            }
        }
    }
    $script:MockMgs = @(
        [pscustomobject]@{ name = 'platform';     id = '/providers/Microsoft.Management/managementGroups/platform';     displayName = 'Platform';      parent = 'tenant-root' }
        [pscustomobject]@{ name = 'landingzones'; id = '/providers/Microsoft.Management/managementGroups/landingzones'; displayName = 'Landing Zones'; parent = 'tenant-root' }
    )
    $script:MockRoles = 1..3 | ForEach-Object {
        [pscustomobject]@{ name = "ra-$_"; id = "/ra/$_"; type = 'microsoft.authorization/roleassignments'
            properties = [pscustomobject]@{ principalType = 'User'; roleDefinitionId = '/rd/reader' } }
    }
}

Describe 'Import-Governance — native collector shape' {
    BeforeEach {
        Mock Search-AzGraph {
            if ($Query -match 'managementgroups')   { return $script:MockMgs }
            if ($Query -match 'policyassignments')  { return $script:MockPolicy }
            if ($Query -match 'roleassignments')    { return $script:MockRoles }
            return @()
        }
        Mock Invoke-AzRestMethod {
            if ($Path -match 'Microsoft\.Consumption/budgets') {
                return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'budget-a' }, @{ name = 'budget-b' }) } | ConvertTo-Json -Depth 5) }
            }
            if ($Path -match 'Microsoft\.Authorization/locks') {
                return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'lock-a'; properties = @{ level = 'CanNotDelete' } }) } | ConvertTo-Json -Depth 5) }
            }
            return [pscustomobject]@{ StatusCode = 404; Content = '{}' }
        }
    }

    It 'populates every governance dataset the rules query, with no AzGovViz call' {
        $result = Import-Governance -Collect (Get-MockCollect)

        @($result.governance.managementGroups).Count  | Should -Be 2
        @($result.governance.policyAssignments).Count | Should -Be 6
        @($result.governance.roleAssignments).Count   | Should -Be 3
        # budgets and locks aggregate across BOTH subscriptions (2 subs × 2 budgets,
        # 2 subs × 1 lock) — proves the per-subscription ARM REST fan-in.
        @($result.governance.budgets).Count           | Should -Be 4
        @($result.governance.resourceLocks).Count     | Should -Be 2
        @($result.governance.classicAdministrators).Count | Should -Be 0
        @($result.governance.pimEligibility).Count        | Should -Be 0
    }

    It 'scopes Resource Graph to the management group when one is supplied' {
        Import-Governance -Collect (Get-MockCollect) -ManagementGroupId 'contoso-root' | Out-Null
        Should -Invoke Search-AzGraph -ParameterFilter { $ManagementGroup -eq 'contoso-root' }
        Should -Invoke Search-AzGraph -ParameterFilter { $null -eq $ManagementGroup } -Times 0 -Exactly
    }

    It 'reads budgets and locks once per subscription via ARM REST' {
        Import-Governance -Collect (Get-MockCollect) | Out-Null
        Should -Invoke Invoke-AzRestMethod -ParameterFilter { $Path -match 'budgets' } -Times 2 -Exactly
        Should -Invoke Invoke-AzRestMethod -ParameterFilter { $Path -match 'locks' }   -Times 2 -Exactly
    }

    It 'never invokes the AzGovViz collector' {
        # Import-Governance must be fully self-contained — prove it does not shell out
        # to git (the AzGovViz clone) as a proxy for "no visualizer dependency".
        Mock git { throw 'git must not be called by the native collector' }
        { Import-Governance -Collect (Get-MockCollect) } | Should -Not -Throw
    }
}

Describe 'Governance rules score against native collect (unblocks AB#5041)' {
    BeforeEach {
        Mock Search-AzGraph {
            if ($Query -match 'managementgroups')   { return $script:MockMgs }
            if ($Query -match 'policyassignments')  { return $script:MockPolicy }
            if ($Query -match 'roleassignments')    { return $script:MockRoles }
            return @()
        }
        Mock Invoke-AzRestMethod {
            if ($Path -match 'budgets') { return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'b1' }, @{ name = 'b2' }) } | ConvertTo-Json) } }
            if ($Path -match 'locks')   { return [pscustomobject]@{ StatusCode = 200; Content = (@{ value = @(@{ name = 'l1' }) } | ConvertTo-Json) } }
            return [pscustomobject]@{ StatusCode = 404; Content = '{}' }
        }
    }

    It 'resolves CAF governance/identity/resource-org/billing rules to real Pass/Fail (not Unknown)' {
        $collect  = Import-Governance -Collect (Get-MockCollect)
        $ruleSet  = Get-RuleSet -Patterns @('caf.governance', 'caf.identity', 'caf.resourceorg', 'caf.billing')
        $findings = Invoke-Assessment -Collect $collect -RuleSet $ruleSet -Assessment 'GovTest'
        $byId     = @{}; $findings | ForEach-Object { $byId[$_.Id] = $_.Status }

        $byId['CAF-GOV-01'] | Should -Be 'Pass'   # policy assignments present
        $byId['CAF-GOV-02'] | Should -Be 'Pass'   # none DoNotEnforce
        $byId['CAF-GOV-03'] | Should -Be 'Pass'   # a resource lock exists
        $byId['CAF-GOV-04'] | Should -Be 'Pass'   # >5 assignments
        $byId['CAF-GOV-05'] | Should -Be 'Pass'   # assignments carry parameters
        $byId['CAF-RES-02'] | Should -Be 'Pass'   # >1 management group
        $byId['CAF-IDN-01'] | Should -Be 'Pass'   # <50 user role assignments
        $byId['CAF-IDN-03'] | Should -Be 'Pass'   # no classic admins
        $byId['CAF-BIL-01'] | Should -Be 'Pass'   # budgets present
        $byId['CAF-BIL-05'] | Should -Be 'Pass'   # >1 budget
    }

    It 'flags a DoNotEnforce policy assignment as Fail on CAF-GOV-02' {
        Mock Search-AzGraph {
            if ($Query -match 'managementgroups')  { return $script:MockMgs }
            if ($Query -match 'policyassignments') {
                return @([pscustomobject]@{ name = 'lax'; properties = [pscustomobject]@{ displayName = 'Lax'; enforcementMode = 'DoNotEnforce'; parameters = $null } })
            }
            if ($Query -match 'roleassignments')   { return $script:MockRoles }
            return @()
        }
        $collect  = Import-Governance -Collect (Get-MockCollect)
        $ruleSet  = Get-RuleSet -Patterns @('caf.governance')
        $findings = Invoke-Assessment -Collect $collect -RuleSet $ruleSet -Assessment 'GovTest'
        ($findings | Where-Object Id -eq 'CAF-GOV-02').Status | Should -Be 'Fail'
    }
}

Describe 'Compare-Benchmark with native governance data' {
    It 'emits real MG/policy Pass-Fail findings when management groups are present' {
        $collect = [pscustomobject]@{
            governance = [pscustomobject]@{
                managementGroups  = @([pscustomobject]@{ name = 'platform' }, [pscustomobject]@{ name = 'landingzones' })
                policyAssignments = @([pscustomobject]@{ properties = [pscustomobject]@{ displayName = 'Deny-Public-IP' } })
            }
        }
        $benchmark = Get-Content "$(Split-Path $PSScriptRoot -Parent)/src/assess/benchmarks/alz-reference.json" -Raw | ConvertFrom-Json
        $findings  = Compare-Benchmark -Collect $collect -Benchmark $benchmark

        ($findings | Where-Object Id -eq 'BENCH-GOV-DATA') | Should -BeNullOrEmpty
        ($findings | Where-Object Id -eq 'BENCH-MG-platform').Status | Should -Be 'Pass'
        ($findings | Where-Object Id -eq 'BENCH-POL-Deny-Public-IP').Status | Should -Be 'Pass'
    }

    It 'returns the explicit Unknown guard when governance data is absent' {
        $collect   = [pscustomobject]@{ governance = [pscustomobject]@{ managementGroups = @() } }
        $benchmark = Get-Content "$(Split-Path $PSScriptRoot -Parent)/src/assess/benchmarks/alz-reference.json" -Raw | ConvertFrom-Json
        $findings  = Compare-Benchmark -Collect $collect -Benchmark $benchmark

        @($findings).Count | Should -Be 1
        $findings[0].Id     | Should -Be 'BENCH-GOV-DATA'
        $findings[0].Status | Should -Be 'Unknown'
    }
}
