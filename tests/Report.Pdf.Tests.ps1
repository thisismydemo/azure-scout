#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
    Pester tests for src/report/renderers/Export-Pdf.ps1 -- the hand-rolled,
    dependency-free .pdf renderer (ADO Stories AB#379/394/395). No Azure
    connection, no external library, no network access required -- exactly
    what the renderer itself needs to run.
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . "$script:Root/src/assess/engine/Get-Score.ps1"
    . "$script:Root/src/report/renderers/Export-Pdf.ps1"

    function New-PdfTestFinding {
        param($Id, $Framework, $Area, $Status, $Severity = 'medium', $Weight = 1.0)
        [pscustomobject]@{
            Id = $Id; Title = "$Id title text for the report"; Framework = $Framework; Area = $Area; Severity = $Severity
            Status = $Status; EvidenceCount = 2; Evidence = @(); Remediation = "Remediate $Id."
            Manual = ($Status -eq 'Manual'); AreaWeight = $Weight
        }
    }

    # 45 findings in one area -- comfortably forces the findings table onto
    # multiple pages so the AB#394 header-repeat path actually exercises.
    $script:ManyFindings = 1..45 | ForEach-Object {
        $status = @('Pass', 'Fail', 'Partial')[$_ % 3]
        New-PdfTestFinding "CAF-NET-$($_.ToString('00'))" 'CAF' 'Networking' $status 'medium'
    }
    $script:ManyFindings += @(
        (New-PdfTestFinding 'WAF-SEC-01' 'WAF' 'Security' 'Fail' 'high')
        (New-PdfTestFinding 'WAF-SEC-02' 'WAF' 'Security' 'Manual')
    )
    $script:Scored = Get-Score -Findings $script:ManyFindings

    $script:Collect = [pscustomobject]@{
        _meta = [pscustomobject]@{ scope = 'ArmOnly'; managementGroupId = 'mg-test-01' }
    }

    $script:OutDir = Join-Path $script:Root 'tests' 'test-output' 'pdf'
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force }

    # Reads the whole PDF as Latin-1 (ISO-8859-1) text -- a byte-for-byte
    # lossless mapping of 0..255 to chars, so binary segments (the %-marker
    # comment, an embedded JPEG) can sit alongside ASCII structure/content
    # without throwing, while still letting Select-String/regex search for
    # the ASCII content-stream text this renderer writes.
    function Get-PdfText {
        param([string]$Path)
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($bytes)
    }
}

