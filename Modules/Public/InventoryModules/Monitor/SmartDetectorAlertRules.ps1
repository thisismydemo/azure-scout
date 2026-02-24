<#
.Synopsis
Inventory for Azure Monitor Smart Detector Alert Rules

.DESCRIPTION
This script consolidates information for all Smart Detector Alert Rules
(microsoft.alertsmanagement/smartdetectoralertrules).
Excel Sheet Name: Smart Detector Alerts

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/SmartDetectorAlertRules.ps1

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
    $smartAlerts = $Resources | Where-Object { $_.TYPE -eq 'microsoft.alertsmanagement/smartdetectoralertrules' }

    if ($smartAlerts) {
        $tmp = foreach ($1 in $smartAlerts) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Detector info
            $detectorId   = if ($data.detector) { $data.detector.id } else { 'N/A' }
            $detectorName = if ($data.detector) { $data.detector.name } else { 'N/A' }

            # Scope (target Application Insights / resource)
            $scopeResourceId = if ($data.scope) { $data.scope -join '; ' } else { 'N/A' }

            # Action groups
            $actionGroupStr = 'None'
            if ($data.actionGroups -and $data.actionGroups.groupIds) {
                $actionGroupStr = ($data.actionGroups.groupIds | ForEach-Object { ($_ -split '/')[-1] }) -join '; '
            }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                  = $1.id;
                    'Subscription'        = $sub1.Name;
                    'Resource Group'      = $1.RESOURCEGROUP;
                    'Alert Rule Name'     = $1.NAME;
                    'Location'            = $1.LOCATION;
                    'State'               = if ($data.state) { $data.state } else { 'N/A' };
                    'Severity'            = if ($data.severity) { $data.severity } else { 'N/A' };
                    'Frequency'           = if ($data.frequency) { $data.frequency } else { 'N/A' };
                    'Detector ID'         = $detectorId;
                    'Detector Name'       = $detectorName;
                    'Target Scope'        = $scopeResourceId;
                    'Action Groups'       = $actionGroupStr;
                    'Throttling Duration' = if ($data.throttlingDuration) { $data.throttlingDuration } else { 'PT0M' };
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
        $TableName = ('SmartAlertTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Alert Rule Name')
        $Exc.Add('Location')
        $Exc.Add('State')
        $Exc.Add('Severity')
        $Exc.Add('Frequency')
        $Exc.Add('Detector ID')
        $Exc.Add('Detector Name')
        $Exc.Add('Target Scope')
        $Exc.Add('Action Groups')
        $Exc.Add('Throttling Duration')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Smart Detector Alerts' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
