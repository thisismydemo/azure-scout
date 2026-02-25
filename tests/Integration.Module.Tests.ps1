#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for Integration inventory modules (APIM, ServiceBus).
#>

$IntegrationPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Integration'

$IntegrationModules = @(
    @{ Name = 'APIM';       File = 'APIM.ps1';       Type = 'microsoft.apimanagement/service';  Worksheet = 'APIM' }
    @{ Name = 'ServiceBUS'; File = 'ServiceBUS.ps1'; Type = 'microsoft.servicebus/namespaces';  Worksheet = 'Service BUS' }
)

BeforeAll {
    $script:ModuleRoot       = Split-Path -Parent $PSScriptRoot
    $script:IntegrationPath  = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Integration'
    $script:TempDir          = Join-Path $env:TEMP 'AZSC_IntegrationTests'
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    $script:MockResources = @()

    # --- APIM ---
    $script:MockResources += [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-int/providers/microsoft.apimanagement/service/apim-prod'
        NAME           = 'apim-prod'
        TYPE           = 'microsoft.apimanagement/service'
        KIND           = ''
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-int'
        subscriptionId = 'sub-00000001'
        tags           = [PSCustomObject]@{ env = 'prod' }
        sku            = [PSCustomObject]@{ name = 'Premium'; capacity = 2 }
        PROPERTIES     = [PSCustomObject]@{
            gatewayUrl = 'https://apim-prod.azure-api.net'
            virtualNetworkType = 'External'
            virtualNetworkConfiguration = [PSCustomObject]@{
                subnetResourceId = '/subscriptions/sub-00000001/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-apim/subnets/apim-subnet'
            }
            customProperties = [PSCustomObject]@{
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2' = 'True'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10' = 'False'
                'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11' = 'False'
            }
            publicIPAddresses = @('20.1.2.3')
        }
    }

    # --- ServiceBus ---
    $script:MockResources += [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-int/providers/microsoft.servicebus/namespaces/sb-prod'
        NAME           = 'sb-prod'
        TYPE           = 'microsoft.servicebus/namespaces'
        KIND           = ''
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-int'
        subscriptionId = 'sub-00000001'
        tags           = [PSCustomObject]@{ env = 'prod' }
        SKU            = [PSCustomObject]@{ name = 'Premium'; capacity = 1 }
        PROPERTIES     = [PSCustomObject]@{
            createdAt = '2025-01-15T08:00:00Z'
            status = 'Active'
            zoneRedundant = $true
            serviceBusEndpoint = 'https://sb-prod.servicebus.windows.net:443/'
        }
    }
    # Add lowercase sku alias for APIM (it uses $1.sku.name)
    $script:MockResources[0] | Add-Member -NotePropertyName 'SKU' -NotePropertyValue $script:MockResources[0].sku -Force
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

Describe 'Integration Module Files Exist' {
    It 'Integration module folder exists' { $script:IntegrationPath | Should -Exist }
    It '<Name> module file exists' -ForEach $IntegrationModules { Join-Path $script:IntegrationPath $File | Should -Exist }
}

Describe 'Integration Module Processing Phase — <Name>' -ForEach $IntegrationModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:IntegrationPath $File
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

Describe 'Integration Module Reporting Phase — <Name>' -ForEach $IntegrationModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:IntegrationPath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("Int_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())
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
