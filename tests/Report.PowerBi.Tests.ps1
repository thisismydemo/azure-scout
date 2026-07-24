#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Export-PowerBi (.pbit generation) AB#5046' {
    BeforeAll {
        . "$PSScriptRoot/../src/report/renderers/Export-PowerBi.ps1"
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $script:Findings = [pscustomobject]@{
            Areas      = @(
                [pscustomobject]@{ Framework = 'CAF'; Area = 'Governance'; Score = 72 }
                [pscustomobject]@{ Framework = 'WAF'; Area = 'Security';   Score = 64 }
            )
            Frameworks = @([pscustomobject]@{ Framework = 'CAF'; Score = 70 })
            Gaps       = @([pscustomobject]@{ Framework = 'CAF'; Area = 'Governance'; Id = 'CAF-GOV-01'; Severity = 'High'; Title = 'x' })
            Findings   = @(
                [pscustomobject]@{ Framework = 'CAF'; Area = 'Governance'; Id = 'CAF-GOV-01'; Severity = 'High'; Status = 'Fail'; EvidenceCount = 2; Title = 'x'; Remediation = 'y'; Manual = $false }
            )
        }
        $script:Out = Join-Path ([System.IO.Path]::GetTempPath()) ("pbit-pester-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        Export-PowerBi -Findings $script:Findings -Collect ([pscustomobject]@{}) -OutputPath $script:Out | Out-Null
        $script:PbiDir = Join-Path $script:Out 'powerbi'
    }
    AfterAll {
        if ($script:Out -and (Test-Path $script:Out)) { Remove-Item $script:Out -Recurse -Force }
    }

    It 'emits the four star-schema CSVs' {
        foreach ($csv in 'fact_area_scores', 'fact_framework', 'dim_gaps', 'fact_findings') {
            Join-Path $script:PbiDir "$csv.csv" | Should -Exist
        }
    }

    It 'generates report.pbit' {
        Join-Path $script:PbiDir 'report.pbit' | Should -Exist
    }

    It 'produces a report.pbit containing all required OPC parts' {
        $pbit = Join-Path $script:PbiDir 'report.pbit'
        $zip = [System.IO.Compression.ZipFile]::OpenRead($pbit)
        try { $names = @($zip.Entries.FullName) } finally { $zip.Dispose() }
        foreach ($part in '[Content_Types].xml', 'Version', 'DataModelSchema', 'Mashup', 'Report/Layout') {
            $names | Should -Contain $part
        }
    }

    It 'writes a README describing the star schema' {
        Join-Path $script:PbiDir 'README.txt' | Should -Exist
        (Get-Content (Join-Path $script:PbiDir 'README.txt') -Raw) | Should -Match 'star schema'
    }
}
