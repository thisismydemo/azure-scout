# Handoff

<!--
  Written at the END of every session by whichever tool was used.
  This is the single most important cross-tool file — the next session
  (possibly a different tool) starts by reading it.
-->

## Last session (2026-07-23, Claude Code) — v2.1.0 feature trio

- **What changed and why:** Delivered the three items that were parked as "v2.1.0 /
  blocked". (1) **AB#5041** — new native governance collector `Import-Governance`
  (`src/ingest/`) replaces the AzGovViz hard dependency: pulls policy/role/MG data
  from Azure Resource Graph + budgets/locks via ambient-token ARM REST. The ALZ
  benchmark is no longer blocked on any upstream AzGovViz fix. (2) **AB#5050** —
  `Invoke-ScoutPipeline` (`src/`), a headless one-command collect→assess→report with
  a CI-facing `pipeline-summary.json` and exit codes. (3) **AB#5053** — `Export-React`
  self-contained interactive report + `Get-ScoutDrift` cross-run drift, wired into the
  orchestrator (`-OutputFormat React`).
- **Files touched:** new `src/ingest/Import-Governance.ps1`, `src/Invoke-ScoutPipeline.ps1`,
  `src/report/renderers/Export-React.ps1`, `src/report/Get-ScoutDrift.ps1`,
  `src/report/templates/report-react.html.template`; edited `src/Invoke-ScoutAssessment.ps1`,
  `src/report/Export-Report.ps1`, `src/assess/Compare-Benchmark.ps1`,
  `src/collect/Invoke-Collect.ps1`, `manifests/assessments.psd1`, `AzureScout.psd1`;
  5 new test files; 13 docs/design files updated.
- **Commands / tests run:** full Pester suite **1325 pass / 0 fail / 3 skip**; VitePress
  `npm run docs:build` green (0 dead links). Governance collector **live-verified** via
  SPN against the HCS tenant (real ARG policy/role data, rules scored real Pass/Fail,
  benchmark guard correct). Real-orchestrator E2E produced a 220KB self-contained React
  report + drift across two runs. One integration bug found & fixed by E2E: Export-React's
  return path leaked into Invoke-ScoutAssessment's output (reporter loop now `| Out-Null`;
  regression test added).
- **Branch:** main — committed (5 per-concern commits `1379826..ee7ebfa`) — pushed: yes.
- **ADO:** AB#5041, AB#5050, AB#5053 all moved New → **Resolved** with commit evidence.
- **Blockers / open decision:** these three constitute **v2.1.0** but it is NOT yet cut or
  published. Release docs are staged as "v2.1.0 — Unreleased". Awaiting the owner's go to
  cut the version bump + tag + GitHub release + PSGallery publish (PSGallery key is in
  kv-hcs-vault-01 as `hcs-vault-azure-scout-powershellgallery-publisher-api-key`).

## Prior session (2026-07-23, Claude Code)

- **What changed and why:** Full remaining-backlog implementation pass (multi-agent).
  (1) Collector extensions in `src/collect/Invoke-Collect.ps1` + 9 rule files — 16 rules
  flipped manual→automated (AB#5057). (2) AB#5044 PPTX renderer rewritten on
  DocumentFormat.OpenXml — `build_deck.py` deleted, no Python anywhere; smoke test added.
  (3) First-ever runtime verification: 4 StrictMode engine defects fixed
  (`Resolve-JsonPath`, `Get-Score`, `Invoke-Rule`, `Invoke-ScoutAssessment`); canonical
  fixture `tests/datadump/sample-collect.json` added. (4) Live-tenant verification (HCS,
  read-only SPN via HCS Governance MCP broker): fixed ARG `-Skip 0` paging (2 files),
  `mv-expand kind=outer`, `kind` reserved keyword, AzGovViz interactive-prompt hang.
  (5) master-plan.md §8 rewritten to delivered state; §10 PPTX dependency row updated.
- **Files touched:** `src/collect/Invoke-Collect.ps1`, 9× `src/assess/rules/*.yaml`,
  `src/assess/engine/{Resolve-JsonPath,Get-Score,Invoke-Rule}.ps1`,
  `src/Invoke-ScoutAssessment.ps1`, `src/ingest/{Invoke-ArgQueryPack,Import-AzGovViz}.ps1`,
  `src/report/renderers/Export-Pptx.ps1`, `src/report/Export-Report.ps1`,
  `src/report/templates/build_deck.py` (deleted), `tests/Assessment.Engine.Tests.ps1`,
  `tests/Test-PptxFromDataDump.ps1` (new), `tests/datadump/sample-collect.json` (new),
  `.gitignore`, `docs/design/master-plan.md`, `docs/design/decisions/pptx-renderer.md`.
- **Commands / tests run and results:** Engine Pester 6/6; full suite 1263 pass / 1
  pre-existing fail (manifest author metadata: test expects `thisismydemo`, manifest says
  `Kristopher Turner` — owner decision pending) / 3 skip. Offline end-to-end: all tiers,
  all 22 manifest entries. Live end-to-end (`Invoke-ScoutAssessment -Assessment
  LandingZone -OutputFormat All`): every ARG query OK, 140 findings
  (Pass 47 / Manual 46 / Fail 45 / Unknown 2), all 5 tiers rendered incl. PPTX. Final
  sweep: 9/9 AST clean, 23 YAML / 139 rules / 0 dup IDs, Test-ModuleManifest OK.
- **Branch:** main — committed: yes (5 per-concern commits this session) — pushed: yes.
- **Blockers:** none for code. Governance/AzGovViz ingest still unexercised live (needs
  `-ManagementGroupId` + MG-root Reader + Graph read perms for the SPN).
- **Exact next steps:**
  1. Approve Platform Engineering PR #5 (tag vocabulary) in ADO — owner action.
  2. Decide manifest author mismatch (change manifest `Author` vs. fix test).
  3. Optional: designer `deck.pptx.template` to replace the programmatic slide master.
  4. Update ADO board states for items whose acceptance criteria verification now meets.
  5. Live AzGovViz/governance ingest run once MG-scope permissions are confirmed.
