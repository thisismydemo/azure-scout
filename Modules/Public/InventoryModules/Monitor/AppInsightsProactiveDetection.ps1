<#
.Synopsis
Inventory for Application Insights Proactive Detection Configurations

.DESCRIPTION
This script retrieves Proactive Detection (Smart Detection) configurations
from all Application Insights components via the ARM REST API.
Excel Sheet Name: App Insights Proactive Detection

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/AppInsightsProactiveDetection.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $appInsights = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/components' }

    if ($appInsights) {
        $tmp = foreach ($ai in $appInsights) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ai.subscriptionId }

            $apiVersion  = '2018-05-01-preview'
            $uri = "/subscriptions/$($ai.subscriptionId)/resourceGroups/$($ai.RESOURCEGROUP)/providers/microsoft.insights/components/$($ai.NAME)/ProactiveDetectionConfigs?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $configs = $response.Content | ConvertFrom-Json
                    foreach ($1 in $configs) {
                        $ResUCount = 1
                        $obj = @{
                            'App Insights Name'             = $ai.NAME;
                            'Subscription'                  = $sub1.Name;
                            'Resource Group'                = $ai.RESOURCEGROUP;
                            'Rule Name'                     = if ($1.Name) { $1.Name } else { 'N/A' };
                            'Display Name'                  = if ($1.RuleDefinitions.DisplayName) { $1.RuleDefinitions.DisplayName } else { 'N/A' };
                            'Enabled'                       = if ($1.Enabled) { 'Yes' } else { 'No' };
                            'Send Email to Sub Owners'      = if ($1.SendEmailsToSubscriptionOwners) { 'Yes' } else { 'No' };
                            'Custom Emails'                 = if ($1.CustomEmails) { $1.CustomEmails -join '; ' } else { 'None' };
                            'Last Updated'                  = if ($1.LastUpdatedTime) { ([datetime]$1.LastUpdatedTime).ToString('yyyy-MM-dd') } else { 'N/A' };
                            'Resource U'                    = $ResUCount;
                            'Tag Name'                      = '';
                            'Tag Value'                     = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("AppInsightsProactiveDetection: Failed for $($ai.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('AIProDetTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('App Insights Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Rule Name')
        $Exc.Add('Display Name')
        $Exc.Add('Enabled')
        $Exc.Add('Send Email to Sub Owners')
        $Exc.Add('Custom Emails')
        $Exc.Add('Last Updated')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'App Insights Proactive Detection' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
