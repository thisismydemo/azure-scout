<#
.Synopsis
Inventory for Subscription-Level Diagnostic Settings

.DESCRIPTION
This script consolidates subscription-level diagnostic settings for Azure Activity Logs.
Captures log categories, retention policies, and destinations (Log Analytics, Storage, Event Hubs).
Excel Sheet Name: Subscription Diagnostics

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/SubscriptionDiagnosticSettings.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        # Get subscription diagnostic settings (Activity Log configurations)
        $diagnosticSettings = @()

        foreach ($subscription in $Sub) {
            Write-AZSCLog -Message "  >> Processing Subscription Diagnostic Settings for: $($subscription.Name)" -Color 'Cyan'

            try {
                $subDiagSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
                if ($subDiagSettings) {
                    $diagnosticSettings += $subDiagSettings | ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'SubscriptionId' -NotePropertyValue $subscription.Id -Force -PassThru
                        $_ | Add-Member -NotePropertyName 'SubscriptionName' -NotePropertyValue $subscription.Name -Force -PassThru
                    }
                }
            } catch {
                Write-AZSCLog -Message "    Failed to retrieve diagnostic settings: $_" -Color 'Yellow'
            }
        }

    <######### Insert the resource Process here ########>

    if($diagnosticSettings)
        {
            $tmp = foreach ($1 in $diagnosticSettings) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.SubscriptionId }
                $data = $1

                # Parse enabled log categories
                $enabledLogs = @()
                if ($data.Logs) {
                    foreach ($log in $data.Logs) {
                        if ($log.Enabled -eq $true) {
                            $category = $log.Category
                            $retentionDays = if ($log.RetentionPolicy.Days -gt 0) {
                                "$($log.RetentionPolicy.Days) days"
                            } else { 'Unlimited' }
                            $enabledLogs += "$category (Retention: $retentionDays)"
                        }
                    }
                }
                $enabledLogsStr = if ($enabledLogs.Count -gt 0) { $enabledLogs -join '; ' } else { 'None' }

                # Parse destinations
                $destinations = @()

                # Log Analytics workspace
                if ($data.WorkspaceId) {
                    $workspaceName = ($data.WorkspaceId -split '/')[-1]
                    $destinations += "Log Analytics: $workspaceName"
                }

                # Storage account
                if ($data.StorageAccountId) {
                    $storageName = ($data.StorageAccountId -split '/')[-1]
                    $destinations += "Storage: $storageName"
                }

                # Event Hub
                if ($data.EventHubAuthorizationRuleId) {
                    $eventHubName = if ($data.EventHubName) {
                        $data.EventHubName
                    } else {
                        ($data.EventHubAuthorizationRuleId -split '/')[-3]
                    }
                    $destinations += "Event Hub: $eventHubName"
                }

                # Partner solution
                if ($data.MarketplacePartnerId) {
                    $partnerName = ($data.MarketplacePartnerId -split '/')[-1]
                    $destinations += "Partner: $partnerName"
                }

                $destinationsStr = if ($destinations.Count -gt 0) { $destinations -join '; ' } else { 'None' }

                # Count enabled categories
                $enabledCount = ($data.Logs | Where-Object { $_.Enabled -eq $true }).Count
                $totalCount = $data.Logs.Count

                $obj = @{
                    'ID'                        = $1.Id;
                    'Subscription'              = $1.SubscriptionName;
                    'Diagnostic Setting Name'   = $data.Name;
                    'Enabled Log Categories'    = $enabledLogsStr;
                    'Categories Enabled'        = "$enabledCount / $totalCount";
                    'Destinations'              = $destinationsStr;
                    'Log Analytics Workspace'   = if ($data.WorkspaceId) { ($data.WorkspaceId -split '/')[-1] } else { 'N/A' };
                    'Storage Account'           = if ($data.StorageAccountId) { ($data.StorageAccountId -split '/')[-1] } else { 'N/A' };
                    'Event Hub'                 = if ($data.EventHubAuthorizationRuleId) {
                        if ($data.EventHubName) { $data.EventHubName } else { ($data.EventHubAuthorizationRuleId -split '/')[-3] }
                    } else { 'N/A' };
                    'Partner Solution'          = if ($data.MarketplacePartnerId) { ($data.MarketplacePartnerId -split '/')[-1] } else { 'N/A' };
                    'Resource U'                = $ResUCount;
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
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

        $TableName = ('SubDiagnosticsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range D:D,F:F -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Diagnostic Setting Name')
        $Exc.Add('Enabled Log Categories')
        $Exc.Add('Categories Enabled')
        $Exc.Add('Destinations')
        $Exc.Add('Log Analytics Workspace')
        $Exc.Add('Storage Account')
        $Exc.Add('Event Hub')
        $Exc.Add('Partner Solution')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Subscription Diagnostics' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
