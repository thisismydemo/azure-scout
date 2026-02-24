<#
.Synopsis
Inventory for Azure Monitor Scheduled Query Rules

.DESCRIPTION
This script consolidates information for all Azure Monitor log query-based alert rules.
Captures KQL queries, thresholds, severity, and action groups.
Excel Sheet Name: Scheduled Queries

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/ScheduledQueryRules.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $scheduledQueryRules = $Resources | Where-Object {$_.TYPE -eq 'microsoft.insights/scheduledqueryrules'}

    <######### Insert the resource Process here ########>

    if($scheduledQueryRules)
        {
            $tmp = foreach ($1 in $scheduledQueryRules) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Parse query and data sources
                $query = if ($data.criteria.allOf[0].query) {
                    $data.criteria.allOf[0].query
                } else { 'N/A' }

                $dataSources = @()
                if ($data.scopes) {
                    foreach ($scope in $data.scopes) {
                        $resourceName = ($scope -split '/')[-1]
                        $dataSources += $resourceName
                    }
                }
                $dataSourcesStr = if ($dataSources.Count -gt 0) { $dataSources -join ', ' } else { 'N/A' }

                # Parse conditions/criteria
                $conditions = @()
                if ($data.criteria.allOf) {
                    foreach ($condition in $data.criteria.allOf) {
                        $metricMeasureColumn = if ($condition.metricMeasureColumn) { $condition.metricMeasureColumn } else { 'N/A' }
                        $operator = $condition. operator
                        $threshold = $condition.threshold
                        $timeAggregation = if ($condition.timeAggregation) { $condition.timeAggregation } else { 'Count' }
                        $conditions += "$timeAggregation($metricMeasureColumn) $operator $threshold"
                    }
                }
                $conditionsStr = if ($conditions.Count -gt 0) { $conditions -join '; ' } else { 'N/A' }

                # Parse action groups
                $actionGroups = @()
                if ($data.actions.actionGroups) {
                    foreach ($ag in $data.actions.actionGroups) {
                        $agName = ($ag -split '/')[-1]
                        $actionGroups += $agName
                    }
                }
                $actionGroupStr = if ($actionGroups.Count -gt 0) { $actionGroups -join ', ' } else { 'None' }

                # Get severity
                $severity = switch ($data.severity) {
                    0 { 'Critical' }
                    1 { 'Error' }
                    2 { 'Warning' }
                    3 { 'Informational' }
                    4 { 'Verbose' }
                    default { $data.severity }
                }

                # Parse evaluation frequency and window
                $evaluationFrequency = if ($data.evaluationFrequency) {
                    $data.evaluationFrequency
                } else { 'PT5M' }
                $windowSize = if ($data.windowSize) {
                    $data.windowSize
                } else { 'PT5M' }

                # Get enabled status
                $enabled = if ($data.enabled -eq $true) { 'Enabled' } else { 'Disabled' }
                $autoMitigate = if ($data.autoMitigate -eq $true) { 'Yes' } else { 'No' }

                # Check if it's a legacy alert rule
                $isLegacy = if ($data.kind -eq 'LogAlert') { 'No' } else { 'Yes (migrate to new API)' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'Query Rule Name'           = $1.NAME;
                        'Description'               = if ($data.description) { $data.description } else { 'N/A' };
                        'Location'                  = $1.LOCATION;
                        'Status'                    = $enabled;
                        'Severity'                  = $severity;
                        'Query'                     = $query;
                        'Data Sources'              = $dataSourcesStr;
                        'Conditions'                = $conditionsStr;
                        'Evaluation Frequency'      = $evaluationFrequency;
                        'Window Size'               = $windowSize;
                        'Auto Mitigate'             = $autoMitigate;
                        'Action Groups'             = $actionGroupStr;
                        'Legacy Alert'              = $isLegacy;
                        'Resource U'                = $ResUCount;
                        'Tag Name'                  = [string]$Tag.Name;
                        'Tag Value'                 = [string]$Tag.Value
                    }
                    $obj
                    if ($ResUCount -eq 1) { $ResUCount = 0 }
                }
            }
            $tmp
        }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('ScheduledQueryTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range E:E,I:I,K:K -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Query Rule Name')
        $Exc.Add('Description')
        $Exc.Add('Location')
        $Exc.Add('Status')
        $Exc.Add('Severity')
        $Exc.Add('Query')
        $Exc.Add('Data Sources')
        $Exc.Add('Conditions')
        $Exc.Add('Evaluation Frequency')
        $Exc.Add('Window Size')
        $Exc.Add('Auto Mitigate')
        $Exc.Add('Action Groups')
        $Exc.Add('Legacy Alert')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Scheduled Queries' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
