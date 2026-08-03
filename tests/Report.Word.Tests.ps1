#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Pester tests for src/report/renderers/Export-Word.ps1 -- the OpenXML-SDK
    Word (.docx) renderer (ADO Story AB#333). No Azure connection, no external
    network access required (DocumentFormat.OpenXml is acquired once via
    dotnet/NuGet and cached under output/.tools -- see the renderer's own
    Import-ScoutDocxOpenXmlAssembly for that acquire-once pattern, which is
    shared/reused by Export-Pptx.ps1's identical cache directory).
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . "$script:Root/src/assess/engine/Get-Score.ps1"
    . "$script:Root/src/report/renderers/Export-Word.ps1"

    function New-WordTestFinding {
        param($Id, $Framework, $Area, $Status, $Severity = 'medium', $Weight = 1.0)
        [pscustomobject]@{
            Id = $Id; Title = "$Id title text for the report"; Framework = $Framework; Area = $Area; Severity = $Severity
            Status = $Status; EvidenceCount = 2; Evidence = @(); Remediation = "Remediate $Id."
            Manual = ($Status -eq 'Manual'); AreaWeight = $Weight
        }
    }

    # A mix of statuses/severities across two frameworks/areas, including
    # deliberately blank/null/unrecognized severities on Fail rows so the
    # AB#5089-style defensive sort/label guard is actually exercised
    # end-to-end through Get-Score -> Export-Word, same as Export-Pptx's tests.
    $script:Findings = @(
        (New-WordTestFinding 'CAF-NET-01' 'CAF' 'Networking' 'Pass' 'low')
        (New-WordTestFinding 'CAF-NET-02' 'CAF' 'Networking' 'Fail' 'high')
        (New-WordTestFinding 'CAF-NET-03' 'CAF' 'Networking' 'Partial' 'medium')
        (New-WordTestFinding 'WAF-SEC-01' 'WAF' 'Security' 'Fail' $null)
        (New-WordTestFinding 'WAF-SEC-02' 'WAF' 'Security' 'Fail' '')
        (New-WordTestFinding 'WAF-SEC-03' 'WAF' 'Security' 'Fail' 'bogus-severity')
        (New-WordTestFinding 'WAF-SEC-04' 'WAF' 'Security' 'Manual')
        (New-WordTestFinding 'WAF-SEC-05' 'WAF' 'Security' 'Unknown')
    )
    $script:Scored = Get-Score -Findings $script:Findings

    $script:Collect = [pscustomobject]@{
        _meta = [pscustomobject]@{ scope = 'ArmOnly'; managementGroupId = 'mg-test-01' }
    }

    $script:OutDir = Join-Path $script:Root 'tests' 'test-output' 'word'
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force }

    # Extracts word/document.xml as raw text -- the rendered runs/text nodes
    # this file writes are plain ASCII in every test fixture below, so a
    # straight substring/regex match against the XML source is sufficient
    # (mirrors the zip-entry approach Test-PptxFromDataDump.ps1 uses).
    function Get-DocxDocumentXml {
        param([string]$Path)
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $ms = [System.IO.MemoryStream]::new($bytes)
        $zip = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)
        try {
            $entry = $zip.GetEntry('word/document.xml')
            if (-not $entry) { return $null }
            $reader = [System.IO.StreamReader]::new($entry.Open())
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally {
            $zip.Dispose()
            $ms.Dispose()
        }
    }

    function Get-DocxValidationIssues {
        param([string]$Path)
        $doc = [DocumentFormat.OpenXml.Packaging.WordprocessingDocument]::Open($Path, $false)
        try {
            # Office2013 target: the parameterless OpenXmlValidator() defaults to
            # an older schema variant that (incorrectly, for a modern renderer)
            # flags w:tblLook's firstRow/lastRow/... boolean attributes as
            # undeclared even though every version of Word since 2010 emits them.
            $validator = New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator ([DocumentFormat.OpenXml.FileFormatVersions]::Office2013)
            return @($validator.Validate($doc))
        }
        finally {
            $doc.Dispose()
        }
    }
}

