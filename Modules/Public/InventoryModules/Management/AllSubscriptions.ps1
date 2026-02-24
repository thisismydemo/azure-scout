<#
.Synopsis
Inventory for ALL Azure Subscriptions in the tenant

.DESCRIPTION
This script enumerates every subscription the authenticated identity can access,
including empty subscriptions that contain zero resources. Cross-references the
Resource Graph to enrich each subscription with a resource count, resource group
count, and management group path.
Excel Sheet Name: All Subscriptions

.Link
https://github.com/thisismydemo/azure-inventory/Modules/Public/InventoryModules/Management/AllSubscriptions.ps1

.COMPONENT
    This PowerShell Module is part of Azure Tenant Inventory (AZTI).

.CATEGORY Management

.NOTES
Version: 1.0.0
First Release Date: February 24, 2026
Authors: AzureTenantInventory Contributors

#>

<######## Default Parameters. Don't modify this ########>

param($SCPath, $Sub, $Intag, $Resources, $Retirements, $Task, $File, $SmaResources, $TableStyle, $Unsupported)

If ($Task -eq 'Processing')
{
    <######### Insert the resource extraction here ########>

    # $Sub already contains ALL subscriptions retrieved at startup by Get-AZTISubscriptions.
    # We enrich each subscription with resource/RG counts and MG path.

    # Build resource count and resource group count maps
    $resourceCountMap   = @{}
    $rgCountMap         = @{}

    if ($Resources) {
        foreach ($res in $Resources) {
            $subId = $res.subscriptionId
            if (-not $subId) { continue }
            if ($resourceCountMap.ContainsKey($subId)) { $resourceCountMap[$subId]++ } else { $resourceCountMap[$subId] = 1 }
        }
        # Resource groups appear in Resources as type 'microsoft.resources/subscriptions/resourcegroups'
        $rgResources = $Resources | Where-Object { $_.TYPE -eq 'microsoft.resources/subscriptions/resourcegroups' }
        foreach ($rg in $rgResources) {
            $subId = $rg.subscriptionId
            if (-not $subId) { continue }
            if ($rgCountMap.ContainsKey($subId)) { $rgCountMap[$subId]++ } else { $rgCountMap[$subId] = 1 }
        }
    }

    # Build MG ancestor path map via Resource Graph
    $mgPathMap = @{}
    try {
        $graphQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions' | extend mgChain = properties.managementGroupAncestorsChain | project subscriptionId, mgChain"
        $graphResult = Search-AzGraph -Query $graphQuery -First 1000 -Debug:$false -ErrorAction SilentlyContinue
        foreach ($row in $graphResult) {
            $subId = $row.subscriptionId
            if ($row.mgChain) {
                # mgChain is ordered from immediate parent → root; reverse for root → leaf display
                $chainItems = @($row.mgChain)
                [array]::Reverse($chainItems)
                $mgPath = ($chainItems | ForEach-Object { $_.displayName }) -join ' / '
            } else {
                $mgPath = 'Tenant Root'
            }
            $mgPathMap[$subId] = $mgPath
        }
    } catch {
        Write-Debug ("AllSubscriptions: MG path lookup failed: $_")
    }

    <######### Insert the resource Process here ########>

    if ($Sub) {
        $tmp = foreach ($1 in $Sub) {
            $ResUCount = 1
            $subId = $1.Id

            $resourceCount   = if ($resourceCountMap.ContainsKey($subId)) { $resourceCountMap[$subId] } else { 0 }
            $rgCount         = if ($rgCountMap.ContainsKey($subId))       { $rgCountMap[$subId] }       else { 0 }
            $mgPath          = if ($mgPathMap.ContainsKey($subId))        { $mgPathMap[$subId] }        else { 'Unknown' }

            $spendingLimit   = try { $1.SubscriptionPolicies.SpendingLimit } catch { 'N/A' }
            $quotaId         = try { $1.SubscriptionPolicies.QuotaId }       catch { 'N/A' }
            $authSource      = try { $1.AuthorizationSource }                catch { 'N/A' }

            $tagsDisplay = if ($1.Tags -and $1.Tags.Count -gt 0) {
                ($1.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
            } else { '' }

            $obj = @{
                'ID'                    = $subId;
                'Subscription Name'     = $1.Name;
                'Subscription ID'       = $subId;
                'State'                 = $1.State;
                'Tenant ID'             = $1.TenantId;
                'Management Group Path' = $mgPath;
                'Resource Groups Count' = $rgCount;
                'Resources Count'       = $resourceCount;
                'Spending Limit'        = $spendingLimit;
                'Quota ID'              = $quotaId;
                'Authorization Source'  = $authSource;
                'Tags'                  = $tagsDisplay;
                'Resource U'            = $ResUCount;
            }
            $obj
            if ($ResUCount -eq 1) { $ResUCount = 0 }
        }
        $tmp
    }
}

<######## Resource Excel Reporting Begins Here ########>

Else
{
    <######## $SmaResources.(RESOURCE FILE NAME) ##########>

    if ($SmaResources)
    {
        $TableName = ('AllSubsTable_' + (($SmaResources.'Resource U' | Measure-Object -Sum).Sum))

        $condEmptyRow  = New-ConditionalText -Text '0' -Range 'H:H' -ConditionalTextColor ([System.Drawing.Color]::OrangeRed) -BackgroundColor ([System.Drawing.Color]::White)
        $condDisabled  = New-ConditionalText -Text 'Disabled' -Range 'D:D' -ConditionalTextColor ([System.Drawing.Color]::Gray) -BackgroundColor ([System.Drawing.Color]::WhiteSmoke)
        $condWarned    = New-ConditionalText -Text 'Warned' -Range 'D:D' -ConditionalTextColor ([System.Drawing.Color]::DarkOrange) -BackgroundColor ([System.Drawing.Color]::LightYellow)

        $Style = New-ExcelStyle -HorizontalAlignment Left -AutoSize -NumberFormat '0'

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription Name')
        $Exc.Add('Subscription ID')
        $Exc.Add('State')
        $Exc.Add('Tenant ID')
        $Exc.Add('Management Group Path')
        $Exc.Add('Resource Groups Count')
        $Exc.Add('Resources Count')
        $Exc.Add('Spending Limit')
        $Exc.Add('Quota ID')
        $Exc.Add('Authorization Source')
        $Exc.Add('Tags')
        $Exc.Add('Resource U')

        [PSCustomObject]$SmaResources |
        ForEach-Object { $_ } | Select-Object $Exc |
        Export-Excel -Path $File `
            -WorksheetName 'All Subscriptions' `
            -AutoSize `
            -MaxAutoSizeRows 100 `
            -TableName $TableName `
            -TableStyle $TableStyle `
            -Style $Style `
            -ConditionalText $condEmptyRow, $condDisabled, $condWarned
    }
}
