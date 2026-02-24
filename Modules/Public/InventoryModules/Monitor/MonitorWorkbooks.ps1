<#
.Synopsis
Inventory for Azure Monitor Workbooks

.DESCRIPTION
This script consolidates information for all Azure Monitor Workbooks
(microsoft.insights/workbooks).
Excel Sheet Name: Monitor Workbooks

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/MonitorWorkbooks.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $workbooks = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/workbooks' }

    if ($workbooks) {
        $tmp = foreach ($1 in $workbooks) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $sourceId  = if ($data.sourceId)  { $data.sourceId }  else { 'N/A' }
            $linkedRes = if ($sourceId -ne 'N/A' -and $sourceId -ne 'azure monitor') { ($sourceId -split '/')[-1] } else { $sourceId }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'               = $1.id;
                    'Subscription'     = $sub1.Name;
                    'Resource Group'   = $1.RESOURCEGROUP;
                    'Workbook Name'    = $1.NAME;
                    'Location'         = $1.LOCATION;
                    'Display Name'     = if ($data.displayName) { $data.displayName } else { $1.NAME };
                    'Category'         = if ($data.category)    { $data.category }    else { 'N/A' };
                    'Kind'             = if ($1.KIND)            { $1.KIND }           else { 'N/A' };
                    'Source Resource'  = $linkedRes;
                    'Source ID'        = $sourceId;
                    'Version'          = if ($data.version)     { $data.version }     else { 'N/A' };
                    'Time Modified'    = if ($data.timeModified) { ([datetime]$data.timeModified).ToString("yyyy-MM-dd") } else { 'N/A' };
                    'Resource U'       = $ResUCount;
                    'Tag Name'         = [string]$Tag.Name;
                    'Tag Value'        = [string]$Tag.Value;
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
        $TableName = ('MonWorkbooksTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Workbook Name')
        $Exc.Add('Location')
        $Exc.Add('Display Name')
        $Exc.Add('Category')
        $Exc.Add('Kind')
        $Exc.Add('Source Resource')
        $Exc.Add('Version')
        $Exc.Add('Time Modified')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Monitor Workbooks' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
