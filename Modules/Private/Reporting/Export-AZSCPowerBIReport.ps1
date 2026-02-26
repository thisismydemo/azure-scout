<#
.Synopsis
Export inventory data as a Power BI-ready CSV bundle

.DESCRIPTION
Reads all cache files produced by the processing phase and exports them as a
folder of flat CSV files optimized for Power BI / Microsoft Fabric import.

Each inventory module becomes its own CSV file with consistent naming. A
_metadata.csv provides tenant/scan context, a Subscriptions.csv dimension
table enables slicing, and a _relationships.json manifest describes the
star-schema relationships for automatic Power BI data model configuration.

Output structure:
    PowerBI/
        _metadata.csv               — Scan metadata (tenant, date, scope, version)
        _relationships.json         — Table relationship definitions for Power BI
        Subscriptions.csv           — Subscription dimension table
        Resources_{Module}.csv      — One file per ARM inventory module
        Entra_{Module}.csv          — One file per Entra/Identity module

.PARAMETER ReportCache
Path to the ReportCache folder containing processed category JSON files.

.PARAMETER File
Path to the base report file (e.g. the .xlsx path). The Power BI folder is
created as a sibling directory named "PowerBI".

.PARAMETER TenantID
The Azure AD / Entra ID tenant identifier.

.PARAMETER Subscriptions
Array of subscription objects with Id and Name properties.

.PARAMETER Scope
Scan scope: All, ArmOnly, or EntraOnly.

.OUTPUTS
[string] Path to the PowerBI output folder.

.LINK
https://github.com/thisismydemo/azure-scout/Modules/Private/Reporting/Export-AZSCPowerBIReport.ps1

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 25, 2026
Authors: AzureScout Contributors
#>

