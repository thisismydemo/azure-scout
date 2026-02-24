<#
.Synopsis
Inventory for Log Analytics Workspace Solutions

.DESCRIPTION
This script consolidates information for all Log Analytics / Operations Management
Solutions (microsoft.operationsmanagement/solutions).
Excel Sheet Name: LA Solutions

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Monitoring/LAWorkspaceSolutions.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Monitor

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    $solutions = $Resources | Where-Object { $_.TYPE -eq 'microsoft.operationsmanagement/solutions' }

    if ($solutions) {
        $tmp = foreach ($1 in $solutions) {
            $ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.Id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            $Tags = if (![string]::IsNullOrEmpty($1.tags.psobject.properties)) { $1.tags.psobject.properties } else { '0' }

            # Workspace ID
            $wsId   = if ($data.workspaceResourceId) { $data.workspaceResourceId } else { 'N/A' }
            $wsName = if ($wsId -ne 'N/A') { ($wsId -split '/')[-1] } else { 'N/A' }

            # Plan info
            $planName      = if ($1.PLAN) { $1.PLAN.name }      else { 'N/A' }
            $planPublisher = if ($1.PLAN) { $1.PLAN.publisher } else { 'N/A' }
            $planProduct   = if ($1.PLAN) { $1.PLAN.product }   else { 'N/A' }

            foreach ($Tag in $Tags) {
                $obj = @{
                    'ID'                       = $1.id;
                    'Subscription'             = $sub1.Name;
                    'Resource Group'           = $1.RESOURCEGROUP;
                    'Solution Name'            = $1.NAME;
                    'Location'                 = $1.LOCATION;
                    'Workspace Name'           = $wsName;
                    'Workspace Resource ID'    = $wsId;
                    'Plan Name'                = $planName;
                    'Publisher'                = $planPublisher;
                    'Product'                  = $planProduct;
                    'Provisioning State'       = if ($data.provisioningState) { $data.provisioningState } else { 'N/A' };
                    'Resource U'               = $ResUCount;
                    'Tag Name'                 = [string]$Tag.Name;
                    'Tag Value'                = [string]$Tag.Value;
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
        $TableName = ('LASolutionsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))
        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('Resource Group')
        $Exc.Add('Solution Name')
        $Exc.Add('Location')
        $Exc.Add('Workspace Name')
        $Exc.Add('Plan Name')
        $Exc.Add('Publisher')
        $Exc.Add('Product')
        $Exc.Add('Provisioning State')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'LA Solutions' `
            -AutoSize -MaxAutoSizeRows 100 `
            -TableName $TableName -TableStyle $TableStyle -Style $Style
    }
}
