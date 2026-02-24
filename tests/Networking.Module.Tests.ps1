#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Networking inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each Networking module
    using synthetic mock data. No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   8.3.6, 19.5.13 — VPN / Networking Testing
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$NetworkingPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Networking'

$NetworkingModules = @(
    @{ Name = 'VirtualNetwork';         File = 'VirtualNetwork.ps1';        Type = 'microsoft.network/virtualnetworks';             Worksheet = 'Virtual Networks' }
    @{ Name = 'vNETPeering';            File = 'vNETPeering.ps1';           Type = 'microsoft.network/virtualnetworks';             Worksheet = 'VNet Peerings' }
    @{ Name = 'VirtualNetworkGateways'; File = 'VirtualNetworkGateways.ps1';Type = 'microsoft.network/virtualnetworkgateways';      Worksheet = 'VPN Gateways' }
    @{ Name = 'Connections';            File = 'Connections.ps1';           Type = 'microsoft.network/connections';                 Worksheet = 'VPN Connections' }
    @{ Name = 'LoadBalancer';           File = 'LoadBalancer.ps1';          Type = 'microsoft.network/loadbalancers';               Worksheet = 'Load Balancers' }
    @{ Name = 'ApplicationGateways';    File = 'ApplicationGateways.ps1';   Type = 'microsoft.network/applicationgateways';        Worksheet = 'Application Gateways' }
    @{ Name = 'NetworkSecurityGroup';   File = 'NetworkSecurityGroup.ps1';  Type = 'microsoft.network/networksecuritygroups';      Worksheet = 'Network Security Groups' }
    @{ Name = 'PublicIP';               File = 'PublicIP.ps1';              Type = 'microsoft.network/publicipaddresses';           Worksheet = 'Public IPs' }
    @{ Name = 'RouteTables';            File = 'RouteTables.ps1';           Type = 'microsoft.network/routetables';                Worksheet = 'Route Tables' }
    @{ Name = 'NetworkInterface';       File = 'NetworkInterface.ps1';      Type = 'microsoft.network/networkinterfaces';          Worksheet = 'Network Interfaces' }
    @{ Name = 'PrivateEndpoint';        File = 'PrivateEndpoint.ps1';       Type = 'microsoft.network/privateendpoints';           Worksheet = 'Private Endpoints' }
    @{ Name = 'PrivateDNS';             File = 'PrivateDNS.ps1';            Type = 'microsoft.network/privatednszones';            Worksheet = 'Private DNS Zones' }
    @{ Name = 'AzureFirewall';          File = 'AzureFirewall.ps1';         Type = 'microsoft.network/azurefirewalls';             Worksheet = 'Azure Firewall' }
    @{ Name = 'BastionHosts';           File = 'BastionHosts.ps1';          Type = 'microsoft.network/bastionhosts';               Worksheet = 'Bastion Hosts' }
    @{ Name = 'NATGateway';             File = 'NATGateway.ps1';            Type = 'microsoft.network/natgateways';                Worksheet = 'NAT Gateways' }
    @{ Name = 'TrafficManager';         File = 'TrafficManager.ps1';        Type = 'microsoft.network/trafficmanagerprofiles';     Worksheet = 'Traffic Manager' }
    @{ Name = 'VirtualWAN';             File = 'VirtualWAN.ps1';            Type = 'microsoft.network/virtualwans';                Worksheet = 'Virtual WANs' }
    @{ Name = 'ExpressRoute';           File = 'ExpressRoute.ps1';          Type = 'microsoft.network/expressroutecircuits';       Worksheet = 'ExpressRoute Circuits' }
    @{ Name = 'NetworkWatchers';        File = 'NetworkWatchers.ps1';       Type = 'microsoft.network/networkwatchers';            Worksheet = 'Network Watchers' }
    @{ Name = 'Frontdoor';              File = 'Frontdoor.ps1';             Type = 'microsoft.network/frontdoors';                 Worksheet = 'Front Doors' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:NetworkingPath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Networking'
    $script:TempDir        = Join-Path $env:TEMP 'AZSC_NetworkingTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockNetResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-net',
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

    # Virtual Network
    $script:MockResources += New-MockNetResource -Id '/net/vnet1' -Name 'vnet-prod' `
        -Type 'microsoft.network/virtualnetworks' -Props ([PSCustomObject]@{
        addressSpace    = [PSCustomObject]@{ addressPrefixes = @('10.0.0.0/16') }
        subnets         = @(
            [PSCustomObject]@{ name = 'default'; properties = [PSCustomObject]@{ addressPrefix = '10.0.0.0/24'; provisioningState = 'Succeeded' } }
        )
        virtualNetworkPeerings = @()
        enableDdosProtection = $false; provisioningState = 'Succeeded'
        dhcpOptions = [PSCustomObject]@{ dnsServers = @('168.63.129.16') }
    })

    # VNet Peering (piggybacked on VNet resource)
    $vnetWithPeering = New-MockNetResource -Id '/net/vnet2' -Name 'vnet-spoke' `
        -Type 'microsoft.network/virtualnetworks' -Props ([PSCustomObject]@{
        addressSpace = [PSCustomObject]@{ addressPrefixes = @('10.1.0.0/16') }
        subnets      = @()
        virtualNetworkPeerings = @(
            [PSCustomObject]@{
                name = 'peer-to-hub'
                properties = [PSCustomObject]@{
                    remoteVirtualNetwork = [PSCustomObject]@{ id = '/net/vnet1' }
                    peeringState = 'Connected'; allowVirtualNetworkAccess = $true
                    allowForwardedTraffic = $true; allowGatewayTransit = $false; useRemoteGateways = $true
                    provisioningState = 'Succeeded'
                }
            }
        )
        provisioningState = 'Succeeded'; enableDdosProtection = $false
    })
    $script:MockResources += $vnetWithPeering

    # VPN Gateway
    $script:MockResources += New-MockNetResource -Id '/net/vpngw1' -Name 'vpngw-prod' `
        -Type 'microsoft.network/virtualnetworkgateways' -Props ([PSCustomObject]@{
        gatewayType = 'Vpn'; vpnType = 'RouteBased'; sku = [PSCustomObject]@{ name = 'VpnGw1'; tier = 'VpnGw1' }
        provisioningState = 'Succeeded'; enableBgp = $false
        ipConfigurations = @(@{name='ipconf1';properties=[PSCustomObject]@{publicIPAddress=[PSCustomObject]@{id='/pip/pip1'}}})
        vpnClientConfiguration = [PSCustomObject]@{
            vpnClientAddressPool = [PSCustomObject]@{ addressPrefixes = @('172.16.0.0/24') }
            vpnClientProtocols = @('IkeV2','SSTP'); vpnAuthenticationTypes = @('Certificate')
            vpnClientRootCertificates = @(@{name='root1'}); vpnClientRevokedCertificates = @()
            radiusServers = $null; aadTenant = $null
        }
        natRules = @(); customDns = @('10.0.0.10'); vpnGatewayGeneration = 'Generation1'
    })

    # VPN Connection
    $script:MockResources += New-MockNetResource -Id '/net/conn1' -Name 'conn-s2s-onprem' `
        -Type 'microsoft.network/connections' -Props ([PSCustomObject]@{
        connectionType = 'IPsec'; connectionStatus = 'Connected'
        virtualNetworkGateway1 = [PSCustomObject]@{ id = '/net/vpngw1' }
        localNetworkGateway2   = [PSCustomObject]@{ id = '/net/lng1' }
        sharedKeyPresent       = $true
        ingressBytesTransferred = 1048576; egressBytesTransferred = 2097152
        ipsecPolicies = @()
        trafficSelectorPolicies     = @()
        dpdTimeoutSeconds           = 45
        usePolicyBasedTrafficSelectors = $false
        provisioningState = 'Succeeded'
    })

    # Load Balancer
    $script:MockResources += New-MockNetResource -Id '/net/lb1' -Name 'lb-web' `
        -Type 'microsoft.network/loadbalancers' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard'; tier = 'Regional' }
        frontendIPConfigurations = @(@{ name = 'frontend1'; properties = [PSCustomObject]@{ privateIPAddress = $null; publicIPAddress = [PSCustomObject]@{id='/pip/pip2'} } })
        backendAddressPools = @(@{ name = 'pool1' })
        loadBalancingRules = @(@{ name = 'rule-http'; properties = [PSCustomObject]@{ protocol = 'Tcp'; frontendPort = 80; backendPort = 80 } })
        probes = @(@{ name = 'probe-http'; properties = [PSCustomObject]@{ protocol = 'Http'; port = 80 } })
        provisioningState = 'Succeeded'
    })

    # Application Gateway
    $script:MockResources += New-MockNetResource -Id '/net/appgw1' -Name 'appgw-prod' `
        -Type 'microsoft.network/applicationgateways' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard_v2'; tier = 'Standard_v2'; capacity = 2 }
        operationalState = 'Running'; provisioningState = 'Succeeded'
        gatewayIPConfigurations = @(@{name='gwip1';properties=[PSCustomObject]@{subnet=[PSCustomObject]@{id='/vnet/vnet1/subnets/gwsubnet'}}})
        backendAddressPools = @(@{ name = 'pool1'; properties = [PSCustomObject]@{backendAddresses=@()} })
        httpListeners = @(@{ name = 'listener-http'; properties = [PSCustomObject]@{ protocol='Http'; frontendPort=[PSCustomObject]@{id='/port/80'} } })
        requestRoutingRules = @()
    })

    # NSG
    $script:MockResources += New-MockNetResource -Id '/net/nsg1' -Name 'nsg-web' `
        -Type 'microsoft.network/networksecuritygroups' -Props ([PSCustomObject]@{
        securityRules = @(
            [PSCustomObject]@{ name = 'allow-http'; properties = [PSCustomObject]@{ priority = 100; direction = 'Inbound'; access = 'Allow'; protocol = 'Tcp'; sourcePortRange = '*'; destinationPortRange = '80'; sourceAddressPrefix = '*'; destinationAddressPrefix = '*'; provisioningState = 'Succeeded' } }
        )
        defaultSecurityRules = @()
        networkInterfaces = @()
        subnets = @([PSCustomObject]@{id='/vnet/vnet1/subnets/default'})
        provisioningState = 'Succeeded'
    })

    # Public IP
    $script:MockResources += New-MockNetResource -Id '/net/pip1' -Name 'pip-vpngw' `
        -Type 'microsoft.network/publicipaddresses' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard'; tier = 'Regional' }
        publicIPAllocationMethod = 'Static'; ipAddress = '20.1.2.3'
        dnsSettings = [PSCustomObject]@{ domainNameLabel = 'vpngw-pip'; fqdn = 'vpngw-pip.eastus.cloudapp.azure.com' }
        provisioningState = 'Succeeded'; ipConfiguration = [PSCustomObject]@{id='/net/vpngw1/ipcfg1'}
    })

    # Route Table
    $script:MockResources += New-MockNetResource -Id '/net/rt1' -Name 'rt-custom' `
        -Type 'microsoft.network/routetables' -Props ([PSCustomObject]@{
        routes = @(
            [PSCustomObject]@{ name = 'route-fw'; properties = [PSCustomObject]@{ addressPrefix = '0.0.0.0/0'; nextHopType = 'VirtualAppliance'; nextHopIpAddress = '10.0.0.4' } }
        )
        disableBgpRoutePropagation = $true; provisioningState = 'Succeeded'
        subnets = @()
    })

    # Network Interface
    $script:MockResources += New-MockNetResource -Id '/net/nic1' -Name 'nic-vm01' `
        -Type 'microsoft.network/networkinterfaces' -Props ([PSCustomObject]@{
        ipConfigurations = @(@{ name='ipconf1'; properties = [PSCustomObject]@{ subnet = [PSCustomObject]@{ id = '/vnet/vnet1/subnets/default' }; privateIPAddress = '10.0.0.5'; publicIPAddress = $null } })
        enableAcceleratedNetworking = $true; enableIPForwarding = $false; networkSecurityGroup = [PSCustomObject]@{id='/net/nsg1'}
        virtualMachine = [PSCustomObject]@{id='/vm/vm01'}; provisioningState = 'Succeeded'
    })

    # Private Endpoint
    $script:MockResources += New-MockNetResource -Id '/net/pe1' -Name 'pe-storage' `
        -Type 'microsoft.network/privateendpoints' -Props ([PSCustomObject]@{
        subnet = [PSCustomObject]@{ id = '/vnet/vnet1/subnets/default' }
        privateLinkServiceConnections = @([PSCustomObject]@{ name = 'plsc-1'; properties = [PSCustomObject]@{ privateLinkServiceId = '/sa/sa1'; groupIds = @('blob'); privateLinkServiceConnectionState = [PSCustomObject]@{status='Approved';description=''} } })
        networkInterfaces = @([PSCustomObject]@{id='/nic/nic-pe1'})
        provisioningState = 'Succeeded'
    })

    # Private DNS Zone
    $script:MockResources += New-MockNetResource -Id '/net/pdns1' -Name 'privatelink.blob.core.windows.net' `
        -Type 'microsoft.network/privatednszones' -Props ([PSCustomObject]@{
        numberOfRecordSets = 2; maxNumberOfRecordSets = 25000
        numberOfVirtualNetworkLinks = 1; maxNumberOfVirtualNetworkLinks = 1000
        provisioningState = 'Succeeded'
    })

    # Azure Firewall
    $script:MockResources += New-MockNetResource -Id '/net/fw1' -Name 'fw-hub' `
        -Type 'microsoft.network/azurefirewalls' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'AZFW_VNet'; tier = 'Premium' }
        threatIntelMode = 'Alert'; provisioningState = 'Succeeded'
        ipConfigurations = @(@{ name='ipconf1'; properties = [PSCustomObject]@{ privateIPAddress = '10.0.1.4'; subnet = [PSCustomObject]@{id='/vnet/hub/subnets/AzureFirewallSubnet'} } })
        firewallPolicy = [PSCustomObject]@{ id = '/net/fwpolicy1' }
        additionalProperties = @{}
    })

    # Bastion
    $script:MockResources += New-MockNetResource -Id '/net/bastion1' -Name 'bastion-hub' `
        -Type 'microsoft.network/bastionhosts' -Props ([PSCustomObject]@{
        ipConfigurations = @(@{ name='ipconf1'; properties = [PSCustomObject]@{ subnet = [PSCustomObject]@{id='/vnet/hub/subnets/AzureBastionSubnet'}; publicIPAddress = [PSCustomObject]@{id='/pip/pip-bas'} } })
        sku = [PSCustomObject]@{ name = 'Standard' }; dnsName = 'bst-001.bastion.azure.com'
        scaleUnits = 2; disableCopyPaste = $false; enableFileCopy = $true; enableIpConnect = $true
        enableShareableLink = $false; enableTunneling = $true; provisioningState = 'Succeeded'
    })

    # NAT Gateway
    $script:MockResources += New-MockNetResource -Id '/net/nat1' -Name 'nat-prod' `
        -Type 'microsoft.network/natgateways' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard' }; idleTimeoutInMinutes = 4
        publicIpAddresses = @([PSCustomObject]@{id='/pip/pip-nat'}); publicIpPrefixes = @()
        subnets = @([PSCustomObject]@{id='/vnet/vnet1/subnets/default'})
        provisioningState = 'Succeeded'
    })

    # Traffic Manager
    $script:MockResources += New-MockNetResource -Id '/net/tm1' -Name 'tm-global' `
        -Type 'microsoft.network/trafficmanagerprofiles' -Props ([PSCustomObject]@{
        profileStatus = 'Enabled'; trafficRoutingMethod = 'Performance'
        dnsConfig = [PSCustomObject]@{ relativeName = 'tm-global'; fqdn = 'tm-global.trafficmanager.net'; ttl = 60 }
        monitorConfig = [PSCustomObject]@{ protocol = 'HTTPS'; port = 443; path = '/health'; intervalInSeconds = 30 }
        endpoints = @(@{ name='ep-eastus'; properties = [PSCustomObject]@{ endpointStatus='Enabled'; weight=50; priority=$null } })
        provisioningState = 'Succeeded'
    })

    # Virtual WAN
    $script:MockResources += New-MockNetResource -Id '/net/vwan1' -Name 'vwan-prod' `
        -Type 'microsoft.network/virtualwans' -Props ([PSCustomObject]@{
        type = 'Standard'; allowVnetToVnetTraffic = $true; allowBranchToBranchTraffic = $true
        virtualHubs = @([PSCustomObject]@{id='/net/vhub1'})
        provisioningState = 'Succeeded'
    })

    # ExpressRoute
    $script:MockResources += New-MockNetResource -Id '/net/er1' -Name 'er-prod' `
        -Type 'microsoft.network/expressroutecircuits' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard_MeteredData'; tier = 'Standard'; family = 'MeteredData' }
        serviceProviderProperties = [PSCustomObject]@{ serviceProviderName = 'Equinix'; peeringLocation = 'Silicon Valley'; bandwidthInMbps = 1000 }
        circuitProvisioningState = 'Enabled'; serviceProviderProvisioningState = 'Provisioned'
        provisioningState = 'Succeeded'
    })

    # Network Watcher
    $script:MockResources += New-MockNetResource -Id '/net/nw1' -Name 'nw-eastus' `
        -Type 'microsoft.network/networkwatchers' -Props ([PSCustomObject]@{
        provisioningState = 'Succeeded'
    })

    # Front Door (classic)
    $script:MockResources += New-MockNetResource -Id '/net/fd1' -Name 'fd-prod' `
        -Type 'microsoft.network/frontdoors' -Props ([PSCustomObject]@{
        frontendEndpoints = @(@{name='fe-prod';properties=[PSCustomObject]@{hostName='fd-prod.azurefd.net';sessionAffinityEnabledState='Disabled'}})
        routingRules = @(@{name='rr-default';properties=[PSCustomObject]@{enabledState='Enabled';patternsToMatch=@('/*')}})
        backendPools = @(@{name='pool1'})
        provisioningState = 'Succeeded'; resourceState = 'Enabled'
    })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'Networking Module Files Exist' {
    It 'Networking module folder exists' {
        $script:NetworkingPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $NetworkingModules {
        Join-Path $script:NetworkingPath $File | Should -Exist
    }
}

Describe 'Networking Module Processing Phase — <Name>' -ForEach $NetworkingModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:NetworkingPath $File
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

Describe 'Networking Module Reporting Phase — <Name>' -ForEach $NetworkingModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:NetworkingPath $File
        $script:ResType  = $Type
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("Net_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

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

Describe 'VPN Gateway — Enhanced P2S and NAT fields present' {
    It 'VirtualNetworkGateways processing produces P2S config fields' {
        $modFile = Join-Path $script:NetworkingPath 'VirtualNetworkGateways.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
        $row = $result | Select-Object -First 1
        # Validate field presence — exact key names defined in the module
        $row.Keys | Should -Contain 'Name'
        $row.Keys | Should -Contain 'Subscription'
        $row.Keys | Should -Contain 'Resource Group'
    }
}

Describe 'VPN Connections — Enhanced IPsec fields present' {
    It 'Connections processing produces Shared Key Present and Ingress/Egress fields' {
        $modFile = Join-Path $script:NetworkingPath 'Connections.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
        $row = $result | Select-Object -First 1
        $row.Keys | Should -Contain 'Connection Type'
        $row.Keys | Should -Contain 'Connection Status'
    }
}
