#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.Synopsis
    Dedicated permission audit for Azure Scout.

.DESCRIPTION
    Runs a standalone permission audit without performing any inventory collection.
    Checks ARM/RBAC access across all visible subscriptions, validates critical Azure
    resource provider registration, and optionally audits Microsoft Graph / Entra ID
    permissions when -IncludeEntraPermissions is specified.

    Outputs colour-coded results to the console (green = OK, yellow = partial/warn,
    red = missing/fail).  Returns a structured object so callers can inspect results
    programmatically or serialize them to JSON.

.PARAMETER IncludeEntraPermissions
    Also audits Microsoft Graph permissions required for Entra ID scanning
    (-Scope All or -Scope EntraOnly).  Requires a Graph-capable token.

.PARAMETER TenantID
    Optional tenant ID override.  Used when connecting to a specific tenant.

.PARAMETER SubscriptionID
    One or more subscription IDs (or names) to scope the audit to.  When provided,
    only these subscriptions are checked for RBAC roles and resource-provider
    registration instead of all accessible subscriptions in the tenant.

.PARAMETER OutputFormat
    If 'Json' or 'Markdown', saves the audit result as a file alongside where the
    Excel report would normally land (the user's AZSC report directory).

.PARAMETER ReportDir
    Directory where the audit file is written when -OutputFormat is Json or Markdown.
    Defaults to the same path that Invoke-AzureScout would use.

.OUTPUTS
    [PSCustomObject] with:
        ArmAccess               [bool]
        GraphAccess             [bool]
        CallerAccount           [string]
        CallerType              [string]
        TenantId                [string]
        ArmDetails              [array]   — per-subscription ARM check objects
        ProviderResults         [array]   — per-subscription provider objects
        GraphDetails            [array]   — Graph permission check objects
        Recommendations         [array]   — actionable remediation strings
        OverallReadiness        [string]  — 'FullARM', 'FullARMAndEntra', 'Partial', 'Insufficient'

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.CATEGORY Management

.NOTES
    Version: 1.0.0
    First Release Date: February 24, 2026
    Authors: AzureScout Contributors
#>
# AB#6893 — Graph permissions whose data is gated by a LICENCE, not by consent.
#
# These are the ones where "grant the permission" is the wrong advice: the endpoint fails on an
# unlicensed tenant however much consent it has. Reporting that as DENIED sends the customer to
# chase a checkbox that cannot fix it, and since most tenants do not carry Entra ID P2, that was
# the COMMON case being reported as an error.
#
# Keyed by permission so the audit can look it up without a special case in the flow.
$Script:ScoutGraphLicensedFeature = @{
    'IdentityRiskyUser.Read.All' = @{
        Product    = 'Microsoft Entra ID P2'
        # subscribedSkus servicePlan names carry the feature, not the SKU marketing name --
        # AAD_PREMIUM_P2 appears in EMS E5 / Microsoft 365 E5 as well as standalone Entra ID P2,
        # so matching the service plan catches every route to the licence.
        SkuPattern = 'AAD_PREMIUM_P2'
    }
}

function Test-ScoutTenantLicence {
    <#
    .SYNOPSIS
        Is a service plan present on any subscribed SKU in this tenant?

    .DESCRIPTION
        AB#6893. Returns $true (present), $false (definitively absent) or $null (could not tell).

        The three-state return is the point. A caller must be able to distinguish "this tenant has
        no P2" from "I could not read the SKUs", because downgrading a genuine permission denial to
        a licensing note on the strength of a failed lookup would hide a real problem. Only an
        explicit $false softens the verdict.

        AB#7100: TenantID must be passed and threaded to the Graph token -- without it the
        subscribedSkus read comes from az CLI's ambient default tenant, not necessarily the
        tenant this audit was invoked against, and can report a licensed tenant as unlicensed.
    #>
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][string]$SkuPattern,
        [string]$TenantID
    )

    try {
        $skus = @(Invoke-AZSCGraphRequest -Uri '/v1.0/subscribedSkus' -SinglePage -TenantID $TenantID)
        if ($skus.Count -eq 0) { return $null }
        foreach ($s in $skus) {
            $plans = $s.PSObject.Properties['servicePlans']
            if (-not $plans -or -not $plans.Value) { continue }
            foreach ($p in @($plans.Value)) {
                $name = $p.PSObject.Properties['servicePlanName']
                if ($name -and "$($name.Value)" -like "*$SkuPattern*") { return $true }
            }
        }
        return $false
    }
    catch {
        # Cannot read subscribedSkus (needs Organization.Read.All, which may itself be denied).
        # Unknown, not absent.
        Write-Verbose "Test-ScoutTenantLicence: could not read subscribedSkus ($($_.Exception.Message)); licence state unknown."
        return $null
    }
}

function Get-ScoutGraphTokenClaim {
    <#
    .SYNOPSIS
        Decode the payload of the Graph bearer token Scout just minted.

    .DESCRIPTION
        AB#7187. No signature verification -- we are reading our own token to learn what the
        STS put in it, not authenticating anything. Returns whether the token is delegated
        (user sign-in: `scp` claim) or an app token (SPN: `roles` claim), and which
        permissions it carries.

        Why this exists: in user-interactive mode the token is delegated and its scope set is
        fixed by the first-party authentication client behind the selected Az context.
        Get-AzAccessToken cannot add an arbitrary Graph scope, so an endpoint whose required
        scope is outside the issued token returns 403 for EVERY user, a Global Administrator
        included. That failure is a property of the sign-in CLIENT/token, not of the caller's
        directory roles, and the audit must say so instead of sending an owner with
        tenant-wide rights to a permissions blade that cannot fix it -- the same anti-pattern
        AB#6893 removed for licence-gated permissions. (Older endpoints keep working because
        the common delegated scope set includes broad Directory.AccessAsUser.All, which newer granular
        surfaces such as authenticationMethodsPolicy and identity/verifiedId do not honour --
        that is why Policy.Read.All probes pass on the same token these two fail on.)
    #>
    [OutputType([object])]
    param([Parameter(Mandatory)][hashtable]$Headers)

    try {
        $jwt = "$($Headers['Authorization'])" -replace '^Bearer\s+', ''
        $payload = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
        switch ($payload.Length % 4) { 2 { $payload += '==' } 3 { $payload += '=' } }
        $claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json

        $scopes = @()
        $isDelegated = $false
        if ($claims.PSObject.Properties['scp'] -and $claims.scp) {
            $isDelegated = $true
            $scopes = @("$($claims.scp)" -split '\s+' | Where-Object { $_ })
        }
        $appRoles = @()
        if ($claims.PSObject.Properties['roles'] -and $claims.roles) { $appRoles = @($claims.roles) }

        [PSCustomObject]@{
            IsDelegated = $isDelegated
            Scopes      = $scopes
            AppRoles    = $appRoles
        }
    }
    catch {
        Write-Verbose "Get-ScoutGraphTokenClaim: could not decode the Graph token payload ($($_.Exception.Message)); scope-claim checks skipped."
        return $null
    }
}

