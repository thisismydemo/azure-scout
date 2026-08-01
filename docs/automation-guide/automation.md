---
description: Run AzureScout unattended from an Azure Automation Account with a system-assigned managed identity, writing reports to blob storage.
---

# Azure Automation Account

AzureScout runs unattended inside an Azure Automation Account runbook. The runbook
authenticates with the Automation Account's system-assigned managed identity, collects the
inventory, and uploads the reports to a blob container — no interactive login, no stored
secret, nothing to rotate.

This is the recommended way to produce inventory on a schedule. For CI-triggered runs, see
[GitHub Actions](./github-actions.md) instead.

## How automation mode differs

`-Automation` changes two things about a run:

- **No interactive login.** The runbook is expected to have already connected with
  `Connect-AzAccount -Identity`.
- **Progress goes to the job stream.** Output uses `Write-Output` rather than
  `Write-Progress`, so it lands in the runbook's Output stream where you can read it.

It used to change a third: automation mode substituted `Start-ThreadJob` for the
process-isolated `Start-Job` the interactive path used, because Automation sandboxes do not
support the latter. **Neither is used any more.** The processing phase runs every collector
in-process, in a fixed order, so automation and interactive runs now execute identical code —
and there is no longer a job type that the sandbox might not support. See the AB#5649 entry in
the [changelog](../project/changelog.md).

Diagram generation still uses background jobs, and is skipped in automation mode regardless.
The Excel workbook, JSON, and any other selected output formats are produced normally.

## Prerequisites

| Resource | Purpose |
|---|---|
| Automation Account | Hosts the runbook and the managed identity |
| Storage Account | Destination for the generated reports |
| Blob container | The specific container reports are written to |

Create all three in advance. The identity you use to create them needs Contributor on the
resource group; the runbook itself never creates anything.

## Step 1 — Enable the system-assigned managed identity

In the Automation Account, open **Account Settings → Identity → System assigned** and set
**Status** to **On**. Copy the resulting **Object (principal) ID** — the role assignments
in the next step are made against it.

```powershell
# Or from the CLI
az automation account identity assign `
  --name '<automation-account>' `
  --resource-group '<resource-group>'
```

## Step 2 — Assign RBAC to the managed identity

Two role assignments are required. Scope the Reader role as broadly as you want the
inventory to reach — assign it at the management group root to scan the whole tenant, or
at individual subscriptions to limit it.

```powershell
$principalId = '<object-id-from-step-1>'

# Read the resources being inventoried
New-AzRoleAssignment -ObjectId $principalId `
  -RoleDefinitionName 'Reader' `
  -Scope '/providers/Microsoft.Management/managementGroups/<tenant-root-mg-id>'

# Write the reports to blob storage
New-AzRoleAssignment -ObjectId $principalId `
  -RoleDefinitionName 'Storage Blob Data Contributor' `
  -Scope '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>'
```

`Storage Blob Data Contributor` is required, not `Contributor` — AzureScout uses
`New-AzStorageContext -UseConnectedAccount`, which authenticates to the data plane with
the identity's Entra token rather than a storage account key. A `Contributor` assignment
grants management-plane rights and will still fail the blob write.

Optional roles, matching the interactive [permissions](../guide/permissions.md) model:

| Role | Enables |
|---|---|
| `Management Group Reader` | Management group tree collection |

Without `Management Group Reader` at the tenant root, the run still succeeds — management
group collection is simply empty. The [management group probe](../guide/permissions.md) reports
this at login.

!!! note "Three roles this page used to list are redundant — do not grant them"

    `Security Reader`, `Monitoring Reader` and `Cost Management Reader` were listed here as
    optional. **Every read AzureScout makes through them is already covered by `Reader`'s
    `*/read`**, so they enable nothing and were removed rather than left as a harmless
    over-ask. Two of them are not harmless:

    - **`Monitoring Reader`** grants `Microsoft.Support/*`, which includes support-ticket
      **creation** — a write. AzureScout only reads `Microsoft.Support/supportTickets`.
    - **`Cost Management Reader`** carries the identical `Microsoft.Support/*`.
    - **`Security Reader`** additionally grants five IoT Defender `/action` permissions,
      including one that downloads a password-reset file. AzureScout calls none of them.

    Cost data is **not** gated on `Cost Management Reader`. It is gated on a billing
    setting — EA *"AO view charges"* or MCA *"Azure charges"* — which no RBAC role can
    grant. See [permissions](../guide/permissions.md).

## Step 3 — Configure the Runtime Environment

Automation Accounts run PowerShell 7.x through a **Runtime Environment**. Create or select
one set to **PowerShell 7.4**, then add these packages:

