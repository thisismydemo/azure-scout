<#
.Synopsis
Inventory for Azure Virtual Desktop Workspaces

.DESCRIPTION
This script consolidates information for all AVD Workspace resources
(microsoft.desktopvirtualization/workspaces).
Excel Sheet Name: AVD Workspaces

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Compute/AVDWorkspaces.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

.CATEGORY Compute

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $avdWorkspaces = $Resources | Where-Object { $_.TYPE -eq 'microsoft.desktopvirtualization/workspaces' }

    if ($avdWorkspaces) {
        $tmp = foreach ($1 in $avdWorkspaces) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $appGroupCount = if ($data.applicationGroupReferences) { @($data.applicationGroupReferences).Count } else { 0 }
            $appGroupNames = if ($data.applicationGroupReferences) {
                (@($data.applicationGroupReferences) | ForEach-Object { ($_ -split '/')[-1] }) -join '; '
            } else { 'None' }

            $peCount = if ($data.privateEndpointConnections) { @($data.privateEndpointConnections).Count } else { 0 }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                          = $1.id;
                    'Subscription'                = $sub1.Name;
                    'Resource Group'              = $1.RESOURCEGROUP;
                    'Name'                        = $1.NAME;
                    'Location'                    = $1.LOCATION;
                    'Friendly Name'               = if ($data.friendlyName)              { $data.friendlyName }              else { 'N/A' };
                    'Description'                 = if ($data.description)               { $data.description }               else { 'N/A' };
                    'Application Groups Count'    = $appGroupCount;
                    'Application Groups'          = $appGroupNames;
                    'Public Network Access'       = if ($data.publicNetworkAccess)       { $data.publicNetworkAccess }       else { 'N/A' };
                    'Private Endpoints'           = $peCount;
                    'Provisioning State'          = if ($data.provisioningState)         { $data.provisioningState }         else { 'N/A' };
                    'Resource U'                  = $ResUCount;
                    'Tag Name'                    = [string]$Tag.Name;
                    'Tag Value'                   = [string]$Tag.Value;
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
        $TableName = ('AVDWorkspacesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Friendly Name')
        $Exc.Add('Description')
        $Exc.Add('Application Groups Count')
        $Exc.Add('Application Groups')
        $Exc.Add('Public Network Access')
        $Exc.Add('Private Endpoints')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD Workspaces' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
