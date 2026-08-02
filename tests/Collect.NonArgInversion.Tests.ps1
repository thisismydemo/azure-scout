#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#5648 (Epic AB#5638) — the NON-ARG half of the collection inversion, and the gate that
    keeps it.

    v2.8.0 inverted the Resource Graph half: a default assessment collect went from 35 queries
    to 4. The four non-ARG sources were left behind. `Get-ScoutApiResources`,
    `Get-ScoutVmQuotas`, `Get-ScoutVmSkuDetails` and `Get-ScoutCostInventory` shipped in
    v2.7.0 and NOTHING called them — a live run still ran the v1 implementations in
    Modules/Private/Extraction for ARM REST resources, VM quota/SKU lookups and Cost
    Management. This file pins the inversion two ways, because each catches a failure the
    other misses:

      1. STATICALLY, by AST. Every Az/ARM cmdlet these four datasets are built from is now
         reachable from exactly one place — src/collect. A future edit that reintroduces an
         `Invoke-RestMethod` or a `Get-AzVMUsage` into the legacy engine fails here, which is
         the regression a behavioural test would happily pass through.

      2. BEHAVIOURALLY, by equivalence. The v1 implementations are reproduced verbatim below
         as reference functions and driven over the SAME stubbed Azure responses as the
         shipping path, then compared key by key — not by row count, which is the comparison
         that passes while every field is wrong.

    The reference functions are the retired code, copied unchanged apart from their names and
    an explicit `Set-StrictMode -Off` (the v1 engine ran under `Set-StrictMode -Off`, set by
    Start-AZSCExtractionOrchestration — see AB#5633). They exist only in this file; they are
    the "expected" side of the comparison and must not be tidied, because tidying them stops
    them being evidence.

    No Azure connection: every Az cmdlet and Invoke-RestMethod is stubbed.
#>

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent

    . "$script:root/src/collect/Get-ScoutApiResources.ps1"
    . "$script:root/src/collect/Get-ScoutVmQuotas.ps1"
    . "$script:root/src/collect/Get-ScoutVmSkuDetails.ps1"
    . "$script:root/src/collect/Get-ScoutCostInventory.ps1"

    # Compatibility projection used by this equivalence test only. Production now calls the
    # Get-Scout* functions directly; these helpers preserve the retired v2 envelope so the
    # reference implementation below remains a meaningful field-by-field oracle.
    function Get-AZSCAPIResources {
        param($Subscriptions, $AzureEnvironment, $SkipPolicy)
        if (-not $Subscriptions) { return }
        $rows = Get-ScoutApiResources -Subscriptions @($Subscriptions) -AzureEnvironment $AzureEnvironment -SkipPolicy:$SkipPolicy
        foreach ($row in @($rows)) {
            if ($SkipPolicy) {
                $policyAssign = ''
                $policyDef = ''
                $policySetDef = ''
            }
            else {
                $policyAssign = $row.PolicyAssignments
                $policyDef = @($row.PolicyDefinitions)
                $policySetDef = @($row.PolicySetDefinitions)
            }
            @{
                Subscription       = $row.Subscription
                ResourceHealth     = if ($row.ResourceHealth) { $row.ResourceHealth } else { $null }
                ManagedIdentities  = if ($row.ManagedIdentities) { $row.ManagedIdentities } else { $null }
                AdvisorScore       = if ($row.AdvisorScore) { $row.AdvisorScore } else { $null }
                ReservationRecomen = if ($row.ReservationRecommendations) { $row.ReservationRecommendations } else { $null }
                PolicyAssign       = $policyAssign
                PolicyDef          = $policyDef
                PolicySetDef       = $policySetDef
            }
        }
    }
    function Get-AZSCCostInventory {
        param($Subscriptions, $Days, $Granularity)
        if (-not $Subscriptions) { return }
        $args = @{ Subscriptions = @($Subscriptions) }
        if ($PSBoundParameters.ContainsKey('Days')) { $args.Days = $Days }
        if ($PSBoundParameters.ContainsKey('Granularity')) { $args.Granularity = $Granularity }
        foreach ($row in @(Get-ScoutCostInventory @args)) {
            @{ SubscriptionId = $row.SubscriptionId; SubscriptionName = $row.SubscriptionName; CostData = $row.CostData }
        }
    }
    function Get-AZSCVMQuotas {
        param($Subscriptions, $Resources)
        if (-not $Subscriptions) { return [pscustomobject]@{ type = 'AZSC/VM/Quotas'; properties = @() } }
        Get-ScoutVmQuotas -Subscriptions @($Subscriptions) -Resources $Resources
    }
    function Get-AZSCVMSkuDetails { param($Resources) Get-ScoutVmSkuDetails -Resources $Resources }


    # ---------------------------------------------------------------- fixtures ----

    $script:Subs = @(
        [pscustomobject]@{ id = 'sub-1'; name = 'First subscription' }
        [pscustomobject]@{ id = 'sub-2'; name = 'Second subscription' }
    )

    # The MIXED resource array both VM functions have to survive: Resource Graph rows carry
    # subscriptionId/type/location, the ARM REST rows appended alongside them carry none of
    # those. A bare `$_.subscriptionId` on one of the latter aborts the pipeline under
    # StrictMode and collects NO quota for ANY subscription (AB#5633).
    function Get-FixtureMixedResources {
        @(
            [pscustomobject]@{ id = '/vm1'; type = 'microsoft.compute/virtualmachines'
                subscriptionId = 'sub-1'; location = 'eastus' }
            [pscustomobject]@{ id = '/vm2'; type = 'Microsoft.Compute/virtualMachines'
                subscriptionId = 'sub-1'; location = 'westus' }
            [pscustomobject]@{ id = '/vmss1'; type = 'microsoft.compute/virtualmachinescalesets'
                subscriptionId = 'sub-2'; location = 'eastus' }
            [pscustomobject]@{ id = '/kv1'; type = 'microsoft.keyvault/vaults'
                subscriptionId = 'sub-1'; location = 'eastus' }
            # A REST row: no subscriptionId, no type, no location.
            [pscustomobject]@{ eventLevel = 'Warning'; impactedService = 'Compute' }
            # A managed identity row: has a type but no subscriptionId.
            [pscustomobject]@{ name = 'uami1'; type = 'microsoft.managedidentity/userassignedidentities' }
            $null
        )
    }

    # ---------------------------------------------------------------- Azure stubs ----

    function Install-ScoutAzureStubs {
        param([switch] $FailPolicyForSub2, [switch] $FailAdvisorForSub2)

        $script:restCalls = [System.Collections.Generic.List[string]]::new()
        $script:vmUsageCalls = [System.Collections.Generic.List[string]]::new()
        $script:skuCalls = [System.Collections.Generic.List[string]]::new()
        $script:costCalls = [System.Collections.Generic.List[string]]::new()
        $script:failPolicy = [bool]$FailPolicyForSub2
        $script:failAdvisor = [bool]$FailAdvisorForSub2

        # Sleeps are pure pacing; the functions under test spend ~1.7s in them per run.
        function global:Start-Sleep { param([int] $Milliseconds, [int] $Seconds) }

        function global:Get-AzAccessToken {
            param([switch] $AsSecureString, $InformationAction, $WarningAction, $Debug)
            [pscustomobject]@{ Token = (ConvertTo-SecureString 'fake-token-value' -AsPlainText -Force) }
        }

        function global:Invoke-RestMethod {
            param($Uri, $Headers, $Method, $Body, $ContentType, $ErrorAction)
            $script:restCalls.Add("$Method $Uri")
            $sub = if ($Uri -match '/subscriptions/([^/]+)/') { $Matches[1] } else { 'unknown' }

            if ($script:failAdvisor -and $sub -eq 'sub-2' -and $Uri -match 'advisorScore') {
                throw 'Advisor is unavailable for this subscription'
            }
            if ($script:failPolicy -and $sub -eq 'sub-2' -and $Uri -match 'policyStates') {
                throw 'Authorization failed for policyStates'
            }

            if ($Uri -match 'ResourceHealth/events') {
                return [pscustomobject]@{ value = @([pscustomobject]@{ name = "health-$sub"; status = 'Available' }) }
            }
            if ($Uri -match 'userAssignedIdentities') {
                # Deliberately EMPTY: an empty collection on every element is the exact shape
                # that made member enumeration throw under StrictMode (AB#5633).
                return [pscustomobject]@{ value = @() }
            }
            if ($Uri -match 'advisorScore') {
                return [pscustomobject]@{ value = @([pscustomobject]@{ name = "score-$sub"; score = 72 }) }
            }
            if ($Uri -match 'reservationRecommendations') {
                return [pscustomobject]@{ value = @([pscustomobject]@{ sku = 'Standard_D2s_v3'; savings = 12.5 }) }
            }
            if ($Uri -match 'policyStates') {
                return [pscustomobject]@{ value = [pscustomobject]@{ policyAssignments = @([pscustomobject]@{ policyAssignmentId = "pa-$sub" }) } }
            }
            if ($Uri -match 'policySetDefinitions') {
                return [pscustomobject]@{ value = @([pscustomobject]@{ name = "psd-$sub" }) }
            }
            if ($Uri -match 'policyDefinitions') {
                return [pscustomobject]@{ value = @([pscustomobject]@{ name = "pd-$sub" }) }
            }
            return [pscustomobject]@{ value = @() }
        }

        function global:Get-AzContext {
            param($ErrorAction)
            [pscustomobject]@{ Subscription = [pscustomobject]@{ Id = 'original-sub' } }
        }
        function global:Set-AzContext {
            param($Subscription, $SubscriptionId, $ErrorAction, $WarningAction, $InformationAction, $Debug)
        }

        function global:Get-AzVMUsage {
            param($Location, $ErrorAction, $Debug)
            $script:vmUsageCalls.Add($Location)
            @(
                [pscustomobject]@{ Name = [pscustomobject]@{ Value = 'standardDSv3Family' }; CurrentValue = 4; Limit = 100 }
                [pscustomobject]@{ Name = [pscustomobject]@{ Value = 'standardFSv2Family' }; CurrentValue = 0; Limit = 50 }
            )
        }

        function global:Get-AzComputeResourceSku {
            param($Location, $ErrorAction, $Debug)
            $script:skuCalls.Add($Location)
            @([pscustomobject]@{ Name = 'Standard_D2s_v3'; Family = 'standardDSv3Family'; Locations = @($Location) })
        }

        function global:Invoke-AzCostManagementQuery {
            param($Type, $Scope, $Timeframe, $DatasetGranularity, $DatasetGrouping,
                $DatasetAggregation, $TimePeriodFrom, $TimePeriodTo, $ErrorAction, $Debug)
            $script:costCalls.Add("$Scope|$DatasetGranularity|$($TimePeriodFrom.ToString('yyyy-MM-dd'))|$($TimePeriodTo.ToString('yyyy-MM-dd'))")
            @([pscustomobject]@{ Row = @(, @('ResourceType', 'rg-1', 'eastus', 'Virtual Machines', 12.34)) })
        }

        # The legacy cost function wrote to the run log; the shim path does too, guarded.
        function global:Write-AZSCLog { param($Message, $Level, $Color) }
    }

    function Remove-ScoutAzureStubs {
        # `Remove-Item function:global:X` is a SILENT NO-OP -- `global:` is not a scope
        # qualifier inside a provider path, so the item is never found and -ErrorAction
        # SilentlyContinue hides that. The stubs then leak into every later test file in the
        # run, which is how a mocked Invoke-AzCostManagementQuery ended up answering another
        # file's "the module is not installed" test. Use the provider path with no qualifier.
        foreach ($name in 'Start-Sleep', 'Get-AzAccessToken', 'Invoke-RestMethod', 'Get-AzContext',
            'Set-AzContext', 'Get-AzVMUsage', 'Get-AzComputeResourceSku',
            'Invoke-AzCostManagementQuery', 'Write-AZSCLog') {
            if (Test-Path "Function:\$name") { Remove-Item "Function:\$name" -Force -ErrorAction SilentlyContinue }
        }
    }

    # ------------------------------------------------- v1 reference implementations ----
    # Copied verbatim from the retired bodies. Do not tidy: tidying them stops them being
    # evidence of what the product used to do.

    function Get-ReferenceApiResources {
        Param($Subscriptions, $AzureEnvironment, $SkipPolicy)
        Set-StrictMode -Off

        try {
            $Token = Get-AzAccessToken -AsSecureString -InformationAction SilentlyContinue -WarningAction SilentlyContinue -Debug:$false
            $TokenData = $Token.Token | ConvertFrom-SecureString -AsPlainText
            $header = @{ 'Authorization' = 'Bearer ' + $TokenData }
        }
        catch { return }

        if ($AzureEnvironment -eq 'AzureCloud') { $AzURL = 'management.azure.com' }
        elseif ($AzureEnvironment -eq 'AzureUSGovernment') { $AzURL = 'management.usgovcloudapi.net' }
        elseif ($AzureEnvironment -eq 'AzureChinaCloud') { $AzURL = 'management.chinacloudapi.cn' }
        else { return }

        $ResourceHealthHistoryDate = (Get-Date).AddMonths(-6)
        $APIResults = @()

        foreach ($Subscription in $Subscriptions) {
            $ResourceHealth = ""; $Identities = ""; $ADVScore = ""; $ReservationRecon = ""
            $PolicyAssign = ""; $PolicySetDef = ""; $PolicyDef = ""

            $Sub = $Subscription.id

            $url = ('https://' + $AzURL + '/subscriptions/' + $Sub + '/providers/Microsoft.ResourceHealth/events?api-version=2022-10-01&queryStartTime=' + $ResourceHealthHistoryDate)
            try { $ResourceHealth = Invoke-RestMethod -Uri $url -Headers $header -Method GET } catch { $ResourceHealth = "" }

            $url = ('https://' + $AzURL + '/subscriptions/' + $Sub + '/providers/Microsoft.ManagedIdentity/userAssignedIdentities?api-version=2023-01-31')
            try { $Identities = Invoke-RestMethod -Uri $url -Headers $header -Method GET } catch { $Identities = "" }

            $url = ('https://' + $AzURL + '/subscriptions/' + $Sub + '/providers/Microsoft.Advisor/advisorScore?api-version=2023-01-01')
            try { $ADVScore = Invoke-RestMethod -Uri $url -Headers $header -Method GET } catch { $ADVScore = "" }

            $url = ('https://' + $AzURL + '/subscriptions/' + $Sub + '/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01')
            try { $ReservationRecon = Invoke-RestMethod -Uri $url -Headers $header -Method GET } catch { $ReservationRecon = "" }

            if (![bool]$SkipPolicy) {
                try {
                    $url = ('https://' + $AzURL + '/subscriptions/' + $sub + '/providers/Microsoft.PolicyInsights/policyStates/latest/summarize?api-version=2019-10-01')
                    $PolicyAssign = (Invoke-RestMethod -Uri $url -Headers $header -Method POST).value
                    $url = ('https://' + $AzURL + '/subscriptions/' + $sub + '/providers/Microsoft.Authorization/policySetDefinitions?api-version=2023-04-01')
                    $PolicySetDef = (Invoke-RestMethod -Uri $url -Headers $header -Method GET).value
                    $url = ('https://' + $AzURL + '/subscriptions/' + $sub + '/providers/Microsoft.Authorization/policyDefinitions?api-version=2023-04-01')
                    $PolicyDef = (Invoke-RestMethod -Uri $url -Headers $header -Method GET).value
                }
                catch { $PolicyAssign = ""; $PolicySetDef = ""; $PolicyDef = "" }
            }

            $tmp = @{
                'Subscription'       = $Sub
                'ResourceHealth'     = if ($ResourceHealth) { $ResourceHealth.value } else { $null }
                'ManagedIdentities'  = if ($Identities) { $Identities.value } else { $null }
                'AdvisorScore'       = if ($ADVScore) { $ADVScore.value } else { $null }
                'ReservationRecomen' = if ($ReservationRecon) { $ReservationRecon.value } else { $null }
                'PolicyAssign'       = $PolicyAssign
                'PolicyDef'          = $PolicyDef
                'PolicySetDef'       = $PolicySetDef
            }
            $APIResults += $tmp
        }
        return $APIResults
    }

    function Get-ReferenceVmQuotas {
        Param ($Subscriptions, $Resources)
        Set-StrictMode -Off

        $OriginalContext = Get-AzContext -ErrorAction SilentlyContinue
        try {
            $Quotas = Foreach ($Sub in $Subscriptions) {
                $VMTypes = @('microsoft.compute/virtualmachines', 'microsoft.compute/virtualmachinescalesets')
                $Locs = @($Resources |
                        Where-Object {
                            $null -ne $_ -and
                            $_.PSObject.Properties.Name -contains 'subscriptionId' -and
                            $_.PSObject.Properties.Name -contains 'Type' -and
                            $_.subscriptionId -eq $Sub.id -and
                            $_.Type -in $VMTypes
                        } |
                        Group-Object -Property Location |
                        ForEach-Object { $_.Name })
                if (![string]::IsNullOrEmpty($Locs)) {
                    Foreach ($Loc in $Locs) {
                        Set-AzContext -Subscription $Sub.Id -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Debug:$false
                        $Quota = get-azvmusage -location $Loc -Debug:$false
                        $Quota = $Quota | Where-Object { $_.CurrentValue -ge 1 }
                        [PSCustomObject]@{
                            Location     = $Loc
                            SubId        = $Sub.id
                            Subscription = $Sub.name
                            Data         = $Quota
                        }
                    }
                }
            }
        }
        finally {
            $RestoreId = $null
            if ($OriginalContext -and $OriginalContext.PSObject.Properties.Name -contains 'Subscription' -and $OriginalContext.Subscription) {
                if ($OriginalContext.Subscription.PSObject.Properties.Name -contains 'Id') { $RestoreId = $OriginalContext.Subscription.Id }
            }
            if ($RestoreId) { Set-AzContext -SubscriptionId $RestoreId -ErrorAction SilentlyContinue | Out-Null }
        }

        return [PSCustomObject]@{
            'type'       = 'AZSC/VM/Quotas'
            'properties' = $Quotas
        }
    }

    function Get-ReferenceVmSkuDetails {
        Param ($Resources)
        Set-StrictMode -Off

        $VMTypes = @('microsoft.compute/virtualmachines', 'microsoft.compute/virtualmachinescalesets')
        $vm = @($Resources | Where-Object {
                $null -ne $_ -and
                $_.PSObject.Properties.Name -contains 'TYPE' -and
                $_.TYPE -in $VMTypes
            })
        $Locations = @($vm |
                Where-Object { $_.PSObject.Properties.Name -contains 'location' -and $_.location } |
                Select-Object -ExpandProperty location -Unique)

        $VMskuData = Foreach ($location in $Locations) {
            [PSCustomObject]@{
                Location = $location
                SKUs     = Get-AzComputeResourceSku $location -Debug:$false
            }
        }

        return [PSCustomObject]@{
            'type'       = 'AZSC/VM/SKU'
            'properties' = $VMskuData
        }
    }

    function Get-ReferenceCostInventory {
        Param($Subscriptions, $Days, $Granularity)
        Set-StrictMode -Off

        $Today = Get-Date
        $EndDate = Get-Date -Year $Today.Year -Month $Today.Month -Day $Today.Day -Hour 23 -Minute 59 -Second 59 -Millisecond 0

        $Grouping = @()
        $Grouping += @{Name = 'ResourceType'; Type = 'Dimension' }
        $Grouping += @{Name = 'ResourceGroup'; Type = 'Dimension' }
        $Grouping += @{Name = 'ResourceLocation'; Type = 'Dimension' }
        $Grouping += @{Name = 'ServiceName'; Type = 'Dimension' }

        $MHash = @{totalCost = @{name = "PreTaxCost"; function = "Sum" } }

        if ($Days -ge 365) {
            $StartDate = Get-date -Year $EndDate.AddYears(-1).Year -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 1
            $EndDate = Get-Date -Year $StartDate.Year -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59 -Millisecond 0
        }
        else {
            $StartDate = (Get-Date -Day 1).AddMonths(-2)
        }

        $Result = Foreach ($Subscription in $Subscriptions) {
            $SubId = $Subscription.id
            $SubName = $Subscription.name
            $Scope = ('/subscriptions/' + $SubId + '/')
            $Costs = @()
            try {
                $Costs = Invoke-AzCostManagementQuery -Type ActualCost -Scope $Scope -Timeframe Custom -DatasetGranularity $Granularity -DatasetGrouping $Grouping -DatasetAggregation $MHash -TimePeriodFrom $StartDate -TimePeriodTo $EndDate -Debug:$false
            }
            catch {
                $Costs = @()
            }
            @{
                SubscriptionId   = $SubId
                SubscriptionName = $SubName
                CostData         = $Costs
            }
        }
        return $Result
    }

    # ---------------------------------------------------------------- comparison ----

    function Get-ScoutFlatMap {
        <#
            Flatten an arbitrary object graph into path -> scalar so two runs can be compared
            key BY KEY. Comparing counts, or a single whole-object JSON string, is the
            comparison that reports one useless "not equal" for any difference anywhere --
            or worse, passes while every field is wrong.
        #>
        param([Parameter(Mandatory)] [AllowNull()] $InputObject, [string] $Prefix = '')
        $map = [ordered]@{}
        if ($null -eq $InputObject) { $map[$Prefix] = '<null>'; return $map }
        if ($InputObject -is [string] -or $InputObject -is [bool] -or $InputObject -is [int] -or
            $InputObject -is [long] -or $InputObject -is [double] -or $InputObject -is [decimal] -or
            $InputObject -is [datetime]) {
            $map[$Prefix] = "$($InputObject.GetType().Name):$InputObject"
            return $map
        }
        if ($InputObject -is [System.Collections.IDictionary]) {
            foreach ($key in ($InputObject.Keys | Sort-Object)) {
                foreach ($entry in (Get-ScoutFlatMap -InputObject $InputObject[$key] -Prefix "$Prefix.$key").GetEnumerator()) {
                    $map[$entry.Key] = $entry.Value
                }
            }
            return $map
        }
        if ($InputObject -is [System.Collections.IEnumerable]) {
            $index = 0
            foreach ($item in $InputObject) {
                foreach ($entry in (Get-ScoutFlatMap -InputObject $item -Prefix "$Prefix[$index]").GetEnumerator()) {
                    $map[$entry.Key] = $entry.Value
                }
                $index++
            }
            $map["$Prefix.__count"] = $index
            return $map
        }
        foreach ($property in ($InputObject.PSObject.Properties | Sort-Object Name)) {
            foreach ($entry in (Get-ScoutFlatMap -InputObject $property.Value -Prefix "$Prefix.$($property.Name)").GetEnumerator()) {
                $map[$entry.Key] = $entry.Value
            }
        }
        return $map
    }

    function Compare-ScoutDataset {
        <#
            Returns a list of human-readable differences between two object graphs: keys
            present on one side only, then values that differ. Empty list == equivalent.
        #>
        param([AllowNull()] $Reference, [AllowNull()] $Actual)
        $refMap = Get-ScoutFlatMap -InputObject $Reference
        $actMap = Get-ScoutFlatMap -InputObject $Actual
        @(
            foreach ($key in $refMap.Keys) {
                if (-not $actMap.Contains($key)) { "MISSING from new path: $key (reference='$($refMap[$key])')" }
            }
            foreach ($key in $actMap.Keys) {
                if (-not $refMap.Contains($key)) { "EXTRA on new path: $key (new='$($actMap[$key])')" }
            }
            foreach ($key in $refMap.Keys) {
                if ($actMap.Contains($key) -and "$($refMap[$key])" -ne "$($actMap[$key])") {
                    "$key : reference='$($refMap[$key])' new='$($actMap[$key])'"
                }
            }
        )
    }
}

