<#
.Synopsis
Inventory for Entra ID Users

.DESCRIPTION
This script consolidates information for all entra/users resources.
Excel Sheet Name: Entra Users

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/Users.ps1

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
    $entraUsers = $Resources | Where-Object { $_.TYPE -eq 'entra/users' }

    if ($entraUsers)
    {
        $tmp = foreach ($1 in $entraUsers) {
            $ResUCount = 1
            $data = $1.properties

            $licenseCount = 0
            if ($null -ne $data.assignedLicenses) {
                $licenseCount = @($data.assignedLicenses).Count
            }

            $obj = @{
                'ID'                      = $1.id;
                'Tenant ID'               = $1.tenantId;
                'Display Name'            = $data.displayName;
                'User Principal Name'     = $data.userPrincipalName;
                'User Type'               = $data.userType;
                'Account Enabled'         = $data.accountEnabled;
                'Created DateTime'        = $data.createdDateTime;
                'Last Password Change'    = $data.lastPasswordChangeDateTime;
                'Assigned License Count'  = $licenseCount;
                'On-Premises Sync'        = if ($data.onPremisesSyncEnabled) { 'Yes' } else { 'No' };
                'Department'              = $data.department;
                'Job Title'               = $data.jobTitle;
                'Mail'                    = $data.mail;
                'Resource U'              = $ResUCount
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
        $TableName = ('EntraUsersTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText False -Range F:F
        $condtxt += New-ConditionalText 0 -Range I:I

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('User Principal Name')
        $Exc.Add('User Type')
        $Exc.Add('Account Enabled')
        $Exc.Add('Created DateTime')
        $Exc.Add('Last Password Change')
        $Exc.Add('Assigned License Count')
        $Exc.Add('On-Premises Sync')
        $Exc.Add('Department')
        $Exc.Add('Job Title')
        $Exc.Add('Mail')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Entra Users' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
