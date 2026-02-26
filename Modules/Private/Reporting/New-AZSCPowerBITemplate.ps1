<#
.Synopsis
Generate a Power BI Template (.pbit) file from an AzureScout CSV bundle.

.DESCRIPTION
Reads the CSV files produced by Export-AZSCPowerBIReport and packages them
into a valid Power BI Template (.pbit) file that can be opened directly in
Power BI Desktop. Opening the template loads all resource tables, the
subscription dimension, and the metadata table — ready for exploration with
no manual import steps required.

The .pbit is an OPC ZIP archive containing:
    [Content_Types].xml      — standard OPC content types
    Version                  — schema version ("3")
    DataModelSchema          — JSON: table/column definitions built from CSV headers
    DiagramState             — JSON: empty star-schema diagram layout
    Mashup                   — inner ZIP: Power Query (M) code to read each CSV
    Report/Layout            — JSON: minimal blank report page
    Settings                 — JSON: minimal report settings
    SecurityBindings         — empty bytes (required by PBI Desktop)

When Power BI Desktop opens the .pbit it will prompt:
    "The report was built from a snapshot — do you want to refresh?"
Clicking Refresh loads all data from the CSV files. If the CSV folder
has moved the user is prompted to re-point the FolderPath parameter.

.PARAMETER PowerBIDir
Path to the folder containing the exported CSV bundle (output of
Export-AZSCPowerBIReport).

.PARAMETER OutputFile
Full path (including .pbit extension) for the file to create.

.OUTPUTS
[string] Path to the created .pbit file.

.EXAMPLE
$pbitPath = New-AZSCPowerBITemplate `
    -PowerBIDir 'C:\reports\PowerBI' `
    -OutputFile 'C:\reports\AzureScout.pbit'

