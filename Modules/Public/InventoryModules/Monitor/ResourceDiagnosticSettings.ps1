<#
.Synopsis
Inventory for Azure Resource-Level Diagnostic Settings

.DESCRIPTION
This script consolidates information for all resource-level diagnostic settings
(Microsoft.Insights/diagnosticSettings) discovered in the tenant.
Captures log categories, metric categories, and destinations.
Excel Sheet Name: Resource Diagnostic Settings

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/ResourceDiagnosticSettings.ps1

.COMPONENT
This powershell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $diagSettings = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/diagnosticsettings' }

    if ($diagSettings) {
        $tmp = foreach ($1 in $diagSettings) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Parent resource name from ID (diagnostic settings are child resources)
            $parentResourceId = $1.id -replace '/providers/microsoft.insights/diagnosticsettings/[^/]+$', ''
            $parentResourceName = ($parentResourceId -split '/')[-1]
            $parentResourceType = if ($parentResourceId -match '/providers/([^/]+/[^/]+)/') { $matches[1] } else { 'Unknown' }

            # Enabled log categories
            $enabledLogs = @()
            $disabledLogs = @()
            if ($data.logs) {
                foreach ($log in $data.logs) {
                    if ($log.enabled) { $enabledLogs += $log.category } else { $disabledLogs += $log.category }
                }
            }

            # Enabled metric categories
            $enabledMetrics = @()
            if ($data.metrics) {
                foreach ($metric in $data.metrics) {
                    if ($metric.enabled) { $enabledMetrics += $metric.category }
                }
            }

            # Destinations
            $destLAW = if ($data.workspaceId) { ($data.workspaceId -split '/')[-1] } else { 'None' }
            $destStorage = if ($data.storageAccountId) { ($data.storageAccountId -split '/')[-1] } else { 'None' }
            $destEventHub = if ($data.eventHubName) { $data.eventHubName } elseif ($data.eventHubAuthorizationRuleId) { ($data.eventHubAuthorizationRuleId -split '/')[-3] } else { 'None' }
            $destPartner = if ($data.marketplacePartnerId) { $data.marketplacePartnerId } else { 'None' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                         = $1.id;
                    'Subscription'               = $sub1.Name;
                    'Resource Group'             = $1.RESOURCEGROUP;
                    'Diagnostic Setting Name'    = $1.NAME;
                    'Parent Resource Name'       = $parentResourceName;
                    'Parent Resource Type'       = $parentResourceType;
                    'Enabled Log Categories'     = $enabledLogs -join ', ';
                    'Disabled Log Categories'    = $disabledLogs -join ', ';
                    'Enabled Metric Categories'  = $enabledMetrics -join ', ';
                    'Destination: Log Analytics' = $destLAW;
                    'Destination: Storage'       = $destStorage;
                    'Destination: Event Hub'     = $destEventHub;
                    'Destination: Partner'       = $destPartner;
                    'Resource U'                 = $ResUCount;
                    'Tag Name'                   = [string]$Tag.Name;
                    'Tag Value'                  = [string]$Tag.Value;
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
        $TableName = ('ResDiagSettTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Diagnostic Setting Name')
        $Exc.Add('Parent Resource Name')
        $Exc.Add('Parent Resource Type')
        $Exc.Add('Enabled Log Categories')
        $Exc.Add('Disabled Log Categories')
        $Exc.Add('Enabled Metric Categories')
        $Exc.Add('Destination: Log Analytics')
        $Exc.Add('Destination: Storage')
        $Exc.Add('Destination: Event Hub')
        $Exc.Add('Destination: Partner')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Resource Diagnostic Settings' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
