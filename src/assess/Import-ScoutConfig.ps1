#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Load an optional Scout assessment config -- an alternative benchmark,
    rule-selection patterns, and/or per-rule threshold overrides -- from a JSON
    file on disk, falling back to the built-in ALZ reference benchmark whenever
    the path is absent, missing, or unparsable.

.DESCRIPTION
    The PowerShell-native equivalent of the web platform's "config upload":
    instead of an HTTP multipart upload, `-ConfigPath` points at a JSON file.
    The schema mirrors exactly what the assessment engine already consumes --
    nothing new is invented here:

      - `benchmark`     is the same shape as benchmarks/alz-reference.json,
                        consumed as-is by Compare-Benchmark (managementGroups,
                        requiredPolicyAssignments, network, ...).
      - `rulePatterns`  is the same string[] of glob patterns already accepted
                        by Get-RuleSet -Patterns (and stored as the `Rules`
                        key in manifests/assessments.psd1).
      - `ruleOverrides` is a { ruleId: <value> } or { ruleId: { value, type } }
                        map applied on top of the loaded rule set by
                        Get-RuleSet's -Overrides parameter (patches a rule's
                        assert.value / assert.type after the YAML load).

    Every key is optional and independently overridable, so a config file can
    supply just one of the three without disturbing the others.

    Never throws on a bad file (AB#375): a missing -ConfigPath, a missing
    file, a read failure, a JSON parse failure, or a non-object JSON payload
    all fall back to the built-in default benchmark with a Write-Warning, so
    a broken config degrades to "run with defaults" rather than aborting the
    assessment.

.PARAMETER ConfigPath
    Path to a JSON config file. Optional -- omit to use the built-in default
    benchmark with no rule-pattern or threshold overrides.

.PARAMETER DefaultBenchmarkPath
    Path to the built-in default benchmark JSON (benchmarks/alz-reference.json
    by default). Used as the fallback when -ConfigPath is absent or invalid,
    and as the base benchmark merged under a config file that omits `benchmark`.

.OUTPUTS
    [pscustomobject] with SchemaVersion, Source ('Default' or 'File'),
    ConfigPath (resolved path, or $null), Benchmark, RulePatterns, and
    RuleOverrides.

.NOTES
    Tracks ADO Stories AB#373 (load), AB#374 (save -- see Export-ScoutConfig.ps1),
    AB#375 (hardcoded fallback).
#>
function Import-ScoutConfig {
    [CmdletBinding()]
    param(
        [string] $ConfigPath,
        [string] $DefaultBenchmarkPath = "$PSScriptRoot/benchmarks/alz-reference.json"
    )

    $default = $null
    try {
        $default = Get-Content -LiteralPath $DefaultBenchmarkPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
    catch {
        # The built-in default itself being unreadable is extremely unusual, but
        # this must still never throw (AB#375) -- fall back to an empty-but-shaped
        # benchmark object so Compare-Benchmark still runs (every field there is
        # read defensively / treated as optional).
        Write-Warning "Import-ScoutConfig: could not load the built-in default benchmark '$DefaultBenchmarkPath': $($_.Exception.Message). Continuing with an empty benchmark."
        $default = [pscustomobject]@{
            managementGroups          = [pscustomobject]@{ expected = @() }
            requiredPolicyAssignments = @()
            network                   = [pscustomobject]@{}
        }
    }

    $result = [pscustomobject]@{
        SchemaVersion = 1
        Source        = 'Default'
        ConfigPath    = $null
        Benchmark     = $default
        RulePatterns  = $null
        RuleOverrides = @{}
    }

    if (-not $ConfigPath) {
        return $result
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Warning "Import-ScoutConfig: config path '$ConfigPath' does not exist -- falling back to the built-in default benchmark."
        return $result
    }

    $raw = $null
    try {
        $raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
    }
    catch {
        Write-Warning "Import-ScoutConfig: could not read '$ConfigPath': $($_.Exception.Message) -- falling back to the built-in default benchmark."
        return $result
    }

    $parsed = $null
    try {
        $parsed = $raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
    catch {
        Write-Warning "Import-ScoutConfig: '$ConfigPath' is not valid JSON ($($_.Exception.Message)) -- falling back to the built-in default benchmark."
        return $result
    }

    if ($null -eq $parsed -or $parsed -isnot [System.Management.Automation.PSCustomObject]) {
        Write-Warning "Import-ScoutConfig: '$ConfigPath' did not parse to a JSON object -- falling back to the built-in default benchmark."
        return $result
    }

    $result.Source     = 'File'
    $result.ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).ProviderPath

    if ($parsed.PSObject.Properties['benchmark'] -and $null -ne $parsed.benchmark) {
        $result.Benchmark = $parsed.benchmark
    }

    if ($parsed.PSObject.Properties['rulePatterns'] -and $null -ne $parsed.rulePatterns) {
        $result.RulePatterns = @($parsed.rulePatterns | ForEach-Object { [string]$_ })
    }

    if ($parsed.PSObject.Properties['ruleOverrides'] -and $null -ne $parsed.ruleOverrides) {
        $overrides = @{}
        foreach ($prop in $parsed.ruleOverrides.PSObject.Properties) {
            $overrides[$prop.Name] = $prop.Value
        }
        $result.RuleOverrides = $overrides
    }

    return $result
}
