#Requires -Version 7.0
<#
.SYNOPSIS
    Generate declarative collector definitions for the service-coverage build-out (AB#6741).

.DESCRIPTION
    Epic AB#6741 adds roughly fifty collectors across three new categories (Migration, General,
    DevOps) and five thin ones (Storage, Web, Integration, IoT, Security). Every one of them is
    the SAME shape: match one or more Resource Graph types, resolve the subscription, unpack
    `properties`, look up any published retirement, and emit one row per resource (expanded per
    tag when the report is rendered with tags).

    Hand-authoring fifty ~200-line `.psd1` files of that shape is how column/field mismatches and
    copy-paste preamble drift get shipped -- both defect classes `Test-ScoutCollectorDefinition.ps1`
    exists to catch after the fact. So the per-collector input is reduced to what actually differs
    (category, name, worksheet, resource types, an optional row filter, and the service-specific
    field expressions) and this script renders the invariant remainder.

    The generated files carry NO `SourceCollector`. The v2 collector tree is retired; these
    definitions are authored as data, not lifted from a script, so the gate's drift check
    (check 7) has nothing to compare against and correctly skips them.

    IDEMPOTENT. Re-running over an unchanged spec rewrites byte-identical files, so a diff after
    a spec edit shows only what the edit changed.

.PARAMETER SpecPath
    The collector spec. Defaults to `manifests/specs/service-collectors.psd1`.

.PARAMETER Category
    Render only these categories. Default renders every category the spec declares.

.PARAMETER OutputRoot
    Definition tree root. Defaults to `manifests/collectors`.

.NOTES
    Tracks ADO AB#6741 (stories AB#6830, AB#6831, AB#6836, AB#6837, AB#6838).
#>
[CmdletBinding()]
param(
    [string]$SpecPath,
    [string[]]$Category,
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SpecPath))   { $SpecPath   = Join-Path $RepoRoot 'manifests' 'specs' 'service-collectors.psd1' }
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = Join-Path $RepoRoot 'manifests' 'collectors' }

if (-not (Test-Path -LiteralPath $SpecPath)) { throw "Collector spec not found: $SpecPath" }

$Spec = Import-PowerShellDataFile -Path $SpecPath

# The retirement lookup is copied verbatim from the shipped definitions (Storage/NetApp.psd1 and
# 170 others) rather than rewritten. It is the one block in the preamble with real branching, and
# a "tidier" rewrite would make every new collector's retirement columns behave differently from
# every existing one for no gain.
$RetirementBlock = @'
                $Retired = $Retirements | Where-Object { $_.id -eq $1.id }
                if ($Retired)
                    {
                        $RetiredFeature = foreach ($Retire in $Retired)
                            {
                                $RetiredServiceID = $Unsupported | Where-Object {$_.Id -eq $Retired.ServiceID}
                                $tmp0 = [pscustomobject]@{
                                        'RetiredFeature'            = $RetiredServiceID.RetiringFeature
                                        'RetiredDate'               = $RetiredServiceID.RetirementDate
                                    }
                                $tmp0
                            }
                        $RetiringFeature = if (@($RetiredFeature.RetiredFeature).count -gt 1) { $RetiredFeature.RetiredFeature | ForEach-Object { $_ + ' ,' } }else { $RetiredFeature.RetiredFeature}
                        $RetiringFeature = [string]$RetiringFeature
                        $RetiringFeature = if ($RetiringFeature -like '* ,*') { $RetiringFeature -replace ".$" }else { $RetiringFeature }

                        $RetiringDate = if (@($RetiredFeature.RetiredDate).count -gt 1) { $RetiredFeature.RetiredDate | ForEach-Object { $_ + ' ,' } }else { $RetiredFeature.RetiredDate}
                        $RetiringDate = [string]$RetiringDate
                        $RetiringDate = if ($RetiringDate -like '* ,*') { $RetiringDate -replace ".$" }else { $RetiringDate }
                    }
                else
                    {
                        $RetiringFeature = $null
                        $RetiringDate = $null
                    }
'@

function ConvertTo-PsdSingleQuoted {
    param([string]$Value)
    "'" + ($Value -replace "'", "''") + "'"
}