AfterAll {
    if (Test-Path $script:OutDir) { Remove-Item $script:OutDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Export-Pdf -- basic document structure AB#379/394/395' {
    BeforeAll {
        $script:PdfPath = Export-Pdf -Findings $script:Scored -Collect $script:Collect -OutputPath $script:OutDir
        $script:Text = Get-PdfText -Path $script:PdfPath
    }

    It 'writes assessment_report.pdf into -OutputPath and returns its path' {
        $script:PdfPath | Should -Exist
        (Split-Path $script:PdfPath -Leaf) | Should -Be 'assessment_report.pdf'
    }

    It 'starts with the %PDF header and ends with %%EOF' {
        $script:Text.Substring(0, 8) | Should -Be '%PDF-1.4'
        $script:Text.TrimEnd().Substring($script:Text.TrimEnd().Length - 5) | Should -Be '%%EOF'
    }

    It 'declares a Catalog, Pages tree, and xref/trailer' {
        $script:Text | Should -Match '/Type /Catalog'
        $script:Text | Should -Match '/Type /Pages'
        $script:Text | Should -Match 'trailer'
        $script:Text | Should -Match 'startxref'
    }

    It 'renders more than one page (the findings table paginates)' {
        ([regex]::Matches($script:Text, '/Type /Page[^s]')).Count | Should -BeGreaterThan 1
    }

    It 'repeats the findings-table column header across a page break (AB#394)' {
        ([regex]::Matches($script:Text, '\(ID\) Tj')).Count | Should -BeGreaterThan 1
        ([regex]::Matches($script:Text, '\(Severity\) Tj')).Count | Should -BeGreaterThan 1
    }

    It 'renders every expected sub-section heading (AB#395)' {
        foreach ($heading in 'Framework Alignment', 'Architecture Diagram', 'Executive Summary', 'Findings by Area', 'Prioritized Gaps', 'Manual Review Items') {
            $pattern = [regex]::Escape("($heading) Tj")
            $script:Text | Should -Match $pattern
        }
    }

    It 'draws status/severity dots as vector circles, not text glyphs (AB#395 emoji stand-in)' {
        # Every Add-ScoutPdfDot call emits four "c" (Bezier curve) operators.
        ([regex]::Matches($script:Text, ' c\r?\n')).Count | Should -BeGreaterThan 0
    }

    It 'notes the missing architecture diagram honestly rather than embedding nothing silently' {
        $script:Text | Should -Match 'Architecture diagram not embedded'
        $script:Text | Should -Not -Match '/DCTDecode'
    }

    It 'is deterministic -- identical input renders byte-identical output' {
        $repeatDir = Join-Path $script:Root 'tests' 'test-output' 'pdf-repeat'
        if (Test-Path $repeatDir) { Remove-Item $repeatDir -Recurse -Force }
        try {
            $repeatPath = Export-Pdf -Findings $script:Scored -Collect $script:Collect -OutputPath $repeatDir
            $a = [System.IO.File]::ReadAllBytes($script:PdfPath)
            $b = [System.IO.File]::ReadAllBytes($repeatPath)
            [System.Convert]::ToBase64String($a) | Should -Be ([System.Convert]::ToBase64String($b))
        }
        finally {
            if (Test-Path $repeatDir) { Remove-Item $repeatDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Export-Pdf -- culture safety' {
    It 'never emits a comma decimal separator in content-stream numbers, even on a comma-decimal thread culture' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'pdf-culture'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
            $path = Export-Pdf -Findings $script:Scored -Collect $script:Collect -OutputPath $dir
            $text = Get-PdfText -Path $path
            # A margin-based coordinate (54.00) must appear with a period; no
            # "<digit>,<digit>" pattern should ever appear inside a Td/re/m/l/c op line.
            $text | Should -Match '54\.00'
            ($text -split "`n" | Where-Object { $_ -match '\d,\d{2} ' -and $_ -notmatch '^\d+ \d+ obj' }) | Should -BeNullOrEmpty
        }
        finally {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Export-Pdf -- AB#379 diagram embed' {
    It 'embeds a valid baseline JPEG dropped at OutputPath/diagram.jpg' {
        # NOTE: the test name deliberately avoids angle brackets around
        # "OutputPath" -- Pester v5 treats a literal <Name> token inside an
        # It name as a data-driven-test placeholder (for -TestCases) and
        # tries to resolve it as a variable even with no -TestCases supplied,
        # throwing "variable ... has not been set" at discovery time.
        # -Skip: is a discovery-time value in Pester v5 -- it cannot depend on a
        # BeforeAll-computed variable (BeforeAll runs during the later Run
        # phase, so the condition would always see an unset value at
        # discovery). Checking availability inside the It body with
        # Set-ItResult -Skipped is the safe, well-documented alternative.
        try {
            Add-Type -AssemblyName System.Drawing.Common -ErrorAction Stop
        }
        catch {
            Set-ItResult -Skipped -Because 'System.Drawing.Common is unavailable on this platform'
            return
        }

        $dir = Join-Path $script:Root 'tests' 'test-output' 'pdf-diagram'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $bmp = [System.Drawing.Bitmap]::new(80, 40)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.Clear([System.Drawing.Color]::CornflowerBlue)
            $bmp.Save((Join-Path $dir 'diagram.jpg'), [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $g.Dispose(); $bmp.Dispose()

            $path = Export-Pdf -Findings $script:Scored -Collect $script:Collect -OutputPath $dir
            $text = Get-PdfText -Path $path
            $text | Should -Match '/Filter /DCTDecode'
            $text | Should -Match '/Subtype /Image'
            $text | Should -Match '/Width 80'
            $text | Should -Match '/Height 40'
            $text | Should -Not -Match 'Architecture diagram not embedded'
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'skips a malformed diagram.jpg (not really a JPEG) without failing the whole render' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'pdf-bad-diagram'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            'this is not a jpeg' | Out-File (Join-Path $dir 'diagram.jpg') -Encoding ascii
            # Redirect the warning stream (3) into the success stream so both the
            # returned path (a [string]) and any [WarningRecord]s come back on one
            # pipeline -- more robust than -WarningVariable against a plain (non
            # -CmdletBinding) function, which every renderer in this folder is.
            $allOutput = @(Export-Pdf -Findings $script:Scored -Collect $script:Collect -OutputPath $dir 3>&1)
            $path = $allOutput | Where-Object { $_ -is [string] } | Select-Object -First 1
            $warnings = $allOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $path | Should -Exist
            $text = Get-PdfText -Path $path
            $text | Should -Not -Match '/DCTDecode'
            @($warnings) | Where-Object { $_.Message -match 'does not look like a valid JPEG' } | Should -Not -BeNullOrEmpty
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Get-ScoutPdfJpegInfo (unit)' {
    It 'returns $null for non-JPEG bytes' {
        Get-ScoutPdfJpegInfo -Bytes ([byte[]]@(1, 2, 3, 4, 5)) | Should -BeNullOrEmpty
    }

    It 'parses width/height/components out of a real baseline JPEG' -Skip:(-not (Get-Command -Name 'Add-Type' -ErrorAction SilentlyContinue)) {
        try {
            Add-Type -AssemblyName System.Drawing.Common -ErrorAction Stop
        }
        catch {
            Set-ItResult -Skipped -Because 'System.Drawing.Common is unavailable on this platform'
            return
        }
        $bmp = [System.Drawing.Bitmap]::new(64, 32)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Red)
        $ms = [System.IO.MemoryStream]::new()
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $g.Dispose(); $bmp.Dispose()

        $info = Get-ScoutPdfJpegInfo -Bytes $ms.ToArray()
        $info.Width | Should -Be 64
        $info.Height | Should -Be 32
        $info.Components | Should -BeIn @(1, 3)
    }
}

Describe 'Export-Pdf -- edge cases' {
    It 'does not throw on an empty Findings set and still produces a valid PDF' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'pdf-empty'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        try {
            $emptyScored = Get-Score -Findings @()
            $path = Export-Pdf -Findings $emptyScored -Collect $null -OutputPath $dir
            $path | Should -Exist
            (Get-PdfText -Path $path) | Should -Match '%PDF-1.4'
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'Export-ScoutPdfHtmlFallback (unit)' {
    It 'writes a clearly-labeled fallback HTML file, not a silently-renamed non-PDF' {
        $dir = Join-Path $script:Root 'tests' 'test-output' 'pdf-fallback'
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        try {
            $path = Export-ScoutPdfHtmlFallback -Findings $script:Scored -Collect $script:Collect -OutputPath $dir -Reason 'synthetic test failure'
            (Split-Path $path -Leaf) | Should -Be 'assessment_report_fallback.html'
            $content = Get-Content $path -Raw
            $content | Should -Match 'PDF generation failed'
            $content | Should -Match 'synthetic test failure'
            $content | Should -Match '__FINDINGS__'
        }
        finally {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}
