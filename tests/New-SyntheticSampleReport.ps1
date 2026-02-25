<#
.SYNOPSIS
    Generates a synthetic sample-report.json for the Excel test harness.

.DESCRIPTION
    Reads every InventoryModule .ps1 file, extracts the column names from
    the Reporting section, and generates 2-3 fake rows per module with
    Contoso-themed data. Outputs a JSON file matching the structure that
    Export-AZSCJsonReport produces.

.NOTES
    Run once to regenerate tests/datadump/sample-report.json.
    This script does NOT require an Azure connection.
#>

[CmdletBinding()]
param(
    [string]$OutputFile
)

$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputFile) {
    $OutputFile = Join-Path $RepoRoot 'tests' 'datadump' 'sample-report.json'
}

$InventoryModulesPath = Join-Path $RepoRoot 'Modules' 'Public' 'InventoryModules'
$EntraFolders = @('Identity')

# ── Fake data pools ──────────────────────────────────────────────────────
$Subscriptions = @(
    @{ id = '00000000-1111-2222-3333-444444444444'; name = 'scout-prod-001' },
    @{ id = '11111111-2222-3333-4444-555555555555'; name = 'scout-dev-001' },
    @{ id = '22222222-3333-4444-5555-666666666666'; name = 'scout-staging-001' }
)

$Locations = @('eastus', 'westus2', 'westeurope', 'northeurope', 'centralus')
$ResourceGroups = @('rg-scout-prod-eus', 'rg-scout-dev-wus2', 'rg-scout-shared-weu', 'rg-scout-data-eus', 'rg-scout-network-eus')
$TagNames = @('Environment', 'CostCenter', 'Owner')
$TagValues = @('Production', 'CC-42', 'platform-team@intergalactic.fish')
$SKUs = @('Standard', 'Premium', 'Basic', 'Free', 'Standard_D2s_v3', 'Standard_B2ms')
$States = @('Succeeded', 'Running', 'Ready', 'Active', 'Enabled')
$VNets = @('vnet-scout-hub-eus', 'vnet-scout-spoke-wus2', 'vnet-scout-prod-weu')
$Subnets = @('snet-default', 'snet-workload', 'snet-data', 'snet-web')
$Zones = @('1', '2', '3', 'Not Configured')

