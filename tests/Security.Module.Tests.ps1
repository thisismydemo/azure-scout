#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Pester tests for all Security inventory modules.

.DESCRIPTION
    Tests both Processing and Reporting phases for Security modules.
    Defender modules (DefenderAlerts, DefenderAssessments, DefenderPricing,
    DefenderSecureScore) call live Az Security cmdlets in Processing — those
    are verified for graceful failure and empty-data Reporting behavior.
    Key Vault (Vault.ps1) uses $Resources and is fully tested with mock data.

.NOTES
    Author:  AzureScout Contributors
    Version: 1.0.0
    Created: 2026-02-24
    Phase:   9.2 — Defender for Cloud Testing
#>

# ===================================================================
# DISCOVERY-TIME
# ===================================================================
$SecurityPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Modules' 'Public' 'InventoryModules' 'Security'

$SecurityModuleFiles = @(
    @{ Name = 'Vault';                File = 'Vault.ps1' }
    @{ Name = 'DefenderAlerts';       File = 'DefenderAlerts.ps1' }
    @{ Name = 'DefenderAssessments';  File = 'DefenderAssessments.ps1' }
    @{ Name = 'DefenderPricing';      File = 'DefenderPricing.ps1' }
    @{ Name = 'DefenderSecureScore';  File = 'DefenderSecureScore.ps1' }
)

