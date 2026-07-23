---
description: Complete reference of all Invoke-AzureScout and Test-AZSCPermissions parameters.
---

# Parameters Reference

## Invoke-AzureScout Parameters

### Core

| Parameter | Description |
|-----------|-------------|
| `-TenantID` | Target Azure AD / Entra ID tenant ID |
| `-SubscriptionID` | Limit to one or more specific subscription IDs (comma-separated or array) |
| `-ResourceGroup` | Limit to one or more specific resource groups |
| `-ManagementGroup` | Inventory all subscriptions under a management group |
| `-Scope` | `ArmOnly` (default), `All`, or `EntraOnly` — controls which data domains are inventoried |
| `-OutputFormat` | `All` (default), `Excel`, `Json`, `Markdown` (`MD`), `AsciiDoc` (`Adoc`), `PowerBI` — controls report file types; `PowerBI` generates flat normalized CSVs in a `PowerBI/` subfolder optimized for Power BI / Microsoft Fabric |
| `-Category` | Filter by resource category: `AI`, `Analytics`, `Compute`, `Containers`, `Databases`, `Hybrid`, `Identity`, `Integration`, `IoT`, `Management`, `Monitor`, `Networking`, `Security`, `Storage`, `Web` — see [Category Filtering](category-filtering.md) |

### Authentication

| Parameter | Description |
|-----------|-------------|
| `-AppId` | Service principal application (client) ID |
| `-Secret` | Service principal client secret or certificate password |
| `-CertificatePath` | Path to `.pfx` certificate file for SPN authentication |
| `-DeviceLogin` | Use device code authentication flow (for headless/remote sessions) |

See [Authentication](authentication.md) for detailed examples of each method.

### Content Options

| Parameter | Description |
|-----------|-------------|
| `-SecurityCenter` | Include Microsoft Defender for Cloud data (assessments, alerts, secure score) |
| `-IncludeTags` | Include resource tags in Excel worksheets |
| `-SkipPolicy` | Skip Azure Policy compliance collection |
| `-SkipAdvisory` | Skip Azure Advisor recommendation collection |
| `-SkipVMDetails` | Skip extra VM detail collection (extensions, boot diagnostics status) |
| `-SkipDiagram` | Skip network diagram generation |
| `-SkipPermissionCheck` | Skip the pre-flight permission validation |

### Output

| Parameter | Description |
|-----------|-------------|
| `-ReportName` | Custom report filename (default: `AzureScout_Report_<timestamp>`) |
| `-ReportDir` | Custom output directory (default: `C:\AzureScout\` on Windows, `$HOME/AzureScout/` on Linux/Mac) |
| `-Lite` | Lightweight Excel report — no charts or pivot tables |

### Diagram

| Parameter | Description |
|-----------|-------------|
| `-DiagramFullEnvironment` | Include all network components in the draw.io topology diagram |

### Other

| Parameter | Description |
|-----------|-------------|
| `-AzureEnvironment` | Target Azure cloud: `AzureCloud` (default), `AzureUSGovernment`, `AzureChinaCloud`, `AzureGermanCloud` |
| `-Debug` | Verbose debug output during extraction and processing |

## Test-AZSCPermissions Parameters

| Parameter | Description |
|-----------|-------------|
| `-TenantID` | Target tenant ID to validate permissions against |
| `-Scope` | `All` (default), `ArmOnly`, or `EntraOnly` — controls which permission checks run |

Returns a structured object:

```powershell
$result = Test-AZSCPermissions -TenantID '00000000-...' -Scope All
$result.ArmAccess    # $true / $false
$result.GraphAccess  # $true / $false
$result.Details      # Array of check results with remediation guidance
```

See [Permissions](permissions.md) for the full list of required roles and API permissions.

## Invoke-ScoutAssessment Parameters

Entry point for the **CAF/WAF assessment platform** (v2.0.0) — a separate
cmdlet from `Invoke-AzureScout`, with its own parameter set. Full run-mode
examples: [Assessment guide](assessment.md#run-modes).

| Parameter | Description |
|-----------|-------------|
| `-Assessment` | One, several, or `All` assessment names from `manifests/assessments.psd1` (default: `Estate`). See the [Assessment Registry](design/assessment-registry.md) for all 22. |
| `-Scope` | `All` (default), `ArmOnly`, or `EntraOnly` — accepted and recorded, but currently does not change what the Collect layer queries; see [the caveat](assessment.md#-scope). |
| `-Category` | Overrides the categories recorded for the run; does not change which rules are scored. See [the caveat](assessment.md#-category-override). |
| `-OutputFormat` | `PowerBi`, `Html`, `Pptx`, `Excel`, `Json`, or `All` (default: `Html`) — accepts an array. |
| `-OutputPath` | Base output directory (default: `./output`); each run writes to a `<OutputPath>/yyyyMMdd_HHmmss/` subfolder. |
| `-PermissionAudit` | Switch — runs `Test-ScoutPermission` for the requested `-Assessment` set and returns before any collection happens. |
| `-CollectOnly` | Switch — stop after Collect; returns the path to `collect.json`. |
| `-FromCollect` | Path to an existing `collect.json` — skips Collect/Ingest and assesses/reports from it directly. |
| `-ManagementGroupId` | Scopes the AzGovViz ingest for assessments that need it (`LandingZone`, `Management`, `Identity`, `Governance`, `Policy`). Does **not** scope the Resource Graph collect itself. |

## Test-ScoutPermission Parameters

Read-only permission pre-flight for the assessment platform — distinct from
`Test-AZSCPermissions` above. Normally invoked via
`Invoke-ScoutAssessment -PermissionAudit` rather than called directly.

| Parameter | Description |
|-----------|-------------|
| `-Assessment` | The assessment name(s) to check permissions for. |
| `-Manifest` | The imported `manifests/assessments.psd1` hashtable (passed automatically by `Invoke-ScoutAssessment`). |

Returns an array of `[pscustomobject]` results (`Check`, `Ok`, `Fix`) — the
ARM check's `Ok` is a live-validated `$true`/`$false`; the Graph checks'
`Ok` is always `$null` (informational, not live-verified). Full explanation:
[what `-PermissionAudit` actually verifies](assessment-permissions.md#what-permissionaudit-actually-verifies).
