<#
.Synopsis
Inventory for Azure Bot Services

.DESCRIPTION
This script consolidates information for all Azure Bot Service resources
(microsoft.botservice/botservices).
Excel Sheet Name: Bot Services

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/BotServices.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY AI

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $botServices = $Resources | Where-Object { $_.TYPE -eq 'microsoft.botservice/botservices' }

    if ($botServices) {
        $tmp = foreach ($1 in $botServices) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                       = $1.id;
                    'Subscription'             = $sub1.Name;
                    'Resource Group'           = $1.RESOURCEGROUP;
                    'Name'                     = $1.NAME;
                    'Location'                 = $1.LOCATION;
                    'SKU'                      = if ($1.SKU.name)                  { $1.SKU.name }                  else { 'N/A' };
                    'Display Name'             = if ($data.displayName)            { $data.displayName }            else { 'N/A' };
                    'Messaging Endpoint'       = if ($data.endpoint)               { $data.endpoint }               else { 'N/A' };
                    'App ID'                   = if ($data.msaAppId)               { $data.msaAppId }               else { 'N/A' };
                    'MSA App Type'             = if ($data.msaAppType)             { $data.msaAppType }             else { 'N/A' };
                    'Developer App Key'        = if ($data.developerAppInsightsKey){ $data.developerAppInsightsKey} else { 'N/A' };
                    'CMEK Enabled'             = if ($data.isCmekEnabled -eq $true){ 'Yes' }                        else { 'No' };
                    'Public Network Access'    = if ($data.publicNetworkAccess)    { $data.publicNetworkAccess }    else { 'N/A' };
                    'Schema Transformation Ver'= if ($data.schemaTransformationVersion) { $data.schemaTransformationVersion } else { 'N/A' };
                    'Provisioning State'       = if ($data.provisioningState)      { $data.provisioningState }      else { 'N/A' };
                    'Resource U'               = $ResUCount;
                    'Tag Name'                 = [string]$Tag.Name;
                    'Tag Value'                = [string]$Tag.Value;
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
        $TableName = ('BotServicesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('SKU')
        $Exc.Add('Display Name')
        $Exc.Add('Messaging Endpoint')
        $Exc.Add('App ID')
        $Exc.Add('MSA App Type')
        $Exc.Add('CMEK Enabled')
        $Exc.Add('Public Network Access')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Bot Services' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
