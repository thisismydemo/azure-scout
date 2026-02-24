<#
.Synopsis
Inventory for Azure Virtual Desktop Scaling Plans

.DESCRIPTION
This script consolidates information for all AVD Scaling Plan resources
(microsoft.desktopvirtualization/scalingplans) including detailed schedule data.
Excel Sheet Name: AVD Scaling Plans

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Compute/AVDScalingPlans.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Compute

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $scalingPlans = $Resources | Where-Object { $_.TYPE -eq 'microsoft.desktopvirtualization/scalingplans' }

    if ($scalingPlans) {
        $tmp = foreach ($1 in $scalingPlans) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $scheduleCount = if ($data.schedules)        { @($data.schedules).Count }        else { 0 }
            $hpRefCount    = if ($data.hostPoolReferences) { @($data.hostPoolReferences).Count } else { 0 }
            $hpNames       = if ($data.hostPoolReferences) {
                (@($data.hostPoolReferences) | ForEach-Object {
                    if ($_.hostPoolArmPath) { ($_.hostPoolArmPath -split '/')[-1] } else { 'N/A' }
                }) -join '; '
            } else { 'None' }

            # Flatten schedule details into one row per plan (summary)
            $scheduleNames = if ($data.schedules) {
                (@($data.schedules) | ForEach-Object { $_.name }) -join '; '
            } else { 'None' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                         = $1.id;
                    'Subscription'               = $sub1.Name;
                    'Resource Group'             = $1.RESOURCEGROUP;
                    'Name'                       = $1.NAME;
                    'Location'                   = $1.LOCATION;
                    'Friendly Name'              = if ($data.friendlyName)          { $data.friendlyName }          else { 'N/A' };
                    'Description'               = if ($data.description)            { $data.description }           else { 'N/A' };
                    'Host Pool Type'             = if ($data.hostPoolType)          { $data.hostPoolType }          else { 'N/A' };
                    'Time Zone'                  = if ($data.timeZone)              { $data.timeZone }              else { 'N/A' };
                    'Exclusion Tag'              = if ($data.exclusionTag)          { $data.exclusionTag }          else { 'None' };
                    'Schedules Count'            = $scheduleCount;
                    'Schedule Names'             = $scheduleNames;
                    'Host Pool References Count' = $hpRefCount;
                    'Host Pools'                 = $hpNames;
                    'Provisioning State'         = if ($data.provisioningState)     { $data.provisioningState }     else { 'N/A' };
                    'Resource U'                 = $ResUCount;
                    'Tag Name'                   = [string]$Tag.Name;
                    'Tag Value'                  = [string]$Tag.Value;
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AVDScalingPlansTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Friendly Name')
        $Exc.Add('Host Pool Type')
        $Exc.Add('Time Zone')
        $Exc.Add('Exclusion Tag')
        $Exc.Add('Schedules Count')
        $Exc.Add('Schedule Names')
        $Exc.Add('Host Pool References Count')
        $Exc.Add('Host Pools')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD Scaling Plans' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
