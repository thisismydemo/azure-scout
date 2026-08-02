#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#6755 / AB#6758 — the production splat must SET -IncludeTenantWideResources.

    `-IncludeTenantWideResources` arrived with AB#5933 as a temporary migration gate and was
    never removed once its consumers shipped. No production caller set it, so
    `Get-ScoutTenantWideResource` never ran and the ManagementGroups, CustomRoleDefinitions,
    PolicyDefinitions and PolicySetDefinitions collectors read an empty resource list on every
    run since — four worksheets silently blank, and four assessments (Landing Zone, AVS Landing
    Zone, Cloud Governance, CASA) scoring against nothing.

    Three separate safeguards missed it, and the shape of each miss dictates the shape of the
    tests here:

      1. `Get-ScoutRawInventory` returns the tenant-wide envelopes empty BY DESIGN when the
         switch is off, so nothing threw.
      2. `tests/Collect.RawInventory.Tests.ps1` passes `-IncludeTenantWideResources` explicitly,
         proving only that the function HONOURS the switch — which was never in doubt.
      3. A permission theory (Management Group Reader) absorbed the blame for the empty rows.

    So these tests assert the one thing none of those did: that the argument hashtable each
    PRODUCTION entry point builds carries the switch. They stub `Get-ScoutRawInventory` and
    capture what the caller actually splatted, which is the only place the defect lived.

    No Azure connection.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent

    # Get-ScoutRawInventory's `Import-Module Az.ResourceGraph` must not pull the real module in.
    function Import-Module { param([Parameter(ValueFromRemainingArguments)] $Rest) }
}

Describe 'AB#6755 — the inventory production splat (Start-AZSCGraphExtraction)' {

    BeforeEach {
        . "$script:Root/src/collect/Start-ScoutGraphExtraction.ps1"

        $script:Splat = $null
        # Only the parameters under test are named; everything else the production splat carries
        # lands in -Rest. Naming them all would make this stub a second copy of the real
        # signature and it would rot the first time one is added.
        function Get-ScoutRawInventory {
            [CmdletBinding()]
            param(
                $SkipApiResourceSweep,
                $SkipPolicy,
                [Parameter(ValueFromRemainingArguments)] $Rest
            )
            $script:Splat = $PSBoundParameters
            [pscustomobject]@{
                Resources = @(); ResourceContainers = @(); Advisories = @()
                Security = @(); Retirements = @()
                ApiResources = @([pscustomobject]@{ Subscription = 'sub-1' })
            }
        }
        function Get-AZSCManagementGroups { param($ManagementGroup, $Subscriptions) $Subscriptions }
    }

    It 'has no parameter that can turn tenant-wide collection off' {
        # The whole point of the correction. A switch nobody sets and a switch that is usually
        # set are the same trap; the only safe shape is no switch at all.
        $null = Start-AZSCGraphExtraction -Subscriptions @([pscustomobject]@{ id = 'sub-1' }) -AzureEnvironment 'AzureCloud'

        $script:Splat.Keys | Should -Not -Contain 'IncludeTenantWideResources'
        (Get-Command Get-ScoutRawInventory).Parameters.Keys | Should -Not -Contain 'IncludeTenantWideResources'
    }

    It 'passes -SkipAPIs through as the sweep flag only, never as a tenant-wide flag' {
        # -SkipAPIs means "Resource Graph only". Only the POLICY definitions come from the ARM
        # REST sweep; management groups and custom roles come from Az cmdlets, so this flag must
        # not be able to drop them.
        $null = Start-AZSCGraphExtraction -Subscriptions @([pscustomobject]@{ id = 'sub-1' }) -AzureEnvironment 'AzureCloud' -SkipAPIs $true

        [bool]$script:Splat['SkipApiResourceSweep'] | Should -BeTrue
    }

    It 'forwards -SkipPolicy so the sweep it drives matches what the operator asked for' {
        $null = Start-AZSCGraphExtraction -Subscriptions @([pscustomobject]@{ id = 'sub-1' }) -AzureEnvironment 'AzureCloud' -SkipPolicy $true

        [bool]$script:Splat['SkipPolicy'] | Should -BeTrue
    }

    It 'hands the ARM REST sweep back up so the orchestration does not repeat it' {
        $result = Start-AZSCGraphExtraction -Subscriptions @([pscustomobject]@{ id = 'sub-1' }) -AzureEnvironment 'AzureCloud'

        @($result.ApiResources).Count | Should -Be 1
        $result.ApiResources[0].Subscription | Should -Be 'sub-1'
    }
}

