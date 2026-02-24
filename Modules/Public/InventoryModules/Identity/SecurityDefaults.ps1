<#
.SYNOPSIS
    Inventory module for Entra ID Security Defaults Policy.

.DESCRIPTION
    Extracts and reports on the Security Defaults enforcement policy configuration.
    Security Defaults provide baseline security protections for Entra ID tenants.

.NOTES
    Type: entra/securitydefaults
    Sheet: Security Defaults
#>

Register-AZTIInventoryModule -ModuleId 'entra/securitydefaults' -PhaseId 'Processing' -ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $Resources = $Context.EntraData.'entra/securitydefaults'
    if (-not $Resources) {
        Write-AZTILog -Message "No security defaults data available" -Level Verbose
        return
    }

    Write-AZTILog -Message "Processing security defaults policy"

    foreach ($Policy in $Resources) {
        try {
            # Extract enabled status
            $IsEnabled = if ($Policy.isEnabled) { 'Yes' } else { 'No' }

            # Extract description
            $Description = $Policy.description ?? 'N/A'

            # Extract display name
            $DisplayName = $Policy.displayName ?? 'Security Defaults Enforcement Policy'

            # Check if there's a modified date
            $LastModified = if ($Policy.lastModifiedDateTime) {
                try {
                    [DateTime]::Parse($Policy.lastModifiedDateTime).ToString('yyyy-MM-dd HH:mm:ss')
                }
                catch {
                    $Policy.lastModifiedDateTime
                }
            }
            else {
                'N/A'
            }

            # Security defaults protections (informational)
            $ProtectionsProvided = @(
                'Require MFA for administrators'
                'Require MFA for end users when necessary'
                'Block legacy authentication'
                'Protect privileged activities like Azure portal access'
                'Require users to register for MFA'
            ) -join '; '

            # Determine recommendation status
            $RecommendationStatus = if ($Policy.isEnabled) {
                'Security Defaults Enabled (or use Conditional Access for advanced control)'
            }
            else {
                'Security Defaults Disabled - Ensure Conditional Access is configured'
            }

            # Extract tenant ID if available
            $TenantId = $Context.TenantId ?? 'N/A'

            $Record = [PSCustomObject][ordered]@{
                TenantId             = $TenantId
                PolicyName           = $DisplayName
                Id                   = $Policy.id
                Enabled              = $IsEnabled
                Description          = $Description
                LastModified         = $LastModified
                ProtectionsProvided  = $ProtectionsProvided
                RecommendationStatus = $RecommendationStatus
            }

            Add-AZTIProcessedData -Type 'entra/securitydefaults' -Data $Record

        }
        catch {
            Write-AZTILog -Message "Failed to process security defaults policy: $_" -Level Error
        }
    }
}

Register-AZTIInventoryModule -ModuleId 'entra/securitydefaults' -PhaseId 'Reporting' -ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $Data = Get-AZTIProcessedData -Type 'entra/securitydefaults'
    if (-not $Data) {
        Write-AZTILog -Message "No security defaults data to export" -Level Verbose
        return
    }

    Write-AZTILog -Message "Exporting security defaults policy to Excel"

    try {
        $ExcelParams = @{
            Path          = $Context.ExcelPath
            WorksheetName = 'Security Defaults'
            TableName     = 'SecurityDefaults'
            TableStyle    = 'Medium2'
            AutoSize      = $true
            FreezeTopRow  = $true
            Append        = $true
        }

        $Data | Export-Excel @ExcelParams -PassThru | Out-Null

        # Apply conditional formatting
        $Excel = Open-ExcelPackage -Path $Context.ExcelPath
        $Worksheet = $Excel.Workbook.Worksheets['Security Defaults']

        if ($Worksheet) {
            # Find Enabled column
            $Headers = 1..($Worksheet.Dimension.Columns) | ForEach-Object {
                $Worksheet.Cells[1, $_].Text
            }
            $EnabledColIndex = ($Headers.IndexOf('Enabled')) + 1

            if ($EnabledColIndex -gt 0) {
                $RowCount = $Worksheet.Dimension.Rows
                for ($Row = 2; $Row -le $RowCount; $Row++) {
                    $CellValue = $Worksheet.Cells[$Row, $EnabledColIndex].Text
                    if ($CellValue -eq 'Yes') {
                        # Green for enabled
                        $Worksheet.Cells[$Row, $EnabledColIndex].Style.Fill.PatternType = 'Solid'
                        $Worksheet.Cells[$Row, $EnabledColIndex].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(198, 239, 206))
                    }
                    else {
                        # Yellow for disabled (may be using Conditional Access instead)
                        $Worksheet.Cells[$Row, $EnabledColIndex].Style.Fill.PatternType = 'Solid'
                        $Worksheet.Cells[$Row, $EnabledColIndex].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 235, 156))
                    }
                }
            }

            # Set text wrapping
            $Worksheet.Cells[$Worksheet.Dimension.Address].Style.WrapText = $true
        }

        Close-ExcelPackage -ExcelPackage $Excel

        Write-AZTILog -Message "Security defaults export completed"
    }
    catch {
        Write-AZTILog -Message "Failed to export security defaults: $_" -Level Error
    }
}
