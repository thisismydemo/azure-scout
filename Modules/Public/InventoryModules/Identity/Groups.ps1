<#
.Synopsis
Inventory for Entra ID Groups

.DESCRIPTION
This script consolidates information for all entra/groups resources.
Excel Sheet Name: Entra Groups

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/Groups.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: AzureTenantInventory Contributors
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraGroups = $Resources | Where-Object { $_.TYPE -eq 'entra/groups' }

    if ($entraGroups)
    {
        $tmp = foreach ($1 in $entraGroups) {
            $ResUCount = 1
            $data = $1.properties

            $groupType = if ($data.groupTypes -contains 'Unified') { 'Microsoft 365' }
                         elseif ($data.securityEnabled) { 'Security' }
                         else { 'Distribution' }

            $dynamicRule = if ($data.membershipRule) { $data.membershipRule } else { '' }

            $obj = @{
                'ID'                    = $1.id;
                'Tenant ID'             = $1.tenantId;
                'Display Name'          = $data.displayName;
                'Group Type'            = $groupType;
                'Security Enabled'      = $data.securityEnabled;
                'Mail Enabled'          = $data.mailEnabled;
                'Is Role Assignable'    = if ($data.isAssignableToRole) { 'Yes' } else { 'No' };
                'Dynamic Membership'    = if ($data.membershipRule) { 'Yes' } else { 'No' };
                'Dynamic Rule'          = $dynamicRule;
                'On-Premises Sync'      = if ($data.onPremisesSyncEnabled) { 'Yes' } else { 'No' };
                'Description'           = $data.description;
                'Resource U'            = $ResUCount
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
    if ($SmaResources)
    {
        $TableName = ('EntraGroupsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText Yes -Range G:G -ConditionalType ContainsText -BackgroundColor LightGreen

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Group Type')
        $Exc.Add('Security Enabled')
        $Exc.Add('Mail Enabled')
        $Exc.Add('Is Role Assignable')
        $Exc.Add('Dynamic Membership')
        $Exc.Add('Dynamic Rule')
        $Exc.Add('On-Premises Sync')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Entra Groups' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
