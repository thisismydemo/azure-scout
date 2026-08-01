---
description: Generated view of every Azure Scout work item, built from the live Azure DevOps board and GitHub issues.
---

# Azure Scout — Complete Task List

::: warning Generated file
Do not edit this page by hand. Azure DevOps and GitHub are the source of truth; this page is
a rendering of them. Regenerate it with `./scripts/Build-TaskList.ps1`.
:::

Generated **2026-07-25 06:19 UTC** from ADO project `85b6e47e-a666-4a38-8c43-de87dd21aa56` and `thisismydemo/azure-scout`.

## Summary

| Measure | Count |
|---|---|
| Work items | 191 |
| State: Closed | 175 |
| State: New | 14 |
| State: Removed | 2 |
| Type: Bug | 26 |
| Type: Epic | 7 |
| Type: Feature | 114 |
| Type: User Story | 44 |
| Linked GitHub issues | 130 |

## Open work

### AB#5093 — Build the Azure Scout served web application (far-future roadmap)

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#346 | Feature | 3 | Report | Build web-accessible inventory portal (from static HTML to enterprise dashboards) | [#37](https://github.com/thisismydemo/azure-scout/issues/37) (open) |
| AB#350 | Feature | 3 | Platform | Add Save-AzContext/Import-AzContext for background collection runspace | [#41](https://github.com/thisismydemo/azure-scout/issues/41) (open) |
| AB#352 | Feature | 3 | Platform | Add 10-minute AbortController timeout on collection fetch | [#43](https://github.com/thisismydemo/azure-scout/issues/43) (open) |
| AB#381 | Feature | 2 | Platform | Implement background runspace collection so HTTP listener stays responsive | [#137](https://github.com/thisismydemo/azure-scout/issues/137) (open) |
| AB#382 | Feature | 3 | Platform | Implement file-based progress IPC — runspace writes temp JSON, client polls every 800ms | [#138](https://github.com/thisismydemo/azure-scout/issues/138) (open) |
| AB#383 | Feature | 3 | Platform | Add named collection stages with step/totalSteps percentage | [#139](https://github.com/thisismydemo/azure-scout/issues/139) (open) |
| AB#384 | Feature | 2 | Platform | Implement concurrent collection guard | [#140](https://github.com/thisismydemo/azure-scout/issues/140) (open) |
| AB#385 | Feature | 3 | Platform | Build cached inventory — serve without re-collecting | [#141](https://github.com/thisismydemo/azure-scout/issues/141) (open) |
| AB#388 | Feature | 3 | Platform | Add start.cmd Windows batch launcher and start.sh cross-platform launcher | [#144](https://github.com/thisismydemo/azure-scout/issues/144) (open) |
| AB#403 | Feature | 2 | Platform | Dispose runspace in finally block | [#159](https://github.com/thisismydemo/azure-scout/issues/159) (open) |
| AB#404 | Feature | 3 | Collect | Add client double-poll guard on collecting:true response | [#160](https://github.com/thisismydemo/azure-scout/issues/160) (open) |
| AB#5093 | Epic | 2 | This Is My Demo — Azure Scout | Build the Azure Scout served web application (far-future roadmap) | — |

### AB#5410 — Integrate Azure Scout with external platforms and multi-tenant estates

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#323 | Feature | 3 | Platform | Build multi-tenant support with Azure Lighthouse cross-tenant scanning | [#11](https://github.com/thisismydemo/azure-scout/issues/11) (open) |
| AB#5410 | Epic | 3 | Platform | Integrate Azure Scout with external platforms and multi-tenant estates | — |

## Delivered

