#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Private/Extraction modules.

.DESCRIPTION
    Tests extraction pipeline functions: API resource retrieval, cost inventory,
    management groups, subscriptions, inventory loop, Entra extraction,
    Graph extraction, VM quotas, and VM SKU details.
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
#>

BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:ExtractionPath = Join-Path $script:ModuleRoot 'Modules' 'Private' 'Extraction'
    $script:ResourceDetails = Join-Path $script:ExtractionPath 'ResourceDetails'
}

# =====================================================================
# FILE EXISTENCE
# =====================================================================
Describe 'Private/Extraction Module Files Exist' {
    $extractionFiles = @(
        'Get-AZTIAPIResources.ps1',
        'Get-AZTICostInventory.ps1',
        'Get-AZTIManagementGroups.ps1',
        'Get-AZTISubscriptions.ps1',
        'Invoke-AZTIInventoryLoop.ps1',
        'Start-AZTIEntraExtraction.ps1',
        'Start-AZTIGraphExtraction.ps1'
    )

    It '<_> exists' -ForEach $extractionFiles {
        Join-Path $script:ExtractionPath $_ | Should -Exist
    }

    It 'ResourceDetails/Get-AZTIVMQuotas.ps1 exists' {
        Join-Path $script:ResourceDetails 'Get-AZTIVMQuotas.ps1' | Should -Exist
    }

    It 'ResourceDetails/Get-AZTIVMSkuDetails.ps1 exists' {
        Join-Path $script:ResourceDetails 'Get-AZTIVMSkuDetails.ps1' | Should -Exist
    }
}

# =====================================================================
# SYNTAX VALIDATION
# =====================================================================
Describe 'Private/Extraction Script Syntax Validation' {
    $allFiles = @(
        'Get-AZTIAPIResources.ps1',
        'Get-AZTICostInventory.ps1',
        'Get-AZTIManagementGroups.ps1',
        'Get-AZTISubscriptions.ps1',
        'Invoke-AZTIInventoryLoop.ps1',
        'Start-AZTIEntraExtraction.ps1',
        'Start-AZTIGraphExtraction.ps1'
    )

    It '<_> parses without errors' -ForEach $allFiles {
        $filePath = Join-Path $script:ExtractionPath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    $rdFiles = @('Get-AZTIVMQuotas.ps1', 'Get-AZTIVMSkuDetails.ps1')
    It 'ResourceDetails/<_> parses without errors' -ForEach $rdFiles {
        $filePath = Join-Path $script:ResourceDetails $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

# =====================================================================
# FUNCTION DEFINITIONS
# =====================================================================
Describe 'Private/Extraction Function Definitions' {

    It 'Get-AZTIAPIResources.ps1 defines Get-AZSCAPIResources' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Get-AZTIAPIResources.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCAPIResources'
    }

    It 'Get-AZTICostInventory.ps1 defines Get-AZSCCostInventory' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Get-AZTICostInventory.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCCostInventory'
    }

    It 'Get-AZTIManagementGroups.ps1 defines Get-AZSCManagementGroups' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Get-AZTIManagementGroups.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCManagementGroups'
    }

    It 'Get-AZTISubscriptions.ps1 defines Get-AZSCSubscriptions' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Get-AZTISubscriptions.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCSubscriptions'
    }

    It 'Invoke-AZTIInventoryLoop.ps1 defines Invoke-AZSCInventoryLoop' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Invoke-AZTIInventoryLoop.ps1') -Raw
        $content | Should -Match 'function\s+Invoke-AZSCInventoryLoop'
    }

    It 'Start-AZTIEntraExtraction.ps1 defines Start-AZSCEntraExtraction' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Start-AZTIEntraExtraction.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCEntraExtraction'
    }

    It 'Start-AZTIGraphExtraction.ps1 defines Start-AZSCGraphExtraction' {
        $content = Get-Content (Join-Path $script:ExtractionPath 'Start-AZTIGraphExtraction.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCGraphExtraction'
    }

    It 'Get-AZTIVMQuotas.ps1 defines Get-AZSCVMQuotas' {
        $content = Get-Content (Join-Path $script:ResourceDetails 'Get-AZTIVMQuotas.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCVMQuotas'
    }

    It 'Get-AZTIVMSkuDetails.ps1 defines Get-AZSCVMSkuDetails' {
        $content = Get-Content (Join-Path $script:ResourceDetails 'Get-AZTIVMSkuDetails.ps1') -Raw
        $content | Should -Match 'function\s+Get-AZSCVMSkuDetails'
    }
}
