#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Azure Scout assessment entry point — collect, assess, and report.

.DESCRIPTION
    The assessment-platform orchestrator (distinct from the inventory cmdlet
    Invoke-AzureScout). Orchestrates the three-layer JSON-on-disk contract:
        COLLECT  -> collect.json
        ASSESS   -> findings.json
        REPORT   -> deliverables

    Every layer runs independently from its JSON input, so you can collect once
    and assess later, or re-render reports from an existing findings set without
    re-scanning. Read-only throughout.

.EXAMPLE
    Invoke-AzureScout -Assessment LandingZone -OutputFormat Html,Pptx

.EXAMPLE
    Invoke-AzureScout -Assessment 'Assess: Management'   # governance/policy/update-manager, scored
    Invoke-AzureScout -Assessment 'Assess: Monitor' -OutputFormat Html

.EXAMPLE
    Invoke-AzureScout -Assessment LandingZone -CollectOnly
    Invoke-AzureScout -Assessment LandingZone -FromCollect ./output/20260720_101500/collect.json -OutputFormat PowerBi

.NOTES
    Tracks ADO Epic AB#5023 (Feature AB#5024, Story AB#5026) and Epic AB#5056.

    `-Scope`: the Collect layer is ARG/ARM only — there is no Entra/Graph
    collection path here, so 'EntraOnly' throws with a redirect to
    `Invoke-AzureScout -Scope EntraOnly` (the v1 inventory tool) rather than
    silently running a collect that can never gather anything. 'ArmOnly' and
    'All' are accepted and behave identically (both run the ARM collect) —
    kept for forward compatibility rather than removed.

    `-ManagementGroupId` now actually scopes the ARG collect (`Search-AzGraph
    -ManagementGroup`, threaded through `Invoke-Collect` and
    `Invoke-ArgQueryPack`), not just the AzGovViz ingest.

    `-Category` (or each assessment's manifest `Collect` list) now actually
    filters which Resource Graph queries `Invoke-Collect` runs, instead of
    always collecting the full ~25-query set.

    AB#405: reports coarse phase-level progress (collect, each ingestor, each
    assessment being scored, each report renderer) through `Write-ScoutProgress`
    (src/Write-ScoutProgress.ps1) when that function is loaded in the calling
    session. Every call is guarded with `Get-Command ... -ErrorAction
    SilentlyContinue`, so this is a soft dependency only -- a session that never
    loaded that helper runs exactly as it did before progress reporting existed.
