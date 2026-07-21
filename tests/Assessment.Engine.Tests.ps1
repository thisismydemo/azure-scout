#Requires -Version 7.0
#Requires -Modules Pester

<#
    Smoke tests for the assessment engine (src/assess). Validates the scoring
    math and assert semantics that the audit flagged (AB#5087/#5088/#5089) plus
    the JSONPath null-path handling. Pure-logic tests — no Azure connection.
#>

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . "$root/src/assess/engine/Resolve-JsonPath.ps1"
    . "$root/src/assess/engine/Invoke-Rule.ps1"
    . "$root/src/assess/engine/Get-Score.ps1"

    function New-Finding {
        param($Framework, $Area, $Status, $Severity = 'medium', $Weight = 1.0)
        [pscustomobject]@{
            Id = 'X'; Title = 't'; Framework = $Framework; Area = $Area; Severity = $Severity
            Status = $Status; EvidenceCount = 0; Evidence = @(); Remediation = 'r'; Manual = $false
            AreaWeight = $Weight
        }
    }
}

Describe 'Resolve-JsonPath' {
    It 'returns empty for a null/blank path (manual rules)' {
        (Resolve-JsonPath -InputObject ([pscustomobject]@{ a = 1 }) -Path '').Count | Should -Be 0
    }
    It 'matches a scalar filter without .length' {
        $obj = [pscustomobject]@{ networking = [pscustomobject]@{ virtualNetworks = @(
            [pscustomobject]@{ name = 'a'; peeringCount = 2 }, [pscustomobject]@{ name = 'b'; peeringCount = 0 }) } }
        (Resolve-JsonPath -InputObject $obj -Path '$.networking.virtualNetworks[?(@.peeringCount > 0)]').Count | Should -Be 1
    }
}

Describe 'Get-Score' {
    It 'excludes Manual and Unknown from the denominator but surfaces the counts' {
        $f = @(
            New-Finding CAF 'Net' 'Pass'
            New-Finding CAF 'Net' 'Fail'
            New-Finding CAF 'Net' 'Manual'
            New-Finding CAF 'Net' 'Unknown'
        )
        $s = Get-Score -Findings $f
        $area = $s.Areas | Where-Object Area -eq 'Net'
        $area.Score   | Should -Be 50      # 1 pass / 2 scorable
        $area.Manual  | Should -Be 1
        $area.Unknown | Should -Be 1
    }

    It 'weights the framework score by AreaWeight, not a flat mean' {
        $f = @(
            (New-Finding CAF 'Big'   'Fail' 'high' 3.0)   # area score 0, weight 3
            (New-Finding CAF 'Small' 'Pass' 'low'  1.0)   # area score 100, weight 1
        )
        $s = Get-Score -Findings $f
        # weighted: (0*3 + 100*1)/4 = 25, not the flat mean of 50
        ($s.Frameworks | Where-Object Framework -eq 'CAF').Score | Should -Be 25
    }

    It 'sorts unknown/missing severity LAST in the gap list' {
        $f = @(
            (New-Finding CAF 'A' 'Fail' 'bogus')
            (New-Finding CAF 'B' 'Fail' 'high')
        )
        $s = Get-Score -Findings $f
        $s.Gaps[0].Severity | Should -Be 'high'
    }
}

Describe 'Invoke-Rule' {
    It 'marks a rule Error (not Pass) when its query throws' {
        $rule = [pscustomobject]@{ id = 'E1'; title = 't'; severity = 'high'; manual = $false
            query = '$.bad[?(@.x.length > 0)]'; assert = [pscustomobject]@{ type = 'countEquals'; value = 0 }; remediation = 'r' }
        $obj = [pscustomobject]@{ bad = @([pscustomobject]@{ x = @(1) }) }
        (Invoke-Rule -Rule $rule -Collect $obj -Area 'A' -Framework 'CAF').Status | Should -Be 'Error'
    }
}
