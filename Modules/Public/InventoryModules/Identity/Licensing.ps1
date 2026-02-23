<#
.Synopsis
Inventory for Entra ID Licensing (Subscribed SKUs)

.DESCRIPTION
This script consolidates information for all entra/subscribedskus resources.
Excel Sheet Name: Licensing

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/Licensing.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 2026-02-23
Authors: Product Technology Team
#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $entraLicensing = $Resources | Where-Object { $_.TYPE -eq 'entra/subscribedskus' }

    if ($entraLicensing)
    {
        $tmp = foreach ($1 in $entraLicensing) {
            $ResUCount = 1
            $data = $1.properties

            $prepaidEnabled = 0
            $prepaidSuspended = 0
            $prepaidWarning = 0
            if ($data.prepaidUnits) {
                $prepaidEnabled = [int]$data.prepaidUnits.enabled
                $prepaidSuspended = [int]$data.prepaidUnits.suspended
                $prepaidWarning = [int]$data.prepaidUnits.warning
            }

            $obj = @{
                'ID'                 = $1.id;
                'Tenant ID'          = $1.tenantId;
                'SKU Part Number'    = $data.skuPartNumber;
                'SKU ID'             = $data.skuId;
                'Consumed Units'     = [int]$data.consumedUnits;
                'Prepaid Enabled'    = $prepaidEnabled;
                'Prepaid Suspended'  = $prepaidSuspended;
                'Prepaid Warning'    = $prepaidWarning;
                'Applies To'         = $data.appliesTo;
                'Capability Status'  = $data.capabilityStatus;
                'Resource U'         = $ResUCount
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
        $TableName = ('LicensingTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText Suspended -Range J:J
        $condtxt += New-ConditionalText Warning -Range J:J

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('SKU Part Number')
        $Exc.Add('SKU ID')
        $Exc.Add('Consumed Units')
        $Exc.Add('Prepaid Enabled')
        $Exc.Add('Prepaid Suspended')
        $Exc.Add('Prepaid Warning')
        $Exc.Add('Applies To')
        $Exc.Add('Capability Status')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Licensing' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
