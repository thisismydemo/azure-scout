#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for OutputFormat parameter and report generation functions.

.DESCRIPTION
    Validates:
      - The -OutputFormat ValidateSet on Invoke-AzureScout (All/Excel/Json/Markdown/AsciiDoc/MD/Adoc/PowerBI)
      - Export-AZSCMarkdownReport function exists and generates a .md file
      - Export-AZSCAsciiDocReport function exists and generates a .adoc file
      - Export-AZSCPowerBIReport function exists and generates a CSV bundle
    No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   21 — Markdown and AsciiDoc Output
#>

BeforeAll {
    $script:ModuleRoot      = Split-Path -Parent $PSScriptRoot
    $script:InvokeScript    = Join-Path $script:ModuleRoot 'Modules' 'Public'   'PublicFunctions' 'Invoke-AzureScout.ps1'
    $script:MarkdownScript  = Join-Path $script:ModuleRoot 'Modules' 'Private'  'Reporting'       'Export-AZTIMarkdownReport.ps1'
    $script:AsciiDocScript  = Join-Path $script:ModuleRoot 'Modules' 'Private'  'Reporting'       'Export-AZTIAsciiDocReport.ps1'
    $script:PowerBIScript   = Join-Path $script:ModuleRoot 'Modules' 'Private'  'Reporting'       'Export-AZSCPowerBIReport.ps1'
    $script:TempDir         = Join-Path $env:TEMP 'AZSC_OutputFormatTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # Dot-source the public function so we can inspect its parameters
    . $script:InvokeScript
    $script:Cmd = Get-Command -Name Invoke-AzureScout -ErrorAction SilentlyContinue

    # Dot-source the reporting helpers
    . $script:MarkdownScript
    . $script:AsciiDocScript
    . $script:PowerBIScript

    # Minimal mock SmaResources for report generation
    $script:MockSmaResources = @{
        VirtualMachine = @(
            [ordered]@{ Name = 'vm-test-01'; 'Subscription' = 'Test Dev'; 'Resource Group' = 'rg-test'; 'Location' = 'eastus'; 'OS' = 'Windows'; 'Size' = 'Standard_D2s_v3'; 'Status' = 'Running' }
        )
        VirtualNetwork = @(
            [ordered]@{ Name = 'vnet-test'; 'Subscription' = 'Test Dev'; 'Resource Group' = 'rg-test'; 'Location' = 'eastus'; 'Address Space' = '10.0.0.0/16' }
        )
    }

    $script:MockSubscriptions = @(
        [PSCustomObject]@{ Id = 'sub-00000001'; Name = 'Test Dev' }
    )

    # Build a minimal ReportCache folder with a stub JSON file for Markdown/AsciiDoc to read
    $script:CacheDir = Join-Path $script:TempDir 'cache'
    New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null

    $cacheData = @{
        VirtualMachine = $script:MockSmaResources.VirtualMachine
        VirtualNetwork = $script:MockSmaResources.VirtualNetwork
    }
    $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:CacheDir 'inventory.json') -Encoding UTF8
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# OutputFormat parameter metadata
# ===================================================================
Describe 'OutputFormat Parameter — Metadata' {
    It 'Invoke-AzureScout function is available' {
        $script:Cmd | Should -Not -BeNullOrEmpty
    }

    It 'OutputFormat parameter exists' {
        $script:Cmd.Parameters.ContainsKey('OutputFormat') | Should -BeTrue
    }

    It 'OutputFormat parameter is [string] type' {
        $script:Cmd.Parameters['OutputFormat'].ParameterType | Should -Be ([string])
    }

    It 'OutputFormat ValidateSet contains "All"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'All'
    }

    It 'OutputFormat ValidateSet contains "Excel"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Excel'
    }

    It 'OutputFormat ValidateSet contains "Json"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Json'
    }

    It 'OutputFormat ValidateSet contains "Markdown"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Markdown'
    }

    It 'OutputFormat ValidateSet contains "AsciiDoc"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'AsciiDoc'
    }

    It 'OutputFormat ValidateSet contains short alias "MD"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'MD'
    }

    It 'OutputFormat ValidateSet contains short alias "Adoc"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'Adoc'
    }

    It 'OutputFormat ValidateSet contains "PowerBI"' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues | Should -Contain 'PowerBI'
    }

    It 'OutputFormat ValidateSet has exactly 8 values' {
        $vs = $script:Cmd.Parameters['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $vs.ValidValues.Count | Should -Be 8
    }

    It 'OutputFormat default value is "All"' {
        $default = $script:Cmd.Parameters['OutputFormat'].DefaultValue
        if ($null -eq $default) {
            Set-ItResult -Skipped -Because 'Default value not accessible via reflection'
        } else {
            $default | Should -Be 'All'
        }
    }
}

