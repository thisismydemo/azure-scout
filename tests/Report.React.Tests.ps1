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

    $script:CollectPath = Join-Path $script:Root 'tests' 'datadump' 'sample-collect.json'
    $script:Collect = [pscustomobject]@{
        _meta = [pscustomobject]@{ scope = 'ArmOnly'; managementGroupId = 'mg-test-01'; generatedOn = (Get-Date).ToString('o') }
        raw   = (Get-Content $script:CollectPath -Raw | ConvertFrom-Json -Depth 100)
    }

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
