<#
.Synopsis
Inventory for Application Insights Continuous Export

.DESCRIPTION
This script retrieves Continuous Export configurations from classic Application Insights
components via the ARM REST API.
Excel Sheet Name: App Insights Continuous Export

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/AppInsightsContinuousExport.ps1

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
    $appInsights = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/components' }

    if ($appInsights) {
        $tmp = foreach ($ai in $appInsights) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ai.subscriptionId }

            $apiVersion = '2015-05-01'
            $uri = "/subscriptions/$($ai.subscriptionId)/resourceGroups/$($ai.RESOURCEGROUP)/providers/microsoft.insights/components/$($ai.NAME)/exportconfiguration?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $exports = $response.Content | ConvertFrom-Json
                    foreach ($1 in $exports) {
                        $ResUCount = 1
                        $destStorageId = if ($1.DestinationStorageSubscriptionId) { $1.DestinationStorageSubscriptionId } else { 'N/A' }
                        $recordTypes   = if ($1.RecordTypes) { $1.RecordTypes -join ', ' } else { 'N/A' }

                        $obj = @{
                            'App Insights Name'            = $ai.NAME;
                            'Subscription'                 = $sub1.Name;
                            'Resource Group'               = $ai.RESOURCEGROUP;
                            'Export ID'                    = if ($1.ExportId)                           { $1.ExportId }                           else { 'N/A' };
                            'Is Enabled'                   = if ($1.IsUserEnabled)                      { 'Yes' }                                 else { 'No' };
                            'Destination Storage Sub'      = $destStorageId;
                            'Destination Storage Location' = if ($1.DestinationStorageLocationId)       { $1.DestinationStorageLocationId }       else { 'N/A' };
                            'Destination Account'          = if ($1.DestinationAccountId)               { $1.DestinationAccountId }               else { 'N/A' };
                            'Destination Container'        = if ($1.DestinationContainerId)             { $1.DestinationContainerId }             else { 'N/A' };
                            'Record Types'                 = $recordTypes;
                            'Export Status'                = if ($1.ExportStatus)                       { $1.ExportStatus }                       else { 'N/A' };
                            'Last Success Time'            = if ($1.LastSuccessTime)                    { $1.LastSuccessTime }                    else { 'N/A' };
                            'Resource U'                   = $ResUCount;
                            'Tag Name'                     = '';
                            'Tag Value'                    = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("AppInsightsContinuousExport: Failed for $($ai.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AIContinuousExportTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('App Insights Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Export ID')
        $Exc.Add('Is Enabled')
        $Exc.Add('Destination Storage Location')
        $Exc.Add('Destination Account')
        $Exc.Add('Destination Container')
        $Exc.Add('Record Types')
        $Exc.Add('Export Status')
        $Exc.Add('Last Success Time')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'App Insights Continuous Export' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
