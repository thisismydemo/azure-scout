---
description: Run AzureScout as a GitHub Action to generate inventory reports from a CI pipeline, on a schedule, or on demand.
---

# GitHub Actions

AzureScout ships a composite action, so a workflow can produce an inventory report without
installing PowerShell modules by hand or checking anything out.

```yaml
- uses: thisismydemo/azure-scout@v2
  with:
    tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
    client-id:     ${{ secrets.AZURE_CLIENT_ID }}
    client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
```

The action installs the module and its dependencies, authenticates with the service
principal, runs the collection, and uploads the reports as a workflow artifact.

## Prerequisites

An Entra app registration (service principal) with a client secret, holding at least
**Reader** on the scope you want to inventory. Store three values as repository secrets
under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_CLIENT_ID` | Application (client) ID |
| `AZURE_CLIENT_SECRET` | Client secret value |

Add `AZURE_SUBSCRIPTION_ID` too if you want to scan one subscription rather than every
subscription the principal can read.

For `scope: All` or `scope: EntraOnly`, the app registration also needs Microsoft Graph
**application** permissions with admin consent granted. See [Permissions](../guide/permissions.md).

## A scheduled weekly inventory

```yaml
name: Weekly Azure Inventory

on:
  schedule:
    - cron: '0 6 * * 1'   # Mondays, 06:00 UTC
  workflow_dispatch:

permissions:
  contents: read

jobs:
  inventory:
    runs-on: ubuntu-latest
    steps:
      - uses: thisismydemo/azure-scout@v2
        with:
          tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
          client-id:     ${{ secrets.AZURE_CLIENT_ID }}
          client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          scope:         ArmOnly
          output-format: All
          artifact-retention-days: '90'
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `tenant-id` | *(required)* | Entra tenant (directory) ID |
| `client-id` | `''` | Service principal client ID |
| `client-secret` | `''` | Client secret — always from a secret, never a literal |
| `subscription-id` | `''` | Single subscription to scan; blank scans all readable subscriptions |
| `scope` | `ArmOnly` | `ArmOnly`, `EntraOnly`, or `All` |
| `category` | `''` | Comma-separated category filter, e.g. `Compute,Networking` |
| `output-format` | `All` | `All`, `Excel`, `Json`, `Markdown`, `AsciiDoc`, or `PowerBI` |
| `report-name` | `AzureScout` | Report file name prefix |
| `report-dir` | `azure-scout-reports` | Output directory, relative to the workspace |
| `module-version` | `''` | Pin a PSGallery version; blank installs the latest |
| `lite` | `true` | Skip Excel chart customization — see the note below |
| `include-costs` | `false` | Collect cost data. Needs `Reader` plus the EA *"AO view charges"* / MCA *"Azure charges"* billing setting — **not** `Cost Management Reader`, which is redundant against `Reader` and cannot unlock the billing gate |
| `upload-artifact` | `true` | Upload the report directory as an artifact |
| `artifact-name` | `azure-scout-reports` | Artifact name |
| `artifact-retention-days` | `30` | Artifact retention |

`client-id` and `client-secret` must be supplied together. Omit both to reuse an Azure
context established by an earlier step, such as an OIDC login via `azure/login`.

## Outputs

| Output | Description |
|---|---|
| `report-dir` | Absolute path to the generated report directory |
| `report-count` | Number of report files generated |

```yaml
- uses: thisismydemo/azure-scout@v2
  id: scout
  with:
    tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
    client-id:     ${{ secrets.AZURE_CLIENT_ID }}
    client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}

- name: Fail if the scan produced nothing
  if: steps.scout.outputs.report-count == '0'
  run: exit 1
```

::: tip `lite: false` is safe on hosted runners since v2.7.0
Excel chart customization used to drive Excel itself through COM automation, so it failed on
any runner without a local Excel install — which is every GitHub-hosted runner, Windows
included. AB#5665 deleted that COM path: chart, shape and tab styling now runs on
EPPlus/ImportExcel (`Build-AZSCExcelChartStyle`) against the already-open workbook, with no
Excel host at all. `lite: false` no longer fails at the chart step on a hosted runner.
:::

