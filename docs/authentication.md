---
description: Five authentication methods supported by AzureScout.
---

# Authentication

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

**The CAF/WAF assessment platform does not have its own authentication.** This
section is an FYI to make that explicit: you sign in exactly as above, and the
only difference is the *permissions* your identity needs.

Everything above is `Connect-AZSCLoginSession`, used by the v1 inventory
cmdlet (`Invoke-AzureScout`). The v2 assessment platform
(`Invoke-ScoutAssessment`, `Test-ScoutPermission`) does **not** have its own
sign-in flow — it reuses whatever `Get-AzContext` is already active (i.e.
authenticate with `Connect-AzAccount`, any of the five methods above, or a
managed identity, then run `Invoke-ScoutAssessment`). What differs is the
**authorization** model, not the authentication mechanism: the identity you
sign in as needs ARM `Reader` at the tenant-root management group for every
assessment, and Microsoft Graph application permissions for 5 specific
assessments. See [Auth & permissions per scan type](assessment-permissions.md)
for the full breakdown and [Assessment Prerequisites](assessment-prerequisites.md)
for the software/module prerequisites.
