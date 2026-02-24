<#
.Synopsis
Inventory for Azure Monitor Metrics Ingestion Endpoints

.DESCRIPTION
This script inventories Data Collection Endpoints and Log Analytics Workspace
capacity/retention settings that govern metrics and log ingestion.
Excel Sheet Name: Monitor Metrics Ingestion

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/MonitorMetricsIngestion.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $workspaces = $Resources | Where-Object { $_.TYPE -eq 'microsoft.operationalinsights/workspaces' }

    if ($workspaces) {
        $tmp = foreach ($1 in $workspaces) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # SKU details
            $skuName        = if ($data.sku.name)                           { $data.sku.name }                           else { 'N/A' }
            $capResLevel    = if ($data.sku.capacityReservationLevel)       { $data.sku.capacityReservationLevel }       else { 'N/A' }

            # Retention
            $retentionDays  = if ($data.retentionInDays)                    { $data.retentionInDays }                    else { 'N/A' }

            # Daily cap
            $dailyQuotaGb   = if ($data.workspaceCapping.dailyQuotaGb -and $data.workspaceCapping.dailyQuotaGb -ne -1) {
                                  $data.workspaceCapping.dailyQuotaGb
                               } else { 'Unlimited' }
            $dataIngestionStatus = if ($data.workspaceCapping.dataIngestionStatus) { $data.workspaceCapping.dataIngestionStatus } else { 'N/A' }

            # Customer-managed key
            $cmkEnabled     = if ($data.features.enableDataExport -eq $true) { 'Yes' } else { 'No' }

            # Public network access
            $publicIngestion = if ($data.publicNetworkAccessForIngestion)   { $data.publicNetworkAccessForIngestion }   else { 'N/A' }
            $publicQuery     = if ($data.publicNetworkAccessForQuery)       { $data.publicNetworkAccessForQuery }       else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                          = $1.id;
                    'Subscription'                = $sub1.Name;
                    'Resource Group'              = $1.RESOURCEGROUP;
                    'Workspace Name'              = $1.NAME;
                    'Location'                    = $1.LOCATION;
                    'SKU'                         = $skuName;
                    'Capacity Reservation (GB/d)' = $capResLevel;
                    'Retention (days)'            = $retentionDays;
                    'Daily Cap (GB)'              = $dailyQuotaGb;
                    'Daily Cap Status'            = $dataIngestionStatus;
                    'Public Ingestion'            = $publicIngestion;
                    'Public Query'                = $publicQuery;
                    'Provisioning State'          = if ($data.provisioningState) { $data.provisioningState } else { 'N/A' };
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
        $TableName = ('MonitorMetricsIngTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Cond = New-ConditionalText -ConditionalType ContainsText  'Unlimited' -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,176,240)) -BackgroundColor ([System.Drawing.Color]::White)
        $Cond2 = New-ConditionalText -ConditionalType ContainsText 'CapReached' -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::FromArgb(255,0,0))
        $Cond3 = New-ConditionalText -ConditionalType ContainsText 'PerNodeNotAllowed' -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::FromArgb(255,165,0))

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Workspace Name')
        $Exc.Add('Location')
        $Exc.Add('SKU')
        $Exc.Add('Capacity Reservation (GB/d)')
        $Exc.Add('Retention (days)')
        $Exc.Add('Daily Cap (GB)')
        $Exc.Add('Daily Cap Status')
        $Exc.Add('Public Ingestion')
        $Exc.Add('Public Query')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Monitor Metrics Ingestion' `
            -AutoSize -MaxAutoSizeRows 100 `
            -ConditionalText $Cond, $Cond2, $Cond3 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
