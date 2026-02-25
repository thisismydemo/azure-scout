<#
.Synopsis
Inventory for Azure Network Connections

.DESCRIPTION
This script consolidates information for all microsoft.network/connections and  resource provider in $Resources variable.
Excel Sheet Name: Connections

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Network_1/Connections.ps1

.COMPONENT
This powershell Module is part of Azure Scout (AZSC)

.NOTES
Version: 3.6.0
First Release Date: 19th November, 2020
Authors: Claudio Merola and Renato Gregio

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $connections = $Resources | Where-Object {$_.TYPE -eq 'microsoft.network/connections'}

    <######### Insert the resource Process here ########>

    if($connections)
        {
            $tmp = foreach ($1 in $connections) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Retired = $Retirements | Where-Object { $_.id -eq $1.id }
                if ($Retired)
                    {
                        $RetiredFeature = foreach ($Retire in $Retired)
                            {
                                $RetiredServiceID = $Unsupported | Where-Object {$_.Id -eq $Retired.ServiceID}
                                $tmp0 = [pscustomobject]@{
                                        'RetiredFeature'            = $RetiredServiceID.RetiringFeature
                                        'RetiredDate'               = $RetiredServiceID.RetirementDate
                                    }
                                $tmp0
                            }
                        $RetiringFeature = if ($RetiredFeature.RetiredFeature.count -gt 1) { $RetiredFeature.RetiredFeature | ForEach-Object { $_ + ' ,' } }else { $RetiredFeature.RetiredFeature}
                        $RetiringFeature = [string]$RetiringFeature
                        $RetiringFeature = if ($RetiringFeature -like '* ,*') { $RetiringFeature -replace ".$" }else { $RetiringFeature }

                        $RetiringDate = if ($RetiredFeature.RetiredDate.count -gt 1) { $RetiredFeature.RetiredDate | ForEach-Object { $_ + ' ,' } }else { $RetiredFeature.RetiredDate}
                        $RetiringDate = [string]$RetiringDate
                        $RetiringDate = if ($RetiringDate -like '* ,*') { $RetiringDate -replace ".$" }else { $RetiringDate }
                    }
                else
                    {
                        $RetiringFeature = $null
                        $RetiringDate = $null
                    }
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # IPsec Policy (first policy if multiple)
                $ipsecPolicy = if ($data.ipsecPolicies -and $data.ipsecPolicies.count -gt 0) { $data.ipsecPolicies[0] } else { $null }
                $IPsecEncryption = if ($ipsecPolicy) { $ipsecPolicy.ipsecEncryption } else { $null }
                $IPsecIntegrity = if ($ipsecPolicy) { $ipsecPolicy.ipsecIntegrity } else { $null }
                $IKEEncryption = if ($ipsecPolicy) { $ipsecPolicy.ikeEncryption } else { $null }
                $IKEIntegrity = if ($ipsecPolicy) { $ipsecPolicy.ikeIntegrity } else { $null }
                $DHGroup = if ($ipsecPolicy) { $ipsecPolicy.dhGroup } else { $null }
                $PFSGroup = if ($ipsecPolicy) { $ipsecPolicy.pfsGroup } else { $null }
                $SALifetime = if ($ipsecPolicy) { $ipsecPolicy.saLifeTimeSeconds } else { $null }
                $SADataSize = if ($ipsecPolicy) { $ipsecPolicy.saDataSizeKilobytes } else { $null }

                # Traffic selectors
                $TrafficSelectors = if ($data.trafficSelectorPolicies -and $data.trafficSelectorPolicies.count -gt 0) {
                    ($data.trafficSelectorPolicies | ForEach-Object {
                        'Local:' + ($_.localAddressRanges -join ',') + ' Remote:' + ($_.remoteAddressRanges -join ',')
                    }) -join '; '
                } else { $null }

                # Shared Key - boolean only, NEVER log the actual key
                $SharedKeySet = if ($data.sharedKey) { 'Yes' } else { 'No' }

                    foreach ($Tag in $Tags) {
                        $obj = @{
                            'ID'                       = $1.id;
                            'Subscription'             = $sub1.name;
                            'Resource Group'           = $1.RESOURCEGROUP;
                            'Name'                     = $1.NAME;
                            'Location'                 = $1.LOCATION;
                            'Retiring Feature'         = $RetiringFeature;
                            'Retiring Date'            = $RetiringDate;
                            'Type'                     = $data.connectionType;
                            'Status'                   = $data.connectionStatus;
                            'Connection Protocol'      = $data.connectionProtocol;
                            'Routing Weight'           = $data.routingWeight;
                            'connectionMode'           = $data.connectionMode;
                            'IPsec Encryption'         = $IPsecEncryption;
                            'IPsec Integrity'          = $IPsecIntegrity;
                            'IKE Encryption'           = $IKEEncryption;
                            'IKE Integrity'            = $IKEIntegrity;
                            'DH Group'                 = $DHGroup;
                            'PFS Group'                = $PFSGroup;
                            'SA Lifetime (sec)'        = $SALifetime;
                            'SA Data Size (KB)'        = $SADataSize;
                            'Use Policy-Based TS'      = $data.usePolicyBasedTrafficSelectors;
                            'Traffic Selectors'        = $TrafficSelectors;
                            'DPD Timeout (sec)'        = $data.dpdTimeoutSeconds;
                            'Ingress Bytes'            = $data.ingressBytesTransferred;
                            'Egress Bytes'             = $data.egressBytesTransferred;
                            'Shared Key Set'           = $SharedKeySet;
                            'Resource U'               = $ResUCount;
                            'Tag Name'                 = [string]$Tag.Name;
                            'Tag Value'                = [string]$Tag.Value
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
        $TableName = ('Connections_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        #Retirement
        $condtxt += New-ConditionalText -Range E2:E100 -ConditionalType ContainsText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Type')
        $Exc.Add('Status')
        $Exc.Add('Connection Protocol')
        $Exc.Add('Routing Weight')
        $Exc.Add('connectionMode')
        $Exc.Add('IPsec Encryption')
        $Exc.Add('IPsec Integrity')
        $Exc.Add('IKE Encryption')
        $Exc.Add('IKE Integrity')
        $Exc.Add('DH Group')
        $Exc.Add('PFS Group')
        $Exc.Add('SA Lifetime (sec)')
        $Exc.Add('SA Data Size (KB)')
        $Exc.Add('Use Policy-Based TS')
        $Exc.Add('Traffic Selectors')
        $Exc.Add('DPD Timeout (sec)')
        $Exc.Add('Ingress Bytes')
        $Exc.Add('Egress Bytes')
        $Exc.Add('Shared Key Set')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Connections' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style -ConditionalText $condtxt
    }
}