function Export-AZSCPowerBIReport {
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
        [string]$Scope = 'All'
    )

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Starting Power BI CSV export.')

    # ── Resolve output folder ────────────────────────────────────────────
    $BaseDir   = Split-Path $File -Parent
    $PowerBIDir = Join-Path $BaseDir 'PowerBI'

    if (Test-Path $PowerBIDir) {
        Remove-Item $PowerBIDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $PowerBIDir -Force | Out-Null

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Power BI output folder: $PowerBIDir")

    # ── Helpers ──────────────────────────────────────────────────────────

    # Convert a module name to PascalCase display name with spaces
    function ConvertTo-DisplayName {
        param([string]$Name)
        # Insert space before each uppercase letter that follows a lowercase letter
        $spaced = [regex]::Replace($Name, '(?<=[a-z])(?=[A-Z])', ' ')
        # Capitalize first letter
        if ($spaced.Length -gt 0) {
            $spaced = $spaced.Substring(0,1).ToUpper() + $spaced.Substring(1)
        }
        return $spaced
    }

    # Export an array of ordered hashtables / PSObjects to CSV
    function Export-FlatCsv {
        param(
            [string]$FilePath,
            [object[]]$Data,
            [string]$Category,
            [string]$Module
        )

        if (-not $Data -or $Data.Count -eq 0) { return 0 }

        # Normalize all items to PSCustomObject and add _Category / _Module columns
        $rows = foreach ($item in $Data) {
            $props = [ordered]@{
                '_Category' = $Category
                '_Module'   = $Module
            }

            if ($item -is [System.Collections.IDictionary]) {
                foreach ($key in $item.Keys) {
                    $value = $item[$key]
                    # Flatten arrays/objects to strings for CSV compatibility
                    if ($null -eq $value) {
                        $props[$key] = ''
                    }
                    elseif ($value -is [array]) {
                        $props[$key] = ($value -join '; ')
                    }
                    elseif ($value -is [PSCustomObject] -or $value -is [System.Collections.IDictionary]) {
                        $props[$key] = ($value | ConvertTo-Json -Depth 5 -Compress)
                    }
                    elseif ($value -is [bool]) {
                        $props[$key] = $value.ToString()
                    }
                    else {
                        $props[$key] = $value
                    }
                }
            }
            else {
                foreach ($prop in $item.PSObject.Properties) {
                    $value = $prop.Value
                    if ($null -eq $value) {
                        $props[$prop.Name] = ''
                    }
                    elseif ($value -is [array]) {
                        $props[$prop.Name] = ($value -join '; ')
                    }
                    elseif ($value -is [PSCustomObject] -or $value -is [System.Collections.IDictionary]) {
                        $props[$prop.Name] = ($value | ConvertTo-Json -Depth 5 -Compress)
                    }
                    elseif ($value -is [bool]) {
                        $props[$prop.Name] = $value.ToString()
                    }
                    else {
                        $props[$prop.Name] = $value
                    }
                }
            }

            [PSCustomObject]$props
        }

        $rows | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -Force
        return $rows.Count
    }

    # ── Track generated files for summary ────────────────────────────────
    $generatedFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
    $totalRows = 0

    # ── 1. Metadata CSV ──────────────────────────────────────────────────
    $metadataFile = Join-Path $PowerBIDir '_metadata.csv'
    $subCount = if ($Subscriptions) { @($Subscriptions).Count } else { 0 }

    $metadataRows = @(
        [ordered]@{ Property = 'Tool';           Value = 'AzureScout' }
        [ordered]@{ Property = 'Version';        Value = '1.0.0' }
        [ordered]@{ Property = 'TenantId';       Value = $TenantID }
        [ordered]@{ Property = 'Subscriptions';  Value = $subCount }
        [ordered]@{ Property = 'GeneratedAt';    Value = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ') }
        [ordered]@{ Property = 'Scope';          Value = $Scope }
    )
    $metadataRows | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -Path $metadataFile -NoTypeInformation -Encoding UTF8 -Force
    $generatedFiles.Add([PSCustomObject]@{ File = '_metadata.csv'; Category = 'Metadata'; Rows = $metadataRows.Count })

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Metadata CSV written.')

    # ── 2. Subscriptions dimension table ─────────────────────────────────
    $subsFile = Join-Path $PowerBIDir 'Subscriptions.csv'
    if ($Subscriptions -and @($Subscriptions).Count -gt 0) {
        $subRows = foreach ($sub in $Subscriptions) {
            [PSCustomObject][ordered]@{
                SubscriptionId   = if ($sub.Id) { $sub.Id } elseif ($sub.SubscriptionId) { $sub.SubscriptionId } else { '' }
                SubscriptionName = if ($sub.Name) { $sub.Name } else { '' }
            }
        }
        $subRows | Export-Csv -Path $subsFile -NoTypeInformation -Encoding UTF8 -Force
        $generatedFiles.Add([PSCustomObject]@{ File = 'Subscriptions.csv'; Category = 'Dimension'; Rows = @($subRows).Count })
    }
    else {
        # Write empty dimension table with headers
        [PSCustomObject]@{ SubscriptionId = ''; SubscriptionName = '' } | Export-Csv -Path $subsFile -NoTypeInformation -Encoding UTF8 -Force
        $generatedFiles.Add([PSCustomObject]@{ File = 'Subscriptions.csv'; Category = 'Dimension'; Rows = 0 })
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Subscriptions CSV written.')

    # ── 3. Discover inventory module folders ─────────────────────────────
    $ParentPath          = (Get-Item $PSScriptRoot).Parent.Parent
    $InventoryModulesPath = Join-Path $ParentPath 'Public' 'InventoryModules'
    $ModuleFolders       = Get-ChildItem -Path $InventoryModulesPath -Directory -ErrorAction SilentlyContinue

    $EntraFolders = @('Identity')

    # Build module name lookup: lowercase → actual BaseName
    $ModuleMap = @{}
    if ($ModuleFolders) {
        foreach ($folder in $ModuleFolders) {
            foreach ($mod in (Get-ChildItem $folder.FullName -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
                $ModuleMap[$mod.BaseName.ToLower()] = $mod.BaseName
            }
        }
    }

    # Helper: PascalCase fallback
    function ConvertTo-PascalCase {
        param([string]$Name)
        if ([string]::IsNullOrEmpty($Name)) { return $Name }
        return $Name.Substring(0,1).ToUpper() + $Name.Substring(1)
    }

    # ── 4. Read cache files and export CSVs ──────────────────────────────
    $CacheFiles = Get-ChildItem -Path $ReportCache -Recurse -Filter '*.json' -ErrorAction SilentlyContinue

    # Track all relationship sources for manifest
    $relationshipTables = [System.Collections.Generic.List[string]]::new()

    foreach ($ModuleFolder in $ModuleFolders) {
        $FolderName    = $ModuleFolder.Name
        $JSONFileName  = "$FolderName.json"
        $CacheFile     = $CacheFiles | Where-Object { $_.Name -eq $JSONFileName }

        if (-not $CacheFile) {
            Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - No cache file for $FolderName — skipping.")
            continue
        }

        $Reader  = New-Object System.IO.StreamReader($CacheFile.FullName)
        $RawJson = $Reader.ReadToEnd()
        $Reader.Dispose()

        if ([string]::IsNullOrWhiteSpace($RawJson)) { continue }

        $CacheData = $RawJson | ConvertFrom-Json

        $ModulePath  = Join-Path $ModuleFolder.FullName '*.ps1'
        $ModuleFiles = Get-ChildItem -Path $ModulePath -ErrorAction SilentlyContinue

        $isEntra = $FolderName -in $EntraFolders

        foreach ($Module in $ModuleFiles) {
            $ModName      = $Module.BaseName
            $ModResources = $CacheData.$ModName

            if (-not $ModResources -or @($ModResources).Count -eq 0) { continue }

            # Build filename: Resources_ModuleName.csv or Entra_ModuleName.csv
            $prefix  = if ($isEntra) { 'Entra' } else { 'Resources' }
            $csvName = "${prefix}_${ModName}.csv"
            $csvPath = Join-Path $PowerBIDir $csvName

            $categoryDisplay = if ($isEntra) { 'Identity' } else { $FolderName }
            $rowCount = Export-FlatCsv -FilePath $csvPath -Data @($ModResources) -Category $categoryDisplay -Module $ModName

            if ($rowCount -gt 0) {
                $generatedFiles.Add([PSCustomObject]@{ File = $csvName; Category = $categoryDisplay; Rows = $rowCount })
                $totalRows += $rowCount
                $relationshipTables.Add($csvName)

                Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Exported $rowCount rows → $csvName")
            }
        }
    }

    # ── 5. Relationships manifest ────────────────────────────────────────
    $relationshipsFile = Join-Path $PowerBIDir '_relationships.json'

    # Build star-schema relationships: each resource table links to Subscriptions via Subscription
    $relationships = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($table in $relationshipTables) {
        # Resource tables that have a Subscription column can join to Subscriptions dimension
        $relationships.Add([PSCustomObject][ordered]@{
            fromTable  = [System.IO.Path]::GetFileNameWithoutExtension($table)
            fromColumn = 'Subscription'
            toTable    = 'Subscriptions'
            toColumn   = 'SubscriptionName'
            type       = 'many-to-one'
        })
    }

    $manifest = [ordered]@{
        description   = 'Power BI data model relationships for Azure Scout inventory data'
        generatedAt   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        instructions  = 'In Power BI Desktop: Get Data > Folder > select the PowerBI directory. Use these relationships to configure the data model.'
        tables        = @(@('_metadata.csv', 'Subscriptions.csv') + @($relationshipTables))
        relationships = @($relationships)
    }

    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $relationshipsFile -Encoding UTF8 -Force

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Relationships manifest written.')

    # ── 6. Summary ───────────────────────────────────────────────────────
    $fileCount = $generatedFiles.Count

    Write-Host "Power BI CSV bundle saved to: " -ForegroundColor Green -NoNewline
    Write-Host $PowerBIDir -ForegroundColor Cyan
    Write-Host "  Files: $fileCount  |  Total rows: $totalRows" -ForegroundColor Gray

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Power BI export complete: $fileCount files, $totalRows rows.")

    return $PowerBIDir
}
