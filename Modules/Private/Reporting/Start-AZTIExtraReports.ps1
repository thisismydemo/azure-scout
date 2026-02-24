<#
.Synopsis
Module for Extra Reports

.DESCRIPTION
This script processes and creates additional report sheets such as Quotas, Security Center, Policies, and Advisory.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/3.ReportingFunctions/Start-AZSCExtraReports.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
Version: 3.6.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Start-AZSCExtraReports {
    Param($File, $Quotas, $SecurityCenter, $SkipPolicy, $SkipAdvisory, $IncludeCosts, $TableStyle, $ReportCache)

    Write-Progress -activity 'Azure Inventory' -Status "70% Complete." -PercentComplete 70 -CurrentOperation "Reporting Extra Resources.."

    <################################################ QUOTAS #######################################################>

    if(![string]::IsNullOrEmpty($Quotas))
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Generating Quota Usage Sheet.')
            Write-Progress -Id 1 -activity 'Azure Resource Inventory Quota Usage' -Status "50% Complete." -PercentComplete 50 -CurrentOperation "Building Quota Sheet"

            Build-AZSCQuotaReport -File $File -AzQuota $Quotas -TableStyle $TableStyle

            Write-Progress -Id 1 -activity 'Azure Resource Inventory Quota Usage' -Status "100% Complete." -Completed
        }

    <################################################ SECURITY CENTER #######################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Checking if Should Generate Security Center Sheet.')
    if ($SecurityCenter.IsPresent) {
        if(get-job | Where-Object {$_.Name -eq 'Security'})
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Generating Security Center Sheet.')

                while (get-job -Name 'Security' | Where-Object { $_.State -eq 'Running' }) {
                    Write-Progress -Id 1 -activity 'Processing Security Center Advisories' -Status "50% Complete." -PercentComplete 50
                    Start-Sleep -Seconds 2
                }

                $Sec = Receive-Job -Name 'Security'
                Remove-Job -Name 'Security' | Out-Null

                Build-AZSCSecCenterReport -File $File -Sec $Sec -TableStyle $TableStyle

                Write-Progress -Id 1 -activity 'Processing Security Center Advisories'  -Status "100% Complete." -Completed
            }

    }

    <################################################ POLICY #######################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Checking if Should Generate Policy Sheet.')
    if (!$SkipPolicy.IsPresent) {
        if(get-job | Where-Object {$_.Name -eq 'Policy'})
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Generating Policy Sheet.')

                while (get-job -Name 'Policy' | Where-Object { $_.State -eq 'Running' }) {
                    Write-Progress -Id 1 -activity 'Processing Policies' -Status "50% Complete." -PercentComplete 50
                    Start-Sleep -Seconds 2
                }

                $Pol = Receive-Job -Name 'Policy'
                Remove-Job -Name 'Policy' | Out-Null

                Build-AZSCPolicyReport -File $File -Pol $Pol -TableStyle $TableStyle

                Write-Progress -Id 1 -activity 'Processing Policies'  -Status "100% Complete." -Completed

                Start-Sleep -Milliseconds 200
            }
    }

    <################################################ ADVISOR #######################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Checking if Should Generate Advisory Sheet.')
    if (!$SkipAdvisory.IsPresent) {
        if (get-job | Where-Object {$_.Name -eq 'Advisory'})
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Generating Advisor Sheet.')

                while (get-job -Name 'Advisory' | Where-Object { $_.State -eq 'Running' }) {
                    Write-Progress -Id 1 -activity 'Processing Advisories' -Status "50% Complete." -PercentComplete 50
                    Start-Sleep -Seconds 2
                }

                $Adv = Receive-Job -Name 'Advisory'
                Remove-Job -Name 'Advisory' | Out-Null

                Build-AZSCAdvisoryReport -File $File -Adv $Adv -TableStyle $TableStyle

                Write-Progress -Id 1 -activity 'Processing Advisories'  -Status "100% Complete." -Completed

                Start-Sleep -Milliseconds 200
            }
    }

    <################################################################### SUBSCRIPTIONS ###################################################################>

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Generating Subscription sheet.')

    Write-Progress -activity 'Azure Resource Inventory Subscriptions' -Status "50% Complete." -PercentComplete 50 -CurrentOperation "Building Subscriptions Sheet"

    while (get-job -Name 'Subscriptions' | Where-Object { $_.State -eq 'Running' }) {
        Write-Progress -Id 1 -activity 'Processing Subscriptions' -Status "50% Complete." -PercentComplete 50
        Start-Sleep -Seconds 2
    }

    $AzSubs = Receive-Job -Name 'Subscriptions'
    Remove-Job -Name 'Subscriptions' | Out-Null

    Build-AZSCSubsReport -File $File -Sub $AzSubs -IncludeCosts $IncludeCosts -TableStyle $TableStyle

    Clear-AZSCMemory

    Write-Progress -activity 'Azure Resource Inventory Subscriptions' -Status "100% Complete." -Completed

    Write-Progress -activity 'Azure Inventory' -Status "80% Complete." -PercentComplete 80 -CurrentOperation "Completed Extra Resources Reporting.."

    <################################################ PHASE 10 — SPECIALIZED TABS #######################################################>

    if ($ReportCache) {
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Building Phase 10 specialized report tabs.')

        Write-Progress -Id 1 -activity 'Building Cost Management tab' -Status "50% Complete." -PercentComplete 50
        Build-AZSCCostManagementReport -File $File -ReportCache $ReportCache -TableStyle $TableStyle
        Write-Progress -Id 1 -activity 'Building Cost Management tab' -Completed

        Write-Progress -Id 1 -activity 'Building Security Overview tab' -Status "50% Complete." -PercentComplete 50
        Build-AZSCSecurityOverviewReport -File $File -ReportCache $ReportCache -TableStyle $TableStyle
        Write-Progress -Id 1 -activity 'Building Security Overview tab' -Completed

        Write-Progress -Id 1 -activity 'Building Azure Update Manager tab' -Status "50% Complete." -PercentComplete 50
        Build-AZSCUpdateManagerReport -File $File -ReportCache $ReportCache -TableStyle $TableStyle
        Write-Progress -Id 1 -activity 'Building Azure Update Manager tab' -Completed

        Write-Progress -Id 1 -activity 'Building Azure Monitor tab' -Status "50% Complete." -PercentComplete 50
        Build-AZSCMonitorReport -File $File -ReportCache $ReportCache -TableStyle $TableStyle
        Write-Progress -Id 1 -activity 'Building Azure Monitor tab' -Completed
    }
}