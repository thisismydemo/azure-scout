<#
.Synopsis
Inventory for Application Insights Availability Tests

.DESCRIPTION
This script consolidates information for all Application Insights Availability /
Web Tests (microsoft.insights/webtests).
Excel Sheet Name: App Insights Availability Tests

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/AppInsightsAvailabilityTests.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZSC).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $webTests = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/webtests' }

    if ($webTests) {
        $tmp = foreach ($1 in $webTests) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Linked Application Insights resource (from hiddenlink tag)
            $aiResourceId = ''
            if ($1.tags) {
                $hiddenLink = $1.tags.psobject.properties | Where-Object { $_.Name -like 'hidden-link:*' }
                if ($hiddenLink) { $aiResourceId = ($hiddenLink.Name -replace '^hidden-link:', '') }
            }
            $aiResourceName = if ($aiResourceId) { ($aiResourceId -split '/')[-1] } else { 'N/A' }

            # Test locations
            $locationCount = if ($data.Locations) { @($data.Locations).Count } else { 0 }
            $locations     = if ($data.Locations) { (@($data.Locations) | ForEach-Object { $_.Id }) -join '; ' } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                      = $1.id;
                    'Subscription'            = $sub1.Name;
                    'Resource Group'          = $1.RESOURCEGROUP;
                    'Test Name'               = $1.NAME;
                    'Location'                = $1.LOCATION;
                    'Kind'                    = if ($1.KIND) { $1.KIND } else { if ($data.Kind) { $data.Kind } else { 'N/A' } };
                    'Enabled'                 = if ($data.Enabled) { 'Yes' } else { 'No' };
                    'Frequency (seconds)'     = if ($data.Frequency) { $data.Frequency } else { 300 };
                    'Timeout (seconds)'       = if ($data.Timeout)   { $data.Timeout }   else { 30 };
                    'Success Criteria'        = if ($data.RetryEnabled) { 'Retry Enabled' } else { 'No Retry' };
                    'Test Type'               = if ($data.SyntheticMonitorId) { 'Synthetic Monitor' } else { 'N/A' };
                    'App Insights Resource'   = $aiResourceName;
                    'Test Locations Count'    = $locationCount;
                    'Test Locations'          = $locations;
                    'Provisioning State'      = if ($data.provisioningState) { $data.provisioningState } else { 'N/A' };
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
        $TableName = ('AIAvailabilityTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Test Name')
        $Exc.Add('Location')
        $Exc.Add('Kind')
        $Exc.Add('Enabled')
        $Exc.Add('Frequency (seconds)')
        $Exc.Add('Timeout (seconds)')
        $Exc.Add('App Insights Resource')
        $Exc.Add('Test Locations Count')
        $Exc.Add('Test Locations')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'App Insights Availability Tests' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
