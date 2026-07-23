#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Pester tests for src/report/Get-ScoutDrift.ps1 — cross-run drift tracking
    (ADO Story AB#5053). Builds scored Findings sets via Get-Score (same
    pattern as tests/Assessment.Engine.Tests.ps1) and points -HistoryPath at a
    throwaway folder under $env:TEMP so runs never touch a real assessment's
    .scout-history. No Azure connection required.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . "$script:Root/src/assess/engine/Get-Score.ps1"
    . "$script:Root/src/report/Get-ScoutDrift.ps1"

    function New-DriftTestFinding {
        param($Id, $Status, $Framework = 'CAF', $Area = 'AreaX', $Severity = 'medium')
        [pscustomobject]@{
            Id = $Id; Title = "$Id title"; Framework = $Framework; Area = $Area; Severity = $Severity
            Status = $Status; EvidenceCount = 1; Evidence = @(); Remediation = "Remediate $Id."
            Manual = ($Status -eq 'Manual'); AreaWeight = 1.0
        }
    }

    function Get-DriftEntry($Drift, $Id) {
        return $Drift.Findings | Where-Object Id -eq $Id
    }
}

Describe 'Get-ScoutDrift — first-ever run' {
    BeforeAll {
        $script:HistoryPath = Join-Path $env:TEMP "ScoutDriftTest_$([guid]::NewGuid().ToString('N'))"

        $run1 = @(
            (New-DriftTestFinding 'f1' 'Pass')
            (New-DriftTestFinding 'f2' 'Fail')
            (New-DriftTestFinding 'f3' 'Manual')
        )
        $script:ScoredRun1 = Get-Score -Findings $run1
        $script:DriftRun1 = Get-ScoutDrift -Findings $script:ScoredRun1 -HistoryPath $script:HistoryPath -RunId 'run1'
    }

    AfterAll {
        if (Test-Path $script:HistoryPath) { Remove-Item $script:HistoryPath -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'returns an explicit baseline drift object, not an error, on the first run' {
        $script:DriftRun1.IsBaseline | Should -BeTrue
        $script:DriftRun1.PreviousRunId | Should -BeNullOrEmpty
        $script:DriftRun1.PreviousScore | Should -BeNullOrEmpty
        $script:DriftRun1.ScoreDelta | Should -BeNullOrEmpty
    }

    It 'classifies every finding as New on the baseline run' {
        $script:DriftRun1.Summary.New | Should -Be 3
        $script:DriftRun1.Summary.Resolved | Should -Be 0
        $script:DriftRun1.Summary.Regressed | Should -Be 0
        $script:DriftRun1.Summary.Unchanged | Should -Be 0
        (Get-DriftEntry $script:DriftRun1 'f1').Drift | Should -Be 'New'
    }

    It 'creates the history file and folder' {
        (Join-Path $script:HistoryPath 'findings-history.json') | Should -Exist
    }
}

Describe 'Get-ScoutDrift — second run with changed statuses' {
    BeforeAll {
        $script:HistoryPath = Join-Path $env:TEMP "ScoutDriftTest_$([guid]::NewGuid().ToString('N'))"

        $run1 = @(
            (New-DriftTestFinding 'f1' 'Pass')
            (New-DriftTestFinding 'f2' 'Fail')
            (New-DriftTestFinding 'f3' 'Manual')
        )
        $scoredRun1 = Get-Score -Findings $run1
        Get-ScoutDrift -Findings $scoredRun1 -HistoryPath $script:HistoryPath -RunId 'run1' | Out-Null

        # f1 unchanged (Pass->Pass), f2 resolved (Fail->Pass), f3 unchanged (Manual->Manual), f4 is new (Fail)
        $run2 = @(
            (New-DriftTestFinding 'f1' 'Pass')
            (New-DriftTestFinding 'f2' 'Pass')
            (New-DriftTestFinding 'f3' 'Manual')
            (New-DriftTestFinding 'f4' 'Fail')
        )
        $script:ScoredRun2 = Get-Score -Findings $run2
        $script:DriftRun2 = Get-ScoutDrift -Findings $script:ScoredRun2 -HistoryPath $script:HistoryPath -RunId 'run2'
    }

    AfterAll {
        if (Test-Path $script:HistoryPath) { Remove-Item $script:HistoryPath -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'is not a baseline and points PreviousRunId at the prior run' {
        $script:DriftRun2.IsBaseline | Should -BeFalse
        $script:DriftRun2.PreviousRunId | Should -Be 'run1'
    }

    It 'classifies a Fail->Pass transition as Resolved' {
        (Get-DriftEntry $script:DriftRun2 'f2').Drift | Should -Be 'Resolved'
        (Get-DriftEntry $script:DriftRun2 'f2').PreviousStatus | Should -Be 'Fail'
        (Get-DriftEntry $script:DriftRun2 'f2').CurrentStatus | Should -Be 'Pass'
    }

    It 'classifies an unseen finding Id as New' {
        (Get-DriftEntry $script:DriftRun2 'f4').Drift | Should -Be 'New'
    }

    It 'classifies same-status findings as Unchanged' {
        (Get-DriftEntry $script:DriftRun2 'f1').Drift | Should -Be 'Unchanged'
        (Get-DriftEntry $script:DriftRun2 'f3').Drift | Should -Be 'Unchanged'
    }

    It 'rolls the per-finding classifications up into an accurate summary' {
        $script:DriftRun2.Summary.New | Should -Be 1
        $script:DriftRun2.Summary.Resolved | Should -Be 1
        $script:DriftRun2.Summary.Regressed | Should -Be 0
        $script:DriftRun2.Summary.Unchanged | Should -Be 2
    }

    It 'computes the correct overall score delta (single-area weighted mean)' {
        # run1: scorable f1(Pass)+f2(Fail) => 1/2*100 = 50
        # run2: scorable f1(Pass)+f2(Pass)+f4(Fail) => 2/3*100 = 67 (AwayFromZero rounding)
        $script:DriftRun2.PreviousScore | Should -Be 50
        $script:DriftRun2.OverallScore | Should -Be 67
        $script:DriftRun2.ScoreDelta | Should -Be 17
    }
}

Describe 'Get-ScoutDrift — third run regresses a previously-passing finding' {
    BeforeAll {
        $script:HistoryPath = Join-Path $env:TEMP "ScoutDriftTest_$([guid]::NewGuid().ToString('N'))"

        $scoredRun1 = Get-Score -Findings @((New-DriftTestFinding 'f1' 'Pass'), (New-DriftTestFinding 'f2' 'Fail'))
        Get-ScoutDrift -Findings $scoredRun1 -HistoryPath $script:HistoryPath -RunId 'run1' | Out-Null

        $script:ScoredRun2 = Get-Score -Findings @((New-DriftTestFinding 'f1' 'Pass'), (New-DriftTestFinding 'f2' 'Pass'))
        Get-ScoutDrift -Findings $script:ScoredRun2 -HistoryPath $script:HistoryPath -RunId 'run2' | Out-Null

        # f1 regresses Pass -> Fail; f2 stays Pass (Unchanged)
        $scoredRun3 = Get-Score -Findings @((New-DriftTestFinding 'f1' 'Fail'), (New-DriftTestFinding 'f2' 'Pass'))
        $script:DriftRun3 = Get-ScoutDrift -Findings $scoredRun3 -HistoryPath $script:HistoryPath -RunId 'run3'
    }

    AfterAll {
        if (Test-Path $script:HistoryPath) { Remove-Item $script:HistoryPath -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'classifies a Pass->Fail transition as Regressed' {
        (Get-DriftEntry $script:DriftRun3 'f1').Drift | Should -Be 'Regressed'
    }

    It 'compares against the immediately previous run (run2), not run1' {
        $script:DriftRun3.PreviousRunId | Should -Be 'run2'
    }

    It 'a rerun of the same RunId replaces its own history record instead of duplicating it' {
        Get-ScoutDrift -Findings $script:ScoredRun2 -HistoryPath $script:HistoryPath -RunId 'run3' | Out-Null
        $historyRaw = Get-Content (Join-Path $script:HistoryPath 'findings-history.json') -Raw | ConvertFrom-Json -Depth 100
        @($historyRaw | Where-Object RunId -eq 'run3').Count | Should -Be 1
    }
}

Describe 'Get-ScoutDrift — malformed/corrupt history is tolerated' {
    BeforeAll {
        $script:HistoryPath = Join-Path $env:TEMP "ScoutDriftTest_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $script:HistoryPath -Force | Out-Null
        'this is not { valid json at all' | Out-File (Join-Path $script:HistoryPath 'findings-history.json') -Encoding utf8

        $scored = Get-Score -Findings @((New-DriftTestFinding 'f1' 'Pass'), (New-DriftTestFinding 'f2' 'Fail'))
        $script:Drift = { Get-ScoutDrift -Findings $scored -HistoryPath $script:HistoryPath -RunId 'run1' }
    }

    AfterAll {
        if (Test-Path $script:HistoryPath) { Remove-Item $script:HistoryPath -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'does not throw on a malformed history file' {
        $script:Drift | Should -Not -Throw
    }

    It 'treats malformed history as a baseline' {
        $result = & $script:Drift
        $result.IsBaseline | Should -BeTrue
        $result.PreviousRunId | Should -BeNullOrEmpty
    }

    It 'overwrites the malformed file with valid JSON afterward' {
        & $script:Drift | Out-Null
        { Get-Content (Join-Path $script:HistoryPath 'findings-history.json') -Raw | ConvertFrom-Json -Depth 100 } | Should -Not -Throw
    }
}

Describe 'Get-ScoutDrift — missing history file/folder is tolerated' {
    It 'treats an entirely absent -HistoryPath/-HistoryFile as a baseline on the first call, not an error' {
        $historyPath = Join-Path $env:TEMP "ScoutDriftTest_$([guid]::NewGuid().ToString('N'))"
        try {
            $scored = Get-Score -Findings @((New-DriftTestFinding 'f1' 'Pass'))
            { Get-ScoutDrift -Findings $scored -HistoryPath $historyPath -RunId 'run1' } | Should -Not -Throw
            # The scriptblock above actually ran (Should -Not -Throw executes it), so the
            # folder/history file now exist from that first, baseline call. A second call
            # with a different RunId should therefore find run1 as its previous run and NOT
            # be a baseline anymore — confirming the auto-create path feeds real history.
            (Get-ScoutDrift -Findings $scored -HistoryPath $historyPath -RunId 'run1-b').IsBaseline | Should -BeFalse
        }
        finally {
            if (Test-Path $historyPath) { Remove-Item $historyPath -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