AfterAll {
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Export-Word -- basic document structure AB#333' {
    BeforeAll {
        $script:DocxPath = Export-Word -Findings $script:Scored -Collect $script:Collect -OutputPath $script:OutDir
        $script:Xml = Get-DocxDocumentXml -Path $script:DocxPath
    }

    It 'writes assessment_report.docx into -OutputPath and returns its path' {
        $script:DocxPath | Should -Exist
        (Split-Path $script:DocxPath -Leaf) | Should -Be 'assessment_report.docx'
    }

    It 'is a valid OPC/zip package with word/document.xml present' {
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        $zip = [System.IO.Compression.ZipFile]::OpenRead($script:DocxPath)
        try {
            $entries = @($zip.Entries | Select-Object -ExpandProperty FullName)
            $entries | Should -Contain 'word/document.xml'
            $entries | Should -Contain '[Content_Types].xml'
        }
        finally { $zip.Dispose() }
    }

    It 'passes full OpenXML schema validation with zero issues' {
        # @() wrap is load-bearing: a zero-issue validation result collapses a
        # bare assignment to $null (the same PowerShell pipeline-unrolling
        # behavior documented throughout the renderer itself), and $null.Count
        # throws under Set-StrictMode -Version Latest.
        $issues = @(Get-DocxValidationIssues -Path $script:DocxPath)
        if ($issues.Count -gt 0) {
            Write-Host ($issues | Select-Object -First 5 | ForEach-Object { "$($_.Description) [$($_.Path.XPath)]" } | Out-String)
        }
        $issues.Count | Should -Be 0
    }

    It 'renders a cover title and the CAF/WAF framework scores in the executive summary' {
        $script:Xml | Should -Match 'Azure Landing Zone Assessment'
        $script:Xml | Should -Match 'Executive Summary'
        $script:Xml | Should -Match 'CAF'
        $script:Xml | Should -Match 'WAF'
    }

    It 'renders a per-area findings section for every scored area, with each finding Id' {
        $script:Xml | Should -Match 'Findings by Area'
        $script:Xml | Should -Match 'Networking'
        $script:Xml | Should -Match 'Security'
        foreach ($id in $script:Findings.Id) {
            # Pre-computing the pattern into a variable, rather than inlining
            # [regex]::Escape(...) as the -Match argument, sidesteps a
            # PowerShell argument-parsing ambiguity where the static-method
            # call gets split across -Match/-Because instead of evaluated
            # as one expression.
            $pattern = [regex]::Escape($id)
            $script:Xml | Should -Match $pattern
        }
    }

    It 'renders the Prioritized Gaps section with every Fail finding title' {
        $script:Xml | Should -Match 'Prioritized Gaps'
        foreach ($f in ($script:Findings | Where-Object Status -eq 'Fail')) {
            $pattern = [regex]::Escape($f.Title)
            $script:Xml | Should -Match $pattern
        }
    }

    It 'renders the Manual Review Worklist section with the manual finding' {
        $script:Xml | Should -Match 'Manual Review Worklist'
        $pattern = [regex]::Escape('WAF-SEC-04 title text for the report')
        $script:Xml | Should -Match $pattern
    }

    It 'never throws on null/blank severity and labels those UNKNOWN (AB#5089-style guard)' {
        # WAF-SEC-01 (null severity) and WAF-SEC-02 (blank severity) are Fail
        # rows -- Get-ScoutDocxSeverityLabel must degrade only these truly
        # empty severities to the literal string UNKNOWN, and each shows up
        # in both the per-area findings table and the Prioritized Gaps table,
        # so it must appear (case-sensitively) at least 4 times. -cmatch (not
        # the default case-insensitive -match) so this can't accidentally
        # pass on WAF-SEC-05's unrelated Status="Unknown" table cell text.
        ([regex]::Matches($script:Xml, 'UNKNOWN')).Count | Should -BeGreaterOrEqual 4
    }

    It 'passes an unrecognized (but non-empty) severity through uppercased rather than forcing it to UNKNOWN' {
        # WAF-SEC-03's severity is the literal string 'bogus-severity' -- not
        # null/blank, so Get-ScoutDocxSeverityLabel must uppercase-passthrough
        # it (mirroring Export-Pptx.ps1's Get-ScoutSeverityLabel exactly),
        # while Get-ScoutDocxSeverityRank still sorts it LAST (rank 99,
        # covered by the dedicated unit test below).
        $script:Xml | Should -Match 'BOGUS-SEVERITY'
    }
}

Describe 'Export-Word -- table header repeat (AB#333 long-table usability)' {
    It 'marks every table header row with w:tblHeader so it repeats across page breaks' {
        $xml = Get-DocxDocumentXml -Path $script:DocxPath
        ([regex]::Matches($xml, '<w:tblHeader')).Count | Should -BeGreaterThan 0
    }
}

