#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Compute cross-run drift (New/Resolved/Regressed/Unchanged + score delta)
    for a scored Findings set against the immediately previous run, and
    append the current run to a durable findings-history log.

.DESCRIPTION
    Maintains a single append-only history file (findings-history.json) under
    -HistoryPath: one compact record per run, keyed by -RunId, capturing every
    finding's Status plus a weighted OverallScore (same Area-weighted-average
    math Get-Score uses for a Framework score, just rolled up across every
    scored area regardless of framework).

    On each call:
      1. Reads the history file (tolerant of a missing file or malformed/
         corrupt JSON — both are treated as "no history", never throrow).
      2. Picks the most recent prior record whose RunId differs from the
         current -RunId as the comparison baseline.
      3. Classifies every current finding as one of:
           New        - no record of this finding Id in the previous run
           Resolved   - previous run had Fail/Partial, current run has Pass
           Regressed  - previous run had Pass, current run has Fail/Partial
           Unchanged  - anything else (same status, or a change that isn't
                        the Resolved/Regressed pattern above, e.g.
                        Partial -> Fail)
      4. Appends/replaces the current run's record in the history file (a
         rerun with the same -RunId overwrites its own prior record rather
         than duplicating it).

    On the first-ever run for a given -HistoryPath (no usable prior record),
    returns an explicit baseline drift object — IsBaseline = $true, every
    finding classified 'New', PreviousScore/ScoreDelta = $null — rather than
    throwing or returning nothing, so callers (e.g. Export-React's Drift tab)
    can render a "baseline run" state without special-casing a null return.

.PARAMETER Findings
    The scored Findings object from Get-Score (GeneratedOn/Frameworks/Areas/
    Gaps/Manual/Errors/Findings).

.PARAMETER HistoryPath
    Folder the findings-history.json log lives in. Created if missing.
    Defaults to a .scout-history folder under the current location if not
    supplied — callers should normally pass an explicit path (e.g. a
    .scout-history folder under the assessment's -OutputPath root) so every
    run in the same output tree shares one history log.

.PARAMETER RunId
    The caller-supplied run identifier (e.g. Invoke-ScoutAssessment's
    yyyyMMdd_HHmmss run folder name) stamped onto this run's history record.
    Required — drift has no meaning without a stable, caller-controlled id
    to compare across.

.OUTPUTS
    [pscustomobject] with RunId/GeneratedOn/IsBaseline/PreviousRunId/
    OverallScore/PreviousScore/ScoreDelta/Summary/Findings — see
    tests/Report.Drift.Tests.ps1 for the exact shape exercised.

.NOTES
    Tracks ADO Story AB#5053.
#>
function Get-ScoutDrift {
    param(
        $Findings,
        [string] $HistoryPath,
        [string] $RunId
    )

    if ($null -eq $Findings) {
        throw 'Get-ScoutDrift: -Findings is required.'
    }
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        throw 'Get-ScoutDrift: -RunId is required (pass the caller-controlled run id, e.g. the assessment run-folder name).'
    }
    if ([string]::IsNullOrWhiteSpace($HistoryPath)) {
        $HistoryPath = Join-Path (Get-Location) 'output' '.scout-history'
    }

    if (-not (Test-Path $HistoryPath)) {
        New-Item -ItemType Directory -Path $HistoryPath -Force | Out-Null
    }
    $historyFile = Join-Path $HistoryPath 'findings-history.json'

    function Get-ScoutDriftProp {
        param($Obj, [string] $Name)
        if ($null -eq $Obj) { return $null }
        $p = $Obj.PSObject.Properties[$Name]
        if ($p) { return $p.Value } else { return $null }
    }

    function Get-ScoutOverallScore {
        # Weighted mean of every scored area's Score by its AreaWeight — the
        # same math Get-Score uses per-framework, just rolled up across all
        # areas so drift has a single headline number to diff.
        param($ScoredFindings)
        $areas = @(Get-ScoutDriftProp $ScoredFindings 'Areas')
        $scorable = @($areas | Where-Object { $null -ne (Get-ScoutDriftProp $_ 'Score') })
        if ($scorable.Count -eq 0) { return $null }
        $wsum = ($scorable | ForEach-Object {
            $w = Get-ScoutDriftProp $_ 'Weight'
            if ($null -eq $w) { 1.0 } else { [double]$w }
        } | Measure-Object -Sum).Sum
        $wnum = ($scorable | ForEach-Object {
            $w = Get-ScoutDriftProp $_ 'Weight'
            if ($null -eq $w) { $w = 1.0 } else { $w = [double]$w }
            (Get-ScoutDriftProp $_ 'Score') * $w
        } | Measure-Object -Sum).Sum
        if ($wsum -gt 0) { return [math]::Round($wnum / $wsum, 0, [System.MidpointRounding]::AwayFromZero) }
        return $null
    }

    # ---- read prior history (tolerant: missing/corrupt => baseline, never throw) ----
    $history = @()
    if (Test-Path $historyFile) {
        try {
            $raw = Get-Content $historyFile -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
                if ($null -ne $parsed) { $history = @($parsed) }
            }
        }
        catch {
            # Malformed/corrupt history file — treat as "no history" (baseline).
            $history = @()
        }
    }

    $priorCandidates = @($history | Where-Object { (Get-ScoutDriftProp $_ 'RunId') -ne $RunId })
    $previous = if ($priorCandidates.Count -gt 0) { $priorCandidates[-1] } else { $null }
    $isBaseline = ($null -eq $previous)

    # ---- current run's findings, keyed by Id ----
    $currentFindings = @(Get-ScoutDriftProp $Findings 'Findings')
    $currentMap = @{}
    foreach ($f in $currentFindings) {
        $id = Get-ScoutDriftProp $f 'Id'
        if ([string]::IsNullOrEmpty($id)) { continue }
        $currentMap[$id] = $f
    }

    $previousStatuses = if ($isBaseline) { $null } else { Get-ScoutDriftProp $previous 'Statuses' }

    $counts = @{ New = 0; Resolved = 0; Regressed = 0; Unchanged = 0 }
    $driftFindings = [System.Collections.Generic.List[object]]::new()

    foreach ($id in $currentMap.Keys) {
        $f = $currentMap[$id]
        $currentStatus = Get-ScoutDriftProp $f 'Status'
        $prevStatus = if ($isBaseline) { $null } else { Get-ScoutDriftProp $previousStatuses $id }
        $existedBefore = ($null -ne $prevStatus)

        $driftType =
            if (-not $existedBefore) { 'New' }
            elseif ($prevStatus -in 'Fail', 'Partial' -and $currentStatus -eq 'Pass') { 'Resolved' }
            elseif ($prevStatus -eq 'Pass' -and $currentStatus -in 'Fail', 'Partial') { 'Regressed' }
            else { 'Unchanged' }

        $counts[$driftType]++
        $driftFindings.Add([pscustomobject]@{
            Id             = $id
            Title          = Get-ScoutDriftProp $f 'Title'
            Framework      = Get-ScoutDriftProp $f 'Framework'
            Area           = Get-ScoutDriftProp $f 'Area'
            PreviousStatus = $prevStatus
            CurrentStatus  = $currentStatus
            Drift          = $driftType
        })
    }

    # Findings present in the previous run but absent from this one — not one
    # of the four required per-finding states, so surfaced only as a summary
    # count (e.g. a rule/area was retired between runs), never as a per-
    # finding Drift value outside the New/Resolved/Regressed/Unchanged set.
    $removedCount = 0
    if (-not $isBaseline -and $null -ne $previousStatuses) {
        $prevIds = @($previousStatuses.PSObject.Properties.Name)
        $removedCount = @($prevIds | Where-Object { -not $currentMap.ContainsKey($_) }).Count
    }

    $currentScore = Get-ScoutOverallScore $Findings
    $previousScore = if ($isBaseline) { $null } else { Get-ScoutDriftProp $previous 'OverallScore' }
    $scoreDelta = if ($isBaseline -or $null -eq $currentScore -or $null -eq $previousScore) {
        $null
    } else {
        $currentScore - $previousScore
    }

    $result = [pscustomobject]@{
        RunId         = $RunId
        GeneratedOn   = (Get-Date).ToString('o')
        IsBaseline    = $isBaseline
        PreviousRunId = if ($isBaseline) { $null } else { Get-ScoutDriftProp $previous 'RunId' }
        OverallScore  = $currentScore
        PreviousScore = $previousScore
        ScoreDelta    = $scoreDelta
        Summary       = [pscustomobject]@{
            New       = $counts['New']
            Resolved  = $counts['Resolved']
            Regressed = $counts['Regressed']
            Unchanged = $counts['Unchanged']
            Removed   = $removedCount
        }
        Findings      = @($driftFindings | Sort-Object Framework, Area, Id)
    }

    # ---- persist this run's record (replace-on-rerun, else append) ----
    $statusesForStorage = [ordered]@{}
    foreach ($id in $currentMap.Keys) {
        $statusesForStorage[$id] = Get-ScoutDriftProp $currentMap[$id] 'Status'
    }
    $newRecord = [pscustomobject]@{
        RunId        = $RunId
        Timestamp    = (Get-Date).ToString('o')
        OverallScore = $currentScore
        Statuses     = [pscustomobject]$statusesForStorage
    }
    $updatedHistory = @($history | Where-Object { (Get-ScoutDriftProp $_ 'RunId') -ne $RunId }) + $newRecord
    $updatedHistory | ConvertTo-Json -Depth 100 | Out-File $historyFile -Encoding utf8

    return $result
}
