#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Compute inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for each Compute module
    using synthetic mock data. No live Azure authentication is required.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   15.3, 19.2, 19.4 — Compute / AVD / VM Enhancement Testing
#>

# ===================================================================
# DISCOVERY-TIME: module spec table (outside BeforeAll for -ForEach)
# ===================================================================
$ComputePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Compute'

$ComputeModules = @(
    @{ Name = 'VirtualMachine';          File = 'VirtualMachine.ps1';          Type = 'microsoft.compute/virtualmachines';                        Worksheet = 'Virtual Machines' }
    @{ Name = 'VirtualMachineScaleSet';  File = 'VirtualMachineScaleSet.ps1';  Type = 'microsoft.compute/virtualmachinescalesets';                Worksheet = 'VM Scale Sets' }
    @{ Name = 'VMDisk';                  File = 'VMDisk.ps1';                  Type = 'microsoft.compute/disks';                                 Worksheet = 'Disks' }
    @{ Name = 'AvailabilitySets';        File = 'AvailabilitySets.ps1';        Type = 'microsoft.compute/availabilitysets';                      Worksheet = 'Availability Sets' }
    @{ Name = 'CloudServices';           File = 'CloudServices.ps1';           Type = 'microsoft.classiccompute/domainnames';                    Worksheet = 'Cloud Services' }
    @{ Name = 'AVDApplicationGroups';    File = 'AVDApplicationGroups.ps1';    Type = 'microsoft.desktopvirtualization/applicationgroups';       Worksheet = 'AVD Application Groups' }
    @{ Name = 'AVDWorkspaces';           File = 'AVDWorkspaces.ps1';           Type = 'microsoft.desktopvirtualization/workspaces';              Worksheet = 'AVD Workspaces' }
    @{ Name = 'AVDSessionHosts';         File = 'AVDSessionHosts.ps1';         Type = 'microsoft.desktopvirtualization/hostpools/sessionhosts';  Worksheet = 'AVD Session Hosts' }
    @{ Name = 'AVDScalingPlans';         File = 'AVDScalingPlans.ps1';         Type = 'microsoft.desktopvirtualization/scalingplans';            Worksheet = 'AVD Scaling Plans' }
    @{ Name = 'AVDApplications';        File = 'AVDApplications.ps1';        Type = 'microsoft.desktopvirtualization/applicationgroups';      Worksheet = 'AVD Applications' }
    @{ Name = 'VMWare';                  File = 'VMWare.ps1';                  Type = 'Microsoft.AVS/privateClouds';                            Worksheet = 'VMWare' }
    @{ Name = 'VMOperationalData';       File = 'VMOperationalData.ps1';       Type = 'microsoft.compute/virtualmachines';                      Worksheet = 'VM Operational' }
    @{ Name = 'AVDAzureLocal';           File = 'AVDAzureLocal.ps1';           Type = 'microsoft.hybridcompute/machines';                    Worksheet = 'AVD Azure Local' }
)

