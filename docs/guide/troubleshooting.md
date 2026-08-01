---
description: Common errors and solutions when running AzureScout.
---

# Troubleshooting

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Insufficient privileges to complete the operation` | Missing Microsoft Graph permission | Grant the required permission and perform admin consent. See [Permissions](./permissions.md). |
| `Authorization_RequestDenied` | Delegated permission not consented | Sign in with a Global Admin and consent to the required permissions. |
| `Resource provider not registered` / `[FAIL] Provider: ... NotRegistered` | Provider not enabled in subscription | **This is expected.** Not all providers need to be registered in every subscription — Azure only registers providers for services you actually use. The corresponding inventory modules are simply skipped. Only register a provider if you actually use that service and want it included in the report: `Register-AzResourceProvider -ProviderNamespace <namespace>`. See [Prerequisites](./prerequisites.md) for details. |
| `No match was found for the specified search criteria and module name` | Module not available in PSGallery or network restrictions | Install the module manually. See [Prerequisites](./prerequisites.md) for install commands. |
| `Get-AzSubscription returned 0 subscriptions` | Identity has no Reader role on any subscription | Assign `Reader` at the subscription or management group level. |
| `Connect-AzAccount: interactive login failed` | Running in a non-interactive session (CI/CD, SSH) | Use `-DeviceLogin`, SPN with secret, or SPN with certificate. See [Authentication](./authentication.md). |
| `Token acquisition failed for MSGraph` | Az.Accounts version too old or tenant configuration issue | Update `Az.Accounts` to latest: `Update-Module Az.Accounts -Force` |
| `Export-Excel: file is locked` | Excel report file is open in another application | Close the file and re-run. |
| Management Groups / Custom Role Definitions / Policy Definitions / Policy Set Definitions worksheets are empty | First check: is `Reader` assigned at the **tenant-root management group**, not just at individual subscriptions? Subscription-scoped `Reader` silently returns an empty hierarchy — no error. | Assign `Reader` at the tenant-root MG. Since v2.3.0 the login summary reports the visible management-group count at sign-in. If root-MG `Reader` is already in place and the sheet is still empty, that's worth reporting — whether `Management Group Reader` is genuinely additional beyond `Reader` is currently unresolved; see [Permissions](./permissions.md#arm-permissions). Do not reach for a broader role first. |
| A Graph-backed collector (e.g. `IdentityProviders`) is empty and nothing seems wrong with permissions | Some Graph queries are issued but consumed by no collector — Scout still probes them so the pre-flight can tell you they're unnecessary | Expected. The pre-flight prints `Warn ... queried but NO collector reads the result. Do not grant it.` for these — check `-PermissionAudit` / `Test-AZSCPermissions` output rather than granting more access. See [Permissions](./permissions.md#microsoft-graph-permissions). |
| Cost data is empty despite `Reader` (and even `Cost Management Reader`) being assigned | Cost visibility is gated on a **billing setting**, not a role: EA "AO view charges" or MCA "Azure charges" | Have a billing administrator (Enterprise Administrator for EA, **Billing Profile Owner** for MCA) enable the setting. No Azure RBAC role change fixes this. See [Permissions](./permissions.md#arm-permissions). |
| Reports are not where a previous version left them | Run isolation (v2.3.0) | Each run now writes to its own folder under the base path. Use `-Force` for the old overwrite-in-place behaviour, or `-RunName` to control the folder name. See [Output Files & Formats](./output.md#run-isolation). |
| Output folders accumulating on disk | One folder per run, by design | `Clear-AZSCCacheFolder -OlderThan 30` prunes runs not written to in the last 30 days. |
| `No Azure DevOps organizations could be discovered` | Service principals have no profile to enumerate | Pass `-DevOpsOrganization 'contoso','fabrikam'`. See [Azure DevOps](../automation-guide/azure-devops.md). |
| `Could not acquire an Azure DevOps token` | Not signed in, or the sign-in cannot reach Azure DevOps | Run `Connect-AzAccount`, or pass `-DevOpsPat`. |
| ADO Service Connections worksheet missing | Identity holds project read but not service connection read | Expected and handled — that slice is skipped and the rest still collects. Grant the scope to include it. |
| Runbook uploads fail with `blob already exists` | Module older than v2.3.0 | Upgrade. Uploads now pass `-Force`, so a second scheduled run overwrites rather than failing. See [Azure Automation Account](../automation-guide/automation.md). |
| Chart step fails on a GitHub-hosted runner, or `0x80040154 REGDB_E_CLASSNOTREG` | Module older than v2.7.0 — chart customization drove Excel over COM, and no hosted runner has Excel installed | Upgrade. Since v2.7.0 chart styling runs on EPPlus/ImportExcel with no Excel host, so `lite: false` works on a hosted runner. See [GitHub Actions](../automation-guide/github-actions.md). |
| `The term 'Invoke-AzCostManagementQuery' is not recognized` | `Az.CostManagement` missing, and before v2.5.3 `-IncludeCosts` treated that as fatal | Upgrade. Since v2.5.3 the run continues without cost data and warns instead. To collect costs, `Install-Module Az.CostManagement -Scope CurrentUser`. |
| `The property '<name>' cannot be found on this object` during extraction | Module older than v2.5.3 | Upgrade. This was a StrictMode member-enumeration fault that fired whenever an Azure API returned an empty result for **every** subscription — see [Changelog](../project/changelog.md). |

## Run logs

**Every run writes a detailed log into its own run folder — you do not have to ask for it.**
When something goes wrong, read the log before re-running anything.

| File | Contents |
|------|----------|
| `scout-run.log` | Structured log: run metadata header, every phase boundary with elapsed time, per-phase counts, warnings, and — when a run fails — the full error record including the failing script, line number and script stack trace |
| `scout-console.log` | Transcript of everything printed to the console, warnings included. Skipped on hosts that do not support transcription (including Azure Automation) |

Both land next to the report:

```
C:\Users\you\Documents\AzureScout\2026-07-25_152431_d6fc73cf\
├── scout-run.log
├── scout-console.log
└── AzureScout_Report_2026-07-25_15_24.xlsx
```

A failed run prints the log path before it exits:

```
  The run failed. Full detail written to: C:\...\2026-07-25_152431_d6fc73cf\scout-run.log
