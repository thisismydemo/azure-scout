#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Containers inventory modules.
.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-25
#>

$ContainersPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Containers'

$ContainerModules = @(
    @{ Name = 'AKS';                File = 'AKS.ps1';                Type = 'microsoft.containerservice/managedclusters';     Worksheet = 'AKS' }
    @{ Name = 'ARO';                File = 'ARO.ps1';                Type = 'microsoft.redhatopenshift/openshiftclusters';     Worksheet = 'ARO' }
    @{ Name = 'ContainerApp';       File = 'ContainerApp.ps1';       Type = 'microsoft.app/containerapps';                    Worksheet = 'Container Apps' }
    @{ Name = 'ContainerAppEnv';    File = 'ContainerAppEnv.ps1';    Type = 'microsoft.app/managedenvironments';              Worksheet = 'Container App Env' }
    @{ Name = 'ContainerGroups';    File = 'ContainerGroups.ps1';    Type = 'microsoft.containerinstance/containergroups';     Worksheet = 'Containers' }
    @{ Name = 'ContainerRegistries';File = 'ContainerRegistries.ps1';Type = 'microsoft.containerregistry/registries';          Worksheet = 'Registries' }
)

BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:ContainersPath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Containers'
    $script:TempDir        = Join-Path $env:TEMP 'AZSC_ContainersTests'
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockContainerResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-containers',
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
            ZONES          = @('1')
        }
    }

    $script:MockResources = @()

    # --- AKS ---
    $script:MockResources += New-MockContainerResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.containerservice/managedclusters/aks-prod' `
        -Name 'aks-prod' -Type 'microsoft.containerservice/managedclusters' `
        -SKU ([PSCustomObject]@{ name = 'Base'; tier = 'Standard' }) `
        -Props ([PSCustomObject]@{
            kubernetesVersion = '1.28.5'; powerstate = [PSCustomObject]@{ code = 'Running' }
            enableRBAC = $true; aadProfile = [PSCustomObject]@{ admingroupobjectids = @('group1') }
            disablelocalaccounts = $true
            networkprofile = [PSCustomObject]@{ networkplugin = 'azure'; networkpluginmode = 'overlay'; podCidr = '10.244.0.0/16'; networkPolicy = 'calico'; outboundType = 'loadBalancer' }
            noderesourcegroup = 'MC_rg-containers_aks-prod_eastus'
            identityprofile = [PSCustomObject]@{ kubeletidentity = [PSCustomObject]@{ resourceid = '/subscriptions/sub-00000001/resourceGroups/MC_rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks-kubelet' } }
            addonProfiles = [PSCustomObject]@{
                omsagent = [PSCustomObject]@{ config = [PSCustomObject]@{ logAnalyticsWorkspaceResourceID = '/subscriptions/sub-00000001/resourceGroups/rg-mon/providers/microsoft.operationalinsights/workspaces/la-prod' } }
                ingressApplicationGateway = [PSCustomObject]@{ config = [PSCustomObject]@{ applicationGatewayName = 'appgw-aks' } }
            }
            apiServerAccessProfile = [PSCustomObject]@{ enablePrivateCluster = $false }
            privatefqdn = $null; publicNetworkAccess = 'Enabled'
            autoUpgradeProfile = [PSCustomObject]@{ upgradeChannel = 'stable'; nodeosupgradechannel = 'NodeImage' }
            fqdn = 'aks-prod-dns.hcp.eastus.azmk8s.io'
            agentPoolProfiles = @([PSCustomObject]@{
                name = 'nodepool1'; powerstate = [PSCustomObject]@{ code = 'Running' }
                orchestratorVersion = '1.28.5'; mode = 'System'; osType = 'Linux'
                ossku = 'AzureLinux'; nodeimageversion = 'AzureLinux-202401.01.0'
                vmSize = 'Standard_D4s_v3'; osDiskSizeGB = 128; count = 3
                availabilityZones = @('1','2','3'); enableAutoScaling = $true
                minCount = 3; maxCount = 10; maxPods = 110
                vnetSubnetID = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-aks/subnets/aks-subnet'
                enableNodePublicIP = $false; nodetaints = @(); nodelabels = [PSCustomObject]@{}
            })
        })

    # --- ARO ---
    $script:MockResources += New-MockContainerResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.redhatopenshift/openshiftclusters/aro-prod' `
        -Name 'aro-prod' -Type 'microsoft.redhatopenshift/openshiftclusters' `
        -Props ([PSCustomObject]@{
            clusterProfile = [PSCustomObject]@{ version = '4.14.16'; domain = 'aro-prod' }
            networkProfile = [PSCustomObject]@{ outboundType = 'Loadbalancer'; podCidr = '10.128.0.0/14'; serviceCidr = '172.30.0.0/16' }
            ingressProfiles = @([PSCustomObject]@{ name = 'default'; visibility = 'Public'; ip = '20.1.2.3' })
            apiserverProfile = [PSCustomObject]@{ visibility = 'Public'; url = 'https://api.aro-prod.eastus.aroapp.io:6443'; ip = '20.1.2.4' }
            consoleProfile = [PSCustomObject]@{ url = 'https://console-openshift-console.apps.aro-prod.eastus.aroapp.io' }
            masterProfile = [PSCustomObject]@{
                vmSize = 'Standard_D8s_v3'
                subnetId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-aro/subnets/master-subnet'
            }
            workerProfiles = @([PSCustomObject]@{
                vmSize = 'Standard_D4s_v3'; diskSizeGB = 128; count = 3
                subnetId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-aro/subnets/worker-subnet'
            })
        })

    # --- Container App ---
    $envId = '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.app/managedenvironments/cae-prod'
    $script:MockResources += New-MockContainerResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.app/containerapps/ca-api' `
        -Name 'ca-api' -Type 'microsoft.app/containerapps' `
        -Props ([PSCustomObject]@{
            runningStatus = 'Running'
            environmentId = $envId
            workloadProfileName = 'Consumption'
            configuration = [PSCustomObject]@{
                ingress = [PSCustomObject]@{ targetPort = 8080; external = $true; allowInsecure = $false; transport = 'auto' }
                dapr = $null; secrets = @([PSCustomObject]@{name='secret1'})
            }
            template = @([PSCustomObject]@{
                containers = @([PSCustomObject]@{
                    name = 'api'; image = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
                    resources = [PSCustomObject]@{ cpu = 0.5; memory = '1Gi'; ephemeralStorage = '2Gi' }
                })
            })
        })

    # --- Container App Environment ---
    $script:MockResources += New-MockContainerResource -Id $envId `
        -Name 'cae-prod' -Type 'microsoft.app/managedenvironments' `
        -Props ([PSCustomObject]@{
            publicNetworkAccess = 'Enabled'; zoneRedundant = $true; staticIp = '10.0.0.100'
            kedaconfiguration = [PSCustomObject]@{ Version = '2.12.1' }
            daprconfiguration = [PSCustomObject]@{ Version = '1.12.0' }
            workloadProfiles = @([PSCustomObject]@{ name = 'Consumption'; workloadProfileType = 'Consumption'; minimumCount = 0; maximumCount = 30 })
        })

    # --- Container Groups ---
    $script:MockResources += New-MockContainerResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.containerinstance/containergroups/cg-worker' `
        -Name 'cg-worker' -Type 'microsoft.containerinstance/containergroups' `
        -Props ([PSCustomObject]@{
            osType = 'Linux'
            containers = @([PSCustomObject]@{
                name = 'worker'
                properties = [PSCustomObject]@{
                    instanceView = [PSCustomObject]@{ currentState = [PSCustomObject]@{ state = 'Running'; startTime = '2025-06-01T10:00:00Z' }; restartCount = 0 }
                    image = 'myregistry.azurecr.io/worker:v1'
                    command = @('/bin/sh', '-c', 'echo hello')
                    resources = [PSCustomObject]@{ requests = [PSCustomObject]@{ cpu = 1.0; memoryInGB = 1.5 } }
                    ports = @([PSCustomObject]@{ protocol = 'TCP'; port = 80 })
                }
            })
            ipAddress = [PSCustomObject]@{ ip = '10.0.0.50' }
        })

    # --- Container Registries ---
    $script:MockResources += New-MockContainerResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-containers/providers/microsoft.containerregistry/registries/acrprod' `
        -Name 'acrprod' -Type 'microsoft.containerregistry/registries' `
        -SKU ([PSCustomObject]@{ name = 'Premium' }) `
        -Props ([PSCustomObject]@{
            creationDate = '2025-01-15T08:00:00Z'
            anonymouspullenabled = $false
            encryption = [PSCustomObject]@{ status = 'Disabled' }
            publicnetworkaccess = 'Enabled'
            zoneredundancy = 'Enabled'
            privateendpointconnections = @([PSCustomObject]@{ id = 'pe1' })
            policies = [PSCustomObject]@{
                softdeletepolicy = [PSCustomObject]@{ status = 'enabled' }
                trustpolicy = [PSCustomObject]@{ status = 'disabled' }
            }
        })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

Describe 'Containers Module Files Exist' {
    It 'Containers module folder exists' { $script:ContainersPath | Should -Exist }
    It '<Name> module file exists' -ForEach $ContainerModules { Join-Path $script:ContainersPath $File | Should -Exist }
}

Describe 'Containers Module Processing Phase — <Name>' -ForEach $ContainerModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:ContainersPath $File
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

Describe 'Containers Module Reporting Phase — <Name>' -ForEach $ContainerModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:ContainersPath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("Ctr_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())
        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $script:ProcessedData = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        } else { $script:ProcessedData = $null }
    }
    It 'Reporting phase does not throw' {
        if ($script:ProcessedData) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:XlsxFile, $script:ProcessedData, 'Light20', $null } | Should -Not -Throw
        } else { Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'" }
    }
    It 'Excel file is created' {
        if ($script:ProcessedData) { $script:XlsxFile | Should -Exist }
        else { Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'" }
    }
}
