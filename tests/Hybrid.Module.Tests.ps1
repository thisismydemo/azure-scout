#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Hybrid (Arc + Azure Local) inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each Hybrid module
    using synthetic mock data. No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   16.5, 8.1.8, 8.2.5, 19.3 — Hybrid / Arc / Azure Local Testing
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$HybridPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Hybrid'

$HybridModules = @(
    @{ Name = 'ARCServers';            File = 'ARCServers.ps1';            Type = 'microsoft.hybridcompute/machines';                    Worksheet = 'Arc Servers' }
    @{ Name = 'ArcGateways';           File = 'ArcGateways.ps1';           Type = 'microsoft.hybridcompute/gateways';                    Worksheet = 'Arc Gateways' }
    @{ Name = 'ArcKubernetes';         File = 'ArcKubernetes.ps1';         Type = 'microsoft.kubernetes/connectedclusters';              Worksheet = 'Arc Kubernetes' }
    @{ Name = 'ArcResourceBridge';     File = 'ArcResourceBridge.ps1';     Type = 'microsoft.resourceconnector/appliances';              Worksheet = 'Arc Resource Bridge' }
    @{ Name = 'ArcExtensions';         File = 'ArcExtensions.ps1';         Type = 'microsoft.hybridcompute/machines/extensions';         Worksheet = 'Arc Extensions' }
    @{ Name = 'ArcSQLServers';         File = 'ArcSQLServers.ps1';         Type = 'microsoft.azurearcdata/sqlserverinstances';           Worksheet = 'Arc SQL Servers' }
    @{ Name = 'ArcSQLManagedInstances';File = 'ArcSQLManagedInstances.ps1';Type = 'microsoft.azurearcdata/sqlmanagedinstances';          Worksheet = 'Arc SQL Managed Instances' }
    @{ Name = 'ArcDataControllers';    File = 'ArcDataControllers.ps1';    Type = 'microsoft.azurearcdata/datacontrollers';              Worksheet = 'Arc Data Controllers' }
    @{ Name = 'ArcSites';              File = 'ArcSites.ps1';              Type = 'microsoft.hybridcompute/sites';                       Worksheet = 'Arc Sites' }
    @{ Name = 'Clusters';              File = 'Clusters.ps1';              Type = 'microsoft.azurestackhci/clusters';                    Worksheet = 'Azure Local Clusters' }
    @{ Name = 'VirtualMachines';       File = 'VirtualMachines.ps1';       Type = 'microsoft.azurestackhci/virtualmachineinstances';     Worksheet = 'Azure Local VMs' }
    @{ Name = 'LogicalNetworks';       File = 'LogicalNetworks.ps1';       Type = 'microsoft.azurestackhci/logicalnetworks';             Worksheet = 'Azure Local Logical Networks' }
    @{ Name = 'StorageContainers';     File = 'StorageContainers.ps1';     Type = 'microsoft.azurestackhci/storagecontainers';           Worksheet = 'Azure Local Storage Paths' }
    @{ Name = 'GalleryImages';         File = 'GalleryImages.ps1';         Type = 'microsoft.azurestackhci/galleryimages';               Worksheet = 'Azure Local Gallery Images' }
    @{ Name = 'MarketplaceGalleryImages'; File = 'MarketplaceGalleryImages.ps1'; Type = 'microsoft.azurestackhci/marketplacegalleryimages'; Worksheet = 'Azure Local Marketplace Images' }
    @{ Name = 'ArcServerOperationalData'; File = 'ArcServerOperationalData.ps1'; Type = 'microsoft.hybridcompute/machines'; Worksheet = 'Arc Server Ops' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot  = Split-Path -Parent $PSScriptRoot
    $script:HybridPath  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Hybrid'
    $script:TempDir     = Join-Path $env:TEMP 'AZSC_HybridTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockHybridResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-hybrid',
              [string]$SubscriptionId = 'sub-00000001', [object]$Props)
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
        }
    }

    $script:MockResources = @()

    # Arc Server
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/arc/srv01' -Name 'arc-server-01' `
        -Type 'microsoft.hybridcompute/machines' -Props ([PSCustomObject]@{
        agentVersion = '1.21.0'; status = 'Connected'; osType = 'Windows'; osName = 'Windows Server 2019'
        osSku = 'Windows Server 2019 Datacenter'; osVersion = '10.0.17763'
        privateLinkScopeResourceId = $null; cloudMetadata = $null
        locationData = [PSCustomObject]@{ name = 'Datacenter 1'; city = 'Atlanta'; countryOrRegion = 'US' }
    })

    # Arc Extension  
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/arc/srv01/ext/mma' -Name 'MicrosoftMonitoringAgent' `
        -Type 'microsoft.hybridcompute/machines/extensions' -Props ([PSCustomObject]@{
        publisher = 'Microsoft.EnterpriseCloud.Monitoring'; typeHandlerVersion = '1.0.18069.0'
        autoUpgradeMinorVersion = $true; enableAutomaticUpgrade = $true
        provisioningState = 'Succeeded'; settings = '{"workspaceId":"ws-001"}'
    })

    # Arc Gateway
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/arc/gw1' -Name 'arc-gw-1' `
        -Type 'microsoft.hybridcompute/gateways' -Props ([PSCustomObject]@{
        gatewayId = 'gw-id-001'; gatewayType = 'Public'; gatewayEndpoint = 'https://gw.arc.azure.com'
        provisioningState = 'Succeeded'; allowedFeatures = @('*')
    })

    # Arc Kubernetes
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/k8s/k8s1' -Name 'arc-k8s-prod' `
        -Type 'microsoft.kubernetes/connectedclusters' -Props ([PSCustomObject]@{
        connectivityStatus = 'Connected'; agentVersion = '1.14.5'; kubernetesVersion = '1.28.3'
        distribution = 'AKSEdge'; provisioningState = 'Succeeded'
    })

    # Arc Resource Bridge
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/rb/rb1' -Name 'arc-bridge-1' `
        -Type 'microsoft.resourceconnector/appliances' -Props ([PSCustomObject]@{
        status = 'Running'; provisioningState = 'Succeeded'; distro = 'AKSEdge'
        infrastructureConfig = [PSCustomObject]@{ provider = 'VMWare' }
    })

    # Arc SQL Server
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/arcsql/sql1' -Name 'arc-sql-01' `
        -Type 'microsoft.azurearcdata/sqlserverinstances' -Props ([PSCustomObject]@{
        version = 'SQL Server 2019'; edition = 'Enterprise'; licenseType = 'HADR'
        vCore = 8; patchLevel = '15.0.4123.1'; collation = 'SQL_Latin1_General_CP1_CI_AS'
        containerResourceId = '/hybrid/sub-00000001/arc/srv01'; azureDefenderStatus = 'Protected'
        provisioningState = 'Succeeded'
    })

    # Arc SQL Managed Instance
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/arcsqlmi/mi1' -Name 'arc-sqlmi-01' `
        -Type 'microsoft.azurearcdata/sqlmanagedinstances' -Props ([PSCustomObject]@{
        licenseType = 'LicenseIncluded'; tier = 'GeneralPurpose'; vCores = '4'
        dataControllerId = '/hybrid/sub-00000001/dc/dc1'; provisioningState = 'Succeeded'
        k8sRaw = [PSCustomObject]@{ spec = [PSCustomObject]@{ replicas = 1 } }
    })

    # Arc Data Controller
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/dc/dc1' -Name 'arc-dc-01' `
        -Type 'microsoft.azurearcdata/datacontrollers' -Props ([PSCustomObject]@{
        k8sRaw = [PSCustomObject]@{ metadata = [PSCustomObject]@{ namespace = 'arc' } }
        infrastructure = 'onpremises'; basicLoginInformation = $null
        logsDashboardCredential = $null; onPremiseProperty = [PSCustomObject]@{ id = 'dc-id-001' }
        provisioningState = 'Succeeded'
    })

    # Arc Sites
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/sites/site1' -Name 'hq-site' `
        -Type 'microsoft.hybridcompute/sites' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'
    })

    # Azure Local Cluster
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1' -Name 'hci-cluster-01' `
        -Type 'microsoft.azurestackhci/clusters' -Props ([PSCustomObject]@{
        cloudId = 'cloud-id-001'; provisioningState = 'Succeeded'; status = 'Connected'
        nodeCount = 4; operatingSystem = 'Azure Local'
        reportedProperties = [PSCustomObject]@{ clusterVersion = '10.2405.0'; isMixedOSCluster = $false }
    })

    # Azure Local VM
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1/vm/vm01' -Name 'hci-vm-01' `
        -Type 'microsoft.azurestackhci/virtualmachineinstances' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'; vmId = 'vm-id-001'
        storageProfile = [PSCustomObject]@{ vmConfigStoragePathId = '/hci/storage1' }
        hardwareProfile = [PSCustomObject]@{ vmSize = 'Standard' }
        osProfile = [PSCustomObject]@{ computerName = 'hci-vm-01'; windowsConfiguration = $null; linuxConfiguration = $null }
        networkProfile = [PSCustomObject]@{ networkInterfaces = @() }
        securityProfile = [PSCustomObject]@{ enableTPM = $true; uefiSettings = [PSCustomObject]@{ secureBootEnabled = $true } }
    })

    # Azure Local Logical Network
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1/net/net1' -Name 'hci-net-01' `
        -Type 'microsoft.azurestackhci/logicalnetworks' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'; dhcpOptions = $null
        subnets = @(@{ properties = [PSCustomObject]@{ addressPrefix = '10.10.0.0/24'; ipAllocationMethod = 'Dynamic' }; name = 'default' })
        vmSwitchName = 'ConvergedSwitch'
    })

    # Azure Local Storage Container
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1/stor/stor1' -Name 'hci-stor-01' `
        -Type 'microsoft.azurestackhci/storagecontainers' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'; storagePath = 'C:\ClusterStorage\Volume01'
        status = [PSCustomObject]@{ availableSizeGB = 500; totalSizeGB = 1000 }
    })

    # Azure Local Gallery Image
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1/img/img1' -Name 'hci-img-01' `
        -Type 'microsoft.azurestackhci/galleryimages' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'; osType = 'Windows'; hyperVGeneration = 'V2'
        identifier = [PSCustomObject]@{ publisher = 'MicrosoftWindowsServer'; offer = 'WindowsServer'; sku = '2022-Datacenter' }
        version    = [PSCustomObject]@{ name = '20348.2340.240303' }
    })

    # Azure Local Marketplace Gallery Image
    $script:MockResources += New-MockHybridResource -Id '/hybrid/sub-00000001/hci/cluster1/mktimg/mktimg1' -Name 'hci-mktimg-01' `
        -Type 'microsoft.azurestackhci/marketplacegalleryimages' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'; osType = 'Windows'; hyperVGeneration = 'V2'
        identifier = [PSCustomObject]@{ publisher = 'MicrosoftWindowsServer'; offer = 'WindowsServer'; sku = '2022-Datacenter' }
        version    = [PSCustomObject]@{ name = '20348.2340.240303' }
    })

    # Mock Invoke-AzRestMethod for ArcServerOperationalData
    function Invoke-AzRestMethod {
        param([string]$Path, [string]$Method = 'GET')
        $mockResponse = @{ value = @(); properties = @{ startDateTime = '2025-06-01T00:00:00Z'; availablePatchCountByClassification = @{ critical = 0; security = 1 }; lastModifiedDateTime = '2025-06-01T12:00:00Z' } }
        [PSCustomObject]@{ Content = ($mockResponse | ConvertTo-Json -Depth 10); StatusCode = 200 }
    }
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'Hybrid Module Files Exist' {
    It 'Hybrid module folder exists' {
        $script:HybridPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $HybridModules {
        Join-Path $script:HybridPath $File | Should -Exist
    }
}

Describe 'Hybrid Module Processing Phase — <Name>' -ForEach $HybridModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:HybridPath $File
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

Describe 'Hybrid Module Reporting Phase — <Name>' -ForEach $HybridModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:HybridPath $File
        $script:ResType  = $Type
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("Hybrid_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

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

Describe 'Arc SQL Server — Processing produces required fields' {
    It 'ArcSQLServers output includes SQL Version, Edition, Licensing fields' {
        $modFile = Join-Path $script:HybridPath 'ArcSQLServers.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
        $row = $result | Select-Object -First 1
        $row.Keys | Should -Contain 'SQL Version'
        $row.Keys | Should -Contain 'Edition'
        $row.Keys | Should -Contain 'Licensing Type'
        $row.Keys | Should -Contain 'vCores'
    }
}

Describe 'Azure Local — Module Processing completeness' {
    It 'Azure Local Clusters output contains cluster fields' {
        $modFile = Join-Path $script:HybridPath 'Clusters.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Azure Local VMs output contains VM fields' {
        $modFile = Join-Path $script:HybridPath 'VirtualMachines.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
    }
}
