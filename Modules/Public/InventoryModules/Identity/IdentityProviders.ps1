<#
.SYNOPSIS
    Inventory module for Entra ID Identity Providers.

.DESCRIPTION
    Extracts and reports on configured identity providers including federated identity providers,
    social identity providers (Microsoft, Google, Facebook), and OIDC/SAML providers.

.NOTES
    Type: entra/identityproviders
    Sheet: Identity Providers
#>

Register-AZTIInventoryModule -ModuleId 'entra/identityproviders' -PhaseId 'Processing' -ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $Resources = $Context.EntraData.'entra/identityproviders'
    if (-not $Resources) {
        Write-AZTILog -Message "No identity providers data available" -Level Verbose
        return
    }

    Write-AZTILog -Message "Processing $($Resources.Count) identity provider(s)"

    foreach ($Provider in $Resources) {
        try {
            # Determine provider type and extract type-specific properties
            $ProviderType = if ($Provider.'@odata.type') {
                switch ($Provider.'@odata.type') {
                    '#microsoft.graph.builtInIdentityProvider' { 'Built-In' }
                    '#microsoft.graph.socialIdentityProvider' { 'Social' }
                    '#microsoft.graph.samlOrWsFedProvider' { 'SAML/WS-Fed' }
                    '#microsoft.graph.openIdConnectProvider' { 'OIDC' }
                    '#microsoft.graph.appleManagedIdentityProvider' { 'Apple' }
                    default { ($_ -replace '#microsoft\.graph\.', '') }
                }
            }
            else {
                'Unknown'
            }

            # Extract identity provider type (in addition to protocol)
            $IdentityProviderType = $Provider.identityProviderType ?? 'N/A'

            # Extract client/app ID
            $ClientId = $Provider.clientId ?? $Provider.appId ?? 'N/A'

            # Extract issuer/metadata URL
            $IssuerUrl = $Provider.issuerUri ?? $Provider.metadataUrl ?? $Provider.openIdConnectDiscoveryEndpoint ?? 'N/A'

            # Extract domains hint (for social providers)
            $DomainsHint = if ($Provider.domainsHint) {
                ($Provider.domainsHint -join '; ')
            }
            else {
                'N/A'
            }

            # Check if client secret is configured
            $ClientSecretConfigured = if ($Provider.clientSecret) { 'Yes' } else { 'No' }

            # Extract response mode and type
            $ResponseMode = $Provider.responseMode ?? 'N/A'
            $ResponseType = $Provider.responseType ?? 'N/A'

            # Extract scope (for OIDC)
            $Scope = $Provider.scope ?? 'N/A'

            # Determine enabled status (some providers don't have this property)
            $Enabled = if ($null -ne $Provider.isEnabled) {
                if ($Provider.isEnabled) { 'Yes' } else { 'No' }
            }
            else {
                'N/A'
            }

            $Record = [PSCustomObject][ordered]@{
                Name                    = $Provider.displayName ?? $Provider.name ?? 'Unnamed Provider'
                Id                      = $Provider.id
                Type                    = $ProviderType
                IdentityProviderType    = $IdentityProviderType
                ClientId                = $ClientId
                ClientSecretConfigured  = $ClientSecretConfigured
                IssuerUrl               = $IssuerUrl
                DomainsHint             = $DomainsHint
                ResponseMode            = $ResponseMode
                ResponseType            = $ResponseType
                Scope                   = $Scope
                Enabled                 = $Enabled
            }

            Add-AZTIProcessedData -Type 'entra/identityproviders' -Data $Record

        }
        catch {
            Write-AZTILog -Message "Failed to process provider $($Provider.id): $_" -Level Error
        }
    }
}

Register-AZTIInventoryModule -ModuleId 'entra/identityproviders' -PhaseId 'Reporting' -ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $Data = Get-AZTIProcessedData -Type 'entra/identityproviders'
    if (-not $Data) {
        Write-AZTILog -Message "No identity providers data to export" -Level Verbose
        return
    }

    Write-AZTILog -Message "Exporting $($Data.Count) identity provider(s) to Excel"

    try {
        $ExcelParams = @{
            Path          = $Context.ExcelPath
            WorksheetName = 'Identity Providers'
            TableName     = 'IdentityProviders'
            TableStyle    = 'Medium2'
            AutoSize      = $true
            FreezeTopRow  = $true
            Append        = $true
        }

        $Data | Export-Excel @ExcelParams -PassThru | Out-Null

        # Apply conditional formatting - highlight if client secret not configured
        $Excel = Open-ExcelPackage -Path $Context.ExcelPath
        $Worksheet = $Excel.Workbook.Worksheets['Identity Providers']

        if ($Worksheet) {
            # Find column index for ClientSecretConfigured
            $Headers = 1..($Worksheet.Dimension.Columns) | ForEach-Object {
                $Worksheet.Cells[1, $_].Text
            }
            $SecretColIndex = ($Headers.IndexOf('ClientSecretConfigured')) + 1

            if ($SecretColIndex -gt 0) {
                $RowCount = $Worksheet.Dimension.Rows
                for ($Row = 2; $Row -le $RowCount; $Row++) {
                    $CellValue = $Worksheet.Cells[$Row, $SecretColIndex].Text
                    if ($CellValue -eq 'No') {
                        $Worksheet.Cells[$Row, $SecretColIndex].Style.Fill.PatternType = 'Solid'
                        $Worksheet.Cells[$Row, $SecretColIndex].Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(255, 255, 200))
                    }
                }
            }

            # Set text wrapping for longer fields
            $Worksheet.Cells[$Worksheet.Dimension.Address].Style.WrapText = $true
        }

        Close-ExcelPackage -ExcelPackage $Excel

        Write-AZTILog -Message "Identity providers export completed"
    }
    catch {
        Write-AZTILog -Message "Failed to export identity providers: $_" -Level Error
    }
}
