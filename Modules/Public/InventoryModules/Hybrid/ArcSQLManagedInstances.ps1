<#
.Synopsis
Inventory for Azure Arc SQL Managed Instances

.DESCRIPTION
This script consolidates information for all Arc-enabled SQL Managed Instance resources
(microsoft.azurearcdata/sqlmanagedinstances).
Excel Sheet Name: Arc SQL Managed Instances

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Hybrid/ArcSQLManagedInstances.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

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
    $arcMIs = $Resources | Where-Object { $_.TYPE -eq 'microsoft.azurearcdata/sqlmanagedinstances' }

    if ($arcMIs) {
        $tmp = foreach ($1 in $arcMIs) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            $dataControllerName = if ($data.dataControllerId) { ($data.dataControllerId -split '/')[-1] } else { 'N/A' }

            # Storage
            $dataStorageGb  = if ($data.storage.data.volumes.size)      { $data.storage.data.volumes.size }      else { 'N/A' }
            $logsStorageGb  = if ($data.storage.logs.volumes.size)      { $data.storage.logs.volumes.size }      else { 'N/A' }

            # HA
            $haMode = if ($data.k8sRaw.spec.replicas -and $data.k8sRaw.spec.replicas -gt 1) { 'Enabled' } else { 'Disabled' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                        = $1.id;
                    'Subscription'              = $sub1.Name;
                    'Resource Group'            = $1.RESOURCEGROUP;
                    'Name'                      = $1.NAME;
                    'Location'                  = $1.LOCATION;
                    'Data Controller'           = $dataControllerName;
                    'Admin Username'            = if ($data.admin)                  { $data.admin }                  else { 'N/A' };
                    'SQL Version'               = if ($data.licenseType)            { $data.licenseType }            else { 'N/A' };
                    'vCores Request'            = if ($data.vCores.request)         { $data.vCores.request }         else { 'N/A' };
                    'vCores Limit'              = if ($data.vCores.limit)           { $data.vCores.limit }           else { 'N/A' };
                    'Data Storage GB'           = $dataStorageGb;
                    'Logs Storage GB'           = $logsStorageGb;
                    'Service Tier'              = if ($data.tier)                   { $data.tier }                   else { 'N/A' };
                    'HA Mode'                   = $haMode;
                    'Endpoint'                  = if ($data.endpoints.primary)      { $data.endpoints.primary }      else { 'N/A' };
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
        $TableName = ('ArcSQLMITable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Name')
        $Exc.Add('Location')
        $Exc.Add('Data Controller')
        $Exc.Add('Admin Username')
        $Exc.Add('vCores Request')
        $Exc.Add('vCores Limit')
        $Exc.Add('Data Storage GB')
        $Exc.Add('Logs Storage GB')
        $Exc.Add('Service Tier')
        $Exc.Add('HA Mode')
        $Exc.Add('Endpoint')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')
        if ($InTag) { $Exc.Add('Tag Name'); $Exc.Add('Tag Value') }

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Arc SQL Managed Instances' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
