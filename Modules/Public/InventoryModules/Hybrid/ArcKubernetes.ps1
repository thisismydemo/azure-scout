<#
.Synopsis
Inventory for Azure Arc-enabled Kubernetes Clusters

.DESCRIPTION
This script consolidates information for all microsoft.kubernetes/connectedclusters resource provider in $Resources variable.
Excel Sheet Name: Arc Kubernetes

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Hybrid/ArcKubernetes.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $arcK8s = $Resources | Where-Object { $_.TYPE -eq 'microsoft.kubernetes/connectedclusters' }

    if ($arcK8s) {
        $tmp = foreach ($1 in $arcK8s) {
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

            # Identity
            $IdentityType = if ($1.identity) { $1.identity.type } else { $null }

            # Last connectivity time
            $LastConnectivity = if ($data.lastConnectivityTime) {
                [string](get-date($data.lastConnectivityTime) -Format 'yyyy-MM-dd HH:mm')
            } else { $null }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                     = $1.id;
                    'Subscription'           = $sub1.name;
                    'Resource Group'         = $1.RESOURCEGROUP;
                    'Name'                   = $1.NAME;
                    'Location'               = $1.LOCATION;
                    'Retiring Feature'       = $RetiringFeature;
                    'Retiring Date'          = $RetiringDate;
                    'Provisioning State'     = $data.provisioningState;
                    'Connectivity Status'    = $data.connectivityStatus;
                    'Distribution'           = $data.distribution;
                    'Distribution Version'   = $data.distributionVersion;
                    'Kubernetes Version'     = $data.kubernetesVersion;
                    'Total Node Count'       = $data.totalNodeCount;
                    'Agent Version'          = $data.agentVersion;
                    'Offering'               = $data.offering;
                    'Infrastructure'         = $data.infrastructure;
                    'Identity Type'          = $IdentityType;
                    'Last Connectivity'      = $LastConnectivity;
                    'Resource U'             = $ResUCount;
                    'Tag Name'               = [string]$Tag.Name;
                    'Tag Value'              = [string]$Tag.Value
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

        $TableName = ('ArcK8s_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText
        $condtxt += New-ConditionalText Disconnected -Range H:H
        $condtxt += New-ConditionalText Expired -Range H:H

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Provisioning State')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Connectivity Status')
        $Exc.Add('Distribution')
        $Exc.Add('Distribution Version')
        $Exc.Add('Kubernetes Version')
        $Exc.Add('Total Node Count')
        $Exc.Add('Agent Version')
        $Exc.Add('Offering')
        $Exc.Add('Infrastructure')
        $Exc.Add('Identity Type')
        $Exc.Add('Last Connectivity')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Arc Kubernetes' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
