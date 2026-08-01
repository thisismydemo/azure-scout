#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Regression locks for Epic AB#6741 — service coverage across Microsoft's eighteen categories.

    Every assertion here corresponds to something that WAS wrong and could silently become wrong
    again. None of them re-test what the golden or schema suites already cover.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:DefinitionRoot = Join-Path $script:RepoRoot 'manifests/collectors'
    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollectorDefinition.ps1')

    $script:Spec = Import-PowerShellDataFile -Path (Join-Path $script:RepoRoot 'manifests/specs/service-collectors.psd1')

    # Microsoft's eighteen published service categories (portal -> All services, captured
    # 2026-07-31 and recorded in pmo/audits/AZURE-SCOUT-AUDIT.md §2).
    $script:PortalCategories = @(
        'AI', 'Analytics', 'Compute', 'Containers', 'Databases', 'DevOps', 'General', 'Hybrid',
        'Identity', 'Integration', 'IoT', 'Management', 'Migration', 'Monitor', 'Networking',
        'Security', 'Storage', 'Web'
    )
}

Describe 'Category taxonomy (AB#6741)' {

    It 'has a collector folder for every one of Microsoft''s eighteen categories' {
        $Folders = @(Get-ChildItem -LiteralPath $script:DefinitionRoot -Directory | ForEach-Object { $_.Name })
        foreach ($Category in $script:PortalCategories) {
            $Folders | Should -Contain $Category -Because "Microsoft publishes '$Category' as a service category and the Epic requires Scout to model all eighteen"
        }
    }

    It 'has no collector folder that is not one of the eighteen' {
        $Folders = @(Get-ChildItem -LiteralPath $script:DefinitionRoot -Directory | ForEach-Object { $_.Name })
        foreach ($Folder in $Folders) {
            $script:PortalCategories | Should -Contain $Folder -Because 'a folder outside the published taxonomy is a category Scout invented'
        }
    }

    It 'offers exactly those categories on -Category, plus All' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/Invoke-AzureScout.ps1') -Raw
        $Match = [regex]::Match($Source, "\[ValidateSet\(('All'[^\)]*)\)\]\s*\r?\n\s*\[string\[\]\]\`$Category")
        $Match.Success | Should -BeTrue -Because 'the -Category ValidateSet must be findable to be checked'
        $Values = @([regex]::Matches($Match.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        ($Values | Sort-Object) | Should -Be (@('All') + $script:PortalCategories | Sort-Object)
    }

    It 'offers the same eighteen in the wizard as on the command line' {
        # A wizard that offers a category -Invoke-AzureScout would reject is a dead end the user
        # only discovers after answering every other question.
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/Start-AZSCWizard.ps1') -Raw
        $Match = [regex]::Match($Source, '\$inventoryCategories = @\(([^\)]*)\)')
        $Match.Success | Should -BeTrue
        $Values = @([regex]::Matches($Match.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        ($Values | Sort-Object) | Should -Be ($script:PortalCategories | Sort-Object)
    }

    It 'no longer aliases DevOps or Migration onto Management' {
        # Both are real categories now. Leaving the aliases in place would route `-Category Migration`
        # to the Management collectors -- the wrong data, with no error.
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/Invoke-AzureScout.ps1') -Raw
        $Map = [regex]::Match($Source, '\$_categoryAliasMap = @\{(.*?)\n    \}', 'Singleline')
        $Map.Success | Should -BeTrue
        $Map.Groups[1].Value | Should -Not -Match "'DevOps'\s*="
        $Map.Groups[1].Value | Should -Not -Match "'Migration'\s*="
    }
}

Describe 'Logic Apps are collected (AB#6836)' {

    It 'does not exclude microsoft.logic/workflows from the resources query' {
        # This exclusion made Integration -- Scout's thinnest category -- miss one of the most
        # common resources in Azure, with no way to opt back in.
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/collect/Get-ScoutRawInventory.ps1') -Raw
        $Clause = [regex]::Match($Source, '\$excludedTypesClause = "([^"]*)"')
        $Clause.Success | Should -BeTrue -Because 'the exclusion clause must be findable to be checked'
        $Clause.Groups[1].Value | Should -Not -Match 'microsoft\.logic/workflows'
    }

    It 'has a collector that consumes them' {
        $Definition = Get-ScoutCollectorDefinition -Path (Join-Path $script:DefinitionRoot 'Integration/LogicApps.psd1')
        @($Definition.ResourceTypes) | Should -Contain 'microsoft.logic/workflows'
    }
}

Describe 'Generated collectors match their spec (AB#6741)' {

    It 'has a definition file for every spec entry' {
        foreach ($Collector in @($script:Spec.Collectors)) {
            $Path = Join-Path $script:DefinitionRoot "$($Collector.Category)/$($Collector.Name).psd1"
            Test-Path -LiteralPath $Path | Should -BeTrue -Because "the spec declares $($Collector.Category)/$($Collector.Name)"
        }
    }

    It 'declares in each definition exactly the resource types the spec names' {
        # The spec is the reviewable record of WHICH Azure services Scout claims to collect, and
        # every string in it was taken from the ARM template reference. A definition that drifted
        # from it -- by a hand-patch the generator would overwrite, or a typo -- would quietly
        # change the estate Scout looks at. AB#6444 found three fabricated type strings shipped
        # this way, so the two are pinned together.
        foreach ($Collector in @($script:Spec.Collectors)) {
            $Definition = Get-ScoutCollectorDefinition -Path (Join-Path $script:DefinitionRoot "$($Collector.Category)/$($Collector.Name).psd1")
            @($Definition.ResourceTypes) | Should -Be @($Collector.ResourceTypes) -Because "$($Collector.Category)/$($Collector.Name) must collect what the spec says it collects"
        }
    }

    It 'declares only lower-case resource types, as Resource Graph returns them' {
        # ARG's `type` column is lower-case. A mixed-case string in a SinglePass `-contains` test
        # never matches, and the collector returns an empty worksheet with no error.
        foreach ($Collector in @($script:Spec.Collectors)) {
            foreach ($Type in @($Collector.ResourceTypes)) {
                if ($Type -like 'AZSC/*') { continue }   # synthetic Scout envelopes keep their casing
                $Type | Should -BeExactly ([string]$Type).ToLowerInvariant() -Because "$($Collector.Category)/$($Collector.Name) matches against ARG's lower-case type column"
            }
        }
    }
}

Describe 'Cross-resource joins (AB#6835)' {

    BeforeAll {
        . (Join-Path $script:RepoRoot 'src/assess/engine/Resolve-JsonPath.ps1')
        . (Join-Path $script:RepoRoot 'src/assess/engine/Resolve-RuleJoin.ps1')

        $script:JoinCollect = [pscustomobject]@{
            compute = [pscustomobject]@{
                virtualMachines = @(
                    [pscustomobject]@{ id = '/subscriptions/s1/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-protected'; name = 'vm-protected' }
                    [pscustomobject]@{ id = '/subscriptions/s1/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-orphan';    name = 'vm-orphan' }
                )
            }
            management = [pscustomobject]@{
                backupProtectedItems = @(
                    # Deliberately different casing on resourceGroups: ARM ids are case-insensitive
                    # and the two providers disagree in practice. A case-sensitive join would report
                    # BOTH VMs as unprotected.
                    [pscustomobject]@{ name = 'pi-1'; sourceResourceId = '/subscriptions/s1/resourcegroups/rg/providers/Microsoft.Compute/virtualMachines/VM-PROTECTED' }
                    [pscustomobject]@{ name = 'pi-dangling'; sourceResourceId = '/subscriptions/s1/resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm-deleted' }
                    [pscustomobject]@{ name = 'pi-nokey'; sourceResourceId = '' }
                )
            }
        }

        $script:LeftOnlyRule = @{
            id = 'TEST-01'
            join = @{
                left = '$.compute.virtualMachines[*]'; leftKey = 'id'
                right = '$.management.backupProtectedItems[*]'; rightKey = 'sourceResourceId'
                mode = 'leftOnly'; leftLabel = 'virtual machine'; rightLabel = 'backup protected item'
            }
        }
    }

    It 'reports only the left rows with no match' {
        $Evidence = @(Resolve-RuleJoin -Rule $script:LeftOnlyRule -Collect $script:JoinCollect)
        $Evidence.Count | Should -Be 1
        $Evidence[0].Left.name | Should -Be 'vm-orphan'
    }

    It 'matches ARM ids case-insensitively' {
        # The guard that makes the previous assertion meaningful: if this broke, vm-protected would
        # also be reported and the count would be 2, not 1.
        $Evidence = @(Resolve-RuleJoin -Rule $script:LeftOnlyRule -Collect $script:JoinCollect)
        @($Evidence | Where-Object { $_.Left.name -eq 'vm-protected' }).Count | Should -Be 0
    }

    It 'names both sides of the relationship on every finding' {
        $Evidence = @(Resolve-RuleJoin -Rule $script:LeftOnlyRule -Collect $script:JoinCollect)
        $Evidence[0].LeftLabel  | Should -Be 'virtual machine'
        $Evidence[0].RightLabel | Should -Be 'backup protected item'
        $Evidence[0].PSObject.Properties.Name | Should -Contain 'Right'
    }

    It 'reports dangling references in rightOnly mode, skipping rows with no key' {
        $Rule = @{ id = 'TEST-02'; join = @{
            left = '$.compute.virtualMachines[*]'; leftKey = 'id'
            right = '$.management.backupProtectedItems[*]'; rightKey = 'sourceResourceId'
            mode = 'rightOnly' } }
        $Evidence = @(Resolve-RuleJoin -Rule $Rule -Collect $script:JoinCollect)
        # pi-dangling only. pi-1 matches; pi-nokey has no key and is unjoinable, not unmatched --
        # counting it would manufacture a finding out of an incomplete projection.
        $Evidence.Count | Should -Be 1
        $Evidence[0].Right.name | Should -Be 'pi-dangling'
    }

    It 'pairs both resources in leftMatched mode' {
        $Rule = @{ id = 'TEST-03'; join = @{
            left = '$.compute.virtualMachines[*]'; leftKey = 'id'
            right = '$.management.backupProtectedItems[*]'; rightKey = 'sourceResourceId'
            mode = 'leftMatched' } }
        $Evidence = @(Resolve-RuleJoin -Rule $Rule -Collect $script:JoinCollect)
        $Evidence.Count | Should -Be 1
        $Evidence[0].Left.name  | Should -Be 'vm-protected'
        $Evidence[0].Right.name | Should -Be 'pi-1'
    }

    It 'rejects a join block missing a required key rather than returning nothing' {
        # Silently returning zero rows would read as "countEquals 0 -> Pass" for every rule with a
        # typo in its join block.
        $Rule = @{ id = 'TEST-04'; join = @{ left = '$.compute.virtualMachines[*]'; leftKey = 'id' } }
        { Resolve-RuleJoin -Rule $Rule -Collect $script:JoinCollect } | Should -Throw '*right*'
    }

    It 'ships at least four cross-resource rules, each with a join block' {
        $Yaml = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/assess/rules/xr.crossresource.yaml') -Raw
        $Ids = @([regex]::Matches($Yaml, '(?m)^\s*-\s+id:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
        $Ids.Count | Should -BeGreaterOrEqual 4
        @([regex]::Matches($Yaml, '(?m)^\s{4}join:')).Count | Should -Be $Ids.Count -Because 'a cross-resource rule without a join is a single-dataset rule in the wrong file'
    }
}

Describe 'SMART is gated on real data (AB#6832)' {

    BeforeAll {
        . (Join-Path $script:RepoRoot 'src/assess/engine/Resolve-JsonPath.ps1')
        . (Join-Path $script:RepoRoot 'src/assess/engine/Resolve-RuleJoin.ps1')
        . (Join-Path $script:RepoRoot 'src/assess/engine/Invoke-Rule.ps1')
        . (Join-Path $script:RepoRoot 'src/assess/Invoke-Assessment.ps1')

        $script:SmartSet = [pscustomobject]@{
            Area = 'Migration readiness (SMART)'; Framework = 'SMART'; Weight = 1.0
            Requires = @(@{ path = '$.domains.migration.migrateProjects[*]'; description = 'Azure Migrate projects' })
            Rules = @(
                @{ id = 'SMART-C1'; title = 'A project exists'; severity = 'high'
                   query = '$.domains.migration.migrateProjects[*]'; assert = @{ type = 'countGreaterThan'; value = 0 }
                   remediation = 'x'; manual = $false }
            )
        }
    }

    It 'reports Unknown, not Pass, when the Migration collectors returned nothing' {
        $Empty = [pscustomobject]@{ domains = [pscustomobject]@{ migration = [pscustomobject]@{ migrateProjects = @() } } }
        $Findings = @(Invoke-Assessment -Collect $Empty -RuleSet @($script:SmartSet) -Assessment 'SMART')
        $Findings.Count | Should -Be 1
        $Findings[0].Status | Should -Be 'Unknown'
        $Findings[0].Remediation | Should -Match 'Azure Migrate projects'
    }

    It 'scores normally once the data is there' {
        # Without this the previous assertion would pass just as well against a set that never
        # scores anything.
        $Populated = [pscustomobject]@{ domains = [pscustomobject]@{ migration = [pscustomobject]@{
            migrateProjects = @([pscustomobject]@{ id = '/subscriptions/s1/x'; name = 'proj-1' }) } } }
        $Findings = @(Invoke-Assessment -Collect $Populated -RuleSet @($script:SmartSet) -Assessment 'SMART')
        $Findings[0].Status | Should -Be 'Pass'
    }

    It 'cites an enumerated SMART item in every rule id and remediation' {
        $Yaml = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/assess/rules/smart.migration.yaml') -Raw
        $Ids = @([regex]::Matches($Yaml, '(?m)^\s*-\s+id:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value })
        $Ids.Count | Should -BeGreaterThan 0
        $Enumeration = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'docs/frameworks/smart-question-set.md') -Raw
        foreach ($Id in $Ids) {
            $Id | Should -Match '^SMART-[A-F]\d+$'
            # The id must exist in the enumeration, not just look like one. This is the check that
            # stops a rule being written against an item nobody enumerated -- the defect the audit's
            # DQ12 names, and how waf.storage.yaml came to score a WAF pillar that does not exist.
            $Enumeration | Should -Match ([regex]::Escape($Id)) -Because "rule $Id must cite an item that docs/frameworks/smart-question-set.md actually enumerates"
        }
    }
}
