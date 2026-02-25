<#
.Synopsis
Inventory for Azure Machine Learning Datastores

.DESCRIPTION
This script retrieves all datastores within Azure Machine Learning workspaces
via the ARM REST API.
Excel Sheet Name: ML Datastores

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/AI/MLDatastores.ps1

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
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.MachineLearningServices/workspaces/$($ws.NAME)/datastores?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result     = $response.Content | ConvertFrom-Json
                    $datastores = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $datastores) {
                        $ResUCount = 1
                        $dProp = $1.properties

                        # Storage path info
                        $storageAccount = if ($dProp.accountName)   { $dProp.accountName }   else { 'N/A' }
                        $container      = if ($dProp.containerName)  { $dProp.containerName }  else { if ($dProp.fileShareName) { $dProp.fileShareName } else { 'N/A' } }
                        $credType       = if ($dProp.credentials -and $dProp.credentials.credentialsType) { $dProp.credentials.credentialsType } else { 'N/A' }

                        $obj = @{
                            'Workspace Name'      = $ws.NAME;
                            'Subscription'        = $sub1.Name;
                            'Resource Group'      = $ws.RESOURCEGROUP;
                            'Datastore Name'      = $1.name;
                            'Datastore Type'      = if ($dProp.datastoreType)   { $dProp.datastoreType }   else { 'N/A' };
                            'Storage Account'     = $storageAccount;
                            'Container/Share'     = $container;
                            'Is Default'          = if ($dProp.isDefault -eq $true) { 'Yes' } else { 'No' };
                            'Credentials Type'    = $credType;
                            'Description'         = if ($dProp.description)    { $dProp.description }    else { 'N/A' };
                            'Resource U'          = $ResUCount;
                            'Tag Name'            = '';
                            'Tag Value'           = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("MLDatastores: Failed for $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('MLDatastoresTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Datastore Name')
        $Exc.Add('Datastore Type')
        $Exc.Add('Storage Account')
        $Exc.Add('Container/Share')
        $Exc.Add('Is Default')
        $Exc.Add('Credentials Type')
        $Exc.Add('Description')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'ML Datastores' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
