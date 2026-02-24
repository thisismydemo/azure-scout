<#
.Synopsis
Inventory for Azure Monitor Data Collection Rules

.DESCRIPTION
This script consolidates information for all Azure Monitor Data Collection Rules (DCRs).
Captures data sources, destinations, transformations, and associations.
Excel Sheet Name: Data Collection Rules

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/DataCollectionRules.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $dcrResources = $Resources | Where-Object {$_.TYPE -eq 'microsoft.insights/datacollectionrules'}

    <######### Insert the resource Process here ########>

    if($dcrResources)
        {
            $tmp = foreach ($1 in $dcrResources) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Parse data sources
                $dataSources = @()
                if ($data.dataSources) {
                    if ($data.dataSources.performanceCounters) {
                        foreach ($pc in $data.dataSources.performanceCounters) {
                            $dataSources += "Performance Counters ($($pc.name))"
                        }
                    }
                    if ($data.dataSources.windowsEventLogs) {
                        foreach ($wel in $data.dataSources.windowsEventLogs) {
                            $dataSources += "Windows Event Logs ($($wel.name))"
                        }
                    }
                    if ($data.dataSources.syslog) {
                        foreach ($syslog in $data.dataSources.syslog) {
                            $dataSources += "Syslog ($($syslog.name))"
                        }
                    }
                    if ($data.dataSources.extensions) {
                        foreach ($ext in $data.dataSources.extensions) {
                            $dataSources += "Extension: $($ext.extensionName)"
                        }
                    }
                }
                $dataSourcesStr = if ($dataSources.Count -gt 0) { $dataSources -join '; ' } else { 'None' }

                # Parse destinations
                $destinations = @()
                if ($data.destinations) {
                    if ($data.destinations.logAnalytics) {
                        foreach ($la in $data.destinations.logAnalytics) {
                            $workspaceName = ($la.workspaceResourceId -split '/')[-1]
                            $destinations += "Log Analytics: $workspaceName"
                        }
                    }
                    if ($data.destinations.azureMonitorMetrics) {
                        $destinations += "Azure Monitor Metrics"
                    }
                    if ($data.destinations.eventHub) {
                        foreach ($eh in $data.destinations.eventHub) {
                            $ehName = ($eh.eventHubResourceId -split '/')[-1]
                            $destinations += "Event Hub: $ehName"
                        }
                    }
                    if ($data.destinations.storageAccounts) {
                        foreach ($sa in $data.destinations.storageAccounts) {
                            $saName = ($sa.storageAccountResourceId -split '/')[-1]
                            $destinations += "Storage: $saName"
                        }
                    }
                }
                $destinationsStr = if ($destinations.Count -gt 0) { $destinations -join '; ' } else { 'None' }

                # Parse data flows
                $dataFlows = @()
                if ($data.dataFlows) {
                    foreach ($flow in $data.dataFlows) {
                        $streams = if ($flow.streams) { $flow.streams -join ', ' } else { 'N/A' }
                        $dest = if ($flow.destinations) { $flow.destinations -join ', ' } else { 'N/A' }
                        $dataFlows += "Streams: $streams -> Dest: $dest"
                    }
                }
                $dataFlowsStr = if ($dataFlows.Count -gt 0) { $dataFlows -join '; ' } else { 'None' }

                # Parse transformations (KQL)
                $transformations = 'None'
                if ($data.dataFlows) {
                    $hasTransform = $false
                    foreach ($flow in $data.dataFlows) {
                        if ($flow.transformKql) {
                            $hasTransform = $true
                            break
                        }
                    }
                    if ($hasTransform) {
                        $transformations = 'Yes (KQL transformations applied)'
                    }
                }

                # Get data collection endpoint
                $dce = 'None'
                if ($data.dataCollectionEndpointId) {
                    $dce = ($data.dataCollectionEndpointId -split '/')[-1]
                }

                # Get description
                $description = if ($data.description) { $data.description } else { 'N/A' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'DCR Name'                  = $1.NAME;
                        'Description'               = $description;
                        'Location'                  = $1.LOCATION;
                        'Data Sources'              = $dataSourcesStr;
                        'Destinations'              = $destinationsStr;
                        'Data Flows'                = $dataFlowsStr;
                        'Transformations'           = $transformations;
                        'Data Collection Endpoint'  = $dce;
                        'Immutable ID'              = if ($data.immutableId) { $data.immutableId } else { 'N/A' };
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

        $TableName = ('DataCollectionRulesTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range E:E,G:I -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('DCR Name')
        $Exc.Add('Description')
        $Exc.Add('Location')
        $Exc.Add('Data Sources')
        $Exc.Add('Destinations')
        $Exc.Add('Data Flows')
        $Exc.Add('Transformations')
        $Exc.Add('Data Collection Endpoint')
        $Exc.Add('Immutable ID')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Data Collection Rules' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