| Module | Why |
|---|---|
| `AzureScout` | The module itself |
| `Az.Accounts` | Authentication and context |
| `Az.ResourceGraph` | The bulk of resource collection |
| `Az.Storage` | Blob upload |
| `Az.Resources` | Role assignments, policy, subscriptions |
| `Az.Compute` | VM detail enrichment |
| `Az.CostManagement` | Only if you use `-IncludeCosts` |
| `ImportExcel` | Excel workbook generation |

Import `AzureScout` from the PowerShell Gallery. Package import is asynchronous — wait for
every module to reach **Available** before running the runbook, or the run fails on a
missing dependency.

## Step 4 — Create the runbook

Create a new runbook of type **PowerShell**, targeting the Runtime Environment from step 3.

```powershell
# Authenticate as the Automation Account's managed identity.
# -Identity is what makes this work unattended; there is no secret involved.
Connect-AzAccount -Identity

Invoke-AzureScout `
    -TenantID        '<tenant-id>' `
    -Automation `
    -StorageAccount  '<storage-account-name>' `
    -StorageContainer '<container-name>' `
    -OutputFormat    'All'
```

Add any collection parameters you would use interactively — `-Category`, `-Scope`,
`-IncludeCosts`, `-SkipPolicy` and so on all behave the same way. See
[Parameters](../guide/parameters.md).

Reports are uploaded with `-Force`, so a scheduled run overwrites the previous run's blob
rather than failing on a name collision. If you want to keep history, either write to a
container per run or enable blob versioning on the storage account.

::: tip Run isolation and the Automation cache
The local run-folder isolation described in [Output](../guide/output.md) still applies inside the
sandbox, but the sandbox filesystem is discarded when the job ends. Blob storage is the
durable copy — that is what `-StorageAccount` is for.
:::

## Step 5 — Schedule it

Under the runbook's **Schedules → Add a schedule**, create a recurring schedule.

| Cadence | Fits |
|---|---|
| Daily | Fast-changing environments, drift detection |
| Weekly | The usual choice — a full tenant scan is not cheap |
| Monthly | Compliance and audit reporting |

Automation Account jobs have a **three-hour fair-share limit**. A full scan of a large
tenant can approach it. If your runs are getting terminated at three hours, split the work
by category across several scheduled runbooks:

```powershell
# Runbook A
Invoke-AzureScout -TenantID '<tenant-id>' -Automation -StorageAccount '<sa>' -StorageContainer '<c>' -Category Compute,Networking,Storage

# Runbook B
Invoke-AzureScout -TenantID '<tenant-id>' -Automation -StorageAccount '<sa>' -StorageContainer '<c>' -Category AI,Analytics,Databases
```

## Step 6 — Verify the first run

Start the runbook manually and watch the **Output** stream. A healthy run prints the
extraction and processing stages, then the upload lines:

```
Sending Excel file to Storage Account:
C:\AzureScout\2026-07-25_101500\AZSC_Automation_Report.xlsx
Sending JSON file to Storage Account:
C:\AzureScout\2026-07-25_101500\AZSC_Automation_Report.json
```

Then confirm the blobs landed in the container.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Connect-AzAccount: no managed identity` | Identity not enabled | Step 1 |
| Run completes, no blobs in the container | Managed identity lacks blob data-plane rights | Assign `Storage Blob Data Contributor`, not `Contributor` (step 2) |
| `The term 'Invoke-AzureScout' is not recognized` | Module not imported into the Runtime Environment, or still importing | Step 3; wait for **Available** |
| Zero resources collected | No `Reader` at the scanned scope | Step 2 — check the assignment scope covers the subscriptions you expect |
| Management Groups worksheet empty | No `Management Group Reader` at tenant root | Optional role in step 2; the run is otherwise valid |
| Job terminated at three hours | Automation fair-share limit | Split by `-Category` (step 5) |
| Diagnostic log not uploaded | Log upload only happens when debug output is enabled | Add `-Debug` to the `Invoke-AzureScout` call in the runbook |
| `blob already exists` | Pre-2.3.0 module | Upgrade — uploads now pass `-Force` |

To capture a diagnostic log for a support issue, add `-Debug` to the runbook's
`Invoke-AzureScout` call. The log is uploaded to the same container alongside the reports.

## Related

- [Parameters](../guide/parameters.md) — every parameter, including `-Automation`, `-StorageAccount`, and `-StorageContainer`
- [Permissions](../guide/permissions.md) — the full role model
- [GitHub Actions](./github-actions.md) — the CI-triggered alternative
- [Output Files & Formats](../guide/output.md) — what gets generated and where