function New-CollectorManifestText {
    param([hashtable]$Collector)

    foreach ($Required in @('Category', 'Name', 'Worksheet', 'ResourceTypes')) {
        if (-not $Collector.ContainsKey($Required) -or -not $Collector[$Required]) {
            throw "Collector spec entry is missing '$Required': $($Collector | ConvertTo-Json -Depth 3 -Compress)"
        }
    }

    $ExtraFields = @(if ($Collector.ContainsKey('Fields') -and $Collector.Fields) { @($Collector.Fields) } else { @() })
    $ExtraPreamble = if ($Collector.ContainsKey('Preamble') -and $Collector.Preamble) { [string]$Collector.Preamble } else { '' }

    # Every collector emits the same five identity columns first, in the same order, so a reader
    # moving between worksheets does not have to relearn the layout per service. A synthetic
    # dataset whose rows are not ARM resources (the VM quota envelope, for one) overrides them --
    # forcing '$1.RESOURCEGROUP' onto a quota reading would be a column of blanks, which is the
    # exact defect the structural gate's check 4 exists to stop.
    $Identity = @(if ($Collector.ContainsKey('Identity') -and $Collector.Identity) { @($Collector.Identity) } else {
        @{ Name = 'ID';             Expression = '$1.id' }
        @{ Name = 'Subscription';   Expression = '$sub1.Name' }
        @{ Name = 'Resource Group'; Expression = '$1.RESOURCEGROUP' }
        @{ Name = 'Name';           Expression = '$1.NAME' }
        @{ Name = 'Location';       Expression = '$1.LOCATION' }
    })
    $HasTagLoop = -not ($Collector.ContainsKey('TagLoop') -and $null -eq $Collector.TagLoop)

    # A collector that overrides Identity is reading a SYNTHETIC envelope, not an ARM resource --
    # `AZSC/VM/Quotas` is one object per run holding a properties array, with no `id`, no
    # `subscriptionId` and no `tags`. The standard preamble would evaluate `$1.id` and
    # `$1.subscriptionId` against it, and the retirement lookup and subscription join would be
    # meaningless even if they did not throw. So both are omitted, along with the retirement
    # columns they feed -- an empty "Retiring Feature" column on a quota worksheet is noise.
    $IsSynthetic = $Collector.ContainsKey('Identity') -and $Collector.Identity

    $Fields = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($Field in $Identity)    { $Fields.Add(@{ Name = [string]$Field.Name; Expression = [string]$Field.Expression }) }
    foreach ($Field in $ExtraFields) { $Fields.Add(@{ Name = [string]$Field.Name; Expression = [string]$Field.Expression }) }
    if (-not $IsSynthetic) {
        $Fields.Add(@{ Name = 'Retiring Feature'; Expression = '$RetiringFeature' })
        $Fields.Add(@{ Name = 'Retiring Date';    Expression = '$RetiringDate' })
    }
    $Fields.Add(@{ Name = 'Resource U';       Expression = '$ResUCount' })
    if ($HasTagLoop) {
        $Fields.Add(@{ Name = 'Tag Name';  Expression = '[string]$Tag.Name' })
        $Fields.Add(@{ Name = 'Tag Value'; Expression = '[string]$Tag.Value' })
    }

    # 'ID' is deliberately NOT exported: it is the join key the cross-resource rules read from the
    # processed rows, and every shipped collector keeps it out of the worksheet the same way.
    $Columns = @($Identity | Where-Object { $_.Name -ne 'ID' } | ForEach-Object { [string]$_.Name }) +
               @($ExtraFields | ForEach-Object { [string]$_.Name }) +
               @(if (-not $IsSynthetic) { 'Retiring Feature'; 'Retiring Date' }) +
               @('Resource U')

    $Builder = [System.Text.StringBuilder]::new()
    $null = $Builder.AppendLine('#')
    $null = $Builder.AppendLine('# GENERATED by scripts/Build-ScoutServiceCollector.ps1 from manifests/specs/service-collectors.psd1 (AB#6741).')
    $null = $Builder.AppendLine('# Authored as data -- there is no source collector script to drift from. Edit the spec and')
    $null = $Builder.AppendLine('# regenerate; do not hand-patch this file.')
    $null = $Builder.AppendLine('#')
    $null = $Builder.AppendLine('@{')
    $null = $Builder.AppendLine('    ResourceTypes = @(')
    foreach ($Type in @($Collector.ResourceTypes)) {
        $null = $Builder.AppendLine("        $(ConvertTo-PsdSingleQuoted -Value ([string]$Type))")
    }
    $null = $Builder.AppendLine('    )')
    $null = $Builder.AppendLine('')

    # SinglePass when the collector admits several types into one ordered pass; Grouped when each
    # declared type gets its own appended pass. Multi-type service collectors here are all the
    # former -- a Logic App standard and consumption workflow belong in one worksheet, ordered by
    # id, not in two blocks.
    $Matching = if ($Collector.ContainsKey('ResourceTypeMatching') -and $Collector.ResourceTypeMatching) {
        [string]$Collector.ResourceTypeMatching
    } elseif (@($Collector.ResourceTypes).Count -gt 1) { 'SinglePass' } else { 'Grouped' }
    $null = $Builder.AppendLine("    ResourceTypeMatching = '$Matching'")
    $null = $Builder.AppendLine('')

    if ($Collector.ContainsKey('AdditionalFilter') -and -not [string]::IsNullOrWhiteSpace([string]$Collector.AdditionalFilter)) {
        $null = $Builder.AppendLine("    AdditionalFilter = $(ConvertTo-PsdSingleQuoted -Value ([string]$Collector.AdditionalFilter))")
    } else {
        $null = $Builder.AppendLine('    AdditionalFilter = $null')
    }
    $null = $Builder.AppendLine('')
    $null = $Builder.AppendLine("    FilterPreamble = ''")
    $null = $Builder.AppendLine('')
    $null = $Builder.AppendLine("    RowLoopVariable = '1'")
    $null = $Builder.AppendLine('')

    $null = $Builder.AppendLine('    Preamble = @''')
    $null = $Builder.AppendLine('$ResUCount = 1')
    if (-not $IsSynthetic) {
        $null = $Builder.AppendLine('                $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }')
    }
    $null = $Builder.AppendLine('                $data = $1.PROPERTIES')
    if (-not $IsSynthetic) {
        $null = $Builder.AppendLine($RetirementBlock)
    }
    if (-not [string]::IsNullOrWhiteSpace($ExtraPreamble)) {
        foreach ($Line in ($ExtraPreamble -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($Line)) { continue }
            $null = $Builder.AppendLine('                ' + $Line.Trim())
        }
    }
    if ($HasTagLoop) {
        $null = $Builder.AppendLine('                $Tags = if(![string]::IsNullOrEmpty($1.tags.psobject.properties)){$1.tags.psobject.properties}else{''0''}')
    }
    $null = $Builder.AppendLine('''@')
    $null = $Builder.AppendLine('')

    $RowLoops = @(if ($Collector.ContainsKey('AdditionalRowLoops') -and $Collector.AdditionalRowLoops) { @($Collector.AdditionalRowLoops) } else { @() })
    if ($RowLoops.Count -eq 0) {
        $null = $Builder.AppendLine('    AdditionalRowLoops = @()')
    } else {
        $null = $Builder.AppendLine('    AdditionalRowLoops = @(')
        foreach ($Loop in $RowLoops) {
            $null = $Builder.AppendLine('        @{')
            # A row loop may carry a `Comment`, emitted verbatim above its Variable. This exists
            # because tests/Collector.VanishingParent.Tests.ps1 requires the AB#6845 decision to be
            # recorded NEXT TO THE LOOP in the generated manifest -- deliberately, so the reasoning
            # cannot drift away from the code into a commit message nobody reads again. Without
            # this the rationale could only live in the spec, and regenerating would strip it out
            # of the very file the test reads.
            if ($Loop.ContainsKey('Comment') -and $Loop.Comment) {
                foreach ($Line in @([string]$Loop.Comment -split "`r?`n")) {
                    if ([string]::IsNullOrWhiteSpace($Line)) { $null = $Builder.AppendLine('            #') }
                    else { $null = $Builder.AppendLine("            # $Line") }
                }
            }
            $null = $Builder.AppendLine("            Variable = $(ConvertTo-PsdSingleQuoted -Value ([string]$Loop.Variable))")
            $null = $Builder.AppendLine("            Source = $(ConvertTo-PsdSingleQuoted -Value ([string]$Loop.Source))")
            $null = $Builder.AppendLine("            Preamble = ''")
            $null = $Builder.AppendLine('        }')
        }
        $null = $Builder.AppendLine('    )')
    }
    $null = $Builder.AppendLine('')
    if ($HasTagLoop) {
        $null = $Builder.AppendLine('    TagLoop = @{')
        $null = $Builder.AppendLine("        Variable = 'Tag'")
        $null = $Builder.AppendLine("        Source = '`$Tags'")
        $null = $Builder.AppendLine("        Preamble = ''")
        $null = $Builder.AppendLine('    }')
    } else {
        $null = $Builder.AppendLine('    TagLoop = $null')
    }
    $null = $Builder.AppendLine('')

    $null = $Builder.AppendLine('    Fields = @(')
    foreach ($Field in $Fields) {
        $null = $Builder.AppendLine('        @{')
        $null = $Builder.AppendLine("            Name = $(ConvertTo-PsdSingleQuoted -Value $Field.Name)")
        $null = $Builder.AppendLine("            Expression = $(ConvertTo-PsdSingleQuoted -Value $Field.Expression)")
        $null = $Builder.AppendLine('        }')
    }
    $null = $Builder.AppendLine('    )')
    $null = $Builder.AppendLine('')

    $Prefix = if ($Collector.ContainsKey('TableNamePrefix') -and $Collector.TableNamePrefix) { [string]$Collector.TableNamePrefix } else { "$($Collector.Name)Table_" }
    $null = $Builder.AppendLine('    Export = @{')
    $null = $Builder.AppendLine("        WorksheetName = $(ConvertTo-PsdSingleQuoted -Value ([string]$Collector.Worksheet))")
    $null = $Builder.AppendLine("        TableNamePrefix = $(ConvertTo-PsdSingleQuoted -Value $Prefix)")
    $null = $Builder.AppendLine('        Columns = @(')
    foreach ($Column in $Columns) {
        $null = $Builder.AppendLine("            $(ConvertTo-PsdSingleQuoted -Value $Column)")
    }
    $null = $Builder.AppendLine('        )')
    if ($HasTagLoop) {
        $null = $Builder.AppendLine('        TagColumns = @(')
        $null = $Builder.AppendLine("            'Tag Name'")
        $null = $Builder.AppendLine("            'Tag Value'")
        $null = $Builder.AppendLine('        )')
        $null = $Builder.AppendLine("        TagColumnsBefore = 'Resource U'")
    } else {
        $null = $Builder.AppendLine('        TagColumns = @()')
    }
    $null = $Builder.AppendLine("        NumberFormat = '0'")
    $null = $Builder.AppendLine('        ConditionalText = @()')
    $null = $Builder.AppendLine('    }')
    $null = $Builder.AppendLine('}')

    return $Builder.ToString()
}

$Wanted = @($Spec.Collectors)
if ($Category -and @($Category).Count -gt 0) {
    $Wanted = @($Wanted | Where-Object { $Category -contains $_.Category })
}

$Written = 0
foreach ($Collector in $Wanted) {
    $CategoryDir = Join-Path $OutputRoot ([string]$Collector.Category)
    if (-not (Test-Path -LiteralPath $CategoryDir)) { $null = New-Item -Path $CategoryDir -ItemType Directory -Force }
    $Target = Join-Path $CategoryDir "$([string]$Collector.Name).psd1"
    $Text = New-CollectorManifestText -Collector $Collector
    # -NoNewline plus explicit CRLF-free content keeps regeneration byte-stable across platforms.
    Set-Content -LiteralPath $Target -Value $Text -Encoding utf8NoBOM -NoNewline
    $Written++
    Write-Verbose "Wrote $Target"
}

Write-Host "Generated $Written collector definition(s) from $SpecPath"