### AB#5023 — Extend Azure Scout into a CAF/WAF landing-zone assessment platform

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#316 | Feature | 2 | Platform | Build full Pester unit and integration test suite for Azure Scout | [#3](https://github.com/thisismydemo/azure-scout/issues/3) (open) |
| AB#317 | Feature | 3 | Platform | Build GitHub Actions CI pipeline for Azure Scout | [#5](https://github.com/thisismydemo/azure-scout/issues/5) (open) |
| AB#319 | Feature | 3 | Collect | Add resource provider pre-flight warnings before collection | [#7](https://github.com/thisismydemo/azure-scout/issues/7) (open) |
| AB#320 | Feature | 2 | Platform | Implement throttling and exponential backoff retry logic | [#8](https://github.com/thisismydemo/azure-scout/issues/8) (open) |
| AB#322 | Feature | 3 | Report | Build Visual Dashboard Tabs with EPPlus pivot charts | [#10](https://github.com/thisismydemo/azure-scout/issues/10) (open) |
| AB#324 | Feature | 3 | Collect | Build cost anomaly detection and reporting | [#12](https://github.com/thisismydemo/azure-scout/issues/12) (open) |
| AB#325 | Feature | 3 | Assess | Implement Bicep/IaC gap detection and reporting | [#13](https://github.com/thisismydemo/azure-scout/issues/13) (open) |
| AB#326 | Feature | 3 | Report | Build resource drift reporting — compare inventory runs over time | [#14](https://github.com/thisismydemo/azure-scout/issues/14) (open) |
| AB#329 | Feature | 3 | Report | Add Fabric and Power BI report export | [#17](https://github.com/thisismydemo/azure-scout/issues/17) (open) |
| AB#330 | Feature | 3 | Collect | Add IoT deep coverage (Device Registry, DPS, Digital Twins, and Edge) | [#18](https://github.com/thisismydemo/azure-scout/issues/18) (open) |
| AB#333 | Feature | 3 | Report | Add Word Document (.docx) report export | [#22](https://github.com/thisismydemo/azure-scout/issues/22) (open) |
| AB#334 | Feature | 3 | Report | Add PDF report export | [#23](https://github.com/thisismydemo/azure-scout/issues/23) (open) |
| AB#342 | Feature | 3 | Report | Improve draw.io diagram quality and consistency for Azure Scout | [#31](https://github.com/thisismydemo/azure-scout/issues/31) (open) |
| AB#344 | Feature | 3 | Report | Replace Excel charts with standalone HTML dashboard using Apache ECharts | [#33](https://github.com/thisismydemo/azure-scout/issues/33) (open) |
| AB#348 | Feature | 3 | Platform | Implement auto device-code login with no browser pop-up on headless servers | [#39](https://github.com/thisismydemo/azure-scout/issues/39) (open) |
| AB#349 | Feature | 3 | Platform | Add auth status banner showing UPN and subscription name on login success | [#40](https://github.com/thisismydemo/azure-scout/issues/40) (open) |
| AB#353 | Feature | 2 | Collect | Build Management Group hierarchy collection | [#109](https://github.com/thisismydemo/azure-scout/issues/109) (open) |
| AB#354 | Feature | 2 | Collect | Build all-subscriptions collector with state and tags | [#110](https://github.com/thisismydemo/azure-scout/issues/110) (open) |
| AB#355 | Feature | 3 | Collect | Build Custom and Built-in Policy Definitions and Initiatives collector | [#111](https://github.com/thisismydemo/azure-scout/issues/111) (open) |
| AB#356 | Feature | 3 | Collect | Build Policy Assignments collector with scope, enforcement mode, and parameters | [#112](https://github.com/thisismydemo/azure-scout/issues/112) (open) |
| AB#357 | Feature | 3 | Collect | Build Role Assignments collector with display name, role, scope, and object type | [#113](https://github.com/thisismydemo/azure-scout/issues/113) (open) |
| AB#358 | Feature | 2 | Collect | Build VNets, subnets, DNS servers, service endpoints, and VNet peerings collector | [#114](https://github.com/thisismydemo/azure-scout/issues/114) (open) |
| AB#359 | Feature | 3 | Collect | Build VPN Gateways collector with type, SKU, active-active, and BGP | [#115](https://github.com/thisismydemo/azure-scout/issues/115) (open) |
| AB#360 | Feature | 3 | Assess | Build Azure Firewalls collector with rule collection detail via Invoke-AzRestMethod | [#116](https://github.com/thisismydemo/azure-scout/issues/116) (open) |
| AB#361 | Feature | 3 | Collect | Build Virtual WAN and hub collection | [#117](https://github.com/thisismydemo/azure-scout/issues/117) (open) |
| AB#362 | Feature | 3 | Assess | Build Network Security Groups collector with rule counts and subnet/NIC associations | [#118](https://github.com/thisismydemo/azure-scout/issues/118) (open) |
| AB#363 | Feature | 3 | Collect | Build Private DNS Zones collector with VNet links and registration flags | [#119](https://github.com/thisismydemo/azure-scout/issues/119) (open) |
| AB#364 | Feature | 3 | Collect | Build Private Endpoints collector with NIC lookup for private IPs | [#120](https://github.com/thisismydemo/azure-scout/issues/120) (open) |
| AB#365 | Feature | 3 | Collect | Build Cost Management Budgets collection | [#121](https://github.com/thisismydemo/azure-scout/issues/121) (open) |
| AB#366 | Feature | 3 | Collect | Build Resource Locks collector with level and notes | [#122](https://github.com/thisismydemo/azure-scout/issues/122) (open) |
| AB#367 | Feature | 3 | Ingest | Build tag aggregation across all subscriptions with unique values per key | [#123](https://github.com/thisismydemo/azure-scout/issues/123) (open) |
| AB#369 | Feature | 3 | Platform | Implement module auto-install and auto-update on startup | [#125](https://github.com/thisismydemo/azure-scout/issues/125) (open) |
| AB#370 | Feature | 2 | Assess | Implement dual scoring engine (CAF compliance and WAF alignment) | [#126](https://github.com/thisismydemo/azure-scout/issues/126) (open) |
| AB#371 | Feature | 3 | Assess | Implement CAF scoring across 7 categories with partial-points rules | [#127](https://github.com/thisismydemo/azure-scout/issues/127) (open) |
| AB#372 | Feature | 3 | Assess | Implement WAF pillar scoring with named calculation references and graduated thresholds | [#128](https://github.com/thisismydemo/azure-scout/issues/128) (open) |
| AB#5023 | Epic | 2 | This Is My Demo — Azure Scout | Extend Azure Scout into a CAF/WAF landing-zone assessment platform | — |
| AB#5024 | Feature | 2 | Platform | Build the module registry and Invoke-AzureScout entry point | — |
| AB#5025 | User Story | 2 | Platform | Create the assessments.psd1 module registry manifest | — |
| AB#5026 | User Story | 2 | Platform | Implement the Invoke-AzureScout orchestrator with collect/assess/report flow | — |
| AB#5027 | Feature | 2 | Assess | Build the declarative assessment rule engine | — |
| AB#5028 | User Story | 2 | Assess | Define the YAML rule file format and Get-RuleSet loader | — |
| AB#5029 | User Story | 2 | Assess | Implement the Resolve-JsonPath Newtonsoft wrapper | — |
| AB#5030 | User Story | 2 | Assess | Implement the Invoke-Rule evaluator with all seven assert types | — |
| AB#5031 | Feature | 2 | Assess | Author the CAF and WAF assessment rule files | — |
| AB#5032 | User Story | 2 | Assess | Encode the CAF eight-design-area rule files | — |
| AB#5033 | User Story | 2 | Assess | Encode the WAF five-pillar rule files | — |
| AB#5034 | Feature | 2 | Assess | Build the assessment runner and dual CAF/WAF scoring engine | — |
| AB#5035 | User Story | 2 | Assess | Implement the Invoke-Assessment rule-set runner | — |
| AB#5036 | User Story | 2 | Assess | Implement the Get-Score CAF/WAF scoring and prioritized gap list | — |
| AB#5037 | Feature | 3 | Ingest | Build the ingest layer normalizing external collectors into collect.json | — |
| AB#5038 | User Story | 3 | Ingest | Implement Import-AzGovViz governance-visualizer ingest | — |
| AB#5039 | User Story | 3 | Ingest | Implement Invoke-ArgQueryPack Resource Graph query pack | — |
| AB#5040 | User Story | 3 | Ingest | Implement Import-AdvisorScores WAF signal ingest | — |
| AB#5041 | Feature | 3 | Benchmark | Build the ALZ benchmark diff | — |
| AB#5042 | User Story | 3 | Benchmark | Author the alz-reference.json benchmark reference | — |
| AB#5043 | User Story | 3 | Benchmark | Implement the Compare-Benchmark comparator | — |
| AB#5044 | Feature | 2 | Report | Rebuild reporting into a tiered renderer engine | — |
| AB#5045 | User Story | 2 | Report | Implement the Export-Report renderer dispatcher | — |
| AB#5046 | User Story | 2 | Report | Implement the Export-PowerBi star-schema CSV and .pbit tier | — |
| AB#5047 | User Story | 2 | Report | Implement the self-contained interactive HTML report tier | — |
| AB#5048 | User Story | 3 | Report | Implement the Export-Pptx executive deck generator | — |
| AB#5049 | User Story | 3 | Report | Retain Excel and JSON evidence tiers | — |
| AB#5050 | Feature | 3 | Platform | Extend permission pre-flight and add the unattended assessment pipeline | — |
| AB#5051 | User Story | 3 | Platform | Extend Test-ScoutPermission for per-assessment read-only checks | — |
| AB#5052 | User Story | 3 | Platform | Add the read-only unattended assessment ADO pipeline | — |
| AB#5053 | Feature | 4 | Report | Add the React report variant and cross-run drift tracking | — |
| AB#5054 | User Story | 4 | Report | Build the React interactive report variant | — |
| AB#5055 | User Story | 4 | Report | Implement cross-run drift tracking for findings.json | — |
| AB#5076 | Bug | 1 | Collect | Fix unpaged Search-AzGraph in Get-AZSCManagementGroups (drops subscriptions past 1000) | [#164](https://github.com/thisismydemo/azure-scout/issues/164) |
| AB#5077 | Bug | 1 | Collect | Replace bare Exit with throw in module functions (kills host/runbook uncatchably) | [#165](https://github.com/thisismydemo/azure-scout/issues/165) |
| AB#5078 | Bug | 2 | Collect | Fix off-by-one overlap in &gt;200-subscription batching loop | [#166](https://github.com/thisismydemo/azure-scout/issues/166) |
| AB#5081 | Bug | 1 | Assess | Implement Invoke-Collect flat-&gt;nested adapter (assessment cannot run end-to-end without it) | [#169](https://github.com/thisismydemo/azure-scout/issues/169) |
| AB#5082 | Bug | 1 | Assess | Resolve the discovery/assessment data-shape mismatch (rules assume nested ARM tree; collectors emit flat rows) | [#170](https://github.com/thisismydemo/azure-scout/issues/170) |
| AB#5083 | Bug | 2 | Assess | Fix Newtonsoft JSONPath .length in filters and stop swallowing query exceptions as passes | [#171](https://github.com/thisismydemo/azure-scout/issues/171) |
| AB#5084 | Bug | 2 | Benchmark | Guard Compare-Benchmark against absent governance data (silent all-Fail) | [#172](https://github.com/thisismydemo/azure-scout/issues/172) |
| AB#5085 | Bug | 3 | Assess | Fix percentageAtLeast zero-denominator and value:0 edge cases | [#173](https://github.com/thisismydemo/azure-scout/issues/173) |
| AB#5086 | Bug | 3 | Assess | Scope WAF-RE-05 zone rule to zone-eligible SKUs/regions | [#174](https://github.com/thisismydemo/azure-scout/issues/174) |
| AB#5087 | Bug | 2 | Assess | Use AreaWeight in framework scoring or remove the dead field | [#175](https://github.com/thisismydemo/azure-scout/issues/175) |
| AB#5088 | Bug | 2 | Assess | Surface Unknown-status rules instead of silently dropping them from the score | [#176](https://github.com/thisismydemo/azure-scout/issues/176) |
| AB#5089 | Bug | 2 | Assess | Fix null/unknown severity sorting to top of gap list and PPTX crash | [#177](https://github.com/thisismydemo/azure-scout/issues/177) |
| AB#5090 | Bug | 3 | Report | Fix HTML report coloring null area scores red | [#178](https://github.com/thisismydemo/azure-scout/issues/178) |
| AB#5091 | Bug | 4 | Report | Use deterministic rounding and de-collide Excel sheet names | [#179](https://github.com/thisismydemo/azure-scout/issues/179) |
| AB#5092 | Bug | 4 | Report | Emit a stable AreaKey for the Power BI star-schema join | [#180](https://github.com/thisismydemo/azure-scout/issues/180) |

