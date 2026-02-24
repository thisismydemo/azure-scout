<#
.Synopsis
Inventory for Azure Custom RBAC Role Definitions

.DESCRIPTION
This script consolidates information for all custom Azure RBAC role definitions.
Excel Sheet Name: Custom Roles

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/CustomRoleDefinitions.ps1

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

        # Get all custom role definitions (exclude built-in roles)
        $customRoles = Get-AzRoleDefinition -Custom -ErrorAction SilentlyContinue

    <######### Insert the resource Process here ########>

    if($customRoles)
        {
            $tmp = foreach ($role in $customRoles) {
                $ResUCount = 1

                # Parse actions
                $actions = if ($role.Actions) { ($role.Actions -join '; ') } else { 'None' }
                $notActions = if ($role.NotActions) { ($role.NotActions -join '; ') } else { 'None' }
                $dataActions = if ($role.DataActions) { ($role.DataActions -join '; ') } else { 'None' }
                $notDataActions = if ($role.NotDataActions) { ($role.NotDataActions -join '; ') } else { 'None' }

                # Parse assignable scopes
                $scopes = if ($role.AssignableScopes) { ($role.AssignableScopes -join '; ') } else { 'None' }

                $obj = @{
                    'ID'                    = $role.Id;
                    'Role Name'             = $role.Name;
                    'Description'           = $role.Description;
                    'Role Type'             = $role.RoleType;
                    'Is Custom'             = $role.IsCustom;
                    'Assignable Scopes'     = $scopes;
                    'Actions'               = $actions;
                    'Not Actions'           = $notActions;
                    'Data Actions'          = $dataActions;
                    'Not Data Actions'      = $notDataActions;
                    'Created On'            = if ($role.CreatedOn) { ([datetime]$role.CreatedOn).ToString("yyyy-MM-dd HH:mm") } else { $null };
                    'Updated On'            = if ($role.UpdatedOn) { ([datetime]$role.UpdatedOn).ToString("yyyy-MM-dd HH:mm") } else { $null };
                    'Created By'            = $role.CreatedBy;
                    'Updated By'            = $role.UpdatedBy;
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

        $TableName = ('CustomRolesTable_'+(($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'
        $StyleExt = New-ExcelStyle -HorizontalAlignment Left -Range F:J -Width 50 -WrapText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Role Name')
        $Exc.Add('Description')
        $Exc.Add('Role Type')
        $Exc.Add('Is Custom')
        $Exc.Add('Assignable Scopes')
        $Exc.Add('Actions')
        $Exc.Add('Not Actions')
        $Exc.Add('Data Actions')
        $Exc.Add('Not Data Actions')
        $Exc.Add('Created On')
        $Exc.Add('Updated On')
        $Exc.Add('Created By')
        $Exc.Add('Updated By')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Custom Roles' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style, $StyleExt

    }
}
