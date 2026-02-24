<#
.Synopsis
    Dedicated permission audit for Azure Tenant Inventory.

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

.PARAMETER OutputFormat
    If 'Json' or 'Markdown', saves the audit result as a file alongside where the
    Excel report would normally land (the user's AZTI report directory).

.PARAMETER ReportDir
    Directory where the audit file is written when -OutputFormat is Json or Markdown.
    Defaults to the same path that Invoke-AzureTenantInventory would use.

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
    https://github.com/thisismydemo/azure-inventory

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.CATEGORY Management

.NOTES
    Version: 1.0.0
    First Release Date: February 24, 2026
    Authors: Product Technology Team
#>
function Invoke-AZTIPermissionAudit {
    [CmdletBinding()]
    param(
        [switch]$IncludeEntraPermissions,
        [string]$TenantID,
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
    Write-Host '║        Azure Tenant Inventory — Permission Audit             ║' -ForegroundColor Cyan
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
        $subs = @(Get-AzSubscription @subParams)
        $r = New-CheckResult 'ARM: Subscription Enumeration' 'Pass' "Found $($subs.Count) subscription(s) accessible to this identity"
        Write-AuditLine -Status Pass -Text $r.Message
    }
    catch {
        $armAccess = $false
        $r = New-CheckResult 'ARM: Subscription Enumeration' 'Fail' $_.Exception.Message `
            'Grant the identity at least Reader role on one or more subscriptions.'
        Write-AuditLine -Status Fail -Text $r.Message
        $recommendations.Add("Grant Reader role: New-AzRoleAssignment -ObjectId <principalId> -RoleDefinitionName 'Reader' -Scope '/subscriptions/<subId>'")
    }
    $armDetails.Add($r)

    # 1b — Root Management Group access
    try {
        $mgScope = "/providers/Microsoft.Management/managementGroups/$tenantId"
        $mgAssign = @(Get-AzRoleAssignment -Scope $mgScope -ErrorAction Stop) | Select-Object -First 1
        $r = New-CheckResult 'ARM: Root Management Group Access' 'Pass' 'Can read root management group role assignments (broadest scope)'
        Write-AuditLine -Status Pass -Text $r.Message
    }
    catch {
        $r = New-CheckResult 'ARM: Root Management Group Access' 'Warn' `
            "Cannot read root MG role assignments — inventory will run per-subscription instead" `
            "Grant Reader at root MG: New-AzRoleAssignment -ObjectId {principalId} -RoleDefinitionName 'Reader' -Scope '/providers/Microsoft.Management/managementGroups/$tenantId'"
        Write-AuditLine -Status Warn -Text $r.Message
    }
    $armDetails.Add($r)

    # 1c — Per-subscription role check
    if ($subs -and $subs.Count -gt 0) {
        Write-Host ''
        Write-Host "  Subscription role summary ($($subs.Count) subscription(s)):" -ForegroundColor White
        Write-Host ''

        $requiredRoles = @{
            'Reader'                   = 'Core inventory (required)'
            'Security Reader'          = 'Microsoft Defender for Cloud'
            'Monitoring Reader'        = 'Azure Monitor resources'
            'Cost Management Reader'   = 'Cost Management / Advisor cost recommendations'
        }

        foreach ($sub in $subs) {
            try {
                Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue | Out-Null
                $assignments = @(Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -ErrorAction Stop)

                $foundRoles = $assignments | Select-Object -ExpandProperty RoleDefinitionName -Unique
                $missingCritical = $requiredRoles.Keys | Where-Object { $_ -eq 'Reader' -and $_ -notin $foundRoles }
                $missingOptional = $requiredRoles.Keys | Where-Object { $_ -ne 'Reader'  -and $_ -notin $foundRoles }

                $status = if ($missingCritical) { 'Fail' } elseif ($missingOptional) { 'Warn' } else { 'Pass' }

                $rolesDisplay = ($requiredRoles.Keys | ForEach-Object {
                    $emoji = if ($_ -in $foundRoles) { '✅' } else { if ($_ -eq 'Reader') { '❌' } else { '⚠️' } }
                    "$emoji $_"
                }) -join '  '

                $subMsg = "[$($sub.Name)] $rolesDisplay"
                Write-AuditLine -Status $status -Text $subMsg

                $subResult = [PSCustomObject]@{
                    SubscriptionId   = $sub.Id
                    SubscriptionName = $sub.Name
                    State            = $sub.State
                    AssignedRoles    = $foundRoles
                    HasReader        = 'Reader' -in $foundRoles
                    HasSecurityReader     = 'Security Reader' -in $foundRoles
                    HasMonitoringReader   = 'Monitoring Reader' -in $foundRoles
                    HasCostMgmtReader     = 'Cost Management Reader' -in $foundRoles
                    Status           = $status
                }
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
                if ('Security Reader' -notin $foundRoles) {
                    $recommendations.Add("Add Security Reader on '$($sub.Name)' for Defender data: New-AzRoleAssignment -ObjectId {principalId} -RoleDefinitionName 'Security Reader' -Scope '/subscriptions/$($sub.Id)'")
                }
            }
            catch {
                Write-AuditLine -Status Warn -Text "[$($sub.Name)] Cannot read role assignments: $($_.Exception.Message)"
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

    $targetSubs = if ($subs) { $subs | Where-Object { $_.State -eq 'Enabled' } | Select-Object -First 3 } else { @() }

    if ($targetSubs.Count -gt 0) {
        $checkSub = $targetSubs[0]
        Set-AzContext -SubscriptionId $checkSub.Id -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Checking against subscription: $($checkSub.Name)" -ForegroundColor Gray
        Write-Host ''

        foreach ($kvp in $criticalProviders.GetEnumerator()) {
            $provider = $kvp.Key
            $purpose  = $kvp.Value
            try {
                $reg = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
                $state = ($reg | Select-Object -ExpandProperty RegistrationState -First 1)
                $status = if ($state -eq 'Registered') { 'Pass' } elseif ($state -in 'Registering','Unregistering') { 'Warn' } else { 'Fail' }
                Write-AuditLine -Status $status -Text "$provider  [$state]  — $purpose"

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
            $graphToken = Get-AZTIGraphToken
            Write-AuditLine -Status Pass -Text 'Microsoft Graph token acquired successfully'
        }
        catch {
            Write-AuditLine -Status Fail -Text "Cannot acquire Microsoft Graph token: $($_.Exception.Message)"
            $graphDetails.Add(( New-CheckResult 'Graph: Token Acquisition' 'Fail' $_.Exception.Message `
                "Ensure the identity has Graph API permissions. For SPNs: grant app permissions in Entra ID app registration. For users: ensure Directory Readers or Global Reader directory role." ))
            $recommendations.Add('Grant Graph permissions — in Entra ID portal: App Registrations > API Permissions > Microsoft Graph > Directory.Read.All (application permission, requires admin consent)')
        }

        if ($graphToken) {
            $graphChecks = [ordered]@{
                'Graph: Organization Read'       = @{ Uri = '/v1.0/organization';                    Permission = 'Organization.Read.All'; Purpose = 'Basic tenant metadata' }
                'Graph: Users Read'              = @{ Uri = '/v1.0/users?$top=1';                   Permission = 'User.Read.All';          Purpose = 'User inventory' }
                'Graph: Groups Read'             = @{ Uri = '/v1.0/groups?$top=1';                  Permission = 'Group.Read.All';         Purpose = 'Group inventory' }
                'Graph: Applications Read'       = @{ Uri = '/v1.0/applications?$top=1';            Permission = 'Application.Read.All';   Purpose = 'App Registration inventory' }
                'Graph: Service Principals Read' = @{ Uri = '/v1.0/servicePrincipals?$top=1';      Permission = 'Application.Read.All';   Purpose = 'Service Principal inventory' }
                'Graph: Directory Roles Read'    = @{ Uri = '/v1.0/directoryRoles';                Permission = 'RoleManagement.Read.Directory'; Purpose = 'Directory role inventory' }
                'Graph: Conditional Access Read' = @{ Uri = '/v1.0/identity/conditionalAccess/policies?$top=1'; Permission = 'Policy.Read.All'; Purpose = 'Conditional Access policy inventory' }
                'Graph: Risky Users Read'        = @{ Uri = '/v1.0/identityProtection/riskyUsers?$top=1'; Permission = 'IdentityRiskyUser.Read.All'; Purpose = 'Identity Protection — risky users' }
                'Graph: Audit Logs Read'         = @{ Uri = '/v1.0/auditLogs/signIns?$top=1';      Permission = 'AuditLog.Read.All';      Purpose = 'Sign-in and audit log access (optional)' }
            }

            $graphAccess = $true
            foreach ($checkName in $graphChecks.Keys) {
                $check = $graphChecks[$checkName]
                try {
                    $null = Invoke-AZTIGraphRequest -Uri $check.Uri -SinglePage
                    $r = New-CheckResult $checkName 'Pass' "$($check.Permission)  — $($check.Purpose)"
                    Write-AuditLine -Status Pass -Text "$checkName  [$($check.Permission)]"
                }
                catch {
                    $isCritical = $checkName -in 'Graph: Organization Read', 'Graph: Users Read', 'Graph: Groups Read', 'Graph: Applications Read'
                    $status = if ($isCritical) { 'Fail'; $graphAccess = $false } else { 'Warn' }
                    $r = New-CheckResult $checkName $status `
                        "DENIED — $($check.Permission)  ($($check.Purpose))" `
                        "Grant '$($check.Permission)' in Entra ID > Enterprise Applications > API Permissions"
                    Write-AuditLine -Status $status -Text "$checkName  [$($check.Permission)] — DENIED"
                    $recommendations.Add("Grant Graph permission '$($check.Permission)' for: $($check.Purpose)")
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

    $recCount = ($recommendations | Sort-Object -Unique).Count
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
    Write-Host '  Suggested Invoke-AzureTenantInventory command:' -ForegroundColor Cyan
    $scopeSuggestion = if ($overallReadiness -eq 'FullARMAndEntra') { '-Scope All' } else { '-Scope ArmOnly' }
    Write-Host "    Invoke-AzureTenantInventory -TenantID $tenantId $scopeSuggestion" -ForegroundColor Cyan
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
        Recommendations  = ($recommendations | Sort-Object -Unique)
        OverallReadiness = $overallReadiness
        AuditTimestamp   = (Get-Date -Format 'o')
    }

    # ── Optional file output ───────────────────────────────────────────────────
    if ($OutputFormat -in 'Json', 'All') {
        $reportPath = if ($ReportDir) { $ReportDir } else {
            $rp = Set-AZTIReportPath -ReportDir $null
            $rp.DefaultPath
        }
        if (-not (Test-Path $reportPath)) { New-Item -ItemType Directory -Path $reportPath -Force | Out-Null }
        $jsonFile = Join-Path $reportPath ("PermissionAudit_" + (Get-Date -Format 'yyyy-MM-dd_HH_mm') + ".json")
        $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        Write-Host "  Audit saved → $jsonFile" -ForegroundColor Cyan
    }

    if ($OutputFormat -in 'Markdown', 'All') {
        $reportPath = if ($ReportDir) { $ReportDir } else {
            $rp = Set-AZTIReportPath -ReportDir $null
            $rp.DefaultPath
        }
        if (-not (Test-Path $reportPath)) { New-Item -ItemType Directory -Path $reportPath -Force | Out-Null }
        $mdFile = Join-Path $reportPath ("PermissionAudit_" + (Get-Date -Format 'yyyy-MM-dd_HH_mm') + ".md")

        $mdLines = [System.Collections.Generic.List[string]]::new()
        $mdLines.Add('# Azure Tenant Inventory - Permission Audit Report')
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
        $reportPath = if ($ReportDir) { $ReportDir } else {
            $rp = Set-AZTIReportPath -ReportDir $null
            $rp.DefaultPath
        }
        if (-not (Test-Path $reportPath)) { New-Item -ItemType Directory -Path $reportPath -Force | Out-Null }
        $adocFile = Join-Path $reportPath ("PermissionAudit_" + (Get-Date -Format 'yyyy-MM-dd_HH_mm') + ".adoc")

        $adocLines = [System.Collections.Generic.List[string]]::new()
        $adocLines.Add('= Azure Tenant Inventory — Permission Audit Report')
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