Describe 'AB#6755 — the assessment production splat (Invoke-Collect)' {

    It 'does not opt out of the ARM REST sweep, because the policy definitions are the point' {
        $source = Get-Content -Raw "$script:Root/src/collect/Invoke-Collect.ps1"
        $rawArgsLine = ([regex]'\$rawArgs\s*=\s*@\{[^}]*\}').Match($source).Value

        $rawArgsLine | Should -Not -Match 'SkipApiResourceSweep'
    }

    It 'does not set -SkipPolicy, because the policy definitions are what it collects for' {
        $source = Get-Content -Raw "$script:Root/src/collect/Invoke-Collect.ps1"
        $rawArgsLine = ([regex]'\$rawArgs\s*=\s*@\{[^}]*\}').Match($source).Value

        $rawArgsLine | Should -Not -Match 'SkipPolicy'
    }

    It 'narrows the sweep with -TenantWideDefinitionsOnly rather than paying for all seven calls' {
        $source = Get-Content -Raw "$script:Root/src/collect/Invoke-Collect.ps1"

        $source | Should -Match '\$rawArgs\s*=\s*@\{[^}]*TenantWideDefinitionsOnly\s*=\s*\$true'
    }
}

Describe 'AB#6755 / AB#6759 — the measured cost of the narrowed sweep' {

    BeforeEach {
        . "$script:Root/src/collect/Get-ScoutApiResources.ps1"

        $script:Uris = [System.Collections.Generic.List[string]]::new()
        function Get-AzAccessToken {
            param([Parameter(ValueFromRemainingArguments)] $Rest)
            [pscustomobject]@{ Token = (ConvertTo-SecureString 'stub' -AsPlainText -Force) }
        }
        function Invoke-RestMethod {
            param([Parameter(ValueFromRemainingArguments)] $Rest)
            $script:Uris.Add(($Rest -join ' '))
            [pscustomobject]@{ value = @() }
        }
        function Start-Sleep { param([Parameter(ValueFromRemainingArguments)] $Rest) }
    }

    It 'issues eight calls per subscription for a full sweep and two for -DefinitionsOnly' {
        # The exact numbers are the point of AB#6759: this is the per-subscription REST cost the
        # assessment path now pays that it did not pay before. If either count moves, the number
        # recorded on the work item is stale and this test says so.
        #
        # Was seven through AB#6759. AB#6801 added the eighth -- `Microsoft.Edge/sites` for the
        # re-sourced Hybrid/ArcSites collector, which is not ARG-indexed and so has to be listed
        # per subscription. -DefinitionsOnly still pays two, because ArcSites is inventory data,
        # not a policy definition, and is skipped alongside the other four.
        $subs = @([pscustomobject]@{ id = 'sub-1'; name = 'Sub One' })

        $null = Get-ScoutApiResources -Subscriptions $subs
        $full = $script:Uris.Count

        $script:Uris.Clear()
        $null = Get-ScoutApiResources -Subscriptions $subs -DefinitionsOnly
        $definitionsOnly = $script:Uris.Count

        $full | Should -Be 8
        $definitionsOnly | Should -Be 2
        ($script:Uris -join ' ') | Should -Match 'policyDefinitions'
        ($script:Uris -join ' ') | Should -Match 'policySetDefinitions'
        ($script:Uris -join ' ') | Should -Not -Match 'ResourceHealth'
        ($script:Uris -join ' ') | Should -Not -Match 'policyStates'
    }

    It 'refuses the contradictory combination rather than silently collecting nothing' {
        { Get-ScoutApiResources -Subscriptions @([pscustomobject]@{ id = 'sub-1' }) -DefinitionsOnly -SkipPolicy } |
            Should -Throw '*cannot be combined*'
    }
}

