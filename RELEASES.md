# Releases & Builds

This document tracks every Azure Scout **build** and **release**: what shipped,
when, the version, the driving ADO work, and the linked GitHub milestone. It is
the human-readable companion to [`CHANGELOG.md`](CHANGELOG.md) (which records the
detailed change list) — this file is the at-a-glance ledger of *builds and
releases over time*.

- **Versioning:** [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`.
- **Source of truth:** ADO Boards (`This Is My Demo — Azure Scout`) for planning;
  GitHub for intake. Commits/PRs link work with `AB#<id>`.
- **Cadence:** minor releases per completed Feature cluster; patch releases for
  fixes; builds cut from `main` after CI is green.

---

## Release status legend

| Symbol | Meaning |
|---|---|
| ✅ | Released |
| 🟡 | In progress / building |
| 🔵 | Planned |

---

## Releases

| Version | Date | Status | Theme | Driving ADO work |
|---|---|---|---|---|
| **1.0.0** | 2026-02-25 | ✅ | Fork from microsoft/ARI → AzureScout; 170+ ARM modules, 15 Entra modules, Excel/JSON/Markdown output, draw.io diagrams, category filtering, permission pre-flight | — |
| **1.1.0** | _TBD_ | 🔵 | Quality & reliability — Pester suite, CI, throttling/retry, `-WhatIf`, non-destructive cache | AB#315–#352 |
| **1.2.0** | _TBD_ | 🔵 | Collector depth — governance, networking, private-endpoint, and policy collectors | AB#353–#405 |
| **2.0.0** | _TBD_ | 🔵 | **CAF/WAF assessment platform** — assessment engine, ingest, ALZ benchmark, tiered reporting (Power BI / HTML / PPTX) | **Epic AB#5023** (Features AB#5024–#5055) |
| **2.1.0** | _TBD_ | 🔵 | **Per-domain CAF/WAF analytics** — every category an independently runnable, tagged assessment | **Epic AB#5056** (Features AB#5057–#5075) |

> **2.0.0 is a major bump** because the reporting overhaul demotes Excel-first
> output to an evidence tier and introduces the `findings.json` contract — a
> breaking change to the output surface.

---

## Builds

Builds are cut from `main` once CI passes. Record each build here as it is produced.

| Build | Commit | Date | From version | Artifacts | Notes |
|---|---|---|---|---|---|
| _pending first CI-green build_ | — | — | — | — | — |

---

## How a release is cut

1. All Features in the target release's ADO cluster reach **Done** (acceptance criteria verified).
2. `CHANGELOG.md` `[Unreleased]` section is finalized and dated under the new version heading.
3. `ModuleVersion` bumped in `AzureScout.psd1`.
4. CI (Pester + `mkdocs build --strict`) is green on `main`.
5. Tag `vX.Y.Z`, cut the build, add a row to **Builds** above, and flip the release row to ✅.
6. GitHub release notes generated from the `CHANGELOG.md` section; ADO Features linked via `AB#<id>`.
