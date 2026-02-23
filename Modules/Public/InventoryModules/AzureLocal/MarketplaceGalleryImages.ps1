<#
.Synopsis
Inventory for Azure Local Marketplace Gallery Images

.DESCRIPTION
This script consolidates information for all microsoft.azurestackhci/marketplacegalleryimages resource provider in $Resources variable.
Excel Sheet Name: AzLocal Marketplace

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AzureLocal/MarketplaceGalleryImages.ps1

.COMPONENT
This powershell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $hciMarketplace = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurestackhci/marketplacegalleryimages' }

    if ($hciMarketplace) {
        $tmp = foreach ($1 in $hciMarketplace) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $Retired = $Retirements | Where-Object { $_.id -eq $1.id }
            if ($Retired) {
                $RetiredFeature = foreach ($Retire in $Retired) {
                    $RetiredServiceID = $Unsupported | Where-Object { $_.Id -eq $Retired.ServiceID }
                    [pscustomobject]@{
                        'RetiredFeature' = $RetiredServiceID.RetiringFeature
                        'RetiredDate'    = $RetiredServiceID.RetirementDate
                    }
                }
                $RetiringFeature = if ($RetiredFeature.RetiredFeature.count -gt 1) { $RetiredFeature.RetiredFeature | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredFeature }
                $RetiringFeature = [string]$RetiringFeature
                $RetiringFeature = if ($RetiringFeature -like '* ,*') { $RetiringFeature -replace ".$" } else { $RetiringFeature }

                $RetiringDate = if ($RetiredFeature.RetiredDate.count -gt 1) { $RetiredFeature.RetiredDate | ForEach-Object { $_ + ' ,' } } else { $RetiredFeature.RetiredDate }
                $RetiringDate = [string]$RetiringDate
                $RetiringDate = if ($RetiringDate -like '* ,*') { $RetiringDate -replace ".$" } else { $RetiringDate }
            }
            else {
                $RetiringFeature = $null
                $RetiringDate = $null
            }

            # Image identifier
            $Identifier = $data.identifier
            $Publisher = $Identifier.publisher
            $Offer = $Identifier.offer
            $SKU = $Identifier.sku

            # Version
            $ImageVersion = $data.version.name

            # Status
            $DownloadStatus = $data.status.downloadStatus.downloadSizeInMB
            $ProgressPercentage = $data.status.progressPercentage

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                     = $1.id;
                    'Subscription'           = $sub1.name;
                    'Resource Group'         = $1.RESOURCEGROUP;
                    'Name'                   = $1.NAME;
                    'Location'               = $1.LOCATION;
                    'Retiring Feature'       = $RetiringFeature;
                    'Retiring Date'          = $RetiringDate;
                    'Provisioning State'     = $data.provisioningState;
                    'Status'                 = $data.status.provisioningStatus.status;
                    'OS Type'                = $data.osType;
                    'Hyper-V Generation'     = $data.hyperVGeneration;
                    'Publisher'              = $Publisher;
                    'Offer'                  = $Offer;
                    'SKU'                    = $SKU;
                    'Version'                = $ImageVersion;
                    'Download Size MB'       = $DownloadStatus;
                    'Progress Percentage'    = $ProgressPercentage;
                    'Resource U'             = $ResUCount;
                    'Tag Name'               = [string]$Tag.Name;
                    'Tag Value'              = [string]$Tag.Value
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

<######## Resource Excel Reporting Begins Here ########>

Else {
    if ($SmaResources) {

        $TableName = ('AzLocalMktplace_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0'

        $condtxt = @()
        $condtxt += New-ConditionalText -Range F2:F100 -ConditionalType ContainsText

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Provisioning State')
        $Exc.Add('Retiring Feature')
        $Exc.Add('Retiring Date')
        $Exc.Add('Status')
        $Exc.Add('OS Type')
        $Exc.Add('Hyper-V Generation')
        $Exc.Add('Publisher')
        $Exc.Add('Offer')
        $Exc.Add('SKU')
        $Exc.Add('Version')
        $Exc.Add('Download Size MB')
        $Exc.Add('Progress Percentage')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'AzLocal Marketplace' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
