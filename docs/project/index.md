---
description: Roadmap, release history, repository layout, testing, and how to contribute to AzureScout.
---

# Project

How AzureScout is built, tested, released, and contributed to.

## Where it is going

| Page | Contents |
|---|---|
| [Roadmap](./roadmap.md) | Release history and what is planned, newest first — **including the full write-up for every release from v3.1.0 onward** |
| [Changelog](./changelog.md) | Version summary table, current release at the top |
| [Release notes](./releases/v3.0.5.md) | Standalone per-release pages, **v3.0.x only** — later releases are documented in the Roadmap rather than here |

## Working on it

| Page | Contents |
|---|---|
| [Repository structure](./folder-structure.md) | Directory layout and how the module loads |
| [Testing](./testing.md) | The Pester suite, what it guards, and how to run it |
| [Contributing](./contributing.md) | Adding a collector, and the conventions to follow |

## Context

| Page | Contents |
|---|---|
| [Differences from ARI](./ari-differences.md) | What AzureScout changed relative to Azure Resource Inventory |
| [Credits and attribution](./credits.md) | Prior work this builds on |

## Project management lives outside the docs

Audits, plans, the original enhancement spec and the generated task list are **not** published
here. They are internal programme records rather than product documentation, and they live in
[`pmo/`](https://github.com/thisismydemo/azure-scout/blob/main/pmo/README.md) in the
repository — including the
[Azure Scout audit](https://github.com/thisismydemo/azure-scout/blob/main/pmo/audits/AZURE-SCOUT-AUDIT.md),
which is the honest account of what this tool does and does not cover.
