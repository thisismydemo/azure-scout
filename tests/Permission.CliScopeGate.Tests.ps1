#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
    AB#7187 — user-mode Graph probes must not report a scope the delegated token cannot acquire as
    "DENIED — grant it". A delegated token's scp claim is fixed by the CLI client, so a 403 on a
    scope outside that claim hits every user (Global Administrator included) and no directory-role
    grant fixes it; the audit reports it UNAVAILABLE WITH CURRENT DELEGATED SIGN-IN instead.

    The decoder is exercised for real with hand-built unsigned JWTs; the branch placement inside
    Invoke-AZSCPermissionAudit's probe loop is pinned by source position, matching this repo's
    established style for audit-flow assertions (a live probe needs a real Graph 403).
#>

BeforeAll {
    $script:Root = Split-Path $PSScriptRoot -Parent
    . (Join-Path -Path $script:Root -ChildPath 'src' -AdditionalChildPath 'Invoke-AZTIPermissionAudit.ps1')

    function New-FakeJwtHeaders {
                [Diagnostics.CodeAnalysis.SuppressMessage('PSUseSingularNouns', '', Justification = 'Name matches the real collector/API/fixture noun (often already plural in the product surface, e.g. ManagementGroups); renaming would break the shadow/mocked signature or the fixture-name convention used across this suite.')]
param([hashtable]$Claims)
        $b64url = {
            param($obj)
            [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        }
        $header  = & $b64url @{ alg = 'none' }
        $payload = & $b64url $Claims
        @{ 'Authorization' = "Bearer $header.$payload.fakesig"; 'Content-Type' = 'application/json' }
    }
}

Describe 'Get-ScoutGraphTokenClaim — decodes what the STS actually issued' {

    It 'reads a delegated token: IsDelegated true and scp split into individual scopes' {
        $h = New-FakeJwtHeaders @{ scp = 'User.Read.All Directory.AccessAsUser.All Policy.Read.All'; upn = 'user@contoso.com' }
        $claim = Get-ScoutGraphTokenClaim -Headers $h
        $claim | Should -Not -BeNullOrEmpty
        $claim.IsDelegated | Should -BeTrue
        @($claim.Scopes) | Should -Contain 'Directory.AccessAsUser.All'
        @($claim.Scopes) | Should -Contain 'Policy.Read.All'
        @($claim.Scopes) | Should -Not -Contain 'Policy.Read.AuthenticationMethod'
    }

    It 'reads an app token: IsDelegated false, roles surfaced as AppRoles' {
        $h = New-FakeJwtHeaders @{ roles = @('Policy.Read.AuthenticationMethod', 'User.Read.All'); appid = '00000000-0000-0000-0000-000000000001' }
        $claim = Get-ScoutGraphTokenClaim -Headers $h
        $claim | Should -Not -BeNullOrEmpty
        $claim.IsDelegated | Should -BeFalse
        @($claim.AppRoles) | Should -Contain 'Policy.Read.AuthenticationMethod'
    }

    It 'survives base64url payloads that need padding (length % 4 = 2 and 3)' {
        # Claim values sized to force each padding branch — the decoder must not throw on either.
        foreach ($filler in @('x', 'xx', 'xxx', 'xxxx') ) {
            $h = New-FakeJwtHeaders @{ scp = "User.Read.All $filler" }
            { Get-ScoutGraphTokenClaim -Headers $h } | Should -Not -Throw
        }
    }

    It 'returns $null (not a throw) for a token that is not a JWT at all' {
        $claim = Get-ScoutGraphTokenClaim -Headers @{ 'Authorization' = 'Bearer not-a-jwt' } -Verbose:$false
        $claim | Should -BeNullOrEmpty
    }
}

Describe 'AB#7187 — probe-loop branch placement (source analysis)' {

    BeforeAll {
        $script:Source = Get-Content -Raw (Join-Path -Path $script:Root -ChildPath 'src' -AdditionalChildPath 'Invoke-AZTIPermissionAudit.ps1')

        function Get-AuditSourceIndex {
            param([string]$Pattern)
            $m = [regex]::Match($script:Source, $Pattern)
            $m.Success | Should -BeTrue -Because "expected to find '$Pattern' in Invoke-AZTIPermissionAudit.ps1"
            return $m.Index
        }
    }

    It 'decodes the token claim once, before the probe loop' {
        $decodeIdx = Get-AuditSourceIndex '\$tokenClaim = Get-ScoutGraphTokenClaim -Headers \$graphToken'
        $loopIdx   = Get-AuditSourceIndex 'foreach \(\$impact in \$graphImpact\)'
        $decodeIdx | Should -BeLessThan $loopIdx
    }

    It 'checks the licence gate before the delegated-scope gate (a missing licence is the deeper truth)' {
        $licenceIdx  = Get-AuditSourceIndex 'Test-ScoutTenantLicence -SkuPattern \$req\.SkuPattern'
        $cliScopeIdx = Get-AuditSourceIndex '\$tokenClaim\.Scopes -notcontains \$impact\.Permission'
        $licenceIdx | Should -BeLessThan $cliScopeIdx
    }

    It 'reports the delegated-scope case as a Warn before the generic DENIED' {
        $cliVerdictIdx = Get-AuditSourceIndex 'UNAVAILABLE WITH CURRENT DELEGATED SIGN-IN'
        $deniedIdx     = Get-AuditSourceIndex '\$deniedRemediation = if'
        $cliVerdictIdx | Should -BeLessThan $deniedIdx
    }

    It 'the delegated-scope remediation sends the operator to a service principal, never to a role or the Enterprise Applications blade' {
        $m = [regex]::Match($script:Source, "UNAVAILABLE WITH CURRENT DELEGATED SIGN-IN[\s\S]{0,1000}?Write-AuditLine")
        $m.Success | Should -BeTrue
        $m.Value | Should -Match 'service principal'
        $m.Value | Should -Match 'will not help'
        $m.Value | Should -Not -Match 'Enterprise Applications'
    }

    It 'the genuine-DENIED remediation for a DELEGATED token names the directory-role path, not the Enterprise Applications blade' {
        $m = [regex]::Match($script:Source, '\$deniedRemediation = if \(\$tokenClaim -and \$tokenClaim\.IsDelegated\) \{\s*"([^"]+)"')
        $m.Success | Should -BeTrue -Because 'the DENIED remediation must branch on token type'
        $m.Groups[1].Value | Should -Match 'directory roles'
        $m.Groups[1].Value | Should -Match 'Authentication Policy Administrator'
        $m.Groups[1].Value | Should -Not -Match 'Enterprise Applications'
    }

    It 'keeps the Enterprise Applications advice for app (SPN) tokens — that path was never wrong' {
        $m = [regex]::Match($script:Source, '\$deniedRemediation = if [\s\S]{0,1200}?else \{\s*"([^"]+)"')
        $m.Success | Should -BeTrue
        $m.Groups[1].Value | Should -Match 'Enterprise Applications'
    }
}
