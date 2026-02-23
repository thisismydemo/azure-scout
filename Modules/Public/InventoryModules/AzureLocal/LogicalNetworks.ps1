<#
.Synopsis
Inventory for Azure Local Logical Networks

.DESCRIPTION
This script consolidates information for all microsoft.azurestackhci/logicalnetworks resource provider in $Resources variable.
Excel Sheet Name: AzLocal Networks

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AzureLocal/LogicalNetworks.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $hciNetworks = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurestackhci/logicalnetworks' }

    if ($hciNetworks) {
        $tmp = foreach ($1 in $hciNetworks) {
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

            # VM Switch Name
            $VMSwitchName = $data.vmSwitchName

            # Subnets
            $SubnetNames = if ($data.subnets) {
                ($data.subnets | ForEach-Object { $_.name }) -join ', '
            } else { $null }

            # First subnet details (primary subnet)
            $VLANID = if ($data.subnets -and $data.subnets[0].properties.vlan) {
                $data.subnets[0].properties.vlan
            } else { $null }

            $AddressPrefix = if ($data.subnets -and $data.subnets[0].properties.addressPrefix) {
                $data.subnets[0].properties.addressPrefix
            } else { $null }

            # IP Pool
            $IPPoolStart = $null
            $IPPoolEnd = $null
            if ($data.subnets -and $data.subnets[0].properties.ipAllocationMethod -eq 'Static' -and $data.subnets[0].properties.ipPools) {
                $IPPoolStart = $data.subnets[0].properties.ipPools[0].start
                $IPPoolEnd = $data.subnets[0].properties.ipPools[0].end
            }
            $IPPool = if ($IPPoolStart -and $IPPoolEnd) { "$IPPoolStart - $IPPoolEnd" } else { $null }

            # DHCP
            $DHCPEnabled = if ($data.subnets -and $data.subnets[0].properties.ipAllocationMethod -eq 'Dynamic') { 'Yes' } else { 'No' }

            # DNS Servers
            $DNSServers = if ($data.dhcpOptions.dnsServers) {
                $data.dhcpOptions.dnsServers -join ', '
            } else { $null }

            # Routes
            $Routes = if ($data.subnets -and $data.subnets[0].properties.routeTable.routes) {
                ($data.subnets[0].properties.routeTable.routes | ForEach-Object { '{0} -> {1}' -f $_.properties.addressPrefix, $_.properties.nextHopIpAddress }) -join '; '
            } else { $null }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                   = $1.id;
                    'Subscription'         = $sub1.name;
                    'Resource Group'       = $1.RESOURCEGROUP;
                    'Name'                 = $1.NAME;
                    'Location'             = $1.LOCATION;
                    'Retiring Feature'     = $RetiringFeature;
                    'Retiring Date'        = $RetiringDate;
                    'Provisioning State'   = $data.provisioningState;
                    'VM Switch Name'       = $VMSwitchName;
                    'Subnets'              = $SubnetNames;
                    'Address Prefix'       = $AddressPrefix;
                    'VLAN ID'              = $VLANID;
                    'DHCP Enabled'         = $DHCPEnabled;
                    'IP Pool'              = $IPPool;
                    'DNS Servers'          = $DNSServers;
                    'Routes'               = $Routes;
                    'Resource U'           = $ResUCount;
                    'Tag Name'             = [string]$Tag.Name;
                    'Tag Value'            = [string]$Tag.Value
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

        $TableName = ('AzLocalNetworks_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Provisioning State')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('VM Switch Name')
        $Exc.Add('Subnets')
        $Exc.Add('Address Prefix')
        $Exc.Add('VLAN ID')
        $Exc.Add('DHCP Enabled')
        $Exc.Add('IP Pool')
        $Exc.Add('DNS Servers')
        $Exc.Add('Routes')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'AzLocal Networks' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
