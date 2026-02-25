#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Public/PublicFunctions utility scripts.

.DESCRIPTION
    Tests public function files: Diagram generation functions and Job wrapper functions.
    Validates file existence, syntax, and function definitions.
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
#>

BeforeAll {
    $script:ModuleRoot   = Split-Path -Parent $PSScriptRoot
    $script:PublicPath   = Join-Path $script:ModuleRoot 'Modules' 'Public' 'PublicFunctions'
    $script:DiagramPath  = Join-Path $script:PublicPath 'Diagram'
    $script:JobsPath     = Join-Path $script:PublicPath 'Jobs'
}

# =====================================================================
# FILE EXISTENCE
# =====================================================================
Describe 'Public/PublicFunctions Files Exist' {
    It 'Invoke-AzureScout.ps1 exists' {
        Join-Path $script:PublicPath 'Invoke-AzureScout.ps1' | Should -Exist
    }

    It 'Test-AZTIPermissions.ps1 exists' {
        Join-Path $script:PublicPath 'Test-AZTIPermissions.ps1' | Should -Exist
    }
}

Describe 'Public/Diagram Files Exist' {
    $diagramFiles = @(
        'Build-AZTIDiagramSubnet.ps1',
        'Set-AZTIDiagramFile.ps1',
        'Start-AZTIDiagramJob.ps1',
        'Start-AZTIDiagramNetwork.ps1',
        'Start-AZTIDiagramOrganization.ps1',
        'Start-AZTIDiagramSubscription.ps1',
        'Start-AZTIDrawIODiagram.ps1'
    )

    It '<_> exists' -ForEach $diagramFiles {
        Join-Path $script:DiagramPath $_ | Should -Exist
    }
}

Describe 'Public/Jobs Files Exist' {
    $jobFiles = @(
        'Start-AZTIAdvisoryJob.ps1',
        'Start-AZTIPolicyJob.ps1',
        'Start-AZTISecCenterJob.ps1',
        'Start-AZTISubscriptionJob.ps1',
        'Wait-AZTIJob.ps1'
    )

    It '<_> exists' -ForEach $jobFiles {
        Join-Path $script:JobsPath $_ | Should -Exist
    }
}

# =====================================================================
# SYNTAX VALIDATION
# =====================================================================
Describe 'Public/PublicFunctions Syntax Validation' {

    It 'Invoke-AzureScout.ps1 parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:PublicPath 'Invoke-AzureScout.ps1'), [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'Test-AZTIPermissions.ps1 parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:PublicPath 'Test-AZTIPermissions.ps1'), [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    $diagramFiles = @(
        'Build-AZTIDiagramSubnet.ps1',
        'Set-AZTIDiagramFile.ps1',
        'Start-AZTIDiagramJob.ps1',
        'Start-AZTIDiagramNetwork.ps1',
        'Start-AZTIDiagramOrganization.ps1',
        'Start-AZTIDiagramSubscription.ps1',
        'Start-AZTIDrawIODiagram.ps1'
    )

    It 'Diagram/<_> parses without errors' -ForEach $diagramFiles {
        $filePath = Join-Path $script:DiagramPath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    $jobFiles = @(
        'Start-AZTIAdvisoryJob.ps1',
        'Start-AZTIPolicyJob.ps1',
        'Start-AZTISecCenterJob.ps1',
        'Start-AZTISubscriptionJob.ps1',
        'Wait-AZTIJob.ps1'
    )

    It 'Jobs/<_> parses without errors' -ForEach $jobFiles {
        $filePath = Join-Path $script:JobsPath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

# =====================================================================
# FUNCTION DEFINITIONS
# =====================================================================
Describe 'Public/Diagram Function Definitions' {

    It 'Build-AZTIDiagramSubnet.ps1 defines Build-AZSCDiagramSubnet' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Build-AZTIDiagramSubnet.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCDiagramSubnet'
    }

    It 'Set-AZTIDiagramFile.ps1 defines Set-AZSCDiagramFile' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Set-AZTIDiagramFile.ps1') -Raw
        $content | Should -Match 'function\s+Set-AZSCDiagramFile'
    }

    It 'Start-AZTIDiagramJob.ps1 defines Start-AZSCDiagramJob' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Start-AZTIDiagramJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCDiagramJob'
    }

    It 'Start-AZTIDiagramNetwork.ps1 defines Start-AZSCDiagramNetwork' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Start-AZTIDiagramNetwork.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCDiagramNetwork'
    }

    It 'Start-AZTIDiagramOrganization.ps1 defines Start-AZSCDiagramOrganization' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Start-AZTIDiagramOrganization.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCDiagramOrganization'
    }

    It 'Start-AZTIDiagramSubscription.ps1 defines Start-AZSCDiagramSubscription' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Start-AZTIDiagramSubscription.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCDiagramSubscription'
    }

    It 'Start-AZTIDrawIODiagram.ps1 defines Start-AZSCDrawIODiagram' {
        $content = Get-Content (Join-Path $script:DiagramPath 'Start-AZTIDrawIODiagram.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCDrawIODiagram'
    }
}

Describe 'Public/Jobs Function Definitions' {

    It 'Start-AZTIAdvisoryJob.ps1 defines Start-AZSCAdvisoryJob' {
        $content = Get-Content (Join-Path $script:JobsPath 'Start-AZTIAdvisoryJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCAdvisoryJob'
    }

    It 'Start-AZTIPolicyJob.ps1 defines Start-AZSCPolicyJob' {
        $content = Get-Content (Join-Path $script:JobsPath 'Start-AZTIPolicyJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCPolicyJob'
    }

    It 'Start-AZTISecCenterJob.ps1 defines Start-AZSCSecCenterJob' {
        $content = Get-Content (Join-Path $script:JobsPath 'Start-AZTISecCenterJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCSecCenterJob'
    }

    It 'Start-AZTISubscriptionJob.ps1 defines Start-AZSCSubscriptionJob' {
        $content = Get-Content (Join-Path $script:JobsPath 'Start-AZTISubscriptionJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCSubscriptionJob'
    }

    It 'Wait-AZTIJob.ps1 defines Wait-AZSCJob' {
        $content = Get-Content (Join-Path $script:JobsPath 'Wait-AZTIJob.ps1') -Raw
        $content | Should -Match 'function\s+Wait-AZSCJob'
    }
}
