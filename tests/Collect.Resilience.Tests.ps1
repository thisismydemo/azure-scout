#Requires -Version 7.0
#Requires -Modules Pester
#Requires -Modules Az.ResourceGraph

<#
    Pester tests for src/collect/Invoke-Collect.ps1's collector resilience
    additions:
      AB#397 - per-subscription try/catch/continue fallback when a tenant/MG-wide
               batch query throws: a single bad subscription is skipped (warned
               about by name) while every other subscription's rows for that same
               query still come back.
      AB#398 - an AuthorizationFailed error on an -ManagementGroupId-scoped query
               gets an actionable Reader-role hint naming the management group.
      AB#399 - the known false "resource provider not registered" condition is
               swallowed at Verbose -- no per-subscription retry, no warning noise.
      AB#400 - firewall policy rule-collection group parsing continues past one
               malformed group instead of losing the whole query's results.
      AB#401 - an empty-data guard warns when literally nothing came back from any
               collected query.

    Search-AzGraph is mocked throughout -- no live Azure connection is made.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module Az.ResourceGraph -ErrorAction Stop
    . "$root/src/collect/Invoke-Collect.ps1"

    function Get-MockSubscriptions {
        @(
            [pscustomobject]@{ id = 'sub-1'; name = 'sub-1'; state = 'Enabled'; tags = $null }
            [pscustomobject]@{ id = 'sub-2'; name = 'sub-2'; state = 'Enabled'; tags = $null }
            [pscustomobject]@{ id = 'sub-3'; name = 'sub-3'; state = 'Enabled'; tags = $null }
        )
    }
}

Describe 'Invoke-Collect -- AB#397 per-subscription fallback' {
    BeforeEach {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            if ($Query -match 'peeringCount') {
                # No -Subscription bound at all -> this is the tenant/MG-wide batch
                # call, which fails (simulating a transient/DNS/token error).
                if (-not $Subscription) { throw 'A transient DNS resolution error occurred while querying virtualNetworks.' }
                # One specific subscription keeps failing even on the per-sub retry.
                if ($Subscription -contains 'sub-2') { throw "A transient error occurred for subscription 'sub-2'." }
                return @([pscustomobject]@{ name = "vnet-$($Subscription[0])"; resourceGroup = 'rg1'; subscriptionId = $Subscription[0]; peeringCount = 0; ddosEnabled = $false })
            }
            return @()
        }
    }

    It 'retries per-subscription after a tenant-wide batch failure, and does not throw' {
        { Invoke-Collect -Categories @('Networking') } | Should -Not -Throw
    }

    It 'collects rows from the subscriptions that succeed on retry, skipping only the one that keeps failing' {
        $result = Invoke-Collect -Categories @('Networking')
        $names = @($result.networking.virtualNetworks.name)
        $names | Should -Contain 'vnet-sub-1'
        $names | Should -Contain 'vnet-sub-3'
        $names | Should -Not -Contain 'vnet-sub-2'
        @($result.networking.virtualNetworks).Count | Should -Be 2
    }

    It 'warns once for the subscription that still fails on retry, naming it and AB#397' {
        Invoke-Collect -Categories @('Networking') -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        ($warnings -join "`n") | Should -Match "failed for subscription 'sub-2'"
        ($warnings -join "`n") | Should -Match 'AB#397'
    }
}

Describe 'Invoke-Collect -- AB#398 AuthorizationFailed management-group hint' {
    It 'surfaces an actionable Reader-role hint naming the management group' {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            if ($Query -match 'peeringCount') {
                throw 'AuthorizationFailed: The client does not have authorization to perform action on the requested management group scope.'
            }
            return @()
        }
        Invoke-Collect -Categories @('Networking') -ManagementGroupId 'contoso-root-mg' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        ($warnings -join "`n") | Should -Match 'AuthorizationFailed'
        ($warnings -join "`n") | Should -Match "Reader role at the 'contoso-root-mg' management group scope"
    }

    It 'still falls back to a per-subscription retry after the MG hint (a subscription-level Reader may still work)' {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            if ($Query -match 'peeringCount') {
                if ($ManagementGroup) { throw 'AuthorizationFailed: missing Reader at management group scope.' }
                return @([pscustomobject]@{ name = "vnet-$($Subscription[0])"; resourceGroup = 'rg1'; subscriptionId = $Subscription[0]; peeringCount = 0; ddosEnabled = $false })
            }
            return @()
        }
        $result = Invoke-Collect -Categories @('Networking') -ManagementGroupId 'contoso-root-mg'
        @($result.networking.virtualNetworks).Count | Should -Be 3
    }
}

