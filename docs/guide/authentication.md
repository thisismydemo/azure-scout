---
description: Five authentication methods supported by AzureScout.
---

# Authentication

::: tip One sign-in for both modes
This page describes `Connect-AZSCLoginSession`, which `Invoke-AzureScout` uses in
**both** modes — inventory and `-Assessment` alike. New here? See the
[Overview](./overview.md).
:::

## Overview

AzureScout supports five authentication methods.
The module uses `Connect-AZSCLoginSession` internally, which selects the auth path based on the parameters you provide.

## Priority Order

When multiple auth parameters are supplied, the module selects the *first* matching path:

1. **SPN + Certificate** — `AppId` + `CertificatePath` (+ optional `CertificatePassword`)
2. **SPN + Client Secret** — `AppId` + `Secret`
3. **Device Code** — `-DeviceLogin` switch
4. **Managed Identity** — Automatic when running in Azure (no parameters needed)
5. **Current User / Interactive** — Default fallback, reuses existing `Get-AzContext`

## Method Details

### 1. Current User (Interactive)

The default. If you've already run `Connect-AzAccount`, AZSC reuses your session.

```powershell
Connect-AzAccount
Invoke-AzureScout
```

If no existing context matches the target tenant, the module calls `Connect-AzAccount` interactively.

### 2. Device Code

For headless or remote sessions (SSH, containers).

```powershell
Invoke-AzureScout -TenantID '00000000-...' -DeviceLogin
```

The module displays a URL and code. Open the link in any browser, enter the code, and authenticate.

### 3. Service Principal + Client Secret

For CI/CD pipelines and unattended automation.

```powershell
Invoke-AzureScout `
    -TenantID  '00000000-...' `
    -AppId     '11111111-...' `
    -Secret    $env:CLIENT_SECRET
```

::: warning
Store the secret in a Key Vault or pipeline secret — never hardcode it.
:::

### 4. Service Principal + Certificate

The most secure SPN method — no secret string to rotate.

```powershell
Invoke-AzureScout `
    -TenantID         '00000000-...' `
    -AppId            '11111111-...' `
    -CertificatePath  'C:\certs\AZSC-spn.pfx' `
    -CertificatePassword $certPwd
```

### 5. Managed Identity

When running inside Azure (VMs, Azure Functions, Azure Automation).
The module detects managed identity automatically — no parameters required.

```powershell
# Inside an Azure VM/Function/Automation Account
Invoke-AzureScout -TenantID '00000000-...'
```

## Azure Environment

All methods accept `-AzureEnvironment` to target sovereign clouds:

```powershell
Invoke-AzureScout -AzureEnvironment AzureUSGovernment
```

Valid values: `AzureCloud` (default), `AzureUSGovernment`, `AzureChinaCloud`, `AzureGermanCloud`.

## LoginExperienceV2

The module checks for the `LoginExperienceV2` Az config setting.
If enabled, it temporarily disables it to ensure compatibility, then restores the original value after login.

## Assessment platform — same sign-in, broader permissions (no separate login)

**Assessment mode does not have its own authentication.** You sign in exactly as
above; the only difference is the *permissions* your identity needs.

`Invoke-AzureScout -Assessment` runs the same `Connect-AZSCLoginSession` flow as
inventory mode and honours the same parameters — `-TenantID`, `-DeviceLogin`,
`-AppId`/`-Secret`, and certificate auth all work identically. An already-active
`Get-AzContext` (from `Connect-AzAccount` or a managed identity) is reused as-is.

::: warning Changed in v2.4.0
Before v2.4.0 the former standalone assessment cmdlet had **no** sign-in
step — it silently required a pre-existing `Connect-AzAccount` context and ignored
the inventory's authentication parameters. Assessment mode on `Invoke-AzureScout`
does not have that gap.
:::

What differs between the modes is the **authorization** model, not the
authentication mechanism: the identity needs ARM `Reader` at the tenant-root
management group for every assessment. Microsoft Graph app permissions are
**not** a default requirement for any assessment — the 5 governance-data
assessments collect natively via ARM/Resource Graph now; Graph only applies
if you explicitly opt one back into the legacy `AzGovViz` ingestor. See
[Auth & permissions per scan type](../assessment/assessment-permissions.md) for the full
breakdown and [Assessment Prerequisites](../assessment/assessment-prerequisites.md) for the
software/module prerequisites.

::: tip Azure RBAC, Entra directory roles, and Graph app permissions are separate systems
An identity's Azure RBAC role assignments say nothing about what it can read in Entra ID, and
vice versa — an Owner on every subscription in the tenant still reads zero directory data. If
you're running `-Scope All`/`EntraOnly` as a signed-in **user**, grant the Entra directory roles
`Directory Readers` + `Security Reader`. If you're running as a **service principal**, grant the
equivalent Microsoft Graph application permissions instead. See
[Permissions](./permissions.md#microsoft-graph-permissions) for both lists.
:::
