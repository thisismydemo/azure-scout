<#
.Synopsis
Inventory for Azure Machine Learning Datasets / Data Assets

.DESCRIPTION
This script retrieves all registered data assets within Azure Machine Learning
workspaces via the ARM REST API (workspaces/data).
Excel Sheet Name: ML Datasets

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/MLDatasets.ps1

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
    $mlWorkspaces = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.machinelearningservices/workspaces' -and
        $_.KIND -notin @('Hub', 'Project')
    }

    if ($mlWorkspaces) {
        $tmp = foreach ($ws in $mlWorkspaces) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }

            $apiVersion = '2023-04-01'
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/data?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result   = $response.Content | ConvertFrom-Json
                    $datasets = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $datasets) {
                        # Fetch latest version
                        $vUri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/data/$($1.name)/versions?api-version=$apiVersion&`$orderby=createdTime desc&`$top=1"
                        $latestVersion = 'N/A'
                        $dataType      = 'N/A'
                        $dataPath      = 'N/A'
                        $createdTime   = 'N/A'

                        try {
                            $vResp = Invoke-AzRestMethod -Path $vUri -Method GET -ErrorAction SilentlyContinue
                            if ($vResp.StatusCode -eq 200) {
                                $vResult = $vResp.Content | ConvertFrom-Json
                                $vData   = if ($vResult.value) { $vResult.value[0] } else { $null }
                                if ($vData) {
                                    $latestVersion = $vData.name
                                    $dataType      = if ($vData.properties.dataType)  { $vData.properties.dataType }  else { 'N/A' }
                                    $dataPath      = if ($vData.properties.dataUri)   { $vData.properties.dataUri }   else { 'N/A' }
                                    $createdTime   = if ($vData.systemData.createdAt) { ([datetime]$vData.systemData.createdAt).ToString('yyyy-MM-dd') } else { 'N/A' }
                                }
                            }
                        } catch {}

                        $ResUCount = 1
                        $obj = @{
                            'Workspace Name'    = $ws.NAME;
                            'Subscription'      = $sub1.Name;
                            'Resource Group'    = $ws.RESOURCEGROUP;
                            'Dataset Name'      = $1.name;
                            'Dataset Type'      = $dataType;
                            'Latest Version'    = $latestVersion;
                            'Data Path'         = $dataPath;
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
                Write-Debug ("MLDatasets: Failed for $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLDatasetsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Dataset Name')
        $Exc.Add('Dataset Type')
        $Exc.Add('Latest Version')
        $Exc.Add('Data Path')
        $Exc.Add('Created Date')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Datasets' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
