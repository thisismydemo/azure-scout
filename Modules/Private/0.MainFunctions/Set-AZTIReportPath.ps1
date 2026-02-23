<#
.Synopsis
Set the report path for Azure Resource Inventory

.DESCRIPTION
This module sets the default paths for report generation in Azure Resource Inventory.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/0.MainFunctions/Set-AZTIReportPath.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 3.6.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola

#>
function Set-AZTIReportPath {
    Param($ReportDir)

    if ($ReportDir)
        {
            $DefaultPath = $ReportDir
            $DiagramCache = Join-Path $ReportDir "DiagramCache"
            $ReportCache = Join-Path $ReportDir 'ReportCache'
        }
    elseif (Resolve-Path -Path 'C:\' -ErrorAction SilentlyContinue)
        {
            $DefaultPath = Join-Path "C:\" "AzureTenantInventory"
            $DiagramCache = Join-Path "C:\" "AzureTenantInventory" "DiagramCache"
            $ReportCache = Join-Path "C:\" "AzureTenantInventory"'ReportCache'
        }
    else
        {
            $DefaultPath = Join-Path "$HOME" "AzureTenantInventory"
            $DiagramCache = Join-Path "$HOME" "AzureTenantInventory" "DiagramCache"
            $ReportCache = Join-Path "$HOME" "AzureTenantInventory" 'ReportCache'
        }

    $ReportPath = @{
        'DefaultPath' = $DefaultPath;
        'DiagramCache' = $DiagramCache;
        'ReportCache' = $ReportCache
    }
    
    return $ReportPath
}