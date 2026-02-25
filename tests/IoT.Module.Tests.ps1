#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for IoT inventory modules (IOTHubs).
#>

$IoTPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'IoT'

$IoTModules = @(
    @{ Name = 'IOTHubs'; File = 'IOTHubs.ps1'; Type = 'microsoft.devices/iothubs'; Worksheet = 'IOTHubs' }
)

BeforeAll {
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:IoTPath    = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'IoT'
    $script:TempDir    = Join-Path $env:TEMP 'AZSC_IoTTests'
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    $script:MockResources = @()

    # --- IOTHub ---
    $script:MockResources += [PSCustomObject]@{
        id             = '/subscriptions/sub-00000001/resourceGroups/rg-iot/providers/microsoft.devices/iothubs/iothub-prod'
        NAME           = 'iothub-prod'
        TYPE           = 'microsoft.devices/iothubs'
        KIND           = ''
        LOCATION       = 'eastus'
        RESOURCEGROUP  = 'rg-iot'
        subscriptionId = 'sub-00000001'
        tags           = [PSCustomObject]@{ env = 'prod' }
        PROPERTIES     = [PSCustomObject]@{
            sku = [PSCustomObject]@{ name = 'S1'; tier = 'Standard' }
            locations = @(
                [PSCustomObject]@{ location = 'East US'; role = 'primary' }
                [PSCustomObject]@{ location = 'West US'; role = 'secondary' }
            )
            state = 'Active'
            ipFilterRules = @([PSCustomObject]@{ filterName = 'AllowAll'; action = 'Accept'; ipMask = '0.0.0.0/0' })
            eventHubEndpoints = [PSCustomObject]@{
                events = [PSCustomObject]@{ retentionTimeInDays = 7; partitionCount = 4; path = 'iothub-prod' }
            }
            cloudToDevice = [PSCustomObject]@{ maxDeliveryCount = 10 }
            hostName = 'iothub-prod.azure-devices.net'
        }
    }
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

Describe 'IoT Module Files Exist' {
    It 'IoT module folder exists' { $script:IoTPath | Should -Exist }
    It '<Name> module file exists' -ForEach $IoTModules { Join-Path $script:IoTPath $File | Should -Exist }
}

Describe 'IoT Module Processing Phase — <Name>' -ForEach $IoTModules {
    BeforeAll {
        $script:ModFile = Join-Path $script:IoTPath $File
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

Describe 'IoT Module Reporting Phase — <Name>' -ForEach $IoTModules {
    BeforeAll {
        $script:ModFile  = Join-Path $script:IoTPath $File
        $script:ResType  = $Type
        $script:XlsxFile = Join-Path $script:TempDir ("IoT_{0}_{1}.xlsx" -f $Name, [System.IO.Path]::GetRandomFileName())
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
