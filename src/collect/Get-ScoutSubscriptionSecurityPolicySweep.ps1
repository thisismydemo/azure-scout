#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Collects the subscription-scoped security, diagnostic, and policy datasets used by the
    legacy inventory collectors.

.DESCRIPTION
    Performs one context-scoped sweep per subscription and returns one synthetic resource
    envelope for that subscription. Each Azure call is isolated so a denied or unavailable
    dataset becomes an empty collection without discarding its neighbours.

    Defender assessment queries retry transient HTTP 5xx failures up to three times. A
    Microsoft.Security provider-registration failure for Defender pricing is represented as
    an empty, Unavailable dataset rather than as a collection error.

.PARAMETER Subscriptions
    Subscription objects with an `id` property and an optional `name` property.

.OUTPUTS
    One `[pscustomobject]` per valid subscription with this integration contract:

        type = 'AZSC/Subscription/SecurityPolicySweep'
        subscriptionId
        subscriptionName
        properties.DefenderAlerts
        properties.DefenderAssessments
        properties.DefenderPricing
        properties.DefenderSecureScores
        properties.DefenderSecureScoreControls
        properties.SubscriptionDiagnosticSettings
        properties.PolicyComplianceStates
        properties.CollectionStatus
        properties.CollectionErrors

    Every dataset property is always an array, including on failure. CollectionStatus
    records Success, Unavailable, or Skipped for every dataset. CollectionErrors contains
    only actual failures and is also always an array.

.NOTES
    Collect-phase implementation for Epic AB#5638. The legacy collectors and the collect
    orchestrator intentionally remain unchanged until their declarative definitions are
    integrated.
