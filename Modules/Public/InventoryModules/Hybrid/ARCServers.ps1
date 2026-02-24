<#
.Synopsis
Inventory for Azure ARC Servers

.DESCRIPTION
This script consolidates information for all microsoft.hybridcompute/machines and  resource provider in $Resources variable. 
Excel Sheet Name: EvHub

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Hybrid/ARCServers.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

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

        $arcservers = $Resources | Where-Object {$_.TYPE -eq 'microsoft.hybridcompute/machines'}

    <######### Insert the resource Process here ########>

    if($arcservers)
        {
            $tmp = foreach ($1 in $arcservers) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                $Retired = Foreach ($Retirement in $Retirements)
                    {
                        if ($Retirement.id -eq $1.id) { $Retirement }
                    }
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
                if($data.networkprofile.networkinterfaces.ipaddresses.count -gt 1)
                    {
                        $IPTemp = @()
                        $SubnetTemp = @()
                        foreach ($IPaddresses in $data.networkprofile.networkinterfaces.ipaddresses)
                            {
                                $IPTemp += $IPaddresses.address
                                $SubnetTemp += $IPaddresses.subnet.addressprefix
                            }
                        $IP = if ($IPTemp.count -gt 1) { $IPTemp | ForEach-Object { $_ + ' ,' } }else { $IPTemp }
                        $IP = [string]$IP
                        $IP = if ($IP -like '* ,*') { $IP -replace ".$" }else { $IP }

                        $Subnet = if ($SubnetTemp.count -gt 1) { $SubnetTemp | ForEach-Object { $_ + ' ,' } }else { $SubnetTemp }
                        $Subnet = [string]$Subnet
                        $Subnet = if ($Subnet -like '* ,*') { $Subnet -replace ".$" }else { $Subnet }
                    }
                else
                    {
                        $IP = $data.networkprofile.networkinterfaces.ipaddresses.address
                        $Subnet = $data.networkprofile.networkinterfaces.ipaddresses.subnet.addressprefix
                    }

                    if(![string]::IsNullOrEmpty($data.laststatuschange))
                        {
                            $LastStatus = $data.laststatuschange
                            $LastStatus = [datetime]$LastStatus
                            $LastStatus = $LastStatus.ToString("yyyy-MM-dd HH:mm")
                        }
                    else
                        {
                            $LastStatus = $null
                        }

                    if(![string]::IsNullOrEmpty($data.osinstalldate))
                        {
                            $InstallDate = $data.osinstalldate
                            $InstallDate = [datetime]$InstallDate
                            $InstallDate = $InstallDate.ToString("yyyy-MM-dd HH:mm")
                        }
                    else
                        {
                            $InstallDate = $null
                        }

                    # ── Phase 17.2.6: Policies Applied ───────────────────────────────
                    $policyCount    = 'N/A'
                    $policyCompliant = 'N/A'
                    try {
                        $policyUri  = "/subscriptions/$($1.subscriptionId)/providers/Microsoft.PolicyInsights/policyStates/latest/queryResults?api-version=2019-10-01&`$filter=resourceId eq '$($1.id)'&`$top=100"
                        $policyResp = Invoke-AzRestMethod -Path $policyUri -Method POST -Payload '{}' -ErrorAction SilentlyContinue
                        if ($policyResp.StatusCode -eq 200) {
                            $pData       = $policyResp.Content | ConvertFrom-Json
                            $states      = $pData.value
                            $policyCount = @($states).Count
                            $nonCompliant = @($states | Where-Object { $_.complianceState -eq 'NonCompliant' }).Count
                            $policyCompliant = if ($nonCompliant -eq 0) { 'Compliant' } else { "$nonCompliant NonCompliant" }
                        }
                    } catch {}

                    # ── Phase 17.2.7: Performance Metrics ────────────────────────────
                    $arcAvgCpu = 'N/A'
                    $arcAvgMem = 'N/A'
                    try {
                        $monEnd2   = (Get-Date).ToUniversalTime().ToString('o')
                        $monStart2 = (Get-Date).AddDays(-7).ToUniversalTime().ToString('o')
                        $arcCpuUri = "/subscriptions/$($1.subscriptionId)/resourceGroups/$($1.RESOURCEGROUP)/providers/Microsoft.HybridCompute/machines/$($1.NAME)/providers/microsoft.insights/metrics?api-version=2019-07-01&metricnames=cpu_usage_active&timespan=$monStart2/$monEnd2&interval=P1D&aggregation=Average"
                        $arcCpuResp = Invoke-AzRestMethod -Path $arcCpuUri -Method GET -ErrorAction SilentlyContinue
                        if ($arcCpuResp.StatusCode -eq 200) {
                            $arcCpuData = $arcCpuResp.Content | ConvertFrom-Json
                            $arcCpuVals = $arcCpuData.value[0].timeseries[0].data.average | Where-Object { $_ -ne $null }
                            if ($arcCpuVals) { $arcAvgCpu = [math]::Round(($arcCpuVals | Measure-Object -Average).Average, 1) }
                        }
                    } catch {}

                    # ── Phase 17.2.9: Cost / ESU Tracking ─────────────────────────────
                    $esuEnabled     = if ($data.licenseprofile.esuprofile.servertype) { $true } else { $false }
                    $arcMonthlyCost = 'N/A'
                    try {
                        $arcCostUri  = "/subscriptions/$($1.subscriptionId)/providers/Microsoft.CostManagement/query?api-version=2023-03-01"
                        $arcCostBody = @{
                            type      = 'Usage'
                            timeframe = 'MonthToDate'
                            dataset   = @{
                                granularity = 'None'
                                filter      = @{ dimensions = @{ name = 'ResourceId'; operator = 'In'; values = @($1.id) } }
                                aggregation = @{ totalCost = @{ name = 'PreTaxCost'; function = 'Sum' } }
                            }
                        } | ConvertTo-Json -Depth 10
                        $arcCostResp = Invoke-AzRestMethod -Path $arcCostUri -Method POST -Payload $arcCostBody -ErrorAction SilentlyContinue
                        if ($arcCostResp.StatusCode -eq 200) {
                            $arcCostData = $arcCostResp.Content | ConvertFrom-Json
                            $rawArcCost  = $arcCostData.properties.rows[0][0]
                            if ($rawArcCost -ne $null) { $arcMonthlyCost = [math]::Round([double]$rawArcCost, 2) }
                        }
                    } catch {}

                    # ── Phase 17.2.10: Hybrid Connectivity ─────────────────────────────
                    $proxyConfigured  = if ($data.agentConfiguration.proxy.url) { $true } else { $false }
                    $privateLinkScope = if ($data.privateLinkScopeResourceId) { ($data.privateLinkScopeResourceId -split '/')[-1] } else { 'None' }
                    $connStatus       = if ($data.status) { $data.status } else { 'N/A' }

                    foreach ($Tag in $Tags) { 
                        $obj = @{
                            'ID'                   = $1.id;
                            'Subscription'         = $sub1.name;
                            'Resource Group'       = $1.RESOURCEGROUP;
                            'Location'             = $1.LOCATION;
                            'Name'                 = $1.NAME;
                            'Retiring Feature'     = $RetiringFeature;
                            'Retiring Date'        = $RetiringDate;
                            'Display Name'         = $data.displayname;
                            'Domain'               = $data.domainname;
                            'AD FQDN'              = $data.adfqdn;
                            'DNS FQDN'             = $data.dnsfqdn;
                            'Cloud Provider'       = $data.cloudmetadata.provider;
                            'Manufacturer'         = $data.detectedproperties.manufacturer;
                            'Model'                = $data.detectedProperties.model;
                            'Processor'            = $data.detectedproperties.processornames;
                            'Processor Count'      = $data.detectedproperties.processorcount;
                            'Logical Core Count'   = $data.detectedproperties.logicalcorecount;
                            'Memory (GB)'          = $data.detectedproperties.totalphysicalmemoryingigabytes;
                            'Serial Number'        = $data.detectedproperties.serialnumber;
                            'Asset Tag'            = $data.detectedproperties.smbiosassettag;
                            'MS SQL Server'        = $data.mssqldiscovered;
                            'Agent Version'        = $data.agentversion;
                            'Status'               = $data.status;
                            'Last Status Change'   = $LastStatus;
                            'IP Address'           = $IP;
                            'Subnet'               = $Subnet;
                            'OS Name'              = $data.osName;
                            'OS Version'           = $data.osVersion;
                            'OS Install Date'      = $InstallDate;
                            'Operating System'     = $data.osSku;
                            'License Status'       = $data.licenseprofile.licensestatus;
                            'License Channel'      = $data.licenseprofile.licensechannel;
                            'License Type'         = $data.licenseprofile.esuprofile.servertype;
                            'ESU Enabled'          = $esuEnabled;
                            'Est. Monthly Cost (USD)' = $arcMonthlyCost;
                            'Policy Assignments'   = $policyCount;
                            'Policy Compliance'    = $policyCompliant;
                            'Avg CPU % (7d)'       = $arcAvgCpu;
                            'Proxy Configured'     = $proxyConfigured;
                            'Private Link Scope'   = $privateLinkScope;
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

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if($SmaResources)
    {

        $TableName = ('ARCServer_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        #Retirement
        $condtxt += New-ConditionalText -Range G2:G100 -ConditionalType ContainsText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Location')
        $Exc.Add('Name')
        $Exc.Add('Display Name')
        $Exc.Add('Domain')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('AD FQDN')
        $Exc.Add('DNS FQDN')
        $Exc.Add('Cloud Provider')
        $Exc.Add('Manufacturer')
        $Exc.Add('Model')
        $Exc.Add('Processor')
        $Exc.Add('Processor Count')
        $Exc.Add('Logical Core Count')
        $Exc.Add('Memory (GB)')
        $Exc.Add('Serial Number')
        $Exc.Add('Asset Tag')
        $Exc.Add('MS SQL Server')
        $Exc.Add('Agent Version')
        $Exc.Add('Status')
        $Exc.Add('Last Status Change')
        $Exc.Add('IP Address')
        $Exc.Add('Subnet')
        $Exc.Add('OS Name')
        $Exc.Add('OS Version')
        $Exc.Add('OS Install Date')
        $Exc.Add('License Status')
        $Exc.Add('License Channel')
        $Exc.Add('License Type')
        $Exc.Add('ESU Enabled')
        $Exc.Add('Est. Monthly Cost (USD)')
        $Exc.Add('Policy Assignments')
        $Exc.Add('Policy Compliance')
        $Exc.Add('Avg CPU % (7d)')
        $Exc.Add('Proxy Configured')
        $Exc.Add('Private Link Scope')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value') 
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources | 
        ForEach-Object { $_ } | Select-Object $Exc | 
        Export-Excel -Path $File -WorksheetName 'ARC Servers' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style

    }
}