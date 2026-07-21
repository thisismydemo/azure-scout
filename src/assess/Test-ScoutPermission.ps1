#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Verify the read-only access each selected assessment needs and emit remediation.

.NOTES
    Read-only throughout. Tracks ADO Story AB#5051.
#>
function Test-ScoutPermission {
    param([string[]] $Assessment, $Manifest)
    $results = @()

    # ARM: Reader at MG root
    $ctx = Get-AzContext
    $mgReader = Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$($ctx.Tenant.Id)" `
        -SignInName $ctx.Account.Id -ErrorAction SilentlyContinue |
        Where-Object RoleDefinitionName -eq 'Reader'
    $results += [pscustomobject]@{
        Check = 'ARM Reader @ MG root'; Ok = [bool]$mgReader
        Fix   = 'Assign Reader at the tenant root management group scope.'
    }

    # Graph app permissions needed when ingesting the governance visualizer
    if ($Assessment | Where-Object { $Manifest[$_].Ingest -contains 'AzGovViz' }) {
        foreach ($p in 'User.Read.All', 'Group.Read.All', 'Application.Read.All', 'PrivilegedAccess.Read.AzureResources') {
            $results += [pscustomobject]@{
                Check = "Graph: $p"; Ok = $null
                Fix   = "Grant application permission $p with admin consent (or use Directory Readers)."
            }
        }
    }
    $results | Format-Table -AutoSize
    return $results
}
