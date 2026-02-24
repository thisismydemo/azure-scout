<#
.Synopsis
Inventory for Entra ID Security / Authorization Policies

.DESCRIPTION
This script consolidates information for all entra/securitypolicies resources.
Excel Sheet Name: Security Policies

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/SecurityPolicies.ps1

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
    $entraSecPol = $Resources | Where-Object { $_.TYPE -eq 'entra/securitypolicies' }

    if ($entraSecPol)
    {
        $tmp = foreach ($1 in $entraSecPol) {
            $ResUCount = 1
            $data = $1.properties

            # Default user role permissions
            $allowCreateApps = ''
            $allowCreateGroups = ''
            $allowReadOtherUsers = ''
            if ($data.defaultUserRolePermissions) {
                $allowCreateApps = [string]$data.defaultUserRolePermissions.allowedToCreateApps
                $allowCreateGroups = [string]$data.defaultUserRolePermissions.allowedToCreateSecurityGroups
                $allowReadOtherUsers = [string]$data.defaultUserRolePermissions.allowedToReadOtherUsers
            }

            $obj = @{
                'ID'                           = $1.id;
                'Tenant ID'                    = $1.tenantId;
                'Display Name'                 = $1.name;
                'Guest User Role ID'           = $data.guestUserRoleId;
                'Allow Invites From'           = $data.allowInvitesFrom;
                'Allow Email Subscriptions'    = [string]$data.allowedToSignUpEmailBasedSubscriptions;
                'Allow Email Verified Join'    = [string]$data.allowEmailVerifiedUsersToJoinOrganization;
                'Allow SSPR'                   = [string]$data.allowedToUseSSPR;
                'Block MSOL PowerShell'        = [string]$data.blockMsolPowerShell;
                'Allow Create Apps'            = $allowCreateApps;
                'Allow Create Security Groups' = $allowCreateGroups;
                'Allow Read Other Users'       = $allowReadOtherUsers;
                'Resource U'                   = $ResUCount
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
        $TableName = ('SecPolTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Guest User Role ID')
        $Exc.Add('Allow Invites From')
        $Exc.Add('Allow Email Subscriptions')
        $Exc.Add('Allow Email Verified Join')
        $Exc.Add('Allow SSPR')
        $Exc.Add('Block MSOL PowerShell')
        $Exc.Add('Allow Create Apps')
        $Exc.Add('Allow Create Security Groups')
        $Exc.Add('Allow Read Other Users')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Security Policies' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
