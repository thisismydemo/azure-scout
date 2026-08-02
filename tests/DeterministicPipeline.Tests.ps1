<#
    AB#5649 — the deterministic pipeline.

    The v1 processing phase coordinated background jobs and nested runspaces. Every defect of
    the v2.5.x wave lived in that coordination, not in the collectors:

      * Start-Job is asynchronous, so a NotStarted job was excluded from the wait, harvested
        empty by Receive-Job and then destroyed by Remove-Job — the category vanished from the
        report with no trace (AB#5629).
      * The wait loop read $Job.Runspace.IsCompleted. PowerShellAsyncResult has no .Runspace,
        so the expression was empty and the loop never waited at all.
      * Get-Job ordering varied, so the same tenant produced different reports run to run.
      * Each job re-imported the module, leaking module-scope StrictMode back in — which is why
        the v2.5.3 opt-out had to be applied at 17 entry points rather than 5.

    These tests pin the properties that replaced it: fixed ordering, contained per-collector
    failure, and byte-identical output for identical input. They run against a fixture tree, so
    they need no Azure and no jobs.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot

    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollector.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollectorDefinition.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutDeclarativeCollector.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutCollector.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Write-ScoutCacheFile.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutProcessing.ps1')

    # ── Fixture collector tree ───────────────────────────────────────────────────────────
    # Mirrors the retired collector layout: one directory per category, each holding
    # collectors that take the ten positional parameters and switch on $Task.
    $script:FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("scout-pipeline-" + [guid]::NewGuid().ToString('N'))
    $script:DefinitionRoot = Join-Path $script:FixtureRoot 'definitions'

    function New-FixtureCollector {
        Param($Category, $Name, $Body, $DeclaredCategory)

        $Dir = Join-Path $script:FixtureRoot $Category
        if (-not (Test-Path -LiteralPath $Dir)) { $null = New-Item -Path $Dir -ItemType Directory -Force }

        # Built by concatenation, not -replace: the collector bodies contain $_ and $1-style
        # sequences that the .NET replacement-string parser would eat.
        $Lines = @()
        if ($DeclaredCategory) {
            # Same-line form, exactly as the 176 shipped collectors write it.
            $Lines += '<#'
            $Lines += ".CATEGORY $DeclaredCategory"
            $Lines += '#>'
        }
        $Lines += 'param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)'
        $Lines += "If (`$Task -eq 'Processing') {"
        $Lines += $Body
        $Lines += '}'

        Set-Content -LiteralPath (Join-Path $Dir "$Name.ps1") -Value ($Lines -join "`n") -Encoding UTF8
    }

    function New-FixtureDefinition {
        param([string]$Category, [string]$Name, [string]$ResourceType, [string]$Kind, [switch]$Throws)
        $Dir = Join-Path $script:DefinitionRoot $Category
        $null = New-Item -ItemType Directory -Path $Dir -Force
        $Preamble = if ($Throws) { "throw 'this collector is broken'" } else { '$ResUCount = 1' }
        $Text = @"
@{
    ResourceTypes = @('$ResourceType')
    RowLoopVariable = '1'
    TagLoop = `$null
    Preamble = @'
$Preamble
'@
    Fields = @(
        @{ Name = 'Name'; Expression = '`$1.NAME' }
        @{ Name = 'Kind'; Expression = '`$1.TYPE' }
    )
    Export = @{ WorksheetName = '$Name'; Columns = @('Name', 'Kind'); TagColumns = @() }
}
"@
        Set-Content -LiteralPath (Join-Path $Dir "$Name.psd1") -Value $Text -Encoding utf8
    }

    # Compute: two healthy collectors.
    New-FixtureCollector -Category 'Compute' -Name 'VirtualMachines' -Body @'
    $Resources | Where-Object { $_.TYPE -eq 'vm' } | ForEach-Object {
        [PSCustomObject]@{ Name = $_.NAME; Kind = 'vm' }
    }
'@
    New-FixtureCollector -Category 'Compute' -Name 'Disks' -Body @'
    $Resources | Where-Object { $_.TYPE -eq 'disk' } | ForEach-Object {
        [PSCustomObject]@{ Name = $_.NAME; Kind = 'disk' }
    }
'@

    # Storage: one healthy collector, plus one that throws — the containment case.
    New-FixtureCollector -Category 'Storage' -Name 'Accounts' -Body @'
    $Resources | Where-Object { $_.TYPE -eq 'storage' } | ForEach-Object {
        [PSCustomObject]@{ Name = $_.NAME; Kind = 'storage' }
    }
