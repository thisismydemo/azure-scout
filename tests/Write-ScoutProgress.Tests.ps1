#Requires -Version 7.0
#Requires -Modules Pester

<#
    Pester tests for src/Write-ScoutProgress.ps1 (AB#405) -- the optional,
    soft-dependency progress-UX helper shared by the collect/assess/report
    pipeline. No live Azure connection is needed.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . "$root/src/Write-ScoutProgress.ps1"
}

Describe 'Write-ScoutProgress -- interactive (Write-Progress) path' {
    It 'does not throw with a percent-complete status call' {
        { Write-ScoutProgress -Activity 'Test' -Status 'step 1' -PercentComplete 10 } | Should -Not -Throw
    }

    It 'does not throw on a -Completed call' {
        { Write-ScoutProgress -Activity 'Test' -Id 1 -Completed } | Should -Not -Throw
    }

    It 'does not throw with an indeterminate (-1, the default) percent' {
        { Write-ScoutProgress -Activity 'Test' -Status 'working' } | Should -Not -Throw
    }

    It 'does not throw with -ParentId set (nested progress)' {
        { Write-ScoutProgress -Activity 'Child' -Status 'nested step' -PercentComplete 50 -Id 2 -ParentId 1 } | Should -Not -Throw
    }
}

Describe 'Write-ScoutProgress -- CI / headless (log-line) fallback' {
    BeforeEach { $ProgressPreference = 'SilentlyContinue' }
    AfterEach  { $ProgressPreference = 'Continue' }

    It 'does not throw when $ProgressPreference is SilentlyContinue' {
        { Write-ScoutProgress -Activity 'Test' -Status 'step 1' -PercentComplete 25 } | Should -Not -Throw
    }

    It 'emits a single-line, log-friendly status via the Information stream' {
        $info = Write-ScoutProgress -Activity 'ScoutTest' -Status 'doing the thing' -PercentComplete 42 6>&1 |
            Where-Object { $_ -is [System.Management.Automation.InformationRecord] }
        $lines = ($info | ForEach-Object { $_.MessageData }) -join "`n"
        $lines | Should -Match 'ScoutTest'
        $lines | Should -Match '42%'
    }

    It 'does not emit a log line on a -Completed call (avoids a spurious final line)' {
        $info = Write-ScoutProgress -Activity 'ScoutTest' -Id 1 -Completed 6>&1 |
            Where-Object { $_ -is [System.Management.Automation.InformationRecord] }
        @($info).Count | Should -Be 0
    }
}

Describe 'Write-ScoutProgress -- soft dependency (no hard install of PwshSpectreConsole)' {
    It 'never throws even though PwshSpectreConsole is not installed in this environment' {
        Get-Module -ListAvailable -Name PwshSpectreConsole | Should -BeNullOrEmpty
        { Write-ScoutProgress -Activity 'Test' -Status 'step' -PercentComplete 5 } | Should -Not -Throw
    }
}

Describe 'Write-ScoutProgress -- guarded optional integration with Invoke-Collect (AB#405)' {
    BeforeAll {
        $collectRoot = Split-Path $PSScriptRoot -Parent
        Import-Module Az.ResourceGraph -ErrorAction Stop
        . "$collectRoot/src/collect/Invoke-Collect.ps1"
    }

    It 'Invoke-Collect calls through to Write-ScoutProgress without error when it is loaded in the session' {
        Mock Search-AzGraph { return @() }
        { Invoke-Collect -Categories @('Security') -WarningAction SilentlyContinue } | Should -Not -Throw
    }
}
