<#
.SYNOPSIS
    AzureTenantInventory — Single-tenant Azure ARM + Entra ID inventory tool.

.DESCRIPTION
    This module orchestrates dot-sourcing of all private and public functions
    that are triggered by the Invoke-AzureTenantInventory cmdlet.

.AUTHOR
    thisismydemo

.COPYRIGHT
    (c) 2026 thisismydemo. All rights reserved.

.VERSION
    1.0.0

#>

foreach ($directory in @('modules\Private', '.\modules\Public\PublicFunctions')) {
    Get-ChildItem -Path "$PSScriptRoot\$directory\*.ps1" -Recurse | ForEach-Object { . $_.FullName }
}


<#
$PrivateFiles = @( Get-ChildItem -Path (Join-Path $PSScriptRoot "Modules" "Private" "*.ps1") -Recurse -ErrorAction SilentlyContinue )
$PublicFiles = @( Get-ChildItem -Path (Join-Path $PSScriptRoot "Modules" "Public" "PublicFunctions" "*.ps1") -Recurse -ErrorAction SilentlyContinue )

Foreach($import in @($PrivateFiles + $PublicFiles))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $PublicFiles.Basename

#>