'@
    New-FixtureCollector -Category 'Storage' -Name 'Exploding' -Body @'
    throw 'this collector is broken'
'@

    # Networking: a collector filed under Networking but declaring itself as Security via
    # the .CATEGORY header — the per-file filtering case.
    New-FixtureCollector -Category 'Networking' -Name 'Firewalls' -DeclaredCategory 'Security' -Body @'
    [PSCustomObject]@{ Name = 'fw1'; Kind = 'firewall' }
'@

    # Empty: a category that legitimately yields nothing. Must NOT produce a cache file.
    New-FixtureCollector -Category 'Empty' -Name 'Nothing' -Body @'
    @()
'@

    New-FixtureDefinition -Category 'Compute' -Name 'VirtualMachines' -ResourceType 'vm' -Kind 'vm'
    New-FixtureDefinition -Category 'Compute' -Name 'Disks' -ResourceType 'disk' -Kind 'disk'
    New-FixtureDefinition -Category 'Storage' -Name 'Accounts' -ResourceType 'storage' -Kind 'storage'
    New-FixtureDefinition -Category 'Storage' -Name 'Exploding' -ResourceType 'storage' -Kind 'broken' -Throws
    New-FixtureDefinition -Category 'Networking' -Name 'Firewalls' -ResourceType 'firewall' -Kind 'firewall'
    New-FixtureDefinition -Category 'Empty' -Name 'Nothing' -ResourceType 'nothing' -Kind 'nothing'

    $script:SampleResources = @(
        [PSCustomObject]@{ NAME = 'vm-a';   TYPE = 'vm' }
        [PSCustomObject]@{ NAME = 'vm-b';   TYPE = 'vm' }
        [PSCustomObject]@{ NAME = 'disk-a'; TYPE = 'disk' }
        [PSCustomObject]@{ NAME = 'sa-a';   TYPE = 'storage' }
        [PSCustomObject]@{ NAME = 'fw-a';   TYPE = 'firewall' }
    )
}

AfterAll {
    if ($script:FixtureRoot -and (Test-Path -LiteralPath $script:FixtureRoot)) {
        Remove-Item -LiteralPath $script:FixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-ScoutCollector — discovery' {

    It 'finds every collector in the tree' {
        $Found = @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot)
        $Found.Count | Should -Be 6
    }

    It 'returns collectors in a deterministic order' {
        # Ordering was previously whatever Get-Job returned, which varied run to run.
        $First  = @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot | ForEach-Object { "$($_.FolderCategory)/$($_.Name)" })
        $Second = @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot | ForEach-Object { "$($_.FolderCategory)/$($_.Name)" })

        $First | Should -Be $Second
        $First[0] | Should -Be 'Compute/Disks'   # sorted by category, then name
    }

    It 'filters at folder level' {
        $Found = @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot -Category 'Compute')
        $Found.Count | Should -Be 2
        @($Found | ForEach-Object { $_.FolderCategory }) | Should -Not -Contain 'Storage'
    }

    It 'honours a .CATEGORY header that differs from the folder' {
        $Firewalls = @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot | Where-Object { $_.Name -eq 'Firewalls' })
        $Firewalls.Count | Should -Be 1
        $Firewalls[0].FolderCategory | Should -Be 'Networking'
        $Firewalls[0].Categories     | Should -Contain 'Security'
    }

    It 'treats All, $null and empty as no filter' {
        @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot -Category 'All').Count | Should -Be 6
        @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot -Category $null).Count | Should -Be 6
        @(Get-ScoutCollector -InventoryRoot $script:FixtureRoot -Category @()).Count   | Should -Be 6
    }

    It 'warns rather than throwing when the root does not exist' {
        $Found = @(Get-ScoutCollector -InventoryRoot (Join-Path $script:FixtureRoot 'no-such-dir') -WarningAction SilentlyContinue)
        $Found.Count | Should -Be 0
    }
}