.NOTES
Version         : 1.0.0
First Release   : February 26, 2026
PowerShell      : 7.0+  (uses [System.IO.Compression])
No extra modules required.
#>
function New-AZSCPowerBITemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PowerBIDir,

        [Parameter(Mandatory)]
        [string] $OutputFile
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + ' - Starting Power BI Template (.pbit) generation.')

    # ── Validate input folder ────────────────────────────────────────────
    if (-not (Test-Path $PowerBIDir)) {
        throw "PowerBIDir not found: $PowerBIDir"
    }

    $csvFiles = Get-ChildItem -Path $PowerBIDir -Filter '*.csv' -ErrorAction SilentlyContinue |
                Sort-Object Name

    if (-not $csvFiles -or $csvFiles.Count -eq 0) {
        throw "No CSV files found in $PowerBIDir. Run Export-AZSCPowerBIReport first."
    }

    # Normalise folder path for M code (forward-slash path parameter)
    $FolderPathForM = $PowerBIDir.Replace('\', '\\')

    # ── Build table metadata from CSV headers ────────────────────────────
    $tables = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($csv in $csvFiles) {
        $tableName = [System.IO.Path]::GetFileNameWithoutExtension($csv.Name)

        # Read header row only (first line)
        $headerLine = $null
        try {
            $sr = [System.IO.StreamReader]::new($csv.FullName, [System.Text.Encoding]::UTF8)
            $headerLine = $sr.ReadLine()
            $sr.Dispose()
        }
        catch { $headerLine = $null }

        $columns = if ($headerLine) {
            $headerLine -split ',' | ForEach-Object { $_.Trim('"').Trim() } | Where-Object { $_ -ne '' }
        } else { @() }

        $tables.Add(@{
            Name     = $tableName
            FileName = $csv.Name
            Columns  = $columns
        })
    }

    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - Found $($tables.Count) tables from CSV files.")

    # ─────────────────────────────────────────────────────────────────────
    # 1.  Version
    # ─────────────────────────────────────────────────────────────────────
    # Must be exactly "3" — PowerBIPackager.ValidateVersion requires a single
    # integer parseable by Version.Parse(). Written as plain ASCII.
    $versionContent = '3'

    # ─────────────────────────────────────────────────────────────────────
    # 3.  DataModelSchema  (JSON)
    # ─────────────────────────────────────────────────────────────────────
    $dmTables = [System.Collections.Generic.List[object]]::new()

    foreach ($t in $tables) {
        $cols = [System.Collections.Generic.List[object]]::new()
        $colIdx = 0
        foreach ($col in $t.Columns) {
            # Infer a broad type: IDs / dates stay text; everything else text for safety
            $dataType = 'string'
            $formatStr = ''

            $cols.Add([ordered]@{
                name           = $col
                dataType       = $dataType
                formatString   = $formatStr
                lineageTag     = "col-$($t.Name)-$colIdx"
                summarizeBy    = 'none'
                sourceColumn   = $col
                annotations    = @([ordered]@{
                    name  = 'SummarizationSetBy'
                    value = 'Automatic'
                })
            })
            $colIdx++
        }

        # Build M expression reference (partition source points to M query)
        $partition = [ordered]@{
            name     = 'Partition'
            dataView = 'full'
            source   = [ordered]@{
                type       = 'm'
                expression = @("[$($t.Name)]")
            }
        }

        $dmTables.Add([ordered]@{
            name         = $t.Name
            lineageTag   = "tbl-$($t.Name)"
            columns      = @($cols)
            partitions   = @($partition)
            annotations  = @([ordered]@{ name = 'PBI_ResultType'; value = 'Table' })
        })
    }

    # Add a simple calculated measure table for AzureScout summary info
    $dmTables.Add([ordered]@{
        name        = '_Measures'
        lineageTag  = 'tbl-measures'
        columns     = @(
            [ordered]@{
                name         = 'ID'
                dataType     = 'int64'
                isHidden     = $true
                lineageTag   = 'col-measures-id'
                summarizeBy  = 'sum'
                sourceColumn = 'ID'
            }
        )
        partitions  = @(
            [ordered]@{
                name     = 'Partition'
                mode     = 'import'
                source   = [ordered]@{
                    type       = 'm'
                    expression = @("[_Measures]")
                }
            }
        )
        measures    = @(
            [ordered]@{
                name        = 'Total Resources'
                expression  = 'SUMX(INFO.TABLES(), IF(LEFT([Name],10)="Resources_",[Rows],0))'
                lineageTag  = 'msr-total-resources'
                annotations = @([ordered]@{ name = 'PBI_FormatHint'; value = '{"isGeneralNumber":true}' })
            }
        )
        annotations = @([ordered]@{ name = 'PBI_ResultType'; value = 'Table' })
    })

    # Build relationships (resource tables → Subscriptions via SubscriptionName/Subscription)
    $dmRelationships = [System.Collections.Generic.List[object]]::new()
    $relIdx = 0
    foreach ($t in $tables) {
        if ($t.Name -like 'Resources_*' -or $t.Name -like 'Entra_*') {
            if ($t.Columns -contains 'Subscription') {
                $dmRelationships.Add([ordered]@{
                    name       = "rel$relIdx"
                    fromTable  = $t.Name
                    fromColumn = 'Subscription'
                    toTable    = 'Subscriptions'
                    toColumn   = 'SubscriptionName'
                })
                $relIdx++
            }
        }
    }

    $dataModelSchema = [ordered]@{
        name                = 'Model'
        culture             = 'en-US'
        dataAccessOptions   = [ordered]@{ legacyRedirects = $true; returnErrorValuesAsNull = $true }
        defaultPowerBIDataSourceVersion = 'powerBI_V3'
        sourceQueryCulture  = 'en-US'
        tables              = @($dmTables)
        relationships       = @($dmRelationships)
        annotations         = @(
            [ordered]@{ name = 'PBIDesktopVersion'; value = '2.128.1380.0 (Main)' }
            [ordered]@{ name = '__PBI_TimeIntelligenceEnabled';   value = '0' }
            [ordered]@{ name = 'PBIDesktopVersion'; value = '2.128.1380.0' }
        )
    }

    $dataModelSchemaJson = $dataModelSchema | ConvertTo-Json -Depth 20 -Compress

    # ─────────────────────────────────────────────────────────────────────
    # 4.  Mashup inner ZIP  (Power Query M code)
    # ─────────────────────────────────────────────────────────────────────

    # -- Build Section1.m   -----------------------------------------------
    $mLines = [System.Text.StringBuilder]::new()
    [void]$mLines.AppendLine('section Section1;')
    [void]$mLines.AppendLine('')

    # FolderPath parameter query (makes the template portable — user can change on open)
    [void]$mLines.AppendLine('shared FolderPath =')
    [void]$mLines.AppendLine('let')
    [void]$mLines.AppendLine("    Source = `"$FolderPathForM`"")
    [void]$mLines.AppendLine('in')
    [void]$mLines.AppendLine('    Source;')
    [void]$mLines.AppendLine('')

    # _Measures placeholder table (1-row hidden table for hosting measures)
    [void]$mLines.AppendLine('shared _Measures =')
    [void]$mLines.AppendLine('let')
    [void]$mLines.AppendLine('    Source = #table(type table [ID = Int64.Type], {{1}})')
    [void]$mLines.AppendLine('in')
    [void]$mLines.AppendLine('    Source;')
    [void]$mLines.AppendLine('')

    # One query per CSV file
    foreach ($t in $tables) {
        $safeName = $t.Name
        $fileName = $t.FileName

        [void]$mLines.AppendLine("shared $safeName =")
        [void]$mLines.AppendLine('let')
        [void]$mLines.AppendLine("    _path   = FolderPath & `"\\$fileName`",")
        [void]$mLines.AppendLine('    _source = Csv.Document(')
        [void]$mLines.AppendLine('                  File.Contents(_path),')
        [void]$mLines.AppendLine('                  [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]'),
        [void]$mLines.AppendLine('              ),')
        [void]$mLines.AppendLine('    _promoted = Table.PromoteHeaders(_source, [PromoteAllScalars = true]),')
        [void]$mLines.AppendLine('    _typed    = Table.TransformColumnTypes(_promoted,')
        
        # Build column type list — everything as text for maximum compatibility
        $typeList = ($t.Columns | ForEach-Object { "{{`"$_`", type text}}" }) -join ', '
        if ($typeList) {
            [void]$mLines.AppendLine("                  {$typeList}")
        } else {
            [void]$mLines.AppendLine('                  {}')
        }
        [void]$mLines.AppendLine('              )')
        [void]$mLines.AppendLine('in')
        [void]$mLines.AppendLine('    _typed;')
        [void]$mLines.AppendLine('')
    }

    $section1MContent = $mLines.ToString()

    # -- Config file for Mashup -------------------------------------------
    $mashupConfig = '{"IsParameterQuery":false,"ResultType":"Text","NumericPrecision":null,"NumericScale":null}'

    # Build the inner Mashup ZIP in memory
    $mashupStream = [System.IO.MemoryStream]::new()
    $mashupZip = [System.IO.Compression.ZipArchive]::new($mashupStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)

    # [Content_Types].xml inside Mashup
    $mashupCT = @'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="m"    ContentType="application/x-ms-m" />
  <Default Extension="json" ContentType="application/json" />
</Types>
'@
    $ctEntry = $mashupZip.CreateEntry('[Content_Types].xml')
    $ctWriter = [System.IO.StreamWriter]::new($ctEntry.Open(), [System.Text.Encoding]::UTF8)
    $ctWriter.Write($mashupCT)
    $ctWriter.Dispose()

    # Config
    $cfgEntry = $mashupZip.CreateEntry('Config')
    $cfgWriter = [System.IO.StreamWriter]::new($cfgEntry.Open(), [System.Text.Encoding]::UTF8)
    $cfgWriter.Write($mashupConfig)
    $cfgWriter.Dispose()

    # Package/Formulas/Section1.m
    $m1Entry = $mashupZip.CreateEntry('Package/Formulas/Section1.m')
    $m1Writer = [System.IO.StreamWriter]::new($m1Entry.Open(), [System.Text.Encoding]::UTF8)
    $m1Writer.Write($section1MContent)
    $m1Writer.Dispose()

    # Package/[Content_Types].xml
    $pkgCT = @'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="m" ContentType="application/x-ms-m" />
</Types>
'@
    $pkgCTEntry = $mashupZip.CreateEntry('Package/[Content_Types].xml')
    $pkgCTWriter = [System.IO.StreamWriter]::new($pkgCTEntry.Open(), [System.Text.Encoding]::UTF8)
    $pkgCTWriter.Write($pkgCT)
    $pkgCTWriter.Dispose()

    $mashupZip.Dispose()
    $mashupBytes = $mashupStream.ToArray()
    $mashupStream.Dispose()

    # ─────────────────────────────────────────────────────────────────────
    # 5.  Report/Layout  (minimal blank page JSON)
    # ─────────────────────────────────────────────────────────────────────
    $reportLayout = [ordered]@{
        id                  = 0
        resourcePackages    = @()
        sections            = @(
            [ordered]@{
                id           = 0
                name         = 'ReportSection'
                displayName  = 'AzureScout Inventory'
                filters      = '[]'
                ordinal      = 0
                visualContainers = @(
                    # Title text box
                    [ordered]@{
                        x         = 20
                        y         = 20
                        z         = 0
                        width     = 1260
                        height    = 80
                        config    = '{"name":"title","layouts":[{"id":0,"position":{"x":20,"y":20,"z":0,"tabOrder":0,"height":80,"width":1260}}],"singleVisual":{"visualType":"textbox","projections":{},"prototypeQuery":{"Version":2,"From":[],"Select":[],"Where":[]},"drillFilterOtherVisuals":true,"objects":{"general":[{"properties":{"paragraphs":[{"textRuns":[{"value":"AzureScout — Azure Inventory Report","textStyle":{"fontFamily":"Segoe UI","fontSize":"18pt","bold":true,"color":{"solid":{"color":"#3B3F42"}}}}],"horizontalTextAlignment":"Left"}]}}]}}}'
                        filters   = '[]'
                        query     = '{}'
                        dataTransforms = '{}'
                    }
                )
                config  = '{"relationships":[]}'
                display = '{}'
                height  = 720
                width   = 1280
            }
        )
        config              = '{}'
        filters             = '[]'
        theme               = [ordered]@{
            name    = 'AzureScout'
            version = '1.0.0'
        }
        annotations         = @([ordered]@{ name = 'PBIDesktopVersion'; value = '2.128.1380.0 (Main)' })
    }

    $reportLayoutJson = $reportLayout | ConvertTo-Json -Depth 30 -Compress

    # ─────────────────────────────────────────────────────────────────────
    # 6.  DiagramState  (relationship diagram layout)
    # ─────────────────────────────────────────────────────────────────────
    $diagramTables = [System.Collections.Generic.List[object]]::new()
    $xPos = 20; $yPos = 20
    foreach ($t in $tables) {
        $diagramTables.Add([ordered]@{
            name     = $t.Name
            position = [ordered]@{ x = $xPos; y = $yPos; width = 220; height = 100 }
        })
        $xPos += 240
        if ($xPos -gt 1000) { $xPos = 20; $yPos += 120 }
    }

    $diagramState = [ordered]@{
        version = '0.0'
        tables  = @($diagramTables)
    }
    $diagramStateJson = $diagramState | ConvertTo-Json -Depth 10 -Compress

    # ─────────────────────────────────────────────────────────────────────
    # 7.  Settings  (minimal)
    # ─────────────────────────────────────────────────────────────────────
    $settingsJson = '{"UseStrictDateTimeHandling":false}'

    # ─────────────────────────────────────────────────────────────────────
    # 8.  Assemble the .pbit using the OPC Package API (System.IO.Packaging)
    # ─────────────────────────────────────────────────────────────────────
    # WindowsBase.dll provides System.IO.Packaging — the same OPC stack that
    # Power BI Desktop uses to write .pbix/.pbit files.  Using raw ZipArchive
    # causes encoding/content-type problems; the Package API handles all of
    # that correctly (including [Content_Types].xml, part URIs, compression).
    Add-Type -AssemblyName WindowsBase

    $outDir = Split-Path $OutputFile -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    if (Test-Path $OutputFile)    { Remove-Item $OutputFile -Force }

    $pkg = [System.IO.Packaging.Package]::Open(
               $OutputFile,
               [System.IO.FileMode]::Create,
               [System.IO.FileAccess]::ReadWrite)

    # Helper: write a text part with specified encoding
    function Add-OpcPart {
        param(
            [System.IO.Packaging.Package]  $Package,
            [string]  $PartUri,
            [string]  $ContentType,
            [string]  $Content,
            [System.Text.Encoding] $Encoding
        )
        $uri    = [System.Uri]::new($PartUri, [System.UriKind]::Relative)
        $part   = $Package.CreatePart($uri, $ContentType, [System.IO.Packaging.CompressionOption]::Maximum)
        $writer = [System.IO.StreamWriter]::new($part.GetStream([System.IO.FileMode]::Create), $Encoding)
        $writer.Write($Content)
        $writer.Flush()
        $writer.Close()
    }

    # Helper: write a binary part
    function Add-OpcBinaryPart {
        param(
            [System.IO.Packaging.Package]  $Package,
            [string]  $PartUri,
            [string]  $ContentType,
            [byte[]]  $Bytes
        )
        $uri    = [System.Uri]::new($PartUri, [System.UriKind]::Relative)
        $part   = $Package.CreatePart($uri, $ContentType, [System.IO.Packaging.CompressionOption]::Maximum)
        $stream = $part.GetStream([System.IO.FileMode]::Create)
        if ($Bytes -and $Bytes.Length -gt 0) { $stream.Write($Bytes, 0, $Bytes.Length) }
        $stream.Flush()
        $stream.Close()
    }

    $encAscii   = [System.Text.Encoding]::ASCII
    $encUtf16Le = New-Object System.Text.UnicodeEncoding($false, $true)  # LE, with BOM

    Add-OpcPart       -Package $pkg -PartUri '/Version'          -ContentType 'text/plain'               -Content $versionContent      -Encoding $encAscii
    Add-OpcPart       -Package $pkg -PartUri '/DataModelSchema'  -ContentType 'application/json'         -Content $dataModelSchemaJson  -Encoding $encUtf16Le
    Add-OpcPart       -Package $pkg -PartUri '/DiagramState'     -ContentType 'application/json'         -Content $diagramStateJson     -Encoding $encUtf16Le
    Add-OpcPart       -Package $pkg -PartUri '/Report/Layout'    -ContentType 'application/json'         -Content $reportLayoutJson     -Encoding $encUtf16Le
    Add-OpcPart       -Package $pkg -PartUri '/Settings'         -ContentType 'application/json'         -Content $settingsJson         -Encoding $encUtf16Le
    Add-OpcBinaryPart -Package $pkg -PartUri '/Mashup'           -ContentType 'application/octet-stream' -Bytes   $mashupBytes
    Add-OpcBinaryPart -Package $pkg -PartUri '/SecurityBindings' -ContentType 'application/octet-stream' -Bytes   @()

    $pkg.Close()

    $sizeKB = [math]::Round((Get-Item $OutputFile).Length / 1KB, 1)
    Write-Debug ((Get-Date -Format 'yyyy-MM-dd_HH_mm_ss') + " - .pbit written: $OutputFile ($sizeKB KB)")

    Write-Host "Power BI Template saved: " -ForegroundColor Green -NoNewline
    Write-Host $OutputFile -ForegroundColor Cyan
    Write-Host "  Tables: $($tables.Count)  |  Size: $sizeKB KB  |  Open in Power BI Desktop to refresh & explore." -ForegroundColor Gray

    return $OutputFile
}
