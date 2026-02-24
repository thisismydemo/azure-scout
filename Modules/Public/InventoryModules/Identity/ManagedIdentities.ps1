<#
.Synopsis
Inventory for Entra ID Managed Identities

.DESCRIPTION
This script consolidates information for all entra/managedidentities resources.
Excel Sheet Name: Managed Identities

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Identity/ManagedIdentities.ps1

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
    $entraMIs = $Resources | Where-Object { $_.TYPE -eq 'entra/managedidentities' }

    if ($entraMIs)
    {
        $tmp = foreach ($1 in $entraMIs) {
            $ResUCount = 1
            $data = $1.properties

            # Determine type from alternativeNames
            $miType = 'Unknown'
            $associatedResource = ''
            if ($data.alternativeNames) {
                $altNames = @($data.alternativeNames)
                if ($altNames -match 'isExplicit=True') {
                    $miType = 'User-Assigned'
                }
                else {
                    $miType = 'System-Assigned'
                }
                # The resource URI is typically the second alternative name
                $resourceUri = $altNames | Where-Object { $_ -match '^/subscriptions/' -or $_ -match '^/providers/' }
                if ($resourceUri) {
                    $associatedResource = ($resourceUri | Select-Object -First 1)
                }
            }

            $obj = @{
                'ID'                    = $1.id;
                'Tenant ID'             = $1.tenantId;
                'Display Name'          = $data.displayName;
                'Application ID'        = $data.appId;
                'Identity Type'         = $miType;
                'Associated Resource'   = $associatedResource;
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
        $TableName = ('ManagedIdsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Application ID')
        $Exc.Add('Identity Type')
        $Exc.Add('Associated Resource')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Managed Identities' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
