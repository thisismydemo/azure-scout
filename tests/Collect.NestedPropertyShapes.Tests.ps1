#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
    AB#6899 -- `Get-ScoutProp`/`Get-ScoutPropArray` could only walk ONE shape.

    Both walkers resolved every path segment with `PSObject.Properties[$segment]`, which finds
    PSCustomObject members and nothing else. Two shapes it silently returned $null for, with no
    error and no warning:

      * `IDictionary` -- PowerShell's dictionary adapter exposes `Keys`/`Values`/`Count` as
        members, never the keys themselves. Any caller handing rows through a hashtable hit this.
      * `Newtonsoft.Json.Linq.JObject` -- `PSObject.Properties` on one is EMPTY, so a nested read
        was indistinguishable from an absent property.

    SCOPE, measured rather than assumed: the path Scout actually runs today is NOT affected.
    `Search-AzGraph` (Az.ResourceGraph 1.3.0, SearchAzureRmGraph) converts rows through
    JTokenExtensions.ToPsObject, which builds a PSCustomObject recursively -- confirmed against a
    live tenant, where both the pre-fix and post-fix walkers shape 5 VNets into 8 subnets
    identically. This is hardening for the other two shapes and a guard against a future caller
    reaching these functions with one, not a fix for an observed production failure.

    Every case therefore runs the SAME reads across all shapes. Every pre-existing fixture in this
    suite is built by `ConvertFrom-Json` and so is PSCustomObject all the way down, which is why
    the dictionary gap was invisible.

    `$script:Shapes` is at file scope, not in `BeforeAll`: Pester evaluates `-ForEach` during
    discovery, before any `BeforeAll` has run.
#>

# Newtonsoft ships with Az.Accounts. If it is genuinely unavailable the JObject cases DROP OUT of
# the shape list rather than quietly passing against a substitute shape that cannot reproduce the
# bug. Loaded during discovery because `$script:Shapes` below feeds `-ForEach`.
if (-not ('Newtonsoft.Json.Linq.JObject' -as [type])) {
    Import-Module Az.Accounts -ErrorAction SilentlyContinue
}
$script:Shapes = @('pscustomobject', 'dictionary') +
    $(if ('Newtonsoft.Json.Linq.JObject' -as [type]) { , 'jobject' } else { @() })

# Pester v5 runs the file body for DISCOVERY and then executes `It` bodies in a separate scope, so
# the fixture builders have to be defined in `BeforeAll` to exist at run time -- only the
# `-ForEach` list above is needed during discovery.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'src' 'collect' 'ConvertFrom-ScoutInventory.ps1')

    $script:VnetJson = @'
{
  "id": "/subscriptions/s1/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/vnet1",
  "name": "vnet1",
  "type": "microsoft.network/virtualnetworks",
  "location": "eastus",
  "resourceGroup": "rg1",
  "subscriptionId": "s1",
  "sku": { "name": "Standard", "tier": "Regional" },
  "properties": {
    "enableDdosProtection": true,
    "virtualNetworkPeerings": [ { "name": "peer1" }, { "name": "peer2" } ],
    "subnets": [
      { "name": "snet-app",
        "properties": { "addressPrefix": "10.0.0.0/24",
                        "ipConfigurations": [ { "id": "ipc1" }, { "id": "ipc2" } ] } },
      { "name": "snet-empty",
        "properties": { "addressPrefix": "10.0.1.0/28", "ipConfigurations": [] } }
    ]
  }
}
'@

    function ConvertTo-ScoutTestDictionary {
    # PSCustomObject -> nested Dictionary[string,object]: the shape a row takes once it has been
    # round-tripped through any hashtable-based caller.
        param($Node)
        if ($Node -is [System.Management.Automation.PSCustomObject]) {
            $d = [System.Collections.Generic.Dictionary[string, object]]::new()
            foreach ($p in $Node.PSObject.Properties) { $d[$p.Name] = ConvertTo-ScoutTestDictionary $p.Value }
            return $d
        }
        if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
            return , @(foreach ($item in $Node) { ConvertTo-ScoutTestDictionary $item })
        }
        return $Node
    }

    function New-ScoutTestRow {
        param([ValidateSet('pscustomobject', 'dictionary', 'jobject')] [string] $Shape)
        # Every arm returns through a unary comma. A JObject is IEnumerable over its JProperties,
        # so a bare `return $jobject` emits the PROPERTIES and the caller never sees the row --
        # the same class of trap as the defect under test.
        switch ($Shape) {
            'pscustomobject' { return , ($script:VnetJson | ConvertFrom-Json) }
            'dictionary' { return , (ConvertTo-ScoutTestDictionary ($script:VnetJson | ConvertFrom-Json)) }
            # A real JObject, which is what the walkers have to cope with when a caller hands one
            # in. It is returned through the unary comma for the same reason as the others, and
            # more urgently: a JObject is IEnumerable over its JProperties, so a bare
            # `return $jobject` emits the PROPERTIES and the caller never sees the object at all.
            'jobject' { return , ([Newtonsoft.Json.Linq.JObject]::Parse($script:VnetJson)) }
        }
    }
}

