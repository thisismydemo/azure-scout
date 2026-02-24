# Azure Category Structure

This document maps AZTI's `-Category` parameter values to Microsoft's official Azure portal category names, the corresponding folder paths in the module tree, and the primary resource types covered.

## Category Mapping

| `-Category` Value | Azure Portal Label | Module Folder Path |
|-------------------|--------------------|-------------------|
| `AI` | AI + Machine Learning | `Modules/Public/InventoryModules/AI/` |
| `Analytics` | Analytics | `Modules/Public/InventoryModules/Analytics/` |
| `Compute` | Compute | `Modules/Public/InventoryModules/Compute/` |
| `Containers` | Containers | `Modules/Public/InventoryModules/Containers/` |
| `Databases` | Databases | `Modules/Public/InventoryModules/Databases/` |
| `Hybrid` | Hybrid + multicloud | `Modules/Public/InventoryModules/Hybrid/` |
| `Identity` | Identity | `Modules/Public/InventoryModules/Identity/` |
| `Integration` | Integration | `Modules/Public/InventoryModules/Integration/` |
| `IoT` | Internet of Things | `Modules/Public/InventoryModules/IoT/` |
| `Management` | Management and governance | `Modules/Public/InventoryModules/Management/` |
| `Monitor` | Monitor | `Modules/Public/InventoryModules/Monitor/` |
| `Networking` | Networking | `Modules/Public/InventoryModules/Networking/` |
| `Security` | Security | `Modules/Public/InventoryModules/Security/` |
| `Storage` | Storage | `Modules/Public/InventoryModules/Storage/` |
| `Web` | Web & Mobile | `Modules/Public/InventoryModules/Web/` |

## Accepted Aliases

The following long-form names (as shown in the Azure portal) are automatically normalized to their short equivalents:

| Input | Normalized to |
|-------|--------------|
| `AI + machine learning` | `AI` |
| `Internet of Things` | `IoT` |
| `Monitoring` | `Monitor` |
| `Management and governance` | `Management` |
| `Web & Mobile` | `Web` |
| `Hybrid + multicloud` | `Hybrid` |
| `Containers` | `Containers` |
| `Networking + CDN` | `Networking` |

## Category Selection Logic

When `-Category` is specified, AZTI:

1. Normalizes any alias values to canonical short names
2. Loads only the module files inside the matching category folders
3. Restricts Resource Graph and REST API queries to those modules' resource types
4. Generates reports containing only the selected categories

When `-Category All` is used (the default), all category folders are included.

## Adding a New Category

To add a new category:

1. Create a new folder under `Modules/Public/InventoryModules/`
2. Add the folder name to `[ValidateSet]` for `-Category` in `Invoke-AzureTenantInventory.ps1`
3. Add any alias entries to the `$_categoryAliasMap` hashtable in `Invoke-AzureTenantInventory.ps1`
4. Update this document with the new mapping
