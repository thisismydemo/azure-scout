# Handoff

<!--
  Written at the END of every session by whichever tool was used.
  This is the single most important cross-tool file — the next session
  (possibly a different tool) starts by reading it.
-->

## Last session (2026-07-23, Claude Code) — backlog drive: ~72 items resolved

**Big picture:** Cleared essentially the entire *tractable* backlog in one session — every bug,
every already-built item (board reconciliation), and every small real gap. 12 commits pushed to
`main`; full Pester suite **1342 pass / 0 fail / 3 skip** throughout; analyzer 0 Errors across
`src`+`Modules`. ADO: **~72 items** moved to Resolved (or Removed) with per-item commit/file evidence.

- **5 v1 bugs (AB#335/336/337/339/340):** automation cache null-path, 0% progress bar, unassigned
  `$JobNames`, dropped `$VMQuotas`, and the echo-only CI workflow → real SPN run.
- **AB#367** tag aggregation (dedup per key) · **AB#369** module auto-update (notify-default, CI-guarded)
  · **AB#5046** `report.pbit` (wired the existing tested `New-AZSCPowerBITemplate` generator — validated
  structurally only; open in Power BI Desktop before a release depends on it) · **AB#317** test+lint CI
  pipeline (+ justified SecureString suppression in `Connect-AZSCLoginSession` so the gate is green) ·
  **AB#349** UPN/subscription auth banner.
- **AB#5068/5071/5075** collector rule depth: new `sqlDefenderPricing` / `purviewAccounts` queries +
  `iotHubs.disableLocalAuth`; flipped CAF-DB-04, CAF-ANL-02 and new CAF-IOT-06 to automated (141 rules,
  0 dup IDs). Rest stay manual with in-file ARG-absence citations.
- **AB#347** Entra "fails with Global Admin" → proven *not* a code bug (Graph delegated-scope/consent;
  degrades per-endpoint). Documented required scopes in `docs/entra-modules.md`.
- **AB#338** verified already-fixed → Resolved · **AB#321** `-WhatIf` on read-only tool → Removed.
- **Phase 0 reconciliation:** 55 already-shipped items (assessment stories, collectors/scoring, rule-depth
  categories) moved New→Resolved after spot-verifying every key artifact exists. Open items: 126 → ~54.

**Commits:** `18bf37d`, `ec7cd98`, `035ddfa`, `10fcae8`, `147d57e`, `4467355`, `b40ad7f`, `eb1b172`,
`1bd67ba` (+ this handoff). All pushed.

**What remains (needs the owner's direction — NOT bugs or unbuilt-by-omission):** the net-new **served
web-portal** vision (AB#346 + AB#373–405: HTTP listener, runspaces, vis.js topology, html2canvas/jsPDF,
browser upload/download, Spectre TUI) and major net-new integrations (Lighthouse multi-tenant AB#323/332,
cost-anomaly AB#324, IaC-gap AB#325, Fabric AB#329, ECharts AB#344, docx/pdf AB#333/334, Automation
Account AB#343). This is weeks of work and a genuine product fork — the standing task says get a go/no-go
before building the portal. A build plan + estimate is owed to the owner before starting.
**Small polish partials still open (quick next-session wins):** AB#315 phase-matrix doc, AB#318 alias doc,
AB#351 MG access probe, AB#368 cross-sub context restore; AB#386/389/396 partially overlap the React
report (do NOT close as done). Epics AB#5023/5056 close when their children are all done.

## Earlier same session (2026-07-23, Claude Code) — backlog Phase 1 detail

- **What changed and why:** Fixed the five real defects in the legacy v1 (AZSC) inventory
  path — all silent because that path has no StrictMode, so bad references degraded to
  `$null` rather than throwing.
  - **AB#335** `Start-AZTIAutProcessJob.ps1` — added missing `$DefaultPath` param and pass
    it from `Start-AZTIProcessOrchestration.ps1:38`; automation-mode batch cache writes no
    longer target a null path.
  - **AB#336** `Build-AZTICacheFiles.ps1:30` — undeclared `$ReportCounter` → `$Counter`;
    progress bar advances instead of sticking at 0%.
  - **AB#337** `Start-AZTIProcessOrchestration.ps1` — automation branch now assigns
    `$JobNames` after `Wait-Job` so the final `Build-AZSCCacheFiles` flush gets the job list.
  - **AB#339** `Start-AZTIExtractionOrchestration.ps1` — `$VMQuotas` initialised to `$null`
    up top and the premature `Remove-Variable` dropped; the `Quotas` return field is now
    populated and safe under `-SkipVMDetails`.
  - **AB#340** `.github/workflows/azure-inventory.yml` — replaced the echo-only simulation
    with a real headless run: validates SPN secrets, installs Az + AzureScout from PSGallery,
    authenticates non-interactively via `Invoke-AzureScout -TenantID/-AppId/-Secret`, runs
    the inventory, uploads reports as an artifact. Required repo secrets documented in-file.
  - Also fixed a stale test (`AzureScout.Tests.ps1` asserted version 2.0.1 → 2.1.0) and
    marked bugs #24/#25/#26/#28/#29 fixed in `docs/design/task-list.md`.
- **Commands / tests run:** full Pester suite **1325 pass / 0 fail / 3 skip** (the version
  test was the only failure and is now fixed); all 4 edited modules parse clean and pass
  PSScriptAnalyzer with **no new** findings (remaining warnings are pre-existing Write-Host/
  ShouldProcess/BOM style).
- **Branch:** main — 2 per-concern commits `18bf37d` (code) + `ec7cd98` (CI) — pushed: yes.
- **ADO:** AB#335, 336, 337, 339, 340 all New → **Resolved** with commit-evidence comments.
- **Next backlog waves (from the standing task):** Phase 0 board reconciliation (~58
  already-built items to Close — do per-item, respect the no-overreach policy); Phase 2 real
  gaps (AB#5046 report.pbit template, AB#367 tag-key aggregation, AB#369 module auto-update,
  AB#317 real test-running CI); Phase 3 collector rule depth (5068/5071/5075); Phase 4 web
  portal (~26 items, AB#373-405 — needs an architecture go/no-go before building).

## Prior session (2026-07-23, Claude Code) — v2.1.0 feature trio

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
