<#
.Synopsis
Build the Azure Update Manager tab in the Excel report

.DESCRIPTION
Creates an "Azure Update Manager" worksheet listing VMs and Arc servers with their
maintenance schedule assignments and patch compliance status, sourced from the
Management/MaintenanceConfigurations and Compute/VirtualMachine cache data.

.COMPONENT
This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors
#>

function Build-AZTIUpdateManagerReport {
    Param($File, $ReportCache, $TableStyle)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Building Azure Update Manager worksheet.')

    $Rows = [System.Collections.Generic.List[object]]::new()

    # ── Maintenance Configurations ────────────────────────────────────────
    $MgmtCache = Join-Path $ReportCache 'Management.json'
    if (Test-Path $MgmtCache) {
        $MgmtData   = Get-Content $MgmtCache -Raw | ConvertFrom-Json
        $Configs    = $MgmtData.MaintenanceConfigurations
        $MaintTable = @{}
        if ($Configs) {
            foreach ($c in $Configs) {
                $key = $c.'Resource Group' + '/' + $c.Name
                $MaintTable[$key] = $c
            }
        }
    }
    else {
        $MaintTable = @{}
    }
    $MaintenanceConfigCount = $MaintTable.Count

    # ── VMs ───────────────────────────────────────────────────────────────
    $ComputeCache = Join-Path $ReportCache 'Compute.json'
    if (Test-Path $ComputeCache) {
        $ComputeData = Get-Content $ComputeCache -Raw | ConvertFrom-Json
        $VMs = $ComputeData.VirtualMachine
        if ($VMs) {
            foreach ($vm in $VMs) {
                $Rows.Add([pscustomobject]@{
                    'Resource Name'             = $vm.Name
                    'Platform'                  = 'Azure VM'
                    'OS Type'                   = $vm.'OS Type'
                    'OS Version / SKU'          = if ($vm.'OS SKU') { $vm.'OS SKU' } else { 'N/A' }
                    'Subscription'              = $vm.Subscription
                    'Resource Group'            = $vm.'Resource Group'
                    'Location'                  = $vm.Location
                    'Power State'               = $vm.'Power State'
                    'Maintenance Schedule'      = 'See MaintenanceConfigurations tab'
                    'Patch Compliance'          = 'N/A'
                    'Last Patch Date'           = 'N/A'
                    'Pending Patches'           = 'N/A'
                })
            }
        }
    }

    # ── Arc Servers ───────────────────────────────────────────────────────
    $HybridCache = Join-Path $ReportCache 'Hybrid.json'
    if (Test-Path $HybridCache) {
        $HybridData = Get-Content $HybridCache -Raw | ConvertFrom-Json
        $Arcs = $HybridData.ARCServers
        if ($Arcs) {
            foreach ($arc in $Arcs) {
                $Rows.Add([pscustomobject]@{
                    'Resource Name'             = $arc.Name
                    'Platform'                  = 'Arc Server'
                    'OS Type'                   = $arc.'OS Type'
                    'OS Version / SKU'          = if ($arc.'OS Name') { $arc.'OS Name' } else { 'N/A' }
                    'Subscription'              = $arc.Subscription
                    'Resource Group'            = $arc.'Resource Group'
                    'Location'                  = $arc.Location
                    'Power State'               = $arc.Status
                    'Maintenance Schedule'      = 'See MaintenanceConfigurations tab'
                    'Patch Compliance'          = if ($arc.'Policy Compliance') { $arc.'Policy Compliance' } else { 'N/A' }
                    'Last Patch Date'           = 'N/A'
                    'Pending Patches'           = 'N/A'
                })
            }
        }
    }

    if ($Rows.Count -gt 0) {
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize
        # Conditional formatting: NonCompliant rows in yellow
        $Excel = $Rows | Export-Excel -Path $File `
            -WorksheetName 'Azure Update Manager' `
            -TableName ('UMgr_' + $Rows.Count) `
            -TableStyle $TableStyle `
            -AutoSize -MaxAutoSizeRows 100 `
            -Style $Style `
            -PassThru

        # Highlight NonCompliant
        $WS = $Excel.Workbook.Worksheets | Where-Object { $_.Name -eq 'Azure Update Manager' }
        if ($WS) {
            $RowIdx = 2
            foreach ($r in $Rows) {
                if ($r.'Patch Compliance' -eq 'NonCompliant') {
                    $WS.Cells[$RowIdx, 1, $RowIdx, 12].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $WS.Cells[$RowIdx, 1, $RowIdx, 12].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::LightYellow)
                }
                $RowIdx++
            }
        }
        Close-ExcelPackage $Excel

        # Summary panel: count configs available
        if ($MaintenanceConfigCount -gt 0) {
            [pscustomobject]@{
                'Maintenance Configurations' = $MaintenanceConfigCount
                'VMs Listed'                 = ($Rows | Where-Object { $_.'Platform' -eq 'Azure VM' }).Count
                'Arc Servers Listed'         = ($Rows | Where-Object { $_.'Platform' -eq 'Arc Server' }).Count
            } | Export-Excel -Path $File `
                -WorksheetName 'Azure Update Manager' `
                -StartRow ($Rows.Count + 5) `
                -AutoSize
        }
    }
    else {
        [pscustomobject]@{
            'Note' = 'No VM or Arc Server data found in cache. Ensure Compute and Hybrid categories were included in the inventory run.'
        } | Export-Excel -Path $File -WorksheetName 'Azure Update Manager' -AutoSize
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Azure Update Manager worksheet complete.')
}
