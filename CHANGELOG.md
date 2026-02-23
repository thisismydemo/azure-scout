# Changelog

All notable changes to the AzureTenantInventory module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial fork from [microsoft/ARI](https://github.com/microsoft/ARI) v3.6.11
- Renamed module to `AzureTenantInventory` (prefix `AZTI`)
- New module manifest with fresh GUID, v1.0.0
- Repository scaffolding (CHANGELOG, README, tests/)

### Removed

- RAMP functions (`Modules/Private/4.RAMPFunctions/`)
- `Invoke-AzureRAMPInventory` public function
- Auto-update logic (`Update-Module` call)
- `Remove-ARIExcelProcess` (aggressive Excel process killer)

### Changed

- All exported function names: `*-ARI*` → `*-AZTI*`
- Module metadata (author, description, project URI, tags)
- LICENSE updated with dual copyright (original + fork)

---

**Version Control**
- Created: 2026-02-22 by thisismydemo
- Last Edited: 2026-02-22 by thisismydemo
- Version: 1.0.0
- Tags: changelog, azuretenantinventory
