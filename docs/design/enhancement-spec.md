---
description: The original AzureScout Enhancement Specification as provided by the project owner — verbatim source of record for the CAF/WAF assessment platform work (Epics AB#5023 and AB#5056).
---

<!--
Recovered verbatim from the owner's pasted specification.
Original accompanying instruction:
"I need you to take this. Create a plan that will update n or create any user item that needs to be created to track each new feature and request in detail.  Follow the MCP standard for ado structure.  Move all git hub items to as well to ado.  Please bea aware of the standards and how GitHub and ado are linked."
-->

# AzureScout Enhancement Specification

**A complete build spec for extending AzureScout from an inventory tool into a CAF/WAF landing-zone assessment platform with a modern reporting engine.**

This document is self-contained: architecture, the module system, the rule/scoring engine, working PowerShell, AzGovViz + PSRule + Advisor integration, and the tiered reporting overhaul. Code blocks are written to be pasted directly into the repo.

---

## 0. Design Goals

1. **Keep collection as-is.** AzureScout already has 170+ ARM modules, 15 Entra modules, cost/security/policy pulls, draw.io diagrams, five auth methods, and a permission pre-flight. Do not rebuild any of it.
2. **Add an assessment layer.** A declarative rule engine that grades collected data against CAF design areas and WAF pillars, producing scored findings and a prioritized gap list.
3. **Run modularly.** One switch to run a single assessment, several, or all.
4. **Rebuild reporting.** Replace Excel-first output with a tiered renderer: Power BI (primary), interactive HTML (governance-style or React), and an auto-generated executive deck. Keep Excel/JSON as evidence tiers.
5. **Read-only throughout.** Reader RBAC + read-only Graph. Nothing the tool does mutates the tenant.

---

## 1. Target Architecture — Three Layers

```
+-------------------+     collect.json     +-------------------+   findings.json   +-------------------+
|   COLLECT layer   | ----------------->   |   ASSESS layer    | --------------->  |   REPORT layer    |
| (exists, extend)  |                      |     (new)         |                   |   (rebuild)       |
| ARM + Entra + cost|                      | rule engine +     |                   | Power BI / HTML / |
| + AzGovViz + ARG  |                      | scoring + bench   |                   | PPTX / Excel/JSON |
+-------------------+                      +-------------------+                   +-------------------+
```

The contract between layers is **JSON on disk**. That is the whole trick that enables "run one / some / all" and swapping reporting without touching collection:

- Run collection alone → get `collect.json`.
- Run assessment against an existing `collect.json` → get `findings.json` (no re-scan needed).
- Run any reporter against `findings.json` → get the deliverable.

### 1.1 Repository layout to add

```
/src
  /collect            # existing AzureScout modules (unchanged)
  /assess             # NEW
    Invoke-Assessment.ps1
    /engine
      Get-RuleSet.ps1
      Invoke-Rule.ps1
      Get-Score.ps1
      Resolve-JsonPath.ps1
    /rules
      caf.identity.yaml
      caf.network.yaml
      caf.governance.yaml
      caf.management.yaml
      caf.security.yaml
      caf.resourceorg.yaml
      caf.platformauto.yaml
      caf.billing.yaml
      waf.reliability.yaml
      waf.security.yaml
      waf.cost.yaml
      waf.operational.yaml
      waf.performance.yaml
    /benchmarks
      alz-reference.json
  /report             # NEW (replaces current reporting)
    Export-Report.ps1
    /renderers
      Export-PowerBi.ps1
      Export-Html.ps1
      Export-Pptx.ps1
      Export-Excel.ps1     # retained evidence tier
    /templates
      report.pbit
      report.html.template
      deck.pptx.template
  /ingest             # NEW — third-party collectors normalized into collect.json
    Import-AzGovViz.ps1
    Invoke-ArgQueryPack.ps1
    Import-AdvisorScores.ps1
/manifests
  assessments.psd1     # module registry
/config
  scout.config.json
```

---

## 2. Module Registry & Execution Model

### 2.1 The manifest (`/manifests/assessments.psd1`)

Each assessment maps to the collect categories it needs, the rule files it runs, and the reporters it emits. Adding an assessment = adding an entry here plus a rule file. No core code change.

```powershell
@{
    LandingZone = @{
        Description   = 'CAF/WAF landing zone audit'
        Collect       = @('Networking','ManagementGovernance','Security','Identity','Monitor')
        Ingest        = @('AzGovViz','ArgQueryPack','AdvisorScores')
        Rules         = @('caf.*','waf.*')
        Benchmark     = 'alz-reference.json'
        Reporters     = @('PowerBi','Html','Pptx')
    }
    Identity = @{
        Description   = 'Identity, security & governance review'
        Collect       = @('Identity','Security')
        Ingest        = @('AzGovViz')
        Rules         = @('caf.identity','caf.security','caf.governance')
        Reporters     = @('Html','Excel')
    }
    Estate = @{
        Description   = 'Full digital estate inventory'
        Collect       = @('*')
        Ingest        = @()
        Rules         = @()          # pure inventory, no scoring
        Reporters     = @('Excel','PowerBi')
    }
    Cost = @{
        Description   = 'Cost / TCO data pull'
        Collect       = @('Cost','Compute','Storage')
        Ingest        = @('AdvisorScores','ArgQueryPack')
        Rules         = @('waf.cost')
        Reporters     = @('Excel','PowerBi')
    }
}
```

### 2.2 Top-level entry point

```powershell
function Invoke-AzureScout {
    [CmdletBinding()]
    param(
        [string[]] $Assessment = @('Estate'),   # one, many, or 'All'
        [ValidateSet('All','ArmOnly','EntraOnly')]
        [string]   $Scope = 'All',
        [string[]] $Category,                    # existing category filter still works
        [ValidateSet('PowerBi','Html','Pptx','Excel','Json','All')]
        [string[]] $OutputFormat = @('Html'),
        [string]   $OutputPath = './output',
        [switch]   $PermissionAudit,
        [switch]   $CollectOnly,                 # stop after collect.json
        [string]   $FromCollect,                 # skip collect, assess an existing collect.json
        [string]   $ManagementGroupId
    )

    $runId   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runPath = Join-Path $OutputPath $runId
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null

    $manifest = Import-PowerShellDataFile "$PSScriptRoot/../manifests/assessments.psd1"
    if ($Assessment -contains 'All') { $Assessment = $manifest.Keys }

    if ($PermissionAudit) { return Test-ScoutPermission -Assessment $Assessment -Manifest $manifest }

    # ---- COLLECT ----
    if ($FromCollect) {
        $collect = Get-Content $FromCollect -Raw | ConvertFrom-Json -Depth 100
    } else {
        $categories = $Assessment | ForEach-Object { $manifest[$_].Collect } | Select-Object -Unique
        if ($Category) { $categories = $Category }
        $collect = Invoke-Collect -Categories $categories -Scope $Scope -ManagementGroupId $ManagementGroupId

        # ingest third-party collectors declared by the chosen assessments
        $ingestors = $Assessment | ForEach-Object { $manifest[$_].Ingest } | Select-Object -Unique
        foreach ($i in $ingestors) {
            switch ($i) {
                'AzGovViz'      { $collect = Import-AzGovViz     -Collect $collect -OutputPath $runPath -ManagementGroupId $ManagementGroupId }
                'ArgQueryPack'  { $collect = Invoke-ArgQueryPack -Collect $collect }
                'AdvisorScores' { $collect = Import-AdvisorScores -Collect $collect }
            }
        }
        $collect | ConvertTo-Json -Depth 100 | Out-File "$runPath/collect.json"
    }
    if ($CollectOnly) { return "$runPath/collect.json" }

    # ---- ASSESS ----
    $allFindings = @()
    foreach ($name in $Assessment) {
        $spec = $manifest[$name]
        if (-not $spec.Rules) { continue }        # inventory-only assessment
        $ruleSet   = Get-RuleSet -Patterns $spec.Rules
        $benchmark = if ($spec.Benchmark) { Get-Content "$PSScriptRoot/benchmarks/$($spec.Benchmark)" -Raw | ConvertFrom-Json -Depth 100 } else { $null }
        $findings  = Invoke-Assessment -Collect $collect -RuleSet $ruleSet -Benchmark $benchmark -Assessment $name
        $allFindings += $findings
    }
    $scored = Get-Score -Findings $allFindings
    $scored | ConvertTo-Json -Depth 100 | Out-File "$runPath/findings.json"

    # ---- REPORT ----
    $reporters = if ($OutputFormat -contains 'All') { @('PowerBi','Html','Pptx','Excel','Json') } else { $OutputFormat }
    foreach ($r in $reporters) {
        Export-Report -Renderer $r -Findings $scored -Collect $collect -OutputPath $runPath
    }
    return $runPath
}
```

### 2.3 Usage examples

```powershell
# Landing zone audit only, HTML + deck
Invoke-AzureScout -Assessment LandingZone -OutputFormat Html,Pptx

# Two assessments at once
Invoke-AzureScout -Assessment LandingZone,Identity

# Everything, every format
Invoke-AzureScout -Assessment All -OutputFormat All

# Collect once, assess later (no re-scan)
Invoke-AzureScout -Assessment LandingZone -CollectOnly
Invoke-AzureScout -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi

# Pre-flight permission check
Invoke-AzureScout -Assessment All -PermissionAudit
```

---

## 3. The Assessment Engine

### 3.1 Rule file format (YAML)

One rule = one CAF/WAF checklist point. Declarative, version-controlled, editable without touching code. `query` is a JSONPath into `collect.json`; `assert` defines pass/fail.

```yaml
# /src/assess/rules/caf.network.yaml
area: "Network topology & connectivity"
framework: CAF
weight: 1.0
rules:
  - id: CAF-NET-01
    title: "Hub-spoke or vWAN topology present"
    severity: high
    query: "$.networking.virtualNetworks[?(@.properties.peerings.length > 0)]"
    assert: { type: countGreaterThan, value: 0 }
    remediation: "Establish a hub-spoke or Virtual WAN topology per the CAF network design area."
    manual: false

  - id: CAF-NET-02
    title: "Azure Firewall or NVA present in hub"
    severity: high
    query: "$.networking.azureFirewalls[*]"
    assert: { type: countGreaterThan, value: 0 }
    remediation: "Deploy Azure Firewall (or an NVA) in the hub for centralized egress control."
    manual: false

  - id: CAF-NET-03
    title: "No subnet exceeds IP utilization threshold"
    severity: medium
    query: "$.networking.subnets[?(@.ipUtilizationPct > 90)]"
    assert: { type: countEquals, value: 0 }
    remediation: "Re-address or split subnets exceeding 90% IP utilization."
    manual: false

  - id: CAF-NET-04
    title: "DDoS protection plan present on internet-facing VNets"
    severity: medium
    query: "$.networking.virtualNetworks[?(@.properties.enableDdosProtection == true)]"
    assert: { type: countGreaterThan, value: 0 }
    remediation: "Enable Azure DDoS Network Protection on internet-facing virtual networks."
    manual: false
```

```yaml
# /src/assess/rules/waf.reliability.yaml
area: "Reliability"
framework: WAF
weight: 1.0
rules:
  - id: WAF-RE-05
    title: "Zone-redundant deployment where supported"
    severity: high
    query: "$.compute.virtualMachines[?(@.zones == null || @.zones.length == 0)]"
    assert: { type: countEquals, value: 0 }
    remediation: "Deploy across availability zones for workloads requiring high availability."
    manual: false

  - id: WAF-RE-09
    title: "Backup configured (Recovery Services vault items present)"
    severity: high
    query: "$.management.recoveryVaults[*].backupItems[*]"
    assert: { type: countGreaterThan, value: 0 }
    remediation: "Configure Azure Backup for stateful workloads."
    manual: false

  - id: WAF-RE-03
    title: "Failure-mode analysis performed"
    severity: medium
    query: null
    assert: { type: manual }
    remediation: "Confirm FMA has been performed and documented for critical flows."
    manual: true          # surfaces as a questionnaire prompt, pre-filled with any evidence found
```

**Supported `assert` types** (implement in `Invoke-Rule.ps1`):

| Type | Meaning |
|------|---------|
| `countGreaterThan` | JSONPath match count > value → Pass |
| `countEquals` | match count == value → Pass |
| `countLessThan` | match count < value → Pass |
| `exists` | at least one match → Pass |
| `notExists` | zero matches → Pass |
| `percentageAtLeast` | (matching / total of `denominatorQuery`) ≥ value |
| `manual` | not machine-evaluable → status = Manual, emit prompt |

### 3.2 Rule loader (`Get-RuleSet.ps1`)

```powershell
function Get-RuleSet {
    param([string[]] $Patterns)
    # requires: Install-Module powershell-yaml
    Import-Module powershell-yaml -ErrorAction Stop
    $ruleDir = "$PSScriptRoot/../rules"
    $files = Get-ChildItem $ruleDir -Filter *.yaml | Where-Object {
        $f = $_.BaseName
        $Patterns | Where-Object { $f -like $_ }
    }
    $sets = foreach ($file in $files) {
        $doc = ConvertFrom-Yaml (Get-Content $file.FullName -Raw)
        [pscustomobject]@{
            Area      = $doc.area
            Framework = $doc.framework
            Weight    = [double]($doc.weight ?? 1.0)
            Rules     = $doc.rules
        }
    }
    return $sets
}
```

### 3.3 JSONPath resolver (`Resolve-JsonPath.ps1`)

A thin wrapper so rules stay declarative. Uses the Newtonsoft JSONPath engine that ships with PowerShell 7.

```powershell
function Resolve-JsonPath {
    param(
        [Parameter(Mandatory)] $InputObject,
        [Parameter(Mandatory)] [string] $Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return @() }
    $json  = $InputObject | ConvertTo-Json -Depth 100
    $token = [Newtonsoft.Json.Linq.JToken]::Parse($json)
    try {
        $results = $token.SelectTokens($Path)
        return @($results)
    } catch {
        Write-Warning "JSONPath '$Path' failed: $_"
        return @()
    }
}
```

### 3.4 Rule evaluator (`Invoke-Rule.ps1`)

```powershell
function Invoke-Rule {
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] $Collect,
        [string] $Area,
        [string] $Framework
    )

    $status = 'Unknown'; $evidenceCount = 0; $evidence = @()

    if ($Rule.manual -or $Rule.assert.type -eq 'manual') {
        # pre-fill with any evidence the scan DID find, then hand to the human
        if ($Rule.query) { $evidence = Resolve-JsonPath -InputObject $Collect -Path $Rule.query; $evidenceCount = $evidence.Count }
        $status = 'Manual'
    }
    else {
        $matches = Resolve-JsonPath -InputObject $Collect -Path $Rule.query
        $evidenceCount = $matches.Count
        $evidence = $matches | Select-Object -First 25    # cap evidence payload
        $v = $Rule.assert.value

        switch ($Rule.assert.type) {
            'countGreaterThan'  { $status = ($evidenceCount -gt  $v) ? 'Pass' : 'Fail' }
            'countEquals'       { $status = ($evidenceCount -eq  $v) ? 'Pass' : 'Fail' }
            'countLessThan'     { $status = ($evidenceCount -lt  $v) ? 'Pass' : 'Fail' }
            'exists'            { $status = ($evidenceCount -gt   0) ? 'Pass' : 'Fail' }
            'notExists'         { $status = ($evidenceCount -eq   0) ? 'Pass' : 'Fail' }
            'percentageAtLeast' {
                $denom = (Resolve-JsonPath -InputObject $Collect -Path $Rule.assert.denominatorQuery).Count
                $pct   = if ($denom -gt 0) { $evidenceCount / $denom * 100 } else { 0 }
                $status = ($pct -ge $v) ? 'Pass' : (($pct -gt 0) ? 'Partial' : 'Fail')
            }
            default { $status = 'Unknown' }
        }
    }

    [pscustomobject]@{
        Id            = $Rule.id
        Title         = $Rule.title
        Framework     = $Framework
        Area          = $Area
        Severity      = $Rule.severity
        Status        = $status
        EvidenceCount = $evidenceCount
        Evidence      = $evidence
        Remediation   = $Rule.remediation
        Manual        = [bool]$Rule.manual
    }
}
```

### 3.5 Assessment runner (`Invoke-Assessment.ps1`)

```powershell
function Invoke-Assessment {
    param($Collect, $RuleSet, $Benchmark, [string] $Assessment)
    $findings = foreach ($set in $RuleSet) {
        foreach ($rule in $set.Rules) {
            $f = Invoke-Rule -Rule $rule -Collect $Collect -Area $set.Area -Framework $set.Framework
            $f | Add-Member -NotePropertyName Assessment -NotePropertyValue $Assessment -PassThru |
                 Add-Member -NotePropertyName AreaWeight -NotePropertyValue $set.Weight -PassThru
        }
    }
    if ($Benchmark) { $findings += Compare-Benchmark -Collect $Collect -Benchmark $Benchmark }
    return $findings
}
```

### 3.6 Scoring (`Get-Score.ps1`)

```powershell
function Get-Score {
    param($Findings)

    $statusWeight = @{ Pass = 1.0; Partial = 0.5; Fail = 0.0 }   # Manual/NA excluded from denominator

    $areas = $Findings | Group-Object Framework, Area | ForEach-Object {
        $scorable = $_.Group | Where-Object { $_.Status -in 'Pass','Partial','Fail' }
        $den = ($scorable | Measure-Object).Count
        $num = ($scorable | ForEach-Object { $statusWeight[$_.Status] } | Measure-Object -Sum).Sum
        [pscustomobject]@{
            Framework   = $_.Group[0].Framework
            Area        = $_.Group[0].Area
            Score       = if ($den -gt 0) { [math]::Round($num / $den * 100) } else { $null }
            Pass        = ($_.Group | Where-Object Status -eq 'Pass').Count
            Partial     = ($_.Group | Where-Object Status -eq 'Partial').Count
            Fail        = ($_.Group | Where-Object Status -eq 'Fail').Count
            Manual      = ($_.Group | Where-Object Status -eq 'Manual').Count
        }
    }

    $frameworks = $areas | Where-Object { $_.Score -ne $null } | Group-Object Framework | ForEach-Object {
        [pscustomobject]@{
            Framework = $_.Name
            Score     = [math]::Round(($_.Group.Score | Measure-Object -Average).Average)
        }
    }

    # prioritized gap list: fails first, weighted by severity
    $sevRank = @{ high = 0; medium = 1; low = 2 }
    $gaps = $Findings | Where-Object Status -eq 'Fail' |
        Sort-Object @{ E = { $sevRank[$_.Severity] } }, Area |
        Select-Object Id, Framework, Area, Severity, Title, Remediation

    [pscustomobject]@{
        GeneratedOn = (Get-Date).ToString('o')
        Frameworks  = $frameworks
        Areas       = $areas
        Gaps        = $gaps
        Manual      = ($Findings | Where-Object Status -eq 'Manual')
        Findings    = $Findings
    }
}
```

---

## 4. Ingest Layer — Feeding External Collectors into `collect.json`

The assessment engine only reads `collect.json`, so any external tool becomes usable by normalizing its output into that shape.

### 4.1 Governance Visualizer ingest (`Import-AzGovViz.ps1`)

The governance visualizer is a read-only PowerShell tool (Reader at MG root + read-only Graph app permissions: `User.Read.All`, `Group.Read.All`, `Application.Read.All`, `PrivilegedAccess.Read.AzureResources`). It exports JSON covering policy definitions/assignments, RBAC, PIM eligibility, the MG hierarchy, and an ALZ policy checker. Run it, then fold its JSON into the collect object.

```powershell
function Import-AzGovViz {
    param($Collect, [string] $OutputPath, [string] $ManagementGroupId)

    $govPath = Join-Path $OutputPath 'govviz'
    New-Item -ItemType Directory -Path $govPath -Force | Out-Null

    # Clone/run the visualizer (pin a version in real use). Read-only.
    if (-not (Test-Path "$govPath/AzGovVizParallel.ps1")) {
        git clone --depth 1 https://github.com/Azure/Azure-Governance-Visualizer.git "$govPath/repo" 2>$null
    }
    & "$govPath/repo/pwsh/AzGovVizParallel.ps1" `
        -ManagementGroupId $ManagementGroupId `
        -OutputPath        $govPath `
        -DoPSRule `                       # WAF-aligned PSRule results
        -NoScopeInsights `                # we only need the JSON, not the big HTML
        -ALZPolicyAssignmentsChecker      # CAF landing-zone policy gap data

    # Fold selected JSON exports into the collect object under a 'governance' key
    $jsonDir = Get-ChildItem "$govPath" -Directory -Filter 'JSON_*' | Select-Object -First 1
    if ($jsonDir) {
        $Collect | Add-Member -NotePropertyName governance -NotePropertyValue ([pscustomobject]@{
            policyAssignments = (Get-ChildItem "$($jsonDir.FullName)" -Recurse -Filter '*PolicyAssignments*.json' | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100 })
            roleAssignments   = (Get-ChildItem "$($jsonDir.FullName)" -Recurse -Filter '*RoleAssignments*.json'   | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100 })
            alzPolicyChecker  = (Get-ChildItem "$govPath" -Recurse -Filter '*ALZPolicyVersionChecker.csv' | Select-Object -First 1 | ForEach-Object { Import-Csv $_.FullName })
        }) -Force
    }
    return $Collect
}
```

Why include it: its policy/RBAC/PIM enrichment (DINE managed-identity resolution, ALZ policy version + assignment checkers) is deeper than raw inventory and directly satisfies several CAF governance and identity rules. Don't reimplement it — ingest it.

### 4.2 ARG query pack (`Invoke-ArgQueryPack.ps1`)

The queries that close the network/ops/cost gaps AzGovViz and basic inventory miss. All read-only KQL via `Search-AzGraph`.

```powershell
function Invoke-ArgQueryPack {
    param($Collect)
    Import-Module Az.ResourceGraph -ErrorAction Stop

    $queries = @{
        subnetIpUsage = @'
resources
| where type =~ "microsoft.network/virtualnetworks"
| mv-expand subnet = properties.subnets
| extend prefix = tostring(subnet.properties.addressPrefix)
| extend total = toint(exp2(32 - toint(split(prefix,"/")[1]))) - 5
| extend used  = array_length(subnet.properties.ipConfigurations)
| project vnet = name, subnet = tostring(subnet.name), prefix, total, used,
          ipUtilizationPct = round(todouble(used) / total * 100, 1)
'@
        orphanedDisks = @'
resources
| where type =~ "microsoft.compute/disks" and properties.diskState =~ "Unattached"
| project name, resourceGroup, location, sku = sku.name, sizeGb = properties.diskSizeGB
'@
        orphanedPips = @'
resources
| where type =~ "microsoft.network/publicipaddresses" and isnull(properties.ipConfiguration)
| project name, resourceGroup, location, sku = sku.name
'@
        diagCoverage = @'
resources
| extend hasDiag = iff(isnotnull(properties.diagnosticSettings), true, false)
| summarize total = count(), withDiag = countif(hasDiag) by type
| extend coveragePct = round(todouble(withDiag)/total*100,1)
'@
        publicExposure = @'
resources
| where type =~ "microsoft.network/networksecuritygroups"
| mv-expand rule = properties.securityRules
| where rule.properties.access =~ "Allow" and rule.properties.direction =~ "Inbound"
      and (rule.properties.sourceAddressPrefix in ("*","0.0.0.0/0","Internet"))
| project nsg = name, resourceGroup, rule = tostring(rule.name),
          port = tostring(rule.properties.destinationPortRange)
'@
        nonZonalVms = @'
resources
| where type =~ "microsoft.compute/virtualmachines"
| extend zones = properties.zones
| where isnull(zones) or array_length(zones) == 0
| project name, resourceGroup, location, size = properties.hardwareProfile.vmSize
'@
    }

    $arg = [ordered]@{}
    foreach ($k in $queries.Keys) {
        $rows = @(); $skip = 0
        do {
            $batch = Search-AzGraph -Query $queries[$k] -First 1000 -Skip $skip
            $rows += $batch; $skip += 1000
        } while ($batch.Count -eq 1000)
        $arg[$k] = $rows
    }

    # normalize into the shapes the rules expect
    $Collect | Add-Member -NotePropertyName networking -NotePropertyValue ([pscustomobject]@{
        subnets           = $arg.subnetIpUsage
        nsgPublicInbound  = $arg.publicExposure
    }) -Force
    $Collect | Add-Member -NotePropertyName costCleanup -NotePropertyValue ([pscustomobject]@{
        orphanedDisks = $arg.orphanedDisks
        orphanedPips  = $arg.orphanedPips
    }) -Force
    $Collect | Add-Member -NotePropertyName opsPosture -NotePropertyValue ([pscustomobject]@{
        diagnosticCoverage = $arg.diagCoverage
    }) -Force
    return $Collect
}
```

### 4.3 Advisor scores (`Import-AdvisorScores.ps1`)

Advisor is the one automated WAF signal Microsoft exposes. Pull it per category to auto-satisfy WAF "Automated" rules.

```powershell
function Import-AdvisorScores {
    param($Collect)
    $subs = (Get-AzSubscription | Where-Object State -eq 'Enabled')
    $recs = foreach ($s in $subs) {
        Set-AzContext -SubscriptionId $s.Id | Out-Null
        Get-AzAdvisorRecommendation | Select-Object Category, Impact, ImpactedField, ImpactedValue,
            @{n='Subscription';e={$s.Name}}, ShortDescriptionProblem, ShortDescriptionSolution
    }
    $Collect | Add-Member -NotePropertyName advisor -NotePropertyValue (@($recs)) -Force
    return $Collect
}
```

---

## 5. Benchmark Layer — Diff Against the ALZ Reference

"Audit" means compare-to-standard. Ship a reference of the canonical landing-zone design and diff the live tenant against it.

### 5.1 Reference file (`/src/assess/benchmarks/alz-reference.json`)

```json
{
  "managementGroups": {
    "expected": ["platform","connectivity","identity","management","landingzones","corp","online","sandbox","decommissioned"],
    "note": "Intermediate root + canonical ALZ archetypes"
  },
  "requiredPolicyAssignments": [
    "Deny-Public-IP",
    "Deploy-Diagnostics-LogAnalytics",
    "Deny-Subnet-Without-Nsg",
    "Deploy-VM-Backup",
    "Audit-ResourceLocks"
  ],
  "network": { "requireHubSpoke": true, "requireFirewallInHub": true, "requireDdosOnInternetVnets": true }
}
```

### 5.2 Comparator (`Compare-Benchmark.ps1`)

```powershell
function Compare-Benchmark {
    param($Collect, $Benchmark)
    $findings = @()

    # MG structure
    $actualMgs = @($Collect.governance.managementGroups.name)
    foreach ($mg in $Benchmark.managementGroups.expected) {
        $present = $actualMgs -contains $mg
        $findings += [pscustomobject]@{
            Id = "BENCH-MG-$mg"; Title = "ALZ management group '$mg' present"
            Framework='CAF'; Area='Management group & subscription org'
            Severity='medium'; Status = ($present ? 'Pass':'Fail'); EvidenceCount=[int]$present
            Evidence=@(); Remediation="Create the '$mg' management group per ALZ archetype."; Manual=$false
        }
    }

    # required policy assignments (leverages the visualizer's ALZ checker if present)
    $assigned = @($Collect.governance.policyAssignments.properties.displayName)
    foreach ($p in $Benchmark.requiredPolicyAssignments) {
        $present = ($assigned -match $p).Count -gt 0
        $findings += [pscustomobject]@{
            Id="BENCH-POL-$p"; Title="Required ALZ policy '$p' assigned"
            Framework='CAF'; Area='Governance (policy & compliance)'
            Severity='high'; Status=($present ? 'Pass':'Fail'); EvidenceCount=[int]$present
            Evidence=@(); Remediation="Assign ALZ policy/initiative '$p'."; Manual=$false
        }
    }
    return $findings
}
```

---

## 6. Reporting Overhaul (Tiered)

All renderers read the same `findings.json`. Pick tiers by audience.

### 6.1 Dispatcher (`Export-Report.ps1`)

```powershell
function Export-Report {
    param([string] $Renderer, $Findings, $Collect, [string] $OutputPath)
    switch ($Renderer) {
        'PowerBi' { Export-PowerBi -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Html'    { Export-Html    -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Pptx'    { Export-Pptx    -Findings $Findings -OutputPath $OutputPath }
        'Excel'   { Export-Excel   -Findings $Findings -Collect $Collect -OutputPath $OutputPath }
        'Json'    { $Findings | ConvertTo-Json -Depth 100 | Out-File "$OutputPath/findings.json" }
    }
}
```

### 6.2 Tier 1 — Power BI (primary)

Emit flat CSVs shaped for a star schema, then bind a `.pbit` template to them. Power BI is the primary deliverable format and reuses any existing Fabric/Power BI capacity.

```powershell
function Export-PowerBi {
    param($Findings, $Collect, [string] $OutputPath)
    $pbiDir = Join-Path $OutputPath 'powerbi'; New-Item -ItemType Directory -Path $pbiDir -Force | Out-Null

    $Findings.Areas      | Export-Csv "$pbiDir/fact_area_scores.csv"  -NoTypeInformation
    $Findings.Frameworks | Export-Csv "$pbiDir/fact_framework.csv"    -NoTypeInformation
    $Findings.Gaps       | Export-Csv "$pbiDir/dim_gaps.csv"          -NoTypeInformation
    $Findings.Findings | Select-Object Id,Framework,Area,Severity,Status,EvidenceCount,Title,Remediation,Manual |
        Export-Csv "$pbiDir/fact_findings.csv" -NoTypeInformation

    Copy-Item "$PSScriptRoot/../templates/report.pbit" "$pbiDir/report.pbit"
    @"
Open report.pbit in Power BI Desktop.
When prompted for the 'DataFolder' parameter, point it at:
  $pbiDir
Refresh. The model binds to the CSVs above (star schema: fact_findings + dim_gaps + fact_area_scores).
"@ | Out-File "$pbiDir/README.txt"
}
```

Template design (build once in Power BI Desktop, save as `.pbit`):
- Parameter `DataFolder` (folder path) → all tables `= Csv.Document(File.Contents(DataFolder & "\..."))`.
- Page 1: framework score cards (CAF, WAF) + area score bar chart.
- Page 2: gap table sliced by severity/area, with remediation column.
- Page 3: manual-items worklist (the questionnaire remainder).
- Because it re-imports on refresh, re-running the scan and refreshing gives trend/drift for free.

### 6.3 Tier 2 — Interactive HTML (self-contained)

Single-file HTML with embedded JSON — no server, works offline, matches the governance-visualizer style your audience already sees. Optionally swap the body for a bundled React app for richer interactivity.

```powershell
function Export-Html {
    param($Findings, $Collect, [string] $OutputPath)
    $json = ($Findings | ConvertTo-Json -Depth 100) -replace '</','<\/'
    $tpl  = Get-Content "$PSScriptRoot/../templates/report.html.template" -Raw
    $tpl.Replace('/*__DATA__*/', "window.__FINDINGS__ = $json;") |
        Out-File "$OutputPath/report.html" -Encoding utf8
}
```

`report.html.template` (vanilla JS; drop-in, no build step):

```html
<!doctype html><html><head><meta charset="utf-8"><title>Landing Zone Assessment</title>
<style>
 body{font:14px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;margin:0;color:#1a1a1a}
 header{background:#1F4E78;color:#fff;padding:20px 28px}
 .cards{display:flex;gap:16px;padding:20px 28px;flex-wrap:wrap}
 .card{border:1px solid #e2e2e2;border-radius:10px;padding:18px 22px;min-width:150px}
 .score{font-size:34px;font-weight:700}
 .pass{color:#2E7D32}.partial{color:#B8860B}.fail{color:#B00020}.manual{color:#555}
 table{border-collapse:collapse;width:calc(100% - 56px);margin:0 28px 28px}
 th,td{border:1px solid #e2e2e2;padding:8px 10px;text-align:left;vertical-align:top}
 th{background:#1F4E78;color:#fff;cursor:pointer}
 tr:nth-child(even){background:#f6f9fd}
 input{margin:0 28px 12px;padding:8px 10px;width:calc(100% - 56px);border:1px solid #ccc;border-radius:6px}
 .tabs{display:flex;gap:8px;padding:0 28px}.tab{padding:8px 14px;cursor:pointer;border-bottom:3px solid transparent}
 .tab.active{border-color:#2E75B6;font-weight:600}
</style></head><body>
<header><h1>Azure Landing Zone Assessment</h1><div id="ts"></div></header>
<div class="tabs">
  <div class="tab active" data-t="scores">Scores</div>
  <div class="tab" data-t="gaps">Gaps</div>
  <div class="tab" data-t="manual">Manual review</div>
  <div class="tab" data-t="all">All findings</div>
</div>
<div id="view"></div>
<script>/*__DATA__*/</script>
<script>
const D = window.__FINDINGS__;
document.getElementById('ts').textContent = 'Generated ' + new Date(D.GeneratedOn).toLocaleString();
const V = document.getElementById('view');
const esc = s => (s??'').toString().replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function scores(){
  const fw = D.Frameworks.map(f=>`<div class="card"><div>${f.Framework}</div><div class="score">${f.Score}</div></div>`).join('');
  const rows = D.Areas.map(a=>`<tr><td>${a.Framework}</td><td>${esc(a.Area)}</td>
    <td class="${a.Score>=80?'pass':a.Score>=50?'partial':'fail'}">${a.Score??'—'}</td>
    <td class="pass">${a.Pass}</td><td class="fail">${a.Fail}</td><td class="manual">${a.Manual}</td></tr>`).join('');
  V.innerHTML = `<div class="cards">${fw}</div>
   <table><tr><th>Framework</th><th>Area</th><th>Score</th><th>Pass</th><th>Fail</th><th>Manual</th></tr>${rows}</table>`;
}
function gaps(){
  V.innerHTML = `<input id="q" placeholder="Filter gaps...">
   <table id="gt"><tr><th>Severity</th><th>Area</th><th>Finding</th><th>Remediation</th></tr>
   ${D.Gaps.map(g=>`<tr><td class="${g.Severity==='high'?'fail':g.Severity==='medium'?'partial':''}">${g.Severity}</td>
     <td>${esc(g.Area)}</td><td>${esc(g.Title)}</td><td>${esc(g.Remediation)}</td></tr>`).join('')}</table>`;
  document.getElementById('q').oninput = e=>{const v=e.target.value.toLowerCase();
    [...document.querySelectorAll('#gt tr')].slice(1).forEach(r=>r.style.display=r.innerText.toLowerCase().includes(v)?'':'none');};
}
function manual(){
  V.innerHTML = `<table><tr><th>Area</th><th>Question</th><th>Evidence found</th><th>Guidance</th></tr>
   ${D.Manual.map(m=>`<tr><td>${esc(m.Area)}</td><td>${esc(m.Title)}</td>
     <td>${m.EvidenceCount} item(s)</td><td>${esc(m.Remediation)}</td></tr>`).join('')}</table>`;
}
function all(){
  V.innerHTML = `<table><tr><th>Id</th><th>Area</th><th>Status</th><th>Sev</th><th>Finding</th></tr>
   ${D.Findings.map(f=>`<tr><td>${f.Id}</td><td>${esc(f.Area)}</td>
     <td class="${f.Status.toLowerCase()}">${f.Status}</td><td>${f.Severity??''}</td><td>${esc(f.Title)}</td></tr>`).join('')}</table>`;
}
const R={scores,gaps,manual,all};
document.querySelectorAll('.tab').forEach(t=>t.onclick=()=>{
  document.querySelectorAll('.tab').forEach(x=>x.classList.remove('active'));
  t.classList.add('active'); R[t.dataset.t]();});
scores();
</script></body></html>
```

For the **React variant**: keep the same `window.__FINDINGS__` injection, bundle a React app to a single JS file, and reference it in the template instead of the inline script. Same data contract, richer UI (sortable/filterable tables, drill-down, topology from the draw.io export). Start with the vanilla version above; graduate to React once the engine is stable.

### 6.4 Tier 3 — Executive deck (`Export-Pptx.ps1`)

Auto-assemble a PowerPoint from the scored JSON. Uses the PSWritePowerPoint-style COM/OpenXML approach or python-pptx via a shell-out; below uses the `PSWritePowerPoint`-free OpenXML route through the `PnP`/`DocumentFormat.OpenXml` assembly. Simplest portable option is python-pptx:

```powershell
function Export-Pptx {
    param($Findings, [string] $OutputPath)
    $data = $Findings | ConvertTo-Json -Depth 100
    $data | Out-File "$OutputPath/_deck_data.json" -Encoding utf8
    python "$PSScriptRoot/../templates/build_deck.py" "$OutputPath/_deck_data.json" "$OutputPath/assessment_deck.pptx"
}
```

`build_deck.py` (python-pptx; title, per-framework score slide, top-10 gaps, manual worklist):

```python
import sys, json
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

data = json.load(open(sys.argv[1])); out = sys.argv[2]
prs = Presentation()
NAVY = RGBColor(0x1F,0x4E,0x78)

def title_slide(t, s):
    sl = prs.slides.add_slide(prs.slide_layouts[0])
    sl.shapes.title.text = t
    sl.placeholders[1].text = s

def bullets(title, lines):
    sl = prs.slides.add_slide(prs.slide_layouts[1])
    sl.shapes.title.text = title
    tf = sl.placeholders[1].text_frame; tf.clear()
    for i,l in enumerate(lines):
        p = tf.paragraphs[0] if i==0 else tf.add_paragraph()
        p.text = l; p.font.size = Pt(16)

title_slide("Azure Landing Zone Assessment",
            "Current state vs. CAF / WAF — generated " + data["GeneratedOn"][:10])

bullets("Framework Scores",
        [f'{f["Framework"]}: {f["Score"]}/100' for f in data["Frameworks"]])

bullets("Area Scores",
        [f'{a["Framework"]} — {a["Area"]}: {a["Score"]}' for a in data["Areas"] if a["Score"] is not None])

top = data["Gaps"][:10]
bullets("Top 10 Prioritized Gaps",
        [f'[{g["Severity"].upper()}] {g["Area"]}: {g["Title"]}' for g in top])

bullets("Manual Review Items (questionnaire remainder)",
        [f'{m["Area"]}: {m["Title"]}' for m in data["Manual"][:12]])

prs.save(out)
```

### 6.5 Keep — Excel & JSON
- **Excel** stays as the raw evidence pack (one sheet per area, all findings). Good for auditors, not for executives.
- **JSON** is the machine contract; always emit it.
- **draw.io** topology (already produced by collection) is embedded/linked into HTML and the deck rather than left standalone.

---

## 7. Permission Pre-Flight (extend existing)

Before any run, verify the read-only access each selected assessment needs and emit remediation. Read-only throughout.

```powershell
function Test-ScoutPermission {
    param([string[]] $Assessment, $Manifest)
    $results = @()

    # ARM: Reader at MG root
    $ctx = Get-AzContext
    $mgReader = Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$($ctx.Tenant.Id)" `
                 -SignInName $ctx.Account.Id -ErrorAction SilentlyContinue |
                 Where-Object RoleDefinitionName -eq 'Reader'
    $results += [pscustomobject]@{ Check='ARM Reader @ MG root'; Ok=[bool]$mgReader
        Fix='Assign Reader at the tenant root management group scope.' }

    # Graph app permissions needed when ingesting the governance visualizer
    if ($Assessment | Where-Object { $Manifest[$_].Ingest -contains 'AzGovViz' }) {
        foreach ($p in 'User.Read.All','Group.Read.All','Application.Read.All','PrivilegedAccess.Read.AzureResources') {
            $results += [pscustomobject]@{ Check="Graph: $p"; Ok=$null
                Fix="Grant application permission $p with admin consent (or use Directory Readers)." }
        }
    }
    $results | Format-Table -AutoSize
    return $results
}
```

---

## 8. Pipeline (unattended, all-in-one)

```yaml
# azure-pipelines.yml — read-only, SPN via service connection
trigger: none
pool: { vmImage: 'ubuntu-latest' }
steps:
  - task: AzurePowerShell@5
    displayName: 'Run full assessment'
    inputs:
      azureSubscription: '<read-only-service-connection>'
      ScriptType: 'InlineScript'
      azurePowerShellVersion: 'LatestVersion'
      pwsh: true
      Inline: |
        Import-Module ./src/AzureScout.psd1
        Invoke-AzureScout `
          -Assessment All `
          -ManagementGroupId $env:MG_ID `
          -OutputFormat PowerBi,Html,Pptx,Json `
          -OutputPath $(Build.ArtifactStagingDirectory)
  - publish: $(Build.ArtifactStagingDirectory)
    artifact: assessment-output
```

---

## 9. Build Phases

**Phase 1 — Foundations.** Three-layer JSON contract; `-Assessment` switch + manifest registry; confirm cost/security modules pull Advisor + Policy compliance (add via §4.3 if missing).

**Phase 2 — Landing Zone module.** Encode CAF 8-area + WAF 5-pillar rule files (§3.1); rule engine + scoring (§3.2–3.6); governance-visualizer ingest (§4.1); ARG query pack (§4.2); ALZ benchmark diff (§5).

**Phase 3 — Reporting overhaul.** Power BI template + CSV emitters (§6.2); self-contained HTML (§6.3); PPTX generator (§6.4). Demote Excel to evidence tier.

**Phase 4 — Remaining modules.** Identity (IT/OT boundary rules, directory-source reconciliation inputs); Cost (RI/AHB/orphan/right-size → external TCO feed); app/wave modules scoped as data feeds to the migration tool, not reimplementations.

**Phase 5 — Polish.** React report variant; drift tracking (commit `findings.json` to Git, diff over runs); one-command pipeline producing all tiers into a dated folder.

---

## 10. Dependencies

| Component | Requirement |
|-----------|-------------|
| PowerShell | 7.0.3+ |
| Az modules | Az.Accounts, Az.Resources, Az.ResourceGraph, Az.Advisor, Az.Security |
| YAML | powershell-yaml (rule files) |
| Graph (ingest) | read-only app perms: User/Group/Application.Read.All, PrivilegedAccess.Read.AzureResources |
| PPTX | python3 + python-pptx |
| Power BI | Power BI Desktop (author .pbit once) |
| Diagrams | draw.io export (already in collection layer) |

---

## 11. Scope Discipline (what NOT to build)

- **No remediation / execution.** Assess and report only. Findings carry remediation guidance; the tool never mutates the tenant.
- **Don't reimplement the migration/ML tooling.** 6R classification, wave AI, and TCO modeling stay external; this platform feeds them normalized data.
- **The architect's judgment stays human.** Network design intent and CAF gap interpretation are review activities. The tool front-loads evidence and scores what is machine-verifiable; the `Manual` status exists precisely to hand the rest to a person with the evidence already attached.

---

## 12. Summary

Collection is already solved. This spec adds a declarative **assessment engine** (rules → scoring → prioritized gaps), an **ingest layer** that folds the governance visualizer, an ARG query pack, and Advisor into one normalized `collect.json`, a **benchmark diff** against the ALZ reference, and a **tiered reporting engine** led by Power BI with self-contained interactive HTML (vanilla now, React later) and an auto-generated executive deck. Everything is read-only, modular (run one/some/all), and driven by a JSON contract so any layer can run independently.