Describe 'Get-ScoutProp reads nested columns on every shape a Resource Graph row can take (AB#6899)' {

    It 'reads a top-level column -- <_>' -ForEach $script:Shapes {
        Get-ScoutProp (New-ScoutTestRow $_) 'name' | Should -Be 'vnet1'
    }

    It 'reads a nested scalar as a real [bool], not a JValue -- <_>' -ForEach $script:Shapes {
        $v = Get-ScoutProp (New-ScoutTestRow $_) 'properties.enableDdosProtection'
        $v | Should -BeOfType [bool]
        $v | Should -BeTrue
    }

    It 'reads a nested object column other than properties -- <_>' -ForEach $script:Shapes {
        Get-ScoutProp (New-ScoutTestRow $_) 'sku.name' | Should -Be 'Standard'
    }

    It 'counts a nested array -- <_>' -ForEach $script:Shapes {
        Measure-ScoutArray (Get-ScoutProp (New-ScoutTestRow $_) 'properties.virtualNetworkPeerings') | Should -Be 2
    }

    It 'walks three segments deep, through an array element -- <_>' -ForEach $script:Shapes {
        # No `@()` around Get-ScoutPropArray: it returns its array through a unary comma, so an
        # array subexpression around the call wraps it a second time.
        $subnets = Get-ScoutPropArray (New-ScoutTestRow $_) 'properties.subnets'
        Get-ScoutProp $subnets[0] 'properties.addressPrefix' | Should -Be '10.0.0.0/24'
    }

    It 'returns null for a genuinely absent segment rather than throwing -- <_>' -ForEach $script:Shapes {
        Get-ScoutProp (New-ScoutTestRow $_) 'properties.noSuchKey.deeper' | Should -BeNullOrEmpty
    }
}

Describe 'Get-ScoutPropArray keeps "present but empty" distinct from "absent" on every shape (AB#6820)' {
    # array_length([]) is 0 in KQL and array_length(missing) is null. The inverted path has to
    # agree with the typed path on that, or the two disagree on every zero-count finding.

    It 'reports 0, not null, for a present-but-empty array -- <_>' -ForEach $script:Shapes {
        $subnets = Get-ScoutPropArray (New-ScoutTestRow $_) 'properties.subnets'
        $empty = $subnets | Where-Object { (Get-ScoutProp $_ 'name') -eq 'snet-empty' }
        Measure-ScoutArray (Get-ScoutPropArray $empty 'properties.ipConfigurations') | Should -Be 0
    }

    It 'reports null for a genuinely absent property -- <_>' -ForEach $script:Shapes {
        Measure-ScoutArray (Get-ScoutPropArray (New-ScoutTestRow $_) 'properties.noSuchKey') | Should -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-ScoutInventory shapes real values from the row shapes it can actually receive' {
    # Only the two shapes that can reach this function. `Search-AzGraph` (Az.ResourceGraph 1.3.0,
    # Microsoft.Azure.Commands.ResourceGraph.Cmdlets.SearchAzureRmGraph) converts each row through
    # JTokenExtensions.ToPsObject, which builds a PSCustomObject RECURSIVELY -- verified against a
    # live tenant, `properties` comes back as a PSCustomObject, not a JToken. A row that were a
    # JObject could not bind to `[object[]] $Resources` at all: PowerShell would enumerate it into
    # its JProperties first. The JObject coverage that matters is on the walkers above, where a
    # JObject-VALUED column is the thing being read.
    $shapes = @('pscustomobject', 'dictionary')

    It 'populates virtualNetworks.peeringCount instead of null -- <_>' -ForEach $shapes {
        # The exact symptom in the banked eight-tenant corpus: peeringCount and ddosEnabled were
        # null on every VNet in every tenant.
        $shaped = ConvertFrom-ScoutInventory -Resources @((New-ScoutTestRow $_)) -ResourceContainers @()
        @($shaped['virtualNetworks'])[0].peeringCount | Should -Be 2
    }

    It 'populates virtualNetworks.ddosEnabled instead of null -- <_>' -ForEach $shapes {
        $shaped = ConvertFrom-ScoutInventory -Resources @((New-ScoutTestRow $_)) -ResourceContainers @()
        @($shaped['virtualNetworks'])[0].ddosEnabled | Should -BeTrue
    }

    It 'returns subnets rows at all -- <_>' -ForEach $shapes {
        # networking.subnets was zero rows in all eight tenants while virtualNetworks returned 18.
        $shaped = ConvertFrom-ScoutInventory -Resources @((New-ScoutTestRow $_)) -ResourceContainers @()
        @($shaped['subnets']).Count | Should -Be 2
    }

    It 'computes subnet capacity and utilisation from the address prefix -- <_>' -ForEach $shapes {
        $shaped = ConvertFrom-ScoutInventory -Resources @((New-ScoutTestRow $_)) -ResourceContainers @()
        $app = @($shaped['subnets']) | Where-Object { $_.subnet -eq 'snet-app' }
        $app.prefix | Should -Be '10.0.0.0/24'
        $app.total | Should -Be 251     # 256 addresses less the 5 Azure reserves
        $app.used | Should -Be 2
    }
}
