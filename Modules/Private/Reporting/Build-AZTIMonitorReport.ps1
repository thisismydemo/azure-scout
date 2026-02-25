<#
.Synopsis
Build the Azure Monitor tab in the Excel report

.DESCRIPTION
Creates an "Azure Monitor" worksheet aggregating key Azure Monitor resources:
action groups, alert rules, data collection rules, Log Analytics workspaces,
Application Insights, and autoscale settings — sourced from the Monitor category cache.

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors
#>

function Build-AZSCMonitorReport {
    Param($File, $ReportCache, $TableStyle)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Building Azure Monitor worksheet.')

    $MonitorCache = Join-Path $ReportCache 'Monitor.json'
    if (-not (Test-Path $MonitorCache)) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Monitor cache found; skipping Azure Monitor tab.')
        return
    }

    $MonData = Get-Content $MonitorCache -Raw | ConvertFrom-Json

    # ── Section builder helper ────────────────────────────────────────────
    $currentRow = 1
    $written    = $false

    function Write-MonitorSection {
        param($SectionData, $TableSuffix, $SheetName, $FilePath, $Style, $TableStyleParam, $Row)
        if ($SectionData -and @($SectionData).Count -gt 0) {
            $rows = @($SectionData)
            $rows | Export-Excel -Path $FilePath `
                -WorksheetName $SheetName `
                -TableName ($TableSuffix + '_' + $rows.Count) `
                -TableStyle $TableStyleParam `
                -AutoSize -MaxAutoSizeRows 100 `
                -Style $Style `
                -StartRow $Row
            return $rows.Count
        }
        return 0
    }

    $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize

    # Action Groups
    $n = Write-MonitorSection -SectionData $MonData.ActionGroups -TableSuffix 'ActGrp' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Alert Rules (metric)
    $n = Write-MonitorSection -SectionData $MonData.MetricAlertRules -TableSuffix 'MetricAlerts' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Scheduled Query Rules (log alert)
    $n = Write-MonitorSection -SectionData $MonData.ScheduledQueryRules -TableSuffix 'LogAlerts' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Data Collection Rules
    $n = Write-MonitorSection -SectionData $MonData.DataCollectionRules -TableSuffix 'DCRs' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Data Collection Endpoints
    $n = Write-MonitorSection -SectionData $MonData.DataCollectionEndpoints -TableSuffix 'DCEs' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Application Insights
    $n = Write-MonitorSection -SectionData $MonData.AppInsights -TableSuffix 'AppInsights' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $currentRow += $n + 3; $written = $true }

    # Autoscale Settings
    $n = Write-MonitorSection -SectionData $MonData.AutoscaleSettings -TableSuffix 'Autoscale' -SheetName 'Azure Monitor' -FilePath $File -Style $Style -TableStyleParam $TableStyle -Row $currentRow
    if ($n -gt 0) { $written = $true }

    if (-not $written) {
        [pscustomobject]@{
            'Note' = 'No Azure Monitor data found in cache. Ensure Monitor category was included in the inventory run.'
        } | Export-Excel -Path $File -WorksheetName 'Azure Monitor' -AutoSize
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Azure Monitor worksheet complete.')
}
