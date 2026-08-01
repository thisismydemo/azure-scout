---
description: How to run and write Pester tests for AzureScout.
---

# Testing

The test suite uses [Pester 5](https://pester.dev) and runs entirely offline — no Azure credentials or live API calls required. As of 2026-07-31 it is **80 test files, 2,243 tests**: 2,236 passing, 3 skipped, and 4 known cross-file flakes — a VM-quota context restore, an Excel retired-registration check, and two `Test-AZSCPermissions` scoping tests — that fail only when the whole suite shares one temp directory, and pass in isolation.

## Prerequisites

| Requirement | Install Command |
|-------------|-----------------|
| PowerShell 7+ | Built-in on modern Windows; `brew install --cask powershell` on macOS |
| Pester 5.3.2+ | `Install-Module Pester -MinimumVersion 5.3.2 -Force` |
| ImportExcel | `Install-Module ImportExcel -Force` |

## Running the Full Suite

```powershell
Import-Module Pester -RequiredVersion 5.3.2 -Force
Invoke-Pester -Path .\tests\ -Output Detailed
```

This runs all 80 test files (2,243 tests: 2,236 passed, 3 skipped, 4 known cross-file flakes).

## Running a Single Test File

```powershell
# Run only the declarative collector golden tests (all 240 collectors)
Invoke-Pester -Path .\tests\DeclarativeCollectorGolden.Tests.ps1 -Output Detailed

# Run only the private main-function tests
Invoke-Pester -Path .\tests\Private.Main.Tests.ps1 -Output Detailed
```

## Test File Overview

The `tests/` directory contains 80 Pester files. There is no longer one test file per collector
category — the old `<Category>.Module.Tests.ps1` files (`Compute.Module.Tests.ps1`,
`Databases.Module.Tests.ps1`, and so on) tested imperative `.ps1` collectors under
`Modules/Public/InventoryModules/`, and were retired when every collector was rewritten as a
declarative `.psd1` definition (Epic AB#5638, AB#5659). All 240 collectors are now tested by the
files below instead.

### Collector Tests

| Test File | What it proves |
|-----------|-----------------|
| `DeclarativeCollectorGolden.Tests.ps1` | For every `.psd1` under `manifests/collectors/**`, the interpreter reproduces a **committed golden output** — same rows, order, keys, values, null/array shape, and the same Excel worksheet columns/cells under both tag states. This is the primary correctness proof and does not read any collector `.ps1` (there are none left). |
| `ResourceTypeExistence.Tests.ps1` | Every resource type a collector declares exists in Azure — see [the resource-type existence gate](#the-resource-type-existence-gate) below. |
| `DeclarativeCollectorCutover.Tests.ps1` | The declarative interpreter path is actually what runs in production — not a parallel path nobody calls. |
| `CollectorDefinitionSchema.Tests.ps1` | Every `.psd1` definition is structurally valid (required keys present, correct types) before the interpreter ever sees it. |
| `ManifestCategory.Tests.ps1` | Every collector's folder matches a `-Category` `[ValidateSet]` entry, and every `[ValidateSet]` entry has a folder. |
| `ManifestCollectorRuntime.Tests.ps1` | Collectors execute end-to-end through `Invoke-ScoutCollector` against mock resources. |
| `Collector.SparsePayload.Tests.ps1` | Collectors survive a payload missing properties they normally read, instead of dropping a whole worksheet — AB#6839/AB#6844. |
| `Collect.ArmChildResources.Tests.ps1` | Child-loop collectors (agent pools, backup items, etc.) render the parent resource even when children are absent — AB#6845. |
| `ServiceCoverage.Tests.ps1` | Category/collector counts documented in `docs/` (arm-modules.md, coverage-table.md) match the manifests on disk. |

### Fixture Generation

Golden tests need fixtures that reach every field expression a collector reads, or the proof is
vacuous — a fixture with an empty `properties` bag makes any broken expression and any working one
both emit nulls and compare equal. `scripts/New-ScoutCollectorFixture.ps1` derives the fixture from
the collector's **own** `.psd1` definition: it walks the AST of the lifted preamble and field
expressions, finds every property path reached from the row variable, and synthesises a resource
with exactly those paths populated. A hand-written fixture tends to under-populate; a
derived one cannot, because every path the collector reads is present by construction. What it
cannot do is invent realistic *values* — see the script's own `Honest limits` notes.

### Private Module Tests (4 files)

These validate internal helper scripts — file existence, syntax (via `Parser::ParseFile`), and function definitions.

| Test File | Scripts Covered |
|-----------|-----------------|
| `Private.Main.Tests.ps1` | 13 (orchestration, auth, caching) |
| `Private.Extraction.Tests.ps1` | 9 (API, Graph, subscriptions) |
| `Private.Processing.Tests.ps1` | 9 (cache, advisory, policy jobs) |
| `Private.Reporting.Tests.ps1` | 23 (Excel, JSON, Markdown, AsciiDoc) — now covers `src/report/renderers/inventory/`, not `Modules/Private/Reporting/`, which no longer exists (AB#5662). Also builds a real `.xlsx` from a real `ReportCache` and asserts no Excel COM was used (AB#5665). |

### Public Function & Integration Tests (10 files)

| Test File | Purpose |
|-----------|---------|
| `Public.Functions.Tests.ps1` | 14 public utility scripts (Diagram, Jobs) |
| `AzureScout.Tests.ps1` | Module manifest & import validation |
| `Invoke-AzureScout.Tests.ps1` | Main entry-point parameter handling |
| `Connect-AZSCLoginSession.Tests.ps1` | Authentication flows |
| `Invoke-AZSCGraphRequest.Tests.ps1` | Graph API request handling |
| `Test-AZSCPermissions.Tests.ps1` | Permission checker logic |
| `Start-AZSCEntraExtraction.Tests.ps1` | Entra ID extraction |
| `PermissionAudit.Tests.ps1` | Permission audit pipeline |
| `OutputFormat.Tests.ps1` | Output format routing |
| `CategoryFiltering.Tests.ps1` | Category filter validation |

## How the declarative collector golden tests work

Every `.psd1` under `manifests/collectors/**` is proved the same way, driven entirely by the
definition file — there is no per-collector test code to write:

1. **Discovery** — `DeclarativeCollectorGolden.Tests.ps1` enumerates every category folder and
   every `.psd1` inside it; each becomes one Pester test case.
2. **Fixture** — `scripts/New-ScoutCollectorFixture.ps1` derives a synthetic resource for that
   collector from its own field expressions (see [Fixture Generation](#fixture-generation) above),
   or a shared fixture is used for collectors that share an input shape (e.g. `Databases`).
3. **Run** — `src/pipeline/Invoke-ScoutDeclarativeCollector.ps1` runs the definition against the
   fixture for both the Processing and Reporting tasks, under both tag states.
4. **Compare** — The result is compared field-for-field against a **committed golden record** in
   `tests/fixtures/collector-golden/<Category>/<Name>.json` — rows, order, keys, values, and
   null/array shape must match exactly, and the rendered Excel worksheet's columns and cells must
   match too.

Golden records are updated only through a reviewed, documented behavior change — never
regenerated to make a failing test pass.

## How Private Module Tests Work

Private module tests validate scripts that are not directly invoked by users:

- **File existence** — Confirms every expected `.ps1` file is present.
- **Syntax validation** — Uses `[System.Management.Automation.Language.Parser]::ParseFile()` to catch parse errors without executing any code.
- **Function definitions** — Verifies each script defines the expected function name via regex search of the file content.
- **Unit tests** — For simple utilities (e.g., `Clear-AZSCMemory`, `Set-AZSCFolder`), the function is dot-sourced and invoked with mocked dependencies.

## Writing Tests for a New Collector

When you add a new `.psd1` collector definition under `manifests/collectors/<Category>/`:

1. Run `scripts/New-ScoutCollectorFixture.ps1` for the category (or add to the shared fixture) to
   generate a fixture that reaches every field expression the definition declares.
2. Run `DeclarativeCollectorGolden.Tests.ps1` once with no committed golden record — it will show
   you the produced output.
3. Review that output by hand, then commit it as the golden record under
   `tests/fixtures/collector-golden/<Category>/<Name>.json`.
4. Re-run the test file and verify it passes against the committed record.
5. Confirm every resource type you declared is real — `ResourceTypeExistence.Tests.ps1` checks
   this automatically, but see [the gate section](#the-resource-type-existence-gate) below for how
   to add a provider newer than the committed catalogue.

See `docs/design/decisions/declarative-collectors.md` for the full `.psd1` schema and
[Contributing](./contributing.md) for the rest of the PR workflow.

## The resource-type existence gate

`tests/ResourceTypeExistence.Tests.ps1` checks every resource type a collector manifest declares
against a committed catalogue of **real** Azure provider/type pairs. It runs offline, on every
pull request, as part of the normal suite.

**Why it cannot be replaced by an ordinary test.** `scripts/New-ScoutCollectorFixture.ps1`
derives each collector's fixture estate from that collector's *own* expressions, so the declared
resource type is fabricated into existence and every property it reads is present by
construction. A collector for a type Azure does not have therefore passes forever — the manifests
are the thing under test, so they cannot also be the ground truth. `Hybrid/ArcSites` declared
three non-existent type strings and shipped green through every release before this gate existed.

It is also the only coverage check that works on a **small tenant**: it needs the resource
provider to be real, not for you to own one of the resources.

### Refreshing the catalogue

`manifests/azure-provider-types.json` is read from ARM and committed. Refresh it when you add a
collector for a provider newer than the file's `GeneratedAt`, or when the gate reports a type you
have independently confirmed is real:

```powershell
Connect-AzAccount
./scripts/Update-ScoutProviderCatalog.ps1
```

It reads `Get-AzResourceProvider -ListAvailable`, which returns every provider ARM knows about
regardless of whether your subscription has registered it — so any subscription in any tenant
produces the same catalogue. Commit the result, and say in the commit message when it was taken.

### What the gate deliberately does not fail on

| Case | Treatment | Why |
|---|---|---|
| `AZSC/…`, `entra/…`, `devops/…` | Skipped | Scout's own synthetic TYPE strings. They have no ARM counterpart by design, so no catalogue can contain them. |
| Three-segment child types (`…/vaults/backupPolicies`) | Checked against the **parent** | ARM's provider metadata under-reports nested types — `Microsoft.RecoveryServices/vaults` is listed but most of its `vaults/backup*` children are not, and they are real and callable. A child of a *non-existent* parent is still rejected. |
| Whether a real type returns any rows | Not checked | That is a live-run question. Conflating "the type does not exist" with "this tenant has none" is exactly the ambiguity the row-count artifact exists to remove. |

## Common Pitfalls

- **Case-sensitive hashtable keys** — PowerShell hashtable keys are case-insensitive; avoid duplicate keys like `SKU` and `sku` in mock data.
- **ARM ID format** — Some modules call `.split('/')[8]` on resource IDs. Always use full ARM paths (e.g., `/subscriptions/.../resourceGroups/.../providers/.../name`) in mocks.
- **DateTime values** — Modules that cast properties to `[datetime]` will fail if mock values aren't valid date strings.
- **Cross-resource lookups** — Some modules (e.g., Backup) join data across multiple resource types. Include mock resources for all related types.
- **Export-Excel -PassThru** — This pattern does not save the file to disk. Test the Reporting phase with `Should -Not -Throw` rather than checking for file existence.

## Testing the CAF/WAF assessment platform

The tests above cover the **inventory-mode** modules and pipeline. The **assessment
layers** (`src/collect`, `src/assess`, `src/report`) have their own, separate test
coverage:

- **`tests/Assessment.Engine.Tests.ps1`** — pure-logic smoke tests for the rule
  engine: JSONPath resolution (`Resolve-JsonPath`), rule assertion semantics
  (`Invoke-Rule`), and CAF/WAF scoring math (`Get-Score`). No Azure connection.
- **`tests/datadump/`** — synthetic fixture data used to offline-render each report
  tier without a live tenant: `Test-ExcelFromDataDump.ps1`,
  `Test-PowerBIFromDataDump.ps1`, and `Test-PptxFromDataDump.ps1` render the
  Excel evidence, Power BI CSV bundle, and PowerPoint deck respectively from the
  same fixture `findings.json`/`collect.json` shape.

Run them the same way as the rest of the suite:

```powershell
Invoke-Pester -Path .\tests\Assessment.Engine.Tests.ps1 -Output Detailed
```

## CI / CD Integration

To run the test suite in a CI pipeline (GitHub Actions, Azure DevOps, etc.):

```yaml
# GitHub Actions example
- name: Run Pester Tests
  shell: pwsh
  run: |
    Install-Module Pester -RequiredVersion 5.3.2 -Force -Scope CurrentUser
    Install-Module ImportExcel -Force -Scope CurrentUser
    Import-Module Pester -RequiredVersion 5.3.2 -Force
    $result = Invoke-Pester -Path ./tests/ -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) { exit 1 }
```
