<#
.Synopsis
Inventory for Log Analytics Workspace Saved Searches

.DESCRIPTION
This script consolidates Saved Searches from all Log Analytics workspaces
in the tenant using the ARM REST API.
Excel Sheet Name: LA Saved Searches

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/LAWorkspaceSavedSearches.ps1

.COMPONENT
This powershell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    # Get all Log Analytics workspaces from Resources
    $workspaces = $Resources | Where-Object { $_.TYPE -eq 'microsoft.operationalinsights/workspaces' }

    if ($workspaces) {
        $tmp = foreach ($ws in $workspaces) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }

            # Use REST API to enumerate saved searches
            $apiVersion = '2020-08-01'
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.OperationalInsights/workspaces/$($ws.NAME)/savedSearches?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $content = $response.Content | ConvertFrom-Json
                    $savedSearches = $content.value | Where-Object {
                        # Exclude Microsoft built-in saved searches
                        $_.properties.category -notlike 'Microsoft*' -and
                        $_.id -notlike '*microsoft.operationalinsights/workspaces/microsoft*'
                    }

                    foreach ($1 in $savedSearches) {
                        $ResUCount = 1
                        $props = $1.properties

                        $obj = @{
                            'Workspace Name'    = $ws.NAME;
                            'Subscription'      = $sub1.Name;
                            'Resource Group'    = $ws.RESOURCEGROUP;
                            'Search ID'         = $1.id;
                            'Display Name'      = if ($props.displayName) { $props.displayName } else { $1.name };
                            'Category'          = if ($props.category)    { $props.category }    else { 'N/A' };
                            'Query'             = if ($props.query) { $props.query.Substring(0, [Math]::Min($props.query.Length, 250)) } else { '' };
                            'Version'           = if ($props.version) { $props.version } else { 1 };
                            'Resource U'        = $ResUCount;
                            'Tag Name'          = '';
                            'Tag Value'         = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("LAWorkspaceSavedSearches: Failed for workspace $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('LASavedSearchTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Display Name')
        $Exc.Add('Category')
        $Exc.Add('Query')
        $Exc.Add('Version')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'LA Saved Searches' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
