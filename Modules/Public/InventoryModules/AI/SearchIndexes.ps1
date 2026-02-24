<#
.Synopsis
Inventory for Azure Cognitive Search Indexes

.DESCRIPTION
This script retrieves all indexes within Azure Cognitive Search / AI Search services
via the Search REST management API.
Excel Sheet Name: Search Indexes

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/AI/SearchIndexes.ps1

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
    $searchServices = $Resources | Where-Object { $_.TYPE -eq 'microsoft.search/searchservices' }

    if ($searchServices) {
        $tmp = foreach ($svc in $searchServices) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $svc.subscriptionId }

            # List indexes via ARM management API
            $apiVersion = '2023-11-01'
            $uri = "/subscriptions/$($svc.subscriptionId)/resourceGroups/$($svc.RESOURCEGROUP)/providers/Microsoft.Search/searchServices/$($svc.NAME)/listQueryKeys?api-version=$apiVersion"

            # Use the ARM indexes endpoint
            $indexUri = "/subscriptions/$($svc.subscriptionId)/resourceGroups/$($svc.RESOURCEGROUP)/providers/Microsoft.Search/searchServices/$($svc.NAME)/indexes?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $indexUri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $result  = $response.Content | ConvertFrom-Json
                    $indexes = if ($result.value) { $result.value } else { @() }

                    foreach ($1 in $indexes) {
                        $ResUCount = 1
                        $fieldsCount   = if ($1.fields)         { @($1.fields).Count }         else { 0 }
                        $analyzers     = if ($1.analyzers)      { @($1.analyzers).Count }      else { 0 }
                        $scoringProfs  = if ($1.scoringProfiles){ @($1.scoringProfiles).Count } else { 0 }
                        $suggesters    = if ($1.suggesters)     { @($1.suggesters).Count }      else { 0 }

                        $obj = @{
                            'Service Name'          = $svc.NAME;
                            'Subscription'          = $sub1.Name;
                            'Resource Group'        = $svc.RESOURCEGROUP;
                            'Index Name'            = $1.name;
                            'Fields Count'          = $fieldsCount;
                            'Analyzers Count'       = $analyzers;
                            'Scoring Profiles'      = $scoringProfs;
                            'Suggesters Count'      = $suggesters;
                            'CORS Allowed Origins'  = if ($1.corsOptions.allowedOrigins) { $1.corsOptions.allowedOrigins -join '; ' } else { 'N/A' };
                            'Default Scoring Profile' = if ($1.defaultScoringProfile)  { $1.defaultScoringProfile }  else { 'None' };
                            'ETag'                  = if ($1.'@odata.etag')             { $1.'@odata.etag' }          else { 'N/A' };
                            'Resource U'            = $ResUCount;
                            'Tag Name'              = '';
                            'Tag Value'             = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("SearchIndexes: Failed for $($svc.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('SearchIndexesTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Service Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Index Name')
        $Exc.Add('Fields Count')
        $Exc.Add('Analyzers Count')
        $Exc.Add('Scoring Profiles')
        $Exc.Add('Suggesters Count')
        $Exc.Add('CORS Allowed Origins')
        $Exc.Add('Default Scoring Profile')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'Search Indexes' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
