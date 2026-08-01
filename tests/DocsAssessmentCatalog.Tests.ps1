#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    There was no page anywhere listing the assessments Azure Scout performs. The two pages that
    came closest disagreed with the product and with each other — docs/assessment/assessment.md
    said "24 assessments", docs/design/assessment-registry.md said "23", and the registry held
    46. This keeps docs/reference/assessment-catalogue.md generated and honest.

    The dangling-glob test is the one that matters. 'Assess: Storage' referenced 'waf.storage'
    for some time after that rule file was deleted in the AB#6746 restructure: the glob matched
    nothing, the assessment silently contributed zero WAF rules, and its Frameworks line went on
    advertising WAF coverage. Nothing failed, because nothing was checking.
#>

BeforeAll {
    $script:Root = Split-Path -Parent $PSScriptRoot
}

Describe 'docs/reference/assessment-catalogue.md is generated, not hand-written' {

    It 'matches a fresh regeneration from the registry and rule files' {
        $Script = Join-Path $script:Root 'scripts/Build-AssessmentCatalog.ps1'
        & pwsh -NoProfile -File $Script -Check 2>&1 | Out-String -OutVariable Output | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because "adding an assessment or a rule file must be followed by ``pwsh scripts/Build-AssessmentCatalog.ps1``. Output:`n$Output"
    }

    It 'states the same assessment count the registry holds' {
        # Independent of the generator: compares the page against the manifest directly, so a
        # regression in the generator itself cannot pass by agreeing with its own output.
        $Expected = (Import-PowerShellDataFile (Join-Path $script:Root 'manifests/assessments.psd1')).Keys.Count
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/assessment-catalogue.md') -Raw
        $Page | Should -Match "\*\*$Expected assessments\*\*"
    }

    It 'states the same rule-file count the rules directory holds' {
        $Expected = @(Get-ChildItem -LiteralPath (Join-Path $script:Root 'src/assess/rules') -Filter '*.yaml' -File).Count
        $Page = Get-Content -LiteralPath (Join-Path $script:Root 'docs/reference/assessment-catalogue.md') -Raw
        $Page | Should -Match "\*\*$Expected rule files\*\*"
    }
}

Describe 'every assessment resolves to at least one rule file' {

    It 'has no dangling Rules glob in the registry' {
        $Registry = Import-PowerShellDataFile (Join-Path $script:Root 'manifests/assessments.psd1')
        $Have = @(Get-ChildItem -LiteralPath (Join-Path $script:Root 'src/assess/rules') -Filter '*.yaml' -File).BaseName

        $Dangling = foreach ($name in $Registry.Keys) {
            $entry = $Registry[$name]
            if (-not $entry.ContainsKey('Rules')) { continue }
            foreach ($pat in @($entry.Rules)) {
                if (-not @($Have | Where-Object { $_ -like $pat })) { "$name -> '$pat'" }
            }
        }

        @($Dangling) | Should -BeNullOrEmpty -Because 'a Rules glob matching no file contributes zero rules silently while the assessment still advertises the framework'
    }
}
