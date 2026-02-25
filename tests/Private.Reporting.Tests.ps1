#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Pester tests for Private/Reporting modules and StyleFunctions.

.DESCRIPTION
    Tests reporting pipeline functions: advisory, cost management, monitor,
    policy, quota, security center, security overview, subscriptions,
    update manager reports, JSON/Markdown/AsciiDoc export, Excel jobs,
    and style/formatting functions.
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
#>

BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:ReportingPath  = Join-Path $script:ModuleRoot 'Modules' 'Private' 'Reporting'
    $script:StylePath      = Join-Path $script:ReportingPath 'StyleFunctions'
}

# =====================================================================
# FILE EXISTENCE
# =====================================================================
Describe 'Private/Reporting Module Files Exist' {
    $reportingFiles = @(
        'Build-AZTIAdvisoryReport.ps1',
        'Build-AZTICostManagementReport.ps1',
        'Build-AZTIMonitorReport.ps1',
        'Build-AZTIPolicyReport.ps1',
        'Build-AZTIQuotaReport.ps1',
        'Build-AZTISecCenterReport.ps1',
        'Build-AZTISecurityOverviewReport.ps1',
        'Build-AZTISubsReport.ps1',
        'Build-AZTIUpdateManagerReport.ps1',
        'Export-AZTIAsciiDocReport.ps1',
        'Export-AZTIJsonReport.ps1',
        'Export-AZTIMarkdownReport.ps1',
        'Start-AZTIExcelExtraData.ps1',
        'Start-AZTIExcelJob.ps1',
        'Start-AZTIExtraReports.ps1'
    )

    It '<_> exists' -ForEach $reportingFiles {
        Join-Path $script:ReportingPath $_ | Should -Exist
    }
}

Describe 'Private/Reporting/StyleFunctions Files Exist' {
    $styleFiles = @(
        'Build-AZTIExcelChart.ps1',
        'Build-AZTIExcelComObject.ps1',
        'Build-AZTIExcelinitialBlock.ps1',
        'Out-AZTIReportResults.ps1',
        'Start-AZTIExcelCustomization.ps1',
        'Start-AZTIExcelOrdening.ps1'
    )

    It '<_> exists' -ForEach $styleFiles {
        Join-Path $script:StylePath $_ | Should -Exist
    }

    It 'Retirement.kql exists' {
        Join-Path $script:StylePath 'Retirement.kql' | Should -Exist
    }

    It 'Support.json exists' {
        Join-Path $script:StylePath 'Support.json' | Should -Exist
    }
}

