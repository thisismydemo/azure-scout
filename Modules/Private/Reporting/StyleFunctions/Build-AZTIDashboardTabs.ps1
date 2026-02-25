<#
.Synopsis
Module for Dashboard Visual Tabs

.DESCRIPTION
Creates dedicated dashboard tabs — styled like the Overview (blue shapes, charts/graphs)
— that visualize data from the raw data-dump worksheets (Cost Management, Security Overview,
Azure Update Manager, Azure Monitor).

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: February 25, 2026
Authors: AzureScout Contributors
#>

function Build-AZSCDashboardTabs {
    Param($File, $TableStyle, $IncludeCosts)

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Building visual dashboard tabs.')

    $Font = 'Segoe UI'
    $Date = Get-Date -Format 'MM/dd/yyyy'

    $Excel = Open-ExcelPackage -Path $File
    $Worksheets = $Excel.Workbook.Worksheets

    # ═══════════════════════════════════════════════════════════════════════
    # COST DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════
    $hasCostData = $Worksheets | Where-Object { $_.Name -eq 'Cost Management' }
    if ($hasCostData) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Creating Cost Dashboard tab.')

        # Create the worksheet if it doesn't exist
        $CostDash = $Worksheets | Where-Object { $_.Name -eq 'Cost Dashboard' }
        if (-not $CostDash) {
            $CostDash = $Excel.Workbook.Worksheets.Add('Cost Dashboard')
        }
        $CostDash.View.ShowGridLines = $false
        $CostDash.TabColor = [System.Drawing.Color]::FromArgb(38, 38, 102)

        # Title shape
        $TitleShape = $CostDash.Drawings.AddShape('CostTitle', 'RoundRect')
        $TitleShape.SetSize(900, 60)
        $TitleShape.SetPosition(0, 0, 0, 5)
        $TitleShape.TextAlignment = 'Center'
        $TitleShape.Fill.Color = [System.Drawing.Color]::FromArgb(38, 38, 102)
        $txt = $TitleShape.RichText.Add("Cost Management Dashboard — $Date")
        $txt.Size = 18
        $txt.Color = [System.Drawing.Color]::White
        $txt.ComplexFont = $Font
        $txt.LatinFont = $Font
        $txt.Bold = $true

        Close-ExcelPackage $Excel

        # Chart 1: Cost by Resource Type (bar chart)
        $CostWS = $null
        try {
            $tmpExcel = Open-ExcelPackage -Path $File
            $CostWS = $tmpExcel.Workbook.Worksheets | Where-Object { $_.Name -eq 'Cost Management' }
            $CostHasTable = $CostWS.Tables.Count -gt 0
            Close-ExcelPackage $tmpExcel -NoSave
        } catch { $CostHasTable = $false }

        if ($CostHasTable) {
            $PTParams = @{
                PivotTableName          = 'CostPT1'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Resource Type')
                PivotData               = @{'Est. Monthly Cost (USD)' = 'Sum'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'BarClustered'
                ChartRow                = 5
                ChartColumn             = 0
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Estimated Monthly Cost by Resource Type'
                PivotNumberFormat       = '$#,##0.00'
                ShowPercent             = $true
                ChartHeight             = 400
                ChartWidth              = 600
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }

            $Excel2 = Open-ExcelPackage -Path $File
            $PTParams.Address = $Excel2.'Cost Dashboard'.Cells['Z5']
            $PTParams.SourceWorkSheet = $Excel2.'Cost Management'
            Add-PivotTable @PTParams
            Close-ExcelPackage $Excel2

            # Chart 2: Cost by Subscription (pie chart)
            $PTParams2 = @{
                PivotTableName          = 'CostPT2'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Subscription')
                PivotData               = @{'Est. Monthly Cost (USD)' = 'Sum'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'Pie3D'
                ChartRow                = 5
                ChartColumn             = 9
                Activate                = $true
                ChartTitle              = 'Cost Distribution by Subscription'
                PivotNumberFormat       = '$#,##0.00'
                ShowPercent             = $true
                ChartHeight             = 400
                ChartWidth              = 400
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $Excel3 = Open-ExcelPackage -Path $File
            $PTParams2.Address = $Excel3.'Cost Dashboard'.Cells['AF5']
            $PTParams2.SourceWorkSheet = $Excel3.'Cost Management'
            Add-PivotTable @PTParams2
            Close-ExcelPackage $Excel3

            # Chart 3: Cost by Location (column chart)
            $PTParams3 = @{
                PivotTableName          = 'CostPT3'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Location')
                PivotData               = @{'Est. Monthly Cost (USD)' = 'Sum'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'ColumnStacked3D'
                ChartRow                = 27
                ChartColumn             = 0
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Cost by Region'
                PivotNumberFormat       = '$#,##0.00'
                ShowPercent             = $true
                ChartHeight             = 350
                ChartWidth              = 600
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $Excel4 = Open-ExcelPackage -Path $File
            $PTParams3.Address = $Excel4.'Cost Dashboard'.Cells['AL5']
            $PTParams3.SourceWorkSheet = $Excel4.'Cost Management'
            Add-PivotTable @PTParams3
            Close-ExcelPackage $Excel4

            # Chart 4: Cost by SKU/Size (bar chart)
            $PTParams4 = @{
                PivotTableName          = 'CostPT4'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('SKU / Size')
                PivotData               = @{'Est. Monthly Cost (USD)' = 'Sum'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'BarStacked3D'
                ChartRow                = 27
                ChartColumn             = 9
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Cost by SKU / Size'
                PivotNumberFormat       = '$#,##0.00'
                ShowPercent             = $true
                ChartHeight             = 350
                ChartWidth              = 400
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $Excel5 = Open-ExcelPackage -Path $File
            $PTParams4.Address = $Excel5.'Cost Dashboard'.Cells['AR5']
            $PTParams4.SourceWorkSheet = $Excel5.'Cost Management'
            Add-PivotTable @PTParams4
            Close-ExcelPackage $Excel5
        }

        $Excel = Open-ExcelPackage -Path $File
        $Worksheets = $Excel.Workbook.Worksheets
    }
    else {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Cost Management data tab found; skipping Cost Dashboard.')
    }

    # ═══════════════════════════════════════════════════════════════════════
    # SECURITY DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════
    $hasSecData = $Worksheets | Where-Object { $_.Name -eq 'Security Overview' }
    if ($hasSecData) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Creating Security Dashboard tab.')

        $SecDash = $Worksheets | Where-Object { $_.Name -eq 'Security Dashboard' }
        if (-not $SecDash) {
            $SecDash = $Excel.Workbook.Worksheets.Add('Security Dashboard')
        }
        $SecDash.View.ShowGridLines = $false
        $SecDash.TabColor = [System.Drawing.Color]::FromArgb(38, 38, 102)

        # Title shape
        $TitleShape = $SecDash.Drawings.AddShape('SecTitle', 'RoundRect')
        $TitleShape.SetSize(900, 60)
        $TitleShape.SetPosition(0, 0, 0, 5)
        $TitleShape.TextAlignment = 'Center'
        $TitleShape.Fill.Color = [System.Drawing.Color]::FromArgb(38, 38, 102)
        $txt = $TitleShape.RichText.Add("Security Dashboard — $Date")
        $txt.Size = 18
        $txt.Color = [System.Drawing.Color]::White
        $txt.ComplexFont = $Font
        $txt.LatinFont = $Font
        $txt.Bold = $true

        Close-ExcelPackage $Excel

        # Security Overview has multiple stacked tables (SecScore, SecAssess, SecAlerts, SecPricing).
        # We must use SourceRange pointing to each specific table's address so the pivot
        # picks up the correct columns instead of the entire worksheet dimension.
        $SecTableMap = @{}
        try {
            $tmpExcel = Open-ExcelPackage -Path $File
            $SecWS = $tmpExcel.Workbook.Worksheets | Where-Object { $_.Name -eq 'Security Overview' }
            foreach ($tbl in $SecWS.Tables) {
                $SecTableMap[$tbl.Name] = $tbl.Address.ToString()
            }
            Close-ExcelPackage $tmpExcel -NoSave
        } catch { }

        if ($SecTableMap.Count -gt 0) {
            # Chart 1: Assessments by Severity
            $assessKey = $SecTableMap.Keys | Where-Object { $_ -like 'SecAssess*' } | Select-Object -First 1
            if ($assessKey) {
                $PTParams = @{
                    PivotTableName          = 'SecPT1'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Severity')
                    PivotData               = @{'Severity' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'Pie3D'
                    ChartRow                = 5
                    ChartColumn             = 0
                    Activate                = $true
                    ChartTitle              = 'Security Assessments by Severity'
                    ShowPercent             = $true
                    ChartHeight             = 400
                    ChartWidth              = 450
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams.Address        = $e.'Security Dashboard'.Cells['Z5']
                $PTParams.SourceWorkSheet = $e.'Security Overview'
                $PTParams.SourceRange     = $e.'Security Overview'.Cells[$SecTableMap[$assessKey]]
                try { Add-PivotTable @PTParams } catch { Write-Debug "SecPT1 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 2: Assessments by Subscription
            if ($assessKey) {
                $PTParams2 = @{
                    PivotTableName          = 'SecPT2'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Subscription')
                    PivotData               = @{'Subscription' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'BarClustered'
                    ChartRow                = 5
                    ChartColumn             = 8
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Security Findings by Subscription'
                    ShowPercent             = $true
                    ChartHeight             = 400
                    ChartWidth              = 500
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams2.Address        = $e.'Security Dashboard'.Cells['AF5']
                $PTParams2.SourceWorkSheet = $e.'Security Overview'
                $PTParams2.SourceRange     = $e.'Security Overview'.Cells[$SecTableMap[$assessKey]]
                try { Add-PivotTable @PTParams2 } catch { Write-Debug "SecPT2 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 3: Defender Plans (pricing) — column is 'Plan Name' not 'Plan'
            $pricingKey = $SecTableMap.Keys | Where-Object { $_ -like 'SecPricing*' } | Select-Object -First 1
            if ($pricingKey) {
                $PTParams3 = @{
                    PivotTableName          = 'SecPT3'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Plan Name')
                    PivotData               = @{'Plan Name' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'ColumnStacked3D'
                    ChartRow                = 27
                    ChartColumn             = 0
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Defender Plans'
                    ShowPercent             = $true
                    ChartHeight             = 350
                    ChartWidth              = 450
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams3.Address        = $e.'Security Dashboard'.Cells['AL5']
                $PTParams3.SourceWorkSheet = $e.'Security Overview'
                $PTParams3.SourceRange     = $e.'Security Overview'.Cells[$SecTableMap[$pricingKey]]
                try { Add-PivotTable @PTParams3 } catch { Write-Debug "SecPT3 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 4: Alerts by Severity
            $alertsKey = $SecTableMap.Keys | Where-Object { $_ -like 'SecAlerts*' } | Select-Object -First 1
            if ($alertsKey) {
                $PTParams4 = @{
                    PivotTableName          = 'SecPT4'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Severity')
                    PivotData               = @{'Severity' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'BarStacked3D'
                    ChartRow                = 27
                    ChartColumn             = 8
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Active Alerts by Severity'
                    ShowPercent             = $true
                    ChartHeight             = 350
                    ChartWidth              = 500
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams4.Address        = $e.'Security Dashboard'.Cells['AR5']
                $PTParams4.SourceWorkSheet = $e.'Security Overview'
                $PTParams4.SourceRange     = $e.'Security Overview'.Cells[$SecTableMap[$alertsKey]]
                try { Add-PivotTable @PTParams4 } catch { Write-Debug "SecPT4 skipped: $_" }
                Close-ExcelPackage $e
            }
        }

        $Excel = Open-ExcelPackage -Path $File
        $Worksheets = $Excel.Workbook.Worksheets
    }
    else {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Security Overview data tab found; skipping Security Dashboard.')
    }

    # ═══════════════════════════════════════════════════════════════════════
    # UPDATE MANAGER DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════
    $hasUMData = $Worksheets | Where-Object { $_.Name -eq 'Azure Update Manager' }
    if ($hasUMData) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Creating Update Manager Dashboard tab.')

        $UMDash = $Worksheets | Where-Object { $_.Name -eq 'Update Dashboard' }
        if (-not $UMDash) {
            $UMDash = $Excel.Workbook.Worksheets.Add('Update Dashboard')
        }
        $UMDash.View.ShowGridLines = $false
        $UMDash.TabColor = [System.Drawing.Color]::FromArgb(38, 38, 102)

        # Title shape
        $TitleShape = $UMDash.Drawings.AddShape('UMTitle', 'RoundRect')
        $TitleShape.SetSize(900, 60)
        $TitleShape.SetPosition(0, 0, 0, 5)
        $TitleShape.TextAlignment = 'Center'
        $TitleShape.Fill.Color = [System.Drawing.Color]::FromArgb(38, 38, 102)
        $txt = $TitleShape.RichText.Add("Azure Update Manager Dashboard — $Date")
        $txt.Size = 18
        $txt.Color = [System.Drawing.Color]::White
        $txt.ComplexFont = $Font
        $txt.LatinFont = $Font
        $txt.Bold = $true

        Close-ExcelPackage $Excel

        # Check tables
        $UMHasTable = $false
        try {
            $tmpExcel = Open-ExcelPackage -Path $File
            $UMWS = $tmpExcel.Workbook.Worksheets | Where-Object { $_.Name -eq 'Azure Update Manager' }
            $UMHasTable = $UMWS.Tables.Count -gt 0
            Close-ExcelPackage $tmpExcel -NoSave
        } catch { $UMHasTable = $false }

        if ($UMHasTable) {
            # Chart 1: Machines by Platform (Azure VM vs Arc)
            $PTParams = @{
                PivotTableName          = 'UMPT1'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Platform')
                PivotData               = @{'Platform' = 'Count'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'Pie3D'
                ChartRow                = 5
                ChartColumn             = 0
                Activate                = $true
                ChartTitle              = 'Machines by Platform'
                ShowPercent             = $true
                ChartHeight             = 400
                ChartWidth              = 400
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $e = Open-ExcelPackage -Path $File
            $PTParams.Address = $e.'Update Dashboard'.Cells['Z5']
            $PTParams.SourceWorkSheet = $e.'Azure Update Manager'
            try { Add-PivotTable @PTParams } catch { Write-Debug "UMPT1 skipped: $_" }
            Close-ExcelPackage $e

            # Chart 2: Machines by OS Type
            $PTParams2 = @{
                PivotTableName          = 'UMPT2'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('OS Type')
                PivotData               = @{'OS Type' = 'Count'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'Pie3D'
                ChartRow                = 5
                ChartColumn             = 7
                Activate                = $true
                ChartTitle              = 'Machines by OS Type'
                ShowPercent             = $true
                ChartHeight             = 400
                ChartWidth              = 400
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $e = Open-ExcelPackage -Path $File
            $PTParams2.Address = $e.'Update Dashboard'.Cells['AF5']
            $PTParams2.SourceWorkSheet = $e.'Azure Update Manager'
            try { Add-PivotTable @PTParams2 } catch { Write-Debug "UMPT2 skipped: $_" }
            Close-ExcelPackage $e

            # Chart 3: Machines by Location
            $PTParams3 = @{
                PivotTableName          = 'UMPT3'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Location')
                PivotData               = @{'Location' = 'Count'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'ColumnStacked3D'
                ChartRow                = 27
                ChartColumn             = 0
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Machines by Region'
                ShowPercent             = $true
                ChartHeight             = 350
                ChartWidth              = 500
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $e = Open-ExcelPackage -Path $File
            $PTParams3.Address = $e.'Update Dashboard'.Cells['AL5']
            $PTParams3.SourceWorkSheet = $e.'Azure Update Manager'
            try { Add-PivotTable @PTParams3 } catch { Write-Debug "UMPT3 skipped: $_" }
            Close-ExcelPackage $e

            # Chart 4: Machines by Power State
            $PTParams4 = @{
                PivotTableName          = 'UMPT4'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Power State')
                PivotData               = @{'Power State' = 'Count'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'BarStacked3D'
                ChartRow                = 27
                ChartColumn             = 8
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Machines by Power State'
                ShowPercent             = $true
                ChartHeight             = 350
                ChartWidth              = 400
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $e = Open-ExcelPackage -Path $File
            $PTParams4.Address = $e.'Update Dashboard'.Cells['AR5']
            $PTParams4.SourceWorkSheet = $e.'Azure Update Manager'
            try { Add-PivotTable @PTParams4 } catch { Write-Debug "UMPT4 skipped: $_" }
            Close-ExcelPackage $e

            # Chart 5: Machines by Subscription
            $PTParams5 = @{
                PivotTableName          = 'UMPT5'
                Address                 = $null
                SourceWorkSheet         = $null
                PivotRows               = @('Subscription')
                PivotData               = @{'Subscription' = 'Count'}
                PivotTableStyle         = $TableStyle
                IncludePivotChart       = $true
                ChartType               = 'BarClustered'
                ChartRow                = 49
                ChartColumn             = 0
                Activate                = $true
                NoLegend                = $true
                ChartTitle              = 'Machines by Subscription'
                ShowPercent             = $true
                ChartHeight             = 350
                ChartWidth              = 900
                ChartRowOffSetPixels    = 5
                ChartColumnOffSetPixels = 5
            }
            $e = Open-ExcelPackage -Path $File
            $PTParams5.Address = $e.'Update Dashboard'.Cells['AX5']
            $PTParams5.SourceWorkSheet = $e.'Azure Update Manager'
            try { Add-PivotTable @PTParams5 } catch { Write-Debug "UMPT5 skipped: $_" }
            Close-ExcelPackage $e
        }

        $Excel = Open-ExcelPackage -Path $File
        $Worksheets = $Excel.Workbook.Worksheets
    }
    else {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Azure Update Manager data tab found; skipping Update Dashboard.')
    }

    # ═══════════════════════════════════════════════════════════════════════
    # MONITOR DASHBOARD
    # ═══════════════════════════════════════════════════════════════════════
    $hasMonData = $Worksheets | Where-Object { $_.Name -eq 'Azure Monitor' }
    if ($hasMonData) {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Creating Monitor Dashboard tab.')

        $MonDash = $Worksheets | Where-Object { $_.Name -eq 'Monitor Dashboard' }
        if (-not $MonDash) {
            $MonDash = $Excel.Workbook.Worksheets.Add('Monitor Dashboard')
        }
        $MonDash.View.ShowGridLines = $false
        $MonDash.TabColor = [System.Drawing.Color]::FromArgb(38, 38, 102)

        # Title shape
        $TitleShape = $MonDash.Drawings.AddShape('MonTitle', 'RoundRect')
        $TitleShape.SetSize(900, 60)
        $TitleShape.SetPosition(0, 0, 0, 5)
        $TitleShape.TextAlignment = 'Center'
        $TitleShape.Fill.Color = [System.Drawing.Color]::FromArgb(38, 38, 102)
        $txt = $TitleShape.RichText.Add("Azure Monitor Dashboard — $Date")
        $txt.Size = 18
        $txt.Color = [System.Drawing.Color]::White
        $txt.ComplexFont = $Font
        $txt.LatinFont = $Font
        $txt.Bold = $true

        Close-ExcelPackage $Excel

        # Azure Monitor also has multiple stacked tables — build a table map
        $MonTableMap = @{}
        try {
            $tmpExcel = Open-ExcelPackage -Path $File
            $MonWS = $tmpExcel.Workbook.Worksheets | Where-Object { $_.Name -eq 'Azure Monitor' }
            foreach ($tbl in $MonWS.Tables) {
                $MonTableMap[$tbl.Name] = $tbl.Address.ToString()
            }
            Close-ExcelPackage $tmpExcel -NoSave
        } catch { }

        if ($MonTableMap.Count -gt 0) {
            # Chart 1: Alert Rules by Subscription (MetricAlerts table)
            $metricKey = $MonTableMap.Keys | Where-Object { $_ -like 'MetricAlerts*' } | Select-Object -First 1
            if ($metricKey) {
                $PTParams = @{
                    PivotTableName          = 'MonPT1'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Subscription')
                    PivotData               = @{'Subscription' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'BarClustered'
                    ChartRow                = 5
                    ChartColumn             = 0
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Alert Rules by Subscription'
                    ShowPercent             = $true
                    ChartHeight             = 400
                    ChartWidth              = 500
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams.Address        = $e.'Monitor Dashboard'.Cells['Z5']
                $PTParams.SourceWorkSheet = $e.'Azure Monitor'
                $PTParams.SourceRange     = $e.'Azure Monitor'.Cells[$MonTableMap[$metricKey]]
                try { Add-PivotTable @PTParams } catch { Write-Debug "MonPT1 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 2: Action Groups by Subscription (ActGrp table)
            $actGrpKey = $MonTableMap.Keys | Where-Object { $_ -like 'ActGrp*' } | Select-Object -First 1
            if ($actGrpKey) {
                $PTParams2 = @{
                    PivotTableName          = 'MonPT2'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Subscription')
                    PivotData               = @{'Subscription' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'Pie3D'
                    ChartRow                = 5
                    ChartColumn             = 8
                    Activate                = $true
                    ChartTitle              = 'Action Groups by Subscription'
                    ShowPercent             = $true
                    ChartHeight             = 400
                    ChartWidth              = 400
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams2.Address        = $e.'Monitor Dashboard'.Cells['AF5']
                $PTParams2.SourceWorkSheet = $e.'Azure Monitor'
                $PTParams2.SourceRange     = $e.'Azure Monitor'.Cells[$MonTableMap[$actGrpKey]]
                try { Add-PivotTable @PTParams2 } catch { Write-Debug "MonPT2 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 3: DCRs by Subscription (DCRs table)
            $dcrKey = $MonTableMap.Keys | Where-Object { $_ -like 'DCRs*' } | Select-Object -First 1
            if ($dcrKey) {
                $PTParams3 = @{
                    PivotTableName          = 'MonPT3'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Subscription')
                    PivotData               = @{'Subscription' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'ColumnStacked3D'
                    ChartRow                = 27
                    ChartColumn             = 0
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Data Collection Rules by Subscription'
                    ShowPercent             = $true
                    ChartHeight             = 350
                    ChartWidth              = 500
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams3.Address        = $e.'Monitor Dashboard'.Cells['AL5']
                $PTParams3.SourceWorkSheet = $e.'Azure Monitor'
                $PTParams3.SourceRange     = $e.'Azure Monitor'.Cells[$MonTableMap[$dcrKey]]
                try { Add-PivotTable @PTParams3 } catch { Write-Debug "MonPT3 skipped: $_" }
                Close-ExcelPackage $e
            }

            # Chart 4: App Insights by Subscription (AppInsights table)
            $appKey = $MonTableMap.Keys | Where-Object { $_ -like 'AppInsights*' } | Select-Object -First 1
            if ($appKey) {
                $PTParams4 = @{
                    PivotTableName          = 'MonPT4'
                    Address                 = $null
                    SourceWorkSheet         = $null
                    SourceRange             = $null
                    PivotRows               = @('Subscription')
                    PivotData               = @{'Subscription' = 'Count'}
                    PivotTableStyle         = $TableStyle
                    IncludePivotChart       = $true
                    ChartType               = 'BarStacked3D'
                    ChartRow                = 27
                    ChartColumn             = 8
                    Activate                = $true
                    NoLegend                = $true
                    ChartTitle              = 'Application Insights by Subscription'
                    ShowPercent             = $true
                    ChartHeight             = 350
                    ChartWidth              = 400
                    ChartRowOffSetPixels    = 5
                    ChartColumnOffSetPixels = 5
                }
                $e = Open-ExcelPackage -Path $File
                $PTParams4.Address        = $e.'Monitor Dashboard'.Cells['AR5']
                $PTParams4.SourceWorkSheet = $e.'Azure Monitor'
                $PTParams4.SourceRange     = $e.'Azure Monitor'.Cells[$MonTableMap[$appKey]]
                try { Add-PivotTable @PTParams4 } catch { Write-Debug "MonPT4 skipped: $_" }
                Close-ExcelPackage $e
            }
        }

        $Excel = Open-ExcelPackage -Path $File
        $Worksheets = $Excel.Workbook.Worksheets
    }
    else {
        Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - No Azure Monitor data tab found; skipping Monitor Dashboard.')
    }

    Close-ExcelPackage $Excel

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Dashboard tabs complete.')
}
