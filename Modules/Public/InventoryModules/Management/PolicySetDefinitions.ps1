<#
.Synopsis
Inventory for Azure Policy Initiative Definitions (Custom)

.DESCRIPTION
This script consolidates information for all custom Azure Policy Set Definitions (Initiatives).
Excel Sheet Name: Policy Initiatives

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/PolicySetDefinitions.ps1

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

        # Get all policy set definitions (custom only)
        $policySetDefs = Get-AzPolicySetDefinition -Custom -ErrorAction SilentlyContinue

    <######### Insert the resource Process here ########>

    if($policySetDefs)
        {
            $tmp = foreach ($policySet in $policySetDefs) {
                $ResUCount = 1

                $props = $policySet.Properties

                # Parse parameters
                $params = if ($props.Parameters) {
                    ($props.Parameters.PSObject.Properties | ForEach-Object { "$($_.Name) ($($_.Value.type))" }) -join '; '
                } else { 'None' }

                # Parse metadata
                $category = if ($props.Metadata.category) { $props.Metadata.category } else { 'Uncategorized' }
                $version = if ($props.Metadata.version) { $props.Metadata.version } else { 'N/A' }

                # Count policy definitions in the initiative
                $policyCount = if ($props.PolicyDefinitions) { $props.PolicyDefinitions.Count } else { 0 }

                # Get list of policy definition references
                $policyRefs = if ($props.PolicyDefinitions) {
                    ($props.PolicyDefinitions | ForEach-Object {
                        $refId = $_.policyDefinitionId -split '/' | Select-Object -Last 1
                        $refId
                    }) -join '; '
                } else { 'None' }

                # Parse policy groups
                $groupCount = if ($props.PolicyDefinitionGroups) { $props.PolicyDefinitionGroups.Count } else { 0 }

                $obj = @{
                    'ID'                        = $policySet.PolicySetDefinitionId;
                    'Name'                      = $policySet.Name;
                    'Display Name'              = $props.DisplayName;
                    'Description'               = $props.Description;
                    'Policy Type'               = $props.PolicyType;
                    'Category'                  = $category;
                    'Version'                   = $version;
                    'Policy Count'              = $policyCount;
                    'Policy Definition Groups'  = $groupCount;
                    'Policy References'         = $policyRefs;
                    'Parameters'                = $params;
                    'Management Group'          = $policySet.ManagementGroupName;
                    'Subscription'              = $policySet.SubscriptionId;
                    'Resource U'                = $ResUCount;
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

        $TableName = ('PolicyInitTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range D:D,J:K -Width 60 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Name')
        $Exc.Add('Display Name')
        $Exc.Add('Description')
        $Exc.Add('Policy Type')
        $Exc.Add('Category')
        $Exc.Add('Version')
        $Exc.Add('Policy Count')
        $Exc.Add('Policy Definition Groups')
        $Exc.Add('Policy References')
        $Exc.Add('Parameters')
        $Exc.Add('Management Group')
        $Exc.Add('Subscription')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Policy Initiatives' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
