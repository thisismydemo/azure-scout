#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Save the effective Scout assessment config (benchmark, rule-selection
    patterns, and any per-rule threshold overrides) to a JSON file -- the
    PowerShell equivalent of the web platform's "config download".

.DESCRIPTION
    Writes the identical schema Import-ScoutConfig reads (`benchmark`,
    `rulePatterns`, `ruleOverrides`), so a round trip -- Import-ScoutConfig,
    edit, Export-ScoutConfig, Import-ScoutConfig again -- reproduces the same
    effective config. Accepts either the object Import-ScoutConfig returns
    (-Config, pipeline-friendly) or the three pieces supplied individually
    (-Benchmark / -RulePatterns / -RuleOverrides) for callers building a
    config from scratch.

.PARAMETER Path
    Destination JSON file path. Parent directory is created if missing.

.PARAMETER Config
    The object returned by Import-ScoutConfig (or anything shaped the same:
    Benchmark / RulePatterns / RuleOverrides properties).

.PARAMETER Benchmark
    Benchmark object to write, same shape as benchmarks/alz-reference.json.
    Used with the 'Parts' parameter set instead of -Config.

.PARAMETER RulePatterns
    Rule-selection glob patterns to write. Used with the 'Parts' parameter set.

.PARAMETER RuleOverrides
    Hashtable of ruleId -> override value/object to write. Used with the
    'Parts' parameter set.

.PARAMETER Force
    Overwrite Path if it already exists. Without -Force, an existing file is
    left untouched and a warning is emitted (non-fatal).

.OUTPUTS
    The resolved path written, or $null if the write was skipped (existing
    file, no -Force).

.NOTES
    Tracks ADO Story AB#374. See Import-ScoutConfig.ps1 for the schema this
    mirrors and AB#373/AB#375.
#>
function Export-ScoutConfig {
    [CmdletBinding(DefaultParameterSetName = 'Config')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'Config', ValueFromPipeline)]
        [pscustomobject] $Config,

        [Parameter(ParameterSetName = 'Parts')]
        $Benchmark,

        [Parameter(ParameterSetName = 'Parts')]
        [string[]] $RulePatterns,

        [Parameter(ParameterSetName = 'Parts')]
        [hashtable] $RuleOverrides,

        [switch] $Force
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Config') {
            $benchmarkOut     = $Config.Benchmark
            $rulePatternsOut  = $Config.RulePatterns
            $ruleOverridesOut = $Config.RuleOverrides
        }
        else {
            $benchmarkOut     = $Benchmark
            $rulePatternsOut  = $RulePatterns
            $ruleOverridesOut = $RuleOverrides
        }

        if ((Test-Path -LiteralPath $Path) -and -not $Force) {
            Write-Warning "Export-ScoutConfig: '$Path' already exists -- use -Force to overwrite. Config was NOT written."
            return $null
        }

        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $payload = [ordered]@{
            schemaVersion = 1
            benchmark     = $benchmarkOut
            rulePatterns  = @($rulePatternsOut)
            ruleOverrides = if ($ruleOverridesOut) { $ruleOverridesOut } else { @{} }
        }

        $payload | ConvertTo-Json -Depth 100 | Out-File -LiteralPath $Path -Encoding utf8

        return (Resolve-Path -LiteralPath $Path).ProviderPath
    }
}
