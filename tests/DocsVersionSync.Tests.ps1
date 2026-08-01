#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#5630 — the documentation site must state the version that is actually shipping.

    The published docs site drifted two minor releases behind the module (the changelog summary
    table stopped at v2.2.0 while v2.4.0 was on the gallery), and nothing caught it: the docs
    deploy is path-filtered, so a release commit that touched only the manifest and CHANGELOG.md
    never redeployed the site, and no test compared the two.

    Widening the workflow's path filter makes the site redeploy on a release. It does NOT stop the
    site from redeploying content that is itself stale. These tests close that half: they fail in
    CI whenever the manifest version is not the version the docs and ledger present.

    Pure-file tests — no Azure, no network.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent

    $manifest = Import-PowerShellDataFile (Join-Path $script:Root 'AzureScout.psd1')
    $script:Version = [string] $manifest.ModuleVersion

    $script:Changelog   = Get-Content (Join-Path $script:Root 'CHANGELOG.md') -Raw
    $script:Releases    = Get-Content (Join-Path $script:Root 'RELEASES.md') -Raw
    $script:DocsRoadmap = Get-Content (Join-Path $script:Root 'docs/project/roadmap.md') -Raw
    $script:DocsChange  = Get-Content (Join-Path $script:Root 'docs/project/changelog.md') -Raw
}

Describe 'Documentation states the shipping version (AB#5630)' {

    It 'has a sane ModuleVersion to compare against' {
        $script:Version | Should -Match '^\d+\.\d+\.\d+$'
    }

    It 'CHANGELOG.md newest version heading matches the manifest' {
        # Skip [Unreleased]; the first NUMBERED heading is the shipping release.
        $m = [regex]::Match($script:Changelog, '(?m)^##\s*\[(\d+\.\d+\.\d+)\]')
        $m.Success | Should -BeTrue -Because 'CHANGELOG.md must carry a numbered version heading'
        $m.Groups[1].Value | Should -Be $script:Version
    }

    It 'docs/project/roadmap.md names the manifest version as the Current Release' {
        $m = [regex]::Match($script:DocsRoadmap, '(?m)^##\s*Current Release\s*[—-]\s*v(\d+\.\d+\.\d+)')
        $m.Success | Should -BeTrue -Because 'the roadmap must declare a Current Release'
        $m.Groups[1].Value | Should -Be $script:Version
    }

    It 'docs/project/changelog.md summary table leads with the manifest version' {
        # The first version row in the table is the newest release.
        $m = [regex]::Match($script:DocsChange, '\|\s*\*\*v(\d+\.\d+\.\d+)\*\*')
        $m.Success | Should -BeTrue -Because 'the docs changelog must have a version row'
        $m.Groups[1].Value | Should -Be $script:Version
    }

    It 'RELEASES.md ledger contains a row for the shipping version' {
        $script:Releases | Should -Match ([regex]::Escape('| **' + $script:Version + '** |'))
    }

    It 'the manifest ReleaseNotes lead with the shipping version' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:Root 'AzureScout.psd1')
        ([string] $manifest.PrivateData.PSData.ReleaseNotes).TrimStart() |
            Should -Match ('^v' + [regex]::Escape($script:Version) + '\b')
    }

    It 'the manifest ReleaseNotes stay under the PowerShell Gallery 10,600-character limit' {
        # PSGallery rejects the push with a 400 above this. Appending every release to a
        # cumulative string blew past it on v2.5.1; keep only the recent releases plus a link.
        $manifest = Import-PowerShellDataFile (Join-Path $script:Root 'AzureScout.psd1')
        ([string] $manifest.PrivateData.PSData.ReleaseNotes).Length | Should -BeLessOrEqual 10600
    }
}

Describe 'The docs deploy fires on a release commit (AB#5630)' {

    It 'watches the version-bearing files, not just docs/' {
        $workflow = Get-Content (Join-Path $script:Root '.github/workflows/documentation.yml') -Raw
        foreach ($path in 'AzureScout.psd1', 'CHANGELOG.md', 'RELEASES.md', 'docs/**') {
            $workflow | Should -Match ([regex]::Escape("'$path'")) -Because `
                "a release touching $path must redeploy the site, or it silently goes stale"
        }
    }
}
