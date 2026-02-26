---
description: Credits and attribution for the AzureScout project.
---

# Credits & Attribution

!!! important
    **AzureScout exists because of [Azure Resource Inventory (ARI)](https://github.com/microsoft/ARI).**
    Without the foundation built by the ARI team at Microsoft, this project would not exist.

The full credits file is maintained in the repository root and rendered on GitHub.

[View CREDITS.md on GitHub](https://github.com/thisismydemo/azure-scout/blob/main/CREDITS.md){ .md-button .md-button--primary }

## Fork Origin

AzureScout was forked from [microsoft/ARI](https://github.com/microsoft/ARI) (Azure Resource Inventory) at version **3.6.11** in October 2024. The original project provided the entire extraction, processing, and reporting pipeline — including 171 ARM inventory modules, the draw.io diagram engine, Excel/ImportExcel integration, and Azure Automation Account support.

## Original Authors

| Author | Role |
|--------|------|
| [**Claudio Merola**](https://github.com/Claudio-Merola) | Original ARI creator and primary developer |
| [**Renato Gregio**](https://github.com/RenatoGregio) | Original ARI co-author and copyright holder |

We are deeply grateful for their work. The ARI project remains actively maintained at [github.com/microsoft/ARI](https://github.com/microsoft/ARI) and we encourage users to check it out.

## What Has Changed

For a detailed breakdown of what AzureScout has added, changed, and diverged from the original ARI codebase, see [Differences from ARI](ari-differences.md).

## Additional Acknowledgments

- **[Doug Finke](https://github.com/dfinke)** — Author of [ImportExcel](https://github.com/dfinke/ImportExcel), the PowerShell module used for Excel report generation (MIT license).
- **Microsoft** — Azure PowerShell SDK (`Az.*` modules), Azure Resource Graph, and Microsoft Graph REST API.
- **All ARI contributors** — The [29 contributors](https://github.com/microsoft/ARI/graphs/contributors) who built and refined ARI over six years.

## License & Disclaimer

Both the original ARI project and AzureScout are licensed under the MIT License. See [LICENSE](https://github.com/thisismydemo/azure-scout/blob/main/LICENSE) for full details.

AzureScout is an independent community project and is **not affiliated with or endorsed by Microsoft**.
