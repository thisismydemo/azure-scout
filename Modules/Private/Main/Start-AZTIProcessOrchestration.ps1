<#
.Synopsis
Process orchestration for Azure Resource Inventory

.DESCRIPTION
This module orchestrates the processing of resources for Azure Resource Inventory.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/0.MainFunctions/Start-AZSCProcessOrchestration.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 3.6.9
First Release Date: 15th Oct, 2024
Authors: Claudio Merola

#>

function Start-AZSCProcessOrchestration {
    Param($Subscriptions, $Resources, $Retirements, $DefaultPath, $File, $Heavy, $InTag, $Automation, $Category)

        Write-Progress -activity 'Azure Inventory' -Status "21% Complete." -PercentComplete 21 -CurrentOperation "Starting to process extracted data.."

        <######################################################### IMPORT UNSUPPORTED VERSION LIST ######################################################################>

        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Importing List of Unsupported Versions.')

        $Unsupported = Get-AZSCUnsupportedData

        <######################################################### RESOURCE GROUP JOB ######################################################################>

        if ($Automation.IsPresent)
            {
                Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Processing Resources in Automation Mode')

                Start-AZSCAutProcessJob -Resources $Resources -Retirements $Retirements -Subscriptions $Subscriptions -Heavy $Heavy -InTag $InTag -Unsupported $Unsupported -Category $Category
            }
        else
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Processing Resources in Regular Mode')

                Start-AZSCProcessJob -Resources $Resources -Retirements $Retirements -Subscriptions $Subscriptions -DefaultPath $DefaultPath -InTag $InTag -Heavy $Heavy -Unsupported $Unsupported -Category $Category
            }

        Remove-Variable -Name Unsupported -ErrorAction SilentlyContinue

        <############################################################## RESOURCES PROCESSING #############################################################>

        if ($Automation.IsPresent)
            {
                Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Waiting for Resource Jobs to Complete in Automation Mode')
                Get-Job | Where-Object {$_.name -like 'ResourceJob_*'} | Wait-Job
            }
        else
            {
                $JobNames = (Get-Job | Where-Object {$_.name -like 'ResourceJob_*'}).Name
                Wait-AZSCJob -JobNames $JobNames -JobType 'Resource' -LoopTime 5
            }

        if ($Automation.IsPresent)
            {
                Write-Output ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Processing Resources in Automation Mode')
            }
        else
            {
                Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Finished Waiting for Resource Jobs.')
            }

        Build-AZSCCacheFiles -DefaultPath $DefaultPath -JobNames $JobNames

        Write-Progress -activity 'Azure Inventory' -Status "60% Complete." -PercentComplete 60 -CurrentOperation "Completed Data Processing Phase.."

}