#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for Storage inventory modules (NetApp, StorageAccounts).
#>

$StoragePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Storage'

$StorageModules = @(
    @{ Name = 'NetApp';          File = 'NetApp.ps1';          Type = 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'; Worksheet = 'NetApp' }
    @{ Name = 'StorageAccounts'; File = 'StorageAccounts.ps1'; Type = 'microsoft.storage/storageaccounts';                     Worksheet = 'Storage Accounts' }
)

BeforeAll {
    $script:ModuleRoot  = Split-Path -Parent $PSScriptRoot
    $script:StoragePath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Storage'
    $script:TempDir     = Join-Path $env:TEMP 'AZSC_StorageTests'
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # Mock Az Storage cmdlets that StorageAccounts.ps1 calls
    function Get-AzStorageBlobServiceProperty {
        param([string]$ResourceGroupName, [string]$StorageAccountName)
        [PSCustomObject]@{
            DeleteRetentionPolicy = [PSCustomObject]@{ Enabled = $true; Days = 7 }
            containerDeleteRetentionPolicy = [PSCustomObject]@{ Enabled = $true; Days = 7 }
        }
    }
    function Get-AzStorageFileServiceProperty {
        param([string]$ResourceGroupName, [string]$StorageAccountName)
        [PSCustomObject]@{
            ShareDeleteRetentionPolicy = [PSCustomObject]@{ Enabled = $true; Days = 7 }
        }
    }

    $script:MockResources = @()

    # --- NetApp Volume ---
    $netAppRes = [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-storage/providers/Microsoft.NetApp/netAppAccounts/na-prod/capacityPools/pool1/volumes/vol1'
        NAME           = 'na-prod/pool1/vol1'
        TYPE           = 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
        KIND           = ''
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-storage'
        subscriptionId = 'sub-00000001'
        tags           = [PSCustomObject]@{ env = 'prod' }
        PROPERTIES     = [PSCustomObject]@{
            subnetId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-netapp/subnets/anf-subnet'
            serviceLevel = 'Premium'
            usageThreshold = 1099511627776   # 1 TB
            protocolTypes = @('NFSv3')
            throughputMibps = 64
            exportPolicy = [PSCustomObject]@{ rules = @([PSCustomObject]@{ruleIndex=1}) }
            networkFeatures = 'Standard'
            securityStyle = 'unix'
            smbEncryption = $false
            unixPermissions = '0770'
            coolAccess = $false
            avsDataStore = 'Disabled'
            ldapEnabled = $false
        }
    }
    $script:MockResources += $netAppRes

    # --- Storage Account ---
    $saResource = [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-storage/providers/microsoft.storage/storageaccounts/saprod01'
        NAME           = 'saprod01'
        TYPE           = 'microsoft.storage/storageaccounts'
        KIND           = 'StorageV2'
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-storage'
        subscriptionId = 'sub-00000001'
        tags           = [PSCustomObject]@{ env = 'prod' }
        SKU            = [PSCustomObject]@{ name = 'Standard_LRS'; tier = 'Standard' }
        ZONES          = @('1')
        PROPERTIES     = [PSCustomObject]@{
            creationTime = '2025-01-10T08:00:00Z'
            supportsHttpsTrafficOnly = $true
            allowBlobPublicAccess = $false
            minimumTlsVersion = 'TLS1_2'
            allowsharedkeyaccess = $true
            isSftpEnabled = $false
            ishnsenabled = $false
            isnfsv3enabled = $false
            largeFileSharesState = 'Disabled'
            allowCrossTenantReplication = $false
            encryption = [PSCustomObject]@{ requireInfrastructureEncryption = $true }
            azureFilesIdentityBasedAuthentication = [PSCustomObject]@{ directoryServiceOptions = 'None' }
            networkacls = [PSCustomObject]@{
                defaultaction = 'Allow'
                virtualnetworkrules = @([PSCustomObject]@{
                    id = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-sa/subnets/sa-subnet'
                })
                iprules = @([PSCustomObject]@{ value = '10.0.0.1' })
                bypass = 'AzureServices'
                resourceaccessrules = @([PSCustomObject]@{ resourceid = '/subscriptions/sub-00000001/resourceGroups/rg-other/providers/Microsoft.Synapse/workspaces/syn-prod' })
            }
            publicNetworkAccess = 'Enabled'
            privateEndpointConnections = @([PSCustomObject]@{
                properties = [PSCustomObject]@{
                    privateendpoint = [PSCustomObject]@{
                        id = '/subscriptions/sub-00000001/resourceGroups/rg-storage/providers/Microsoft.Network/privateEndpoints/pe-sa'
                    }
                }
            })
            accessTier = 'Hot'
            primaryLocation = 'eastus'
            statusOfPrimary = 'available'
            secondaryLocation = $null
            statusofsecondary = $null
        }
    }
    $saResource | Add-Member -NotePropertyName 'sku' -NotePropertyValue $saResource.SKU -Force
    $saResource | Add-Member -NotePropertyName 'kind' -NotePropertyValue $saResource.KIND -Force
    $script:MockResources += $saResource
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

Describe 'Storage Module Files Exist' {
    It 'Storage module folder exists' { $script:StoragePath | Should -Exist }
    It '<Name> module file exists' -ForEach $StorageModules { Join-Path $script:StoragePath $File | Should -Exist }
}

Describe 'Storage Module Processing Phase — <Name>' -ForEach $StorageModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:StoragePath $File
        $script:ResType = $Type
    }
    It 'Processing returns results when matching resources are present' {
        $matchedResources = $script:MockResources | Where-Object { $_.TYPE -eq $script:ResType }
        if ($matchedResources) {
            $content = Get-Content -Path $script:ModFile -Raw
            $sb = [ScriptBlock]::Create($content)
            $result = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
            $result | Should -Not -BeNullOrEmpty
        } else { Set-ItResult -Skipped -Because "No mock resource of type '$script:ResType'" }
    }
    It 'Processing does not throw when given an empty resource list' {
        $content = Get-Content -Path $script:ModFile -Raw
        $sb = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Storage Module Reporting Phase — <Name>' -ForEach $StorageModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:StoragePath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("Stor_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())
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
        } else { Set-ItResult -Skipped -Because 'No processed data' }
    }
    It 'Excel file is created' {
        if ($script:ProcessedData) { $script:XlsxFile | Should -Exist }
        else { Set-ItResult -Skipped -Because 'No processed data' }
    }
}
