<#
.Synopsis
Inventory for Azure Monitor Private Link Scopes

.DESCRIPTION
This script consolidates information for all Azure Monitor Private Link Scopes
(microsoft.insights/privatelinkscopes).
Excel Sheet Name: Monitor Private Link Scopes

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/MonitorPrivateLinkScopes.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $plsScopes = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/privatelinkscopes' }

    if ($plsScopes) {
        $tmp = foreach ($1 in $plsScopes) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $peLinkCount = if ($data.privateEndpointConnections) {
                @($data.privateEndpointConnections).Count
            } else { 0 }

            $scopedResCount = if ($data.scopedResources) {
                @($data.scopedResources).Count
            } else { 0 }

            $scopedResTypes = if ($data.scopedResources) {
                (@($data.scopedResources) | ForEach-Object {
                    $_.linkedResourceId -split '/' | Select-Object -Skip 6 -First 2 | Join-String -Separator '/'
                } | Sort-Object -Unique) -join '; '
            } else { 'None' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                           = $1.id;
                    'Subscription'                 = $sub1.Name;
                    'Resource Group'               = $1.RESOURCEGROUP;
                    'Private Link Scope Name'      = $1.NAME;
                    'Location'                     = $1.LOCATION;
                    'Access Mode'                  = if ($data.accessModeSettings.queryAccessMode) { $data.accessModeSettings.queryAccessMode } else { 'N/A' };
                    'Ingestion Access Mode'        = if ($data.accessModeSettings.ingestionAccessMode) { $data.accessModeSettings.ingestionAccessMode } else { 'N/A' };
                    'Private Endpoint Connections' = $peLinkCount;
                    'Scoped Resources Count'       = $scopedResCount;
                    'Scoped Resource Types'        = $scopedResTypes;
                    'Provisioning State'           = if ($data.provisioningState) { $data.provisioningState } else { 'N/A' };
                    'Resource U'                   = $ResUCount;
                    'Tag Name'                     = [string]$Tag.Name;
                    'Tag Value'                    = [string]$Tag.Value;
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
        $TableName = ('MonPLSTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Private Link Scope Name')
        $Exc.Add('Location')
        $Exc.Add('Access Mode')
        $Exc.Add('Ingestion Access Mode')
        $Exc.Add('Private Endpoint Connections')
        $Exc.Add('Scoped Resources Count')
        $Exc.Add('Scoped Resource Types')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Monitor Private Link Scopes' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
