<#
.Synopsis
Inventory for Azure AI Foundry Hubs

.DESCRIPTION
This script consolidates information for all Azure AI Foundry Hub resources
(microsoft.machinelearningservices/workspaces where kind == 'Hub').
Excel Sheet Name: AI Foundry Hubs

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/AIFoundryHubs.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY AI

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    # AI Foundry Hubs are ML workspaces with kind = 'Hub'
    $hubs = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.machinelearningservices/workspaces' -and $_.KIND -eq 'Hub'
    }

    if ($hubs) {
        $tmp = foreach ($1 in $hubs) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Associated resources
            $storageAccount = if ($data.storageAccount)        { ($data.storageAccount -split '/')[-1] }        else { 'N/A' }
            $keyVault       = if ($data.keyVault)              { ($data.keyVault -split '/')[-1] }              else { 'N/A' }
            $appInsights    = if ($data.applicationInsights)   { ($data.applicationInsights -split '/')[-1] }   else { 'N/A' }
            $containerReg   = if ($data.containerRegistry)     { ($data.containerRegistry -split '/')[-1] }     else { 'None' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                      = $1.id;
                    'Subscription'            = $sub1.Name;
                    'Resource Group'          = $1.RESOURCEGROUP;
                    'Hub Name'                = $1.NAME;
                    'Location'                = $1.LOCATION;
                    'Friendly Name'           = if ($data.friendlyName)             { $data.friendlyName }             else { 'N/A' };
                    'Description'             = if ($data.description)              { $data.description }              else { 'N/A' };
                    'SKU'                     = if ($1.SKU.name)                    { $1.SKU.name }                    else { 'N/A' };
                    'Public Network Access'   = if ($data.publicNetworkAccess)      { $data.publicNetworkAccess }      else { 'N/A' };
                    'Storage Account'         = $storageAccount;
                    'Key Vault'               = $keyVault;
                    'App Insights'            = $appInsights;
                    'Container Registry'      = $containerReg;
                    'Provisioning State'      = if ($data.provisioningState)        { $data.provisioningState }        else { 'N/A' };
                    'Resource U'              = $ResUCount;
                    'Tag Name'                = [string]$Tag.Name;
                    'Tag Value'               = [string]$Tag.Value;
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
        $TableName = ('AIFoundryHubsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Hub Name')
        $Exc.Add('Location')
        $Exc.Add('Friendly Name')
        $Exc.Add('Description')
        $Exc.Add('SKU')
        $Exc.Add('Public Network Access')
        $Exc.Add('Storage Account')
        $Exc.Add('Key Vault')
        $Exc.Add('App Insights')
        $Exc.Add('Container Registry')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'AI Foundry Hubs' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
