<#
.Synopsis
Inventory for Azure Monitor Action Groups

.DESCRIPTION
This script consolidates information for all Azure Monitor action groups.
Captures notification channels, receivers, and alert routing configurations.
Excel Sheet Name: Action Groups

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/ActionGroups.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        $actionGroups = $Resources | Where-Object {$_.TYPE -eq 'microsoft.insights/actiongroups'}

    <######### Insert the resource Process here ########>

    if($actionGroups)
        {
            $tmp = foreach ($1 in $actionGroups) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
                $data = $1.PROPERTIES
                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{'0'}

                # Parse email receivers
                $emailReceivers = @()
                if ($data.emailReceivers) {
                    foreach ($email in $data.emailReceivers) {
                        $emailReceivers += "$($email.name): $($email.emailAddress)"
                    }
                }
                $emailStr = if ($emailReceivers.Count -gt 0) { $emailReceivers -join '; ' } else { 'None' }

                # Parse SMS receivers
                $smsReceivers = @()
                if ($data.smsReceivers) {
                    foreach ($sms in $data.smsReceivers) {
                        $smsReceivers += "$($sms.name): $($sms.countryCode)-$($sms.phoneNumber)"
                    }
                }
                $smsStr = if ($smsReceivers.Count -gt 0) { $smsReceivers -join '; ' } else { 'None' }

                # Parse webhook receivers
                $webhookReceivers = @()
                if ($data.webhookReceivers) {
                    foreach ($webhook in $data.webhookReceivers) {
                        $webhookReceivers += "$($webhook.name): $($webhook.serviceUri)"
                    }
                }
                $webhookStr = if ($webhookReceivers.Count -gt 0) { $webhookReceivers -join '; ' } else { 'None' }

                # Parse Azure app push receivers
                $appPushReceivers = @()
                if ($data.azureAppPushReceivers) {
                    foreach ($push in $data.azureAppPushReceivers) {
                        $appPushReceivers += "$($push.name): $($push.emailAddress)"
                    }
                }
                $appPushStr = if ($appPushReceivers.Count -gt 0) { $appPushReceivers -join '; ' } else { 'None' }

                # Parse automation runbook receivers
                $runbookReceivers = @()
                if ($data.automationRunbookReceivers) {
                    foreach ($runbook in $data.automationRunbookReceivers) {
                        $runbookReceivers += "$($runbook.name): $($runbook.runbookName)"
                    }
                }
                $runbookStr = if ($runbookReceivers.Count -gt 0) { $runbookReceivers -join '; ' } else { 'None' }

                # Parse Azure Function receivers
                $functionReceivers = @()
                if ($data.azureFunctionReceivers) {
                    foreach ($func in $data.azureFunctionReceivers) {
                        $functionReceivers += "$($func.name): $($func.functionName)"
                    }
                }
                $functionStr = if ($functionReceivers.Count -gt 0) { $functionReceivers -join '; ' } else { 'None' }

                # Parse Logic App receivers
                $logicAppReceivers = @()
                if ($data.logicAppReceivers) {
                    foreach ($logic in $data.logicAppReceivers) {
                        $logicAppReceivers += "$($logic.name): $($logic.resourceId -split '/')[-1]"
                    }
                }
                $logicAppStr = if ($logicAppReceivers.Count -gt 0) { $logicAppReceivers -join '; ' } else { 'None' }

                # Get enabled status
                $enabled = if ($data.enabled -eq $true) { 'Enabled' } else { 'Disabled' }

                foreach ($Tag in $Tags) {
                    $obj = @{
                        'ID'                        = $1.id;
                        'Subscription'              = $sub1.Name;
                        'Resource Group'            = $1.RESOURCEGROUP;
                        'Action Group Name'         = $1.NAME;
                        'Short Name'                = if ($data.groupShortName) { $data.groupShortName } else { 'N/A' };
                        'Location'                  = $1.LOCATION;
                        'Status'                    = $enabled;
                        'Email Receivers'           = $emailStr;
                        'SMS Receivers'             = $smsStr;
                        'Webhook Receivers'         = $webhookStr;
                        'Azure App Push'            = $appPushStr;
                        'Automation Runbooks'       = $runbookStr;
                        'Azure Functions'           = $functionStr;
                        'Logic Apps'                = $logicAppStr;
                        'Total Receivers'           = ($emailReceivers.Count + $smsReceivers.Count + $webhookReceivers.Count + $appPushReceivers.Count + $runbookReceivers.Count + $functionReceivers.Count + $logicAppReceivers.Count);
                        'Resource U'                = $ResUCount;
                        'Tag Name'                  = [string]$Tag.Name;
                        'Tag Value'                 = [string]$Tag.Value
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

        $TableName = ('ActionGroupsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range H:N -Width 40 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Action Group Name')
        $Exc.Add('Short Name')
        $Exc.Add('Location')
        $Exc.Add('Status')
        $Exc.Add('Email Receivers')
        $Exc.Add('SMS Receivers')
        $Exc.Add('Webhook Receivers')
        $Exc.Add('Azure App Push')
        $Exc.Add('Automation Runbooks')
        $Exc.Add('Azure Functions')
        $Exc.Add('Logic Apps')
        $Exc.Add('Total Receivers')
        if($InTag)
            {
                $Exc.Add('Tag Name')
                $Exc.Add('Tag Value')
            }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Action Groups' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
