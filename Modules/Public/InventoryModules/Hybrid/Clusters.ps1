<#
.Synopsis
Inventory for Azure Local (Stack HCI) Clusters

.DESCRIPTION
This script consolidates information for all microsoft.azurestackhci/clusters resource provider in $Resources variable.
Excel Sheet Name: AzLocal Clusters

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AzureLocal/Clusters.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $hciClusters = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurestackhci/clusters' }

    if ($hciClusters) {
        $tmp = foreach ($1 in $hciClusters) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $Retired = $Retirements | Where-Object { $_.id -eq $1.id }
            if ($Retired) {
                $RetiredFeature = foreach ($Retire in $Retired) {
                    $RetiredServiceID = $Unsupported | Where-Object { $_.Id -eq $Retired.ServiceID }
                    [pscustomobject]@{
                        'RetiredFeature' = $RetiredServiceID.RetiringFeature
                        'RetiredDate'    = $RetiredServiceID.RetirementDate
                    }
                }
                $RetiringFeature = if ($RetiredFeature.RetiredFeature.count -gt 1) { $RetiredFeature.RetiredFeature | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredFeature }
                $RetiringFeature = [string]$RetiringFeature
                $RetiringFeature = if ($RetiringFeature -like '* ,*') { $RetiringFeature -replace ".$" } else { $RetiringFeature }

                $RetiringDate = if ($RetiredFeature.RetiredDate.count -gt 1) { $RetiredFeature.RetiredDate | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredDate }
                $RetiringDate = [string]$RetiringDate
                $RetiringDate = if ($RetiringDate -like '* ,*') { $RetiringDate -replace ".$" } else { $RetiringDate }
            }
            else {
                $RetiringFeature = $null
                $RetiringDate = $null
            }

            # Parse last sync time
            $LastSync = if (![string]::IsNullOrEmpty($data.lastSyncTimestamp)) {
                $ts = [datetime]$data.lastSyncTimestamp
                $ts.ToString("yyyy-MM-dd HH:mm")
            } else { $null }

            # Parse last billing sync
            $LastBillingSync = if (![string]::IsNullOrEmpty($data.lastBillingTimestamp)) {
                $ts = [datetime]$data.lastBillingTimestamp
                $ts.ToString("yyyy-MM-dd HH:mm")
            } else { $null }

            # Node count from reported properties
            $NodeCount = if ($data.reportedProperties.clusterNodes) {
                $data.reportedProperties.clusterNodes.Count
            } else { $null }

            # OS version from reported properties
            $OSVersion = if ($data.reportedProperties.clusterVersion) {
                $data.reportedProperties.clusterVersion
            } else { $null }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                    = $1.id;
                    'Subscription'          = $sub1.name;
                    'Resource Group'        = $1.RESOURCEGROUP;
                    'Name'                  = $1.NAME;
                    'Location'              = $1.LOCATION;
                    'Retiring Feature'      = $RetiringFeature;
                    'Retiring Date'         = $RetiringDate;
                    'Status'                = $data.status;
                    'Cloud Id'              = $data.cloudId;
                    'Service Endpoint'      = $data.serviceEndpoint;
                    'Cluster Version'       = $OSVersion;
                    'OS Version'            = $data.reportedProperties.osName;
                    'Node Count'            = $NodeCount;
                    'Last Sync'             = $LastSync;
                    'Last Billing Sync'     = $LastBillingSync;
                    'Connectivity Status'   = $data.connectivityStatus;
                    'Provisioning State'    = $data.provisioningState;
                    'Cloud Management'      = $data.cloudManagementEndpoint;
                    'Desired Properties'    = [string]$data.desiredProperties.windowsServerSubscription;
                    'Diagnostics Level'     = [string]$data.desiredProperties.diagnosticLevel;
                    'Resource U'            = $ResUCount;
                    'Tag Name'              = [string]$Tag.Name;
                    'Tag Value'             = [string]$Tag.Value
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

<######## Resource Excel Reporting Begins Here ########>

Else {
    if ($SmaResources) {

        $TableName = ('AzLocalClusters_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText
        $condtxt += New-ConditionalText 'ConnectedRecently' -Range O:O
        $condtxt += New-ConditionalText 'Disconnected' -Range O:O
        $condtxt += New-ConditionalText 'NotYet' -Range O:O

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Status')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Cloud Id')
        $Exc.Add('Cluster Version')
        $Exc.Add('OS Version')
        $Exc.Add('Node Count')
        $Exc.Add('Last Sync')
        $Exc.Add('Last Billing Sync')
        $Exc.Add('Connectivity Status')
        $Exc.Add('Provisioning State')
        $Exc.Add('Cloud Management')
        $Exc.Add('Desired Properties')
        $Exc.Add('Diagnostics Level')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'AzLocal Clusters' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
