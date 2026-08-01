# WAF — enumerated source for the AI workload assessment

**Enumerated 2026-08-01. Verification method and limits are stated below — read them before quoting
any coverage number from this page.**

The audit's DQ12 records why this file exists: *"Writing rules against a framework you have not
enumerated is how `waf.storage.yaml` happened"* — a rule file scoring a WAF pillar that does not
exist. A future `waf.ai.yaml` is written against this enumeration and nothing else, and every rule
in it must cite an item number from the tables below.

## What this assessment is

Microsoft's **Azure Well-Architected Framework AI workload assessment**
(<https://learn.microsoft.com/en-us/assessments/ea306cce-c7fa-4a2b-89a6-bfefba6a9cf4>) is one of
Microsoft's per-workload specialised reviews (§14, item 4 of `pmo/audits/AZURE-SCOUT-AUDIT.md`).
Unlike Azure Local, AVD, and most other workloads, the AI workload is **not organised by the five
WAF pillars** — it's organised into **ten "AI workload design areas"** described at
[AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/get-started#ai-workload-design-areas),
and the assessment tool is built from questions "based on the AI workload design areas."

## Source

| Field | Value |
|---|---|
| Design-area index | [AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/get-started) |
| Framework version | Azure Well-Architected Framework, AI workload guidance, current (`learn.microsoft.com/azure/well-architected/ai/`) |
| Extraction date | 2026-08-01 |
| Verification method | Each design-area article was fetched in full via the Microsoft Learn MCP `microsoft_docs_fetch` tool. Seven of the ten design areas publish a **"Recommendations"** summary table — a genuine, citable, Microsoft-authored checklist. Those seven tables are transcribed below in full. |

## The one thing this enumeration is NOT

**The interactive assessment's question text and numbering are not published**, exactly as with
SMART and the Azure Local review. What this file enumerates instead is the **"Recommendations"**
table that appears on seven of the ten design-area articles — each row is Microsoft's own
bolded-recommendation-plus-description, which the assessment tool draws its questions from. The
`WAF-AI-*` identifiers below are **Scout's**, not Microsoft's.

**Three design areas are a documented gap, not a fabrication:**

| Design area | Why it's not enumerated here |
|---|---|
| [Data platform](https://learn.microsoft.com/en-us/azure/well-architected/ai/data-platform) | Fetched in full. It has no "Recommendations" summary table — its content is a set of "Technology options" comparison tables and evaluation questions, not discrete checklist items. |
| [Testing and evaluation](https://learn.microsoft.com/en-us/azure/well-architected/ai/test) | Fetched in full. Same as above — narrative guidance and tooling lists, no "Recommendations" table. |
| [Workload personas](https://learn.microsoft.com/en-us/azure/well-architected/ai/personas) | Not fetched in this pass. Its content (team-role definitions) is unlikely to produce ARM-scoreable items even if it does have a table; flagged for a follow-up verification rather than guessed at here. |

**Shelf life.** The AI workload guidance is one of the most actively developed corners of the WAF
docs (new agentic-AI content lands frequently). Re-verify before quoting, and re-date this page when
you do.

## The enumeration — 34 items across 7 of 10 design areas

### Application design (WAF-AI-APPD) — 6 items

Source: [Application design for AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/application-design)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-APPD-01 | Prioritize security and Responsible AI controls (provider safety systems, input/output filtering, rate limiting) | ⚠️ Partial — `Security/DefenderAssessments` may surface generic findings; AI-specific content-safety config isn't collected |
| WAF-AI-APPD-02 | Keep intelligence away from the client (back-end handles rate limiting, failover, AI logic) | ❌ Unanswerable — an application-architecture pattern, not an ARM property |
| WAF-AI-APPD-03 | Block direct access to data stores (route through an API/data-access abstraction) | ❌ Unanswerable — code-level pattern |
| WAF-AI-APPD-04 | Abstract models and tools behind standardized interfaces | ❌ Unanswerable — code-level pattern |
| WAF-AI-APPD-05 | Isolate behaviors and actions across client/intelligence/knowledge/tools layers | ❌ Unanswerable — architecture pattern |
| WAF-AI-APPD-06 | Prioritize prebuilt SaaS/PaaS solutions over custom builds | ✅ `AI/OpenAIAccounts`, `AI/AppliedAIServices` presence indicates PaaS/SaaS adoption vs. `AI/MachineLearning` custom-build indicators |

### Application platform (WAF-AI-APPP) — 7 items

Source: [Application platform for AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/application-platform)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-APPP-01 | Reuse existing tools before adopting a new one | ❌ Organisational |
| WAF-AI-APPP-02 | Consider compliance requirements for data and deployment regions | ⚠️ Partial — resource `location` is collected on every `AI/*` collector; regulatory-fit judgement isn't automatable |
| WAF-AI-APPP-03 | Minimize building — prefer PaaS/SaaS to reduce operational burden | ✅ Same signal as WAF-AI-APPD-06 |
| WAF-AI-APPP-04 | Understand quotas and limits for the chosen PaaS/SaaS service | ❌ Unanswerable — quota values aren't exposed via the ARG properties Scout reads |
| WAF-AI-APPP-05 | Deploy related resources in the same region | ✅ Cross-resource region comparison across `AI/*`, `Networking/*` collectors is a rule-authoring task on already-collected `location` fields |
| WAF-AI-APPP-06 | Practice safe deployment — place APIs behind a gateway | ⚠️ Partial — `Networking/PrivateEndpoint`, API Management collectors (if present) evidence a gateway; the practice itself isn't fully inferable |
| WAF-AI-APPP-07 | Establish performance benchmarks through experimentation | ❌ Unanswerable — a benchmarking exercise |

### Training data design (WAF-AI-TRAIN) — 5 items

Source: [Design training data for AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/training-data-design)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-TRAIN-01 | Select data sources based on workload requirements (quality, balance, technique) | ❌ Unanswerable — a data-science process decision |
| WAF-AI-TRAIN-02 | Conduct data analysis (EDA) on collected data early | ⚠️ Partial — `AI/MLComputes` presence suggests EDA tooling exists; whether it's used early is not collected |
| WAF-AI-TRAIN-03 | Maintain data segmentation where security/technical requirements call for it | ❌ Unanswerable — a data-pipeline design choice |
| WAF-AI-TRAIN-04 | Preprocess data to remove noise and standardize formats | ❌ Unanswerable — a pipeline implementation detail |
| WAF-AI-TRAIN-05 | Avoid training on stale data — monitor for drift, define retraining triggers | ⚠️ Partial — `AI/MLPipelines` presence indicates a retraining pipeline exists; drift-monitoring configuration isn't collected |

### Grounding data design (WAF-AI-GROUND) — 4 items

Source: [Grounding Data Design for AI Workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/grounding-data-design)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-GROUND-01 | Anticipate user queries when designing the grounding pipeline | ❌ Unanswerable — a design-time decision |
| WAF-AI-GROUND-02 | Externalize grounding data to a search index instead of querying the source system | ✅ `AI/SearchServices`, `AI/SearchIndexes` presence evidences this |
| WAF-AI-GROUND-03 | Develop a comprehensive ingestion strategy (dedup, standardize, rescope) | ❌ Unanswerable — a pipeline implementation detail |
| WAF-AI-GROUND-04 | Design the index for maximum relevancy (filtering, sorting, metadata) | ⚠️ Partial — `AI/SearchIndexes` reports schema/field configuration where the API exposes it; relevancy tuning quality is not scorable |

### MLOps and GenAIOps (WAF-AI-MLOPS) — 4 items

Source: [MLOps and GenAIOps for AI workloads on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/mlops-genaiops)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-MLOPS-01 | Design an efficient workload operations lifecycle (DataOps/MLOps/GenAIOps stages, tooling) | ✅ Composite — `AI/MLPipelines`, `AI/MLEndpoints`, `AI/MLModels` together evidence lifecycle tooling is in place |
| WAF-AI-MLOPS-02 | Automate everything in the build/test/validate/deploy cycle | ⚠️ Partial — DevOps pipeline collectors (`DevOps/*`) can show CI/CD exists; whether AI-specific stages are automated is not distinguishable |
| WAF-AI-MLOPS-03 | Use deployment pipelines for repeatable infrastructure and model promotion | ⚠️ Partial — same as MLOPS-02 |
| WAF-AI-MLOPS-04 | Prevent drift and decay in models via structured maintenance | ❌ Unanswerable — model-quality monitoring configuration isn't a collected property |

### Workload operations (WAF-AI-OPS) — 4 items

Source: [AI workload operations on Azure](https://learn.microsoft.com/en-us/azure/well-architected/ai/operations)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-OPS-01 | Monitor all aspects of the workload (component availability + quality metrics) | ✅ `Monitor/DataCollectionRules`, `Monitor/MetricAlertRules` scoped to `AI/*` resources |
| WAF-AI-OPS-02 | Apply safe deployment practices to AI components (blue-green, canary, side-by-side index updates) | ❌ Unanswerable — a deployment-process practice |
| WAF-AI-OPS-03 | Embrace DevOps practices — testing and automation in production | ⚠️ Partial — `DevOps/*` collectors evidence pipeline existence generally |
| WAF-AI-OPS-04 | Document progress — decisions, data sources, training history | ❌ Organisational |

### Responsible AI (WAF-AI-RAI) — 4 items

Source: [Responsible AI in Azure workloads](https://learn.microsoft.com/en-us/azure/well-architected/ai/responsible-ai)

| # | Item | Scout collector |
|---|---|---|
| WAF-AI-RAI-01 | Develop policies enforcing responsible-AI practices at each lifecycle stage | ❌ Organisational |
| WAF-AI-RAI-02 | Protect user data — collect only what's necessary, apply technical controls | ⚠️ Partial — `Security/KeyVaultSecrets`, `Security/KeyVaultKeys` evidence secret-handling infrastructure; data-minimisation practice itself isn't scorable |
| WAF-AI-RAI-03 | Keep AI decisions clear and understandable to users | ❌ Unanswerable — a UX/transparency practice |
| WAF-AI-RAI-04 | Implement agentic AI safeguards (auditability, RBAC, circuit breakers) | ⚠️ Partial — `Identity/ConditionalAccess` and RBAC-assignment collectors (where present) evidence access control exists; circuit-breaker/auditability configuration is not collected |

## Summary

| Design area | Items | Answerable (✅) | Partial (⚠️) | Unanswerable (❌) |
|---|---|---|---|---|
| Application design | 6 | 1 | 1 | 4 |
| Application platform | 7 | 2 | 2 | 3 |
| Training data design | 5 | 0 | 2 | 3 |
| Grounding data design | 4 | 1 | 1 | 2 |
| MLOps and GenAIOps | 4 | 1 | 2 | 1 |
| Workload operations | 4 | 1 | 1 | 2 |
| Responsible AI | 4 | 0 | 2 | 2 |
| **Total (7 of 10 areas)** | **34** | **6** | **11** | **17** |

6 of 34 enumerated items (18%) map cleanly to an existing collector — lower than Azure Local, because
AI workload guidance is dominated by application-design and process practices (code architecture,
data-science methodology, deployment process) that ARM/ARG inherently cannot see. 11 are partially
answerable through existing `AI/*`, `Security/*`, `Monitor/*`, and `Identity/*` collectors. 17 are
genuinely unanswerable — the highest proportion of any of the four checklists in this release, and an
honest reflection of how much of "AI workload well-architected" is process and application-code
discipline rather than infrastructure configuration.

## What this means for the rule file

A future `waf.ai.yaml` should cite `WAF-AI-*` item numbers. Given the low automatable fraction, this
rule file should expect to carry more `manual: true` rows than any of the other three workload
checklists in this release, and the report should say so rather than implying full coverage.
