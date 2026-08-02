#
# Collector spec for the service-coverage build-out — Epic AB#6741.
#
# Rendered into manifests/collectors/<Category>/<Name>.psd1 by
# scripts/Build-ScoutServiceCollector.ps1. Edit HERE and regenerate; the generated definitions
# say so in their own headers.
#
# WHAT EACH ENTRY DECLARES
#
#   Category              the manifests/collectors folder, which IS the Scout category
#   Name                  the definition file basename and the collector's identity
#   Worksheet             the Excel sheet name — unique across every definition, <= 31 chars
#   ResourceTypes         Resource Graph type strings, lower-case, as ARG returns them
#   ResourceTypeMatching  omit to get SinglePass for multi-type, Grouped for single-type
#   AdditionalFilter      optional Where-Object body over the matched rows ($_ is the resource)
#   Preamble              optional extra statements, run per row after $data is bound
#   Fields                the service-specific columns, in worksheet order
#
# The five identity columns (Subscription, Resource Group, Name, Location) plus the retirement
# pair, 'Resource U' and the tag columns are added by the generator — never declare them here.
#
# RESOURCE TYPE PROVENANCE. Every type string below is taken from the ARM template reference on
# Microsoft Learn (learn.microsoft.com/azure/templates/<provider>/<type>), lower-cased to match
# what Resource Graph returns. AB#6444 found three fabricated type strings in Hybrid/ArcSites
# that the fixture generator happily manufactured rows for, so a definition passing its tests
# proves nothing about whether the type exists. tests/ServiceCollectorTypes.Tests.ps1 pins each
# string against this spec; only a live run proves rows come back.
#
@{
    Collectors = @(

        # ---------------------------------------------------------------------------------------
        # Migration — the only category at zero coverage (AB#6750: stories AB#6830, AB#6831).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Migration'
            Name = 'AzureMigrateProjects'
            Worksheet = 'Migrate Projects'
            ResourceTypes = @('microsoft.migrate/migrateprojects')
            Fields = @(
                @{ Name = 'Project Kind';          Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';    Expression = '$data.provisioningState' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Service Endpoint';      Expression = '$data.serviceEndpoint' }
                @{ Name = 'Utility Storage';       Expression = '$UtilityStorage' }
            )
            Preamble = @'
$UtilityStorage = if(![string]::IsNullOrEmpty($data.utilityStorageAccountId)){Get-AZSCIdSegment -Id $data.utilityStorageAccountId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Migration'
            Name = 'AzureMigrateAssessments'
            Worksheet = 'Migrate Assessment Projects'
            ResourceTypes = @('microsoft.migrate/assessmentprojects')
            Fields = @(
                @{ Name = 'Project Status';        Expression = '$data.projectStatus' }
                @{ Name = 'Provisioning State';    Expression = '$data.provisioningState' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Assessment Solution';   Expression = '$AssessmentSolution' }
                @{ Name = 'Workspace Location';    Expression = '$data.customerWorkspaceLocation' }
            )
            Preamble = @'
$AssessmentSolution = if(![string]::IsNullOrEmpty($data.assessmentSolutionId)){Get-AZSCIdSegment -Id $data.assessmentSolutionId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Migration'
            Name = 'AzureMigrateDiscoverySites'
            Worksheet = 'Migrate Discovery Sites'
            ResourceTypes = @(
                'microsoft.offazure/vmwaresites'
                'microsoft.offazure/hypervsites'
                'microsoft.offazure/serversites'
                'microsoft.offazure/mastersites'
            )
            Fields = @(
                @{ Name = 'Site Type';             Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';    Expression = '$data.provisioningState' }
                @{ Name = 'Service Endpoint';      Expression = '$data.serviceEndpoint' }
                @{ Name = 'Discovery Solution';    Expression = '$DiscoverySolution' }
                @{ Name = 'Agent Version';         Expression = '$data.agentDetails.version' }
            )
            Preamble = @'
$DiscoverySolution = if(![string]::IsNullOrEmpty($data.discoverySolutionId)){Get-AZSCIdSegment -Id $data.discoverySolutionId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Migration'
            Name = 'DatabaseMigrationServices'
            Worksheet = 'Database Migration Services'
            ResourceTypes = @('microsoft.datamigration/services', 'microsoft.datamigration/sqlmigrationservices')
            Fields = @(
                @{ Name = 'Service Kind';       Expression = '$1.TYPE' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';           Expression = '$1.sku.tier' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Virtual Network';    Expression = '$VNET' }
                @{ Name = 'Subnet';             Expression = '$Subnet' }
            )
            Preamble = @'
$VNET = if(![string]::IsNullOrEmpty($data.virtualSubnetId)){Get-AZSCIdSegment -Id $data.virtualSubnetId -Index 8}else{$null}
$Subnet = if(![string]::IsNullOrEmpty($data.virtualSubnetId)){Get-AZSCIdSegment -Id $data.virtualSubnetId -Index 10}else{$null}
'@
        }
        @{
            Category = 'Migration'
            Name = 'DataBox'
            Worksheet = 'Data Box Jobs'
            ResourceTypes = @('microsoft.databox/jobs')
            Fields = @(
                @{ Name = 'SKU';              Expression = '$1.sku.name' }
                @{ Name = 'Job Status';       Expression = '$data.status' }
                @{ Name = 'Transfer Type';    Expression = '$data.transferType' }
                @{ Name = 'Delivery Type';    Expression = '$data.deliveryType' }
                @{ Name = 'Start Time';       Expression = '[string]$data.startTime' }
                @{ Name = 'Cancellation Reason'; Expression = '$data.cancellationReason' }
            )
        }
        @{
            Category = 'Migration'
            Name = 'StackEdge'
            Worksheet = 'Stack Edge Devices'
            ResourceTypes = @('microsoft.databoxedge/databoxedgedevices')
            Fields = @(
                @{ Name = 'SKU';               Expression = '$1.sku.name' }
                @{ Name = 'Device Status';     Expression = '$data.dataBoxEdgeDeviceStatus' }
                @{ Name = 'Device Type';       Expression = '$data.deviceType' }
                @{ Name = 'Model';             Expression = '$data.modelDescription' }
                @{ Name = 'Software Version';  Expression = '$data.deviceSoftwareVersion' }
                @{ Name = 'Serial Number';     Expression = '$data.serialNumber' }
            )
        }

        # ---------------------------------------------------------------------------------------
        # General — the third missing category (AB#6838). Largely relocation: SupportTickets moves
        # here from Management, and Reservations/Subscriptions are genuinely new.
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'General'
            Name = 'Reservations'
            Worksheet = 'Reservations'
            ResourceTypes = @('microsoft.capacity/reservationorders', 'microsoft.capacity/reservationorders/reservations')
            Fields = @(
                @{ Name = 'Display Name';       Expression = '$data.displayName' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Quantity';           Expression = '[string]$data.quantity' }
                @{ Name = 'Term';               Expression = '$data.term' }
                @{ Name = 'Billing Plan';       Expression = '$data.billingPlan' }
                @{ Name = 'Benefit Start';      Expression = '[string]$data.benefitStartTime' }
                @{ Name = 'Expiry Date';        Expression = '[string]$data.expiryDate' }
                @{ Name = 'Renew';              Expression = '[string]$data.renew' }
            )
        }
        # Quotas is a General service and Scout has ALWAYS fetched the data -- Get-ScoutVmQuotas
        # emits a single 'AZSC/VM/Quotas' envelope per run whose `properties` holds one entry per
        # subscription/region, each carrying the Get-AzVMUsage rows. Nothing rendered it. This is
        # the collector that finally does, so the two nested loops walk the envelope rather than
        # a resource list, and the identity columns come from the quota reading, not from ARM.
        @{
            Category = 'General'
            Name = 'Quotas'
            Worksheet = 'Quotas'
            ResourceTypes = @('AZSC/VM/Quotas')
            Identity = @(
                @{ Name = 'ID';           Expression = '$Loc.SubId' }
                @{ Name = 'Subscription'; Expression = '$Loc.Subscription' }
                @{ Name = 'Location';     Expression = '$Loc.Location' }
            )
            # Both loops are deliberately UNGUARDED. The per-loop `Comment` is emitted into the
            # generated manifest next to the loop it describes, because
            # tests/Collector.VanishingParent.Tests.ps1 requires the decision to be recorded there
            # rather than only here -- the reasoning must not drift away from the code.
            AdditionalRowLoops = @(
                @{
                    Variable = 'Loc'
                    Source   = '$data'
                    Comment  = @'
AB#6845 decision ($Loc): deliberately UNGUARDED -- the parent must NOT become a row.

This collector's "parent" is not an Azure resource at all: it is the synthetic
AZSC/VM/Quotas envelope the engine builds to carry quota data, and every column on
this worksheet except Resource U is read off $Loc or $Usage. An envelope with no
locations would therefore emit a row that is entirely blank -- a phantom line item
in a report about quota headroom, stating nothing and inviting the reader to wonder
which subscription it belongs to.

The behaviour is asserted, not merely skipped, in
tests/Collector.VanishingParent.Tests.ps1.
'@
                }
                @{
                    Variable = 'Usage'
                    Source   = '$Loc.Data'
                    Comment  = @'
AB#6845 decision ($Usage): deliberately UNGUARDED -- the ROW IS THE CHILD. One row
per usage line is the unit this worksheet inventories, so a location envelope
carrying no usage data has nothing to state and must not manufacture a row to say
so.
'@
                }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Quota';         Expression = '$Usage.Name.LocalizedValue' }
                @{ Name = 'Quota Name';    Expression = '$Usage.Name.Value' }
                @{ Name = 'Current Value'; Expression = '[string]$Usage.CurrentValue' }
                @{ Name = 'Limit';         Expression = '[string]$Usage.Limit' }
                # Computed in the field expression, not the row Preamble: the Preamble runs before
                # the AdditionalRowLoops bind $Usage, so a variable assigned there would read $null
                # for every row -- a silently empty column.
                @{ Name = 'Used %';        Expression = '[string]$(if($null -ne $Usage -and $Usage.Limit -and [double]$Usage.Limit -gt 0){[math]::Round((([double]$Usage.CurrentValue / [double]$Usage.Limit) * 100), 1)}else{$null})' }
                @{ Name = 'Unit';          Expression = '$Usage.Unit' }
            )
        }

        # ---------------------------------------------------------------------------------------
        # DevOps — the second missing category. Epic AB#6741's acceptance criteria require all
        # eighteen categories to exist, and DevOps is named in its scope alongside Migration.
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'DevOps'
            Name = 'ChaosStudio'
            Worksheet = 'Chaos Studio'
            ResourceTypes = @('microsoft.chaos/experiments', 'microsoft.chaos/targets')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Step Count';         Expression = '[string]@($data.steps).Count' }
                @{ Name = 'Selector Count';     Expression = '[string]@($data.selectors).Count' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'DevCenters'
            Worksheet = 'Dev Centers'
            ResourceTypes = @('microsoft.devcenter/devcenters', 'microsoft.devcenter/projects')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Dev Center';         Expression = '$DevCenter' }
                @{ Name = 'Dev Box Limit';      Expression = '[string]$data.maxDevBoxesPerUser' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
            )
            Preamble = @'
$DevCenter = if(![string]::IsNullOrEmpty($data.devCenterId)){Get-AZSCIdSegment -Id $data.devCenterId -Index 8}else{$null}
'@
        }
        @{
            Category = 'DevOps'
            Name = 'DevBoxPools'
            Worksheet = 'Dev Box Pools'
            ResourceTypes = @('microsoft.devcenter/projects/pools')
            Fields = @(
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'Definition Name';     Expression = '$data.devBoxDefinitionName' }
                @{ Name = 'Network Connection';  Expression = '$data.networkConnectionName' }
                @{ Name = 'Local Admin';         Expression = '$data.licenseType' }
                @{ Name = 'Admin Status';        Expression = '$data.localAdministrator' }
                @{ Name = 'Stop On Disconnect';  Expression = '$data.stopOnDisconnect.status' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'DevCenterNetworkConnections'
            Worksheet = 'Dev Center Network Conns'
            ResourceTypes = @('microsoft.devcenter/networkconnections')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Domain Join Type';   Expression = '$data.domainJoinType' }
                @{ Name = 'Domain Name';        Expression = '$data.domainName' }
                @{ Name = 'Virtual Network';    Expression = '$VNET' }
                @{ Name = 'Subnet';             Expression = '$Subnet' }
            )
            Preamble = @'
$VNET = if(![string]::IsNullOrEmpty($data.subnetId)){Get-AZSCIdSegment -Id $data.subnetId -Index 8}else{$null}
$Subnet = if(![string]::IsNullOrEmpty($data.subnetId)){Get-AZSCIdSegment -Id $data.subnetId -Index 10}else{$null}
'@
        }
        @{
            Category = 'DevOps'
            Name = 'DeploymentEnvironments'
            Worksheet = 'Deployment Environments'
            ResourceTypes = @(
                'microsoft.devcenter/devcenters/environmenttypes'
                'microsoft.devcenter/projects/environmenttypes'
                'microsoft.devcenter/devcenters/catalogs'
                'microsoft.devcenter/projects/catalogs'
            )
            Fields = @(
                @{ Name = 'Resource Kind';       Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'Deployment Target';   Expression = '$DeploymentTarget' }
                @{ Name = 'Status';              Expression = '$data.status' }
                @{ Name = 'Sync State';          Expression = '$data.syncState' }
            )
            Preamble = @'
$DeploymentTarget = if(![string]::IsNullOrEmpty($data.deploymentTargetId)){Get-AZSCIdSegment -Id $data.deploymentTargetId -Index 2}else{$null}
'@
        }
        @{
            Category = 'DevOps'
            Name = 'DevTestLabs'
            Worksheet = 'DevTest Labs'
            ResourceTypes = @('microsoft.devtestlab/labs', 'microsoft.devtestlab/schedules')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Lab Storage Type';     Expression = '$data.labStorageType' }
                @{ Name = 'Premium Data Disks';   Expression = '$data.premiumDataDisks' }
                @{ Name = 'Schedule Status';      Expression = '$data.status' }
                @{ Name = 'Task Type';            Expression = '$data.taskType' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'LabServices'
            Worksheet = 'Lab Services'
            ResourceTypes = @('microsoft.labservices/labs', 'microsoft.labservices/labplans')
            Fields = @(
                @{ Name = 'Resource Kind';       Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'State';               Expression = '$data.state' }
                @{ Name = 'SKU';                 Expression = '$1.sku.name' }
                @{ Name = 'Security Open Access'; Expression = '$data.securityProfile.openAccess' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'LoadTesting'
            Worksheet = 'Load Testing'
            ResourceTypes = @('microsoft.loadtestservice/loadtests')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Data Plane URI';     Expression = '$data.dataPlaneURI' }
                @{ Name = 'Description';        Expression = '$data.description' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
                @{ Name = 'CMK Identity';       Expression = '$data.encryption.identity.type' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'ManagedDevOpsPools'
            Worksheet = 'Managed DevOps Pools'
            ResourceTypes = @('microsoft.devopsinfrastructure/pools')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Maximum Agents';     Expression = '[string]$data.maximumConcurrency' }
                @{ Name = 'Organisation Kind';  Expression = '$data.organizationProfile.kind' }
                @{ Name = 'Agent OS';           Expression = '$data.fabricProfile.kind' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'PlaywrightTesting'
            Worksheet = 'Playwright Workspaces'
            ResourceTypes = @('microsoft.azureplaywrightservice/accounts')
            Fields = @(
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'Dashboard URI';       Expression = '$data.dashboardUri' }
                @{ Name = 'Local Auth';          Expression = '$data.localAuth' }
                @{ Name = 'Regional Affinity';   Expression = '$data.regionalAffinity' }
                @{ Name = 'Reporting';           Expression = '$data.reporting' }
                @{ Name = 'Scalable Execution';  Expression = '$data.scalableExecution' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'AppConfiguration'
            Worksheet = 'App Configuration'
            ResourceTypes = @('microsoft.appconfiguration/configurationstores')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Endpoint';             Expression = '$data.endpoint' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Local Auth Disabled';  Expression = '[string]$data.disableLocalAuth' }
                @{ Name = 'Purge Protection';     Expression = '[string]$data.enablePurgeProtection' }
                @{ Name = 'Soft Delete Days';     Expression = '[string]$data.softDeleteRetentionInDays' }
                @{ Name = 'Private Endpoints';    Expression = '[string]@($data.privateEndpointConnections).Count' }
            )
        }
        @{
            Category = 'DevOps'
            Name = 'ApiConnections'
            Worksheet = 'API Connections'
            ResourceTypes = @('microsoft.web/connections')
            Fields = @(
                @{ Name = 'Display Name';   Expression = '$data.displayName' }
                @{ Name = 'API Name';       Expression = '$data.api.name' }
                @{ Name = 'API Type';       Expression = '$data.api.type' }
                @{ Name = 'Status';         Expression = '$Status' }
                @{ Name = 'Created Time';   Expression = '[string]$data.createdTime' }
                @{ Name = 'Changed Time';   Expression = '[string]$data.changedTime' }
            )
            Preamble = @'
$Status = [string]($data.statuses | ForEach-Object { $_.status })
'@
        }

        # ---------------------------------------------------------------------------------------
        # Integration — Scout's thinnest category at 3 of 15 (AB#6836).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Integration'
            Name = 'LogicApps'
            Worksheet = 'Logic Apps'
            ResourceTypes = @('microsoft.logic/workflows')
            Fields = @(
                @{ Name = 'State';            Expression = '$data.state' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Version';          Expression = '$data.version' }
                @{ Name = 'Access Endpoint';  Expression = '$data.accessEndpoint' }
                @{ Name = 'Integration Account'; Expression = '$IntegrationAccount' }
                @{ Name = 'Trigger Count';    Expression = '[string]@($data.definition.triggers.psobject.properties).Count' }
                @{ Name = 'Action Count';     Expression = '[string]@($data.definition.actions.psobject.properties).Count' }
                @{ Name = 'Created Time';     Expression = '[string]$data.createdTime' }
                @{ Name = 'Changed Time';     Expression = '[string]$data.changedTime' }
            )
            Preamble = @'
$IntegrationAccount = if(![string]::IsNullOrEmpty($data.integrationAccount.id)){Get-AZSCIdSegment -Id $data.integrationAccount.id -Index 8}else{$null}
'@
        }
        @{
            Category = 'Integration'
            Name = 'IntegrationAccounts'
            Worksheet = 'Integration Accounts'
            ResourceTypes = @('microsoft.logic/integrationaccounts', 'microsoft.logic/integrationserviceenvironments')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'State';              Expression = '$data.state' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Public Network';     Expression = '$data.publicNetworkAccess' }
            )
        }
        @{
            Category = 'Integration'
            Name = 'LogicAppsCustomConnectors'
            Worksheet = 'Logic Apps Connectors'
            ResourceTypes = @('microsoft.web/customapis')
            Fields = @(
                @{ Name = 'Display Name';     Expression = '$data.displayName' }
                @{ Name = 'Description';      Expression = '$data.description' }
                @{ Name = 'Backend Service';  Expression = '$data.backendService.serviceUrl' }
                @{ Name = 'API Type';         Expression = '$data.apiType' }
                @{ Name = 'Connection Params'; Expression = '[string]@($data.connectionParameters.psobject.properties).Count' }
            )
        }
        @{
            Category = 'Integration'
            Name = 'EventGrid'
            Worksheet = 'Event Grid'
            ResourceTypes = @(
                'microsoft.eventgrid/topics'
                'microsoft.eventgrid/systemtopics'
                'microsoft.eventgrid/domains'
                'microsoft.eventgrid/partnertopics'
                'microsoft.eventgrid/namespaces'
            )
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Endpoint';             Expression = '$data.endpoint' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Local Auth Disabled';  Expression = '[string]$data.disableLocalAuth' }
                @{ Name = 'Source Type';          Expression = '$data.topicType' }
                @{ Name = 'Private Endpoints';    Expression = '[string]@($data.privateEndpointConnections).Count' }
            )
        }
        @{
            Category = 'Integration'
            Name = 'EventHubClusters'
            Worksheet = 'Event Hubs Clusters'
            ResourceTypes = @('microsoft.eventhub/clusters')
            Fields = @(
                @{ Name = 'SKU';               Expression = '$1.sku.name' }
                @{ Name = 'Capacity';          Expression = '[string]$1.sku.capacity' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Metric Id';         Expression = '$data.metricId' }
                @{ Name = 'Supports Scaling';  Expression = '[string]$data.supportsScaling' }
            )
        }
        @{
            Category = 'Integration'
            Name = 'Relays'
            Worksheet = 'Relays'
            ResourceTypes = @('microsoft.relay/namespaces', 'microsoft.relay/namespaces/hybridconnections', 'microsoft.relay/namespaces/wcfrelays')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Service Bus Endpoint'; Expression = '$data.serviceBusEndpoint' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Listener Count';       Expression = '[string]$data.listenerCount' }
            )
        }
        @{
            Category = 'Integration'
            Name = 'HealthDataServices'
            Worksheet = 'Health Data Services'
            ResourceTypes = @(
                'microsoft.healthcareapis/services'
                'microsoft.healthcareapis/workspaces'
                'microsoft.healthcareapis/workspaces/fhirservices'
                'microsoft.healthcareapis/workspaces/dicomservices'
                'microsoft.healthcareapis/workspaces/iotconnectors'
            )
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'Service Kind';         Expression = '$1.KIND' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Authority';            Expression = '$data.authenticationConfiguration.authority' }
                @{ Name = 'SMART Proxy Enabled';  Expression = '[string]$data.authenticationConfiguration.smartProxyEnabled' }
            )
        }

        # ---------------------------------------------------------------------------------------
        # Web and Mobile — 6 of 22 (AB#6836).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Web'
            Name = 'AppServiceEnvironments'
            Worksheet = 'App Service Environments'
            ResourceTypes = @('microsoft.web/hostingenvironments')
            Fields = @(
                @{ Name = 'Kind';               Expression = '$1.KIND' }
                @{ Name = 'Status';             Expression = '$data.status' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Internal Load Balancing'; Expression = '$data.internalLoadBalancingMode' }
                @{ Name = 'Dedicated Host Count'; Expression = '[string]$data.dedicatedHostCount' }
                @{ Name = 'Zone Redundant';     Expression = '[string]$data.zoneRedundant' }
                @{ Name = 'Virtual Network';    Expression = '$VNET' }
                @{ Name = 'Subnet';             Expression = '$Subnet' }
            )
            Preamble = @'
$VNET = if(![string]::IsNullOrEmpty($data.virtualNetwork.id)){Get-AZSCIdSegment -Id $data.virtualNetwork.id -Index 8}else{$null}
$Subnet = if(![string]::IsNullOrEmpty($data.virtualNetwork.subnet)){$data.virtualNetwork.subnet}else{$null}
'@
        }
        @{
            Category = 'Web'
            Name = 'StaticWebApps'
            Worksheet = 'Static Web Apps'
            ResourceTypes = @('microsoft.web/staticsites')
            Fields = @(
                @{ Name = 'SKU';                 Expression = '$1.sku.name' }
                @{ Name = 'Default Hostname';    Expression = '$data.defaultHostname' }
                @{ Name = 'Repository URL';      Expression = '$data.repositoryUrl' }
                @{ Name = 'Branch';              Expression = '$data.branch' }
                @{ Name = 'Provider';            Expression = '$data.provider' }
                @{ Name = 'Staging Environments'; Expression = '$data.stagingEnvironmentPolicy' }
                @{ Name = 'Config File Changes'; Expression = '[string]$data.allowConfigFileUpdates' }
                @{ Name = 'Custom Domains';      Expression = '[string]@($data.customDomains).Count' }
            )
        }
        @{
            Category = 'Web'
            Name = 'FunctionApps'
            Worksheet = 'Function Apps'
            ResourceTypes = @('microsoft.web/sites')
            AdditionalFilter = '$_.KIND -like ''*functionapp*'''
            Fields = @(
                @{ Name = 'Kind';                Expression = '$1.KIND' }
                @{ Name = 'State';               Expression = '$data.state' }
                @{ Name = 'Default Hostname';    Expression = '$data.defaultHostName' }
                @{ Name = 'App Service Plan';    Expression = '$ServerFarm' }
                @{ Name = 'HTTPS Only';          Expression = '[string]$data.httpsOnly' }
                @{ Name = 'Client Cert Enabled'; Expression = '[string]$data.clientCertEnabled' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Outbound Subnet';     Expression = '$OutboundSubnet' }
                @{ Name = 'Identity Type';       Expression = '$1.identity.type' }
            )
            Preamble = @'
$ServerFarm = if(![string]::IsNullOrEmpty($data.serverFarmId)){Get-AZSCIdSegment -Id $data.serverFarmId -Index 8}else{$null}
$OutboundSubnet = if(![string]::IsNullOrEmpty($data.virtualNetworkSubnetId)){Get-AZSCIdSegment -Id $data.virtualNetworkSubnetId -Index 10}else{$null}
'@
        }
        @{
            Category = 'Web'
            Name = 'DeploymentSlots'
            Worksheet = 'Deployment Slots'
            ResourceTypes = @('microsoft.web/sites/slots')
            Fields = @(
                @{ Name = 'Kind';               Expression = '$1.KIND' }
                @{ Name = 'Parent Site';        Expression = '$ParentSite' }
                @{ Name = 'State';              Expression = '$data.state' }
                @{ Name = 'Default Hostname';   Expression = '$data.defaultHostName' }
                @{ Name = 'App Service Plan';   Expression = '$ServerFarm' }
                @{ Name = 'HTTPS Only';         Expression = '[string]$data.httpsOnly' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
            )
            Preamble = @'
$ParentSite = if(![string]::IsNullOrEmpty($1.NAME)){Get-AZSCIdSegment -Id $1.NAME -Index 0}else{$null}
$ServerFarm = if(![string]::IsNullOrEmpty($data.serverFarmId)){Get-AZSCIdSegment -Id $data.serverFarmId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Web'
            Name = 'AppServiceCertificates'
            Worksheet = 'App Service Certificates'
            ResourceTypes = @('microsoft.certificateregistration/certificateorders', 'microsoft.web/certificates')
            Fields = @(
                @{ Name = 'Resource Kind';    Expression = '$1.TYPE' }
                @{ Name = 'Status';           Expression = '$data.status' }
                @{ Name = 'Subject Name';     Expression = '$data.subjectName' }
                @{ Name = 'Issuer';           Expression = '$data.issuer' }
                @{ Name = 'Issue Date';       Expression = '[string]$data.issueDate' }
                @{ Name = 'Expiration Date';  Expression = '[string]$Expiration' }
                @{ Name = 'Days To Expiry';   Expression = '[string]$DaysToExpiry' }
                @{ Name = 'Auto Renew';       Expression = '[string]$data.autoRenew' }
                @{ Name = 'Key Vault';        Expression = '$KeyVault' }
            )
            Preamble = @'
$Expiration = if(![string]::IsNullOrEmpty($data.expirationDate)){$data.expirationDate}else{$data.expirationTime}
$DaysToExpiry = if(![string]::IsNullOrEmpty($Expiration)){[math]::Floor(([datetime]$Expiration - [datetime]'2000-01-01').TotalDays)}else{$null}
$KeyVault = if(![string]::IsNullOrEmpty($data.keyVaultId)){Get-AZSCIdSegment -Id $data.keyVaultId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Web'
            Name = 'AppServiceDomains'
            Worksheet = 'App Service Domains'
            ResourceTypes = @('microsoft.domainregistration/domains')
            Fields = @(
                @{ Name = 'Registration Status'; Expression = '$data.registrationStatus' }
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'Created Time';        Expression = '[string]$data.createdTime' }
                @{ Name = 'Expiration Time';     Expression = '[string]$data.expirationTime' }
                @{ Name = 'Auto Renew';          Expression = '[string]$data.autoRenew' }
                @{ Name = 'Privacy';             Expression = '[string]$data.privacy' }
            )
        }
        @{
            Category = 'Web'
            Name = 'SignalR'
            Worksheet = 'SignalR'
            ResourceTypes = @('microsoft.signalrservice/signalr')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';             Expression = '$1.sku.tier' }
                @{ Name = 'Capacity';             Expression = '[string]$1.sku.capacity' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Host Name';            Expression = '$data.hostName' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Local Auth Disabled';  Expression = '[string]$data.disableLocalAuth' }
                @{ Name = 'TLS Client Cert';      Expression = '[string]$data.tls.clientCertEnabled' }
            )
        }
        @{
            Category = 'Web'
            Name = 'WebPubSub'
            Worksheet = 'Web PubSub'
            ResourceTypes = @('microsoft.signalrservice/webpubsub')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';             Expression = '$1.sku.tier' }
                @{ Name = 'Capacity';             Expression = '[string]$1.sku.capacity' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Host Name';            Expression = '$data.hostName' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Local Auth Disabled';  Expression = '[string]$data.disableLocalAuth' }
            )
        }
        @{
            Category = 'Web'
            Name = 'CommunicationServices'
            Worksheet = 'Communication Services'
            ResourceTypes = @(
                'microsoft.communication/communicationservices'
                'microsoft.communication/emailservices'
                'microsoft.communication/emailservices/domains'
            )
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Data Location';      Expression = '$data.dataLocation' }
                @{ Name = 'Host Name';          Expression = '$data.hostName' }
                @{ Name = 'Domain Management';  Expression = '$data.domainManagement' }
                @{ Name = 'Verification State'; Expression = '$data.verificationStates.Domain.status' }
            )
        }
        @{
            Category = 'Web'
            Name = 'NotificationHubs'
            Worksheet = 'Notification Hubs'
            ResourceTypes = @('microsoft.notificationhubs/namespaces', 'microsoft.notificationhubs/namespaces/notificationhubs')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';             Expression = '$1.sku.tier' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Namespace Type';       Expression = '$data.namespaceType' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
            )
        }
        @{
            Category = 'Web'
            Name = 'FluidRelay'
            Worksheet = 'Fluid Relay'
            ResourceTypes = @('microsoft.fluidrelay/fluidrelayservers')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Storage SKU';        Expression = '$data.storagesku' }
                @{ Name = 'Frs Tenant Id';      Expression = '$data.frsTenantId' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
            )
        }
        @{
            Category = 'Web'
            Name = 'SpringApps'
            Worksheet = 'Spring Apps'
            ResourceTypes = @('microsoft.appplatform/spring', 'microsoft.appplatform/spring/apps')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';           Expression = '$1.sku.tier' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Service Id';         Expression = '$data.serviceId' }
                @{ Name = 'Zone Redundant';     Expression = '[string]$data.zoneRedundant' }
                @{ Name = 'Public Endpoint';    Expression = '[string]$data.public' }
            )
        }

        # ---------------------------------------------------------------------------------------
        # Storage — 3 of 17 (AB#6837). Child resources are collected separately (AB#6834).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Storage'
            Name = 'Snapshots'
            Worksheet = 'Snapshots'
            ResourceTypes = @('microsoft.compute/snapshots')
            Fields = @(
                @{ Name = 'SKU';               Expression = '$1.sku.name' }
                @{ Name = 'Disk State';        Expression = '$data.diskState' }
                @{ Name = 'Size (GB)';         Expression = '[string]$data.diskSizeGB' }
                @{ Name = 'Incremental';       Expression = '[string]$data.incremental' }
                @{ Name = 'Created';           Expression = '[string]$data.timeCreated' }
                @{ Name = 'Source Disk';       Expression = '$SourceDisk' }
                @{ Name = 'OS Type';           Expression = '$data.osType' }
                @{ Name = 'Network Access';    Expression = '$data.networkAccessPolicy' }
                @{ Name = 'Public Network';    Expression = '$data.publicNetworkAccess' }
            )
            Preamble = @'
$SourceDisk = if(![string]::IsNullOrEmpty($data.creationData.sourceResourceId)){Get-AZSCIdSegment -Id $data.creationData.sourceResourceId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Storage'
            Name = 'DiskEncryptionSets'
            Worksheet = 'Disk Encryption Sets'
            ResourceTypes = @('microsoft.compute/diskencryptionsets')
            Fields = @(
                @{ Name = 'Encryption Type';    Expression = '$data.encryptionType' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Key Vault';          Expression = '$KeyVault' }
                @{ Name = 'Auto Key Rotation';  Expression = '[string]$data.rotationToLatestKeyVersionEnabled' }
                @{ Name = 'Identity Type';      Expression = '$1.identity.type' }
            )
            Preamble = @'
$KeyVault = if(![string]::IsNullOrEmpty($data.activeKey.sourceVault.id)){Get-AZSCIdSegment -Id $data.activeKey.sourceVault.id -Index 8}else{$null}
'@
        }
        @{
            Category = 'Storage'
            Name = 'ElasticSan'
            Worksheet = 'Elastic SAN'
            ResourceTypes = @('microsoft.elasticsan/elasticsans', 'microsoft.elasticsan/elasticsans/volumegroups')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Base Size (TiB)';    Expression = '[string]$data.baseSizeTiB' }
                @{ Name = 'Extended Size (TiB)'; Expression = '[string]$data.extendedCapacitySizeTiB' }
                @{ Name = 'Protocol Type';      Expression = '$data.protocolType' }
                @{ Name = 'Encryption';         Expression = '$data.encryption' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
            )
        }
        @{
            Category = 'Storage'
            Name = 'StorageSync'
            Worksheet = 'Storage Sync Services'
            ResourceTypes = @(
                'microsoft.storagesync/storagesyncservices'
                'microsoft.storagesync/storagesyncservices/syncgroups'
                'microsoft.storagesync/storagesyncservices/registeredservers'
            )
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Incoming Traffic';     Expression = '$data.incomingTrafficPolicy' }
                @{ Name = 'Server Name';          Expression = '$data.friendlyName' }
                @{ Name = 'Server OS';            Expression = '$data.serverOSVersion' }
                @{ Name = 'Agent Version';        Expression = '$data.agentVersion' }
                @{ Name = 'Server Status';        Expression = '$data.serverManagementErrorCode' }
            )
        }
        @{
            Category = 'Storage'
            Name = 'EdgeHardwareCenter'
            Worksheet = 'Edge Hardware Center'
            ResourceTypes = @('microsoft.edgeorder/orders', 'microsoft.edgeorder/orderitems', 'microsoft.edgeorder/addresses')
            Fields = @(
                @{ Name = 'Resource Kind';   Expression = '$1.TYPE' }
                @{ Name = 'Order Stage';     Expression = '$data.orderStageHistory' }
                @{ Name = 'Product Family';  Expression = '$data.productDetails.hierarchyInformation.productFamilyName' }
                @{ Name = 'Product Line';    Expression = '$data.productDetails.hierarchyInformation.productLineName' }
                @{ Name = 'Quantity';        Expression = '[string]$data.productDetails.count' }
                @{ Name = 'Address State';   Expression = '$data.addressValidationStatus' }
            )
        }
        @{
            Category = 'Storage'
            Name = 'PartnerStorage'
            Worksheet = 'Partner Storage Services'
            ResourceTypes = @(
                'purestorage.block/storagepools'
                'purestorage.block/reservations'
                'qumulo.storage/filesystems'
            )
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Marketplace Plan';   Expression = '$1.plan.name' }
                @{ Name = 'Publisher';          Expression = '$1.plan.publisher' }
                @{ Name = 'Offer';              Expression = '$1.plan.product' }
            )
        }

        # ---------------------------------------------------------------------------------------
        # Internet of Things — 8 of 19 (AB#6837).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'IoT'
            Name = 'DeviceProvisioningServices'
            Worksheet = 'IoT DPS'
            ResourceTypes = @('microsoft.devices/provisioningservices')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'Capacity';             Expression = '[string]$1.sku.capacity' }
                @{ Name = 'State';                Expression = '$data.state' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Service Endpoint';     Expression = '$data.serviceOperationsHostName' }
                @{ Name = 'Allocation Policy';    Expression = '$data.allocationPolicy' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Linked IoT Hubs';      Expression = '[string]@($data.iotHubs).Count' }
            )
        }
        @{
            Category = 'IoT'
            Name = 'IoTCentral'
            Worksheet = 'IoT Central'
            ResourceTypes = @('microsoft.iotcentral/iotapps')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'State';                Expression = '$data.state' }
                @{ Name = 'Application Id';       Expression = '$data.applicationId' }
                @{ Name = 'Subdomain';            Expression = '$data.subdomain' }
                @{ Name = 'Template';             Expression = '$data.template' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Identity Type';        Expression = '$1.identity.type' }
            )
        }
        @{
            Category = 'IoT'
            Name = 'DeviceUpdate'
            Worksheet = 'Device Update'
            ResourceTypes = @('microsoft.deviceupdate/accounts', 'microsoft.deviceupdate/accounts/instances')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$data.sku' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Host Name';            Expression = '$data.hostName' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Linked IoT Hubs';      Expression = '[string]@($data.iotHubs).Count' }
            )
        }
        @{
            Category = 'IoT'
            Name = 'DigitalTwins'
            Worksheet = 'Digital Twins'
            ResourceTypes = @(
                'microsoft.digitaltwins/digitaltwinsinstances'
                'microsoft.digitaltwins/digitaltwinsinstances/endpoints'
                'microsoft.digitaltwins/digitaltwinsinstances/timeseriesdatabaseconnections'
            )
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Host Name';            Expression = '$data.hostName' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Endpoint Type';        Expression = '$data.endpointType' }
                @{ Name = 'Identity Type';        Expression = '$1.identity.type' }
            )
        }
        @{
            Category = 'IoT'
            Name = 'Maps'
            Worksheet = 'Azure Maps'
            ResourceTypes = @('microsoft.maps/accounts', 'microsoft.maps/accounts/creators')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'SKU Tier';             Expression = '$1.sku.tier' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Unique Id';            Expression = '$data.uniqueId' }
                @{ Name = 'Local Auth Disabled';  Expression = '[string]$data.disableLocalAuth' }
                @{ Name = 'Storage Units';        Expression = '[string]$data.storageUnits' }
            )
        }
        @{
            Category = 'IoT'
            Name = 'DefenderForIoT'
            Worksheet = 'Defender for IoT'
            ResourceTypes = @(
                'microsoft.iotsecurity/defendersettings'
                'microsoft.iotsecurity/sites'
                'microsoft.iotsecurity/sensors'
                'microsoft.iotsecurity/onpremisesensors'
            )
            Fields = @(
                @{ Name = 'Resource Kind';       Expression = '$1.TYPE' }
                @{ Name = 'Device Quota';        Expression = '[string]$data.deviceQuota' }
                @{ Name = 'Onboarding Kind';     Expression = '$data.onboardingKind' }
                @{ Name = 'Sentinel Workspace';  Expression = '$SentinelWorkspace' }
                @{ Name = 'MDE Integration';     Expression = '$data.mdeIntegration.status' }
                @{ Name = 'Display Name';        Expression = '$data.displayName' }
            )
            Preamble = @'
$SentinelWorkspace = if(![string]::IsNullOrEmpty($data.sentinelWorkspaceResourceIds)){Get-AZSCIdSegment -Id ([string]@($data.sentinelWorkspaceResourceIds)[0]) -Index 8}else{$null}
'@
        }

        # ---------------------------------------------------------------------------------------
        # Child resources (AB#6833 / AB#6834 / AB#6751).
        #
        # `Get-ScoutArmChildResource` COLLECTS these; without a collector to render them the data
        # is fetched on every run and thrown away, which is precisely the collect-versus-display
        # defect §5.3 of the audit is about. Their rows are synthetic `AZSC/ARMChild/*` envelopes,
        # so each declares its own Identity: there is no `tags` column, no retirement record and
        # no subscription join off `$1.subscriptionId` alone.
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Security'
            Name = 'KeyVaultSecrets'
            Worksheet = 'Key Vault Secrets'
            ResourceTypes = @('AZSC/ARMChild/KeyVaultSecrets')
            Identity = @(
                @{ Name = 'ID';             Expression = '$1.id' }
                @{ Name = 'Subscription';   Expression = '$sub1.Name' }
                @{ Name = 'Resource Group'; Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Key Vault';      Expression = '$1.PARENTNAME' }
                @{ Name = 'Secret';         Expression = '$SecretName' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Content Type';   Expression = '$data.contentType' }
                @{ Name = 'Kind';           Expression = '$Kind' }
                @{ Name = 'Enabled';        Expression = '[string]$data.attributes.enabled' }
                @{ Name = 'Expires';        Expression = '$Expires' }
                @{ Name = 'Days To Expiry'; Expression = '[string]$DaysToExpiry' }
                @{ Name = 'Expiry Status';  Expression = '$ExpiryStatus' }
                @{ Name = 'Not Before';     Expression = '$NotBefore' }
                @{ Name = 'Created';        Expression = '$Created' }
                @{ Name = 'Updated';        Expression = '$Updated' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$SecretName = if([string]::IsNullOrEmpty($1.name)){$null}else{(([string]$1.name) -split '/')[-1]}
$Kind = if($data.contentType -match 'x-pkcs12|x-pem-file'){'Certificate'}else{'Secret'}
$Expires = if($null -eq $data.attributes.exp){''}else{[string]([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.exp).ToString('yyyy-MM-dd')}
$DaysToExpiry = if($null -eq $data.attributes.exp){$null}else{[math]::Floor(((([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.exp)) - $ScoutRunTime).TotalDays)}
$ExpiryStatus = if($null -eq $DaysToExpiry){'No expiry set'}elseif($DaysToExpiry -lt 0){'EXPIRED'}elseif($DaysToExpiry -le 30){'Expires within 30 days'}elseif($DaysToExpiry -le 90){'Expires within 90 days'}else{'OK'}
$NotBefore = if($null -eq $data.attributes.nbf){''}else{[string]([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.nbf).ToString('yyyy-MM-dd')}
$Created = if($null -eq $data.attributes.created){''}else{[string]([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.created).ToString('yyyy-MM-dd')}
$Updated = if($null -eq $data.attributes.updated){''}else{[string]([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.updated).ToString('yyyy-MM-dd')}
'@
        }
        @{
            Category = 'Security'
            Name = 'KeyVaultKeys'
            Worksheet = 'Key Vault Keys'
            ResourceTypes = @('AZSC/ARMChild/KeyVaultKeys')
            Identity = @(
                @{ Name = 'ID';             Expression = '$1.id' }
                @{ Name = 'Subscription';   Expression = '$sub1.Name' }
                @{ Name = 'Resource Group'; Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Key Vault';      Expression = '$1.PARENTNAME' }
                @{ Name = 'Key';            Expression = '$KeyName' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Key Type';       Expression = '$data.kty' }
                @{ Name = 'Key Size';       Expression = '[string]$data.keySize' }
                @{ Name = 'Curve';          Expression = '$data.curveName' }
                @{ Name = 'Enabled';        Expression = '[string]$data.attributes.enabled' }
                @{ Name = 'Expires';        Expression = '$Expires' }
                @{ Name = 'Days To Expiry'; Expression = '[string]$DaysToExpiry' }
                @{ Name = 'Expiry Status';  Expression = '$ExpiryStatus' }
                @{ Name = 'Rotation Policy'; Expression = '[string]$data.rotationPolicy.lifetimeActions.Count' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$KeyName = if([string]::IsNullOrEmpty($1.name)){$null}else{(([string]$1.name) -split '/')[-1]}
$Expires = if($null -eq $data.attributes.exp){''}else{[string]([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.exp).ToString('yyyy-MM-dd')}
$DaysToExpiry = if($null -eq $data.attributes.exp){$null}else{[math]::Floor(((([datetime]::UnixEpoch).AddSeconds([double]$data.attributes.exp)) - $ScoutRunTime).TotalDays)}
$ExpiryStatus = if($null -eq $DaysToExpiry){'No expiry set'}elseif($DaysToExpiry -lt 0){'EXPIRED'}elseif($DaysToExpiry -le 30){'Expires within 30 days'}elseif($DaysToExpiry -le 90){'Expires within 90 days'}else{'OK'}
'@
        }
        @{
            # AB#6829. `Reservations` (General/Reservations) already lists what was BOUGHT; this
            # renders what the Microsoft.Consumption `reservationSummaries` child call says about
            # how much of it is USED. Field names follow the documented ReservationSummary schema
            # (learn.microsoft.com/javascript/api/@azure/arm-consumption/reservationsummary) --
            # unverified against a live tenant, same caveat as every other ARMChild collector here.
            # A reservation whose most recent monthly grain has not closed yet produces no child
            # row at all (see Get-ScoutArmChildResource), which is an absence, not a zero -- the
            # vault-with-no-items class this file's Key Vault collectors also have to get right.
            Category = 'General'
            Name = 'ReservationUtilization'
            Worksheet = 'Reservation Utilization'
            ResourceTypes = @('AZSC/ARMChild/ReservationUtilization')
            Identity = @(
                @{ Name = 'ID';           Expression = '$1.PARENTID' }
                @{ Name = 'Subscription'; Expression = '$SubName' }
                @{ Name = 'Reservation';  Expression = '$1.PARENTNAME' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'SKU';                    Expression = '$data.skuName' }
                @{ Name = 'Usage Date';              Expression = '[string]$data.usageDate' }
                @{ Name = 'Reserved Hours';          Expression = '[string]$data.reservedHours' }
                @{ Name = 'Used Hours';              Expression = '[string]$data.usedHours' }
                @{ Name = 'Avg Utilization %';       Expression = '[string]$data.avgUtilizationPercentage' }
                @{ Name = 'Min Utilization %';       Expression = '[string]$data.minUtilizationPercentage' }
                @{ Name = 'Max Utilization %';       Expression = '[string]$data.maxUtilizationPercentage' }
                @{ Name = 'Purchased Quantity';      Expression = '[string]$data.purchasedQuantity' }
                @{ Name = 'Remaining Quantity';      Expression = '[string]$data.remainingQuantity' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$SubName = $sub1.Name
'@
        }
        @{
            Category = 'Storage'
            Name = 'BlobContainers'
            Worksheet = 'Blob Containers'
            ResourceTypes = @('AZSC/ARMChild/StorageBlobContainers')
            Identity = @(
                @{ Name = 'ID';              Expression = '$1.id' }
                @{ Name = 'Subscription';    Expression = '$sub1.Name' }
                @{ Name = 'Resource Group';  Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Storage Account'; Expression = '$1.PARENTNAME' }
                @{ Name = 'Container';       Expression = '$ContainerName' }
            )
            TagLoop = $null
            Fields = @(
                # 'Public Access' and the exposure verdict are the reason this collector exists: a
                # storage-account list cannot say whether anything inside it is anonymously
                # reachable, and that is the highest-severity finding in most Azure estates.
                @{ Name = 'Public Access';        Expression = '$PublicAccess' }
                @{ Name = 'Anonymous Access';     Expression = '$AnonymousAccess' }
                @{ Name = 'Lease State';          Expression = '$data.leaseState' }
                @{ Name = 'Lease Status';         Expression = '$data.leaseStatus' }
                @{ Name = 'Immutability Policy';  Expression = '[string]$data.hasImmutabilityPolicy' }
                @{ Name = 'Legal Hold';           Expression = '[string]$data.hasLegalHold' }
                @{ Name = 'Version Level WORM';   Expression = '[string]$data.isVersionLevelWormEnabled' }
                @{ Name = 'Last Modified';        Expression = '[string]$data.lastModifiedTime' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$ContainerName = if([string]::IsNullOrEmpty($1.name)){$null}else{(([string]$1.name) -split '/')[-1]}
$PublicAccess = if([string]::IsNullOrEmpty($data.publicAccess)){'None'}else{[string]$data.publicAccess}
$AnonymousAccess = if($PublicAccess -eq 'Container'){'YES - full anonymous read of blobs AND container listing'}elseif($PublicAccess -eq 'Blob'){'YES - anonymous read of blobs'}else{'No'}
'@
        }
        @{
            Category = 'Storage'
            Name = 'FileShares'
            Worksheet = 'File Shares'
            ResourceTypes = @('AZSC/ARMChild/StorageFileShares')
            Identity = @(
                @{ Name = 'ID';              Expression = '$1.id' }
                @{ Name = 'Subscription';    Expression = '$sub1.Name' }
                @{ Name = 'Resource Group';  Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Storage Account'; Expression = '$1.PARENTNAME' }
                @{ Name = 'Share';           Expression = '$ShareName' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Quota (GiB)';      Expression = '[string]$data.shareQuota' }
                @{ Name = 'Access Tier';      Expression = '$data.accessTier' }
                @{ Name = 'Protocols';        Expression = '$data.enabledProtocols' }
                @{ Name = 'Root Squash';      Expression = '$data.rootSquash' }
                @{ Name = 'Snapshot Count';   Expression = '[string]$data.snapshotCount' }
                @{ Name = 'Last Modified';    Expression = '[string]$data.lastModifiedTime' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$ShareName = if([string]::IsNullOrEmpty($1.name)){$null}else{(([string]$1.name) -split '/')[-1]}
'@
        }
        @{
            Category = 'Storage'
            Name = 'LifecyclePolicies'
            Worksheet = 'Storage Lifecycle Policies'
            ResourceTypes = @('AZSC/ARMChild/StorageLifecyclePolicies')
            Identity = @(
                @{ Name = 'ID';              Expression = '$1.id' }
                @{ Name = 'Subscription';    Expression = '$sub1.Name' }
                @{ Name = 'Resource Group';  Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Storage Account'; Expression = '$1.PARENTNAME' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Rule Count';      Expression = '[string]$RuleCount' }
                @{ Name = 'Enabled Rules';   Expression = '[string]$EnabledRules' }
                @{ Name = 'Rule Names';      Expression = '$RuleNames' }
                @{ Name = 'Last Modified';   Expression = '[string]$data.lastModifiedTime' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$LifecycleRules = @($data.policy.rules)
$RuleCount = $LifecycleRules.Count
$EnabledRules = @($LifecycleRules | Where-Object { $_.enabled -ne $false }).Count
$RuleNames = [string](@($LifecycleRules | ForEach-Object { $_.name }) -join ', ')
'@
        }
        @{
            Category = 'Management'
            Name = 'BackupInstances'
            Worksheet = 'Backup Instances'
            ResourceTypes = @('AZSC/ARMChild/BackupInstances')
            Identity = @(
                @{ Name = 'ID';             Expression = '$1.id' }
                @{ Name = 'Subscription';   Expression = '$sub1.Name' }
                @{ Name = 'Resource Group'; Expression = '$1.RESOURCEGROUP' }
                @{ Name = 'Backup Vault';   Expression = '$1.PARENTNAME' }
                @{ Name = 'Instance';       Expression = '$InstanceName' }
            )
            TagLoop = $null
            Fields = @(
                @{ Name = 'Friendly Name';      Expression = '$data.friendlyName' }
                @{ Name = 'Datasource Type';    Expression = '$data.dataSourceInfo.datasourceType' }
                @{ Name = 'Protected Resource'; Expression = '$ProtectedResource' }
                @{ Name = 'Protection State';   Expression = '$data.currentProtectionState' }
                @{ Name = 'Protection Status';  Expression = '$data.protectionStatus.status' }
                @{ Name = 'Policy';             Expression = '$PolicyName' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
            )
            Preamble = @'
$sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
$InstanceName = if([string]::IsNullOrEmpty($1.name)){$null}else{(([string]$1.name) -split '/')[-1]}
$ProtectedResource = if([string]::IsNullOrEmpty($data.dataSourceInfo.resourceID)){$null}else{(Get-AZSCIdSegment -Id $data.dataSourceInfo.resourceID -Index 8)}
$PolicyName = if([string]::IsNullOrEmpty($data.policyInfo.policyId)){$null}else{(Get-AZSCIdSegment -Id $data.policyInfo.policyId -Index 10)}
'@
        }

        # ---------------------------------------------------------------------------------------
        # Security — 6 of 22, and the most damaging gap: a security-posture tool that sees a third
        # of the security services (AB#6837).
        # ---------------------------------------------------------------------------------------
        @{
            Category = 'Security'
            Name = 'Sentinel'
            Worksheet = 'Sentinel'
            ResourceTypes = @('microsoft.operationsmanagement/solutions', 'microsoft.securityinsights/onboardingstates')
            # A Sentinel deployment surfaces in the `resources` table as an OMS solution named
            # `SecurityInsights(<workspace>)`. Matching the whole solutions type would sweep in
            # every other OMS solution in the estate, so the name is the discriminator.
            AdditionalFilter = '$_.TYPE -eq ''microsoft.securityinsights/onboardingstates'' -or $_.NAME -like ''SecurityInsights*'''
            Fields = @(
                @{ Name = 'Resource Kind';    Expression = '$1.TYPE' }
                @{ Name = 'Workspace';        Expression = '$Workspace' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Customer Managed Key'; Expression = '[string]$data.customerManagedKey' }
                @{ Name = 'Plan';             Expression = '$1.plan.name' }
            )
            Preamble = @'
$Workspace = if(![string]::IsNullOrEmpty($data.workspaceResourceId)){Get-AZSCIdSegment -Id $data.workspaceResourceId -Index 8}else{$null}
'@
        }
        @{
            Category = 'Security'
            Name = 'ManagedHSM'
            Worksheet = 'Managed HSM'
            ResourceTypes = @('microsoft.keyvault/managedhsms')
            Fields = @(
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'SKU Family';           Expression = '$1.sku.family' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'HSM URI';              Expression = '$data.hsmUri' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Purge Protection';     Expression = '[string]$data.enablePurgeProtection' }
                @{ Name = 'Soft Delete Days';     Expression = '[string]$data.softDeleteRetentionInDays' }
                @{ Name = 'Security Domain';      Expression = '$data.securityDomainProperties.activationStatus' }
            )
        }
        @{
            Category = 'Security'
            Name = 'CloudHSM'
            Worksheet = 'Cloud HSM'
            ResourceTypes = @('microsoft.hardwaresecuritymodules/cloudhsmclusters')
            Fields = @(
                @{ Name = 'Resource Kind';        Expression = '$1.TYPE' }
                @{ Name = 'SKU';                  Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State';   Expression = '$data.provisioningState' }
                @{ Name = 'Public Network Access'; Expression = '$data.publicNetworkAccess' }
                @{ Name = 'Auto Generated Domain'; Expression = '[string]$data.autoGeneratedDomainNameLabelScope' }
                @{ Name = 'Stamp Id';             Expression = '$data.stampId' }
            )
        }
        @{
            Category = 'Security'
            Name = 'ApplicationSecurityGroups'
            Worksheet = 'App Security Groups'
            ResourceTypes = @('microsoft.network/applicationsecuritygroups')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Resource GUID';      Expression = '$data.resourceGuid' }
            )
        }
        @{
            Category = 'Security'
            Name = 'WafPolicies'
            Worksheet = 'WAF Policies'
            ResourceTypes = @(
                'microsoft.network/applicationgatewaywebapplicationfirewallpolicies'
                'microsoft.network/frontdoorwebapplicationfirewallpolicies'
                'microsoft.cdn/cdnwebapplicationfirewallpolicies'
            )
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'SKU';                Expression = '$1.sku.name' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Enabled State';      Expression = '$EnabledState' }
                @{ Name = 'Mode';               Expression = '$Mode' }
                @{ Name = 'Managed Rule Sets';  Expression = '[string]@($data.managedRules.managedRuleSets).Count' }
                @{ Name = 'Custom Rules';       Expression = '[string]$CustomRuleCount' }
                @{ Name = 'Associations';       Expression = '[string]$AssociationCount' }
            )
            Preamble = @'
$EnabledState = if(![string]::IsNullOrEmpty($data.policySettings.enabledState)){$data.policySettings.enabledState}else{[string]$data.policySettings.state}
$Mode = $data.policySettings.mode
$CustomRuleCount = if($null -ne $data.customRules.rules){@($data.customRules.rules).Count}else{@($data.customRules).Count}
$AssociationCount = @($data.applicationGateways).Count + @($data.httpListeners).Count + @($data.pathBasedRules).Count + @($data.frontendEndpointLinks).Count
'@
        }
        @{
            Category = 'Security'
            Name = 'DdosProtectionPlans'
            Worksheet = 'DDoS Protection Plans'
            ResourceTypes = @('microsoft.network/ddosprotectionplans')
            Fields = @(
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Protected VNETs';    Expression = '[string]@($data.virtualNetworks).Count' }
                @{ Name = 'Public IP Count';    Expression = '[string]@($data.publicIPAddresses).Count' }
                @{ Name = 'Resource GUID';      Expression = '$data.resourceGuid' }
            )
        }
        @{
            Category = 'Security'
            Name = 'ConfidentialLedger'
            Worksheet = 'Confidential Ledger'
            ResourceTypes = @('microsoft.confidentialledger/ledgers')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Ledger Type';        Expression = '$data.ledgerType' }
                @{ Name = 'Ledger URI';         Expression = '$data.ledgerUri' }
                @{ Name = 'Identity Service';   Expression = '$data.identityServiceUri' }
                @{ Name = 'Running State';      Expression = '$data.runningState' }
            )
        }
        @{
            Category = 'Security'
            Name = 'ArtifactSigning'
            Worksheet = 'Artifact Signing'
            ResourceTypes = @('microsoft.codesigning/codesigningaccounts')
            Fields = @(
                @{ Name = 'SKU';                Expression = '$data.sku.name' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Account URI';        Expression = '$data.accountUri' }
            )
        }
        @{
            Category = 'Security'
            Name = 'EntraDomainServices'
            Worksheet = 'Entra Domain Services'
            ResourceTypes = @('microsoft.aad/domainservices')
            Fields = @(
                @{ Name = 'Domain Name';         Expression = '$data.domainName' }
                @{ Name = 'SKU';                 Expression = '$data.sku' }
                @{ Name = 'Provisioning State';  Expression = '$data.provisioningState' }
                @{ Name = 'Sync Scope';          Expression = '$data.syncScope' }
                @{ Name = 'TLS v1 Enabled';      Expression = '$data.domainSecuritySettings.tlsV1' }
                @{ Name = 'NTLM v1 Enabled';     Expression = '$data.domainSecuritySettings.ntlmV1' }
                @{ Name = 'Kerberos RC4';        Expression = '$data.domainSecuritySettings.kerberosRc4Encryption' }
                @{ Name = 'LDAPS Enabled';       Expression = '$data.ldapsSettings.ldaps' }
                @{ Name = 'LDAPS External';      Expression = '$data.ldapsSettings.externalAccess' }
            )
        }
        @{
            Category = 'Security'
            Name = 'AppComplianceAutomation'
            Worksheet = 'App Compliance Automation'
            ResourceTypes = @('microsoft.appcomplianceautomation/reports', 'microsoft.appcomplianceautomation/reports/snapshots')
            Fields = @(
                @{ Name = 'Resource Kind';      Expression = '$1.TYPE' }
                @{ Name = 'Provisioning State'; Expression = '$data.provisioningState' }
                @{ Name = 'Status';             Expression = '$data.status' }
                @{ Name = 'Trigger Time';       Expression = '[string]$data.triggerTime' }
                @{ Name = 'Time Zone';          Expression = '$data.timeZone' }
                @{ Name = 'Resource Count';     Expression = '[string]@($data.resources).Count' }
            )
        }
    )
}
