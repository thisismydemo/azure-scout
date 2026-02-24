<#
.Synopsis
Inventory for Azure Update Manager Maintenance Configurations

.DESCRIPTION
This script consolidates information for all microsoft.maintenance/maintenanceconfigurations resources.
Excel Sheet Name: Maintenance Configs

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Management/MaintenanceConfigurations.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Management

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $maintenanceConfigs = $Resources | Where-Object {$_.TYPE -eq 'microsoft.maintenance/maintenanceconfigurations'}

    <######### Insert the resource Process here ########>

    if($maintenanceConfigs)
        {
            $tmp = foreach ($1 in $maintenanceConfigs) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Parse maintenance window
                $maintenanceWindow = $data.maintenanceWindow

                # Parse maintenance scope
                $scope = $data.maintenanceScope
                $scopeFriendly = switch ($scope) {
                    'Host' { 'Dedicated Hosts' }
                    'OSImage' { 'OS Image Updates' }
                    'Extension' { 'VM Extensions' }
                    'InGuestPatch' { 'In-Guest Patching' }
                    'SQLDB' { 'SQL Database' }
                    'SQLManagedInstance' { 'SQL Managed Instance' }
                    default { $scope }
                }

                # Parse recurrence pattern
                $recurEvery = if ($maintenanceWindow.recurEvery) { $maintenanceWindow.recurEvery } else { 'Not specified' }

                # Parse OS filter
                $osFilter = 'All'
                if ($data.installPatches -and $data.installPatches.windowsParameters) {
                    $osFilter = 'Windows'
                } elseif ($data.installPatches -and $data.installPatches.linuxParameters) {
                    $osFilter = 'Linux'
                }

                # Get classification filters
                $classifications = @()
                if ($data.installPatches.windowsParameters.classificationsToInclude) {
                    $classifications = $data.installPatches.windowsParameters.classificationsToInclude
                } elseif ($data.installPatches.linuxParameters.classificationsToInclude) {
                    $classifications = $data.installPatches.linuxParameters.classificationsToInclude
                }
                $classificationsStr = if ($classifications) { ($classifications -join ', ') } else { 'All' }

                # Reboot setting
                $rebootSetting = 'IfRequired'
                if ($data.installPatches.rebootSetting) {
                    $rebootSetting = $data.installPatches.rebootSetting
                } elseif ($data.installPatches.windowsParameters.rebootSetting) {
                    $rebootSetting = $data.installPatches.windowsParameters.rebootSetting
                } elseif ($data.installPatches.linuxParameters.rebootSetting) {
                    $rebootSetting = $data.installPatches.linuxParameters.rebootSetting
                }

                # Pre/Post tasks
                $preTasks = if ($data.tasks -and $data.tasks.preMaintenanceTasks) {
                    ($data.tasks.preMaintenanceTasks | ForEach-Object { $_.source } | Where-Object { $_ }) -join '; '
                } else { 'None' }

                $postTasks = if ($data.tasks -and $data.tasks.postMaintenanceTasks) {
                    ($data.tasks.postMaintenanceTasks | ForEach-Object { $_.source } | Where-Object { $_ }) -join '; '
                } else { 'None' }

                # KB numbers
                $kbInclude = if ($data.installPatches.windowsParameters.kbNumbersToInclude) {
                    ($data.installPatches.windowsParameters.kbNumbersToInclude -join ', ')
                } else { 'None' }
                $kbExclude = if ($data.installPatches.windowsParameters.kbNumbersToExclude) {
                    ($data.installPatches.windowsParameters.kbNumbersToExclude -join ', ')
                } else { 'None' }

                # Package names
                $pkgInclude = if ($data.installPatches.linuxParameters.packageNameMasksToInclude) {
                    ($data.installPatches.linuxParameters.packageNameMasksToInclude -join ', ')
                } else { 'None' }
                $pkgExclude = if ($data.installPatches.linuxParameters.packageNameMasksToExclude) {
                    ($data.installPatches.linuxParameters.packageNameMasksToExclude -join ', ')
                } else { 'None' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'Configuration Name'        = $1.NAME;
                        'Location'                  = $1.LOCATION;
                        'Scope'                     = $scopeFriendly;
                        'Recurrence Pattern'        = $recurEvery;
                        'Start Time (UTC)'          = if ($maintenanceWindow.startDateTime) { $maintenanceWindow.startDateTime } else { 'Not scheduled' };
                        'Duration (hours)'          = if ($maintenanceWindow.duration) { $maintenanceWindow.duration } else { 'Not specified' };
                        'Time Zone'                 = if ($maintenanceWindow.timeZone) { $maintenanceWindow.timeZone } else { 'UTC' };
                        'OS Filter'                 = $osFilter;
                        'Patch Classifications'     = $classificationsStr;
                        'Reboot Setting'            = $rebootSetting;
                        'KB Numbers (Include)'      = $kbInclude;
                        'KB Numbers (Exclude)'      = $kbExclude;
                        'Package Names (Include)'   = $pkgInclude;
                        'Package Names (Exclude)'   = $pkgExclude;
                        'Pre-Maintenance Tasks'     = $preTasks;
                        'Post-Maintenance Tasks'    = $postTasks;
                        'Visibility'                = if ($data.visibility) { $data.visibility } else { 'Custom' };
                        'Resource U'                = $ResUCount;
                        'Tag Name'                  = [string]$Tag.Name;
                        'Tag Value'                 = [string]$Tag.Value
                    }
                    $obj
                    if ($ResUCount -eq 1) { $ResUCount = 0 }
                }
            }
            $tmp
        }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('MaintConfigTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range M:Q -Width 40 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Configuration Name')
        $Exc.Add('Location')
        $Exc.Add('Scope')
        $Exc.Add('Recurrence Pattern')
        $Exc.Add('Start Time (UTC)')
        $Exc.Add('Duration (hours)')
        $Exc.Add('Time Zone')
        $Exc.Add('OS Filter')
        $Exc.Add('Patch Classifications')
        $Exc.Add('Reboot Setting')
        $Exc.Add('KB Numbers (Include)')
        $Exc.Add('KB Numbers (Exclude)')
        $Exc.Add('Package Names (Include)')
        $Exc.Add('Package Names (Exclude)')
        $Exc.Add('Pre-Maintenance Tasks')
        $Exc.Add('Post-Maintenance Tasks')
        $Exc.Add('Visibility')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Maintenance Configs' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