# ===================================================================
# EXECUTION-TIME SETUP
# ===================================================================
BeforeAll {
    $script:ModuleRoot   = Split-Path -Parent $PSScriptRoot
    $script:SecurityPath = Join-Path $script:ModuleRoot 'Modules' 'Public' 'InventoryModules' 'Security'
    $script:TempDir      = Join-Path $env:TEMP 'AZSC_SecurityTests'

    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    function New-MockSecResource {
        param([string]$Id, [string]$Name, [string]$Type, [string]$Kind = '',
              [string]$Location = 'eastus', [string]$RG = 'rg-sec',
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

    # Key Vault
    $script:MockResources += New-MockSecResource -Id '/sec/kv1' -Name 'kv-prod' `
        -Type 'microsoft.keyvault/vaults' -Props ([PSCustomObject]@{
        sku             = [PSCustomObject]@{ name = 'premium'; family = 'A' }
        tenantId        = 'tenant-001'
        enabledForDeployment         = $false
        enabledForTemplateDeployment = $true
        enabledForDiskEncryption     = $true
        enableSoftDelete             = $true
        softDeleteRetentionInDays    = 90
        enablePurgeProtection        = $true
        enableRbacAuthorization      = $true
        publicNetworkAccess          = 'Disabled'
        networkAcls = [PSCustomObject]@{ bypass = 'AzureServices'; defaultAction = 'Deny'; ipRules = @(); virtualNetworkRules = @() }
        provisioningState = 'Succeeded'
        vaultUri = 'https://kv-prod.vault.azure.net/'
    })
}

AfterAll {
    if (Test-Path $script:TempDir) { Remove-Item $script:TempDir -Recurse -Force }
}

# ===================================================================
# TESTS
# ===================================================================
Describe 'Security Module Files Exist' {
    It 'Security module folder exists' {
        $script:SecurityPath | Should -Exist
    }

    It '<Name> module file exists' -ForEach $SecurityModuleFiles {
        Join-Path $script:SecurityPath $File | Should -Exist
    }
}

Describe 'Key Vault (Vault.ps1) — Processing' {
    It 'Processing returns results for Key Vault resources' {
        $modFile = Join-Path $script:SecurityPath 'Vault.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Processing returns no output for empty resource list without throwing' {
        $modFile = Join-Path $script:SecurityPath 'Vault.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'Processing output contains expected Key Vault fields' {
        $modFile = Join-Path $script:SecurityPath 'Vault.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        $result  = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $row = $result | Select-Object -First 1
        $row.Keys | Should -Contain 'Name'
        $row.Keys | Should -Contain 'Subscription'
        $row.Keys | Should -Contain 'Resource Group'
    }
}

Describe 'Key Vault (Vault.ps1) — Reporting' {
    BeforeAll {
        $modFile  = Join-Path $script:SecurityPath 'Vault.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $sb       = [ScriptBlock]::Create($content)
        $script:KvProcessed = Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $script:MockResources, $null, 'Processing', $null, $null, 'Light20', $null
        $script:KvXlsx = Join-Path $script:TempDir 'Vault_test.xlsx'
    }

    It 'Reporting phase does not throw' {
        $modFile = Join-Path $script:SecurityPath 'Vault.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $script:KvXlsx, $script:KvProcessed, 'Light20', $null } | Should -Not -Throw
    }

    It 'Excel file is created' {
        $script:KvXlsx | Should -Exist
    }
}

Describe 'Defender Modules — Graceful Behavior Without Live Azure Connection' {

    It 'DefenderAlerts Processing does not throw when Get-AzSecurityAlert is unavailable' {
        $modFile = Join-Path $script:SecurityPath 'DefenderAlerts.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderAssessments Processing does not throw when Get-AzSecurityAssessment is unavailable' {
        $modFile = Join-Path $script:SecurityPath 'DefenderAssessments.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderPricing Processing does not throw when Get-AzSecurityPricing is unavailable' {
        $modFile = Join-Path $script:SecurityPath 'DefenderPricing.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderSecureScore Processing does not throw when Get-AzSecuritySecureScore is unavailable' {
        $modFile = Join-Path $script:SecurityPath 'DefenderSecureScore.ps1'
        $content = Get-Content -Path $modFile -Raw
        $sb      = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, @(), $null, 'Processing', $null, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderAlerts Reporting does not throw with empty data' {
        $modFile  = Join-Path $script:SecurityPath 'DefenderAlerts.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir 'DefenderAlerts_empty.xlsx'
        $sb       = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderAssessments Reporting does not throw with empty data' {
        $modFile  = Join-Path $script:SecurityPath 'DefenderAssessments.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir 'DefenderAssessments_empty.xlsx'
        $sb       = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderPricing Reporting does not throw with empty data' {
        $modFile  = Join-Path $script:SecurityPath 'DefenderPricing.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir 'DefenderPricing_empty.xlsx'
        $sb       = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }

    It 'DefenderSecureScore Reporting does not throw with empty data' {
        $modFile  = Join-Path $script:SecurityPath 'DefenderSecureScore.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $xlsxFile = Join-Path $script:TempDir 'DefenderSecureScore_empty.xlsx'
        $sb       = [ScriptBlock]::Create($content)
        { Invoke-Command -ScriptBlock $sb -ArgumentList $null, $null, $null, $null, $null, 'Reporting', $xlsxFile, $null, 'Light20', $null } | Should -Not -Throw
    }
}

Describe 'Defender modules contain correct Azure resource type filters' {
    It 'DefenderAlerts.ps1 contains Get-AzSecurityAlert call' {
        $modFile  = Join-Path $script:SecurityPath 'DefenderAlerts.ps1'
        $content  = Get-Content -Path $modFile -Raw
        $content | Should -Match 'Get-AzSecurityAlert'
    }

    It 'DefenderAssessments.ps1 contains Get-AzSecurityAssessment call' {
        $modFile = Join-Path $script:SecurityPath 'DefenderAssessments.ps1'
        $content = Get-Content -Path $modFile -Raw
        $content | Should -Match 'Get-AzSecurityAssessment'
    }

    It 'DefenderPricing.ps1 contains Get-AzSecurityPricing call' {
        $modFile = Join-Path $script:SecurityPath 'DefenderPricing.ps1'
        $content = Get-Content -Path $modFile -Raw
        $content | Should -Match 'Get-AzSecurityPricing'
    }

    It 'DefenderSecureScore.ps1 contains Get-AzSecuritySecureScore call' {
        $modFile = Join-Path $script:SecurityPath 'DefenderSecureScore.ps1'
        $content = Get-Content -Path $modFile -Raw
        $content | Should -Match 'Get-AzSecuritySecureScore'
    }
}
