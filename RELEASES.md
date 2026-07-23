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
| **2.0.0** | 2026-07-23 | ✅ | **CAF/WAF assessment platform** — assessment engine (139 rules), ARG collect layer, AzGovViz/Advisor/ARG ingest, ALZ benchmark, tiered reporting (Power BI / HTML / OpenXML PPTX / Excel / JSON); per-domain analytics foundation. Runtime-verified offline + live tenant. | **Epic AB#5023** (AB#5024, 5027, 5031, 5034, 5044) + **Epic AB#5056** (AB#5057–5060) |
| **2.1.0** | _TBD_ | 🟡 | **Per-domain CAF/WAF analytics** — native governance collector (AB#5041), unattended pipeline (AB#5050), and React report / drift tracking (AB#5053) shipped; full per-category rule depth still in progress | **Epic AB#5023** (AB#5041, AB#5050, AB#5053) + **Epic AB#5056** (Features AB#5061–#5075) |

> **2.0.0 is a major bump** because the reporting overhaul demotes Excel-first
> output to an evidence tier and introduces the `findings.json` contract — a
> breaking change to the output surface.

---

## 2.1.0 — Unreleased (TBD)

Delivered on `main` in the current development line (not yet tagged or published):

- **Native governance collector** (`src/ingest/Import-Governance.ps1`, AB#5041) — replaces the AzGovViz hard dependency as the default governance collector. Populates `collect.json`'s `governance` object natively from Azure Resource Graph (policy assignments, role assignments, management groups) plus ambient-token ARM REST (budgets, locks). Needs only Reader at the management-group root — no cloned repo, no `AzAPICall` install prompt, fully unattended. `AzGovViz` remains available as an opt-in `Ingest` value. Live-verified against the HCS tenant.
- **Unattended pipeline** (`Invoke-ScoutPipeline`, AB#5050) — one command runs collect → assess → report headless into a single dated run folder, fully non-interactive, with a read-only permission pre-flight and a `PartialSuccess` degrade path on exporter failure. Writes `pipeline-summary.json` / `.md`.
- **React report + cross-run drift** (`Export-React`, `Get-ScoutDrift`, AB#5053) — a new self-contained `report-react.html` (`-OutputFormat React`) with client-side filter/sort/search and a Drift tab, plus cross-run drift computation (New / Resolved / Regressed / Unchanged, weighted score delta) tracked in an append-only `.scout-history/findings-history.json`.

Still open for 2.1.0: full per-category rule depth (Epic AB#5056, Features AB#5061–#5075).

---

## Builds

Builds are cut from `main` once CI passes. Record each build here as it is produced.

| Build | Commit | Date | From version | Artifacts | Notes |
|---|---|---|---|---|---|
| v2.0.0 | `0518c7a` | 2026-07-23 | 2.0.0 | `AzureScout` module (PSGallery), GitHub release `v2.0.0` | First assessment-platform release. Verified offline (Pester) + against a live tenant (140 findings, all report tiers). |

---

## How a release is cut

1. All Features in the target release's ADO cluster reach **Done** (acceptance criteria verified).
2. `CHANGELOG.md` `[Unreleased]` section is finalized and dated under the new version heading.
3. `ModuleVersion` bumped in `AzureScout.psd1`.
4. CI (Pester + `mkdocs build --strict`) is green on `main`.
5. Tag `vX.Y.Z`, cut the build, add a row to **Builds** above, and flip the release row to ✅.
6. GitHub release notes generated from the `CHANGELOG.md` section; ADO Features linked via `AB#<id>`.