Describe 'Invoke-ScoutCollector — per-collector failure containment' {

    BeforeAll {
        $script:Context = @{
            ScriptRoot    = $script:FixtureRoot
            Subscriptions = @()
            InTag         = $null
            Resources     = $script:SampleResources
            Retirements   = @()
            Task          = 'Processing'
            File          = $null
            SmaResources  = $null
            TableStyle    = $null
            Unsupported   = @()
        }
    }

    It 'runs a collector and returns its rows' {
        $Collector = Get-ScoutCollector -InventoryRoot $script:FixtureRoot | Where-Object { $_.Name -eq 'VirtualMachines' }
        $Result = Invoke-ScoutCollector -Collector $Collector -Context $script:Context

        $Result.Success | Should -BeTrue
        @($Result.Rows).Count | Should -Be 2
        @($Result.Rows | ForEach-Object { $_.Name }) | Should -Be @('vm-a', 'vm-b')
    }

    It 'contains a throwing collector instead of letting it abort the run' {
        # The whole point of AB#5649: under the old pipeline this either emptied the category
        # silently or took down the batch.
        $Collector = Get-ScoutCollector -InventoryRoot $script:FixtureRoot | Where-Object { $_.Name -eq 'Exploding' }

        { Invoke-ScoutCollector -Collector $Collector -Context $script:Context -WarningAction SilentlyContinue } |
            Should -Not -Throw

        $Result = Invoke-ScoutCollector -Collector $Collector -Context $script:Context -WarningAction SilentlyContinue
        $Result.Success | Should -BeFalse
        $Result.Error.Exception.Message | Should -BeLike '*this collector is broken*'
        @($Result.Rows).Count | Should -Be 0
    }

    It 'records how long the collector took' {
        $Collector = Get-ScoutCollector -InventoryRoot $script:FixtureRoot | Where-Object { $_.Name -eq 'Disks' }
        $Result = Invoke-ScoutCollector -Collector $Collector -Context $script:Context
        $Result.Duration | Should -BeOfType [timespan]
    }
}

Describe 'Write-ScoutCacheFile' {

    BeforeEach {
        $script:CacheDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scout-cache-" + [guid]::NewGuid().ToString('N'))
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:CacheDir) {
            Remove-Item -LiteralPath $script:CacheDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # NB: no angle brackets in the test name — Pester reads <Word> as a -ForEach placeholder
    # and fails the test looking for a variable of that name.
    It 'writes the category JSON file when there are rows' {
        $Result = Write-ScoutCacheFile -Category 'Compute' -CachePath $script:CacheDir -Data @{
            VirtualMachines = @([PSCustomObject]@{ Name = 'vm-a' })
        }

        $Result.Written  | Should -BeTrue
        $Result.RowCount | Should -Be 1
        Test-Path -LiteralPath (Join-Path $script:CacheDir 'Compute.json') | Should -BeTrue
    }

    It 'writes no file at all for an empty category' {
        # The reporting phase reads a missing cache file as "nothing of this kind in the
        # estate". A file full of nulls instead yields empty worksheets.
        $Result = Write-ScoutCacheFile -Category 'Empty' -CachePath $script:CacheDir -Data @{ Nothing = @() }

        $Result.Written | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:CacheDir 'Empty.json') | Should -BeFalse
    }

    It 'round-trips the collector rows' {
        $null = Write-ScoutCacheFile -Category 'Compute' -CachePath $script:CacheDir -Data @{
            VirtualMachines = @([PSCustomObject]@{ Name = 'vm-a'; Kind = 'vm' })
        }

        $Read = Get-Content -LiteralPath (Join-Path $script:CacheDir 'Compute.json') -Raw | ConvertFrom-Json
        $Read.VirtualMachines[0].Name | Should -Be 'vm-a'
    }
}

