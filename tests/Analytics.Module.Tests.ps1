#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Analytics inventory modules.
.DESCRIPTION
    Tests both Processing and Reporting phases for each Analytics module
    using synthetic mock data. No live Azure authentication is required.
.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-25
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$AnalyticsPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Analytics'

$AnalyticsModules = @(
    @{ Name = 'Databricks';          File = 'Databricks.ps1';          Type = 'microsoft.databricks/workspaces';           Worksheet = 'Databricks' }
    @{ Name = 'DataExplorerCluster'; File = 'DataExplorerCluster.ps1'; Type = 'microsoft.kusto/clusters';                  Worksheet = 'Data Explorer Clusters' }
    @{ Name = 'EvtHub';              File = 'EvtHub.ps1';              Type = 'microsoft.eventhub/namespaces';              Worksheet = 'Event Hubs' }
    @{ Name = 'Purview';             File = 'Purview.ps1';             Type = 'microsoft.purview/accounts';                 Worksheet = 'Purview' }
    @{ Name = 'Streamanalytics';     File = 'Streamanalytics.ps1';     Type = 'microsoft.streamanalytics/streamingjobs';    Worksheet = 'Stream Analytics Jobs' }
    @{ Name = 'Synapse';             File = 'Synapse.ps1';             Type = 'microsoft.synapse/workspaces';               Worksheet = 'Synapse' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:AnalyticsPath  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Analytics'
    $script:TempDir        = Join-Path $env:TEMP 'AZSC_AnalyticsTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockAnalyticsResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-analytics',
              [string]$SubscriptionId = 'sub-00000001', [object]$Props, [object]$SKU = $null)
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            KIND           = $Kind
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Props
            SKU            = $SKU
        }
    }

    $script:MockResources = @()

    # --- Databricks ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.databricks/workspaces/dbw-prod' `
        -Name 'dbw-prod' -Type 'microsoft.databricks/workspaces' `
        -SKU ([PSCustomObject]@{ name = 'premium'; tier = 'Premium' }) `
        -Props ([PSCustomObject]@{
            createdDateTime = '2025-06-15T10:00:00Z'
            parameters = [PSCustomObject]@{
                enableNoPublicIp = [PSCustomObject]@{ value = 'False' }
                customVirtualNetworkId = [PSCustomObject]@{ value = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-dbw/subnets/private' }
                storageAccountName = [PSCustomObject]@{ value = 'sadbwprod01' }
                storageAccountSkuName = [PSCustomObject]@{ value = 'Standard_LRS' }
                requireInfrastructureEncryption = [PSCustomObject]@{ value = $true }
                prepareEncryption = [PSCustomObject]@{ value = $false }
                customPrivateSubnetName = [PSCustomObject]@{ value = 'private-subnet' }
                customPublicSubnetName = [PSCustomObject]@{ value = 'public-subnet' }
            }
            managedResourceGroupId = '/subscriptions/sub-00000001/resourceGroups/rg-dbw-managed/providers/foo/bar'
            workspaceUrl = 'adb-123456.azuredatabricks.net'
        })

    # --- Data Explorer Cluster ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.kusto/clusters/dec-prod' `
        -Name 'dec-prod' -Type 'microsoft.kusto/clusters' `
        -SKU ([PSCustomObject]@{ name = 'Standard_D13_v2'; capacity = 2 }) `
        -Props ([PSCustomObject]@{
            state = 'Running'; stateReason = ''
            virtualNetworkConfiguration = [PSCustomObject]@{
                subnetid = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-kusto/subnets/kusto-subnet'
                dataManagementPublicIpId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/publicIPAddresses/pip-kusto-dm'
                enginePublicIpId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/publicIPAddresses/pip-kusto-engine'
            }
            trustedExternalTenants = @([PSCustomObject]@{ value = '*' })
            optimizedAutoscale = [PSCustomObject]@{ isEnabled = 'true'; minimum = 2; maximum = 10 }
            enableDiskEncryption = $true; enableStreamingIngest = $true
            uri = 'https://dec-prod.eastus.kusto.windows.net'
            dataIngestionUri = 'https://ingest-dec-prod.eastus.kusto.windows.net'
        })

    # --- Event Hub ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.eventhub/namespaces/eh-prod' `
        -Name 'eh-prod' -Type 'microsoft.eventhub/namespaces' `
        -SKU ([PSCustomObject]@{ name = 'Standard'; capacity = 2 }) `
        -Props ([PSCustomObject]@{
            createdAt = '2025-03-10T08:30:00Z'; status = 'Active'
            zoneRedundant = $true; disablelocalauth = $false
            isAutoInflateEnabled = $true; maximumThroughputUnits = 20
            kafkaEnabled = $true; minimumtlsversion = '1.2'
            serviceBusEndpoint = 'https://eh-prod.servicebus.windows.net:443/'
        })

    # --- Purview ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.purview/accounts/purv-prod' `
        -Name 'purv-prod' -Type 'microsoft.purview/accounts' `
        -Props ([PSCustomObject]@{
            cloudConnectors = @([PSCustomObject]@{ id = 'cc1' })
            privateEndpointConnections = @([PSCustomObject]@{ id = 'pe1' }, [PSCustomObject]@{ id = 'pe2' })
            createdAt = '2025-01-20T14:00:00Z'
            sku = [PSCustomObject]@{ name = 'Standard'; capacity = 1 }
            friendlyName = 'Production Purview'
            managedResourceGroupName = 'rg-purview-managed'
            managedResources = [PSCustomObject]@{
                storageAccount = '/subscriptions/sub-00000001/resourceGroups/rg-purview/providers/Microsoft.Storage/storageAccounts/sapurvprod'
                eventHubNamespace = '/subscriptions/sub-00000001/resourceGroups/rg-purview/providers/Microsoft.EventHub/namespaces/ehpurvprod'
            }
            publicNetworkAccess = 'Enabled'
            createdBy = 'admin@contoso.com'
        })

    # --- Stream Analytics (needs both cluster and job resources) ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.streamanalytics/clusters/sac-prod' `
        -Name 'sac-prod' -Type 'microsoft.streamanalytics/clusters' `
        -SKU ([PSCustomObject]@{ name = 'Default'; capacity = 36 }) `
        -Props ([PSCustomObject]@{
            capacityallocated = 36; capacityassigned = 12
            createddate = '2025-02-01T10:00:00Z'
        })

    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.streamanalytics/streamingjobs/saj-transform' `
        -Name 'saj-transform' -Type 'microsoft.streamanalytics/streamingjobs' `
        -Props ([PSCustomObject]@{
            cluster = [PSCustomObject]@{ id = '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.streamanalytics/clusters/sac-prod' }
            createdDate = '2025-04-01T09:00:00Z'
            sku = [PSCustomObject]@{ name = 'Standard' }
            compatibilityLevel = '1.2'
            jobstorageaccount = [PSCustomObject]@{ accountname = 'sajstorage01'; authenticationmode = 'ConnectionString' }
            contentStoragePolicy = 'SystemAccount'
            dataLocale = 'en-US'
            eventsLateArrivalMaxDelayInSeconds = 5
            eventsOutOfOrderMaxDelayInSeconds = 0
            eventsOutOfOrderPolicy = 'Adjust'
            jobState = 'Running'; jobType = 'Cloud'
            lastOutputEventTime = '2025-06-01T12:00:00Z'
            outputStartTime = '2025-04-01T10:00:00Z'
            outputErrorPolicy = 'Stop'
        })

    # --- Synapse ---
    $script:MockResources += New-MockAnalyticsResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-analytics/providers/microsoft.synapse/workspaces/syn-prod' `
        -Name 'syn-prod' -Type 'microsoft.synapse/workspaces' `
        -Props ([PSCustomObject]@{
            publicNetworkAccess = 'Enabled'
            privateEndpointConnections = @([PSCustomObject]@{ id = 'pe1' })
            encryption = [PSCustomObject]@{ doubleEncryptionEnabled = $true }
            trustedServiceBypassEnabled = $true
            sqlAdministratorLogin = 'sqladmin'
            extraProperties = [PSCustomObject]@{ IsScopeEnabled = $true; WorkspaceType = 'Normal' }
            managedVirtualNetworkSettings = [PSCustomObject]@{ preventDataExfiltration = $true }
            managedVirtualNetwork = 'default'
            managedResourceGroupName = 'rg-synapse-managed'
        })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'Analytics Module Files Exist' {
    It 'Analytics module folder exists' {
        $script:AnalyticsPath | Should -Exist
    }
    It '<Name> module file exists' -ForEach $AnalyticsModules {
        Join-Path $script:AnalyticsPath $File | Should -Exist
    }
}

Describe 'Analytics Module Processing Phase — <Name>' -ForEach $AnalyticsModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:AnalyticsPath $File
        $script:ResType = $Type
    }
    It 'Processing returns results when matching resources are present' {
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
    It 'Processing does not throw when given an empty resource list' {
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Analytics Module Reporting Phase — <Name>' -ForEach $AnalyticsModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:AnalyticsPath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("Analytics_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else {
            $script:ProcessedData = $null
        }
    }
    It 'Reporting phase does not throw' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }
    It 'Excel file is created' {
        if ($script:ProcessedData) {
            $script:XlsxFile | Should -Exist
        } else {
            Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'"
        }
    }
}
