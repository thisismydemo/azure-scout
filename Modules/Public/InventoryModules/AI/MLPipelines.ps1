<#
.Synopsis
Inventory for Azure Machine Learning Pipelines

.DESCRIPTION
This script retrieves all pipeline jobs and pipeline components within Azure Machine
Learning workspaces via the ARM REST API.
Excel Sheet Name: ML Pipelines

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/MLPipelines.ps1

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
    $mlWorkspaces = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.machinelearningservices/workspaces' -and
        $_.KIND -notin @('Hub', 'Project')
    }

    if ($mlWorkspaces) {
        $tmp = foreach ($ws in $mlWorkspaces) {
            $sub1      = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }
            $apiVersion = '2023-04-01'
            $baseUri    = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)"

            # Pipeline jobs
            $pipelineUri = "$baseUri/jobs?api-version=$apiVersion&`$filter=jobType eq 'Pipeline'"
            try {
                $response = Invoke-AzRestMethod -Path $pipelineUri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result   = $response.Content | ConvertFrom-Json
                    $pipelines = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $pipelines) {
                        $ResUCount = 1
                        $jProp     = $1.properties

                        $obj = @{
                            'Workspace Name'     = $ws.NAME;
                            'Subscription'       = $sub1.Name;
                            'Resource Group'     = $ws.RESOURCEGROUP;
                            'Pipeline Name'      = $1.name;
                            'Pipeline ID'        = $1.id;
                            'Display Name'       = if ($jProp.displayName)          { $jProp.displayName }          else { 'N/A' };
                            'Status'             = if ($jProp.status)               { $jProp.status }               else { 'N/A' };
                            'Created Time'       = if ($jProp.creationContext.createdAt) { ([datetime]$jProp.creationContext.createdAt).ToString('yyyy-MM-dd HH:mm') } else { 'N/A' };
                            'Last Modified'      = if ($jProp.creationContext.lastModifiedAt) { ([datetime]$jProp.creationContext.lastModifiedAt).ToString('yyyy-MM-dd HH:mm') } else { 'N/A' };
                            'Description'        = if ($jProp.description)          { $jProp.description }          else { 'N/A' };
                            'Experiment Name'    = if ($jProp.experimentName)       { $jProp.experimentName }       else { 'N/A' };
                            'Compute ID'         = if ($jProp.settings.defaultCompute) { $jProp.settings.defaultCompute } else { 'N/A' };
                            'Resource U'         = $ResUCount;
                            'Tag Name'           = '';
                            'Tag Value'          = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("MLPipelines: Failed to retrieve pipelines for workspace $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLPipelinesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style     = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Pipeline Name')
        $Exc.Add('Pipeline ID')
        $Exc.Add('Display Name')
        $Exc.Add('Status')
        $Exc.Add('Created Time')
        $Exc.Add('Last Modified')
        $Exc.Add('Description')
        $Exc.Add('Experiment Name')
        $Exc.Add('Compute ID')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Pipelines' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
