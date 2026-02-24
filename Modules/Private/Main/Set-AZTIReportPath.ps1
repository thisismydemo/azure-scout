<#
.Synopsis
Set the report path for Azure Tenant Inventory

.DESCRIPTION
This module sets the default paths for report generation in Azure Tenant Inventory (AZSC).
Windows default: C:\AzureScout
Linux/Mac default: $HOME/AzureScout

.Link
https://github.com/thisismydemo/azure-scout/Modules/Private/Main/Set-AZSCReportPath.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZSC)

.NOTES
Version: 1.5.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola (original), thisismydemo (fork)

#>
function Set-AZSCReportPath {
    Param($ReportDir)

    if ($ReportDir)
        {
            $DefaultPath = $ReportDir
            $DiagramCache = Join-Path $ReportDir "DiagramCache"
            $ReportCache = Join-Path $ReportDir 'ReportCache'
        }
    elseif (Resolve-Path -Path 'C:\' -ErrorAction SilentlyContinue)
        {
            $DefaultPath = Join-Path "C:\" "AzureScout"
            $DiagramCache = Join-Path "C:\" "AzureScout" "DiagramCache"
            $ReportCache = Join-Path "C:\" "AzureScout"'ReportCache'
        }
    else
        {
            $DefaultPath = Join-Path "$HOME" "AzureScout"
            $DiagramCache = Join-Path "$HOME" "AzureScout" "DiagramCache"
            $ReportCache = Join-Path "$HOME" "AzureScout" 'ReportCache'
        }

    $ReportPath = @{
        'DefaultPath' = $DefaultPath;
        'DiagramCache' = $DiagramCache;
        'ReportCache' = $ReportCache
    }

    return $ReportPath
}
