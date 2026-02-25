<#
.Synopsis
Inventory for Entra ID Named Locations

.DESCRIPTION
This script consolidates information for all entra/namedlocations resources.
Excel Sheet Name: Named Locations

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Identity/NamedLocations.ps1

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
    $entraNamedLocations = $Resources | Where-Object { $_.TYPE -eq 'entra/namedlocations' }

    if ($entraNamedLocations)
    {
        $tmp = foreach ($1 in $entraNamedLocations) {
            $ResUCount = 1
            $data = $1.properties

            # Determine location type from @odata.type
            $locationType = 'Unknown'
            $ipRanges = ''
            $countries = ''
            $isTrusted = $false
            if ($data.'@odata.type' -eq '#microsoft.graph.ipNamedLocation') {
                $locationType = 'IP Range'
                $isTrusted = [bool]$data.isTrusted
                if ($data.ipRanges) {
                    $ipRanges = ($data.ipRanges | ForEach-Object { $_.cidrAddress }) -join ', '
                }
            }
            elseif ($data.'@odata.type' -eq '#microsoft.graph.countryNamedLocation') {
                $locationType = 'Country'
                if ($data.countriesAndRegions) {
                    $countries = ($data.countriesAndRegions -join ', ')
                }
            }

            $obj = @{
                'ID'               = $1.id;
                'Tenant ID'        = $1.tenantId;
                'Display Name'     = $data.displayName;
                'Location Type'    = $locationType;
                'Is Trusted'       = $isTrusted;
                'IP Ranges'        = $ipRanges;
                'Countries'        = $countries;
                'Created DateTime' = $data.createdDateTime;
                'Modified DateTime'= $data.modifiedDateTime;
                'Resource U'       = $ResUCount
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
        $TableName = ('NamedLocsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Display Name')
        $Exc.Add('Location Type')
        $Exc.Add('Is Trusted')
        $Exc.Add('IP Ranges')
        $Exc.Add('Countries')
        $Exc.Add('Created DateTime')
        $Exc.Add('Modified DateTime')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Named Locations' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -Style $Style
    }
}
