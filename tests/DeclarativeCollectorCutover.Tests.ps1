#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollector.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollectorDefinition.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutDeclarativeCollector.ps1')
    . (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutCollector.ps1')
}

Describe 'v3 declarative collector cutover' {
    It 'discovers the shipped manifest catalog without a retired collector tree' {
        $Definitions = Join-Path $script:RepoRoot 'manifests/collectors'
        $Collectors = @(Get-ScoutCollector -DefinitionRoot $Definitions)

        # 174 through v3.0.9; 242 after AB#6741 added 68; 236 after AB#6767/AB#6842 retired six
        # that could never return a row -- three whose Azure endpoint no longer exists, and three
        # declaring resource types the provider metadata does not have; 240 after AB#6779 added the
        # four governance collectors (role assignments, policy assignments, locks, budgets); 241
        # after AB#6801 re-created Hybrid/ArcSites against the confirmed-real, non-RG-indexed
        # `Microsoft.Edge/sites` type (Hybrid/VirtualMachines was re-sourced under AB#6802 without
        # a count change -- it already existed); 242 after AB#6829 added the owned-reservation
        # utilization collector. The number is pinned rather than derived so that a collector
        # silently DISAPPEARING is a failure, not an invisible regression.
        $Collectors.Count | Should -Be 242
        @($Collectors | Where-Object { -not $_.HasDeclarativeDefinition }).Count | Should -Be 0
        @($Collectors | Where-Object { $_.Path }).Count | Should -Be 0
    }

    It 'exposes no imperative execution switch on the runtime entry point' {
        $Command = Get-Command Invoke-ScoutCollector
        $Command.Parameters.ContainsKey('Imperative') | Should -BeFalse
        $Command.Parameters.ContainsKey('ForceImperativeCollectors') | Should -BeFalse

        $Runtime = Get-Content (Join-Path $script:RepoRoot 'src/pipeline/Invoke-ScoutCollector.ps1') -Raw
        $Runtime | Should -Not -Match 'Set-StrictMode\s+-Off'
        $Runtime | Should -Not -Match 'ImperativeCapture|ImperativeFallback'
    }

    It 'contains an invalid definition as a declarative failure rather than executing another path' {
        $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("scout-v3-cutover-" + [guid]::NewGuid().ToString('N'))
        try {
            $Dir = Join-Path $Root 'Fixture'; $null = New-Item -ItemType Directory -Path $Dir -Force
            "@{ ResourceTypes = @('widget'); RowLoopVariable = '1'; Export = @{ WorksheetName = 'Bad'; Columns = @('ID') } }" |
                Set-Content -LiteralPath (Join-Path $Dir 'Malformed.psd1') -Encoding utf8
            $Collector = @(Get-ScoutCollector -DefinitionRoot $Root)[0]
            $Result = Invoke-ScoutCollector -Collector $Collector -Context @{ Resources = @(); Task = 'Processing' } -WarningAction SilentlyContinue

            $Result.Success | Should -BeFalse
            $Result.Mode | Should -Be 'Declarative'
            @($Result.Rows).Count | Should -Be 0
        } finally { Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
