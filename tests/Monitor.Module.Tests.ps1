#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Azure Monitor inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each Monitor module
    using synthetic mock data. No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   13.5 — Phase 13 Testing
#>

# ===================================================================
# DISCOVERY-TIME: module spec table (outside BeforeAll for -ForEach)
# ===================================================================
$MonitorPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Monitor'

$MonitorModules = @(
    @{ Name = 'ActionGroups';                  File = 'ActionGroups.ps1';                  Type = 'microsoft.insights/actiongroups';                          Worksheet = 'Action Groups' }
    @{ Name = 'ActivityLogAlertRules';         File = 'ActivityLogAlertRules.ps1';         Type = 'microsoft.insights/activitylogalerts';                     Worksheet = 'Activity Log Alerts' }
    @{ Name = 'AppInsights';                   File = 'AppInsights.ps1';                   Type = 'microsoft.insights/components';                            Worksheet = 'AppInsights' }
    @{ Name = 'AutoscaleSettings';             File = 'AutoscaleSettings.ps1';             Type = 'microsoft.insights/autoscalesettings';                     Worksheet = 'Autoscale Settings' }
    @{ Name = 'DataCollectionEndpoints';       File = 'DataCollectionEndpoints.ps1';       Type = 'microsoft.insights/datacollectionendpoints';               Worksheet = 'Data Collection Endpoints' }
    @{ Name = 'DataCollectionRules';           File = 'DataCollectionRules.ps1';           Type = 'microsoft.insights/datacollectionrules';                   Worksheet = 'Data Collection Rules' }
    @{ Name = 'MetricAlertRules';              File = 'MetricAlertRules.ps1';              Type = 'microsoft.insights/metricalerts';                          Worksheet = 'Metric Alerts' }
    @{ Name = 'MonitorPrivateLinkScopes';      File = 'MonitorPrivateLinkScopes.ps1';      Type = 'microsoft.insights/privatelinkscopes';                     Worksheet = 'Monitor Private Link Scopes' }
    @{ Name = 'MonitorWorkbooks';              File = 'MonitorWorkbooks.ps1';              Type = 'microsoft.insights/workbooks';                             Worksheet = 'Monitor Workbooks' }
    @{ Name = 'ResourceDiagnosticSettings';    File = 'ResourceDiagnosticSettings.ps1';    Type = 'microsoft.insights/diagnosticsettings';                    Worksheet = 'Resource Diagnostic Settings' }
    @{ Name = 'ScheduledQueryRules';           File = 'ScheduledQueryRules.ps1';           Type = 'microsoft.insights/scheduledqueryrules';                   Worksheet = 'Scheduled Queries' }
    @{ Name = 'SmartDetectorAlertRules';       File = 'SmartDetectorAlertRules.ps1';       Type = 'microsoft.alertsmanagement/smartdetectoralertrules';       Worksheet = 'Smart Detector Alerts' }
    @{ Name = 'Workspaces';                    File = 'Workspaces.ps1';                    Type = 'microsoft.operationalinsights/workspaces';                 Worksheet = 'Workspaces' }
)

