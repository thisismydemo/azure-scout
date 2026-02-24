<#
.Synopsis
Inventory for Azure Applied AI Services

.DESCRIPTION
This script consolidates information for Applied AI Services accounts
(Form Recognizer / Document Intelligence, Metrics Advisor, Anomaly Detector,
Personalizer, Immersive Reader variants).
Excel Sheet Name: Applied AI Services

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/AppliedAIServices.ps1

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
    $appliedAIKinds = @(
        'FormRecognizer', 'documentIntelligence', 'MetricsAdvisor',
        'AnomalyDetector', 'Personalizer', 'ImmersiveReader'
    )

    $appliedAI = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.cognitiveservices/accounts' -and
        $appliedAIKinds -contains $_.KIND
    }

    if ($appliedAI) {
        $tmp = foreach ($1 in $appliedAI) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $peCount = if ($data.privateEndpointConnections) { @($data.privateEndpointConnections).Count } else { 0 }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                      = $1.id;
                    'Subscription'            = $sub1.Name;
                    'Resource Group'          = $1.RESOURCEGROUP;
                    'Name'                    = $1.NAME;
                    'Location'                = $1.LOCATION;
                    'Kind'                    = if ($1.KIND) { $1.KIND } else { 'N/A' };
                    'SKU'                     = if ($1.SKU.name)                    { $1.SKU.name }                    else { 'N/A' };
                    'Endpoint'                = if ($data.endpoint)                 { $data.endpoint }                 else { 'N/A' };
                    'Custom Subdomain'        = if ($data.customSubDomainName)      { $data.customSubDomainName }      else { 'N/A' };
                    'Public Network Access'   = if ($data.publicNetworkAccess)      { $data.publicNetworkAccess }      else { 'N/A' };
                    'Private Endpoints'       = $peCount;
                    'Disable Local Auth'      = if ($data.disableLocalAuth -eq $true) { 'Yes' } else { 'No' };
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
        $TableName = ('AppliedAISvcTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Kind')
        $Exc.Add('SKU')
        $Exc.Add('Endpoint')
        $Exc.Add('Custom Subdomain')
        $Exc.Add('Public Network Access')
        $Exc.Add('Private Endpoints')
        $Exc.Add('Disable Local Auth')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Applied AI Services' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