#>
function Invoke-ScoutAssessmentCore {
    [CmdletBinding()]
    param(
        # AB#6795 -- 'Estate' (Rules = @(), a full-inventory pull with no scoring) was removed
        # from the assessment registry entirely; it is not this platform's job to double as the
        # inventory tool. 'LandingZone' is the existing pre-checked default everywhere else
        # (Get-ScoutAvailableAssessment, the wizard), so a bare -CollectOnly / -FromCollect call
        # with no explicit -Assessment now defaults to the same entry an interactive run would.
        [string[]] $Assessment = @('LandingZone'),   # one, many, or 'All'
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]   $Scope = 'All',              # EntraOnly throws -- ARM/ARG collect only, no Entra path here
        [string[]] $Category,                    # existing category filter still works
        [ValidateSet('PowerBi', 'Html', 'Pptx', 'Excel', 'Json', 'JsonEvidence', 'React', 'Pdf', 'Word', 'EChartsDashboard', 'All')]
        [string[]] $OutputFormat = @('Html'),
        [string]   $OutputPath = './output',
        [switch]   $PermissionAudit,
        [switch]   $CollectOnly,                 # stop after collect.json
        [string]   $FromCollect,                 # skip collect, assess an existing collect.json
        [string]   $ManagementGroupId,
        # AB#5543 — extraction data from an inventory pass that already ran in this invocation.
        # Passed through to Invoke-Collect so a combined run shapes the assessment scalars from
        # rows already in memory instead of querying Azure a second time.
        [object]   $FromInventory,
        # AB#6827 (Feature AB#6749) -- opt-in, same shape as Invoke-AzureScout's own switch. Only
        # threaded to Import-ScoutDevOpsCapability when a chosen assessment's `Ingest` list asks
        # for 'DevOpsCapability'; every other assessment pays nothing for it.
        [switch]   $IncludeDevOps,
        [string[]] $DevOpsOrganization,
        [string]   $DevOpsPat,
        [string]   $TenantID
    )

    # AB#6902: two runs started within the same second must not share a folder --
    # the second would overwrite the first's artefacts, and Get-ScoutDrift would
    # replace the prior history record (same RunId) instead of appending one.
    $runId   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runPath = Join-Path $OutputPath $runId
    $suffix  = 1
    while (Test-Path $runPath) {
        $runPath = Join-Path $OutputPath ('{0}_{1:d2}' -f $runId, $suffix)
        $suffix++
    }
    $runId = Split-Path $runPath -Leaf
    New-Item -ItemType Directory -Path $runPath -Force | Out-Null

    # AB#405: soft dependency -- every call below is skipped entirely when this
    # helper isn't loaded in the session, so the assessment core has zero hard
    # dependency on it.
    $scoutProgressAvailable = [bool](Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue)
    function Write-ScoutAssessmentProgress {
        param([string] $Status, [int] $PercentComplete = -1, [switch] $Completed)
        if (-not $scoutProgressAvailable) { return }
        try {
            $params = @{ Activity = 'Scout Assessment'; Id = 1 }
            if ($Completed) { $params.Completed = $true } else { $params.Status = $Status; $params.PercentComplete = $PercentComplete }
            Write-ScoutProgress @params
        }
        catch { Write-Verbose "Invoke-ScoutAssessmentCore: Write-ScoutProgress failed, continuing without progress UX: $_" }
    }

    $manifest = Import-PowerShellDataFile "$PSScriptRoot/../manifests/assessments.psd1"
    if ($Assessment -contains 'All') { $Assessment = @($manifest.Keys) }
    # AB#6762 -- fifteen entries were renamed with an `Assess: ` prefix to stop the wizard menu
    # colliding with the fifteen identically-named inventory categories. A scripted
    # `-Assessment Compute` predates that rename and must keep working, so the legacy name is
    # mapped here (with a warning naming the new value) before anything indexes the manifest.
    $Assessment = @(Resolve-ScoutAssessmentName -Name $Assessment -Manifest $manifest)

    if ($PermissionAudit) {
        return Test-ScoutPermission -Assessment $Assessment -Manifest $manifest
    }

    # ---- COLLECT ----
    if ($FromCollect) {
        $collect = Get-Content $FromCollect -Raw | ConvertFrom-Json -Depth 100
    }
    else {
        # There is no Entra/Graph collection path in this platform's Collect layer
        # (Invoke-Collect is ARG/ARM only) — 'EntraOnly' could never actually
        # collect anything, so fail fast with the honest redirect instead of
        # silently returning an empty/misleading run. 'ArmOnly' and 'All' are
        # functionally identical today (both just run the ARM collect) and stay
        # accepted for forward compatibility.
        if ($Scope -eq 'EntraOnly') {
            throw "The assessment core collects ARM/Resource Graph data only -- the assessment platform's Collect layer has no Entra ID collection path. Use 'Invoke-AzureScout -Scope EntraOnly' for Entra ID inventory instead."
        }
        $categories = $Assessment | ForEach-Object { $manifest[$_].Collect } | Select-Object -Unique
        if ($Category) { $categories = $Category }
        Write-ScoutAssessmentProgress -Status 'Collecting Azure resource data' -PercentComplete 5
        $collectArgs = @{ Categories = $categories; Scope = $Scope; ManagementGroupId = $ManagementGroupId }
        # AB#5543 — reuse the inventory pass when this run already made one.
        if ($FromInventory) { $collectArgs.FromInventory = $FromInventory }
        # AB#6792 — the policy-compliance sweep is opt-in on Invoke-Collect (it is an extra
        # Azure call type relative to every other assessment's collect) and is switched on only
        # when a chosen assessment actually scores compliance state.
        $wantsCompliance = [bool](@($Assessment | Where-Object { $manifest.ContainsKey($_) -and $manifest[$_] -is [hashtable] -and $manifest[$_].ContainsKey('Compliance') -and $manifest[$_].Compliance }).Count)
        if ($wantsCompliance) { $collectArgs.IncludePolicyCompliance = $true }
        # AB#6803 (Feature AB#6747, Epic AB#6454) -- same opt-in shape as -IncludePolicyCompliance
        # above: `arcSites`/`azureLocalVirtualMachineInstances` cost a materially heavier ARM REST
        # sweep than every other assessment's collect (see Invoke-Collect's -IncludeAzureLocalArm
        # doc comment), so only an assessment that actually scores them pays for it.
        $wantsAzureLocalArm = [bool](@($Assessment | Where-Object { $manifest.ContainsKey($_) -and $manifest[$_] -is [hashtable] -and $manifest[$_].ContainsKey('RequiresAzureLocalArm') -and $manifest[$_].RequiresAzureLocalArm }).Count)
        if ($wantsAzureLocalArm) { $collectArgs.IncludeAzureLocalArm = $true }
        $collect = Invoke-Collect @collectArgs

        # ingest third-party collectors declared by the chosen assessments
        $ingestors = $Assessment | ForEach-Object { $manifest[$_].Ingest } | Select-Object -Unique
        foreach ($i in $ingestors) {
            Write-ScoutAssessmentProgress -Status "Ingesting: $i" -PercentComplete 20
            switch ($i) {
                # Native governance collector (AB#5041) — ARG + ambient-token ARM
                # REST, no AzGovViz dependency. Default for every assessment that
                # needs management-group / policy / role / budget / lock data.
                'Governance'    { $collect = Import-Governance   -Collect $collect -ManagementGroupId $ManagementGroupId }
                # AzGovViz stays available as an opt-in heavy collector, but nothing
                # in the manifest references it by default any more.
                'AzGovViz'      { $collect = Import-AzGovViz     -Collect $collect -OutputPath $runPath -ManagementGroupId $ManagementGroupId }
                # AB#6774 -- ArgQueryPack is retired. All six of its queries duplicated data
                # Invoke-Collect had just collected, and it overwrote the good copies with
                # worse ones (no divide-by-zero guard on two of them, untyped projections on a
                # third), while a fourth was fetched and never merged at all. Any manifest
                # entry still naming it is ignored rather than erroring, because the value is
                # in a data file a customer may have copied.
                'ArgQueryPack'  { Write-Verbose 'Invoke-ScoutAssessmentCore: the ArgQueryPack ingest is retired (AB#6774) -- Invoke-Collect already produces all six of its datasets. Ignoring.' }
                # AB#6777 -- in a combined run the advisor rows are already in memory from the
                # inventory pass, so hand them over instead of re-fetching per subscription
                # through a slower API.
                'AdvisorScores' {
                    $advisorArgs = @{ Collect = $collect }
                    if ($FromInventory -and $FromInventory.PSObject.Properties['Advisories']) {
                        $advisorArgs.FromInventory = @($FromInventory.Advisories)
                    }
                    $collect = Import-AdvisorScores @advisorArgs
                }
                # AB#6826 (Feature AB#6749) -- Get-ScoutCostInventory wired into the collect
                # pipeline for the first time (previously built, never called -- see the
                # FinOps question-set enumeration's own "what this means" section). No new
                # switch: cost data is either reachable (Az.CostManagement installed, billing
                # RBAC in place) or it is not, and the ingestor itself computes `available`.
                'CostInventory' {
                    $costArgs = @{ Collect = $collect }
                    if ($FromInventory -and $FromInventory.PSObject.Properties['Costs']) {
                        $costArgs.FromInventory = @($FromInventory.Costs)
                    }
                    $collect = Import-ScoutCostInventory @costArgs
                }
                # AB#6827 (Feature AB#6749) -- same opt-in gate Invoke-AzureScout's own
                # -IncludeDevOps already uses; the DevOps Capability assessment is the first
                # -Assessment-only caller of the five ADO REST collectors, which previously fed
                # only the Excel inventory path.
                'DevOpsCapability' {
                    $devopsArgs = @{ Collect = $collect; IncludeDevOps = $IncludeDevOps.IsPresent }
                    if ($DevOpsOrganization) { $devopsArgs.DevOpsOrganization = $DevOpsOrganization }
                    if ($DevOpsPat) { $devopsArgs.DevOpsPat = $DevOpsPat }
                    if ($TenantID) { $devopsArgs.TenantID = $TenantID }
                    if ($FromInventory -and $FromInventory.PSObject.Properties['Resources']) {
                        $devopsArgs.FromInventory = @($FromInventory.Resources)
                    }
                    $collect = Import-ScoutDevOpsCapability @devopsArgs
                }
            }
        }
        $collect | ConvertTo-Json -Depth 100 | Out-File "$runPath/collect.json"
    }
    if ($CollectOnly) { return "$runPath/collect.json" }

    # ---- ASSESS ----
    # AB#6879 (Feature AB#6878, clause R-01). Findings are accumulated BOTH into the flat
    # $allFindings -- which the roll-up and every existing caller still read -- and into
    # $findingsByAssessment, keyed by assessment name, so the report phase can render one
    # detailed set PER ASSESSMENT.
    #
    # Phase 0 measured what the single merged document costs: a run selecting LandingZone and
    # Cloud Governance emitted ONE assessment_report.docx, and three unrelated tenants produced
    # documents within 258 bytes of each other. See pmo/research/baseline/.
    $allFindings = @()
    $findingsByAssessment = [ordered]@{}
    $assessmentIndex = 0
    foreach ($name in $Assessment) {
        $assessmentIndex++
        Write-ScoutAssessmentProgress -Status "Assessing: $name" -PercentComplete (35 + [Math]::Min(30, [Math]::Round(($assessmentIndex / [Math]::Max(1, @($Assessment).Count)) * 30)))
        $spec = $manifest[$name]
        if (-not $spec.Rules) { continue }        # inventory-only assessment
        # AB#6792/#6793/#6794 (Feature AB#6744) -- a `Compliance = $true` entry scores Azure
        # Policy compliance state Scout already collected, not a YAML rule set. It still needs a
        # matching Rules glob (for the AB#6763 menu gate, see compliance.initiative.yaml), so the
        # `-not $spec.Rules` guard above still applies to it; this branch replaces Get-RuleSet /
        # Invoke-Assessment with the compliance engine instead of running them on an empty
        # `rules: []` marker file and reporting a hollow zero-finding "pass".
        if ($spec.ContainsKey('Compliance') -and $spec.Compliance) {
            $findings = Invoke-ScoutComplianceAssessment -Collect $collect -Assessment $name
            $allFindings += $findings
            $findingsByAssessment[$name] = @($findings)
            continue
        }
        $ruleSet   = Get-RuleSet -Patterns $spec.Rules
        # $spec is a Hashtable straight out of assessments.psd1, and most assessment
        # entries don't define a Benchmark key at all (only LandingZone does). Dot-
        # accessing a Hashtable key that is entirely absent throws PropertyNotFound
        # under Set-StrictMode -Version Latest, so check ContainsKey first rather
        # than relying on truthiness of a property access that may never resolve.
        $benchmark = if ($spec.ContainsKey('Benchmark') -and $spec.Benchmark) {
            Get-Content "$PSScriptRoot/assess/benchmarks/$($spec.Benchmark)" -Raw | ConvertFrom-Json -Depth 100
        } else { $null }
        $findings = Invoke-Assessment -Collect $collect -RuleSet $ruleSet -Benchmark $benchmark -Assessment $name
        $allFindings += $findings
        $findingsByAssessment[$name] = @($findings)
    }
    $scored = Get-Score -Findings $allFindings
    $scored | ConvertTo-Json -Depth 100 | Out-File "$runPath/findings.json"

    # ---- DRIFT (cross-run) ----
    # Compare this run against the immediately previous run and append it to a
    # findings-history log shared across every run under $OutputPath (keyed by
    # $runId), so the React report's Drift tab can show New/Resolved/Regressed
    # deltas (AB#5053). History lives under $OutputPath (not $runPath) so it
    # persists across dated run folders. Never fatal — a drift failure must not
    # sink an otherwise-good assessment.
    $drift = $null
    try {
        $drift = Get-ScoutDrift -Findings $scored -HistoryPath (Join-Path $OutputPath '.scout-history') -RunId $runId
    }
    catch {
        Write-Warning "Invoke-ScoutAssessmentCore: drift tracking skipped: $($_.Exception.Message)"
    }

    # ---- REPORT ----
    # AB#6863. GovernanceReport was missing from this list. Export-Report dispatches it and the
    # renderer is fully implemented and tested, but no production caller ever reached it through
    # the All path -- so the only surface carrying the 1-10 CAF Govern domain maturity score never
    # rendered on a default run. A renderer that exists, passes its tests and is unreachable is
    # indistinguishable from one that was never written.
    $reporters = if ($OutputFormat -contains 'All') { @('PowerBi', 'Html', 'Pptx', 'Excel', 'Json', 'JsonEvidence', 'React', 'Pdf', 'Word', 'EChartsDashboard', 'GovernanceReport') } else { $OutputFormat }
    $reporterIndex = 0
    foreach ($r in $reporters) {
        $reporterIndex++
        Write-ScoutAssessmentProgress -Status "Rendering: $r" -PercentComplete (70 + [Math]::Min(29, [Math]::Round(($reporterIndex / [Math]::Max(1, @($reporters).Count)) * 29)))
        # Pipe to Out-Null: some renderers (Export-React) RETURN the path they
        # wrote, and that must not leak into this function's output stream — the
        # only thing the assessment core returns is $runPath. Without this,
        # a run that includes 'React' returns @(reportPath, runPath) and every
        # caller that expects a single run-folder path (incl. Invoke-ScoutPipeline)
        # breaks.
        Export-Report -Renderer $r -Findings $scored -Collect $collect -OutputPath $runPath -Drift $drift | Out-Null
    }

    # ---- PER-ASSESSMENT REPORTS (AB#6879, clause R-01/R-02) ----
    # The run root keeps the merged set, unchanged, so every existing caller and test that reads
    # $runPath/assessment_report.docx still finds it. Alongside it, each selected assessment now
    # gets its OWN complete report set under assessments/<slug>/.
    #
    # Only when there is more than one: a single-assessment run would otherwise write the same
    # documents twice, which is noise, not a deliverable.
    if (@($findingsByAssessment.Keys).Count -gt 1) {
        $assessmentRoot = Join-Path $runPath 'assessments'
        foreach ($name in $findingsByAssessment.Keys) {
            $perFindings = @($findingsByAssessment[$name])
            if ($perFindings.Count -eq 0) { continue }

            # Slug: lowercase, non-alphanumerics collapsed to a single dash. 'Assess: Cloud
            # Governance' -> 'assess-cloud-governance'. Folder names must not carry ':' on Windows.
            $slug = ($name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
            $perPath = Join-Path $assessmentRoot $slug
            $null = New-Item -ItemType Directory -Path $perPath -Force

            # Scored INDEPENDENTLY. A per-assessment report must show that assessment's own score,
            # not the run-wide one -- reusing $scored would print the same number in every folder
            # and defeat the point of splitting them.
            $perScored = Get-Score -Findings $perFindings
            $perScored | ConvertTo-Json -Depth 100 | Out-File "$perPath/findings.json"

            Write-ScoutAssessmentProgress -Status "Rendering: $name"
            foreach ($r in $reporters) {
                # Never fatal. One assessment's renderer failing must not cost the operator the
                # other assessments' reports, nor the merged set already written above.
                try {
                    Export-Report -Renderer $r -Findings $perScored -Collect $collect -OutputPath $perPath -Drift $drift | Out-Null
                }
                catch {
                    Write-Warning "Invoke-ScoutAssessmentCore: '$r' failed for assessment '$name': $($_.Exception.Message)"
                }
            }
        }

        # ---- EXECUTIVE ROLL-UP (AB#6880, clause R-03) ----
        # "Here is your estate, and here is how it scored across every framework assessed."
        # Scout has never produced this artefact, and it is the one an executive actually reads:
        # the per-assessment reports answer "how did Landing Zone do", but nobody was answering
        # "how did we do overall, and which of these is the worst".
        #
        # It renders from the SAME merged $scored the run root uses -- this is a roll-up, not a
        # re-assessment -- into executive/, next to the per-assessment folders. Deck and PDF only:
        # the roll-up is the read-in-ten-minutes artefact, and shipping a full workbook and Power
        # BI project beside it would bury the point.
        $execPath = Join-Path $runPath 'executive'
        $null = New-Item -ItemType Directory -Path $execPath -Force

        $execScores = foreach ($name in $findingsByAssessment.Keys) {
            $af = @($findingsByAssessment[$name])
            if ($af.Count -eq 0) { continue }
            $s = Get-Score -Findings $af
            [pscustomobject]@{
                Assessment = $name
                Score      = (Get-AZSCSafeProperty -InputObject $s -Path 'Score')
                Findings   = $af.Count
                Failed     = @($af | Where-Object { $_.Status -eq 'Fail' }).Count
                Manual     = @($af | Where-Object { $_.Status -eq 'Manual' }).Count
            }
        }
        @($execScores) | ConvertTo-Json -Depth 20 | Out-File "$execPath/rollup.json"

        Write-ScoutAssessmentProgress -Status 'Rendering: executive roll-up'
        foreach ($r in @('Pptx', 'Pdf')) {
            if ($reporters -notcontains $r) { continue }
            try {
                Export-Report -Renderer $r -Findings $scored -Collect $collect -OutputPath $execPath -Drift $drift | Out-Null
            }
            catch {
                Write-Warning "Invoke-ScoutAssessmentCore: '$r' failed for the executive roll-up: $($_.Exception.Message)"
            }
        }
    }

    Write-ScoutAssessmentProgress -Completed
    return $runPath
}