Describe 'Invoke-ScoutProcessing — the pipeline end to end' {

    BeforeEach {
        $script:RunPath = Join-Path ([System.IO.Path]::GetTempPath()) ("scout-run-" + [guid]::NewGuid().ToString('N'))
        $null = New-Item -Path (Join-Path $script:RunPath 'ReportCache') -ItemType Directory -Force
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:RunPath) {
            Remove-Item -LiteralPath $script:RunPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'runs every collector and caches each non-empty category' {
        $Summary = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue

        $Summary.CollectorCount | Should -Be 6

        $Cache = Join-Path $script:RunPath 'ReportCache'
        Test-Path -LiteralPath (Join-Path $Cache 'Compute.json')    | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $Cache 'Storage.json')    | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $Cache 'Networking.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $Cache 'Empty.json')      | Should -BeFalse
    }

    It 'completes the run despite a broken collector, and reports it' {
        $Summary = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue

        $Summary.FailureCount | Should -Be 1
        $Summary.Failures[0].Collector | Should -Be 'Exploding'

        # …and its healthy sibling in the SAME category still made it to the cache. Under the
        # old pipeline the throw took the whole category with it.
        $Storage = Get-Content -LiteralPath (Join-Path $script:RunPath 'ReportCache/Storage.json') -Raw | ConvertFrom-Json
        $Storage.Accounts[0].Name | Should -Be 'sa-a'
    }

    It 'produces byte-identical cache files across two runs of the same input' {
        # This is the property the old pipeline could not offer: Compute.json came back 5,158
        # bytes on one run and 470 on the next against the same tenant (AB#5629).
        $RunA = Join-Path $script:RunPath 'a'
        $RunB = Join-Path $script:RunPath 'b'
        $null = New-Item -Path (Join-Path $RunA 'ReportCache') -ItemType Directory -Force
        $null = New-Item -Path (Join-Path $RunB 'ReportCache') -ItemType Directory -Force

        $null = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $RunA `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue
        $null = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $RunB `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue

        $FilesA = @(Get-ChildItem -LiteralPath (Join-Path $RunA 'ReportCache') | Sort-Object Name)
        $FilesB = @(Get-ChildItem -LiteralPath (Join-Path $RunB 'ReportCache') | Sort-Object Name)

        @($FilesA | ForEach-Object { $_.Name }) | Should -Be @($FilesB | ForEach-Object { $_.Name })

        foreach ($File in $FilesA) {
            $Hash = (Get-FileHash -LiteralPath $File.FullName).Hash
            $Other = (Get-FileHash -LiteralPath (Join-Path $RunB 'ReportCache' $File.Name)).Hash
            $Hash | Should -Be $Other -Because "$($File.Name) must be identical across runs"
        }
    }

    It 'honours the category filter' {
        $Summary = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -Category 'Compute' -WarningAction SilentlyContinue

        $Summary.CollectorCount | Should -Be 2
        Test-Path -LiteralPath (Join-Path $script:RunPath 'ReportCache/Storage.json') | Should -BeFalse
    }

    It 'starts no background jobs' {
        # The regression this whole feature exists to prevent. If a job appears here, the
        # runspace machinery has crept back in.
        $Before = @(Get-Job).Count

        $null = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue

        @(Get-Job).Count | Should -Be $Before
    }

    It 'returns an empty summary rather than throwing when nothing matches' {
        $Summary = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -Category 'NoSuchCategory' -WarningAction SilentlyContinue

        $Summary.CollectorCount | Should -Be 0
        $Summary.FailureCount   | Should -Be 0
    }

    It 'returns the same property set whether or not any collector matched' {
        # A summary whose shape depends on which branch produced it throws under StrictMode the
        # first time a caller reads the missing property — the exact trap behind the v2.5.3
        # crash wave.
        $Full = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -WarningAction SilentlyContinue
        $Empty = Invoke-ScoutProcessing -Resources $script:SampleResources -DefaultPath $script:RunPath `
            -InventoryRoot $script:FixtureRoot -DefinitionRoot $script:DefinitionRoot -Category 'NoSuchCategory' -WarningAction SilentlyContinue

        $FullProps  = @($Full.PSObject.Properties.Name  | Sort-Object)
        $EmptyProps = @($Empty.PSObject.Properties.Name | Sort-Object)

        $EmptyProps | Should -Be $FullProps
    }
}

Describe 'Start-AZSCExtraJobs — security, policy, advisory and subscriptions, in-process' {

    BeforeAll {
        . (Join-Path $script:RepoRoot 'src/pipeline/Start-ScoutExtraJobs.ps1')

        # Stand-ins for the four real processing functions and the diagram wrapper. Each
        # records what it was handed so the argument-passing can be asserted.
        $script:Seen = @{}

        function Start-AZSCSecCenterJob    { Param($Subscriptions, $Security)
                                             $script:Seen['SecArg'] = $Security; 'sec-rows' }
        function Start-AZSCPolicyJob       { Param($Subscriptions, $PolicySetDef, $PolicyAssign, $PolicyDef)
                                             'pol-rows' }
        function Start-AZSCAdvisoryJob     { Param($Advisories) 'adv-rows' }
        function Start-AZSCSubscriptionJob { Param($Subscriptions, $Resources, $CostData) 'sub-rows' }
        function Invoke-AZSCDrawIOJob      { Param($Subscriptions, $Resources, $Advisories, $DDFile,
                                                   $DiagramCache, $FullEnv, $ResourceContainers,
                                                   $Automation, $AZSCModule) }
    }

    It 'returns all four results as data instead of leaving them in jobs' {
        $Result = Start-AZSCExtraJobs -SkipDiagram $true -SkipAdvisory $false -SkipPolicy $false `
            -SecurityCenter 'on' -Security @('a') -Subscriptions @('s') -Resources @('r') `
            -Advisories @('adv') -PolicyAssign 'pa' -PolicyDef 'pd' -PolicySetDef 'psd' `
            -CostData $null -Automation $false

        $Result.Security      | Should -Be 'sec-rows'
        $Result.Policy        | Should -Be 'pol-rows'
        $Result.Advisory      | Should -Be 'adv-rows'
        $Result.Subscriptions | Should -Be 'sub-rows'
    }

    It 'hands Start-AZSCSecCenterJob the security ROWS, not the on/off switch' {
        # The shipped bug: it was called as -SecurityCenter $SecurityCenter against a parameter
        # block with no such parameter, so PowerShell routed it to $args, $null crossed the job
        # boundary as -Security, and the Security Center sheet was empty in every release.
        $script:Seen = @{}

        $null = Start-AZSCExtraJobs -SkipDiagram $true -SkipAdvisory $true -SkipPolicy $true `
            -SecurityCenter 'on' -Security @('row1', 'row2') -Subscriptions @('s') `
            -Resources @('r') -Automation $false

        $script:Seen['SecArg'] | Should -Be @('row1', 'row2')
        $script:Seen['SecArg'] | Should -Not -Be 'on'
    }

    It 'starts no background jobs' {
        $Before = @(Get-Job).Count

        $null = Start-AZSCExtraJobs -SkipDiagram $true -SkipAdvisory $false -SkipPolicy $false `
            -SecurityCenter 'on' -Security @('a') -Subscriptions @('s') -Resources @('r') `
            -Advisories @('adv') -PolicyAssign 'pa' -PolicyDef 'pd' -PolicySetDef 'psd' `
            -Automation $false

        @(Get-Job).Count | Should -Be $Before
    }

    It 'completes the remaining steps when one of them throws' {
        function Start-AZSCPolicyJob { Param($Subscriptions, $PolicySetDef, $PolicyAssign, $PolicyDef)
                                       throw 'policy processing exploded' }

        $Result = Start-AZSCExtraJobs -SkipDiagram $true -SkipAdvisory $false -SkipPolicy $false `
            -SecurityCenter 'on' -Security @('a') -Subscriptions @('s') -Resources @('r') `
            -Advisories @('adv') -PolicyAssign 'pa' -PolicyDef 'pd' -PolicySetDef 'psd' `
            -Automation $false -WarningAction SilentlyContinue

        $Result.Policy        | Should -BeNullOrEmpty
        $Result.Advisory      | Should -Be 'adv-rows'
        $Result.Subscriptions | Should -Be 'sub-rows'
    }

    It 'skips security processing entirely when SecurityCenter is not requested' {
        $script:Seen = @{}

        $Result = Start-AZSCExtraJobs -SkipDiagram $true -SkipAdvisory $true -SkipPolicy $true `
            -SecurityCenter '' -Security @('a') -Subscriptions @('s') -Resources @('r') `
            -Automation $false

        $Result.Security | Should -BeNullOrEmpty
        $script:Seen.ContainsKey('SecArg') | Should -BeFalse
    }
}