### AB#5056 — Deliver per-domain CAF/WAF analytics across all Azure Scout categories

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#5056 | Epic | 2 | Assess | Deliver per-domain CAF/WAF analytics across all Azure Scout categories | — |
| AB#5057 | Feature | 2 | Assess | Establish the per-domain assessment taxonomy, tagging, and category-scoped run model | — |
| AB#5058 | User Story | 2 | Assess | Extend the manifest schema with Category, Frameworks, and Tags | — |
| AB#5059 | User Story | 2 | Assess | Wire -Assessment &lt;domain&gt; to category-scoped discovery and scoring | — |
| AB#5060 | User Story | 2 | Assess | Author the assessment registry document | — |
| AB#5061 | Feature | 2 | Assess | Author CAF/WAF assessment coverage for the Management category | — |
| AB#5062 | Feature | 2 | Assess | Author CAF/WAF assessment coverage for the Monitor category | — |
| AB#5063 | Feature | 2 | Assess | Author CAF/WAF assessment coverage for the Networking category | — |
| AB#5064 | Feature | 2 | Assess | Author CAF/WAF assessment coverage for the Identity category | — |
| AB#5065 | Feature | 2 | Assess | Author CAF/WAF assessment coverage for the Security category | — |
| AB#5066 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Compute category | — |
| AB#5067 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Storage category | — |
| AB#5068 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Databases category | — |
| AB#5069 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Containers category | — |
| AB#5070 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Web category | — |
| AB#5071 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Analytics category | — |
| AB#5072 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the AI category | — |
| AB#5073 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Integration category | — |
| AB#5074 | Feature | 3 | Assess | Author CAF/WAF assessment coverage for the Hybrid category | — |
| AB#5075 | Feature | 4 | Assess | Author CAF/WAF assessment coverage for the IoT category | — |

