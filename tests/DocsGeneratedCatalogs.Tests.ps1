#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Guards the two catalogues added by the documentation audit's F4 and F7 findings:

      docs/reference/framework-coverage.md — how much of each enumerated framework has a rule.
        Published because the docs implied full CAF/WAF alignment while the AB#6447 audit put
        real coverage at roughly 10% and 15%, and that figure lived only in a PMO audit.

      docs/reference/collector-fields.md — the worksheet and columns each collector produces.
        arm-modules.md said what is covered; nothing said what comes back.

    Both are generated for the same reason the ARM catalogue is: the hand-maintained version of
    that page drifted fifteen collectors out of date while claiming to be generated (AB#6741).
#>

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
}

Describe 'Generated reference catalogues are current' {

    It 'framework-coverage.md matches a fresh regeneration' {
        $Script = Join-Path $script:Root 'scripts/Build-FrameworkCoverage.ps1'
        & pwsh -NoProfile -File $Script -Check 2>&1 | Out-String -OutVariable Output | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because "adding a rule or editing a framework enumeration must be followed by ``pwsh scripts/Build-FrameworkCoverage.ps1``. Output:`n$Output"
    }

    It 'collector-fields.md matches a fresh regeneration' {
        $Script = Join-Path $script:Root 'scripts/Build-CollectorFieldCatalog.ps1'
        & pwsh -NoProfile -File $Script -Check 2>&1 | Out-String -OutVariable Output | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because "changing a collector's Export block must be followed by ``pwsh scripts/Build-CollectorFieldCatalog.ps1``. Output:`n$Output"
    }
}

Describe 'Framework coverage is reported honestly' {

    It 'states a coverage percentage rather than implying full alignment' {
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/framework-coverage.md') -Raw
        $Page | Should -Match '\*\*\d+ of \d+ items \(\d+%\) have a rule behind them\*\*'
    }

    It 'explains the 0% item coverage on the CAF enumeration rather than leaving it bare' {
        # CAF enumerates individual recommendations while the rules work per design area, so
        # item-level coverage is 0% by construction. Printing that number with no explanation
        # would be as misleading as claiming full coverage.
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/framework-coverage.md') -Raw
        $Page | Should -Match '0% \*\*by construction\*\*'
        $Page | Should -Match 'Areas covered'
    }

    It 'says a covered item is not necessarily a well-tested one' {
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/framework-coverage.md') -Raw
        $Page | Should -Match 'coverage\s+measure, not a quality one'
    }
}

Describe 'Collector fields catalogue covers every collector' {

    It 'lists as many collectors as the manifest tree holds' {
        $Expected = @(Get-ChildItem -LiteralPath (Join-Path $script:Root 'manifests/collectors') -Recurse -Filter '*.psd1' -File).Count
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/collector-fields.md') -Raw
        $Rows = ([regex]::Matches($Page, '(?m)^\| \*\*[^*]+\*\* \|')).Count
        $Rows | Should -Be $Expected
    }

    It 'warns that a declared column is not a guarantee of data' {
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/collector-fields.md') -Raw
        $Page | Should -Match 'collector-rowcounts\.json'
    }
}
