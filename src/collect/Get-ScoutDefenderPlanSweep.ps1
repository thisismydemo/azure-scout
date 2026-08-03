#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Collects Microsoft Defender for Cloud plan assignments (Microsoft.Security/pricings)
    for every subscription, one ARM GET per subscription.

.DESCRIPTION
    AB#6903. `security.defenderPlans` shipped as a hard-coded empty placeholder from the
    day the collect contract was written, while `caf.security.yaml` and `waf.security.yaml`
    carry live rules querying `$.security.defenderPlans[?(@.properties.pricingTier ==
    'Standard')]` -- so those rules failed on every tenant regardless of the estate's real
    Defender posture (proven live: 18 plans, 4 non-Free, on a subscription the banked
    corpus showed as zero rows).

    Plain ARM REST, no Az.Security dependency. A subscription where the Microsoft.Security
    provider is not registered answers 404 or the "register to Microsoft.Security" error
    (AB#6900) -- both are the quiet no-Defender state, never a warning. Any other failure
    warns once for that subscription and collection continues with its neighbours.

.PARAMETER Subscriptions
    Subscription objects with an `id` property and an optional `name` property.

.OUTPUTS
    One flat [pscustomobject] per Defender plan across every subscription:
    id / name / subscriptionId / subscriptionName / properties.pricingTier /
    properties.subPlan. Always an array; empty when no subscription carries a plan.
#>
function Get-ScoutDefenderPlanSweep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Subscriptions
    )

    $plans = @(
        foreach ($subscription in $Subscriptions) {
            $idProperty = if ($subscription) { $subscription.PSObject.Properties['id'] } else { $null }
            if ($null -eq $idProperty -or [string]::IsNullOrWhiteSpace([string] $idProperty.Value)) { continue }
            $subscriptionId = [string] $idProperty.Value
            $nameProperty = $subscription.PSObject.Properties['name']
            $subscriptionName = if ($null -ne $nameProperty -and -not [string]::IsNullOrWhiteSpace([string] $nameProperty.Value)) {
                [string] $nameProperty.Value
            }
            else { $subscriptionId }

            try {
                $response = Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/providers/Microsoft.Security/pricings?api-version=2024-01-01" -Method GET -ErrorAction Stop
                if ($null -eq $response) { throw 'ARM returned no response.' }
                if ([int]$response.StatusCode -eq 404) { continue }
                if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
                    $content = [string]$response.Content
                    if ($content -match '(?i)MissingSubscriptionRegistration|SubscriptionNotRegistered|not registered.+Microsoft\.Security|Microsoft\.Security.+not registered|register to Microsoft\.Security') {
                        continue
                    }
                    throw "ARM returned status $($response.StatusCode): $content"
                }

                $body = $response.Content | ConvertFrom-Json
                $rows = if ($body -and $body.PSObject.Properties['value']) { @($body.value) } else { @() }
                foreach ($plan in $rows) {
                    if (-not $plan) { continue }
                    $props = if ($plan.PSObject.Properties['properties'] -and $plan.properties) { $plan.properties } else { $null }
                    [pscustomobject]@{
                        id               = if ($plan.PSObject.Properties['id']) { [string]$plan.id } else { $null }
                        name             = if ($plan.PSObject.Properties['name']) { [string]$plan.name } else { $null }
                        subscriptionId   = $subscriptionId
                        subscriptionName = $subscriptionName
                        properties       = [pscustomobject]@{
                            pricingTier = if ($props -and $props.PSObject.Properties['pricingTier']) { [string]$props.pricingTier } else { $null }
                            subPlan     = if ($props -and $props.PSObject.Properties['subPlan']) { [string]$props.subPlan } else { $null }
                        }
                    }
                }
            }
            catch {
                Write-Warning "Get-ScoutDefenderPlanSweep: Defender plan collection failed for subscription '$subscriptionName' -- security.defenderPlans will omit it: $($_.Exception.Message)"
            }
        }
    )
    return $plans
}
