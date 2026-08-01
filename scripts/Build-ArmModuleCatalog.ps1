#Requires -Version 7.0
<#
.SYNOPSIS
    Regenerate docs/reference/arm-modules.md from the shipped collector manifests (AB#6741).

.DESCRIPTION
    `docs/reference/arm-modules.md` claims in its own tip box that its counts are "generated from the module
    files under manifests/collectors/". They were not — the page was hand-maintained, and by the
    time AB#6741 touched it the header read "159 ARM inventory modules organized into 15
    categories" against a tree holding 174 across 15, with several per-category tables out of date
    too. A page that says it is generated and is not will drift again the moment anyone adds a
    collector.

    So it is generated now. The catalog rows, the counts, and the `-Category` list all come from
    the manifest tree and `Invoke-AzureScout.ps1`'s ValidateSet. The only hand-written content
    left is the per-category one-line description below, which no machine can derive.

    `tests/DocsArmCatalog.Tests.ps1` fails the build when the committed page and a fresh
    regeneration disagree.

.PARAMETER OutputPath
    Defaults to docs/reference/arm-modules.md.

.PARAMETER Check
    Compare against the committed file and exit non-zero on a difference, writing nothing.
#>
[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $RepoRoot 'docs' 'reference' 'arm-modules.md' }

. (Join-Path $RepoRoot 'src' 'pipeline' 'Get-ScoutCollectorDefinition.ps1')

# The one thing that cannot be derived: what a category is FOR, in a sentence.
$CategoryBlurb = @{
    AI          = 'Cognitive Services, Azure OpenAI, Machine Learning, AI Foundry, Bot Services, and AI Search.'
    Analytics   = 'Synapse, Databricks, Data Explorer, Event Hubs, Stream Analytics, and Purview.'
    Compute     = 'Virtual machines, scale sets, availability sets, and the Azure Virtual Desktop estate.'
    Containers  = 'AKS, ARO, Container Apps, container instances, and container registries.'
    Databases   = 'Azure SQL, Cosmos DB, MySQL, PostgreSQL, MariaDB, and Redis.'
    DevOps      = 'Chaos Studio, Dev Box and Dev Centers, DevTest and Lab Services, Load Testing, Managed DevOps Pools, and Playwright workspaces.'
    General     = 'Support tickets, reservations, and VM quotas — the platform-level surfaces that belong to no service family.'
    Hybrid      = 'Azure Arc, Azure Local, VMware Solution, and the hybrid data services.'
    Identity    = 'Entra ID via Microsoft Graph — users, groups, app registrations, Conditional Access, and PIM.'
    Integration = 'Logic Apps, integration accounts, Event Grid, Relays, Health Data Services, API Management, and Service Bus.'
    IoT         = 'IoT Hub and DPS, IoT Central, Device Update, Digital Twins, Azure Maps, and Defender for IoT.'
    Management  = 'Subscriptions, management groups, policy, backup, automation, Advisor, Lighthouse, and the Azure DevOps organisation collectors.'
    Migration   = 'Azure Migrate projects, assessments and discovery sites; Database Migration Services, Data Box, and Azure Stack Edge.'
    Monitor     = 'Alert rules, Application Insights, data collection rules, diagnostic settings, and Log Analytics.'
    Networking  = 'Virtual networks, NSGs, load balancers, gateways, Front Door, Firewall, Bastion, and ExpressRoute.'
    Security    = 'Defender for Cloud, Key Vault and its secret/key expiry, Sentinel, HSMs, WAF and DDoS policies, and Entra Domain Services.'
    Storage     = 'Storage accounts and their containers, shares and lifecycle policies; NetApp Files, snapshots, encryption sets, and Elastic SAN.'
    Web         = 'App Services and plans, Function Apps, slots, Static Web Apps, SignalR, Web PubSub, and Communication Services.'
}

$DefinitionRoot = Join-Path $RepoRoot 'manifests' 'collectors'
$Folders = @(Get-ChildItem -LiteralPath $DefinitionRoot -Directory | Sort-Object Name)

$Total = 0
$Sections = foreach ($Folder in $Folders) {
    $Files = @(Get-ChildItem -LiteralPath $Folder.FullName -Filter '*.psd1' -File | Sort-Object BaseName)
    $Total += $Files.Count
    $Blurb = if ($CategoryBlurb.ContainsKey($Folder.Name)) { $CategoryBlurb[$Folder.Name] } else { '' }
    $Rows = foreach ($File in $Files) {
        $Definition = Get-ScoutCollectorDefinition -Path $File.FullName
        $Types = @($Definition.ResourceTypes) | ForEach-Object { '`' + $_ + '`' }
        $Filter = if ($Definition.AdditionalFilter) { ' *(filtered)*' } else { '' }
        "| $($File.BaseName) | $($Types -join ' · ')$Filter |"
    }
    @(
        ''
        "### $($Folder.Name) ($($Files.Count) modules)"
        ''
        $Blurb
        ''
        '| Module | Resource Type |'
        '|--------|---------------|'
        $Rows
    )
}

$CategoryList = @($Folders | ForEach-Object { $_.Name })

$Header = @(
    '---'
    "description: Complete catalog of AzureScout inventory collectors across all $($Folders.Count) of Microsoft's published service categories."
    '---'
    ''
    '# ARM Inventory Modules'
    ''
    '## Overview'
    ''
    "AzureScout ships **$Total collector definitions** across **$($Folders.Count) categories** — Microsoft's"
    'eighteen published service categories, as listed on the Azure portal''s All services page.'
    'The `Identity` category queries Microsoft Graph rather than ARM; those collectors are also'
    'cataloged on the [Entra ID Modules](entra-modules.md) page.'
    ''
    'Each definition targets one or more Azure resource types and generally produces one worksheet'
    'in the Excel report.'
    ''
    'Run ARM-only extraction with:'
    ''
    '```powershell'
    'Invoke-AzureScout -Scope ArmOnly'
    '```'
    ''
    '`ArmOnly` is the **default** `-Scope` value for `Invoke-AzureScout` — running the'
    'cmdlet with no `-Scope` flag already does this.'
    ''
    '::: tip This page is generated'
    'Regenerate it with `scripts/Build-ArmModuleCatalog.ps1`. The counts and the rows come from'
    '`manifests/collectors/`; `tests/DocsArmCatalog.Tests.ps1` fails the build if the committed page'
    'and a fresh regeneration disagree. Do not hand-edit it — the previous, hand-maintained version'
    'claimed to be generated and was 15 collectors out of date.'
    ':::'
    ''
    '## Module Catalog'
)

$Footer = @(
    ''
    '## Valid `-Category` filter values'
    ''
    'Every category above is a valid `-Category` value. The full `[ValidateSet]` is:'
    ''
    '```'
    "All, $($CategoryList -join ', ')"
    '```'
    ''
    '`Identity` runs the Entra collectors subject to `-Scope`. See'
    '[Category Reference](category-reference.md) for the accepted long-form aliases (e.g.'
    '`-Category ''AI + machine learning''` normalises to `-Category AI`).'
    ''
)

$Content = (@($Header) + @($Sections) + @($Footer)) -join "`n"

# --- docs/reference/coverage-table.md ---------------------------------------------------------------------
# The same tree, sliced by worksheet instead of by resource type. It was a SECOND hand-maintained
# copy of the same facts, and had drifted to the same 2016-era numbers; generating both from one
# pass is the only way they stay consistent with each other as well as with the manifests.
$CoveragePath = Join-Path (Split-Path -Parent $OutputPath) 'coverage-table.md'

$SummaryRows = foreach ($Folder in $Folders) {
    $Count = @(Get-ChildItem -LiteralPath $Folder.FullName -Filter '*.psd1' -File).Count
    $Blurb = if ($CategoryBlurb.ContainsKey($Folder.Name)) { $CategoryBlurb[$Folder.Name] } else { '' }
    "| $($Folder.Name) | $Count | $Blurb |"
}

$CoverageSections = foreach ($Folder in $Folders) {
    $Files = @(Get-ChildItem -LiteralPath $Folder.FullName -Filter '*.psd1' -File | Sort-Object BaseName)
    $Rows = foreach ($File in $Files) {
        $Definition = Get-ScoutCollectorDefinition -Path $File.FullName
        $Types = @($Definition.ResourceTypes) | ForEach-Object { '`' + $_ + '`' }
        "| $($File.BaseName) | $($Types -join ' · ') | $($Definition.Export.WorksheetName) |"
    }
    @(
        ''
        "## $($Folder.Name) Category ($($Files.Count) modules)"
        ''
        '| Module | Resource Type | Worksheet |'
        '|--------|---------------|-----------|'
        $Rows
    )
}

$CoverageContent = (@(
    '---'
    'description: Every AzureScout inventory collector, the Azure resource type it covers, and the Excel worksheet it writes to.'
    '---'
    ''
    '# Coverage Table'
    ''
    'Every inventory collector in AzureScout, the Azure resource type(s) it covers, and the Excel'
    'worksheet it writes to.'
    ''
    '::: tip This page is generated'
    'Regenerate it with `scripts/Build-ArmModuleCatalog.ps1`, which writes this page and'
    '[ARM Modules](arm-modules.md) from the same pass over `manifests/collectors/`.'
    ':::'
    ''
    '## Coverage Summary'
    ''
    '| Category | Modules | Notes |'
    '|----------|---------|-------|'
    $SummaryRows
    "| **Total** | **$Total** | across all $($Folders.Count) of Microsoft's published service categories |"
) + @($CoverageSections) + @('')) -join "`n"

if ($Check) {
    $Failed = $false
    foreach ($Pair in @(@{ Path = $OutputPath; Body = $Content }, @{ Path = $CoveragePath; Body = $CoverageContent })) {
        if (-not (Test-Path -LiteralPath $Pair.Path)) { Write-Error "Missing $($Pair.Path)"; $Failed = $true; continue }
        $Committed = (Get-Content -LiteralPath $Pair.Path -Raw) -replace "`r`n", "`n"
        if ($Committed.TrimEnd() -ne $Pair.Body.TrimEnd()) {
            Write-Error "$($Pair.Path) is out of date. Regenerate it with scripts/Build-ArmModuleCatalog.ps1"
            $Failed = $true
        }
    }
    if ($Failed) { exit 1 }
    Write-Host '[Build-ArmModuleCatalog] docs/reference/arm-modules.md and docs/reference/coverage-table.md are current.'
    exit 0
}

Set-Content -LiteralPath $OutputPath -Value $Content -Encoding utf8NoBOM
Set-Content -LiteralPath $CoveragePath -Value $CoverageContent -Encoding utf8NoBOM
Write-Host "[Build-ArmModuleCatalog] Wrote $OutputPath and $CoveragePath ($Total collectors across $($Folders.Count) categories)"