# =====================================================================
# SYNTAX VALIDATION
# =====================================================================
Describe 'Private/Reporting Script Syntax Validation' {
    $reportingFiles = @(
        'Build-AZTIAdvisoryReport.ps1',
        'Build-AZTICostManagementReport.ps1',
        'Build-AZTIMonitorReport.ps1',
        'Build-AZTIPolicyReport.ps1',
        'Build-AZTIQuotaReport.ps1',
        'Build-AZTISecCenterReport.ps1',
        'Build-AZTISecurityOverviewReport.ps1',
        'Build-AZTISubsReport.ps1',
        'Build-AZTIUpdateManagerReport.ps1',
        'Export-AZTIAsciiDocReport.ps1',
        'Export-AZTIJsonReport.ps1',
        'Export-AZTIMarkdownReport.ps1',
        'Start-AZTIExcelExtraData.ps1',
        'Start-AZTIExcelJob.ps1',
        'Start-AZTIExtraReports.ps1'
    )

    It '<_> parses without errors' -ForEach $reportingFiles {
        $filePath = Join-Path $script:ReportingPath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    $styleScripts = @(
        'Build-AZTIExcelChart.ps1',
        'Build-AZTIExcelComObject.ps1',
        'Build-AZTIExcelinitialBlock.ps1',
        'Out-AZTIReportResults.ps1',
        'Start-AZTIExcelCustomization.ps1',
        'Start-AZTIExcelOrdening.ps1'
    )

    It 'StyleFunctions/<_> parses without errors' -ForEach $styleScripts {
        $filePath = Join-Path $script:StylePath $_
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
}

# =====================================================================
# FUNCTION DEFINITIONS
# =====================================================================
Describe 'Private/Reporting Function Definitions' {

    It 'Build-AZTIAdvisoryReport.ps1 defines Build-AZSCAdvisoryReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTIAdvisoryReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCAdvisoryReport'
    }

    It 'Build-AZTICostManagementReport.ps1 defines Build-AZSCCostManagementReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTICostManagementReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCCostManagementReport'
    }

    It 'Build-AZTIMonitorReport.ps1 defines Build-AZSCMonitorReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTIMonitorReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCMonitorReport'
    }

    It 'Build-AZTIPolicyReport.ps1 defines Build-AZSCPolicyReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTIPolicyReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCPolicyReport'
    }

    It 'Build-AZTIQuotaReport.ps1 defines Build-AZSCQuotaReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTIQuotaReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCQuotaReport'
    }

    It 'Build-AZTISecCenterReport.ps1 defines Build-AZSCSecCenterReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTISecCenterReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCSecCenterReport'
    }

    It 'Build-AZTISecurityOverviewReport.ps1 defines Build-AZSCSecurityOverviewReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTISecurityOverviewReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCSecurityOverviewReport'
    }

    It 'Build-AZTISubsReport.ps1 defines Build-AZSCSubsReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTISubsReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCSubsReport'
    }

    It 'Build-AZTIUpdateManagerReport.ps1 defines Build-AZSCUpdateManagerReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Build-AZTIUpdateManagerReport.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCUpdateManagerReport'
    }

    It 'Export-AZTIJsonReport.ps1 defines Export-AZSCJsonReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Export-AZTIJsonReport.ps1') -Raw
        $content | Should -Match 'function\s+Export-AZSCJsonReport'
    }

    It 'Export-AZTIMarkdownReport.ps1 defines Export-AZSCMarkdownReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Export-AZTIMarkdownReport.ps1') -Raw
        $content | Should -Match 'function\s+Export-AZSCMarkdownReport'
    }

    It 'Export-AZTIAsciiDocReport.ps1 defines Export-AZSCAsciiDocReport' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Export-AZTIAsciiDocReport.ps1') -Raw
        $content | Should -Match 'function\s+Export-AZSCAsciiDocReport'
    }

    It 'Start-AZTIExcelExtraData.ps1 defines Start-AZSCExcelExtraData' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Start-AZTIExcelExtraData.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExcelExtraData'
    }

    It 'Start-AZTIExcelJob.ps1 defines Start-AZSCExcelJob' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Start-AZTIExcelJob.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExcelJob'
    }

    It 'Start-AZTIExtraReports.ps1 defines Start-AZSCExtraReports' {
        $content = Get-Content (Join-Path $script:ReportingPath 'Start-AZTIExtraReports.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExtraReports'
    }
}

Describe 'Private/Reporting/StyleFunctions Function Definitions' {

    It 'Build-AZTIExcelChart.ps1 defines Build-AZSCExcelChart' {
        $content = Get-Content (Join-Path $script:StylePath 'Build-AZTIExcelChart.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCExcelChart'
    }

    It 'Build-AZTIExcelComObject.ps1 defines Build-AZSCExcelComObject' {
        $content = Get-Content (Join-Path $script:StylePath 'Build-AZTIExcelComObject.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCExcelComObject'
    }

    It 'Build-AZTIExcelinitialBlock.ps1 defines Build-AZSCInitialBlock' {
        $content = Get-Content (Join-Path $script:StylePath 'Build-AZTIExcelinitialBlock.ps1') -Raw
        $content | Should -Match 'function\s+Build-AZSCInitialBlock'
    }

    It 'Out-AZTIReportResults.ps1 defines Out-AZSCReportResults' {
        $content = Get-Content (Join-Path $script:StylePath 'Out-AZTIReportResults.ps1') -Raw
        $content | Should -Match 'function\s+Out-AZSCReportResults'
    }

    It 'Start-AZTIExcelCustomization.ps1 defines Start-AZSCExcelCustomization' {
        $content = Get-Content (Join-Path $script:StylePath 'Start-AZTIExcelCustomization.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExcelCustomization'
    }

    It 'Start-AZTIExcelOrdening.ps1 defines Start-AZSCExcelOrdening' {
        $content = Get-Content (Join-Path $script:StylePath 'Start-AZTIExcelOrdening.ps1') -Raw
        $content | Should -Match 'function\s+Start-AZSCExcelOrdening'
    }
}

# =====================================================================
# SUPPORT.JSON VALIDATION
# =====================================================================
Describe 'Support.json — valid JSON structure' {
    It 'Is valid JSON' {
        $jsonPath = Join-Path $script:StylePath 'Support.json'
        $content = Get-Content $jsonPath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Contains retirement/support data' {
        $jsonPath = Join-Path $script:StylePath 'Support.json'
        $data = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $data | Should -Not -BeNullOrEmpty
    }
}
