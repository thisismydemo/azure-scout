<#
.Synopsis
Inventory for Azure OpenAI Deployments

.DESCRIPTION
This script retrieves all model deployments within Azure OpenAI accounts
via the ARM REST API (microsoft.cognitiveservices/accounts/deployments).
Excel Sheet Name: OpenAI Deployments

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/OpenAIDeployments.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY AI

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $openAI = $Resources | Where-Object { $_.TYPE -eq 'microsoft.cognitiveservices/accounts' -and $_.KIND -eq 'OpenAI' }

    if ($openAI) {
        $tmp = foreach ($account in $openAI) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $account.subscriptionId }

            $apiVersion = '2023-05-01'
            $uri = "/subscriptions/$($account.subscriptionId)/resourceGroups/$($account.RESOURCEGROUP)/providers/Microsoft.CognitiveServices/accounts/$($account.NAME)/deployments?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result = $response.Content | ConvertFrom-Json
                    $deployments = if ($result.value) { $result.value } else { $result }
                    foreach ($1 in $deployments) {
                        $ResUCount = 1
                        $dData = $1.properties
                        $model = $dData.model

                        $obj = @{
                            'Account Name'         = $account.NAME;
                            'Subscription'         = $sub1.Name;
                            'Resource Group'       = $account.RESOURCEGROUP;
                            'Location'             = $account.LOCATION;
                            'Deployment Name'      = $1.name;
                            'Model Name'           = if ($model.name)    { $model.name }    else { 'N/A' };
                            'Model Version'        = if ($model.version) { $model.version } else { 'N/A' };
                            'Model Format'         = if ($model.format)  { $model.format }  else { 'N/A' };
                            'Scale Type'           = if ($dData.scaleSettings.scaleType)     { $dData.scaleSettings.scaleType }     else { 'N/A' };
                            'Capacity (PTUs)'      = if ($dData.scaleSettings.capacity)      { $dData.scaleSettings.capacity }      else { 'N/A' };
                            'Dynamic Throttling'   = if ($dData.dynamicThrottlingEnabled -eq $true) { 'Yes' } else { 'No' };
                            'Provisioning State'   = if ($dData.provisioningState) { $dData.provisioningState } else { 'N/A' };
                            'Resource U'           = $ResUCount;
                            'Tag Name'             = '';
                            'Tag Value'            = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("OpenAIDeployments: Failed for $($account.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('OpenAIDeploymentsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Account Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Location')
        $Exc.Add('Deployment Name')
        $Exc.Add('Model Name')
        $Exc.Add('Model Version')
        $Exc.Add('Model Format')
        $Exc.Add('Scale Type')
        $Exc.Add('Capacity (PTUs)')
        $Exc.Add('Dynamic Throttling')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'OpenAI Deployments' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
