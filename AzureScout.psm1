<#
.SYNOPSIS
    AzureScout — Single-tenant Azure ARM + Entra ID inventory tool.

.DESCRIPTION
    This module orchestrates dot-sourcing of all private and public functions
    that are triggered by the Invoke-AzureScout cmdlet.

.AUTHOR
    thisismydemo

.COPYRIGHT
    (c) 2026 thisismydemo. All rights reserved.

.VERSION
    1.0.0

#>

#region — Dependency bootstrap
$_requiredModules = @(
    'ImportExcel',
    'Az.Accounts',
    'Az.ResourceGraph',
    'Az.Storage',
    'Az.Compute',
    'Az.Authorization',
    'Az.Resources'
)
foreach ($_mod in $_requiredModules) {
    if (-not (Get-Module -Name $_mod -ListAvailable)) {
        Write-Host "[AzureScout] Installing required module: $_mod" -ForegroundColor Cyan
        try {
            Install-Module -Name $_mod -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } catch {
            Write-Warning "[AzureScout] Could not install $_mod`: $_. Some functionality may be unavailable."
            continue
        }
    }
    if (-not (Get-Module -Name $_mod)) {
        Import-Module -Name $_mod -ErrorAction SilentlyContinue
    }
}
#endregion

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
