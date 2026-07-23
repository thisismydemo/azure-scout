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

    # ---- permission pre-flight (never fatal to the pipeline) ----
    $permissionAudit = [ordered]@{
        Skipped = [bool]$SkipPermissionAudit
        Ran     = $false
        Ok      = $null
        Checks  = @()
        Error   = $null
    }
    if (-not $SkipPermissionAudit) {
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
    }

    # ---- collect / assess / report ----
    $assessParams = @{
        Assessment   = $Assessment
        OutputFormat = $OutputFormat
        OutputPath   = $OutputPath
    }
    if ($ManagementGroupId) { $assessParams.ManagementGroupId = $ManagementGroupId }
    if ($Category)          { $assessParams.Category          = $Category }

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
    $outcome =
        if (-not $runFolder -or (-not $collectExists -and -not $findingsExist)) { 'Failed' }
        elseif ($assessmentError -or ($permissionAudit.Ok -eq $false))          { 'PartialSuccess' }
        else                                                                     { 'Success' }

    $summary = [ordered]@{
        schemaVersion     = $schemaVersion
        startedOn         = $startedOn.ToString('o')
        finishedOn        = $finishedOn.ToString('o')
        elapsedSeconds    = [math]::Round(($finishedOn - $startedOn).TotalSeconds, 1)
        assessments       = @($Assessment)
        formats           = @($OutputFormat)
        managementGroupId = $ManagementGroupId
        runFolder         = $runFolder
        assessmentStatus  = $assessmentStatus
        findingsByStatus  = $findingsByStatus
        permissionAudit   = $permissionAudit
        assessmentError   = $assessmentError
        outcome           = $outcome
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
