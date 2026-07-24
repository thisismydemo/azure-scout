#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Pester tests for src/report/renderers/Export-JsonEvidence.ps1 -- the
    resources-only JSON evidence export (ADO Story AB#396). Uses the repo's
    existing tests/datadump/sample-collect.json fixture as -Collect. No Azure
    connection required.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . "$script:Root/src/report/renderers/Export-JsonEvidence.ps1"

    $script:CollectPath = Join-Path $script:Root 'tests' 'datadump' 'sample-collect.json'
    $script:Collect = Get-Content $script:CollectPath -Raw | ConvertFrom-Json -Depth 100

    # A representative scored-Findings object -- Export-JsonEvidence must
    # never leak any of this into the output (AB#396's core requirement).
    $script:Findings = [pscustomobject]@{
        GeneratedOn = (Get-Date).ToString('o')
        Frameworks  = @([pscustomobject]@{ Framework = 'CAF'; Score = 70 })
        Areas       = @([pscustomobject]@{ Framework = 'CAF'; Area = 'Networking'; Score = 50 })
        Gaps        = @([pscustomobject]@{ Id = 'CAF-NET-01'; Severity = 'high'; Title = 'x' })
        Manual      = @()
        Errors      = @()
        Findings    = @([pscustomobject]@{ Id = 'CAF-NET-01'; Status = 'Fail' })
    }

    $script:OutDir = Join-Path $script:Root 'tests' 'test-output' 'json-evidence'
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force }
}

AfterAll {
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Export-JsonEvidence AB#396' {
    BeforeAll {
        $script:EvidencePath = Export-JsonEvidence -Findings $script:Findings -Collect $script:Collect -OutputPath $script:OutDir
        $script:Raw = Get-Content $script:EvidencePath -Raw
        $script:Parsed = $script:Raw | ConvertFrom-Json -Depth 100
    }

    It 'writes evidence.json into -OutputPath and returns its path' {
        $script:EvidencePath | Should -Exist
        (Split-Path $script:EvidencePath -Leaf) | Should -Be 'evidence.json'
    }

    It 'is well-formed, parseable JSON' {
        { $script:Raw | ConvertFrom-Json -Depth 100 } | Should -Not -Throw
    }

    It 'contains the raw collected resource sections' {
        $script:Parsed.networking.virtualNetworks.Count | Should -Be 3
        $script:Parsed.compute.virtualMachines.Count | Should -Be 3
        $script:Parsed.domains.storage.storageAccounts.Count | Should -Be 2
        $script:Parsed.advisor.Count | Should -Be 10
    }

    It 'contains NO assessment metadata, scores, gaps, or findings from the scored Findings object' {
        foreach ($forbidden in 'GeneratedOn', 'Frameworks', 'Gaps', 'Manual', 'Errors') {
            $script:Parsed.PSObject.Properties.Name | Should -Not -Contain $forbidden
        }
        # 'Findings' as a top-level key would only ever come from the scored
        # object -- Collect has no such key in its own canonical shape.
        $script:Parsed.PSObject.Properties.Name | Should -Not -Contain 'Findings'
    }

    It 'ignores -Findings entirely -- identical output regardless of what is passed' {
        $altDir = Join-Path $script:Root 'tests' 'test-output' 'json-evidence-alt'
        if (Test-Path $altDir) { Remove-Item $altDir -Recurse -Force }
        try {
            $altPath = Export-JsonEvidence -Findings $null -Collect $script:Collect -OutputPath $altDir
            (Get-Content $altPath -Raw) | Should -Be $script:Raw
        }
        finally {
            if (Test-Path $altDir) { Remove-Item $altDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'is deterministic -- re-rendering the same Collect produces byte-identical output' {
        $repeatDir = Join-Path $script:Root 'tests' 'test-output' 'json-evidence-repeat'
        if (Test-Path $repeatDir) { Remove-Item $repeatDir -Recurse -Force }
        try {
            $repeatPath = Export-JsonEvidence -Findings $script:Findings -Collect $script:Collect -OutputPath $repeatDir
            (Get-Content $repeatPath -Raw) | Should -Be $script:Raw
        }
        finally {
            if (Test-Path $repeatDir) { Remove-Item $repeatDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Export-JsonEvidence -- defensive/edge cases' {
    It 'does not throw and emits an empty object when -Collect is $null' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'json-evidence-null'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        try {
            $path = Export-JsonEvidence -Findings $null -Collect $null -OutputPath $dir
            $path | Should -Exist
            $parsed = Get-Content $path -Raw | ConvertFrom-Json -Depth 100
            # @(...) forces array semantics on the Properties collection itself --
            # under Set-StrictMode, dot-accessing .Name on a ZERO-element
            # PSMemberInfoCollection throws (no elements to enumerate a .Name
            # across), rather than returning an empty array as one might expect.
            @($parsed.PSObject.Properties).Count | Should -Be 0
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
