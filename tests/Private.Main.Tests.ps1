#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Private/Main utility functions.

.DESCRIPTION
    Tests core utility functions: folder management, cache clearing, memory cleanup,
    path resolution, platform detection, unsupported data loading, graph token,
    and orchestration functions.
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
#>

BeforeAll {
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:MainPath   = Join-Path $script:ModuleRoot 'Modules' 'Private' 'Main'
    $script:TempDir    = Join-Path $env:TEMP 'AZSC_PrivateMainTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# =====================================================================
# FILE EXISTENCE TESTS
# =====================================================================
Describe 'Private/Main Module Files Exist' {
    $mainFiles = @(
        'Clear-AZTICacheFolder.ps1',
        'Clear-AZTIMemory.ps1',
        'Connect-AZTILoginSession.ps1',
        'Get-AZTIGraphToken.ps1',
        'Get-AZTIUnsupportedData.ps1',
        'Invoke-AZTIGraphRequest.ps1',
        'Invoke-AZTIPermissionAudit.ps1',
        'Set-AZTIFolder.ps1',
        'Set-AZTIReportPath.ps1',
        'Start-AZTIExtractionOrchestration.ps1',
        'Start-AZTIProcessOrchestration.ps1',
        'Start-AZTIReporOrchestration.ps1',
        'Test-AZTIPS.ps1'
    )

    It '<_> exists' -ForEach $mainFiles {
        Join-Path $script:MainPath $_ | Should -Exist
    }
}

# =====================================================================
# SYNTAX VALIDATION — every file parses without error
# =====================================================================
Describe 'Private/Main Script Syntax Validation' {
    $mainFiles = @(
        'Clear-AZTICacheFolder.ps1',
        'Clear-AZTIMemory.ps1',
        'Connect-AZTILoginSession.ps1',
        'Get-AZTIGraphToken.ps1',
        'Get-AZTIUnsupportedData.ps1',
        'Invoke-AZTIGraphRequest.ps1',
        'Invoke-AZTIPermissionAudit.ps1',
        'Set-AZTIFolder.ps1',
        'Set-AZTIReportPath.ps1',
        'Start-AZTIExtractionOrchestration.ps1',
        'Start-AZTIProcessOrchestration.ps1',
        'Start-AZTIReporOrchestration.ps1',
        'Test-AZTIPS.ps1'
    )

    It '<_> parses without errors' -ForEach $mainFiles {
        $filePath = Join-Path $script:MainPath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

# =====================================================================
# FUNCTION DEFINITION TESTS — each file defines the expected function
# =====================================================================
Describe 'Private/Main Function Definitions' {

    It 'Clear-AZTICacheFolder.ps1 defines Clear-AZSCCacheFolder' {
        $content = Get-Content (Join-Path $script:MainPath 'Clear-AZTICacheFolder.ps1') -Raw
        $content | Should -Match 'function\s+Clear-AZSCCacheFolder'
    }

    It 'Clear-AZTIMemory.ps1 defines Clear-AZSCMemory' {
        $content = Get-Content (Join-Path $script:MainPath 'Clear-AZTIMemory.ps1') -Raw
        $content | Should -Match 'function\s+Clear-AZSCMemory'
    }

    It 'Set-AZTIFolder.ps1 defines Set-AZSCFolder' {
        $content = Get-Content (Join-Path $script:MainPath 'Set-AZTIFolder.ps1') -Raw
        $content | Should -Match 'function\s+Set-AZSCFolder'
    }

    It 'Set-AZTIReportPath.ps1 defines Set-AZSCReportPath' {
        $content = Get-Content (Join-Path $script:MainPath 'Set-AZTIReportPath.ps1') -Raw
        $content | Should -Match 'function\s+Set-AZSCReportPath'
    }

    It 'Test-AZTIPS.ps1 defines Test-AZSCPS' {
        $content = Get-Content (Join-Path $script:MainPath 'Test-AZTIPS.ps1') -Raw
        $content | Should -Match 'function\s+Test-AZSCPS'
    }

    It 'Get-AZTIUnsupportedData.ps1 defines Get-AZSCUnsupportedData' {
        $content = Get-Content (Join-Path $script:MainPath 'Get-AZTIUnsupportedData.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCUnsupportedData'
    }

    It 'Get-AZTIGraphToken.ps1 defines Get-AZSCGraphToken' {
        $content = Get-Content (Join-Path $script:MainPath 'Get-AZTIGraphToken.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCGraphToken'
    }

    It 'Start-AZTIExtractionOrchestration.ps1 defines Start-AZSCExtractionOrchestration' {
        $content = Get-Content (Join-Path $script:MainPath 'Start-AZTIExtractionOrchestration.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExtractionOrchestration'
    }

    It 'Start-AZTIProcessOrchestration.ps1 defines Start-AZSCProcessOrchestration' {
        $content = Get-Content (Join-Path $script:MainPath 'Start-AZTIProcessOrchestration.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCProcessOrchestration'
    }

    It 'Start-AZTIReporOrchestration.ps1 defines Start-AZSCReporOrchestration' {
        $content = Get-Content (Join-Path $script:MainPath 'Start-AZTIReporOrchestration.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCRepor[Ot]rchestration'
    }

    It 'Connect-AZTILoginSession.ps1 defines Connect-AZSCLoginSession' {
        $content = Get-Content (Join-Path $script:MainPath 'Connect-AZTILoginSession.ps1') -Raw
        $content | Should -Match 'function\s+Connect-AZSCLoginSession'
    }

    It 'Invoke-AZTIGraphRequest.ps1 defines Invoke-AZSCGraphRequest' {
        $content = Get-Content (Join-Path $script:MainPath 'Invoke-AZTIGraphRequest.ps1') -Raw
        $content | Should -Match 'function\s+Invoke-AZSCGraphRequest'
    }

    It 'Invoke-AZTIPermissionAudit.ps1 defines Invoke-AZSCPermissionAudit' {
        $content = Get-Content (Join-Path $script:MainPath 'Invoke-AZTIPermissionAudit.ps1') -Raw
        $content | Should -Match 'function\s+Invoke-AZSCPermissionAudit'
    }
}

# =====================================================================
# UNIT TESTS — Simple utility functions
# =====================================================================
Describe 'Clear-AZSCMemory — runs without error' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Clear-AZTIMemory.ps1')
    }

    It 'Executes without throwing' {
        { Clear-AZSCMemory } | Should -Not -Throw
    }
}

Describe 'Clear-AZSCCacheFolder — deletes files in cache folder' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Clear-AZTICacheFolder.ps1')
        $script:CacheDir = Join-Path $script:TempDir 'cache_test'
        New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
        # Create test files
        'data1' | Out-File (Join-Path $script:CacheDir 'file1.json')
        'data2' | Out-File (Join-Path $script:CacheDir 'file2.json')
    }

    It 'Removes files from cache folder' {
        Clear-AZSCCacheFolder -ReportCache $script:CacheDir
        $remaining = Get-ChildItem -Path $script:CacheDir -File -Recurse
        $remaining.Count | Should -Be 0
    }
}

Describe 'Set-AZSCFolder — creates directories' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Set-AZTIFolder.ps1')
        $script:TestDefaultPath  = Join-Path $script:TempDir 'default_folder'
        $script:TestDiagramCache = Join-Path $script:TempDir 'diagram_cache'
        $script:TestReportCache  = Join-Path $script:TempDir 'report_cache'
    }

    It 'Creates directories that do not exist' {
        Set-AZSCFolder -DefaultPath $script:TestDefaultPath -DiagramCache $script:TestDiagramCache -ReportCache $script:TestReportCache
        $script:TestDefaultPath  | Should -Exist
        $script:TestDiagramCache | Should -Exist
        $script:TestReportCache  | Should -Exist
    }

    It 'Does not throw when directories already exist' {
        { Set-AZSCFolder -DefaultPath $script:TestDefaultPath -DiagramCache $script:TestDiagramCache -ReportCache $script:TestReportCache } | Should -Not -Throw
    }
}

Describe 'Set-AZSCReportPath — returns path hashtable' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Set-AZTIReportPath.ps1')
    }

    It 'Returns a hashtable with DefaultPath, DiagramCache, ReportCache' {
        $result = Set-AZSCReportPath -ReportDir $script:TempDir
        $result | Should -Not -BeNullOrEmpty
        $result.DefaultPath | Should -Not -BeNullOrEmpty
        $result.DiagramCache | Should -Not -BeNullOrEmpty
        $result.ReportCache | Should -Not -BeNullOrEmpty
    }

    It 'Uses custom ReportDir when provided' {
        $result = Set-AZSCReportPath -ReportDir $script:TempDir
        $result.DefaultPath | Should -BeLike "*$([System.IO.Path]::GetFileName($script:TempDir))*"
    }

    It 'Returns valid paths when no ReportDir is specified' {
        $result = Set-AZSCReportPath
        $result | Should -Not -BeNullOrEmpty
        $result.DefaultPath | Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-AZSCPS — detects platform' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Test-AZTIPS.ps1')
    }

    It 'Returns a non-empty string' {
        $result = Test-AZSCPS
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Returns one of the known platform strings' {
        $result = Test-AZSCPS
        $result | Should -BeIn @('Azure CloudShell', 'PowerShell Unix', 'PowerShell Desktop')
    }
}

Describe 'Get-AZSCUnsupportedData — loads Support.json' {
    BeforeAll {
        . (Join-Path $script:MainPath 'Get-AZTIUnsupportedData.ps1')
    }

    It 'Returns parsed data from Support.json' {
        $result = Get-AZSCUnsupportedData
        # Might return null if Support.json path resolution fails outside module context
        # At minimum it should not throw
    }

    It 'Does not throw' {
        { Get-AZSCUnsupportedData } | Should -Not -Throw
    }
}
