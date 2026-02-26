---
description: How to contribute new inventory modules and improvements to AzureScout.
---

# Contributing

The full contributing guide is maintained in the repository root and rendered on GitHub.

[View CONTRIBUTING.md on GitHub](https://github.com/thisismydemo/azure-scout/blob/main/CONTRIBUTING.md){ .md-button .md-button--primary }

## Quick Reference

- Fork the repo and create a feature branch
- New ARM modules go in `Modules/Public/InventoryModules/<Category>/`
- New Entra modules go in `Modules/Public/PublicFunctions/Identity/`
- Use the `Modules/Public/InventoryModules/Module-template.tpl` as your starting point
- Add a Pester test in `tests/` for any new public function
- Open a PR against `main` — describe what resource type you added and why

See [ARM Modules](arm-modules.md) and [Entra Modules](entra-modules.md) for the current catalog.
