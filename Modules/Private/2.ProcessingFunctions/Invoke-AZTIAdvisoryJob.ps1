<#
.Synopsis
Module responsible for invoking advisory processing jobs.

.DESCRIPTION
This module starts jobs to process advisory data for Azure Resources, either in automation or manual mode.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/2.ProcessingFunctions/Invoke-AZTIAdvisoryJob.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.NOTES
Version: 3.6.5
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Invoke-AZTIAdvisoryJob {
    Param($Advisories, $AZTIModule, $Automation)

    if ($Automation.IsPresent)
        {
            Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Advisory Job')
            Start-ThreadJob -Name 'Advisory' -ScriptBlock {

                import-module $($args[1])

                $AdvResult = Start-AZTIAdvisoryJob -Advisories $($args[0])

                $AdvResult

            } -ArgumentList $Advisories, $AZTIModule | Out-Null
        }
    else
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Advisory Job.')
            Start-Job -Name 'Advisory' -ScriptBlock {

                import-module $($args[1])

                $AdvResult = Start-AZTIAdvisoryJob -Advisories $($args[0])

                $AdvResult

            } -ArgumentList $Advisories, $AZTIModule | Out-Null
        }
}