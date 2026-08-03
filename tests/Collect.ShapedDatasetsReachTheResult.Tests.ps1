#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
    AB#6896 -- a dataset the shaper produces can be dropped on the floor with no error.

    `Invoke-Collect` copies inverted-path results into `$r` by walking `$q.Keys` -- the typed
    Resource Graph query pack. A dataset `ConvertFrom-ScoutInventory` shapes but that has NO typed
    query (because no KQL can produce it, or because it is derived from rows the raw pass already
    holds) is never visited by that loop, so it must be copied across explicitly.

    `arcSites` and `azureLocalVirtualMachineInstances` always were. `recoveryVaults` was not: the
    AB#6895 fix taught the shaper to build Recovery Services vaults from the raw `resources` rows,
    added no `$q` entry, and added no explicit copy -- so the fix was a NO-OP in production. Vaults
    kept reporting zero on every run while `backupProtectedItems` returned rows, which is exactly
    the vanishing-parent failure (AB#6845) it was written to close. It passed review, passed the
    suite, and shipped in v3.3.2.

    The gap is structural, so the guard is structural: enumerate what the shaper produces and
    assert every key has somewhere to land. That is cheaper than one assertion per dataset and,
    unlike a per-dataset test, it covers the dataset nobody has added yet.
#>

BeforeAll {
    $script:CollectDir = Join-Path $PSScriptRoot '..' 'src' 'collect'
    . (Join-Path $script:CollectDir 'ConvertFrom-ScoutInventory.ps1')

    # Comment lines are stripped before any pattern scan below. The file explains these traps in
    # prose, quoting the very expressions being banned, and a scan over the raw text flags the
    # explanation as the offence.
    $script:InvokeCollectCode = (
        Get-Content (Join-Path $script:CollectDir 'Invoke-Collect.ps1') |
            Where-Object { $_ -notmatch '^\s*#' }
    ) -join "`n"

    # An empty inventory still declares the full key set -- the shaper seeds every dataset it
    # knows about, which is precisely the contract under test.
    $script:ShapedKeys = @((ConvertFrom-ScoutInventory -Resources @() -ResourceContainers @()).Keys)

    $qBlock = [regex]::Match($script:InvokeCollectCode, '(?s)\$q = @\{.*?\r?\n    \}').Value
    $script:TypedQueryKeys = @(
        [regex]::Matches($qBlock, "(?m)^\s+([A-Za-z][A-Za-z0-9]*)\s*=\s*@'") | ForEach-Object { $_.Groups[1].Value }
    )
    $script:ExplicitCopyKeys = @(
        [regex]::Matches($script:InvokeCollectCode, "\`$r\['([A-Za-z][A-Za-z0-9]*)'\]\s*=") |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    )
}

Describe 'Every dataset ConvertFrom-ScoutInventory shapes can reach the collect result (AB#6896)' {

    It 'parses a non-trivial typed-query pack and copy list out of Invoke-Collect' {
        # If either regex stops matching, every assertion below would pass vacuously. Fail loudly
        # instead of quietly asserting nothing.
        $script:ShapedKeys.Count | Should -BeGreaterThan 40
        $script:TypedQueryKeys.Count | Should -BeGreaterThan 40
        $script:ExplicitCopyKeys | Should -Not -BeNullOrEmpty
    }

    It 'leaves no shaped dataset without either a typed query or an explicit copy' {
        $lost = @($script:ShapedKeys | Sort-Object | Where-Object {
                $script:TypedQueryKeys -notcontains $_ -and $script:ExplicitCopyKeys -notcontains $_
            })
        # Named in the failure message: a bare count tells whoever hits this nothing about which
        # dataset they just added and forgot to wire up.
        $lost -join ', ' | Should -BeNullOrEmpty -Because 'a dataset with no typed query is only copied into $r if Invoke-Collect assigns it explicitly; anything listed here is collected and then silently discarded'
    }

    It 'never guards a $r lookup with PSObject.Properties' {
        # `$r` is a hashtable. `$r.PSObject.Properties['x']` resolves the dictionary adapter's own
        # members (Keys/Values/Count), never the keys -- so such a guard is unconditionally false
        # and its whole branch is dead. This is how the AB#6895 vault read returned @() forever.
        $offenders = @(
            [regex]::Matches($script:InvokeCollectCode, "\`$r\.PSObject\.Properties\['([A-Za-z][A-Za-z0-9]*)'\]") |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        )
        $offenders -join ', ' | Should -BeNullOrEmpty -Because 'use $r.ContainsKey(...) -- a hashtable does not expose its keys as PSObject properties'
    }
}

Describe 'recoveryVaults specifically survives the inverted path (AB#6895/AB#6896)' {

    It 'carries a shaped vault through to the canonical contract' {
        $vaultRow = @'
{
  "id": "/subscriptions/s1/resourceGroups/rg1/providers/Microsoft.RecoveryServices/vaults/rsv1",
  "name": "rsv1",
  "type": "microsoft.recoveryservices/vaults",
  "location": "eastus",
  "resourceGroup": "rg1",
  "subscriptionId": "s1",
  "properties": { "provisioningState": "Succeeded" }
}
'@ | ConvertFrom-Json

        $shaped = ConvertFrom-ScoutInventory -Resources @($vaultRow) -ResourceContainers @()
        # The shaper's half of AB#6895 was always correct -- it was the hand-off that was not.
        @($shaped['recoveryVaults']).Count | Should -Be 1
        @($shaped['recoveryVaults'])[0].name | Should -Be 'rsv1'
    }
}
