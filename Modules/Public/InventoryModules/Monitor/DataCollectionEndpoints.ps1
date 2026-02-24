<#
.Synopsis
Inventory for Azure Monitor Data Collection Endpoints

.DESCRIPTION
This script consolidates information for all Azure Monitor Data Collection Endpoints (DCEs).
Captures ingestion endpoints, network access configurations, and associated DCRs.
Excel Sheet Name: Data Collection Endpoints

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/DataCollectionEndpoints.ps1

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

        $dceResources = $Resources | Where-Object {$_.TYPE -eq 'microsoft.insights/datacollectionendpoints'}

    <######### Insert the resource Process here ########>

    if($dceResources)
        {
            $tmp = foreach ($1 in $dceResources) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Get network access configuration
                $publicNetworkAccess = if ($data.networkAcls.publicNetworkAccess) {
                    $data.networkAcls.publicNetworkAccess
                } else { 'Enabled' }

                # Get configuration access endpoint
                $configAccessEndpoint = if ($data.configurationAccess.endpoint) {
                    $data.configurationAccess.endpoint
                } else { 'N/A' }

                # Get logs ingestion endpoint
                $logsIngestionEndpoint = if ($data.logsIngestion.endpoint) {
                    $data.logsIngestion.endpoint
                } else { 'N/A' }

                # Get metrics ingestion endpoint
                $metricsIngestionEndpoint = if ($data.metricsIngestion.endpoint) {
                    $data.metricsIngestion.endpoint
                } else { 'N/A' }

                # Get description
                $description = if ($data.description) { $data.description } else { 'N/A' }

                # Parse private link scope connections
                $privateLinkScopes = @()
                if ($data.privateLinkScopeResourceId) {
                    $plsName = ($data.privateLinkScopeResourceId -split '/')[-1]
                    $privateLinkScopes += $plsName
                }
                $privateLinkScopesStr = if ($privateLinkScopes.Count -gt 0) {
                    $privateLinkScopes -join ', '
                } else { 'None' }

                # Get failover configuration
                $failoverConfig = if ($data.failoverConfiguration) {
                    "Failover: $($data.failoverConfiguration.activeLocation)"
                } else { 'No failover configured' }

                # Get immutable ID
                $immutableId = if ($data.immutableId) { $data.immutableId } else { 'N/A' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'DCE Name'                  = $1.NAME;
                        'Description'               = $description;
                        'Location'                  = $1.LOCATION;
                        'Public Network Access'     = $publicNetworkAccess;
                        'Configuration Endpoint'    = $configAccessEndpoint;
                        'Logs Ingestion Endpoint'   = $logsIngestionEndpoint;
                        'Metrics Ingestion Endpoint'= $metricsIngestionEndpoint;
                        'Private Link Scopes'       = $privateLinkScopesStr;
                        'Failover Configuration'    = $failoverConfig;
                        'Immutable ID'              = $immutableId;
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

        $TableName = ('DataCollectionEndpointsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range E:E,H:J -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('DCE Name')
        $Exc.Add('Description')
        $Exc.Add('Location')
        $Exc.Add('Public Network Access')
        $Exc.Add('Configuration Endpoint')
        $Exc.Add('Logs Ingestion Endpoint')
        $Exc.Add('Metrics Ingestion Endpoint')
        $Exc.Add('Private Link Scopes')
        $Exc.Add('Failover Configuration')
        $Exc.Add('Immutable ID')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Data Collection Endpoints' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
