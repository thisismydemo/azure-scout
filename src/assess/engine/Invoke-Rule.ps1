#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Evaluate a single rule against the collect object, returning a finding.

.NOTES
    Supports the seven assert types. Tracks ADO Story AB#5030.

    AB#6826 (Feature AB#6749, Epic AB#6454) added an eighth, orthogonal concept: an optional
    `assert.gate` JSONPath. When present, the rule's Status is 'NotAssessed' (and the normal
    query/assert evaluation never runs) whenever the gate resolves to NO matches at all, OR
    resolves to a single scalar boolean token whose value is `false` -- for a data source that
    is gated behind a permission system Scout's ordinary Reader role does not satisfy (the
    FinOps EA/MCA billing gate, Azure DevOps access not granted), a `countEquals: 0` or
    `exists` assert cannot tell "the source was blocked" apart from "the source was checked
    and found clean", and collapsing the two into a Pass or a Fail is exactly the false read
    AB#6793 already fixed once for Azure Policy compliance state. `gate` is evaluated with the
    SAME Resolve-JsonPath a rule's own `query` uses -- write it as a plain scalar path to a
    boolean field the collect pipeline computes (`$.finops.available`, `$.devops.available`),
    NOT a `[?()]` array filter: Newtonsoft JSONPath's `[?()]` iterates an array's ELEMENTS, and
    `finops`/`devops` are single objects, not arrays, so `$.finops[?(@.available == true)]`
    silently matches nothing in EITHER state -- found by this feature's own manual gate test,
    not by a live run.
