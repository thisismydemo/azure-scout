<#
.Synopsis
Inventory for Entra ID Domains

.DESCRIPTION
This script consolidates information for all entra/domains resources.
Excel Sheet Name: Entra Domains

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/Domains.ps1

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
    $entraDomains = $Resources | Where-Object { $_.TYPE -eq 'entra/domains' }

    if ($entraDomains)
    {
        $tmp = foreach ($1 in $entraDomains) {
            $ResUCount = 1
            $data = $1.properties

            # supportedServices is an array
            $supportedServices = ''
            if ($data.supportedServices) {
                $supportedServices = ($data.supportedServices -join ', ')
            }

            $obj = @{
                'ID'                    = $1.id;
                'Tenant ID'             = $1.tenantId;
                'Domain Name'           = $data.id;
                'Is Verified'           = [bool]$data.isVerified;
                'Is Default'            = [bool]$data.isDefault;
                'Is Admin Managed'      = [bool]$data.isAdminManaged;
                'Authentication Type'   = $data.authenticationType;
                'Supported Services'    = $supportedServices;
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
        $TableName = ('DomainsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText False -Range D:D

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Domain Name')
        $Exc.Add('Is Verified')
        $Exc.Add('Is Default')
        $Exc.Add('Is Admin Managed')
        $Exc.Add('Authentication Type')
        $Exc.Add('Supported Services')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Entra Domains' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
