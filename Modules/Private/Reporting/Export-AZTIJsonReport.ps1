<#
.Synopsis
Export inventory data as a structured JSON report

.DESCRIPTION
Reads all cache files produced by the processing phase and assembles them into
a single structured JSON document with a metadata envelope. The JSON file is
written alongside (or instead of) the Excel report depending on the
-OutputFormat parameter on Invoke-AzureTenantInventory.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/Reporting/Export-AZTIJsonReport.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.5.0
First Release Date: 15th Oct, 2024
Authors: Claudio Merola
#>

function Export-AZTIJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReportCache,

        [Parameter(Mandatory)]
        [string]$File,

        [Parameter()]
        [string]$TenantID,

        [Parameter()]
        [object]$Subscriptions,

        [Parameter()]
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]$Scope = 'All',

        [Parameter()]
        [object]$Quotas,

        [Parameter()]
        [switch]$SecurityCenter,

        [Parameter()]
        [switch]$SkipAdvisory,

        [Parameter()]
        [switch]$SkipPolicy,

        [Parameter()]
        [switch]$IncludeCosts
    )

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Starting JSON report export.')

    # ── Resolve output path ──────────────────────────────────────────────
    # Derive the .json path from the .xlsx path
    $JsonFile = [System.IO.Path]::ChangeExtension($File, '.json')

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - JSON output file: $JsonFile")

    # ── Build metadata envelope ──────────────────────────────────────────
    $SubscriptionList = @()
    if ($Subscriptions) {
        foreach ($sub in $Subscriptions) {
            $SubscriptionList += [ordered]@{
                id   = if ($sub.Id) { $sub.Id } elseif ($sub.SubscriptionId) { $sub.SubscriptionId } else { '' }
                name = if ($sub.Name) { $sub.Name } else { '' }
            }
        }
    }

    $Metadata = [ordered]@{
        tool          = 'AzureTenantInventory'
        version       = '1.5.0'
        tenantId      = $TenantID
        subscriptions = $SubscriptionList
        generatedAt   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        scope         = $Scope
    }

    # ── Discover inventory module folders ────────────────────────────────
    $ParentPath   = (Get-Item $PSScriptRoot).Parent.Parent
    $InventoryModulesPath = Join-Path $ParentPath 'Public' 'InventoryModules'
    $ModuleFolders = Get-ChildItem -Path $InventoryModulesPath -Directory

    # ── Category mapping ─────────────────────────────────────────────────
    # Map each InventoryModules folder name to a top-level JSON section.
    # Identity modules go under "entra"; everything else goes under "arm".
    $EntraFolders = @('Identity')

    $ArmData   = [ordered]@{}
    $EntraData = [ordered]@{}

    $CacheFiles = Get-ChildItem -Path $ReportCache -Recurse -Filter '*.json' -ErrorAction SilentlyContinue

    foreach ($ModuleFolder in $ModuleFolders) {
        $FolderName   = $ModuleFolder.Name
        $JSONFileName = "$FolderName.json"
        $CacheFile    = $CacheFiles | Where-Object { $_.Name -eq $JSONFileName }

        if (-not $CacheFile) {
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - No cache file for folder: $FolderName — skipping.")
            continue
        }

        # Read and parse the cache file
        $Reader   = New-Object System.IO.StreamReader($CacheFile.FullName)
        $RawJson  = $Reader.ReadToEnd()
        $Reader.Dispose()

        if ([string]::IsNullOrWhiteSpace($RawJson)) {
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Cache file is empty for folder: $FolderName — skipping.")
            continue
        }

        $CacheData = $RawJson | ConvertFrom-Json

        # Each cache file contains properties keyed by module name (filename without .ps1).
        # Collect all modules within this folder into a section object.
        $SectionData = [ordered]@{}

        $ModulePath  = Join-Path $ModuleFolder.FullName '*.ps1'
        $ModuleFiles = Get-ChildItem -Path $ModulePath -ErrorAction SilentlyContinue

        foreach ($Module in $ModuleFiles) {
            $ModName     = $Module.BaseName   # e.g. "VirtualMachines"
            $ModResources = $CacheData.$ModName

            if ($ModResources -and @($ModResources).Count -gt 0) {
                # Convert the module name to a camelCase JSON key
                $JsonKey = $ModName.Substring(0,1).ToLower() + $ModName.Substring(1)
                $SectionData[$JsonKey] = @($ModResources)
                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Added $(@($ModResources).Count) resources from $FolderName/$ModName")
            }
        }

        if ($SectionData.Count -eq 0) {
            continue
        }

        # Convert folder name to camelCase JSON key
        $FolderKey = $FolderName.Substring(0,1).ToLower() + $FolderName.Substring(1)

        if ($FolderName -in $EntraFolders) {
            # Entra data — flatten identity modules directly into the "entra" section
            foreach ($key in $SectionData.Keys) {
                $EntraData[$key] = $SectionData[$key]
            }
        }
        else {
            $ArmData[$FolderKey] = $SectionData
        }
    }

    # ── Build extra data sections ────────────────────────────────────────
    # Advisory, Policy, Security Center, Quotas — read from extra-report cache files if present
    $ExtraData = [ordered]@{}

    # Advisory
    if (-not $SkipAdvisory.IsPresent) {
        $AdvisoryCache = $CacheFiles | Where-Object { $_.Name -eq 'Advisory.json' }
        if ($AdvisoryCache) {
            try {
                $AdvReader = New-Object System.IO.StreamReader($AdvisoryCache.FullName)
                $AdvRaw    = $AdvReader.ReadToEnd()
                $AdvReader.Dispose()
                if (-not [string]::IsNullOrWhiteSpace($AdvRaw)) {
                    $ExtraData['advisory'] = ($AdvRaw | ConvertFrom-Json)
                }
            }
            catch {
                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Failed to read Advisory cache: $_")
            }
        }
    }

    # Policy
    if (-not $SkipPolicy.IsPresent) {
        $PolicyCache = $CacheFiles | Where-Object { $_.Name -eq 'Policy.json' }
        if ($PolicyCache) {
            try {
                $PolReader = New-Object System.IO.StreamReader($PolicyCache.FullName)
                $PolRaw    = $PolReader.ReadToEnd()
                $PolReader.Dispose()
                if (-not [string]::IsNullOrWhiteSpace($PolRaw)) {
                    $ExtraData['policy'] = ($PolRaw | ConvertFrom-Json)
                }
            }
            catch {
                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Failed to read Policy cache: $_")
            }
        }
    }

    # Security Center
    if ($SecurityCenter.IsPresent) {
        $SecCache = $CacheFiles | Where-Object { $_.Name -eq 'SecurityCenter.json' }
        if ($SecCache) {
            try {
                $SecReader = New-Object System.IO.StreamReader($SecCache.FullName)
                $SecRaw    = $SecReader.ReadToEnd()
                $SecReader.Dispose()
                if (-not [string]::IsNullOrWhiteSpace($SecRaw)) {
                    $ExtraData['security'] = ($SecRaw | ConvertFrom-Json)
                }
            }
            catch {
                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Failed to read SecurityCenter cache: $_")
            }
        }
    }

    # Quotas
    if ($Quotas) {
        $QuotaCache = $CacheFiles | Where-Object { $_.Name -eq 'Quotas.json' }
        if ($QuotaCache) {
            try {
                $QuotaReader = New-Object System.IO.StreamReader($QuotaCache.FullName)
                $QuotaRaw    = $QuotaReader.ReadToEnd()
                $QuotaReader.Dispose()
                if (-not [string]::IsNullOrWhiteSpace($QuotaRaw)) {
                    $ExtraData['quotas'] = ($QuotaRaw | ConvertFrom-Json)
                }
            }
            catch {
                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Failed to read Quotas cache: $_")
            }
        }
    }

    # ── Assemble final report object ─────────────────────────────────────
    $Report = [ordered]@{
        '_metadata' = $Metadata
    }

    if ($Scope -in ('All', 'ArmOnly') -and $ArmData.Count -gt 0) {
        $Report['arm'] = $ArmData
    }

    if ($Scope -in ('All', 'EntraOnly') -and $EntraData.Count -gt 0) {
        $Report['entra'] = $EntraData
    }

    # Merge extra data sections at the top level
    foreach ($key in $ExtraData.Keys) {
        $Report[$key] = $ExtraData[$key]
    }

    # ── Write JSON file ──────────────────────────────────────────────────
    try {
        $JsonOutput = $Report | ConvertTo-Json -Depth 40
        $JsonOutput | Out-File -FilePath $JsonFile -Encoding utf8 -Force

        Write-Host "JSON report saved to: " -ForegroundColor Green -NoNewline
        Write-Host $JsonFile -ForegroundColor Cyan
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - JSON report written successfully.")
    }
    catch {
        Write-Warning "Failed to write JSON report to '$JsonFile': $_"
    }

    return $JsonFile
}
