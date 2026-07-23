#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the unattended pipeline wrapper (src/Invoke-ScoutPipeline.ps1).

.DESCRIPTION
    Invoke-ScoutAssessment (and, transitively, Test-ScoutPermission) is mocked
    throughout -- no Azure call is ever made. Validates:
      - pipeline-summary.json is written with the documented schema keys
      - outcome is computed correctly for Success / PartialSuccess (exporter
        throws mid-run, or the permission audit hard-fails) / Failed (the
        orchestrator returns nothing and creates no run folder)
      - Failed throws (and sets $global:LASTEXITCODE = 1); Success/PartialSuccess
        return the run folder normally
      - non-interactive preferences ($ConfirmPreference / $ProgressPreference) are
        set for the duration of the orchestrator call
      - -SkipPermissionAudit actually skips the -PermissionAudit call
      - -ManagementGroupId / -Category are threaded through to the orchestrator call

    Tracks ADO AB#5050.
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
    function Get-FailedPermissionCheck {
        [pscustomobject]@{ Check = 'ARM Reader @ MG root'; Ok = $false; Fix = 'Assign Reader at the tenant root management group scope.' }
    }
}

Describe 'Invoke-ScoutPipeline -- Success path' {
    BeforeEach {
        # A unique folder name per test -- the mock below writes a fixed run-folder
        # name, and leftover folders from an earlier test in the same $TestDrive
        # would otherwise be mistaken for "already existed before this call" by the
        # exception-recovery directory scan.
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
        $script:seenConfirm  = $null
        $script:seenProgress = $null

        Mock Invoke-ScoutAssessment {
            if ($PermissionAudit) { return @(Get-OkPermissionCheck) }

            $script:seenConfirm  = $ConfirmPreference
            $script:seenProgress = $ProgressPreference

            $folder = Join-Path $OutputPath '20260101_000000'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '{}' | Out-File (Join-Path $folder 'collect.json')
            @{ Findings = @(@{ Status = 'Pass' }, @{ Status = 'Pass' }, @{ Status = 'Fail' }, @{ Status = 'Manual' }) } |
                ConvertTo-Json -Depth 5 | Out-File (Join-Path $folder 'findings.json')
            return $folder
        }
    }

    It 'returns the run folder path' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $runFolder | Should -Not -BeNullOrEmpty
        Test-Path $runFolder | Should -BeTrue
    }

    It 'writes pipeline-summary.json with every documented schema key' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $summaryPath = Join-Path $runFolder 'pipeline-summary.json'
        Test-Path $summaryPath | Should -BeTrue

        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        $keys = $summary.PSObject.Properties.Name
        foreach ($expected in 'schemaVersion', 'startedOn', 'finishedOn', 'elapsedSeconds',
                              'assessments', 'formats', 'managementGroupId', 'runFolder',
                              'assessmentStatus', 'findingsByStatus', 'permissionAudit',
                              'assessmentError', 'outcome') {
            $keys | Should -Contain $expected
        }
    }

    It 'writes a human-readable pipeline-summary.md' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        Test-Path (Join-Path $runFolder 'pipeline-summary.md') | Should -BeTrue
    }

    It 'computes outcome Success when the audit passes and the orchestrator returns cleanly' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
        $summary.outcome | Should -Be 'Success'
        $summary.assessmentError | Should -BeNullOrEmpty
    }

    It 'computes findings counts by Status from findings.json' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
        $summary.findingsByStatus.Pass   | Should -Be 2
        $summary.findingsByStatus.Fail   | Should -Be 1
        $summary.findingsByStatus.Manual | Should -Be 1
    }

    It 'sets non-interactive preferences for the duration of the orchestrator call' {
        Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath | Out-Null
        "$script:seenConfirm"  | Should -Be 'None'
        "$script:seenProgress" | Should -Be 'SilentlyContinue'
    }

    It 'does not throw' {
        { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Not -Throw
    }

    It 'threads -ManagementGroupId and -Category through to the orchestrator call' {
        Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath -ManagementGroupId 'contoso-root-mg' -Category 'Security' | Out-Null
        Should -Invoke Invoke-ScoutAssessment -ParameterFilter {
            -not $PermissionAudit -and $ManagementGroupId -eq 'contoso-root-mg' -and ($Category -contains 'Security')
        } -Times 1
    }
}

