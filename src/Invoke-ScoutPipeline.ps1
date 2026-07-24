#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    One-command, unattended Scout pipeline -- collect, assess, and report headless
    into a single dated run folder, with a machine-readable run summary.

.DESCRIPTION
    Wraps Invoke-ScoutAssessment (the collect -> assess -> report orchestrator) for
    CI/cron hosts that have no console to answer a prompt or watch a progress bar,
    and that need a single artifact to inspect afterward instead of parsing scrollback.

    Non-interactive throughout: forces $ConfirmPreference = 'None' and
    $ProgressPreference = 'SilentlyContinue' for the run so no cmdlet can block on a
    ShouldContinue prompt or spam progress records into a log file.

    Unless -SkipPermissionAudit is set, runs the existing read-only permission
    pre-flight first (Invoke-ScoutAssessment -PermissionAudit, i.e. Test-ScoutPermission)
    and folds its result into the summary. A permission-audit failure is recorded, not
    thrown -- governance datasets (AzGovViz / Graph-backed rules) can legitimately come
    back partial (degrading to 'Unknown' findings) without that being fatal to the run
    (AB#5050).

    The orchestrator call itself is wrapped in try/catch, mirroring the resilience
    pattern already used for the AzGovViz ingest in src/ingest/Import-AzGovViz.ps1: an
    exporter (or any orchestrator step) throwing mid-run degrades the outcome to
    'PartialSuccess' rather than losing whatever collect.json / findings.json / reports
    were already written to disk. Invoke-ScoutAssessment only returns its run-folder
    path on a clean return, so when it throws this function recovers the folder by
    diffing the directory listing of -OutputPath from before/after the call (the
    orchestrator creates its dated run folder as its very first action, before doing
    any work that could fail).

    Writes two files into the run folder:
      - pipeline-summary.json  (schema documented below -- the CI-facing contract)
      - pipeline-summary.md    (human-readable mirror of the same data)

    Exit semantics for a CI caller: returns the run-folder path normally for
    'Success' and 'PartialSuccess'. Throws (and sets $global:LASTEXITCODE = 1) for
    'Failed' -- i.e. collect/assess produced no run folder at all, so there is
    nothing downstream to report on.

.PARAMETER Assessment
    One or many assessment names from manifests/assessments.psd1 (or 'All').
    Same contract as Invoke-ScoutAssessment -Assessment.

.PARAMETER OutputFormat
    One or many report renderers, or 'All'. Same contract as
    Invoke-ScoutAssessment -OutputFormat.

.PARAMETER OutputPath
    Parent folder the dated run folder is created under. Same contract as
    Invoke-ScoutAssessment -OutputPath.

.PARAMETER ManagementGroupId
    Scopes the ARG collect (and the AzGovViz/ArgQueryPack ingests) to a management
    group, exactly as Invoke-ScoutAssessment -ManagementGroupId does.

.PARAMETER Category
    Filters which Resource Graph collect categories run, exactly as
    Invoke-ScoutAssessment -Category does.

.PARAMETER SkipPermissionAudit
    Skip the Test-ScoutPermission pre-flight entirely (useful when the caller has
    already run its own permission check, e.g. earlier in the same pipeline).

.EXAMPLE
    Invoke-ScoutPipeline -Assessment LandingZone -OutputFormat All -OutputPath ./output -ManagementGroupId 'contoso-root-mg'

    Full unattended landing-zone run, every reporter tier, scoped to a management group.

.EXAMPLE
    Invoke-ScoutPipeline -Assessment Security, Networking -OutputFormat Html, Excel -SkipPermissionAudit

    A CI job that already validated permissions upstream and only wants two
    per-category assessments rendered to two tiers.

.EXAMPLE
    try {
        $runFolder = Invoke-ScoutPipeline -Assessment All -OutputPath $(Build.ArtifactStagingDirectory)
        Write-Host "##vso[artifact.upload]$runFolder"
    }
    catch {
        Write-Error "Scout pipeline failed: $_"
        exit 1
    }

    Typical Azure DevOps / GitHub Actions usage: capture the run folder for
    artifact upload, let a Failed outcome fail the CI step.

.NOTES
    Read-only throughout (delegates entirely to Invoke-ScoutAssessment / Invoke-Collect,
    neither of which writes to Azure). Tracks ADO AB#5050.

    Per-assessment status in the summary is best-effort: Invoke-ScoutAssessment's
    return contract is a single run-folder path, not a per-assessment result, so every
    requested assessment name is reported with the same overall status (Completed /
    Error) rather than an independently-verified one.

    AB#402: the permission audit and the collect/assess/report call are each wrapped
    with an `$Error.Count` before/after delta (`$Error` records EVERY error the
    session sees, including ones a nested try/catch already caught and handled) --
    a non-zero delta on an otherwise-non-throwing step means something was swallowed
    internally (most commonly Invoke-Collect's own AB#397/399/400 per-query
    resilience kicking in) and is surfaced two ways: `pipeline-summary.json`'s
    `permissionAudit.HadNonTerminatingErrors` / top-level `hadNonTerminatingErrors`
    fields, and a Write-Warning at the point it was detected. Either flag alone is
    enough to force the run's overall `outcome` to `PartialSuccess` even when
    nothing actually threw.

    AB#405: reports coarse phase-level progress through `Write-ScoutProgress`
    (src/Write-ScoutProgress.ps1) when that function is loaded in the calling
    session. Every call is guarded with `Get-Command ... -ErrorAction
    SilentlyContinue`, so this is a soft dependency only -- a session that never
    loaded that helper behaves exactly as it did before progress reporting existed.
#>
function Invoke-ScoutPipeline {
    [CmdletBinding()]
    param(
        [string[]] $Assessment = @('LandingZone'),
        [ValidateSet('PowerBi', 'Html', 'Pptx', 'Excel', 'Json', 'All')]
        [string[]] $OutputFormat = @('All'),
        [string]   $OutputPath = './output',
        [string]   $ManagementGroupId,
        [string[]] $Category,
        [switch]   $SkipPermissionAudit
    )

    # Non-interactive throughout (AB#5050) -- a CI/cron host has no console to answer
    # a ShouldContinue prompt (it would hang) or benefit from a progress bar (it would
    # just spam log output), so force both off for the whole run.
    $ConfirmPreference  = 'None'
    $ProgressPreference = 'SilentlyContinue'

    $schemaVersion = '1.0'
    $startedOn = Get-Date
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    # Snapshot the folder listing before the orchestrator runs so a thrown exception
    # (which loses the return value) can still be resolved back to the run folder the
    # orchestrator had already created before it failed.
    $priorRunFolders = @(Get-ChildItem -Path $OutputPath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)

    if (Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue) {
        try { Write-ScoutProgress -Activity 'Scout Pipeline' -Status 'Permission audit' -PercentComplete 0 -Id 1 }
        catch { Write-Verbose "Invoke-ScoutPipeline: Write-ScoutProgress failed, continuing without progress UX: $_" }
    }

    # ---- permission pre-flight (never fatal to the pipeline) ----
    $permissionAudit = [ordered]@{
        Skipped                  = [bool]$SkipPermissionAudit
        Ran                      = $false
        Ok                       = $null
        Checks                   = @()
        Error                    = $null
        HadNonTerminatingErrors  = $false
    }
    if (-not $SkipPermissionAudit) {
        # AB#402: $Error accumulates every error PowerShell records for the session,
        # INCLUDING ones a nested try/catch already caught and handled -- so a delta
        # across this call surfaces problems the audit swallowed internally (e.g. a
        # Graph/ARG cmdlet that logged a non-terminating error but still completed)
        # without changing the audit's own non-fatal-by-design outcome.
        $errCountBeforeAudit = $Error.Count
        try {
            $auditResult = Invoke-ScoutAssessment -Assessment $Assessment -PermissionAudit
            $permissionAudit.Ran = $true
            $permissionAudit.Checks = @($auditResult | ForEach-Object {
                [ordered]@{ Check = $_.Check; Ok = $_.Ok; Fix = $_.Fix }
            })
            # A per-check Ok of $null means "unverifiable" (e.g. a Graph app permission
            # that can't be probed without calling Graph), not "failed" -- only an
            # explicit $false on any check is a hard failure worth degrading the outcome.
            $hardFailures = @($permissionAudit.Checks | Where-Object { $_.Ok -eq $false })
            $permissionAudit.Ok = ($hardFailures.Count -eq 0)
        }
        catch {
            # A permission-audit failure must never abort the whole pipeline --
            # governance datasets can legitimately be partial (AB#5050). Record it and
            # keep going into collect/assess/report.
            $permissionAudit.Ran   = $true
            $permissionAudit.Ok    = $false
            $permissionAudit.Error = $_.Exception.Message
            Write-Warning "Invoke-ScoutPipeline: permission audit failed (non-fatal): $($_.Exception.Message)"
        }
        $permissionAudit.HadNonTerminatingErrors = ($Error.Count -gt $errCountBeforeAudit)
        if ($permissionAudit.HadNonTerminatingErrors -and -not $permissionAudit.Error) {
            Write-Warning "Invoke-ScoutPipeline: the permission audit completed but recorded $($Error.Count - $errCountBeforeAudit) non-terminating error(s) along the way (AB#402) -- see the warning/verbose output above for detail."
        }
    }

    # ---- collect / assess / report ----
    $assessParams = @{
        Assessment   = $Assessment
        OutputFormat = $OutputFormat
        OutputPath   = $OutputPath
    }
    if ($ManagementGroupId) { $assessParams.ManagementGroupId = $ManagementGroupId }
    if ($Category)          { $assessParams.Category          = $Category }

    if (Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue) {
        try { Write-ScoutProgress -Activity 'Scout Pipeline' -Status 'Collect / assess / report' -PercentComplete 50 -Id 1 }
        catch { Write-Verbose "Invoke-ScoutPipeline: Write-ScoutProgress failed, continuing without progress UX: $_" }
    }

    # AB#402: same $Error-delta technique as the permission audit above -- surfaces
    # non-terminating errors the orchestrator (or, transitively, Invoke-Collect's own
    # AB#397/399/400 per-query resilience) swallowed internally while still completing,
    # so a run that degraded some datasets without hard-failing is visible as such
    # instead of looking identical to a fully clean run.
    $errCountBeforeAssess = $Error.Count
    $runFolder       = $null
    $assessmentError = $null
    try {
        $runFolder = Invoke-ScoutAssessment @assessParams
    }
    catch {
        # Mirrors the resilience pattern in src/ingest/Import-AzGovViz.ps1: a failure
        # partway through the orchestrator (e.g. an exporter throwing) degrades the run
        # to PartialSuccess rather than killing it outright -- whatever collect.json /
        # findings.json / reports were already written stay on disk and get reported on.
        $assessmentError = $_.Exception.Message
        Write-Warning "Invoke-ScoutPipeline: Invoke-ScoutAssessment failed: $assessmentError"
    }
    $assessmentHadNonTerminatingErrors = ($Error.Count -gt $errCountBeforeAssess)
    if ($assessmentHadNonTerminatingErrors -and -not $assessmentError) {
        Write-Warning "Invoke-ScoutPipeline: the collect/assess/report run completed but recorded $($Error.Count - $errCountBeforeAssess) non-terminating error(s) along the way (AB#402) -- see the warning/verbose output above for detail."
    }

    if (-not $runFolder) {
        $recovered = Get-ChildItem -Path $OutputPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $priorRunFolders -notcontains $_.Name } |
            Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($recovered) { $runFolder = $recovered.FullName }
    }

    $finishedOn = Get-Date

    # ---- per-assessment status (best-effort -- see .NOTES) ----
    $assessmentStatus = @($Assessment | ForEach-Object {
        [ordered]@{ Name = $_; Status = if ($assessmentError) { 'Error' } else { 'Completed' } }
    })

    # ---- findings counts by Status, if findings.json exists ----
    $findingsByStatus = [ordered]@{}
    $collectExists = $false
    $findingsExist = $false
    if ($runFolder -and (Test-Path $runFolder)) {
        $collectExists = Test-Path (Join-Path $runFolder 'collect.json')
        $findingsPath  = Join-Path $runFolder 'findings.json'
        $findingsExist = Test-Path $findingsPath
        if ($findingsExist) {
            try {
                $findingsDoc = Get-Content $findingsPath -Raw | ConvertFrom-Json -Depth 100
                $findingsList = if ($null -ne $findingsDoc.PSObject.Properties['Findings']) { @($findingsDoc.Findings) } else { @() }
                foreach ($grp in ($findingsList | Group-Object Status)) {
                    $findingsByStatus[$grp.Name] = $grp.Count
                }
            }
            catch {
                Write-Warning "Invoke-ScoutPipeline: could not parse findings.json for summary counts: $_"
            }
        }
    }

    # ---- overall outcome ----
    # Failed: the orchestrator produced nothing at all -- no run folder, or a run
    # folder with neither collect.json nor findings.json in it -- nothing downstream
    # to report on. Anything with at least a collect.json/findings.json on disk is at
    # worst PartialSuccess (a permission-audit hard failure also forces PartialSuccess
    # even on an otherwise-clean run, since some datasets may be silently degraded).
    # AB#402: a step that recorded non-terminating errors it otherwise swallowed
    # (e.g. Invoke-Collect's own AB#397/399/400 per-query resilience kicking in) also
    # forces PartialSuccess -- a run that degraded some datasets without hard-failing
    # must not look identical to a fully clean run in the summary.
    $hadNonTerminatingErrors = $permissionAudit.HadNonTerminatingErrors -or $assessmentHadNonTerminatingErrors
    $outcome =
        if (-not $runFolder -or (-not $collectExists -and -not $findingsExist))                          { 'Failed' }
        elseif ($assessmentError -or ($permissionAudit.Ok -eq $false) -or $hadNonTerminatingErrors)       { 'PartialSuccess' }
        else                                                                                               { 'Success' }

    if (Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue) {
        try { Write-ScoutProgress -Activity 'Scout Pipeline' -Status "Done ($outcome)" -Id 1 -Completed }
        catch { Write-Verbose "Invoke-ScoutPipeline: Write-ScoutProgress completion call failed: $_" }
    }

    $summary = [ordered]@{
        schemaVersion           = $schemaVersion
        startedOn               = $startedOn.ToString('o')
        finishedOn              = $finishedOn.ToString('o')
        elapsedSeconds          = [math]::Round(($finishedOn - $startedOn).TotalSeconds, 1)
        assessments             = @($Assessment)
        formats                 = @($OutputFormat)
        managementGroupId       = $ManagementGroupId
        runFolder               = $runFolder
        assessmentStatus        = $assessmentStatus
        findingsByStatus        = $findingsByStatus
        permissionAudit         = $permissionAudit
        assessmentError         = $assessmentError
        hadNonTerminatingErrors = $hadNonTerminatingErrors
        outcome                 = $outcome
    }

    if ($runFolder) {
        if (-not (Test-Path $runFolder)) { New-Item -ItemType Directory -Path $runFolder -Force | Out-Null }
        $summary | ConvertTo-Json -Depth 10 | Out-File (Join-Path $runFolder 'pipeline-summary.json')

        $md = [System.Collections.Generic.List[string]]::new()
        $md.Add("# Scout pipeline run -- $outcome")
        $md.Add('')
        $md.Add("- Started: $($summary.startedOn)")
        $md.Add("- Finished: $($summary.finishedOn) ($($summary.elapsedSeconds)s)")
        $md.Add("- Assessments: $($Assessment -join ', ')")
        $md.Add("- Formats: $($OutputFormat -join ', ')")
        if ($ManagementGroupId) { $md.Add("- Management group: $ManagementGroupId") }
        $md.Add("- Run folder: $runFolder")
        if ($permissionAudit.Ran) {
            $auditLabel = if ($permissionAudit.Ok) { 'OK' } elseif ($null -eq $permissionAudit.Ok) { 'Unknown' } else { 'FAILED' }
            $md.Add("- Permission audit: $auditLabel")
        }
        elseif ($permissionAudit.Skipped) {
            $md.Add('- Permission audit: skipped (-SkipPermissionAudit)')
        }
        if ($hadNonTerminatingErrors) {
            $md.Add('- Non-terminating errors: yes (AB#402 -- see warning/verbose output for detail; the run still completed)')
        }
        if ($findingsByStatus.Count -gt 0) {
            $md.Add('')
            $md.Add('## Findings by status')
            foreach ($k in $findingsByStatus.Keys) { $md.Add("- $($k): $($findingsByStatus[$k])") }
        }
        if ($assessmentError) {
            $md.Add('')
            $md.Add('## Error')
            $md.Add($assessmentError)
        }
        ($md -join "`n") | Out-File (Join-Path $runFolder 'pipeline-summary.md')
    }
    else {
        # No run folder ever materialized -- nowhere on disk to persist the summary.
        # The thrown message below carries the diagnosis for the CI caller's log instead.
        Write-Warning 'Invoke-ScoutPipeline: no run folder was produced -- pipeline failed before any output existed.'
    }

    if ($outcome -eq 'Failed') {
        $global:LASTEXITCODE = 1
        throw "Invoke-ScoutPipeline: run failed -- collect/assess produced no output.$(if ($assessmentError) { " $assessmentError" })"
    }

    $global:LASTEXITCODE = 0
    return $runFolder
}