AfterAll {
    Remove-ScoutAzureStubs
}

# =====================================================================================
# GATE 1 — the new path is the executing one, proved statically
# =====================================================================================

Describe 'AB#5648 — the non-ARG collection cmdlets are reachable from src/collect only' {

    BeforeAll {
        $script:repo = Split-Path $PSScriptRoot -Parent

        function Get-ScoutCommandNode {
            <#
                AST command names, not raw text. The shims' comment-based help names the
                retired endpoints and cmdlets to explain what superseded them, and a comment
                is not a call site -- a grep-based version of this test fails on its own
                documentation.
            #>
            param([string[]] $Path, [string[]] $CommandName)
            Get-ChildItem -Path $Path -Recurse -Filter *.ps1 | ForEach-Object {
                $file = $_
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
                $names = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
                        ForEach-Object { $_.GetCommandName() } | Where-Object { $_ })
                foreach ($wanted in $CommandName) {
                    if ($names -contains $wanted) {
                        [pscustomobject]@{ File = $file.FullName.Replace($script:repo, '').TrimStart('\', '/'); Command = $wanted }
                    }
                }
            }
        }
    }

    It 'no file under Modules/ issues an ARM REST call any more (Get-AZSCAPIResources is a shim)' {
        # Get-AzAccessToken + Invoke-RestMethod were the whole of the retired v1 implementation.
        #
        # Two files under Modules/ still reach a REST service and are allowed to, because
        # neither is ARM and neither is served by Resource Graph or by src/collect: the Azure
        # DevOps extraction talks to dev.azure.com, and Invoke-AZSCGraphRequest talks to
        # Microsoft Graph. They are named individually rather than excluded by directory, so
        # adding a THIRD REST caller anywhere under Modules/ fails this test and has to be
        # argued for.
        $allowed = @(
            'src\Invoke-AZTIGraphRequest.ps1'
        )
        $hits = @(Get-ScoutCommandNode -Path (Join-Path $script:repo 'Modules') -CommandName 'Invoke-RestMethod', 'Get-AzAccessToken' |
                Where-Object { $_.File -notin $allowed })
        ($hits | ForEach-Object { "$($_.File) -> $($_.Command)" }) -join "`n" | Should -BeNullOrEmpty
    }

    It 'the deleted legacy wrappers are absent' {
        # Belt and braces on the allow-list above, and scoped to the four files this work
        # retired rather than to Modules/ as a whole -- the 176 collectors legitimately name
        # resource TYPES like 'microsoft.managedidentity/userassignedidentities', which are
        # Resource Graph type strings and not REST endpoints. What must be gone is URL
        # CONSTRUCTION: no management host literal may survive in a shim.
        $retired = @(
            'Modules/Private/Extraction/Get-AZTIAPIResources.ps1'
            'Modules/Private/Extraction/Get-AZTICostInventory.ps1'
            'Modules/Private/Extraction/ResourceDetails/Get-AZTIVMQuotas.ps1'
            'Modules/Private/Extraction/ResourceDetails/Get-AZTIVMSkuDetails.ps1'
        )
        foreach ($relative in $retired) {
            Test-Path (Join-Path $script:repo $relative) | Should -BeFalse
        }
    }

    It 'no file under Modules/ calls Get-AzVMUsage or Get-AzComputeResourceSku any more' {
        $hits = @(Get-ScoutCommandNode -Path (Join-Path $script:repo 'Modules') -CommandName 'Get-AzVMUsage', 'Get-AzComputeResourceSku')
        ($hits | ForEach-Object { "$($_.File) -> $($_.Command)" }) -join "`n" | Should -BeNullOrEmpty
    }

    It 'no file under Modules/ calls Invoke-AzCostManagementQuery any more' {
        $hits = @(Get-ScoutCommandNode -Path (Join-Path $script:repo 'Modules') -CommandName 'Invoke-AzCostManagementQuery')
        ($hits | ForEach-Object { "$($_.File) -> $($_.Command)" }) -join "`n" | Should -BeNullOrEmpty
    }

    It 'each ARM/compute/cost cmdlet has one owning src/collect implementation' {
        $expected = @{
            'Invoke-RestMethod'            = 'Get-ScoutApiResources.ps1'
            'Get-AzVMUsage'                = 'Get-ScoutVmQuotas.ps1'
            'Get-AzComputeResourceSku'     = 'Get-ScoutVmSkuDetails.ps1'
            'Invoke-AzCostManagementQuery' = 'Get-ScoutCostInventory.ps1'
        }
        foreach ($cmd in $expected.Keys) {
            $hits = @(Get-ScoutCommandNode -Path (Join-Path $script:repo 'src') -CommandName $cmd)
            $owned = @($hits | Where-Object { (Split-Path $_.File -Leaf) -eq $expected[$cmd] })
            $owned.Count | Should -Be 1 -Because "$cmd must have one owning call site in $($expected[$cmd])"
        }
    }

    It 'the extraction orchestrator calls src/collect directly' {
        $path = Join-Path $script:repo 'src/Start-AZTIExtractionOrchestration.ps1'
        $code = Get-Content -LiteralPath $path -Raw
        foreach ($command in 'Get-ScoutApiResources', 'Get-ScoutCostInventory', 'Get-ScoutVmQuotas', 'Get-ScoutVmSkuDetails') {
            $code | Should -Match $command
        }
    }
}

# =====================================================================================
# GATE 2 — equivalence, key by key, against the retired implementations
# =====================================================================================

Describe 'AB#5648 — API resources: the shim and the retired implementation agree' {

    BeforeEach { Install-ScoutAzureStubs }
    AfterEach { Remove-ScoutAzureStubs }

    It 'produces the same keys and the same values for every subscription' {
        $reference = Get-ReferenceApiResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false
        $actual = Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null

        $differences = Compare-ScoutDataset -Reference $reference -Actual $actual
        $differences -join "`n" | Should -BeNullOrEmpty
    }

    It 'produces the same result with -SkipPolicy, including the empty-string Policy fields' {
        $reference = Get-ReferenceApiResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $true
        $actual = Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $true 6>$null

        $differences = Compare-ScoutDataset -Reference $reference -Actual $actual
        $differences -join "`n" | Should -BeNullOrEmpty

        # And the three Policy REST calls really were not issued.
        @($script:restCalls | Where-Object { $_ -match 'policy' }).Count | Should -Be 0
    }

    It 'still returns hashtable elements, which is what Get-AZSCCollectedValue reads' {
        # Start-AZSCExtractionOrchestration reads these results through
        # Get-AZSCCollectedValue, whose IDictionary branch is what has always run for them.
        # src/collect emits [pscustomobject]; if the shim stopped converting, the OTHER branch
        # would run and nothing would break loudly -- it would just quietly diverge.
        $actual = @(Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null)
        $actual.Count | Should -Be 2
        $actual[0] -is [System.Collections.IDictionary] | Should -BeTrue
        $actual[0].Keys | Should -Contain 'ReservationRecomen'
        $actual[0].Keys | Should -Contain 'PolicyAssign'
        $actual[0].Keys | Should -Contain 'PolicyDef'
        $actual[0].Keys | Should -Contain 'PolicySetDef'
    }

    It 'issues the same URLs, in the same order, as the retired implementation' {
        Get-ReferenceApiResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false | Out-Null
        $referenceCalls = @($script:restCalls)

        Install-ScoutAzureStubs
        Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null | Out-Null
        $actualCalls = @($script:restCalls)

        # queryStartTime carries a timestamp computed at call time; normalise it away.
        $normalise = { param($c) $c -replace 'queryStartTime=.*$', 'queryStartTime=<now-6m>' }

        # DELIBERATE DIVERGENCE (AB#6801): the current implementation issues one call the retired
        # v1 never did -- `Microsoft.Edge/sites`, the re-sourced Hybrid/ArcSites collector. The
        # retired implementation predates that resource type entirely, so byte-equality against it
        # is not the contract any more. Drop that one call and assert the rest still matches in
        # order, which is what this gate actually protects: no OTHER call was added, removed or
        # reordered while ArcSites was being wired in.
        $arcSites = @($actualCalls | Where-Object { $_ -match 'Microsoft\.Edge/sites' })
        $arcSites.Count | Should -Be @($script:Subs).Count -Because 'ArcSites is issued exactly once per subscription'

        $comparableActual = @($actualCalls | Where-Object { $_ -notmatch 'Microsoft\.Edge/sites' })
        @($referenceCalls | ForEach-Object { & $normalise $_ }) -join "`n" |
            Should -Be (@($comparableActual | ForEach-Object { & $normalise $_ }) -join "`n")
    }

    It 'degrades one failing endpoint to $null for that subscription only, exactly as v1 did' {
        Install-ScoutAzureStubs -FailAdvisorForSub2
        $reference = Get-ReferenceApiResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false

        Install-ScoutAzureStubs -FailAdvisorForSub2
        $actual = Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null

        (Compare-ScoutDataset -Reference $reference -Actual $actual) -join "`n" | Should -BeNullOrEmpty
        @($actual)[1].AdvisorScore | Should -BeNullOrEmpty
        @($actual)[0].AdvisorScore | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unknown Azure environment before an ARM request is made' {
        { Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureGermanCloud' -SkipPolicy $false 6>$null } |
            Should -Throw
        $script:restCalls.Count | Should -Be 0
    }

    It 'returns nothing, without throwing, for an empty subscription list' {
        { Get-AZSCAPIResources -Subscriptions @() -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null } |
            Should -Not -Throw
        $result = Get-AZSCAPIResources -Subscriptions @() -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null
        $result | Should -BeNullOrEmpty
    }

    It 'DELIBERATE DIVERGENCE: a failed policyStates call no longer discards the definition lists' {
        # v1 wrapped all three Policy calls in ONE try/catch, so a denial on the first --
        # policyStates/summarize, the one most often denied -- threw away two definition lists
        # that were never even attempted. That is the AB#5636 defect class: one optional
        # dataset failing must not destroy its neighbours. This asserts the improvement rather
        # than letting the equivalence test above quietly enforce the old behaviour.
        Install-ScoutAzureStubs -FailPolicyForSub2
        $reference = Get-ReferenceApiResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false

        Install-ScoutAzureStubs -FailPolicyForSub2
        $actual = Get-AZSCAPIResources -Subscriptions $script:Subs -AzureEnvironment 'AzureCloud' -SkipPolicy $false 6>$null

        # v1: all three lost for sub-2.
        @($reference)[1].PolicyAssign | Should -BeNullOrEmpty
        @($reference)[1].PolicySetDef | Should -BeNullOrEmpty
        @($reference)[1].PolicyDef | Should -BeNullOrEmpty

        # new: only the one that actually failed is lost.
        @($actual)[1].PolicyAssign | Should -BeNullOrEmpty
        @($actual)[1].PolicySetDef | Should -Not -BeNullOrEmpty
        @($actual)[1].PolicyDef | Should -Not -BeNullOrEmpty

        # The untouched subscription remains populated on the direct v3 path.
        @($actual)[0].PolicyAssign | Should -Not -BeNullOrEmpty
    }
}

Describe 'AB#5648 — VM quotas: the shim and the retired implementation agree' {

    BeforeEach { Install-ScoutAzureStubs }
    AfterEach { Remove-ScoutAzureStubs }

    It 'produces the same envelope, the same pairs and the same quota rows' {
        $resources = Get-FixtureMixedResources
        $reference = Get-ReferenceVmQuotas -Subscriptions $script:Subs -Resources $resources
        $actual = Get-AZSCVMQuotas -Subscriptions $script:Subs -Resources $resources

        (Compare-ScoutDataset -Reference $reference -Actual $actual) -join "`n" | Should -BeNullOrEmpty
        $actual.type | Should -Be 'AZSC/VM/Quotas'
    }

    It 'queries the same (subscription, location) pairs, in the same order' {
        $resources = Get-FixtureMixedResources
        Get-ReferenceVmQuotas -Subscriptions $script:Subs -Resources $resources | Out-Null
        $referencePairs = @($script:vmUsageCalls)

        Install-ScoutAzureStubs
        Get-AZSCVMQuotas -Subscriptions $script:Subs -Resources $resources | Out-Null
        @($script:vmUsageCalls) -join ',' | Should -Be ($referencePairs -join ',')

        # And it really did target only where VMs live -- not every Azure region.
        $referencePairs -join ',' | Should -Be 'eastus,westus,eastus'
    }

    It 'survives the mixed array that used to collect NO quota for ANY subscription (AB#5633)' {
        # The regression this guards is not "one row is skipped" -- a bare $_.subscriptionId on
        # a REST row aborts the PIPELINE, so every subscription lost its quota, not just one.
        { Get-AZSCVMQuotas -Subscriptions $script:Subs -Resources (Get-FixtureMixedResources) } | Should -Not -Throw
        @((Get-AZSCVMQuotas -Subscriptions $script:Subs -Resources (Get-FixtureMixedResources)).properties).Count | Should -Be 3
    }

    It 'restores the caller original subscription context' {
        $restored = [System.Collections.Generic.List[string]]::new()
        # Record BOTH spellings. Get-ScoutVmQuotas restores with `-Subscription <id>`, which is
        # the parameter Az actually exposes (it takes a name OR an id); a stub that watched only
        # -SubscriptionId saw nothing and reported "never restored" against correct code. The
        # sweep itself also calls -Subscription per subscription, so this list holds the visited
        # subscriptions followed by the restored one -- 'original-sub' being present is the
        # contract, not the list being a single element.
        function global:Set-AzContext {
            param($Subscription, $SubscriptionId, $Tenant, $ErrorAction, $WarningAction, $InformationAction, $Debug)
            if ($SubscriptionId) { $restored.Add([string]$SubscriptionId) }
            elseif ($Subscription) { $restored.Add([string]$Subscription) }
        }
        Get-AZSCVMQuotas -Subscriptions $script:Subs -Resources (Get-FixtureMixedResources) | Out-Null
        $restored | Should -Contain 'original-sub'
    }

    It 'returns the typed envelope with no properties for an empty subscription list' {
        $result = Get-AZSCVMQuotas -Subscriptions @() -Resources (Get-FixtureMixedResources)
        $result.type | Should -Be 'AZSC/VM/Quotas'
        @($result.properties).Count | Should -Be 0
    }
}

Describe 'AB#5648 — VM SKU details: the shim and the retired implementation agree' {

    BeforeEach { Install-ScoutAzureStubs }
    AfterEach { Remove-ScoutAzureStubs }

    It 'produces the same envelope, the same locations and the same SKU rows' {
        $resources = Get-FixtureMixedResources
        $reference = Get-ReferenceVmSkuDetails -Resources $resources
        $actual = Get-AZSCVMSkuDetails -Resources $resources

        (Compare-ScoutDataset -Reference $reference -Actual $actual) -join "`n" | Should -BeNullOrEmpty
        $actual.type | Should -Be 'AZSC/VM/SKU'
    }

    It 'queries the same distinct locations, in the same order' {
        $resources = Get-FixtureMixedResources
        Get-ReferenceVmSkuDetails -Resources $resources | Out-Null
        $referenceLocations = @($script:skuCalls)

        Install-ScoutAzureStubs
        Get-AZSCVMSkuDetails -Resources $resources | Out-Null
        @($script:skuCalls) -join ',' | Should -Be ($referenceLocations -join ',')
        $referenceLocations -join ',' | Should -Be 'eastus,westus'
    }

    It 'survives a resource array with no VMs at all' {
        $result = Get-AZSCVMSkuDetails -Resources @([pscustomobject]@{ id = '/kv1'; type = 'microsoft.keyvault/vaults' })
        $result.type | Should -Be 'AZSC/VM/SKU'
        @($result.properties).Count | Should -Be 0
        $script:skuCalls.Count | Should -Be 0
    }
}

Describe 'AB#5648 — cost inventory: the shim and the retired implementation agree' {

    BeforeEach { Install-ScoutAzureStubs }
    AfterEach { Remove-ScoutAzureStubs }

    It 'produces the same rows and the same cost data on the success path' {
        $reference = Get-ReferenceCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly'
        $actual = Get-AZSCCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly'

        (Compare-ScoutDataset -Reference $reference -Actual $actual) -join "`n" | Should -BeNullOrEmpty
    }

    It 'queries the same scope, granularity and date range' {
        Get-ReferenceCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly' | Out-Null
        $referenceQueries = @($script:costCalls)

        Install-ScoutAzureStubs
        Get-AZSCCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly' | Out-Null
        @($script:costCalls) -join "`n" | Should -Be ($referenceQueries -join "`n")
    }

    It 'switches to the full previous calendar year at -Days 365, exactly as v1 did' {
        Get-ReferenceCostInventory -Subscriptions @($script:Subs[0]) -Days 365 -Granularity 'Monthly' | Out-Null
        $referenceQueries = @($script:costCalls)

        Install-ScoutAzureStubs
        Get-AZSCCostInventory -Subscriptions @($script:Subs[0]) -Days 365 -Granularity 'Monthly' | Out-Null
        @($script:costCalls) -join "`n" | Should -Be ($referenceQueries -join "`n")
        $referenceQueries[0] | Should -Match '-01-01\|.*-12-31$'
    }

    It 'still returns hashtable elements, which is the shape that has shipped' {
        $actual = @(Get-AZSCCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly')
        $actual.Count | Should -Be 2
        $actual[0] -is [System.Collections.IDictionary] | Should -BeTrue
        $actual[0].Keys | Should -Contain 'SubscriptionId'
        $actual[0].Keys | Should -Contain 'SubscriptionName'
        $actual[0].Keys | Should -Contain 'CostData'
    }

    It 'never throws and never returns $null CostData when Cost Management fails (AB#5636)' {
        function global:Invoke-AzCostManagementQuery {
            param($Type, $Scope, $Timeframe, $DatasetGranularity, $DatasetGrouping,
                $DatasetAggregation, $TimePeriodFrom, $TimePeriodTo, $ErrorAction, $Debug)
            throw 'Subscription is not enrolled for Cost Management'
        }
        { Get-AZSCCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly' -WarningAction SilentlyContinue } |
            Should -Not -Throw
        $result = @(Get-AZSCCostInventory -Subscriptions $script:Subs -Days 60 -Granularity 'Monthly' -WarningAction SilentlyContinue)
        $result.Count | Should -Be 2
        # NOT -Not -BeNullOrEmpty: @() IS empty, and empty is the correct answer here. The
        # guarantee is that it is an empty COLLECTION and never $null, so a caller's
        # .Count under StrictMode is safe.
        ($null -eq $result[0].CostData) | Should -BeFalse
        @($result[0].CostData).Count | Should -Be 0
        @($result[1].CostData).Count | Should -Be 0
    }

    It 'returns nothing, without throwing, for an empty subscription list' {
        { Get-AZSCCostInventory -Subscriptions @() -Days 60 -Granularity 'Monthly' } | Should -Not -Throw
        $result = Get-AZSCCostInventory -Subscriptions @() -Days 60 -Granularity 'Monthly'
        $result | Should -BeNullOrEmpty
    }
}
