<#
.Synopsis
Inventory for Azure Virtual Desktop Session Hosts

.DESCRIPTION
This script consolidates information for all AVD Session Host resources
(microsoft.desktopvirtualization/hostpools/sessionhosts) including Arc/Azure Local detection.
Excel Sheet Name: AVD Session Hosts

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Compute/AVDSessionHosts.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

.CATEGORY Compute

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $sessionHosts = $Resources | Where-Object { $_.TYPE -eq 'microsoft.desktopvirtualization/hostpools/sessionhosts' }

    if ($sessionHosts) {
        $tmp = foreach ($1 in $sessionHosts) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Parse host pool name from resource ID: /.../hostPools/{name}/sessionHosts/{vh}
            $idParts      = $1.id -split '/'
            $shIdx        = $idParts.IndexOf('sessionHosts')
            $hpIdx        = $idParts.IndexOf('hostPools')
            $hostPoolName = if ($hpIdx -ge 0) { $idParts[$hpIdx + 1] } else { 'N/A' }
            $shName       = if ($shIdx -ge 0)  { $idParts[$shIdx + 1] } else { $1.NAME }

            # Arc / Azure Local detection
            $resourceId    = if ($data.resourceId)        { $data.resourceId }        else { '' }
            $isArc         = if ($resourceId -match 'Microsoft.HybridCompute/machines') { 'Yes' } else { 'No' }
            $isAzureLocal  = if ($resourceId -match 'Microsoft.AzureStackHCI')          { 'Yes' } else { 'No' }

            $lastHeartbeat = if ($data.lastHeartBeat) { ([datetime]$data.lastHeartBeat).ToString('yyyy-MM-dd HH:mm') } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                    = $1.id;
                    'Subscription'          = $sub1.Name;
                    'Resource Group'        = $1.RESOURCEGROUP;
                    'Host Pool'             = $hostPoolName;
                    'Session Host'          = $shName;
                    'Status'                = if ($data.status)               { $data.status }               else { 'N/A' };
                    'Agent Version'         = if ($data.agentVersion)         { $data.agentVersion }         else { 'N/A' };
                    'OS Version'            = if ($data.osVersion)            { $data.osVersion }            else { 'N/A' };
                    'Sessions'              = if ($null -ne $data.sessions)   { $data.sessions }             else { 0 };
                    'Assigned User'         = if ($data.assignedUser)         { $data.assignedUser }         else { 'Unassigned' };
                    'Allow New Session'     = if ($data.allowNewSession -eq $true) { 'Yes' } else { 'No' };
                    'Update State'          = if ($data.updateState)          { $data.updateState }          else { 'N/A' };
                    'Last Heartbeat'        = $lastHeartbeat;
                    'Arc Enabled'           = $isArc;
                    'Azure Local'           = $isAzureLocal;
                    'Resource ID'           = if ($resourceId) { $resourceId } else { 'N/A' };
                    'Resource U'            = $ResUCount;
                    'Tag Name'              = [string]$Tag.Name;
                    'Tag Value'             = [string]$Tag.Value;
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
        $TableName = ('AVDSessionHostsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Cond  = New-ConditionalText -ConditionalType ContainsText 'Available'     -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,176,80))  -BackgroundColor ([System.Drawing.Color]::White)
        $Cond2 = New-ConditionalText -ConditionalType ContainsText 'Unavailable'   -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::Red)
        $Cond3 = New-ConditionalText -ConditionalType ContainsText 'Disconnected'  -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::FromArgb(255,165,0))
        $Cond4 = New-ConditionalText -ConditionalType ContainsText 'Yes' -PatternType $([OfficeOpenXml.Style.ExcelFillStyle]::Solid) -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,112,192)) -BackgroundColor ([System.Drawing.Color]::White)

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Host Pool')
        $Exc.Add('Session Host')
        $Exc.Add('Status')
        $Exc.Add('Agent Version')
        $Exc.Add('OS Version')
        $Exc.Add('Sessions')
        $Exc.Add('Assigned User')
        $Exc.Add('Allow New Session')
        $Exc.Add('Update State')
        $Exc.Add('Last Heartbeat')
        $Exc.Add('Arc Enabled')
        $Exc.Add('Azure Local')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AVD Session Hosts' `
            -AutoSize -MaxAutoSizeRows 100 `
            -ConditionalText $Cond, $Cond2, $Cond3 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
