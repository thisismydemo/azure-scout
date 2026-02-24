<#
.Synopsis
Inventory for Azure Monitor Metric Alert Rules

.DESCRIPTION
This script consolidates information for all Azure Monitor metric-based alert rules.
Captures threshold conditions, severity, evaluation frequency, and action groups.
Excel Sheet Name: Metric Alerts

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/MetricAlertRules.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $metricAlerts = $Resources | Where-Object {$_.TYPE -eq 'microsoft.insights/metricalerts'}

    <######### Insert the resource Process here ########>

    if($metricAlerts)
        {
            $tmp = foreach ($1 in $metricAlerts) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Parse criteria
                $criteria = $data.criteria
                $criteriaType = if ($criteria.'odata.type') {
                    $criteria.'odata.type' -replace 'Microsoft.Azure.Monitor.', ''
                } else { 'SingleResourceMultipleMetricCriteria' }

                # Parse conditions
                $conditions = @()
                if ($criteria.allOf) {
                    foreach ($condition in $criteria.allOf) {
                        $metricName = $condition.metricName
                        $operator = $condition.operator
                        $threshold = $condition.threshold
                        $timeAggregation = $condition.timeAggregation
                        $conditions += "$metricName $operator $threshold ($timeAggregation)"
                    }
                }
                $conditionsStr = if ($conditions.Count -gt 0) { $conditions -join '; ' } else { 'N/A' }

                # Parse target resources
                $targetResources = @()
                if ($data.scopes) {
                    foreach ($scope in $data.scopes) {
                        $resourceName = ($scope -split '/')[-1]
                        $targetResources += $resourceName
                    }
                }
                $targetStr = if ($targetResources.Count -gt 0) { $targetResources -join ', ' } else { 'N/A' }

                # Parse action groups
                $actionGroups = @()
                if ($data.actions) {
                    foreach ($action in $data.actions) {
                        if ($action.actionGroupId) {
                            $agName = ($action.actionGroupId -split '/')[-1]
                            $actionGroups += $agName
                        }
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
                } else { 'PT1M' }
                $windowSize = if ($data.windowSize) {
                    $data.windowSize
                } else { 'PT5M' }

                # Get enabled status
                $enabled = if ($data.enabled -eq $true) { 'Enabled' } else { 'Disabled' }
                $autoMitigate = if ($data.autoMitigate -eq $true) { 'Yes' } else { 'No' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'Alert Rule Name'           = $1.NAME;
                        'Description'               = if ($data.description) { $data.description } else { 'N/A' };
                        'Location'                  = $1.LOCATION;
                        'Status'                    = $enabled;
                        'Severity'                  = $severity;
                        'Criteria Type'             = $criteriaType;
                        'Conditions'                = $conditionsStr;
                        'Target Resources'          = $targetStr;
                        'Target Resource Type'      = if ($data.targetResourceType) { $data.targetResourceType } else { 'N/A' };
                        'Evaluation Frequency'      = $evaluationFrequency;
                        'Window Size'               = $windowSize;
                        'Auto Mitigate'             = $autoMitigate;
                        'Action Groups'             = $actionGroupStr;
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

        $TableName = ('MetricAlertsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range E:E,J:J,K:K -Width 40 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Alert Rule Name')
        $Exc.Add('Description')
        $Exc.Add('Location')
        $Exc.Add('Status')
        $Exc.Add('Severity')
        $Exc.Add('Criteria Type')
        $Exc.Add('Conditions')
        $Exc.Add('Target Resources')
        $Exc.Add('Target Resource Type')
        $Exc.Add('Evaluation Frequency')
        $Exc.Add('Window Size')
        $Exc.Add('Auto Mitigate')
        $Exc.Add('Action Groups')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Metric Alerts' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
