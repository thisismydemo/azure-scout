#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the AzureScout module.

.DESCRIPTION
    Basic module validation tests for AzureScout (AZSC).
    These tests verify the module can be imported, that expected functions
    are exported, and that the manifest is well-formed.

.NOTES
    Author:  thisismydemo
    Version: 1.0.0
    Created: 2026-01-20
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = Join-Path $ModuleRoot 'AzureScout.psd1'
    $ModulePath   = Join-Path $ModuleRoot 'AzureScout.psm1'
}

Describe 'Module Manifest Tests' {
    It 'Has a valid module manifest' {
        $ManifestPath | Should -Exist
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        $Manifest | Should -Not -BeNullOrEmpty
    }

    It 'Has the correct module name' {
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        $Manifest.Name | Should -Be 'AzureScout'
    }

    It 'Has a valid GUID' {
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        $Manifest.Guid | Should -Be 'a0785538-fd96-4960-bf93-c733f88519e0'
    }

    It 'Has version 1.0.0' {
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        $Manifest.Version | Should -Be '1.0.0'
    }

    It 'Has the correct author' {
        $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        $Manifest.Author | Should -Be 'thisismydemo'
    }

    It 'Has a root module' {
        $ModulePath | Should -Exist
    }
}

Describe 'Module Import Tests' {
    It 'Imports without errors' {
        { Import-Module $ManifestPath -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Exports Invoke-AzureScout' {
        Import-Module $ManifestPath -Force -ErrorAction Stop
        $Commands = Get-Command -Module AzureScout
        $Commands.Name | Should -Contain 'Invoke-AzureScout'
    }
}