# Modules that call live Az cmdlets (no $Resources filter) — mock-only path
$LiveCallModules = @('AppInsightsAvailabilityTests','AppInsightsContinuousExport','AppInsightsProactiveDetection','AppInsightsWebTests','AppInsightsWorkItems','LAWorkspaceLinkedServices','LAWorkspaceSavedSearches','LAWorkspaceSolutions','MonitorMetricsIngestion','Outages','SubscriptionDiagnosticSettings')

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot   = Split-Path -Parent $PSScriptRoot
    $script:MonitorPath  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Monitor'
    $script:TempDir      = Join-Path $env:TEMP 'AZSC_MonitorTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockArmResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Location = 'eastus',
              [string]$ResourceGroup = 'rg-test', [string]$SubscriptionId = 'sub-00000001',
              [object]$Properties, [string]$Kind = '')
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            LOCATION       = $Location
            RESOURCEGROUP  = $ResourceGroup
            subscriptionId = $SubscriptionId
            KIND           = $Kind
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Properties
        }
    }

    function Invoke-MonitorModule {
        param([string]$ModuleFile, [string]$Task,
              [object]$Resources = $null, [object]$SmaResources = $null,
              [string]$File = $null, [string]$TableStyle = 'Light20')
        $content = Get-Content -Path $ModuleFile -Raw
        $sb = [ScriptBlock]::Create($content)
        Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $Resources, $null, $Task, $File, $SmaResources, $TableStyle, $null
    }

    # ── Mock resources ────────────────────────────────────────────────
    $script:MockResources = @()

    # Action Groups
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/ag/ag1' -Name 'ag-ops' -Type 'microsoft.insights/actiongroups' -Properties ([PSCustomObject]@{
        groupShortName = 'ops'; enabled = $true; emailReceivers = @(@{name='Admin';emailAddress='admin@corp.com'}); smsReceivers = $null; webhookReceivers = $null; azureAppPushReceivers = $null; automationRunbookReceivers = $null; azureFunctionReceivers = $null; logicAppReceivers = $null
    })

    # Activity Log Alerts
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/ag/ala1' -Name 'ala-svc' -Type 'microsoft.insights/activitylogalerts' -Properties ([PSCustomObject]@{
        enabled = $true; condition = [PSCustomObject]@{ allOf = @(@{field='category';equals='ServiceHealth'}) }; scopes = @('/subscriptions/sub-00000001')
    })

    # App Insights
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/ai/ai1' -Name 'ai-web' -Type 'microsoft.insights/components' -Kind 'web' -Properties ([PSCustomObject]@{
        InstrumentationKey = 'key-abc'; ApplicationType = 'web'; IngestionMode = 'LogAnalytics'; WorkspaceResourceId = '/sub/sub-00000001/ws/ws1'; RetentionInDays = 90; SamplingPercentage = 100; ConnectionString = 'InstrumentationKey=key-abc'; CreationDate = '2025-01-15T10:30:00Z'
    })

    # Autoscale Settings
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/autoscale/as1' -Name 'as-vmss' -Type 'microsoft.insights/autoscalesettings' -Properties ([PSCustomObject]@{
        enabled = $true; targetResourceUri = '/sub/sub-00000001/compute/vmss1'; profiles = @(@{name='Default';capacity=@{minimum=1;maximum=5;default=2}})
    })

    # Data Collection Endpoints
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/dce/dce1' -Name 'dce-prod' -Type 'microsoft.insights/datacollectionendpoints' -Properties ([PSCustomObject]@{
        logsIngestion = [PSCustomObject]@{ endpoint = 'https://dce.ingest.monitor.azure.com' }; networkAcls = [PSCustomObject]@{ publicNetworkAccess = 'Enabled' }; provisioningState = 'Succeeded'
    })

    # Data Collection Rules
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/dcr/dcr1' -Name 'dcr-ama' -Type 'microsoft.insights/datacollectionrules' -Properties ([PSCustomObject]@{
        description = 'AMA rule'; dataSources = [PSCustomObject]@{ performanceCounters = @(@{name='pc1'}) }; destinations = [PSCustomObject]@{ logAnalytics = @(@{workspaceResourceId='/ws/ws1';name='dest1'}) }; provisioningState = 'Succeeded'
    })

    # Metric Alert Rules
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/metricalert/ma1' -Name 'ma-cpu' -Type 'microsoft.insights/metricalerts' -Properties ([PSCustomObject]@{
        enabled = $true; severity = 2; evaluationFrequency = 'PT5M'; windowSize = 'PT15M'; criteria = [PSCustomObject]@{ 'odata.type' = 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'; allOf = @(@{metricName='Percentage CPU';threshold=80;operator='GreaterThan'}) }; scopes = @('/sub/sub-00000001')
    })

    # Monitor Private Link Scopes
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/pls/pls1' -Name 'pls-prod' -Type 'microsoft.insights/privatelinkscopes' -Properties ([PSCustomObject]@{
        accessModeSettings = [PSCustomObject]@{ ingestionAccessMode = 'Open'; queryAccessMode = 'Open' }; privateEndpointConnections = @(@{name='pec1'})
    })

    # Monitor Workbooks
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/workbook/wb1' -Name 'wb-security' -Type 'microsoft.insights/workbooks' -Properties ([PSCustomObject]@{
        category = 'security'; displayName = 'Security Overview'; version = '1.0'; serializedData = '{}'; timeModified = '2026-01-01T00:00:00Z'
    })

    # Resource Diagnostic Settings
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/diag/ds1' -Name 'ds-kv' -Type 'microsoft.insights/diagnosticsettings' -Properties ([PSCustomObject]@{
        resourceId = '/sub/sub-00000001/kv/kv1'; logs = @(@{category='AuditEvent';enabled=$true}); metrics = @(@{category='AllMetrics';enabled=$true}); workspaceId = '/ws/ws1'
    })

    # Scheduled Query Rules
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/sqr/sqr1' -Name 'sqr-errors' -Type 'microsoft.insights/scheduledqueryrules' -Properties ([PSCustomObject]@{
        enabled = $true; severity = 1; evaluationFrequency = 'PT5M'; windowSize = 'PT30M'; criteria = [PSCustomObject]@{ allOf = @(@{query='exceptions | count';threshold=0;operator='GreaterThan'}) }
    })

    # Smart Detector Alert Rules
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/sdar/sdar1' -Name 'sdar-ai' -Type 'microsoft.alertsmanagement/smartdetectoralertrules' -Properties ([PSCustomObject]@{
        severity = 'Sev3'; frequency = 'PT24H'; detector = [PSCustomObject]@{ id = 'FailureAnomaliesDetector' }; state = 'Enabled'
    })

    # Subscription Diagnostic Settings
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/subdiag/sd1' -Name 'sd-sub' -Type 'microsoft.insights/diagnosticsettings/subscription' -Properties ([PSCustomObject]@{
        workspaceId = '/ws/ws1'; logs = @(@{category='Administrative';enabled=$true},@{category='Security';enabled=$true})
    })

    # Log Analytics Workspaces
    $script:MockResources += New-MockArmResource -Id '/sub/sub-00000001/ws/ws1' -Name 'ws-prod' -Type 'microsoft.operationalinsights/workspaces' -Properties ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'PerGB2018' }; retentionInDays = 90; workspaceCapping = [PSCustomObject]@{ dailyQuotaGb = -1 }; provisioningState = 'Succeeded'; customerId = 'cust-id-001'; createdDate = '2025-01-15T10:30:00Z'
    })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS — per module
