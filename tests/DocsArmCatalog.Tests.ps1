#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    docs/reference/arm-modules.md told readers it was generated from manifests/collectors/ while being
    hand-maintained, and drifted 15 collectors and 3 categories out of date without anything
    noticing (AB#6741). It is generated now, and this is what keeps it that way.
#>

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
}

Describe 'docs/reference/arm-modules.md is generated, not hand-written' {

    It 'matches a fresh regeneration from the collector manifests (both catalog pages)' {
        $Script = Join-Path $script:Root 'scripts/Build-ArmModuleCatalog.ps1'
        & pwsh -NoProfile -File $Script -Check 2>&1 | Out-String -OutVariable Output | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because "adding or removing a collector must be followed by ``pwsh scripts/Build-ArmModuleCatalog.ps1``. Output:`n$Output"
    }

    It 'states the same collector count the manifest tree holds' {
        # Cheap independent check: if the generator itself regressed, -Check would still pass
        # (it compares the page against the generator's own output). This compares the page
        # against the filesystem.
        $Expected = @(Get-ChildItem -LiteralPath (Join-Path $script:Root 'manifests/collectors') -Recurse -Filter '*.psd1' -File).Count
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/arm-modules.md') -Raw
        $Page | Should -Match "\*\*$Expected collector definitions\*\*"
    }
}