## Narrowing a scan by category

A full tenant scan is expensive. Split it or narrow it:

```yaml
      - uses: thisismydemo/azure-scout@v2
        with:
          tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
          client-id:     ${{ secrets.AZURE_CLIENT_ID }}
          client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          category:      'Compute,Networking,Storage'
```

Category values and their aliases are in the [Category Reference](../reference/category-reference.md).

## Running the whole tenant in parallel

Matrix the categories to stay inside job time limits and get results sooner:

```yaml
jobs:
  inventory:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        category:
          - 'Compute,Containers,Web'
          - 'Networking,Storage,Databases'
          - 'AI,Analytics,IoT'
          - 'Identity,Security,Management'
          - 'Hybrid,Monitor,Integration'
    steps:
      - uses: thisismydemo/azure-scout@v2
        with:
          tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
          client-id:     ${{ secrets.AZURE_CLIENT_ID }}
          client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
          category:      ${{ matrix.category }}
          artifact-name: inventory-${{ strategy.job-index }}
```

Give each matrix leg a distinct `artifact-name`; identical names collide on upload.

## Publishing reports to Azure Storage

The action leaves reports in the workspace, so any upload step can pick them up:

```yaml
      - uses: thisismydemo/azure-scout@v2
        id: scout
        with:
          tenant-id:     ${{ secrets.AZURE_TENANT_ID }}
          client-id:     ${{ secrets.AZURE_CLIENT_ID }}
          client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}

      - name: Upload to blob storage
        shell: pwsh
        env:
          TENANT_ID:     ${{ secrets.AZURE_TENANT_ID }}
          CLIENT_ID:     ${{ secrets.AZURE_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          REPORT_DIR:    ${{ steps.scout.outputs.report-dir }}
        run: |
          $sec  = ConvertTo-SecureString $env:CLIENT_SECRET -AsPlainText -Force
          $cred = [pscredential]::new($env:CLIENT_ID, $sec)
          Connect-AzAccount -ServicePrincipal -Tenant $env:TENANT_ID -Credential $cred | Out-Null
          $ctx = New-AzStorageContext -StorageAccountName 'yourstorageaccount' -UseConnectedAccount
          Get-ChildItem -Path $env:REPORT_DIR -File | ForEach-Object {
              Set-AzStorageBlobContent -File $_.FullName -Container 'azurescout-reports' -Blob $_.Name -Context $ctx -Force
          }
```

The service principal needs **Storage Blob Data Contributor** on the storage account —
`Contributor` alone grants management-plane rights and still fails the data-plane write.

## Security notes

- Pass secrets through `with:` from `secrets.*` only. A literal in the workflow file is
  committed to history.
- The action reads every input through an environment variable rather than interpolating
  `${{ }}` into a script body, so a crafted input value cannot break out and execute.
- AzureScout is read-only against your tenant. It issues no write operations.
- `permissions: contents: read` is enough; the action needs no write scope on the repo.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Chart step fails on a hosted runner | `lite: false` | Set `lite: true` |
| `AADSTS7000215: Invalid client secret` | Secret expired or mis-copied | Regenerate and update the repository secret |
| Zero resources collected | No Reader on the target scope | Assign Reader to the app registration |
| Entra worksheets empty with `scope: All` | Graph application permissions missing or unconsented | See [Permissions](../guide/permissions.md) |
| Artifact upload finds no files | Collection produced nothing — check the log for the resource count | Confirm the scope and subscription ID |
| Two matrix legs overwrite each other's artifact | Shared `artifact-name` | Give each leg a distinct name |

## Related

- [Azure Automation Account](./automation.md) — the scheduled, in-Azure alternative
- [Authentication](../guide/authentication.md) — every supported login method
- [Category Reference](../reference/category-reference.md) — category values and aliases
- [Parameters](../guide/parameters.md) — the full parameter set behind these inputs
