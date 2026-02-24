<#
.Synopsis
Inventory for Azure Monitor Autoscale Settings

.DESCRIPTION
This script consolidates information for all Autoscale Settings
(microsoft.insights/autoscalesettings).
Excel Sheet Name: Autoscale Settings

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/AutoscaleSettings.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $autoscaleSettings = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/autoscalesettings' }

    if ($autoscaleSettings) {
        $tmp = foreach ($1 in $autoscaleSettings) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Target resource
            $targetId   = if ($data.targetResourceUri)    { $data.targetResourceUri }    else { 'N/A' }
            $targetName = if ($targetId -ne 'N/A')        { ($targetId -split '/')[-1] } else { 'N/A' }
            $targetLoc  = if ($data.targetResourceLocation) { $data.targetResourceLocation } else { 'N/A' }

            # Profiles summary
            $profileCount = if ($data.profiles) { @($data.profiles).Count } else { 0 }
            $profileNames = if ($data.profiles) {
                (@($data.profiles) | ForEach-Object { $_.name }) -join '; '
            } else { '' }

            # Capacity across all profiles (use first/default profile)
            $defaultProfile = if ($data.profiles) { @($data.profiles)[0] } else { $null }
            $capacityMin     = if ($defaultProfile -and $defaultProfile.capacity) { $defaultProfile.capacity.minimum } else { 'N/A' }
            $capacityMax     = if ($defaultProfile -and $defaultProfile.capacity) { $defaultProfile.capacity.maximum } else { 'N/A' }
            $capacityDefault = if ($defaultProfile -and $defaultProfile.capacity) { $defaultProfile.capacity.default }  else { 'N/A' }
            $defaultRulesCount = if ($defaultProfile -and $defaultProfile.rules) { @($defaultProfile.rules).Count } else { 0 }

            # Notifications
            $notifyEmails = @()
            $notifyWebhooks = @()
            if ($data.notifications) {
                foreach ($notif in @($data.notifications)) {
                    if ($notif.email) {
                        if ($notif.email.sendToSubscriptionAdministrator)    { $notifyEmails += 'Sub Admin' }
                        if ($notif.email.sendToSubscriptionCoAdministrators) { $notifyEmails += 'Co-Admins' }
                        if ($notif.email.customEmails) { $notifyEmails += @($notif.email.customEmails) }
                    }
                    if ($notif.webhooks) { $notifyWebhooks += @($notif.webhooks) | ForEach-Object { $_.serviceUri } }
                }
            }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                       = $1.id;
                    'Subscription'             = $sub1.Name;
                    'Resource Group'           = $1.RESOURCEGROUP;
                    'Autoscale Setting Name'   = $1.NAME;
                    'Location'                 = $1.LOCATION;
                    'Enabled'                  = if ($data.enabled) { 'Yes' } else { 'No' };
                    'Target Resource'          = $targetName;
                    'Target Resource ID'       = $targetId;
                    'Target Location'          = $targetLoc;
                    'Profiles Count'           = $profileCount;
                    'Profile Names'            = $profileNames;
                    'Default Profile Min'      = $capacityMin;
                    'Default Profile Max'      = $capacityMax;
                    'Default Profile Default'  = $capacityDefault;
                    'Default Profile Rules'    = $defaultRulesCount;
                    'Notification Emails'      = $notifyEmails -join '; ';
                    'Notification Webhooks'    = $notifyWebhooks -join '; ';
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
        $TableName = ('AutoscaleTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Autoscale Setting Name')
        $Exc.Add('Location')
        $Exc.Add('Enabled')
        $Exc.Add('Target Resource')
        $Exc.Add('Target Location')
        $Exc.Add('Profiles Count')
        $Exc.Add('Profile Names')
        $Exc.Add('Default Profile Min')
        $Exc.Add('Default Profile Max')
        $Exc.Add('Default Profile Default')
        $Exc.Add('Default Profile Rules')
        $Exc.Add('Notification Emails')
        $Exc.Add('Notification Webhooks')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Autoscale Settings' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
