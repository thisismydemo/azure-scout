<#
.Synopsis
Inventory for Azure Machine Learning Models

.DESCRIPTION
This script retrieves all registered models within Azure Machine Learning workspaces
via the ARM REST API.
Excel Sheet Name: ML Models

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/MLModels.ps1

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
    $mlWorkspaces = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.machinelearningservices/workspaces' -and
        $_.KIND -notin @('Hub', 'Project')
    }

    if ($mlWorkspaces) {
        $tmp = foreach ($ws in $mlWorkspaces) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }

            $apiVersion = '2023-04-01'
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/models?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result = $response.Content | ConvertFrom-Json
                    $models = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $models) {
                        # Get latest version details
                        $versionUri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/models/$($1.name)/versions?api-version=$apiVersion&`$orderby=createdTime desc&`$top=1"
                        $latestVersion = 'N/A'
                        $framework     = 'N/A'
                        $createdTime   = 'N/A'

                        try {
                            $vResp = Invoke-AzRestMethod -Path $versionUri -Method GET -ErrorAction SilentlyContinue
                            if ($vResp.StatusCode -eq 200) {
                                $vResult = $vResp.Content | ConvertFrom-Json
                                $vData   = if ($vResult.value) { $vResult.value[0] } else { $null }
                                if ($vData) {
                                    $latestVersion = $vData.name
                                    $framework     = if ($vData.properties.flavors) { ($vData.properties.flavors.psobject.properties.Name) -join ', ' } else { 'N/A' }
                                    $createdTime   = if ($vData.systemData.createdAt) { ([datetime]$vData.systemData.createdAt).ToString('yyyy-MM-dd') } else { 'N/A' }
                                }
                            }
                        } catch {}

                        $ResUCount = 1
                        $obj = @{
                            'Workspace Name'    = $ws.NAME;
                            'Subscription'      = $sub1.Name;
                            'Resource Group'    = $ws.RESOURCEGROUP;
                            'Model Name'        = $1.name;
                            'Latest Version'    = $latestVersion;
                            'Framework'         = $framework;
                            'Created Date'      = $createdTime;
                            'Description'       = if ($1.properties.description) { $1.properties.description } else { 'N/A' };
                            'Resource U'        = $ResUCount;
                            'Tag Name'          = '';
                            'Tag Value'         = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("MLModels: Failed for $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLModelsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Model Name')
        $Exc.Add('Latest Version')
        $Exc.Add('Framework')
        $Exc.Add('Created Date')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Models' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