Describe 'Export-Word -- prioritized gaps capping and honesty note' {
    BeforeAll {
        $script:ManyGapFindings = 1..60 | ForEach-Object {
            New-WordTestFinding "GAP-$($_.ToString('000'))" 'CAF' 'Networking' 'Fail' 'high'
        }
        $script:ManyGapScored = Get-Score -Findings $script:ManyGapFindings
        $script:ManyGapDir = Join-Path $script:Root 'tests' 'test-output' 'word-manygaps'
        if (Test-Path $script:ManyGapDir) { Remove-Item $script:ManyGapDir -Recurse -Force }
    }

    AfterAll {
        if (Test-Path $script:ManyGapDir) { Remove-Item $script:ManyGapDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'caps the Prioritized Gaps table and honestly notes how many were left out' {
        $path = Export-Word -Findings $script:ManyGapScored -Collect $null -OutputPath $script:ManyGapDir
        $xml = Get-DocxDocumentXml -Path $path
        $xml | Should -Match 'more not shown'
        # 60 Fail findings, capped at 50 -- 10 should be reported as truncated.
        $xml | Should -Match '\+10 more not shown'
    }
}

Describe 'Export-Word -- edge cases' {
    It 'does not throw on an empty Findings set and still produces a schema-valid docx' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'word-empty'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        try {
            $emptyScored = Get-Score -Findings @()
            $path = Export-Word -Findings $emptyScored -Collect $null -OutputPath $dir
            $path | Should -Exist
            (Split-Path $path -Leaf) | Should -Be 'assessment_report.docx'
            @(Get-DocxValidationIssues -Path $path).Count | Should -Be 0
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'does not throw when Collect is $null' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'word-nocollect'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        try {
            { Export-Word -Findings $script:Scored -Collect $null -OutputPath $dir } | Should -Not -Throw
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Export-Word -- non-fatal on failure (AB#333)' {
    It 'writes a clearly-labeled HTML fallback instead of throwing when rendering fails' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'word-forcefail'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        $savedFn = ${function:New-ScoutDocxRun}
        try {
            # Force a real failure deep inside the renderer (not a contrived
            # dead-code path) by breaking a helper every content section calls.
            Set-Item function:New-ScoutDocxRun -Value { throw 'forced failure for fallback test' }
            $allOutput = @(Export-Word -Findings $script:Scored -Collect $script:Collect -OutputPath $dir 3>&1)
            $path = $allOutput | Where-Object { $_ -is [string] } | Select-Object -First 1
            $warnings = $allOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

            $path | Should -Exist
            (Split-Path $path -Leaf) | Should -Be 'assessment_word_fallback.html'
            $content = Get-Content $path -Raw
            $content | Should -Match 'Word \(\.docx\) generation failed'
            $content | Should -Match 'forced failure for fallback test'
            $content | Should -Match '__FINDINGS__'
            @($warnings) | Where-Object { $_.Message -match 'docx generation failed' } | Should -Not -BeNullOrEmpty
        }
        finally {
            Set-Item function:New-ScoutDocxRun -Value $savedFn
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Get-ScoutDocxSeverityLabel / Get-ScoutDocxSeverityRank (unit)' {
    It 'labels null/blank severities as UNKNOWN, uppercase-passes-through anything else, and never throws' {
        Get-ScoutDocxSeverityLabel $null | Should -Be 'UNKNOWN'
        Get-ScoutDocxSeverityLabel '' | Should -Be 'UNKNOWN'
        # Mirrors Export-Pptx.ps1's Get-ScoutSeverityLabel exactly: a
        # non-empty-but-unrecognized severity is NOT coerced to UNKNOWN, it's
        # uppercase-passed-through (only Rank, tested below, sorts it last).
        Get-ScoutDocxSeverityLabel 'not-a-real-severity' | Should -Be 'NOT-A-REAL-SEVERITY'
        Get-ScoutDocxSeverityLabel 'high' | Should -Be 'HIGH'
    }

    It 'ranks unknown/missing severity LAST (99), never throws' {
        Get-ScoutDocxSeverityRank $null | Should -Be 99
        Get-ScoutDocxSeverityRank 'bogus' | Should -Be 99
        Get-ScoutDocxSeverityRank 'high' | Should -Be 0
        Get-ScoutDocxSeverityRank 'medium' | Should -Be 1
        Get-ScoutDocxSeverityRank 'low' | Should -Be 2
    }
}

Describe 'AB#6862/AB#6892 -- the gaps table carries its supporting number (clause W-14)' {

    BeforeAll {
        . (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/report/renderers/Export-Word.ps1')
    }

    It 'says "<Expected>" for EvidenceCount=<Count>, Denominator=<Denom>' -ForEach @(
        # The case Phase 0 found on 42 of 57 FAILING controls. An `exists` rule fails precisely
        # because its query matched nothing, so there is no resource to name -- but an empty cell
        # is indistinguishable from a rule that never ran.
        @{ Count = 0;  Denom = $null; Expected = 'None found' }
        @{ Count = 1;  Denom = $null; Expected = '1 resource' }
        @{ Count = 7;  Denom = $null; Expected = '7 resources' }
        # The reference deliverable's defining property: "60 of 198 storage accounts".
        @{ Count = 17; Denom = 198;   Expected = '17 of 198' }
        # Denominator 0 is not a usable ratio -- fall back rather than print "3 of 0".
        @{ Count = 3;  Denom = 0;     Expected = '3 resources' }
    ) {
        $Gap = [pscustomobject]@{ EvidenceCount = $Count; Denominator = $Denom }
        Get-ScoutDocxEvidenceSummary $Gap | Should -Be $Expected
    }

    It 'returns empty, without throwing, for a finding carrying no EvidenceCount' {
        # Older findings.json files and hand-built fixtures predate AB#6892.
        $Gap = [pscustomobject]@{ Title = 'no count here' }
        { Get-ScoutDocxEvidenceSummary $Gap } | Should -Not -Throw
        Get-ScoutDocxEvidenceSummary $Gap | Should -Be ''
    }

    It 'declares Evidence as the fourth column of the prioritized gaps table' {
        $Source = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/report/renderers/Export-Word.ps1') -Raw
        $Source | Should -Match "foreach \(\`$h in 'Severity', 'Area', 'Gap', 'Evidence'\)"
        $Source | Should -Match 'Get-ScoutDocxEvidenceSummary \$gap'
    }
}

Describe 'AB#6874 -- the document has real Word styles (clauses W-01, W-02)' {

    BeforeAll {
        $script:StyleDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scout-styles-" + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:StyleDir -Force
        # The suite's shared fixture, built in the top-level BeforeAll.
        Export-Word -Findings ([pscustomobject]@{ Findings = $script:Findings }) -Collect $null -OutputPath $script:StyleDir 3>$null
        $script:StyleDocx = (Get-ChildItem -Path $script:StyleDir -Filter '*.docx' | Select-Object -First 1).FullName

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($script:StyleDocx)
        try {
            $script:PartNames = @($zip.Entries | ForEach-Object { $_.FullName })
            $entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
            $reader = [System.IO.StreamReader]::new($entry.Open())
            $script:DocXml = $reader.ReadToEnd()
            $reader.Close()
            $styleEntry = $zip.Entries | Where-Object { $_.FullName -eq 'word/styles.xml' }
            if ($styleEntry) {
                $sr = [System.IO.StreamReader]::new($styleEntry.Open())
                $script:StylesXml = $sr.ReadToEnd()
                $sr.Close()
            }
        }
        finally { $zip.Dispose() }
    }

    AfterAll {
        if ($script:StyleDir -and (Test-Path $script:StyleDir)) {
            Remove-Item $script:StyleDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'W-01: the package contains a styles part' {
        # Phase 0 measured a THREE-part package: _rels, [Content_Types], document.xml. The
        # absence of this part is the root formatting defect -- no styles means no navigation
        # pane, no TOC field and no rebranding.
        $script:PartNames | Should -Contain 'word/styles.xml'
    }

    It 'W-01: it declares Heading1, Heading2 and Heading3' {
        foreach ($Id in 'Heading1', 'Heading2', 'Heading3') {
            $script:StylesXml | Should -Match "w:styleId=`"$Id`""
        }
    }

    It 'W-01: each heading style carries an outline level, which is what builds the nav pane' {
        @([regex]::Matches($script:StylesXml, 'w:outlineLvl')).Count | Should -BeGreaterOrEqual 3
    }

    It 'W-02: headings in the body reference a declared style' {
        # The measured failure was 0 of 1,803 paragraphs carrying a pStyle.
        @([regex]::Matches($script:DocXml, 'w:pStyle')).Count | Should -BeGreaterThan 0
        $script:DocXml | Should -Match 'w:val="Heading1"'
    }

    It 'every style id referenced from the body is actually declared in the styles part' {
        # A dangling pStyle renders as Normal and silently loses the outline level -- the same
        # symptom as having no styles at all, but harder to spot.
        $Referenced = @([regex]::Matches($script:DocXml, 'w:pStyle w:val="(?<id>[^"]+)"') |
            ForEach-Object { $_.Groups['id'].Value } | Sort-Object -Unique)

        $Referenced.Count | Should -BeGreaterThan 0
        foreach ($Id in $Referenced) {
            $script:StylesXml | Should -Match "w:styleId=`"$Id`"" -Because "body references style '$Id'"
        }
    }
}
