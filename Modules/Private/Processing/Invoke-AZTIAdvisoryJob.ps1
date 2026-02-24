<#
.Synopsis
Module responsible for invoking advisory processing jobs.

.DESCRIPTION
This module starts jobs to process advisory data for Azure Resources, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/2.ProcessingFunctions/Invoke-AZSCAdvisoryJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZSCAdvisoryJob {
    Param($Advisories, $AZSCModule, $Automation)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Advisory Job')
            Start-ThreadJob -Name 'Advisory' -ScriptBlock {

                import-module $($args[1])

                $AdvResult = Start-AZSCAdvisoryJob -Advisories $($args[0])

                $AdvResult

            } -ArgumentList $Advisories, $AZSCModule | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Advisory Job.')
            Start-Job -Name 'Advisory' -ScriptBlock {

                import-module $($args[1])

                $AdvResult = Start-AZSCAdvisoryJob -Advisories $($args[0])

                $AdvResult

            } -ArgumentList $Advisories, $AZSCModule | Out-Null
        }
}