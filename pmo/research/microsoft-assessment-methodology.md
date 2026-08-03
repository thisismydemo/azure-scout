# How Microsoft assesses and reports Azure Landing Zone / CAF / WAF posture

Research input for the v3.3.4 reporting engine rebuild. Every claim below is sourced.
Scope: report *structure* and *score explanation* patterns Microsoft itself uses — not
general CAF prose.

---

## 1. Azure Landing Zone Review (learn.microsoft.com/assessments)

- **What it is**: a self-service questionnaire, ~30 minutes, multiple-choice/multiple-response,
  that reviews "Azure platform readiness" and the customer's landing zone plan. Designed for
  customers with 2+ years of Azure experience, but usable earlier to find investment areas.
  Source: [Azure Landing Zone Review](https://learn.microsoft.com/en-us/assessments/21765fea-dfe6-4bc4-8bb7-db9df5a6f6c0/), [Azure Essentials show walkthrough](https://learn.microsoft.com/en-us/shows/azure-essentials-show/assess-your-cloud-environment-with-the-azure-landing-zone-review).
- **Results page contents** (per the Microsoft Assessments platform FAQ, which governs every
  assessment on the platform including this one):
  1. An **overall score** used to benchmark "where you are on your journey."
  2. **Curated next steps and tailored recommendations per category**, each with a link to
     supporting Learn documentation.
  3. A **share/export mechanism** — social sharing, and CSV export when signed in.
  4. The design intent stated explicitly: "help you determine what concrete actions you can
     take to improve your journey" — i.e., the score exists to justify a call to action, not
     as an end in itself.
  Source: [Microsoft Assessments FAQ — what information does the results page provide](https://learn.microsoft.com/assessments/support/#what-is-microsoft-assessments).
- Retaking the assessment and tracking score-over-time is a first-class feature — the tool
  assumes the customer will act, then re-run, then compare.

**Takeaway for azure-scout**: every Microsoft assessment result page pairs *score → recommendation
→ link to guidance → path to re-measure*. A score with no adjacent "what to do about it, and where
it comes from" is not the Microsoft pattern.

---

## 2. Azure landing zone design areas (CAF Ready) — what "compliant" means per area

The Azure landing zone conceptual architecture is organized into **eight lettered design areas**
(A–I, skipping D/H in the current diagram), each with a stated objective a review can be scored
against:

| Area | Design area | Objective |
|---|---|---|
| A | Azure billing and Microsoft Entra tenant | Correct tenant creation, enrollment, and billing setup |
| B | Identity and access management | The primary security boundary in the public cloud |
| C | Resource organization | Subscription design and management-group hierarchy that scales |
| E | Network topology and connectivity | Foundational networking decisions |
| — | Resource organization / Governance | Mechanisms and processes for maintaining control over platforms, apps, resources |
| — | Security | Security is a first-class design area, cross-cutting through greenfield/brownfield guidance |
| — | Management | Operations, monitoring |
| — | Platform automation and DevOps | IaC and automated landing zone deployment |

Sources: [Azure landing zone design areas and conceptual architecture](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-areas), [Design area: Azure governance](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/governance), [Design area: Security](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/security), [Azure Virtual Desktop landing zone design guide — "eight design areas"](https://learn.microsoft.com/azure/architecture/landing-zones/azure-virtual-desktop/design-guide).

Each design-area article follows the same fixed sub-structure: **Design area overview → Design
considerations → Design recommendations**, so "compliant" per area means: the environment's
configuration matches the stated recommendations for that area, not an arbitrary numeric
threshold. There is no official CAF numeric weighting of the eight areas relative to each other —
weighting is introduced downstream, by the review tooling (see §3) or by MCSB/Secure Score (§6),
not by the CAF conceptual model itself.

**Takeaway for azure-scout**: the product's per-assessment structure (Identity, Networking,
Governance, Security, Management, DevOps, Resource Organization, Billing) already mirrors these
eight areas by name. The report should say so explicitly — map each azure-scout assessment
category to its CAF design-area name and link, so the reader can verify the report is following
a documented Microsoft taxonomy rather than an invented one.

---

## 3. Azure Review Checklists (github.com/Azure/review-checklists) — the ALZ checklist schema

This is Microsoft's own open-source tool for doing landing zone / WAF design reviews at scale
(used internally by Microsoft field teams and partners). It is the closest real-world analogue
to what azure-scout produces.

- **Item schema** (from `checklists/alz_checklist.en.json`), one JSON object per checklist row:

  | Field | Purpose | Example |
  |---|---|---|
  | `guid` | Stable identity for the check, survives renumbering | `70c15989-c726-42c7-b0d3-24b7375b9201` |
  | `id` | Human-readable item code, tied to the design-area letter | `A01.01` |
  | `category` | Design area | `Azure Billing and Microsoft Entra ID Tenants` |
  | `subcategory` | Sub-topic within the area | `Microsoft Entra ID Tenants` |
  | `text` | The actual recommendation being checked | "Use one Entra tenant for managing your Azure resources…" |
  | `description` | Optional longer explanation | — |
  | `severity` | High / Medium / Low | `Medium` |
  | `waf` | Which WAF pillar the item maps to | `Operations` |
  | `service` | Azure service the item concerns | `Entra` |
  | `link` | Deep link to the CAF/Learn guidance for this exact item | `https://learn.microsoft.com/azure/cloud-adoption-framework/...` |
  | `training` | Optional Microsoft Learn training module link | — |
  | `graph` | Optional Azure Resource Graph KQL query that can auto-detect the item | — |
  | `ammp` | Boolean flag marking the item in-scope for the Azure Migration and Modernization Program variant | — |

  Source: [Azure/review-checklists](https://github.com/Azure/review-checklists), raw schema inspection of `checklists/alz_checklist.en.json`.

- **Reporting mechanism**: the JSON compiles into an Excel workbook. Reviewers work row by row —
  either area-by-area (Networking, then Security, etc.) or severity-first (all High items across
  every area first) — setting a status per row and adding a Comments field to record remediation
  owner or the reason a deviation is accepted. A **Dashboard worksheet** aggregates status counts
  into a graphical "review progress" view. There's also an Azure Monitor workbook and a
  Power BI path for the same data. Source: [Azure/review-checklists README](https://github.com/Azure/review-checklists).

**Takeaway for azure-scout**: this is the closest Microsoft-native precedent for a per-finding
evidence table. Azure-scout's findings should carry the same fields this schema treats as
load-bearing: a stable id, severity, WAF pillar mapping, and — critically — a **direct link to
the Learn guidance for that exact rule**, not just a category name. Today's reports don't
consistently carry that link (see gap table, §8).

---

## 4. Well-Architected Review assessment — pillar scores and recommendation prioritization

- **Structure**: ~60 questions across the five WAF pillars (Reliability, Security, Cost
  Optimization, Operational Excellence, Performance Efficiency), roughly 60 minutes, informed
  optionally by live Azure Advisor recommendations for the target subscription/resource group.
  Source: [Azure Well-Architected Review](https://learn.microsoft.com/en-us/assessments/azure-architecture-review/), [Complete an Azure Well-Architected Review assessment](https://learn.microsoft.com/en-us/azure/well-architected/design-guides/implementing-recommendations).
- **Milestones, not a single point-in-time score**: the tool explicitly supports re-running the
  assessment as a "milestone" and comparing it to a prior milestone — brownfield workloads are
  expected to be re-assessed on a cadence (Microsoft's own example: every four months). The
  report is framed as a **continuous-improvement loop diagram**: assess → prioritize → implement
  → re-assess.
- **Recommendation identity and prioritization**: every recommendation carries a pillar code plus
  number (e.g., `SE:05` = Security pillar, article 5), so a reader can trace any single
  recommendation back to the exact WAF guidance article. Recommendations are explicitly
  characterized by **severity, effort, and business impact**, and the guidance surfaces a
  curated **top-5 "priority actions"** — meaningful improvement for manageable effort — rather
  than dumping the full backlog on the reader at once.
- **Export path**: results export to CSV for import into the team's backlog/ADO/GitHub, with a
  published DevOps tooling recipe for that import (`WellArchitected-Tools/WARP/devops`).
- Sources: [Complete an Azure Well-Architected Review assessment](https://learn.microsoft.com/en-us/azure/well-architected/design-guides/implementing-recommendations), [WAF review assessment updates](https://techcommunity.microsoft.com/blog/azurearchitectureblog/azure-well-architected-review-assessment-updates/3981023).

**Takeaway for azure-scout**: (1) recommendations need a stable pillar+number code the reader can
look up, exactly like `SE:05`; (2) the report should curate a small "top N now" list distinct
from the full findings table — a wall of findings with no ordering is not the Microsoft pattern;
(3) framing every report as one point in a milestone series (even if azure-scout doesn't yet
store history) sets the right reader expectation.

---

## 5. AzGovViz / partner-led ALZ assessments — what's actually delivered

Search for concrete AzGovViz/partner-ALZ-assessment deliverable examples did not surface a
citable, authoritative Microsoft-owned description of the artifact set beyond what's already
covered by the Review Checklists tool (§3) and the ALZ Bicep/accelerator governance defaults
referenced from the CAF governance design-area page. I did not find a primary source strong
enough to state new claims here without weakening the rest of the document's sourcing standard —
flagging this as an open gap rather than asserting something unverified. The CAF governance page
does confirm one relevant fact: **Microsoft's own accelerators (ALZ-Bicep) ship default policy
assignments as the operational expression of "governance design area compliance"** — i.e.,
in Microsoft's own tooling, governance compliance is ultimately checked against Azure Policy
assignment state, not narrative. Source: [Design area: Azure governance](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/governance#design-area-review).

---

## 6. Microsoft Cloud Security Benchmark / Defender for Cloud Secure Score — the "score = weighted controls" pattern

This is the strongest, most concrete precedent for **explaining a score to a reader**, and the
one the v3.3.4 rebuild should copy most directly.

- **Foundation**: Secure Score is generated from MCSB assessment findings. Only built-in MCSB
  recommendations count toward the score; **Preview recommendations are explicitly excluded** and
  labeled as such — this is the "not assessed" handling azure-scout needs.
- **Controls, not raw findings, are the scoring unit**: individual recommendations are grouped
  into named **security controls** (e.g., "Enable MFA," "Secure management ports," "Remediate
  vulnerabilities"). Each control has a **fixed max score**, published in a table, that reflects
  its relative security importance and is constant across every environment — MFA is worth 10
  points everywhere; "Implement security best practices" is worth 0 points everywhere (informational
  only, doesn't move the number).
- **The exact formula, shown to the reader**:
  - Per control: `current score = (max score / total resources in scope) × healthy resources`.
    Example given verbatim in the docs: max score 6, 78 total resources, 4 healthy →
    `6/78 = 0.0769` per resource → `0.0769 × 4 = 0.31` current score.
  - Per subscription: `secure score % = (Σ current scores of all controls) / (Σ max scores of all controls) × 100`.
  - Across multiple subscriptions: a **weighted sum**, not an average of percentages — each
    subscription's weight is its combined healthy+unhealthy resource count. The docs explicitly
    warn readers not to try to hand-recompute the aggregate from the per-control numbers shown in
    the UI, because the weighting isn't visible at that level — the UI already tells the reader
    "the math is more than what you can see, trust the aggregate."
  - **"Not assessed" handling**: if a subscription has zero resources in scope for a given
    control (no healthy or unhealthy resources), that control is dropped entirely from that
    subscription's calculation — neither its current nor its max points are counted. This is the
    concrete precedent for "N/A collectors shouldn't silently count as a zero."
  - **Potential score increase** is shown per control: `(max score/total resources) × unhealthy
    resources` — i.e., exactly what the reader gains by fixing everything in that one control,
    which is how Defender for Cloud tells the reader what to work on first.
- **Presentation**: overall score shown prominently as a single percentage plus its underlying
  numerator/denominator; a dedicated Secure Score page breaks it down per subscription and per
  management group; the Recommendations page's "Secure score recommendations" tab lists every
  control with columns for **Max score / Current score / Potential score increase / Insights**
  (Fix / Enforce / Deny badges); a Power BI "Secure Score Over Time" template tracks the trend and
  even calls out a "detected changes that might affect your secure score" table when the number
  moves, distinguishing real remediation from resource churn.
- Source: [Secure score in Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/secure-score-security-controls) — includes the full worked formula, the fixed max-score table for all 15 controls, and the multi-subscription weighting caveat quoted above.

**Takeaway for azure-scout**: this is the single best model for the "how to read this score"
section the reporting engine needs. It answers, concretely, the numbers azure-scout currently
leaves unexplained:
- Show the **denominator** (how many resources/checks were in scope for this area) next to any
  score, not just the numeric result.
- Publish a **fixed, documented weight per assessment/rule** so a 10/10 always means the same
  thing across tenants (Secure Score's per-control max score is fixed for every environment;
  azure-scout's per-rule severity/weight should be too, and should be printed in the report, not
  just used silently by the scoring engine).
- Treat **rules with zero applicable resources as excluded from the denominator**, and say so in
  the report ("N of M rules not applicable in this tenant") rather than silently scoring them 0
  or 10.
- Show, per area, what the score would become if every open finding in that area were fixed —
  the "potential score increase" column — so remediation prioritization has a number attached,
  not just a severity label.

---

## 7. Cross-cutting pattern across every Microsoft source above

Every artifact examined — the Landing Zone Review results page, the WAF Review milestone/export
model, the Review Checklists dashboard, and Secure Score — repeats the same four elements in the
same order:

1. **A score the reader can audit**: numerator, denominator, and what's excluded and why.
2. **A stable identifier per finding/recommendation** (`A01.01`, `SE:05`, a control name, a
   checklist `guid`) that survives report regeneration and can be tracked over time.
3. **A direct link from the finding to Microsoft's own guidance for fixing it** — never just a
   category name.
4. **A curated, prioritized subset for action** (top 5, "potential score increase," Fix/Enforce/Deny
   badges) that is visibly separate from the exhaustive findings list.

None of the four sources present an unexplained bare score with no legend, and none present an
undifferentiated wall of findings with no ranking.

---

## 8. Gap table — azure-scout today vs. the Microsoft-style pattern

| Microsoft pattern | azure-scout today | Gap / filed bug |
|---|---|---|
| Score shown with numerator/denominator and a legend explaining the scale | `Export-Pptx.ps1`'s Executive Summary renders bare score cards (`Get-ScoutScoreColor`/`Get-ScoutPptxProp 'Score'`) with no denominator, no "N rules assessed, M not applicable" text, no legend slide | Unexplained 10/10 scores with no methodology (already filed) |
| Fixed, documented per-item weight, same across every environment (Secure Score's per-control max) | Assessment rule weights exist in the scoring engine (`src/assess/rules/*.yaml`) but are not surfaced in the rendered report — the reader sees only the rolled-up number | No methodology/legend section in the report (already filed) |
| "Not assessed" / N-A items excluded from the denominator, and disclosed as excluded | Not confirmed as consistently modeled in the renderer output — no visible "N/A" accounting alongside scores | Related to the unexplained-score bug; worth a check during the v3.3.4 methodology section build |
| Dashboard aggregates progress visually (Review Checklists' Dashboard worksheet; Secure Score tile) | Dashboard reported as rendering blank in current output | Blank dashboard (already filed) |
| Every finding/report carries a stable, human-meaningful identity (`A01.01`, `SE:05`, workload name in the WAF assessment title) | Reports have been shipped without a clear per-tenant/per-assessment identifying name | Unnamed reports (already filed) |
| Direct link from each finding to the exact Learn/CAF guidance article for that rule (Review Checklists' `link`/`training` fields) | Findings carry category/severity but link-to-guidance coverage is inconsistent per the collector audit corpus findings memory | Design-input for v3.3.4: add a `link` field to the rule schema, mirroring `alz_checklist.en.json` |
| Curated "priority actions" (WAF's top-5) / "potential score increase" ranking (Secure Score) distinct from the full findings table | Findings render as one flat table with no now/next/later split | Design-input for v3.3.4: add a remediation roadmap section |
| Milestone/re-run framing — score-over-time is a first-class concept | No score-history or trend concept in the current renderer set | Out of scope for v3.3.4 per the corpus-based, single-snapshot rendering model, but worth flagging for the reporting engine's data model going forward |

This maps directly onto AB#6904–6912 as filed (blank dashboard, unexplained 10/10 scores, missing
methodology/legend, unnamed reports) — every one of those four defects is the azure-scout-specific
instance of a pattern Microsoft's own tooling treats as mandatory in all four sources reviewed.

---

## 9. Concrete recommendation for the v3.3.4 per-assessment report structure

Order, modeled directly on the sources above (Secure Score for the scoring math, WAF Review for
the milestone/priority framing, Review Checklists for the finding schema, Landing Zone Review for
the results-page shape):

1. **Cover / title** — tenant name, assessment name, generation timestamp. Every report must be
   self-identifying (closes the "unnamed reports" gap).
2. **Executive summary** — overall score(s) per framework, one sentence per area on direction of
   travel, and the curated "priority actions" list (WAF's top-5 pattern) — not the full findings
   table.
3. **Scoring methodology ("How to read this report")** — a fixed, reusable section, not
   generated per-tenant: explain the scale, state that weights are fixed per rule/design area
   (name where the weight table lives), explain N/A handling and how it's excluded from the
   denominator, and give one worked example in the same style as the Secure Score docs
   (`max / total resources in scope × healthy = current score`). This single section closes the
   "no methodology/legend" gap for every report the engine produces.
4. **Per-design-area scorecard** — one row/card per CAF design area (mapped explicitly to the
   eight design areas in §2, by name, with the Learn link for that area), each showing:
   `current score / max score`, resources or checks assessed, checks not applicable, and the
   "potential score increase if fixed" number, exactly as Secure Score's control table does.
5. **Findings with evidence** — the Review Checklists schema fields per row: stable id,
   category/subcategory, severity, WAF pillar, the resource(s) affected (the evidence), and a
   direct Learn/CAF guidance link per finding, not just per category.
6. **Prioritized remediation roadmap** — now / next / later phases (a defensible way to operationalize
   WAF's severity+effort+impact triage without requiring a live effort-scoring interview), each
   item carrying its Learn link, mirroring WAF Review's CSV-to-backlog export intent even if
   azure-scout's own export is a table rather than a literal CSV handoff.
7. **Appendix** — full raw findings table (the exhaustive list this structure deliberately keeps
   out of the executive summary), collector coverage notes, and the fixed weight table referenced
   in the methodology section.

This gives every report the four cross-cutting elements from §7 — auditable score, stable
identifiers, guidance links, and a curated action list — in the same order Microsoft's own
assessment tooling uses them.

---

## Sources

- [Azure Landing Zone Review](https://learn.microsoft.com/en-us/assessments/21765fea-dfe6-4bc4-8bb7-db9df5a6f6c0/)
- [Assess your cloud environment with the Azure Landing Zone Review (show)](https://learn.microsoft.com/en-us/shows/azure-essentials-show/assess-your-cloud-environment-with-the-azure-landing-zone-review)
- [Microsoft Assessments — Frequently asked questions](https://learn.microsoft.com/assessments/support/)
- [Azure landing zone design areas and conceptual architecture](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-areas)
- [Design area: Azure governance](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/governance)
- [Design area: Security](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/security)
- [Azure Virtual Desktop landing zone design guide](https://learn.microsoft.com/azure/architecture/landing-zones/azure-virtual-desktop/design-guide)
- [What is an Azure landing zone?](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Azure/review-checklists (GitHub repo)](https://github.com/Azure/review-checklists)
- [alz_checklist.en.json (raw schema)](https://raw.githubusercontent.com/Azure/review-checklists/main/checklists/alz_checklist.en.json)
- [Azure Well-Architected Review](https://learn.microsoft.com/en-us/assessments/azure-architecture-review/)
- [Complete an Azure Well-Architected Review assessment](https://learn.microsoft.com/en-us/azure/well-architected/design-guides/implementing-recommendations)
- [Azure Well-Architected Review Assessment Updates (Community Hub)](https://techcommunity.microsoft.com/blog/azurearchitectureblog/azure-well-architected-review-assessment-updates/3981023)
- [Secure score in Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/secure-score-security-controls)

## Repo cross-reference

- Current executive-summary/score-card rendering: `D:\git\thisismydemo\azure-scout\src\report\renderers\Export-Pptx.ps1` (score cards ~line 979, per-area score table ~line 1072, no methodology/legend slide, no denominator shown).
- Assessment rule definitions (where fixed weights should live/be surfaced): `D:\git\thisismydemo\azure-scout\src\assess\rules\*.yaml`.
