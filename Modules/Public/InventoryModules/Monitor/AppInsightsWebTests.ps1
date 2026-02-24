<#
.Synopsis
Inventory for Application Insights Standard Web Tests

.DESCRIPTION
This script inventories Application Insights Standard Web Tests
(microsoft.insights/webtests where kind == 'standard').
Excel Sheet Name: App Insights Web Tests

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/AppInsightsWebTests.ps1

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
    # Standard web tests are kind='standard'; classic availability tests are kind='ping' or 'multistep'
    $webTests = $Resources | Where-Object { $_.TYPE -eq 'microsoft.insights/webtests' -and $_.KIND -eq 'standard' }

    if ($webTests) {
        $tmp = foreach ($1 in $webTests) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Linked App Insights via hidden-link tag
            $aiResourceId = ''
            if ($1.tags) {
                $hiddenLink = $1.tags.psobject.properties | Where-Object { $_.Name -like 'hidden-link:*' }
                if ($hiddenLink) { $aiResourceId = ($hiddenLink.Name -replace '^hidden-link:', '') }
            }
            $aiResourceName = if ($aiResourceId) { ($aiResourceId -split '/')[-1] } else { 'N/A' }

            # Validation rules
            $validateStatus = if ($data.ValidationRules.ExpectedHttpStatusCode) { $data.ValidationRules.ExpectedHttpStatusCode } else { '200' }
            $sslCheck       = if ($data.ValidationRules.CheckSsl) { 'Yes' } else { 'No' }
            $sslAlertDays   = if ($data.ValidationRules.SSLCertRemainingLifetimeCheck) { $data.ValidationRules.SSLCertRemainingLifetimeCheck } else { 'N/A' }

            # Test request
            $testUrl        = if ($data.Request.RequestUrl)    { $data.Request.RequestUrl }    else { 'N/A' }
            $followRedirect = if ($data.Request.FollowRedirects -eq $true) { 'Yes' } else { 'No' }

            $locationCount  = if ($data.Locations) { @($data.Locations).Count } else { 0 }
            $locations      = if ($data.Locations) { (@($data.Locations) | ForEach-Object { $_.Id }) -join '; ' } else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                     = $1.id;
                    'Subscription'           = $sub1.Name;
                    'Resource Group'         = $1.RESOURCEGROUP;
                    'Test Name'              = $1.NAME;
                    'Location'               = $1.LOCATION;
                    'Enabled'                = if ($data.Enabled) { 'Yes' } else { 'No' };
                    'Test URL'               = $testUrl;
                    'Frequency (seconds)'    = if ($data.Frequency) { $data.Frequency } else { 300 };
                    'Timeout (seconds)'      = if ($data.Timeout)   { $data.Timeout }   else { 30 };
                    'Expected HTTP Status'   = $validateStatus;
                    'SSL Check'              = $sslCheck;
                    'SSL Alert Days'         = $sslAlertDays;
                    'Follow Redirects'       = $followRedirect;
                    'App Insights Resource'  = $aiResourceName;
                    'Test Locations Count'   = $locationCount;
                    'Test Locations'         = $locations;
                    'Provisioning State'     = if ($data.provisioningState) { $data.provisioningState } else { 'N/A' };
                    'Resource U'             = $ResUCount;
                    'Tag Name'               = [string]$Tag.Name;
                    'Tag Value'              = [string]$Tag.Value;
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
        $TableName = ('AIWebTestTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Test Name')
        $Exc.Add('Location')
        $Exc.Add('Enabled')
        $Exc.Add('Test URL')
        $Exc.Add('Frequency (seconds)')
        $Exc.Add('Timeout (seconds)')
        $Exc.Add('Expected HTTP Status')
        $Exc.Add('SSL Check')
        $Exc.Add('SSL Alert Days')
        $Exc.Add('Follow Redirects')
        $Exc.Add('App Insights Resource')
        $Exc.Add('Test Locations Count')
        $Exc.Add('Test Locations')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'App Insights Web Tests' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
