<#
.Synopsis
Inventory for Azure Policy Definitions (Custom)

.DESCRIPTION
This script consolidates information for all custom Azure Policy definitions.
Excel Sheet Name: Policy Definitions

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/PolicyDefinitions.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

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

        # Get all policy definitions (custom only)
        $policyDefs = Get-AzPolicyDefinition -Custom -ErrorAction SilentlyContinue

    <######### Insert the resource Process here ########>

    if($policyDefs)
        {
            $tmp = foreach ($policy in $policyDefs) {
                $ResUCount = 1

                $props = $policy.Properties

                # Parse parameters
                $params = if ($props.Parameters) {
                    ($props.Parameters.PSObject.Properties | ForEach-Object { "$($_.Name) ($($_.Value.type))" }) -join '; '
                } else { 'None' }

                # Parse metadata
                $category = if ($props.Metadata.category) { $props.Metadata.category } else { 'Uncategorized' }
                $version = if ($props.Metadata.version) { $props.Metadata.version } else { 'N/A' }

                # Parse policy rule effect
                $effect = if ($props.PolicyRule.then.effect) { $props.PolicyRule.then.effect } else { 'Unknown' }

                $obj = @{
                    'ID'                    = $policy.PolicyDefinitionId;
                    'Name'                  = $policy.Name;
                    'Display Name'          = $props.DisplayName;
                    'Description'           = $props.Description;
                    'Policy Type'           = $props.PolicyType;
                    'Mode'                  = $props.Mode;
                    'Category'              = $category;
                    'Version'               = $version;
                    'Effect'                = $effect;
                    'Parameters'            = $params;
                    'Management Group'      = $policy.ManagementGroupName;
                    'Subscription'          = $policy.SubscriptionId;
                    'Resource U'            = $ResUCount;
                }
                $obj
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

        $TableName = ('PolicyDefsTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range D:D,J:J -Width 60 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Name')
        $Exc.Add('Display Name')
        $Exc.Add('Description')
        $Exc.Add('Policy Type')
        $Exc.Add('Mode')
        $Exc.Add('Category')
        $Exc.Add('Version')
        $Exc.Add('Effect')
        $Exc.Add('Parameters')
        $Exc.Add('Management Group')
        $Exc.Add('Subscription')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Policy Definitions' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
