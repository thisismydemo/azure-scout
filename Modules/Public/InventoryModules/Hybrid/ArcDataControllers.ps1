<#
.Synopsis
Inventory for Azure Arc Data Controllers

.DESCRIPTION
This script consolidates information for all Arc Data Controller resources
(microsoft.azurearcdata/datacontrollers).
Excel Sheet Name: Arc Data Controllers

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Hybrid/ArcDataControllers.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

.CATEGORY Hybrid

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $dataControllers = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurearcdata/datacontrollers' }

    if ($dataControllers) {
        $tmp = foreach ($1 in $dataControllers) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $k8sResourceId     = if ($data.k8sRaw.metadata.namespace) { $data.k8sRaw.metadata.namespace } else { 'N/A' }
            $laWorkspaceId     = if ($data.logAnalyticsWorkspaceConfig.workspaceId) { $data.logAnalyticsWorkspaceConfig.workspaceId } else { 'N/A' }
            $metricsUploadState = if ($data.uploadStatus.metrics.lastUploadedAt) { $data.uploadStatus.metrics.lastUploadedAt } else { 'N/A' }
            $logsUploadState    = if ($data.uploadStatus.logs.lastUploadedAt)    { $data.uploadStatus.logs.lastUploadedAt }    else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                        = $1.id;
                    'Subscription'              = $sub1.Name;
                    'Resource Group'            = $1.RESOURCEGROUP;
                    'Name'                      = $1.NAME;
                    'Location'                  = $1.LOCATION;
                    'Connectivity Mode'         = if ($data.infrastructure)         { $data.infrastructure }         else { 'N/A' };
                    'K8s Namespace'             = $k8sResourceId;
                    'Log Analytics Workspace'   = $laWorkspaceId;
                    'Metrics Last Uploaded'     = $metricsUploadState;
                    'Logs Last Uploaded'        = $logsUploadState;
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
        $TableName = ('ArcDataCtrlTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Connectivity Mode')
        $Exc.Add('K8s Namespace')
        $Exc.Add('Log Analytics Workspace')
        $Exc.Add('Metrics Last Uploaded')
        $Exc.Add('Logs Last Uploaded')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Arc Data Controllers' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
