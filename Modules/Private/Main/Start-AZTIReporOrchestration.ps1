<#
.Synopsis
Main module for Excel Report Building

.DESCRIPTION
This module is the main module for building the Excel Report.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/0.MainFunctions/Start-AZTIReporOrchestration.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 3.6.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola

#>
Function Start-AZTIReporOrchestration {
    Param($ReportCache,
    $SecurityCenter,
    $File,
    $Quotas,
    $SkipPolicy,
    $SkipAdvisory,
    $Automation,
    $TableStyle,
    $IncludeCosts)

    Write-Progress -activity 'Azure Inventory' -Status "65% Complete." -PercentComplete 65 -CurrentOperation "Starting the Report Phase.."

    <############################################################## REPORT CREATION ###################################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Resource Reporting Cache.')
    Start-AZTIExcelJob -ReportCache $ReportCache -TableStyle $TableStyle -File $File

    <############################################################## REPORT EXTRA DETAILS ###################################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Reporting Extra Details.')
    Start-AZTIExcelExtraData -File $File

    <############################################################## EXTRA REPORTS ###################################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Default Data Reporting.')

    Start-AZTIExtraReports -File $File -Quotas $Quotas -SecurityCenter $SecurityCenter -SkipPolicy $SkipPolicy -SkipAdvisory $SkipAdvisory -IncludeCosts $IncludeCosts -TableStyle $TableStyle -ReportCache $ReportCache

}