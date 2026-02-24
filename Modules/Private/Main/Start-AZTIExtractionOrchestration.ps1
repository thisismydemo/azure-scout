<#
.Synopsis
Extraction orchestration for Azure Resource Inventory

.DESCRIPTION
This module orchestrates the extraction of resources for Azure Resource Inventory.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/0.MainFunctions/Start-AZSCExtractionOrchestration.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
Version: 3.6.11
First Release Date: 15th Oct, 2024
Authors: Claudio Merola

#>
function Start-AZSCExtractionOrchestration {
    Param($ManagementGroup, $Subscriptions, $SubscriptionID, $SkipPolicy, $ResourceGroup, $SecurityCenter, $SkipAdvisory, $IncludeTags, $TagKey, $TagValue, $SkipAPIs, $SkipVMDetails, $IncludeCosts, $Automation, $AzureEnvironment,
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]$Scope = 'All',
        [string]$TenantID
    )

    $Resources = @()
    $ResourceContainers = @()
    $Advisories = @()
    $Security = @()
    $Retirements = @()
    $EntraResources = @()
    $PolicyAssign = $null
    $PolicyDef = $null
    $PolicySetDef = $null
    $Costs = $null

    # ── ARM Extraction (skip when Scope = EntraOnly) ──
    if ($Scope -ne 'EntraOnly') {
        $GraphData = Start-AZSCGraphExtraction -ManagementGroup $ManagementGroup -Subscriptions $Subscriptions -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -SecurityCenter $SecurityCenter -SkipAdvisory $SkipAdvisory -IncludeTags $IncludeTags -TagKey $TagKey -TagValue $TagValue -AzureEnvironment $AzureEnvironment

        $Resources = $GraphData.Resources
        $ResourceContainers = $GraphData.ResourceContainers
        $Advisories = $GraphData.Advisories
        $Security = $GraphData.Security
        $Retirements = $GraphData.Retirements

        Remove-Variable -Name GraphData -ErrorAction SilentlyContinue

        if(!$SkipAPIs.IsPresent)
            {
                Write-Progress -activity 'Azure Inventory' -Status "12% Complete." -PercentComplete 12 -CurrentOperation "Starting API Extraction.."
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Getting API Resources.')
                $APIResults = Get-AZSCAPIResources -Subscriptions $Subscriptions -AzureEnvironment $AzureEnvironment -SkipPolicy $SkipPolicy
                $Resources += $APIResults.ResourceHealth
                $Resources += $APIResults.ManagedIdentities
                $Resources += $APIResults.AdvisorScore
                $Resources += $APIResults.ReservationRecomen
                $PolicyAssign = $APIResults.PolicyAssign
                $PolicyDef = $APIResults.PolicyDef
                $PolicySetDef = $APIResults.PolicySetDef
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'API Resource Inventory Finished.')
                Remove-Variable APIResults -ErrorAction SilentlyContinue
            }

        if ($IncludeCosts.IsPresent) {
            $Costs = Get-AZSCCostInventory -Subscriptions $Subscriptions -Days 60 -Granularity 'Monthly'
        }

        if (!$SkipVMDetails.IsPresent)
            {
                Write-Host 'Gathering VM Extra Details: ' -NoNewline
                Write-Host 'Quotas' -ForegroundColor Cyan
                Write-Progress -activity 'Azure Inventory' -Status "13% Complete." -PercentComplete 13 -CurrentOperation "Starting VM Details Extraction.."

                $VMQuotas = Get-AZSCVMQuotas -Subscriptions $Subscriptions -Resources $Resources

                $Resources += $VMQuotas

                Remove-Variable -Name VMQuotas -ErrorAction SilentlyContinue

                Write-Host 'Gathering VM Extra Details: ' -NoNewline
                Write-Host 'Size SKU' -ForegroundColor Cyan

                $VMSkuDetails = Get-AZSCVMSkuDetails -Resources $Resources

                $Resources += $VMSkuDetails

                Remove-Variable -Name VMSkuDetails -ErrorAction SilentlyContinue

            }
    }
    else {
        Write-Host 'Scope is EntraOnly — ' -NoNewline -ForegroundColor Yellow
        Write-Host 'Skipping ARM resource extraction' -ForegroundColor Yellow
    }

    # ── Entra ID Extraction (when Scope = All or EntraOnly) ──
    if ($Scope -in @('All', 'EntraOnly')) {
        if ([string]::IsNullOrEmpty($TenantID)) {
            Write-Warning 'TenantID is required for Entra ID extraction but was not provided. Skipping Entra extraction.'
        }
        else {
            Write-Progress -activity 'Azure Inventory' -Status "15% Complete." -PercentComplete 15 -CurrentOperation "Starting Entra ID Extraction.."
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Starting Entra ID extraction for tenant: ' + $TenantID)

            $EntraData = Start-AZSCEntraExtraction -TenantID $TenantID
            $EntraResources = $EntraData.EntraResources

            # Merge Entra resources into the main Resources array
            $Resources += $EntraResources

            Remove-Variable -Name EntraData -ErrorAction SilentlyContinue

            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Entra ID extraction complete. ' + $EntraResources.Count + ' resources added.')
        }
    }

    $ResourcesCount = [string]$Resources.Count
    $AdvisoryCount = [string]$Advisories.Count
    $SecCenterCount = [string]$Security.Count
    $PolicyCount = [string]$PolicyAssign.policyAssignments.Count

    $ReturnData = [PSCustomObject]@{
        Resources          = $Resources
        EntraResources     = $EntraResources
        Quotas             = $VMQuotas
        Costs              = $Costs
        ResourceContainers = $ResourceContainers
        Advisories         = $Advisories
        ResourcesCount     = $ResourcesCount
        AdvisoryCount      = $AdvisoryCount
        SecCenterCount     = $SecCenterCount
        Security           = $Security
        Retirements        = $Retirements
        PolicyCount        = $PolicyCount
        PolicyAssign       = $PolicyAssign
        PolicyDef          = $PolicyDef
        PolicySetDef       = $PolicySetDef
    }

    return $ReturnData
}
