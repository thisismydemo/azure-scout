<#
.Synopsis
Inventory for Entra ID Directory Roles

.DESCRIPTION
This script consolidates information for all entra/directoryroles resources.
Excel Sheet Name: Directory Roles

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/DirectoryRoles.ps1

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
    $entraRoles = $Resources | Where-Object { $_.TYPE -eq 'entra/directoryroles' }

    if ($entraRoles)
    {
        $tmp = foreach ($1 in $entraRoles) {
            $ResUCount = 1
            $data = $1.properties

            $obj = @{
                'ID'                = $1.id;
                'Tenant ID'         = $1.tenantId;
                'Display Name'      = $data.displayName;
                'Role Template ID'  = $data.roleTemplateId;
                'Description'       = $data.description;
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
        $TableName = ('DirRolesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Role Template ID')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Directory Roles' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
