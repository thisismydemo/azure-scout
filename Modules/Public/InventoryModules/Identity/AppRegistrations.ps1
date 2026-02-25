<#
.Synopsis
Inventory for Entra ID App Registrations

.DESCRIPTION
This script consolidates information for all entra/applications resources.
Excel Sheet Name: App Registrations

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/AppRegistrations.ps1

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
    $entraApps = $Resources | Where-Object { $_.TYPE -eq 'entra/applications' }

    if ($entraApps)
    {
        $tmp = foreach ($1 in $entraApps) {
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

            $permissionCount = 0
            if ($data.requiredResourceAccess) {
                $permissionCount = @($data.requiredResourceAccess).Count
            }

            $obj = @{
                'ID'                      = $1.id;
                'Tenant ID'               = $1.tenantId;
                'Display Name'            = $data.displayName;
                'Application ID'          = $data.appId;
                'Sign-In Audience'        = $data.signInAudience;
                'Key Credential Expiry'   = $keyExpiry;
                'Password Credential Expiry' = $passwordExpiry;
                'API Permission Count'    = $permissionCount;
                'Publisher Domain'        = $data.publisherDomain;
                'Created DateTime'        = $data.createdDateTime;
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
        $TableName = ('AppRegsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Application ID')
        $Exc.Add('Sign-In Audience')
        $Exc.Add('Key Credential Expiry')
        $Exc.Add('Password Credential Expiry')
        $Exc.Add('API Permission Count')
        $Exc.Add('Publisher Domain')
        $Exc.Add('Created DateTime')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'App Registrations' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
