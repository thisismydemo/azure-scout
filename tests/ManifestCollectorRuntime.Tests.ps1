#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    v3 runtime catalog gate.  The collector engine must discover its entire executable
    catalog from manifests/collectors; a missing source script must not silently shrink a run.
#>
BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:RepoRoot 'src/pipeline/Get-ScoutCollector.ps1')
}

Describe 'Manifest collector runtime catalog' {
    It 'discovers every shipped collector without a retired collector root' {
        $DefinitionRoot = Join-Path $script:RepoRoot 'manifests/collectors'
        $Expected = @(Get-ChildItem -LiteralPath $DefinitionRoot -Recurse -Filter '*.psd1' -File)
        $Actual = @(Get-ScoutCollector -DefinitionRoot $DefinitionRoot)

        $Actual.Count | Should -Be $Expected.Count
        $Actual.Count | Should -Be 242   # 174 through v3.0.9, +68 from AB#6741, -6 retired by AB#6767/AB#6842, +4 from AB#6779, +1 ArcSites (AB#6801), +1 ReservationUtilization (AB#6829)
        @($Actual | Where-Object {
            -not $_.HasDeclarativeDefinition -or
            [string]::IsNullOrWhiteSpace($_.DefinitionPath) -or
            $_.Path
        }).Count | Should -Be 0
    }

    It 'orders and filters the manifest catalog by category and collector name' {
        $DefinitionRoot = Join-Path $script:RepoRoot 'manifests/collectors'
        $All = @(Get-ScoutCollector -DefinitionRoot $DefinitionRoot)
        $Compute = @(Get-ScoutCollector -DefinitionRoot $DefinitionRoot -Category Compute)

        @($All | ForEach-Object { "$($_.FolderCategory)/$($_.Name)" }) |
            Should -Be @($All | ForEach-Object { "$($_.FolderCategory)/$($_.Name)" } | Sort-Object)
        $Compute.Count | Should -BeGreaterThan 0
        @($Compute.FolderCategory | Select-Object -Unique) | Should -Be @('Compute')
    }
}
