<#
.Synopsis
Operational Deep-Data for Azure Arc Servers

.DESCRIPTION
This script provides deep operational data for Azure Arc-enabled servers including
agent health, extension summary, lifecycle tags, and update compliance.
Supplement to ARCServers.ps1 — does not replace it.
Excel Sheet Name: Arc Server Operational Data

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Hybrid/ArcServerOperationalData.ps1

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
    $arcServers = $Resources | Where-Object { $_.TYPE -eq 'microsoft.hybridcompute/machines' }

    if ($arcServers) {

        # Pre-load Arc extensions
        $arcExtensions = $Resources | Where-Object { $_.TYPE -eq 'microsoft.hybridcompute/machines/extensions' }

        # Pre-load Advisor recommendations
        $advisorRecs = $Resources | Where-Object { $_.TYPE -eq 'microsoft.advisor/recommendations' }

        # Pre-load backup items
        $backupItems = $Resources | Where-Object {
            $_.TYPE -like 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
        }

        $tmp = foreach ($1 in $arcServers) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # ---- OS Details ----
            $osName       = if ($data.osName)         { $data.osName }         else { if ($data.osSku)    { $data.osSku }    else { 'N/A' } }
            $osVersion    = if ($data.osVersion)      { $data.osVersion }      else { 'N/A' }
            $osSku        = if ($data.osSku)          { $data.osSku }          else { 'N/A' }

            # ---- Arc Agent Health ----
            $agentVersion = if ($data.agentVersion)   { $data.agentVersion }   else { 'N/A' }
            $connStatus   = if ($data.status)         { $data.status }         else { 'N/A' }
            $lastHB       = if ($data.lastStatusChange) { ([datetime]$data.lastStatusChange).ToString('yyyy-MM-dd HH:mm') } else { 'N/A' }
            $agentErrors  = if ($data.errorDetails)   { ($data.errorDetails | ForEach-Object { $_.message }) -join '; ' } else { 'None' }

            # ---- Extensions ----
            $machExts  = $arcExtensions | Where-Object { $_.id -match "/machines/$($1.NAME)/extensions/" }
            $extCount  = if ($machExts) { @($machExts).Count } else { 0 }
            $extNames  = if ($machExts) { ($machExts | ForEach-Object { $_.PROPERTIES.type }) -join ', ' } else { 'None' }
            $hasAMA    = if ($machExts -and ($machExts.PROPERTIES.publisher -contains 'Microsoft.Azure.Monitor')) { 'Yes' } else { 'No' }

            # ---- Backup ----
            $backupItem    = $backupItems | Where-Object { $_.PROPERTIES.sourceResourceId -eq $1.id }
            $backupEnabled = if ($backupItem) { 'Yes' } else { 'No' }
            $lastBackup    = if ($backupItem) { $backupItem.PROPERTIES.lastBackupTime } else { 'N/A' }

            # ---- Advisor ----
            $vmAdvisor    = $advisorRecs | Where-Object { $_.PROPERTIES.resourceMetadata.resourceId -eq $1.id }
            $advisorCount = if ($vmAdvisor) { @($vmAdvisor).Count } else { 0 }
            $secAdvisor   = if ($vmAdvisor) { @($vmAdvisor | Where-Object { $_.PROPERTIES.category -eq 'Security' }).Count } else { 0 }

            # ---- Update compliance via REST ----
            $pendingCritical = 'N/A'
            $lastPatchTime   = 'N/A'
            try {
                $patchUri = "/subscriptions/$($1.subscriptionId)/resourceGroups/$($1.RESOURCEGROUP)/providers/Microsoft.HybridCompute/machines/$($1.NAME)/assessPatches?api-version=2023-06-20-preview"
                $patchResp = Invoke-AzRestMethod -Path $patchUri -Method POST -ErrorAction SilentlyContinue
                if ($patchResp.StatusCode -in 200, 202) {
                    $patchData       = $patchResp.Content | ConvertFrom-Json
                    $pendingCritical = if ($patchData.availablePatchCountByClassification.critical) { $patchData.availablePatchCountByClassification.critical } else { 0 }
                    $lastPatchTime   = if ($patchData.lastModifiedDateTime) { ([datetime]$patchData.lastModifiedDateTime).ToString('yyyy-MM-dd') } else { 'N/A' }
                }
            } catch {}

            # ---- Lifecycle tags ----
            $tagEnv       = if ($1.tags.Environment)   { $1.tags.Environment }    elseif ($1.tags.environment)   { $1.tags.environment }   else { 'N/A' }
            $tagOwner     = if ($1.tags.Owner)          { $1.tags.Owner }           elseif ($1.tags.owner)         { $1.tags.owner }         else { 'N/A' }
            $tagCostCenter = if ($1.tags.CostCenter)   { $1.tags.CostCenter }      elseif ($1.tags.costcenter)    { $1.tags.costcenter }    else { 'N/A' }
            $tagLocation  = if ($1.tags.PhysicalLocation) { $1.tags.PhysicalLocation } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                       = $1.id;
                    'Subscription'             = $sub1.Name;
                    'Resource Group'           = $1.RESOURCEGROUP;
                    'Machine Name'             = $1.NAME;
                    'Location'                 = $1.LOCATION;
                    'Connection Status'        = $connStatus;
                    'OS Name'                  = $osName;
                    'OS Version'               = $osVersion;
                    'OS SKU'                   = $osSku;
                    'Arc Agent Version'        = $agentVersion;
                    'Last Status Change'       = $lastHB;
                    'Agent Errors'             = $agentErrors;
                    'Extensions Count'         = $extCount;
                    'Extensions Installed'     = $extNames;
                    'Azure Monitor Agent'      = $hasAMA;
                    'Backup Enabled'           = $backupEnabled;
                    'Last Backup'              = $lastBackup;
                    'Advisor Recs Total'       = $advisorCount;
                    'Advisor Security Recs'    = $secAdvisor;
                    'Pending Critical Patches' = $pendingCritical;
                    'Last Patch Assessment'    = $lastPatchTime;
                    'Tag: Environment'         = $tagEnv;
                    'Tag: Owner'               = $tagOwner;
                    'Tag: Cost Center'         = $tagCostCenter;
                    'Tag: Physical Location'   = $tagLocation;
                    'Resource U'               = $ResUCount;
                    'Tag Name'                 = [string]$Tag.Name;
                    'Tag Value'                = [string]$Tag.Value;
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
        $TableName = ('ArcSrvOperDataTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Cond  = New-ConditionalText -ConditionalType ContainsText 'Disconnected'  -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::Red)
        $Cond2 = New-ConditionalText -ConditionalType ContainsText 'Connected'     -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,176,80))  -BackgroundColor ([System.Drawing.Color]::White)
        $Cond3 = New-ConditionalText -ConditionalType ContainsText 'No'            -ConditionalTextColor ([System.Drawing.Color]::FromArgb(255,165,0))  -BackgroundColor ([System.Drawing.Color]::White)

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Machine Name')
        $Exc.Add('Location')
        $Exc.Add('Connection Status')
        $Exc.Add('OS Name')
        $Exc.Add('OS Version')
        $Exc.Add('OS SKU')
        $Exc.Add('Arc Agent Version')
        $Exc.Add('Last Status Change')
        $Exc.Add('Agent Errors')
        $Exc.Add('Extensions Count')
        $Exc.Add('Extensions Installed')
        $Exc.Add('Azure Monitor Agent')
        $Exc.Add('Backup Enabled')
        $Exc.Add('Last Backup')
        $Exc.Add('Advisor Recs Total')
        $Exc.Add('Advisor Security Recs')
        $Exc.Add('Pending Critical Patches')
        $Exc.Add('Last Patch Assessment')
        $Exc.Add('Tag: Environment')
        $Exc.Add('Tag: Owner')
        $Exc.Add('Tag: Cost Center')
        $Exc.Add('Tag: Physical Location')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Arc Server Operational Data' `
            -AutoSize -MaxAutoSizeRows 100 `
            -ConditionalText $Cond, $Cond2, $Cond3 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
