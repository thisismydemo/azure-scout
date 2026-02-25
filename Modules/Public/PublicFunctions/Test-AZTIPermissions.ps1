<#
.SYNOPSIS
    Pre-flight permission checker for Azure Scout.

.DESCRIPTION
    Validates that the current identity has sufficient ARM and/or Microsoft Graph
    permissions before the main inventory extraction runs. Returns a structured
    result object with per-check status, messages, and remediation guidance.

    This function delegates to Invoke-AZSCPermissionAudit to avoid duplicating
    permission-check logic. It maps the richer audit result back to the simpler
    shape that existing callers expect.

    This function never blocks execution — callers should inspect the result and
    display warnings for any failed or degraded checks.

.PARAMETER TenantID
    Target Azure AD tenant ID.

.PARAMETER SubscriptionID
    One or more subscription IDs to validate ARM access against.
    If omitted, the function enumerates subscriptions from the tenant.

.PARAMETER Scope
    Controls which permission categories to check.
    All (default) — ARM + Graph, ArmOnly — ARM only, EntraOnly — Graph only.

.OUTPUTS
    [PSCustomObject] with properties:
        ArmAccess   [bool]   — $true if core ARM checks passed
        GraphAccess [bool]   — $true if core Graph checks passed
        Details     [array]  — Per-check objects: Check, Status (Pass/Warn/Fail), Message, Remediation

.EXAMPLE
    $result = Test-AZSCPermissions -TenantID '00000000-0000-0000-0000-000000000000'
    $result.Details | Format-Table -AutoSize

.LINK
    https://github.com/thisismydemo/azure-scout

.COMPONENT
    This PowerShell Module is part of Azure Scout (AZSC)

.NOTES
    Version: 2.0.0
    Authors: Claudio Merola, thisismydemo
    Refactored (20.4.1): delegates to Invoke-AZSCPermissionAudit to avoid duplicate logic.
#>
function Test-AZSCPermissions {
    [CmdletBinding()]
    param(
        [string]$TenantID,

        # SubscriptionID is retained for backward API compatibility but is not consumed by the
        # delegated Invoke-AZSCPermissionAudit call (which auto-enumerates all accessible subs).
        [string[]]$SubscriptionID,

        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]$Scope = 'All'
    )

    # ── Delegate to Invoke-AZSCPermissionAudit ───────────────────────────────
    # Map the -Scope parameter to Invoke-AZSCPermissionAudit's -IncludeEntraPermissions switch.
    # The full audit function performs a strict superset of the checks this function used to do.
    $includeEntra = $Scope -in 'All', 'EntraOnly'

    $auditParams = @{
        OutputFormat = 'Console'
    }
    if ($TenantID)     { $auditParams['TenantID']                = $TenantID }
    if ($includeEntra) { $auditParams['IncludeEntraPermissions'] = $true }

    $auditResult = Invoke-AZSCPermissionAudit @auditParams

    if (-not $auditResult) {
        # Invoke-AZSCPermissionAudit returned $null — no auth context available
        return [PSCustomObject]@{
            ArmAccess   = $false
            GraphAccess = $false
            Details     = @([PSCustomObject]@{
                Check       = 'Azure Authentication'
                Status      = 'Fail'
                Message     = 'No Azure authentication context found. Run Connect-AzAccount first.'
                Remediation = 'Connect-AzAccount -TenantId <tenantId>'
            })
        }
    }

    # ── Map richer result to simplified shape expected by existing callers ────
    # Combine ARM + provider + Graph details into the single Details array.
    $allDetails = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($d in $auditResult.ArmDetails)     { $allDetails.Add($d) }
    foreach ($p in $auditResult.ProviderResults) {
        $allDetails.Add([PSCustomObject]@{
            Check       = "Provider: $($p.Provider)"
            Status      = $p.Status
            Message     = "$($p.Purpose) — $($p.RegistrationState)"
            Remediation = if ($p.Status -ne 'Pass') { "Register-AzResourceProvider -ProviderNamespace '$($p.Provider)'" } else { $null }
        })
    }
    foreach ($g in $auditResult.GraphDetails)    { $allDetails.Add($g) }

    # For EntraOnly scope suppress ARM details from the returned Details array.
    if ($Scope -eq 'EntraOnly') {
        $allDetails = [System.Collections.Generic.List[PSCustomObject]]($allDetails | Where-Object { $_.Check -like 'Graph:*' })
    }

    return [PSCustomObject]@{
        ArmAccess   = $auditResult.ArmAccess
        GraphAccess = if ($Scope -eq 'ArmOnly') { $null } else { $auditResult.GraphAccess }
        Details     = $allDetails.ToArray()
    }
}
