<#
.Synopsis
Inventory for Azure Arc Machine Extensions

.DESCRIPTION
This script consolidates information for all microsoft.hybridcompute/machines/extensions resource provider in $Resources variable.
Excel Sheet Name: Arc Extensions

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Hybrid/ArcExtensions.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $arcExtensions = $Resources | Where-Object { $_.TYPE -eq 'microsoft.hybridcompute/machines/extensions' }

    if ($arcExtensions) {
        $tmp = foreach ($1 in $arcExtensions) {
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

            # Extract machine name from resource id
            # Format: .../machines/{machineName}/extensions/{extensionName}
            $MachineName = if ($1.id -match '/machines/([^/]+)/extensions/') { $Matches[1] } else { $null }

            # Status message
            $StatusMessage = if ($data.instanceView.status.message) {
                $data.instanceView.status.message.Substring(0, [Math]::Min($data.instanceView.status.message.Length, 100))
            } else { $null }

            # Deep config additions
            $SettingsJson        = if ($data.settings) { ($data.settings | ConvertTo-Json -Compress -Depth 3) } else { 'N/A' }
            $HasProtectedSet     = if ($data.protectedSettings) { 'Yes' } else { 'No' }
            $InstanceViewTime    = if ($data.instanceView.status.time) { $data.instanceView.status.time } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                     = $1.id;
                    'Subscription'           = $sub1.name;
                    'Resource Group'         = $1.RESOURCEGROUP;
                    'Machine Name'           = $MachineName;
                    'Extension Name'         = $1.NAME;
                    'Location'               = $1.LOCATION;
                    'Retiring Feature'       = $RetiringFeature;
                    'Retiring Date'          = $RetiringDate;
                    'Provisioning State'     = $data.provisioningState;
                    'Publisher'              = $data.publisher;
                    'Type'                   = $data.type;
                    'Type Handler Version'   = $data.typeHandlerVersion;
                    'Auto Upgrade Minor'     = $data.autoUpgradeMinorVersion;
                    'Enable Auto Upgrade'    = $data.enableAutomaticUpgrade;
                    'Status'                 = $data.instanceView.status.code;
                    'Status Message'         = $StatusMessage;
                    'Instance View Time'     = $InstanceViewTime;
                    'Settings'               = $SettingsJson;
                    'Has Protected Settings' = $HasProtectedSet;
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

        $TableName = ('ArcExtensions_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText
        $condtxt += New-ConditionalText Failed -Range H:H

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Machine Name')
        $Exc.Add('Extension Name')
        $Exc.Add('Location')
        $Exc.Add('Provisioning State')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Publisher')
        $Exc.Add('Type')
        $Exc.Add('Type Handler Version')
        $Exc.Add('Auto Upgrade Minor')
        $Exc.Add('Enable Auto Upgrade')
        $Exc.Add('Status')
        $Exc.Add('Status Message')
        $Exc.Add('Instance View Time')
        $Exc.Add('Settings')
        $Exc.Add('Has Protected Settings')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Arc Extensions' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
