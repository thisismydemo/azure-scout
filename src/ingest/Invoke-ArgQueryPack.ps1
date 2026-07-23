#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Run a read-only Azure Resource Graph query pack and normalize results into
    the collect shapes the rules expect.

.NOTES
    Tracks ADO Story AB#5039. `-ManagementGroupId`, when supplied, is passed as
    `-ManagementGroup` to every `Search-AzGraph` call so this ingest is scoped the
    same way `Invoke-Collect` is, instead of always running tenant-wide.
#>
function Invoke-ArgQueryPack {
    param($Collect, [string] $ManagementGroupId)
    Import-Module Az.ResourceGraph -ErrorAction Stop

    $queries = @{
        subnetIpUsage = @'
resources
| where type =~ "microsoft.network/virtualnetworks"
| mv-expand subnet = properties.subnets
| extend prefix = tostring(subnet.properties.addressPrefix)
| extend total = toint(exp2(32 - toint(split(prefix,"/")[1]))) - 5
| extend used  = array_length(subnet.properties.ipConfigurations)
| project vnet = name, subnet = tostring(subnet.name), prefix, total, used,
          ipUtilizationPct = round(todouble(used) / total * 100, 1)
'@
        orphanedDisks = @'
resources
| where type =~ "microsoft.compute/disks" and properties.diskState =~ "Unattached"
| project name, resourceGroup, location, sku = sku.name, sizeGb = properties.diskSizeGB
'@
        orphanedPips = @'
resources
| where type =~ "microsoft.network/publicipaddresses" and isnull(properties.ipConfiguration)
| project name, resourceGroup, location, sku = sku.name
'@
        diagCoverage = @'
resources
| extend hasDiag = iff(isnotnull(properties.diagnosticSettings), true, false)
| summarize total = count(), withDiag = countif(hasDiag) by type
| extend coveragePct = round(todouble(withDiag)/total*100,1)
'@
        publicExposure = @'
resources
| where type =~ "microsoft.network/networksecuritygroups"
| mv-expand rule = properties.securityRules
| where rule.properties.access =~ "Allow" and rule.properties.direction =~ "Inbound"
      and (rule.properties.sourceAddressPrefix in ("*","0.0.0.0/0","Internet"))
| project nsg = name, resourceGroup, rule = tostring(rule.name),
          port = tostring(rule.properties.destinationPortRange)
'@
        nonZonalVms = @'
resources
| where type =~ "microsoft.compute/virtualmachines"
| extend zones = properties.zones
| where isnull(zones) or array_length(zones) == 0
| project name, resourceGroup, location, size = properties.hardwareProfile.vmSize
'@
    }

    $arg = [ordered]@{}
    foreach ($k in $queries.Keys) {
        $rows = @(); $skip = 0
        do {
            # Search-AzGraph rejects -Skip 0 (ValidateRange minimum is 1) — omit it on the first page.
            $params = @{ Query = $queries[$k]; First = 1000 }
            if ($skip -gt 0) { $params.Skip = $skip }
            if ($ManagementGroupId) { $params.ManagementGroup = $ManagementGroupId }
            $batch = @(Search-AzGraph @params)
            $rows += $batch; $skip += 1000
        } while ($batch.Count -eq 1000)
        $arg[$k] = $rows
    }

    # normalize into the shapes the rules expect.
    # Invoke-Collect already populated `networking` (virtualNetworks, azureFirewalls,
    # vpnGateways, privateEndpoints, privateDnsZones, ...). MERGE subnets +
    # nsgPublicInbound onto that existing object instead of replacing it — a `-Force`
    # replace here wiped the collector's networking data, so CAF-SEC-03/CAF-SEC-06/
    # CAF-NET-* rules saw empty inputs and false-failed.
    if (-not $Collect.PSObject.Properties['networking']) {
        $Collect | Add-Member -NotePropertyName networking -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $Collect.networking | Add-Member -NotePropertyName subnets          -NotePropertyValue $arg.subnetIpUsage  -Force
    $Collect.networking | Add-Member -NotePropertyName nsgPublicInbound -NotePropertyValue $arg.publicExposure -Force
    $Collect | Add-Member -NotePropertyName costCleanup -NotePropertyValue ([pscustomobject]@{
        orphanedDisks = $arg.orphanedDisks
        orphanedPips  = $arg.orphanedPips
    }) -Force
    $Collect | Add-Member -NotePropertyName opsPosture -NotePropertyValue ([pscustomobject]@{
        diagnosticCoverage = $arg.diagCoverage
    }) -Force
    return $Collect
}
