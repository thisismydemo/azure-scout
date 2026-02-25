<#
.Synopsis
Inventory for Entra ID PIM Role Assignments

.DESCRIPTION
This script consolidates information for all entra/pimassignments resources.
Excel Sheet Name: PIM Assignments

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/PIMAssignments.ps1

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
    $entraPIM = $Resources | Where-Object { $_.TYPE -eq 'entra/pimassignments' }

    if ($entraPIM)
    {
        $tmp = foreach ($1 in $entraPIM) {
            $ResUCount = 1
            $data = $1.properties

            # Extract expanded principal and role definition names
            $principalName = ''
            $principalType = ''
            if ($data.principal) {
                $principalName = $data.principal.displayName
                if ($data.principal.'@odata.type') {
                    $principalType = $data.principal.'@odata.type' -replace '#microsoft\.graph\.', ''
                }
            }

            $roleName = ''
            if ($data.roleDefinition) {
                $roleName = $data.roleDefinition.displayName
            }

            $obj = @{
                'ID'                  = $data.id;
                'Tenant ID'           = $1.tenantId;
                'Principal Name'      = $principalName;
                'Principal ID'        = $data.principalId;
                'Principal Type'      = $principalType;
                'Role Name'           = $roleName;
                'Role Definition ID'  = $data.roleDefinitionId;
                'Directory Scope'     = $data.directoryScopeId;
                'Resource U'          = $ResUCount
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
        $TableName = ('PIMTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Principal Name')
        $Exc.Add('Principal Type')
        $Exc.Add('Role Name')
        $Exc.Add('Principal ID')
        $Exc.Add('Role Definition ID')
        $Exc.Add('Directory Scope')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'PIM Assignments' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
