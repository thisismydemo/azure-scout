#Requires -Version 7.0
#Requires -Modules Pester

<#
    Pester tests for src/Invoke-ScoutPipeline.ps1's AB#402 addition: an
    $Error.Count before/after delta around the permission audit and the
    collect/assess/report call surfaces non-terminating errors a step swallowed
    internally (e.g. Invoke-Collect's own AB#397/399/400 per-query resilience)
    without the step itself throwing -- forcing the run's overall outcome to
    PartialSuccess and recording `hadNonTerminatingErrors` in the summary.

    Invoke-ScoutAssessment is mocked throughout -- no live Azure connection or
    real Invoke-Collect call is made.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    # Dot-source the real orchestrator purely so Mock has a command with a matching
    # parameter set to attach a proxy to -- its body is never actually executed here.
    . "$root/src/Invoke-ScoutAssessment.ps1"
    . "$root/src/Invoke-ScoutPipeline.ps1"

    function Get-OkPermissionCheck {
        [pscustomobject]@{ Check = 'ARM Reader @ MG root'; Ok = $true; Fix = 'Assign Reader at the tenant root management group scope.' }
    }

    # Simulates a step that records a non-terminating error internally (caught by
    # its own try/catch, exactly like Invoke-Collect's AB#397/399/400 handling)
    # but still completes and returns normally -- the scenario AB#402 exists to
    # surface. PowerShell adds a caught exception to $Error regardless of whether
    # it propagates, so this reproduces that "swallowed but still recorded" case
    # without needing a real Invoke-Collect call.
    function Add-SimulatedSwallowedError {
        try { throw 'Simulated per-query failure that was already handled internally.' }
        catch { Write-Verbose "Swallowed (by design): $($_.Exception.Message)" }
    }
}

Describe 'Invoke-ScoutPipeline -- AB#402 non-terminating error surfacing' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
    }

    Context 'the collect/assess/report step swallowed an error internally' {
        BeforeEach {
            Mock Invoke-ScoutAssessment {
                if ($PermissionAudit) { return @(Get-OkPermissionCheck) }
                Add-SimulatedSwallowedError
                $folder = Join-Path $OutputPath '20260101_000000'
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                '{}' | Out-File (Join-Path $folder 'collect.json')
                @{ Findings = @(@{ Status = 'Pass' }) } | ConvertTo-Json -Depth 5 | Out-File (Join-Path $folder 'findings.json')
                return $folder
            }
        }

        It 'does not throw' {
            { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Not -Throw
        }

        It 'records hadNonTerminatingErrors = true even though nothing threw' {
            $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
            $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
            $summary.hadNonTerminatingErrors | Should -BeTrue
            $summary.assessmentError | Should -BeNullOrEmpty
        }

        It 'degrades the outcome to PartialSuccess despite a clean (non-throwing) return' {
            $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
            $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
            $summary.outcome | Should -Be 'PartialSuccess'
        }

        It 'notes the non-terminating errors in pipeline-summary.md' {
            $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
            $md = Get-Content (Join-Path $runFolder 'pipeline-summary.md') -Raw
            $md | Should -Match 'Non-terminating errors: yes'
        }
    }

    Context 'the permission audit swallowed an error internally' {
        BeforeEach {
            Mock Invoke-ScoutAssessment {
                if ($PermissionAudit) {
                    Add-SimulatedSwallowedError
                    return @(Get-OkPermissionCheck)
                }
                $folder = Join-Path $OutputPath '20260101_000000'
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                '{}' | Out-File (Join-Path $folder 'collect.json')
                @{ Findings = @(@{ Status = 'Pass' }) } | ConvertTo-Json -Depth 5 | Out-File (Join-Path $folder 'findings.json')
                return $folder
            }
        }

        It 'records permissionAudit.HadNonTerminatingErrors = true and degrades to PartialSuccess' {
            $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
            $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
            $summary.permissionAudit.HadNonTerminatingErrors | Should -BeTrue
            $summary.outcome | Should -Be 'PartialSuccess'
        }
    }

    Context 'a fully clean run records no non-terminating errors' {
        BeforeEach {
            Mock Invoke-ScoutAssessment {
                if ($PermissionAudit) { return @(Get-OkPermissionCheck) }
                $folder = Join-Path $OutputPath '20260101_000000'
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                '{}' | Out-File (Join-Path $folder 'collect.json')
                @{ Findings = @(@{ Status = 'Pass' }) } | ConvertTo-Json -Depth 5 | Out-File (Join-Path $folder 'findings.json')
                return $folder
            }
        }

        It 'records hadNonTerminatingErrors = false and outcome Success' {
            $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
            $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
            $summary.hadNonTerminatingErrors | Should -BeFalse
            $summary.outcome | Should -Be 'Success'
        }
    }
}