### AB#5094 — Deliver Azure Scout feature parity across the PowerShell and web surfaces

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#373 | Feature | 3 | Assess | Add WAF config hot-swap via browser file upload | [#129](https://github.com/thisismydemo/azure-scout/issues/129) (open) |
| AB#374 | Feature | 3 | Assess | Add WAF config download as JSON | [#130](https://github.com/thisismydemo/azure-scout/issues/130) (open) |
| AB#375 | Feature | 3 | Assess | Add hardcoded fallback assessment when config fails to load | [#131](https://github.com/thisismydemo/azure-scout/issues/131) (open) |
| AB#376 | Feature | 3 | Report | Build vis.js VNet topology diagram with VNets, VMs, and peering edges | [#132](https://github.com/thisismydemo/azure-scout/issues/132) (open) |
| AB#377 | Feature | 3 | Report | Add click-node-to-Resource-Details-panel to topology diagram | [#133](https://github.com/thisismydemo/azure-scout/issues/133) (open) |
| AB#378 | Feature | 4 | Report | Add Reset View and Fit to Screen diagram controls | [#134](https://github.com/thisismydemo/azure-scout/issues/134) (open) |
| AB#379 | Feature | 3 | Report | Embed html2canvas diagram capture as PNG in PDF | [#135](https://github.com/thisismydemo/azure-scout/issues/135) (open) |
| AB#380 | Feature | 3 | Report | Build hierarchical diagram for Management Group hierarchy visualization | [#136](https://github.com/thisismydemo/azure-scout/issues/136) (open) |
| AB#386 | Feature | 3 | Report | Add per-section search/filter inputs in HTML report | [#142](https://github.com/thisismydemo/azure-scout/issues/142) (open) |
| AB#387 | Feature | 3 | Report | Add clickable rows with Resource Details side panel | [#143](https://github.com/thisismydemo/azure-scout/issues/143) (open) |
| AB#389 | Feature | 3 | Report | Build 14 summary KPI cards on dashboard overview | [#145](https://github.com/thisismydemo/azure-scout/issues/145) (open) |
| AB#390 | Feature | 3 | Assess | Build full Azure Firewall policy rule drill-down | [#146](https://github.com/thisismydemo/azure-scout/issues/146) (open) |
| AB#391 | Feature | 3 | Report | Add Governance section with budgets table, locks table, and tag chips | [#147](https://github.com/thisismydemo/azure-scout/issues/147) (open) |
| AB#392 | Feature | 3 | Report | Add policy enforcement mode badge (Default green, DoNotEnforce warning) | [#148](https://github.com/thisismydemo/azure-scout/issues/148) (open) |
| AB#393 | Feature | 4 | Report | Add scope truncation with full tooltip on hover | [#149](https://github.com/thisismydemo/azure-scout/issues/149) (open) |
| AB#394 | Feature | 3 | Report | Implement custom addTable() PDF helper with page-break-aware header repeat | [#150](https://github.com/thisismydemo/azure-scout/issues/150) (open) |
| AB#395 | Feature | 3 | Report | Implement addSubSection(), addBullet(), and getStatusEmoji() PDF text helpers | [#151](https://github.com/thisismydemo/azure-scout/issues/151) (open) |
| AB#396 | Feature | 3 | Report | Build JSON evidence export with resources only and no assessment metadata | [#152](https://github.com/thisismydemo/azure-scout/issues/152) (open) |
| AB#397 | Feature | 2 | Collect | Add per-subscription try/catch/continue for DNS and token errors | [#153](https://github.com/thisismydemo/azure-scout/issues/153) (open) |
| AB#398 | Feature | 3 | Platform | Add AuthorizationFailed on MG role requirement hint | [#154](https://github.com/thisismydemo/azure-scout/issues/154) (open) |
| AB#399 | Feature | 3 | Collect | Swallow false MG resource-provider registration error | [#155](https://github.com/thisismydemo/azure-scout/issues/155) (open) |
| AB#400 | Feature | 3 | Assess | Log firewall policy rule parse errors per group — collection continues | [#156](https://github.com/thisismydemo/azure-scout/issues/156) (open) |
| AB#401 | Feature | 3 | Platform | Add empty-data guard with diagnostic hint | [#157](https://github.com/thisismydemo/azure-scout/issues/157) (open) |
| AB#402 | Feature | 3 | Platform | Check pipeline HadErrors and extract/log as warnings | [#158](https://github.com/thisismydemo/azure-scout/issues/158) (open) |
| AB#405 | Feature | 3 | Platform | Integrate PwshSpectreConsole for rich terminal TUI progress display in Azure Scout | [#161](https://github.com/thisismydemo/azure-scout/issues/161) (open) |
| AB#5079 | Bug | 2 | Collect | Isolate per-subscription query failures so one bad subscription cannot abort the tenant run | [#167](https://github.com/thisismydemo/azure-scout/issues/167) |
| AB#5080 | Bug | 3 | Platform | Add top-level zero-resources guard to the extraction orchestrator | [#168](https://github.com/thisismydemo/azure-scout/issues/168) |
| AB#5094 | Epic | 2 | This Is My Demo — Azure Scout | Deliver Azure Scout feature parity across the PowerShell and web surfaces | — |

