<#
.Synopsis
Inventory for Log Analytics Workspace Linked Services

.DESCRIPTION
This script consolidates Linked Services (Automation Account associations) from all
Log Analytics workspaces using the ARM REST API.
Excel Sheet Name: LA Linked Services

.Link
https://github.com/thisismydemo/azure-scout/Modules/Public/InventoryModules/Monitoring/LAWorkspaceLinkedServices.ps1

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC).

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
    $workspaces = $Resources | Where-Object { $_.TYPE -eq 'microsoft.operationalinsights/workspaces' }

    if ($workspaces) {
        $tmp = foreach ($ws in $workspaces) {
            $sub1 = $SUB | Where-Object { $_.Id -eq $ws.subscriptionId }

            $apiVersion = '2020-08-01'
            $uri = "/subscriptions/$($ws.subscriptionId)/resourceGroups/$($ws.RESOURCEGROUP)/providers/Microsoft.OperationalInsights/workspaces/$($ws.NAME)/linkedServices?api-version=$apiVersion"

            try {
                $response = Invoke-AzRestMethod -Path $uri -Method GET -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    $content = $response.Content | ConvertFrom-Json
                    foreach ($1 in $content.value) {
                        $ResUCount = 1
                        $props = $1.properties

                        $linkedResId   = if ($props.resourceId)       { $props.resourceId }       else { 'N/A' }
                        $writeResId    = if ($props.writeAccessResourceId) { $props.writeAccessResourceId } else { 'N/A' }
                        $linkedResName = if ($linkedResId -ne 'N/A')  { ($linkedResId -split '/')[-1] }  else { 'N/A' }

                        # Determine linked resource type
                        $linkedResType = if ($linkedResId -ne 'N/A' -and $linkedResId -match '/providers/([^/]+/[^/]+)/') {
                            $matches[1]
                        } else { 'N/A' }

                        $obj = @{
                            'Workspace Name'           = $ws.NAME;
                            'Subscription'             = $sub1.Name;
                            'Resource Group'           = $ws.RESOURCEGROUP;
                            'Linked Service Name'      = ($1.name -split '/')[-1];
                            'Linked Resource Name'     = $linkedResName;
                            'Linked Resource Type'     = $linkedResType;
                            'Linked Resource ID'       = $linkedResId;
                            'Write Access Resource ID' = $writeResId;
                            'Provisioning State'       = if ($props.provisioningState) { $props.provisioningState } else { 'N/A' };
                            'Resource U'               = $ResUCount;
                            'Tag Name'                 = '';
                            'Tag Value'                = '';
                        }
                        $obj
                    }
                }
            } catch {
                Write-Debug ("LAWorkspaceLinkedServices: Failed for workspace $($ws.NAME): $_")
            }
        }
        $tmp
    }
}

Else
{
    if ($SmaResources) {
        $TableName = ('LALinkedSvcTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Workspace Name')
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Linked Service Name')
        $Exc.Add('Linked Resource Name')
        $Exc.Add('Linked Resource Type')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'LA Linked Services' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
