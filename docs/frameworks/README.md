# docs/frameworks — the standard for enumerated framework sources

This directory holds Scout's own enumeration of each framework a rule file scores against —
CAF design areas, WAF pillars, SMART's subject areas, and any regulatory-compliance initiative
added later. A rule file must never be written against a framework nobody enumerated first: that
is how `waf.storage.yaml` ended up scoring a WAF pillar that does not exist (audit §8, item 9),
and how a `caf.*` rule file could go on citing a recommendations heading Microsoft has since
rewritten (audit §8, item 7). This file is the standard every enumeration file under this
directory must meet. `smart-question-set.md` is the reference implementation — match its shape.

## Why this exists (AB#6817)

Two facts from the audit make framework currency a permanent, not a one-time, problem:

1. **Microsoft is actively rewriting CAF design-area pages** away from the
   "Design considerations" / "Design recommendations" structure. At least three pages already
   render as numbered task sections instead, with no recommendations heading at all. A coverage
   percentage computed against a recommendation count on one of those pages silently drifts the
   next time Microsoft edits it.
2. **Regulatory-compliance initiatives are versioned, and older versions stay live.** Azure
   simultaneously ships six CIS Azure Foundations initiatives (v1.1.0 through v3.0.0), two ISO
   27001 sets, three PCI sets, and both NIST SP 800-53 Rev. 5 and R5.1.1. "CIS compliance: 72%"
   names nothing if the reader cannot tell whether the denominator was 31 policies or 168.

The fix is not a one-off correction — it is a rule that every enumeration file, and every
coverage figure Scout ever prints, keeps naming what it was measured against.

## The mandatory header block

Every file under `docs/frameworks/*.md` — except this `README.md` — must carry four pieces of
information near the top, before the first content section: **Source**, **Framework version**,
**Extraction date**, and **Verification method**. What actually landed in this directory while
this standard was being written settled on two equally acceptable shapes rather than one; use
whichever fits the file better, but do not invent a third:

**Shape A — a blockquote metadata block**, immediately under the title (`smart-question-set.md`,
`waf-pillar-checklists.md`, `caf-landing-zone-design-areas.md`):

```markdown
# <Framework name> — <what this file enumerates>

> **Source:** <the canonical URL(s) this enumeration was read from>
> **Framework version:** <the framework's own version string, or, when the framework does not
> publish one (CAF and WAF do not), a statement that the extraction date is being used as the
> version>
> **Extracted:** <YYYY-MM-DD — the date the source was actually read>
> **Verification method:** <one or two sentences: what was read, how, and what could NOT be
> confirmed>
```

**Shape B — a `Field | Value` table**, placed wherever the file's own structure reads best,
paired with the `**Enumerated YYYY-MM-DD.**` lede paragraph most files already open with
(`waf-ai-workload-checklist.md`, `waf-avd-workload-checklist.md`, `waf-avs-workload-checklist.md`,
`waf-azure-local-checklist.md`):

```markdown
**Enumerated YYYY-MM-DD.** ...

| Field | Value |
|---|---|
| Source page | <URL(s)> |
| Framework version | <version string, or "not versioned by Microsoft — see extraction date"> |
| Extraction date | YYYY-MM-DD |
| Verification method | <what was read, how, and what could not be confirmed> |
```

A third, older pattern — the `**Enumerated YYYY-MM-DD.**` lede plus a `## Verification method`
section and a "What was read" table, but with no explicit **Framework version** line — predates
this standard and is **not sufficient on its own**: it is missing the version field criterion 1
of AB#6817 requires. `avs-landing-zone-question-set.md`, `casa-question-set.md`, and
`cloud-governance-question-set.md` used to be in this state; each now carries an added
**`Framework version:`** line stating plainly that Microsoft does not version the source and that
the extraction date is being used instead — add the same one line to any future file that starts
from this pattern, rather than reworking its whole structure.

`tests/FrameworkCurrency.Tests.ps1` parses all three shapes: it looks for a Source URL, a
`Framework version` field or line, a parseable extraction date, and a `Verification method`
field, section, or line, in any of the arrangements above. It does not care which shape a file
uses — it cares that all four pieces of information are actually present.

After the header, the body is free-form Markdown. `smart-question-set.md` is the fullest
template: a short "What is this framework" section, a longer "Verification method" section that
states exactly what was read and what could not be (SMART's own question text is not published —
the file says so rather than inventing it), and then the enumeration itself as one or more
tables.

