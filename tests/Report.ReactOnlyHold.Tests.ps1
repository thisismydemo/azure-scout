#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#6922 — the React single-page report is the product's deliverable; every other RENDERED
    format is on hold while the reporting engine is rebuilt.

    These tests pin the hold as a CONTRACT rather than an implementation detail, because the
    failure mode being guarded against is silence: a run that quietly renders nothing, or quietly
    renders a held format again, looks identical to a healthy run from the outside. That is the
    same class of failure that let a blank dashboard ship past a green suite.

    Pure-file/behavioural tests against the real orchestrator via -FromCollect. No Azure.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    Import-Module "$script:Root/AzureScout.psd1" -Force -ErrorAction Stop
    $script:Module = Get-Module AzureScout | Where-Object { $_.ModuleBase -eq $script:Root } | Select-Object -First 1
    $script:Fixture = "$script:Root/tests/datadump/sample-collect.json"
}

Describe 'The React-only report hold (AB#6922)' {

    It 'declares the held renderers in exactly one place, so lifting the hold is a one-line edit' {
        $held = & $script:Module { $script:ScoutHeldRenderers }
        $all = & $script:Module { $script:ScoutAllRenderers }
        @($held).Count | Should -BeGreaterThan 0
        # Every held name must be a real renderer, or the hold silently guards nothing.
        foreach ($h in $held) { $all | Should -Contain $h }
    }

    It 'holds every rendered document format' {
        $held = & $script:Module { $script:ScoutHeldRenderers }
        foreach ($fmt in 'PowerBi', 'Html', 'Pptx', 'Excel', 'Pdf', 'Word', 'EChartsDashboard', 'GovernanceReport') {
            $held | Should -Contain $fmt -Because "$fmt is a rendered document format and is on hold under AB#6922"
        }
    }

    It 'does NOT hold React — the deliverable must always be renderable' {
        $held = & $script:Module { $script:ScoutHeldRenderers }
        $held | Should -Not -Contain 'React'
    }

    It 'does NOT hold Json/JsonEvidence — they are data, not documents' {
        # The corpus harness, the drift history and downstream tooling read these. Holding them
        # would break automation that has nothing to do with the reporting rebuild.
        $held = & $script:Module { $script:ScoutHeldRenderers }
        $held | Should -Not -Contain 'Json'
        $held | Should -Not -Contain 'JsonEvidence'
    }

    It 'defaults -OutputFormat to React, not to a held format' {
        $cmd = & $script:Module { Get-Command Invoke-ScoutAssessmentCore }
        $default = $cmd.Parameters['OutputFormat'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | Select-Object -First 1
        # The default value itself isn't exposed on the attribute; assert against the AST instead.
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:Root 'src/Invoke-ScoutAssessmentCore.ps1'), [ref]$null, [ref]$null)
        $param = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ParameterAst] -and
                $n.Name.VariablePath.UserPath -eq 'OutputFormat' }, $true) | Select-Object -First 1
        $param | Should -Not -BeNullOrEmpty
        $param.DefaultValue.Extent.Text | Should -Match 'React'
    }

    Context 'end to end against the canonical fixture' {
        BeforeAll {
            $script:OutAll = Join-Path ([System.IO.Path]::GetTempPath()) ("AZSC_Hold_All_" + [System.IO.Path]::GetRandomFileName())
            $script:RunAll = & $script:Module {
                param($Fixture, $OutPath)
                Invoke-ScoutAssessmentCore -Assessment LandingZone -FromCollect $Fixture -OutputFormat All -OutputPath $OutPath
            } $script:Fixture $script:OutAll 3>$null
        }
        AfterAll {
            if ($script:OutAll -and (Test-Path $script:OutAll)) {
                Remove-Item $script:OutAll -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It '-OutputFormat All renders the React report' {
            Test-Path (Join-Path $script:RunAll 'report-react.html') | Should -BeTrue
        }

        It '-OutputFormat All renders NO held document format' {
            # Named explicitly rather than globbing, so a renamed output file cannot make this
            # test pass by accident.
            foreach ($artefact in 'report.html', 'assessment_report.docx', 'assessment_report.pdf',
                'assessment_deck.pptx', 'assessment_evidence.xlsx', 'assessment_dashboard.html',
                'governance_report.html') {
                Test-Path (Join-Path $script:RunAll $artefact) | Should -BeFalse -Because "$artefact is a held format under AB#6922"
            }
            Test-Path (Join-Path $script:RunAll 'powerbi') | Should -BeFalse
        }

        It '-OutputFormat All still emits the machine-readable data exports' {
            Test-Path (Join-Path $script:RunAll 'findings.json') | Should -BeTrue
        }
    }

    It 'warns and skips — never silently produces nothing — when a held format is asked for by name' {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) ("AZSC_Hold_Word_" + [System.IO.Path]::GetRandomFileName())
        try {
            # -WarningVariable binds to the `&` call, not to the cmdlet running inside the module
            # scriptblock, so it comes back empty even when the warning was raised. Redirect the
            # warning stream into the output stream and partition it by record type instead.
            $captured = & $script:Module {
                param($Fixture, $OutPath)
                Invoke-ScoutAssessmentCore -Assessment LandingZone -FromCollect $Fixture -OutputFormat Word -OutputPath $OutPath
            } $script:Fixture $out 3>&1
            $warnings = @($captured | Where-Object { $_ -is [System.Management.Automation.WarningRecord] } | ForEach-Object { [string]$_ })
            $run = @($captured | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }) | Select-Object -Last 1

            # It warned, naming the held format and pointing at the supported route.
            ($warnings -join ' ') | Should -Match 'on hold'
            ($warnings -join ' ') | Should -Match 'Word'

            # And the run still produced a deliverable rather than an empty folder.
            Test-Path (Join-Path $run 'assessment_report.docx') | Should -BeFalse
            Test-Path (Join-Path $run 'report-react.html') | Should -BeTrue
        }
        finally {
            if (Test-Path $out) { Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
