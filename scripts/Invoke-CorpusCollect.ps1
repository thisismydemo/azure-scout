#Requires -Version 7.0
<#
.SYNOPSIS
    Collect the multi-tenant data corpus: one collect.json per tenant, data only, no reports.

.DESCRIPTION
    AB#6898. The corpus (D:\azure-scout-corpus, never in git) exists so report work renders
    offline from banked data instead of re-scanning Azure (AB#6450 ground rule). The previous
    corpus was collected by an ad-hoc, unpreserved harness and banked rows whose nested
    `properties.*` fields were null in every tenant -- so every report rendered from it showed
    empty sections and three healthy collectors were mis-diagnosed as broken (AB#6896). This
    script is the committed replacement, and it refuses to bank silently-bad data: every tenant's
    collect.json is integrity-checked before it counts as 'ok'.

    Authentication is service-principal per tenant (the 1-hour bearer tokens the old run used can
    expire mid-run). Credentials come from a JSON file OUTSIDE the repo -- pass -CredentialPath;
    the file is an array of { alias, tenantId, clientId, secret } or, for a tenant whose platform
    vault denies the broker (azlmgmt/tppoc today), { alias, tenantId, clientId, token } carrying a
    fresh ARM bearer token from the HCS Governance MCP's get_auth_token. Secrets never appear in
    arguments, transcripts, or the corpus.

.EXAMPLE
    ./scripts/Invoke-CorpusCollect.ps1 -CredentialPath $env:TEMP\corpus-creds.json

.NOTES
    Collect ONLY. If a .docx/.pptx/.xlsx or figures/ ever appears under a run stamp, something
    ran a report pass against the corpus -- see the corpus README.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $CredentialPath,
    [string] $CorpusRoot = 'D:\azure-scout-corpus',
    # yyyy-MM-dd-runNN; default derives a fresh stamp for today.
    [string] $RunStamp,
    # Subset of aliases to (re)collect; default is every entry in the credential file.
    [string[]] $Alias
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$creds = Get-Content -LiteralPath $CredentialPath -Raw | ConvertFrom-Json
if ($Alias) { $creds = @($creds | Where-Object { $Alias -contains $_.alias }) }
if (@($creds).Count -eq 0) { throw "No tenants selected from '$CredentialPath'." }

if (-not $RunStamp) {
    $day = Get-Date -Format 'yyyy-MM-dd'
    $n = 1
    while (Test-Path (Join-Path $CorpusRoot ('{0}-run{1:d2}' -f $day, $n))) { $n++ }
    $RunStamp = '{0}-run{1:d2}' -f $day, $n
}
$runRoot = Join-Path $CorpusRoot $RunStamp
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
Write-Host "corpus run: $runRoot  ($(@($creds).Count) tenant(s))" -ForegroundColor Cyan

Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.ResourceGraph -ErrorAction Stop
# Invoke-AzureScout sets this for interactive runs; this harness calls the assessment core
# directly, so it must do the same or every tenant's log fills with Az upcoming-breaking-change
# banners that read like collection errors.
$env:SuppressAzurePowerShellBreakingChangeWarnings = 'true'
# The process must not inherit (or persist) any interactive context: the previous stale-token
# failure mode was the saved profile shadowing the credential actually passed in.
Disable-AzContextAutosave -Scope Process -WarningAction SilentlyContinue | Out-Null

Import-Module (Join-Path $repoRoot 'AzureScout.psd1') -Force -ErrorAction Stop
$scoutModule = Get-Module AzureScout

function Test-CorpusCollectIntegrity {
    <#
        Heuristics over a freshly-written collect.json that catch the exact corruption class the
        stale corpus had: rows present, nested scalars all null/empty. Each returns a finding
        string; an empty list means the bank is trustworthy. These are relationship checks
        ("a VNet always carries subnets"), not row-count expectations -- an empty estate passes.
    #>
    param([Parameter(Mandatory)] [string] $Path)
    $findings = [System.Collections.Generic.List[string]]::new()
    $c = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100

    $vnets = @($c.networking.virtualNetworks)
    if ($vnets.Count -gt 0 -and @($c.networking.subnets).Count -eq 0) {
        $findings.Add("networking: $($vnets.Count) VNet(s) but zero subnet rows -- an Azure VNet cannot exist without subnets, so the nested read is broken")
    }
    $laws = @($c.management.logAnalyticsWorkspaces)
    if ($laws.Count -gt 0 -and -not ($laws | Where-Object { $null -ne $_.retentionInDays })) {
        $findings.Add("management: $($laws.Count) Log Analytics workspace(s), all with null retentionInDays -- the service default is 30, null everywhere means the property read failed")
    }
    $sas = @($c.domains.storage.storageAccounts)
    if ($sas.Count -gt 0 -and -not ($sas | Where-Object { $_.minTls })) {
        $findings.Add("storage: $($sas.Count) account(s), all with empty minTls -- every storage account carries minimumTlsVersion")
    }
    $vms = @($c.compute.virtualMachines)
    if ($vms.Count -gt 0 -and -not ($vms | Where-Object { $_.size })) {
        $findings.Add("compute: $($vms.Count) VM(s), all with empty size -- every VM carries hardwareProfile.vmSize")
    }
    # The AB#6845/AB#6895 vanishing-parent signature: children without their parent.
    if (@($c.management.backupProtectedItems).Count -gt 0 -and @($c.management.recoveryVaults).Count -eq 0) {
        $findings.Add('management: backup protected items exist but zero Recovery Services vaults -- a protected item cannot exist without a vault (AB#6896)')
    }
    return , @($findings)
}

$manifest = [System.Collections.Generic.List[object]]::new()

foreach ($t in $creds) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $entry = [ordered]@{
        alias = $t.alias; tenantId = $t.tenantId; status = 'failed'
        subscriptions = 0; minutes = 0.0; collectMB = 0.0
        warnings = 0; integrity = @(); error = $null
    }
    $tenantDir = Join-Path $runRoot $t.alias
    New-Item -ItemType Directory -Path $tenantDir -Force | Out-Null
    $log = Join-Path $tenantDir 'collect.log'

    Write-Host "`n=== $($t.alias) ($($t.tenantId)) ===" -ForegroundColor Yellow
    try {
        Clear-AzContext -Scope Process -Force -ErrorAction SilentlyContinue | Out-Null
        if ($t.PSObject.Properties['token'] -and $t.token) {
            # Bearer-token fallback. TWO traps behind the same 'The access token is invalid'
            # message: (1) -AccessToken is a PLAIN [string] parameter -- a SecureString gets
            # stringified to 'System.Security.SecureString' and rejected; (2) a BOM or trailing
            # newline in the token has the same effect, hence the Trim.
            Connect-AzAccount -AccessToken ([string]$t.token).Trim() -AccountId $t.clientId -Tenant $t.tenantId -WarningAction SilentlyContinue | Out-Null
        }
        else {
            $cred = [pscredential]::new($t.clientId, (ConvertTo-SecureString $t.secret -AsPlainText -Force))
            Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $t.tenantId -WarningAction SilentlyContinue | Out-Null
        }

        # -Assessment All maximises the Collect category set, so every collector with a
        # declared category runs. Warnings are captured, counted, and preserved in the log --
        # the bar is a run the operator never has to read an error out of.
        $warnings = [System.Collections.Generic.List[string]]::new()
        $collectPath = & $scoutModule {
            param($OutPath)
            Invoke-ScoutAssessmentCore -Assessment All -CollectOnly -OutputPath $OutPath
        } $tenantDir 3>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.WarningRecord]) { $warnings.Add([string]$_); $null } else { $_ }
        } | Where-Object { $_ } | Select-Object -Last 1

        $warnings | Set-Content -LiteralPath $log -Encoding utf8
        $entry.warnings = $warnings.Count
        if (-not $collectPath -or -not (Test-Path $collectPath)) { throw 'collect returned no collect.json path' }

        $c = Get-Content -LiteralPath $collectPath -Raw | ConvertFrom-Json -Depth 100
        $entry.subscriptions = @($c.subscriptions).Count
        $entry.collectMB = [Math]::Round((Get-Item $collectPath).Length / 1MB, 2)

        $integrity = Test-CorpusCollectIntegrity -Path $collectPath
        $entry.integrity = @($integrity)
        $entry.status = if ($integrity.Count -gt 0) { 'suspect' } else { 'ok' }
        if ($integrity.Count -gt 0) {
            Write-Host "INTEGRITY FAILED for $($t.alias):" -ForegroundColor Red
            $integrity | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        }
        else {
            Write-Host "ok: $($entry.subscriptions) sub(s), $($entry.collectMB) MB, $($entry.warnings) warning(s)" -ForegroundColor Green
        }
    }
    catch {
        $entry.error = $_.Exception.Message
        Write-Host "FAILED: $($entry.error)" -ForegroundColor Red
    }
    finally {
        $entry.minutes = [Math]::Round($sw.Elapsed.TotalMinutes, 1)
        $manifest.Add([pscustomobject]$entry)
        # Write incrementally so a mid-run failure still leaves an accurate record.
        $manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $runRoot 'manifest.json') -Encoding utf8
    }
}

Clear-AzContext -Scope Process -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "`n=== corpus run complete ===" -ForegroundColor Cyan
$manifest | Format-Table alias, status, subscriptions, minutes, collectMB, warnings -AutoSize
$bad = @($manifest | Where-Object { $_.status -ne 'ok' })
if ($bad.Count -gt 0) {
    Write-Warning "$($bad.Count) tenant(s) not ok: $(($bad | ForEach-Object { $_.alias }) -join ', ') -- do NOT render from those banks."
    exit 1
}