## The ID-scheme convention

Every enumerated item gets a stable, citable identifier of the shape `<PREFIX>-<SECTION><N>`,
e.g. `SMART-A1`, `SMART-C6`. The prefix matches the `framework:` value used in the corresponding
rule YAML file (`SMART`, `CAF`, `WAF`, and so on). These IDs are **Scout's own**, not Microsoft's
— state that explicitly in the file if Microsoft does not publish numbered items of its own (CAF
recommendations and SMART questions are both examples). A rule file must cite the enumeration
file's ID in every rule's `remediation` text, so a reader can go from a failed rule straight back
to the sentence in Microsoft's docs it is checking.

## No coverage percentage without a named version

**Every coverage percentage Scout emits must name the framework version it was measured
against.** In the assessment engine this is carried as the `frameworkversion` key at the top of
each rule YAML file (`src/assess/rules/*.yaml`), next to `framework:` and `area:`. It flows
through unchanged:

- `src/assess/engine/Get-RuleSet.ps1` reads `frameworkversion` off the YAML document and
  **refuses to load any rule file that declares rules but no version** — a load-time, fail-fast
  error, not a silent gap.
- `src/assess/Invoke-Assessment.ps1` stamps every finding it emits with the rule set's
  `FrameworkVersion`.
- `src/assess/engine/Get-Score.ps1` carries that version onto both the per-area and the
  per-framework roll-up (`Areas[].Version`, `Frameworks[].Version`) so any renderer consuming
  `Get-Score`'s output has the version sitting next to the score it belongs to, not somewhere
  else the reader has to go find.

For CAF and WAF, which Microsoft does not version, the `frameworkversion` string names the
extraction/verification date instead — consistent with the header block above. For a versioned
regulatory initiative (CIS, ISO, PCI, NIST — none exist as rule files yet), `frameworkversion`
must name the actual initiative version (e.g. `CIS Azure Foundations v3.0.0`), not just a date,
because the same initiative name legitimately means a different policy count release to release.

`tests/FrameworkCurrency.Tests.ps1` is the gate: it asserts every loaded rule set carries a
version, and proves the assertion is not vacuous by constructing a rule file with no
`frameworkversion` and watching `Get-RuleSet` reject it.

## Recheck cadence and procedure

**Cadence: every 90 days**, or immediately whenever a rule file that depends on an enumeration is
touched. Ninety days matches the pace the audit actually observed — Microsoft rewriting CAF
pages and shipping new CIS/NIST initiative versions is not an annual event — while staying loose
enough that a quarterly documentation pass, not a CI job, can carry it. `pmo/audits/AZURE-SCOUT-AUDIT.md`
§8 is the log of what a full recheck has found before; keep adding to it rather than starting a
parallel record.

**Procedure**, per enumeration file:

1. Re-open every URL in the file's `Source` field. Note anything that redirects, is marked
   archived, or has visibly changed structure (a missing "Design recommendations" heading, a
   renamed section, a retired taxonomy) — these are exactly the audit's §8 findings.
2. Re-count the enumerated items. If the count changed, update both the enumeration table and
   every rule file's `remediation` text that cites an ID whose meaning shifted.
3. Update the header block's `Extracted` date to today and, if anything in step 1 changed the
   substance of what was read, update `Verification method` to say so.
4. If the framework is a versioned regulatory initiative, confirm the initiative version named in
   `frameworkversion` is still current, and if Microsoft has shipped a newer version, decide
   explicitly whether Scout moves to it or keeps scoring the old one on purpose — do not let the
   version string go stale by default.
5. Re-run `tests/FrameworkCurrency.Tests.ps1`. It will fail the file's age check once it is
   sufficiently overdue (see the test file for the exact grace period and the reasoning for it)
   as a backstop for step 3 being skipped, not as the primary trigger for doing a recheck.

## Files in this directory

| File | Framework | Enumerates |
|---|---|---|
| `smart-question-set.md` | SMART | The published CAF Migrate content SMART assesses readiness against — the reference implementation of this standard |
| `waf-pillar-checklists.md` | WAF | All five WAF pillar design-review checklists, 59 items total, Microsoft's own item codes (`RE:01` etc.) |
| `caf-landing-zone-design-areas.md` | CAF | All eight CAF landing-zone design areas (393 items total); Network topology and connectivity (135 items, 11 of ~14 pages) still has ~3-4 unfetched child pages recorded as a residual gap |

Add a row here whenever a new enumeration file lands.
