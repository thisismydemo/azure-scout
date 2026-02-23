<#
.SYNOPSIS
    Pre-flight permission checker for Azure Tenant Inventory.

.DESCRIPTION
    Validates that the current identity has sufficient ARM and/or Microsoft Graph
    permissions before the main inventory extraction runs. Returns a structured
    result object with per-check status, messages, and remediation guidance.

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
    $result = Test-AZTIPermissions -TenantID '00000000-0000-0000-0000-000000000000'
    $result.Details | Format-Table -AutoSize

.LINK
    https://github.com/thisismydemo/azure-inventory

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI)

.NOTES
    Version: 1.0.0
    Authors: Claudio Merola, thisismydemo
#>
function Test-AZTIPermissions {
    [CmdletBinding()]
    param(
        [string]$TenantID,

        [string[]]$SubscriptionID,

        [ValidateSet('All', 'ArmOnly', 'EntraOnly')]
        [string]$Scope = 'All'
    )

    $details = [System.Collections.Generic.List[PSCustomObject]]::new()
    $armAccess   = $true
    $graphAccess = $true

    # ---------------------------------------------------------------
    # ARM Permission Checks
    # ---------------------------------------------------------------
    if ($Scope -in 'All', 'ArmOnly') {

        # Check 1 — Subscription enumeration
        $enumeratedSubs = $null
        try {
            $getSubParams = @{ ErrorAction = 'Stop' }
            if ($TenantID) { $getSubParams['TenantId'] = $TenantID }

            $enumeratedSubs = @(Get-AzSubscription @getSubParams)

            if ($enumeratedSubs.Count -gt 0) {
                $details.Add([PSCustomObject]@{
                    Check       = 'ARM: Subscription Enumeration'
                    Status      = 'Pass'
                    Message     = "Found $($enumeratedSubs.Count) subscription(s)"
                    Remediation = $null
                })
            }
            else {
                $armAccess = $false
                $details.Add([PSCustomObject]@{
                    Check       = 'ARM: Subscription Enumeration'
                    Status      = 'Fail'
                    Message     = 'No subscriptions found in tenant'
                    Remediation = 'Grant the identity at least Reader role on one or more subscriptions.'
                })
            }
        }
        catch {
            $armAccess = $false
            $details.Add([PSCustomObject]@{
                Check       = 'ARM: Subscription Enumeration'
                Status      = 'Fail'
                Message     = $_.Exception.Message
                Remediation = 'Ensure the identity has Reader role on the tenant or target subscriptions.'
            })
        }

        # Check 2 — Role assignment read on first available subscription
        $targetSub = if ($SubscriptionID) { $SubscriptionID[0] }
                     elseif ($enumeratedSubs -and $enumeratedSubs.Count -gt 0) { $enumeratedSubs[0].Id }
                     else { $null }

        if ($targetSub) {
            try {
                $null = Get-AzRoleAssignment -Scope "/subscriptions/$targetSub" -ErrorAction Stop |
                        Select-Object -First 1
                $details.Add([PSCustomObject]@{
                    Check       = 'ARM: Role Assignment Read'
                    Status      = 'Pass'
                    Message     = "Can read role assignments on subscription $targetSub"
                    Remediation = $null
                })
            }
            catch {
                $details.Add([PSCustomObject]@{
                    Check       = 'ARM: Role Assignment Read'
                    Status      = 'Warn'
                    Message     = "Cannot read role assignments: $($_.Exception.Message)"
                    Remediation = 'Reader role is sufficient for most inventory data; role-assignment reads require Microsoft.Authorization/roleAssignments/read.'
                })
            }
        }
    }

    # ---------------------------------------------------------------
    # Microsoft Graph Permission Checks
    # ---------------------------------------------------------------
    if ($Scope -in 'All', 'EntraOnly') {

        # Check 1 — Organization (basic directory read)
        try {
            $null = Invoke-AZTIGraphRequest -Uri '/v1.0/organization' -SinglePage
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: Organization Read'
                Status      = 'Pass'
                Message     = 'Can read organization object'
                Remediation = $null
            })
        }
        catch {
            $graphAccess = $false
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: Organization Read'
                Status      = 'Fail'
                Message     = "Cannot read organization: $($_.Exception.Message)"
                Remediation = 'Grant Directory.Read.All (application) or User.Read.All (delegated) permission in Entra ID.'
            })
        }

        # Check 2 — Users (read permission)
        try {
            $null = Invoke-AZTIGraphRequest -Uri '/v1.0/users?$top=1' -SinglePage
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: User Read'
                Status      = 'Pass'
                Message     = 'Can read user objects'
                Remediation = $null
            })
        }
        catch {
            $graphAccess = $false
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: User Read'
                Status      = 'Fail'
                Message     = "Cannot read users: $($_.Exception.Message)"
                Remediation = 'Grant User.Read.All permission in Entra ID.'
            })
        }

        # Check 3 — Conditional Access policies (optional, warn-only)
        try {
            $null = Invoke-AZTIGraphRequest -Uri '/v1.0/identity/conditionalAccess/policies' -SinglePage
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: Conditional Access Policies'
                Status      = 'Pass'
                Message     = 'Can read Conditional Access policies'
                Remediation = $null
            })
        }
        catch {
            # This is optional — CA policy inventory is a bonus, not a requirement
            $details.Add([PSCustomObject]@{
                Check       = 'Graph: Conditional Access Policies'
                Status      = 'Warn'
                Message     = "Cannot read CA policies: $($_.Exception.Message)"
                Remediation = 'Grant Policy.Read.All permission for Conditional Access inventory (optional).'
            })
        }
    }

    # ---------------------------------------------------------------
    # Return structured result
    # ---------------------------------------------------------------
    return [PSCustomObject]@{
        ArmAccess   = $armAccess
        GraphAccess = $graphAccess
        Details     = $details
    }
}
