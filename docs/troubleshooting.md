---
description: Common errors and solutions when running AzureScout.
---

# Troubleshooting

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Insufficient privileges to complete the operation` | Missing Microsoft Graph permission | Grant the required permission and perform admin consent. See [Permissions](permissions.md). |
| `Authorization_RequestDenied` | Delegated permission not consented | Sign in with a Global Admin and consent to the required permissions. |
| `Resource provider not registered` / `[FAIL] Provider: ... NotRegistered` | Provider not enabled in subscription | **This is expected.** Not all providers need to be registered in every subscription — Azure only registers providers for services you actually use. The corresponding inventory modules are simply skipped. Only register a provider if you actually use that service and want it included in the report: `Register-AzResourceProvider -ProviderNamespace <namespace>`. See [Prerequisites](prerequisites.md) for details. |
| `No match was found for the specified search criteria and module name` | Module not available in PSGallery or network restrictions | Install the module manually. See [Prerequisites](prerequisites.md) for install commands. |
| `Get-AzSubscription returned 0 subscriptions` | Identity has no Reader role on any subscription | Assign `Reader` at the subscription or management group level. |
| `Connect-AzAccount: interactive login failed` | Running in a non-interactive session (CI/CD, SSH) | Use `-DeviceLogin`, SPN with secret, or SPN with certificate. See [Authentication](authentication.md). |
| `Token acquisition failed for MSGraph` | Az.Accounts version too old or tenant configuration issue | Update `Az.Accounts` to latest: `Update-Module Az.Accounts -Force` |
| `Export-Excel: file is locked` | Excel report file is open in another application | Close the file and re-run. |

## Debugging

Enable verbose debug output to diagnose issues:

```powershell
Invoke-AzureScout -TenantID '00000000-...' -Debug
```

This produces timestamped log entries for each extraction step, module execution, and API call.

## Pre-flight Permission Check

Run the permission checker standalone to validate access before a full inventory:

```powershell
$result = Test-AZSCPermissions -TenantID '00000000-...' -Scope All
$result | Format-List
```

The `Details` array contains per-check results with remediation guidance for any failures.
