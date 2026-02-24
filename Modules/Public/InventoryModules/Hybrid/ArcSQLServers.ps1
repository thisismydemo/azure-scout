<#
.Synopsis
Inventory for Arc-Enabled SQL Server Instances

.DESCRIPTION
This script consolidates information for all Arc-enabled SQL Server instances
(microsoft.azurearcdata/sqlserverinstances).
Excel Sheet Name: Arc SQL Servers

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Hybrid/ArcSQLServers.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $arcSQL = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurearcdata/sqlserverinstances' }

    if ($arcSQL) {
        $tmp = foreach ($1 in $arcSQL) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                        = $1.id;
                    'Subscription'              = $sub1.Name;
                    'Resource Group'            = $1.RESOURCEGROUP;
                    'Name'                      = $1.NAME;
                    'Location'                  = $1.LOCATION;
                    'Host Machine Name'         = if ($data.hostType)              { $data.hostType }              else { if ($data.azureDefenderStatus) { 'N/A' } else { 'N/A' } };
                    'SQL Version'               = if ($data.version)               { $data.version }               else { 'N/A' };
                    'Edition'                   = if ($data.edition)               { $data.edition }               else { 'N/A' };
                    'Licensing Type'            = if ($data.licenseType)           { $data.licenseType }           else { 'N/A' };
                    'vCores'                    = if ($data.vCore)                 { $data.vCore }                 else { 'N/A' };
                    'Patch Level'               = if ($data.patchLevel)            { $data.patchLevel }            else { 'N/A' };
                    'Collation'                 = if ($data.collation)             { $data.collation }             else { 'N/A' };
                    'Container Resource ID'     = if ($data.containerResourceId)   { ($data.containerResourceId -split '/')[-1] } else { 'N/A' };
                    'Azure Defender Status'     = if ($data.azureDefenderStatus)   { $data.azureDefenderStatus }   else { 'N/A' };
                    'Azure Defender Update Time'= if ($data.azureDefenderStatusLastUpdated) { ([datetime]$data.azureDefenderStatusLastUpdated).ToString('yyyy-MM-dd') } else { 'N/A' };
                    'Provisioning State'        = if ($data.provisioningState)     { $data.provisioningState }     else { 'N/A' };
                    'Resource U'                = $ResUCount;
                    'Tag Name'                  = [string]$Tag.Name;
                    'Tag Value'                 = [string]$Tag.Value;
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
        $TableName = ('ArcSQLServersTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('SQL Version')
        $Exc.Add('Edition')
        $Exc.Add('Licensing Type')
        $Exc.Add('vCores')
        $Exc.Add('Patch Level')
        $Exc.Add('Collation')
        $Exc.Add('Container Resource ID')
        $Exc.Add('Azure Defender Status')
        $Exc.Add('Azure Defender Update Time')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Arc SQL Servers' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