### AB#5246 — Establish the Azure Scout engineering foundation, docs, and tooling

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#335 | Bug | 1 | Platform | Fix automation mode cache write to null path in Start-AZSCAutProcessJob | [#24](https://github.com/thisismydemo/azure-scout/issues/24) (open) |
| AB#336 | Bug | 1 | Report | Fix progress bar always showing 0% — $ReportCounter undeclared in Build-AZSCCacheFiles | [#25](https://github.com/thisismydemo/azure-scout/issues/25) (open) |
| AB#337 | Bug | 1 | Platform | Fix $JobNames undefined reference in automation branch of Start-AZSCProcessOrchestration | [#26](https://github.com/thisismydemo/azure-scout/issues/26) (open) |
| AB#338 | Bug | 1 | Platform | Fix $StorageContext null reference — only created inside automation block | [#27](https://github.com/thisismydemo/azure-scout/issues/27) (open) |
| AB#339 | Bug | 2 | Report | Fix $VMQuotas undefined when -SkipVMDetails is passed | [#28](https://github.com/thisismydemo/azure-scout/issues/28) (open) |
| AB#340 | Bug | 2 | Platform | Fix non-functional GitHub Actions azure-inventory.yml workflow (pure simulation) | [#29](https://github.com/thisismydemo/azure-scout/issues/29) (open) |
| AB#341 | User Story | 3 | Assess | Track tech debt, inconsistencies, gaps, improvements, and unknowns in azure-scout | [#30](https://github.com/thisismydemo/azure-scout/issues/30) (open) |
| AB#345 | User Story | 4 | Collect | Auto-generate roadmap from GitHub Issues as single source of truth | [#36](https://github.com/thisismydemo/azure-scout/issues/36) |
| AB#347 | Bug | 1 | Platform | Fix Entra ID modules failing with Global Admin permissions | [#38](https://github.com/thisismydemo/azure-scout/issues/38) (open) |
| AB#5246 | Epic | 2 | Platform | Establish the Azure Scout engineering foundation, docs, and tooling | — |
| AB#5247 | Bug | 2 | Platform | Fix repo-wide .Count-on-null crash class and enforce PowerShell 7 | [#181](https://github.com/thisismydemo/azure-scout/issues/181) |
| AB#5248 | Feature | 3 | Platform | Migrate the Azure Scout documentation site to VitePress | [#34](https://github.com/thisismydemo/azure-scout/issues/34), [#35](https://github.com/thisismydemo/azure-scout/issues/35) |
| AB#5249 | Feature | 3 | Platform | Build the Azure Scout test infrastructure and synthetic fixtures | — |
| AB#5250 | User Story | 3 | Platform | Add the Claude Code agent scaffold to the azure-scout repo | — |
| AB#5251 | Feature | 3 | Platform | Import and rebrand Azure Resource Inventory as the Azure Scout v1 foundation | — |
| AB#5392 | Feature | 2 | Platform | Publish Azure Scout to the PowerShell Gallery and finalize the public release surface | [#2](https://github.com/thisismydemo/azure-scout/issues/2), [#4](https://github.com/thisismydemo/azure-scout/issues/4) |
| AB#5393 | Bug | 3 | Platform | Scope the permission audit to the subscription targeted by -SubscriptionID | [#19](https://github.com/thisismydemo/azure-scout/issues/19) |
| AB#5394 | User Story | 3 | Collect | Collect the full tenant management group hierarchy | [#44](https://github.com/thisismydemo/azure-scout/issues/44) |
| AB#5395 | User Story | 3 | Collect | Collect all subscriptions with state and tags | [#45](https://github.com/thisismydemo/azure-scout/issues/45), [#58](https://github.com/thisismydemo/azure-scout/issues/58) |
| AB#5396 | User Story | 3 | Collect | Collect custom and built-in policy definitions and initiatives | [#46](https://github.com/thisismydemo/azure-scout/issues/46) |
| AB#5397 | User Story | 3 | Collect | Collect policy assignments with scope, enforcement mode, and parameters | [#47](https://github.com/thisismydemo/azure-scout/issues/47) |
| AB#5398 | User Story | 3 | Collect | Collect tenant-wide role assignments with principal and scope detail | [#48](https://github.com/thisismydemo/azure-scout/issues/48) |
| AB#5399 | User Story | 3 | Collect | Collect virtual networks, subnets, DNS servers, service endpoints, and peerings | [#49](https://github.com/thisismydemo/azure-scout/issues/49) |
| AB#5400 | User Story | 3 | Collect | Collect VPN gateways with type, SKU, active-active, and BGP settings | [#50](https://github.com/thisismydemo/azure-scout/issues/50), [#57](https://github.com/thisismydemo/azure-scout/issues/57) |
| AB#5401 | User Story | 3 | Collect | Collect Azure Firewalls with rule collection detail | [#51](https://github.com/thisismydemo/azure-scout/issues/51) |
| AB#5402 | User Story | 3 | Collect | Collect Virtual WAN instances and their hubs | [#52](https://github.com/thisismydemo/azure-scout/issues/52) |
| AB#5403 | User Story | 3 | Collect | Collect network security groups with rule counts and associations | [#53](https://github.com/thisismydemo/azure-scout/issues/53) |
| AB#5404 | User Story | 3 | Collect | Collect private DNS zones with VNet links and registration flags | [#54](https://github.com/thisismydemo/azure-scout/issues/54) |
| AB#5405 | User Story | 3 | Collect | Collect private endpoints with NIC lookup for private IPs | [#55](https://github.com/thisismydemo/azure-scout/issues/55) |
| AB#5406 | User Story | 3 | Collect | Collect Cost Management budgets per subscription | [#56](https://github.com/thisismydemo/azure-scout/issues/56) |
| AB#5407 | User Story | 3 | Collect | Report named collection stages with step and total-step progress percentage | [#108](https://github.com/thisismydemo/azure-scout/issues/108) |
| AB#5414 | Feature | 2 | Platform | Harden the Azure Scout module estate against the StrictMode null-reference crash class | — |
| AB#5415 | Feature | 3 | Platform | Build the Azure Scout AI agent and session-protocol scaffold | — |
| AB#5416 | Feature | 3 | Platform | Build the Azure Scout work-tracking and roadmap generation surface | — |