Describe 'Invoke-Collect -- AB#399 known-noise error is swallowed' {
    BeforeEach {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            if ($Query -match 'microsoft\.keyvault/vaults') {
                throw "MissingSubscriptionRegistration: The subscription is not registered to use namespace 'Microsoft.KeyVault'."
            }
            if ($Query -match 'microsoft\.network/networksecuritygroups') {
                return @([pscustomobject]@{ nsg = 'nsg1'; resourceGroup = 'rg1'; rule = 'AllowAll'; port = '*' })
            }
            return @()
        }
    }

    It 'does not warn for the known-noise error and returns an empty (not thrown) result for that query' {
        $result = Invoke-Collect -Categories @('Security') -WarningVariable warnings -WarningAction SilentlyContinue
        @($result.domains.security.keyVaults).Count | Should -Be 0
        ($warnings -join "`n") | Should -Not -Match 'keyVaults'
    }

    It 'logs the known-noise condition at Verbose' {
        $verboseRecords = Invoke-Collect -Categories @('Security') -Verbose 4>&1 |
            Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
        ($verboseRecords | ForEach-Object { $_.Message }) -join "`n" | Should -Match 'AB#399'
    }
}

Describe 'Invoke-Collect -- AB#400 firewall policy rule-group parse errors continue per-group' {
    BeforeEach {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            if ($Query -match 'firewallpolicies/rulecollectiongroups') {
                return @(
                    [pscustomobject]@{
                        name = 'good-group'; resourceGroup = 'rg1'; subscriptionId = 'sub-1'; policyName = 'fwpolicy1'
                        priority = 100
                        ruleCollections = @(
                            [pscustomobject]@{ rules = @([pscustomobject]@{ name = 'r1' }, [pscustomobject]@{ name = 'r2' }) }
                        )
                    }
                    [pscustomobject]@{
                        name = 'bad-group'; resourceGroup = 'rg1'; subscriptionId = 'sub-1'; policyName = 'fwpolicy1'
                        priority = 200
                        ruleCollections = 'not-a-valid-shape'
                    }
                )
            }
            return @()
        }
    }

    It 'parses the well-formed group normally and records a placeholder with parseError for the malformed one' {
        $result = Invoke-Collect -Categories @('Networking')
        $groups = @($result.networking.firewallPolicyRuleGroups)
        $groups.Count | Should -Be 2

        $good = $groups | Where-Object { $_.name -eq 'good-group' }
        $good.parseError | Should -BeNullOrEmpty
        $good.ruleCount | Should -Be 2
        $good.ruleCollectionCount | Should -Be 1

        $bad = $groups | Where-Object { $_.name -eq 'bad-group' }
        $bad.parseError | Should -Not -BeNullOrEmpty
        $bad.ruleCount | Should -Be 0
        $bad.ruleCollectionCount | Should -Be 0
    }

    It 'warns about the malformed group by name, referencing AB#400, without losing the well-formed group' {
        $result = Invoke-Collect -Categories @('Networking') -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings -join "`n") | Should -Match 'bad-group'
        ($warnings -join "`n") | Should -Match 'AB#400'
        @($result.networking.firewallPolicyRuleGroups | Where-Object { $_.name -eq 'good-group' }) | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-Collect -- AB#401 empty-data guard' {
    It 'warns with a diagnostic hint when literally no resources are returned for any query' {
        Mock Search-AzGraph { return @() }
        Invoke-Collect -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        ($warnings -join "`n") | Should -Match 'no resources were returned'
        ($warnings -join "`n") | Should -Match 'Reader role'
    }

    It 'names the management group in the hint when one was supplied' {
        Mock Search-AzGraph { return @() }
        Invoke-Collect -ManagementGroupId 'contoso-root-mg' -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        ($warnings -join "`n") | Should -Match "management group 'contoso-root-mg'"
    }

    It 'does not warn when at least one query returns data' {
        Mock Search-AzGraph {
            if ($Query -match 'microsoft\.resources/subscriptions"') { return Get-MockSubscriptions }
            return @()
        }
        Invoke-Collect -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        ($warnings -join "`n") | Should -Not -Match 'no resources were returned'
    }
}
