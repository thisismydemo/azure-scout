#
# Re-created for AB#6801. The prior manifest (converted from
# archived/Modules/Public/InventoryModules/Hybrid/ArcSites.ps1, AB#5660) declared three
# provider/type pairs that do not exist -- `microsoft.azurestackhci/sites`,
# `microsoft.edgeconfig/sites`, `microsoft.hybridcompute/sites` -- and was retired outright in
# AB#6842 rather than corrected, because at the time no verified replacement type was in hand.
#
# The audit's suggested correction, `Microsoft.Edge/sites`, is confirmed real:
#   - listed in manifests/azure-provider-types.json (ARM's own provider/type catalog, 2026-07-31)
#   - documented at https://learn.microsoft.com/azure/templates/microsoft.edge/2025-06-01/sites
#   - it is Azure Arc site manager's site resource -- see
#     https://learn.microsoft.com/azure/azure-arc/site-manager/overview
#
# It is NOT Resource-Graph-indexed, though: Resource Graph's supported-type reference
# (https://learn.microsoft.com/azure/governance/resource-graph/reference/supported-tables-resources)
# lists thirteen `microsoft.edge/*` types it carries and `sites` is not one of them. So this
# collector cannot read the `resources` table either -- it reads the per-subscription ARM REST
# list `Get-ScoutApiResources.ps1` now makes (`ArcSites` field), converted to resource rows by
# `ConvertTo-ScoutArcSiteResource.ps1`, the same non-RG-indexed shape AB#6769 established for
# Monitor/ResourceDiagnosticSettings.
#
# `Microsoft.Edge/sites` has no `tags` property in its schema (SiteProperties carries
# `displayName`, `description`, `siteAddress`, `labels` -- no `tags`), so this collector emits
# exactly one row per site rather than one row per tag.
#
@{
    ResourceTypes = @(
        'AZSC/ARMChild/ArcSites'
    )

    ResourceTypeMatching = 'Grouped'

    AdditionalFilter = $null

    FilterPreamble = ''

    RowLoopVariable = '1'

    Preamble = @'
$ResUCount = 1
            $sub1 = $SUB | Where-Object { $_.id -eq $1.subscriptionId }
            $data = $1.PROPERTIES
            # No `tags` property exists on this resource type (see the header note above); the
            # loop still needs a single-iteration source so exactly one row is emitted per site.
            $Tags = '0'

            $resourceGroupName = if ([string]::IsNullOrEmpty($1.RESOURCEGROUP)) { 'N/A (subscription-scoped)' } else { [string]$1.RESOURCEGROUP }

            $address = $data.siteAddress
            $addressLine = if ($null -eq $address) {
                'N/A'
            }
            else {
                $Parts = @(
                    $address.streetAddress1, $address.streetAddress2, $address.city,
                    $address.stateOrProvince, $address.postalCode
                ) | Where-Object { -not [string]::IsNullOrEmpty($_) }
                if ($Parts.Count -gt 0) { $Parts -join ', ' } else { 'N/A' }
            }
            $country = if ($null -ne $address -and -not [string]::IsNullOrEmpty($address.country)) { $address.country } else { 'N/A' }

            $labelCount = if ($data.labels) { @($data.labels.psobject.properties).Count } else { 0 }
'@

    AdditionalRowLoops = @()

    TagLoop = @{
        Variable = 'Tag'
        Source = '$Tags'
        Preamble = ''
    }

    Fields = @(
        @{
            Name = 'ID'
            Expression = '$1.id'
        }
        @{
            Name = 'Subscription'
            Expression = '(Get-AZSCSafeProperty -InputObject $sub1 -Path ''name'')'
        }
        @{
            Name = 'Resource Group'
            Expression = '$resourceGroupName'
        }
        @{
            Name = 'Name'
            Expression = '$1.NAME'
        }
        @{
            Name = 'Display Name'
            Expression = 'if ($data.displayName) { $data.displayName } else { ''N/A'' }'
        }
        @{
            Name = 'Description'
            Expression = 'if ($data.description) { $data.description } else { ''N/A'' }'
        }
        @{
            Name = 'Address'
            Expression = '$addressLine'
        }
        @{
            Name = 'Country/Region'
            Expression = '$country'
        }
        @{
            Name = 'Label Count'
            Expression = '$labelCount'
        }
        @{
            Name = 'Resource U'
            Expression = '$ResUCount'
        }
    )

    Export = @{
        WorksheetName = 'Arc Sites'
        TableNamePrefix = 'ArcSitesTable_'
        Columns = @(
            'Subscription'
            'Resource Group'
            'Name'
            'Display Name'
            'Description'
            'Address'
            'Country/Region'
            'Label Count'
            'Resource U'
        )
        TagColumns = @()
        TagColumnsBefore = $null
        NumberFormat = '0'
        ConditionalText = @()
    }

    SourceCollector = 'src/collect/ConvertTo-ScoutArcSiteResource.ps1'

    # This definition was hand-authored for AB#6801 against Microsoft.Edge/sites, NOT lifted
    # from a v2 collector -- see this file's header. ConvertTo-ScoutArcSiteResource.ps1 is the
    # REST projection helper the pipeline calls, not a Standard-contract collector, so
    # ConvertTo-ScoutCollectorDefinition.ps1 cannot regenerate a definition from it: it looks
    # for a `$Task -eq 'Processing'` branch that a converter has no reason to contain.
    #
    # The drift check therefore threw on every run and failed the whole gate. It has been red
    # on main since at least the v3.2.0 release, blocking every pull request in the repo --
    # a check nobody can make pass stops being a gate and starts being a tax.
    #
    # Declaring the exemption is the mechanism Test-ScoutCollectorDefinition.ps1 already
    # provides for exactly this case: it prints "Manual conversion drift exemption" with this
    # reason rather than silently skipping, so the exemption stays visible in the log.
    # SourceCollector is retained as provenance for where the projection logic lives.
    ManualConversionReason = 'Hand-authored for AB#6801 against Microsoft.Edge/sites. SourceCollector names the REST projection helper, which is not a Standard-contract collector and cannot be mechanically re-converted; the committed golden output is the behavioural evidence instead.'
}
