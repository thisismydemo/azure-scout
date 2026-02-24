<#
.Synopsis
Inventory for Azure OpenAI Accounts

.DESCRIPTION
This script consolidates information for all Azure OpenAI Cognitive Services accounts
(microsoft.cognitiveservices/accounts where kind == 'OpenAI').
Excel Sheet Name: OpenAI Accounts

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/OpenAIAccounts.ps1

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
    $openAI = $Resources | Where-Object { $_.TYPE -eq 'microsoft.cognitiveservices/accounts' -and $_.KIND -eq 'OpenAI' }

    if ($openAI) {
        $tmp = foreach ($1 in $openAI) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Private endpoints
            $peCount = if ($data.privateEndpointConnections) { @($data.privateEndpointConnections).Count } else { 0 }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                        = $1.id;
                    'Subscription'              = $sub1.Name;
                    'Resource Group'            = $1.RESOURCEGROUP;
                    'Name'                      = $1.NAME;
                    'Location'                  = $1.LOCATION;
                    'SKU'                       = if ($1.SKU.name) { $1.SKU.name } else { 'N/A' };
                    'Endpoint'                  = if ($data.endpoint)               { $data.endpoint }               else { 'N/A' };
                    'Custom Subdomain'          = if ($data.customSubDomainName)    { $data.customSubDomainName }    else { 'N/A' };
                    'Public Network Access'     = if ($data.publicNetworkAccess)    { $data.publicNetworkAccess }    else { 'N/A' };
                    'Private Endpoints'         = $peCount;
                    'Network ACL Default'       = if ($data.networkAcls.defaultAction) { $data.networkAcls.defaultAction } else { 'N/A' };
                    'Disable Local Auth'        = if ($data.disableLocalAuth -eq $true) { 'Yes' } else { 'No' };
                    'Provisioning State'        = if ($data.provisioningState)      { $data.provisioningState }      else { 'N/A' };
                    'Resource U'                = $ResUCount;
                    'Tag Name'                  = [string]$Tag.Name;
                    'Tag Value'                 = [string]$Tag.Value;
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
        $TableName = ('OpenAIAccountsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Cond  = New-ConditionalText -ConditionalType ContainsText 'Succeeded' -ConditionalTextColor ([System.Drawing.Color]::FromArgb(0,176,80))  -BackgroundColor ([System.Drawing.Color]::White)
        $Cond2 = New-ConditionalText -ConditionalType ContainsText 'Failed'    -ConditionalTextColor ([System.Drawing.Color]::White) -BackgroundColor ([System.Drawing.Color]::Red)

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('SKU')
        $Exc.Add('Endpoint')
        $Exc.Add('Custom Subdomain')
        $Exc.Add('Public Network Access')
        $Exc.Add('Private Endpoints')
        $Exc.Add('Network ACL Default')
        $Exc.Add('Disable Local Auth')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'OpenAI Accounts' `
            -AutoSize -MaxAutoSizeRows 100 `
            -ConditionalText $Cond, $Cond2 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
