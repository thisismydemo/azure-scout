<#
.Synopsis
Module responsible for invoking Security Center processing jobs.

.DESCRIPTION
This module starts jobs to process Azure Security Center data for subscriptions and resources, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/2.ProcessingFunctions/Invoke-AZSCSecurityCenterJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZSCSecurityCenterJob {
    Param($Subscriptions, $Automation, $Resources, $AZSCModule)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting SecurityCenter Job')
            Start-ThreadJob  -Name 'Security' -ScriptBlock {

                import-module $($args[2])

                $SecResult = Start-AZSCSecCenterJob -Subscriptions $($args[0]) -Security $($args[1])

                $SecResult

            } -ArgumentList $Subscriptions , $SecurityCenter, $AZSCModule | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting SecurityCenter Job.')
            Start-Job -Name 'Security' -ScriptBlock {

                import-module $($args[2])

                $SecResult = Start-AZSCSecCenterJob -Subscriptions $($args[0]) -Security $($args[1])

                $SecResult

            } -ArgumentList $Subscriptions , $SecurityCenter, $AZSCModule | Out-Null
        }
}