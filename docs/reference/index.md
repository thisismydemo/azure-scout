---
description: Generated catalogues of everything AzureScout collects and assesses, plus category and validation reference.
---

# Catalogues & Reference

The two questions everyone asks first — *what does it collect* and *what does it assess* —
each have one page, and both are **generated from the product** rather than hand-maintained.

## The two catalogues

| Page | Contents |
|---|---|
| [Assessment Catalogue](./assessment-catalogue.md) | All **46 assessments**, grouped into CAF design areas, WAF pillars, per-service slices and specialised reviews — with the rule files, rule counts, and the automated-versus-manual split behind each |
| [Framework Coverage](./framework-coverage.md) | **How much of each framework actually has a rule behind it.** Scout enumerates every framework in full; this is the gap between enumerating an item and testing it |
| [ARM Modules](./arm-modules.md) | All **242 collector definitions** across Microsoft's 18 published service categories, each mapped to the resource types it targets |
| [Collector Fields](./collector-fields.md) | The worksheet and the ordered columns each collector produces — what actually comes back, as opposed to what is covered |

::: tip Both pages are generated
`scripts/Build-AssessmentCatalog.ps1` and `scripts/Build-ArmModuleCatalog.ps1` regenerate them
from `manifests/`, and CI fails if a committed page and a fresh regeneration disagree. An
earlier hand-maintained catalogue claimed to be generated and drifted fifteen collectors out of
date before anyone noticed, which is why they are built this way now.
:::

## Supporting reference

| Page | Contents |
|---|---|
| [Entra ID Modules](./entra-modules.md) | Identity collectors that query Microsoft Graph rather than ARM |
| [Coverage Table](./coverage-table.md) | Service coverage per category, from the same pass over the manifests |
| [Category Structure](./category-structure.md) | How the 18 categories are organised |
| [Category Reference](./category-reference.md) | Every report section heading mapped to its category, aliases, and collector folder |
| [Validation Matrix](./validation-matrix.md) | Which checks are verified by automated tests and which need a live tenant |

## Reading a count on any page here

Counts on these pages come from the manifests at generation time, so they match the shipped
product exactly. Counts written into prose elsewhere in the documentation are maintained by
hand and are the ones to distrust — if two pages disagree, these two win.
