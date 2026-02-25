<#
.Synopsis
Build the Security Overview tab in the Excel report

.DESCRIPTION
Creates a "Security Overview" worksheet consolidating Microsoft Defender for Cloud
secure score, high-severity assessments, active security alerts, and Defender pricing
tier data collected by the Security category modules.

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureScout Contributors
#>

function Build-AZSCSecurityOverviewReport {
    Param($File, $ReportCache, $TableStyle)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Building Security Overview worksheet.')

    $SecCache = Join-Path $ReportCache 'Security.json'
    if (-not (Test-Path $SecCache)) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Security cache found; skipping Security Overview tab.')
        return
    }

    $SecData = Get-Content $SecCache -Raw | ConvertFrom-Json

    # ── Secure Score Summary ──────────────────────────────────────────────
    $ScoreRows = [System.Collections.Generic.List[object]]::new()
    if ($SecData.DefenderSecureScore) {
        foreach ($s in $SecData.DefenderSecureScore) { $ScoreRows.Add($s) }
    }

    # ── High/Critical Assessments ─────────────────────────────────────────
    $AssessRows = [System.Collections.Generic.List[object]]::new()
    if ($SecData.DefenderAssessments) {
        $highSev = $SecData.DefenderAssessments | Where-Object { $_.'Severity' -in ('High', 'Critical') }
        foreach ($a in $highSev) { $AssessRows.Add($a) }
    }

    # ── Active Alerts ─────────────────────────────────────────────────────
    $AlertRows = [System.Collections.Generic.List[object]]::new()
    if ($SecData.DefenderAlerts) {
        $active = $SecData.DefenderAlerts | Where-Object { $_.'Status' -ne 'Dismissed' }
        foreach ($a in $active) { $AlertRows.Add($a) }
    }

    # ── Defender Plan Pricing ─────────────────────────────────────────────
    $PricingRows = [System.Collections.Generic.List[object]]::new()
    if ($SecData.DefenderPricing) {
        foreach ($p in $SecData.DefenderPricing) { $PricingRows.Add($p) }
    }

    $started = $false

    if ($ScoreRows.Count -gt 0) {
        $ScoreRows | Export-Excel -Path $File `
            -WorksheetName 'Security Overview' `
            -TableName ('SecScore_' + $ScoreRows.Count) `
            -TableStyle $TableStyle `
            -AutoSize -MaxAutoSizeRows 100
        $started = $true
    }

    if ($AssessRows.Count -gt 0) {
        $HighStyle = New-ExcelStyle -BackgroundColor ([System.Drawing.Color]::LightCoral) -Bold -Range A1 -AutoSize
        $AssessRows | Export-Excel -Path $File `
            -WorksheetName 'Security Overview' `
            -TableName ('SecAssess_' + $AssessRows.Count) `
            -TableStyle $TableStyle `
            -AutoSize -MaxAutoSizeRows 100 `
            -StartRow ($ScoreRows.Count + 4)
    }

    if ($AlertRows.Count -gt 0) {
        $AlertRows | Export-Excel -Path $File `
            -WorksheetName 'Security Overview' `
            -TableName ('SecAlerts_' + $AlertRows.Count) `
            -TableStyle $TableStyle `
            -AutoSize -MaxAutoSizeRows 100 `
            -StartRow ($ScoreRows.Count + $AssessRows.Count + 7)
    }

    if ($PricingRows.Count -gt 0) {
        $PricingRows | Export-Excel -Path $File `
            -WorksheetName 'Security Overview' `
            -TableName ('SecPricing_' + $PricingRows.Count) `
            -TableStyle $TableStyle `
            -AutoSize `
            -StartRow ($ScoreRows.Count + $AssessRows.Count + $AlertRows.Count + 10)
    }

    if (-not $started -and $AssessRows.Count -eq 0 -and $AlertRows.Count -eq 0 -and $PricingRows.Count -eq 0) {
        [pscustomobject]@{ 'Note' = 'No Defender for Cloud data available. Run with -SecurityCenter or ensure Security modules executed.' } |
            Export-Excel -Path $File -WorksheetName 'Security Overview' -AutoSize
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Security Overview worksheet complete.')
}
