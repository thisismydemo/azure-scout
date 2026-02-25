<#
.Synopsis
Build the Cost Management tab in the Excel report

.DESCRIPTION
Creates a dedicated "Cost Management" worksheet aggregating estimated cost data
collected during Phase 17 VM/Arc enrichment, reservation recommendations,
and any cost data from the Subscriptions worksheet.

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors
#>

function Build-AZSCCostManagementReport {
    Param($File, $ReportCache, $TableStyle)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Building Cost Management worksheet.')

    $CostRows = [System.Collections.Generic.List[object]]::new()

    # ── Read VM cost estimates from cache ─────────────────────────────────
    $VmCache = Join-Path $ReportCache 'Compute.json'
    if (Test-Path $VmCache) {
        $VmData = Get-Content $VmCache -Raw | ConvertFrom-Json
        $VMs = $VmData.VirtualMachine
        if ($VMs) {
            foreach ($vm in $VMs) {
                if ($vm.'Est. Monthly Cost (USD)' -and $vm.'Est. Monthly Cost (USD)' -ne 'N/A') {
                    $CostRows.Add([pscustomobject]@{
                        'Resource Name'         = $vm.Name
                        'Resource Type'         = 'Virtual Machine'
                        'Subscription'          = $vm.Subscription
                        'Resource Group'        = $vm.'Resource Group'
                        'Location'              = $vm.Location
                        'SKU / Size'            = $vm.Size
                        'Est. Monthly Cost (USD)' = $vm.'Est. Monthly Cost (USD)'
                    })
                }
            }
        }
    }

    # ── Read Arc server cost estimates from cache ─────────────────────────
    $ArcCache = Join-Path $ReportCache 'Hybrid.json'
    if (Test-Path $ArcCache) {
        $ArcData = Get-Content $ArcCache -Raw | ConvertFrom-Json
        $Arcs = $ArcData.ARCServers
        if ($Arcs) {
            foreach ($arc in $Arcs) {
                if ($arc.'Est. Monthly Cost (USD)' -and $arc.'Est. Monthly Cost (USD)' -ne 'N/A') {
                    $CostRows.Add([pscustomobject]@{
                        'Resource Name'           = $arc.Name
                        'Resource Type'           = 'Arc Server'
                        'Subscription'            = $arc.Subscription
                        'Resource Group'          = $arc.'Resource Group'
                        'Location'                = $arc.Location
                        'SKU / Size'              = 'N/A'
                        'Est. Monthly Cost (USD)'  = $arc.'Est. Monthly Cost (USD)'
                    })
                }
            }
        }
    }

    # ── Reservation recommendations from cache ────────────────────────────
    $MgmtCache = Join-Path $ReportCache 'Management.json'
    $ReservRows = [System.Collections.Generic.List[object]]::new()
    if (Test-Path $MgmtCache) {
        $MgmtData = Get-Content $MgmtCache -Raw | ConvertFrom-Json
        $Reserv = $MgmtData.ReservationRecom
        if ($Reserv) {
            foreach ($r in $Reserv) {
                $ReservRows.Add($r)
            }
        }
    }

    # ── Write Cost Estimates worksheet ────────────────────────────────────
    if ($CostRows.Count -gt 0) {
        $Style = @(
            New-ExcelStyle -HorizontalAlignment Center -AutoSize
            New-ExcelStyle -NumberFormat '$#,##0.00' -Range G:G
        )
        $CostRows |
            Export-Excel -Path $File `
                -WorksheetName 'Cost Management' `
                -TableName ('CostMgmt_' + $CostRows.Count) `
                -TableStyle $TableStyle `
                -AutoSize `
                -MaxAutoSizeRows 100 `
                -Style $Style `
                -Append:$false
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Cost Management: $($CostRows.Count) rows written.")
    }
    else {
        # Write a placeholder row explaining how to get cost data
        [pscustomobject]@{
            'Note' = 'No estimated cost data available. Run with -IncludeCosts or ensure Phase 17 enrichment completed.'
        } | Export-Excel -Path $File -WorksheetName 'Cost Management' -AutoSize
    }

    # ── Write Reservation Recommendations sub-section ─────────────────────
    if ($ReservRows.Count -gt 0) {
        $ReservRows |
            Export-Excel -Path $File `
                -WorksheetName 'Cost Management' `
                -TableName ('ReservAdv_' + $ReservRows.Count) `
                -TableStyle $TableStyle `
                -AutoSize `
                -MaxAutoSizeRows 100 `
                -StartRow ($CostRows.Count + 4)
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Reservation recommendations: $($ReservRows.Count) rows written.")
    }
}