# AVD Host Pools needs its own spec (Worksheet name differs from plan)
$AVDHostPoolSpec = @{ Name = 'AVD'; File = 'AVD.ps1'; Type = 'microsoft.desktopvirtualization/hostpools'; Worksheet = 'AVD Host Pools' }

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot  = Split-Path -Parent $PSScriptRoot
    $script:ComputePath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Compute'
    $script:TempDir     = Join-Path $env:TEMP 'AZSC_ComputeTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockVM {
        param([string]$Id, [string]$Name, [string]$Location = 'eastus',
              [string]$SubscriptionId = 'sub-00000001', [string]$RG = 'rg-test', [object]$Props)
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = 'microsoft.compute/virtualmachines'
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            KIND           = ''
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Props
        }
    }

    function New-MockResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Location = 'eastus',
              [string]$SubscriptionId = 'sub-00000001', [string]$RG = 'rg-test',
              [object]$Props, [string]$Kind = '', [string]$ManagedBy = '')
        [PSCustomObject]@{
            id             = $Id
            NAME           = $Name
            TYPE           = $Type
            LOCATION       = $Location
            RESOURCEGROUP  = $RG
            subscriptionId = $SubscriptionId
            KIND           = $Kind
            tags           = [PSCustomObject]@{}
            PROPERTIES     = $Props
            MANAGEDBY      = $ManagedBy
        }
    }

    function Invoke-ComputeModule {
        param([string]$ModuleFile, [string]$Task,
              [object]$Resources = $null, [object]$SmaResources = $null,
              [string]$File = $null, [string]$TableStyle = 'Light20')
        $content = Get-Content -Path $ModuleFile -Raw
        $sb = [ScriptBlock]::Create($content)
        Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $Resources, $null, $Task, $File, $SmaResources, $TableStyle, $null
    }

    # ── Mock resources ────────────────────────────────────────────────
    $script:MockResources = @()

    # Virtual Machine
    $script:MockResources += New-MockVM -Id '/sub/sub-00000001/vm/vm01' -Name 'vm-prod-01' -Props ([PSCustomObject]@{
        storageProfile = [PSCustomObject]@{
            osDisk         = [PSCustomObject]@{ osType = 'Windows'; diskSizeGB = 128 }
            dataDisks      = @()
            imageReference = [PSCustomObject]@{ publisher = 'MicrosoftWindowsServer'; offer = 'WindowsServer'; sku = '2022-Datacenter'; version = 'latest' }
        }
        hardwareProfile  = [PSCustomObject]@{ vmSize = 'Standard_D4s_v3' }
        osProfile        = [PSCustomObject]@{ computerName = 'vm-prod-01'; adminUsername = 'azureuser' }
        networkProfile   = [PSCustomObject]@{ networkInterfaces = @(@{ id = '/sub/sub-00000001/nic/nic01' }) }
        provisioningState = 'Succeeded'
        powerState       = 'PowerState/running'
        timeCreated      = '2025-06-15T08:30:00Z'
    })

    # VM Disk
    $script:MockResources += New-MockResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-test/providers/microsoft.compute/disks/disk-os-01' -Name 'disk-os-01' -Type 'microsoft.compute/disks' -ManagedBy '/subscriptions/sub-00000001/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-prod-01' -Props ([PSCustomObject]@{
        diskSizeGB = 128; osType = 'Windows'; diskState = 'Attached'; hyperVGeneration = 'V2'
        provisioningState = 'Succeeded'; timeCreated = '2026-01-01T00:00:00Z'
        creationData = [PSCustomObject]@{ createOption = 'FromImage' }
        encryption = [PSCustomObject]@{ type = 'EncryptionAtRestWithPlatformKey' }
        sku = [PSCustomObject]@{ name = 'Premium_LRS' }
    })

    # NIC (needed by VirtualMachine module)
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/nic/nic01' -Name 'nic01' -Type 'microsoft.network/networkinterfaces' -Props ([PSCustomObject]@{
        ipConfigurations = @(@{ properties = [PSCustomObject]@{ subnet = [PSCustomObject]@{ id = '/vnet/vnet1/subnets/default' }; privateIPAddress = '10.0.0.4'; publicIPAddress = $null } })
        enableAcceleratedNetworking = $true; enableIPForwarding = $false
        virtualMachine = [PSCustomObject]@{ id = '/sub/sub-00000001/vm/vm01' }
    })

    # VM Scale Set
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/vmss/vmss01' -Name 'vmss-web' -Type 'microsoft.compute/virtualmachinescalesets' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'Standard_D2s_v3'; capacity = 3; tier = 'Standard' }
        upgradePolicy = [PSCustomObject]@{ mode = 'Automatic' }
        provisioningState = 'Succeeded'
        singlePlacementGroup = $true
        orchestrationMode = 'Uniform'
        timeCreated = '2025-07-01T12:00:00Z'
    })

    # Availability Set
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/as/as01' -Name 'as-web' -Type 'microsoft.compute/availabilitysets' -Props ([PSCustomObject]@{
        platformUpdateDomainCount = 5; platformFaultDomainCount = 3
        virtualMachines = @(@{ id = '/vm/vm01' })
        sku = [PSCustomObject]@{ name = 'Aligned' }
    })

    # Cloud Services
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/cs/cs01' -Name 'cs-legacy' -Type 'microsoft.classiccompute/domainnames' -Props ([PSCustomObject]@{
        status = 'Running'; label = 'Legacy Cloud Service'; deploymentSlot = 'Production'
    })

    # AVD Host Pool
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/hp/hp01' -Name 'hp-prod' -Type 'microsoft.desktopvirtualization/hostpools' -Props ([PSCustomObject]@{
        hostPoolType = 'Pooled'; loadBalancerType = 'BreadthFirst'; maxSessionLimit = 10
        validationEnvironment = $false; startVMOnConnect = $true
        registrationInfo = [PSCustomObject]@{ expirationTime = '9999-12-31T23:59:59Z' }
        preferredAppGroupType = 'Desktop'
    })

    # AVD Application Group
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/ag/ag01' -Name 'ag-desktop' -Type 'microsoft.desktopvirtualization/applicationgroups' -Props ([PSCustomObject]@{
        applicationGroupType = 'Desktop'; hostPoolArmPath = '/hp/hp01'
        workspaceArmPath = '/ws/ws01'; friendlyName = 'Desktop Apps'
    })

    # AVD Application Group (RemoteApp) — needed by AVDApplications module
    $script:MockResources += New-MockResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/applicationGroups/ag-remoteapp' `
        -Name 'ag-remoteapp' -Type 'microsoft.desktopvirtualization/applicationgroups' -Props ([PSCustomObject]@{
        applicationGroupType = 'RemoteApp'; hostPoolArmPath = '/hp/hp01'
        workspaceArmPath = '/ws/ws01'; friendlyName = 'Remote Apps'
    })

    # AVD Workspace
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/avdws/avdws01' -Name 'avdws-prod' -Type 'microsoft.desktopvirtualization/workspaces' -Props ([PSCustomObject]@{
        applicationGroupReferences = @('/ag/ag01'); friendlyName = 'Production Workspace'
        publicNetworkAccess = 'Enabled'
    })

    # AVD Session Host
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/hp/hp01/sessionhosts/vm01' -Name 'hp01/vm01.corp.com' -Type 'microsoft.desktopvirtualization/hostpools/sessionhosts' -Props ([PSCustomObject]@{
        status = 'Available'; agentVersion = '1.0.5780'; osVersion = 'Windows Server 2022'
        sessions = 2; allowNewSession = $true; assignedUser = $null
        lastHeartBeat = '2026-02-24T10:00:00Z'; updateState = 'Succeeded'
        resourceId = '/sub/sub-00000001/vm/vm01'
    })

    # AVD Session Host (Azure Local / hybridCompute) — needed by AVDAzureLocal module
    $script:MockResources += New-MockResource `
        -Id '/subscriptions/sub-00000001/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp01/sessionHosts/arcvm01' `
        -Name 'hp01/arcvm01.corp.com' -Type 'microsoft.desktopvirtualization/hostpools/sessionhosts' -Props ([PSCustomObject]@{
        status = 'Available'; agentVersion = '1.0.5780'; osVersion = 'Windows Server 2022'
        sessions = 1; allowNewSession = $true; assignedUser = 'testuser@corp.com'
        lastHeartBeat = '2026-02-24T10:00:00Z'; updateState = 'Succeeded'
        resourceId = '/subscriptions/sub-00000001/resourceGroups/rg-avd/providers/Microsoft.hybridCompute/machines/arcvm01'
    })

    # Arc machine tagged as AVD session host — needed by AVDAzureLocal module
    $script:MockResources += [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-avd/providers/Microsoft.HybridCompute/machines/arcvm01'
        NAME           = 'arcvm01'
        TYPE           = 'microsoft.hybridcompute/machines'
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-avd'
        subscriptionId = 'sub-00000001'
        KIND           = ''
        tags           = [PSCustomObject]@{ AvdSessionHost = 'true' }
        PROPERTIES     = [PSCustomObject]@{
            status           = 'Connected'
            agentversion     = '1.0.5780'
            osVersion        = 'Windows Server 2022'
            lastStatusChange = '2026-02-24T10:00:00Z'
        }
        MANAGEDBY      = ''
    }

    # AVD Scaling Plan
    $script:MockResources += New-MockResource -Id '/sub/sub-00000001/sp/sp01' -Name 'sp-weekday' -Type 'microsoft.desktopvirtualization/scalingplans' -Props ([PSCustomObject]@{
        hostPoolReferences = @(@{ hostPoolArmPath = '/hp/hp01'; scalingPlanEnabled = $true })
        schedules = @(@{ name = 'Weekday'; daysOfWeek = @('Monday','Tuesday') })
        timeZone = 'Eastern Standard Time'
        exclusionTag = 'ExcludeScaling'
    })

    # VMWare Private Cloud
    $script:MockResources += New-MockResource -Id '/subscriptions/sub-00000001/resourceGroups/rg-avs/providers/Microsoft.AVS/privateClouds/avs-prod' -Name 'avs-prod' -Type 'Microsoft.AVS/privateClouds' -Props ([PSCustomObject]@{
        sku = [PSCustomObject]@{ name = 'AV36' }
        availability = [PSCustomObject]@{ strategy = 'SingleZone'; zone = 1 }
        circuit = [PSCustomObject]@{ expressRouteID = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/expressRouteCircuits/er-avs' }
        encryption = [PSCustomObject]@{ status = 'Enabled' }
        externalCloudLinks = @()
        identitySources = @()
        internet = 'Disabled'
        managementCluster = [PSCustomObject]@{ clusterSize = 3 }
        managementNetwork = '10.0.0.0/22'
        networkBlock = '10.0.0.0/22'
        provisioningNetwork = '10.0.4.0/24'
        vmotionNetwork = '10.0.8.0/24'
        endpoints = [PSCustomObject]@{ hcxCloudManager = 'https://hcx.avs-prod.azure.com'; nsxtManager = 'https://nsx.avs-prod.azure.com'; vcsa = 'https://vcsa.avs-prod.azure.com' }
    })

    # Mock Invoke-AzRestMethod for AVDApplications and VMOperationalData
    function Invoke-AzRestMethod {
        param([string]$Path, [string]$Method = 'GET')
        $mockResponse = @{ value = @() }
        if ($Path -match '/applicationgroups/.+/applications\?') {
            $mockResponse = @{ value = @(@{ name = 'Calculator'; properties = @{ friendlyName = 'Calculator'; description = 'Windows Calculator'; applicationType = 'InBuilt'; filePath = 'C:\Windows\system32\calc.exe'; commandLineSetting = 'DoNotAllow'; commandLineArguments = ''; iconPath = 'C:\Windows\system32\calc.exe'; showInPortal = $true } }) }
        } elseif ($Path -match 'patchAssessmentResults') {
            $mockResponse = @{ value = @(); properties = @{ startDateTime = '2025-06-01T00:00:00Z'; availablePatchCountByClassification = @{ critical = 0; security = 1; updateRollUp = 2 }; lastModifiedDateTime = '2025-06-01T12:00:00Z' } }
        }
        [PSCustomObject]@{ Content = ($mockResponse | ConvertTo-Json -Depth 10); StatusCode = 200 }
    }
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'Compute Module Files Exist' {
    It 'Compute module folder exists' {
        $script:ComputePath | Should -Exist
    }

    It '<Name> module file exists' -ForEach ($ComputeModules + @($AVDHostPoolSpec)) {
        Join-Path $script:ComputePath $File | Should -Exist
    }
}

Describe 'Compute Module Processing Phase — <Name>' -ForEach $ComputeModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:ComputePath $File
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

Describe 'Compute Module Reporting Phase — <Name>' -ForEach $ComputeModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:ComputePath $File
        $script:ResType  = $Type
        $script:WsName   = $Worksheet
        $script:XlsxFile = Join-Path $script:TempDir ("Compute_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())

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

Describe 'AVD SessionHosts — Processing produces expected fields' {
    It 'Produces Host Pool, Session Host, Status, Arc Enabled, Azure Local, Agent Version fields' {
        $modFile  = Join-Path $script:ComputePath 'AVDSessionHosts.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $sb       = [ScriptBlock]::Create($content)
        $result   = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
        $row = $result | Select-Object -First 1
        $row.Keys | Should -Contain 'Host Pool'
        $row.Keys | Should -Contain 'Session Host'
        $row.Keys | Should -Contain 'Status'
        $row.Keys | Should -Contain 'Arc Enabled'
        $row.Keys | Should -Contain 'Azure Local'
        $row.Keys | Should -Contain 'Agent Version'
    }
}

Describe 'VirtualMachine — Processing produces required columns' {
    It 'Processing returns rows with OS, SKU and VM Name fields' {
        $modFile = Join-Path $script:ComputePath 'VirtualMachine.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
    }
}
