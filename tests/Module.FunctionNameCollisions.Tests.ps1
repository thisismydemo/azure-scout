#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
    AB#6897 -- two files defining the same function name is a silent, load-order-decided defect.

    AzureScout.psm1 dot-sources every src/*.ps1 sorted by full path into ONE module session
    state. When two files define the same function, whichever loads LAST wins everywhere -- with
    no warning, no error, and no test failure unless something exercises the losing caller
    through the module (unit tests dot-source individual files and never see the collision).

    This has now shipped two corpus-poisoning defects:
      * AB#6883 -- ImportExcel's Export-Excel shadowed the workbook renderer.
      * AB#6897 -- Export-Pptx.ps1's single-name `Get-ScoutProp` shadowed the collect layer's
        dotted-path walker of the same name. Every module-imported collect run scored nulls for
        most nested fields; the entire 2026-08-03-run01 corpus was corrupted by it, and three
        healthy collectors were mis-diagnosed as broken off that data.

    The AST is parsed per file, so function names inside here-strings (embedded JavaScript in the
    HTML renderers) never false-positive. Only NON-NESTED definitions are counted: a function
    defined inside another function lives in the parent invocation's scope and is discarded when
    the parent returns, so two files each nesting their own `Add-Icon` (the diagram layer does)
    never meet. Only definitions that dot-sourcing executes directly land in module session state.
#>

BeforeAll {
    $srcRoot = Join-Path $PSScriptRoot '..' 'src'
    $script:Definitions = @{}   # name -> list of "file:line"

    foreach ($file in Get-ChildItem -Path $srcRoot -Filter '*.ps1' -Recurse) {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        # Parse errors are some other test's problem; skipping keeps this one single-purpose.
        if ($errors -and $errors.Count -gt 0) { continue }
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            Where-Object {
                # Keep only definitions NOT nested inside another function -- walk ancestors.
                $parent = $_.Parent
                while ($null -ne $parent) {
                    if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $false }
                    $parent = $parent.Parent
                }
                return $true
            }
        foreach ($fn in $functions) {
            if (-not $script:Definitions.ContainsKey($fn.Name)) {
                $script:Definitions[$fn.Name] = [System.Collections.Generic.List[string]]::new()
            }
            $relative = $file.FullName.Substring($srcRoot.Length + 1)
            $script:Definitions[$fn.Name].Add("$relative`:$($fn.Extent.StartLineNumber)")
        }
    }
}

Describe 'No function name is defined by more than one src file (AB#6897)' {

    It 'parsed a plausible number of function definitions' {
        # Guard against the scan itself breaking and everything below passing vacuously.
        $script:Definitions.Keys.Count | Should -BeGreaterThan 300
    }

    It 'finds no cross-file duplicate function definitions' {
        $collisions = foreach ($name in ($script:Definitions.Keys | Sort-Object)) {
            $files = @($script:Definitions[$name] | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique)
            if ($files.Count -gt 1) { "$name defined in: $($script:Definitions[$name] -join ', ')" }
        }
        ($collisions -join "`n") | Should -BeNullOrEmpty -Because 'the module loader dot-sources all of src/ into one session state, so the last definition silently wins for every caller (see AB#6883, AB#6897)'
    }
}
