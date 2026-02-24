<#
.Synopsis
Inventory for Entra ID Service Principals

.DESCRIPTION
This script consolidates information for all entra/serviceprincipals resources.
Excel Sheet Name: Service Principals

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/ServicePrincipals.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: AzureScout Contributors
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraSPs = $Resources | Where-Object { $_.TYPE -eq 'entra/serviceprincipals' }

    if ($entraSPs)
    {
        $tmp = foreach ($1 in $entraSPs) {
            $ResUCount = 1
            $data = $1.properties

            # Get nearest key credential expiry
            $keyExpiry = $null
            if ($data.keyCredentials) {
                $keyExpiry = ($data.keyCredentials | Sort-Object endDateTime | Select-Object -First 1).endDateTime
            }

            # Get nearest password credential expiry
            $passwordExpiry = $null
            if ($data.passwordCredentials) {
                $passwordExpiry = ($data.passwordCredentials | Sort-Object endDateTime | Select-Object -First 1).endDateTime
            }

            $tagList = ''
            if ($data.tags) {
                $tagList = ($data.tags -join ', ')
            }

            $obj = @{
                'ID'                         = $1.id;
                'Tenant ID'                  = $1.tenantId;
                'Display Name'               = $data.displayName;
                'Application ID'             = $data.appId;
                'Service Principal Type'     = $data.servicePrincipalType;
                'Account Enabled'            = $data.accountEnabled;
                'App Owner Organization ID'  = $data.appOwnerOrganizationId;
                'Key Credential Expiry'      = $keyExpiry;
                'Password Credential Expiry' = $passwordExpiry;
                'Tags'                       = $tagList;
                'Resource U'                 = $ResUCount
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
        $TableName = ('SPsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText False -Range F:F

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Application ID')
        $Exc.Add('Service Principal Type')
        $Exc.Add('Account Enabled')
        $Exc.Add('App Owner Organization ID')
        $Exc.Add('Key Credential Expiry')
        $Exc.Add('Password Credential Expiry')
        $Exc.Add('Tags')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Service Principals' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