#>
function Get-ScoutSubscriptionSecurityPolicySweep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Subscriptions
    )

    if ($Subscriptions.Count -eq 0) {
        return @()
    }

    function Invoke-ScoutSweepDataset {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Dataset,

            [Parameter(Mandatory)]
            [string] $SubscriptionName,

            [Parameter(Mandatory)]
            [scriptblock] $Operation,

            [ValidateRange(1, 5)]
            [int] $MaxAttempts = 1,

            [switch] $ProviderRegistrationIsUnavailable
        )

        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            try {
                return [pscustomobject]@{
                    Data   = @(& $Operation)
                    Status = 'Success'
                    Error  = $null
                }
            }
            catch {
                $message = $_.Exception.Message
                # 'Please register to Microsoft.Security in order to view your security status' is
                # the phrasing Azure actually uses for an unregistered provider on this endpoint
                # (observed live, AB#6900) -- it says "register to", never "not registered", so the
                # original patterns missed it and the quiet Unavailable path fell through to a
                # raw Write-Warning on every collect against a subscription without Defender.
                $providerUnavailable =
                    $ProviderRegistrationIsUnavailable -and
                    $message -match '(?i)MissingSubscriptionRegistration|SubscriptionNotRegistered|not registered.+Microsoft\.Security|Microsoft\.Security.+not registered|register to Microsoft\.Security'

                if ($providerUnavailable) {
                    return [pscustomobject]@{
                        Data   = @()
                        Status = 'Unavailable'
                        Error  = $null
                    }
                }

                $transientFailure = $message -match '(?i)\bHTTP\s*(500|502|503|504)\b|InternalServerError|BadGateway|ServiceUnavailable|GatewayTimeout'
                if ($transientFailure -and $attempt -lt $MaxAttempts) {
                    Start-Sleep -Milliseconds (200 * $attempt)
                    continue
                }

                # A null-reference here is a known Az.Security client-side symptom of Defender for
                # Cloud not being fully provisioned/onboarded on this subscription -- not a Scout
                # defect, and not the transient-HTTP pattern retries above target. Surface a clearer
                # hint instead of the bare CLR exception text.
                if ($message -match '(?i)Object reference not set to an instance of an object') {
                    $message = "$message (commonly indicates Microsoft Defender for Cloud is not fully provisioned/onboarded on this subscription)"
                }

                Write-Warning "Get-ScoutSubscriptionSecurityPolicySweep: '$Dataset' failed for subscription '$SubscriptionName' after $attempt attempt(s): $message"
                return [pscustomobject]@{
                    Data   = @()
                    Status = 'Unavailable'
                    Error  = [pscustomobject]@{
                        Dataset = $Dataset
                        Message = $message
                    }
                }
            }
        }
    }

    $originalContext = try {
        Get-AzContext -ErrorAction SilentlyContinue
    }
    catch {
        $null
    }

    $results = try {
        foreach ($subscription in $Subscriptions) {
            $idProperty = $subscription.PSObject.Properties['id']
            if ($null -eq $idProperty -or [string]::IsNullOrWhiteSpace([string] $idProperty.Value)) {
                Write-Warning 'Get-ScoutSubscriptionSecurityPolicySweep: skipping a subscription object without an id.'
                continue
            }

            $subscriptionId = [string] $idProperty.Value
            $tenantIdProperty = $subscription.PSObject.Properties['tenantId']
            $subscriptionTenantId = if ($null -ne $tenantIdProperty -and -not [string]::IsNullOrWhiteSpace([string] $tenantIdProperty.Value)) {
                [string] $tenantIdProperty.Value
            }
            elseif ($null -ne $originalContext -and $null -ne $originalContext.PSObject.Properties['Tenant'] -and $null -ne $originalContext.Tenant -and $null -ne $originalContext.Tenant.PSObject.Properties['Id']) {
                [string] $originalContext.Tenant.Id
            }
            else {
                $null
            }
            $nameProperty = $subscription.PSObject.Properties['name']
            $subscriptionName = if (
                $null -ne $nameProperty -and
                -not [string]::IsNullOrWhiteSpace([string] $nameProperty.Value)
            ) {
                [string] $nameProperty.Value
            }
            else {
                $subscriptionId
            }

            $emptyData = [ordered]@{
                DefenderAlerts                  = @()
                DefenderAssessments             = @()
                DefenderPricing                 = @()
                DefenderSecureScores            = @()
                DefenderSecureScoreControls     = @()
                SubscriptionDiagnosticSettings  = @()
                PolicyComplianceStates          = @()
            }
            $statuses = [ordered]@{}
            $collectionErrors = [System.Collections.Generic.List[object]]::new()

            try {
                $contextParams = @{ Subscription = $subscriptionId; ErrorAction = 'Stop' }
                if ($subscriptionTenantId) { $contextParams['Tenant'] = $subscriptionTenantId }
                Set-AzContext @contextParams | Out-Null
            }
            catch {
                $message = $_.Exception.Message
                Write-Warning "Get-ScoutSubscriptionSecurityPolicySweep: could not enter subscription context '$subscriptionName': $message"
                foreach ($datasetName in $emptyData.Keys) {
                    $statuses[$datasetName] = 'Skipped'
                }
                $collectionErrors.Add([pscustomobject]@{
                        Dataset = 'Context'
                        Message = $message
                    })

                [pscustomobject]@{
                    id               = "/subscriptions/$subscriptionId/providers/AzureScout/securityPolicySweep/default"
                    name             = 'default'
                    type             = 'AZSC/Subscription/SecurityPolicySweep'
                    subscriptionId   = $subscriptionId
                    subscriptionName = $subscriptionName
                    properties       = [pscustomobject]@{
                        DefenderAlerts                 = @()
                        DefenderAssessments            = @()
                        DefenderPricing                = @()
                        DefenderSecureScores           = @()
                        DefenderSecureScoreControls    = @()
                        SubscriptionDiagnosticSettings = @()
                        PolicyComplianceStates         = @()
                        CollectionStatus               = [pscustomobject] $statuses
                        CollectionErrors               = @($collectionErrors)
                    }
                }
                continue
            }

            $queries = [ordered]@{}
            $queries.DefenderAlerts = Invoke-ScoutSweepDataset `
                -Dataset 'DefenderAlerts' `
                -SubscriptionName $subscriptionName `
                -Operation { Get-AzSecurityAlert -ErrorAction Stop }

            $queries.DefenderAssessments = Invoke-ScoutSweepDataset `
                -Dataset 'DefenderAssessments' `
                -SubscriptionName $subscriptionName `
                -MaxAttempts 3 `
                -Operation { Get-AzSecurityAssessment -ErrorAction Stop }

            $queries.DefenderPricing = Invoke-ScoutSweepDataset `
                -Dataset 'DefenderPricing' `
                -SubscriptionName $subscriptionName `
                -ProviderRegistrationIsUnavailable `
                -Operation { Get-AzSecurityPricing -ErrorAction Stop }

            $queries.DefenderSecureScores = Invoke-ScoutSweepDataset `
                -Dataset 'DefenderSecureScores' `
                -SubscriptionName $subscriptionName `
                -Operation { Get-AzSecuritySecureScore -ErrorAction Stop }

            if (@($queries.DefenderSecureScores.Data).Count -gt 0) {
                $queries.DefenderSecureScoreControls = Invoke-ScoutSweepDataset `
                    -Dataset 'DefenderSecureScoreControls' `
                    -SubscriptionName $subscriptionName `
                    -Operation { Get-AzSecuritySecureScoreControl -ErrorAction Stop }
            }
            else {
                $queries.DefenderSecureScoreControls = [pscustomobject]@{
                    Data   = @()
                    Status = 'Skipped'
                    Error  = $null
                }
            }

            $resourceId = "/subscriptions/$subscriptionId"
            $queries.SubscriptionDiagnosticSettings = Invoke-ScoutSweepDataset `
                -Dataset 'SubscriptionDiagnosticSettings' `
                -SubscriptionName $subscriptionName `
                -Operation { Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction Stop }

            $queries.PolicyComplianceStates = Invoke-ScoutSweepDataset `
                -Dataset 'PolicyComplianceStates' `
                -SubscriptionName $subscriptionName `
                -Operation { Get-AzPolicyState -SubscriptionId $subscriptionId -ErrorAction Stop }

            foreach ($datasetName in @($emptyData.Keys)) {
                $query = $queries[$datasetName]
                $emptyData[$datasetName] = @($query.Data)
                $statuses[$datasetName] = $query.Status
                if ($null -ne $query.Error) {
                    $collectionErrors.Add($query.Error)
                }
            }

            [pscustomobject]@{
                id               = "/subscriptions/$subscriptionId/providers/AzureScout/securityPolicySweep/default"
                name             = 'default'
                type             = 'AZSC/Subscription/SecurityPolicySweep'
                subscriptionId   = $subscriptionId
                subscriptionName = $subscriptionName
                properties       = [pscustomobject]@{
                    DefenderAlerts                 = @($emptyData.DefenderAlerts)
                    DefenderAssessments            = @($emptyData.DefenderAssessments)
                    DefenderPricing                = @($emptyData.DefenderPricing)
                    DefenderSecureScores           = @($emptyData.DefenderSecureScores)
                    DefenderSecureScoreControls    = @($emptyData.DefenderSecureScoreControls)
                    SubscriptionDiagnosticSettings = @($emptyData.SubscriptionDiagnosticSettings)
                    PolicyComplianceStates         = @($emptyData.PolicyComplianceStates)
                    CollectionStatus               = [pscustomobject] $statuses
                    CollectionErrors               = @($collectionErrors)
                }
            }
        }
    }
    finally {
        $restoreId = $null
        if (
            $null -ne $originalContext -and
            $null -ne $originalContext.PSObject.Properties['Subscription'] -and
            $null -ne $originalContext.Subscription -and
            $null -ne $originalContext.Subscription.PSObject.Properties['Id']
        ) {
            $restoreId = [string] $originalContext.Subscription.Id
        }
        if (-not [string]::IsNullOrWhiteSpace($restoreId)) {
            try {
                $restoreParams = @{ Subscription = $restoreId; ErrorAction = 'Stop' }
                if ($null -ne $originalContext.PSObject.Properties['Tenant'] -and $null -ne $originalContext.Tenant -and $null -ne $originalContext.Tenant.PSObject.Properties['Id'] -and $originalContext.Tenant.Id) {
                    $restoreParams['Tenant'] = $originalContext.Tenant.Id
                }
                Set-AzContext @restoreParams | Out-Null
            }
            catch {
                Write-Warning "Get-ScoutSubscriptionSecurityPolicySweep: could not restore subscription context '$restoreId': $($_.Exception.Message)"
            }
        }
    }

    return @($results)
}
