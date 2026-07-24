#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for the module auto-UPDATE check (AB#369).

.DESCRIPTION
    Tests Test-AZSCModuleUpdate (Modules\Private\Main\Test-AZSCModuleUpdate.ps1), the
    function AzureScout.psm1 calls once on import to surface a newer PSGallery release.
    Find-Module, Get-Module, and Update-Module are mocked throughout so these tests never
    touch the network or the real PSGallery. The marker file used for the 24h throttle is
    a real file (matching this repo's existing Private/Main test convention of exercising
    real temp-file I/O -- see Private.Main.Tests.ps1), isolated to its own path and cleaned
    up before/after every test so runs never interfere with each other or with a real
    session's throttle state.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Work item: AB#369
#>

BeforeAll {
    $script:ModuleRoot   = Split-Path -Parent $PSScriptRoot
    $script:MainPath     = Join-Path $script:ModuleRoot 'Modules' 'Private' 'Main'
    $script:FunctionFile = Join-Path $script:MainPath 'Test-AZSCModuleUpdate.ps1'
    $script:ManifestPath = Join-Path $script:ModuleRoot 'AzureScout.psd1'
    $script:ThrottleFile = Join-Path ([System.IO.Path]::GetTempPath()) 'azurescout-update-check.txt'

    # Find-Module/Update-Module are function exports of PowerShellGet, loaded on demand.
    # Import explicitly so Pester's Mock can find a command to shim -- without this,
    # command discovery inside the Pester runner scope can fail before the mock is set up.
    Import-Module -Name PowerShellGet -ErrorAction SilentlyContinue

    . $script:FunctionFile
}

Describe 'Test-AZSCModuleUpdate' {

    BeforeEach {
        # Isolate every test from the real machine throttle marker and from any CI /
        # opt-out / opt-in env vars that might be set in the outer shell.
        Remove-Item -Path $script:ThrottleFile -Force -ErrorAction SilentlyContinue
        foreach ($v in @('CI', 'TF_BUILD', 'GITHUB_ACTIONS', 'AZURESCOUT_SKIP_UPDATE_CHECK', 'AZURESCOUT_AUTO_UPDATE')) {
            Remove-Item -Path "Env:$v" -ErrorAction SilentlyContinue
        }
    }

    AfterAll {
        Remove-Item -Path $script:ThrottleFile -Force -ErrorAction SilentlyContinue
        foreach ($v in @('CI', 'TF_BUILD', 'GITHUB_ACTIONS', 'AZURESCOUT_SKIP_UPDATE_CHECK', 'AZURESCOUT_AUTO_UPDATE')) {
            Remove-Item -Path "Env:$v" -ErrorAction SilentlyContinue
        }
    }

    Context 'newer version available on PSGallery' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName Find-Module -MockWith {
                [pscustomobject]@{ Name = 'AzureScout'; Version = [Version]'99.0.0' }
            }
            Mock -CommandName Update-Module -MockWith { }
        }

        It 'notifies (Write-Warning) with the newer version and does not update without opt-in' {
            $warnings = @()
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningVariable warnings -WarningAction SilentlyContinue
            ($warnings -join ' ') | Should -Match '99\.0\.0'
            ($warnings -join ' ') | Should -Match 'Update-Module AzureScout'
            Should -Invoke -CommandName Update-Module -Times 0
        }

        It 'updates via Update-Module when AZURESCOUT_AUTO_UPDATE is set (explicit opt-in)' {
            $env:AZURESCOUT_AUTO_UPDATE = '1'
            { Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue } | Should -Not -Throw
            Should -Invoke -CommandName Update-Module -Times 1 -ParameterFilter { $Name -eq 'AzureScout' }
        }

        It 'prefers an already-imported module instance over the manifest when Get-Module finds one' {
            Mock -CommandName Get-Module -MockWith {
                [pscustomobject]@{ Name = 'AzureScout'; Version = [Version]'0.0.1' }
            }
            $warnings = @()
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningVariable warnings -WarningAction SilentlyContinue
            ($warnings -join ' ') | Should -Match '0\.0\.1'
        }
    }

    Context 'offline / PSGallery unreachable' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName Find-Module -MockWith { throw 'Unable to resolve package source (no network).' }
        }

        It 'does not throw and does not block the caller' {
            { Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath } | Should -Not -Throw
        }

        It 'degrades to Write-Verbose only (no warning surfaced)' {
            $warnings = @()
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -BeNullOrEmpty
        }
    }

    Context 'already at the latest version' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName Find-Module -MockWith {
                [pscustomobject]@{ Name = 'AzureScout'; Version = [Version]'2.1.0' }
            }
            Mock -CommandName Update-Module -MockWith { }
        }

        It 'is a no-op: no warning, no update, when local and gallery versions match' {
            $warnings = @()
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -BeNullOrEmpty
            Should -Invoke -CommandName Update-Module -Times 0
        }
    }

    Context 'CI / automation guard' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName Find-Module -MockWith {
                [pscustomobject]@{ Name = 'AzureScout'; Version = [Version]'99.0.0' }
            }
        }

        It 'skips the check entirely under GITHUB_ACTIONS (never calls Find-Module)' {
            $env:GITHUB_ACTIONS = 'true'
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Should -Invoke -CommandName Find-Module -Times 0
        }

        It 'skips the check entirely under TF_BUILD (Azure DevOps) (never calls Find-Module)' {
            $env:TF_BUILD = 'True'
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Should -Invoke -CommandName Find-Module -Times 0
        }

        It 'skips the check entirely when AZURESCOUT_SKIP_UPDATE_CHECK is set (explicit opt-out)' {
            $env:AZURESCOUT_SKIP_UPDATE_CHECK = '1'
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Should -Invoke -CommandName Find-Module -Times 0
        }
    }

    Context 'throttle (once per 24 hours)' {

        BeforeEach {
            Mock -CommandName Get-Module -MockWith { $null }
            Mock -CommandName Find-Module -MockWith {
                [pscustomobject]@{ Name = 'AzureScout'; Version = [Version]'2.1.0' }
            }
        }

        It 'only calls Find-Module once across two calls made back-to-back' {
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Should -Invoke -CommandName Find-Module -Times 1
        }

        It 'checks again once the marker is older than 24 hours' {
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Set-Content -Path $script:ThrottleFile -Value (Get-Date).AddHours(-25).ToString('o')
            Test-AZSCModuleUpdate -ManifestPath $script:ManifestPath -WarningAction SilentlyContinue
            Should -Invoke -CommandName Find-Module -Times 2
        }
    }
}
