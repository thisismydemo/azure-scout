<#
.Synopsis
Wait for AZTI Jobs to Complete

.DESCRIPTION
This script waits for the completion of specified AZTI jobs.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/PublicFunctions/Jobs/Wait-AZTIJob.ps1

.COMPONENT
    This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 3.6.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola

#>
function Wait-AZTIJob {
    Param($JobNames, $JobType, $LoopTime)

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Jobs Collector.')

    $c = 0

    while (get-job -Name $JobNames | Where-Object { $_.State -eq 'Running' }) {
        $jb = get-job -Name $JobNames
        $c = (((($jb.count - ($jb | Where-Object { $_.State -eq 'Running' }).Count)) / $jb.Count) * 100)
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+"$JobType Jobs Still Running: "+[string]($jb | Where-Object { $_.State -eq 'Running' }).count)
        $c = [math]::Round($c)
        Write-Progress -Id 1 -activity "Processing $JobType Jobs" -Status "$c% Complete." -PercentComplete $c
        Start-Sleep -Seconds $LoopTime
    }
    Write-Progress -Id 1 -activity "Processing $JobType Jobs" -Status "100% Complete." -Completed

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Jobs Complete.')
}
