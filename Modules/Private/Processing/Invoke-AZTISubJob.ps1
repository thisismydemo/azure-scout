<#
.Synopsis
Module responsible for invoking subscription processing jobs.

.DESCRIPTION
This module starts jobs to process Azure subscriptions and their associated resources, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/2.ProcessingFunctions/Invoke-AZTISubJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZTISubJob {
    Param($Subscriptions, $Automation, $Resources, $CostData, $AZTIModule)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Subscription Job')
            Start-ThreadJob -Name 'Subscriptions' -ScriptBlock {

                import-module $($args[2])

                $SubResult = Start-AZTISubscriptionJob -Subscriptions $($args[0]) -Resources $($args[1]) -CostData $($args[3])

                $SubResult

            } -ArgumentList $Subscriptions, $Resources, $AZTIModule, $CostData | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Subscription Job.')
            Start-Job -Name 'Subscriptions' -ScriptBlock {

                import-module $($args[2])

                $SubResult = Start-AZTISubscriptionJob -Subscriptions $($args[0]) -Resources $($args[1]) -CostData $($args[3])

                $SubResult

            } -ArgumentList $Subscriptions, $Resources, $AZTIModule, $CostData | Out-Null
        }

}

