<#
.Synopsis
Module responsible for retrieving Azure VM SKU details.

.DESCRIPTION
This module retrieves details about Azure VM SKUs available in specific locations.

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/1.ExtractionFunctions/ResourceDetails/Get-AZSCVMSkuDetails.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.NOTES
Version: 3.6.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola, Olli Uronen (Seppohto)
#>
function Get-AZSCVMSkuDetails {
    Param ($Resources)

    $vm = $Resources | Where-Object {$_.TYPE -in 'microsoft.compute/virtualmachines','microsoft.compute/virtualmachinescalesets'}

    $VMskuData = Foreach($location in ($vm | Select-Object -ExpandProperty location -Unique))
        {
            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Getting VM SKU Details: '+$location)
            $tmp = [PSCustomObject]@{
                Location    = $location
                SKUs        = Get-AzComputeResourceSku $location -Debug:$false
            }
            $tmp
        }

    $VMSkuDetails = [PSCustomObject]@{
        'type'          = 'AZSC/VM/SKU'
        'properties'    = $VMskuData
    }

    return $VMSkuDetails
}