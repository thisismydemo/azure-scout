<#
.Synopsis
Inventory for Azure Machine Learning Online Endpoints

.DESCRIPTION
This script retrieves all online and batch endpoints within Azure Machine Learning
workspaces via the ARM REST API.
Excel Sheet Name: ML Endpoints

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/MLEndpoints.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

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
            $baseUri    = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)"

            foreach ($endpointType in @('onlineEndpoints', 'batchEndpoints')) {
                $uri = "$baseUri/$endpointType`?api-version=$apiVersion"
                try {
                    $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                    if ($response.StatusCode -eq 200) {
                        $result    = $response.Content | ConvertFrom-Json
                        $endpoints = if ($result.value) { $result.value } else { @() }

                        foreach ($1 in $endpoints) {
                            $ResUCount = 1
                            $eProp = $1.properties

                            # Count deployments
                            $deplUri = "$baseUri/$endpointType/$($1.name)/deployments?api-version=$apiVersion"
                            $deplCount = 0
                            try {
                                $deplResp = Invoke-AzRestMethod -Path $deplUri -Method GET -ErrorAction SilentlyContinue
                                if ($deplResp.StatusCode -eq 200) {
                                    $deplResult = $deplResp.Content | ConvertFrom-Json
                                    $deplCount  = if ($deplResult.value) { @($deplResult.value).Count } else { 0 }
                                }
                            } catch {}

                            $obj = @{
                                'Workspace Name'    = $ws.NAME;
                                'Subscription'      = $sub1.Name;
                                'Resource Group'    = $ws.RESOURCEGROUP;
                                'Endpoint Name'     = $1.name;
                                'Endpoint Type'     = if ($endpointType -eq 'onlineEndpoints') { 'Online' } else { 'Batch' };
                                'Auth Mode'         = if ($eProp.authMode)            { $eProp.authMode }            else { 'N/A' };
                                'Scoring URI'       = if ($eProp.scoringUri)          { $eProp.scoringUri }          else { 'N/A' };
                                'Deployments Count' = $deplCount;
                                'Provisioning State'= if ($eProp.provisioningState)   { $eProp.provisioningState }   else { 'N/A' };
                                'Description'       = if ($eProp.description)         { $eProp.description }         else { 'N/A' };
                                'Resource U'        = $ResUCount;
                                'Tag Name'          = '';
                                'Tag Value'         = '';
                            }
                            $obj
                        }
                    }
                } catch {
                    Write-Debug ("MLEndpoints: Failed $endpointType for $($ws.NAME): $_")
                }
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLEndpointsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Endpoint Name')
        $Exc.Add('Endpoint Type')
        $Exc.Add('Auth Mode')
        $Exc.Add('Scoring URI')
        $Exc.Add('Deployments Count')
        $Exc.Add('Provisioning State')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Endpoints' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
