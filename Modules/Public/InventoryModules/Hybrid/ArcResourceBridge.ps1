<#
.Synopsis
Inventory for Azure Arc Resource Bridge (Appliances)

.DESCRIPTION
This script consolidates information for all microsoft.resourceconnector/appliances resource provider in $Resources variable.
Excel Sheet Name: Arc Resource Bridge

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Hybrid/ArcResourceBridge.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: 23rd February, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing') {

    $arcBridge = $Resources | Where-Object { $_.TYPE -eq 'microsoft.resourceconnector/appliances' }

    if ($arcBridge) {
        $tmp = foreach ($1 in $arcBridge) {
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

            # Identity
            $IdentityType = if ($1.identity) { $1.identity.type } else { $null }

            # Enhanced config details
            $KubeconfigPresent = if ($data.publicKeyInfo) { 'Yes' } else { 'No' }
            $InfraSubType      = if ($data.infrastructureConfig.provisioningState) { $data.infrastructureConfig.provisioningState } else { 'N/A' }

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
                    'Status'                 = $data.status;
                    'Distro'                 = $data.distro;
                    'Version'                = $data.version;
                    'Infrastructure Type'    = $data.infrastructureConfig.provider;
                    'Identity Type'          = $IdentityType;
                    'Kubeconfig Present'     = $KubeconfigPresent;
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

        $TableName = ('ArcBridge_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
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
        $Exc.Add('Distro')
        $Exc.Add('Version')
        $Exc.Add('Infrastructure Type')
        $Exc.Add('Identity Type')
        $Exc.Add('Kubeconfig Present')
        if ($InTag) {
            $Exc.Add('Tag Name')
            $Exc.Add('Tag Value')
        }
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File -WorksheetName 'Arc Resource Bridge' -AutoSize -MaxAutoSizeRows 100 -TableName $TableName -TableStyle $tableStyle -ConditionalText $condtxt -Style $Style
    }
}
