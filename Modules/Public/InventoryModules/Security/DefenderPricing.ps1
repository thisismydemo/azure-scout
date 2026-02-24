<#
.Synopsis
Inventory for Microsoft Defender for Cloud Pricing Plans

.DESCRIPTION
This script consolidates Microsoft Defender for Cloud plan enablement per subscription.
Captures which Defender plans are enabled, pricing tiers, and extensions.
Excel Sheet Name: Defender Pricing

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Security/DefenderPricing.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task ,$File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

        # Get Defender pricing plans per subscription
        $pricingPlans = @()

        foreach ($subscription in $Sub) {
            Write-AZTILog -Message "  >> Processing Defender Pricing for subscription: $($subscription.Name)" -Color 'Cyan'

            try {
                $subPricing = Get-AzSecurityPricing -ErrorAction SilentlyContinue
                if ($subPricing) {
                    $pricingPlans += $subPricing | ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'SubscriptionId' -NotePropertyValue $subscription.Id -Force -PassThru
                        $_ | Add-Member -NotePropertyName 'SubscriptionName' -NotePropertyValue $subscription.Name -Force -PassThru
                    }
                }
            } catch {
                Write-AZTILog -Message "    Failed to retrieve pricing: $_" -Color 'Yellow'
            }
        }

    <######### Insert the resource Process here ########>

    if($pricingPlans)
        {
            $tmp = foreach ($1 in $pricingPlans) {
                $ResUCount = 1
                $sub1 = $SUB | Where-Object { $_.Id -eq $1.SubscriptionId }
                $data = $1

                # Parse plan details
                $planName = $data.Name
                $pricingTier = $data.PricingTier
                $isEnabled = if ($pricingTier -eq 'Standard') { 'Yes' } else { 'No' }

                # Get extensions if applicable
                $extensions = @()
                if ($data.Extensions) {
                    foreach ($ext in $data.Extensions) {
                        $extName = $ext.Name
                        $extEnabled = if ($ext.IsEnabled -eq 'True') { 'Enabled' } else { 'Disabled' }
                        $extensions += "$extName ($extEnabled)"
                    }
                }
                $extensionsStr = if ($extensions.Count -gt 0) { $extensions -join '; ' } else { 'None' }

                # Get deprecated status
                $isDeprecated = if ($data.Deprecated -eq $true) { 'Yes' } else { 'No' }

                # Get replaced by information
                $replacedBy = if ($data.ReplacedBy) {
                    ($data.ReplacedBy -join ', ')
                } else { 'N/A' }

                # Friendly plan names
                $planFriendly = switch ($planName) {
                    'VirtualMachines' { 'Servers' }
                    'SqlServers' { 'SQL Servers on Machines' }
                    'AppServices' { 'App Service' }
                    'StorageAccounts' { 'Storage' }
                    'SqlServerVirtualMachines' { 'SQL Servers on VMs' }
                    'KubernetesService' { 'Containers (AKS)' }
                    'ContainerRegistry' { 'Container Registries' }
                    'KeyVaults' { 'Key Vault' }
                    'Dns' { 'DNS' }
                    'Arm' { 'Resource Manager' }
                    'OpenSourceRelationalDatabases' { 'Open-Source Databases' }
                    'CosmosDbs' { 'Azure Cosmos DB' }
                    'Containers' { 'Containers (Advanced)' }
                    'CloudPosture' { 'Cloud Security Posture Management (CSPM)' }
                    default { $planName }
                }

                $obj = @{
                    'ID'                        = $1.Id;
                    'Subscription'              = $1.SubscriptionName;
                    'Plan Name'                 = $planFriendly;
                    'Plan ID'                   = $planName;
                    'Pricing Tier'              = $pricingTier;
                    'Enabled'                   = $isEnabled;
                    'Extensions'                = $extensionsStr;
                    'Deprecated'                = $isDeprecated;
                    'Replaced By'               = $replacedBy;
                    'Free Trial Remaining Days' = if ($data.FreeTrialRemainingTime) {
                        [math]::Round($data.FreeTrialRemainingTime.TotalDays, 0)
                    } else { 'N/A' };
                    'Portal Link'               = "https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/pricingTier";
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

        $TableName = ('DefenderPricingTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range G:G -Width 40 -WrapText

        # Conditional formatting for enabled plans
        $condEnabled = New-ConditionalText -Text 'Yes' -BackgroundColor '#C6EFCE' -ConditionalTextColor '#006100'
        $condDisabled = New-ConditionalText -Text 'No' -BackgroundColor '#FFC7CE' -ConditionalTextColor '#9C0006'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Plan Name')
        $Exc.Add('Plan ID')
        $Exc.Add('Pricing Tier')
        $Exc.Add('Enabled')
        $Exc.Add('Extensions')
        $Exc.Add('Deprecated')
        $Exc.Add('Replaced By')
        $Exc.Add('Free Trial Remaining Days')
        $Exc.Add('Portal Link')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Defender Pricing' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt -ConditionalText $condEnabled, $condDisabled

    }
}
