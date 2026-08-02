#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    AB#6892 -- every finding says WHAT WAS SEARCHED, even when nothing was found.

    Phase 0 (pmo/research/baseline/) measured this on three real tenants:

      * 42 of 57 FAILING controls carried zero evidence;
      * no report named a single Azure resource -- 0 `/subscriptions/<guid>` in word/document.xml;
      * three unrelated estates produced documents within 258 bytes of each other.

    The cause is structural, not a renderer defect. An `exists` rule fails precisely BECAUSE its
    query returned nothing, so its evidence list is empty by construction and no renderer can name
    a resource in it.

    What makes such a finding actionable is the SCOPE -- what was looked for, and how many
    candidates there were. These tests pin that every finding carries it.
#>

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $script:RepoRoot 'src/assess/engine/Resolve-JsonPath.ps1')
    . (Join-Path $script:RepoRoot 'src/assess/engine/Invoke-Rule.ps1')

    $script:Collect = [pscustomobject]@{
        storage = @(
            [pscustomobject]@{ id = '/subscriptions/0000/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/sa1'; https = $true }
            [pscustomobject]@{ id = '/subscriptions/0000/resourceGroups/rg1/providers/Microsoft.Storage/storageAccounts/sa2'; https = $false }
        )
        purview = @()
    }
}

Describe 'AB#6892 -- a finding that found nothing still says what it looked for' {

    It 'carries SearchedPath on an exists rule that FAILS with no evidence' {
        # THE case Phase 0 found 42 times. Nothing exists, so Evidence is empty and always will
        # be. Without SearchedPath the reader cannot tell a missing Purview account from a rule
        # that never ran.
        $Rule = @{
            id = 'T-01'; title = 'Purview exists'; severity = 'High'; manual = $false; remediation = 'Fix it'
            query = '$.purview[*]'; assert = @{ type = 'exists' }
        }
        $Finding = Invoke-Rule -Rule $Rule -Collect $script:Collect -Area 'Data' -Framework 'CAF'

        $Finding.Status | Should -Be 'Fail'
        $Finding.EvidenceCount | Should -Be 0
        $Finding.SearchedPath | Should -Be '$.purview[*]'
        $Finding.AssertType | Should -Be 'exists'
    }

    It 'carries SearchedPath on a rule that PASSES too, so the scope is auditable either way' {
        $Rule = @{
            id = 'T-02'; title = 'Storage exists'; severity = 'Low'; manual = $false; remediation = 'Fix it'
            query = '$.storage[*]'; assert = @{ type = 'exists' }
        }
        $Finding = Invoke-Rule -Rule $Rule -Collect $script:Collect -Area 'Data' -Framework 'CAF'

        $Finding.Status | Should -Be 'Pass'
        $Finding.SearchedPath | Should -Be '$.storage[*]'
    }

    It 'reports Denominator as $null when the rule has no denominator, not 0' {
        # $null means "not applicable to this rule". 0 would read as "we looked and found no
        # candidates", which is a different and much stronger claim.
        $Rule = @{
            id = 'T-03'; title = 'Storage exists'; severity = 'Low'; manual = $false; remediation = 'Fix it'
            query = '$.storage[*]'; assert = @{ type = 'exists' }
        }
        $Finding = Invoke-Rule -Rule $Rule -Collect $script:Collect -Area 'Data' -Framework 'CAF'

        $Finding.Denominator | Should -BeNullOrEmpty
    }

    It 'carries the Denominator on a percentage rule, so "N of M" can be rendered' {
        # The reference deliverable's defining property: every risk row carries its supporting
        # number -- "60 of 198 storage accounts", never "storage accounts are misconfigured".
        $Rule = @{
            id = 'T-04'; title = 'HTTPS coverage'; severity = 'High'; manual = $false; remediation = 'Fix it'
            query = '$.storage[?(@.https == true)]'
            assert = @{ type = 'percentageAtLeast'; value = 100; denominatorQuery = '$.storage[*]' }
        }
        $Finding = Invoke-Rule -Rule $Rule -Collect $script:Collect -Area 'Data' -Framework 'CAF'

        $Finding.Denominator | Should -Be 2
        $Finding.EvidenceCount | Should -Be 1
        $Finding.Status | Should -Not -Be 'Pass'
    }
}

Describe 'AB#6892 -- the fields exist on every emission path' {

    It 'declares SearchedPath, AssertType and Denominator on the main finding object' {
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/assess/engine/Invoke-Rule.ps1') -Raw

        $Source | Should -Match 'SearchedPath\s*=\s*\$searchedPath'
        $Source | Should -Match 'AssertType\s*=\s*\$assertType'
        $Source | Should -Match 'Denominator\s*=\s*\$denominator'
    }

    It 'initialises $denominator before the early returns can run' {
        # The gate-failure, query-failure and not-assessed paths build their own object and
        # return early. $denominator must already exist or those paths throw under StrictMode.
        $Source = Get-Content -LiteralPath (Join-Path $script:RepoRoot 'src/assess/engine/Invoke-Rule.ps1') -Raw

        $InitIndex = $Source.IndexOf('$denominator = $null')
        $InitIndex | Should -BeGreaterThan 0

        $FirstReturn = $Source.IndexOf("Status = 'Error'")
        $InitIndex | Should -BeLessThan $FirstReturn -Because 'the early returns run after this point'
    }

    It 'does not throw for a rule whose query fails' {
        $Rule = @{
            id = 'T-05'; title = 'Bad query'; severity = 'Low'; manual = $false; remediation = 'Fix it'
            query = '$.nope['; assert = @{ type = 'exists' }
        }
        { Invoke-Rule -Rule $Rule -Collect $script:Collect -Area 'Data' -Framework 'CAF' 3>$null } |
            Should -Not -Throw
    }
}