#>
function Invoke-Rule {
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] $Collect,
        [string] $Area,
        [string] $Framework
    )

    $status = 'Unknown'; $evidenceCount = 0; $evidence = @()

    # AB#6892. Initialised here, not at the point of use, because the early `return`s below
    # (gate failure, query failure, not-assessed) build their own finding object and every one of
    # them must still be able to say what it was going to look for. $null means "not applicable
    # to this rule", which is distinct from 0.
    $denominator = $null

    # ---- AB#6826: optional gate, checked before manual/query evaluation ----
    $gatePath = $null
    if ($Rule.assert -is [hashtable]) {
        if ($Rule.assert.ContainsKey('gate')) { $gatePath = $Rule.assert.gate }
    }
    elseif ($Rule.assert -and $Rule.assert.PSObject.Properties['gate']) {
        $gatePath = $Rule.assert.gate
    }
    if (-not [string]::IsNullOrWhiteSpace($gatePath)) {
        $gateMatches = $null
        # NOT wrapped in @(): Resolve-JsonPath already returns its (possibly empty) array via
        # `Write-Output -NoEnumerate`, exactly like every other Resolve-JsonPath call in this
        # file. Wrapping it again here nests that array inside a further one-element array, so
        # `.Count` is never 0 even on a genuinely empty result -- found by this feature's own
        # gate test, not by a live run.
        try { $gateMatches = Resolve-JsonPath -InputObject $Collect -Path $gatePath }
        catch {
            Write-Warning "Rule $($Rule.id): gate query '$gatePath' failed: $_"
            return [pscustomobject]@{
                Id = $Rule.id; Title = $Rule.title; Framework = $Framework; Area = $Area
                Severity = $Rule.severity; Status = 'Error'; EvidenceCount = 0; Evidence = @()
                Remediation = $Rule.remediation; Manual = [bool]$Rule.manual
            }
        }
        $gateOpen = $true
        if (@($gateMatches).Count -eq 0) {
            $gateOpen = $false
        }
        elseif (@($gateMatches).Count -eq 1) {
            # A single scalar boolean token (the intended shape: `$.finops.available`,
            # `$.devops.available`) closes the gate when its value is exactly `false`. Any
            # other single-match shape (a row, a string, ...) is treated as "present" -- the
            # gate is a data-availability check, not a second assert.
            try { if ($gateMatches[0].ToObject([bool]) -eq $false) { $gateOpen = $false } }
            catch { }   # not a boolean token -- presence alone means the gate is open
        }
        if (-not $gateOpen) {
            return [pscustomobject]@{
                Id = $Rule.id; Title = $Rule.title; Framework = $Framework; Area = $Area
                Severity = $Rule.severity; Status = 'NotAssessed'; EvidenceCount = 0; Evidence = @()
                Remediation = $Rule.remediation; Manual = [bool]$Rule.manual
            }
        }
    }

    # A rule carries EITHER a `query` (one dataset, filtered) or a `join` (two datasets,
    # correlated) -- never both. `join` is read through the same shape-agnostic accessor the rest
    # of this function uses, because ConvertFrom-Yaml hands back a Hashtable while test fixtures
    # build a pscustomobject, and dotting a missing key throws under StrictMode (AB#6835).
    $hasJoin = if ($Rule -is [hashtable]) { $Rule.ContainsKey('join') -and $null -ne $Rule.join }
               elseif ($Rule -is [System.Collections.IDictionary]) { $Rule.Contains('join') -and $null -ne $Rule['join'] }
               else { $null -ne $Rule.PSObject.Properties['join'] -and $null -ne $Rule.join }

    if ($Rule.manual -or $Rule.assert.type -eq 'manual') {
        # pre-fill with any evidence the scan DID find, then hand to the human
        if ($Rule.query) {
            $evidence = Resolve-JsonPath -InputObject $Collect -Path $Rule.query
            $evidenceCount = $evidence.Count
        }
        $status = 'Manual'
    }
    else {
        try {
            # Assigned INSIDE each branch, not from the `if` as an expression. `$x = if (...) { @() }`
            # returns $null, not an empty array -- the if's output stream enumerates and an empty
            # array enumerates to nothing -- and the very next line reads `.Count`, which then
            # throws under StrictMode. A join that legitimately found no unmatched rows (the PASS
            # case, and the common one) hit that on every rule.
            $matches = $null
            if ($hasJoin) {
                $matches = @(Resolve-RuleJoin -Rule $Rule -Collect $Collect)
            } else {
                $matches = Resolve-JsonPath -InputObject $Collect -Path $Rule.query
            }
        }
        catch {
            # A query that threw (unsupported/invalid JSONPath, or a malformed join block) is an
            # Error, never a silent Pass on countEquals:0 (AB#5083). Surface it so it's visible.
            Write-Warning "Rule $($Rule.id): $(if ($hasJoin) { 'join' } else { "query '$($Rule.query)'" }) failed: $_"
            return [pscustomobject]@{
                Id = $Rule.id; Title = $Rule.title; Framework = $Framework; Area = $Area
                Severity = $Rule.severity; Status = 'Error'; EvidenceCount = 0; Evidence = @()
                Remediation = $Rule.remediation; Manual = [bool]$Rule.manual
            }
        }
        $evidenceCount = $matches.Count
        $evidence = $matches | Select-Object -First 25    # cap evidence payload
        # ConvertFrom-Yaml returns `assert:` as a Hashtable (test fixtures often use a
        # pscustomobject instead), and 'exists'/'notExists' rules legitimately omit a
        # `value:` key. Accessing a missing key/property via dot-notation throws
        # PropertyNotFoundException under Set-StrictMode -Version Latest, so only read
        # .value when it's actually present — the exists/notExists cases below never
        # reference $v. Handle both Hashtable and pscustomobject assert shapes.
        $v = $null
        if ($Rule.assert -is [hashtable]) {
            if ($Rule.assert.ContainsKey('value')) { $v = $Rule.assert.value }
        }
        elseif ($Rule.assert.PSObject.Properties['value']) {
            $v = $Rule.assert.value
        }

        switch ($Rule.assert.type) {
            'countGreaterThan'  { $status = ($evidenceCount -gt  $v) ? 'Pass' : 'Fail' }
            'countEquals'       { $status = ($evidenceCount -eq  $v) ? 'Pass' : 'Fail' }
            'countLessThan'     { $status = ($evidenceCount -lt  $v) ? 'Pass' : 'Fail' }
            'exists'            { $status = ($evidenceCount -gt   0) ? 'Pass' : 'Fail' }
            'notExists'         { $status = ($evidenceCount -eq   0) ? 'Pass' : 'Fail' }
            'percentageAtLeast' {
                $denom = (Resolve-JsonPath -InputObject $Collect -Path $Rule.assert.denominatorQuery).Count
                # AB#6892: surfaced on the finding so a renderer can say "17 of 198", which is the
                # supporting number the reference deliverable carries on every risk row. Without
                # it the reader gets a percentage with nothing behind it.
                $denominator = $denom
                # No denominator = nothing collected for this dimension -> Unknown,
                # NOT a 0% Fail, which would be misleading (AB#5085).
                if ($denom -le 0) { $status = 'Unknown' }
                else {
                    $pct = $evidenceCount / $denom * 100
                    $status = ($pct -ge $v) ? 'Pass' : (($pct -gt 0) ? 'Partial' : 'Fail')
                }
            }
            default {
                Write-Warning "Rule $($Rule.id): unknown assert type '$($Rule.assert.type)'"
                $status = 'Error'
            }
        }
    }

    # AB#6892 -- WHAT WAS SEARCHED, always, even when nothing was found.
    #
    # Phase 0 measured that 42 of 57 FAILING controls carried zero evidence, and no report named a
    # single Azure resource across three real tenants. That is not a renderer defect. An `exists`
    # rule fails precisely BECAUSE its query returned nothing, so its evidence list is empty by
    # construction -- there is no resource to name, and there never will be.
    #
    # What makes such a finding actionable is not a resource list but the SCOPE: what was looked
    # for, where, and how many candidates existed. "No Purview account was found in any of the 9
    # subscriptions scanned" is actionable. "Data governance coverage: Fail" is decoration.
    #
    # So every finding now carries the query it ran and the assertion it applied, and the
    # percentage rules carry their denominator. Renderers can state the scope of a nil result
    # instead of rendering an empty table.
    $searchedPath = if ($hasJoin) { '(join)' } else { [string]$Rule.query }
    $assertType = if ($Rule.assert) { [string]$Rule.assert.type } else { $null }

    [pscustomobject]@{
        Id            = $Rule.id
        Title         = $Rule.title
        Framework     = $Framework
        Area          = $Area
        Severity      = $Rule.severity
        Status        = $status
        EvidenceCount = $evidenceCount
        Evidence      = $evidence
        SearchedPath  = $searchedPath
        AssertType    = $assertType
        Denominator   = $denominator
        Remediation   = $Rule.remediation
        Manual        = [bool]$Rule.manual
    }
}
