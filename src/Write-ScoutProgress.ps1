#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Uniform phase-level progress reporting for the Scout collect/assess/report
    pipeline (AB#405).

.DESCRIPTION
    A single call site every long-running phase (a collect query, an ingestor, an
    assessment, a report renderer) calls into instead of hand-rolling its own
    Write-Progress / Write-Host calls.

    Renders through PwshSpectreConsole ONLY when that module is ALREADY installed
    and discoverable (`Get-Module -ListAvailable`) — a genuinely optional, soft
    dependency. Scout never installs PwshSpectreConsole, never requires it, and a
    run never fails because it is missing: this file, and every caller of it, is
    fully functional with nothing beyond core PowerShell 7 + the Az modules Scout
    already requires.

    Falls back to the native `Write-Progress` cmdlet, which is automatically
    silenced whenever the caller has set `$ProgressPreference = 'SilentlyContinue'`
    (exactly what Invoke-ScoutPipeline does for unattended/CI runs) — no extra
    detection logic needed for that case. When progress is silenced this way (a
    headless/CI host), a single-line, log-friendly status line is written instead
    via Write-Information, so scrollback still shows phase-by-phase progress
    without a live bar that would otherwise just spam a log file with carriage
    returns. That line is colored with raw ANSI escape sequences when the host
    reports virtual-terminal support and the NO_COLOR convention is not set;
    plain text otherwise.

    Every rendering path is wrapped in its own try/catch so a failure in ANY of
    them (an unexpected PwshSpectreConsole cmdlet signature, a host that doesn't
    support Write-Progress the way expected, etc.) degrades to a plain
    Write-Verbose line rather than ever being able to break the collect/assess/
    report run that is asking for progress UX.

.PARAMETER Activity
    Top-level activity name (e.g. 'Scout Collect', 'Scout Assessment', 'Scout Report').

.PARAMETER Status
    Current phase/status text (e.g. 'Collecting: Networking (4/12)').

.PARAMETER PercentComplete
    0-100. Omit (or pass -1, the default) for an indeterminate phase.

.PARAMETER Id
    Progress record id — matches Write-Progress -Id. Lets independent phases
    (e.g. collect vs. report) run their own progress record without colliding.

.PARAMETER ParentId
    Parent progress record id, for a nested progress record (Write-Progress -ParentId).

.PARAMETER Completed
    Marks the activity's progress record complete/removed (Write-Progress -Completed).

.EXAMPLE
    Write-ScoutProgress -Activity 'Scout Collect' -Status 'Querying: virtualNetworks' -PercentComplete 40 -Id 1

.EXAMPLE
    Write-ScoutProgress -Activity 'Scout Collect' -Id 1 -Completed

.NOTES
    Tracks ADO AB#405. Soft dependency only — PwshSpectreConsole is optional and
    Scout does not install it; every caller guards the call with
    `Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue` so a session
    that never dot-sourced/imported this file behaves exactly as it did before
    this file existed.
#>
function Write-ScoutProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Activity,
        [string] $Status = 'Working...',
        [int]    $PercentComplete = -1,
        [int]    $Id = 1,
        [int]    $ParentId = -1,
        [switch] $Completed
    )

    # ---- optional Spectre rendering (soft dependency -- Scout never installs it) ----
    # The availability probe is cached per-session (Get-Module -ListAvailable is not
    # free) rather than re-run on every single progress call.
    if (-not (Test-Path Variable:script:ScoutSpectreChecked)) {
        $script:ScoutSpectreChecked = $true
        try { $script:ScoutSpectreAvailable = [bool](Get-Module -ListAvailable -Name PwshSpectreConsole -ErrorAction SilentlyContinue) }
        catch { $script:ScoutSpectreAvailable = $false }
    }

    $useSpectre = $script:ScoutSpectreAvailable -and ($ProgressPreference -ne 'SilentlyContinue') -and (-not $Completed)
    if ($useSpectre) {
        try {
            Import-Module PwshSpectreConsole -ErrorAction Stop
            $pctText = if ($PercentComplete -ge 0) { "[$PercentComplete%] " } else { '' }
            Write-SpectreHost "[bold cyan]$Activity[/] $pctText[grey]$Status[/]"
            return
        }
        catch {
            # Any Spectre failure (an older/newer cmdlet signature, a non-VT host,
            # etc.) must never break progress reporting -- fall through to the
            # native fallback below instead of propagating.
            Write-Verbose "Write-ScoutProgress: PwshSpectreConsole rendering failed, falling back to Write-Progress: $($_.Exception.Message)"
        }
    }

    # ---- native Write-Progress (auto-silenced by $ProgressPreference = 'SilentlyContinue') ----
    try {
        $progressParams = @{ Activity = $Activity; Status = $Status; Id = $Id }
        if ($ParentId -ge 0) { $progressParams.ParentId = $ParentId }
        if ($Completed) { $progressParams.Completed = $true }
        elseif ($PercentComplete -ge 0) { $progressParams.PercentComplete = [Math]::Min(100, $PercentComplete) }
        Write-Progress @progressParams
    }
    catch {
        Write-Verbose "Write-ScoutProgress: Write-Progress failed, continuing without a progress bar: $($_.Exception.Message)"
    }

    # ---- log-friendly single-line fallback for headless/CI hosts ----
    # Only emitted when the interactive bar above is suppressed
    # ($ProgressPreference = 'SilentlyContinue', e.g. Invoke-ScoutPipeline's
    # non-interactive mode) -- an interactive console gets the live bar only, not
    # both a bar AND a scrolling duplicate line per call.
    if (-not $Completed -and $ProgressPreference -eq 'SilentlyContinue') {
        try {
            $pctText = if ($PercentComplete -ge 0) { "$PercentComplete%" } else { '...' }
            $line = "[$Activity] $pctText $Status"
            $supportsAnsi = $false
            try { $supportsAnsi = $Host.UI.SupportsVirtualTerminal -and -not $env:NO_COLOR } catch { $supportsAnsi = $false }
            if ($supportsAnsi) {
                $esc = [char]27
                Write-Information "$esc[36m$line$esc[0m" -InformationAction Continue
            }
            else {
                Write-Information $line -InformationAction Continue
            }
        }
        catch {
            Write-Verbose "Write-ScoutProgress: log-line fallback failed: $($_.Exception.Message)"
        }
    }
}