# ===================================================================
# Reporting function existence
# ===================================================================
Describe 'Report Generation Functions Exist' {
    It 'Export-AZTIMarkdownReport.ps1 file exists' {
        $script:MarkdownScript | Should -Exist
    }

    It 'Export-AZTIAsciiDocReport.ps1 file exists' {
        $script:AsciiDocScript | Should -Exist
    }

    It 'Export-AZSCMarkdownReport function is loaded after dot-source' {
        Get-Command -Name Export-AZSCMarkdownReport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Export-AZSCAsciiDocReport function is loaded after dot-source' {
        Get-Command -Name Export-AZSCAsciiDocReport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Export-AZSCPowerBIReport.ps1 file exists' {
        $script:PowerBIScript | Should -Exist
    }

    It 'Export-AZSCPowerBIReport function is loaded after dot-source' {
        Get-Command -Name Export-AZSCPowerBIReport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

# ===================================================================
# Markdown report generation
# ===================================================================
Describe 'Export-AZSCMarkdownReport — Output File Generation' {
    BeforeAll {
        $script:MdFile = Join-Path $script:TempDir 'AzureScout_Report.xlsx'  # function changes extension to .md
    }

    It 'Export-AZSCMarkdownReport does not throw with minimal inputs' {
        {
            Export-AZSCMarkdownReport `
                -ReportCache $script:CacheDir `
                -File        $script:MdFile `
                -TenantID    'tenant-test-001' `
                -Subscriptions $script:MockSubscriptions `
                -Scope       'ArmOnly'
        } | Should -Not -Throw
    }

    It 'Markdown .md file is created' {
        $mdOutput = [System.IO.Path]::ChangeExtension($script:MdFile, '.md')
        $mdOutput | Should -Exist
    }

    It 'Markdown file starts with "# Azure Scout Report"' {
        $mdOutput = [System.IO.Path]::ChangeExtension($script:MdFile, '.md')
        $first = Get-Content -Path $mdOutput | Select-Object -First 1
        $first | Should -Be '# Azure Scout Report'
    }

    It 'Markdown file contains Tenant ID entry' {
        $mdOutput = [System.IO.Path]::ChangeExtension($script:MdFile, '.md')
        $content  = Get-Content -Path $mdOutput -Raw
        $content  | Should -Match 'Tenant ID'
    }

    It 'Markdown file contains Generated date entry' {
        $mdOutput = [System.IO.Path]::ChangeExtension($script:MdFile, '.md')
        $content  = Get-Content -Path $mdOutput -Raw
        $content  | Should -Match 'Generated'
    }
}

# ===================================================================
# AsciiDoc report generation
# ===================================================================
Describe 'Export-AZSCAsciiDocReport — Output File Generation' {
    BeforeAll {
        $script:AdocFile = Join-Path $script:TempDir 'AzureScout_Report_adoc.xlsx'
    }

    It 'Export-AZSCAsciiDocReport does not throw with minimal inputs' {
        {
            Export-AZSCAsciiDocReport `
                -ReportCache $script:CacheDir `
                -File        $script:AdocFile `
                -TenantID    'tenant-test-001' `
                -Subscriptions $script:MockSubscriptions `
                -Scope       'ArmOnly'
        } | Should -Not -Throw
    }

    It 'AsciiDoc .adoc file is created' {
        $adocOutput = [System.IO.Path]::ChangeExtension($script:AdocFile, '.adoc')
        $adocOutput | Should -Exist
    }

    It 'AsciiDoc file contains document title marker (= )' {
        $adocOutput = [System.IO.Path]::ChangeExtension($script:AdocFile, '.adoc')
        $content = Get-Content -Path $adocOutput -Raw
        $content | Should -Match '= Azure Scout'
    }
}

# ===================================================================
# OutputFormat routing in Invoke-AzureScout source
# ===================================================================
Describe 'OutputFormat routing logic in Invoke-AzureScout source' {
    BeforeAll {
        $script:FunctionSource = Get-Content -Path $script:InvokeScript -Raw
    }

    It 'Source contains Markdown format routing' {
        $script:FunctionSource | Should -Match "Markdown|'MD'"
    }

    It 'Source contains AsciiDoc format routing' {
        $script:FunctionSource | Should -Match "AsciiDoc|'Adoc'"
    }

    It 'Source contains JSON export routing' {
        $script:FunctionSource | Should -Match "Json"
    }

    It 'Source contains Excel export routing (Export-Excel or Start-AZTIExcelJob)' {
        $script:FunctionSource | Should -Match 'Excel|ExcelJob'
    }

    It 'Source contains Power BI format routing' {
        $script:FunctionSource | Should -Match 'PowerBI'
    }
}

# ===================================================================
# Power BI CSV report generation
# ===================================================================
Describe 'Export-AZSCPowerBIReport — Output File Generation' {
    BeforeAll {
        $script:PbiBaseFile = Join-Path $script:TempDir 'AzureScout_PBI_Report.xlsx'

        # Build a minimal ReportCache that matches the InventoryModules folder structure
        $script:PbiCacheDir = Join-Path $script:TempDir 'pbi-cache'
        if (Test-Path $script:PbiCacheDir) { Remove-Item $script:PbiCacheDir -Recurse -Force }
        New-Item -ItemType Directory -Path $script:PbiCacheDir -Force | Out-Null

        # Create a Compute.json cache file matching the Compute folder modules
        $computeCache = @{
            VirtualMachine = @(
                [ordered]@{ Name = 'vm-pbi-01'; Subscription = 'Test Dev'; 'Resource Group' = 'rg-pbi'; Location = 'eastus'; 'Resource U' = 1 }
            )
        }
        $computeCache | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:PbiCacheDir 'Compute.json') -Encoding UTF8

        # Create an Identity.json cache file for Entra
        $identityCache = @{
            Users = @(
                [ordered]@{ 'Display Name' = 'Test User'; 'User Principal Name' = 'test@contoso.com'; 'Resource U' = 1 }
            )
        }
        $identityCache | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $script:PbiCacheDir 'Identity.json') -Encoding UTF8
    }

    It 'Export-AZSCPowerBIReport does not throw with minimal inputs' {
        {
            Export-AZSCPowerBIReport `
                -ReportCache $script:PbiCacheDir `
                -File        $script:PbiBaseFile `
                -TenantID    'tenant-pbi-001' `
                -Subscriptions $script:MockSubscriptions `
                -Scope       'All'
        } | Should -Not -Throw
    }

    It 'PowerBI output directory is created' {
        $pbiDir = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI'
        $pbiDir | Should -Exist
    }

    It '_metadata.csv is created' {
        $metaFile = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI' '_metadata.csv'
        $metaFile | Should -Exist
    }

    It '_metadata.csv contains TenantId' {
        $metaFile = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI' '_metadata.csv'
        $content = Import-Csv $metaFile
        ($content | Where-Object { $_.Property -eq 'TenantId' }).Value | Should -Be 'tenant-pbi-001'
    }

    It 'Subscriptions.csv is created' {
        $subsFile = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI' 'Subscriptions.csv'
        $subsFile | Should -Exist
    }

    It '_relationships.json is created with valid JSON' {
        $relFile = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI' '_relationships.json'
        $relFile | Should -Exist
        { Get-Content $relFile -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'At least one Resources_*.csv file is created' {
        $pbiDir = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI'
        $csvFiles = Get-ChildItem -Path $pbiDir -Filter 'Resources_*.csv' -ErrorAction SilentlyContinue
        @($csvFiles).Count | Should -BeGreaterThan 0
    }

    It 'At least one Entra_*.csv file is created' {
        $pbiDir = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI'
        $csvFiles = Get-ChildItem -Path $pbiDir -Filter 'Entra_*.csv' -ErrorAction SilentlyContinue
        @($csvFiles).Count | Should -BeGreaterThan 0
    }

    It 'Resource CSV files contain _Category and _Module columns' {
        $pbiDir = Join-Path (Split-Path $script:PbiBaseFile -Parent) 'PowerBI'
        $csvFile = Get-ChildItem -Path $pbiDir -Filter 'Resources_*.csv' | Select-Object -First 1
        $data = Import-Csv $csvFile.FullName
        $data[0].PSObject.Properties.Name | Should -Contain '_Category'
        $data[0].PSObject.Properties.Name | Should -Contain '_Module'
    }
}