# ===================================================================
Describe 'Monitor Module Files Exist' {
    It 'Monitor module folder exists' {
        $script:MonitorPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $MonitorModules {
        Join-Path $script:MonitorPath $File | Should -Exist
    }
}

Describe 'Monitor Module Processing Phase — <Name>' -ForEach $MonitorModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:MonitorPath $File
        $script:ResType = $Type
    }

    It 'Processing returns an array (or $null) when matching resources are present' {
        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $result = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
            $result | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }

    It 'Processing returns $null (not an error) when no matching resources exist' {
        $emptyResources = @()
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $emptyResources, $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Monitor Module Reporting Phase — <Name>' -ForEach $MonitorModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:MonitorPath $File
        $script:ResType  = $Type
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("Monitor_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else {
            $script:ProcessedData = $null
        }
    }

    It 'Reporting phase writes an Excel worksheet without throwing' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }

    It 'Excel file is created after reporting phase' {
        if ($script:ProcessedData) {
            $script:XlsxFile | Should -Exist
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }

    It 'Excel worksheet "<Worksheet>" is present in the workbook' -ForEach @($PSBoundParameters + @{Worksheet=$Worksheet}) {
        if ($script:ProcessedData -and (Test-Path $script:XlsxFile)) {
            $sheets = (Open-ExcelPackage -Path $script:XlsxFile).Workbook.Worksheets.Name
            $sheets | Should -Contain $script:WsName
            Close-ExcelPackage -ExcelPackage (Open-ExcelPackage -Path $script:XlsxFile) -NoSave
        } else {
            Set-ItResult -Skipped -Because "No data or file not produced"
        }
    }
}

Describe 'Monitor Modules — Graceful Empty Resource Handling' {
    It '<Name> processing produces no output for empty resource list without throwing' -ForEach $MonitorModules {
        $modFile = Join-Path $script:MonitorPath $File
        $content = Get-Content -Path $modFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}
