<#
.Synopsis
Inventory for Azure Virtual Desktop Application Groups

.DESCRIPTION
This script consolidates information for all AVD Application Group resources
(microsoft.desktopvirtualization/applicationgroups).
Excel Sheet Name: AVD Application Groups

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Compute/AVDApplicationGroups.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Compute

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $appGroups = $Resources | Where-Object { $_.TYPE -eq 'microsoft.desktopvirtualization/applicationgroups' }

    if ($appGroups) {
        $tmp = foreach ($1 in $appGroups) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $hostPoolName = if ($data.hostPoolArmPath) { ($data.hostPoolArmPath -split '/')[-1] } else { 'N/A' }
            $workspaceName = if ($data.workspaceArmPath) { ($data.workspaceArmPath -split '/')[-1] } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                       = $1.id;
                    'Subscription'             = $sub1.Name;
                    'Resource Group'           = $1.RESOURCEGROUP;
                    'Name'                     = $1.NAME;
                    'Location'                 = $1.LOCATION;
                    'Friendly Name'            = if ($data.friendlyName)           { $data.friendlyName }           else { 'N/A' };
                    'Description'              = if ($data.description)            { $data.description }            else { 'N/A' };
                    'Application Group Type'   = if ($data.applicationGroupType)   { $data.applicationGroupType }   else { 'N/A' };
                    'Host Pool'                = $hostPoolName;
                    'Workspace'                = $workspaceName;
                    'Provisioning State'       = if ($data.provisioningState)      { $data.provisioningState }      else { 'N/A' };
                    'Resource U'               = $ResUCount;
                    'Tag Name'                 = [string]$Tag.Name;
                    'Tag Value'                = [string]$Tag.Value;
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
        $TableName = ('AVDAppGroupsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Friendly Name')
        $Exc.Add('Description')
        $Exc.Add('Application Group Type')
        $Exc.Add('Host Pool')
        $Exc.Add('Workspace')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD Application Groups' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
