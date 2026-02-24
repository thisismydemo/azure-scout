<#
.Synopsis
Module responsible for invoking policy evaluation jobs.

.DESCRIPTION
This module starts jobs to evaluate Azure policies, including policy definitions, assignments, and set definitions, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/2.ProcessingFunctions/Invoke-AZSCPolicyJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZSCPolicyJob {
    Param($Subscriptions, $PolicySetDef, $PolicyAssign, $PolicyDef, $AZSCModule, $Automation)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Policy Job')
            Start-ThreadJob -Name 'Policy' -ScriptBlock {

                import-module $($args[4])

                $PolResult = Start-AZSCPolicyJob -Subscriptions $($args[0]) -PolicySetDef $($args[1]) -PolicyAssign $($args[2]) -PolicyDef $($args[3])

                $PolResult

            } -ArgumentList $Subscriptions, $PolicySetDef, $PolicyAssign, $PolicyDef, $AZSCModule | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Policy Job.')
            Start-Job -Name 'Policy' -ScriptBlock {

                import-module $($args[4])

                $PolResult = Start-AZSCPolicyJob -Subscriptions $($args[0]) -PolicySetDef $($args[1]) -PolicyAssign $($args[2]) -PolicyDef $($args[3])

                $PolResult

            } -ArgumentList $Subscriptions, $PolicySetDef, $PolicyAssign, $PolicyDef, $AZSCModule | Out-Null
        }
}