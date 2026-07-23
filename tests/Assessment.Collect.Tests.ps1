#Requires -Version 7.0
#Requires -Modules Pester
#Requires -Modules Az.ResourceGraph

<#
    Pester tests for src/collect/Invoke-Collect.ps1's parameter wiring:
      - `-Categories` actually filters which Resource Graph queries run
        (rather than the pre-fix behavior of always running the full ~25-query
        set regardless of the value passed).
      - `-ManagementGroupId`, when supplied, is threaded through to every
        `Search-AzGraph` call as `-ManagementGroup`; omitted entirely when not
        supplied (preserves tenant-wide behavior).

    Search-AzGraph is mocked throughout — no live Azure connection is made.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module Az.ResourceGraph -ErrorAction Stop
    . "$root/src/collect/Invoke-Collect.ps1"
}

Describe 'Invoke-Collect -Categories query filtering' {
    BeforeEach {
        Mock Search-AzGraph { return @() }
    }

    It 'a specific category (Security) runs the queries it and its cross-domain rules need, and skips unrelated-domain queries' {
        Invoke-Collect -Categories @('Security') | Out-Null

        # In-scope for Security: its own domain (keyVaults) plus the networking/
        # databases queries caf.security / waf.security filter by (nsgPublicInbound,
        # privateEndpoints, privateDnsZones, sqlServers) — see Invoke-Collect.ps1's
        # $queryCategories map.
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.keyvault/vaults' } -Times 1
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.network/networksecuritygroups' } -Times 1
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.sql/servers"' } -Times 1

        # Out-of-scope for Security: Web/Containers/Analytics/AI/Hybrid/Integration/
        # IoT-only domain queries should NOT run.
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.web/sites' } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.containerservice/managedclusters' } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.synapse/workspaces' } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.devices/iothubs' } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.hybridcompute/machines"' } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.eventhub/namespaces' } -Times 0 -Exactly
    }

    It 'the Security run collects meaningfully fewer resource types than the full/default run' {
        $script:callCount = 0
        Mock Search-AzGraph { $script:callCount++; return @() }
        Invoke-Collect -Categories @('Security') | Out-Null
        $securityCalls = $script:callCount

        $script:callCount = 0
        Mock Search-AzGraph { $script:callCount++; return @() }
        Invoke-Collect | Out-Null
        $fullCalls = $script:callCount

        $securityCalls | Should -BeLessThan $fullCalls
    }

    It '''*'' (the default) runs the full query set, including domain-only queries Security skips' {
        Invoke-Collect | Out-Null
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.web/sites' } -Times 1
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.containerservice/managedclusters' } -Times 1
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.keyvault/vaults' } -Times 1
    }

    It 'an empty -Categories list runs the full query set (same as ''*'')' {
        Invoke-Collect -Categories @() | Out-Null
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.web/sites' } -Times 1
    }

    It 'always runs the base subscriptions query regardless of category' {
        Invoke-Collect -Categories @('Security') | Out-Null
        Should -Invoke Search-AzGraph -ParameterFilter { $Query -match 'microsoft\.resources/subscriptions' } -Times 1
    }
}

Describe 'Invoke-Collect -ManagementGroupId scoping' {
    BeforeEach {
        Mock Search-AzGraph { return @() }
    }

    It 'passes -ManagementGroup to every Search-AzGraph call when an id is supplied' {
        Invoke-Collect -Categories @('Security') -ManagementGroupId 'contoso-root-mg' | Out-Null
        # Every call this run made should carry the management group -- none should
        # be missing it.
        Should -Invoke Search-AzGraph -ParameterFilter { $null -eq $ManagementGroup } -Times 0 -Exactly
        Should -Invoke Search-AzGraph -ParameterFilter { $ManagementGroup -eq 'contoso-root-mg' } -Times 1
    }

    It 'omits -ManagementGroup entirely when no id is supplied (preserves tenant-wide scope)' {
        Invoke-Collect -Categories @('Security') | Out-Null
        Should -Invoke Search-AzGraph -ParameterFilter { $null -ne $ManagementGroup } -Times 0 -Exactly
    }
}
