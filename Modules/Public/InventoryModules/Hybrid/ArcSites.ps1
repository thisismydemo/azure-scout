<#
.Synopsis
Inventory for Azure Arc Sites

.DESCRIPTION
This script consolidates information for all Azure Stack HCI (Azure Local) Site resources
(microsoft.azurestackhci/sites) and EdgeConfig sites.
Excel Sheet Name: Arc Sites

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Hybrid/ArcSites.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $arcSites = $Resources | Where-Object {
        $_.TYPE -in @(
            'microsoft.azurestackhci/sites',
            'microsoft.edgeconfig/sites',
            'microsoft.hybridcompute/sites'
        )
    }

    if ($arcSites) {
        $tmp = foreach ($1 in $arcSites) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Determine site type from resource type
            $siteType = switch ($1.TYPE) {
                'microsoft.azurestackhci/sites'    { 'Azure Local (HCI)' }
                'microsoft.edgeconfig/sites'       { 'Edge Config' }
                'microsoft.hybridcompute/sites'    { 'Arc Hybrid Compute' }
                default { 'Unknown' }
            }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                    = $1.id;
                    'Subscription'          = $sub1.Name;
                    'Resource Group'        = $1.RESOURCEGROUP;
                    'Name'                  = $1.NAME;
                    'Location'              = $1.LOCATION;
                    'Site Type'             = $siteType;
                    'Display Name'          = if ($data.displayName)             { $data.displayName }             else { 'N/A' };
                    'Address'               = if ($data.address)                 { $data.address }                 else { 'N/A' };
                    'Country/Region'        = if ($data.country)                 { $data.country }                 else { 'N/A' };
                    'Description'           = if ($data.description)             { $data.description }             else { 'N/A' };
                    'Provisioning State'    = if ($data.provisioningState)       { $data.provisioningState }       else { 'N/A' };
                    'Resource U'            = $ResUCount;
                    'Tag Name'              = [string]$Tag.Name;
                    'Tag Value'             = [string]$Tag.Value;
                }
                $obj
                if ($ResUCount -eq 1) { $ResUCount = 0 }
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('ArcSitesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Site Type')
        $Exc.Add('Display Name')
        $Exc.Add('Address')
        $Exc.Add('Country/Region')
        $Exc.Add('Description')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Arc Sites' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