Describe 'Excel reporting only invokes collectors that have data' {

    # Found by a live run, not by the suite. The reporting loop guarded on
    # `@($SmaResources).count -gt 0`, and @($null).Count is 1 — so every collector was invoked
    # in Reporting mode whether or not it had rows. Filtering null cache entries means only
    # collectors with data execute in the reporting phase.

    It 'counts an absent cache entry as zero rows, not one' {
        # The exact PowerShell behaviour behind the bug. @($null) is a one-element array
        # containing $null, so a bare .Count reports 1 for "nothing".
        @($null).Count | Should -Be 1
        @($null).Where({ $null -ne $_ }).Count | Should -Be 0
    }

    It 'Start-AZSCExcelJob filters nulls out of definition-indexed cache rows' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/report/renderers/inventory/Start-AZSCExcelJob.ps1') -Raw
        $Source | Should -Match '\$SmaResources\s*=\s*if\s*\(\$CacheProperty\)\s*\{\s*@\(\$CacheProperty\.Value\)\.Where'
        $Source | Should -Not -Match '\$CacheData\.\$ModName'
    }

    It 'Start-AZSCExcelJob runs only definitions with rows' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/report/renderers/inventory/Start-AZSCExcelJob.ps1') -Raw
        $Source | Should -Match '\$SmaResources\.Count -gt 0'
        $Source | Should -Match 'Invoke-ScoutDeclarativeReporting'
    }

    It 'has no collector using the retired registration contract' {
        # `Modules/` was the imperative collector root and no longer exists. Scanning a path that
        # is gone must not throw -- the whole point of this gate is that its ABSENCE is the pass.
        $Roots = @('src', 'Modules') |
            ForEach-Object { Join-Path $script:RepoRoot $_ } |
            Where-Object { Test-Path -LiteralPath $_ }
        $Users = @($Roots | ForEach-Object {
            Get-ChildItem -LiteralPath $_ -Filter '*.ps1' -Recurse -File |
                Where-Object { (Get-Content $_.FullName -Raw) -match 'Register-AZSCInventoryModule' }
        })

        $Users | Should -BeNullOrEmpty
    }
}

