<#
.Synopsis
Inventory for Azure Machine Learning Compute Resources

.DESCRIPTION
This script retrieves all compute resources within Azure Machine Learning workspaces
via the ARM REST API (microsoft.machinelearningservices/workspaces/computes).
Excel Sheet Name: ML Compute

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/MLComputes.ps1

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
    # ML workspaces (exclude Hubs and Projects — standard workspaces only)
    $mlWorkspaces = $Resources | Where-Object {
        $_.TYPE -eq 'microsoft.machinelearningservices/workspaces' -and
        $_.KIND -notin @('Hub', 'Project')
    }

    if ($mlWorkspaces) {
        $tmp = foreach ($ws in $mlWorkspaces) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }

            $apiVersion = '2023-04-01'
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/computes?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result   = $response.Content | ConvertFrom-Json
                    $computes = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $computes) {
                        $ResUCount = 1
                        $cProp = $1.properties

                        # Cluster-specific sizes
                        $vmSize   = if ($cProp.properties.vmSize)          { $cProp.properties.vmSize }          else { 'N/A' }
                        $minNodes = if ($null -ne $cProp.properties.scaleSettings.minNodeCount) { $cProp.properties.scaleSettings.minNodeCount } else { 'N/A' }
                        $maxNodes = if ($null -ne $cProp.properties.scaleSettings.maxNodeCount) { $cProp.properties.scaleSettings.maxNodeCount } else { 'N/A' }
                        $vmPriority = if ($cProp.properties.vmPriority)    { $cProp.properties.vmPriority }      else { 'N/A' }

                        $obj = @{
                            'Workspace Name'      = $ws.NAME;
                            'Subscription'        = $sub1.Name;
                            'Resource Group'      = $ws.RESOURCEGROUP;
                            'Compute Name'        = $1.name;
                            'Compute Type'        = if ($cProp.computeType) { $cProp.computeType } else { 'N/A' };
                            'VM Size'             = $vmSize;
                            'VM Priority'         = $vmPriority;
                            'Min Nodes'           = $minNodes;
                            'Max Nodes'           = $maxNodes;
                            'Location'            = if ($1.location)        { $1.location }        else { 'N/A' };
                            'State'               = if ($cProp.provisioningState) { $cProp.provisioningState } else { 'N/A' };
                            'Description'         = if ($cProp.description) { $cProp.description } else { 'N/A' };
                            'Resource U'          = $ResUCount;
                            'Tag Name'            = '';
                            'Tag Value'           = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("MLComputes: Failed for $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLComputeTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Compute Name')
        $Exc.Add('Compute Type')
        $Exc.Add('VM Size')
        $Exc.Add('VM Priority')
        $Exc.Add('Min Nodes')
        $Exc.Add('Max Nodes')
        $Exc.Add('Location')
        $Exc.Add('State')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Compute' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