Describe 'Invoke-ScoutPipeline -- -SkipPermissionAudit' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
        Mock Invoke-ScoutAssessment {
            if ($PermissionAudit) { return @(Get-OkPermissionCheck) }
            $folder = Join-Path $OutputPath '20260101_000000'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '{}' | Out-File (Join-Path $folder 'collect.json')
            return $folder
        }
    }

    It 'never calls Invoke-ScoutAssessment -PermissionAudit' {
        Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath -SkipPermissionAudit | Out-Null
        Should -Invoke Invoke-ScoutAssessment -ParameterFilter { $PermissionAudit } -Times 0 -Exactly
    }

    It 'records the audit as Skipped in the summary' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath -SkipPermissionAudit
        $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
        $summary.permissionAudit.Skipped | Should -BeTrue
        $summary.permissionAudit.Ran     | Should -BeFalse
    }
}

Describe 'Invoke-ScoutPipeline -- PartialSuccess (exporter throws mid-run)' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
        Mock Invoke-ScoutAssessment {
            if ($PermissionAudit) { return @(Get-OkPermissionCheck) }
            # Simulate the orchestrator getting partway through (collect.json written)
            # before an exporter throws -- the run folder exists but is incomplete.
            $folder = Join-Path $OutputPath '20260101_000000'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '{}' | Out-File (Join-Path $folder 'collect.json')
            throw 'Export-Pptx: simulated exporter failure'
        }
    }

    It 'does not throw -- degrades to PartialSuccess instead of killing the run' {
        { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Not -Throw
    }

    It 'recovers the run folder the orchestrator had already created before it threw' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $runFolder | Should -Not -BeNullOrEmpty
        Test-Path (Join-Path $runFolder 'collect.json') | Should -BeTrue
    }

    It 'computes outcome PartialSuccess and captures the error message' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
        $summary.outcome | Should -Be 'PartialSuccess'
        $summary.assessmentError | Should -Match 'simulated exporter failure'
    }
}

Describe 'Invoke-ScoutPipeline -- PartialSuccess (permission audit hard failure)' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
        Mock Invoke-ScoutAssessment {
            if ($PermissionAudit) { return @(Get-FailedPermissionCheck) }
            $folder = Join-Path $OutputPath '20260101_000000'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '{}' | Out-File (Join-Path $folder 'collect.json')
            @{ Findings = @(@{ Status = 'Pass' }) } | ConvertTo-Json -Depth 5 | Out-File (Join-Path $folder 'findings.json')
            return $folder
        }
    }

    It 'does not throw even when the permission audit hard-fails' {
        { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Not -Throw
    }

    It 'computes outcome PartialSuccess despite a clean orchestrator run' {
        $runFolder = Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath
        $summary = Get-Content (Join-Path $runFolder 'pipeline-summary.json') -Raw | ConvertFrom-Json
        $summary.outcome | Should -Be 'PartialSuccess'
        $summary.permissionAudit.Ok | Should -BeFalse
    }
}

Describe 'Invoke-ScoutPipeline -- Failed (assess returns nothing)' {
    BeforeEach {
        $script:outPath = Join-Path $TestDrive "output-$([guid]::NewGuid())"
        Mock Invoke-ScoutAssessment {
            if ($PermissionAudit) { return @(Get-OkPermissionCheck) }
            # Simulate total failure: no folder created, nothing returned.
            return $null
        }
    }

    It 'throws' {
        { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Throw
    }

    It 'sets $global:LASTEXITCODE to 1' {
        try { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath }
        catch { Write-Verbose "Expected failure captured: $_" -Verbose:$false }
        $global:LASTEXITCODE | Should -Be 1
    }

    It 'the thrown message mentions the run produced no output' {
        { Invoke-ScoutPipeline -Assessment LandingZone -OutputPath $script:outPath } | Should -Throw -ExpectedMessage '*produced no output*'
    }
}
