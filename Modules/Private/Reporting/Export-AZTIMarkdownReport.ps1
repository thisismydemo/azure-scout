<#
.Synopsis
Export inventory data as a structured Markdown report

.DESCRIPTION
Reads all cache files produced by the processing phase and assembles them into
a single Markdown document. Each category becomes a top-level section and each
module's data is rendered as a GitHub-Flavored Markdown pipe table. Suitable
for GitHub/GitLab wikis, Obsidian, and Confluence.

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Private/Reporting/Export-AZTIMarkdownReport.ps1

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: Product Technology Team
#>

function Export-AZTIMarkdownReport {
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

    $MdFile = [System.IO.Path]::ChangeExtension($File, '.md')
    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Markdown output file: $MdFile")

    $subCount = if ($Subscriptions) { @($Subscriptions).Count } else { 0 }
    $genDate  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $lines = [System.Collections.Generic.List[string]]::new()

    # ── Header ───────────────────────────────────────────────────────────
    $lines.Add('# Azure Tenant Inventory Report')
    $lines.Add('')
    $lines.Add("| Field | Value |")
    $lines.Add("|-------|-------|")
    $lines.Add("| Generated | $genDate |")
    $lines.Add("| Tenant ID | $TenantID |")
    $lines.Add("| Subscriptions | $subCount |")
    $lines.Add("| Scope | $Scope |")
    $lines.Add("| Tool | AzureTenantInventory |")
    $lines.Add('')

    # ── Discover module folders ───────────────────────────────────────────
    $ParentPath           = (Get-Item $PSScriptRoot).Parent.Parent
    $InventoryModulesPath = Join-Path $ParentPath 'Public' 'InventoryModules'
    $ModuleFolders        = Get-ChildItem -Path $InventoryModulesPath -Directory | Sort-Object Name
    $CacheFiles           = Get-ChildItem -Path $ReportCache -Recurse -Filter '*.json' -ErrorAction SilentlyContinue

    # ── Table of Contents ─────────────────────────────────────────────────
    $tocLines       = [System.Collections.Generic.List[string]]::new()
    $sectionLines   = [System.Collections.Generic.List[string]]::new()
    $totalResources = 0

    $tocLines.Add('## Table of Contents')
    $tocLines.Add('')

    foreach ($ModuleFolder in $ModuleFolders) {
        $FolderName   = $ModuleFolder.Name
        $JSONFileName = "$FolderName.json"
        $CacheFile    = $CacheFiles | Where-Object { $_.Name -eq $JSONFileName }
        if (-not $CacheFile) { continue }

        $RawJson = try { [System.IO.File]::ReadAllText($CacheFile.FullName) } catch { $null }
        if ([string]::IsNullOrWhiteSpace($RawJson)) { continue }

        $CacheData  = $RawJson | ConvertFrom-Json
        $ModuleFiles = Get-ChildItem -Path (Join-Path $ModuleFolder.FullName '*.ps1') -ErrorAction SilentlyContinue | Sort-Object BaseName

        $folderHasData = $false
        $folderSections = [System.Collections.Generic.List[string]]::new()

        foreach ($Module in $ModuleFiles) {
            $ModName      = $Module.BaseName
            $ModResources = $CacheData.$ModName
            if (-not $ModResources -or @($ModResources).Count -eq 0) { continue }

            $rows = @($ModResources)
            $totalResources += $rows.Count

            if (-not $folderHasData) {
                # Add category heading
                $anchor = $FolderName.ToLower() -replace '[^a-z0-9]', '-'
                $tocLines.Add("- [$FolderName](#$anchor)")
                $folderSections.Add("## $FolderName")
                $folderSections.Add('')
                $folderHasData = $true
            }

            # Module sub-heading
            $modAnchor = $ModName.ToLower() -replace '[^a-z0-9]', '-'
            $tocLines.Add("  - [$ModName](#$modAnchor)")
            $folderSections.Add("### $ModName")
            $folderSections.Add('')
            $folderSections.Add("_$($rows.Count) resource(s)_")
            $folderSections.Add('')

            # Build table from first row's properties
            $props = $rows[0].PSObject.Properties.Name | Where-Object { $_ -notmatch 'Tag (Name|Value)|Resource U' }
            if ($props.Count -gt 0) {
                $header = '| ' + ($props -join ' | ') + ' |'
                $sep    = '| ' + (($props | ForEach-Object { '---' }) -join ' | ') + ' |'
                $folderSections.Add($header)
                $folderSections.Add($sep)
                foreach ($row in $rows) {
                    $cells = $props | ForEach-Object {
                        $v = $row.$_
                        if ($null -eq $v) { '' }
                        else { [string]$v -replace '\|', '&#124;' -replace '\r?\n', ' ' }
                    }
                    $folderSections.Add('| ' + ($cells -join ' | ') + ' |')
                }
            }
            $folderSections.Add('')
        }

        if ($folderHasData) {
            foreach ($l in $folderSections) { $sectionLines.Add($l) }
        }
    }

    $tocLines.Add('')
    $lines.Add("_Total resources: $totalResources_")
    $lines.Add('')
    foreach ($l in $tocLines)    { $lines.Add($l) }
    foreach ($l in $sectionLines) { $lines.Add($l) }

    # ── Footer ────────────────────────────────────────────────────────────
    $lines.Add('---')
    $lines.Add('')
    $lines.Add("*Report generated by [AzureTenantInventory](https://github.com/thisismydemo/azure-inventory) at $genDate*")

    try {
        $lines | Out-File -FilePath $MdFile -Encoding UTF8 -Force
        Write-Host "Markdown report saved to: " -ForegroundColor Green -NoNewline
        Write-Host $MdFile -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to write Markdown report to '$MdFile': $_"
    }

    return $MdFile
}
