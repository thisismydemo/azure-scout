#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Pester tests for src/report/renderers/Export-React.ps1 — the self-contained
    interactive HTML report renderer (ADO Story AB#5053). Renders against a
    synthetic scored Findings set (built the same way
    tests/Assessment.Engine.Tests.ps1 does, via Get-Score) plus the repo's
    existing tests/datadump/sample-collect.json fixture for -Collect. No Azure
    connection, no external network access required.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . "$script:Root/src/assess/engine/Get-Score.ps1"
    . "$script:Root/src/report/renderers/Export-React.ps1"

    function New-ReactTestFinding {
        param($Id, $Framework, $Area, $Status, $Severity = 'medium', $Weight = 1.0)
        [pscustomobject]@{
            Id = $Id; Title = "$Id title"; Framework = $Framework; Area = $Area; Severity = $Severity
            Status = $Status; EvidenceCount = 2; Evidence = @(); Remediation = "Remediate $Id."
            Manual = ($Status -eq 'Manual'); AreaWeight = $Weight
        }
    }

    $script:Findings = @(
        (New-ReactTestFinding 'net-1' 'CAF' 'Networking' 'Pass' 'low')
        (New-ReactTestFinding 'net-2' 'CAF' 'Networking' 'Fail' 'high')
        (New-ReactTestFinding 'sec-1' 'WAF' 'Security' 'Partial' 'medium')
        (New-ReactTestFinding 'sec-2' 'WAF' 'Security' 'Manual')
        (New-ReactTestFinding 'sec-3' 'WAF' 'Security' 'Unknown')
    )
    $script:Scored = Get-Score -Findings $script:Findings

    # Mirrors the REAL shape Invoke-ScoutAssessment passes to Export-Report/
    # Export-React: the canonical collect.json object itself (networking/
    # compute/governance/tags at the top level), with `_meta` sitting
    # alongside those keys — not wrapped under a `.raw` property.
    $script:CollectPath = Join-Path $script:Root 'tests' 'datadump' 'sample-collect.json'
    $script:Collect = Get-Content $script:CollectPath -Raw | ConvertFrom-Json -Depth 100
    $script:Collect | Add-Member -NotePropertyName _meta -NotePropertyValue ([pscustomobject]@{
            scope = 'ArmOnly'; managementGroupId = 'mg-test-01'; generatedOn = (Get-Date).ToString('o')
        }) -Force

    $script:OutDir = Join-Path $script:Root 'tests' 'test-output' 'react'
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Export-React — without drift' {
    BeforeAll {
        $script:ReportPath = Export-React -Findings $script:Scored -Collect $script:Collect -OutputPath $script:OutDir
        $script:Html = Get-Content $script:ReportPath -Raw
    }

    It 'writes report-react.html into -OutputPath and returns its path' {
        $script:ReportPath | Should -Exist
        (Split-Path $script:ReportPath -Leaf) | Should -Be 'report-react.html'
    }

    It 'embeds the findings JSON blob under window.__SCOUT_DATA__' {
        $script:Html | Should -Match '__SCOUT_DATA__'
        $script:Html | Should -Match 'GeneratedOn'
        $script:Html | Should -Match 'net-1'
    }

    It 'embedded data is valid, parseable JSON containing every synthetic finding Id' {
        $match = [regex]::Match($script:Html, 'window\.__SCOUT_DATA__ = (\{.*?\});(?=\s*</script>)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $match.Success | Should -BeTrue
        $embedded = $match.Groups[1].Value | ConvertFrom-Json -Depth 100
        $embedded.Findings.Findings.Count | Should -Be 5
        ($embedded.Findings.Findings.Id | Sort-Object) | Should -Be (@('net-1', 'net-2', 'sec-1', 'sec-2', 'sec-3') | Sort-Object)
        $embedded.Meta.Scope | Should -Be 'ArmOnly'
        $embedded.Meta.ManagementGroupId | Should -Be 'mg-test-01'
        $embedded.Drift | Should -BeNullOrEmpty
    }

    It 'has no external CDN / network references (self-contained offline artifact)' {
        $script:Html | Should -Not -Match 'src\s*=\s*"http'
        $script:Html | Should -Not -Match "src\s*=\s*'http"
        $script:Html | Should -Not -Match 'href\s*=\s*"http'
        $script:Html | Should -Not -Match "href\s*=\s*'http"
        $script:Html | Should -Not -Match 'cdn\.'
    }

    It 'is a single self-contained file (inline styles and scripts, no linked css or js)' {
        $script:Html | Should -Match '<style>'
        $script:Html | Should -Match '<script>'
        $script:Html | Should -Not -Match '<link[^>]+rel="stylesheet"'
        $script:Html | Should -Not -Match '<script[^>]+src='
    }

    It 'embeds a null Drift so the client-side "if(DRIFT)" guard skips the tab' {
        $script:Html | Should -Match '"Drift":\s*null'
    }
}

Describe 'Export-React — with drift embedded' {
    BeforeAll {
        $script:DriftObject = [pscustomobject]@{
            RunId         = 'run2'
            GeneratedOn   = (Get-Date).ToString('o')
            IsBaseline    = $false
            PreviousRunId = 'run1'
            OverallScore  = 67
            PreviousScore = 50
            ScoreDelta    = 17
            Summary       = [pscustomobject]@{ New = 1; Resolved = 1; Regressed = 0; Unchanged = 2; Removed = 0 }
            Findings      = @(
                [pscustomobject]@{ Id = 'net-2'; Title = 'net-2 title'; Framework = 'CAF'; Area = 'Networking'; PreviousStatus = 'Fail'; CurrentStatus = 'Pass'; Drift = 'Resolved' }
            )
        }
        $script:ReportPath = Export-React -Findings $script:Scored -Collect $script:Collect -OutputPath $script:OutDir -Drift $script:DriftObject
        $script:Html = Get-Content $script:ReportPath -Raw
    }

    It 'embeds the drift object and includes the client-side Drift tab capability' {
        # The Drift tab is only pushed into the DOM at runtime by client JS (no
        # headless browser here to execute it), so assert on the two things a
        # static read of the file can actually prove: (1) the template's JS
        # conditionally renders a drift tab whenever DRIFT is truthy, and
        # (2) this run's embedded payload actually carries a truthy Drift
        # object with the expected fields serialized in — together those
        # guarantee a browser opening this file renders the tab.
        $script:Html | Should -Match "tabs\.push\(\['drift'"
        $script:Html | Should -Match '"PreviousRunId":\s*"run1"'
        $script:Html | Should -Match '"RunId":\s*"run2"'
    }

    It 'embedded Drift payload parses with the expected summary counts' {
        $match = [regex]::Match($script:Html, 'window\.__SCOUT_DATA__ = (\{.*?\});(?=\s*</script>)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $embedded = $match.Groups[1].Value | ConvertFrom-Json -Depth 100
        $embedded.Drift | Should -Not -BeNullOrEmpty
        $embedded.Drift.IsBaseline | Should -BeFalse
        $embedded.Drift.Summary.Resolved | Should -Be 1
    }

    It 'remains free of external CDN references with drift embedded' {
        $script:Html | Should -Not -Match 'src\s*=\s*"http'
        $script:Html | Should -Not -Match 'href\s*=\s*"http'
    }
}

<#
    Environment-visuals feature trio (AB#376-378, 380, 386-393): interactive VNet
    topology + click-to-details + reset/fit, MG-hierarchy diagram, per-section
    search/filter, clickable rows + side panel, inventory KPI cards, Azure
    Firewall drill-down, Governance section (budgets/locks/tag chips), policy
    enforcement badge, scope tooltips. sample-collect.json already carries real
    networking/compute/governance/tags data, so -Collect is passed as-is (the
    canonical collect.json shape, mirroring Invoke-ScoutAssessment) to prove the
    renderer reads it out correctly. There is no headless browser in this test
    run, so — matching the existing Drift-tab test's approach above — assertions
    check (1) the embedded JSON payload actually carries the expected data, and
    (2) the template's client-side JS source contains the conditional
    render/hide logic that would act on it in a real browser. The client-side
    render *logic itself* (topology node/edge construction, MG-tree building,
    truncation, enforcement-badge mapping, dual-shape property reads) is
    exercised for real in a plain Node harness — see the PR/session notes for
    the exact commands run.
#>
Describe 'Export-React — environment visuals (AB#376-378, 380, 386-393)' {
    BeforeAll {
        $script:EnvReportPath = Export-React -Findings $script:Scored -Collect $script:Collect -OutputPath $script:OutDir
        $script:EnvHtml = Get-Content $script:EnvReportPath -Raw
        $envMatch = [regex]::Match($script:EnvHtml, 'window\.__SCOUT_DATA__ = (\{.*?\});(?=\s*</script>)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $envMatch.Success | Should -BeTrue
        $script:EnvEmbedded = $envMatch.Groups[1].Value | ConvertFrom-Json -Depth 100
    }

    It 'embeds the Networking slice from Collect (AB#376 topology data source)' {
        $script:EnvEmbedded.Networking.VirtualNetworks.Count | Should -Be 3
        ($script:EnvEmbedded.Networking.VirtualNetworks.name | Sort-Object) | Should -Be (@('vnet-hub', 'vnet-isolated', 'vnet-spoke1') | Sort-Object)
        $script:EnvEmbedded.Networking.Subnets.Count | Should -Be 3
        $script:EnvEmbedded.Networking.AzureFirewalls[0].name | Should -Be 'afw-hub'
    }

    It 'embeds the Compute and Governance slices from Collect (AB#380/391 data sources)' {
        $script:EnvEmbedded.Compute.VirtualMachines.Count | Should -Be 3
        $script:EnvEmbedded.Governance.ManagementGroups.Count | Should -Be 3
        $script:EnvEmbedded.Governance.PolicyAssignments.Count | Should -Be 3
        $script:EnvEmbedded.Governance.Budgets.Count | Should -Be 2
        $script:EnvEmbedded.Governance.ResourceLocks.Count | Should -Be 1
        $script:EnvEmbedded.Tags.Count | Should -Be 2
    }

    It 'embeds the raw policy-assignment enforcementMode values the client-side badge maps (AB#392)' {
        $modes = $script:EnvEmbedded.Governance.PolicyAssignments.properties.enforcementMode
        $modes | Should -Contain 'Default'
        $modes | Should -Contain 'DoNotEnforce'
    }

    It 'the template JS defines the topology/governance renderers and their supporting helpers' {
        $script:EnvHtml | Should -Match 'function buildTopology\(\)'
        $script:EnvHtml | Should -Match 'function renderTopology\(\)'
        $script:EnvHtml | Should -Match 'function renderGovernance\(\)'
        $script:EnvHtml | Should -Match 'function buildMgTree\(mgs\)'
        $script:EnvHtml | Should -Match 'truncateMiddle = function\('
        $script:EnvHtml | Should -Match 'enforcementBadge = function\('
        $script:EnvHtml | Should -Match 'function openPanel\('
    }

    It 'Topology/Governance tabs are only pushed when hasNetworkingData/hasGovernanceData are true (AB#376/380 graceful hide)' {
        $script:EnvHtml | Should -Match "if\(hasNetworkingData\)\{\s*tabs\.push\(\['topology'"
        $script:EnvHtml | Should -Match "if\(hasGovernanceData\)\{\s*tabs\.push\(\['governance'"
    }

    It 'the Firewall drill-down honestly notes that rule-collection data is not collected (AB#390 graceful degrade)' {
        $script:EnvHtml | Should -Match 'Rule-collection data \(Microsoft\.Network/firewallPolicies\) is not collected'
    }

    It 'the VNet topology honestly notes its peering/VM-grouping are aggregates, not fabricated precise edges (AB#376)' {
        $script:EnvHtml | Should -Match 'Peered VNet identities are not collected'
        $script:EnvHtml | Should -Match 'VM-to-subnet mapping'
    }

    It 'the topology viewport wires reset/fit/pan/zoom controls (AB#378)' {
        $script:EnvHtml | Should -Match 'id="topo-reset"'
        $script:EnvHtml | Should -Match 'id="topo-fit"'
        $script:EnvHtml | Should -Match "addEventListener\('wheel'"
        $script:EnvHtml | Should -Match "addEventListener\('mousedown'"
    }

    It 'Manual review and Governance sub-tables each get their own search input (AB#386)' {
        $script:EnvHtml | Should -Match 'id="manual-search"'
        $script:EnvHtml | Should -Match 'id="gov-policy-search"'
        $script:EnvHtml | Should -Match 'id="gov-budgets-search"'
        $script:EnvHtml | Should -Match 'id="gov-locks-search"'
    }

    It 'Findings/Gaps/Manual/Governance rows are marked clickable for the side panel (AB#387)' {
        $script:EnvHtml | Should -Match 'class="clickable-row"'
        ([regex]::Matches($script:EnvHtml, 'clickable-row')).Count | Should -BeGreaterThan 3
    }

    It 'the side panel and overlay markup exist exactly once (AB#377/387)' {
        ([regex]::Matches($script:EnvHtml, 'id="side-panel"')).Count | Should -Be 1
        ([regex]::Matches($script:EnvHtml, 'id="panel-overlay"')).Count | Should -Be 1
    }

    It 'stays a single self-contained offline file with the new sections added' {
        $script:EnvHtml | Should -Not -Match 'src\s*=\s*"http'
        $script:EnvHtml | Should -Not -Match 'href\s*=\s*"http'
        $script:EnvHtml | Should -Not -Match 'cdn\.'
        $script:EnvHtml | Should -Not -Match '<script[^>]+src='
    }
}

Describe 'Export-React — environment visuals degrade gracefully when uncollected (AB#376/380 hide-not-error)' {
    It 'does not throw and embeds null Networking/Governance/Tags when Collect never carried them' {
        $bareCollect = [pscustomobject]@{
            _meta = [pscustomobject]@{ scope = 'EntraOnly'; managementGroupId = $null; generatedOn = (Get-Date).ToString('o') }
        }
        { $script:BareReportPath = Export-React -Findings $script:Scored -Collect $bareCollect -OutputPath $script:OutDir } | Should -Not -Throw
        $bareHtml = Get-Content $script:BareReportPath -Raw
        $match = [regex]::Match($bareHtml, 'window\.__SCOUT_DATA__ = (\{.*?\});(?=\s*</script>)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $embedded = $match.Groups[1].Value | ConvertFrom-Json -Depth 100
        $embedded.Networking.VirtualNetworks | Should -BeNullOrEmpty
        $embedded.Governance.ManagementGroups | Should -BeNullOrEmpty
        $embedded.Tags | Should -BeNullOrEmpty
    }

    It 'does not throw when Collect is $null (CollectOnly-style caller with nothing to embed yet)' {
        { Export-React -Findings $script:Scored -Collect $null -OutputPath $script:OutDir } | Should -Not -Throw
    }
}