Describe 'Every report exporter tolerates a cache with no entry for a collector' {

    # The old pipeline created a hashtable key for EVERY module file, including ones that
    # produced nothing, so `$CacheData.$ModName` always resolved. The deterministic pipeline
    # writes keys only for collectors it actually ran — so a skipped or filtered collector
    # legitimately has no key, and an unguarded read throws under StrictMode:
    #     The property 'IdentityProviders' cannot be found on this object.
    # All four exporters carried the identical unguarded line. Found by a live run.

    $ExporterFiles = @(
        'src/report/renderers/inventory/Export-AZSCJsonReport.ps1'
        'src/report/renderers/inventory/Export-AZSCMarkdownReport.ps1'
        'src/report/renderers/inventory/Export-AZSCAsciiDocReport.ps1'
        'src/report/renderers/inventory/Export-AZSCPowerBIReport.ps1'
    )

    It '<_> checks the property exists before reading it' -ForEach $ExporterFiles {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot $_) -Raw

        $Source | Should -Not -Match '(?m)^\s*\$ModResources\s*=\s*\$CacheData\.\$ModName\s*$'
        # The original guard checked the dynamic name against .Properties.Name.  Manifest-backed
        # exporters use the equivalent indexer form so their cache key comes from the definition.
        $Source | Should -Match 'PSObject\.Properties(?:\.Name -contains \$ModName|\[\$Section\.CacheKey\])'
    }

    It 'reading a missing property on a PSCustomObject throws under StrictMode' {
        # The behaviour the guard exists for, pinned so nobody "simplifies" it back.
        $Obj = [PSCustomObject]@{ Present = 1 }
        $Name = 'Absent'
        { Set-StrictMode -Version Latest; $null = $Obj.$Name } |
            Should -Throw -ExpectedMessage "*cannot be found on this object*"
    }

    It 'the guarded form returns $null instead of throwing' {
        Set-StrictMode -Version Latest
        $CacheData = [PSCustomObject]@{ Present = 1 }
        $ModName = 'Absent'
        $ModResources = if ($CacheData -and $CacheData.PSObject.Properties.Name -contains $ModName) { $CacheData.$ModName } else { $null }
        $ModResources | Should -BeNullOrEmpty
    }
}