Describe 'AB#6755 — Get-ScoutRawInventory returns the sweep it ran' {

    BeforeEach {
        . "$script:Root/src/collect/Get-ScoutRawInventory.ps1"

        function Search-AzGraph { param([Parameter(ValueFromRemainingArguments)] $Rest) @() }
        function Get-AzContext { $null }
        function ConvertTo-ScoutManagementGroupHierarchy { param($Root) @() }
        function Get-ScoutTenantWideResource { param([object[]] $ApiResources) @() }
    }

    It 'runs the sweep on an ordinary run, with no switch asked for' {
        function Get-ScoutApiResources {
            param([object[]] $Subscriptions, [string] $AzureEnvironment, [switch] $SkipPolicy, [switch] $DefinitionsOnly)
            @([pscustomobject]@{ Subscription = 'sub-1'; SkipPolicyWas = [bool]$SkipPolicy })
        }

        $result = Get-ScoutRawInventory -SubscriptionIds @('sub-1')

        @($result.ApiResources).Count | Should -Be 1
        $result.ApiResources[0].Subscription  | Should -Be 'sub-1'
        $result.ApiResources[0].SkipPolicyWas | Should -BeFalse
    }

    It 'forwards -SkipPolicy into the sweep' {
        function Get-ScoutApiResources {
            param([object[]] $Subscriptions, [string] $AzureEnvironment, [switch] $SkipPolicy, [switch] $DefinitionsOnly)
            @([pscustomobject]@{ Subscription = 'sub-1'; SkipPolicyWas = [bool]$SkipPolicy })
        }

        $result = Get-ScoutRawInventory -SubscriptionIds @('sub-1') -SkipPolicy

        $result.ApiResources[0].SkipPolicyWas | Should -BeTrue
    }

    It 'still collects management groups and custom roles under -SkipApiResourceSweep' {
        # THE regression this correction exists to prevent. -SkipAPIs means "Resource Graph
        # only", and only the policy definitions come from the REST sweep. Management groups and
        # custom role definitions come from Az cmdlets, so skipping the sweep must cost the
        # policy halves and nothing else.
        function Get-ScoutApiResources { param([Parameter(ValueFromRemainingArguments)] $Rest) throw 'the sweep must not run under -SkipApiResourceSweep' }
        $script:TenantWideRan = $false
        function Get-ScoutTenantWideResource {
            param([object[]] $ApiResources)
            $script:TenantWideRan = $true
            @(
                [pscustomobject]@{ type = 'AZSC/Management/ManagementGroup'; properties = @('root') }
                [pscustomobject]@{ type = 'AZSC/Management/RoleDefinition';  properties = @('custom-1') }
                [pscustomobject]@{ type = 'AZSC/Management/PolicyDefinition'; properties = @($ApiResources) }
            )
        }

        $result = Get-ScoutRawInventory -SubscriptionIds @('sub-1') -SkipApiResourceSweep

        $script:TenantWideRan | Should -BeTrue
        @($result.ApiResources).Count | Should -Be 0
        @($result.Resources | Where-Object type -eq 'AZSC/Management/ManagementGroup').Count | Should -Be 1
        @($result.Resources | Where-Object type -eq 'AZSC/Management/RoleDefinition').Count  | Should -Be 1
    }

    It 'still collects management groups and custom roles when the sweep THROWS' {
        # Same guarantee, arrived at the other way. Folding the sweep and the envelopes into one
        # try block is how the management groups were lost the first time.
        function Get-ScoutApiResources { param([Parameter(ValueFromRemainingArguments)] $Rest) throw 'ARM is having a day' }
        function Get-ScoutTenantWideResource {
            param([object[]] $ApiResources)
            @([pscustomobject]@{ type = 'AZSC/Management/ManagementGroup'; properties = @('root') })
        }

        $result = Get-ScoutRawInventory -SubscriptionIds @('sub-1') -WarningAction SilentlyContinue

        @($result.Resources | Where-Object type -eq 'AZSC/Management/ManagementGroup').Count | Should -Be 1
    }
}
