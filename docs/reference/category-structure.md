---
description: Maps AzureScout -Category parameter values to Microsoft's Azure portal categories and module folder paths.
---

# Category Structure

This page maps the `-Category` parameter values to Microsoft's official Azure portal category names, the corresponding folder paths in the module tree, and the primary resource types covered.

## Category Mapping

| `-Category` Value | Azure Portal Label | Module Folder Path |
|-------------------|--------------------|--------------------|
| `AI` | AI + Machine Learning | `manifests/collectors/AI/` |
| `Analytics` | Analytics | `manifests/collectors/Analytics/` |
| `Compute` | Compute | `manifests/collectors/Compute/` |
| `Containers` | Containers | `manifests/collectors/Containers/` |
| `Databases` | Databases | `manifests/collectors/Databases/` |
| `DevOps` | DevOps | `manifests/collectors/DevOps/` |
| `General` | General | `manifests/collectors/General/` |
| `Hybrid` | Hybrid + multicloud | `manifests/collectors/Hybrid/` |
| `Identity` | Identity | `manifests/collectors/Identity/` |
| `Integration` | Integration | `manifests/collectors/Integration/` |
| `IoT` | Internet of Things | `manifests/collectors/IoT/` |
| `Management` | Management and governance | `manifests/collectors/Management/` |
| `Migration` | Migration | `manifests/collectors/Migration/` |
| `Monitor` | Monitor | `manifests/collectors/Monitor/` |
| `Networking` | Networking | `manifests/collectors/Networking/` |
| `Security` | Security | `manifests/collectors/Security/` |
| `Storage` | Storage | `manifests/collectors/Storage/` |
| `Web` | Web & Mobile | `manifests/collectors/Web/` |

`DevOps`, `General` and `Migration` are canonical categories as of v3.1.0 (AB#6741), each with its
own manifest folder, `[ValidateSet]` entry and report heading. They are **not** aliases for
anything — see the warning below.

## Accepted Aliases

The following long-form names (as shown in the Azure portal) are automatically normalized to their short equivalents. Matching is case-insensitive.

| Input | Normalized to |
|-------|---------------|
| `AI + machine learning` | `AI` |
| `AI+machine learning` | `AI` |
| `Machine Learning` | `AI` |
| `Internet of Things` | `IoT` |
| `Monitoring` | `Monitor` |
| `Management and governance` | `Management` |
| `Management & governance` | `Management` |
| `Web & Mobile` | `Web` |
| `Web and mobile` | `Web` |
| `Mobile` | `Web` |
| `Hybrid + multicloud` | `Hybrid` |
| `Hybrid+multicloud` | `Hybrid` |
| `Networking + CDN` | `Networking` |
| `Networking+CDN` | `Networking` |

::: warning `DevOps` and `Migration` are not aliases
Both used to be listed here resolving to `Management`. They are **canonical categories** as of
v3.1.0, each with its own manifest directory, so folding either into `Management` would silently
run the wrong collectors. The old alias entries were also unreachable even before the removal —
neither string was in the `-Category` `[ValidateSet]`, so parameter binding rejected them before
the alias map was ever consulted.
:::

See the [Category Reference](./category-reference.md) for the full mapping of report section headings to categories, collector folders, and module counts.

## Category Selection Logic

When `-Category` is specified, AzureScout:

1. Normalizes any alias values to canonical short names
2. Loads only the module files inside the matching category folders
3. Restricts Resource Graph and REST API queries to those modules' resource types
4. Generates reports containing only the selected categories

When `-Category All` is used (the default), all category folders are included.

```powershell
# Run only Compute and Security modules
Invoke-AzureScout -Category Compute,Security

# Full portal name also works
Invoke-AzureScout -Category 'AI + machine learning'

# Default — all categories
Invoke-AzureScout
```

## Adding a New Category

To add a new category:

1. Create a new folder under `manifests/collectors/`
2. Add the folder name to `[ValidateSet]` for `-Category` in `Invoke-AzureScout.ps1`
3. Add any alias entries to the `$_categoryAliasMap` hashtable in `Invoke-AzureScout.ps1`
4. Update the [Coverage Table](./coverage-table.md) with the new modules

See [Contributing](../project/contributing.md) for full guidance on adding modules.