Describe 'Start-AZSCDiagramJob builds the diagram lookup in-process' {

    # AB#5649 — this was 290 lines: two copies of the same 27-type filter behind an if/else on
    # $Automation, the non-automation copy using 27 separate [PowerShell]::Create() runspaces
    # to perform 27 array filters, plus its own instance of the $Job.Runspace.IsCompleted
    # no-op wait. It is now one bucket-sorting pass over $Resources.

    BeforeAll {
        . (Join-Path $script:RepoRoot 'src/pipeline/diagram/Start-ScoutDiagramJob.ps1')

        $script:DiagramResources = @(
            [PSCustomObject]@{ Type = 'microsoft.network/virtualnetworks'; name = 'vnet1' }
            [PSCustomObject]@{ Type = 'Microsoft.Network/VirtualNetworks'; name = 'vnet2' }
            [PSCustomObject]@{ Type = 'microsoft.compute/virtualmachines'; name = 'vm1' }
            [PSCustomObject]@{ Type = 'Microsoft.Compute/virtualMachineScaleSets'; name = 'vmss1' }
            [PSCustomObject]@{ Type = 'microsoft.storage/storageaccounts'; name = 'not-a-diagram-type' }
        )
    }

    It 'returns all 27 keys the diagram builders index by' {
        $V = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $false
        @($V.Keys).Count | Should -Be 27
        $V.Keys | Should -Contain 'AZVNETs'
        $V.Keys | Should -Contain 'AppGtw'
        $V.Keys | Should -Contain 'ANF'
    }

    It 'matches resource types case-insensitively, as -eq did' {
        $V = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $false
        @($V['AZVNETs']).Count | Should -Be 2
        $V['VMSS'].name | Should -Be 'vmss1'
    }

    It 'returns $null for a type with no resources, NOT an empty collection' {
        # Load-bearing. Under StrictMode, member enumeration over an EMPTY collection throws
        # "property cannot be found", while the same read over $null is safe — the AB#5633
        # crash class. Handing the diagram builders empty lists would walk straight back into it.
        $V = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $false
        $V['ANF'] | Should -BeNullOrEmpty
        $null -eq $V['ANF'] | Should -BeTrue
    }

    It 'starts no background jobs and creates no runspaces' {
        $Before = @(Get-Job).Count
        $null = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $false
        $null = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $true
        @(Get-Job).Count | Should -Be $Before
    }

    It 'gives automation and non-automation runs identical output' {
        # They were two hand-maintained copies of the same mapping; that is exactly how the
        # two collector-discovery implementations drifted apart.
        $A = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $false
        $B = Start-AZSCDiagramJob -Resources $script:DiagramResources -Automation $true

        ($A.Keys | Sort-Object) | Should -Be ($B.Keys | Sort-Object)
        foreach ($K in $A.Keys) {
            @($A[$K]).Count | Should -Be @($B[$K]).Count -Because "key $K must match across modes"
        }
    }

    It 'tolerates an empty and a null resource set' {
        { Start-AZSCDiagramJob -Resources @() -Automation $false }   | Should -Not -Throw
        { Start-AZSCDiagramJob -Resources $null -Automation $false } | Should -Not -Throw
    }

    It 'no longer contains the runspace fan-out or the no-op wait' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/pipeline/diagram/Start-ScoutDiagramJob.ps1') -Raw
        $Tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$Tokens, [ref]$null)
        $Code = ($Tokens | Where-Object { $_.Kind -ne 'Comment' } | ForEach-Object { $_.Text }) -join ' '

        $Code | Should -Not -Match 'Start-Job'
        $Code | Should -Not -Match 'Start-ThreadJob'
        $Code | Should -Not -Match 'BeginInvoke'
        $Code | Should -Not -Match 'Runspace'
    }

    It 'Start-AZSCDrawIODiagram takes the lookup as a value instead of harvesting a job' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/pipeline/diagram/Start-ScoutDrawIoDiagram.ps1') -Raw
        $Tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$Tokens, [ref]$null)
        $Code = ($Tokens | Where-Object { $_.Kind -ne 'Comment' } | ForEach-Object { $_.Text }) -join ' '

        $Code | Should -Match '\$Job = Start-AZSCDiagramJob'
        $Code | Should -Not -Match "DiagramVariables"
    }
}

Describe 'The processing path no longer depends on background jobs' {

    It 'Start-AZSCProcessOrchestration calls the deterministic pipeline' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/Start-AZTIProcessOrchestration.ps1') -Raw
        $Source | Should -Match 'Invoke-ScoutProcessing'
    }

    It 'Start-AZSCProcessOrchestration no longer creates, waits on or harvests jobs' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/Start-AZTIProcessOrchestration.ps1') -Raw

        # Comments explaining the history are allowed; executable calls are not.
        $Code = ($Source -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"

        $Code | Should -Not -Match 'Start-AZSCProcessJob'
        $Code | Should -Not -Match 'Start-AZSCAutProcessJob'
        $Code | Should -Not -Match 'Wait-AZSCJob'
        $Code | Should -Not -Match 'Build-AZSCCacheFiles'
        $Code | Should -Not -Match 'Get-Job'
    }
}
