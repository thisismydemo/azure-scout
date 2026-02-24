<#
.Synopsis
Inventory for Microsoft Defender for Cloud Security Alerts

.DESCRIPTION
This script consolidates active security alerts from Microsoft Defender for Cloud.
Captures threat intelligence, affected resources, severity, and recommended actions.
Excel Sheet Name: Defender Alerts

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Security/DefenderAlerts.ps1

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

        # Get security alerts from Microsoft Defender for Cloud
        $alerts = @()

        foreach ($subscription in $Sub) {
            Write-AZSCLog -Message "  >> Processing Defender Alerts for subscription: $($subscription.Name)" -Color 'Cyan'

            try {
                $subAlerts = Get-AzSecurityAlert -ErrorAction SilentlyContinue
                if ($subAlerts) {
                    $alerts += $subAlerts | ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'SubscriptionId' -NotePropertyValue $subscription.Id -Force -PassThru
                    }
                }
            } catch {
                Write-AZSCLog -Message "    Failed to retrieve alerts: $_" -Color 'Yellow'
            }
        }

    <######### Insert the resource Process here ########>

    if($alerts)
        {
            $tmp = foreach ($1 in $alerts) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.SubscriptionId }
                $data = $1

                # Parse alert details
                $alertName = $data.AlertDisplayName
                $alertType = $data.AlertType
                $severity = $data.Severity
                $status = $data.Status

                # Get affected resources
                $affectedResources = if ($data.Entities) {
                    ($data.Entities | Where-Object { $_.Type -eq 'azure-resource' } | ForEach-Object {
                        if ($_.ResourceId) { ($_.ResourceId -split '/')[-1] }
                    } | Where-Object { $_ }) -join ', '
                } else { 'N/A' }

                if ([string]::IsNullOrEmpty($affectedResources)) {
                    $affectedResources = 'Subscription-level'
                }

                # Get resource group
                $resourceGroup = if ($data.ResourceIdentifiers -and $data.ResourceIdentifiers.ResourceGroup) {
                    $data.ResourceIdentifiers.ResourceGroup
                } else { 'N/A' }

                # Get alert time
                $alertTime = if ($data.TimeGeneratedUtc) {
                    $data.TimeGeneratedUtc.ToString('yyyy-MM-dd HH:mm:ss')
                } else { 'N/A' }

                # Get description and remediation
                $description = if ($data.Description) { $data.Description } else { 'See Azure Portal' }
                $remediationSteps = if ($data.RemediationSteps) {
                    ($data.RemediationSteps -join '; ')
                } else { 'See Azure Portal for recommended actions' }

                # Get intent and tactics (MITRE ATT&CK)
                $intent = if ($data.Intent) { $data.Intent } else { 'Unknown' }
                $tactics = if ($data.ExtendedProperties -and $data.ExtendedProperties.Tactics) {
                    $data.ExtendedProperties.Tactics -join ', '
                } else { 'N/A' }

                $obj = @{
                    'ID'                        = $1.Name;
                    'Subscription'              = $sub1.Name;
                    'Alert Name'                = $alertName;
                    'Alert Type'                = $alertType;
                    'Severity'                  = $severity;
                    'Status'                    = $status;
                    'Time Generated (UTC)'      = $alertTime;
                    'Resource Group'            = $resourceGroup;
                    'Affected Resources'        = $affectedResources;
                    'Description'               = $description;
                    'Intent'                    = $intent;
                    'Tactics (MITRE ATT&CK)'    = $tactics;
                    'Remediation Steps'         = $remediationSteps;
                    'Confidence Level'          = if ($data.ConfidenceLevel) { $data.ConfidenceLevel } else { 'N/A' };
                    'Portal Link'               = "https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/0";
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

        $TableName = ('DefenderAlertTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range J:J,M:M -Width 50 -WrapText

        # Conditional formatting for high severity alerts
        $condSeverity = New-ConditionalText -Text 'High' -BackgroundColor '#FFC7CE' -ConditionalTextColor '#9C0006'
        $condActive = New-ConditionalText -Text 'Active' -BackgroundColor '#FFEB9C' -ConditionalTextColor '#9C6500'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Alert Name')
        $Exc.Add('Alert Type')
        $Exc.Add('Severity')
        $Exc.Add('Status')
        $Exc.Add('Time Generated (UTC)')
        $Exc.Add('Resource Group')
        $Exc.Add('Affected Resources')
        $Exc.Add('Description')
        $Exc.Add('Intent')
        $Exc.Add('Tactics (MITRE ATT&CK)')
        $Exc.Add('Remediation Steps')
        $Exc.Add('Confidence Level')
        $Exc.Add('Portal Link')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Defender Alerts' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt -ConditionalText $condSeverity, $condActive

    }
}
