---
description: How to contribute new inventory modules and improvements to AzureScout.
---

# Contributing

The full contributing guide is maintained in the repository root and rendered on GitHub.

[View CONTRIBUTING.md on GitHub](https://github.com/thisismydemo/azure-scout/blob/main/CONTRIBUTING.md){ .md-button .md-button--primary }

## Quick Reference

- Fork the repo and create a feature branch
- New ARM collectors are declarative `.psd1` files under `manifests/collectors/<Category>/` — see
  [Category Structure](../reference/category-structure.md) for the 18 category folders and their
  `[ValidateSet]`/alias plumbing in `src/Invoke-AzureScout.ps1`. There is no `.ps1` template to
  copy from: a definition describes *what* to filter and *what* fields to produce (resource
  types, an optional filter, field expressions, the Excel export shape), and one shared
  interpreter runs it. See the decision record at
  [`docs/design/decisions/declarative-collectors.md`](../design/decisions/declarative-collectors.md)
  for the full schema and worked examples.
- New Entra ID collectors are catalog entries in `src/collect/Get-ScoutEntraQueryCatalog.ps1`, not
  separate files — see [Entra Modules](../reference/entra-modules.md) for the current 17-entry catalog.
- Before you add a resource type, confirm Azure actually has it. Six collectors were retired
  2026-07-31 because they declared types that do not exist (`Hybrid/ArcSites`,
  `Compute/CloudServices`, `Storage/DataLakeStoreGen1`, `Databases/POSTGRE`,
  `Monitor/AppInsightsContinuousExport`, `Monitor/AppInsightsWorkItems`) — see
  [Category Reference](../reference/category-reference.md#report-section-heading-category). Every declared type
  is checked against a real Azure provider/type catalogue by
  `tests/ResourceTypeExistence.Tests.ps1`; see
  [Testing: the resource-type existence gate](./testing.md#the-resource-type-existence-gate).
- Fixtures for the collector's own test are **generated** from its `.psd1` definition by
  `scripts/New-ScoutCollectorFixture.ps1`, not hand-written — see [Testing](./testing.md) for how the
  golden tests use them.
- Open a PR against `main` — describe what resource type you added and why.

See [ARM Modules](../reference/arm-modules.md) and [Entra Modules](../reference/entra-modules.md) for the current catalog.
