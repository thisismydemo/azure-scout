<#
.SYNOPSIS
Checks PSGallery for a newer AzureScout release than the one currently loaded and
surfaces it to the caller (AB#369).

.DESCRIPTION
Called once from AzureScout.psm1 on module import, right after the module's own
functions are dot-sourced. This is the auto-UPDATE counterpart to the auto-INSTALL
dependency bootstrap at the top of AzureScout.psm1 -- same "never block import"
contract, same non-fatal try/catch style.

Never throws: every external call (Get-Module, Find-Module, Update-Module) is
reached only inside a try/catch, so an offline host, an unreachable PSGallery, or a
throttled/misconfigured repository degrades to a Write-Verbose and nothing else.
Import always proceeds regardless of what this function does.

Notify-only by default. A real reinstall is only attempted if the caller has
explicitly opted in via $env:AZURESCOUT_AUTO_UPDATE, and that opt-in is itself
ignored whenever a CI/automation signal is detected -- a pinned automation run
must never be silently moved onto a different module version mid-run. Absent the
opt-in, a newer version is only ever surfaced via Write-Warning with the exact
command to run.

.PARAMETER ManifestPath
Path to the AzureScout.psd1 manifest used to determine the currently-loaded
version when Get-Module can't yet see the module (e.g. mid-import). Defaults to
the manifest that ships alongside this module.

.NOTES
Throttle design: at most once every 24 hours, tracked via a small marker file in
the machine temp directory (not an in-memory/session flag). AzureScout is
typically re-imported once per new pwsh process (a fresh terminal session), so an
in-memory-only guard would not actually throttle anything across the common
"open a terminal, import the module" workflow -- only a file-based marker
persists across processes and avoids a PSGallery round-trip on every session.

CI/automation guard: any of the common CI environment variables (CI, TF_BUILD --
Azure DevOps, GITHUB_ACTIONS -- GitHub Actions) skip the entire check, not just
the reinstall. This keeps pinned/automation runs fast and deterministic -- no
surprise network call, no surprise notice, no chance of an unattended reinstall.
Opt out of the check entirely (interactively too) with $env:AZURESCOUT_SKIP_UPDATE_CHECK.

.COMPONENT
This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
Version: 1.0.0
First Release Date: 23rd Jul, 2026
Work item: AB#369
#>
function Test-AZSCModuleUpdate {
    [CmdletBinding()]
    param(
        [string]$ManifestPath = (Join-Path $PSScriptRoot '..\..\..\AzureScout.psd1')
    )

    # Opt-out: skip the check entirely, no network call at all.
    if ($env:AZURESCOUT_SKIP_UPDATE_CHECK) {
        Write-Verbose '[AzureScout] Update check skipped ($env:AZURESCOUT_SKIP_UPDATE_CHECK set).'
        return
    }

    # CI/automation guard -- a pinned automation run should never spend time on, or be
    # surprised by, this check (and must never be auto-updated out from under it).
    $_isCi = [bool]($env:CI -or $env:TF_BUILD -or $env:GITHUB_ACTIONS)
    if ($_isCi) {
        Write-Verbose '[AzureScout] Update check skipped (CI/automation environment detected).'
        return
    }

    try {
        # Throttle: once per 24h, tracked in a marker file (see .NOTES for rationale).
        $_throttleFile = Join-Path ([System.IO.Path]::GetTempPath()) 'azurescout-update-check.txt'
        if (Test-Path -Path $_throttleFile -ErrorAction SilentlyContinue) {
            $_lastCheckRaw = Get-Content -Path $_throttleFile -Raw -ErrorAction SilentlyContinue
            $_lastCheck = [datetime]::MinValue
            if ($_lastCheckRaw -and [DateTime]::TryParse($_lastCheckRaw.Trim(), [ref]$_lastCheck)) {
                if (((Get-Date) - $_lastCheck).TotalHours -lt 24) {
                    Write-Verbose '[AzureScout] Update check throttled (checked within the last 24 hours).'
                    return
                }
            }
        }
        Set-Content -Path $_throttleFile -Value (Get-Date -Format 'o') -ErrorAction SilentlyContinue

        # Locally-loaded version: prefer an already-imported module instance, else fall
        # back to reading the manifest directly (Get-Module can't see this module yet
        # while AzureScout.psm1 is still mid-import).
        $_localVersion = (Get-Module -Name AzureScout -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1).Version
        if (-not $_localVersion) {
            $_localVersion = (Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop).Version
        }

        $_galleryModule = Find-Module -Name AzureScout -Repository PSGallery -ErrorAction Stop
        $_galleryVersion = [Version]$_galleryModule.Version

        if ($_galleryVersion -gt $_localVersion) {
            if ($env:AZURESCOUT_AUTO_UPDATE) {
                Write-Warning "[AzureScout] Newer version $_galleryVersion found (you have $_localVersion) -- updating (`$env:AZURESCOUT_AUTO_UPDATE is set)..."
                try {
                    Update-Module -Name AzureScout -Force -ErrorAction Stop
                    Write-Warning "[AzureScout] Updated to $_galleryVersion. Restart your PowerShell session to load it."
                } catch {
                    Write-Warning "[AzureScout] Auto-update to $_galleryVersion failed: $_. Run 'Update-Module AzureScout' manually."
                }
            } else {
                Write-Warning "[AzureScout] A newer version is available: $_galleryVersion (you have $_localVersion). Run 'Update-Module AzureScout' to update, or set `$env:AZURESCOUT_AUTO_UPDATE = '1' to update automatically on import."
            }
        } else {
            Write-Verbose "[AzureScout] Already at the latest version ($_localVersion)."
        }
    } catch {
        Write-Verbose "[AzureScout] Update check skipped: $_"
    }
}