function Invoke-AZSCPermissionAudit {
    [CmdletBinding()]
    param(
        [switch]$IncludeEntraPermissions,
        [string]$TenantID,
        [string[]]$SubscriptionID,
        [ValidateSet('Console', 'Json', 'Markdown', 'AsciiDoc', 'All')]
        [string]$OutputFormat = 'Console',
        [string]$ReportDir
    )

    # ── Helpers ──────────────────────────────────────────────────────────────
    function Write-AuditLine {
        param($Status, $Text)
        switch ($Status) {
            'Pass'  { Write-Host "  [" -NoNewline; Write-Host " OK  " -ForegroundColor Green  -NoNewline; Write-Host "] $Text" }
            'Warn'  { Write-Host "  [" -NoNewline; Write-Host " WARN" -ForegroundColor Yellow -NoNewline; Write-Host "] $Text" }
            'Fail'  { Write-Host "  [" -NoNewline; Write-Host " FAIL" -ForegroundColor Red    -NoNewline; Write-Host "] $Text" }
            'Info'  { Write-Host "  [" -NoNewline; Write-Host " INFO" -ForegroundColor Cyan   -NoNewline; Write-Host "] $Text" }
            'Skip'  { Write-Host "  [" -NoNewline; Write-Host " SKIP" -ForegroundColor Gray   -NoNewline; Write-Host "] $Text" }
        }
    }

    function New-CheckResult {
        param($Check, $Status, $Message, $Remediation = $null)
        [PSCustomObject]@{
            Check       = $Check
            Status      = $Status
            Message     = $Message
            Remediation = $Remediation
        }
    }

    # ── Banner ────────────────────────────────────────────────────────────────
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║        Azure Scout — Permission Audit                      ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    if ($IncludeEntraPermissions.IsPresent) {
        Write-Host '  Scope: ARM/RBAC + Microsoft Graph (Entra ID)' -ForegroundColor Cyan
    } else {
        Write-Host '  Scope: ARM/RBAC only  (add -IncludeEntraPermissions to also audit Entra ID)' -ForegroundColor Gray
    }
    Write-Host ''

    # ── Caller context ────────────────────────────────────────────────────────
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
        Write-Host '  ERROR: No Azure authentication context found. Run Connect-AzAccount first.' -ForegroundColor Red
        return $null
    }

    $callerAccount = $ctx.Account.Id
    $callerType    = $ctx.Account.Type   # User / ServicePrincipal / ManagedServiceIdentity
    $tenantId      = if ($TenantID) { $TenantID } else { $ctx.Tenant.Id }

    Write-Host "  Account : $callerAccount"
    Write-Host "  Type    : $callerType"
    Write-Host "  Tenant  : $tenantId"
    Write-Host ''

    $armDetails      = [System.Collections.Generic.List[PSCustomObject]]::new()
    $providerResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $graphDetails    = [System.Collections.Generic.List[PSCustomObject]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()
    # AB#6765 -- declared here, not inside the Graph branch, because the summary reads it
    # unconditionally and StrictMode makes an unset variable a terminating error.
    $emptyCollectors = [System.Collections.Generic.List[PSCustomObject]]::new()
    $armAccess       = $true
    $graphAccess     = $false   # stays false unless -IncludeEntraPermissions and tests pass

    # ═══════════════════════════════════════════════════════════════════════════
    # SECTION 1 — ARM / RBAC
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host '── ARM / RBAC Checks ────────────────────────────────────────────' -ForegroundColor White
    Write-Host ''

    # 1a — Subscription enumeration
    $subs = $null
    try {
        $subParams = @{ ErrorAction = 'Stop' }
        if ($TenantID) { $subParams['TenantId'] = $TenantID }
        $allSubs = @(Get-AzSubscription @subParams)

        # When -SubscriptionID is specified, scope the audit to only those subscriptions
        if ($SubscriptionID -and $SubscriptionID.Count -gt 0) {
            $subs = @($allSubs | Where-Object { $_.Id -in $SubscriptionID -or $_.Name -in $SubscriptionID })
            if ($subs.Count -eq 0) {
                $r = New-CheckResult -Check 'ARM: Subscription Enumeration' -Status 'Fail' -Message "None of the specified subscription(s) ($($SubscriptionID -join ', ')) were found in the $($allSubs.Count) accessible subscription(s)" -Remediation 'Verify the -SubscriptionID value matches an accessible subscription ID or name.'
                Write-AuditLine -Status Fail -Text $r.Message
                $armAccess = $false
                $recommendations.Add('Verify -SubscriptionID matches an accessible subscription ID or name.')
            }
            else {
                $r = New-CheckResult -Check 'ARM: Subscription Enumeration' -Status 'Pass' -Message "Scoped to $($subs.Count) of $($allSubs.Count) accessible subscription(s)"
                Write-AuditLine -Status Pass -Text $r.Message
            }
        }
        else {
            $subs = $allSubs
            $r = New-CheckResult -Check 'ARM: Subscription Enumeration' -Status 'Pass' -Message "Found $($subs.Count) subscription(s) accessible to this identity"
            Write-AuditLine -Status Pass -Text $r.Message
        }
    }
    catch {
        $armAccess = $false
        $r = New-CheckResult -Check 'ARM: Subscription Enumeration' -Status 'Fail' -Message $_.Exception.Message -Remediation 'Grant the identity at least Reader role on one or more subscriptions.'
        Write-AuditLine -Status Fail -Text $r.Message
        $recommendations.Add("Grant Reader role: New-AzRoleAssignment -ObjectId <principalId> -RoleDefinitionName 'Reader' -Scope '/subscriptions/<subId>'")
    }
    $armDetails.Add($r)

    # 1b — Root Management Group access
    try {
        $mgScope = "/providers/Microsoft.Management/managementGroups/$tenantId"
        $null = @(Get-AzRoleAssignment -Scope $mgScope -ErrorAction Stop) | Select-Object -First 1
        $r = New-CheckResult -Check 'ARM: Root Management Group Access' -Status 'Pass' -Message 'Can read root management group role assignments (broadest scope)'
        Write-AuditLine -Status Pass -Text $r.Message
    }
    catch {
        $r = New-CheckResult -Check 'ARM: Root Management Group Access' -Status 'Warn' -Message "Cannot read root MG role assignments — inventory will run per-subscription instead" -Remediation "Grant Reader at root MG: New-AzRoleAssignment -ObjectId {principalId} -RoleDefinitionName 'Reader' -Scope '/providers/Microsoft.Management/managementGroups/$tenantId'"
        Write-AuditLine -Status Warn -Text $r.Message
    }
    $armDetails.Add($r)

    # 1c — Per-subscription role check
    if ($subs -and $subs.Count -gt 0) {
        Write-Host ''
        Write-Host "  Subscription role summary ($($subs.Count) subscription(s)):" -ForegroundColor White
        Write-Host ''

        # AB#6778. This used to list Security Reader, Monitoring Reader and Cost Management
        # Reader as optional roles, warn on every subscription that lacked them, and emit a
        # New-AzRoleAssignment line telling the operator to grant Security Reader. All three
        # are redundant: Azure `Reader` is `Actions: ["*/read"]` with an empty `NotActions`,
        # and every action Scout calls through those roles is inside that single wildcard.
        #
        # Two of them are worse than merely useless as an ask. Monitoring Reader and Cost
        # Management Reader both carry `Microsoft.Support/*`, which includes support-ticket
        # CREATION -- a write, in a tool sold as read-only. Security Reader carries five IoT
        # Defender `/action` permissions, one of which downloads a password-reset file.
        #
        # Cost data in particular was never gated on Cost Management Reader: it is gated on
        # the EA "AO view charges" / MCA "Azure charges" billing setting, which no RBAC role
        # can grant. Recommending the role was advice that could not work.
        # AB#368 — try/finally, not a scriptblock, so the loop body keeps writing to the
        # enclosing scope's $armAccess/$armDetails/$recommendations while the caller's
        # subscription context is still restored on both the normal and the error path.
        $armLoopContext = Get-AzContext -ErrorAction SilentlyContinue
        try {
            foreach ($sub in $subs) {
                try {
                    $selectedContext = Set-AzContext -Subscription $sub.Id -Tenant $tenantId -ErrorAction Stop
                    if (-not $selectedContext) {
                        throw "Set-AzContext returned no context for subscription '$($sub.Id)'."
                    }

                    # Test the signed-in identity, not the subscription's assignment list. The
                    # latter contains roles held by every principal and can show Reader even when
                    # this caller has no resource read access at all.
                    Get-AzResourceGroup -ErrorAction Stop | Select-Object -First 1 | Out-Null
                    $assignments = @(Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -ErrorAction Stop)

                    $foundRoles = $assignments | Select-Object -ExpandProperty RoleDefinitionName -Unique

                    # AB#7189. 'Reader' used to be matched by NAME, so an account holding Owner
                    # or Contributor -- strict supersets of Reader's */read -- FAILED this check
                    # and was told to go grant Reader it did not need. Accept any role whose
                    # effective actions cover every control-plane read: the built-in supersets
                    # by name, then custom roles by their definition's Actions ('*' or '*/read').
                    # Role names below are explanatory only. Access readiness was established by
                    # the live resource-group read above, under the current signed-in identity.
                    $readSupersets = @('Reader', 'Contributor', 'Owner')
                    $readCapableRole = @($foundRoles | Where-Object { $_ -in $readSupersets }) | Select-Object -First 1
                    if (-not $readCapableRole) {
                        foreach ($roleName in @($foundRoles | Where-Object { $_ -notin $readSupersets })) {
                            try {
                                $def = Get-AzRoleDefinition -Name $roleName -ErrorAction Stop
                                if ($def -and (@($def.Actions) -contains '*' -or @($def.Actions) -contains '*/read')) {
                                    $readCapableRole = $roleName
                                    break
                                }
                            }
                            catch {
                                Write-Verbose "Could not inspect role definition '$roleName': $($_.Exception.Message)"
                            }
                        }
                    }
                    $missingCritical = $false

                    # There is no longer an "optional roles are missing" Warn state: read access
                    # is the whole ARM ask (AB#6778), so a subscription either has it or does not.
                    $status = if ($missingCritical) { 'Fail' } else { 'Pass' }

                    $rolesDisplay = if (-not $readCapableRole) { '✅ ARM read probe' }
                        elseif ($readCapableRole -eq 'Reader') { '✅ Reader' }
                        else { "✅ Reader (via $readCapableRole)" }

                    $subMsg = "[$($sub.Name)] $rolesDisplay"
                    Write-AuditLine -Status $status -Text $subMsg

                    $armDetails.Add([PSCustomObject]@{
                        Check       = "ARM: Subscription [$($sub.Name)]"
                        Status      = $status
                        Message     = $subMsg
                        Remediation = if ($missingCritical) { "Add Reader role on subscription $($sub.Id)" } else { $null }
                    })

                    if ($missingCritical) {
                        $armAccess = $false
                        $recommendations.Add("Add Reader role on '$($sub.Name)': New-AzRoleAssignment -ObjectId {principalId} -RoleDefinitionName 'Reader' -Scope '/subscriptions/$($sub.Id)'")
                    }
                }
                catch {
                    $armAccess = $false
                    $failureMessage = "[$($sub.Name)] Current identity could not prove ARM read access: $($_.Exception.Message)"
                    Write-AuditLine -Status Fail -Text $failureMessage
                    $armDetails.Add([PSCustomObject]@{
                        Check       = "ARM: Subscription [$($sub.Name)]"
                        Status      = 'Fail'
                        Message     = $failureMessage
                        Remediation = "Grant the current identity Reader access on subscription $($sub.Id) or the intended parent scope."
                    })
                    $recommendations.Add("Grant the current identity Reader access on '$($sub.Name)' at subscription or parent scope.")
                }
            }
        }
        finally {
            # Written inline rather than calling the shared Restore-AZSCContext helper:
            # the audit is dot-sourced standalone (by tests, and by callers that do not
            # import the whole module) and must not depend on a sibling file being loaded.
            # Property presence is tested via PSObject.Properties because a bare
            # $ctx.Subscription THROWS under Set-StrictMode when the property is absent,
            # and callers with strict mode in their profile do reach this path.
            $restoreId = $null
            if ($armLoopContext -and $armLoopContext.PSObject.Properties.Name -contains 'Subscription' -and $armLoopContext.Subscription) {
                if ($armLoopContext.Subscription.PSObject.Properties.Name -contains 'Id') {
                    $restoreId = $armLoopContext.Subscription.Id
                }
            }
            if ($restoreId) {
                $restoreParams = @{ Subscription = $restoreId; ErrorAction = 'SilentlyContinue' }
                if ($armLoopContext.PSObject.Properties.Name -contains 'Tenant' -and $armLoopContext.Tenant -and $armLoopContext.Tenant.PSObject.Properties.Name -contains 'Id' -and $armLoopContext.Tenant.Id) {
                    $restoreParams['Tenant'] = $armLoopContext.Tenant.Id
                }
                Set-AzContext @restoreParams | Out-Null
            }
        }
    }

    # ═══════════════════════════════════════════════════════════════════════════
    # SECTION 2 — Resource Provider Registration
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host ''
    Write-Host '── Resource Provider Registration ───────────────────────────────' -ForegroundColor White
    Write-Host ''

    $criticalProviders = [ordered]@{
        'Microsoft.Security'                = 'Microsoft Defender for Cloud'
        'Microsoft.Insights'                = 'Azure Monitor, Application Insights'
        'Microsoft.Maintenance'             = 'Azure Update Manager'
        'Microsoft.DesktopVirtualization'   = 'Azure Virtual Desktop'
        'Microsoft.HybridCompute'           = 'Azure Arc-enabled Servers'
        'Microsoft.AzureStackHCI'           = 'Azure Local (Azure Stack HCI)'
        'Microsoft.MachineLearningServices' = 'Azure Machine Learning / AI Foundry'
        'Microsoft.CognitiveServices'       = 'Azure OpenAI, Cognitive Services, Bot Services'
        'Microsoft.Search'                  = 'Azure AI Search'
        'Microsoft.BotService'              = 'Azure Bot Services'
        'Microsoft.AlertsManagement'        = 'Azure Monitor Smart Alerts'
        'Microsoft.OperationalInsights'     = 'Log Analytics Workspaces'
        'Microsoft.AzureArcData'            = 'Arc-enabled SQL Server / Data Services'
        'Microsoft.Kubernetes'              = 'Arc-enabled Kubernetes'
    }

    # NOTE: wrap in @() — Where-Object/Select-Object collapse a single match to a bare
    # scalar object (not an array). Accessing .Count on that scalar is silently coerced
    # to 1 by PowerShell 7's intrinsic Count/Length member, but THROWS under strict mode
    # on Windows PowerShell 5.1 ("The property 'Count' cannot be found on this object"),
    # since Desktop edition has no such intrinsic. @() guarantees a real array here.
    $targetSubs = @(if ($subs) { $subs | Where-Object { $_.State -eq 'Enabled' } | Select-Object -First 3 } else { @() })

    if ($targetSubs.Count -gt 0) {
        $checkSub = $targetSubs[0]

        # AB#368 — the provider probe borrows a subscription context; the audit must not
        # leave the caller parked in it once the section is done.
        $providerLoopContext = Get-AzContext -ErrorAction SilentlyContinue
        try {
            $providerContext = Set-AzContext -Subscription $checkSub.Id -Tenant $tenantId -ErrorAction Stop
            if (-not $providerContext) {
                throw "Set-AzContext returned no context for subscription '$($checkSub.Id)'."
            }
            Write-Host "  Checking against subscription: $($checkSub.Name)" -ForegroundColor Gray
            Write-Host "  NOTE: Not all providers need to be registered. Unregistered providers are" -ForegroundColor DarkGray
            Write-Host "        expected — they simply mean that service is not deployed here." -ForegroundColor DarkGray
            Write-Host "        The scan will complete successfully; those modules will be skipped." -ForegroundColor DarkGray
            Write-Host ''

            foreach ($kvp in $criticalProviders.GetEnumerator()) {
                $provider = $kvp.Key
                $purpose  = $kvp.Value
                try {
                    $reg = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
                    $state = ($reg | Select-Object -ExpandProperty RegistrationState -First 1)
                    $status = if ($state -eq 'Registered') { 'Pass' } elseif ($state -in 'Registering','Unregistering') { 'Warn' } else { 'Info' }
                    $skipText = if ($status -eq 'Info') { " (modules for this service will be skipped)" } else { '' }
                    Write-AuditLine -Status $status -Text "$provider  [$state]  — $purpose$skipText"

                    if ($status -ne 'Pass') {
                        $recommendations.Add("Register provider: Register-AzResourceProvider -ProviderNamespace '$provider'")
                    }
                }
                catch {
                    $state = 'Unknown'
                    $status = 'Warn'
                    Write-AuditLine -Status Warn -Text "$provider  [Unknown — cannot read]  — $purpose"
                }

                $providerResults.Add([PSCustomObject]@{
                    SubscriptionId   = $checkSub.Id
                    SubscriptionName = $checkSub.Name
                    Provider         = $provider
                    Purpose          = $purpose
                    RegistrationState = $state
                    Status           = $status
                })
            }
        }
        finally {
            $restoreId = $null
            if ($providerLoopContext -and $providerLoopContext.PSObject.Properties.Name -contains 'Subscription' -and $providerLoopContext.Subscription) {
                if ($providerLoopContext.Subscription.PSObject.Properties.Name -contains 'Id') {
                    $restoreId = $providerLoopContext.Subscription.Id
                }
            }
            if ($restoreId) {
                $restoreParams = @{ Subscription = $restoreId; ErrorAction = 'SilentlyContinue' }
                if ($providerLoopContext.PSObject.Properties.Name -contains 'Tenant' -and $providerLoopContext.Tenant -and $providerLoopContext.Tenant.PSObject.Properties.Name -contains 'Id' -and $providerLoopContext.Tenant.Id) {
                    $restoreParams['Tenant'] = $providerLoopContext.Tenant.Id
                }
                Set-AzContext @restoreParams | Out-Null
            }
        }
    }
    else {
        Write-AuditLine -Status Skip -Text 'No enabled subscriptions available — skipping provider check'
    }

    # ═══════════════════════════════════════════════════════════════════════════
    # SECTION 3 — Microsoft Graph / Entra ID (optional)
    # ═══════════════════════════════════════════════════════════════════════════
    if ($IncludeEntraPermissions.IsPresent) {
        Write-Host ''
        Write-Host '── Microsoft Graph / Entra ID Checks ───────────────────────────' -ForegroundColor White
        Write-Host ''

        $graphToken = $null
        try {
            $graphToken = Get-AZSCGraphToken -TenantID $tenantId
            Write-AuditLine -Status Pass -Text 'Microsoft Graph token acquired successfully'
        }
        catch {
            Write-AuditLine -Status Fail -Text "Cannot acquire Microsoft Graph token: $($_.Exception.Message)"
            $graphDetails.Add(( New-CheckResult -Check 'Graph: Token Acquisition' -Status 'Fail' -Message $_.Exception.Message -Remediation "Ensure the identity has Graph API permissions. For SPNs: grant app permissions in Entra ID app registration. For users: ensure Directory Readers or Global Reader directory role." ))
            $recommendations.Add('Grant Graph permissions — in Entra ID portal: App Registrations > API Permissions > Microsoft Graph > Directory.Read.All (application permission, requires admin consent)')
        }

        if ($graphToken) {
            # AB#6765 -- the checks are DERIVED from the query catalog Scout actually runs and
            # from the collector manifests that consume it, not from a second hand-maintained
            # list. The old list had nine entries and a hardcoded four of them were "critical";
            # a denial outside those four left the run reporting READY with an empty worksheet
            # behind it, and 'Graph: Audit Logs Read' was checked at all despite no collector
            # reading sign-in logs.
            #
            # Loaded defensively, for the same reason the context restore below is written
            # inline rather than through the shared helper: this file is dot-sourced standalone
            # by tests and by callers that do not import the whole module, so it must not
            # assume a sibling has already been loaded.
            if (-not (Get-Command Get-ScoutEntraQueryCatalog -ErrorAction SilentlyContinue)) {
                . (Join-Path $PSScriptRoot 'collect/Get-ScoutEntraQueryCatalog.ps1')
            }
            if (-not (Get-Command Get-ScoutGraphPermissionImpact -ErrorAction SilentlyContinue)) {
                . (Join-Path $PSScriptRoot 'Get-ScoutGraphPermissionImpact.ps1')
            }

            $graphImpact = @(Get-ScoutGraphPermissionImpact)

            # AB#7187 -- decoded once for the whole probe loop; $null when undecodable, and
            # every use below is guarded so an undecodable token degrades to the old behaviour
            # (a plain DENIED) rather than a new failure mode.
            $tokenClaim = Get-ScoutGraphTokenClaim -Headers $graphToken

            $graphAccess = $true

            foreach ($impact in $graphImpact) {
                $checkName  = "Graph: $($impact.Permission)"
                $probe      = @(Get-ScoutEntraQueryCatalog | Where-Object { $_.Permission -eq $impact.Permission })[0]
                $purpose    = ($impact.Queries -join ', ')

                if (-not $impact.IsConsumed) {
                    # A permission no collector consumes is not worth failing, warning, or even
                    # asking for. Say so rather than quietly probing it every run.
                    $r = New-CheckResult -Check $checkName -Status 'Warn' -Message "$($impact.Permission) — queried ($purpose) but NO collector reads the result. Do not grant it." -Remediation "Remove '$($impact.Permission)' from the access request — nothing consumes it."
                    Write-AuditLine -Status Warn -Text "$checkName — queried but unused by every collector"
                    $graphDetails.Add($r)
                    continue
                }

                try {
                    $null = Invoke-AZSCGraphRequest -Uri $probe.Uri -SinglePage -TenantID $tenantId
                    $r = New-CheckResult -Check $checkName -Status 'Pass' -Message "$($impact.Permission) — $purpose ($($impact.CollectorCount) collectors)"
                    Write-AuditLine -Status Pass -Text "$checkName  [$($impact.CollectorCount) collectors]"
                }
                catch {
                    # AB#6893. A LICENSED-FEATURE permission is not a misconfiguration. Identity
                    # Protection is Entra ID P2; on a tenant without P2 the risky-users endpoint
                    # fails no matter how much consent is granted, and reporting that as
                    # "DENIED - grant this permission" sends the customer to chase a checkbox
                    # that will not fix it. Most tenants do not have P2, so this was the common
                    # case being reported as an error.
                    #
                    # Scout already collects subscribedSkus, so the licence state is knowable
                    # rather than guessable -- and when it is not knowable this stays a Fail,
                    # because silently downgrading a real denial would be the worse error.
                    if ($Script:ScoutGraphLicensedFeature.ContainsKey($impact.Permission)) {
                        $req = $Script:ScoutGraphLicensedFeature[$impact.Permission]
                        $licensed = Test-ScoutTenantLicence -SkuPattern $req.SkuPattern -TenantID $tenantId
                        if ($licensed -eq $false) {
                            foreach ($c in $impact.Collectors) {
                                $emptyCollectors.Add([PSCustomObject]@{
                                        Collector  = $c
                                        Reason     = "Not licensed — requires $($req.Product)"
                                        Permission = $impact.Permission
                                    })
                            }
                            $r = New-CheckResult -Check $checkName -Status 'Warn' -Message "NOT LICENSED — $($impact.Permission) ($purpose) requires $($req.Product), which this tenant does not have. $($impact.CollectorCount) collector(s) will be empty and are reported as Not assessed: $($impact.Collectors -join ', ')" -Remediation "No action needed unless you intend to license $($req.Product). Granting the permission alone will not populate these collectors."
                            Write-AuditLine -Status Warn -Text "$checkName — not licensed ($($req.Product)); reported as Not assessed"
                            $graphDetails.Add($r)
                            continue
                        }
                    }

                    # AB#7187. A delegated token that does not CARRY the required scope cannot
                    # pass this probe no matter which directory roles the signed-in user holds:
                    # user-mode tokens carry a fixed pre-authorized scope set that
                    # Get-AzAccessToken cannot extend, so "grant the permission" is advice that cannot work
                    # -- a Global Administrator hits the same 403. Report the truth instead:
                    # this surface needs a service principal, or it stays Not assessed.
                    if ($tokenClaim -and $tokenClaim.IsDelegated -and $tokenClaim.Scopes -notcontains $impact.Permission) {
                        foreach ($c in $impact.Collectors) {
                            $emptyCollectors.Add([PSCustomObject]@{
                                    Collector  = $c
                                    Reason     = "Unavailable with current delegated sign-in — needs '$($impact.Permission)' via a service principal"
                                    Permission = $impact.Permission
                                })
                        }
                        $r = New-CheckResult -Check $checkName -Status 'Warn' -Message "UNAVAILABLE WITH CURRENT DELEGATED SIGN-IN — $($impact.Permission) ($purpose) is not among the delegated scopes carried by the selected Az context token, and Get-AzAccessToken cannot add it, so this fails regardless of directory roles. $($impact.CollectorCount) collector(s) will be empty and are reported as Not assessed: $($impact.Collectors -join ', ')" -Remediation "Run Scout with a service principal (-AppId with -Secret or -CertificatePath) granted the '$($impact.Permission)' application permission with admin consent. Granting directory roles to this user account will not help because a directory role cannot add a missing OAuth scope."
                        Write-AuditLine -Status Warn -Text "$checkName — unavailable with current delegated sign-in; reported as Not assessed"
                        $graphDetails.Add($r)
                        continue
                    }

                    # Criticality is derived: this permission has consumers, so denying it
                    # empties worksheets, so the run is not READY. There is no list to edit.
                    $graphAccess = $false
                    foreach ($c in $impact.Collectors) {
                        $emptyCollectors.Add([PSCustomObject]@{
                            Collector  = $c
                            Reason     = 'Graph permission denied'
                            Permission = $impact.Permission
                        })
                    }
                    # AB#7187 -- the Enterprise Applications blade only exists for SPNs; telling
                    # a signed-in USER to go there was a dead end. A delegated token that DOES
                    # carry the scope but still gets 403 is a directory-role problem.
                    $deniedRemediation = if ($tokenClaim -and $tokenClaim.IsDelegated) {
                        "The signed-in user's directory roles do not permit this read. Assign a role that covers it (for authentication-method and Verified ID surfaces: Authentication Policy Administrator, or Global Reader), or run Scout as a service principal granted the '$($impact.Permission)' application permission."
                    } else {
                        "Grant '$($impact.Permission)' in Entra ID > Enterprise Applications > API Permissions"
                    }
                    $r = New-CheckResult -Check $checkName -Status 'Fail' -Message "DENIED — $($impact.Permission) ($purpose). $($impact.CollectorCount) collectors will be empty: $($impact.Collectors -join ', ')" -Remediation $deniedRemediation
                    Write-AuditLine -Status Fail -Text "$checkName — DENIED; $($impact.CollectorCount) collectors will be empty"
                    # AB#6765 -- this used to be a coloured Write-Host and nothing else, so a
                    # denied permission never reached the warning stream and never reached the
                    # run's error count. An automated caller could not tell.
                    Write-Warning "[AzureScout] Graph permission '$($impact.Permission)' is DENIED. These collectors will produce no data: $($impact.Collectors -join ', ')."
                    if ($tokenClaim -and $tokenClaim.IsDelegated) {
                        $recommendations.Add("Assign a directory role covering '$($impact.Permission)' (or run as a service principal with that application permission) — without it these collectors are empty: $($impact.Collectors -join ', ')")
                    } else {
                        $recommendations.Add("Grant Graph permission '$($impact.Permission)' — without it these collectors are empty: $($impact.Collectors -join ', ')")
                    }
                }
                $graphDetails.Add($r)
            }
        }
    }
    else {
        $graphAccess = $null   # not checked
    }

    # ═══════════════════════════════════════════════════════════════════════════
    # SECTION 4 — Summary & Recommendations
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host ''
    Write-Host '── Summary ──────────────────────────────────────────────────────' -ForegroundColor White
    Write-Host ''

    $overallReadiness = switch ($true) {
        { -not $armAccess }                             { 'Insufficient' }
        { $armAccess -and $graphAccess -eq $true }      { 'FullARMAndEntra' }
        { $armAccess -and $graphAccess -eq $false }     { 'Partial' }
        { $armAccess -and $null -eq $graphAccess }      { 'FullARM' }
        default                                         { 'Unknown' }
    }

    $readinessColor = switch ($overallReadiness) {
        'FullARMAndEntra'  { 'Green'  }
        'FullARM'          { 'Green'  }
        'Partial'          { 'Yellow' }
        'Insufficient'     { 'Red'    }
        default            { 'Gray'   }
    }

    $readinessText = switch ($overallReadiness) {
        'FullARMAndEntra'  { 'READY — Full ARM + Entra ID scan supported' }
        'FullARM'          { 'READY — ARM-only scan supported  (use -Scope ArmOnly)' }
        'Partial'          { 'PARTIAL — ARM accessible, but some Graph permissions are missing (use -Scope ArmOnly for full coverage)' }
        'Insufficient'     { 'INSUFFICIENT — ARM access is missing on one or more subscriptions' }
        default            { 'UNKNOWN' }
    }

    Write-Host "  Overall Readiness: " -NoNewline
    Write-Host $readinessText -ForegroundColor $readinessColor
    Write-Host ''

    # ── AB#6765: the impact table ─────────────────────────────────────────────
    # The verdict word above is kept because scripts read $result.OverallReadiness, but it is no
    # longer the answer. This table is: it names every collector that will produce no data and
    # the permission each one needs. A word can be wrong in a way a list cannot -- "READY"
    # printed over four empty worksheets is exactly the failure this replaces.
    if ($emptyCollectors -and $emptyCollectors.Count -gt 0) {
        Write-Host "  Collectors that will produce NO data ($($emptyCollectors.Count)):" -ForegroundColor Yellow
        Write-Host ''
        foreach ($row in ($emptyCollectors | Sort-Object Collector)) {
            # AB#7189 follow-up: the CLI-sign-in reason already names the permission; appending
                    # ' — needs X' repeated it. Only append when the reason does not carry it.
                    $line = if ($row.Reason -like ('*' + $row.Permission + '*')) { '    {0,-40} {1}' -f $row.Collector, $row.Reason }
                            else { '    {0,-40} {1} — needs {2}' -f $row.Collector, $row.Reason, $row.Permission }
                    Write-Host $line -ForegroundColor Yellow
        }
        Write-Host ''
    }
    elseif ($null -ne $graphAccess) {
        Write-Host '  Every Entra collector has the permission it needs.' -ForegroundColor Green
        Write-Host ''
    }

    # @() guard: when $recommendations is empty, piping it through Sort-Object -Unique
    # emits nothing at all, so the expression evaluates to $null — and $null.Count
    # throws under strict mode on every PowerShell edition/version, not just 5.1.
    $recCount = @($recommendations | Sort-Object -Unique).Count
    if ($recCount -gt 0) {
        Write-Host "  Recommendations ($recCount):" -ForegroundColor Yellow
        Write-Host ''
        $recommendations | Sort-Object -Unique | ForEach-Object {
            Write-Host "    • $_" -ForegroundColor Yellow
        }
        Write-Host ''
    }
    else {
        Write-Host '  No remediation actions required.' -ForegroundColor Green
        Write-Host ''
    }

    # Suggested command
    Write-Host '  Suggested Invoke-AzureScout command:' -ForegroundColor Cyan
    $scopeSuggestion = if ($overallReadiness -eq 'FullARMAndEntra') { '-Scope All' } else { '-Scope ArmOnly' }
    Write-Host "    Invoke-AzureScout -TenantID $tenantId $scopeSuggestion" -ForegroundColor Cyan
    Write-Host ''

    # ── Build result object ────────────────────────────────────────────────────
    $result = [PSCustomObject]@{
        ArmAccess        = $armAccess
        GraphAccess      = $graphAccess
        CallerAccount    = $callerAccount
        CallerType       = $callerType
        TenantId         = $tenantId
        ArmDetails       = $armDetails.ToArray()
        ProviderResults  = $providerResults.ToArray()
        GraphDetails     = $graphDetails.ToArray()
        Recommendations  = @($recommendations | Sort-Object -Unique)
        # AB#6765 -- the per-collector impact, so an automated caller gets the same answer the
        # console table shows instead of having to interpret OverallReadiness.
        EmptyCollectors  = @($emptyCollectors | Sort-Object Collector)
        OverallReadiness = $overallReadiness
        AuditTimestamp   = (Get-Date -Format 'o')
    }

    # ── Optional file output ───────────────────────────────────────────────────
    $reportPath = $null
    $auditFileStem = $null
    if ($OutputFormat -ne 'Console') {
        $reportPath = if ($ReportDir) { $ReportDir } else {
            $rp = Set-AZSCReportPath -ReportDir $null
            $rp.DefaultPath
        }
        if (-not (Test-Path -LiteralPath $reportPath)) { New-Item -ItemType Directory -Path $reportPath -Force | Out-Null }
        $auditFileStem = 'PermissionAudit_{0}_{1}' -f (Get-Date -Format 'yyyy-MM-dd_HHmmss_fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    }

    if ($OutputFormat -in 'Json', 'All') {
        $jsonFile = Join-Path $reportPath "$auditFileStem.json"
        $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        Write-Host "  Audit saved → $jsonFile" -ForegroundColor Cyan
    }

    if ($OutputFormat -in 'Markdown', 'All') {
        $mdFile = Join-Path $reportPath "$auditFileStem.md"

        $mdLines = [System.Collections.Generic.List[string]]::new()
        $mdLines.Add('# Azure Scout - Permission Audit Report')
        $mdLines.Add("")
        $mdLines.Add("| Field | Value |")
        $mdLines.Add("|-------|-------|")
        $mdLines.Add("| Generated | " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " |")
        $mdLines.Add("| Account | $callerAccount |")
        $mdLines.Add("| Account Type | $callerType |")
        $mdLines.Add("| Tenant ID | $tenantId |")
        $mdLines.Add("| Overall Readiness | **$overallReadiness** |")
        $mdLines.Add("")
        $mdLines.Add("## ARM / RBAC Checks")
        $mdLines.Add("")
        $mdLines.Add("| Check | Status | Message | Remediation |")
        $mdLines.Add("|-------|--------|---------|-------------|")
        foreach ($d in $armDetails) {
            $icon = switch ($d.Status) { 'Pass' { '✅' } 'Warn' { '⚠️' } 'Fail' { '❌' } default { 'ℹ️' } }
            $mdLines.Add("| $($d.Check) | $icon $($d.Status) | $($d.Message -replace '\|','&#124;') | $($d.Remediation -replace '\|','&#124;') |")
        }
        $mdLines.Add("")
        $mdLines.Add("## Resource Provider Registration")
        $mdLines.Add("")
        $mdLines.Add("| Provider | Purpose | State | Status |")
        $mdLines.Add("|----------|---------|-------|--------|")
        foreach ($p in $providerResults) {
            $icon = switch ($p.Status) { 'Pass' { '✅' } 'Warn' { '⚠️' } 'Fail' { '❌' } default { 'ℹ️' } }
            $mdLines.Add("| $($p.Provider) | $($p.Purpose) | $($p.RegistrationState) | $icon |")
        }
        if ($graphDetails.Count -gt 0) {
            $mdLines.Add("")
            $mdLines.Add("## Microsoft Graph / Entra ID Permissions")
            $mdLines.Add("")
            $mdLines.Add("| Check | Status | Details |")
            $mdLines.Add("|-------|--------|---------|")
            foreach ($g in $graphDetails) {
                $icon = switch ($g.Status) { 'Pass' { '✅' } 'Warn' { '⚠️' } 'Fail' { '❌' } default { 'ℹ️' } }
                $mdLines.Add("| $($g.Check) | $icon $($g.Status) | $($g.Message -replace '\|','&#124;') |")
            }
        }
        if ($recommendations.Count -gt 0) {
            $mdLines.Add("")
            $mdLines.Add("## Recommendations")
            $mdLines.Add("")
            $recommendations | Sort-Object -Unique | ForEach-Object { $mdLines.Add("- ``$_``") }
        }
        $mdLines | Out-File -FilePath $mdFile -Encoding UTF8
        Write-Host "  Audit saved → $mdFile" -ForegroundColor Cyan
    }

    if ($OutputFormat -in 'AsciiDoc', 'All') {
        $adocFile = Join-Path $reportPath "$auditFileStem.adoc"

        $adocLines = [System.Collections.Generic.List[string]]::new()
        $adocLines.Add('= Azure Scout — Permission Audit Report')
        $adocLines.Add(':toc: left')
        $adocLines.Add(':toclevels: 2')
        $adocLines.Add(':icons: font')
        $adocLines.Add(':source-highlighter: highlight.js')
        $adocLines.Add('')
        $adocLines.Add('[%autowidth.stretch]')
        $adocLines.Add('|===')
        $adocLines.Add('| Field | Value')
        $adocLines.Add('')
        $adocLines.Add("| Generated | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $adocLines.Add("| Account | $callerAccount")
        $adocLines.Add("| Account Type | $callerType")
        $adocLines.Add("| Tenant ID | $tenantId")
        $adocLines.Add("| Overall Readiness | *$overallReadiness*")
        $adocLines.Add('|===')
        $adocLines.Add('')
        $adocLines.Add('== ARM / RBAC Checks')
        $adocLines.Add('')
        $adocLines.Add('[%autowidth.stretch,cols="2,1,3,3"]')
        $adocLines.Add('|===')
        $adocLines.Add('| Check | Status | Message | Remediation')
        $adocLines.Add('')
        foreach ($d in $armDetails) {
            $icon = switch ($d.Status) { 'Pass' { 'icon:check-circle[role=green]' } 'Warn' { 'icon:exclamation-triangle[role=yellow]' } 'Fail' { 'icon:times-circle[role=red]' } default { 'icon:info-circle[]' } }
            $adocLines.Add("| $($d.Check) | $icon $($d.Status) | $($d.Message) | $($d.Remediation)")
            $adocLines.Add('')
        }
        $adocLines.Add('|===')
        $adocLines.Add('')
        $adocLines.Add('== Resource Provider Registration')
        $adocLines.Add('')
        $adocLines.Add('[%autowidth.stretch,cols="2,2,1,1"]')
        $adocLines.Add('|===')
        $adocLines.Add('| Provider | Purpose | State | Status')
        $adocLines.Add('')
        foreach ($p in $providerResults) {
            $stateIcon = switch ($p.Status) { 'Pass' { 'icon:check-circle[role=green]' } 'Warn' { 'icon:exclamation-triangle[role=yellow]' } 'Fail' { 'icon:times-circle[role=red]' } default { 'icon:info-circle[]' } }
            $adocLines.Add("| $($p.Provider) | $($p.Purpose) | $($p.RegistrationState) | $stateIcon")
            $adocLines.Add('')
        }
        $adocLines.Add('|===')
        if ($graphDetails.Count -gt 0) {
            $adocLines.Add('')
            $adocLines.Add('== Microsoft Graph / Entra ID Permissions')
            $adocLines.Add('')
            $adocLines.Add('[%autowidth.stretch,cols="2,1,3"]')
            $adocLines.Add('|===')
            $adocLines.Add('| Check | Status | Details')
            $adocLines.Add('')
            foreach ($g in $graphDetails) {
                $gIcon = switch ($g.Status) { 'Pass' { 'icon:check-circle[role=green]' } 'Warn' { 'icon:exclamation-triangle[role=yellow]' } 'Fail' { 'icon:times-circle[role=red]' } default { 'icon:info-circle[]' } }
                $adocLines.Add("| $($g.Check) | $gIcon $($g.Status) | $($g.Message)")
                $adocLines.Add('')
            }
            $adocLines.Add('|===')
        }
        if ($recommendations.Count -gt 0) {
            $adocLines.Add('')
            $adocLines.Add('== Recommendations')
            $adocLines.Add('')
            $recommendations | Sort-Object -Unique | ForEach-Object { $adocLines.Add("[source,powershell]`n----`n$_`n----`n") }
        }
        $adocLines | Out-File -FilePath $adocFile -Encoding UTF8
        Write-Host "  Audit saved → $adocFile" -ForegroundColor Cyan
    }

    return $result
}