function Get-FakeValue {
    param([string]$FieldName, [int]$RowIndex)

    # Common field patterns
    switch -Wildcard ($FieldName) {
        'Subscription'          { return $Subscriptions[$RowIndex % 3].name }
        'SubscriptionId'        { return $Subscriptions[$RowIndex % 3].id }
        'Resource Group'        { return $ResourceGroups[$RowIndex % $ResourceGroups.Count] }
        'Location'              { return $Locations[$RowIndex % $Locations.Count] }
        'Zone'                  { return $Zones[$RowIndex % $Zones.Count] }
        'Tag Name'              { return $TagNames[$RowIndex % $TagNames.Count] }
        'Tag Value'             { return $TagValues[$RowIndex % $TagValues.Count] }
        'Resource U'            { return 1 }
        'SKU'                   { return $SKUs[$RowIndex % $SKUs.Count] }
        'SKU *'                 { return $SKUs[$RowIndex % $SKUs.Count] }
        'Retiring Feature'      { return $null }
        'Retiring Date'         { return $null }
        '*State'                { return $States[$RowIndex % $States.Count] }
        '*Status'               { return $States[$RowIndex % $States.Count] }
        'Provisioning State'    { return 'Succeeded' }
        'Public Network Access' { return 'Enabled' }
        '*FQDN'                 { return "resource-$RowIndex.intergalactic.fish" }
        '*Endpoint*'            { return "https://resource-$RowIndex.intergalactic.fish" }
        '*URI*'                 { return "https://resource-$RowIndex.intergalactic.fish" }
        '*Url*'                 { return "https://resource-$RowIndex.intergalactic.fish" }
        'Virtual Network'       { return $VNets[$RowIndex % $VNets.Count] }
        'Subnet'                { return $Subnets[$RowIndex % $Subnets.Count] }
        '*IP Address*'          { return "10.$($RowIndex + 1).0.$($RowIndex + 10)" }
        '*IP*'                  { return "10.$($RowIndex + 1).0.$($RowIndex + 10)" }
        'Admin Login'           { return 'scoutadmin' }
        'Admin Username'        { return 'scoutadmin' }
        '*Time*'                { return '2026-01-15T10:30:00Z' }
        '*Date*'                { return '2026-01-15' }
        '*DateTime*'            { return '2026-01-15T10:30:00Z' }
        '*Version*'             { return '1.0.0' }
        '*Enabled'              { return $true }
        '*Count*'               { return ($RowIndex + 1) * 2 }
        '*Size*'                { return ($RowIndex + 1) * 50 }
        '*Score*'               { return [math]::Round(70 + ($RowIndex * 10), 1) }
        '*Percentage*'          { return [math]::Round(0.7 + ($RowIndex * 0.1), 2) }
        '*Cost*'                { return [math]::Round(125.50 + ($RowIndex * 50), 2) }
        '*Days*'                { return 30 }
        '*Retention*'           { return 90 }
        '*Capacity*'            { return ($RowIndex + 1) * 4 }
        '*Tier'                 { return $SKUs[$RowIndex % 3] }
        '*Description'          { return "Synthetic test resource $RowIndex" }
        'Severity'              { return @('High', 'Medium', 'Low')[$RowIndex % 3] }
        'Direction'             { return @('Inbound', 'Outbound')[$RowIndex % 2] }
        'Action'                { return @('Allow', 'Deny')[$RowIndex % 2] }
        'Protocol'              { return @('TCP', 'UDP', 'Any')[$RowIndex % 3] }
        'Priority'              { return 100 + ($RowIndex * 100) }
        '*Type'                 { return "SampleType-$RowIndex" }
        default                 { return "sample-$FieldName-$RowIndex" }
    }
}

function Get-FieldsFromModule {
    param([string]$FilePath)

    $Content = Get-Content $FilePath -Raw
    $Fields = @()

    # ── Primary: $Exc.Add('FieldName') — the definitive column list ─────
    $excMatches = [regex]::Matches($Content, '\$Exc\.Add\(''([^'']+)''\)')
    foreach ($m in $excMatches) {
        $field = $m.Groups[1].Value
        if ($field.Length -gt 1 -and $Fields -notcontains $field) {
            $Fields += $field
        }
    }

    # ── Fallback: single-quoted keys in @{ 'FieldName' = ... } ──────────
    if ($Fields.Count -eq 0) {
        $kvMatches = [regex]::Matches($Content, "'([^']+)'\s*=\s*\$")
        foreach ($m in $kvMatches) {
            $field = $m.Groups[1].Value
            # Skip known non-field patterns (case-sensitive check)
            if ($field.Length -gt 1 -and $Fields -notcontains $field -and
                $field -cnotmatch '^\$|^-' -and
                $field -cnotmatch '^(Processing|Reporting|Import|Export|Write|Get|Set|New|Remove|Start|Stop|Invoke|Test|Clear|Select|Where|Format|Out|Sort|Group|Measure|Compare|ConvertTo|ConvertFrom|Add|Join|Split|Read|ForEach)') {
                $Fields += $field
            }
        }
    }

    # ── Fallback 2: unquoted keys in [ordered]@{ Key = $... } ───────────
    if ($Fields.Count -eq 0) {
        $bareMatches = [regex]::Matches($Content, '^\s+([A-Z]\w+)\s*=\s*\$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($m in $bareMatches) {
            $field = $m.Groups[1].Value
            if ($field.Length -gt 1 -and $Fields -notcontains $field -and
                $field -cnotmatch '^(If|Else|ForEach|While|Switch|Try|Catch|Finally|Param|Begin|Process|End|Return|Break|Continue|Throw|Exit|Function|Filter|Workflow|Configuration|Class|Enum|Using|Trap|Data|DynamicParam|Parallel|Sequence|InlineScript)$') {
                $Fields += $field
            }
        }
    }

    return $Fields
}

