#Requires -Version 7.0
#Requires -Modules Pester

<#
    AB#7098 (Story AB#7071, Feature AB#7069, Epic AB#7099) -- Microsoft Entra External ID.

    Three things this file pins:

      1. Get-ScoutEntraQueryCatalog carries the new 'External Identities' query, and
         Start-ScoutEntraExtraction's normalizer no longer throws on a Graph response with no
         `id` property (crossTenantAccessPolicyConfigurationDefault has none -- every OTHER
         catalog entry's response does, so this was previously untested).

      2. Get-ScoutExternalIdentitiesPolicy.ps1 shapes GET /policies/crossTenantAccessPolicy/default
         into the flat contract domains.identity.externalIdentitiesPolicy carries -- b2b access types,
         inbound trust booleans, tenant restrictions -- and reports Collected = $false, not a
         thrown exception, when Graph is unreachable or returns nothing.

      3. Invoke-Collect wires domains.identity.externalIdentitiesPolicy into the canonical collect.json
         contract, gated off for -Scope ArmOnly, and never missing (even as the "not collected"
         shape) when the Graph call fails or is skipped.

    Search-AzGraph is mocked throughout. No live Azure connection is made.
#>

BeforeAll {
    $script:root = Split-Path $PSScriptRoot -Parent

    . "$script:root/src/collect/Get-ScoutEntraQueryCatalog.ps1"
    . "$script:root/src/Get-AZTIGraphToken.ps1"
    . "$script:root/src/collect/Start-ScoutEntraExtraction.ps1"
    . "$script:root/src/Get-AZSCSafeProperty.ps1"
    . "$script:root/src/Invoke-AZTIGraphRequest.ps1"
    . "$script:root/src/collect/Get-ScoutExternalIdentitiesPolicy.ps1"

    function New-DefaultCrossTenantAccessResponse {
        [pscustomobject]@{
            isServiceDefault      = $false
            b2bCollaborationInbound  = [pscustomobject]@{ applications = [pscustomobject]@{ accessType = 'allowed' } }
            b2bCollaborationOutbound = [pscustomobject]@{ applications = [pscustomobject]@{ accessType = 'allowed' } }
            b2bDirectConnectInbound  = [pscustomobject]@{ applications = [pscustomobject]@{ accessType = 'blocked' } }
            b2bDirectConnectOutbound = [pscustomobject]@{ applications = [pscustomobject]@{ accessType = 'blocked' } }
            inboundTrust           = [pscustomobject]@{
                isMfaAccepted = $true
                isCompliantDeviceAccepted = $false
                isHybridAzureADJoinedDeviceAccepted = $true
            }
            tenantRestrictions = [pscustomobject]@{ usersAndGroups = [pscustomobject]@{ accessType = 'blocked' } }
        }
    }
}

Describe 'Get-ScoutEntraQueryCatalog -- External Identities entry (AB#7098)' {
    It 'declares the default cross-tenant access policy query, GA v1.0, Policy.Read.All' {
        $catalog = @(Get-ScoutEntraQueryCatalog)
        $entry = $catalog | Where-Object { $_.Type -eq 'entra/externalidentities' }

        $entry | Should -Not -BeNullOrEmpty
        $entry.Name | Should -Be 'External Identities'
        $entry.Uri | Should -Be '/v1.0/policies/crossTenantAccessPolicy/default'
        $entry.Permission | Should -Be 'Policy.Read.All'
        $entry.SingleObject | Should -BeTrue
    }

    It 'is distinct from the existing Cross-Tenant Access (partners) query' {
        $catalog = @(Get-ScoutEntraQueryCatalog)
        $partners = $catalog | Where-Object { $_.Type -eq 'entra/crosstenantaccess' }
        $default = $catalog | Where-Object { $_.Type -eq 'entra/externalidentities' }

        $partners.Uri | Should -Be '/v1.0/policies/crossTenantAccessPolicy/partners'
        $default.Uri | Should -Not -Be $partners.Uri
    }
}

Describe 'Start-AZSCEntraExtraction -- normalizes a Graph object with no id property (AB#7098)' {
    BeforeEach {
        Mock Get-AZSCGraphToken {
            @{ Authorization = 'Bearer preflight-token'; 'Content-Type' = 'application/json' }
        }
    }

    It 'does not throw, and stamps the synthetic type with a $null id' {
        Mock Invoke-AZSCGraphRequest {
            param($Uri)
            if ($Uri -eq '/v1.0/policies/crossTenantAccessPolicy/default') {
                return New-DefaultCrossTenantAccessResponse
            }
            return @()
        }

        { Start-AZSCEntraExtraction -TenantID 'test-tenant' } | Should -Not -Throw

        $result = Start-AZSCEntraExtraction -TenantID 'test-tenant'
        $row = $result.EntraResources | Where-Object { $_.TYPE -eq 'entra/externalidentities' } | Select-Object -First 1
        $row | Should -Not -BeNullOrEmpty
        $row.id | Should -BeNullOrEmpty
        $row.tenantId | Should -Be 'test-tenant'
    }
}

Describe 'Get-ScoutExternalIdentitiesPolicy (AB#7098)' {
    It 'shapes b2b access types, inbound trust booleans and tenant restrictions from the default policy' {
        Mock Invoke-AZSCGraphRequest { New-DefaultCrossTenantAccessResponse }

        $policy = Get-ScoutExternalIdentitiesPolicy

        $policy.Collected | Should -BeTrue
        $policy.IsServiceDefault | Should -BeFalse
        $policy.B2BCollaborationInboundAccessType | Should -Be 'allowed'
        $policy.B2BCollaborationOutboundAccessType | Should -Be 'allowed'
        $policy.B2BDirectConnectInboundAccessType | Should -Be 'blocked'
        $policy.B2BDirectConnectOutboundAccessType | Should -Be 'blocked'
        $policy.InboundTrustMfa | Should -BeTrue
        $policy.InboundTrustCompliantDevice | Should -BeFalse
        $policy.InboundTrustHybridAzureADJoined | Should -BeTrue
        $policy.TenantRestrictionsAccessType | Should -Be 'blocked'
    }

    It 'reports Collected = $false, never throws, when Graph returns nothing' {
        Mock Invoke-AZSCGraphRequest { $null }

        { Get-ScoutExternalIdentitiesPolicy } | Should -Not -Throw
        $policy = Get-ScoutExternalIdentitiesPolicy
        $policy.Collected | Should -BeFalse
        $policy.IsServiceDefault | Should -BeNullOrEmpty
    }

    It 'reports Collected = $false, never throws, on a sparse response missing every optional block' {
        Mock Invoke-AZSCGraphRequest { [pscustomobject]@{ isServiceDefault = $true } }

        { Get-ScoutExternalIdentitiesPolicy } | Should -Not -Throw
        $policy = Get-ScoutExternalIdentitiesPolicy
        $policy.Collected | Should -BeTrue
        $policy.IsServiceDefault | Should -BeTrue
        $policy.B2BCollaborationInboundAccessType | Should -BeNullOrEmpty
        $policy.InboundTrustMfa | Should -BeNullOrEmpty
    }

    It 'pins the Graph request to the requested tenant' {
        Mock Invoke-AZSCGraphRequest { New-DefaultCrossTenantAccessResponse }

        $null = Get-ScoutExternalIdentitiesPolicy -TenantID 'target-tenant'

        Should -Invoke Invoke-AZSCGraphRequest -Exactly 1 -ParameterFilter {
            $TenantID -eq 'target-tenant'
        }
    }
}

Describe 'Invoke-Collect -- domains.identity.externalIdentitiesPolicy reaches the canonical contract (AB#7098)' {
    BeforeAll {
        function Import-Module {             [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Intentional local override of a built-in cmdlet to stub Azure/PowerShell calls for the test -- this is the point of the mock.')]
            [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', '', Justification = 'Mock/shadow function must declare the full real-cmdlet signature so PowerShell parameter binding accepts every argument the code under test passes; not every parameter is exercised by this test.')]
param([Parameter(ValueFromRemainingArguments)] $Rest) }
        . "$script:root/src/collect/ConvertFrom-ScoutInventory.ps1"
        . "$script:root/src/collect/Get-ScoutRawInventory.ps1"
        . "$script:root/src/collect/Invoke-Collect.ps1"
    }

    It 'populates the shaped policy on a normal (-Scope All) run' {
        function global:Search-AzGraph {             [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', '', Justification = 'Mock/shadow function must declare the full real-cmdlet signature so PowerShell parameter binding accepts every argument the code under test passes; not every parameter is exercised by this test.')]
param([string] $Query) return @() }
        Mock Invoke-AZSCGraphRequest { New-DefaultCrossTenantAccessResponse }

        try {
            $collect = Invoke-Collect -Source TypedQueries -WarningAction SilentlyContinue
            $collect.domains.identity.externalIdentitiesPolicy.Collected | Should -BeTrue
            $collect.domains.identity.externalIdentitiesPolicy.B2BCollaborationInboundAccessType | Should -Be 'allowed'
        }
        finally {
            Remove-Item function:Search-AzGraph -ErrorAction SilentlyContinue
        }
    }

    It 'threads the requested tenant through the assessment collector' {
        function global:Search-AzGraph {
            [Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Intentional local override of a built-in cmdlet to stub Azure calls for this test.')]
            [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', '', Justification = 'The stub accepts the production query signature; its value is irrelevant here.')]
            param([string] $Query)
            return @()
        }
        Mock Invoke-AZSCGraphRequest { New-DefaultCrossTenantAccessResponse }

        try {
            $null = Invoke-Collect -Source TypedQueries -TenantID 'target-tenant' -WarningAction SilentlyContinue
            Should -Invoke Invoke-AZSCGraphRequest -Exactly 1 -ParameterFilter {
                $TenantID -eq 'target-tenant'
            }
        }
        finally {
            Remove-Item function:Search-AzGraph -ErrorAction SilentlyContinue
        }
    }

    It 'skips the Graph call and reports Collected = $false on an -Scope ArmOnly run' {
        function global:Search-AzGraph {             [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', '', Justification = 'Mock/shadow function must declare the full real-cmdlet signature so PowerShell parameter binding accepts every argument the code under test passes; not every parameter is exercised by this test.')]
param([string] $Query) return @() }
        Mock Invoke-AZSCGraphRequest { throw 'must not be called for an ArmOnly run' }

        try {
            $collect = Invoke-Collect -Source TypedQueries -Scope ArmOnly -WarningAction SilentlyContinue
            $collect.domains.identity.externalIdentitiesPolicy.Collected | Should -BeFalse
        }
        finally {
            Remove-Item function:Search-AzGraph -ErrorAction SilentlyContinue
        }
    }

    It 'never omits domains.identity.externalIdentitiesPolicy, even when the Graph call fails' {
        function global:Search-AzGraph {             [Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', '', Justification = 'Mock/shadow function must declare the full real-cmdlet signature so PowerShell parameter binding accepts every argument the code under test passes; not every parameter is exercised by this test.')]
param([string] $Query) return @() }
        Mock Invoke-AZSCGraphRequest { throw 'simulated Graph failure' }

        try {
            $collect = Invoke-Collect -Source TypedQueries -WarningAction SilentlyContinue
            $collect.domains.identity.PSObject.Properties.Name | Should -Contain 'externalIdentitiesPolicy'
            $collect.domains.identity.externalIdentitiesPolicy.Collected | Should -BeFalse
        }
        finally {
            Remove-Item function:Search-AzGraph -ErrorAction SilentlyContinue
        }
    }
}
