<#
.Synopsis
Module responsible for invoking subscription processing jobs.

.DESCRIPTION
This module starts jobs to process Azure subscriptions and their associated resources, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/2.ProcessingFunctions/Invoke-AZSCSubJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZSCSubJob {
    Param($Subscriptions, $Automation, $Resources, $CostData, $AZSCModule)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Subscription Job')
            Start-ThreadJob -Name 'Subscriptions' -ScriptBlock {

                import-module $($args[2])

                $SubResult = Start-AZSCSubscriptionJob -Subscriptions $($args[0]) -Resources $($args[1]) -CostData $($args[3])

                $SubResult

            } -ArgumentList $Subscriptions, $Resources, $AZSCModule, $CostData | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Subscription Job.')
            Start-Job -Name 'Subscriptions' -ScriptBlock {

                import-module $($args[2])

                $SubResult = Start-AZSCSubscriptionJob -Subscriptions $($args[0]) -Resources $($args[1]) -CostData $($args[3])

                $SubResult

            } -ArgumentList $Subscriptions, $Resources, $AZSCModule, $CostData | Out-Null
        }

}

