<#
.Synopsis
Inventory for Azure Monitor Activity Log Alert Rules

.DESCRIPTION
This script consolidates information for all Activity Log Alert rules
(microsoft.insights/activitylogalerts).
Excel Sheet Name: Activity Log Alerts

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/ActivityLogAlertRules.ps1

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
    $alerts = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/activitylogalerts' }

    if ($alerts) {
        $tmp = foreach ($1 in $alerts) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Scopes
            $scopes = if ($data.scopes) { $data.scopes -join '; ' } else { 'N/A' }

            # Condition — extract key filters
            $condCategory = ''
            $condOperationName = ''
            $condLevel = ''
            $condStatus = ''
            $condResourceType = ''
            if ($data.condition -and $data.condition.allOf) {
                foreach ($filter in $data.condition.allOf) {
                    switch ($filter.field) {
                        'category'      { $condCategory      = $filter.equals }
                        'operationName' { $condOperationName = $filter.equals }
                        'level'         { $condLevel         = $filter.equals }
                        'status'        { $condStatus        = $filter.equals }
                        'resourceType'  { $condResourceType  = $filter.equals }
                    }
                }
            }

            # Action groups
            $actionGroupIds = @()
            if ($data.actions -and $data.actions.actionGroups) {
                $actionGroupIds = $data.actions.actionGroups | ForEach-Object {
                    ($_.actionGroupId -split '/')[-1]
                }
            }
            $actionGroupStr = if ($actionGroupIds.Count -gt 0) { $actionGroupIds -join '; ' } else { 'None' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                  = $1.id;
                    'Subscription'        = $sub1.Name;
                    'Resource Group'      = $1.RESOURCEGROUP;
                    'Alert Name'          = $1.NAME;
                    'Location'            = $1.LOCATION;
                    'Enabled'             = if ($data.enabled) { 'Yes' } else { 'No' };
                    'Description'         = if ($data.description) { $data.description } else { '' };
                    'Scopes'              = $scopes;
                    'Category'            = $condCategory;
                    'Operation Name'      = $condOperationName;
                    'Level'               = $condLevel;
                    'Status'              = $condStatus;
                    'Resource Type Filter'= $condResourceType;
                    'Action Groups'       = $actionGroupStr;
                    'Resource U'          = $ResUCount;
                    'Tag Name'            = [string]$Tag.Name;
                    'Tag Value'           = [string]$Tag.Value;
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
        $TableName = ('ActLogAlertTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Alert Name')
        $Exc.Add('Location')
        $Exc.Add('Enabled')
        $Exc.Add('Description')
        $Exc.Add('Scopes')
        $Exc.Add('Category')
        $Exc.Add('Operation Name')
        $Exc.Add('Level')
        $Exc.Add('Status')
        $Exc.Add('Resource Type Filter')
        $Exc.Add('Action Groups')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Activity Log Alerts' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
