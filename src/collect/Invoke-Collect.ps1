#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Produce the normalized collect.json the assessment rules evaluate against.

.DESCRIPTION
    Resolves the discovery -> assessment data-shape gap (AB#5081, AB#5082). The
    existing inventory modules emit flat, Excel-oriented rows; the rule engine
    needs a nested object with SCALAR fields (so rule JSONPath never has to use
    `.length` inside a filter, which Newtonsoft does not support — AB#5083).

    This adapter runs read-only Azure Resource Graph queries and shapes the
    result into the canonical contract below. Ingestors (AzGovViz, Advisor)
    enrich `governance` / `advisor` afterward.

    Canonical shape (top-level keys the rules query):
        subscriptions[], tags[]
        networking { virtualNetworks[{name,peeringCount,ddosEnabled}], subnets[{ipUtilizationPct}],
                     azureFirewalls[], firewallPolicyRuleGroups[{policyName,priority,ruleCollectionCount,ruleCount,parseError}],
                     nsgPublicInbound[], privateDnsZones[], vpnGateways[],
                     privateEndpoints[{targetResourceId,targetProvider,targetType}] }
        compute    { virtualMachines[{name,zoneRedundant,zoneEligible}] }
        management { recoveryVaults[{backupItems[]}], deployments[],
                     logAnalyticsWorkspaces[{retentionInDays}] }
        security   { defenderPlans[] }
        governance { managementGroups[], policyAssignments[], roleAssignments[], budgets[],
                     resourceLocks[], pimEligibility[], classicAdministrators[] }  (filled by the native Governance ingestor, Import-Governance)
        costCleanup { orphanedDisks[], orphanedPips[] }
        opsPosture  { diagnosticCoverage[{type,coveragePct}] }
        domains     { storage{storageAccounts[{networkDefaultDeny}]},
                      databases{sqlServers[],sqlDatabases[],sqlDefenderPricing[{pricingTier}]},
                      web{webApps[{vnetIntegrated,customDomainBound}]},
                      containers{aksClusters[{networkPolicyEnabled,aadIntegrated,allPoolsZoned}],
                                 containerRegistries[]},
                      security{keyVaults[]},
                      ai{cognitiveAccounts[{identityType,cmkEnabled}]},
                      hybrid{arcServers[], arcExtensions[{machineId,extensionType}],
                             azureLocalClusters[{connectivityStatus}]},
                      integration{eventHubNamespaces[{autoInflateEnabled}], apiManagement[],
                                  serviceBusNamespaces[{publicAccess}]},
                      iot{iotHubs[{disableLocalAuth}]},
                      analytics{synapseWorkspaces[{managedVnetEnabled}], purviewAccounts[]} }   (per-category scalars, Epic AB#5056)
        advisor[]                                                                   (filled by ingest)

    Read-only throughout.

.NOTES
    Tracks ADO AB#5081, AB#5082 (Feature AB#5024). Every scalar the rules need
    (peeringCount, zoneRedundant, ipUtilizationPct, coveragePct) is computed here
    in KQL so no rule has to compute array lengths at evaluation time.

    AB#5057 follow-up: extended per-domain collectors so previously-manual CAF/WAF
    rules can assert against real ARG scalars instead of a human review. Every new
    field below was verified against a documented ARM property (or, for
    Microsoft.AzureStackHCI/clusters, the SDK-level enum) via Microsoft Learn before
    being added — sub-resources that Resource Graph does not index (SQL firewall
    rules/auditing/TDE, storage blob-service/management-policy settings, Synapse
    firewall rules, DPS enrollment groups) were deliberately left out; those rules
    stay manual.

    AB#5068/5071/5075 follow-up (Databases/Analytics/IoT rule-depth pass): added
    `sqlDefenderPricing` (Microsoft.Security/pricings, "SqlServers" plan — queried
    from the `SecurityResources` ARG table, not the default `Resources` table),
    `purviewAccounts` (Microsoft.Purview/accounts), and `iotHubs.disableLocalAuth`
    (documented IotHubProperties field). Each was confirmed present in the Azure
    Resource Graph supported-tables-and-resource-types reference before being added.
    Still deliberately NOT ARG-collectable (confirmed absent from that same
    reference) and left manual: SQL TDE/auditing/firewall-rules child resources,
    Data Factory/Synapse pipeline linked-service definitions, Synapse workspace
    firewall rules, DPS enrollment groups, per-device IoT credential type, and any
    metric- or Monitor-backed signal (IoT Hub throughput right-sizing).

    Parameter wiring (this pass):
      - `-ManagementGroupId`, when supplied, is passed as `-ManagementGroup` to
        every `Search-AzGraph` call so Collect is actually scoped, not tenant-wide.
        Omitted entirely when not supplied (preserves current tenant-wide behavior).
      - `-Categories` now really filters which ARG queries run. Each query below is
        tagged in `$queryCategories` with the manifest `Collect` category name(s)
        whose rule files reference its output path (cross-checked against every
        `src/assess/rules/*.yaml` `query:` field) — including cross-domain
        references (e.g. `waf.security` needs `domains.databases.sqlServers`, so
        `sqlServers` is tagged both `Databases` and `Security`). `subscriptions` is
        always collected (base data every rule set / the canonical shape needs). A
        `'*'` entry, an empty list, or omitting `-Categories` runs every query
        (unchanged full-collect behavior).

    Collector/pipeline resilience (AB#397/398/399/400/401):
      - `subscriptions` is always collected FIRST (regardless of hashtable
        enumeration order) so its subscription-id list is available as a fallback
        scope for every other query.
      - AB#397: if a tenant/MG-wide batch query throws (DNS blip, expired token,
        any other transient ARG/ARM error), it is retried ONE SUBSCRIPTION AT A
        TIME using the subscription list above. A subscription that still fails on
        retry logs a warning naming that subscription and is skipped — the OTHER
        subscriptions' rows for that same query are still collected and returned.
        Only a query that fails with no subscription list available at all (i.e.
        the `subscriptions` query itself failed) degrades to an empty result for
        that query, same as before this change.
      - AB#398: an `AuthorizationFailed` error on a query scoped to
        `-ManagementGroupId` gets a specific, actionable warning naming the
        management-group Reader-role requirement, instead of a bare ARG exception.
      - AB#399: a small set of documented, known-false ARG/ARM errors (a resource
        provider reported as "not registered" on a subscription that Resource Graph
        can still query successfully) are logged at Verbose and treated as
        non-errors — no per-subscription retry, no warning noise.
      - AB#400: `firewallPolicyRuleGroups`' nested rule-collection/rule structure is
        walked in PowerShell (not KQL) with a try/catch PER GROUP — one malformed
        group is recorded with `parseError` set and the run continues; it never
        blanks out the other, well-formed rule-collection groups in the same run.
      - AB#401: if literally every collected query returns zero rows, a diagnostic
        warning is emitted suggesting the likely causes (missing Reader RBAC, wrong
        subscription/tenant context, an empty/inaccessible `-ManagementGroupId`, or
        a `-Categories` filter that matched nothing) instead of silently handing an
        empty dataset to the report layer.
      - AB#405: when `Write-ScoutProgress` (src/Write-ScoutProgress.ps1) is loaded in
        the calling session, each query reports phase progress through it. The call
        is guarded by `Get-Command` so Collect has zero hard dependency on that
        helper — a session that never loaded it behaves exactly as before.
#>
function Invoke-Collect {
    [CmdletBinding()]
    param(
        [string[]] $Categories = @('*'),
        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]   $Scope = 'All',
        [string]   $ManagementGroupId
    )
    Import-Module Az.ResourceGraph -ErrorAction Stop

    # ---- read-only KQL producing SCALAR fields the rules filter on ----
    $q = @{
        subscriptions = @'
resourcecontainers
| where type =~ "microsoft.resources/subscriptions"
| project id = subscriptionId, name, state = tostring(properties.state), tags
'@
        virtualNetworks = @'
resources
| where type =~ "microsoft.network/virtualnetworks"
| extend peeringCount = array_length(properties.virtualNetworkPeerings)
| extend ddosEnabled  = tobool(properties.enableDdosProtection)
| project name, resourceGroup, subscriptionId, peeringCount, ddosEnabled
'@
        subnets = @'
resources
| where type =~ "microsoft.network/virtualnetworks"
| mv-expand subnet = properties.subnets
| extend prefix = tostring(subnet.properties.addressPrefix)
| extend total = toint(exp2(32 - toint(split(prefix,"/")[1]))) - 5
| extend used  = array_length(subnet.properties.ipConfigurations)
| project vnet = name, subnet = tostring(subnet.name), prefix, total, used,
          ipUtilizationPct = iff(total > 0, round(todouble(used) / total * 100, 1), todouble(0))
'@
        azureFirewalls = @'
resources | where type =~ "microsoft.network/azurefirewalls"
| project name, resourceGroup, subscriptionId, sku = tostring(properties.sku.name)
'@
        # AB#400: firewall policy rule-collection groups. The nested rule-collection/rule
        # array is intentionally left as a dynamic column here (`ruleCollections`) rather
        # than walked with KQL mv-expand — the PowerShell-side parse below handles a
        # malformed/unexpected group's shape per-group instead of per-run (see NOTES).
        firewallPolicyRuleGroups = @'
resources
| where type =~ "microsoft.network/firewallpolicies/rulecollectiongroups"
| extend policyName = tostring(split(id, "/")[8])
| project name, resourceGroup, subscriptionId, policyName,
          priority = toint(properties.priority), ruleCollections = properties.ruleCollections
'@
        vpnGateways = @'
resources | where type =~ "microsoft.network/virtualnetworkgateways"
| project name, resourceGroup, gatewayType = tostring(properties.gatewayType),
          sku = tostring(properties.sku.name), activeActive = tobool(properties.activeActive),
          bgp = tobool(properties.enableBgp)
'@
        privateEndpoints = @'
resources | where type =~ "microsoft.network/privateendpoints"
// AB#5057: expose the linked-service target so per-domain rules (CAF-AI-04,
// CAF-IOT-05, ...) can test "does this account/hub have a dedicated PE" without
// a full cross-table join. ARG mv-expand only supports kind=bag|array (no outer),
// so take the first connection instead — preserves endpoints with no connection
// row, keeping the plain existence-count rules ($.networking.privateEndpoints[*])
// unaffected. PEs carry exactly one privateLinkServiceConnection in practice.
| extend conn = coalesce(properties.privateLinkServiceConnections[0], properties.manualPrivateLinkServiceConnections[0])
| extend targetResourceId = tostring(conn.properties.privateLinkServiceId)
| extend targetProvider = tolower(tostring(split(targetResourceId, "/")[6]))
| extend targetType = tolower(tostring(split(targetResourceId, "/")[7]))
| project name, resourceGroup, subscriptionId, targetResourceId, targetProvider, targetType
'@
        privateDnsZones = @'
resources | where type =~ "microsoft.network/privatednszones"
| project name, resourceGroup, subscriptionId
'@
        nsgPublicInbound = @'
resources
| where type =~ "microsoft.network/networksecuritygroups"
| mv-expand rule = properties.securityRules
| where rule.properties.access =~ "Allow" and rule.properties.direction =~ "Inbound"
      and (rule.properties.sourceAddressPrefix in ("*","0.0.0.0/0","Internet"))
| project nsg = name, resourceGroup, rule = tostring(rule.name),
          port = tostring(rule.properties.destinationPortRange)
'@
        virtualMachines = @'
resources
| where type =~ "microsoft.compute/virtualmachines"
| extend zoneCount = array_length(zones)
| extend zoneRedundant = iff(zoneCount > 0, true, false)
// Region-level AZ availability (documented, stable list) — a coarse but honest
// zone-eligibility signal. SKU-level zone capability needs a join against the
// resourceSkus table, deliberately deferred: it varies per region/SKU/quota
// and would need periodic refresh to stay accurate (AB#5086).
| extend zoneEligible = location in (
    "eastus","eastus2","westus2","westus3","centralus","southcentralus",
    "northeurope","westeurope","uksouth","francecentral","germanywestcentral",
    "switzerlandnorth","norwayeast","swedencentral","southeastasia","eastasia",
    "australiaeast","japaneast","koreacentral","centralindia","canadacentral",
    "brazilsouth","uaenorth","southafricanorth"
  )
| project name, resourceGroup, subscriptionId, zoneRedundant, zoneEligible,
          size = tostring(properties.hardwareProfile.vmSize)
'@
        orphanedDisks = @'
resources | where type =~ "microsoft.compute/disks" and properties.diskState =~ "Unattached"
| project name, resourceGroup, location, sku = tostring(sku.name), sizeGb = toint(properties.diskSizeGB)
'@
        orphanedPips = @'
resources | where type =~ "microsoft.network/publicipaddresses" and isnull(properties.ipConfiguration)
| project name, resourceGroup, location, sku = tostring(sku.name)
'@
        diagnosticCoverage = @'
resources
| extend hasDiag = iff(isnotnull(properties.diagnosticSettings), true, false)
| summarize total = count(), withDiag = countif(hasDiag) by type
| extend coveragePct = iff(total > 0, round(todouble(withDiag)/total*100,1), todouble(0))
| project type, total, withDiag, coveragePct
'@
        deployments = @'
resourcecontainers
| where type =~ "microsoft.resources/subscriptions/resourcegroups"
| project name, subscriptionId
'@
        storageAccounts = @'
resources | where type =~ "microsoft.storage/storageaccounts"
| extend publicAccess = tobool(properties.allowBlobPublicAccess)
| extend httpsOnly = tobool(properties.supportsHttpsTrafficOnly)
| extend minTls = tostring(properties.minimumTlsVersion)
// properties.networkAcls is on the storage account resource itself (not a
// sub-resource), so it's safe to project directly — CAF-STO-05 (AB#5057).
| extend networkDefaultDeny = tostring(properties.networkAcls.defaultAction) =~ "Deny"
| project name, resourceGroup, sku = tostring(sku.name), publicAccess, httpsOnly, minTls, networkDefaultDeny
'@
        sqlDatabases = @'
resources | where type =~ "microsoft.sql/servers/databases"
| extend zoneRedundant = tobool(properties.zoneRedundant)
| project name, resourceGroup, zoneRedundant, tier = tostring(sku.tier)
'@
        sqlServers = @'
resources | where type =~ "microsoft.sql/servers"
| extend publicNetworkAccess = tostring(properties.publicNetworkAccess)
| project name, resourceGroup, publicNetworkAccess
'@
        # AB#5068: Microsoft.Security/pricings ("SqlServers" plan) is the subscription-scoped
        # Defender for SQL / Advanced Threat Protection toggle and IS indexed by Resource
        # Graph — under the SecurityResources table, not the default Resources table
        # (confirmed via the ARG supported-tables-and-resource-types reference). This is a
        # coarse, subscription-wide signal (same tradeoff as security.defenderPlans /
        # CAF-SEC-02), not a per-server property — Microsoft.Sql/servers/auditingSettings and
        # .../extendedAuditingSettings (the "auditing" half of the old combined rule) are NOT
        # in that reference list, so they stay manual (CAF-DB-07).
        sqlDefenderPricing = @'
SecurityResources
| where type =~ "microsoft.security/pricings" and name =~ "sqlservers"
| project subscriptionId, name, pricingTier = tostring(properties.pricingTier)
'@
        webApps = @'
resources | where type =~ "microsoft.web/sites"
| extend httpsOnly = tobool(properties.httpsOnly)
| extend minTls = tostring(properties.siteConfig.minTlsVersion)
// virtualNetworkSubnetId and hostNameSslStates are top-level site properties
// (NOT part of the siteConfig summary object, which Resource Graph does not
// fully expand) — CAF-WEB-04/05 (AB#5057). customDomainBound is a coarse
// signal (more than the always-present *.azurewebsites.net entry), same
// tradeoff as the VM zoneEligible heuristic below.
| extend vnetIntegrated = isnotempty(tostring(properties.virtualNetworkSubnetId))
| extend customDomainBound = array_length(properties.hostNameSslStates) > 1
| project name, resourceGroup, httpsOnly, minTls, vnetIntegrated, customDomainBound
'@
        aksClusters = @'
resources | where type =~ "microsoft.containerservice/managedclusters"
| extend k8sVersion = tostring(properties.kubernetesVersion)
| extend privateCluster = tobool(properties.apiServerAccessProfile.enablePrivateCluster)
| extend rbacEnabled = tobool(properties.enableRBAC)
| extend networkPolicyEnabled = isnotempty(tostring(properties.networkProfile.networkPolicy))
| extend aadIntegrated = isnotnull(properties.aadProfile)
// agentPoolProfiles is an array, so per-pool zone spread needs mv-expand +
// summarize back to one row per cluster — CAF-CON-05 (AB#5057).
| mv-expand pool = properties.agentPoolProfiles
| extend poolZoned = array_length(pool.availabilityZones) > 0
| summarize totalPools = count(), zonedPools = countif(poolZoned)
    by name, resourceGroup, k8sVersion, privateCluster, rbacEnabled, networkPolicyEnabled, aadIntegrated
| extend allPoolsZoned = zonedPools == totalPools
| project name, resourceGroup, k8sVersion, privateCluster, rbacEnabled, networkPolicyEnabled, aadIntegrated, allPoolsZoned
'@
        containerRegistries = @'
resources | where type =~ "microsoft.containerregistry/registries"
| extend adminEnabled = tobool(properties.adminUserEnabled)
| extend publicAccess = tostring(properties.publicNetworkAccess)
| project name, resourceGroup, sku = tostring(sku.name), adminEnabled, publicAccess
'@
        keyVaults = @'
resources | where type =~ "microsoft.keyvault/vaults"
| extend softDelete = tobool(properties.enableSoftDelete)
| extend purgeProtection = tobool(properties.enablePurgeProtection)
| project name, resourceGroup, softDelete, purgeProtection
'@
        cognitiveAccounts = @'
resources | where type =~ "microsoft.cognitiveservices/accounts"
| extend publicAccess = tostring(properties.publicNetworkAccess)
// `kind` is a reserved Kusto keyword — it can be neither an extend target nor a
// project alias; read the built-in column via ['kind'] and expose it as accountKind.
| extend accountKind = tostring(['kind'])
// `identity` is a top-level Resource Graph column (not under properties) —
// CAF-AI-03 (AB#5057). properties.encryption.keySource is the standard
// BYOK/CMK marker used across RPs (matches EventHub/Synapse) — CAF-AI-05.
| extend identityType = tostring(identity.type)
| extend cmkEnabled = tostring(properties.encryption.keySource) =~ "Microsoft.KeyVault"
| project name, resourceGroup, accountKind, publicAccess, identityType, cmkEnabled
'@
        arcServers = @'
resources | where type =~ "microsoft.hybridcompute/machines"
| extend status = tostring(properties.status)
| project name, resourceGroup, status, agentVersion = tostring(properties.agentVersion)
'@
        eventHubNamespaces = @'
resources | where type =~ "microsoft.eventhub/namespaces"
| extend zoneRedundant = tobool(properties.zoneRedundant)
| extend publicAccess = tostring(properties.publicNetworkAccess)
// The ARM property is isAutoInflateEnabled, not autoInflateEnabled — CAF-INT-05 (AB#5057).
| extend autoInflateEnabled = tobool(properties.isAutoInflateEnabled)
| project name, resourceGroup, zoneRedundant, publicAccess, autoInflateEnabled
'@
        apiManagement = @'
resources | where type =~ "microsoft.apimanagement/service"
| extend virtualNetworkType = tostring(properties.virtualNetworkType)
| project name, resourceGroup, sku = tostring(sku.name), virtualNetworkType
'@
        serviceBusNamespaces = @'
resources | where type =~ "microsoft.servicebus/namespaces"
| extend publicAccess = tostring(properties.publicNetworkAccess)
| project name, resourceGroup, publicAccess
'@
        iotHubs = @'
resources | where type =~ "microsoft.devices/iothubs"
| extend publicAccess = tostring(properties.publicNetworkAccess)
// disableLocalAuth (documented IotHubProperties field) is true when SAS
// tokens issued from the hub's own shared access policies are rejected,
// forcing Microsoft Entra ID + RBAC for service-API access — CAF-IOT-06
// (AB#5075). This is a hub-level *service-API* auth control, distinct from
// per-device X.509/TPM-vs-symmetric-key credential choice (CAF-IOT-02, still
// manual — that lives in the device registry, a data-plane store Resource
// Graph does not index).
| extend disableLocalAuth = tobool(properties.disableLocalAuth)
| project name, resourceGroup, sku = tostring(sku.name), publicAccess, disableLocalAuth
'@
        synapseWorkspaces = @'
resources | where type =~ "microsoft.synapse/workspaces"
| extend publicAccess = tostring(properties.publicNetworkAccess)
// properties.managedVirtualNetwork is "default" when the workspace-managed
// VNet is on, empty otherwise — a top-level workspace property, not a
// sub-resource — CAF-ANL-03 (AB#5057).
| extend managedVnetEnabled = isnotempty(tostring(properties.managedVirtualNetwork))
| project name, resourceGroup, publicAccess, managedVnetEnabled
'@
        # AB#5071: Microsoft.Purview/accounts IS indexed by Resource Graph (confirmed via the
        # ARG supported-tables-and-resource-types reference), unlike Data Factory/Synapse
        # pipeline linked services (CAF-ANL-04, still manual — linked services are a
        # data-plane sub-object of the factory/pipeline payload, not a distinct ARM child
        # resource) or Synapse workspace firewall rules (CAF-ANL-05, still manual — not in
        # that reference list either). Existence-only signal, same coarse tradeoff as the
        # VM zoneEligible / webApps customDomainBound heuristics above: a Purview account
        # existing is evidence a governance foundation is in place, not proof the whole
        # analytics estate is catalogued/classified — CAF-ANL-02.
        purviewAccounts = @'
resources | where type =~ "microsoft.purview/accounts"
| project name, resourceGroup, subscriptionId
'@
        arcExtensions = @'
resources | where type =~ "microsoft.hybridcompute/machines/extensions"
| extend extensionType = tostring(properties.type)
| extend machineId = tostring(split(id, "/extensions/")[0])
| project machineId, name, extensionType, resourceGroup
'@
        azureLocalClusters = @'
resources | where type =~ "microsoft.azurestackhci/clusters"
// connectivityStatus is the documented cluster-resource health enum
// (Connected/Disconnected/NotConnectedRecently/PartiallyConnected/
// NotYetRegistered/NotSpecified) — CAF-HYB-05 (AB#5057).
| extend connectivityStatus = tostring(properties.connectivityStatus)
| project name, resourceGroup, connectivityStatus
'@
        logAnalyticsWorkspaces = @'
resources | where type =~ "microsoft.operationalinsights/workspaces"
| extend retentionInDays = toint(properties.retentionInDays)
| project name, resourceGroup, retentionInDays
'@
    }

    # ---- category tagging (AB#5057 follow-up) ----
    # Which manifest `Collect` categories need each query's output, derived from
    # every rule file's `query:` JSONPath (see .NOTES). '*' means "always run"
    # regardless of the requested categories.
    $queryCategories = @{
        subscriptions       = @('*')
        virtualNetworks     = @('Networking')
        subnets             = @('Networking', 'Compute')
        azureFirewalls      = @('Networking')
        firewallPolicyRuleGroups = @('Networking', 'Security')
        vpnGateways         = @('Networking')
        # caf.security (CAF-SEC-03/06), caf.ai (CAF-AI-04), caf.iot (CAF-IOT-05)
        # all filter networking.privateEndpoints by target — those categories need
        # this query too, not just Networking.
        privateEndpoints    = @('Networking', 'Security', 'AI', 'IoT')
        privateDnsZones     = @('Networking', 'Security')
        nsgPublicInbound    = @('Networking', 'Security')
        virtualMachines     = @('Compute')
        # caf.billing (CAF-BIL-02/03) and waf.cost both need these under Management
        # and Compute/Cost respectively.
        orphanedDisks       = @('Compute', 'Cost', 'Management')
        orphanedPips        = @('Compute', 'Cost', 'Management')
        diagnosticCoverage  = @('Monitor', 'Management')
        deployments         = @('Monitor', 'Management')
        storageAccounts     = @('Storage')
        sqlDatabases        = @('Databases')
        # waf.security (WAF-SE-03) filters domains.databases.sqlServers too.
        sqlServers          = @('Databases', 'Security')
        sqlDefenderPricing  = @('Databases')
        webApps             = @('Web')
        aksClusters         = @('Containers')
        containerRegistries = @('Containers')
        keyVaults           = @('Security')
        cognitiveAccounts   = @('AI')
        arcServers          = @('Hybrid')
        arcExtensions       = @('Hybrid')
        azureLocalClusters  = @('Hybrid')
        eventHubNamespaces  = @('Integration')
        apiManagement       = @('Integration')
        serviceBusNamespaces = @('Integration')
        iotHubs             = @('IoT')
        synapseWorkspaces   = @('Analytics')
        purviewAccounts     = @('Analytics')
        logAnalyticsWorkspaces = @('Management', 'Monitor')
    }

    $runAllCategories = (-not $Categories) -or (@($Categories).Count -eq 0) -or ($Categories -contains '*')
    $selectedKeys = if ($runAllCategories) {
        $q.Keys
    }
    else {
        $q.Keys | Where-Object {
            $cats = $queryCategories[$_]
            $cats -and (($cats -contains '*') -or ($Categories | Where-Object { $cats -contains $_ }))
        }
    }

    function Invoke-Arg {
        param([string] $Query, [string] $SubscriptionId, [switch] $OmitManagementGroup)
        $rows = @(); $skip = 0
        do {
            # Search-AzGraph rejects -Skip 0 (ValidateRange minimum is 1) — omit it on the first page.
            $params = @{ Query = $Query; First = 1000; ErrorAction = 'Stop' }
            if ($skip -gt 0) { $params.Skip = $skip }
            # -ManagementGroup and -Subscription are DIFFERENT, mutually exclusive
            # Search-AzGraph parameter sets (ManagementGroupScopedQuery vs.
            # SubscriptionScopedQuery) — passing both throws an ambiguous-parameter-set
            # error, so a per-subscription call (below, AB#397) always omits
            # -ManagementGroup regardless of whether one was supplied for this run.
            if ($ManagementGroupId -and -not $OmitManagementGroup) { $params.ManagementGroup = $ManagementGroupId }
            if ($SubscriptionId) { $params.Subscription = @($SubscriptionId) }
            $batch = @(Search-AzGraph @params)
            $rows += $batch; $skip += 1000
        } while ($batch.Count -eq 1000)
        return , $rows
    }

    # A small set of ARG/ARM errors are documented, KNOWN FALSE POSITIVES — most
    # commonly a "resource provider not registered" condition reported for a
    # subscription that Resource Graph can (and does) still query successfully
    # (AB#399). These are noise, not a real collection gap: log at Verbose and move
    # on without a warning or a per-subscription retry.
    function Test-ScoutKnownNoiseError([string] $Message) {
        return [bool]($Message -match '(?i)resource provider.*not\s+registered' -or
                       $Message -match '(?i)MissingSubscriptionRegistration' -or
                       $Message -match '(?i)SubscriptionNotRegistered')
    }

    function Invoke-CollectQuery {
        param([string] $Key, [string] $Query, [string[]] $SubscriptionIds)
        try {
            return Invoke-Arg -Query $Query
        }
        catch {
            $errText = $_.Exception.Message

            # AB#399 — known noise: log at Verbose only, no retry, no warning.
            if (Test-ScoutKnownNoiseError $errText) {
                Write-Verbose "Invoke-Collect: query '$Key' hit the known false 'resource provider not registered' condition — ignoring (AB#399): $errText"
                # `return @()` (without the leading comma) gets pipeline-UNROLLED to
                # zero output objects -- the caller's `$r[$k] = Invoke-CollectQuery ...`
                # would capture $null instead of an empty array. The unary comma
                # prevents that (same idiom Invoke-Arg already uses for `$rows`).
                return , @()
            }

            # AB#398 — an AuthorizationFailed error on an MG-scoped query is almost
            # always a missing Reader assignment AT THE MANAGEMENT GROUP (a Reader
            # role at subscription scope alone does not satisfy an MG-scoped ARG
            # query), so surface that as an explicit, actionable hint.
            if ($ManagementGroupId -and $errText -match '(?i)AuthorizationFailed') {
                Write-Warning "Invoke-Collect: query '$Key' failed with AuthorizationFailed while scoped to management group '$ManagementGroupId'. Hint: assign the caller (user or service principal) the Reader role at the '$ManagementGroupId' management group scope — a Reader role assigned only at a subscription underneath it is not sufficient for a management-group-scoped Resource Graph query."
            }
            else {
                Write-Warning "Invoke-Collect: query '$Key' failed: $errText"
            }

            # AB#397 — fall back to one query per known subscription instead of losing
            # the whole dataset for this resource type: a single subscription with a
            # transient/DNS/token problem must not blank out every OTHER
            # subscription's data for the same query.
            if (-not $SubscriptionIds -or @($SubscriptionIds).Count -eq 0) { return , @() }

            $rows = @()
            foreach ($subId in $SubscriptionIds) {
                try { $rows += Invoke-Arg -Query $Query -SubscriptionId $subId -OmitManagementGroup }
                catch {
                    $subErrText = $_.Exception.Message
                    if (Test-ScoutKnownNoiseError $subErrText) {
                        Write-Verbose "Invoke-Collect: query '$Key' hit the known false 'resource provider not registered' condition for subscription '$subId' — ignoring (AB#399): $subErrText"
                        continue
                    }
                    Write-Warning "Invoke-Collect: query '$Key' failed for subscription '$subId' — skipping this subscription and continuing with the rest (AB#397): $subErrText"
                }
            }
            return , $rows
        }
    }

    $r = @{}

    # Always collect `subscriptions` first, regardless of hashtable enumeration
    # order, so its subscription-id list is available for the AB#397 per-subscription
    # fallback used by every OTHER query below.
    $subscriptionIds = @()
    if ($selectedKeys -contains 'subscriptions') {
        try {
            $r['subscriptions'] = Invoke-Arg -Query $q['subscriptions']
            $subscriptionIds = @($r['subscriptions'] | ForEach-Object {
                    if ($_ -and $_.PSObject.Properties['id']) { $_.id }
                } | Where-Object { $_ })
        }
        catch {
            Write-Warning "Invoke-Collect: query 'subscriptions' failed: $_ — the per-subscription retry (AB#397) is unavailable for the rest of this run because the subscription list itself could not be collected."
            $r['subscriptions'] = @()
        }
    }

    $progressAvailable = [bool](Get-Command Write-ScoutProgress -ErrorAction SilentlyContinue)
    $remainingKeys = @($q.Keys | Where-Object { $_ -ne 'subscriptions' })
    $queryIndex = 0
    foreach ($k in $remainingKeys) {
        $queryIndex++
        if ($selectedKeys -notcontains $k) { $r[$k] = @(); continue }
        if ($progressAvailable) {
            $pct = if (@($remainingKeys).Count -gt 0) { [Math]::Min(100, [Math]::Round(($queryIndex / @($remainingKeys).Count) * 100)) } else { -1 }
            try { Write-ScoutProgress -Activity 'Scout Collect' -Status "Querying: $k" -PercentComplete $pct -Id 1 }
            catch { Write-Verbose "Invoke-Collect: Write-ScoutProgress failed, continuing without progress UX: $_" }
        }
        $r[$k] = Invoke-CollectQuery -Key $k -Query $q[$k] -SubscriptionIds $subscriptionIds
    }
    if ($progressAvailable) {
        try { Write-ScoutProgress -Activity 'Scout Collect' -Id 1 -Completed }
        catch { Write-Verbose "Invoke-Collect: Write-ScoutProgress completion call failed: $_" }
    }

    # ---- firewall policy rule-collection group parsing (AB#400) ----
    # properties.ruleCollections is a nested dynamic array (rule collections -> rules)
    # that Resource Graph hands back as-is; walking it needs real conditional logic,
    # not just KQL projection, so the walk happens here in PowerShell. A single
    # malformed/unexpected-shape rule-collection group must not blank out every OTHER
    # (perfectly fine) group from the same run, so each row gets its own try/catch —
    # a parse error is logged per-group, not per-run, and collection continues with a
    # placeholder entry that records what happened via `parseError`.
    $firewallPolicyRuleGroups = @()
    foreach ($group in $r['firewallPolicyRuleGroups']) {
        if (-not $group) { continue }
        try {
            $ruleCollections = @($group.ruleCollections)
            $ruleCount = 0
            foreach ($rc in $ruleCollections) { $ruleCount += @($rc.rules).Count }
            $firewallPolicyRuleGroups += [pscustomobject]@{
                name                = $group.name
                resourceGroup       = $group.resourceGroup
                policyName          = $group.policyName
                priority            = $group.priority
                ruleCollectionCount = $ruleCollections.Count
                ruleCount           = $ruleCount
                parseError          = $null
            }
        }
        catch {
            Write-Warning "Invoke-Collect: firewall policy rule-collection group '$($group.name)' (policy '$($group.policyName)') failed to parse — skipping this group and continuing (AB#400): $($_.Exception.Message)"
            $firewallPolicyRuleGroups += [pscustomobject]@{
                name                = $group.name
                resourceGroup       = $group.resourceGroup
                policyName          = $group.policyName
                priority            = $group.priority
                ruleCollectionCount = 0
                ruleCount           = 0
                parseError          = $_.Exception.Message
            }
        }
    }

    # ---- empty-data guard (AB#401) ----
    # A collect that returns literally nothing across every requested query is a
    # strong signal something is mis-configured (missing Reader RBAC, the wrong
    # tenant/subscription selected in the current Az context, an empty or
    # inaccessible -ManagementGroupId, or a -Categories filter that matched nothing)
    # rather than a genuinely empty estate — surface a diagnostic hint instead of
    # silently handing an empty dataset to the assess/report layers.
    $totalRows = 0
    foreach ($k in $r.Keys) { $totalRows += @($r[$k]).Count }
    if ($totalRows -eq 0) {
        $scopeHint = if ($ManagementGroupId) { "management group '$ManagementGroupId'" } else { 'the current subscription/tenant context' }
        Write-Warning ("Invoke-Collect: no resources were returned for any collected query, scoped to {0}. This usually means (1) the signed-in identity is missing the Reader role at that scope, (2) the wrong tenant/subscription is selected in the current Az context, (3) -ManagementGroupId points at an empty or inaccessible management group, or (4) -Categories filtered out every query that would otherwise have run — verify RBAC and scope before treating this as a genuinely empty estate." -f $scopeHint)
    }

    # ---- unique tag-key/value aggregation across subscriptions (AB#367) ----
    # $r.subscriptions[*].tags is a per-subscription dynamic bag (the KQL `tags`
    # column deserializes to a PSCustomObject keyed by tag name, or $null when a
    # subscription has no tags). The old code just concatenated those raw bags
    # (`ForEach-Object { $_.tags }`), which duplicated a value every time two
    # subscriptions shared it and never actually rolled values up per key.
    # Aggregate into one entry per distinct tag KEY with the deduplicated, sorted
    # set of values seen for that key across every subscription instead.
    $tagValuesByKey = [ordered]@{}
    foreach ($sub in $r.subscriptions) {
        $bag = $sub.tags
        if ($null -eq $bag) { continue }
        foreach ($prop in $bag.PSObject.Properties) {
            $key = $prop.Name
            $value = $prop.Value
            if ($null -eq $value) { continue }
            if (-not $tagValuesByKey.Contains($key)) {
                $tagValuesByKey[$key] = [System.Collections.Generic.HashSet[string]]::new()
            }
            [void] $tagValuesByKey[$key].Add([string] $value)
        }
    }
    $tags = @(
        foreach ($key in ($tagValuesByKey.Keys | Sort-Object)) {
            [pscustomobject]@{
                key    = $key
                values = @($tagValuesByKey[$key] | Sort-Object)
            }
        }
    )

    # ---- shape into the canonical contract ----
    $collect = [pscustomobject]@{
        subscriptions = $r.subscriptions
        tags          = $tags
        networking    = [pscustomobject]@{
            virtualNetworks          = $r.virtualNetworks
            subnets                  = $r.subnets
            azureFirewalls           = $r.azureFirewalls
            firewallPolicyRuleGroups = $firewallPolicyRuleGroups
            vpnGateways              = $r.vpnGateways
            privateEndpoints         = $r.privateEndpoints
            privateDnsZones          = $r.privateDnsZones
            nsgPublicInbound         = $r.nsgPublicInbound
        }
        compute       = [pscustomobject]@{ virtualMachines = $r.virtualMachines }
        management    = [pscustomobject]@{
            recoveryVaults = @(); deployments = $r.deployments
            logAnalyticsWorkspaces = $r.logAnalyticsWorkspaces
        }
        security      = [pscustomobject]@{ defenderPlans = @() }
        governance    = [pscustomobject]@{
            managementGroups = @(); policyAssignments = @(); roleAssignments = @()
            budgets = @(); resourceLocks = @(); pimEligibility = @(); classicAdministrators = @()
        }
        costCleanup   = [pscustomobject]@{ orphanedDisks = $r.orphanedDisks; orphanedPips = $r.orphanedPips }
        opsPosture    = [pscustomobject]@{ diagnosticCoverage = $r.diagnosticCoverage }
        # Per-domain resource data (scalar compliance fields) for the per-category
        # assessments in Epic AB#5056.
        domains       = [pscustomobject]@{
            storage      = [pscustomobject]@{ storageAccounts = $r.storageAccounts }
            databases    = [pscustomobject]@{
                sqlDatabases = $r.sqlDatabases; sqlServers = $r.sqlServers
                sqlDefenderPricing = $r.sqlDefenderPricing
            }
            web          = [pscustomobject]@{ webApps = $r.webApps }
            containers   = [pscustomobject]@{ aksClusters = $r.aksClusters; containerRegistries = $r.containerRegistries }
            security     = [pscustomobject]@{ keyVaults = $r.keyVaults }
            ai           = [pscustomobject]@{ cognitiveAccounts = $r.cognitiveAccounts }
            hybrid       = [pscustomobject]@{
                arcServers = $r.arcServers; arcExtensions = $r.arcExtensions
                azureLocalClusters = $r.azureLocalClusters
            }
            integration  = [pscustomobject]@{
                eventHubNamespaces = $r.eventHubNamespaces; apiManagement = $r.apiManagement
                serviceBusNamespaces = $r.serviceBusNamespaces
            }
            iot          = [pscustomobject]@{ iotHubs = $r.iotHubs }
            analytics    = [pscustomobject]@{
                synapseWorkspaces = $r.synapseWorkspaces; purviewAccounts = $r.purviewAccounts
            }
        }
        advisor       = @()
        _meta         = [pscustomobject]@{
            generatedOn = (Get-Date).ToString('o'); scope = $Scope
            categories = $Categories; managementGroupId = $ManagementGroupId
        }
    }
    return $collect
}
