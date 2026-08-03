#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    AB#6879 (Feature AB#6878) -- clause R-01/R-02 of docs/design/report-conformance.md.

    The owner's stated requirement: "If I am doing an inventory and assessment together, and
    picked Landing Zone and another assessment, there should be detailed reports for each."

    Phase 0 measured what the single merged document cost. A run selecting LandingZone AND
    Cloud Governance emitted ONE assessment_report.docx, and three unrelated tenants -- 9, 2 and
    8 subscriptions -- produced documents within 258 bytes of each other. See
    pmo/research/baseline/README.md.

    These tests read the SOURCE rather than executing a full run: the render path needs a live
    $collect, and the contract being pinned here is structural -- that the core accumulates per
    assessment, scores each independently, and renders each into its own folder.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:CorePath = Join-Path $script:RepoRoot 'src/Invoke-ScoutAssessmentCore.ps1'
    $script:Source = Get-Content -LiteralPath $script:CorePath -Raw
}

Describe 'AB#6879 -- the run keeps findings per assessment, not just merged' {

    It 'accumulates into a per-assessment map alongside the flat collection' {
        $script:Source | Should -Match '\$findingsByAssessment\s*=\s*\[ordered\]@\{\}'
        $script:Source | Should -Match '\$findingsByAssessment\[\$name\]\s*=\s*@\(\$findings\)'
    }

    It 'still populates $allFindings, because the roll-up and every existing caller read it' {
        # The merged set is not being replaced -- it is being joined. A change that dropped it
        # would break the run-root report and every test that reads it.
        $script:Source | Should -Match '\$allFindings\s*\+=\s*\$findings'
        $script:Source | Should -Match 'Get-Score -Findings \$allFindings'
    }

    It 'records the compliance branch too, which returns early' {
        # Invoke-ScoutComplianceAssessment `continue`s, so it needs its own map write or a
        # compliance assessment would silently have no per-assessment report.
        $ComplianceBlock = [regex]::Match(
            $script:Source,
            'Invoke-ScoutComplianceAssessment.*?continue',
            [System.Text.RegularExpressions.RegexOptions]::Singleline).Value

        $ComplianceBlock | Should -Match '\$findingsByAssessment\[\$name\]'
    }
}

Describe 'AB#6879 -- each assessment renders into its own folder' {

    It 'writes under assessments/<slug>/ per clause R-02' {
        $script:Source | Should -Match "Join-Path \`$runPath 'assessments'"
    }

    It 'slugifies the assessment name so a colon never reaches a folder name' {
        # 'Assess: Cloud Governance' must not become a directory name -- ':' is invalid on
        # Windows and the run would throw at New-Item.
        $script:Source | Should -Match "-replace '\[\^a-z0-9\]\+', '-'"
    }

    It 'scores each assessment INDEPENDENTLY rather than reusing the run-wide score' {
        # Reusing $scored would print the same number in every folder, which defeats the split.
        $script:Source | Should -Match '\$perScored\s*=\s*Get-Score -Findings \$perFindings'
        $script:Source | Should -Match 'Export-Report -Renderer \$r -Findings \$perScored'
    }

    It 'emits the per-assessment sets only when more than one assessment ran' {
        # A single-assessment run would otherwise write identical documents twice.
        $script:Source | Should -Match '@\(\$findingsByAssessment\.Keys\)\.Count -gt 1'
    }

    It 'contains one renderer failure to that assessment, never the whole run' {
        $PerBlock = [regex]::Match(
            $script:Source,
            "Join-Path \`$runPath 'assessments'.*?^\s{4}\}",
            [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
            [System.Text.RegularExpressions.RegexOptions]::Multiline).Value

        $PerBlock | Should -Match 'try\s*\{'
        $PerBlock | Should -Match 'catch'
        $PerBlock | Should -Match 'Write-Warning'
    }

    It 'still returns exactly one run path' {
        # Every caller including Invoke-ScoutPipeline expects a single path. Renderers that
        # RETURN what they wrote must stay piped to Out-Null.
        $script:Source | Should -Match 'return \$runPath'
        @([regex]::Matches($script:Source, 'Export-Report[^\r\n]*\| Out-Null')).Count |
            Should -BeGreaterOrEqual 2 -Because 'both the merged and the per-assessment render must swallow renderer return values'
    }
}

Describe 'AB#6879 -- the slug is a valid folder name' {

    It 'turns the shipped assessment names into safe slugs' -ForEach @(
        @{ Name = 'LandingZone';              Expected = 'landingzone' }
        @{ Name = 'Assess: Cloud Governance'; Expected = 'assess-cloud-governance' }
        @{ Name = 'CAF: Governance';          Expected = 'caf-governance' }
        @{ Name = 'WAF: Cost Optimization';   Expected = 'waf-cost-optimization' }
        @{ Name = 'AVS Landing Zone';         Expected = 'avs-landing-zone' }
    ) {
        # The same expression the core uses.
        $Slug = ($Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')

        $Slug | Should -Be $Expected
        $Slug | Should -Not -Match '[:\\/<>"|?*]'
    }
}

Describe 'AB#6880 -- the cross-assessment executive roll-up (clause R-03)' {

    It 'writes the roll-up under executive/' {
        $script:Source | Should -Match "Join-Path \`$runPath 'executive'"
    }

    It 'renders the roll-up from the MERGED score, not a re-assessment' {
        # It is a roll-up: "here is your estate, here is how it scored across every framework
        # assessed". Re-scoring here would invent a third number that matches neither the run
        # root nor any per-assessment folder.
        $Block = [regex]::Match(
            $script:Source,
            "Join-Path \`$runPath 'executive'.*?\z",
            [System.Text.RegularExpressions.RegexOptions]::Singleline).Value

        $Block | Should -Match 'Export-Report -Renderer \$r -Findings \$scored'
    }

    It 'emits a rollup.json carrying per-assessment score, failed and manual counts' {
        # The roll-up's whole value is the COMPARISON across assessments -- which of these is
        # worst. That needs each assessment's own numbers side by side.
        $script:Source | Should -Match 'rollup\.json'
        foreach ($Field in 'Assessment', 'Score', 'Findings', 'Failed', 'Manual') {
            $script:Source | Should -Match "$Field\s*=" -Because "the roll-up compares assessments on $Field"
        }
    }

    It 'restricts the roll-up to the deck and the PDF' {
        # The read-in-ten-minutes artefact. A workbook and a Power BI project beside it would
        # bury the point.
        $script:Source | Should -Match "foreach \(\`$r in @\('Pptx', 'Pdf'\)\)"
    }

    It 'honours -OutputFormat -- no roll-up deck when the caller did not ask for Pptx' {
        $script:Source | Should -Match '\$reporters -notcontains \$r'
    }

    It 'contains a roll-up renderer failure without losing the reports already written' {
        $Block = [regex]::Match(
            $script:Source,
            "Join-Path \`$runPath 'executive'.*?\z",
            [System.Text.RegularExpressions.RegexOptions]::Singleline).Value

        $Block | Should -Match 'catch'
        $Block | Should -Match 'failed for the executive roll-up'
    }

    It 'only produces a roll-up when more than one assessment ran' {
        # Nested inside the same >1 guard as the per-assessment folders: a roll-up over a single
        # assessment is that assessment.
        $GuardIndex = $script:Source.IndexOf('@($findingsByAssessment.Keys).Count -gt 1')
        $ExecIndex = $script:Source.IndexOf("Join-Path `$runPath 'executive'")

        $GuardIndex | Should -BeGreaterThan 0
        $ExecIndex | Should -BeGreaterThan $GuardIndex
    }
}
