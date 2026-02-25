<#
.Synopsis
Inventory for Entra ID Administrative Units

.DESCRIPTION
This script consolidates information for all entra/administrativeunits resources.
Excel Sheet Name: Admin Units

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/AdminUnits.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: AzureScout Contributors
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraAdminUnits = $Resources | Where-Object { $_.TYPE -eq 'entra/administrativeunits' }

    if ($entraAdminUnits)
    {
        $tmp = foreach ($1 in $entraAdminUnits) {
            $ResUCount = 1
            $data = $1.properties

            $membershipType = if ($data.membershipType) { $data.membershipType } else { 'Assigned' }
            $membershipRule = if ($data.membershipRule) { $data.membershipRule } else { '' }

            $obj = @{
                'ID'                = $1.id;
                'Tenant ID'         = $1.tenantId;
                'Display Name'      = $data.displayName;
                'Description'       = $data.description;
                'Membership Type'   = $membershipType;
                'Membership Rule'   = $membershipRule;
                'Visibility'        = $data.visibility;
                'Resource U'        = $ResUCount
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
        $TableName = ('AdminUnitsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Description')
        $Exc.Add('Membership Type')
        $Exc.Add('Membership Rule')
        $Exc.Add('Visibility')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Admin Units' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