```

The failure block in `scout-run.log` looks like this — the script and line are the fastest
route to a diagnosis, and are exactly what a bare console error does not give you:

```
[2026-07-25 15:58:09.445] [ERROR] ---------------- RUN FAILED ----------------
[2026-07-25 15:58:09.476] [ERROR] Message    : The term 'Invoke-AzCostManagementQuery' is not recognized...
[2026-07-25 15:58:09.587] [ERROR] Script     : ...\Modules\Private\Extraction\Get-AZTICostInventory.ps1
[2026-07-25 15:58:09.620] [ERROR] Line       : 49
[2026-07-25 15:58:09.682] [ERROR] ScriptStackTrace :
[2026-07-25 15:58:09.711] [ERROR]     at Get-AZSCCostInventory, ...
```

Logging is best-effort by design: if the log cannot be written the run still proceeds, warning
once. A lost log is a lost diagnostic, never a lost report.

## Debugging

For step-by-step tracing beyond the run log, enable debug output:

```powershell
Invoke-AzureScout -TenantID '00000000-...' -Debug
```

This produces timestamped log entries for each extraction step, module execution, and API call.

## A worksheet looks wrong after upgrading — force the previous collector engine

Most inventory collectors are defined declaratively (`manifests/collectors/<Category>/<Name>.psd1`)
and executed by a shared interpreter rather than by their own script. Each definition is proven to
produce the same rows as the script it replaced, and a full processing pass produces a
byte-identical report cache either way — but if a worksheet ever looks wrong and you need to rule
the interpreter out, set this before the run:

```powershell
$env:AZURESCOUT_FORCE_IMPERATIVE_COLLECTORS = '1'
Invoke-AzureScout -TenantID '00000000-...'
```

Every collector then runs as its original script, exactly as releases up to v2.9.0 did. Accepted
values are `1`, `true`, `yes` and `on` (case-insensitive); anything else — including `0` and
`false` — leaves the normal path in place. Clear it with
`Remove-Item Env:\AZURESCOUT_FORCE_IMPERATIVE_COLLECTORS`.

If that changes the output, the difference is a genuine defect worth reporting: attach the
worksheet and the collector name.

The run log records which engine ran each collector — look for `Collectors declarative` and
`Collectors imperative` in the processing phase summary.

## Pre-flight Permission Check

Run the permission checker standalone to validate access before a full inventory:

```powershell
$result = Test-AZSCPermissions -TenantID '00000000-...' -Scope All
$result | Format-List
```

The `Details` array contains per-check results with remediation guidance for any failures. The
output is a per-collector impact table, not a bare READY/PARTIAL/INSUFFICIENT verdict — a denied
permission names the exact collectors that will come back empty rather than a generic warning. A
denied Microsoft Graph permission also reaches PowerShell's warning stream, so a scripted caller
(a pipeline step, a scheduled Automation Account run) can detect it with `-WarningVariable` or by
capturing stream 3, not only a human watching coloured console output. See
[Permissions](./permissions.md#pre-flight-validation).

## Complete Removal (Uninstall)

If you need to completely remove Azure Scout and ensure no old, cached modules are loaded in future sessions, run the following commands. This forces PowerShell to unload the module from memory, uninstalls all registered versions, and physically deletes any lingering cached folders across your module paths.

`powershell
# 1. Unload from current active memory
Remove-Module AzureScout -ErrorAction SilentlyContinue

# 2. Uninstall all registered versions
Uninstall-Module AzureScout -AllVersions -Force -ErrorAction SilentlyContinue

# 3. Aggressively hunt down and delete any physical artifact folders left behind
$modulePaths = ($env:PSModulePath -split ';') | Where-Object { $_ -ne '' }
foreach ($path in $modulePaths) {
    $target = Join-Path $path "AzureScout"
    if (Test-Path $target) {
        Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
    }
}
`

> [!IMPORTANT]
> Once you run these commands, you **must close your PowerShell terminal completely** and open a new one to fully flush the session cache.
