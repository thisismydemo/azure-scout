<#
.Synopsis
Inventory for Application Insights Work Item Integrations

.DESCRIPTION
This script retrieves Work Item Integration configurations from Application Insights
components via the ARM REST API (microsoft.insights/workitemconfigurations).
Excel Sheet Name: App Insights Work Items

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/AppInsightsWorkItems.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

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
            $uri = "/subscriptions/$($ai.subscriptionId)/resourceGroups/$($ai.RESOURCEGROUP)/providers/microsoft.insights/components/$($ai.NAME)/WorkItemConfigs?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $items = ($response.Content | ConvertFrom-Json).value
                    if (-not $items) { $items = $response.Content | ConvertFrom-Json }
                    foreach ($1 in $items) {
                        $ResUCount = 1
                        $obj = @{
                            'App Insights Name'    = $ai.NAME;
                            'Subscription'         = $sub1.Name;
                            'Resource Group'       = $ai.RESOURCEGROUP;
                            'Config ID'            = if ($1.Id)                 { $1.Id }                 else { 'N/A' };
                            'Config Display Name'  = if ($1.ConfigDisplayName)  { $1.ConfigDisplayName }  else { 'N/A' };
                            'Is Default'           = if ($1.IsDefault)          { 'Yes' }                 else { 'No' };
                            'Config Properties'    = if ($1.ConfigProperties)   { $1.ConfigProperties }   else { 'N/A' };
                            'Resource U'           = $ResUCount;
                            'Tag Name'             = '';
                            'Tag Value'            = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("AppInsightsWorkItems: Failed for $($ai.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AIWorkItemsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('App Insights Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Config ID')
        $Exc.Add('Config Display Name')
        $Exc.Add('Is Default')
        $Exc.Add('Config Properties')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'App Insights Work Items' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