# ── Name mapping helper ──────────────────────────────────────────────────
# The Reporting modules use different naming patterns for the worksheet tab
# vs what goes into the cache. But for the JSON, we just need PascalCase module names.

Write-Host "`nGenerating synthetic sample report..." -ForegroundColor Cyan
Write-Host "Reading module schemas from: $InventoryModulesPath`n" -ForegroundColor Gray

$ArmData = [ordered]@{}
$EntraData = [ordered]@{}
$ModuleCount = 0
$RowsPerModule = 3

$ModuleFolders = Get-ChildItem -Path $InventoryModulesPath -Directory | Sort-Object Name

foreach ($folder in $ModuleFolders) {
    $folderKey = $folder.Name.Substring(0, 1).ToLower() + $folder.Name.Substring(1)
    $sectionData = [ordered]@{}

    $modules = Get-ChildItem $folder.FullName -Filter '*.ps1' | Sort-Object Name

    foreach ($mod in $modules) {
        $modName = $mod.BaseName
        $modKey = $modName.Substring(0, 1).ToLower() + $modName.Substring(1)

        # Extract fields
        $fields = Get-FieldsFromModule -FilePath $mod.FullName

        if ($fields.Count -eq 0) {
            Write-Host "  [!] $($folder.Name)/$modName — no fields found, using defaults" -ForegroundColor Yellow
            $fields = @('Subscription', 'Resource Group', 'Name', 'Location', 'Resource U')
        }

        # Generate fake rows
        $rows = @()
        for ($i = 0; $i -lt $RowsPerModule; $i++) {
            $row = [ordered]@{}
            foreach ($field in $fields) {
                $row[$field] = Get-FakeValue -FieldName $field -RowIndex $i
            }
            # Override Name field with something descriptive
            if ($row.Contains('Name')) {
                $row['Name'] = "scout-$(@('prod','dev','staging')[$i % 3])-$($modName.ToLower())-$($i + 1)"
            }
            $rows += $row
        }

        $sectionData[$modKey] = $rows
        $ModuleCount++
    }

    if ($sectionData.Count -gt 0) {
        if ($folder.Name -in $EntraFolders) {
            foreach ($key in $sectionData.Keys) {
                $EntraData[$key] = $sectionData[$key]
            }
            Write-Host "  [+] Identity ($($sectionData.Count) modules → entra)" -ForegroundColor Green
        }
        else {
            $ArmData[$folderKey] = $sectionData
            Write-Host "  [+] $($folder.Name) ($($sectionData.Count) modules)" -ForegroundColor Green
        }
    }
}

# ── Build the full report structure ──────────────────────────────────────
$Report = [ordered]@{
    _metadata = [ordered]@{
        tool          = 'AzureScout'
        version       = '1.0.0'
        tenantId      = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        subscriptions = @(
            [ordered]@{ id = '00000000-1111-2222-3333-444444444444'; name = 'scout-prod-001' },
            [ordered]@{ id = '11111111-2222-3333-4444-555555555555'; name = 'scout-dev-001' },
            [ordered]@{ id = '22222222-3333-4444-5555-666666666666'; name = 'scout-staging-001' }
        )
        generatedAt   = '2026-02-25T12:00:00Z'
        scope         = 'All'
    }
    arm   = $ArmData
    entra = $EntraData
}

# ── Write the JSON ───────────────────────────────────────────────────────
$JsonOutput = $Report | ConvertTo-Json -Depth 20

# Ensure directory exists
$OutputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$JsonOutput | Out-File -FilePath $OutputFile -Encoding utf8

$FileSize = [math]::Round((Get-Item $OutputFile).Length / 1KB, 1)

Write-Host "`n═════════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "  Generated: $OutputFile" -ForegroundColor White
Write-Host "  Modules:   $ModuleCount across $($ModuleFolders.Count) categories" -ForegroundColor Gray
Write-Host "  Rows:      $($ModuleCount * $RowsPerModule) total ($RowsPerModule per module)" -ForegroundColor Gray
Write-Host "  Size:      $FileSize KB" -ForegroundColor Gray
Write-Host "═════════════════════════════════════════════════════`n" -ForegroundColor DarkCyan
