#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#6903 -- security.defenderPlans was a hard-coded empty placeholder while
    caf.security / waf.security rules queried
    $.security.defenderPlans[?(@.properties.pricingTier == 'Standard')], so those
    rules failed on every tenant regardless of the estate's real Defender posture.

    Get-ScoutDefenderPlanSweep collects Microsoft.Security/pricings per subscription
    over plain ARM REST. These tests pin the three behaviours that matter:
    rows flow through with tier + subscription identity, an unregistered provider is
    the QUIET no-Defender state (no warning), and one failing subscription cannot
    take down its neighbours' rows.
#>

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:root 'src/collect/Get-ScoutDefenderPlanSweep.ps1')

    function script:New-PricingResponse {
        param([object[]] $Plans)
        [pscustomobject]@{
            StatusCode = 200
            Content    = (@{ value = $Plans } | ConvertTo-Json -Depth 8)
        }
    }

    $script:subA = [pscustomobject]@{ id = '11111111-1111-1111-1111-111111111111'; name = 'sub-with-defender' }
    $script:subB = [pscustomobject]@{ id = '22222222-2222-2222-2222-222222222222'; name = 'sub-without-provider' }
    $script:planRows = @(
        [pscustomobject]@{
            id         = "/subscriptions/$($script:subA.id)/providers/Microsoft.Security/pricings/VirtualMachines"
            name       = 'VirtualMachines'
            properties = [pscustomobject]@{ pricingTier = 'Standard'; subPlan = 'P2' }
        }
        [pscustomobject]@{
            id         = "/subscriptions/$($script:subA.id)/providers/Microsoft.Security/pricings/Dns"
            name       = 'Dns'
            properties = [pscustomobject]@{ pricingTier = 'Free' }
        }
    )
}

Describe 'Get-ScoutDefenderPlanSweep (AB#6903)' {
    It 'shapes one flat row per plan with tier, subPlan and subscription identity' {
        Mock Invoke-AzRestMethod { New-PricingResponse -Plans $script:planRows }
        $rows = @(Get-ScoutDefenderPlanSweep -Subscriptions @($script:subA))

        $rows.Count | Should -Be 2
        $rows[0].name | Should -Be 'VirtualMachines'
        $rows[0].properties.pricingTier | Should -Be 'Standard'
        $rows[0].properties.subPlan | Should -Be 'P2'
        $rows[0].subscriptionId | Should -Be $script:subA.id
        $rows[0].subscriptionName | Should -Be 'sub-with-defender'
        $rows[1].properties.pricingTier | Should -Be 'Free'
        $rows[1].properties.subPlan | Should -BeNullOrEmpty
    }

    It 'satisfies the exact JSONPath the CAF-SEC-02 / WAF-SE-06 rules issue' {
        Mock Invoke-AzRestMethod { New-PricingResponse -Plans $script:planRows }
        $collectShape = [pscustomobject]@{
            security = [pscustomobject]@{ defenderPlans = @(Get-ScoutDefenderPlanSweep -Subscriptions @($script:subA)) }
        }
        $standard = @($collectShape.security.defenderPlans | Where-Object { $_.properties.pricingTier -eq 'Standard' })
        $standard.Count | Should -Be 1
        $standard[0].name | Should -Be 'VirtualMachines'
    }

    It 'treats an unregistered Microsoft.Security provider as quiet no-Defender, never a warning' {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 400
                Content    = '{"error":{"code":"Error","message":"Please register to Microsoft.Security in order to view your security status"}}'
            }
        }
        $warnings = @()
        $rows = @(Get-ScoutDefenderPlanSweep -Subscriptions @($script:subB) -WarningVariable warnings -WarningAction SilentlyContinue 3>$null)
        $rows.Count | Should -Be 0
        @($warnings).Count | Should -Be 0
    }

    It 'treats a 404 as quiet no-Defender too' {
        Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 404; Content = '{}' } }
        $warnings = @()
        $rows = @(Get-ScoutDefenderPlanSweep -Subscriptions @($script:subB) -WarningVariable warnings -WarningAction SilentlyContinue 3>$null)
        $rows.Count | Should -Be 0
        @($warnings).Count | Should -Be 0
    }

    It 'keeps the healthy subscription''s rows when a neighbour hard-fails, and warns once' {
        Mock Invoke-AzRestMethod {
            if ($Path -match [regex]::Escape($script:subB.id)) {
                [pscustomobject]@{ StatusCode = 500; Content = 'InternalServerError' }
            }
            else { New-PricingResponse -Plans $script:planRows }
        }
        $warnings = @()
        $rows = @(Get-ScoutDefenderPlanSweep -Subscriptions @($script:subA, $script:subB) -WarningVariable warnings -WarningAction SilentlyContinue)
        $rows.Count | Should -Be 2
        @($rows | Where-Object subscriptionId -eq $script:subA.id).Count | Should -Be 2
        @($warnings).Count | Should -Be 1
        [string]$warnings[0] | Should -Match 'sub-without-provider'
    }

    It 'returns an empty array for no subscriptions and for a subscription without an id' {
        Mock Invoke-AzRestMethod { throw 'must not be called' }
        @(Get-ScoutDefenderPlanSweep -Subscriptions @()).Count | Should -Be 0
        @(Get-ScoutDefenderPlanSweep -Subscriptions @([pscustomobject]@{ name = 'no-id' }) -WarningAction SilentlyContinue).Count | Should -Be 0
    }
}
