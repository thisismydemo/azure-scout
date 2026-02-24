<#
.Synopsis
Operational Deep-Data for Azure Virtual Machines

.DESCRIPTION
This script provides deep operational data for Azure VMs including backup status,
advisor recommendations count, update compliance, and lifecycle tag extraction.
Supplement to VirtualMachine.ps1 — does not replace it.
Excel Sheet Name: VM Operational Data

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Compute/VMOperationalData.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $vms = $Resources | Where-Object { $_.TYPE -eq 'microsoft.compute/virtualmachines' }

    if ($vms) {

        # Pre-load backup items from Resources (ARG type for protected items)
        $backupItems = $Resources | Where-Object {
            $_.TYPE -like 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
        }

        # Pre-load Advisor recommendations if present in Resources
        $advisorRecs = $Resources | Where-Object { $_.TYPE -eq 'microsoft.advisor/recommendations' }

        $tmp = foreach ($1 in $vms) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # ---- Extensions summary ----
            $vmExts = $Resources | Where-Object {
                $_.TYPE -eq 'microsoft.compute/virtualmachines/extensions' -and
                ($_.id -split '/')[8] -eq $1.NAME
            }
            $extCount    = if ($vmExts)  { @($vmExts).Count }                                                       else { 0 }
            $extNames    = if ($vmExts)  { ($vmExts | ForEach-Object { $_.PROPERTIES.type }) -join ', ' }           else { 'None' }
            $hasAMA      = if ($vmExts -and ($vmExts.PROPERTIES.publisher -contains 'Microsoft.Azure.Monitor'))    { 'Yes' } else { 'No' }
            $hasDefender = if ($vmExts -and ($vmExts.PROPERTIES.type -like '*MDE*' -or $vmExts.PROPERTIES.Publisher -like '*MicrosoftDefender*')) { 'Yes' } else { 'No' }

            # ---- Boot diagnostics ----
            $bootDiag    = if ($data.diagnosticsProfile.bootDiagnostics.enabled -eq $true) { 'Enabled' } else { 'Disabled' }
            $bootDiagSA  = if ($data.diagnosticsProfile.bootDiagnostics.storageUri) { $data.diagnosticsProfile.bootDiagnostics.storageUri } else { 'Managed' }

            # ---- Backup status (cross-ref from pre-loaded backup items) ----
            $backupItem     = $backupItems | Where-Object { $_.PROPERTIES.sourceResourceId -eq $1.id }
            $backupEnabled  = if ($backupItem)  { 'Yes' }                                   else { 'No' }
            $lastBackupTime = if ($backupItem)  { $backupItem.PROPERTIES.lastBackupTime }   else { 'N/A' }
            $backupVault    = if ($backupItem)  { ($backupItem.id -split '/')[8] }          else { 'N/A' }
            $backupPolicy   = if ($backupItem)  { $backupItem.PROPERTIES.policyName }       else { 'N/A' }

            # ---- Advisor recommendations (cross-ref) ----
            $vmAdvisor     = $advisorRecs | Where-Object { $_.PROPERTIES.resourceMetadata.resourceId -eq $1.id }
            $advisorCount  = if ($vmAdvisor)  { @($vmAdvisor).Count }                                          else { 0 }
            $costAdvisor   = if ($vmAdvisor)  { @($vmAdvisor | Where-Object { $_.PROPERTIES.category -eq 'Cost' }).Count }        else { 0 }
            $secAdvisor    = if ($vmAdvisor)  { @($vmAdvisor | Where-Object { $_.PROPERTIES.category -eq 'Security' }).Count }    else { 0 }

            # ---- Update compliance via REST (optional, try/catch) ----
            $pendingCritical  = 'N/A'
            $pendingImportant = 'N/A'
            $lastPatchTime    = 'N/A'
            try {
                $assessUri = "/subscriptions/$($1.subscriptionId)/resourceGroups/$($1.RESOURCEGROUP)/providers/Microsoft.Compute/virtualMachines/$($1.NAME)/assessPatches?api-version=2023-03-01"
                $assessResp = Invoke-AzRestMethod -Path $assessUri -Method POST -ErrorAction SilentlyContinue
                if ($assessResp.StatusCode -in 200, 202) {
                    $assessData    = $assessResp.Content | ConvertFrom-Json
                    $pendingCritical  = if ($assessData.criticalAndSecurityPatchCount)  { $assessData.criticalAndSecurityPatchCount }  else { 0 }
                    $pendingImportant = if ($assessData.otherPatchCount)                 { $assessData.otherPatchCount }                 else { 0 }
                    $lastPatchTime    = if ($assessData.startDateTime)                   { ([datetime]$assessData.startDateTime).ToString('yyyy-MM-dd') } else { 'N/A' }
                }
            } catch {}

            # ---- Lifecycle tags ----
            $tagEnv      = if ($1.tags.Environment)  { $1.tags.Environment }  elseif ($1.tags.environment)  { $1.tags.environment }  else { 'N/A' }
            $tagOwner    = if ($1.tags.Owner)         { $1.tags.Owner }         elseif ($1.tags.owner)        { $1.tags.owner }        else { 'N/A' }
            $tagCostCenter = if ($1.tags.CostCenter) { $1.tags.CostCenter }   elseif ($1.tags.costcenter)   { $1.tags.costcenter }   else { 'N/A' }
            $tagExpiry   = if ($1.tags.ExpirationDate){ $1.tags.ExpirationDate } elseif ($1.tags.Expiration){ $1.tags.Expiration }    else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                        = $1.id;
                    'Subscription'              = $sub1.Name;
                    'Resource Group'            = $1.RESOURCEGROUP;
                    'VM Name'                   = $1.NAME;
                    'Location'                  = $1.LOCATION;
                    'Power State'               = if ($data.extended.instanceView.powerState.displayStatus) { $data.extended.instanceView.powerState.displayStatus } else { 'N/A' };
                    'Extensions Count'          = $extCount;
                    'Extensions Installed'      = $extNames;
                    'Azure Monitor Agent'       = $hasAMA;
                    'Defender Extension'        = $hasDefender;
                    'Boot Diagnostics'          = $bootDiag;
                    'Boot Diag Storage'         = $bootDiagSA;
                    'Backup Enabled'            = $backupEnabled;
                    'Last Backup Time'          = $lastBackupTime;
                    'Backup Vault'              = $backupVault;
                    'Backup Policy'             = $backupPolicy;
                    'Advisor Recs Total'        = $advisorCount;
                    'Advisor Cost Recs'         = $costAdvisor;
                    'Advisor Security Recs'     = $secAdvisor;
                    'Pending Critical Patches'  = $pendingCritical;
                    'Pending Other Patches'     = $pendingImportant;
                    'Last Patch Assessment'     = $lastPatchTime;
                    'Tag: Environment'          = $tagEnv;
                    'Tag: Owner'                = $tagOwner;
                    'Tag: Cost Center'          = $tagCostCenter;
                    'Tag: Expiration Date'      = $tagExpiry;
                    'Resource U'                = $ResUCount;
                    'Tag Name'                  = [string]$Tag.Name;
                    'Tag Value'                 = [string]$Tag.Value;
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
        $TableName = ('VMOperDataTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Cond  = New-ConditionalText -ConditionalType ContainsText 'No'       -ConditionalTextColor ([System.Drawing.Color]::FromArgb(255,165,0))  -BackgroundColor ([System.Drawing.Color]::White)
        $Cond2 = New-ConditionalText -ConditionalType ContainsText 'Disabled' -ConditionalTextColor ([System.Drawing.Color]::FromArgb(255,0,0))    -BackgroundColor ([System.Drawing.Color]::White)
        $Cond3 = New-ConditionalText -ConditionalType ContainsText 'Yes'      -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,176,80))   -BackgroundColor ([System.Drawing.Color]::White)

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('VM Name')
        $Exc.Add('Location')
        $Exc.Add('Power State')
        $Exc.Add('Extensions Count')
        $Exc.Add('Extensions Installed')
        $Exc.Add('Azure Monitor Agent')
        $Exc.Add('Defender Extension')
        $Exc.Add('Boot Diagnostics')
        $Exc.Add('Boot Diag Storage')
        $Exc.Add('Backup Enabled')
        $Exc.Add('Last Backup Time')
        $Exc.Add('Backup Vault')
        $Exc.Add('Backup Policy')
        $Exc.Add('Advisor Recs Total')
        $Exc.Add('Advisor Cost Recs')
        $Exc.Add('Advisor Security Recs')
        $Exc.Add('Pending Critical Patches')
        $Exc.Add('Pending Other Patches')
        $Exc.Add('Last Patch Assessment')
        $Exc.Add('Tag: Environment')
        $Exc.Add('Tag: Owner')
        $Exc.Add('Tag: Cost Center')
        $Exc.Add('Tag: Expiration Date')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'VM Operational Data' `
            -AutoSize -MaxAutoSizeRows 100 `
            -ConditionalText $Cond, $Cond2, $Cond3 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
