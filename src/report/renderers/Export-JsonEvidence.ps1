#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Emit a resources-only JSON evidence export -- the raw Collect object, no
    assessment metadata/scores/findings. Retained tier.

.DESCRIPTION
    Same renderer contract as every other Export-* function dispatched from
    Export-Report.ps1: it accepts -Findings/-Collect/-OutputPath even though
    this renderer deliberately never reads -Findings. AB#396 asks for an
    evidence export containing ONLY what was collected (subscriptions,
    networking, compute, security, governance, domains, advisor, etc. --
    whatever shape Invoke-Collect/the ingestors produced) -- not the scored
    Findings object (GeneratedOn/Frameworks/Areas/Gaps/Manual/Errors/Findings),
    which carries assessment metadata, rule outcomes, and severity/score data.
    Excluding -Findings entirely, rather than filtering its fields out, is what
    guarantees no assessment metadata/scores/findings ever leaks into this
    format.

    $Collect's own `_meta` block (generatedOn/scope/categories/
    managementGroupId written by Invoke-Collect) is kept: it is collection
    provenance -- when/how the evidence was gathered -- not assessment
    (scoring) metadata, and is useful for anyone consuming the evidence pack
    standalone. If a future consumer needs `_meta` stripped too, that is a
    one-line change here (Remove-Member '_meta' before serializing).

    Serialization is deterministic: ConvertTo-Json on a PSCustomObject/ordered
    Hashtable preserves property insertion order, so the same $Collect input
    always produces byte-identical JSON text (module-relative line endings
    aside). No timestamps, GUIDs, or other non-deterministic values are added
    by this renderer -- whatever is already in $Collect (e.g. its own
    generatedOn) is the only source of any date/time content.

.PARAMETER Findings
    Unused. Present only so this renderer matches the shared 3-argument
    Export-* call shape Export-Report.ps1 uses for every renderer.

.PARAMETER Collect
    The raw Collect object (output of Invoke-Collect, optionally enriched by
    the ingestors). Serialized as-is.

.PARAMETER OutputPath
    Folder to write evidence.json into. Created if missing.

.OUTPUTS
    [string] the full path to the written evidence.json file, or $null if
    writing failed (non-fatal -- a bad renderer must never sink an otherwise
    good assessment run).

.NOTES
    Tracks ADO Story AB#396.
#>
function Export-JsonEvidence {
    param($Findings, $Collect, [string] $OutputPath)

    try {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }

        # $Collect may legitimately be $null (e.g. a caller re-rendering from an
        # empty/failed collect) -- emit an explicit empty object rather than
        # letting ConvertTo-Json render the literal text "null" for the whole file.
        $payload = if ($null -ne $Collect) { $Collect } else { [pscustomobject]@{} }

        $evidencePath = Join-Path $OutputPath 'evidence.json'
        $payload | ConvertTo-Json -Depth 100 | Out-File -FilePath $evidencePath -Encoding utf8
        return $evidencePath
    }
    catch {
        Write-Warning "Export-JsonEvidence: could not write evidence export: $_"
        return $null
    }
}