### AB#5410 — Integrate Azure Scout with external platforms and multi-tenant estates

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#327 | Feature | 3 | Platform | Build Azure DevOps integration for Azure Scout inventory | [#15](https://github.com/thisismydemo/azure-scout/issues/15) |
| AB#328 | Feature | 3 | Platform | Build GitHub Actions module to run Azure Scout as a GitHub Action | [#16](https://github.com/thisismydemo/azure-scout/issues/16) |
| AB#343 | Feature | 3 | Platform | Add Azure Automation Account support with first-class unattended execution | [#32](https://github.com/thisismydemo/azure-scout/issues/32) |

### AB#5411 — Harden the Azure Scout collection run and close the remaining documentation gaps

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#315 | Feature | 2 | Platform | Build phase testing and validation matrix for all collection phases (5-21) | [#1](https://github.com/thisismydemo/azure-scout/issues/1) |
| AB#318 | User Story | 4 | Collect | Document category alias reference for Azure Scout report sections | [#6](https://github.com/thisismydemo/azure-scout/issues/6) |
| AB#331 | Feature | 2 | Platform | Implement non-destructive cache to prevent overwriting previous scan data | [#20](https://github.com/thisismydemo/azure-scout/issues/20) |
| AB#351 | Feature | 3 | Platform | Add post-login management group access probe | [#42](https://github.com/thisismydemo/azure-scout/issues/42) |
| AB#368 | Feature | 3 | Platform | Build cross-subscription context switching with restore | [#124](https://github.com/thisismydemo/azure-scout/issues/124) |
| AB#5411 | Epic | 2 | Platform | Harden the Azure Scout collection run and close the remaining documentation gaps | — |
| AB#5417 | Feature | 4 | Report | Close the Azure Scout report documentation gaps | — |

## Dropped

| Item | Type | P | Area | Title | GitHub |
|---|---|---|---|---|---|
| AB#321 | Feature | 3 | Platform | Implement Invoke-AzureScout -WhatIf support | [#9](https://github.com/thisismydemo/azure-scout/issues/9) |
| AB#332 | Feature | 3 | Platform | Add multi-tenant scanning support for Azure Scout | [#21](https://github.com/thisismydemo/azure-scout/issues/21) |

