# Azure Scout — assessment platform (`/src`)

This tree extends Azure Scout from an inventory tool into a CAF/WAF landing-zone
assessment platform. It implements the three-layer, JSON-on-disk architecture
tracked by ADO Epic **AB#5023**.

```
COLLECT  --collect.json-->  ASSESS  --findings.json-->  REPORT
(extend)                    (new)                       (rebuild)
```

The contract between layers is JSON on disk, so each layer runs independently:
collect once and assess later, or re-render reports from an existing findings set
without re-scanning. **Read-only throughout** (Reader RBAC + read-only Graph).

## Layout

| Path | Purpose | ADO |
|---|---|---|
| `Invoke-AzureScout.ps1` | Entry point / orchestrator | AB#5024 |
| `../manifests/assessments.psd1` | Module registry (run one/some/all) | AB#5025 |
| `assess/engine/` | Rule loader, JSONPath resolver, evaluator, scoring | AB#5027, AB#5034 |
| `assess/rules/*.yaml` | CAF 8-area + WAF 5-pillar rule files | AB#5031 |
| `assess/benchmarks/alz-reference.json` + `Compare-Benchmark.ps1` | ALZ benchmark diff | AB#5041 |
| `ingest/` | AzGovViz, ARG query pack, Advisor normalized into collect.json | AB#5037 |
| `report/` + `report/renderers/` + `report/templates/` | Power BI / HTML / PPTX / Excel / JSON | AB#5044 |
| `assess/Test-ScoutPermission.ps1` | Read-only permission pre-flight | AB#5050 |
| `../.ado/azure-pipelines.yml` | Unattended all-tiers pipeline | AB#5052 |

## Usage

```powershell
# Landing zone audit only, HTML + deck
Invoke-AzureScout -Assessment LandingZone -OutputFormat Html,Pptx

# Two assessments at once
Invoke-AzureScout -Assessment LandingZone,Identity

# Everything, every format
Invoke-AzureScout -Assessment All -OutputFormat All

# Collect once, assess later (no re-scan)
Invoke-AzureScout -Assessment LandingZone -CollectOnly
Invoke-AzureScout -Assessment LandingZone -FromCollect ./output/<run>/collect.json -OutputFormat PowerBi

# Pre-flight permission check
Invoke-AzureScout -Assessment All -PermissionAudit
```

## Dependencies

| Component | Requirement |
|---|---|
| PowerShell | 7.0.3+ |
| Az modules | Az.Accounts, Az.Resources, Az.ResourceGraph, Az.Advisor, Az.Security |
| YAML | powershell-yaml (rule files) |
| Excel tier | ImportExcel (optional; falls back to CSV) |
| PPTX | python3 + python-pptx |
| Power BI | Power BI Desktop (author the `.pbit` once) |

## Scope discipline

Assess and report only — the platform never mutates the tenant. Findings carry
remediation guidance; the `Manual` status hands non-machine-verifiable checks to
a human with any evidence already attached.
